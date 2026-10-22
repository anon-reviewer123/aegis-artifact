import re

_ELEM = re.compile(
    r"^(u?int\d*|address(\s+payable)?|bool|bytes\d*|string)$")


def _match_block(src, open_idx):
    depth = 0
    for i in range(open_idx, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    return -1


def contract_span(src, name):
    for m in re.finditer(r"\b(?:abstract\s+)?contract\s+" + re.escape(name) +
                         r"\b[^{]*\{", src):
        end = _match_block(src, m.end() - 1)
        if end != -1:
            return m.start(), m.end(), end
    return None


def _split_params(text):
    out, depth, buf = [], 0, ""
    for c in text:
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        if c == "," and depth == 0:
            out.append(buf.strip())
            buf = ""
        else:
            buf += c
    if buf.strip():
        out.append(buf.strip())
    return out


def _norm_type(p):
    """Return a callable-from-probe type, or None if unsupported."""
    p = p.strip()
    if not p:
        return None
    p = re.sub(r"\b(calldata|memory|storage)\b", " ", p)
    p = re.sub(r"\s+", " ", p).strip()
    toks = p.split()
    if not toks:
        return None
    t = toks[0]
    arr = ""
    m = re.match(r"^(.*?)((\[\s*\d*\s*\])+)$", t)
    if m:
        t, arr = m.group(1), m.group(2).replace(" ", "")
    if not _ELEM.match(t):
        return None
    if t.startswith("address"):
        t = "address"
    if arr:
        return None
    return t


def signature(src, contract, fname):
    """Return (arg_types, is_payable, ok). ok is False when undrivable."""
    span = contract_span(src, contract)
    if not span:
        return [], False, False
    body = src[span[1]:span[2]]
    for m in re.finditer(r"function\s+" + re.escape(fname) + r"\s*\(", body):
        depth, j = 0, m.end() - 1
        while j < len(body):
            if body[j] == "(":
                depth += 1
            elif body[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        params = body[m.end():j]
        rest = body[j + 1:j + 240]
        if not re.match(r"[^{;]*\{", rest):
            continue
        header = rest.split("{")[0]
        if "internal" in header or "private" in header:
            return [], False, False
        types = []
        for p in _split_params(params):
            t = _norm_type(p)
            if t is None:
                return [], False, False
            types.append(t)
        return types, ("payable" in header), True
    return [], False, False


def view_signature(src, contract, vname):
    types, _, ok = signature(src, contract, vname)
    if not ok:
        return None, None
    span = contract_span(src, contract)
    body = src[span[1]:span[2]]
    m = re.search(r"function\s+" + re.escape(vname) +
                  r"\s*\([^)]*\)[^{;]*returns\s*\(([^)]*)\)", body)
    if not m:
        return None, None
    rets = _split_params(m.group(1))
    if len(rets) != 1:
        return None, None
    rt = _norm_type(rets[0])
    if rt is None or rt == "string" or rt == "bytes":
        return None, None
    return types, rt


def _args(types, names=None):
    vals = []
    for i, t in enumerate(types):
        if names:
            vals.append(names[i])
        elif t == "address":
            vals.append("address(this)")
        elif t == "bool":
            vals.append("false")
        elif t.startswith("bytes"):
            vals.append("bytes32(0)" if t != "bytes" else '""')
        elif t == "string":
            vals.append('""')
        else:
            vals.append("0")
    return ", ".join(vals)


def _params(types, prefix="a"):
    return ", ".join(f"{t} {prefix}{i}" for i, t in enumerate(types))


def build_probe(src, contract, exposure_fn, view_fn):
    """Append a differential read-only probe to UNMODIFIED source.

    The probe re-enters through receive() while the exposure function holds the
    contract in an intermediate state, reads the flagged view there, and asserts
    it agrees with the value observed after the call returns. Nothing in the
    original source is rewritten, so inheritance, libraries, structs and
    assembly are handled by solc rather than by reconstruction.
    """
    etypes, payable, ok = signature(src, contract, exposure_fn)
    if not ok:
        return None, "exposure signature not drivable"
    vsig = view_signature(src, contract, view_fn)
    if vsig == (None, None):
        return None, "view signature not drivable"
    vtypes, vret = vsig
    if len(etypes) > 6 or len(vtypes) > 4:
        return None, "too many parameters"

    vargs = _args(vtypes)
    eargs = _args(etypes, [f"a{i}" for i in range(len(etypes))])
    value_mod = "{value: msg.value}" if payable else ""

    probe = f"""
contract AegisProbe_{contract} {{
    {contract} internal t;
    {vret} internal duringVal;
    bool internal armed;
    bool internal observed;

    constructor(address payable target) {{
        t = {contract}(target);
    }}

    receive() external payable {{
        if (armed) {{
            armed = false;
            observed = true;
            duringVal = t.{view_fn}({vargs});
        }}
    }}

    function probe({_params(etypes)}) external payable {{
        armed = true;
        observed = false;
        t.{exposure_fn}{value_mod}({eargs});
        if (observed) {{
            {vret} afterVal = t.{view_fn}({vargs});
            assert(duringVal == afterVal);
        }}
    }}
}}
"""
    return src.rstrip() + "\n" + probe, ""
