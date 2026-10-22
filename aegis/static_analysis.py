"""
static_analysis.py - Modules 1 & 2 of Aegis.

Module 1 (Front-End): parse the contract, list functions, storage vars,
                       visibility, and external-call sites.
Module 2 (Exposure Analyzer): classify which call sites are callback-capable
                       and compute write-before-call / write-after-call sets.

Design note for the paper's soundness story: the SET OF CALLBACK-REACHABLE
FUNCTIONS used downstream must be a SOUND OVER-APPROXIMATION. This module
therefore computes a conservative closure = {all public/external functions
that touch any storage variable exposed at the call site}. The LLM may
*propose* a smaller closure, but the validator (validator.py) checks the
LLM's closure against THIS conservative set and rejects/expands if the LLM
dropped a reachable function. That is the hook that keeps the LLM out of the
trusted base.
"""
from __future__ import annotations
from dataclasses import dataclass, field
import json
import re
import shutil
import subprocess
import tempfile
import os


@dataclass
class FunctionInfo:
    name: str
    visibility: str                       # public/external/internal/private
    mutability: str = "nonpayable"        # view/pure/payable/nonpayable
    param_types: list = field(default_factory=list)  # solidity param types
    # Declared return types, in order. The read-only obligation compares the
    # value a view returns at three points, so it has to declare a local of the
    # view's own type; assuming uint256 makes any bool- or address-returning
    # view uncompilable.
    return_types: list = field(default_factory=list)
    reads: set[str] = field(default_factory=set)
    writes: set[str] = field(default_factory=set)
    external_calls: list[str] = field(default_factory=list)
    # storage written before / after the (first) external call
    write_before_call: set[str] = field(default_factory=set)
    write_after_call: set[str] = field(default_factory=set)
    # Names of same-contract functions this one calls. Needed to close read and
    # write sets over internal helpers: a function that writes nothing itself
    # but calls a helper that does still writes that storage.
    internal_calls: set[str] = field(default_factory=set)
    # True when the body contains a construct whose storage effect cannot be
    # bounded statically (delegatecall, inline assembly, or a low-level call
    # whose target is not resolvable). Such a function can neither be admitted
    # to a read-only footprint argument nor be assumed callback-free.
    has_unresolved_call: bool = False
    # True when the body can write storage the analysis cannot see:
    # delegatecall runs foreign code on this contract's storage and balance,
    # and inline assembly may sstore. Memory-only assembly does not count.
    has_unbounded_write: bool = False
    # Boolean storage variables this function requires to be FALSE before it
    # will run, whether the check sits in its body or in an attached modifier.
    # A function guarded on a flag the window holds cannot execute during that
    # window.
    guard_flags: set[str] = field(default_factory=set)


@dataclass
class ExposureSite:
    function: str
    call: str
    callback_capable: bool
    reason: str
    exposed_storage: set[str] = field(default_factory=set)
    write_before_call: set[str] = field(default_factory=set)
    write_after_call: set[str] = field(default_factory=set)
    # Ordinal of this call within its function, so s = (f, l) is a stable
    # identity even when one function makes the same kind of call twice.
    index: int = 0
    # Booleans this site sets true before yielding control and clears after, so
    # they hold for the whole window. A closure member guarded on one of them
    # cannot run while the window is open.
    window_flags: set[str] = field(default_factory=set)


@dataclass
class LoopSite:
    """An external call that occurs INSIDE a loop body -- the pattern RAVEN
    excludes (its topological ordering breaks on in-loop call-sites). Aegis
    verifies these via an inductive loop-step obligation over an arbitrary
    iteration count."""
    function: str
    call: str
    loop_body_writes: list = field(default_factory=list)   # state written per iteration
    loop_body_reads: list = field(default_factory=list)    # state read per iteration
    writes_before_call: list = field(default_factory=list) # written BEFORE the in-loop call
    writes_after_call: list = field(default_factory=list)  # written AFTER the in-loop call
    propagates_failure: bool = False  # loop reverts on call failure (require(ok)) -> no progress


@dataclass
class ContractFacts:
    contract: str
    storage_vars: list[str]
    functions: dict[str, FunctionInfo]
    exposure_sites: list[ExposureSite]
    loop_sites: list = field(default_factory=list)
    # Declared Solidity type of each storage variable, taken verbatim from the
    # solc AST (the `typeString` of each VariableDeclaration), e.g.
    #   "balanceOf" -> "mapping(address => uint256)"
    #   "hook"      -> "address"
    #   "totalSupply" -> "uint256"
    # Empty when the regex analyzer produced the facts (solc unavailable); in
    # that case downstream consumers fall back to their prior heuristics, so
    # this field is purely additive and changes no existing behavior.
    var_types: dict[str, str] = field(default_factory=dict)
    # Filesystem path the facts were derived from. Consumers that need the
    # original source (the ghost-direction hint, the loop body extractor) read
    # it from here instead of guessing a directory.
    path: str = ""
    # Public functions a contract caller cannot invoke, with why:
    # {name: (kind, evidence)}, kind "access" or "eoa". Filled by analyze()
    # from aegis/access.py; the closures below leave these out. See that module
    # for the trust assumption this encodes.
    privileged: dict = field(default_factory=dict)

    # ---- transitive read/write sets over the internal call graph ----------
    # W*(f) = Write(f) u U_{k in Calls(f)} W*(k), and likewise for reads. Both
    # are memoised per ContractFacts and terminate on recursion via `seen`.

    def _transitive(self, fn_name: str, attr: str, seen=None) -> set[str]:
        seen = seen if seen is not None else set()
        if fn_name in seen:
            return set()
        seen.add(fn_name)
        info = self.functions.get(fn_name)
        if info is None:
            return set()
        out = set(getattr(info, attr))
        for callee in info.internal_calls:
            out |= self._transitive(callee, attr, seen)
        return out

    def transitive_writes(self, fn_name: str) -> set[str]:
        return self._transitive(fn_name, "writes")

    def transitive_reads(self, fn_name: str) -> set[str]:
        return self._transitive(fn_name, "reads")

    def reaches_unresolved(self, fn_name: str, seen=None) -> bool:
        """True if fn_name, or anything it calls internally, contains a
        construct whose storage effect cannot be bounded."""
        seen = seen if seen is not None else set()
        if fn_name in seen:
            return False
        seen.add(fn_name)
        info = self.functions.get(fn_name)
        if info is None:
            return False
        if info.has_unresolved_call:
            return True
        return any(self.reaches_unresolved(c, seen) for c in info.internal_calls)

    def reaches_unbounded_write(self, fn_name: str, seen=None) -> bool:
        """True if fn_name, or anything it calls internally, may write storage
        the recorded write sets do not show."""
        seen = seen if seen is not None else set()
        if fn_name in seen:
            return False
        seen.add(fn_name)
        info = self.functions.get(fn_name)
        if info is None:
            return False
        if info.has_unbounded_write:
            return True
        return any(self.reaches_unbounded_write(c, seen)
                   for c in info.internal_calls)

    def site_key(self, site: ExposureSite) -> tuple:
        """Identity of an exposure site: s = (f, l)."""
        return (site.function, site.call, getattr(site, "index", 0))

    def conservative_closure(self, site: ExposureSite) -> set[str]:
        """The PRESERVATION closure: public/external functions that may WRITE
        exposed storage during the window, directly or through an internal
        helper. These are the functions an exposure invariant must survive, and
        the set the validator checks an LLM-proposed closure against.

        This is the write partition of the full closure below. A view that only
        reads exposed state cannot break the exposure invariant, and emitting an
        OBL_cb_<view> for it produces a malformed value-returning obligation, so
        it is handled by the read-only arm instead."""
        result = set()
        for fn in self.functions.values():
            if fn.visibility not in ("public", "external"):
                continue
            if fn.name in self.privileged:
                continue
            if (self.transitive_writes(fn.name) & site.exposed_storage
                    or self.reaches_unbounded_write(fn.name)):
                result.add(fn.name)
        return result

    def observation_closure(self, site: ExposureSite) -> set[str]:
        """The OBSERVATION partition: public/external functions that read
        exposed storage without writing it. These are what an adversary can use
        to observe the window, and the members the read-only footprint premise
        of Lemma 1 quantifies over."""
        writers = self.conservative_closure(site)
        result = set()
        for fn in self.functions.values():
            if fn.visibility not in ("public", "external"):
                continue
            if fn.name in writers or fn.name in self.privileged:
                continue
            if self.transitive_reads(fn.name) & site.exposed_storage:
                result.add(fn.name)
        return result

    def full_closure(self, site: ExposureSite) -> set[str]:
        """Closure(s) = {g in F_pub | (Read*(g) u Write*(g)) n Exposed(s) != {}}.

        The union of the preservation and observation partitions. This is the
        set the modelled adversary may invoke during the window; the partitions
        differ only in which obligation form discharges each member."""
        return self.conservative_closure(site) | self.observation_closure(site)


# Patterns that indicate a callback-capable external call.
#
# We classify three levels of specificity. Specific named hooks are recognized
# by their ERC-standard names; low-level transfers (.call / .send / .transfer)
# are recognized syntactically; finally a *general* pattern detects any call to
# a function whose name follows a callback naming convention
# (on...Received, on...Hook, notify..., onFlashLoan, executeOperation, fallback,
# receive) regardless of the interface used to type the receiver. The general
# pattern is what lets the analyzer recognize unknown adversary interfaces
# the way IReceiver(receiver).onTokensReceived(...) is recognized without
# being hard-coded.
_CALLBACK_PATTERNS = [
    # specific well-known ERC-standard hooks
    (r"\.onAssetReceived\s*\(", "ERC777-style asset hook can re-enter"),
    (r"\.tokensReceived\s*\(", "ERC777 tokensReceived hook can re-enter"),
    (r"\.onTokensReceived\s*\(", "token receiver hook can re-enter"),
    (r"\.onERC1155Received\s*\(", "ERC1155 receiver hook can re-enter"),
    (r"\.onERC1155BatchReceived\s*\(", "ERC1155 batch receiver hook can re-enter"),
    (r"\.onERC721Received\s*\(", "ERC721 safeTransfer callback can re-enter"),
    # low-level transfers
    (r"\.call\s*\{", "low-level call can re-enter"),
    (r"\.call\s*\(", "low-level call can re-enter"),
    (r"\.send\s*\(", "send may trigger fallback"),
    (r"\.transfer\s*\(", "transfer may trigger fallback"),
    # flash-loan callbacks
    (r"\.executeOperation\s*\(", "flash-loan callback can re-enter"),
    (r"executeOperation\s*\(", "flash-loan callback can re-enter"),
    (r"\.onFlashLoan\s*\(", "ERC-3156 flash-loan callback can re-enter"),
    # GENERAL conventions: any method named on...Received / on...Hook / notify...
    # called on an externally-controlled address. This is what makes detection
    # contract-agnostic: an unknown adversary interface whose hook follows the
    # convention is still recognized as callback-capable.
    (r"\.onCallback\s*\(", "generic external callback can re-enter"),
    (r"\.onReadOnly\w*\s*\(", "read-only reentrancy callback can re-enter"),
    (r"\.on[A-Z]\w*Received\s*\(", "generic 'on*Received' callback can re-enter"),
    (r"\.on[A-Z]\w*\s*\(", "generic 'on*' callback can re-enter"),
    (r"\.on[A-Z]\w*Hook\s*\(", "generic 'on*Hook' callback can re-enter"),
    (r"\.notify[A-Z]\w*\s*\(", "notify-style callback can re-enter"),
]


def _solc_available() -> bool:
    return shutil.which("solc") is not None


def _try_solc_ast(sol_path: str) -> dict | None:
    """Return solc compact AST JSON, or None if solc unavailable/failed."""
    if not _solc_available():
        return None
    try:
        out = subprocess.run(
            ["solc", "--ast-compact-json", sol_path],
            capture_output=True, text=True, timeout=60,
        )
        # solc prints a header line then JSON per source; extract the JSON blob.
        text = out.stdout
        start = text.find("{")
        if start == -1:
            return None
        return json.loads(text[start:])
    except Exception:
        return None


# Records which analyzer produced the most recent facts. The pipeline reports
# this; a SOUNDNESS claim is only valid when this is "ast".
LAST_ANALYZER = "none"



def _rank_exposure_sites(facts):
    """Order exposure sites so the pipeline's facts.exposure_sites[0] is the one
    most worth verifying: a genuine exposed window (numeric storage written
    AFTER the external call) ranks above a windowless site (e.g. a bare
    .transfer with nothing after it). Among windowed sites, prefer those with
    writes on BOTH sides of the call, then the larger exposed set. Deterministic
    and stable so repeated runs pick the same site."""
    def _num(v):
        t = (facts.var_types.get(v, "uint256") or "uint256") if getattr(
            facts, "var_types", None) else "uint256"
        return t.startswith("uint") or t.startswith("int")

    def key(s):
        after = [v for v in s.write_after_call if _num(v)]
        before = [v for v in s.write_before_call if _num(v)]
        has_after = bool(after)
        both_sides = bool(after) and bool(before)
        window = len(set(after) | set(before))
        return (has_after, both_sides, window, s.function)

    facts.exposure_sites.sort(key=key, reverse=True)
    return facts


# Whether a `tx.origin == msg.sender` gate closes a function to the adversary.
# True reproduces the usual reading. Since EIP-7702 an externally owned account
# can carry delegated code and still pass that check while receiving callbacks,
# so a run can set this False to keep such functions in the closure.
TRUST_EOA_GATES = True


def _mark_privileged(facts: ContractFacts) -> ContractFacts:
    from . import access
    try:
        src = open(facts.path, errors="ignore").read()
    except Exception:
        return facts
    public = [f.name for f in facts.functions.values()
              if f.visibility in ("public", "external")]
    found = access.privileged_functions(src, public)
    facts.privileged = {n: g for n, g in found.items()
                        if g[0] == "access" or TRUST_EOA_GATES}
    return facts


def analyze(sol_path: str) -> ContractFacts:
    """Top-level entry: prefer the real solc-AST analyzer (sound), fall back to
    the regex analyzer (best-effort, for environments without a working solc)."""
    global LAST_ANALYZER
    # Import here to avoid a circular import at module load.
    from . import ast_analysis
    try:
        facts = ast_analysis.analyze_ast(sol_path)
        if facts is not None:
            LAST_ANALYZER = "ast"
            facts.path = sol_path
            return _rank_exposure_sites(_mark_privileged(facts))
    except Exception:
        pass  # fall through to regex on any AST surprise
    LAST_ANALYZER = "regex"
    facts = _analyze_from_regex(sol_path)
    if not facts.path:
        facts.path = sol_path
    return _mark_privileged(facts)


# --------------------------------------------------------------------------
# Regex fallback (works with NO solc installed). Good enough for the vault
# class of contracts; the AST path is the production route.
# --------------------------------------------------------------------------
def _analyze_from_regex(sol_path: str) -> ContractFacts:
    src = open(sol_path).read()
    # strip BOTH block and line comments to avoid false hits. A doc comment like
    # `/* This contract manages ... */` would otherwise make the contract-name
    # regex match `manages` (the lottery mis-selection bug).
    src_nc = re.sub(r"/\*.*?\*/", "", src, flags=re.DOTALL)
    src_nc = re.sub(r"//[^\n]*", "", src_nc)

    # Select the MAIN contract, not merely the first `contract X` match. On
    # flattened multi-contract files the first match is usually a base/library
    # (or a fragment), which is the `OwnableH`/`manages` mis-selection bug. We
    # find every top-level `contract X { ... }` span (brace-balanced) and pick
    # the one whose body defines the most functions -- the contract that carries
    # the actual logic and the exposure site.
    def _pick_main_contract(text: str) -> str:
        # Prefer the contract that performs an external call: that is where the
        # exposure site lives. Ranking by function count alone selects the
        # largest base library on flattened sources, which binds storage from
        # one contract while the site function belongs to another.
        call_re = re.compile(r"\.call\s*[\({]|\.call\s*\.\s*value\s*\(|"
                             r"\.on[A-Z]\w*\s*\(|\.tokensReceived\s*\(|"
                             r"\.executeOperation\s*\(|\.onFlashLoan\s*\(")
        best_name, best_key = None, (-1, -1)
        for cm in re.finditer(r"\bcontract\s+(\w+)[^{]*\{", text):
            nm = cm.group(1)
            body = _extract_body(text, cm.end() - 1)
            nfns = len(re.findall(r"\bfunction\s+\w+\s*\(", body))
            key = (1 if call_re.search(body) else 0, nfns)
            if key > best_key:
                best_name, best_key = nm, key
        return best_name
    contract = _pick_main_contract(src_nc) or os.path.basename(sol_path)

    # storage vars: top-level state declarations inside the contract body.
    #
    # Declarations are looked for in the source with every function body
    # removed. Scanning the whole file instead conflates locals with state, and
    # requiring the declaration to end at the name drops every variable that
    # carries an initializer -- `uint256 public reserve = 1000;` -- which is how
    # most deployed contracts declare state.
    def _strip_function_bodies(text: str) -> str:
        out, i = [], 0
        for fm in re.finditer(r"\bfunction\s+\w+\s*\([^)]*\)[^{;]*\{", text):
            if fm.start() < i:
                continue
            body = _extract_body(text, fm.end() - 1)
            out.append(text[i:fm.end()])
            i = fm.end() + len(body)
        out.append(text[i:])
        return "".join(out)

    decl_src = _strip_function_bodies(src_nc)
    storage_vars: list[str] = []
    # mappings
    for m in re.finditer(r"mapping\s*\([^;]*?\)\s+(?:public\s+|private\s+|internal\s+)?(\w+)\s*(?:=[^;]*)?;", decl_src):
        storage_vars.append(m.group(1))
    # scalar state vars (uint/bool/address ...), with or without an initializer
    for m in re.finditer(
            r"\b(?:uint\d*|int\d*|bool|address(?:\s+payable)?|bytes\d*|string)\s+"
            r"(?:(?:public|private|internal|constant|immutable)\s+)*"
            r"([A-Za-z_][\w,\s]*?)\s*(?:=[^;]*)?;", decl_src):
        names = m.group(1)
        # avoid local declarations: keep only ones that appear before first function? simple heuristic below
        for nm in names.split(","):
            nm = nm.strip()
            if nm and nm.isidentifier() and nm not in storage_vars:
                storage_vars.append(nm)

    # crude pruning: keep only vars referenced as bare storage (drop obvious locals)
    storage_vars = [v for v in storage_vars if re.search(rf"\b{re.escape(v)}\b", src_nc)]

    functions: dict[str, FunctionInfo] = {}
    exposure_sites: list[ExposureSite] = []

    # capture each function body
    #
    # The header tail is matched as "anything up to the opening brace" rather
    # than as a run of word characters. The narrower form could not match a
    # `returns (...)` clause, so every function with a return type -- which is
    # every view -- was invisible to this analyzer and the read-only arm had
    # nothing to work with whenever solc's AST was unavailable.
    for fm in re.finditer(
        r"function\s+(\w+)\s*\(([^)]*)\)([^{;]*)\{",
        src_nc,
    ):
        name = fm.group(1)
        params = fm.group(2)
        header_mods = fm.group(3)
        vis = "public"
        for v in ("external", "public", "internal", "private"):
            if re.search(rf"\b{v}\b", header_mods):
                vis = v
                break
        mut = "nonpayable"
        for m_ in ("view", "pure", "payable"):
            if re.search(rf"\b{m_}\b", header_mods.split("returns")[0]):
                mut = m_
                break
        ptypes = []
        for prm in params.split(","):
            prm = " ".join(prm.split())
            if prm:
                ptypes.append(prm.split()[0])
        rtypes = []
        rm = re.search(r"returns\s*\(([^)]*)\)", header_mods)
        if rm:
            for prm in rm.group(1).split(","):
                prm = " ".join(prm.split())
                if prm:
                    rtypes.append(prm.split()[0])
        # extract balanced body
        body = _extract_body(src_nc, fm.end() - 1)
        info = FunctionInfo(name=name, visibility=vis, mutability=mut,
                            param_types=ptypes, return_types=rtypes)

        # reads/writes over storage vars.
        #
        # The assignment pattern must not fire on a comparison: a bare `=` that
        # is part of `==`, `>=`, `<=` or `!=` is not a write. Without the
        # guards a `return reserve == supply;` inside a view marks the view as
        # a writer, which puts it in the preservation closure and blocks the
        # read-only arm for the whole contract.
        _ASSIGN = r"(?<![=!<>+\-*/])(?:=(?!=)|\+=|-=|\*=|/=)"
        for v in storage_vars:
            if re.search(rf"\b{re.escape(v)}\b\s*(\[[^\]]*\])?\s*{_ASSIGN}", body):
                info.writes.add(v)
            if re.search(rf"\b{re.escape(v)}\b", body):
                info.reads.add(v)
        # A view or pure function cannot write storage, whatever the text looks
        # like. This is a language guarantee, so it is safe to enforce here.
        if mut in ("view", "pure"):
            info.writes = set()

        # external calls + first-call split
        # Every callback-capable call in the body, in source order. One site
        # per call, not one per function.
        call_hits = []
        for pat, _reason in _CALLBACK_PATTERNS:
            for cm in re.finditer(pat, body):
                token = body[cm.start():cm.start() + 40].split("(")[0].strip()
                call_hits.append((cm.start(), token, _reason))
        call_hits.sort()
        # drop overlapping matches from different patterns hitting one call
        deduped = []
        for pos, token, rsn in call_hits:
            if deduped and pos - deduped[-1][0] < 4:
                continue
            deduped.append((pos, token, rsn))
        call_hits = deduped
        for _pos, token, _rsn in call_hits:
            info.external_calls.append(token)
        first_call_pos = call_hits[0][0] if call_hits else None

        # same-contract calls, and constructs whose storage effect is unbounded
        info.internal_calls = {c for c in re.findall(r"\b(\w+)\s*\(", body)}
        if re.search(r"\.delegatecall\s*\(|\bassembly\s*\{", body):
            info.has_unresolved_call = True
        if re.search(r"\.delegatecall\s*\(", body) or (
                re.search(r"\bassembly\s*\{", body)
                and re.search(r"\b(sstore|delegatecall|callcode)\s*\(", body)):
            info.has_unbounded_write = True

        # Re-entrancy guards: a require that the function will only run while
        # some boolean is false. Both spellings appear in practice.
        for gm in re.finditer(r"require\s*\(\s*!\s*([A-Za-z_]\w*)", body):
            info.guard_flags.add(gm.group(1))
        for gm in re.finditer(
                r"require\s*\(\s*([A-Za-z_]\w*)\s*==\s*false\b", body):
            info.guard_flags.add(gm.group(1))

        for k, (pos, call_token, reason) in enumerate(call_hits):
            nxt = call_hits[k + 1][0] if k + 1 < len(call_hits) else len(body)
            before = body[:pos]
            after = body[pos:nxt]
            wbc, wac = set(), set()
            for v in storage_vars:
                pat_v = rf"\b{re.escape(v)}\b\s*(\[[^\]]*\])?\s*{_ASSIGN}"
                if re.search(pat_v, before):
                    wbc.add(v)
                if re.search(pat_v, after):
                    wac.add(v)
            if k == 0:
                info.write_before_call = set(wbc)
                info.write_after_call = set(wac)
            exposed = wbc | wac | (info.reads & info.writes)
            set_true = {m.group(1) for m in re.finditer(
                r"([A-Za-z_]\w*)\s*=\s*true\b", before)}
            set_false = {m.group(1) for m in re.finditer(
                r"([A-Za-z_]\w*)\s*=\s*false\b", after)}
            exposure_sites.append(ExposureSite(
                function=name,
                call=call_token,
                callback_capable=True,
                reason=reason,
                exposed_storage=set(exposed),
                write_before_call=set(wbc),
                write_after_call=set(wac),
                index=k,
                window_flags=set_true & set_false & set(storage_vars),
            ))

        functions[name] = info

    # The regex pass collected every callee-looking token; keep only the ones
    # that name a function of this contract.
    for info in functions.values():
        info.internal_calls &= set(functions)
        info.internal_calls.discard(info.name)

    return _rank_exposure_sites(
        ContractFacts(contract, storage_vars, functions, exposure_sites,
                      path=sol_path))


def _extract_body(src: str, brace_open_idx: int) -> str:
    depth = 0
    i = brace_open_idx
    n = len(src)
    while i < n:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[brace_open_idx + 1:i]
        i += 1
    return src[brace_open_idx + 1:]


def _analyze_from_ast(sol_path: str, ast: dict) -> ContractFacts:
    # A full AST walker is straightforward but verbose; for the prototype we
    # reuse the regex extractor (which is sound enough for the vault class)
    # and keep this hook so a production AST walk can replace it later.
    return _analyze_from_regex(sol_path)


if __name__ == "__main__":
    import sys
    facts = analyze(sys.argv[1])
    print("contract:", facts.contract)
    print("storage:", facts.storage_vars)
    for f in facts.functions.values():
        print(f"  fn {f.name} [{f.visibility}] writes={sorted(f.writes)} "
              f"ext_calls={f.external_calls} wbc={sorted(f.write_before_call)} "
              f"wac={sorted(f.write_after_call)}")
    print("exposure sites:")
    for s in facts.exposure_sites:
        print(f"  {s.function} -> {s.call} | {s.reason}")
        print(f"     exposed_storage={sorted(s.exposed_storage)}")
        print(f"     conservative_closure={sorted(facts.conservative_closure(s))}")


def view_closure(facts, exposed_function):
    """Public/external view functions that read any storage exposed during the
    callback window of `exposed_function`. These are the read-only reentrancy
    surface: a consumer calling one mid-callback observes state under I_exp."""
    exposed = set()
    for site in facts.exposure_sites:
        if site.function == exposed_function:
            exposed |= set(site.write_before_call) | set(site.write_after_call)
    fi = facts.functions.get(exposed_function)
    if fi is not None:
        exposed |= (set(fi.reads) & set(fi.writes))
    out = []
    for name, info in facts.functions.items():
        if info.visibility not in ("public", "external"):
            continue
        if info.mutability not in ("view", "pure"):
            continue
        if set(info.reads) & exposed:
            out.append(name)
    return out
