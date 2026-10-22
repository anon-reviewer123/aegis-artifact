import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import static_analysis, synth, validator
from aegis.synth import _net_pre_deltas as deltas
from aegis.synth import exposure_invariant_from_pre as invariant


def test_a_side_the_pre_phase_drained_gets_the_ghost():
    """TRYPTO: the ether has left, so the balance side is short by the
    in-flight amount while control is away. The proposer added the ghost to
    the accounting side instead, and OBL_pre was false by construction."""
    d = deltas("_ethBal -= marketing_balance;", "marketing_balance")
    assert invariant("marketing_balance + growth_balance <= _ethBal", d) == \
        "marketing_balance + growth_balance <= _ethBal + inFlight"


def test_a_side_the_pre_phase_credited_puts_the_ghost_on_the_other():
    d = deltas("liabilities += amt;", "amt")
    assert invariant("credits == liabilities", d) == \
        "credits + inFlight == liabilities"


def test_a_credit_and_a_debit_that_cancel_leave_the_target_alone():
    """SafePaymentVault: a payable credit followed by the debit for the call."""
    d = deltas("_ethBal += amount; _ethBal -= amount;", "amount")
    assert invariant("_ethBal == TotalBalance", d) == "_ethBal == TotalBalance"


def test_both_sides_moving_alike_leaves_the_relation_untouched():
    d = deltas("total -= amt; bal -= amt;", "amt")
    assert invariant("_sum_bal == total", d) == "_sum_bal == total"


def test_a_mapping_write_moves_the_sum_the_target_names():
    assert deltas("bal -= amt;", "amt") == {"bal": -1}
    assert invariant("_sum_bal == total", {"bal": -1}) == \
        "_sum_bal + inFlight == total"


def test_writes_of_other_quantities_are_not_counted():
    assert deltas("fee += 3; lock = true; total -= amt;", "amt") == {"total": -1}


def test_the_plan_is_built_and_validates():
    src = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract T {
    uint256 public marketing_balance; uint256 public growth_balance; uint256 public _ethBal;
    function fund() external payable { _ethBal += msg.value; marketing_balance += msg.value; }
    function take_marketing() external {
        _ethBal -= marketing_balance;
        (bool s, ) = msg.sender.call{value: marketing_balance}("");
        require(s);
        marketing_balance = 0;
    }
}"""
    p = os.path.join(tempfile.mkdtemp(), "T.sol")
    open(p, "w").write(src)
    f = static_analysis.analyze(p)
    s = f.exposure_sites[0]
    plan = synth.net_effect_plan(f, s,
                                 "marketing_balance + growth_balance <= _ethBal")
    assert plan is not None
    assert plan.exposure_invariant.formula == \
        "marketing_balance + growth_balance <= _ethBal + inFlight"
    assert validator.validate(plan, f, s) == []


def test_deltas_come_from_the_harness_not_the_source():
    """SafePaymentVault: the source reads `_ethBal += msg.value` then
    `-= amount`, which look like different quantities; the harness rewrites
    msg.value to amount, where they cancel. The obligation checks the harness,
    so the invariant must describe the harness."""
    import re
    h = """contract H {
    function beginExposed(uint256 amount) public {
        _ethBal += amount;
        _ethBal -= amount;
        inFlight += amount;
        exposed   = true;
    }
}"""
    pre = re.search(r"function beginExposed\(uint256 amount\) public \{(.*?)\n    \}",
                    h, re.S).group(1)
    pre = "\n".join(l for l in pre.splitlines()
                    if not re.match(r"\s*(inFlight|exposed|snapPre)\b", l))
    d = deltas(pre, "amount")
    assert d == {"_ethBal": 0}
    assert invariant("_ethBal == TotalBalance", d) == "_ethBal == TotalBalance"


def test_the_harness_ledger_is_not_a_contract_effect():
    """`inFlight += amount` is the harness's own bookkeeping."""
    import re
    pre = "\n".join(l for l in ["        total -= amt;", "        inFlight += amount;"]
                    if not re.match(r"\s*(inFlight|exposed|snapPre)\b", l))
    assert deltas(pre, "amt") == {"total": -1}


def test_the_stable_invariant_is_assumed_where_the_phase_begins():
    """TRYPTO: depositFor credits several variables and can leave the relation
    false, so assuming it before the seeding let the phase start from a state
    the assumption excluded."""
    from aegis.templates import get_template, TemplateCtx
    c = TemplateCtx(q=lambda s: s, inv_exp="a == b + inFlight", inv_stable="a == b",
                    target="a == b", flag_name="exposed", primary_ghost="inFlight",
                    share_guard="", fresh_state=())
    body = get_template("conserve").pre_check(c)
    assert body.index("depositFor") < body.index("require(a == b)")


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL NET-EFFECT TESTS PASSED")
