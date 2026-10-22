import ast as pyast
import io
import os
import sys

TARGET = os.path.join("aegis", "pipeline.py")

OLD = '''            if r.name == "OBL_post" and _det_verified:
                continue  # phase-model artifact, contradicted by a sound proof'''

NEW = '''            # A failed OBL_post used to be discarded here whenever a
            # deterministic obligation verified, on the grounds that it was a
            # phase-model artifact. Those artifacts came from phase bodies that
            # lost statements during extraction and from ledger writes the
            # harness substituted for the contract's own; with both corrected,
            # OBL_post fails only when the post phase genuinely does not restore
            # the stable invariant, which is the defect the obligation exists to
            # catch. Suppressing it reports VERIFIED for a contract whose
            # G_post guarantee was never discharged.'''


def main():
    if not os.path.exists(TARGET):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(TARGET, encoding="utf-8").read()
    if "used to be discarded here" in text:
        print("already patched")
        return 0
    if OLD not in text:
        print("error: anchor not found; OBL_post suppression may have moved")
        return 1
    io.open(TARGET + ".bak", "w", encoding="utf-8").write(text)
    text = text.replace(OLD, NEW, 1)
    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(TARGET, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak)" % (TARGET, TARGET))
    print("  a failed OBL_post now yields BUG_FOUND instead of being discarded")
    return 0


if __name__ == "__main__":
    sys.exit(main())
