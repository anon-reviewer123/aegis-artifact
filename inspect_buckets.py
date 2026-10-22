import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze

root = sys.argv[1]
prone = [json.loads(l)["address"] for l in open(os.path.join(root, "census.jsonl"))
         if json.loads(l).get("callback_prone")]

def bucket(a):
    p = os.path.join(root, "contracts", a + ".sol")
    src = open(p, errors="ignore").read()
    f = analyze(p)
    window = bool(f.exposure_sites) and any(s.write_after_call for s in f.exposure_sites)
    swap = bool(re.search(r"swapExactTokensForETH|swapTokensForETH|swapBack", src))
    fee = bool(re.search(r"_taxFee|_redisFee|taxAmount|takeFee", src))
    lowlevel_eth = bool(re.search(r"\.call\{value:|\.transfer\(|\.send\(", src))
    mapping_bal = "mapping(address => uint256)" in src and "balanceOf" in src
    if window: return "HAS_REAL_WINDOW", src
    if swap and fee: return "tax_token_swap_no_window", src
    if lowlevel_eth and mapping_bal: return "eth_withdraw_pattern", src
    return "other", src

target = sys.argv[2]
shown = 0
for a in prone:
    try:
        b, src = bucket(a)
    except Exception:
        continue
    if b != target:
        continue
    # find the function with the .call{value} / transfer and show it
    m = re.search(r"function\s+\w+[^{]*\{[^}]*?(\.call\{value:|\.transfer\(|\.send\()",
                  src, re.S)
    print("="*64, "\n", a[:12])
    if m:
        start = src.rfind("function", 0, m.start()+9)
        print(src[start:start+520])
    shown += 1
    if shown >= 4:
        break
