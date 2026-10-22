"""
Gap 1 integration Step 1b: capture, for each loop-call site, which state vars the
loop body writes BEFORE the external call vs AFTER it. This before/after split is
exactly what distinguishes a safe iteration (effect-before-interaction) from an
unsafe one (interaction-before-effect), and the step-harness synthesizer needs it.
"""
import shutil

def patch():
    P = "aegis/ast_analysis.py"
    shutil.copy(P, P + ".bak_ordering")
    s = open(P).read()

    # extend LoopSite fields on the static_analysis side
    S = "aegis/static_analysis.py"
    shutil.copy(S, S + ".bak_ordering")
    ss = open(S).read()
    if "writes_before_call" not in ss:
        ss = ss.replace(
            "    loop_body_writes: list = field(default_factory=list)   # state written per iteration\n"
            "    loop_body_reads: list = field(default_factory=list)    # state read per iteration",
            "    loop_body_writes: list = field(default_factory=list)   # state written per iteration\n"
            "    loop_body_reads: list = field(default_factory=list)    # state read per iteration\n"
            "    writes_before_call: list = field(default_factory=list) # written BEFORE the in-loop call\n"
            "    writes_after_call: list = field(default_factory=list)  # written AFTER the in-loop call")
        open(S, "w").write(ss)
        print("patched static_analysis.py: LoopSite before/after-call write fields")

    # in _detect_loop_sites, compute before/after by walking the loop body's
    # statements in order and splitting at the external call.
    anchor = '''                    if ok and loop_stack:
                        body = loop_stack[-1].get("body", {})
                        sites.append(LoopSite(
                            function=fname, call=tok if ok else "?",
                            loop_body_writes=sorted(_writes(body)),
                            loop_body_reads=sorted(_reads(body))))'''
    new = '''                    if ok and loop_stack:
                        body = loop_stack[-1].get("body", {})
                        wb, wa = _split_writes_at_call(body, state_names)
                        sites.append(LoopSite(
                            function=fname, call=tok if ok else "?",
                            loop_body_writes=sorted(_writes(body)),
                            loop_body_reads=sorted(_reads(body)),
                            writes_before_call=sorted(wb),
                            writes_after_call=sorted(wa)))'''
    if anchor in s:
        s = s.replace(anchor, new)

    # add the splitter helper inside _detect_loop_sites (before scan())
    split_helper = '''    def _split_writes_at_call(body, state):
        """Walk the loop body statements in source order; collect state writes
        before the first external call vs after it."""
        before, after = set(), set()
        seen_call = [False]
        def stmt_writes(node):
            w = set()
            def walk(n):
                if isinstance(n, dict):
                    if n.get("nodeType") == "Assignment":
                        base = n.get("leftHandSide", {})
                        while base.get("nodeType") == "IndexAccess":
                            base = base.get("baseExpression", {})
                        if base.get("name") in state:
                            w.add(base["name"])
                    for v in n.values():
                        walk(v)
                elif isinstance(n, list):
                    for v in n:
                        walk(v)
            walk(node); return w
        def has_call(node):
            found = [False]
            def walk(n):
                if isinstance(n, dict):
                    if n.get("nodeType") == "FunctionCall":
                        try:
                            ok, _, _ = _is_external_call(n)
                        except Exception:
                            ok = False
                        if ok: found[0] = True
                    for v in n.values():
                        walk(v)
                elif isinstance(n, list):
                    for v in n:
                        walk(v)
            walk(node); return found[0]
        stmts = (body.get("statements") if isinstance(body, dict) else None) or [body]
        for st in stmts:
            w = stmt_writes(st)
            if seen_call[0]:
                after |= w
            else:
                before |= w
            if has_call(st):
                seen_call[0] = True
                # writes in the SAME statement as the call count as before
        return before, after

'''
    s = s.replace("    def scan(fn):", split_helper + "    def scan(fn):", 1)

    open(P, "w").write(s)
    print("patched ast_analysis.py: _split_writes_at_call + populated before/after")

patch()
