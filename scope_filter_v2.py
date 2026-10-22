import json
import os
import re
import sys
import random
import collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aegis.static_analysis import analyze


def numeric_type(t):
    return t.startswith("uint") or t.startswith("int")


def in_scope(facts):
    if not facts.exposure_sites:
        return False, "no_exposure_site"
    best = None
    for s in facts.exposure_sites:
        num_after = {v for v in s.write_after_call
                     if numeric_type(facts.var_types.get(v, "uint256"))}
        num_before = {v for v in s.write_before_call
                      if numeric_type(facts.var_types.get(v, "uint256"))}
        if num_after and (num_before or num_after):
            best = s
            break
    if best is None:
        return False, "no_exposed_window"
    nums = [v for v in facts.storage_vars
            if numeric_type(facts.var_types.get(v, "uint256"))
            and "mapping" not in facts.var_types.get(v, "")]
    map_nums = [v for v in facts.storage_vars
                if facts.var_types.get(v, "").startswith("mapping")
                and numeric_type(facts.var_types.get(v, "").split("=>")[-1]
                                 .strip().rstrip(")"))]
    if len(nums) + len(map_nums) < 2:
        return False, "no_linear_anchor"
    return True, "ok"


def main():
    root = sys.argv[1]
    contracts_dir = os.path.join(root, "contracts")
    census = None
    for cand in ("census.jsonl", os.path.join("..", "census.jsonl")):
        if os.path.exists(os.path.join(root, cand)):
            census = os.path.join(root, cand)
            break
    if census:
        addrs = [json.loads(l)["address"] for l in open(census)
                 if json.loads(l).get("callback_prone")]
    else:
        addrs = [f[:-4] for f in os.listdir(contracts_dir)
                 if f.endswith(".sol")]

    reasons = collections.Counter()
    scope = []
    for i, a in enumerate(addrs):
        p = os.path.join(contracts_dir, a + ".sol")
        if not os.path.exists(p):
            reasons["missing"] += 1
            continue
        try:
            facts = analyze(p)
        except Exception as e:
            reasons["analyze_error"] += 1
            continue
        ok, why = in_scope(facts)
        reasons[why] += 1
        if ok:
            scope.append(a)
        if (i + 1) % 100 == 0:
            print(f"  ...{i+1} processed, {len(scope)} in scope", flush=True)

    print("in scope:", len(scope))
    for k, v in reasons.most_common():
        print(f"  {k:20s} {v}")
    rng = random.Random(42)
    n = min(220, len(scope))
    sample = sorted(rng.sample(scope, n)) if scope else []
    json.dump({"seed": 42, "in_scope_total": len(scope),
               "in_scope": sorted(scope), "sample": sample},
              open(os.path.join(root, "scope_v2.json"), "w"), indent=1)
    print("sampled:", len(sample), "-> scope_v2.json")


if __name__ == "__main__":
    main()
