"""
Gap 1 Step 1: loop-site detection.

Finds external calls that occur INSIDE a loop body and characterises the
per-iteration state effects. This is the pattern RAVEN excludes (call-site in a
loop breaks its topological ordering). Standalone: does not modify the pipeline.

Usage:
    SOLC_VERSION=0.8.19 python3 loop_site_detect.py <contract.sol>
"""
import sys, os
sys.path.insert(0, os.path.expanduser("~/Downloads/aegis_dist"))
from aegis import ast_analysis as A


def _state_names(ast):
    names = set()
    for n in A._iter_nodes(ast):
        if n.get("nodeType") == "VariableDeclaration" and n.get("stateVariable"):
            if n.get("name"):
                names.add(n["name"])
    return names


def _idents_written(node, state):
    """State vars assigned (=, +=, -=) anywhere under node."""
    w = set()
    def walk(n):
        if isinstance(n, dict):
            if n.get("nodeType") == "Assignment":
                lhs = n.get("leftHandSide", {})
                base = lhs
                # peel IndexAccess to the base identifier (mapping/array writes)
                while base.get("nodeType") == "IndexAccess":
                    base = base.get("baseExpression", {})
                nm = base.get("name")
                if nm in state:
                    w.add(nm)
            for v in n.values():
                walk(v)
        elif isinstance(n, list):
            for v in n:
                walk(v)
    walk(node)
    return w


def _idents_read(node, state):
    r = set()
    def walk(n):
        if isinstance(n, dict):
            if n.get("nodeType") == "Identifier" and n.get("name") in state:
                r.add(n["name"])
            for v in n.values():
                walk(v)
        elif isinstance(n, list):
            for v in n:
                walk(v)
    walk(node)
    return r


def find_loop_sites(sol_path):
    ast = A._get_ast(sol_path)
    if not ast:
        return None, []
    state = _state_names(ast)
    sites = []

    def scan_fn(fn):
        fname = fn.get("name") or "<fallback>"
        results = []
        def walk(node, loop_stack):
            if isinstance(node, dict):
                nt = node.get("nodeType")
                is_loop = nt in ("ForStatement", "WhileStatement", "DoWhileStatement")
                new_stack = loop_stack + [node] if is_loop else loop_stack
                if nt == "FunctionCall":
                    try:
                        ok, tok, reason = A._is_external_call(node)
                    except Exception:
                        ok = False
                    if ok and loop_stack:
                        loop = loop_stack[-1]
                        body = loop.get("body", {})
                        results.append({
                            "function": fname,
                            "call_token": tok if ok else "?",
                            "loop_body_writes": sorted(_idents_written(body, state)),
                            "loop_body_reads": sorted(_idents_read(body, state)),
                        })
                for k, v in node.items():
                    walk(v, new_stack)
            elif isinstance(node, list):
                for v in node:
                    walk(v, loop_stack)
        walk(fn.get("body", {}), [])
        return results

    for c in A._contract_defs(ast):
        if c.get("contractKind") != "contract":
            continue
        for node in c.get("nodes", []):
            if node.get("nodeType") == "FunctionDefinition" and node.get("body"):
                sites.extend(scan_fn(node))
    return state, sites


if __name__ == "__main__":
    p = sys.argv[1]
    state, sites = find_loop_sites(p)
    print("contract:", os.path.basename(p))
    print("state vars:", sorted(state) if state else state)
    print("loop-call sites found:", len(sites))
    for s in sites:
        print("  function:", s["function"], "| call:", s["call_token"])
        print("    loop-body writes:", s["loop_body_writes"])
        print("    loop-body reads :", s["loop_body_reads"])
