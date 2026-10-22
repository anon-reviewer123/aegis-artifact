"""Discharge a single-step obligation with solc's BMC engine.

A phase or callback obligation is a Hoare triple over one call: from any state
where the assumption holds, the harness function keeps the assertion true. The
CHC encoding of the `Obligation` contract asks the solver for an invariant of
every state reachable over any number of transactions, which is the hard part
and is not needed for the triple. BMC checks each public function on its own,
starting from an arbitrary storage state.

This is sound for the triple only when the checked code has no loops and no
recursion, because BMC unrolls both to a bound. Starting from every state,
reachable or not, can only add counterexamples, so only a proof is taken from
BMC; a violation or an undecided run is left to the CHC path.
"""
import os
import re
import subprocess
import tempfile

ELIGIBLE = ("OBL_cb_", "OBL_pre", "OBL_post", "OBL_stable_implies_target")


def eligible(name: str) -> bool:
    return name.startswith(ELIGIBLE) and "_canary" not in name


def _block_end(text: str, open_brace: int) -> int:
    depth, i = 0, open_brace
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _functions(text: str) -> dict:
    out = {}
    for m in re.finditer(r"\bfunction\s+(\w+)\s*\([^)]*\)[^{;]*\{", text):
        end = _block_end(text, m.end() - 1)
        if end > 0:
            out[m.group(1)] = text[m.end():end]
    return out


def _has_loop(text: str) -> bool:
    code = re.sub(r"//[^\n]*|/\*.*?\*/", "", text, flags=re.S)
    return re.search(r"\b(for|while)\s*\(|\bdo\s*\{", code) is not None


def _has_recursion(text: str) -> bool:
    fns = _functions(text)
    calls = {f: {g for g in fns if re.search(rf"(?<![\.\w]){re.escape(g)}\s*\(", body)}
             for f, body in fns.items()}
    state = {}

    def visit(f):
        state[f] = 1
        for g in calls[f]:
            if state.get(g) == 1:
                return True
            if g not in state and visit(g):
                return True
        state[f] = 2
        return False

    return any(f not in state and visit(f) for f in fns)


def _reached_code_unbounded(harness: str, check_body: str) -> bool:
    """True if code check() can reach has a loop or recursion. Functions it
    cannot reach do not change its result, so a loop in an unrelated view (an
    NFT's tokensOfOwner, say) no longer keeps the obligation away from BMC.
    Every modifier body is counted, reached or not."""
    fns = _functions(harness)
    calls = {f: {g for g in fns if re.search(rf"(?<!\w){re.escape(g)}\s*\(", b)}
             for f, b in fns.items()}
    todo = [g for g in fns if re.search(rf"(?<!\w){re.escape(g)}\s*\(", check_body)]
    seen = set()
    while todo:
        f = todo.pop()
        if f not in seen:
            seen.add(f)
            todo.extend(calls[f] - seen)
    mods = "".join(harness[m.end():_block_end(harness, m.end() - 1)]
                   for m in re.finditer(r"\bmodifier\s+\w+[^{;]*\{", harness))
    if _has_loop("".join(fns[f] for f in seen) + mods):
        return True
    state = {}

    def visit(f):
        state[f] = 1
        for g in calls[f] & seen:
            if state.get(g) == 1 or (g not in state and visit(g)):
                return True
        state[f] = 2
        return False

    return any(f not in state and visit(f) for f in seen)


def to_one_step(source: str):
    """The obligation with its check() moved into the harness contract, or
    None when it does not have the plain `v = new H(...)` shape, or has a
    loop or recursion."""
    cut = source.find("\ncontract Obligation {")
    if cut < 0:
        return None
    inner, outer = source[:cut], source[cut:]
    m = re.search(r"\bfunction\s+check\s*\(([^)]*)\)\s*public\s*\{", outer)
    if not m:
        return None
    end = _block_end(outer, m.end() - 1)
    if end < 0:
        return None
    params, body = m.group(1), outer[m.end():end]
    # In check(), address(this) is the Obligation contract, which is the
    # caller every harness function sees as msg.sender. Moved inside the
    # harness and called internally, those functions see the transaction's
    # sender instead, so the same account is msg.sender there. Any other use
    # of `this` has no counterpart and keeps the obligation on CHC.
    body = re.sub(r"//[^\n]*|/\*.*?\*/", "", body, flags=re.S)
    body = re.sub(r"\baddress\s*\(\s*this\s*\)", "__AEGIS_CALLER__", body)
    if re.search(r"\bv\s*=|\bnew\s+\w|\bthis\b", body):
        return None
    hm = re.search(r"\bcontract\s+(\w+)\s*\{", inner)
    if not hm:
        return None
    h_open = hm.end() - 1
    h_close = _block_end(inner, h_open)
    if h_close < 0:
        return None
    harness = inner[h_open:h_close + 1]
    if _reached_code_unbounded(harness, body):
        return None
    public_vars = set(re.findall(
        r"^\s*[\w\[\]\s\(\)=>,.]*?\bpublic\s+(\w+)\s*(?:=[^;]*)?;", harness, re.M))

    def rewrite(mm):
        name, args = mm.group(1), mm.group(2).strip()
        if name in public_vars:
            if not args:
                return name
            return name + "".join(f"[{a.strip()}]" for a in args.split(","))
        return f"{name}({args})"

    # the contract's own address reaches check() as address(v); inside the
    # harness that is address(this). A placeholder keeps the getter rewrite
    # below, which takes arguments without parentheses, working on it.
    body = re.sub(r"\baddress\s*\(\s*v\s*\)", "__AEGIS_SELF__", body)
    local = re.sub(r"\bv\.(\w+)\(([^()]*)\)", rewrite, body)
    if re.search(r"\bv\.|\bv\b", local):
        return None
    local = local.replace("__AEGIS_SELF__", "address(this)")
    local = local.replace("__AEGIS_CALLER__", "msg.sender")
    # The Obligation contract that called the harness is never the harness
    # itself; without this BMC let the token be its own caller and found
    # "violations" in which it transferred its own balance.
    check = (f"\n    function __aegis_check({params}) public {{\n"
             f"        require(msg.sender != address(this));{local}}}\n")
    return inner[:h_close] + check + inner[h_close:]


def bmc_proves(source: str, timeout_ms: int, solc_bin: str = "solc") -> tuple:
    """(proved?, solver output), from the first solc whose BMC engine answers.

    A solc-select artifact can print nothing at all for a BMC run (on this
    machine 0.8.30 did, while the solc on PATH answered), and an empty output
    is not a proof. The binary from AEGIS_BMC_SOLC comes first, then the one on
    PATH, then the one matched to the pragma."""
    tried, out = [], ""
    for b in (os.environ.get("AEGIS_BMC_SOLC", ""), "solc", solc_bin):
        if not b or b in tried:
            continue
        tried.append(b)
        proved, out = _bmc_once(source, timeout_ms, b)
        if "BMC" in out or "Error" in out or "timeout" in out:
            return proved, f"[{b}]\n{out}"
    return False, out


def bmc_witness(source: str, timeout_ms: int, solc_bin: str = "solc") -> tuple:
    """(found?, solver output): BMC reaches the canary's assert(false).

    That shows the callback can run to completion from some state satisfying
    the assumption, the state space the one-step proofs quantify over. It does
    not show the state is reachable from deployment, which only the CHC
    canary does, so the verdict records which kind of evidence was used. Only
    a source whose single assertion is the canary's counts."""
    code = re.sub(r"//[^\n]*|/\*.*?\*/", "", source, flags=re.S)
    if len(re.findall(r"\bassert\s*\(", code)) != 1 or not re.search(
            r"\bassert\s*\(\s*false\s*\)", code):
        return False, "not a single-assert canary"
    tried, out = [], ""
    for b in (os.environ.get("AEGIS_BMC_SOLC", ""), "solc", solc_bin):
        if not b or b in tried:
            continue
        tried.append(b)
        _p, out = _bmc_once(source, timeout_ms, b)
        if "BMC" in out or "Error" in out or "timeout" in out:
            found = ("Assertion violation happens here" in out
                     and "Error:" not in out)
            return found, f"[{b}]\n{out}"
    return False, out


def _bmc_once(source: str, timeout_ms: int, solc_bin: str) -> tuple:
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "OneStep.sol")
        with open(path, "w") as fh:
            fh.write(source)
        cmd = [solc_bin, "--model-checker-engine", "bmc",
               "--model-checker-targets", "assert",
               "--model-checker-solvers", "z3",
               "--model-checker-timeout", str(timeout_ms),
               "--model-checker-show-unproved",
               "--model-checker-show-proved-safe", path]
        from .backend import _run_killing_group
        try:
            proc = _run_killing_group(cmd, timeout=timeout_ms / 1000.0 + 5)
        except subprocess.TimeoutExpired:
            return False, "BMC wall-clock timeout"
        except OSError as exc:
            return False, f"cannot run {solc_bin}: {exc}"
    out = (proc.stdout or "") + "\n" + (proc.stderr or "")
    negative = ("Error:" in out
                or "Assertion violation happens" in out
                or "might happen" in out
                or "could not be proved" in out
                or "not yet support" in out
                or "not available" in out)
    asserts = len(re.findall(r"\bassert\s*\(", re.sub(r"//[^\n]*", "", source)))
    safe = len(re.findall(r"BMC: Assertion violation check is safe", out))
    return (not negative and asserts > 0 and safe >= asserts), out


def internal_canary(source: str):
    """A canary whose check() already sits inside the harness, as the
    read-only arm builds them, ready for a BMC witness; None when check() can
    reach a loop or recursion, or when this is not that shape."""
    if "contract Obligation" in source:
        return None
    m = re.search(r"\bfunction\s+check\s*\([^)]*\)\s*public\s*\{", source)
    if not m:
        return None
    body = source[m.end():_block_end(source, m.end() - 1)]
    if _reached_code_unbounded(source, body):
        return None
    return source
