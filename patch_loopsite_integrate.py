"""
Gap 1 integration, Step 1: make loop-call sites a first-class part of the
pipeline facts (parallel to ExposureSite). Additive: loop_sites defaults to []
so no existing behavior changes when there are no loops.
"""
import shutil

def patch_static_analysis():
    P = "aegis/static_analysis.py"
    shutil.copy(P, P + ".bak_loopsite")
    s = open(P).read()

    # 1) LoopSite dataclass, declared just before ContractFacts.
    if "class LoopSite" not in s:
        anchor = "class ContractFacts:"
        # find the @dataclass decorator line preceding ContractFacts
        idx = s.rfind("@dataclass", 0, s.index(anchor))
        loopsite = '''@dataclass
class LoopSite:
    """An external call that occurs INSIDE a loop body -- the pattern RAVEN
    excludes (its topological ordering breaks on in-loop call-sites). Aegis
    verifies these via an inductive loop-step obligation over an arbitrary
    iteration count."""
    function: str
    call: str
    loop_body_writes: list = field(default_factory=list)   # state written per iteration
    loop_body_reads: list = field(default_factory=list)    # state read per iteration


'''
        s = s[:idx] + loopsite + s[idx:]

    # 2) add loop_sites field to ContractFacts (after exposure_sites).
    if "loop_sites:" not in s:
        s = s.replace(
            "    exposure_sites: list[ExposureSite]\n",
            "    exposure_sites: list[ExposureSite]\n"
            "    loop_sites: list = field(default_factory=list)\n", 1)

    open(P, "w").write(s)
    print("patched static_analysis.py: LoopSite dataclass + loop_sites field")


patch_static_analysis()


def patch_ast_analysis():
    P = "aegis/ast_analysis.py"
    shutil.copy(P, P + ".bak_loopsite")
    s = open(P).read()

    # import LoopSite into ast_analysis (handles single- and multi-line imports)
    if "LoopSite" not in s:
        import re as _re
        # multi-line: from .static_analysis import (A, B, C,\n   D)
        m = _re.search(r"from \.static_analysis import \(([^)]*)\)", s, _re.S)
        if m:
            inner = m.group(1)
            new_inner = inner.rstrip().rstrip(",") + ", LoopSite,"
            s = s.replace(m.group(0), "from .static_analysis import (" + new_inner + ")")
        else:
            m2 = _re.search(r"from \.static_analysis import ([^\n(]+)", s)
            if m2:
                s = s.replace(m2.group(0), m2.group(0).rstrip() + ", LoopSite")

    # detection helper (before analyze_ast)
    if "_detect_loop_sites" not in s:
        helper = '''
def _detect_loop_sites(target, state_names):
    """Find external calls inside loop bodies and capture per-iteration state
    writes/reads. Parallel to exposure-site detection but loop-aware (does NOT
    flatten loops). Returns list[LoopSite]."""
    from .static_analysis import LoopSite
    sites = []

    def _writes(node):
        w = set()
        def walk(n):
            if isinstance(n, dict):
                if n.get("nodeType") == "Assignment":
                    base = n.get("leftHandSide", {})
                    while base.get("nodeType") == "IndexAccess":
                        base = base.get("baseExpression", {})
                    nm = base.get("name")
                    if nm in state_names:
                        w.add(nm)
                for v in n.values():
                    walk(v)
            elif isinstance(n, list):
                for v in n:
                    walk(v)
        walk(node); return w

    def _reads(node):
        r = set()
        def walk(n):
            if isinstance(n, dict):
                if n.get("nodeType") == "Identifier" and n.get("name") in state_names:
                    r.add(n["name"])
                for v in n.values():
                    walk(v)
            elif isinstance(n, list):
                for v in n:
                    walk(v)
        walk(node); return r

    def scan(fn):
        fname = fn.get("name") or "<fallback>"
        def walk(node, loop_stack):
            if isinstance(node, dict):
                nt = node.get("nodeType")
                is_loop = nt in ("ForStatement", "WhileStatement", "DoWhileStatement")
                stack = loop_stack + [node] if is_loop else loop_stack
                if nt == "FunctionCall":
                    try:
                        ok, tok, _ = _is_external_call(node)
                    except Exception:
                        ok = False
                    if ok and loop_stack:
                        body = loop_stack[-1].get("body", {})
                        sites.append(LoopSite(
                            function=fname, call=tok if ok else "?",
                            loop_body_writes=sorted(_writes(body)),
                            loop_body_reads=sorted(_reads(body))))
                for v in node.values():
                    walk(v, stack)
            elif isinstance(node, list):
                for v in node:
                    walk(v, loop_stack)
        walk(fn.get("body", {}), [])

    for node in target.get("nodes", []):
        if node.get("nodeType") == "FunctionDefinition" and node.get("body"):
            scan(node)
    return sites


'''
        s = s.replace("def analyze_ast(sol_path: str)", helper + "def analyze_ast(sol_path: str)", 1)

    # populate loop_sites in the return
    s = s.replace(
        "    return ContractFacts(contract=target.get(\"name\", \"Contract\"),\n"
        "                         storage_vars=sorted(state_names),\n"
        "                         functions=functions,\n"
        "                         exposure_sites=exposure_sites,\n"
        "                         var_types=state_types)",
        "    loop_sites = _detect_loop_sites(target, state_names)\n"
        "    return ContractFacts(contract=target.get(\"name\", \"Contract\"),\n"
        "                         storage_vars=sorted(state_names),\n"
        "                         functions=functions,\n"
        "                         exposure_sites=exposure_sites,\n"
        "                         loop_sites=loop_sites,\n"
        "                         var_types=state_types)")

    open(P, "w").write(s)
    print("patched ast_analysis.py: _detect_loop_sites + populated loop_sites")


patch_ast_analysis()
