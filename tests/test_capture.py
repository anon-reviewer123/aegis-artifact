import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import (compiler, harness_synth, static_analysis, synth, validator)

SRC = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract K {
    mapping(address => uint256) public balances; uint256 public winnerFunds; bool public withdrawing;
    function deposit() external payable { balances[msg.sender] += msg.value; winnerFunds += msg.value; }
    function withdraw(address to) public {
        require(!withdrawing, "w");
        uint256 amt = balances[msg.sender];
        withdrawing = true;
        (bool ok, ) = payable(to).call{value: amt}(""); require(ok);
        balances[msg.sender] = 0;
        winnerFunds -= amt;
        withdrawing = false;
    }
}"""
TARGET = "_sum_balances == winnerFunds"


def _built():
    p = os.path.join(tempfile.mkdtemp(), "K.sol")
    open(p, "w").write(SRC)
    f = static_analysis.analyze(p)
    s = f.exposure_sites[0]
    h = harness_synth.synthesize_harness(SRC, f, s, TARGET)
    return f, s, h, synth.net_effect_plan(f, s, TARGET, harness_src=h)


def test_the_harness_records_what_the_pre_phase_captured():
    _f, _s, h, _plan = _built()
    assert "// [capture] amt == balances[msg.sender]" in h


def test_the_invariant_carries_the_captured_relation():
    """KatRoyalties zeroes `balances[msg.sender]` and subtracts the captured
    `amt`; those balance out only while the two are still equal, and without
    saying so OBL_post is refuted from states where they differ."""
    _f, _s, _h, plan = _built()
    assert plan.exposure_invariant.formula == \
        "_sum_balances == winnerFunds && amt == balances[msg.sender]"


def test_the_captured_field_is_a_backed_ghost_and_not_the_in_flight_counter():
    _f, _s, _h, plan = _built()
    names = [g.name for g in plan.ghost_state]
    assert names == ["inFlight", "amt"]
    assert [g.backed_by_storage for g in plan.ghost_state if g.name == "amt"] == [True]
    assert compiler._primary_ghost_name(plan) == "inFlight"


def test_the_plan_validates():
    f, s, _h, plan = _built()
    assert validator.validate(plan, f, s) == []


def test_the_obligation_reads_the_capture_through_the_handle():
    f, _s, h, plan = _built()
    obs = compiler.compile_obligations(plan, f, h)
    post = [o for o in obs if o.name == "OBL_post"][0]
    assert "v.amt() == v.balances(address(this))" in post.harness_source


def test_a_callback_obligation_must_preserve_it():
    """A callback that changes the state the value was read from breaks the
    invariant -- which is the race this shape is exposed to."""
    f, _s, h, plan = _built()
    obs = compiler.compile_obligations(plan, f, h)
    cb = [o for o in obs if o.name == "OBL_cb_deposit"][0]
    assert "v.amt() == v.balances(address(this))" in cb.harness_source


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL CAPTURE TESTS PASSED")
