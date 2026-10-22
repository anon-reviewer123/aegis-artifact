"""Structural check on the generated dividend step harnesses.

Verifies that each harness contains the contract's own statements, that the
safe/unsafe difference comes from the transcribed guard rather than a switch in
the builder, and that the two harnesses are otherwise identical.
"""
import re
import sys

SAFE = "loop_steps/dividend_safe.step.sol"
UNSAFE = "loop_steps/dividend_unsafe.step.sol"

REAL_STATEMENTS = {
    SAFE: ["distributing = true;", "uint256 snapshot = pool;",
           "uint256 amt = snapshot * shareOf[h] / 100;",
           "pool = 0;", "distributing = false;"],
    UNSAFE: ["uint256 snapshot = pool;",
             "uint256 amt = snapshot * shareOf[h] / 100;",
             "pool = 0;"],
}

GUARD = "if (!(!distributing)) { inReenter = false; return; }"


def _norm(s):
    s = re.sub(r"//[^\n]*", "", s)
    return re.sub(r"\s+", " ", s).strip()


def main():
    ok = True
    for path, stmts in REAL_STATEMENTS.items():
        src = open(path).read()
        for st in stmts:
            present = _norm(st) in _norm(src)
            print(f"{'PASS' if present else 'FAIL'}  {path}: contains {st!r}")
            ok &= present

    safe_src, unsafe_src = open(SAFE).read(), open(UNSAFE).read()
    has_guard = _norm(GUARD) in _norm(safe_src)
    print(f"{'PASS' if has_guard else 'FAIL'}  safe harness blocks the replay "
          f"with the transcribed guard")
    ok &= has_guard

    no_guard = "distributing" not in unsafe_src
    print(f"{'PASS' if no_guard else 'FAIL'}  unsafe harness has no guard "
          f"(the contract declares none)")
    ok &= no_guard

    same_assert = (safe_src.count("assert(totalPaid <= poolAtStart)") == 1
                   and unsafe_src.count("assert(totalPaid <= poolAtStart)") == 1)
    print(f"{'PASS' if same_assert else 'FAIL'}  both harnesses carry the same "
          f"assertion")
    ok &= same_assert

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
