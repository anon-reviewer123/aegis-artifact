import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_seed_params"

HELPER = '''
def _seed_params(decls):
    """Parameters and assignments that put the slice in an arbitrary state.

    A slice starts from the constructor, so every variable is zero and stays
    zero: the only feasible transfer amount is zero, the three observations
    coincide and the obligation holds for any contract. Seeding each variable
    from an unconstrained parameter makes the states the property is about
    reachable.
    """
    params, body = [], []
    for i, line in enumerate(decls.splitlines()):
        m = re.match(r"\\s*(mapping\\s*\\(\\s*([^=)]+?)\\s*=>\\s*([^)]+?)\\s*\\)"
                     r"|[A-Za-z_]\\w*(?:\\s*\\[[^\\]]*\\])*)\\s+([A-Za-z_]\\w*)\\s*;",
                     line)
        if not m:
            continue
        vtype, key, val, name = m.group(1), m.group(2), m.group(3), m.group(4)
        if vtype.startswith("mapping"):
            vt = (val or "uint256").strip()
            if vt.startswith("mapping") or "[" in vt:
                continue
            kt = (key or "uint256").strip()
            idx = "msg.sender" if kt.startswith("address") else "_k%d" % i
            if not kt.startswith("address"):
                params.append("%s _k%d" % (kt, i))
            params.append("%s _s%d" % (vt, i))
            body.append("        %s[%s] = _s%d;" % (name, idx, i))
        elif "[" in vtype:
            continue
        else:
            params.append("%s _s%d" % (vtype, i))
            body.append("        %s = _s%d;" % (name, i))
        if len(params) > 8:
            break
    return params, body
'''

OLD = '''    check = """
    function check(uint256 amount) public {
        uint256 entry = %s;
        beginExposed(amount);
        uint256 during = %s;
        endExposed(amount);
        uint256 settled = %s;
        assert(during == entry || during == settled);
    }
""" % (obs, obs, obs)
    return body.rstrip()[:-1] + check + "}\\n", ""'''

NEW = '''    dm = re.search(r"contract \\w+ \\{\\n(.*?)\\n\\n    function beginExposed",
                   body, re.S)
    seed_params, seed_body = _seed_params(dm.group(1) if dm else "")
    sig = ", ".join(["uint256 amount"] + seed_params)
    check = """
    function check(%s) public {
%s
        uint256 entry = %s;
        beginExposed(amount);
        uint256 during = %s;
        endExposed(amount);
        uint256 settled = %s;
        assert(during == entry || during == settled);
    }
""" % (sig, "\\n".join(seed_body), obs, obs, obs)
    return body.rstrip()[:-1] + check + "}\\n", ""'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    if OLD not in text:
        print("error: check() template not found; apply the obligation patch")
        return 1
    io.open(SH + ".bak6", "w", encoding="utf-8").write(text)

    anchor = "def build_slice_obligation("
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)
    text = text.replace(OLD, NEW, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(SH, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak6)" % (SH, SH))
    print("  obligation now starts from an arbitrary reachable state")
    return 0


if __name__ == "__main__":
    sys.exit(main())
