#!/usr/bin/env python3
"""Show exactly what the solver says about undecided OBL_pre obligations.

The backend reports "could not prove" for three different situations -- the
solver giving up on the query, SMTChecker meeting a construct it does not
support, and the solver failing to start -- and those need different fixes.
This builds each contract's OBL_pre (sliced, as the pipeline now does), runs
solc with the backend's own flags and a full budget, and prints solc's own
words, several contracts at a time.

  python3 rq3_probe.py
  python3 rq3_probe.py Ring SHIBB DLAND --timeout-ms 120000
"""
import argparse
import concurrent.futures as cf
import csv
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

DEFAULT = ["DLAND", "BULLRUNNERSCLUB", "Ring", "WuZeTian", "SHIBB",
           "X7RLiquidityHub", "X7DAOLiquidityHub", "SafePaymentVault",
           "SummoningOfTheWicked", "QuantumEnergy", "BadBunnyNFTS",
           "KatRoyalties"]


def build(row):
    from aegis import compiler, harness_synth, static_analysis, synth
    facts = static_analysis.analyze(row["path"])
    site = facts.exposure_sites[0]
    src = open(row["path"], errors="ignore").read()
    harness = harness_synth.synthesize_harness(src, facts, site, row["target"])
    plan = synth.sample_plans(facts, site, row["target"], backend="openai",
                              k=1)[0]
    compiler.SLICE = True
    obs = compiler.compile_obligations(plan, facts, harness)
    pre = [o for o in obs if o.name == "OBL_pre"]
    return (pre[0].harness_source if pre else None,
            plan.exposure_invariant.formula)


def solve(source, timeout_ms):
    from aegis.backend import _resolve_solc_for
    with tempfile.NamedTemporaryFile("w", suffix=".sol", delete=False) as fh:
        fh.write(source)
        path = fh.name
    cmd = [_resolve_solc_for(source), "--model-checker-engine", "chc",
           "--model-checker-targets", "assert",
           "--model-checker-solvers", os.environ.get("AEGIS_SOLVER", "eld"),
           "--model-checker-ext-calls", "trusted",
           "--model-checker-timeout", str(timeout_ms),
           "--model-checker-show-unproved", path]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=timeout_ms / 1000 + 5)
        return (p.stdout or "") + (p.stderr or "")
    except subprocess.TimeoutExpired:
        return "WALL-CLOCK TIMEOUT"


def probe(item, timeout_ms):
    row, source, inv, err = item
    if err:
        return row["contract"], "build failed", err, 0, ""
    if not source:
        return row["contract"], "no OBL_pre", "", 0, ""
    out = solve(source, timeout_ms)
    lines = [l.strip() for l in out.splitlines()
             if re.search(r"CHC|Warning|Error|unproved|could not|Unsupported|"
                          r"not supported|timeout|TIMEOUT", l)]
    return (row["contract"], "ran", "\n      ".join(lines[:8]),
            len(source.splitlines()), inv)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("contracts", nargs="*")
    ap.add_argument("--verdicts", default="results/rq3_verdicts_v3.csv")
    ap.add_argument("--timeout-ms", type=int, default=120000)
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()

    want = set(args.contracts or DEFAULT)
    rows, seen = [], set()
    for r in csv.DictReader(open(os.path.join(HERE, args.verdicts))):
        if r["contract"] in want and r["arm"] == "general" \
                and r["contract"] not in seen:
            rows.append(r)
            seen.add(r["contract"])
    print(f"probing {len(rows)} contract(s), {args.timeout_ms // 1000}s each, "
          f"{args.workers} at a time\n")

    # Obligations are built one at a time: compile_obligations keeps some
    # module-level state, so building on several threads could let them
    # interfere. Solving is the slow part, and that runs in parallel.
    built = []
    for r in rows:
        try:
            source, inv = build(r)
            built.append((r, source, inv, ""))
        except Exception as exc:
            built.append((r, None, "", str(exc)[:200]))
        print(f"  built {r['contract']}")
    print()
    with cf.ThreadPoolExecutor(max_workers=args.workers) as ex:
        for c, state, text, n, inv in ex.map(
                lambda it: probe(it, args.timeout_ms), built):
            print(f"=== {c}   ({state}, OBL_pre {n} lines)")
            if inv:
                print(f"    Iexp: {inv[:90]}")
            print(f"      {text or '(no solver messages)'}\n")


if __name__ == "__main__":
    main()
