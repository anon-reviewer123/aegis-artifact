import shutil
P = "aegis/harness_synth.py"
shutil.copy(P, P + ".bak_xknown")
s = open(P).read()

# The promoted cross-phase locals become harness fields, so _resolve_unbound must
# treat them as KNOWN (else it re-declares them -> duplicate declaration). Extract
# the promoted names from _xphase_decls and add them to _known before the call.
old = '''    begin_body, end_body, _xphase_decls = _promote_cross_phase_locals(
        begin_body, end_body)
    _extra_decls, (begin_body, end_body, callback_stubs, view_funcs) = _resolve_unbound('''
new = '''    begin_body, end_body, _xphase_decls = _promote_cross_phase_locals(
        begin_body, end_body)
    import re as _re_xp
    _xphase_names = set(_re_xp.findall(r"public (\\w+);", _xphase_decls))
    _known = _known | _xphase_names
    _extra_decls, (begin_body, end_body, callback_stubs, view_funcs) = _resolve_unbound('''
if old not in s:
    raise SystemExit("xphase/resolve anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched: promoted cross-phase locals added to _known (no duplicate decl)")
