import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_statement_span"

HELPER = '''
def _top_level_statements(body):
    """Split a function body into top-level statements.

    Depth counts braces, parentheses and brackets, so a `for` header's
    semicolons and any nested block stay inside the statement that owns them. A
    statement ends at a `;` at depth zero, or at the `}` that closes a block
    opened at depth zero.
    """
    out, start, depth = [], 0, 0
    i = 0
    while i < len(body):
        c = body[i]
        if c in "{([":
            depth += 1
        elif c in "})]":
            depth -= 1
            if depth == 0 and c == "}":
                j = i + 1
                # an `else` continues the same statement
                k = j
                while k < len(body) and body[k] in " \\t\\r\\n":
                    k += 1
                if body[k:k + 4] == "else":
                    i += 1
                    continue
                out.append((start, j))
                start = j
        elif c == ";" and depth == 0:
            out.append((start, i + 1))
            start = i + 1
        i += 1
    if body[start:].strip():
        out.append((start, len(body)))
    return out


def _statement_span(body, call_pos):
    """Span of the top-level statement containing the external call.

    Cutting at the call itself splits whatever construct encloses it: a call in
    one branch of an `if / else if / else` chain leaves the remaining branches
    stranded on the post side, and no amount of brace repair recovers a valid
    body from that. Excising the whole enclosing statement keeps both sides
    parseable; the statement's own effects are attributed to the pre-phase,
    where the call occurs.
    """
    for start, end in _top_level_statements(body):
        if start <= call_pos < end:
            return start, end
    return call_pos, call_pos
'''

OLD = '''    cs, ce = _guard_span(e_body, m.start())
    pre = _clean_chunk(e_body[:cs], keep_requires=False)
    post = _clean_chunk(e_body[ce:], keep_requires=False)'''

NEW = '''    cs, ce = _statement_span(e_body, m.start())
    # Statements inside the enclosing construct that precede the call still run
    # before control leaves the contract, so keep them on the pre side.
    _inner = e_body[cs:ce]
    _rel = m.start() - cs
    _inner_pre = _inner[:_rel]
    _inner_pre = _inner_pre[_inner_pre.find("{") + 1:] \\
        if "{" in _inner_pre else ""
    pre = _clean_chunk(e_body[:cs] + "\\n" + _inner_pre, keep_requires=False)
    post = _clean_chunk(e_body[ce:], keep_requires=False)'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    if OLD not in text:
        print("error: cut site not found")
        return 1
    io.open(SH + ".bak10", "w", encoding="utf-8").write(text)

    anchor = "def build_slice_harness("
    text = text.replace(anchor, HELPER.strip() + "\n\n\n" + anchor, 1)
    text = text.replace(OLD, NEW, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(SH, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak10)" % (SH, SH))
    print("  phase cut now falls on statement boundaries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
