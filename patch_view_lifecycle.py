import shutil

# The differential view obligation falsely VERIFIED because check() assumed
# `exposed` without establishing the window, leaving payment/inFlight/totals
# unconstrained -> the solver picks a degenerate no-op state. Fix: run the FULL
# window lifecycle so the settle actually moves state, exposing the read-only
# inconsistency.

def patch_template():
    P = "aegis/templates.py"
    shutil.copy(P, P + ".bak_lifecycle")
    s = open(P).read()

    old = '''        rt = (ret_type or "uint256").replace(" memory", "").replace(" calldata", "").strip()
        extra_sig = "".join(", " + d for d in decls)
        call_args = ", ".join(args)
        return f"""
            function check(uint256 amount{extra_sig}) public {{
                require(v.{c.flag_name}());               // mid-callback (exposed)
                {rt} r_exposed = v.{g}({call_args});       // view during the window
                v.endExposed(amount);                      // settle the window
                {rt} r_stable  = v.{g}({call_args});       // view after settlement
                assert(r_exposed == r_stable);             // read-only safe iff equal
            }}"""'''

    new = '''        rt = (ret_type or "uint256").replace(" memory", "").replace(" calldata", "").strip()
        extra_sig = "".join(", " + d for d in decls)
        call_args = ", ".join(args)
        return f"""
            function check(uint256 amount{extra_sig}) public {{
                require(!v.{c.flag_name}());               // start outside the window
                v.depositFor(address(v), amount);          // seed feasible state
                v.beginExposed(amount);                    // enter the exposed window
                {rt} r_exposed = v.{g}({call_args});       // view DURING the window
                v.endExposed(amount);                      // settle (commit the effect)
                {rt} r_stable  = v.{g}({call_args});       // view AFTER settlement
                assert(r_exposed == r_stable);             // read-only safe iff equal
            }}"""'''

    if old not in s:
        raise SystemExit("view_check differential anchor missing")
    s = s.replace(old, new)
    open(P, "w").write(s)
    print("patched templates.py: differential check runs full window lifecycle")


def patch_compiler_keep_depositfor():
    """The lifecycle check calls depositFor, so keep it in the view trim set."""
    P = "aegis/compiler.py"
    shutil.copy(P, P + ".bak_lifecycle")
    s = open(P).read()
    old = '_trim_harness(body, {"beginExposed", "endExposed", g})'
    new = '_trim_harness(body, {"beginExposed", "endExposed", "depositFor", g})'
    if old not in s:
        raise SystemExit("view trim anchor missing")
    s = s.replace(old, new)
    open(P, "w").write(s)
    print("patched compiler.py: view trim keeps depositFor for lifecycle seeding")


patch_template()
patch_compiler_keep_depositfor()
print("\nlifecycle differential-view applied. Note: _wrap_internal strips v. so the")
print("internal check calls depositFor/beginExposed/endExposed/view directly.")
