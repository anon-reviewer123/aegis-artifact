import json, sys, os, re
root = sys.argv[1]
prone = [json.loads(l)["address"] for l in open(os.path.join(root, "census.jsonl"))
         if json.loads(l).get("callback_prone")]
guarded = multi_pub_shared = has_views_on_state = has_invariant = 0
guard_but_partial = 0
for a in prone:
    try: src = open(os.path.join(root,"contracts",a+".sol"),errors="ignore").read()
    except: continue
    has_guard = bool(re.search(r"nonReentrant|_status\s*==|_reentrancyGuard|locked\s*=", src))
    # count external/public state-mutating functions
    pubfns = re.findall(r"function\s+\w+\s*\([^)]*\)\s*(?:external|public)[^{]*\{", src)
    # views over mapping/state
    views = re.findall(r"function\s+\w+\s*\([^)]*\)\s*(?:external|public)\s*view", src)
    # a supply/balance invariant candidate
    inv = ("totalSupply" in src and "mapping(address => uint256)" in src) \
          or ("reserve" in src.lower() and "balanceOf" in src)
    if has_guard: guarded += 1
    if has_guard and len(pubfns) >= 3: guard_but_partial += 1   # guard + many entry points = closure question
    if len(views) >= 2: has_views_on_state += 1
    if inv: has_invariant += 1
n=len(prone)
print("callback-prone:", n)
print(f"  have a reentrancy guard:              {guarded:5d} ({100*guarded/n:.0f}%)   <- Pivot A universe")
print(f"  guard + >=3 public entry points:      {guard_but_partial:5d} ({100*guard_but_partial/n:.0f}%)  <- guard-sufficiency question")
print(f"  >=2 public view functions on state:   {has_views_on_state:5d} ({100*has_views_on_state/n:.0f}%)  <- Pivot B (read-only reentrancy)")
print(f"  has supply/reserve invariant:         {has_invariant:5d} ({100*has_invariant/n:.0f}%)  <- Pivot C (invariant preservation)")
