import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_NEVER_HAVOC"

HELPER = '''
_NEVER_HAVOC = {
    "revert", "require", "assert", "emit", "return", "if", "for", "while",
    "delete", "new", "keccak256", "sha256", "ecrecover", "addmod", "mulmod",
    "type", "unchecked", "selfdestruct", "payable", "address", "uint256",
    "int256", "bool", "bytes32", "string", "bytes",
}
'''

DECL_OLD = '''def declare(vtype, name, known=frozenset()):
    t = _abstract_user_types(vtype.strip(), known)'''

DECL_NEW = '''def declare(vtype, name, known=frozenset()):
    # Mapping types must go through the nesting-aware rewriter: the general
    # abstraction stops at the first `)`, so a mapping whose value is itself a
    # mapping loses its inner type and keeps the inner closing parenthesis.
    t = vtype.strip()
    if t.startswith("mapping"):
        t = _fix_nested_mappings(t, known)
    else:
        t = _abstract_user_types(t, known)'''

HAVOC_OLD = '''    def repl(m):
        name = m.group(1)
        if name in known or name in _KEYWORDS:
            return m.group(0)
        return "_havoc"'''

HAVOC_NEW = '''    def repl(m):
        name = m.group(1)
        if name in known or name in _KEYWORDS or name in _NEVER_HAVOC:
            return m.group(0)
        # `revert CustomError(...)`, `emit Event(...)` and `new C(...)` name a
        # construct, not a helper whose value the slice needs.
        pre = body[max(0, m.start() - 12):m.start()]
        if re.search(r"\\b(revert|emit|new)\\s+$", pre):
            return m.group(0)
        return "_havoc"'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    io.open(SH + ".bak8", "w", encoding="utf-8").write(text)

    anchor = "def havoc_calls(body, known):"
    if anchor not in text:
        print("error: havoc_calls not found")
        return 1
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)

    for old, new, label in ((DECL_OLD, DECL_NEW, "declare"),
                            (HAVOC_OLD, HAVOC_NEW, "havoc guard")):
        if old not in text:
            print("error: anchor not found (%s)" % label)
            return 1
        text = text.replace(old, new, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(SH, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak8)" % (SH, SH))
    print("  nested mapping declarations no longer lose parentheses")
    print("  revert/require/emit no longer rewritten as havoc reads")
    return 0


if __name__ == "__main__":
    sys.exit(main())
