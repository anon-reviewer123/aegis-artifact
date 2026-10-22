import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze
root = sys.argv[1]
prone = [json.loads(l)["address"] for l in open(os.path.join(root, "census.jsonl"))
         if json.loads(l).get("callback_prone")]
shown = 0
for a in prone:
    p = os.path.join(root, "contracts", a + ".sol")
    try:
        src = open(p, errors="ignore").read(); f = analyze(p)
    except Exception:
        continue
    # need: an external call site (callback) AND a public view reading state
    # that the surrounding function writes.
    if not f.exposure_sites:
        continue
    s = f.exposure_sites[0]
    exposed = s.write_before_call | s.write_after_call | (
        set(f.functions[s.function].reads) & set(f.functions[s.function].writes)
        if s.function in f.functions else set())
    if not exposed:
        continue
    # find public view functions that read any exposed var
    views = []
    for m in re.finditer(r"function\s+(\w+)\s*\([^)]*\)\s*(?:external|public)\s*view[^{]*\{", src):
        vname = m.group(1)
        body_start = m.end()
        body = src[body_start:body_start+400]
        if any(re.search(r"\b%s\b" % re.escape(v), body) for v in exposed):
            views.append(vname)
    if not views:
        continue
    print("="*60)
    print(a[:12], "| site:", s.function, "| exposed:", sorted(exposed)[:4])
    print("   views reading exposed state:", views[:5])
    shown += 1
    if shown >= 5:
        break
print("shown with real read-only surface:", shown)
