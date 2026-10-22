import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import compiler, harness_synth, static_analysis, synth
from aegis.backend import ObligationResult as R
from aegis.failsafe import localize

FIX = os.path.join(os.path.dirname(__file__), "..", "contracts", "corpus",
                   "CrossFunctionDesync_U06.sol")
TARGET = "aum == trackedValue"


class _Plan:
    pass


def _obligations():
    src = open(FIX).read()
    f = static_analysis.analyze(FIX)
    s = f.exposure_sites[0]
    h = harness_synth.synthesize_harness(src, f, s, TARGET)
    plan = synth.sample_plans(f, s, TARGET, backend="stub", k=1)[0]
    return plan, compiler.compile_obligations(plan, f, h)


def _modules(results):
    loc = localize(_Plan(), results)
    return sorted(loc.correct_modules()), sorted(loc.in_progress_modules())


def test_every_callback_gets_a_reachability_canary():
    """OBL_post is only meaningful if a callback can run inside the window.
    TraderSpirits guards its mint with `amount >= mintPrice * quantity`, a
    product of two unknowns; a path the solver deems unsatisfiable is a path
    the adversary never takes, and the post-phase is then proved over states
    the adversary cannot produce."""
    plan, obs = _obligations()
    names = {o.name for o in obs}
    for f in plan.closure.functions:
        assert f"OBL_reach_{f}_canary" in names, f


def test_the_canary_drives_the_callback_and_asserts_false():
    _plan, obs = _obligations()
    c = [o for o in obs if o.name.endswith("_canary")][0]
    check = c.harness_source[c.harness_source.index("function check"):]
    assert "v.beginExposed(amount)" in check
    assert "assert(false)" in check


def test_a_reachable_callback_does_not_block():
    base = [R("OBL_pre", "phases", "verified"), R("OBL_post", "phases", "verified")]
    _ok, bad = _modules(base + [R("OBL_reach_f_canary", "phases", "failed")])
    assert not bad


def test_an_unreachable_callback_blocks_the_proof():
    base = [R("OBL_pre", "phases", "verified"), R("OBL_post", "phases", "verified")]
    _ok, bad = _modules(base + [R("OBL_reach_f_canary", "phases", "verified")])
    assert "phases" in bad


def test_an_undecided_canary_also_blocks():
    """If the solver cannot tell whether the callback is reachable, the
    premise the proof rests on is unconfirmed."""
    base = [R("OBL_pre", "phases", "verified"), R("OBL_post", "phases", "verified")]
    _ok, bad = _modules(base + [R("OBL_reach_f_canary", "phases", "unknown")])
    assert "phases" in bad


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL REACH-CANARY TESTS PASSED")
