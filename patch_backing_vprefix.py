import shutil
P = "aegis/templates.py"
shutil.copy(P, P + ".bak_vprefix")
s = open(P).read()

# The view_check assertion runs in the outer Obligation contract, which accesses
# the harness via `v.`. The backing invariant references _sum_<m> and
# address(this).balance as bare names -- but _sum_<m> is state on the inner
# harness `v`, so it must be called as v._sum_<m>(), and address(this).balance
# must be v-relative too. We rewrite the backing string: _sum_<x> -> v._sum_<x>(),
# and address(this).balance -> address(v).balance.
old = '''        safety = c.q(backing) if backing else c.q(c.inv_stable)'''
new = '''        if backing:
            import re as _re
            _b = backing
            _b = _re.sub(r"\\b(_sum_\\w+)\\b", r"v.\\1()", _b)
            _b = _b.replace("address(this).balance", "address(v).balance")
            safety = c.q(_b)
        else:
            safety = c.q(c.inv_stable)'''
if old not in s:
    raise SystemExit("view_check safety anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched: backing invariant ghosts routed through v.<ghost>() and address(v).balance")
