"""Structural check on the generated griefing step harnesses.

Verifies that each harness carries the contract's own loop-body statements, that
the halt lowering was applied only where the contract propagates the failure,
and that both harnesses carry the same assertion.
"""
import re
import sys

SAFE = "loop_steps/griefing_safe.step.sol"
UNSAFE = "loop_steps/griefing_unsafe.step.sol"

REAL_STATEMENTS = {
    SAFE: ["uint256 amt = owed[c];", "owed[c] = 0;",
           "if (!ok) { owed[c] = amt; failed[c] = true; }"],
    UNSAFE: ["uint256 amt = owed[c];", "owed[c] = 0;", "failed[c] = false;"],
}


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

    safe_no_halt = "halted = true" not in safe_src
    print(f"{'PASS' if safe_no_halt else 'FAIL'}  safe harness cannot set halted "
          f"(the contract records the failure)")
    ok &= safe_no_halt

    unsafe_halts = "if (!(ok)) { halted = true; }" in unsafe_src
    print(f"{'PASS' if unsafe_halts else 'FAIL'}  unsafe harness halts on failure "
          f"(the contract propagates it)")
    ok &= unsafe_halts

    no_revert = "require(ok" not in unsafe_src
    print(f"{'PASS' if no_revert else 'FAIL'}  unsafe harness has no surviving "
          f"revert that would mask the halt")
    ok &= no_revert

    same_assert = (safe_src.count("assert(!halted)") == 1
                   and unsafe_src.count("assert(!halted)") == 1)
    print(f"{'PASS' if same_assert else 'FAIL'}  both harnesses carry the same "
          f"assertion")
    ok &= same_assert

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
