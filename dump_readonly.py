import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze

root = sys.argv[1]
targets = sys.argv[2:]  # addresses (prefixes) to dump

def find(addr_prefix):
    for fn in os.listdir(os.path.join(root, "contracts")):
        if fn.startswith(addr_prefix):
            return os.path.join(root, "contracts", fn)
    return None

for tp in targets:
    p = find(tp)
    if not p:
        print(tp, "not found"); continue
    src = open(p, errors="ignore").read()
    f = analyze(p)
    s = f.exposure_sites[0]
    exposed = s.write_before_call | s.write_after_call
    if s.function in f.functions:
        fi = f.functions[s.function]
        exposed |= (set(fi.reads) & set(fi.writes))
    print("="*66)
    print(tp, "| exposed site:", s.function, "| call:", s.call)
    print("   exposed state:", sorted(exposed)[:6])
    # dump the exposed function body head
    m = re.search(r"function\s+%s\b" % re.escape(s.function), src)
    if m:
        print("   --- exposed function ---")
        print("  ", src[m.start():m.start()+360].replace("\n","\n   "))
    # dump one view that reads exposed state
    for vm in re.finditer(r"function\s+(\w+)\s*\([^)]*\)\s*(?:external|public)\s*view[^{]*\{", src):
        body = src[vm.end():vm.end()+260]
        if any(re.search(r"\b%s\b"%re.escape(v), body) for v in exposed):
            print("   --- view reading exposed state:", vm.group(1), "---")
            print("  ", src[vm.start():vm.start()+300].replace("\n","\n   "))
            break
