import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import backend

os.environ["AEGIS_SOLVER_FALLBACK"] = ""


def _counting(status="unknown"):
    calls = {"n": 0}

    def fake(name, module, src, timeout_ms=0, ext_calls="trusted", solver=""):
        calls["n"] += 1
        return backend.ObligationResult(name, module, status, "detail")
    backend._check_obligation_uncached = fake
    backend._SOLVED.clear()
    return calls


def test_an_identical_obligation_is_solved_once():
    """TRYPTO spent its whole budget re-attempting one OBL_post that came
    back unknown at 300s, once per candidate per round."""
    calls = _counting()
    for _ in range(6):
        res = backend.check_obligation("OBL_post", "phases", "SRC", 300000)
    assert calls["n"] == 1
    assert res.status == "unknown"


def test_a_changed_obligation_is_solved_again():
    calls = _counting()
    backend.check_obligation("OBL_post", "phases", "SRC A", 300000)
    backend.check_obligation("OBL_post", "phases", "SRC B", 300000)
    assert calls["n"] == 2


def test_a_different_budget_is_a_different_question():
    """A longer budget can settle what a shorter one could not."""
    calls = _counting()
    backend.check_obligation("OBL_post", "phases", "SRC", 120000)
    backend.check_obligation("OBL_post", "phases", "SRC", 300000)
    assert calls["n"] == 2


def test_the_name_travels_with_the_reused_result():
    _counting("verified")
    backend.check_obligation("OBL_pre", "phases", "SRC", 1000)
    again = backend.check_obligation("OBL_cb_f", "closure", "SRC", 1000)
    assert again.name == "OBL_cb_f" and again.module == "closure"
    assert again.status == "verified"



def test_an_undecided_obligation_is_retried_with_the_fallback_solver():
    """BULLRUNNERSCLUB: Eldarica left a reachability canary undecided."""
    seen = []

    def fake(name, module, src, timeout_ms=0, ext_calls="trusted", solver=""):
        seen.append((solver, timeout_ms))
        status = "failed" if solver == "z3" else "unknown"
        return backend.ObligationResult(name, module, status, "d")
    backend._check_obligation_uncached = fake
    backend._SOLVED.clear()
    os.environ["AEGIS_SOLVER_FALLBACK"] = "z3"
    try:
        res = backend.check_obligation("OBL_x", "m", "SRC2", 300000)
    finally:
        os.environ["AEGIS_SOLVER_FALLBACK"] = ""
    assert res.status == "failed" and res.detail.endswith("[z3]")
    assert seen == [("", 300000), ("z3", 120000)]



def test_a_canary_gets_a_shorter_chc_run():
    seen = []

    def fake(name, module, src, timeout_ms=0, ext_calls="trusted", solver=""):
        seen.append(timeout_ms)
        return backend.ObligationResult(name, module, "failed", "d")
    backend._check_obligation_uncached = fake
    backend._SOLVED.clear()
    backend.check_obligation("OBL_reach_x_canary", "m", "SRC3", 300000)
    backend.check_obligation("OBL_post", "m", "SRC4", 300000)
    backend.check_obligation("OBL_view_get_balance_canary", "m", "SRC5", 300000)
    assert seen == [120000, 300000, 300000]


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL SOLVED-CACHE TESTS PASSED")
