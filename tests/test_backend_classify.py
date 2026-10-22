import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis.backend import _classify


def _s(out):
    return _classify("OBL_x", "phases", out).status


def test_a_missing_horn_solver_is_no_backend():
    """Only a genuinely absent solver may report no_backend, because the
    pipeline turns that into UNAVAILABLE for the entire run."""
    for out in ("Warning: no Horn solver was found",
                "eld was selected for SMTChecker but it is not available",
                "None of the installed solvers can handle this"):
        assert _s(out) == "no_backend", out


def test_an_unencodable_obligation_is_unknown_not_no_backend():
    """The engine is present and running; it could not encode this one query.
    Reporting no_backend would discard every other obligation in the run."""
    out = "Warning: CHC analysis was not possible."
    assert _s(out) == "unknown"


def test_a_compile_error_is_unknown():
    assert _s("Error: Undeclared identifier.") == "unknown"


def test_an_assertion_violation_is_failed():
    out = "Warning: CHC: Assertion violation happens here."
    assert _s(out) == "failed"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL BACKEND CLASSIFY TESTS PASSED")
