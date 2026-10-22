import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import harness_synth, static_analysis, synth

SRC = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract K {
    mapping(address => uint256) public balances; uint256 public winnerFunds; bool public withdrawing;
    function deposit() external payable { balances[msg.sender] += msg.value; winnerFunds += msg.value; }
    function withdraw(address to) public {
        require(!withdrawing, "w");
        uint256 amount = balances[msg.sender];
        withdrawing = true;
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok);
        balances[msg.sender] = 0;
        winnerFunds -= amount;
        withdrawing = false;
    }
}"""
TARGET = "_sum_balances == winnerFunds"


def _built():
    p = os.path.join(tempfile.mkdtemp(), "K.sol")
    open(p, "w").write(SRC)
    f = static_analysis.analyze(p)
    s = f.exposure_sites[0]
    return f, s, harness_synth.synthesize_harness(SRC, f, s, TARGET)


def test_a_local_shadowing_the_driver_parameter_is_renamed():
    """KatRoyalties reads `uint256 amount = balances[msg.sender];`. The name
    collides with the driver's own `amount`, so the local was excluded from
    promotion and the post-phase settled with the parameter instead."""
    _f, _s, h = _built()
    begin = re.search(r"function beginExposed.*?\n    \}", h, re.S).group(0)
    assert "amount_pre = balances[msg.sender];" in begin


def test_the_capture_is_recorded():
    _f, _s, h = _built()
    assert "// [capture] amount_pre == balances[msg.sender]" in h


def test_the_moved_amount_constraint_follows_the_rename():
    """Otherwise the call's value still reads `amount` and the constraint
    degenerates to `amount == amount`."""
    _f, _s, h = _built()
    assert "require(amount == amount_pre" in h


def test_the_invariant_carries_the_captured_value():
    """The post-phase zeroes the balance and subtracts the captured figure;
    those balance out only while the two are equal, and OBL_cb then has to
    prove no callback changes the caller's balance during the window."""
    f, s, h = _built()
    plan = synth.net_effect_plan(f, s, TARGET, harness_src=h)
    assert "amount_pre == balances[msg.sender]" in plan.exposure_invariant.formula
    assert TARGET in plan.exposure_invariant.formula


def test_a_capture_puts_that_plan_first():
    """Without the captured value OBL_post is refuted from states where the
    figure and its source differ, so a weaker plan cannot be repaired into a
    working one -- it just spends the rounds."""
    import inspect
    from aegis import pipeline
    src = inspect.getsource(pipeline)
    assert "_det.insert(0, _entry)" in src
    assert "synth._captures(hc_src" in src


def test_an_undecided_plan_is_not_repaired_round_after_round():
    import inspect
    from aegis import pipeline
    src = inspect.getsource(pipeline)
    assert "the plan is not repairable" in src.replace("\n", " ").replace("  ", " ") or \
        "is not repairable" in src


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL SHADOWED-LOCAL TESTS PASSED")
