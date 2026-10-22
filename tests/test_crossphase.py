import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import harness_synth, static_analysis, synth, validator

SRC = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract W {
    mapping(address => uint256) public deposits; uint256 public total;
    function claim() public returns (bool) {
        uint256 balance = deposits[msg.sender];
        (bool ok, ) = payable(msg.sender).call{value: balance}("");
        require(ok);
        if (deposits[msg.sender] < balance) { return false; }
        deposits[msg.sender] = 0;
        total -= balance;
        return true;
    }
}"""


def _harness():
    p = os.path.join(tempfile.mkdtemp(), "W.sol")
    open(p, "w").write(SRC)
    f = static_analysis.analyze(p)
    return f, harness_synth.synthesize_harness(SRC, f, f.exposure_sites[0],
                                               "_sum_deposits == total")


def test_a_local_read_after_the_call_becomes_a_field():
    """WAsgard: isolating the returns moved each body into its own function
    before promotion ran, so a local declared in the pre-phase was invisible
    in the post-phase and the obligation would not compile."""
    _f, h = _harness()
    assert "balance" in re.findall(r"public (\w+);", h)


def test_the_post_phase_can_still_read_it():
    _f, h = _harness()
    post = re.search(r"function __postBody.*?\n    \}", h, re.S) or \
        re.search(r"function endExposed.*?\n    \}", h, re.S)
    assert "balance" in post.group(0)


def test_a_derived_invariant_whose_writes_cancel_is_accepted():
    """SafePaymentVault: a payable credit and the call's debit cancel, so the
    stable invariant holds at the call. Rejecting it sent the plan to repair,
    which replaced it with a ghost the pre-phase could not establish."""
    src = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract V {
    uint256 public TotalBalance; uint256 public _ethBal;
    mapping(address => uint256) public Deposits;
    function MakeDeposit() external payable { _ethBal += msg.value; Deposits[msg.sender] += msg.value; TotalBalance += msg.value; }
    function EmptyVault(uint256 amount) external payable {
        _ethBal += amount;
        _ethBal -= amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok);
        TotalBalance -= amount;
    }
}"""
    p = os.path.join(tempfile.mkdtemp(), "V.sol")
    open(p, "w").write(src)
    f = static_analysis.analyze(p)
    s = f.exposure_sites[0]
    h = harness_synth.synthesize_harness(src, f, s, "TotalBalance == _ethBal")
    plan = synth.net_effect_plan(f, s, "TotalBalance == _ethBal", harness_src=h)
    assert plan.exposure_invariant.formula == "TotalBalance == _ethBal"
    assert plan.exposure_invariant.derived_from_pre
    assert validator.validate(plan, f, s) == []


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL CROSS-PHASE TESTS PASSED")
