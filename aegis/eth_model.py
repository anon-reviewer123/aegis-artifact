"""eth_model.py -- model address(this).balance as a ghost storage variable.

SMTChecker tracks declared storage; address(this).balance is the contract's
live ETH balance, which a harness cannot observe. A ghost uint256 _ethBal
mirrors it: credited by msg.value wherever ETH can arrive, debited wherever ETH
can leave, and the target's address(this).balance is rewritten to it.

What counts as ETH leaving:

  R.call{value: V}(...)    the usual way since 0.8
  R.transfer(V)            one argument only -- an ERC20 transfer takes two
  R.send(V)                likewise

Debiting only transfer and send, as the first version did, left every
`call{value: V}` unaccounted: the real balance fell while the ghost stayed
put, so a contract that paid out without updating its books still satisfied
`books <= _ethBal`. That is a false proof, not a missed one.

A debit is placed immediately before the statement that sends, so the ghost
has already fallen when control passes to the recipient -- which is what the
recipient would observe. When that statement is the body of a brace-less
`if`/`else`, the debit and the statement are wrapped in braces together, so
the debit stays under the same guard.

The ghost is declared in the contract the analysis is about -- the most
derived non-abstract contract that sends ETH, as the AST analyzer chooses --
and the rewrite and the instrumentation are confined to that contract's body.
A flattened file puts Context, Ownable and the like first; declaring the ghost
in whichever `contract` came first put it where the target could not see it.
"""
import re

GHOST = "_ethBal"

_ETH_OUT = re.compile(
    r"\.\s*call\s*\{[^{}]*\bvalue\s*:"          # R.call{value: V}
    r"|\.\s*(?:transfer|send)\s*\((?=[^(),]*(?:\([^()]*\)[^(),]*)*\))")


def needs_eth_model(src: str, prop: str) -> bool:
    # Fire only when the property itself is about the ETH balance. A source that
    # merely mentions address(this).balance in unrelated bundled code must not
    # trigger the transform, which would corrupt AST compilation.
    return "address(this).balance" in prop or GHOST in prop


def _contracts(src):
    """(name, header_start, body_start, body_end) for each concrete contract."""
    out = []
    for m in re.finditer(r"(?<![\w.])(abstract\s+)?contract\s+([A-Za-z_]\w*)"
                         r"[^{;]*\{", src):
        if m.group(1):
            continue
        start = m.end()
        depth, i = 1, start
        while i < len(src) and depth:
            depth += src[i] == "{"
            depth -= src[i] == "}"
            i += 1
        out.append((m.group(2), m.start(), start, i - 1))
    return out


def _target(src):
    cs = _contracts(src)
    if not cs:
        return None
    with_eth = [c for c in cs if _ETH_OUT.search(src[c[2]:c[3]])]
    return (with_eth or cs)[-1]


def _balanced_close(text, i, open_ch="(", close_ch=")"):
    depth = 0
    while i < len(text):
        if text[i] == open_ch:
            depth += 1
        elif text[i] == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _sent_value(body, m):
    """The value expression a matched ETH-out sends, or None."""
    s = m.group(0)
    if "call" in s:
        j = body.index("value", m.start()) + len("value")
        j = body.index(":", j) + 1
        k = j
        depth = 0
        while k < len(body):
            c = body[k]
            if c in "([":
                depth += 1
            elif c in ")]":
                depth -= 1
            elif (c == "," or c == "}") and depth == 0:
                break
            k += 1
        return body[j:k].strip()
    p = body.index("(", m.start())
    q = _balanced_close(body, p)
    if q < 0:
        return None
    return body[p + 1:q].strip()


def _instrument(body):
    """Insert a debit before each statement that sends ETH, and credit
    msg.value at the entry of each payable function, receive and fallback."""
    # credits
    body = re.sub(
        r"((?:function\s+\w+|receive|fallback|constructor)\s*\([^)]*\)"
        r"[^{;]*\bpayable\b[^{;]*\{)",
        r"\1 " + GHOST + " += msg.value;", body)

    # debits, last match first so earlier offsets stay valid
    for m in reversed(list(_ETH_OUT.finditer(body))):
        v = _sent_value(body, m)
        if not v:
            continue
        sep = max(body.rfind(";", 0, m.start()), body.rfind("{", 0, m.start()),
                  body.rfind("}", 0, m.start()))
        stmt_start = sep + 1
        semi = body.find(";", m.end())
        if semi < 0:
            continue
        head = body[stmt_start:m.start()]
        g = re.match(r"(\s*)((?:else\s+)?if\s*\(|else\b)", head)
        debit = f"{GHOST} -= {v}; "
        if g and g.group(2).startswith(("if", "else if")):
            # brace-less guard: the guarded statement starts after its `)`
            p = stmt_start + head.index("(", g.start(2))
            q = _balanced_close(body, p)
            if q < 0 or q > m.start():
                continue
            ins = q + 1
            body = (body[:ins] + " { " + debit + body[ins:semi + 1] + " }"
                    + body[semi + 1:])
        elif g and g.group(2) == "else":
            ins = stmt_start + g.end(2)
            body = (body[:ins] + " { " + debit + body[ins:semi + 1] + " }"
                    + body[semi + 1:])
        else:
            lead = len(head) - len(head.lstrip())
            ins = stmt_start + lead
            body = body[:ins] + debit + body[ins:]
    return body


def transform(src: str, prop: str):
    """Return (new_src, new_prop, changed)."""
    if not needs_eth_model(src, prop):
        return src, prop, False
    t = _target(src)
    if t is None:
        return src, prop, False
    name, _hstart, bstart, bend = t

    body = src[bstart:bend]
    body = body.replace("address(this).balance", GHOST)
    body = _instrument(body)
    decl = f"\n    uint256 public {GHOST}; // [ghost] models address(this).balance"
    src = src[:bstart] + decl + body + src[bend:]

    prop = prop.replace("address(this).balance", GHOST)
    return src, prop, True
