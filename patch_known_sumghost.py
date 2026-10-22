import shutil
P = "aegis/compiler.py"
shutil.copy(P, P + ".bak_known")
s = open(P).read()

# The q() qualifier only v-prefixes identifiers in known_idents. The mapping-sum
# ghosts _sum_<m> are missing, so they stay bare and become "Undeclared
# identifier" in OBL_pre/cb/post (which reference the invariant using _sum_m).
# Add a _sum_<m> ghost name for every mapping storage var to known_idents.
old = '''    known_idents = list(facts.storage_vars) + [_CANON_GHOST, _CANON_FLAG, "snapPre"]'''
new = '''    _sum_ghost_idents = ["_sum_" + v for v in facts.storage_vars]
    known_idents = (list(facts.storage_vars) + [_CANON_GHOST, _CANON_FLAG, "snapPre"]
                    + _sum_ghost_idents)'''
if old not in s:
    raise SystemExit("known_idents anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched: _sum_<m> ghosts added to known_idents (q() will v-prefix them)")
