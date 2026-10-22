import ast as pyast
import io
import os
import sys

SH = os.path.join("aegis", "slice_harness.py")
MARKER = "_balanced_mapping_type"

HELPER = '''
def _balanced_mapping_type(text, start):
    """Return the full `mapping(...)` type beginning at `start`, or None.

    A non-greedy `mapping\\\\s*\\\\(.*?\\\\)` stops at the first closing
    parenthesis, so a mapping whose value is itself a mapping is never matched
    and the variable it declares is not recognised as state at all.
    """
    i = text.find("(", start)
    if i == -1:
        return None
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "(":
            depth += 1
        elif text[j] == ")":
            depth -= 1
            if depth == 0:
                return text[start:j + 1]
    return None
'''

OLD_FN = '''def state_vars(body):
    """name -> declared type, for storage declarations at contract level."""
    spans = []
    for m in re.finditer(r"function\\s+\\w*\\s*\\([^;{]*\\{", body):
        end = _match(body, m.end() - 1)
        if end != -1:
            spans.append((m.start(), end))
    out = {}
    pat = re.compile(
        r"^[ \\t]*((?:mapping\\s*\\(.*?\\)|%s|[A-Z]\\w*)(?:\\s*\\[[^\\]]*\\])*)"
        r"((?:\\s+(?:public|private|internal|constant|immutable|override))*)"
        r"\\s+([A-Za-z_]\\w*)\\s*(?:=[^;]*)?;" % _ELEM, re.M)
    for m in pat.finditer(body):
        if any(a <= m.start() <= b for a, b in spans):
            continue
        if "constant" in m.group(2) or "immutable" in m.group(2):
            continue
        out[m.group(3)] = m.group(1).strip()
    return out'''

NEW_FN = '''def state_vars(body):
    """name -> declared type, for storage declarations at contract level."""
    spans = []
    for m in re.finditer(r"function\\s+\\w*\\s*\\([^;{]*\\{", body):
        end = _match(body, m.end() - 1)
        if end != -1:
            spans.append((m.start(), end))

    out = {}
    tail = re.compile(
        r"^((?:\\s*\\[[^\\]]*\\])*)"
        r"((?:\\s+(?:public|private|internal|constant|immutable|override))*)"
        r"\\s+([A-Za-z_]\\w*)\\s*(?:=[^;]*)?;")

    for m in re.finditer(r"^[ \\t]*(mapping\\b)", body, re.M):
        if any(a <= m.start() <= b for a, b in spans):
            continue
        vtype = _balanced_mapping_type(body, m.start(1))
        if not vtype:
            continue
        rest = body[m.start(1) + len(vtype):]
        tm = tail.match(rest)
        if not tm or "constant" in tm.group(2) or "immutable" in tm.group(2):
            continue
        out[tm.group(3)] = (vtype + tm.group(1)).strip()

    pat = re.compile(
        r"^[ \\t]*((?:%s|[A-Z]\\w*)(?:\\s*\\[[^\\]]*\\])*)"
        r"((?:\\s+(?:public|private|internal|constant|immutable|override))*)"
        r"\\s+([A-Za-z_]\\w*)\\s*(?:=[^;]*)?;" % _ELEM, re.M)
    for m in pat.finditer(body):
        if any(a <= m.start() <= b for a, b in spans):
            continue
        if "constant" in m.group(2) or "immutable" in m.group(2):
            continue
        out.setdefault(m.group(3), m.group(1).strip())
    return out'''


def main():
    if not os.path.exists(SH):
        print("error: aegis/slice_harness.py not found")
        return 1
    text = io.open(SH, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    if OLD_FN not in text:
        print("error: state_vars not found in expected form")
        return 1
    io.open(SH + ".bak9", "w", encoding="utf-8").write(text)

    text = text.replace("def state_vars(body):",
                        HELPER.strip() + "\n\n\ndef state_vars(body):", 1)
    text = text.replace(OLD_FN, NEW_FN, 1)

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(SH, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak9)" % (SH, SH))
    print("  nested-mapping state variables now recognised")
    return 0


if __name__ == "__main__":
    sys.exit(main())
