"""After installing the patched ast_analysis.py, confirm whether the AST path
now works and, if not, show the REAL solc error (no longer swallowed).
    cd ~/Downloads/aegis_dist
    python3 diagnose_ast2.py contracts/realworld/Z4GPresale.sol
"""
import sys
from aegis import ast_analysis
path = sys.argv[1]
facts = ast_analysis.analyze_ast(path)
if facts is not None:
    print("AST OK  contract:", facts.contract)
    print("storage:", facts.storage_vars)
    print("var_types:", facts.var_types)
    print("exposure sites:", [(s.function, s.call) for s in facts.exposure_sites])
else:
    print("AST still None. Captured solc error:")
    print(ast_analysis.LAST_SOLC_ERROR[:1500])
