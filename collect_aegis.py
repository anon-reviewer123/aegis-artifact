#!/usr/bin/env python3
"""
collect_aegis.py  --  run Aegis over the labeled benchmark and emit the shared
RQ1 schema (so it sits in the same Table 1 / Table 2 as the baselines).

Aegis's distinguishing column is `localized`: when it reports BUG_FOUND it names
the exact A/G obligation (OBL_pre / OBL_cb_<g> / OBL_post / OBL_target) that was
refuted -> the precise re-entrant entry point. No baseline can fill this.

Usage:
  python3 collect_aegis.py --labels benchmark.json --llm openai --k 4 \
        --out results/aegis_rq1.json
  # for a quick plumbing check without spending API tokens:
  python3 collect_aegis.py --labels benchmark.json --llm stub --out /tmp/a.json
"""
from __future__ import annotations
import os, sys, json, time, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aegis.pipeline import run_aegis


def collect_one(sol_path, meta, llm, k, max_rounds, timeout_ms):
    prop = meta["property"]
    expected = meta["verdict"]
    bug_site = meta.get("bug_site")
    t0 = time.time()
    res = run_aegis(sol_path, prop, llm_backend=llm, k=k,
                    max_repair_rounds=max_rounds,
                    smt_timeout_ms=timeout_ms, verbose=False)
    secs = round(time.time() - t0, 1)

    failed_obls = [o["obligation"] for o in res.obligations_report
                   if o.get("status") == "failed"]
    localized = res.status == "BUG_FOUND" and len(failed_obls) > 0
    localized_to = "+".join(failed_obls) if failed_obls else None

    # map Aegis status onto the RQ1 verdict + correctness vs ground truth
    if res.status in ("VERIFIED", "BUG_FOUND"):
        verdict = res.status
        correct = (res.status == expected)
    elif res.status == "UNAVAILABLE":
        verdict, correct = "UNKNOWN", False
    else:
        verdict, correct = "UNKNOWN", (expected == "UNKNOWN")

    return dict(
        tool="aegis", contract=os.path.basename(sol_path),
        **{"class": meta.get("class", "?")},
        verdict=verdict, expected=expected, correct=correct,
        localized=localized, localized_to=localized_to,
        misfired_on=None,
        repair_rounds=res.repair_rounds, total_repairs=res.total_repairs,
        candidates_tried=res.candidates_tried,
        closure_size=(len(res.plan.closure.functions) if res.plan else None),
        backend=res.backend_used, seconds=secs,
        metrics=res.metrics,
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", default="benchmark.json")
    ap.add_argument("--llm", default="openai", choices=["stub", "openai", "anthropic"])
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--max-repair-rounds", type=int, default=8)
    ap.add_argument("--smt-timeout-ms", type=int, default=0)
    ap.add_argument("--out", default="results/aegis_rq1.json")
    ap.add_argument("--corpus", default="contracts/corpus")
    args = ap.parse_args()

    labels = json.load(open(args.labels))
    records = []
    for b, meta in labels.items():
        sol = os.path.join(args.corpus, b)
        if not os.path.exists(sol):
            print(f"  !! {b}: source not found at {sol}, skipping")
            continue
        rec = collect_one(sol, meta, args.llm, args.k,
                          args.max_repair_rounds, args.smt_timeout_ms)
        records.append(rec)
        loc = rec["localized_to"] or "-"
        ok = "OK" if rec["correct"] else "XX"
        print(f"  {b:28s} {rec['verdict']:9s} [{ok}] "
              f"localized->{loc}  {rec['seconds']}s")

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    json.dump(records, open(args.out, "w"), indent=2)
    n_ok = sum(1 for r in records if r["correct"])
    print(f"\nwrote {len(records)} records -> {args.out}")
    print(f"oracle: {n_ok}/{len(records)} correct vs ground truth")


if __name__ == "__main__":
    main()
