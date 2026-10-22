import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_local_names"

HELPER = '''
def _local_names(text):
    """Names declared locally inside the sliced bodies.

    A local must not also be emitted as a state variable: the duplicate either
    shadows the local or contradicts its type, which is how `bool selfSponsor =
    false;` ends up alongside `uint256 selfSponsor;`.
    """
    try:
        from .harness_synth import _declared_locals
        return set(_declared_locals(text))
    except Exception:
        return set()


def _fix_nested_mappings(text, known):
    """Abstract mapping value types, innermost first, without losing parens.

    A single non-recursive substitution over `mapping(K => V)` cannot see that V
    is itself a mapping, so the closing parenthesis of the inner type is left
    dangling.
    """
    pat = re.compile(r"mapping\\s*\\(\\s*([^(),=]+?)\\s*=>\\s*([^(),]+?)\\s*\\)")
    prev = None
    while prev != text:
        prev = text

        def repl(m):
            key, val = m.group(1).strip(), m.group(2).strip()
            if not _TYPE_NAME.match(key.split("[")[0]):
                key = "uint256"
            vb = val.split("[")[0].strip()
            if not _TYPE_NAME.match(vb) and vb not in known \\
                    and not vb.startswith("@"):
                val = "uint256"
            return "@MAP@(%s => %s)" % (key, val)

        text = pat.sub(repl, text)
    return text.replace("@MAP@", "mapping")


def _repair_havoc_tuples(text):
    """Drop tuple assignments whose right-hand call was havoced away.

    `(bool ok, bytes memory ret) = target.call(data);` loses its call when the
    callee is not in the slice, leaving a tuple bound to a plain value. The
    components are unconstrained either way, so the statement is replaced by
    declarations of its parts.
    """
    def repl(m):
        comps = [c.strip() for c in m.group(1).split(",") if c.strip()]
        out = []
        for c in comps:
            parts = c.split()
            if len(parts) >= 2:
                out.append("%s %s;" % (" ".join(parts[:-1]), parts[-1]))
        return " ".join(out) if out else ";"
    return re.sub(r"\\(([^()]*,[^()]*)\\)\\s*=\\s*[^;]*;", repl, text)
'''

USE_OLD = '''    decls = "\\n".join(declare(svars[v], v, enums) for v in sorted(relevant))
    pre = _abstract_user_types(pre, enums)
    post = _abstract_user_types(post, enums)
    v_body = _abstract_user_types(v_body, enums)'''

USE_NEW = '''    pre = _repair_havoc_tuples(pre)
    post = _repair_havoc_tuples(post)
    decls = "\\n".join(declare(svars[v], v, enums) for v in sorted(relevant))
    decls = _fix_nested_mappings(decls, enums)
    pre = _abstract_user_types(pre, enums)
    post = _abstract_user_types(post, enums)
    v_body = _abstract_user_types(v_body, enums)'''

FREE_OLD = '''    free = (identifiers(pre) | identifiers(post) | identifiers(v_body)) \\
        - relevant - known - pnames - {"amount"}'''

FREE_NEW = '''    locals_declared = _local_names(pre) | _local_names(post) \\
        | _local_names(v_body)
    free = (identifiers(pre) | identifiers(post) | identifiers(v_body)) \\
        - relevant - known - pnames - locals_declared - {"amount"}'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    io.open(SH + ".bak3", "w", encoding="utf-8").write(text)

    anchor = "def _abstract_user_types(text, known):"
    if anchor not in text:
        print("error: insertion anchor missing")
        return 1
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)

    for old, new, label in ((USE_OLD, USE_NEW, "emission order"),
                            (FREE_OLD, FREE_NEW, "free identifiers")):
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
    print("patched %s (backup %s.bak3)" % (SH, SH))
    print("  locals no longer duplicated as state variables")
    print("  nested mappings abstracted without losing parentheses")
    print("  havoced tuple calls replaced by component declarations")
    return 0


if __name__ == "__main__":
    sys.exit(main())
