import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import compiler, harness_synth, static_analysis, synth

FIX = os.path.join(os.path.dirname(__file__), "..", "contracts", "corpus",
                   "CrossFunctionDesync_U06.sol")
TARGET = "aum == trackedValue"


def _obligations():
    src = open(FIX).read()
    f = static_analysis.analyze(FIX)
    s = f.exposure_sites[0]
    h = harness_synth.synthesize_harness(src, f, s, TARGET)
    plan = synth.sample_plans(f, s, TARGET, backend="stub", k=1)[0]
    return plan, compiler.compile_obligations(plan, f, h)


def test_the_post_obligation_admits_states_a_callback_produced():
    """The composition theorem requires the post-phase to restore the stable
    invariant from ANY state satisfying the exposure invariant, including one
    an admissible callback produced. With the wrappers trimmed away, only
    states reachable through beginExposed alone remained -- still carrying the
    pre-phase's own guard -- and TraderSpirits was proved safe that way while
    its bug is a nested mint against a stale count followed by the outer
    post-phase minting again."""
    plan, obs = _obligations()
    post = [o for o in obs if o.name == "OBL_post"][0]
    present = set(re.findall(r"function (\w+)\(", post.harness_source))
    for f in plan.closure.functions:
        assert f in present, f
    assert {"beginExposed", "endExposed"} <= present


def test_the_post_obligation_still_drives_only_the_post_phase():
    _plan, obs = _obligations()
    post = [o for o in obs if o.name == "OBL_post"][0]
    check = post.harness_source[post.harness_source.index("function check"):]
    assert "v.endExposed(amount)" in check
    assert "v.beginExposed(amount)" not in check


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL POST-CALLBACK TESTS PASSED")
