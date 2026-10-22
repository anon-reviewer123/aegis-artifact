import ast as pyast
import io
import os
import sys

HS = os.path.join("aegis", "harness_synth.py")

MARKER = "def _binding_value("

HELPER = '''
def _binding_value(ptype: str, base: str, structs: frozenset = frozenset()):
    """A value of type `ptype` derived from the wrapper's `uint256 amount`.

    Every original parameter is bound inside a uniform `(uint256 amount)`
    wrapper, so the binding has to convert rather than assign: `uint16 x =
    amount;` and `uint256[] memory a = amount;` both parse but neither
    typechecks. Narrower integers are truncated explicitly, reference types get
    an empty value, and anything unmodelled is left default-initialised, which
    keeps the harness an over-approximation.
    """
    arr = "[" in ptype
    if arr:
        inner = ptype.split("[")[0].strip()
        if ptype.rstrip().endswith("]") and \\
                re.search(r"\\[\\s*\\d+\\s*\\]$", ptype.strip()):
            return None
        return "new %s[](0)" % inner
    if base in ("bytes", "string"):
        return '""'
    if re.fullmatch(r"bytes([1-9]|[12]\\d|3[0-2])", base):
        return "%s(bytes32(amount))" % base if base != "bytes32" \\
            else "bytes32(amount)"
    if base == "bool":
        return "amount != 0"
    if base.startswith("address"):
        if "payable" in ptype:
            return "payable(address(uint160(amount)))"
        return "address(uint160(amount))"
    if base == "uint256" or base == "uint":
        return "amount"
    if re.fullmatch(r"uint\\d*", base):
        return "%s(amount)" % base
    if re.fullmatch(r"int\\d*", base):
        return "%s(int256(amount))" % base if base != "int256" \\
            else "int256(amount)"
    if base in structs:
        return None
    return None


'''

OLD = '''    lines = []
    aliased_amount = False
    for ptype, pname in params:
        base = ptype.split()[0]  # strip 'memory'/'calldata'/'payable'
        if not aliased_amount and (base.startswith("uint") or base.startswith("int")):
            # bind the primary numeric param to the wrapper's `amount`
            if pname != "amount":
                lines.append(f"        {ptype} {pname} = amount;")
            aliased_amount = True
        elif base.startswith("uint") or base.startswith("int"):
            lines.append(f"        {ptype} {pname} = amount;")
        elif base == "address":
            lines.append(f"        address {pname} = address(this);")
        elif base == "bool":
            lines.append(f"        bool {pname} = false;")
        else:
            # unknown type: default-construct via a zero-ish value
            lines.append(f"        {ptype} {pname};")
    return ("\\n".join(lines) + "\\n") if lines else ""'''

NEW = '''    lines = []
    aliased_amount = False
    for ptype, pname in params:
        base = ptype.split()[0]  # strip 'memory'/'calldata'/'payable'
        decl = ptype
        if ("[" in ptype or base in ("bytes", "string")) and \\
                not re.search(r"\\b(memory|storage|calldata)\\b", ptype):
            decl = ptype + " memory"
        if base in ("uint256", "uint") and not aliased_amount:
            aliased_amount = True
            if pname != "amount":
                lines.append(f"        {decl} {pname} = amount;")
            continue
        val = _binding_value(ptype, base)
        if val is None:
            lines.append(f"        {decl} {pname};")
        else:
            lines.append(f"        {decl} {pname} = {val};")
    return ("\\n".join(lines) + "\\n") if lines else ""'''


def main():
    if not os.path.exists(HS):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(HS, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    if OLD not in text:
        print("error: _param_bindings body not found as expected")
        return 1
    io.open(HS + ".bak12", "w", encoding="utf-8").write(text)

    anchor = "def _param_bindings("
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)
    text = text.replace(OLD, NEW, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(HS, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak12)" % (HS, HS))
    print("  parameter bindings now convert to the declared type")
    return 0


if __name__ == "__main__":
    sys.exit(main())
