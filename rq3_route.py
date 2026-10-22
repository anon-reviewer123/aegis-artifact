#!/usr/bin/env python3
"""Route the deployed contracts to arms, without running a solver.

This is step one of RQ3 and produces no verdicts on purpose. It records, for
each contract, which arm the tool would take and what the static analysis sees,
so the labelling sample can be stratified by arm and drawn before any tool
output exists.

  python3 rq3_route.py --list results/compilable.csv --root ../scs-eth
  python3 rq3_route.py --list results/compilable.csv --root ../scs-eth --out results/rq3_routing.csv
"""
import argparse
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from aegis import coverage, guards, static_analysis
from aegis.footprint import classify_views
from aegis.static_analysis import view_closure

FIELDS = ["contract", "path", "arm", "analyzer", "sites", "windowed_sites",
          "site_function", "site_call", "closure_size", "admitted_views",
          "loop_sites", "nesting", "note"]


def resolve(path, root, listroot):
    """Map a path recorded in the list onto this machine."""
    if os.path.isabs(path) and os.path.exists(path):
        return path
    cand = os.path.join(HERE, path)
    if os.path.exists(cand):
        return cand
    if root:
        # strip the leading prefix the list was written with, then re-root
        tail = path
        if listroot and tail.startswith(listroot):
            tail = tail[len(listroot):].lstrip("/")
        cand = os.path.join(root, tail)
        if os.path.exists(cand):
            return cand
        cand = os.path.join(root, os.path.basename(path))
        if os.path.exists(cand):
            return cand
    return ""


def route(path):
    """Which arm would take this contract, from static facts alone."""
    facts = static_analysis.analyze(path)
    row = {"analyzer": static_analysis.LAST_ANALYZER,
           "sites": len(facts.exposure_sites),
           "loop_sites": len(facts.loop_sites)}

    if facts.loop_sites:
        row["arm"] = "loop"
    windowed = [s for s in facts.exposure_sites
                if s.write_before_call and s.write_after_call]
    row["windowed_sites"] = len(windowed)

    if not facts.exposure_sites:
        row.update(arm=row.get("arm", "none"), note="no exposure site")
        return row

    site = facts.exposure_sites[0]
    row["site_function"] = site.function
    row["site_call"] = site.call
    row["closure_size"] = len(facts.full_closure(site))
    admitted = [v.view for v in
                classify_views(facts, site, view_closure(facts, site.function))
                if v.admitted]
    row["admitted_views"] = len(admitted)
    row["nesting"] = "ok" if coverage.nesting_gate(facts, site).ok else "nested"

    # arm precedence follows the pipeline: loop first, then read-only, then the
    # general arm
    if not facts.loop_sites:
        row["arm"] = "read_only" if admitted else "general"
    g = guards.explain(facts, site)
    if g:
        row["note"] = g[:80]
    return row


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", default="results/compilable.csv")
    ap.add_argument("--root", default="",
                    help="directory the contract paths should be resolved "
                         "against, if the list was written elsewhere")
    ap.add_argument("--list-root", default="../scs-eth",
                    help="prefix to strip from the recorded paths")
    ap.add_argument("--out", default="results/rq3_routing.csv")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    entries = list(csv.DictReader(open(os.path.join(HERE, args.list))))
    if args.limit:
        entries = entries[:args.limit]

    rows, missing = [], 0
    for i, e in enumerate(entries, 1):
        raw = e.get("file") or e.get("path") or ""
        name = e.get("contract") or os.path.basename(raw)
        path = resolve(raw, args.root, args.list_root)
        if not path:
            missing += 1
            rows.append({"contract": name, "path": raw, "arm": "missing",
                         "note": "source file not found"})
            continue
        try:
            row = route(path)
        except Exception as exc:
            row = {"arm": "error", "note": str(exc)[:80]}
        row["contract"] = name
        row["path"] = path
        rows.append(row)
        if i % 25 == 0:
            print(f"  routed {i}/{len(entries)}")

    out = os.path.join(HERE, args.out)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in FIELDS})

    import collections
    by_arm = collections.Counter(r.get("arm", "?") for r in rows)
    by_an = collections.Counter(r.get("analyzer", "?") for r in rows)
    print(f"\nrouted {len(rows)} contract(s)")
    for arm, n in by_arm.most_common():
        print(f"  {arm:12s} {n:4d}")
    print(f"analyzer: " + ", ".join(f"{k}={v}" for k, v in by_an.most_common()))
    if missing:
        print(f"\n*** {missing} source file(s) not found -- fix --root before "
              f"sampling ***")
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
