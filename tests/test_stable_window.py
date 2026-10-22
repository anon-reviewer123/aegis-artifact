import os
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, HERE)

from aegis import static_analysis, synth, validator
from aegis.static_analysis import ExposureSite

FIX = os.path.join(HERE, "tests", "fixtures", "stable_window.sol")
TARGET = "_sum_balances == winnerFunds"


def _site(before, after):
    return ExposureSite(function="w", call=".call", callback_capable=True,
                        reason="", write_before_call=set(before),
                        write_after_call=set(after))


def test_a_mapping_sum_reads_its_mapping():
    assert validator.pre_touches_invariant("_sum_balances == w", _site({"balances"}, set()))
    assert not validator.pre_touches_invariant("_sum_balances == w", _site({"lock"}, {"w"}))


def test_the_eth_debit_before_a_payout_touches_a_balance_invariant():
    assert validator.pre_touches_invariant("books <= _ethBal", _site({"_ethBal"}, {"books"}))


def test_the_target_is_the_plan_when_the_pre_phase_leaves_it_alone():
    """KatRoyalties: the pre-phase writes only the lock, so the target holds
    at the call. Forcing a ghost made OBL_pre fail by construction."""
    f = static_analysis.analyze(FIX)
    s = f.exposure_sites[0]
    plan = synth.stable_window_plan(f, s, TARGET)
    assert plan is not None
    assert plan.exposure_invariant.formula == TARGET
    assert not plan.ghost_state
    assert validator.validate(plan, f, s) == []


def test_no_such_plan_when_the_pre_phase_changes_the_target():
    f = static_analysis.analyze(FIX)
    s = f.exposure_sites[0]
    s.write_before_call = set(s.write_before_call) | {"winnerFunds"}
    assert synth.stable_window_plan(f, s, TARGET) is None


def test_the_stable_invariant_is_still_rejected_when_the_pre_phase_changes_it():
    f = static_analysis.analyze(FIX)
    s = f.exposure_sites[0]
    plan = synth.stable_window_plan(f, s, TARGET)
    s.write_before_call = set(s.write_before_call) | {"winnerFunds"}
    assert "exposure_invariant" in validator.validate(plan, f, s)


def test_an_obl_post_refutation_under_the_stable_invariant_is_not_a_fallback():
    from aegis import pipeline
    f = static_analysis.analyze(FIX)
    plan = synth.stable_window_plan(f, f.exposure_sites[0], TARGET)
    assert pipeline._iexp_is_stable(plan)


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL STABLE-WINDOW TESTS PASSED")
