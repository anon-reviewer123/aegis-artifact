import ast as pyast
import io
import os
import sys

HS = os.path.join("aegis", "harness_synth.py")

HELPER = '''
_REF_LOCAL = re.compile(
    r"^(\\s*)([A-Za-z_]\\w*(?:\\s*\\[[^\\]]*\\])*)"
    r"\\s+([A-Za-z_]\\w*)\\s*(=|;)")


def _add_local_data_locations(body: str, structs: set = frozenset()) -> str:
    """Give reference-typed locals an explicit data location.

    `bytes`, `string`, array and struct types are reference types: as a local
    they must state `memory`, `storage` or `calldata`, though as a state
    variable they must not. Bodies are transcribed from source where the
    location was present on the original declaration or implied by a parameter,
    so re-emitting them without one fails to compile.
    """
    out = []
    for line in body.splitlines():
        m = _REF_LOCAL.match(line)
        if not m:
            out.append(line)
            continue
        indent, tname, var, tail = m.groups()
        base = tname.split("[")[0].strip()
        is_ref = (base in ("bytes", "string") or "[" in tname
                  or base in structs)
        if not is_ref:
            out.append(line)
            continue
        if re.search(r"\\b(memory|storage|calldata)\\b", line):
            out.append(line)
            continue
        if re.match(r"\\s*(public|private|internal|constant|immutable)\\b",
                    line[len(indent):]):
            out.append(line)
            continue
        sep = "" if tail == ";" else " "
        out.append("%s%s memory %s%s%s%s" % (
            indent, tname, var, sep, tail, line[m.end():]))
    return "\\n".join(out)
'''

APPLY_OLD = '''    begin_body = _normalize_unknown_types(begin_body, _defined_types)
    end_body = _normalize_unknown_types(end_body, _defined_types)
    callback_stubs = _normalize_unknown_types(callback_stubs, _defined_types)
    view_funcs = _normalize_unknown_types(view_funcs, _defined_types)'''

APPLY_NEW = '''    begin_body = _normalize_unknown_types(begin_body, _defined_types)
    end_body = _normalize_unknown_types(end_body, _defined_types)
    callback_stubs = _normalize_unknown_types(callback_stubs, _defined_types)
    view_funcs = _normalize_unknown_types(view_funcs, _defined_types)
    begin_body = _add_local_data_locations(begin_body, _defined_types)
    end_body = _add_local_data_locations(end_body, _defined_types)
    callback_stubs = _add_local_data_locations(callback_stubs, _defined_types)
    view_funcs = _add_local_data_locations(view_funcs, _defined_types)'''


def main():
    if not os.path.exists(HS):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(HS, encoding="utf-8").read()
    if "_add_local_data_locations" in text:
        print("already patched")
        return 0
    if APPLY_OLD not in text:
        print("error: normalization anchor not found")
        return 1
    io.open(HS + ".bak11", "w", encoding="utf-8").write(text)

    anchor = "def _normalize_unknown_types("
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)
    text = text.replace(APPLY_OLD, APPLY_NEW, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(HS, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak11)" % (HS, HS))
    print("  reference-typed locals now declared with an explicit location")
    return 0


if __name__ == "__main__":
    sys.exit(main())
