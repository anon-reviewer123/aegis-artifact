import shutil
P = "aegis/templates.py"
shutil.copy(P, P + ".bak_vpred")
s = open(P).read()

# For the view obligation, the assumed precondition (I_exp) may reference an
# exposed mapping as a bare scalar getter (v._deposits()), which is ill-typed.
# Generalize: when a backing invariant is present (mapping-sum case), assume the
# backing invariant's own relation as the precondition context rather than the
# raw I_exp predicate. This is sound: we are checking that, GIVEN we are inside
# the exposed window (exposed flag set) and the sum ghost reflects the mapping,
# the backing invariant holds. We drop the ill-typed raw-mapping require.
old = '''            function check({sig}) public {{
                require(v.{c.flag_name}());
                require({c.q(pred)});           // assume I_exp (mid-callback)
                v.{g}({call_args});              // observe the view now
                assert({safety});               // backing invariant holds mid-callback
            }}"""'''
new = '''            function check({sig}) public {{
                require(v.{c.flag_name}());
                {pred_line}
                v.{g}({call_args});              // observe the view now
                assert({safety});               // backing invariant holds mid-callback
            }}"""'''
if old not in s:
    raise SystemExit("view_check body anchor missing")
s = s.replace(old, new)

# build pred_line: only emit the require(pred) when it does NOT reference a bare
# mapping getter. If backing is present (mapping case), skip the raw predicate.
anchor2 = '''        if backing:
            import re as _re
            _b = backing'''
inject = '''        pred_line = ("// I_exp assumed via exposed flag + sum ghost"
                     if backing else f"require({c.q(pred)});")
        if backing:
            import re as _re
            _b = backing'''
if anchor2 not in s:
    raise SystemExit("backing block anchor missing")
s = s.replace(anchor2, inject)
open(P, "w").write(s)
print("fix: view_check drops ill-typed raw-mapping predicate when backing present")
