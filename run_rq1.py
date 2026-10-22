#!/usr/bin/env python3
"""
run_rq1.py -- run Aegis over the RQ1 twin benchmark and record, for every
contract, not just the verdict but which obligation produced it.

The provenance column is the point. A verdict is only evidence for the claimed
mechanism if the obligation that produced it is the operative one: OBL_view_<g>
for read-only, OBL_loop_step_<fn> for loops. A BUG_FOUND that came from some
other obligation, or a VERIFIED where no operative obligation ran at all, is
recorded as such rather than counted as a success.

Usage:
  python3 run_rq1.py --labels rq1_twins.json --out results/rq1_aegis
  python3 run_rq1.py --labels rq1_twins.json --pattern read_only --llm openai
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

OPERATIVE_PREFIXES = ("OBL_view_", "OBL_loop_step_")
OPERATIVE_NAMES = ("OBL_readonly", "OBL_reentry", "OBL_conservation")


def _is_operative(name):
    return name.startswith(OPERATIVE_PREFIXES) or name in OPERATIVE_NAMES


def _obligations(res):
    out = []
    for o in res.obligations_report or []:
        if isinstance(o, dict):
            out.append((o.get("obligation", ""), o.get("status", "")))
        else:
            out.append((getattr(o, "name", ""), getattr(o, "status", "")))
    return out


def _provenance(res):
    """Which obligation produced this verdict, and was it the operative one."""
    obls = _obligations(res)
    # canaries are reachability probes: a canary is EXPECTED to fail, so it is
    # never evidence of a bug and must not appear in the provenance column.
    canary = [f"{n}:{s}" for n, s in obls if n.endswith("_canary")]
    real = [(n, s) for n, s in obls if not n.endswith("_canary")]
    failed = [n for n, s in real if s == "failed"]
    verified = [n for n, s in real if s == "verified"]

    if res.status == "BUG_FOUND":
        source = "+".join(failed) if failed else ""
        grounded = any(_is_operative(n) for n in failed)
    elif res.status == "VERIFIED":
        ops = [n for n in verified if _is_operative(n)]
        source = "+".join(ops)
        grounded = bool(ops)
    else:
        source, grounded = "", False
    return source, grounded, ("+".join(canary) if canary else "")


def run_one(sol_path, meta, args):
    t0 = time.time()
    try:
        res = run_aegis(sol_path, meta["property"], llm_backend=args.llm,
                        k=args.k, max_repair_rounds=args.max_repair_rounds,
                        smt_timeout_ms=args.smt_timeout_ms, verbose=args.verbose)
        status = res.status
        source, grounded, canary = _provenance(res)
        obl_count = len(_obligations(res))
        error = ""
    except Exception as exc:
        status, source, grounded, canary, obl_count = "ERROR", "", False, "", 0
        error = f"{type(exc).__name__}: {exc}"[:200]
        res = None

    secs = round(time.time() - t0, 1)
    expected = meta["expected"]
    return {
        "contract": os.path.basename(sol_path),
        "pair": meta["pair"],
        "pattern": meta["pattern"],
        "label": meta["label"],
        "expected": expected,
        "status": status,
        "correct": status == expected,
        "operative_obligation": source,
        "verdict_grounded": grounded,
        "canary": canary,
        "obligations": obl_count,
        "seconds": secs,
        "backend": getattr(res, "backend_used", "none") if res else "none",
        "error": error,
    }


def summarise(rows):
    print("\n=================== RQ1 SUMMARY ===================")
    by_pattern = defaultdict(list)
    for r in rows:
        by_pattern[r["pattern"]].append(r)

    for pattern, rs in sorted(by_pattern.items()):
        safe = [r for r in rs if r["label"] == "safe"]
        unsafe = [r for r in rs if r["label"] == "unsafe"]
        print(f"\n{pattern}:")
        print(f"  safe   VERIFIED : {sum(r['correct'] for r in safe)}/{len(safe)}")
        print(f"  unsafe BUG_FOUND: {sum(r['correct'] for r in unsafe)}/{len(unsafe)}")
        ungrounded = [r for r in rs if r["correct"] and not r["verdict_grounded"]]
        if ungrounded:
            print(f"  NOT GROUNDED in an operative obligation: "
                  f"{[r['contract'] for r in ungrounded]}")

    print("\npair discrimination (safe VERIFIED and unsafe BUG_FOUND):")
    pairs = defaultdict(list)
    for r in rows:
        pairs[r["pair"]].append(r)
    for pair, rs in sorted(pairs.items()):
        ok = all(r["correct"] for r in rs) and len(rs) >= 2
        print(f"  {'YES' if ok else 'NO '}  {pair}"
              + ("" if len(rs) >= 2 else "  (incomplete pair)"))

    bad = [r for r in rows if not r["correct"]]
    if bad:
        print("\nincorrect verdicts:")
        for r in bad:
            print(f"  {r['contract']}: expected {r['expected']}, got {r['status']}"
                  + (f" :: {r['error']}" if r["error"] else ""))


def main():
    ap = argparse.ArgumentParser(description="RQ1 twin discrimination run")
    ap.add_argument("--labels", default="rq1_twins.json")
    ap.add_argument("--out", default="results/rq1_aegis")
    ap.add_argument("--pattern", default=None,
                    help="restrict to one pattern (read_only | loop)")
    ap.add_argument("--llm", default="stub",
                    choices=["stub", "anthropic", "openai"])
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--max-repair-rounds", type=int, default=8)
    ap.add_argument("--smt-timeout-ms", type=int, default=90000)
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    labels = json.load(open(args.labels))
    labels.pop("_README", None)

    rows = []
    for sol_path, meta in labels.items():
        if args.pattern and meta["pattern"] != args.pattern:
            continue
        if not os.path.exists(sol_path):
            print(f"[skip] {sol_path} not found")
            continue
        print(f"[run] {sol_path}")
        row = run_one(sol_path, meta, args)
        print(f"      {row['status']} (expected {row['expected']}) "
              f"via {row['operative_obligation'] or 'nothing'} "
              f"[{row['seconds']}s]")
        rows.append(row)

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out + ".csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    json.dump(rows, open(args.out + ".json", "w"), indent=2)
    print(f"\nwrote {args.out}.csv and {args.out}.json")

    summarise(rows)


if __name__ == "__main__":
    main()
