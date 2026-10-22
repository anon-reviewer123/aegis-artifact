import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze

root = sys.argv[1]
scope = json.load(open(os.path.join(root, "scope_v2.json")))
addrs = scope["in_scope"]

def num(f, v):
    t = (f.var_types.get(v, "uint256") or "uint256")
    return t.startswith("uint") or t.startswith("int")

ethbal = same_real = cross = empty = nonlinear = 0
for a in addrs:
    p = os.path.join(root, "contracts", a + ".sol")
    try:
        f = analyze(p)
    except Exception:
        continue
    if not f.exposure_sites:
        empty += 1
        continue
    s = f.exposure_sites[0]
    after = [v for v in s.write_after_call if num(f, v)]
    before = [v for v in s.write_before_call if num(f, v)]
    if not after:
        empty += 1
        continue
    cross_pair = [(x, y) for x in before for y in after if x != y]
    src = open(p).read()
    # is the window variable an eth-model artifact?
    is_ethbal = any(v == "_ethBal" for v in after) or "address(this).balance" in src
    # does the function body have nonlinear swap math near the call?
    fn = re.search(r"function\s+%s\b" % re.escape(s.function), src)
    region = src[fn.start():fn.start()+1200] if fn else ""
    has_nonlinear = bool(re.search(r"\.(mul|div)\s*\(|[\w\)]\s*[*/]\s*[\w\(]", region)) \
                    or "swapTokensFor" in region or "getAmountsOut" in region
    if cross_pair:
        cross += 1
    elif is_ethbal or has_nonlinear:
        nonlinear += 1
    else:
        same_real += 1

print("in-scope total:", len(addrs))
print("  cross-variable (real):        ", cross)
print("  same-variable REAL accounting:", same_real)
print("  eth-model / nonlinear swap:   ", nonlinear, "  <- likely NOT soundly verifiable")
print("  empty window at site[0]:      ", empty)
