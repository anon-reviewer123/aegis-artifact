import ast as pyast
import io
import os
import sys

HS = os.path.join("aegis", "harness_synth.py")

LOCALS_OLD_START = "def _declared_locals(body: str) -> set:"

LOCALS_NEW = '''def _declared_locals(body: str) -> set:
    """Names introduced by local declarations inside a generated phase or
    wrapper body.

    Must cover every declaration form real code uses, not just bare elementary
    scalars: array types, an explicit data location, and tuple destructuring all
    introduce names. A name missed here is treated as free by the resolver and
    redeclared as storage, which both shadows the local and rewrites the
    declaration into `uint256[] memory = amount;`.
    """
    out = set()
    body = _strip_comments_strings(body)

    elem = (r"(?:u?int\\d*|address(?:\\s+payable)?|bool|bytes\\d*|string|"
            r"mapping\\s*\\([^)]*\\)|[A-Z]\\w*(?:\\.\\w+)?)")
    loc = r"(?:\\s+(?:storage|memory|calldata))?"
    arr = r"(?:\\s*\\[[^\\]]*\\])*"

    # `T[] memory name = ...;`  /  `T name;`
    for m in re.finditer(rf"\\b{elem}{arr}{loc}\\s+([A-Za-z_]\\w*)\\s*(?==|;|,|\\))",
                         body):
        out.add(m.group(1))

    # tuple destructuring: `(bool ok, bytes memory ret) = f();`
    for m in re.finditer(r"\\(([^()]*)\\)\\s*=", body):
        for part in m.group(1).split(","):
            part = part.strip()
            if not part:
                continue
            mm = re.match(rf"^{elem}{arr}{loc}\\s+([A-Za-z_]\\w*)$", part)
            if mm:
                out.add(mm.group(1))

    out.discard("memory")
    out.discard("storage")
    out.discard("calldata")
    out.discard("payable")
    return out
'''

PRAGMA_OLD_START = "def _best_pragma(src: str) -> str:"

PRAGMA_NEW = '''def _best_pragma(src: str) -> str:
    """Pragma for the generated harness.

    The harness is freshly generated 0.8 code, so it needs a floor rather than
    the source's own constraint. Echoing an exact pin (`0.8.17`, `=0.8.19`)
    forces a solc build that may not be installed, and resolution then falls
    back to whatever `solc` happens to be, producing a version mismatch. A floor
    lets any installed 0.8.x compile it.
    """
    floors = []
    for m in re.finditer(r"pragma\\s+solidity\\s+([^;]+);", src):
        for n in re.findall(r"(\\d+)\\.(\\d+)\\.?(\\d+)?", m.group(1)):
            floors.append(tuple(int(x or 0) for x in n))
    if not floors:
        return ""
    top = max(floors)
    if top < (0, 8, 0):
        return "pragma solidity >=0.8.0;"
    return "pragma solidity >=%d.%d.%d;" % top
'''


def replace_def(text, start_marker, new_src):
    i = text.find(start_marker)
    if i == -1:
        return None
    j = text.find("\ndef ", i + 1)
    k = text.find("\n_", i + 1)
    ends = [x for x in (j, k) if x != -1]
    end = min(ends) if ends else len(text)
    return text[:i] + new_src.rstrip() + "\n\n" + text[end + 1:]


def main():
    if not os.path.exists(HS):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(HS, encoding="utf-8").read()
    if "tuple destructuring" in text:
        print("already patched")
        return 0
    io.open(HS + ".bak9", "w", encoding="utf-8").write(text)

    for marker, new, label in ((LOCALS_OLD_START, LOCALS_NEW, "_declared_locals"),
                               (PRAGMA_OLD_START, PRAGMA_NEW, "_best_pragma")):
        res = replace_def(text, marker, new)
        if res is None:
            print("error: %s not found" % label)
            return 1
        text = res

    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(HS, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak9)" % (HS, HS))
    print("  local declarations: arrays, data locations, tuple destructuring")
    print("  harness pragma emitted as a floor, never an exact pin")
    return 0


if __name__ == "__main__":
    sys.exit(main())
