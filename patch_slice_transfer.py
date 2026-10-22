import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_transfer_effect"

HELPER = '''
def _call_value_expr(e_body, call_pos):
    """The amount a value-bearing external call sends, as a source expression.

    Recognises `.call{value: X}(...)`, the legacy `.call.value(X)(...)`, and
    `.transfer(X)` / `.send(X)`. Returns None when the call carries no value.
    """
    window = e_body[max(0, call_pos - 200):call_pos + 200]
    m = re.search(r"\\.call\\s*\\{[^}]*\\bvalue\\s*:\\s*([^,}]+)", window)
    if m:
        return m.group(1).strip()
    m = re.search(r"\\.call\\s*\\.\\s*value\\s*\\(\\s*([^)]+?)\\s*\\)", window)
    if m:
        return m.group(1).strip()
    m = re.search(r"\\.(?:transfer|send)\\s*\\(\\s*([^)]+?)\\s*\\)", window)
    if m:
        return m.group(1).strip()
    return None


def _transfer_effect(value_expr, relevant, svars):
    """Statements applying the call's value transfer before control returns.

    Ether leaves the contract when the call is made, not when it returns, so a
    view reading `address(this).balance` sees the reduced amount throughout the
    callback window while any bookkeeping in the post-phase is still pending.
    Omitting this makes the pre-phase empty and the window indistinguishable
    from the entry state, which is why a contract that sends before it settles
    its accounting appeared consistent.
    """
    if not value_expr:
        return ""
    return "        _ethBalance -= %s;\\n" % value_expr
'''

OLD = '''    cs, ce = _guard_span(e_body, m.start())
    pre = _clean_chunk(e_body[:cs], keep_requires=False)
    post = _clean_chunk(e_body[ce:], keep_requires=False)'''

NEW = '''    cs, ce = _guard_span(e_body, m.start())
    pre = _clean_chunk(e_body[:cs], keep_requires=False)
    post = _clean_chunk(e_body[ce:], keep_requires=False)
    _value_expr = _call_value_expr(e_body, m.start())'''

APPLY_OLD = '''    pre = _stabilize_env(_repair_havoc_tuples(pre))'''

APPLY_NEW = '''    pre = _stabilize_env(_repair_havoc_tuples(pre))
    if _value_expr:
        pre = pre.rstrip() + "\\n" + _stabilize_env(
            _transfer_effect(_value_expr, None, None)).rstrip()'''

ENV_USED_OLD = '''    relevant = used_state(pre + post + v_body, svars)'''

ENV_USED_NEW = '''    if _value_expr:
        pre = pre + "\\n        // value leaves at the call\\n"
    relevant = used_state(pre + post + v_body, svars)'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    io.open(SH + ".bak5", "w", encoding="utf-8").write(text)

    anchor = "def _stabilize_env(text):"
    if anchor not in text:
        print("error: _stabilize_env not found; apply the obligation patch first")
        return 1
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)

    for old, new, label in ((OLD, NEW, "value extraction"),
                            (APPLY_OLD, APPLY_NEW, "transfer effect")):
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
    print("patched %s (backup %s.bak5)" % (SH, SH))
    print("  value transferred by the external call now applied pre-callback")
    return 0


if __name__ == "__main__":
    sys.exit(main())
