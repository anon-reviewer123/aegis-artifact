"""Batch AST-level diagnosis across all real-world contracts (cheap: analysis
only, no LLM, no solver). Maps what each contract needs before any pipeline run.

    cd ~/Downloads/aegis_dist
    python3 batch_diagnose.py contracts/realworld
or point at the subset dir:
    python3 batch_diagnose.py ~/Downloads/rw10_subset/rw10
"""
import sys, os, glob
from aegis import ast_analysis, static_analysis

d = sys.argv[1] if len(sys.argv) > 1 else "contracts/realworld"
files = sorted(glob.glob(os.path.join(d, "*.sol")))
files = [f for f in files if not f.endswith(".harness.sol")]

def classify(facts):
    if facts is None:
        return "AST-FAIL"
    sites = [s for s in facts.exposure_sites if s.exposed_storage]
    if not sites:
        return "OUT-OF-SCOPE (no value-call site w/ accounting)"
    # per-account if any exposed var is a mapping/struct
    vt = facts.var_types or {}
    exposed = set()
    for s in sites:
        exposed |= set(s.exposed_storage)
    per_acct = any("mapping" in vt.get(v, "") or "struct" in vt.get(v, "")
                   for v in exposed)
    if per_acct:
        return "PER-ACCOUNT (needs quantified template)"
    return "IN-SCOPE scalar (existing templates)"

print(f"{'contract file':42s} {'AST':5s} {'name':16s} verdict")
print("=" * 110)
for f in files:
    base = os.path.basename(f)[:40]
    try:
        facts = ast_analysis.analyze_ast(f)
    except Exception as e:
        facts = None
    name = facts.contract if facts else "-"
    verdict = classify(facts)
    ast_ok = "OK" if facts else "FAIL"
    print(f"{base:42s} {ast_ok:5s} {name:16s} {verdict}")
    if facts:
        for s in facts.exposure_sites:
            if s.exposed_storage:
                print(f"    site {s.function:18s} {s.call:8s} "
                      f"exposed={sorted(s.exposed_storage)}")
    elif hasattr(ast_analysis, "LAST_SOLC_ERROR") and ast_analysis.LAST_SOLC_ERROR:
        print(f"    solc: {ast_analysis.LAST_SOLC_ERROR.strip().splitlines()[0][:90]}")
