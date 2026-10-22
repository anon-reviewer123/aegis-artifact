import ast as pyast
import io
import os
import re
import sys

HS = os.path.join("aegis", "harness_synth.py")

MARKER = "upper bound"

NEW_FN = '''def _best_pragma(src: str) -> str:
    """Pragma for the generated harness.

    Only the LOWER bound of each version range counts. A source writing
    `pragma solidity >=0.8.0 <0.9.0;` names 0.9.0 as an exclusive upper bound,
    and treating it as a floor produces a harness no released compiler can
    satisfy, so resolution falls back to whatever `solc` happens to be and the
    version check fails. The harness itself is generated 0.8 code, so a floor
    at the highest declared lower bound is all it needs.
    """
    floors = []
    for m in re.finditer(r"pragma\\s+solidity\\s+([^;]+);", src):
        spec = m.group(1)
        # drop upper-bound clauses: `<0.9.0`, `<=0.8.20`
        spec = re.sub(r"<=?\\s*\\d+\\.\\d+(\\.\\d+)?", " ", spec)
        for n in re.findall(r"(\\d+)\\.(\\d+)\\.?(\\d+)?", spec):
            floors.append(tuple(int(x or 0) for x in n))
    if not floors:
        return ""
    top = max(floors)
    if top < (0, 8, 0):
        top = (0, 8, 0)
    cap = _highest_installed_solc()
    if cap and top > cap:
        top = cap
    return "pragma solidity >=%d.%d.%d;" % top


def _highest_installed_solc():
    """Highest solc build actually available, or None.

    Emitting a floor above every installed compiler leaves resolution with no
    candidate, so it falls back to whatever `solc` resolves to and the version
    check fails on a harness that would otherwise be fine.
    """
    best = None
    try:
        from .ast_analysis import _solc_artifacts_dirs
        dirs = _solc_artifacts_dirs()
    except Exception:
        return None
    for art in dirs:
        try:
            entries = os.listdir(art)
        except Exception:
            continue
        for e in entries:
            m = re.fullmatch(r"solc-(\d+)\.(\d+)\.(\d+)", e)
            if not m:
                continue
            if not os.path.isfile(os.path.join(art, e, e)):
                continue
            v = tuple(int(x) for x in m.groups())
            if best is None or v > best:
                best = v
    return best
'''


def replace_def(text, name, new_src):
    start = text.find("def %s(" % name)
    if start == -1:
        return None
    nxt = re.search(r"^(def |_[A-Z])", text[start + 1:], re.M)
    end = start + 1 + nxt.start() if nxt else len(text)
    return text[:start] + new_src.rstrip() + "\n\n\n" + text[end:]


def main():
    if not os.path.exists(HS):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(HS, encoding="utf-8").read()
    if MARKER in text:
        print("already patched")
        return 0
    if "def _best_pragma(" not in text:
        print("error: _best_pragma not present; apply patch_split_pragma first")
        return 1
    io.open(HS + ".bak13", "w", encoding="utf-8").write(text)
    out = replace_def(text, "_best_pragma", NEW_FN)
    if out is None:
        print("error: could not replace _best_pragma")
        return 1
    try:
        pyast.parse(out)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(HS, "w", encoding="utf-8").write(out)
    print("patched %s (backup %s.bak13)" % (HS, HS))
    print("  pragma floors no longer read upper bounds as minimums")
    return 0


if __name__ == "__main__":
    sys.exit(main())
