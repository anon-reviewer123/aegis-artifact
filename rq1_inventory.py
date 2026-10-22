#!/usr/bin/env python3
"""Map the contracts on disk onto the family table the paper reports for RQ1.

RQ1 is stated over 117 curated twins in eight families. Before trying to
reproduce the numbers it is worth knowing which of those contracts exist, since
a family that is short cannot produce the row the paper prints for it.

  python3 rq1_inventory.py
  python3 rq1_inventory.py --emit rq1_full.json
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Table III: family -> (safe, unsafe)
PAPER = {
    "classic_reentrancy":   (10, 10),
    "cross_function":       (10, 10),
    "read_only":            (8, 8),
    "token_hook":           (8, 8),
    "forced_revert_loop":   (7, 8),
    "flash_loan":           (6, 6),
    "phase_ordering":       (5, 5),
    "eoa_assumption":       (4, 4),
}

# Filename prefixes are the reliable key. The `class` field in
# benchmark_50.json groups several families together -- UnexpectedEOACallback
# is filed under classic_reentrancy, PhaseOrderingDesync under
# griefing_liveness -- so classifying by it silently empties two families.
PREFIX_TO_FAMILY = {
    "ClassicReentrancy": "classic_reentrancy",
    "CrossFunctionDesync": "cross_function",
    "ReadOnlyReentrancy": "read_only",
    "TokenHookAccounting": "token_hook",
    "ForcedRevertGriefing": "forced_revert_loop",
    "FlashLoanCallback": "flash_loan",
    "PhaseOrderingDesync": "phase_ordering",
    "UnexpectedEOACallback": "eoa_assumption",
}

CLASS_TO_FAMILY = {
    "classic_reentrancy": "classic_reentrancy",
    "cross_function_desync": "cross_function",
    "cross_function": "cross_function",
    "read_only_reentrancy": "read_only",
    "read_only": "read_only",
    "token_hook_accounting": "token_hook",
    "token_hook": "token_hook",
    "forced_revert_griefing": "forced_revert_loop",
    "forced_revert": "forced_revert_loop",
    "loop": "forced_revert_loop",
    "flash_loan_callback": "flash_loan",
    "flash_loan": "flash_loan",
    "phase_ordering_desync": "phase_ordering",
    "phase_ordering": "phase_ordering",
    "unexpected_eoa_callback": "eoa_assumption",
    "eoa_assumption": "eoa_assumption",
}


def _family(cls):
    return CLASS_TO_FAMILY.get((cls or "").lower(), "")


def _family_from_name(name):
    base = os.path.basename(name)
    for prefix, fam in PREFIX_TO_FAMILY.items():
        if base.startswith(prefix):
            return fam
    return ""


def collect(read_only="v2"):
    """Every labelled twin on disk, as {path: entry}."""
    out = {}

    b50 = os.path.join(HERE, "benchmark_50.json")
    if os.path.exists(b50):
        for name, meta in json.load(open(b50)).items():
            if name == "_README":
                continue
            fam = _family_from_name(name) or _family(meta.get("class"))
            # The corpus read-only contracts predate the v2 family and cover
            # the same ground. Counting both puts the family at 24 where the
            # paper reports 16, so only one source is used.
            if fam == "read_only" and read_only == "v2":
                continue
            expected = meta.get("verdict", "")
            out[f"contracts/corpus/{name}"] = {
                "family": fam,
                "arm": "general",
                "label": "unsafe" if expected == "BUG_FOUND" else "safe",
                "expected": expected,
                "property": meta.get("property", ""),
            }

    # The v2 read-only family supersedes the read-only entries of
    # rq1_twins.json: the originals cannot discriminate under Lemma 1, so
    # keeping both would double-count the family and carry twins that no
    # verdict can separate.
    v2 = os.path.join(HERE, "rq1_twins_v2.json")
    has_v2 = os.path.exists(v2) and read_only in ("v2", "both")

    r1 = os.path.join(HERE, "rq1_twins.json")
    if os.path.exists(r1):
        for path, meta in json.load(open(r1)).items():
            if path == "_README":
                continue
            fam = _family(meta.get("pattern"))
            if has_v2 and fam == "read_only":
                continue
            out[path] = {
                "family": fam,
                "arm": "fixed",
                "label": meta.get("label", ""),
                "expected": meta.get("expected", ""),
                "property": meta.get("property", ""),
            }

    if has_v2:
        for path, meta in json.load(open(v2)).items():
            if path == "_README":
                continue
            out[path] = {
                "family": _family(meta.get("pattern")),
                "arm": meta.get("arm", "fixed"),
                "label": meta.get("label", ""),
                "expected": meta.get("expected", ""),
                "property": meta.get("property", ""),
            }
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--read-only", default="v2",
                    choices=("v2", "corpus", "both"),
                    help="which read-only twins count toward the family: the "
                         "v2 family that discriminates under Lemma 1 "
                         "(default), the original corpus contracts, or both")
    ap.add_argument("--emit", default="",
                    help="write a combined RQ1 manifest to this path")
    args = ap.parse_args()

    found = collect(args.read_only)
    missing_file = [p for p in found if not os.path.exists(os.path.join(HERE, p))]

    counts = {}
    for meta in found.values():
        fam = meta["family"] or "(unmapped)"
        s, u = counts.get(fam, (0, 0))
        if meta["label"] == "safe":
            s += 1
        else:
            u += 1
        counts[fam] = (s, u)

    print(f"{'family':22s} {'have s/u':>10s} {'paper s/u':>10s} {'gap':>8s}")
    tot_have = tot_need = 0
    for fam, (ns, nu) in PAPER.items():
        hs, hu = counts.get(fam, (0, 0))
        gap = (hs + hu) - (ns + nu)
        tot_have += hs + hu
        tot_need += ns + nu
        flag = "" if gap == 0 else ("  <-- SHORT" if gap < 0 else "  <-- extra")
        print(f"{fam:22s} {f'{hs}/{hu}':>10s} {f'{ns}/{nu}':>10s} "
              f"{gap:+8d}{flag}")
    for fam, (hs, hu) in sorted(counts.items()):
        if fam not in PAPER:
            print(f"{fam:22s} {f'{hs}/{hu}':>10s} {'-':>10s} {'':>8s}"
                  "  <-- not a paper family")
    print(f"\ntotal on disk {tot_have}, paper reports {tot_need}, "
          f"short by {tot_need - tot_have}")
    if missing_file:
        print(f"\nmanifest entries with no file ({len(missing_file)}):")
        for p in missing_file[:10]:
            print("  ", p)

    if args.emit:
        payload = {"_README": "Combined RQ1 manifest: general-arm twins from "
                              "benchmark_50.json and fixed-form twins from "
                              "rq1_twins.json, tagged by paper family."}
        for path, meta in sorted(found.items()):
            if path in missing_file:
                continue
            payload[path] = {
                "pair": meta["family"] + ":" + os.path.basename(path),
                "pattern": meta["family"],
                "arm": meta["arm"],
                "label": meta["label"],
                "expected": meta["expected"],
                "property": meta["property"],
            }
        with open(os.path.join(HERE, args.emit), "w") as fh:
            json.dump(payload, fh, indent=1)
        print(f"\nwrote {args.emit} with {len(payload) - 1} contract(s)")


if __name__ == "__main__":
    main()
