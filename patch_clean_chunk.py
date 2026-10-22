import ast as pyast
import io
import os
import sys

TARGET = os.path.join("aegis", "harness_synth.py")

OLD = '''    kept = []
    for raw in _split_statements(chunk):
        stripped = raw.strip()
        if not stripped or stripped.startswith("//"):
            continue'''

NEW = '''    def _drop_leading_comments(text: str) -> str:
        """Remove comment lines that lead a statement.

        _split_statements cuts on `;`, so a comment sitting above a statement is
        absorbed into that statement's text. Testing the raw text for a leading
        `//` therefore discards the comment AND the code it documents, which
        silently empties phase bodies extracted from commented source.
        """
        prev = None
        while prev != text:
            prev = text
            text = text.strip()
            if text.startswith("//"):
                nl = text.find("\\n")
                text = "" if nl == -1 else text[nl + 1:]
            elif text.startswith("/*"):
                end = text.find("*/")
                text = "" if end == -1 else text[end + 2:]
        return text.strip()

    kept = []
    for raw in _split_statements(chunk):
        stripped = _drop_leading_comments(raw)
        if not stripped:
            continue'''


def main():
    if not os.path.exists(TARGET):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(TARGET, encoding="utf-8").read()
    if "_drop_leading_comments" in text:
        print("already patched")
        return 0
    if OLD not in text:
        print("error: anchor not found in _clean_chunk")
        return 1
    io.open(TARGET + ".bak3", "w", encoding="utf-8").write(text)
    text = text.replace(OLD, NEW, 1)
    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(TARGET, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak3)" % (TARGET, TARGET))
    print("  statements preceded by a comment are no longer discarded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
