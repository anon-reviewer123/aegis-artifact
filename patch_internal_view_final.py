import shutil, re

# Emit the read-only view obligation's check() INSIDE the harness contract so all
# calls are internal -- SMTChecker havocs EXTERNAL view returns (v.g()), yielding
# UNKNOWN on the differential check. Internal calls let the solver track the state
# change across endExposed and decide VERIFIED (safe) / FAILED (unsafe).

P = "aegis/compiler.py"
shutil.copy(P, P + ".bak_intviewfinal")
s = open(P).read()

if "_wrap_internal" in s:
    print("internal wrap already present; skip")
else:
    anchor = "def _wrap(inner_body: str, inner_name: str, check_fn: str) -> str:"
    helper = '''def _wrap_internal(inner_body: str, inner_name: str, check_fn: str) -> str:
    """Inject check() INSIDE the harness contract so view/endExposed calls and
    storage reads are INTERNAL. SMTChecker can then reason about the state change
    across the settle instead of havoc'ing external return values. Strips `v.`;
    public state-variable getters (exposed/inFlight/snapPre/_sum_*) become bare
    names, while real view functions keep their call parentheses."""
    import re as _re
    internal_check = _re.sub(r"\\bv\\.", "", check_fn)
    for _var in ("exposed", "inFlight", "snapPre"):
        internal_check = _re.sub(rf"\\b{_var}\\(\\)", _var, internal_check)
    internal_check = _re.sub(r"\\b(_sum_\\w+)\\(\\)", r"\\1", internal_check)
    idx = inner_body.rstrip().rfind("}")
    if idx == -1:
        return _wrap(inner_body, inner_name, check_fn)
    injected = inner_body[:idx] + internal_check + "\\n" + inner_body[idx:]
    return f"""{_HEADER}
{injected}
"""


def _wrap(inner_body: str, inner_name: str, check_fn: str) -> str:'''
    s = s.replace(anchor, helper, 1)

    old_emit = '''                    harness_source=_wrap(_trim_harness(body, {"beginExposed", "endExposed", g}),
                                         H, template.view_check('''
    new_emit = '''                    harness_source=_wrap_internal(_trim_harness(body, {"beginExposed", "endExposed", g}),
                                         H, template.view_check('''
    if old_emit not in s:
        raise SystemExit("view emission anchor missing")
    s = s.replace(old_emit, new_emit)
    open(P, "w").write(s)
    print("patched compiler.py: view obligation uses _wrap_internal (internal calls)")
