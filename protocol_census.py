import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze
root = sys.argv[1]
scope = json.load(open(os.path.join(root, "scope_v2.json")))
pat = {
    "uniswapV2_swap": r"swapExactTokensFor|swapTokensForETH|swapExactETHFor|IUniswapV2Router",
    "uniswapV3_swap": r"exactInputSingle|ISwapRouter|IUniswapV3",
    "getAmountsOut":  r"getAmountsOut|getAmountOut",
    "chainlink_oracle": r"latestRoundData|latestAnswer|AggregatorV3",
    "getReserves":    r"getReserves",
    "erc20_transfer": r"\.transfer\(|\.transferFrom\(|safeTransfer",
    "add_liquidity":  r"addLiquidity|addLiquidityETH",
    "balanceOf_self": r"balanceOf\(address\(this\)\)",
}
counts = {k:0 for k in pat}
total = 0
for a in scope["in_scope"]:
    p = os.path.join(root, "contracts", a + ".sol")
    try: src = open(p).read()
    except Exception: continue
    total += 1
    for k, rx in pat.items():
        if re.search(rx, src):
            counts[k] += 1
print("in-scope contracts scanned:", total)
for k, v in sorted(counts.items(), key=lambda x:-x[1]):
    print(f"  {k:20s} {v:4d}  ({100*v/total:.0f}%)")
