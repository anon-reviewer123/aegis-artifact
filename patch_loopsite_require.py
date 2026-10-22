"""
Gap 1 Slice 2b: detect whether the loop body PROPAGATES a call failure via a
require/revert after the external call (unsafe griefing) vs handles it (safe).
Adds LoopSite.propagates_failure.
"""
import shutil

def patch():
    S = "aegis/static_analysis.py"
    shutil.copy(S, S + ".bak_require")
    ss = open(S).read()
    if "propagates_failure" not in ss:
        ss = ss.replace(
            "    writes_after_call: list = field(default_factory=list)  # written AFTER the in-loop call",
            "    writes_after_call: list = field(default_factory=list)  # written AFTER the in-loop call\n"
            "    propagates_failure: bool = False  # loop reverts on call failure (require(ok)) -> no progress")
        open(S, "w").write(ss)
        print("patched static_analysis.py: LoopSite.propagates_failure")

    P = "aegis/ast_analysis.py"
    shutil.copy(P, P + ".bak_require")
    s = open(P).read()

    # add a detector for "require/revert after the call in the loop body" and pass it.
    if "_loop_propagates_failure" not in s:
        helper = '''    def _loop_propagates_failure(body):
        """True if the loop body contains a require()/revert AFTER the external
        call (propagating a call failure -> the loop can halt = no progress)."""
        stmts = (body.get("statements") if isinstance(body, dict) else None) or [body]
        seen_call = [False]
        found = [False]
        def has_ext_call(n):
            f = [False]
            def w(x):
                if isinstance(x, dict):
                    if x.get("nodeType") == "FunctionCall":
                        try:
                            ok, _, _ = _is_external_call(x)
                        except Exception:
                            ok = False
                        if ok: f[0] = True
                    for v in x.values(): w(v)
                elif isinstance(x, list):
                    for v in x: w(v)
            w(n); return f[0]
        def has_require(n):
            f = [False]
            def w(x):
                if isinstance(x, dict):
                    if x.get("nodeType") == "FunctionCall":
                        exp = x.get("expression", {})
                        if exp.get("name") in ("require", "revert") or exp.get("nodeType") == "Identifier" and exp.get("name") == "require":
                            f[0] = True
                    if x.get("nodeType") in ("RevertStatement",):
                        f[0] = True
                    for v in x.values(): w(v)
                elif isinstance(x, list):
                    for v in x: w(v)
            w(n); return f[0]
        for st in stmts:
            if seen_call[0] and has_require(st):
                found[0] = True
            if has_ext_call(st):
                # a require in the SAME statement (after the call expr) counts too
                if has_require(st):
                    found[0] = True
                seen_call[0] = True
        return found[0]

'''
        s = s.replace("    def scan(fn):", helper + "    def scan(fn):", 1)

    # thread it into the LoopSite construction
    s = s.replace(
        "                            writes_before_call=sorted(wb),\n"
        "                            writes_after_call=sorted(wa)))",
        "                            writes_before_call=sorted(wb),\n"
        "                            writes_after_call=sorted(wa),\n"
        "                            propagates_failure=_loop_propagates_failure(body)))")

    open(P, "w").write(s)
    print("patched ast_analysis.py: _loop_propagates_failure + populated")

patch()
