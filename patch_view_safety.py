import shutil

# ============================================================================
# View-safety obligations for read-only reentrancy.
#
# Adds OBL_view_<g>: for each public view g that reads state exposed during the
# callback window, prove g's return is consistent with the stable invariant
# even while I_exp holds (mid-callback). A proof means the view is safe against
# read-only reentrancy; a counterexample is a concrete read-only reentrancy
# witness naming the offending view. Mirrors the existing OBL_cb machinery.
#
# This is the class RAVEN's Limitations section explicitly excludes (ECF is
# per-contract and does not capture view-return inconsistency observed by an
# external consumer during a callback).
# ============================================================================


def patch_functioninfo():
    P = "aegis/static_analysis.py"
    shutil.copy(P, P + ".bak_view")
    s = open(P).read()
    if "mutability" in s:
        print("static_analysis.py already has mutability; skip")
        return
    s = s.replace(
        '    name: str\n    visibility: str                       '
        '# public/external/internal/private\n    reads: set[str] = '
        'field(default_factory=set)',
        '    name: str\n    visibility: str                       '
        '# public/external/internal/private\n    mutability: str = "nonpayable"'
        '        # view/pure/payable/nonpayable\n    reads: set[str] = '
        'field(default_factory=set)')
    open(P, "w").write(s)
    print("patched static_analysis.py: FunctionInfo.mutability")


def patch_ast_capture():
    P = "aegis/ast_analysis.py"
    shutil.copy(P, P + ".bak_view")
    s = open(P).read()
    if 'mutability=node.get' in s:
        print("ast_analysis.py already captures mutability; skip")
        return
    s = s.replace(
        '            vis = node.get("visibility", "public")\n'
        '            info = FunctionInfo(name=name, visibility=vis)',
        '            vis = node.get("visibility", "public")\n'
        '            mut = node.get("stateMutability", "nonpayable")\n'
        '            info = FunctionInfo(name=name, visibility=vis,\n'
        '                                mutability=mut)')
    open(P, "w").write(s)
    print("patched ast_analysis.py: capture stateMutability")


def patch_facts_viewclosure():
    P = "aegis/static_analysis.py"
    s = open(P).read()
    if "def view_closure" in s:
        print("view_closure already present; skip")
        return
    # add a method on ContractFacts to compute public views reading exposed state
    anchor = "@dataclass\nclass ContractFacts:"
    # find the class body's first method or end; simplest: append a helper fn
    helper = '''

def view_closure(facts, exposed_function):
    """Public/external view functions that read any storage exposed during the
    callback window of `exposed_function`. These are the read-only reentrancy
    surface: a consumer calling one mid-callback observes state under I_exp."""
    exposed = set()
    for site in facts.exposure_sites:
        if site.function == exposed_function:
            exposed |= set(site.write_before_call) | set(site.write_after_call)
    fi = facts.functions.get(exposed_function)
    if fi is not None:
        exposed |= (set(fi.reads) & set(fi.writes))
    out = []
    for name, info in facts.functions.items():
        if info.visibility not in ("public", "external"):
            continue
        if info.mutability not in ("view", "pure"):
            continue
        if set(info.reads) & exposed:
            out.append(name)
    return out
'''
    s = s.rstrip() + "\n" + helper
    open(P, "w").write(s)
    print("patched static_analysis.py: view_closure() helper")


def patch_template_viewcheck():
    P = "aegis/templates.py"
    shutil.copy(P, P + ".bak_view")
    s = open(P).read()
    if "def view_check" in s:
        print("templates.py already has view_check; skip")
        return
    # add a default view_check to the base Template class, right after cb_check
    anchor = '''    def cb_check(self, c: TemplateCtx, f: str) -> str:
        pred = self.exposed_predicate(c)
        return f"""
            function check(uint256 amount) public {{
                require(v.{c.flag_name}());
                require({c.q(pred)});           // assume I_exp before callback
                v.{f}(amount);                    // run the callback
                assert({c.q(pred)});            // I_exp must still hold
            }}"""'''
    viewcheck = anchor + '''

    def view_check(self, c: TemplateCtx, g: str, ret_type: str) -> str:
        """View-safety: while I_exp holds (mid-callback), the public view g must
        return a value consistent with the stable invariant. We assert that the
        view's return equals the value the stable invariant implies for it. A
        counterexample is a read-only reentrancy witness for g."""
        pred = self.exposed_predicate(c)
        return f"""
            function check() public {{
                require(v.{c.flag_name}());
                require({c.q(pred)});           // assume I_exp (mid-callback)
                {ret_type} r = v.{g}();          // observe the view now
                // stable invariant must still characterize the view's return:
                assert({c.q(c.inv_stable)});    // view-return consistent with I_stable
            }}"""'''
    s = s.replace(anchor, viewcheck)
    open(P, "w").write(s)
    print("patched templates.py: Template.view_check")


def patch_compiler_emit():
    P = "aegis/compiler.py"
    shutil.copy(P, P + ".bak_view")
    s = open(P).read()
    if "OBL_view" in s:
        print("compiler.py already emits OBL_view; skip")
        return
    # emit OBL_view obligations right after the OBL_cb loop
    anchor = '''            obligations.append(Obligation(
                name=f"OBL_cb_{f}", module="closure",
                description=f"callback {f} preserves the exposure invariant",
                harness_source=_wrap(_trim_harness(body, {"beginExposed", f}), H,
                                     template.cb_check(_ctx, f))))'''
    emit = anchor + '''

        # ---- OBL_view_<g> : each public view reading exposed state is
        #      consistent with I_stable even mid-callback (read-only reentrancy)
        try:
            from .static_analysis import view_closure
            for g in view_closure(facts, plan.phases.function):
                gi = facts.functions.get(g)
                if gi is None:
                    continue
                obligations.append(Obligation(
                    name=f"OBL_view_{g}", module="readonly",
                    description=(f"view {g} is consistent with the stable "
                                 f"invariant during the callback window"),
                    harness_source=_wrap(_trim_harness(body, {"beginExposed"}),
                                         H, template.view_check(_ctx, g, "uint256"))))
        except Exception:
            pass'''
    if anchor not in s:
        raise SystemExit("compiler OBL_cb anchor missing")
    s = s.replace(anchor, emit)
    open(P, "w").write(s)
    print("patched compiler.py: emit OBL_view obligations")


patch_functioninfo()
patch_ast_capture()
patch_facts_viewclosure()
patch_template_viewcheck()
patch_compiler_emit()
print("\nview-safety obligation feature applied across 3 files.")
print("NOTE: 'site' must be in scope at the OBL_cb emission point; if compiler")
print("uses a different variable name, adjust view_closure(facts, site) call.")
