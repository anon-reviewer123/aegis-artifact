"""Run on your PC (where solc IS on PATH) to capture WHY the AST analyzer fails
and falls back to the regex path. Usage:
    cd ~/Downloads/aegis_dist
    python3 diagnose_ast.py contracts/realworld/Z4GPresale.sol
"""
import sys, traceback
from aegis import ast_analysis
path = sys.argv[1] if len(sys.argv) > 1 else "contracts/realworld/Z4GPresale.sol"
print(f"=== diagnosing AST analyzer on {path} ===")
try:
    facts = ast_analysis.analyze_ast(path)
    if facts is None:
        print("analyze_ast returned None (silent failure). "
              "Add prints inside analyze_ast to see which step bailed.")
    else:
        print("AST OK. contract:", facts.contract)
        print("var_types:", facts.var_types)
except Exception:
    print("AST raised:")
    traceback.print_exc()
