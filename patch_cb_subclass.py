import shutil
P = "aegis/templates.py"
shutil.copy(P, P + ".bak_cbsub")
s = open(P).read()

old = '''    def cb_check(self, c: TemplateCtx, f: str) -> str:
        expr = self._monitored(c)
        return f"""
            function check(uint256 amount) public {{
                require(v.{c.flag_name}());
                uint256 entryValue = {c.q(expr)};
                v.{f}(amount);                    // run the callback
                assert({c.q(expr)} >= entryValue); // callback must not lower it
            }}"""'''
new = '''    def cb_check(self, c: TemplateCtx, f: str, cb_param_types=None) -> str:
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
if old not in s:
    raise SystemExit("MonotonicBound cb_check anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched MonotonicBoundTemplate.cb_check: accepts + threads cb_param_types")
