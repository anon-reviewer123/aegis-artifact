import json, sys, os, re
sys.path.insert(0, ".")
from aegis.static_analysis import analyze, _try_solc_ast
from aegis import ast_analysis as A

root = sys.argv[1]
prone = [json.loads(l)["address"] for l in open(os.path.join(root, "census.jsonl"))
         if json.loads(l).get("callback_prone")]

def has_call_in_loop(ast):
    """True if any external call node sits inside a for/while loop body."""
    found = [False]
    def walk(n, in_loop):
        if isinstance(n, dict):
            nt = n.get("nodeType")
            loop_now = in_loop or nt in ("ForStatement", "WhileStatement", "DoWhileStatement")
            if nt == "FunctionCall":
                ok, tok, rsn = A._is_external_call(n)
                if ok and in_loop:
                    found[0] = True
            for k, v in n.items():
                # for loop nodes, only the body counts as "in loop"
                if nt in ("ForStatement","WhileStatement","DoWhileStatement"):
                    walk(v, k == "body" or in_loop)
                else:
                    walk(v, in_loop)
        elif isinstance(n, list):
            for v in n: walk(v, in_loop)
    walk(ast, False)
    return found[0]

count = 0; withinv = 0; examples = []
for a in prone:
    p = os.path.join(root, "contracts", a + ".sol")
    try:
        ast = _try_solc_ast(p)
        if not ast: continue
    except Exception:
        continue
    if not has_call_in_loop(ast):
        continue
    count += 1
    src = open(p, errors="ignore").read()
    # heuristic: is there an accounting-style invariant candidate near the loop?
    invish = bool(re.search(r"require\s*\([^)]*(sent|ok|success|paid|total)", src)) \
             or ("mapping(address" in src and re.search(r"for\s*\(|while\s*\(", src))
    if invish:
        withinv += 1
        if len(examples) < 8: examples.append(a[:12])

print("callback-prone:", len(prone))
print("with external call INSIDE a loop (RAVEN-excluded):", count,
      f"({100*count/len(prone):.0f}%)")
print("  of those, with an accounting/require invariant nearby:", withinv)
print("  examples:", examples)
