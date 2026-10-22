import shutil
P = "aegis/compiler.py"
shutil.copy(P, P + ".bak_vtrim")
s = open(P).read()

# Keep the view function g in the trimmed harness so v.g(...) resolves. Also
# make the view obligation's assumed predicate (I_exp) use the sum ghost when an
# exposed mapping exists, by passing a rewritten predicate through _ctx is not
# possible here; instead we keep the mapping's own view AND beginExposed so the
# harness is well-formed, and rely on the backing invariant (which already uses
# v._sum_<m>()) for the actual safety assertion.
old = '''                    harness_source=_wrap(_trim_harness(body, {"beginExposed"}),
                                         H, template.view_check(
                                             _ctx, g, "uint256",
                                             param_types=gi.param_types,
                                             backing=_backing_invariant))))'''
new = '''                    harness_source=_wrap(_trim_harness(body, {"beginExposed", g}),
                                         H, template.view_check(
                                             _ctx, g, "uint256",
                                             param_types=gi.param_types,
                                             backing=_backing_invariant))))'''
if old not in s:
    raise SystemExit("view trim anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("fix: view function kept in trimmed harness (v.g resolves)")
