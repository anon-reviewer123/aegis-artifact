"""
Loop rebuild, slice 1: extract the CONTRACT'S REAL loop code as source text.

extract_loop_body     -- the loop body split around the in-loop external call.
extract_loop_context  -- the same, plus the function-level statements before and
                         after the loop. Some shapes place the safety mechanism
                         outside the loop (a mutex wrapping the whole loop, a
                         snapshot taken before it, a teardown after it), so the
                         harness must transcribe those too.

Everything returned is a verbatim substring of the contract source, so the
rebuilt harness contains the contract's own code, not authored templates.
"""
import re


def _function_body(contract_src, function_name):
    fn_re = re.compile(
        rf"function\s+{re.escape(function_name)}\s*\([^)]*\)\s*[^{{]*{{",
        re.DOTALL)
    m = fn_re.search(contract_src)
    if not m:
        return None
    start = m.end()
    depth, i = 1, start
    while i < len(contract_src) and depth > 0:
        if contract_src[i] == "{":
            depth += 1
        elif contract_src[i] == "}":
            depth -= 1
        i += 1
    return contract_src[start:i - 1]


def _find_loop(fn_body, call_token):
    """Return (loop_start, body_start, body_end, loop_end) for the loop whose
    body contains call_token, or None."""
    tok = call_token.lstrip(".")
    for lm in re.finditer(r"\b(for|while)\s*\([^{]*\)\s*\{", fn_body):
        bstart = lm.end() - 1
        d, j = 0, bstart
        while j < len(fn_body):
            if fn_body[j] == "{":
                d += 1
            elif fn_body[j] == "}":
                d -= 1
                if d == 0:
                    break
            j += 1
        if j >= len(fn_body):
            continue
        if fn_body[lm.end():j].find(tok) == -1:
            continue
        return lm.start(), lm.end(), j, j + 1
    return None


def _split_around_call(loop_body, call_token):
    """Split the loop body into (pre, call, post) around the external call.

    The statement boundary is found at brace depth zero relative to the loop
    body, so a call that follows a nested block (an `if` guard, say) does not
    cut that block in half and leave `pre` with an unclosed brace.
    """
    tok = call_token.lstrip(".")
    cpos = loop_body.find(tok)
    if cpos == -1:
        return None

    depth, boundary = 0, 0
    for i, ch in enumerate(loop_body[:cpos]):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                boundary = i + 1
        elif ch == ";" and depth == 0:
            boundary = i + 1
    stmt_start = boundary

    stmt_end = loop_body.find(";", cpos)
    stmt_end = len(loop_body) if stmt_end == -1 else stmt_end + 1
    return (loop_body[:stmt_start].strip(),
            loop_body[stmt_start:stmt_end].strip(),
            loop_body[stmt_end:].strip())


def extract_loop_body(contract_src, function_name, call_token=".call"):
    """Loop body split around the in-loop external call:
    {"pre", "call", "post", "loop_header"}. Returns None if not found."""
    ctx = extract_loop_context(contract_src, function_name, call_token)
    if ctx is None:
        return None
    return {"pre": ctx["pre"], "call": ctx["call"], "post": ctx["post"],
            "loop_header": ctx["loop_header"]}


def extract_loop_context(contract_src, function_name, call_token=".call"):
    """Full context around the in-loop external call:

        pre_loop     function statements before the loop header
        loop_header  the loop header text
        pre          loop-body statements before the call
        call         the external call statement
        post         loop-body statements after the call
        post_loop    function statements after the loop's closing brace

    All verbatim source. Returns None if the function or loop is not found.
    """
    fn_body = _function_body(contract_src, function_name)
    if fn_body is None:
        return None
    loc = _find_loop(fn_body, call_token)
    if loc is None:
        return None
    loop_start, body_start, body_end, loop_end = loc
    loop_body = fn_body[body_start:body_end]
    split = _split_around_call(loop_body, call_token)
    if split is None:
        return None
    pre, call_stmt, post = split
    return {
        "pre_loop": fn_body[:loop_start].strip(),
        "loop_header": fn_body[loop_start:body_start].strip(),
        "pre": pre,
        "call": call_stmt,
        "post": post,
        "post_loop": fn_body[loop_end:].strip(),
    }


if __name__ == "__main__":
    import sys
    src = open(sys.argv[1]).read()
    fn = sys.argv[2] if len(sys.argv) > 2 else "settle"
    r = extract_loop_context(src, fn)
    if r is None:
        print("NOT FOUND")
        sys.exit(1)
    for k in ("pre_loop", "loop_header", "pre", "call", "post", "post_loop"):
        print(f"--- {k} ---")
        print(r[k] if r[k] else "(empty)")
