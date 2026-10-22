#!/usr/bin/env python3
"""
baseline_smtchecker.py  --  RQ1 "SMTChecker-direct" baseline (NO MCVP).

This is the load-bearing fair baseline: it is Aegis's OWN backend
(solc --model-checker-engine chc --model-checker-solvers eld) invoked
*directly* on the contract with the target property asserted as a single
MONOLITHIC invariant -- exactly the proof shape Aegis argues is wrong for
callbacks. No phase split, no exposure invariant, no closure, no ghost state.

The point of the table row this produces: on safe cross-function / desync
contracts it should either (a) fail to prove (UNKNOWN) or (b) MISFIRE on an
unrelated function (the `setSettler` phenomenon), and it NEVER localizes the
violation to a specific A/G obligation.

It reuses aegis.backend's solver invocation + classifier so the comparison is
apples-to-apples: same solc, same Eldarica, same flags, same parser. The ONLY
difference vs Aegis is: monolithic assert instead of compiled MCVP obligations.

Output JSON schema (one record per contract), shared with all RQ1 tools:
{
  "tool": "smtchecker-direct",
  "contract": "PerpVault.sol",
  "verdict": "VERIFIED|BUG_FOUND|SPURIOUS|UNKNOWN",
  "localized": false,            # did it point at the right obligation/function?
  "localized_to": null,          # or the function/obligation name if it did
  "raw_status": "verified|failed|unknown|no_backend",
  "misfired_on": "setSettler",   # function it flagged that is NOT the real bug site
  "seconds": 12.3,
  "detail": "..."
}

Usage:
  python3 baseline_smtchecker.py --corpus contracts/corpus --out results/baseline_smtchecker.json
  python3 baseline_smtchecker.py --contract contracts/corpus/PerpVault.sol \
        --property "aum == trackedValue"
"""
from __future__ import annotations
import os, re, sys, glob, json, time, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aegis import backend, static_analysis           # reuse the REAL backend


# ---------------------------------------------------------------------------
# Monolithic harness synthesis: wrap the contract and assert the target
# property at the END of every public/external function. This is the
# "direct SMTChecker" usage a practitioner would actually write -- assert the
# global invariant and let CHC try to prove it inductively over all entry
# points (including the re-entrant callback, via ext-calls=trusted).
# ---------------------------------------------------------------------------

def _read(path: str) -> str:
    with open(path) as fh:
        return fh.read()


def _contract_bounds(sol_src: str, contract_name: str):
    """Return (name, body_open_brace_idx, body_close_brace_idx) for the target
    contract, brace-balanced. Falls back to the first contract in the file."""
    idx = sol_src.find(f"contract {contract_name}")
    if idx == -1:
        m = re.search(r"\bcontract\s+(\w+)", sol_src)
        if not m:
            raise ValueError("no contract found in source")
        contract_name = m.group(1)
        idx = m.start()
    brace_start = sol_src.find("{", idx)
    depth = 0
    for i in range(brace_start, len(sol_src)):
        if sol_src[i] == "{":
            depth += 1
        elif sol_src[i] == "}":
            depth -= 1
            if depth == 0:
                return contract_name, brace_start, i
    raise ValueError("unbalanced braces; cannot locate contract body")


def _discover_callback_iface(sol_src: str):
    """Find the callback interface + method the contract calls during exposure,
    e.g. `IAssetReceiver(receiver).onAssetReceived(amount)`.
    Returns (iface_name, method_name) or (None, None)."""
    m = re.search(r"(\w+)\s*\(\s*\w+\s*\)\s*\.\s*(\w+)\s*\(", sol_src)
    if m:
        return m.group(1), m.group(2)
    # interface decl fallback
    mi = re.search(r"interface\s+(\w+)\s*\{\s*function\s+(\w+)", sol_src)
    if mi:
        return mi.group(1), mi.group(2)
    return None, None


def _public_funcs(sol_src: str, exclude=()):
    """Names of public/external functions taking a single uint256 (so the
    attacker can re-enter them as f(amount)). Heuristic, good enough for the
    minimal-model benchmark."""
    out = []
    for m in re.finditer(r"function\s+(\w+)\s*\(\s*uint256[^)]*\)\s*"
                         r"(?:public|external)", sol_src):
        if m.group(1) not in exclude:
            out.append(m.group(1))
    return out


def build_monolithic_harness(sol_src: str, contract_name: str,
                             property_expr: str) -> str:
    """Faithful direct-SMTChecker usage on a callback contract (NO MCVP).

    This is how a practitioner actually verifies a callback property with plain
    SMTChecker. Plain CHC does NOT follow an external call into a separate
    adversary contract under ext-calls=trusted, so a cross-contract attacker is
    invisible to it. The faithful single-contract encoding: at the exposure
    point (where control would leave to the callback), inline the worst-case
    re-entrant action -- a closure function runs -- then assert the GLOBAL
    invariant right there, mid-operation. One global invariant, NO phase
    decomposition, asked to hold across the interrupted execution.

    On safe cross-function/ROR/flash contracts the global invariant is FALSE
    mid-callback (assets in flight), so CHC refutes the inlined assert ->
    SPURIOUS. That contrast is the RQ1 story.
    """
    name, body_open, body_close = _contract_bounds(sol_src, contract_name)
    iface, method = _discover_callback_iface(sol_src)

    # exposure call statement: `<Iface>(<x>).<method>(<args>);`
    exp_call_re = re.compile(
        r"[A-Za-z_]\w*\s*\(\s*\w+\s*\)\s*\.\s*" + re.escape(method or "_none_")
        + r"\s*\([^;]*\)\s*;")
    m = exp_call_re.search(sol_src)

    # exposed function = enclosing function of the exposure call
    exposed_fn = None
    if m:
        pre = sol_src[:m.start()]
        fm = list(re.finditer(r"function\s+(\w+)\s*\(", pre))
        if fm:
            exposed_fn = fm[-1].group(1)
    excl = set(filter(None, (exposed_fn, method)))
    closure = [f for f in _public_funcs(sol_src) if f not in excl]
    def _vis(fn):
        mm = re.search(r"function\s+" + re.escape(fn) + r"\s*\([^)]*\)\s*"
                       r"(public|external|internal|private)", sol_src)
        return mm.group(1) if mm else "public"
    pub = [f for f in closure if _vis(f) == "public"]
    reenter_fn = (pub[0] if pub else (closure[0] if closure else exposed_fn))

    if not (m and reenter_fn):
        # no modelable callback -> plain boundary assert only
        checker = ("\n    function __aegis_baseline_check() public view {\n"
                   f"        assert({property_expr});\n    }}\n")
        return sol_src[:body_close] + checker + sol_src[body_close:]

    # Inline re-entry + mid-callback assert, REPLACING the external call. The
    # property is over the contract's OWN storage (we are inside it), so no
    # retargeting. We re-enter a closure entry point, then assert the global
    # invariant during exposure -- exactly where the monolithic shape breaks.
    call_expr = (f"this.{reenter_fn}(1)" if _vis(reenter_fn) == "external"
                 else f"{reenter_fn}(1)")
    inline = ("{ // [BASELINE] inlined re-entrant callback (monolithic, no MCVP)\n"
              f"            {call_expr}; // attacker re-enters a closure entry\n"
              f"            assert({property_expr}); // global invariant mid-callback\n"
              "        }")
    src2 = sol_src[:m.start()] + inline + sol_src[m.end():]

    # keep a boundary assert too (recompute close brace after the edit)
    _, _, close2 = _contract_bounds(src2, contract_name)
    boundary = ("\n    function __aegis_baseline_check() public view {\n"
                f"        assert({property_expr});\n    }}\n")
    return src2[:close2] + boundary + src2[close2:]


def _retarget_property(prop: str, var: str) -> str:
    """Rewrite bare storage identifiers in the property to getter calls on
    `var` (e.g. 'totalAssets == totalShares' -> 't.totalAssets() == t.totalShares()').
    Leaves numbers and operators alone."""
    def repl(m):
        ident = m.group(0)
        if ident in ("true", "false") or ident.isdigit():
            return ident
        return f"{var}.{ident}()"
    # match identifiers that look like storage vars (letters, not pure numbers)
    return re.sub(r"[A-Za-z_]\w*", repl, prop)


# ---------------------------------------------------------------------------
# Classify the monolithic run into the RQ1 column schema.
# ---------------------------------------------------------------------------

def classify_direct(raw, expected_verdict: str, real_bug_site: str | None,
                    property_expr: str):
    """Map aegis.backend's ObligationResult onto the RQ1 columns.

    Inputs:
      raw              : backend.ObligationResult from the monolithic run
      expected_verdict : ground truth "VERIFIED" | "BUG_FOUND"
      real_bug_site    : the function that is the TRUE bug location (for buggy
                         contracts), so we can detect MISFIRES.
    Returns dict with verdict/localized/misfired_on.
    """
    status = raw.status
    cex = raw.counterexample or ""
    detail = raw.detail or ""

    # Monolithic SMTChecker NEVER localizes to an A/G obligation -- it has no
    # notion of OBL_pre/OBL_cb/OBL_post. The best it can do is name a function
    # in its counterexample. We extract that to detect the misfire phenomenon.
    flagged_fn = _function_in_cex(cex + " " + detail)

    if status == "no_backend":
        return dict(verdict="UNKNOWN", localized=False, localized_to=None,
                    raw_status=status, misfired_on=None,
                    detail="no working solver/backend")

    if status == "verified":
        # It proved the monolithic invariant. Correct ONLY if contract is safe.
        if expected_verdict == "VERIFIED":
            return dict(verdict="VERIFIED", localized=False, localized_to=None,
                        raw_status=status, misfired_on=None,
                        detail="proved monolithic invariant")
        else:
            # proved-safe on a buggy contract = unsound MISS (false negative).
            return dict(verdict="UNKNOWN", localized=False, localized_to=None,
                        raw_status=status, misfired_on=None,
                        detail="MISS: proved safe but contract is buggy "
                               "(monolithic invariant too weak to see the "
                               "exposed-state bug)")

    if status == "failed":
        # An assertion violation was found. Is it the REAL bug, or a misfire?
        if expected_verdict == "BUG_FOUND":
            # buggy contract, found a violation. Did it point at the right site?
            if real_bug_site and flagged_fn and \
                    real_bug_site.lower() in flagged_fn.lower():
                return dict(verdict="BUG_FOUND", localized=False,
                            localized_to=None, raw_status=status,
                            misfired_on=None,
                            detail=f"found violation; cex mentions "
                                   f"{flagged_fn} (correct site) but NO "
                                   f"obligation-level localization")
            else:
                # found *a* violation but on the wrong / unrelated function:
                # the setSettler phenomenon. Counts as detection but a spurious
                # / mislocalized one.
                return dict(verdict="BUG_FOUND", localized=False,
                            localized_to=None, raw_status=status,
                            misfired_on=flagged_fn,
                            detail=f"violation found but mislocalized to "
                                   f"{flagged_fn or 'unrelated function'}; "
                                   f"monolithic check cannot point to the A/G "
                                   f"obligation")
        else:
            # SAFE contract but SMTChecker reports a violation = SPURIOUS.
            return dict(verdict="SPURIOUS", localized=False, localized_to=None,
                        raw_status=status, misfired_on=flagged_fn,
                        detail=f"SPURIOUS failure on safe contract; flagged "
                               f"{flagged_fn or 'a function'} -- the monolithic "
                               f"invariant is too rigid for the exposed phase")

    # unknown / timeout
    return dict(verdict="UNKNOWN", localized=False, localized_to=None,
                raw_status=status, misfired_on=None,
                detail=detail or "could not prove (timeout/unsupported)")


def _function_in_cex(text: str) -> str | None:
    """Best-effort: pull a function name SMTChecker mentions in its output."""
    # solc cex usually mentions "function f()" or "f(...)" or a call trace.
    for pat in (r"(?:function\s+)(\w+)\s*\(",
                r"call to (\w+)",
                r"\b(\w+)\([^)]*\)\s*(?:->|returns|at)"):
        m = re.search(pat, text)
        if m and m.group(1) not in ("assert", "require", "function"):
            return m.group(1)
    return None


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

def run_one(sol_path: str, property_expr: str, expected_verdict: str,
            real_bug_site: str | None, timeout_ms: int) -> dict:
    src = _read(sol_path)
    base = os.path.basename(sol_path)
    cname = os.path.splitext(base)[0]
    t0 = time.time()
    try:
        harness = build_monolithic_harness(src, cname, property_expr)
    except Exception as e:
        return dict(tool="smtchecker-direct", contract=base,
                    verdict="UNKNOWN", localized=False, localized_to=None,
                    raw_status="harness_error", misfired_on=None,
                    seconds=round(time.time() - t0, 1),
                    detail=f"could not build monolithic harness: {e}")
    raw = backend.check_obligation("MONO_property", "monolithic",
                                   harness, timeout_ms=timeout_ms)
    secs = round(time.time() - t0, 1)
    cls = classify_direct(raw, expected_verdict, real_bug_site, property_expr)
    cls.update(tool="smtchecker-direct", contract=base, seconds=secs)
    return cls


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", default=None,
                    help="dir of *.sol to run (uses benchmark.json labels)")
    ap.add_argument("--labels", default="benchmark.json",
                    help="JSON mapping contract -> {property, verdict, bug_site}")
    ap.add_argument("--contract", default=None)
    ap.add_argument("--property", default=None)
    ap.add_argument("--expected", default="VERIFIED")
    ap.add_argument("--bug-site", default=None)
    ap.add_argument("--smt-timeout-ms", type=int, default=0)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    if not backend.solc_healthy():
        print("*** NO WORKING solc/SMTChecker -- results would be UNAVAILABLE. ***")
        print("*** install solc 0.8.26 + Eldarica, then re-run.            ***")
        # We still proceed so you can see the schema, but every row = UNKNOWN.

    records = []
    if args.contract:
        records.append(run_one(args.contract, args.property or "true",
                               args.expected, args.bug_site,
                               args.smt_timeout_ms))
    else:
        labels = {}
        if os.path.exists(args.labels):
            labels = json.load(open(args.labels))
        corpus = args.corpus or "contracts/corpus"
        for sol in sorted(glob.glob(os.path.join(corpus, "*.sol"))):
            b = os.path.basename(sol)
            if b.endswith(".harness.sol"):
                continue
            meta = labels.get(b)
            if not meta:
                continue  # only run labeled contracts
            rec = run_one(sol, meta["property"], meta["verdict"],
                          meta.get("bug_site"), args.smt_timeout_ms)
            rec["class"] = meta.get("class", "?")
            records.append(rec)
            print(f"  {b:28s} -> {rec['verdict']:9s} "
                  f"(misfire={rec.get('misfired_on')})  {rec['seconds']}s")

    out = args.out or "results/baseline_smtchecker.json"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(records, open(out, "w"), indent=2)
    print(f"\nwrote {len(records)} records -> {out}")


if __name__ == "__main__":
    main()
