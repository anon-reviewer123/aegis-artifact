#!/usr/bin/env python3
"""
run_rq4.py -- component ablation.

Each mode removes one part of the obligation Aegis constructs and re-runs the
twin benchmark. A component is load-bearing if removing it costs discrimination:
safe and unsafe twins stop being told apart.

  none             full pipeline
  no-callback      the depth-1 re-entrant replay is removed, so the external
                   call becomes a no-op and effect ordering cannot matter
  no-differential  the view is read only after settlement, never inside the
                   exposed window, so the two reads cannot disagree
  fixed-shape      the loop-shape classifier is bypassed and every loop is
                   compiled with the conservation builder
  canary           the reachability probe is skipped

Usage:
  python3 run_rq4.py --labels rq1_twins.json --out results/rq4
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aegis.pipeline import run_aegis

MODES = ["none", "no-callback", "no-differential", "fixed-shape", "canary"]


def one(sol_path, meta, ablate, args):
    t0 = time.time()
    try:
        res = run_aegis(sol_path, meta["property"], llm_backend=args.llm,
                        k=args.k, max_repair_rounds=args.max_repair_rounds,
                        smt_timeout_ms=args.smt_timeout_ms, verbose=False,
                        ablate=ablate)
        status = res.status
    except Exception as exc:
        status = f"ERROR({type(exc).__name__})"
    return status, round(time.time() - t0, 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", default="rq1_twins.json")
    ap.add_argument("--out", default="results/rq4")
    ap.add_argument("--modes", default=",".join(MODES))
    ap.add_argument("--llm", default="stub")
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--max-repair-rounds", type=int, default=8)
    ap.add_argument("--smt-timeout-ms", type=int, default=90000)
    args = ap.parse_args()

    modes = [m.strip() for m in args.modes.split(",") if m.strip()]
    labels = json.load(open(args.labels))
    labels.pop("_README", None)
    labels = {k: v for k, v in labels.items() if os.path.exists(k)}

    rows = []
    for mode in modes:
        print(f"\n===== ablate={mode} =====")
        for path, meta in labels.items():
            status, secs = one(path, meta, mode, args)
            rows.append({
                "mode": mode,
                "contract": os.path.basename(path),
                "pattern": meta["pattern"],
                "pair": meta["pair"],
                "label": meta["label"],
                "expected": meta["expected"],
                "status": status,
                "correct": status == meta["expected"],
                "seconds": secs,
            })
        done = [r for r in rows if r["mode"] == mode]
        print(f"  {sum(r['correct'] for r in done)}/{len(done)} correct")

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out + ".csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()),
                           lineterminator="\n")
        w.writeheader()
        w.writerows(rows)

    print("\n=================== RQ4 SUMMARY ===================")
    hdr = f"{'mode':<17}{'loop pairs':>12}{'RO pairs':>10}{'correct':>10}{'time':>9}"
    print(hdr)
    for mode in modes:
        rs = [r for r in rows if r["mode"] == mode]
        pairs = defaultdict(list)
        for r in rs:
            pairs[r["pair"]].append(r)
        loop_ok = sum(1 for p, g in pairs.items()
                      if g[0]["pattern"] == "loop" and len(g) >= 2
                      and all(x["correct"] for x in g))
        ro_ok = sum(1 for p, g in pairs.items()
                    if g[0]["pattern"] == "read_only" and len(g) >= 2
                    and all(x["correct"] for x in g))
        n_loop = sum(1 for p, g in pairs.items()
                     if g[0]["pattern"] == "loop" and len(g) >= 2)
        n_ro = sum(1 for p, g in pairs.items()
                   if g[0]["pattern"] == "read_only" and len(g) >= 2)
        print(f"{mode:<17}{f'{loop_ok}/{n_loop}':>12}{f'{ro_ok}/{n_ro}':>10}"
              f"{f'{sum(r[chr(99)+chr(111)+chr(114)+chr(114)+chr(101)+chr(99)+chr(116)] for r in rs)}/{len(rs)}':>10}"
              f"{sum(r['seconds'] for r in rs):>8.0f}s")
    print(f"\nwrote {args.out}.csv")
    print("\nA pair counts only when both twins are correct: an ablation that "
          "makes\nboth twins report the same verdict loses the pair.")


if __name__ == "__main__":
    main()
