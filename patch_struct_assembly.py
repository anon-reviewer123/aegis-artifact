import ast as pyast
import io
import os
import sys

HS = os.path.join("aegis", "harness_synth.py")
MARKER = "class HarnessUnsupported"

HELPER = '''
class HarnessUnsupported(Exception):
    """Raised when a faithful harness cannot be built for a contract.

    Refusing is the honest outcome: emitting a harness that silently drops code
    with storage effects would let the solver prove a property the original
    contract does not satisfy.
    """


def _strip_comments(text: str) -> str:
    text = re.sub(r"/\\*.*?\\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\\n]*", " ", text)


def _drop_assembly(body: str) -> str:
    """Remove inline assembly blocks from a transcribed body.

    Yul cannot be reproduced meaningfully inside an isolated harness: it reads
    calldata and memory the harness does not have. A block that only computes
    local values may be dropped, since the values it feeds are already resolved
    as unconstrained symbols. A block that writes storage cannot: dropping it
    would remove a state effect the property depends on, so the contract is
    reported unsupported instead.
    """
    out, i = [], 0
    while True:
        m = re.search(r"\\bassembly\\b\\s*(\\(\\s*\\"memory-safe\\"\\s*\\))?\\s*\\{",
                      body[i:])
        if not m:
            out.append(body[i:])
            break
        start = i + m.start()
        brace = body.find("{", i + m.start())
        depth, j = 0, brace
        while j < len(body):
            if body[j] == "{":
                depth += 1
            elif body[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        block = body[brace:j + 1]
        if re.search(r"\\bsstore\\b|\\.slot\\b", block):
            raise HarnessUnsupported(
                "inline assembly writes storage; cannot model faithfully")
        out.append(body[i:start])
        out.append("        // [assembly block omitted]\\n")
        i = j + 1
    return "".join(out)
'''

APPLY_OLD = '''    begin_body = _add_local_data_locations(begin_body, _defined_types)
    end_body = _add_local_data_locations(end_body, _defined_types)
    callback_stubs = _add_local_data_locations(callback_stubs, _defined_types)
    view_funcs = _add_local_data_locations(view_funcs, _defined_types)'''

APPLY_NEW = '''    begin_body = _add_local_data_locations(begin_body, _defined_types)
    end_body = _add_local_data_locations(end_body, _defined_types)
    callback_stubs = _add_local_data_locations(callback_stubs, _defined_types)
    view_funcs = _add_local_data_locations(view_funcs, _defined_types)
    begin_body = _drop_assembly(begin_body)
    end_body = _drop_assembly(end_body)
    callback_stubs = _drop_assembly(callback_stubs)
    view_funcs = _drop_assembly(view_funcs)'''

FIELDS_OLD = '''        inner = body[1:-1]
        fixed = []
        for field in inner.split(";"):
            f = field.strip()
            if not f:
                continue'''

FIELDS_NEW = '''        inner = _strip_comments(body[1:-1])
        fixed = []
        for field in inner.split(";"):
            f = " ".join(field.split())
            if not f:
                continue
            # Only well-formed `type name` pairs are fields; anything else is a
            # fragment of a construct the splitter did not understand and must
            # not be emitted as a declaration.
            if not re.fullmatch(r"[A-Za-z_][\\w.]*(?:\\s*\\[[^\\]]*\\])*"
                                r"(?:\\s+(?:memory|storage|calldata))?"
                                r"\\s+[A-Za-z_]\\w*", f):
                continue'''


def main():
    if not os.path.exists(HS):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(HS, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    io.open(HS + ".bak14", "w", encoding="utf-8").write(text)

    anchor = "def _collect_type_defs("
    if anchor not in text:
        print("error: _collect_type_defs not found")
        return 1
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)

    for old, new, label in ((FIELDS_OLD, FIELDS_NEW, "struct fields"),
                            (APPLY_OLD, APPLY_NEW, "assembly removal")):
        if old not in text:
            print("error: anchor not found (%s)" % label)
            return 1
        text = text.replace(old, new, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(HS, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak14)" % (HS, HS))
    print("  struct fields: comments stripped, malformed fragments dropped")
    print("  inline assembly: dropped, or refused when it writes storage")
    return 0


if __name__ == "__main__":
    sys.exit(main())
