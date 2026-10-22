#!/usr/bin/env python3
"""Report what the admissibility premise and the two gates decide, per contract.

Runs no solver. Use it to see which sites the read-only rule still applies to,
which contracts fall outside the depth-one model, and which contracts have a
second exposure site that a whole-contract verdict would not cover.

  python3 report_gates.py contracts/corpus ro_twins loop_twins_v2
  python3 report_gates.py --csv results/gates.csv contracts/corpus
"""
import argparse
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis import coverage, static_analysis
from aegis.footprint import classify_views
from aegis.static_analysis import view_closure

FIELDS = ["contract", "analyzer", "site", "views_total", "views_admitted",
          "blocked_by", "nesting", "uncovered_sites", "note"]


def scan(path):
    try:
        facts = static_analysis.analyze(path)
    except Exception as exc:
        return {"contract": os.path.basename(path),
                "note": f"analysis failed: {exc}"}
    analyzer = static_analysis.LAST_ANALYZER
    if not facts.exposure_sites:
        return {"contract": os.path.basename(path), "analyzer": analyzer,
                "note": "no exposure site"}
    site = facts.exposure_sites[0]
    views = view_closure(facts, site.function)
    verdicts = classify_views(facts, site, views)
    admitted = [v for v in verdicts if v.admitted]
    blocked = sorted({v.writer for v in verdicts if v.writer})
    nest = coverage.nesting_gate(facts, site)
    cov = coverage.coverage_gate(facts, site)
    return {
        "contract": os.path.basename(path),
        "analyzer": analyzer,
        "site": f"{site.function}{site.call}",
        "views_total": len(views),
        "views_admitted": len(admitted),
        "blocked_by": ";".join(blocked),
        "nesting": "ok" if nest.ok else "nested",
        "uncovered_sites": len(coverage.uncovered_sites(facts, site)),
        "note": "" if nest.ok else nest.reason,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--csv", default="")
    args = ap.parse_args()

    rows = []
    for d in args.dirs:
        files = ([d] if d.endswith(".sol") else
                 [os.path.join(d, f) for f in sorted(os.listdir(d))
                  if f.endswith(".sol") and ".harness" not in f
                  and ".ethmodel" not in f])
        for f in files:
            rows.append(scan(f))

    with_site = [r for r in rows if r.get("site")]
    vt = sum(r["views_total"] for r in with_site)
    va = sum(r["views_admitted"] for r in with_site)
    import collections
    by_an = collections.Counter(r.get("analyzer", "?") for r in rows)
    print(f"contracts scanned         {len(rows)}")
    print(f"  analyzer used           "
          + ", ".join(f"{k}={v}" for k, v in sorted(by_an.items())))
    print(f"  with an exposure site   {len(with_site)}")
    print(f"exposed views             {vt}")
    print(f"  admitted to read-only   {va}"
          + (f" ({100.0*va/vt:.1f}%)" if vt else ""))
    print(f"  fall through to general {vt - va}")
    print(f"contracts outside depth-1 "
          f"{sum(1 for r in with_site if r['nesting'] == 'nested')}")
    print(f"contracts with an uncovered second site "
          f"{sum(1 for r in with_site if r['uncovered_sites'])}")

    if args.csv:
        os.makedirs(os.path.dirname(args.csv) or ".", exist_ok=True)
        with open(args.csv, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=FIELDS)
            w.writeheader()
            for r in rows:
                w.writerow({k: r.get(k, "") for k in FIELDS})
        print(f"\nwrote {args.csv}")


if __name__ == "__main__":
    main()
