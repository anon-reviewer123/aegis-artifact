#!/usr/bin/env python3
"""Draw a stratified labelling sample and emit blind labelling sheets.

Step two of RQ3. The sample is stratified by the arm each contract routes to,
so per-arm rates are reportable rather than only an aggregate, and it is drawn
from a fixed seed so it can be redrawn exactly.

The sheets carry no tool output. They carry what an annotator needs to decide
the question and nothing that hints at an answer: the contract, its exposure
site, and blank columns for the label, the target relation and a justification.
Two sheets are written, one per annotator, plus an overlap both label so a
Cohen's kappa can be computed.

  python3 rq3_sample.py --n 80 --overlap 25
  python3 rq3_sample.py --n 80 --overlap 25 --seed 20260919

Fill in `label` (safe / unsafe / unclear), `target` (the relation the contract
is meant to maintain) and `why` (one line). Do this before running the tool.
"""
import argparse
import collections
import csv
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))

# What the annotator sees. No verdict, no arm-quality hint.
SHEET_FIELDS = ["contract", "path", "site_function", "site_call",
                "label", "target", "why"]
KEY_FIELDS = ["contract", "path", "arm", "windowed_sites", "closure_size",
              "in_overlap", "stratum_size", "sampled", "weight"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--routing", default="results/rq3_routing.csv")
    ap.add_argument("--n", type=int, default=80,
                    help="contracts to label in total")
    ap.add_argument("--overlap", type=int, default=25,
                    help="how many both annotators label, for kappa")
    ap.add_argument("--seed", type=int, default=20260919)
    ap.add_argument("--take-all-below", type=int, default=12,
                    help="strata smaller than this are labelled in full; a "
                         "rate computed on three contracts says nothing")
    ap.add_argument("--min-per-arm", type=int, default=15,
                    help="floor for the remaining strata")
    ap.add_argument("--require-ast", action="store_true", default=True,
                    help="skip contracts routed by the regex fallback, whose "
                         "arm assignment is not reliable")
    ap.add_argument("--outdir", default="results")
    args = ap.parse_args()

    allrows = list(csv.DictReader(open(os.path.join(HERE, args.routing))))
    rows = [r for r in allrows if r["arm"] in ("loop", "read_only", "general")]
    if args.require_ast:
        dropped = [r for r in rows if r.get("analyzer") != "ast"]
        rows = [r for r in rows if r.get("analyzer") == "ast"]
        if dropped:
            print(f"excluded {len(dropped)} contract(s) routed by the regex "
                  f"fallback; their arm assignment is not reliable")
    if not rows:
        print("no routable contracts in the routing file")
        return

    by_arm = collections.defaultdict(list)
    for r in rows:
        by_arm[r["arm"]].append(r)

    # Allocation. Small strata are taken in full and the rest share what is
    # left in proportion, so every arm carries enough contracts to report on.
    # Oversampling a small stratum skews the aggregate, so each contract keeps
    # the weight stratum_size / sampled and the scorer weights by it.
    rng = random.Random(args.seed)
    total = len(rows)
    alloc, remaining = {}, args.n
    small = [a for a, g in by_arm.items() if len(g) < args.take_all_below]
    for arm in small:
        alloc[arm] = len(by_arm[arm])
        remaining -= alloc[arm]
    rest = [a for a in by_arm if a not in alloc]
    rest_total = sum(len(by_arm[a]) for a in rest) or 1
    for arm in sorted(rest):
        want = max(args.min_per_arm,
                   round(remaining * len(by_arm[arm]) / rest_total))
        alloc[arm] = min(want, len(by_arm[arm]))
    # trim the largest stratum if the floors overshot the budget
    while sum(alloc.values()) > args.n:
        biggest = max(alloc, key=lambda a: alloc[a])
        if alloc[biggest] <= args.min_per_arm:
            break
        alloc[biggest] -= 1

    picked = []
    for arm in sorted(alloc):
        chosen = rng.sample(by_arm[arm], alloc[arm])
        w = len(by_arm[arm]) / alloc[arm] if alloc[arm] else 0.0
        for r in chosen:
            r["stratum_size"] = len(by_arm[arm])
            r["sampled"] = alloc[arm]
            r["weight"] = f"{w:.4f}"
        picked += chosen
    rng.shuffle(picked)

    # Identity is the path, not the contract name. Mainnet reuses names across
    # addresses, so a name-keyed overlap both collapses duplicates and then
    # matches every row sharing a name -- which is how a 25-contract overlap
    # became a 29-row sheet. The same key would mis-join labels to verdicts.
    overlap = set(r["path"] for r in rng.sample(
        picked, min(args.overlap, len(picked))))

    os.makedirs(os.path.join(HERE, args.outdir), exist_ok=True)

    # the key stays with you, not the annotators
    kpath = os.path.join(HERE, args.outdir, "rq3_sample_key.csv")
    with open(kpath, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=KEY_FIELDS)
        w.writeheader()
        for r in picked:
            w.writerow({"contract": r["contract"], "path": r["path"],
                        "arm": r["arm"],
                        "windowed_sites": r.get("windowed_sites", ""),
                        "closure_size": r.get("closure_size", ""),
                        "in_overlap": "yes" if r["path"] in overlap else "",
                        "stratum_size": r.get("stratum_size", ""),
                        "sampled": r.get("sampled", ""),
                        "weight": r.get("weight", "")})

    # annotator A labels everything; annotator B labels the overlap
    for tag, subset in (("a", picked),
                        ("b", [r for r in picked if r["path"] in overlap])):
        spath = os.path.join(HERE, args.outdir, f"rq3_labels_{tag}.csv")
        with open(spath, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=SHEET_FIELDS)
            w.writeheader()
            for r in subset:
                w.writerow({"contract": r["contract"], "path": r["path"],
                            "site_function": r.get("site_function", ""),
                            "site_call": r.get("site_call", ""),
                            "label": "", "target": "", "why": ""})
        print(f"wrote {args.outdir}/rq3_labels_{tag}.csv  "
              f"({len(subset)} contract(s))")

    print(f"wrote {args.outdir}/rq3_sample_key.csv  (keep this; the sheets "
          f"carry no arm or verdict)")

    dupes = collections.Counter(r["contract"] for r in picked)
    repeated = {n: c for n, c in dupes.items() if c > 1}
    if repeated:
        print(f"\nnote: {len(repeated)} contract name(s) appear more than "
              f"once at different addresses; the path is the identity")
    print(f"\nsample of {len(picked)} from {total} routable, seed {args.seed}")
    for arm, n in sorted(collections.Counter(
            r["arm"] for r in picked).items()):
        w = len(by_arm[arm]) / n
        print(f"  {arm:12s} {n:4d}  of {len(by_arm[arm]):4d} in the population"
              f"   (weight {w:.2f})")
    print(f"overlap for kappa: {len(overlap)}")


if __name__ == "__main__":
    main()
