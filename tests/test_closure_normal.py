import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import static_analysis, synth, validator

FIX = os.path.join(os.path.dirname(__file__), "..", "contracts", "corpus",
                   "CrossFunctionDesync_U06.sol")
TARGET = "aum == trackedValue"


def _normalised():
    f = static_analysis.analyze(FIX)
    s = f.exposure_sites[0]
    cons = sorted(f.conservative_closure(s))
    plan = synth.sample_plans(f, s, TARGET, backend="stub", k=1)[0]
    # a proposer may pad the closure with anything public
    plan.closure.functions = sorted(set(plan.closure.functions) |
                                    {"setFee", "setOwner"})
    plan.closure.functions = list(cons)
    plan.protocol.allowed_callbacks = list(cons)
    plan.protocol.nesting_bound = {x: 1 for x in cons}
    return f, s, plan, cons


def test_padding_is_removed_and_gaps_are_filled():
    """ReservaX: the proposer added fourteen owner-only setters the access
    filter had excluded, and each became an obligation re-solved every round."""
    _f, _s, plan, cons = _normalised()
    assert plan.closure.functions == cons
    assert "setFee" not in plan.closure.functions


def test_the_normalised_plan_validates():
    f, s, plan, _cons = _normalised()
    assert validator.validate(plan, f, s) == []


def test_the_protocol_matches_the_closure():
    _f, _s, plan, cons = _normalised()
    assert plan.protocol.allowed_callbacks == cons
    assert set(plan.protocol.nesting_bound) == set(cons)


def test_the_trim_holds_at_obligation_build_time():
    """The repair loop re-synthesizes the closure through the proposer, which
    hands back a padded one; trimming only where candidates are made left
    ReservaX building fourteen callback obligations against an empty
    conservative closure."""
    from aegis import compiler, harness_synth
    f = static_analysis.analyze(FIX)
    s = f.exposure_sites[0]
    cons = sorted(f.conservative_closure(s))
    h = harness_synth.synthesize_harness(open(FIX).read(), f, s, TARGET)
    plan = synth.sample_plans(f, s, TARGET, backend="stub", k=1)[0]
    plan.closure.functions = sorted(set(plan.closure.functions) |
                                    {"setFee", "setOwner", "pause"})
    obs = compiler.compile_obligations(plan, f, h)
    cb = sorted(o.name[len("OBL_cb_"):] for o in obs
                if o.name.startswith("OBL_cb_"))
    assert cb == cons
    assert plan.closure.functions == cons


def test_an_empty_conservative_closure_builds_no_callback_obligation():
    """Nothing the adversary can call touches the invariant, so the callback
    guarantee is vacuous."""
    from aegis import compiler, harness_synth
    f = static_analysis.analyze(FIX)
    s = f.exposure_sites[0]
    h = harness_synth.synthesize_harness(open(FIX).read(), f, s, TARGET)
    plan = synth.sample_plans(f, s, TARGET, backend="stub", k=1)[0]
    f.privileged = {n: ("access", "test") for n in f.functions}
    plan.closure.functions = ["setFee", "withdraw"]
    obs = compiler.compile_obligations(plan, f, h)
    assert not [o for o in obs if o.name.startswith("OBL_cb_")]


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL CLOSURE NORMALISATION TESTS PASSED")
