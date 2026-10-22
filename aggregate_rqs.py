#!/usr/bin/env python3
"""Aggregate RQ3/RQ4 results into paper-ready summary tables.

Usage:
  python3 aggregate_rqs.py
"""
import csv
import os
import sys


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return list(csv.DictReader(f))


def print_rq3():
    summary = read_csv("results/rq3_summary.csv")
    if not summary:
        print("No RQ3 summary found at results/rq3_summary.csv")
        return

    print("Table: RQ3 MCVP module ablation (bench10)")
    print(f"{'Variant':20s} {'Corr':>5s} {'Miss':>5s} {'Bad':>5s} {'Unk':>5s} {'Err':>5s}")
    print("-" * 55)
    for r in summary:
        mode = r.get("ablation", "?")
        label = "Full Aegis" if mode == "none" else f"- {mode}"
        corr = int(r.get("correct", 0))
        miss = int(r.get("missed_callback", 0))
        bad = int(r.get("bad_invariant", 0))
        unk = int(r.get("unknown", 0))
        err = int(r.get("error", 0))
        print(f"{label:20s} {corr:5d} {miss:5d} {bad:5d} {unk:5d} {err:5d}")
    print()

    # per-mode detail
    for mode_file in sorted(f for f in os.listdir("results") if f.startswith("rq3_") and f != "rq3_summary.csv"):
        rows = read_csv(f"results/{mode_file}")
        if not rows:
            continue
        mode = mode_file.replace("rq3_", "").replace(".csv", "")
        print(f"  Detail: {mode}")
        for r in rows:
            tag = "OK" if r.get("outcome") == "correct" else r.get("outcome", "?").upper()
            print(f"    {r['contract']:30s} gt={r['ground_truth']:10s} "
                  f"verdict={r['raw_verdict']:12s} -> {tag}")
        print()


def print_rq4():
    summary = read_csv("results/rq4_summary.csv")
    if not summary:
        print("No RQ4 summary found at results/rq4_summary.csv")
        return

    print("Table: RQ4 modular repair on bench10")
    print(f"{'Strategy':16s} {'Rec':>5s} {'Corr':>5s} {'Calls':>7s} "
          f"{'Reuse':>6s} {'Time':>8s}")
    print("-" * 55)
    for r in summary:
        print(f"{r['strategy']:16s} {r['recovered']:>5s} {r['correct']:>5s} "
              f"{r['total_calls']:>7s} {r['total_reuse']:>6s} "
              f"{r['mean_time_sec']:>7s}s")
    print()

    # per-contract detail
    detail = read_csv("results/rq4_repair.csv")
    if detail:
        print("  Per-contract detail:")
        current_strat = None
        for r in detail:
            if r["strategy"] != current_strat:
                current_strat = r["strategy"]
                print(f"\n  --- {current_strat} ---")
            rec = "Y" if r.get("recovered") == "True" else "N"
            cor = "Y" if r.get("correct") == "True" else "N"
            print(f"    {r['contract']:30s} rec={rec} cor={cor} "
                  f"calls={r['smtchecker_calls']} reuse={r['reuse_hits']} "
                  f"t={r['time_sec']}s")
        print()

    # phase 1 initial failures
    initial = read_csv("results/rq4_initial.csv")
    if initial:
        failing = [r for r in initial if r.get("initially_fails") == "True"]
        print(f"  Initially failing: {len(failing)} / {len(initial)}")
        for r in failing:
            print(f"    {r['contract']:30s} status={r['status']}")
        print()


def main():
    print("=" * 60)
    print("AEGIS EXPERIMENT RESULTS — bench10")
    print("=" * 60)
    print()
    print_rq3()
    print_rq4()


if __name__ == "__main__":
    main()
