import ast as pyast
import io
import os
import sys

TARGET = os.path.join("aegis", "harness_synth.py")

LOCALS_OLD = '''    out = set()
    body = _strip_comments_strings(body)
    for m in re.finditer(r"\\b(?:u?int\\d*|address(?:\\s+payable)?|bool|bytes\\d*|string)\\s+([A-Za-z_]\\w*)\\s*[=;]", body):
        out.add(m.group(1))
    return out'''

LOCALS_NEW = '''    out = set()
    body = _strip_comments_strings(body)
    for m in re.finditer(r"\\b(?:u?int\\d*|address(?:\\s+payable)?|bool|bytes\\d*|string)\\s+([A-Za-z_]\\w*)\\s*[=;]", body):
        out.add(m.group(1))
    # Locals whose type is user-defined (`Order memory o = ...`,
    # `InOutInfo storage info = ...`, `IOwnable rollup_;`). Without these the
    # resolver treats the local NAME as a free identifier and declares a
    # same-named uint256 state variable, which shadows the local and changes
    # its type.
    for m in re.finditer(
            r"\\b([A-Z]\\w*)(?:\\.\\w+)?(?:\\s*\\[\\s*\\])?\\s+"
            r"(?:storage|memory|calldata)?\\s*([A-Za-z_]\\w*)\\s*[=;]", body):
        out.add(m.group(2))
    return out'''

TYPEDEF_HELPER = '''
_ELEMENTARY_PREFIXES = ("uint", "int", "address", "bool", "bytes", "string",
                        "mapping", "fixed", "ufixed")


def _collect_type_defs(src: str) -> tuple:
    """Return (definition_text, defined_names) for every struct and enum in the
    source.

    The harness is a standalone contract, so a transcribed body that mentions a
    struct or enum needs that definition present. Field types naming a contract
    or interface are rewritten to `address`, which is how the harness models any
    external party anyway.
    """
    defined = set()
    blocks = []
    for m in re.finditer(r"\\b(struct|enum)\\s+([A-Za-z_]\\w*)\\s*\\{", src):
        kind, name = m.group(1), m.group(2)
        if name in defined:
            continue
        open_idx = src.find("{", m.end() - 1)
        depth, j = 0, open_idx
        while j < len(src):
            if src[j] == "{":
                depth += 1
            elif src[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if j >= len(src):
            continue
        defined.add(name)
        blocks.append((kind, name, src[open_idx:j + 1]))

    out = []
    for kind, name, body in blocks:
        if kind == "enum":
            out.append("    enum %s %s" % (name, body))
            continue
        inner = body[1:-1]
        fixed = []
        for field in inner.split(";"):
            f = field.strip()
            if not f:
                continue
            mm = re.match(r"^([A-Za-z_]\\w*)((?:\\s*\\[[^\\]]*\\])?)\\s+"
                          r"([A-Za-z_]\\w*)$", f)
            if mm and mm.group(1) not in defined and \\
                    not mm.group(1).startswith(_ELEMENTARY_PREFIXES):
                fixed.append("        address%s %s;" % (mm.group(2), mm.group(3)))
            else:
                fixed.append("        %s;" % f)
        body = "{\\n%s\\n    }" % "\\n".join(fixed)
        out.append("    struct %s %s" % (name, body))
    return ("\\n".join(out) + "\\n") if out else "", defined


def _normalize_unknown_types(body: str, defined: set) -> str:
    """Rewrite locals typed by a contract or interface to `address`.

    `IOwnable rollup_;` cannot compile in an isolated harness because the
    interface is not carried over; the harness models external parties as plain
    addresses, so the declaration becomes `address rollup_;`.
    """
    def repl(m):
        tname, rest, var = m.group(1), m.group(2), m.group(3)
        if tname in defined or tname.startswith(_ELEMENTARY_PREFIXES):
            return m.group(0)
        return "address%s %s" % (rest, var)
    return re.sub(r"\\b([A-Z]\\w*)((?:\\s*\\[\\s*\\])?)\\s+"
                  r"(?:storage\\s+|memory\\s+|calldata\\s+)?([a-z_]\\w*)\\s*(?==|;)",
                  repl, body)
'''

CALL_OLD = '''    _CONTRACT_OWNED_LEDGER.clear()'''

CALL_NEW = '''    _type_defs, _defined_types = _collect_type_defs(contract_src)
    _CONTRACT_OWNED_LEDGER.clear()'''

APPLY_OLD = '''    callback_stubs = _emit_callback_wrappers(contract_src, facts, site)
    view_funcs = _emit_view_functions(contract_src, facts, site)'''

APPLY_NEW = '''    callback_stubs = _emit_callback_wrappers(contract_src, facts, site)
    view_funcs = _emit_view_functions(contract_src, facts, site)
    begin_body = _normalize_unknown_types(begin_body, _defined_types)
    end_body = _normalize_unknown_types(end_body, _defined_types)
    callback_stubs = _normalize_unknown_types(callback_stubs, _defined_types)
    view_funcs = _normalize_unknown_types(view_funcs, _defined_types)'''

EMIT_OLD = '''contract {name}H {{
{storage_decls}'''

EMIT_NEW = '''contract {name}H {{
{_type_defs}{storage_decls}'''


def main():
    if not os.path.exists(TARGET):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(TARGET, encoding="utf-8").read()
    if "_collect_type_defs" in text:
        print("already patched")
        return 0
    io.open(TARGET + ".bak7", "w", encoding="utf-8").write(text)

    anchor = "def _declared_locals("
    if anchor not in text:
        print("error: _declared_locals not found")
        return 1
    text = text.replace(anchor, TYPEDEF_HELPER.strip() + "\n\n\n" + anchor, 1)

    for old, new, label in ((LOCALS_OLD, LOCALS_NEW, "declared locals"),
                            (CALL_OLD, CALL_NEW, "type-def collection"),
                            (APPLY_OLD, APPLY_NEW, "type normalization"),
                            (EMIT_OLD, EMIT_NEW, "type-def emission")):
        if old not in text:
            print("error: anchor not found (%s)" % label)
            return 1
        text = text.replace(old, new, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(TARGET, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak7)" % (TARGET, TARGET))
    print("  struct/enum definitions emitted into the harness")
    print("  user-defined-type locals no longer promoted to storage")
    print("  contract/interface-typed locals rewritten to address")
    return 0


if __name__ == "__main__":
    sys.exit(main())
