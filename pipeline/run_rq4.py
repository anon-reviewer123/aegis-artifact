#!/usr/bin/env python3
"""RQ4 batch runner: modular repair contribution over bench10.

Phase 1: run all 10 contracts with --repair none --k 1 to detect initial failures.
Phase 2: for each failing contract, run all 5 repair strategies.

Usage:
  cd ~/Downloads/aegis_dist
  export AEGIS_OPENAI_MODEL="gpt-5.4-mini"
  python3 run_rq4.py --llm openai --k 4 --smt-timeout-ms 90000

Outputs:
  results/rq4_initial.csv   phase-1 initial run
  results/rq4_repair.csv    phase-2 per-strategy results
  results/rq4_summary.csv   aggregated
"""
import argparse
import csv
import json
import os
import sys

from aegis.pipeline import run_aegis
from aegis.experiment import REPAIR_STRATEGIES

BENCH = "benchmark_bench10.json"
CORPUS = "contracts/corpus"


def load_bench():
    with open(BENCH) as f:
        return json.load(f)


def run_one(contract_file, prop, llm, k, timeout, repair, max_rounds=8):
    path = os.path.join(CORPUS, contract_file)
    if not os.path.exists(path):
        return None
    try:
        res = run_aegis(path, prop, llm_backend=llm, k=k,
                        max_repair_rounds=max_rounds, smt_timeout_ms=timeout,
                        verbose=False, ablate="none", repair=repair)
        return res
    except Exception as e:
        print(f"  ERROR {contract_file}: {e}", file=sys.stderr)
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--llm", default="openai", choices=["stub", "anthropic", "openai"])
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--smt-timeout-ms", type=int, default=90000)
    ap.add_argument("--max-repair-rounds", type=int, default=8)
    ap.add_argument("--strategies", nargs="*", default=list(REPAIR_STRATEGIES),
                    help="repair strategies to run (default: all)")
    ap.add_argument("--skip-phase1", action="store_true",
                    help="skip initial-failure detection, run all strategies on all contracts")
    args = ap.parse_args()

    bench = load_bench()
    os.makedirs("results", exist_ok=True)

    # Phase 1: detect initially-failing subset
    failing_subset = []
    initial_rows = []

    if not args.skip_phase1:
        print("=== Phase 1: initial run (--repair none --k 1) ===")
        for contract_file, spec in bench.items():
            prop = spec["property"]
            gt = spec["ground_truth"]
            print(f"  {contract_file}...", end=" ", flush=True)

            res = run_one(contract_file, prop, args.llm, k=1,
                          timeout=args.smt_timeout_ms, repair="none")
            if res is None:
                initial_rows.append({"contract": contract_file, "ground_truth": gt,
                                     "status": "ERROR", "initially_fails": True})
                failing_subset.append(contract_file)
                print("ERROR -> in failing subset")
                continue

            fails = res.status not in ("VERIFIED", "BUG_FOUND")
            initial_rows.append({
                "contract": contract_file,
                "ground_truth": gt,
                "status": res.status,
                "initially_fails": fails,
            })
            if fails:
                failing_subset.append(contract_file)
            print(f"{res.status} {'-> FAILING' if fails else '-> OK'}")

        with open("results/rq4_initial.csv", "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["contract", "ground_truth",
                                               "status", "initially_fails"])
            w.writeheader()
            w.writerows(initial_rows)
        print(f"\nInitially failing: {len(failing_subset)} / {len(bench)}")
        print(f"wrote results/rq4_initial.csv")
    else:
        failing_subset = list(bench.keys())
        print(f"Phase 1 skipped; running all {len(failing_subset)} contracts")

    if not failing_subset:
        print("\nNo initially-failing contracts on bench10.")
        print("This is the honest result: first-attempt MCVPs succeeded for all 10.")
        # still run all strategies for comparison on the full set
        print("Falling back: running all strategies on ALL contracts for timing data.")
        failing_subset = list(bench.keys())

    # Phase 2: run each repair strategy on the failing subset
    print(f"\n=== Phase 2: repair strategies on {len(failing_subset)} contracts ===")
    repair_rows = []

    for strategy in args.strategies:
        if strategy not in REPAIR_STRATEGIES:
            continue
        print(f"\n--- strategy: {strategy} ---")
        for contract_file in failing_subset:
            spec = bench[contract_file]
            prop = spec["property"]
            gt = spec["ground_truth"]
            print(f"  {contract_file} ({strategy})...", end=" ", flush=True)

            res = run_one(contract_file, prop, args.llm, args.k,
                          args.smt_timeout_ms, strategy,
                          max_rounds=args.max_repair_rounds)
            if res is None:
                repair_rows.append({
                    "contract": contract_file, "strategy": strategy,
                    "recovered": False, "correct": False,
                    "smtchecker_calls": 0, "reuse_hits": 0, "time_sec": 0,
                })
                print("ERROR")
                continue

            recovered = res.status in ("VERIFIED", "BUG_FOUND")
            correct = res.status == gt
            calls = res.metrics.get("smtchecker_calls", 0)
            reuse = res.metrics.get("reuse_hits", 0)
            wall = res.metrics.get("wall_clock_sec", 0)

            repair_rows.append({
                "contract": contract_file,
                "strategy": strategy,
                "recovered": recovered,
                "correct": correct,
                "smtchecker_calls": calls,
                "reuse_hits": reuse,
                "time_sec": wall,
            })
            print(f"{res.status} rec={recovered} cor={correct} "
                  f"calls={calls} reuse={reuse} t={wall}s")

    # write per-contract CSV
    fields = ["contract", "strategy", "recovered", "correct",
              "smtchecker_calls", "reuse_hits", "time_sec"]
    with open("results/rq4_repair.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(repair_rows)
    print(f"\nwrote results/rq4_repair.csv")

    # aggregate per strategy
    summary = {}
    for r in repair_rows:
        s = r["strategy"]
        if s not in summary:
            summary[s] = {"recovered": 0, "correct": 0, "total": 0,
                          "calls": 0, "reuse": 0, "time": 0.0}
        summary[s]["total"] += 1
        if r["recovered"]:
            summary[s]["recovered"] += 1
        if r["correct"]:
            summary[s]["correct"] += 1
        summary[s]["calls"] += r["smtchecker_calls"]
        summary[s]["reuse"] += r["reuse_hits"]
        summary[s]["time"] += r["time_sec"]

    summary_rows = []
    for s in args.strategies:
        if s in summary:
            d = summary[s]
            n = d["total"] or 1
            summary_rows.append({
                "strategy": s,
                "recovered": d["recovered"],
                "correct": d["correct"],
                "total_calls": d["calls"],
                "total_reuse": d["reuse"],
                "mean_time_sec": round(d["time"] / n, 2),
            })

    sfields = ["strategy", "recovered", "correct", "total_calls",
               "total_reuse", "mean_time_sec"]
    with open("results/rq4_summary.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=sfields)
        w.writeheader()
        w.writerows(summary_rows)
    print(f"wrote results/rq4_summary.csv")

    print("\n=== RQ4 Summary ===")
    print(f"{'Strategy':16s} {'Rec':>4s} {'Cor':>4s} {'Calls':>6s} {'Reuse':>6s} {'Time':>8s}")
    for r in summary_rows:
        print(f"{r['strategy']:16s} {r['recovered']:4d} {r['correct']:4d} "
              f"{r['total_calls']:6d} {r['total_reuse']:6d} "
              f"{r['mean_time_sec']:8.2f}s")


if __name__ == "__main__":
    main()
