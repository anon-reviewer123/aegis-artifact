import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze

root = sys.argv[1]
scope = json.load(open(os.path.join(root, "scope_v2.json")))
def num(f, v):
    t = (f.var_types.get(v, "uint256") or "uint256")
    return t.startswith("uint") or t.startswith("int")

cross = []
for a in scope["in_scope"]:
    p = os.path.join(root, "contracts", a + ".sol")
    try:
        f = analyze(p)
    except Exception:
        continue
    if not f.exposure_sites:
        continue
    s = f.exposure_sites[0]
    after = [v for v in s.write_after_call if num(f, v)]
    before = [v for v in s.write_before_call if num(f, v)]
    pairs = [(x, y) for x in before for y in after if x != y]
    if not pairs:
        continue
    src = open(p).read()
    # exclude eth-model / nonlinear regions to keep it sound
    fn = re.search(r"function\s+%s\b" % re.escape(s.function), src)
    region = src[fn.start():fn.start()+1200] if fn else ""
    if "_ethBal" in [v for pr in pairs for v in pr] or "address(this).balance" in src:
        continue
    if re.search(r"\.(mul|div)\s*\(|swapTokensFor|getAmountsOut", region):
        continue
    a_, b_ = pairs[0]
    cross.append({"address": a, "function": s.function,
                  "property": f"{a_} == {b_}"})

json.dump(cross, open(os.path.join(root, "cross_clean.json"), "w"), indent=1)
print("clean cross-variable contracts:", len(cross))
for c in cross[:12]:
    print(" ", c["address"][:12], "|", c["function"], "|", c["property"])
