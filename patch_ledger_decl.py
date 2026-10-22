import ast as pyast
import io
import os
import sys

TARGET = os.path.join("aegis", "harness_synth.py")

OLD = '''    skip = _GHOST_LEDGER_VARS | _RECEIVER_VARS'''

NEW = '''    # Ledger variables the contract declares itself stay in the state block:
    # the harness no longer supplies bookkeeping for them, so skipping them here
    # would leave them undeclared and resolved as unconstrained symbols.
    skip = (_GHOST_LEDGER_VARS - _CONTRACT_OWNED_LEDGER) | _RECEIVER_VARS'''


def main():
    if not os.path.exists(TARGET):
        print("error: run from the aegis_dist root")
        return 1
    text = io.open(TARGET, encoding="utf-8").read()
    if "_CONTRACT_OWNED_LEDGER" not in text:
        print("error: apply patch_owned_ledger.py first")
        return 1
    if "_GHOST_LEDGER_VARS - _CONTRACT_OWNED_LEDGER) | _RECEIVER_VARS" in text:
        print("already patched")
        return 0
    if OLD not in text:
        print("error: anchor not found in _harness_state_block")
        return 1
    io.open(TARGET + ".bak5", "w", encoding="utf-8").write(text)
    text = text.replace(OLD, NEW, 1)
    try:
        pyast.parse(text)
    except SyntaxError as e:
        print("error: would not parse (%s)" % e)
        return 1
    io.open(TARGET, "w", encoding="utf-8").write(text)
    print("patched %s (backup %s.bak5)" % (TARGET, TARGET))
    print("  contract-owned inFlight/exposed are now declared in the state block")
    return 0


if __name__ == "__main__":
    sys.exit(main())
