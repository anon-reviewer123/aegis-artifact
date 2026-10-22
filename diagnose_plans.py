import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis.static_analysis import analyze
from aegis import synth, validator


def dump(obj, width=700):
    try:
        d = obj if isinstance(obj, dict) else obj.__dict__
    except Exception:
        return str(obj)[:width]
    return json.dumps(d, default=str, indent=2)[:width]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("contract")
    ap.add_argument("--property", required=True)
    ap.add_argument("--llm", default="openai")
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--show-plans", action="store_true")
    args = ap.parse_args()

    facts = analyze(args.contract)
    if not facts.exposure_sites:
        print("no exposure site")
        return 1
    site = facts.exposure_sites[0]

    print(f"contract       {facts.contract}")
    print(f"site           {site.function}")
    print(f"closure        {sorted(facts.conservative_closure(site))}")
    print(f"write_after    {sorted(site.write_after_call)}")
    print()

    plans = synth.sample_plans(facts, site, args.property,
                               backend=args.llm, k=args.k)
    print(f"plans sampled  {len(plans)}\n")

    tally = collections.Counter()
    for i, p in enumerate(plans):
        if p is None:
            print(f"plan {i}: PARSE FAILED")
            tally["parse_failed"] += 1
            continue
        failed = validator.validate(p, facts, site)
        tally[",".join(failed) if failed else "ACCEPTED"] += 1
        cl = getattr(p, "closure", None)
        pc = sorted(getattr(cl, "functions", []) or [])
        proto = getattr(p, "protocol", None)
        allowed = sorted(getattr(proto, "allowed_callbacks", []) or [])
        inv = getattr(p, "exposure_invariant", None)
        print(f"plan {i}: {'ACCEPTED' if not failed else 'rejected: ' + ','.join(failed)}")
        print(f"  closure      {pc}")
        print(f"  allowed_cb   {allowed}")
        print(f"  exposure_inv {str(getattr(inv, 'formula', inv))[:120]}")
        print(f"  kind         {getattr(inv, 'kind', None)}")
        if args.show_plans:
            print(dump(p))
        print()

    print("summary")
    for k, v in tally.most_common():
        print(f"  {k:40s} {v}")

    cons = sorted(facts.conservative_closure(site))
    print()
    print("validator expects closure to cover:", cons)
    return 0


if __name__ == "__main__":
    sys.exit(main())
