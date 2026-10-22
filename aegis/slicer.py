"""
slicer.py - cut a harness down to what one obligation can observe.

A general-arm obligation is checked against a harness that reconstructs the
whole contract. On a flattened mainnet source that is dozens of state variables
and every function body, and the reconstruction either fails to compile on some
construct the obligation never mentions or produces a query too large for the
Horn solver to decide. The read-only arm already avoids this by checking a
slice; this extends the same idea to the general arm.

The slicing criterion is the obligation's own check function: every storage
variable it reads through `v.<name>` must keep its true value. From there the
slice is a backward closure over two kinds of dependence.

  data     a kept statement that writes v and reads w needs w
  control  a statement kept inside a branch or loop needs the variables its
           condition reads, and everything that writes them

Soundness. What is removed only ever adds executions, never takes them away:

  * a statement writing only variables nothing kept reads cannot change any
    value the obligation observes; removing it also removes any revert it
    might have raised, which admits more executions, not fewer
  * a require or assert over variables outside the slice is removed for the
    same reason: it can only have cut paths short

So a VERIFIED result on the slice holds for the full harness. The imprecision
falls on the other side -- a removed guard can admit a path the original
contract would have rejected -- which can cost a spurious refutation but never
a false proof.

Anything the slicer does not understand is kept. A statement it cannot classify,
a call to a helper, a line holding more than one statement: all are kept whole,
and everything they read joins the slice.
"""
from __future__ import annotations

import re

# Solidity keywords and type names only. Member names such as `sender`,
# `value`, `length` or `balance` must NOT be here: they are also ordinary
# local names, and filtering them meant a kept line reading a local `sender`
# never marked it needed, so its declaration was sliced away and the call
# referred to a name that no longer existed. `msg`, `block`, `tx` and `abi`
# stay, since they are never variables; a stray name here only ever keeps
# more lines, which is safe.
_KEYWORDS = {
    "if", "else", "for", "while", "do", "return", "returns", "require",
    "assert", "revert", "emit", "new", "delete", "true", "false", "this",
    "msg", "block", "tx", "abi", "super", "unchecked", "memory", "storage",
    "calldata", "public", "private", "internal", "external", "view", "pure",
    "payable", "virtual", "override", "constant", "immutable", "mapping",
    "function", "modifier", "constructor", "struct", "enum", "event",
    "address", "bool", "string", "bytes", "uint", "int", "type", "keccak256",
    "sha256", "ecrecover", "addmod", "mulmod", "gasleft", "blockhash",
    "wei", "gwei", "ether", "seconds", "minutes", "hours", "days", "weeks",
}
_INT = re.compile(r"^(?:u?int\d*|bytes\d+|address|bool)$")
_IDENT = re.compile(r"\b[A-Za-z_]\w*\b")
_ASSIGN_OPS = r"(?:\+=|-=|\*=|/=|%=|\|=|&=|\^=|<<=|>>=|=(?!=))"
_ASSIGN = re.compile(
    r"^\s*([A-Za-z_]\w*)((?:\s*\[[^\]]*\]|\s*\.\s*[A-Za-z_]\w*)*)\s*"
    + _ASSIGN_OPS)
_INCDEC = re.compile(r"^\s*(?:\+\+|--)?\s*([A-Za-z_]\w*)(?:\[[^\]]*\])*\s*"
                     r"(?:\+\+|--)?\s*;\s*$")
_DELETE = re.compile(r"^\s*delete\s+([A-Za-z_]\w*)")
_LOCAL = re.compile(
    r"^\s*(?:[A-Za-z_][\w.]*(?:\s*\[[^\]]*\])*)"
    r"(?:\s+(?:memory|storage|calldata|payable))*\s+([A-Za-z_]\w*)\s*(?:=|;)")
_TUPLE = re.compile(r"^\s*\(([^)]*)\)\s*=")


def _idents(text: str) -> set:
    return {t for t in _IDENT.findall(text)
            if t not in _KEYWORDS and not _INT.match(t)}


def _strip_comment(line: str) -> str:
    i = line.find("//")
    return line if i < 0 else line[:i]


def _classify(stmt: str):
    """(kind, writes, reads) for one simple statement.

    kind is 'local', 'assign', 'guard', 'call' or 'other'. writes is the set
    of names the statement writes (a local's name for a declaration, the base
    variable for an assignment); reads is every other identifier it mentions.
    """
    s = stmt.strip().rstrip(";").strip()
    ids = _idents(s)
    if re.match(r"^(require|assert|revert)\b", s):
        return "guard", set(), ids
    if re.match(r"^emit\b", s):
        return "emit", set(), ids
    if re.match(r"^return\b", s):
        return "other", set(), ids
    m = _TUPLE.match(s)
    if m:
        names = {p.strip().split()[-1] for p in m.group(1).split(",")
                 if p.strip() and len(p.strip().split()) >= 2}
        return "local", names, ids - names
    m = _LOCAL.match(s + ";")
    if m and not _ASSIGN.match(s):
        name = m.group(1)
        return "local", {name}, ids - {name}
    m = _ASSIGN.match(s)
    if m:
        base = m.group(1)
        # a compound or indexed write reads the variable too
        return "assign", {base}, ids
    m = _DELETE.match(s)
    if m:
        return "assign", {m.group(1)}, ids
    m = _INCDEC.match(s + ";")
    if m and ("++" in s or "--" in s):
        return "assign", {m.group(1)}, ids
    if re.search(r"\b[A-Za-z_]\w*\s*\(", s):
        return "call", set(), ids
    return "other", set(), ids


def _split_contract(src: str):
    """(before, header, members, after) for the first contract in src."""
    m = re.search(r"\bcontract\s+[A-Za-z_]\w*[^{]*\{", src)
    if not m:
        return None
    start = m.end()
    depth, i = 1, start
    while i < len(src) and depth:
        c = src[i]
        depth += c == "{"
        depth -= c == "}"
        i += 1
    return src[:m.start()], src[m.start():start], src[start:i - 1], src[i - 1:]


def _members(body: str):
    """Split a contract body into ('decl'|'func'|'other', text) members."""
    out, i, n = [], 0, len(body)
    while i < n:
        # skip whitespace
        j = i
        while j < n and body[j] in " \t\r\n":
            j += 1
        if j >= n:
            out.append(("space", body[i:]))
            break
        if body.startswith("//", j):
            k = body.find("\n", j)
            k = n if k < 0 else k + 1
            out.append(("other", body[i:k]))
            i = k
            continue
        if body.startswith("/*", j):
            k = body.find("*/", j)
            k = n if k < 0 else k + 2
            out.append(("other", body[i:k]))
            i = k
            continue
        # find whichever comes first at depth 0: ';' or '{'
        k, depth = j, 0
        while k < n:
            c = body[k]
            if c == "{":
                if depth == 0:
                    # a block member: consume to its matching brace
                    d, m = 1, k + 1
                    while m < n and d:
                        d += body[m] == "{"
                        d -= body[m] == "}"
                        m += 1
                    head = body[j:k]
                    kind = ("func" if re.match(
                        r"\s*(function|constructor|modifier|receive|fallback)\b",
                        head) else "other")
                    out.append((kind, body[i:m]))
                    i = m
                    break
                depth += 1
            elif c == "}":
                depth -= 1
            elif c == ";" and depth == 0:
                out.append(("decl", body[i:k + 1]))
                i = k + 1
                break
            k += 1
        else:
            out.append(("other", body[i:]))
            break
    return out


def _decl_name(text: str):
    t = _strip_comment(text).strip().rstrip(";")
    # strip an initializer, but not the `=>` inside a mapping type
    t = re.sub(r"=(?!>).*$", "", t).strip()
    if re.match(r"^(using|event|error|pragma|import)\b", t):
        return None
    m = re.search(r"([A-Za-z_]\w*)\s*$", t)
    return m.group(1) if m else None


def _func_parts(text: str):
    """(head, body lines, tail) of a function member."""
    k = text.index("{")
    end = text.rindex("}")
    return text[:k + 1], text[k + 1:end].split("\n"), text[end:]


def slice_harness(inner: str, check_fn: str,
                  always_keep: frozenset = frozenset()) -> str:
    """The harness `inner`, reduced to what `check_fn` can observe."""
    parts = _split_contract(inner)
    if parts is None:
        return inner
    before, header, body, after = parts
    members = _members(body)

    state = set()
    for kind, text in members:
        if kind == "decl":
            nm = _decl_name(text)
            if nm:
                state.add(nm)
    if not state:
        return inner

    # the criterion: storage the obligation reads, plus the harness's ghosts
    R = (_idents(check_fn) & state) | (set(always_keep) & state)
    R |= {s for s in state if s in ("inFlight", "exposed", "snapPre")}

    funcs = [(i, _func_parts(t)) for i, (k, t) in enumerate(members)
             if k == "func"]

    def local_names(head, lines):
        """Parameters and locals declared in one function. Inside it they
        shadow any state variable of the same name, so they must not be
        treated as storage -- which is how a local `amount` shadowing a state
        `amount` was taken for a write to irrelevant state and dropped."""
        names = set()
        m = re.search(r"\(([^)]*)\)", head)
        if m:
            for prm in m.group(1).split(","):
                toks = re.findall(r"[A-Za-z_]\w*", prm)
                if len(toks) >= 2:
                    names.add(toks[-1])
        for raw in lines:
            line = _strip_comment(raw).strip()
            if not line or "{" in line or "}" in line:
                continue
            kind, writes, _r = _classify(line)
            if kind == "local":
                names |= writes
        return names

    def analyse(lines, head=""):
        """For one body: (kept line flags, reads of kept lines)."""
        own = local_names(head, lines)
        state_here = state - own
        need_local = set()
        keep = [True] * len(lines)
        reads_kept = set()
        changed = True
        while changed:
            changed = False
            keep = [True] * len(lines)
            reads_kept = set()
            for idx, raw in enumerate(lines):
                line = _strip_comment(raw).strip()
                if not line:
                    continue
                if "{" in line or "}" in line or line.count(";") != 1:
                    # control structure, or more than one statement on the
                    # line: keep it, and everything it reads is needed
                    ids = _idents(line)
                    reads_kept |= ids
                    continue
                kind, writes, reads = _classify(line)
                if kind == "emit":
                    keep[idx] = False
                    continue
                if kind == "local":
                    if writes & need_local:
                        reads_kept |= reads
                    else:
                        keep[idx] = False
                    continue
                if kind == "assign":
                    # keep a write only if what it writes is needed: storage
                    # in the slice, or a local a kept statement reads
                    if (writes & state_here & R) or (writes & need_local):
                        reads_kept |= reads
                    else:
                        keep[idx] = False
                    continue
                if kind == "guard":
                    # Guards are always kept, and what they read joins the
                    # slice. Dropping one is sound -- it only admits more
                    # executions -- but on the traces it is exactly what
                    # manufactured false alarms: a reentrancy lock, a pause, a
                    # cap removed, and the solver walked through the gap the
                    # contract keeps shut. In this domain the guard is often
                    # the whole reason the contract is safe.
                    reads_kept |= reads
                    continue
                # a call, a return, anything unclassified: keep it whole
                reads_kept |= reads
            new_locals = (reads_kept - state_here)
            if not new_locals <= need_local:
                need_local |= new_locals
                changed = True
        return keep, reads_kept

    # fixpoint over the relevant storage set across every function
    while True:
        before_R = set(R)
        for _i, (_h, lines, _t) in funcs:
            _keep, reads = analyse(lines, _h)
            R |= reads & (state - local_names(_h, lines))
        if R == before_R:
            break

    # emit
    out_members = []
    kept_text = [check_fn]
    for i, (kind, text) in enumerate(members):
        if kind == "func":
            head, lines, tail = _func_parts(text)
            keep, _ = analyse(lines, head)
            body_out = "\n".join(l for l, k in zip(lines, keep) if k)
            new = head + body_out + tail
            out_members.append((kind, text[:text.index(head)] + new
                                if head in text else new))
            kept_text.append(new)
        else:
            out_members.append((kind, text))
    referenced = set()
    for t in kept_text:
        referenced |= _idents(t)

    final = []
    for kind, text in out_members:
        if kind == "decl":
            nm = _decl_name(text)
            if nm and nm in state and nm not in R and nm not in referenced:
                continue
        final.append(text)
    return before + header + "".join(final) + after


def slice_report(inner: str, check_fn: str) -> tuple:
    """(state vars before, after) -- for logging how much a slice removed."""
    def count(src):
        parts = _split_contract(src)
        if not parts:
            return 0
        return sum(1 for k, t in _members(parts[2])
                   if k == "decl" and _decl_name(t))
    return count(inner), count(slice_harness(inner, check_fn))
