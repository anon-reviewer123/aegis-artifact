#!/usr/bin/env python3
"""Score the RQ3 verdicts into the Table V row.

Step five. Reports each arm on its own, unweighted, because that is the rate
for that arm. The aggregate is weighted back to the population the sample was
drawn from, since the small strata were deliberately oversampled and treating
the sample as if it were the population would overstate their influence.

Every proportion carries a Wilson interval. The sample is 80 of 245, so a bare
point estimate would claim more precision than it has.

  python3 rq3_table5.py
  python3 rq3_table5.py --verdicts results/rq3_verdicts.csv --tex
"""
import argparse
import collections
import csv
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def wilson(k, n, z=1.96):
    """Wilson score interval for k successes in n trials."""
    if n == 0:
        return (0.0, 0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / d
    half = (z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))) / d
    return (p, max(0.0, centre - half), min(1.0, centre + half))


def fmt(p, lo, hi):
    return f"{p:.0%} [{lo:.0%}-{hi:.0%}]"


def counts(rows, weighted=False):
    c = collections.Counter()
    for r in rows:
        w = float(r.get("weight") or 1.0) if weighted else 1.0
        c[r["outcome"]] += w
    return c


def report(rows, title, weighted=False):
    if not rows:
        return
    c = counts(rows, weighted)
    n = sum(c.values())
    tp, tn, fp, fn, nv = (c["TP"], c["TN"], c["FP"], c["FN"], c["NV"])
    decided = tp + tn + fp + fn
    unsafe = sum((float(r.get("weight") or 1.0) if weighted else 1.0)
                 for r in rows if r["label"] == "unsafe")

    print(f"\n{title}   (N={n:.0f}" + (", weighted" if weighted else "") + ")")
    print(f"  TN {tn:.0f}   TP {tp:.0f}   FN {fn:.0f}   FP {fp:.0f}   "
          f"N/V {nv:.0f}")
    if tp + fp:
        print(f"  precision      {fmt(*wilson(tp, tp + fp))}")
    if tp + fn:
        print(f"  recall decided {fmt(*wilson(tp, tp + fn))}")
    if unsafe:
        print(f"  recall corpus  {fmt(*wilson(tp, unsafe))}")
    print(f"  coverage       {fmt(*wilson(decided, n))}")
    print(f"  correct        {fmt(*wilson(tp + tn, n))}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verdicts", default="results/rq3_verdicts.csv")
    ap.add_argument("--labels", default="results/rq3_frozen_labels.json",
                    help="the frozen labels; always re-read, so an "
                         "adjudication made after a run still applies")
    ap.add_argument("--population", type=int, default=245,
                    help="routable deployed contracts the sample came from")
    args = ap.parse_args()

    rows = list(csv.DictReader(open(os.path.join(HERE, args.verdicts))))
    if not rows:
        print("no verdicts recorded")
        return

    # The verdicts file records what the tool said. The label it was scored
    # against is taken from the frozen labels now, not from the moment the
    # tool ran: an arm run before adjudication would otherwise keep a label
    # the adjudication has since replaced.
    lpath = os.path.join(HERE, args.labels)
    if os.path.exists(lpath):
        frozen = json.load(open(lpath))
        relabelled, dropped = 0, 0
        kept = []
        for r in rows:
            f = frozen.get(r["path"])
            if f is None:
                dropped += 1
                continue
            if f["label"] != r["label"]:
                relabelled += 1
            r["label"] = f["label"]
            r["weight"] = f.get("weight", r.get("weight"))
            st = r["status"]
            r["outcome"] = (("TP" if f["label"] == "unsafe" else "FP")
                            if st == "BUG_FOUND" else
                            ("TN" if f["label"] == "safe" else "FN")
                            if st == "VERIFIED" else "NV")
            kept.append(r)
        rows = kept
        if relabelled:
            print(f"note: {relabelled} verdict row(s) re-scored against the "
                  f"adjudicated labels")
        if dropped:
            print(f"note: {dropped} verdict row(s) not in the frozen labels "
                  f"were left out")

    dead = [r for r in rows if r.get("backend") == "none"]
    if dead:
        print(f"*** {len(dead)} row(s) ran with no verifier; this is not a "
              f"result. Fix solc and re-run those contracts. ***")
        return

    # A general-arm contract whose annotator stated no target was run against
    # the property `true`, which always holds. Its VERIFIED proves nothing
    # about the contract, so counting it as a true negative inflates both
    # coverage and correctness. Such rows are not scorable and are set apart.
    vacuous = [r for r in rows
               if r["arm"] == "general" and
               (r.get("has_target") == "no" or r["status"] == "NO_TARGET")
               and r["status"] != "NOT_EXPRESSIBLE"]
    # Targets that cannot be stated as a storage invariant are outside what
    # the general arm verifies. They are reported as scope, not as failures.
    inexpressible = [r for r in rows if r["status"] == "NOT_EXPRESSIBLE"]
    rows = [r for r in rows if r not in vacuous and r not in inexpressible]

    print(f"{args.verdicts}: {len(rows)} scorable contract(s) from a "
          f"population of {args.population}")
    if vacuous:
        print(f"set apart: {len(vacuous)} general-arm contract(s) with no "
              f"stated target -- only `true` could be checked, so not scored")
    if inexpressible:
        print(f"set apart: {len(inexpressible)} general-arm contract(s) whose "
              f"target is not a storage invariant the property language can "
              f"state (scope, not failure)")

    # per arm, unweighted: this is the rate for that arm
    for arm in sorted({r["arm"] for r in rows}):
        sub = [r for r in rows if r["arm"] == arm]
        w = float(sub[0].get("weight") or 1.0)
        report(sub, f"arm: {arm}  ({len(sub)} sampled, weight {w:.2f})")

    # the fixed forms together, which is the row the paper reports separately
    fixed = [r for r in rows if r["arm"] in ("loop", "read_only")]
    if fixed:
        report(fixed, "AEGIS (fixed forms)")

    report(rows, "AEGIS (all arms), sample")
    report(rows, "AEGIS (all arms), weighted to the population", weighted=True)

    print(f"\nintervals are Wilson at 95%; the sample is {len(rows)} of "
          f"{args.population}")


if __name__ == "__main__":
    main()
