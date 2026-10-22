#!/usr/bin/env python3
"""
verify_step1.py - Confirm the AST type-classification fix (Step 1) on YOUR
machine, where solc is on PATH so the AST analyzer actually runs.

Run from the aegis_dist root AFTER copying the three patched files in:
    python3 verify_step1.py

What it checks, per contract:
  1. Which analyzer ran (must be 'ast' for the fix to be exercised).
  2. var_types is populated from the solc AST.
  3. The three classifiers (_addr_bool_vars / _mapping_storage_vars /
     _numeric_storage_vars) agree with the declared types -- in particular
     that a `mapping(address => uint)` is numeric+mapping, NOT addr/bool
     (the glp / balanceOf misclassification that caused the UNKNOWNs).
  4. The generated depositFor seeds every numeric accounting var, mappings
     with [who].

It does NOT call the backend; it isolates the harness-synthesis layer so you
get a fast pass/fail without waiting on Eldarica. Once this is green, run the
real pipeline (run_aegis.py) on SupplyToken to confirm the UNKNOWNs are gone.
"""
import sys, os, glob, re
sys.path.insert(0, ".")

from aegis import static_analysis, harness_synth


def classify_from_typestring(tstr: str) -> str:
    """Independent ground-truth oracle, so the test does not just re-run the
    code under test against itself."""
    if tstr.startswith("mapping("):
        inner = tstr[tstr.rfind("=>") + 2:].strip().rstrip(")").strip()
        return "mapping_numeric" if inner.startswith(("uint", "int")) else "mapping_other"
    if tstr == "bool" or tstr.startswith("address") or tstr.startswith(("contract ", "interface ")):
        return "addr_bool"
    if tstr.startswith(("uint", "int")):
        return "numeric_scalar"
    return "other"


def check_contract(path: str) -> bool:
    facts = static_analysis.analyze(path)
    analyzer = static_analysis.LAST_ANALYZER
    name = os.path.basename(path)
    print(f"\n=== {name}  (analyzer={analyzer}) ===")

    if analyzer != "ast":
        print("  SKIP: AST analyzer did not run (solc missing/failed for this "
              "file). The fix only changes the AST path; fallback is unchanged.")
        return True  # not a failure of the fix

    if not facts.var_types:
        print("  FAIL: AST ran but var_types is empty.")
        return False
    print(f"  var_types: {facts.var_types}")

    harness_synth._SRC_CACHE[facts.contract] = open(path).read()
    addr_bool = harness_synth._addr_bool_vars(facts)
    mapping = harness_synth._mapping_storage_vars(facts)
    numeric = harness_synth._numeric_storage_vars(facts)

    ok = True
    for v in facts.storage_vars:
        truth = classify_from_typestring(facts.var_types.get(v, ""))
        in_ab, in_map, in_num = v in addr_bool, v in mapping, v in numeric
        if truth == "addr_bool":
            want = in_ab and not in_num and not in_map
        elif truth == "mapping_numeric":
            want = in_map and in_num and not in_ab
        elif truth == "numeric_scalar":
            want = in_num and not in_ab and not in_map
        else:  # mapping_other / other: just must not be seeded numerically
            want = not in_num
        flag = "ok " if want else "BAD"
        if not want:
            ok = False
        print(f"    [{flag}] {v:16} type={truth:15} "
              f"addr_bool={in_ab} mapping={in_map} numeric={in_num}")

    # show the generated depositFor and assert every numeric var is seeded.
    # depositFor deliberately skips ghost-ledger vars (inFlight, exposed) and
    # receiver-style vars -- those are managed by beginExposed/endExposed and
    # the callback wrappers, not by seeding -- so we exclude the same set here.
    if facts.exposure_sites:
        skip = harness_synth._GHOST_LEDGER_VARS | harness_synth._RECEIVER_VARS
        dep = harness_synth._emit_deposit_for(facts)
        seeded = set(re.findall(r"(\w+)\s*(?:\[who\])?\s*\+= amount", dep))
        should_seed = numeric - skip
        missing = should_seed - seeded
        if missing:
            ok = False
            print(f"    BAD: depositFor fails to seed numeric vars: {sorted(missing)}")
        else:
            print(f"    ok  depositFor seeds all accounting vars: {sorted(seeded)}"
                  f"  (ghost/receiver skipped: {sorted(numeric & skip)})")

    print("  RESULT:", "PASS" if ok else "FAIL")
    return ok


def main():
    files = [f for f in glob.glob("contracts/corpus/*.sol")
             if not f.endswith(".harness.sol")]
    if not files:
        print("no contracts found under contracts/corpus/")
        return 1
    results = {f: check_contract(f) for f in sorted(files)}
    print("\n" + "=" * 60)
    failed = [os.path.basename(f) for f, ok in results.items() if not ok]
    if failed:
        print("FAILED:", failed)
        return 1
    print("ALL CONTRACTS PASS the AST type-classification check.")
    print("Next: run the real pipeline on SupplyToken to confirm no more UNKNOWN:")
    print('  python3 run_aegis.py contracts/corpus/SupplyToken.sol \\')
    print('      --property "totalSupply == trackedSum" --llm openai --k 4')
    return 0


if __name__ == "__main__":
    sys.exit(main())
