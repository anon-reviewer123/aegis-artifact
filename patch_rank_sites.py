import shutil

P = "aegis/static_analysis.py"
shutil.copy(P, P + ".bak_rank")
s = open(P).read()

helper = '''
def _rank_exposure_sites(facts):
    """Order exposure sites so the pipeline's facts.exposure_sites[0] is the one
    most worth verifying: a genuine exposed window (numeric storage written
    AFTER the external call) ranks above a windowless site (e.g. a bare
    .transfer with nothing after it). Among windowed sites, prefer those with
    writes on BOTH sides of the call, then the larger exposed set. Deterministic
    and stable so repeated runs pick the same site."""
    def _num(v):
        t = (facts.var_types.get(v, "uint256") or "uint256") if getattr(
            facts, "var_types", None) else "uint256"
        return t.startswith("uint") or t.startswith("int")

    def key(s):
        after = [v for v in s.write_after_call if _num(v)]
        before = [v for v in s.write_before_call if _num(v)]
        has_after = bool(after)
        both_sides = bool(after) and bool(before)
        window = len(set(after) | set(before))
        return (has_after, both_sides, window, s.function)

    facts.exposure_sites.sort(key=key, reverse=True)
    return facts

'''

anchor = "def analyze(sol_path: str) -> ContractFacts:"
if "_rank_exposure_sites" in s:
    print("already patched")
else:
    s = s.replace(anchor, helper + "\n" + anchor, 1)
    # AST path
    s = s.replace(
        "            LAST_ANALYZER = \"ast\"\n            return facts",
        "            LAST_ANALYZER = \"ast\"\n"
        "            return _rank_exposure_sites(facts)")
    # regex path final return
    s = s.replace(
        "    return ContractFacts(contract, storage_vars, functions, exposure_sites)",
        "    return _rank_exposure_sites(\n"
        "        ContractFacts(contract, storage_vars, functions, exposure_sites))")
    open(P, "w").write(s)
    print("patched static_analysis.py: exposure sites ranked, windowed first")
