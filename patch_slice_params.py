import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_bind_exposure_params"

HELPER = '''
def _bind_exposure_params(params, relevant):
    """Declarations binding the exposure function's own parameters.

    The sliced phases are that function's statements, so they still refer to its
    parameters by name (`supply -= burn;`). The obligation drives the phases
    through a uniform `amount`, so every other parameter needs a local binding
    or the body references an undeclared name.
    """
    out, primary = [], False
    for p in _split_returns(params or ""):
        p = " ".join(p.split())
        if not p or " " not in p:
            continue
        parts = p.split()
        name = parts[-1]
        if name in relevant or name == "amount":
            continue
        ptype = " ".join(parts[:-1])
        ptype = re.sub(r"\\b(memory|calldata|storage)\\b", " ", ptype)
        ptype = " ".join(ptype.split())
        base = ptype.split("[")[0].strip()
        if "[" in ptype or base in ("bytes", "string"):
            continue
        if base in ("uint256", "uint") and not primary:
            primary = True
            out.append("        uint256 %s = amount;" % name)
        elif re.fullmatch(r"uint\\d*", base):
            out.append("        %s %s = %s(amount);" % (base, name, base))
        elif re.fullmatch(r"int\\d*", base):
            out.append("        %s %s = %s(int256(amount));" % (base, name,
                                                                base))
        elif base.startswith("address"):
            out.append("        address %s = address(0);" % name)
        elif base == "bool":
            out.append("        bool %s = amount != 0;" % name)
        elif re.fullmatch(r"bytes([1-9]|[12]\\d|3[0-2])", base):
            out.append("        %s %s = %s(bytes32(amount));" % (base, name,
                                                                 base))
        else:
            out.append("        uint256 %s;" % name)
    return ("\\n".join(out) + "\\n") if out else ""


_ADDR_HELPER = """    function _addrOf(uint256 v) internal pure returns (address) {
        return address(uint160(v));
    }
"""
'''

OLD = '''    pre = _stabilize_env(_repair_havoc_tuples(pre))'''

NEW = '''    _bindings = _bind_exposure_params(e_params, set())
    _need_addr = "_addrOf(" in _bindings
    if _bindings:
        pre = _bindings + pre
        post = _bindings + post
    pre = _stabilize_env(_repair_havoc_tuples(pre))'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    if OLD not in text:
        print("error: anchor not found")
        return 1
    io.open(SH + ".bak7", "w", encoding="utf-8").write(text)

    anchor = "def _stabilize_env(text):"
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)
    text = text.replace(OLD, NEW, 1)
    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(SH, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak7)" % (SH, SH))
    print("  exposure-function parameters bound inside the slice")
    return 0


if __name__ == "__main__":
    sys.exit(main())
