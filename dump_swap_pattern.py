import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze
root = sys.argv[1]
scope = json.load(open(os.path.join(root, "scope_v2.json")))
# find the canonical swapAndLiquify-style contracts and dump the exposed fn +
# what public functions the closure re-enters
shown = 0
for a in scope["in_scope"]:
    p = os.path.join(root, "contracts", a + ".sol")
    try: 
        src = open(p).read(); f = analyze(p)
    except Exception: continue
    if "swapTokensForETH" not in src and "swapExactTokensForETH" not in src:
        continue
    if not f.exposure_sites: continue
    s = f.exposure_sites[0]
    print("="*70)
    print(a[:14], "| site:", s.function, "| closure:",
          sorted(f.conservative_closure(s))[:6])
    # show the exposed function body
    fn = re.search(r"function\s+%s\b" % re.escape(s.function), src)
    if fn:
        body = src[fn.start():fn.start()+600]
        print(body)
    shown += 1
    if shown >= 2: break
