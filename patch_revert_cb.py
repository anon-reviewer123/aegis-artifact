import shutil
P = "aegis/templates.py"
shutil.copy(P, P + ".bak_revertcb")
s = open(P).read()

# The closure wrapper is ALWAYS emitted as <name>(uint256 amount) by
# _emit_callback_wrappers. So cb_check must call v.<f>(amount), NOT the real
# parameter types. The earlier param-threading was wrong for callbacks (it is
# correct only for views, which are not wrapped). Revert both cb_check methods.

# base Template.cb_check
base_old = '''    def cb_check(self, c: TemplateCtx, f: str, cb_param_types=None) -> str:
        pred = self.exposed_predicate(c)
        cb_param_types = cb_param_types or []
        decls, args = [], []
        for i, t in enumerate(cb_param_types):
            base = (t or "uint256").replace(" memory", "").replace(" calldata", "").strip()
            if base.startswith("address"): base = "address"
            elif base.startswith("uint"): base = "uint256"
            elif base.startswith("int"): base = "int256"
            elif base.startswith("bool"): base = "bool"
            elif base.startswith("bytes32"): base = "bytes32"
            else: base = "uint256"
            decls.append(f"{base} p{i}"); args.append(f"p{i}")
        extra_sig = ("".join(", " + d for d in decls))
        call_args = ", ".join(args)
        return f"""
            function check(uint256 amount{extra_sig}) public {{
                require(v.{c.flag_name}());
                require({c.q(pred)});           // assume I_exp before callback
                v.{f}({call_args});              // run the callback
                assert({c.q(pred)});            // I_exp must still hold
            }}"""'''
base_new = '''    def cb_check(self, c: TemplateCtx, f: str, cb_param_types=None) -> str:
        pred = self.exposed_predicate(c)
        return f"""
            function check(uint256 amount) public {{
                require(v.{c.flag_name}());
                require({c.q(pred)});           // assume I_exp before callback
                v.{f}(amount);                    // run the callback (wrapper takes uint256)
                assert({c.q(pred)});            // I_exp must still hold
            }}"""'''
if base_old not in s:
    raise SystemExit("base cb_check anchor missing")
s = s.replace(base_old, base_new)

# MonotonicBoundTemplate.cb_check
mono_old = '''    def cb_check(self, c: TemplateCtx, f: str, cb_param_types=None) -> str:
        expr = self._monitored(c)
        cb_param_types = cb_param_types or []
        decls, args = [], []
        for i, t in enumerate(cb_param_types):
            base = (t or "uint256").replace(" memory", "").replace(" calldata", "").strip()
            if base.startswith("address"): base = "address"
            elif base.startswith("uint"): base = "uint256"
            elif base.startswith("int"): base = "int256"
            elif base.startswith("bool"): base = "bool"
            elif base.startswith("bytes32"): base = "bytes32"
            else: base = "uint256"
            decls.append(f"{base} p{i}"); args.append(f"p{i}")
        extra_sig = "".join(", " + d for d in decls)
        call_args = ", ".join(args)
        return f"""
            function check(uint256 amount{extra_sig}) public {{
                require(v.{c.flag_name}());
                uint256 entryValue = {c.q(expr)};
                v.{f}({call_args});               // run the callback
                assert({c.q(expr)} >= entryValue); // callback must not lower it
            }}"""'''
mono_new = '''    def cb_check(self, c: TemplateCtx, f: str, cb_param_types=None) -> str:
        expr = self._monitored(c)
        return f"""
            function check(uint256 amount) public {{
                require(v.{c.flag_name}());
                uint256 entryValue = {c.q(expr)};
                v.{f}(amount);                    // run the callback (wrapper takes uint256)
                assert({c.q(expr)} >= entryValue); // callback must not lower it
            }}"""'''
if mono_old not in s:
    raise SystemExit("mono cb_check anchor missing")
s = s.replace(mono_old, mono_new)

open(P, "w").write(s)
print("reverted both cb_check methods to v.<f>(amount) — wrapper takes uint256")
