import ast as pyast
import io
import os
import sys

HS = os.path.join("aegis", "harness_synth.py")

SPLIT_OLD = '''    def _split_statements(text):
        parts, buf, depth = [], [], 0
        for chprev in text:
            if chprev == "{":
                depth += 1
            elif chprev == "}":
                depth -= 1
            buf.append(chprev)
            if chprev == ";" and depth == 0:
                parts.append("".join(buf)); buf = []
        if "".join(buf).strip():
            parts.append("".join(buf))
        return parts'''

SPLIT_NEW = '''    def _split_statements(text):
        """Split on statement-terminating semicolons.

        Depth must count parentheses and brackets as well as braces: a `for`
        header carries two semicolons inside its parentheses, and cutting there
        splits the header into fragments that cannot parse. That single omission
        accounts for the dangling-paren, primary-expression and stray-`for`
        failures seen on real contracts.
        """
        parts, buf, depth = [], [], 0
        for chprev in text:
            if chprev in "{([":
                depth += 1
            elif chprev in "})]":
                depth -= 1
            buf.append(chprev)
            if chprev == ";" and depth <= 0:
                parts.append("".join(buf))
                buf = []
                depth = 0
        if "".join(buf).strip():
            parts.append("".join(buf))
        return parts'''

PRAGMA_OLD = '''    pragma = _extract_pragma(contract_src) or "pragma solidity >=0.8.0;"'''

PRAGMA_NEW = '''    pragma = _best_pragma(contract_src) or "pragma solidity >=0.8.0;"'''

BEST_PRAGMA = '''
def _best_pragma(src: str) -> str:
    """Choose the pragma governing the harness.

    Flattened sources concatenate many files, each keeping its own pragma, so
    the first one encountered is usually an inlined library's (often 0.4 or
    0.5) rather than the deployed contract's. The harness is generated 0.8
    code, so take the highest floor declared anywhere in the file.
    """
    best, best_key = "", None
    for m in re.finditer(r"pragma\\s+solidity\\s+([^;]+);", src):
        spec = m.group(1).strip()
        nums = re.findall(r"(\\d+)\\.(\\d+)\\.?(\\d+)?", spec)
        if not nums:
            continue
        key = max(tuple(int(x or 0) for x in n) for n in nums)
        if best_key is None or key > best_key:
            best, best_key = "pragma solidity %s;" % spec, key
    if best_key and best_key < (0, 8, 0):
        return "pragma solidity >=0.8.0;"
    return best
'''


def patch(path, edits, marker, insert=None, anchor=None):
    text = io.open(path, encoding="utf-8").read()
    if marker in text:
        print("  %s already patched" % path)
        return True
    io.open(path + ".bak8", "w", encoding="utf-8").write(text)
    if insert and anchor:
        if anchor not in text:
            print("  error: insert anchor missing in %s" % path)
            return False
        text = text.replace(anchor, insert.strip() + "\n\n\n" + anchor, 1)
    for old, new, label in edits:
        if old not in text:
            print("  error: anchor not found (%s)" % label)
            return False
        text = text.replace(old, new, 1)
    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("  error: %s would not parse (%s)" % (path, e))
        return False
    io.open(path, "w", encoding="utf-8").write(text)
    print("  patched %s (backup %s.bak8)" % (path, path))
    return True


def main():
    if not os.path.exists(HS):
        print("error: run from the aegis_dist root")
        return 1
    ok = patch(HS,
               [(SPLIT_OLD, SPLIT_NEW, "statement splitter"),
                (PRAGMA_OLD, PRAGMA_NEW, "pragma selection")],
               marker="_best_pragma",
               insert=BEST_PRAGMA,
               anchor="def _extract_pragma(")
    if not ok:
        return 1
    print("\n  statement splitting now counts parens and brackets")
    print("  harness pragma taken from the highest floor in the file")
    return 0


if __name__ == "__main__":
    sys.exit(main())
