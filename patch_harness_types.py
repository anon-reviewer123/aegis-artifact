import io
import os
import re
import sys

TARGET = os.path.join("aegis", "harness_synth.py")

NEW_TYPE_BLOCK = '''
_LOC_SUFFIX = re.compile(
    r"\\s+(storage(\\s+(ref|pointer))?|memory|calldata|payable)\\b")


def _strip_loc(t: str) -> str:
    prev = None
    while prev != t:
        prev = t
        t = _LOC_SUFFIX.sub("", t).strip()
    return t


def _scalar_harness_type(t: str):
    """Map one non-mapping type to a declaration valid inside the harness.
    Returns None only for types that cannot be declared standalone (structs and
    function types); every other type is declared unconstrained, which is a
    sound over-approximation because an unconstrained variable is havoced."""
    t = _strip_loc(t)
    if not t:
        return None
    m = re.match(r"^(.*)\\[(\\d*)\\]$", t)
    if m:
        base = _scalar_harness_type(m.group(1))
        if base is None:
            base = "uint256"
        return "%s[%s]" % (base, m.group(2))
    if re.match(r"^u?int\\d*$", t):
        return t
    if t == "bool":
        return "bool"
    if t == "address" or t.startswith("address") \\
            or t.startswith("contract ") or t.startswith("interface "):
        return "address"
    if t == "string":
        return "string"
    if t == "bytes":
        return "bytes"
    if re.match(r"^bytes([1-9]|[12]\\d|3[0-2])$", t):
        return t
    if t.startswith("enum "):
        return "uint256"
    if t.startswith("struct ") or t.startswith("function "):
        return None
    return None


def _split_mapping(t: str):
    """Split `mapping(K => V)` at the top-level arrow, tolerating nesting."""
    inner = t[t.find("(") + 1:t.rfind(")")]
    depth = 0
    for i in range(len(inner) - 1):
        c = inner[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif depth == 0 and inner[i:i + 2] == "=>":
            return inner[:i].strip(), inner[i + 2:].strip()
    return None, None


def _mapping_harness_type(t: str):
    key, val = _split_mapping(t)
    if key is None:
        return None
    k = _scalar_harness_type(key)
    if k is None or k == "string" or k.endswith("]"):
        return None
    val = _strip_loc(val)
    if val.startswith("mapping("):
        v = _mapping_harness_type(val)
    else:
        v = _scalar_harness_type(val)
    if v is None:
        v = "uint256"
    return "mapping(%s => %s)" % (k, v)


def _harness_type(tstr: str, var: str, src: str):
    """Map a storage variable to a declaration type valid INSIDE the isolated
    harness contract. Returns None only when no standalone declaration exists
    (structs, function types, mappings with an unrepresentable key).

    Types the solver models poorly are still declared. Omitting them leaves the
    inlined body referencing an undeclared name, which fails to compile; leaving
    them unconstrained is sound, since a havoced variable admits every value the
    original could hold.
    """
    t = (tstr or "").strip()
    if not t:
        t = _infer_type_from_source(var, src).strip()
    if not t:
        return "uint256"
    t = _strip_loc(t)
    if t.startswith("mapping("):
        return _mapping_harness_type(t)
    return _scalar_harness_type(t)
'''

OLD_SRC_LINE = '    src = _SRC_CACHE.get(facts.contract, "")'
NEW_SRC_LINE = '    src = _SRC_CACHE.get(facts.contract) or src'


def find_function(text, name):
    m = re.search(r"^def %s\(" % re.escape(name), text, re.M)
    if not m:
        return None, None
    start = m.start()
    nxt = re.search(r"^(def |_UNREPRESENTABLE_VARS|@)", text[m.end():], re.M)
    end = m.end() + nxt.start() if nxt else len(text)
    return start, end


def main():
    if not os.path.exists(TARGET):
        print("error: run from the aegis_dist root (%s not found)" % TARGET)
        return 1

    text = io.open(TARGET, encoding="utf-8").read()

    if "_scalar_harness_type" in text:
        print("already patched; nothing to do")
        return 0

    backup = TARGET + ".bak"
    io.open(backup, "w", encoding="utf-8").write(text)

    start, end = find_function(text, "_harness_type")
    if start is None:
        print("error: _harness_type not found")
        return 1
    text = text[:start] + NEW_TYPE_BLOCK.strip() + "\n\n\n" + text[end:]

    if OLD_SRC_LINE in text:
        text = text.replace(OLD_SRC_LINE, NEW_SRC_LINE, 1)
        src_fixed = True
    else:
        src_fixed = False

    io.open(TARGET, "w", encoding="utf-8").write(text)

    import ast
    try:
        ast.parse(text)
    except SyntaxError as e:
        io.open(TARGET, "w", encoding="utf-8").write(
            io.open(backup, encoding="utf-8").read())
        print("error: patched file does not parse (%s); reverted" % e)
        return 1

    print("patched %s" % TARGET)
    print("  _harness_type widened: string, bytes, bytesN, arrays, enums,")
    print("  mapping-to-complex now declared instead of omitted")
    print("  source-cache shadowing fixed: %s" % ("yes" if src_fixed else
                                                  "line not found"))
    print("  backup at %s" % backup)
    return 0


if __name__ == "__main__":
    sys.exit(main())
