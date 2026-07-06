#!/usr/bin/env python3
"""RQ3 batch runner: run each ablation mode over bench10, produce CSVs.

Usage:
  cd ~/Downloads/aegis_dist
  export AEGIS_OPENAI_MODEL="gpt-5.4-mini"
  python3 run_rq3.py --llm openai --k 4 --smt-timeout-ms 90000

Outputs:
  results/rq3_<mode>.csv   per ablation mode
  results/rq3_summary.csv  aggregated counts
"""
import argparse
import csv
import json
import os
import sys

from aegis.pipeline import run_aegis
from aegis.experiment import ABLATION_MODES

BENCH = "benchmark_bench10.json"
CORPUS = "contracts/corpus"


def load_bench():
    with open(BENCH) as f:
        return json.load(f)


def classify_outcome(status, ground_truth):
    if status == ground_truth:
        return "correct"
    if status in ("UNKNOWN", "UNAVAILABLE"):
        return "unknown"
    if status == "VERIFIED" and ground_truth == "BUG_FOUND":
        return "missed_callback"
    if status == "BUG_FOUND" and ground_truth == "VERIFIED":
        return "bad_invariant"
    return "unknown"


def classify_dominant(status, obligations):
    if status in ("VERIFIED", "BUG_FOUND"):
        return ""
    val_fail = any(o.get("status") == "failed" and o.get("module") == "phases"
                   for o in obligations)
    inv_fail = any("invariant" in o.get("detail", "").lower() for o in obligations)
    if val_fail:
        return "invalid_mcvp"
    if inv_fail:
        return "bad_invariant"
    return "unknown"


def run_one(contract_file, prop, llm, k, timeout, ablate):
    path = os.path.join(CORPUS, contract_file)
    if not os.path.exists(path):
        print(f"  SKIP {contract_file}: file not found", file=sys.stderr)
        return None
    try:
        res = run_aegis(path, prop, llm_backend=llm, k=k,
                        max_repair_rounds=8, smt_timeout_ms=timeout,
                        verbose=False, ablate=ablate, repair="cegar-reuse")
        return res
    except Exception as e:
        print(f"  ERROR {contract_file}: {e}", file=sys.stderr)
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--llm", default="openai", choices=["stub", "anthropic", "openai"])
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--smt-timeout-ms", type=int, default=90000)
    ap.add_argument("--modes", nargs="*", default=list(ABLATION_MODES),
                    help="ablation modes to run (default: all)")
    args = ap.parse_args()

    bench = load_bench()
    os.makedirs("results", exist_ok=True)

    summary_rows = []

    for mode in args.modes:
        if mode not in ABLATION_MODES:
            print(f"unknown mode: {mode}", file=sys.stderr)
            continue

        print(f"\n=== RQ3 ablation: {mode} ===")
        csv_path = f"results/rq3_{mode}.csv"
        rows = []

        for contract_file, spec in bench.items():
            prop = spec["property"]
            gt = spec["ground_truth"]
            print(f"  {contract_file} (gt={gt}, ablate={mode})...", end=" ", flush=True)

            res = run_one(contract_file, prop, args.llm, args.k,
                          args.smt_timeout_ms, mode)
            if res is None:
                rows.append({"contract": contract_file, "ground_truth": gt,
                             "outcome": "error", "raw_verdict": "ERROR",
                             "failing_module": "", "notes": "run failed"})
                print("ERROR")
                continue

            outcome = classify_outcome(res.status, gt)
            failing_mod = ""
            failing_obl = ""
            for o in res.obligations_report:
                if o["status"] in ("failed", "unknown"):
                    failing_mod = o.get("module", "")
                    failing_obl = o.get("obligation", "")
                    break

            rows.append({
                "contract": contract_file,
                "ground_truth": gt,
                "outcome": outcome,
                "raw_verdict": res.status,
                "failing_module": failing_mod,
                "notes": failing_obl,
            })
            print(f"{res.status} -> {outcome}")

        with open(csv_path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["contract", "ground_truth", "outcome",
                                               "raw_verdict", "failing_module", "notes"])
            w.writeheader()
            w.writerows(rows)
        print(f"  wrote {csv_path}")

        counts = {}
        for r in rows:
            counts[r["outcome"]] = counts.get(r["outcome"], 0) + 1
        summary_rows.append({"ablation": mode, **counts})

    # write summary
    if summary_rows:
        all_outcomes = set()
        for r in summary_rows:
            all_outcomes.update(k for k in r if k != "ablation")
        fields = ["ablation"] + sorted(all_outcomes)
        with open("results/rq3_summary.csv", "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=fields, restval=0)
            w.writeheader()
            w.writerows(summary_rows)
        print(f"\nwrote results/rq3_summary.csv")

    # print table
    print("\n=== RQ3 Summary ===")
    for r in summary_rows:
        parts = [f"{k}={v}" for k, v in r.items() if k != "ablation"]
        print(f"  {r['ablation']:20s}  {', '.join(parts)}")


if __name__ == "__main__":
    main()
