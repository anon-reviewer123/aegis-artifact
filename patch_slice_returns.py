import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_TYPE_NAME = re.compile"

TYPES_BLOCK = '''
_TYPE_NAME = re.compile(
    r"^(?:u?int(?:8|16|24|32|40|48|56|64|72|80|88|96|104|112|120|128|136|144|"
    r"152|160|168|176|184|192|200|208|216|224|232|240|248|256)?|"
    r"bytes(?:[1-9]|[12]\\d|3[0-2])?|address|bool|string|mapping)$")


def _is_type_name(word):
    """True for a Solidity type used where an identifier might be expected.

    Sized elementary types are not in the keyword list, so a transcribed
    `uint256 x = 1;` leaves `uint256` looking like a free name and it gets
    declared as a variable (`uint256 uint256;`).
    """
    return bool(_TYPE_NAME.match(word))


def _split_returns(text):
    parts, depth, buf = [], 0, ""
    for c in text:
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(buf.strip())
            buf = ""
        else:
            buf += c
    if buf.strip():
        parts.append(buf.strip())
    return parts


def _comparable_return(header, enums):
    """Pick a scalar component of the view's return list to observe.

    A view returning several values, or an enum, is still observable: the
    obligation compares one scalar across the callback window, so projecting a
    single elementary component is enough. Struct and array returns have no
    scalar projection and are reported unsupported.
    """
    m = re.search(r"returns\\s*\\(([^)]*)\\)", header or "")
    if not m:
        return None, None, "view has no return type"
    parts = _split_returns(m.group(1))
    if not parts:
        return None, None, "view has no return type"
    for idx, p in enumerate(parts):
        base = p.strip().split()[0]
        if re.match(_ELEM + r"$", base):
            return ("address" if base.startswith("address") else base), \\
                idx, ""
        if base in enums:
            return "uint256", idx, ""
    return None, None, "view return type not comparable"


def _enum_names(src):
    return {m.group(1) for m in re.finditer(r"\\benum\\s+([A-Za-z_]\\w*)", src)}


def _project_return(body, idx, n_parts, rtype):
    """Rewrite `return (a, b, c);` to yield only the observed component."""
    if n_parts <= 1:
        return body

    def repl(m):
        inner = m.group(1).strip()
        if inner.startswith("(") and inner.endswith(")"):
            comps = _split_returns(inner[1:-1])
            if len(comps) == n_parts:
                return "return %s(%s);" % (
                    "" if rtype != "uint256" else "", comps[idx]) \\
                    .replace("return (", "return ")
        return "return %s(0);" % rtype if rtype != "bool" \\
            else "return false;"
    return re.sub(r"return\\s+([^;]+);", repl, body)
'''

OLD = '''    ret = re.search(r"returns\\s*\\(([^)]*)\\)", v_header or "")
    if not ret:
        return None, "view has no return type"
    rtypes = [t.strip().split()[0] for t in ret.group(1).split(",")
              if t.strip()]
    if len(rtypes) != 1 or not re.match(_ELEM + r"$", rtypes[0]):
        return None, "view return type not comparable"
    rtype = rtypes[0]'''

NEW = '''    enums = _enum_names(src)
    rtype, ridx, rerr = _comparable_return(v_header, enums)
    if rtype is None:
        return None, rerr
    _rparts = len(_split_returns(
        re.search(r"returns\\s*\\(([^)]*)\\)", v_header).group(1)))
    v_body = _project_return(v_body, ridx, _rparts, rtype)'''

IDENT_OLD = '''        if m.group(2) in _KEYWORDS:
            continue
        out.add(m.group(2))
    return out'''

IDENT_NEW = '''        if m.group(2) in _KEYWORDS or _is_type_name(m.group(2)):
            continue
        out.add(m.group(2))
    return out'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    io.open(SH + ".bak", "w", encoding="utf-8").write(text)

    anchor = "def _match(src, open_idx):"
    if anchor not in text:
        print("error: insertion anchor not found")
        return 1
    text = text.replace(anchor, TYPES_BLOCK.strip() + "\n\n\n" + anchor, 1)

    for old, new, label in ((OLD, NEW, "return handling"),
                            (IDENT_OLD, IDENT_NEW, "identifier filter")):
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
    print("patched %s (backup %s.bak)" % (SH, SH))
    print("  sized elementary types no longer declared as variables")
    print("  multi-return and enum-returning views now observable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
