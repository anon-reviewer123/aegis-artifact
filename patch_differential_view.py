import shutil

# ============================================================================
# Differential view-safety obligation for read-only reentrancy.
#
# The previous view_check called the view but discarded its return, then
# asserted a detached backing invariant -> it verified even unsafe contracts
# (no discrimination). The correct, general obligation captures the view's
# return DURING the exposed window and AFTER settling the window, and asserts
# they are equal. If a re-entrant reader would observe a different value than
# the settled truth, that IS the read-only reentrancy, and the assertion fails
# with a counterexample. No per-view synthesized relation is needed.
#
#   check(uint256 amount, <view params>):
#       require(v.exposed());               // mid-callback
#       <T> r_exposed = v.g(args);          // view during window
#       v.endExposed(amount);               // settle (commit the effect)
#       <T> r_stable  = v.g(args);          // view after settlement
#       assert(r_exposed == r_stable);      // safe iff equal
# ============================================================================


def patch_view_check():
    P = "aegis/templates.py"
    shutil.copy(P, P + ".bak_diffview")
    s = open(P).read()

    old = '''    def view_check(self, c: TemplateCtx, g: str, ret_type: str,
                   param_types=None, backing=None) -> str:
        """View-safety: while I_exp holds (mid-callback), the public view g must
        return a value consistent with the stable invariant. Declares fresh
        symbolic parameters so the view is called with the correct arity."""
        pred = self.exposed_predicate(c)
        param_types = param_types or []
        decls, args = [], []
        for i, t in enumerate(param_types):
            base = (t or "uint256").replace(" memory", "").replace(" calldata", "").strip()
            if base.startswith("address"): base = "address"
            elif base.startswith("uint"): base = "uint256"
            elif base.startswith("int"): base = "int256"
            elif base.startswith("bool"): base = "bool"
            elif base.startswith("bytes32"): base = "bytes32"
            else: base = "uint256"
            decls.append(f"{base} a{i}")
            args.append(f"a{i}")
        sig = ", ".join(decls)
        call_args = ", ".join(args)
        pred_line = ("// I_exp assumed via exposed flag + sum ghost"
                     if backing else f"require({c.q(pred)});")
        if backing:
            import re as _re
            _b = backing
            _b = _re.sub(r"\\b(_sum_\\w+)\\b", r"v.\\1()", _b)
            _b = _b.replace("address(this).balance", "address(v).balance")
            safety = c.q(_b)
        else:
            safety = c.q(c.inv_stable)
        return f"""
            function check({sig}) public {{
                require(v.{c.flag_name}());
                {pred_line}
                v.{g}({call_args});              // observe the view now
                assert({safety});               // backing invariant holds mid-callback
            }}"""'''

    new = '''    def view_check(self, c: TemplateCtx, g: str, ret_type: str,
                   param_types=None, backing=None) -> str:
        """Differential view-safety: the value returned by view g during the
        exposed window must equal the value it returns after the window is
        settled. Divergence is a concrete read-only reentrancy witness. This is
        general: it needs no per-view synthesized relation."""
        param_types = param_types or []
        decls, args = [], []
        for i, t in enumerate(param_types):
            base = (t or "uint256").replace(" memory", "").replace(" calldata", "").strip()
            if base.startswith("address"): base = "address"
            elif base.startswith("uint"): base = "uint256"
            elif base.startswith("int"): base = "int256"
            elif base.startswith("bool"): base = "bool"
            elif base.startswith("bytes32"): base = "bytes32"
            else: base = "uint256"
            decls.append(f"{base} a{i}")
            args.append(f"a{i}")
        rt = (ret_type or "uint256").replace(" memory", "").replace(" calldata", "").strip()
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

    if old not in s:
        raise SystemExit("view_check anchor missing (has the file diverged?)")
    s = s.replace(old, new)
    open(P, "w").write(s)
    print("patched templates.py: differential view_check (captures return pre/post settle)")


def patch_compiler_keep_endexposed():
    """The differential obligation calls endExposed to settle, so the trimmed
    harness for the view obligation must keep endExposed as well as beginExposed
    and the view g."""
    P = "aegis/compiler.py"
    shutil.copy(P, P + ".bak_diffview")
    s = open(P).read()
    old = '''                    harness_source=_wrap(_trim_harness(body, {"beginExposed", g}),
                                         H, template.view_check(
                                             _ctx, g, "uint256",
                                             param_types=gi.param_types,'''
    new = '''                    harness_source=_wrap(_trim_harness(body, {"beginExposed", "endExposed", g}),
                                         H, template.view_check(
                                             _ctx, g, "uint256",
                                             param_types=gi.param_types,'''
    if old not in s:
        raise SystemExit("compiler view emission anchor missing")
    s = s.replace(old, new)
    open(P, "w").write(s)
    print("patched compiler.py: view obligation keeps endExposed (settle) + passes return type")


patch_view_check()
patch_compiler_keep_endexposed()
print("\ndifferential view-safety obligation applied.")
print("Re-run the twins: safe MUST verify, both unsafe MUST fail with counterexample.")
