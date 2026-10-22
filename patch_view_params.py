import shutil

# Fix OBL_view harness: call the view with the correct number of symbolic
# arguments. Capture parameter types on FunctionInfo, then have view_check
# declare fresh symbolic params and pass them.

def patch_functioninfo_params():
    P = "aegis/static_analysis.py"
    shutil.copy(P, P + ".bak_vparams")
    s = open(P).read()
    if "param_types" in s:
        print("param_types already present; skip"); return
    s = s.replace(
        '    mutability: str = "nonpayable"        # view/pure/payable/nonpayable\n'
        '    reads: set[str] = field(default_factory=set)',
        '    mutability: str = "nonpayable"        # view/pure/payable/nonpayable\n'
        '    param_types: list = field(default_factory=list)  # solidity param types\n'
        '    reads: set[str] = field(default_factory=set)')
    open(P, "w").write(s)
    print("patched static_analysis.py: FunctionInfo.param_types")


def patch_ast_params():
    P = "aegis/ast_analysis.py"
    shutil.copy(P, P + ".bak_vparams")
    s = open(P).read()
    if "param_types=" in s:
        print("ast param capture already present; skip"); return
    s = s.replace(
        '            mut = node.get("stateMutability", "nonpayable")\n'
        '            info = FunctionInfo(name=name, visibility=vis,\n'
        '                                mutability=mut)',
        '            mut = node.get("stateMutability", "nonpayable")\n'
        '            ptypes = []\n'
        '            for prm in (node.get("parameters", {}) or {}).get("parameters", []):\n'
        '                t = (prm.get("typeDescriptions", {}) or {}).get("typeString", "")\n'
        '                ptypes.append(t)\n'
        '            info = FunctionInfo(name=name, visibility=vis,\n'
        '                                mutability=mut, param_types=ptypes)')
    open(P, "w").write(s)
    print("patched ast_analysis.py: capture view parameter types")


def patch_template_args():
    P = "aegis/templates.py"
    shutil.copy(P, P + ".bak_vparams")
    s = open(P).read()
    old = '''    def view_check(self, c: TemplateCtx, g: str, ret_type: str) -> str:
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
    new = '''    def view_check(self, c: TemplateCtx, g: str, ret_type: str,
                   param_types=None) -> str:
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
        return f"""
            function check({sig}) public {{
                require(v.{c.flag_name}());
                require({c.q(pred)});           // assume I_exp (mid-callback)
                v.{g}({call_args});              // observe the view now
                assert({c.q(c.inv_stable)});    // view-return consistent with I_stable
            }}"""'''
    if old not in s:
        raise SystemExit("view_check anchor missing")
    s = s.replace(old, new)
    open(P, "w").write(s)
    print("patched templates.py: view_check declares symbolic params")


def patch_compiler_pass_params():
    P = "aegis/compiler.py"
    shutil.copy(P, P + ".bak_vparams")
    s = open(P).read()
    old = '''                obligations.append(Obligation(
                    name=f"OBL_view_{g}", module="readonly",
                    description=(f"view {g} is consistent with the stable "
                                 f"invariant during the callback window"),
                    harness_source=_wrap(_trim_harness(body, {"beginExposed"}),
                                         H, template.view_check(_ctx, g, "uint256"))))'''
    new = '''                obligations.append(Obligation(
                    name=f"OBL_view_{g}", module="readonly",
                    description=(f"view {g} is consistent with the stable "
                                 f"invariant during the callback window"),
                    harness_source=_wrap(_trim_harness(body, {"beginExposed"}),
                                         H, template.view_check(
                                             _ctx, g, "uint256",
                                             param_types=gi.param_types))))'''
    if old not in s:
        raise SystemExit("compiler OBL_view anchor missing")
    s = s.replace(old, new)
    open(P, "w").write(s)
    print("patched compiler.py: pass view param_types")


patch_functioninfo_params()
patch_ast_params()
patch_template_args()
patch_compiler_pass_params()
print("\nview parameter-arity fix applied.")
