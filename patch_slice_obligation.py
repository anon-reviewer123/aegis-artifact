import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "def build_slice_obligation("

HELPER = '''
_STRICT_LOCAL = re.compile(
    r"^\\s*((?:mapping\\s*\\([^)]*\\)|[A-Za-z_]\\w*)(?:\\s*\\[[^\\]]*\\])*)"
    r"(?:\\s+(?:memory|storage|calldata))?"
    r"\\s+([A-Za-z_]\\w*)\\s*(?==|;)", re.M)


def _strict_locals(text):
    """Names a body declares itself.

    Deliberately stricter than the harness-wide detector: it only accepts a
    type followed by a name at the start of a statement. A looser rule
    misclassifies ordinary expressions as declarations, and the name then gets
    neither a local nor a state declaration.
    """
    out = set()
    for m in _STRICT_LOCAL.finditer(_strip(text)):
        t = m.group(1)
        if t in ("return", "emit", "revert", "require", "assert", "if",
                 "for", "while", "else", "delete", "new"):
            continue
        out.add(m.group(2))
    return out


_ENV_READS = (
    (r"address\\s*\\(\\s*this\\s*\\)\\s*\\.\\s*balance", "_ethBalance"),
    (r"\\bmsg\\s*\\.\\s*value\\b", "amount"),
    (r"\\bblock\\s*\\.\\s*timestamp\\b", "_blockTime"),
    (r"\\bblock\\s*\\.\\s*number\\b", "_blockNum"),
    (r"\\bgasleft\\s*\\(\\s*\\)", "_gasLeft"),
)


def _stabilize_env(text):
    """Bind environment reads to state variables.

    `address(this).balance` and `gasleft()` are unconstrained at every
    occurrence, so a view reading one returns a fresh value on each call and any
    comparison across the callback window is decided by that noise rather than
    by the contract. Binding them once keeps them unknown but consistent.
    """
    for pat, name in _ENV_READS:
        text = re.sub(pat, name, text)
    return text


_ENV_DECLS = """    uint256 _ethBalance;
    uint256 _blockTime;
    uint256 _blockNum;
    uint256 _gasLeft;"""


def build_slice_obligation(src, contract, exposure_fn, view_fn):
    """Slice plus the read-only reentrancy obligation.

    The property is that the view never exposes a state corresponding to no
    quiescent point: its value during the callback window must equal either the
    value on entry or the value once the call has settled. A contract that
    applies all of its updates on one side of the external call satisfies this;
    one that splits an update across the call does not, which is the shape the
    Curve and Balancer incidents took.
    """
    body, err = build_slice_harness(src, contract, exposure_fn, view_fn)
    if body is None:
        return None, err
    m = re.search(r"function observed\\(\\) public view returns \\(([^)]*)\\)",
                  body)
    rtype = m.group(1).strip() if m else "uint256"
    cast = "uint256" if rtype not in ("bool",) else "uint256"
    conv = {
        "bool": "(%s ? 1 : 0)",
        "address": "uint256(uint160(%s))",
    }.get(rtype if not rtype.startswith("address") else "address",
          "uint256(%s)")
    obs = conv % "observed()"
    check = """
    function check(uint256 amount) public {
        uint256 entry = %s;
        beginExposed(amount);
        uint256 during = %s;
        endExposed(amount);
        uint256 settled = %s;
        assert(during == entry || during == settled);
    }
""" % (obs, obs, obs)
    return body.rstrip()[:-1] + check + "}\\n", ""
'''

ENV_OLD = '''    pre = _repair_havoc_tuples(pre)
    post = _repair_havoc_tuples(post)'''

ENV_NEW = '''    pre = _stabilize_env(_repair_havoc_tuples(pre))
    post = _stabilize_env(_repair_havoc_tuples(post))
    v_body = _stabilize_env(v_body)'''

FREE_VARIANTS = [
    '''    locals_declared = _local_names(pre) | _local_names(post) \\
        | _local_names(v_body)
    free = (identifiers(pre) | identifiers(post) | identifiers(v_body)) \\
        - relevant - known - pnames - locals_declared - {"amount"}''',
    '''    free = (identifiers(pre) | identifiers(post) | identifiers(v_body)) \\
        - relevant - known - pnames - {"amount"}''',
]
FREE_OLD = None

FREE_NEW = '''    declared_locally = _strict_locals(pre) | _strict_locals(post) \\
        | _strict_locals(v_body)
    free = (identifiers(pre) | identifiers(post) | identifiers(v_body)) \\
        - relevant - known - pnames - declared_locally \\
        - {"amount", "_ethBalance", "_blockTime", "_blockNum", "_gasLeft"}'''

DECL_OLD = '''    uint256 _havoc;
'''

DECL_NEW = '''    uint256 _havoc;
{env}
'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    io.open(SH + ".bak4", "w", encoding="utf-8").write(text)

    anchor = "def build_slice_harness("
    if anchor not in text:
        print("error: build_slice_harness not found")
        return 1

    hit = False
    for variant in FREE_VARIANTS:
        if variant in text:
            text = text.replace(variant, FREE_NEW, 1)
            hit = True
            break
    if not hit:
        print("error: free-identifier block not found")
        return 1
    for old, new, label in ((ENV_OLD, ENV_NEW, "env stabilisation"),
                            (DECL_OLD, DECL_NEW, "env declarations")):
        if old not in text:
            print("error: anchor not found (%s)" % label)
            return 1
        text = text.replace(old, new, 1)

    text = text.replace('           rtype=rtype, v_body=v_body), "")',
                        '           rtype=rtype, v_body=v_body,\n'
                        '           env=_ENV_DECLS), "")', 1)

    text = text + "\n\n" + HELPER.strip() + "\n"

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(SH, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak4)" % (SH, SH))
    print("  three-point read-only obligation added")
    print("  environment reads bound to stable state variables")
    print("  local declarations detected strictly")
    return 0


if __name__ == "__main__":
    sys.exit(main())
