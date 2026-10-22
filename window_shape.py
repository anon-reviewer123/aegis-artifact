import json, sys, os
sys.path.insert(0, ".")
from aegis.static_analysis import analyze

root = sys.argv[1]
scope = json.load(open(os.path.join(root, "scope_v2.json")))
addrs = scope["in_scope"]
cross = same = nowin = 0
for a in addrs:
    try:
        f = analyze(os.path.join(root, "contracts", a + ".sol"))
    except Exception:
        continue
    has_cross = has_same = False
    for s in f.exposure_sites:
        after = [v for v in s.write_after_call
                 if (f.var_types.get(v, "uint256") or "uint").startswith(("uint", "int"))]
        before = [v for v in s.write_before_call
                  if (f.var_types.get(v, "uint256") or "uint").startswith(("uint", "int"))]
        if not after:
            continue
        if any(a2 != b for a2 in before for b in after):
            has_cross = True
        elif set(after) & set(before) or after:
            has_same = True
    if has_cross:
        cross += 1
    elif has_same:
        same += 1
    else:
        nowin += 1
print(f"in-scope contracts analyzed: {cross+same+nowin}")
print(f"  cross-variable window (A==B, verifiable now): {cross}")
print(f"  same-variable window (needs ghost/conservation): {same}")
print(f"  no numeric window after recheck: {nowin}")
