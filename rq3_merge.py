#!/usr/bin/env python3
"""Merge the two annotators' sheets, measure agreement, freeze the labels.

Step three of RQ3, and the last one before any tool runs. It joins both sheets
to the sample key, computes Cohen's kappa on the overlap both annotators
labelled, writes out the disagreements for joint adjudication, and emits the
frozen label manifest the tool is then run against.

  python3 rq3_merge.py --a results/rq3_labels_a_completed.csv \\
                       --b results/rq3_labels_b_filled.csv

Adjudicate results/rq3_disagreements.csv by filling its `final` column, then
re-run with --adjudicated to fold those decisions in.
"""
import argparse
import collections
import csv
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
LABELS = ("safe", "unsafe", "unclear")


def norm(v):
    v = (v or "").strip().lower()
    return v if v in LABELS else ""


def cohens_kappa(pairs):
    """Unweighted Cohen's kappa over (a, b) label pairs."""
    if not pairs:
        return None, 0.0, 0.0
    cats = sorted({x for p in pairs for x in p})
    n = len(pairs)
    observed = sum(1 for a, b in pairs if a == b) / n
    ca = collections.Counter(a for a, _ in pairs)
    cb = collections.Counter(b for _, b in pairs)
    expected = sum((ca[c] / n) * (cb[c] / n) for c in cats)
    if expected == 1.0:
        return None, observed, expected
    return (observed - expected) / (1 - expected), observed, expected


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", default="results/rq3_sample_key.csv")
    ap.add_argument("--sheet-a", default="results/rq3_labels_a.csv",
                    help="the blank sheet as drawn; carries the path")
    ap.add_argument("--sheet-b", default="results/rq3_labels_b.csv")
    ap.add_argument("--a", default="results/rq3_labels_a_completed.csv")
    ap.add_argument("--b", default="results/rq3_labels_b_filled.csv")
    ap.add_argument("--adjudicated", default="",
                    help="results/rq3_disagreements.csv with `final` filled in")
    ap.add_argument("--out", default="results/rq3_frozen_labels.json")
    args = ap.parse_args()

    key = {}
    by_path = {}
    dupes = collections.Counter()
    for r in csv.DictReader(open(os.path.join(HERE, args.key))):
        dupes[r["contract"]] += 1
        key.setdefault(r["contract"], r)
        by_path[r["path"]] = r

    # The packet sheets name each source NNN_<contract>.sol, where NNN is the
    # row's position in the blank sheet it was cut from. That index is exact
    # where the contract name is not: mainnet reuses names across addresses,
    # and joining on the name loses every contract whose name is shared. Read
    # the blank sheets so the index can be resolved back to a path.
    def load_index(path):
        full = os.path.join(HERE, path)
        if not os.path.exists(full):
            return []
        return list(csv.DictReader(open(full)))

    blank_a = load_index(args.sheet_a)
    blank_b = load_index(args.sheet_b)

    def path_of(row, blank):
        """Resolve a filled row to its source path, by index where possible."""
        m = re.match(r"(\d+)_", (row.get("file") or ""))
        if m and blank:
            i = int(m.group(1)) - 1
            if 0 <= i < len(blank):
                cand = blank[i]
                if cand["contract"] == row["contract"]:
                    return cand["path"]
        k = key.get(row["contract"])
        return k["path"] if k and dupes[row["contract"]] == 1 else ""

    sheet_a = list(csv.DictReader(open(os.path.join(HERE, args.a))))
    sheet_b = list(csv.DictReader(open(os.path.join(HERE, args.b))))

    ambiguous = sorted(n for n, c in dupes.items() if c > 1)
    if ambiguous:
        print(f"note: {len(ambiguous)} contract name(s) appear more than once "
              f"at different addresses ({', '.join(ambiguous)});")
        print("      resolved by sheet position, which is exact\n")

    # index the overlap by path, so a repeated name does not merge two rows
    by_b = {}
    for r in sheet_b:
        pb = path_of(r, blank_b)
        if pb:
            by_b[pb] = r

    # ---- agreement on the overlap
    pairs, disagreements = [], []
    for r in sheet_a:
        pa = path_of(r, blank_a)
        if not pa or pa not in by_b:
            continue
        name = r["contract"]
        la, lb = norm(r["label"]), norm(by_b[pa]["label"])
        if not la or not lb:
            continue
        pairs.append((la, lb))
        if la != lb:
            disagreements.append({
                "contract": name, "path": pa,
                "label_a": la, "target_a": r.get("target", ""),
                "why_a": r.get("why", ""),
                "label_b": lb, "target_b": by_b[pa].get("target", ""),
                "why_b": by_b[pa].get("why", ""),
                "final": "", "final_target": ""})

    k, observed, expected = cohens_kappa(pairs)
    print(f"overlap labelled by both : {len(pairs)}")
    print(f"agreed                   : {sum(1 for a, b in pairs if a == b)}"
          f"  ({observed:.1%})")
    print(f"expected by chance       : {expected:.1%}")
    print(f"Cohen's kappa            : "
          + (f"{k:.2f}" if k is not None else "undefined (one category)"))

    dpath = os.path.join(HERE, "results/rq3_disagreements.csv")

    # Read the adjudication BEFORE writing the disagreements file. They are
    # usually the same path, and writing first blanked the `final` column the
    # adjudicator had filled -- so every adjudication was silently discarded
    # and then reported as missing.
    final = {}
    if args.adjudicated and os.path.exists(os.path.join(HERE, args.adjudicated)):
        for r in csv.DictReader(open(os.path.join(HERE, args.adjudicated))):
            f = norm(r.get("final"))
            if f:
                final[r.get("path") or r["contract"]] = (
                    f, (r.get("final_target") or "").strip())

    already_filled = os.path.exists(dpath) and any(
        norm(r.get("final")) for r in csv.DictReader(open(dpath)))
    if disagreements and not already_filled:
        with open(dpath, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=list(disagreements[0]))
            w.writeheader()
            w.writerows(disagreements)
        print(f"\n{len(disagreements)} disagreement(s) -> "
              f"results/rq3_disagreements.csv")
        print("   fill `final` (and `final_target` if the two differ), then "
              "re-run with --adjudicated results/rq3_disagreements.csv")

    if args.adjudicated:
        print(f"\nadjudicated: {len(final)} decision(s) applied")
        if not final:
            print("*** the adjudication file has no `final` values filled "
                  "in; nothing was applied ***")

    # ---- freeze
    frozen, unclear, skipped = {}, 0, 0
    for r in sheet_a:
        name = r["contract"]
        pa = path_of(r, blank_a)
        if not pa or pa not in by_path:
            skipped += 1
            continue
        label = norm(r["label"])
        target = (r.get("target") or "").strip()
        for fk in (pa, name):
            if fk in final:
                label, t2 = final[fk]
                target = t2 or target
                break
        if label == "unclear" or not label:
            unclear += 1
            continue
        k_row = by_path[pa]
        frozen[pa] = {
            "contract": name,
            "arm": k_row.get("arm", ""),
            "weight": float(k_row.get("weight") or 1.0),
            "label": label,
            "expected": "BUG_FOUND" if label == "unsafe" else "VERIFIED",
            "target": target,
        }

    out = os.path.join(HERE, args.out)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w") as fh:
        json.dump(frozen, fh, indent=1)

    by_arm = collections.Counter(v["arm"] for v in frozen.values())
    by_lab = collections.Counter(v["label"] for v in frozen.values())
    print(f"\nfrozen: {len(frozen)} contract(s) -> {args.out}")
    print("  by arm  : " + ", ".join(f"{a}={n}" for a, n in by_arm.most_common()))
    print("  by label: " + ", ".join(f"{l}={n}" for l, n in by_lab.most_common()))
    if unclear:
        print(f"  set aside as unclear: {unclear} (reported, not scored)")
    if skipped:
        print(f"  unjoinable: {skipped}")
    no_target = sum(1 for v in frozen.values()
                    if v["arm"] == "general" and
                    v["target"].lower() in ("", "none"))
    if no_target:
        print(f"  general-arm contracts with no stated target: {no_target} "
              f"(these cannot be run on the general arm)")


if __name__ == "__main__":
    main()
