"""
access.py - which public functions the re-entering contract cannot call.

The adversary in the model is the contract that receives a callback. Under the
assumption stated in the paper, privileged roles are trusted and are not that
contract: a function every caller but an owner, admin or listed role is turned
away from is outside what the adversary can invoke during the window. A
function guarded by `tx.origin == msg.sender` is likewise treated as closed to
a contract caller -- with the caveat that since EIP-7702 an externally owned
account can carry delegated code, so this second exclusion is weaker and is
reported separately.

A function is treated as gated when an unconditional guard -- a modifier's
check before `_;`, or a top-level `require` / `if (...) revert` in the body --
restricts the caller. A transaction that fails a top-level guard reverts
entirely, so where in the body the guard sits does not matter; a guard nested
inside a branch does not count, since the other branch stays open.

What restricts the caller:

  msg.sender == X, X == _msgSender(), and != in either direction
  role[msg.sender] used as a boolean (not `balances[msg.sender] >= x`)
  a call such as isOwner(msg.sender) or _checkOwner() whose own body is one of
  the above, resolved a few levels deep

A disjunction restricts only if every disjunct does -- `msg.sender == owner ||
block.timestamp > deadline` lets anyone in after the deadline -- while a
conjunction restricts if any conjunct does.

Modifiers that only set a flag (`inSwap = true; _; inSwap = false;`) or check
state that is not the caller (`require(!paused)`) are not access control and
are left alone here.
"""
from __future__ import annotations

import re

_CALLER = r"(?:msg\.sender|_msgSender\s*\(\s*\))"


def _block_end(src: str, open_idx: int) -> int:
    depth, i = 0, open_idx
    while i < len(src):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(src)


def _modifiers(src: str) -> dict:
    """name -> (param names, text before `_;`)."""
    out = {}
    for m in re.finditer(r"\bmodifier\s+([A-Za-z_]\w*)\s*(\([^)]*\))?\s*"
                         r"(?:virtual\s*|override\s*(?:\([^)]*\))?\s*)*\{", src):
        end = _block_end(src, m.end() - 1)
        body = src[m.end():end]
        pre = body.split("_;")[0]
        params = [p.strip().split()[-1] for p in (m.group(2) or "()")[1:-1].split(",")
                  if p.strip()]
        out[m.group(1)] = (params, pre)
    return out


def _functions(src: str) -> dict:
    """name -> (parameter names, header tail, body) for the last definition."""
    out = {}
    for m in re.finditer(r"\bfunction\s+([A-Za-z_]\w*)\s*\(([^)]*)\)([^{;]*)\{", src):
        end = _block_end(src, m.end() - 1)
        params = [p.strip().split()[-1] for p in m.group(2).split(",")
                  if p.strip() and len(p.strip().split()) >= 2]
        out[m.group(1)] = (params, m.group(3), src[m.end():end])
    return out


def _top_level_guards(body: str) -> list:
    """Conditions of top-level require(...) and if (...) revert, as the
    condition under which execution continues."""
    conds = []
    depth, i, n = 0, 0, len(body)
    while i < n:
        c = body[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        elif depth == 0:
            m = re.match(r"\brequire\s*\(", body[i:])
            if m and (i == 0 or not (body[i - 1].isalnum() or body[i - 1] == "_")):
                j = i + m.end() - 1
                k = _paren_end(body, j)
                conds.append(_first_arg(body[j + 1:k]))
                i = k
            else:
                m = re.match(r"\bif\s*\(", body[i:])
                if m and (i == 0 or not (body[i - 1].isalnum() or body[i - 1] == "_")):
                    j = i + m.end() - 1
                    k = _paren_end(body, j)
                    rest = body[k + 1:k + 60].lstrip()
                    if rest.startswith("revert") or re.match(r"\{\s*revert", rest):
                        conds.append("!(" + body[j + 1:k] + ")")
                    i = k
        i += 1
    return conds


def _paren_end(text: str, open_idx: int) -> int:
    depth, i = 0, open_idx
    while i < len(text):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(text) - 1


def _first_arg(args: str) -> str:
    depth = 0
    for i, c in enumerate(args):
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif c == "," and depth == 0:
            return args[:i]
    return args


def _split_top(expr: str, op: str) -> list:
    parts, depth, last, i = [], 0, 0, 0
    while i < len(expr):
        c = expr[i]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0 and expr.startswith(op, i):
            parts.append(expr[last:i])
            last = i + len(op)
            i += len(op)
            continue
        i += 1
    parts.append(expr[last:])
    return [p.strip() for p in parts]


def _strip_parens(e: str) -> str:
    e = e.strip()
    while e.startswith("(") and _paren_end(e, 0) == len(e) - 1:
        e = e[1:-1].strip()
    return e


def _classify(cond: str, fns: dict, depth: int = 0):
    """'access', 'eoa', or None for one condition."""
    cond = _strip_parens(cond)
    neg = False
    while cond.startswith("!") and not cond.startswith("!="):
        neg = not neg
        cond = _strip_parens(cond[1:])
    ors = _split_top(cond, "||")
    if len(ors) > 1:
        kinds = [_classify(p, fns, depth) for p in ors]
        if all(kinds):
            return "eoa" if all(k == "eoa" for k in kinds) else "access"
        return None
    ands = _split_top(cond, "&&")
    if len(ands) > 1:
        for p in ands:
            k = _classify(p, fns, depth)
            if k:
                return k
        return None
    c = cond
    if re.search(rf"tx\.origin\s*[!=]=\s*{_CALLER}|{_CALLER}\s*[!=]=\s*tx\.origin", c):
        return "eoa"
    if re.search(rf"{_CALLER}\s*[!=]=|[!=]=\s*{_CALLER}", c):
        return "access"
    # role[msg.sender] used as a boolean, or compared with true
    if re.fullmatch(rf"[A-Za-z_]\w*\s*\[\s*{_CALLER}\s*\](?:\s*==\s*true)?", c):
        return "access"
    # a call that passes the caller, or takes nothing, resolved into its body
    m = re.fullmatch(rf"([A-Za-z_]\w*)\s*\(\s*({_CALLER})?\s*\)", c)
    if m and depth < 4:
        return _classify_function(m.group(1), bool(m.group(2)), fns, depth + 1)
    return None


def _classify_function(name: str, passes_caller: bool, fns: dict, depth: int):
    if name not in fns:
        # OpenZeppelin's role helpers by name, when the library is not inlined
        if name in ("hasRole", "_checkRole", "_checkOwner", "isOwner"):
            return "access"
        return None
    params, _tail, body = fns[name]
    b = " ".join(body.split())
    m = re.fullmatch(r"return\s+(.+?)\s*;", b)
    if m:
        expr = m.group(1)
        if passes_caller and params:
            expr = re.sub(rf"\b{re.escape(params[0])}\b", "msg.sender", expr)
        return _classify(expr, fns, depth)
    for cnd in _top_level_guards(body):
        k = _classify(cnd, fns, depth)
        if k:
            return k
    return None


def gate(src: str, fn_name: str, fns=None, mods=None):
    """(kind, evidence) if fn_name is closed to a contract caller, else None."""
    fns = fns if fns is not None else _functions(src)
    mods = mods if mods is not None else _modifiers(src)
    if fn_name not in fns:
        return None
    _params, tail, body = fns[fn_name]
    tail = re.sub(r"returns\s*\([^)]*\)", " ", tail)
    for m in re.finditer(r"\b([A-Za-z_]\w*)\s*(\([^)]*\))?", tail):
        name = m.group(1)
        if name in mods:
            for cnd in _top_level_guards(mods[name][1]):
                k = _classify(cnd, fns)
                if k:
                    return k, f"modifier {name}: {' '.join(cnd.split())[:70]}"
            for call in re.findall(r"\b([A-Za-z_]\w*)\s*\(\s*\)\s*;", mods[name][1]):
                k = _classify_function(call, False, fns, 1)
                if k:
                    return k, f"modifier {name} -> {call}()"
    for cnd in _top_level_guards(body):
        k = _classify(cnd, fns)
        if k:
            return k, f"require {' '.join(cnd.split())[:70]}"
    return None


def privileged_functions(src: str, names) -> dict:
    """{function: (kind, evidence)} for each name closed to a contract caller."""
    src = src.replace("\r\n", "\n")
    fns, mods = _functions(src), _modifiers(src)
    out = {}
    for n in names:
        g = gate(src, n, fns, mods)
        if g:
            out[n] = g
    return out
