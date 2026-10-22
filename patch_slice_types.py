import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_abstract_user_types"

HELPER = '''
_RESERVED_EXTRA = {
    "in", "of", "alias", "apply", "auto", "case", "copyof", "default",
    "define", "final", "implements", "inline", "macro", "match", "mutable",
    "null", "partial", "promise", "reference", "relocatable", "sealed",
    "sizeof", "static", "supports", "switch", "typedef", "typeof", "var",
    "after", "days", "hours", "weeks", "years",
}


def _abstract_user_types(text, known):
    """Replace types the slice does not define with `uint256`.

    The slice deliberately omits struct and contract definitions it does not
    need, so a transcribed `Ring storage ring = ...` or a
    `mapping(uint256 => Proposal)` names a type that is not present. Abstracting
    it to an unconstrained integer keeps the declaration well-formed and leaves
    the value unconstrained, which widens rather than narrows the reachable
    states.
    """
    def map_repl(m):
        key, val = m.group(1).strip(), m.group(2).strip()
        if not _TYPE_NAME.match(val.split("[")[0]) and val not in known:
            val = "uint256"
        if not _TYPE_NAME.match(key.split("[")[0]):
            key = "uint256"
        return "mapping(%s => %s)" % (key, val)

    text = re.sub(r"mapping\\s*\\(\\s*([^=)]+?)\\s*=>\\s*([^)]+?)\\s*\\)",
                  map_repl, text)

    def local_repl(m):
        tname, loc, var = m.group(1), m.group(2), m.group(3)
        if _TYPE_NAME.match(tname) or tname in known:
            return m.group(0)
        return "uint256 %s" % var

    text = re.sub(r"\\b([A-Z]\\w*)\\s+(storage|memory|calldata)\\s+"
                  r"([A-Za-z_]\\w*)\\b", local_repl, text)
    text = re.sub(r"\\b([A-Z]\\w*)\\s+([a-z_]\\w*)\\s*(?==)",
                  lambda m: m.group(0) if (_TYPE_NAME.match(m.group(1))
                                           or m.group(1) in known)
                  else "uint256 %s " % m.group(2), text)
    return text
'''

PROJ_OLD = '''    def repl(m):
        inner = m.group(1).strip()
        if inner.startswith("(") and inner.endswith(")"):
            comps = _split_returns(inner[1:-1])
            if len(comps) == n_parts:
                return "return %s(%s);" % (
                    "" if rtype != "uint256" else "", comps[idx]) \\
                    .replace("return (", "return ")
        return "return %s(0);" % rtype if rtype != "bool" \\
            else "return false;"
    return re.sub(r"return\\s+([^;]+);", repl, body)'''

PROJ_NEW = '''    def repl(m):
        inner = m.group(1).strip()
        if inner.startswith("(") and inner.endswith(")"):
            comps = _split_returns(inner[1:-1])
            if len(comps) == n_parts:
                return "return %s;" % comps[idx].strip()
        if rtype == "bool":
            return "return false;"
        if rtype.startswith("address"):
            return "return address(0);"
        return "return %s(0);" % rtype
    return re.sub(r"return\\s+([^;]+);", repl, body)'''

DECL_OLD = '''def declare(vtype, name):
    t = vtype.strip()
    if t.startswith("mapping"):
        return "    %s %s;" % (t, name)
    if re.match(r"^[A-Z]", t.split("[")[0]):
        base = t.split("[")[0]
        rest = t[len(base):]
        return "    address%s %s;" % (rest, name)
    return "    %s %s;" % (t, name)'''

DECL_NEW = '''def declare(vtype, name, known=frozenset()):
    t = _abstract_user_types(vtype.strip(), known)
    if t.startswith("mapping"):
        return "    %s %s;" % (t, name)
    base = t.split("[")[0].strip()
    if re.match(r"^[A-Z]", base) and base not in known:
        return "    uint256 %s;" % name
    return "    %s %s;" % (t, name)'''

USE_OLD = '''    decls = "\\n".join(declare(svars[v], v) for v in sorted(relevant))'''

USE_NEW = '''    decls = "\\n".join(declare(svars[v], v, enums) for v in sorted(relevant))
    pre = _abstract_user_types(pre, enums)
    post = _abstract_user_types(post, enums)
    v_body = _abstract_user_types(v_body, enums)'''

FREE_OLD = '''        if m.group(2) in _KEYWORDS or _is_type_name(m.group(2)):
            continue'''

FREE_NEW = '''        if m.group(2) in _KEYWORDS or m.group(2) in _RESERVED_EXTRA \\
                or _is_type_name(m.group(2)):
            continue'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    io.open(SH + ".bak2", "w", encoding="utf-8").write(text)

    anchor = "def _split_returns(text):"
    if anchor not in text:
        print("error: insertion anchor missing")
        return 1
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)

    for old, new, label in ((PROJ_OLD, PROJ_NEW, "return projection"),
                            (DECL_OLD, DECL_NEW, "declare"),
                            (USE_OLD, USE_NEW, "declare call"),
                            (FREE_OLD, FREE_NEW, "reserved words")):
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
    print("patched %s (backup %s.bak2)" % (SH, SH))
    print("  return projection no longer crashes on multi-return views")
    print("  undefined user types abstracted to uint256")
    print("  extra reserved words excluded from declarations")
    return 0


if __name__ == "__main__":
    sys.exit(main())
