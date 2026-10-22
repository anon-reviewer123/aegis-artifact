import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis.backend import ObligationResult as R
from aegis.failsafe import localize


class _Plan:
    pass


def _status(results):
    loc = localize(_Plan(), results)
    return sorted(loc.correct_modules()), sorted(loc.in_progress_modules())


def test_every_obligation_must_be_discharged():
    ok, _ = _status([R("OBL_pre", "phases", "verified"),
                     R("OBL_post", "phases", "verified"),
                     R("OBL_cb_f", "closure", "verified")])
    assert "phases" in ok and "closure" in ok


def test_an_undecided_obligation_blocks():
    """TraderSpirits was reported VERIFIED with OBL_post timed out and no
    callback obligation at all."""
    _ok, bad = _status([R("OBL_pre", "phases", "verified"),
                        R("OBL_post", "phases", "unknown")])
    assert "phases" in bad


def test_a_failed_obligation_blocks_even_beside_a_verified_deterministic_one():
    _ok, bad = _status([R("OBL_pre", "phases", "verified"),
                        R("OBL_post", "phases", "failed"),
                        R("OBL_view_x", "readonly", "verified")])
    assert "phases" in bad


def test_a_fired_canary_does_not_block():
    """A canary is meant to fail: that is what shows the harness body is
    reachable and the proof beside it not vacuous."""
    ok, bad = _status([R("OBL_view_x_canary", "readonly", "failed"),
                       R("OBL_view_x", "readonly", "verified")])
    assert not bad


def test_the_site_function_gets_a_callback_obligation():
    """Re-entering the function that made the call is the classic pattern;
    the compiler used to skip it."""
    import re
    src = open(os.path.join(os.path.dirname(__file__), "..", "aegis",
                            "compiler.py")).read()
    assert "if f == plan.phases.function:\n                continue" not in src


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL DISCHARGE TESTS PASSED")
