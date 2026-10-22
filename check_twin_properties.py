#!/usr/bin/env python3
"""Report twin pairs whose two members are checked against different targets.

A pair is meant to differ only in the mechanism that makes one member safe. If
the safe member is also verified against a weaker property than its partner is
refuted against, the comparison is not controlled and the family's numbers do
not mean what the table says they mean.

  python3 check_twin_properties.py
  python3 check_twin_properties.py --manifest benchmark_50.json
"""
import argparse
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default="benchmark_50.json")
    args = ap.parse_args()

    d = json.load(open(os.path.join(HERE, args.manifest)))
    d.pop("_README", None)
    pairs = collections.defaultdict(dict)
    for name, meta in d.items():
        m = re.match(r"(.+?)_([SU])(\d+)\.sol$", name)
        if m:
            pairs[(m.group(1), m.group(3))][m.group(2)] = meta.get("property", "")

    complete = {k: v for k, v in pairs.items() if "S" in v and "U" in v}
    bad = {k: v for k, v in complete.items() if v["S"] != v["U"]}

    print(f"{args.manifest}: {len(complete)} complete pair(s), "
          f"{len(bad)} with mismatched targets")
    for (fam, idx), v in sorted(bad.items()):
        print(f"\n  {fam}_{idx}")
        print(f"     safe   : {v['S']}")
        print(f"     unsafe : {v['U']}")
    if not bad:
        print("\nevery pair shares one target property")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
