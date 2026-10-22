import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze

root = sys.argv[1]
prone = [json.loads(l)["address"] for l in open(os.path.join(root, "census.jsonl"))
         if json.loads(l).get("callback_prone")]

# categorize the DOMINANT callback shape per contract, whether or not in-scope
cat = {}
examples = {}
def bump(k, a):
    cat[k] = cat.get(k, 0) + 1
    examples.setdefault(k, [])
    if len(examples[k]) < 3: examples[k].append(a[:10])

for a in prone:
    p = os.path.join(root, "contracts", a + ".sol")
    try:
        src = open(p, errors="ignore").read()
        f = analyze(p)
    except Exception:
        bump("analyze_error", a); continue

    has_site = bool(f.exposure_sites)
    window = has_site and any(s.write_after_call for s in f.exposure_sites)

    # feature flags from source
    swap = bool(re.search(r"swapExactTokensForETH|swapTokensForETH|_swapback|swapBack", src))
    feeonlyxfer = bool(re.search(r"_taxFee|_redisFee|taxAmount|_marketingFee|takeFee", src))
    hook721 = "onERC721Received" in src or "_safeMint" in src
    lowlevel_eth = bool(re.search(r"\.call\{value:|\.transfer\(|\.send\(", src))
    reentrancy_guard = "nonReentrant" in src or "_status" in src or "locked" in src
    mapping_bal = "mapping(address => uint256)" in src and "balanceOf" in src

    if window:
        bump("HAS_REAL_WINDOW", a)
    elif swap and feeonlyxfer:
        bump("tax_token_swap_no_window", a)
    elif hook721:
        bump("erc721_hook_CEI", a)
    elif swap:
        bump("swap_no_fee_no_window", a)
    elif lowlevel_eth and mapping_bal:
        bump("eth_withdraw_pattern", a)
    elif lowlevel_eth:
        bump("bare_eth_transfer", a)
    elif not has_site:
        bump("no_site_detected", a)
    else:
        bump("other_windowless", a)

print("callback-prone analyzed:", len(prone))
for k, v in sorted(cat.items(), key=lambda x: -x[1]):
    print(f"  {k:28s} {v:5d}  ({100*v/len(prone):.0f}%)   e.g. {examples.get(k,[])}")
