import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze

root = sys.argv[1]
prone = [json.loads(l)["address"] for l in open(os.path.join(root, "census.jsonl"))
         if json.loads(l).get("callback_prone")]

real = 0; examples = []; kinds = {}
for a in prone:
    p = os.path.join(root, "contracts", a + ".sol")
    try:
        src = open(p, errors="ignore").read(); f = analyze(p)
    except Exception:
        continue
    if not f.exposure_sites:
        continue
    s = f.exposure_sites[0]
    exposed = s.write_before_call | s.write_after_call
    if s.function in f.functions:
        fi = f.functions[s.function]
        exposed |= (set(fi.reads) & set(fi.writes))
    if not exposed:
        continue
    # public view reading exposed state
    hit = False
    for m in re.finditer(r"function\s+(\w+)\s*\([^)]*\)\s*(?:external|public)\s*view[^{]*\{", src):
        body = src[m.end():m.end()+400]
        if any(re.search(r"\b%s\b" % re.escape(v), body) for v in exposed):
            hit = True; break
    if not hit:
        continue
    real += 1
    # classify the callback kind
    if "rawFulfillRandomWords" in src or "fulfillRandomWords" in src: k = "VRF_callback"
    elif "receiveFlashLoan" in src or "onFlashLoan" in src or "executeOperation" in src: k = "flashloan_callback"
    elif "withdrawPayments" in src or "_deposits" in src: k = "pullpayment"
    elif "onERC721Received" in src or "onERC1155" in src: k = "token_hook"
    else: k = "other_external_call"
    kinds[k] = kinds.get(k, 0) + 1
    if len(examples) < 10: examples.append((a[:12], s.function, k))

print("callback-prone:", len(prone))
print("with REAL read-only surface (view reads exposed state):", real,
      f"({100*real/len(prone):.0f}%)")
print("by callback kind:")
for k,v in sorted(kinds.items(), key=lambda x:-x[1]):
    print(f"   {k:22s} {v}")
print("examples:")
for e in examples: print("  ", e)
