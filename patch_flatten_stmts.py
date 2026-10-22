import shutil

PATH = "aegis/ast_analysis.py"
shutil.copy(PATH, PATH + ".bak_flatten")
src = open(PATH).read()

old = '''def _ordered_statements(fn_body) -> list[dict]:
    """Flat, ordered list of statement nodes in a function body."""
    stmts = []
    for s in (fn_body or {}).get("statements", []):
        stmts.append(s)
    return stmts'''

new = '''def _ordered_statements(fn_body) -> list[dict]:
    """Flat, ordered list of statement nodes in a function body.

    Recursively flattens nested blocks (unchecked blocks, if/else arms, for
    and while bodies) into a single ordered sequence so a callback buried
    inside a compound statement is visible to the before/after phase split.
    Leaf statements are returned as-is; a compound statement contributes its
    inner statements in source order and is not itself emitted.
    """
    out = []

    def walk(node):
        if not isinstance(node, dict):
            return
        nt = node.get("nodeType")
        if nt in ("Block", "UncheckedBlock"):
            for s in node.get("statements", []) or []:
                walk(s)
            return
        if nt == "IfStatement":
            cond = node.get("condition")
            if cond is not None:
                out.append({"nodeType": "ExpressionStatement",
                            "expression": cond})
            walk(node.get("trueBody"))
            walk(node.get("falseBody"))
            return
        if nt in ("ForStatement", "WhileStatement", "DoWhileStatement"):
            walk(node.get("body"))
            return
        out.append(node)

    for s in (fn_body or {}).get("statements", []) or []:
        walk(s)
    return out'''

if old not in src:
    raise SystemExit("anchor not found; _ordered_statements differs")
src = src.replace(old, new)
open(PATH, "w").write(src)
print("patched _ordered_statements (backup at .bak_flatten)")
