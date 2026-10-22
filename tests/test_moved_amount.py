import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import harness_synth as hs
from aegis.static_analysis import ExposureSite


def _site(fn="w"):
    return ExposureSite(function=fn, call=".call", callback_capable=True,
                        reason="", write_before_call=set(),
                        write_after_call={"x"})


def test_the_value_of_a_low_level_call_is_the_moved_amount():
    src = """contract C { function w(address to) public {
        uint256 amt = balances[msg.sender];
        (bool ok, ) = payable(to).call{value: amt}("");
        x = 0; } }"""
    assert hs._moved_value_expr(src, _site()) == "amt"


def test_a_transfer_or_send_names_it_too():
    for form in ("payable(to).transfer(share);", "bool ok = payable(to).send(share);"):
        src = "contract C { function w(address to) public { uint256 share = f; " + form + " x = 0; } }"
        site = ExposureSite(function="w", call=".transfer" if "transfer" in form else ".send",
                            callback_capable=True, reason="",
                            write_before_call=set(), write_after_call={"x"})
        assert hs._moved_value_expr(src, site) == "share", form


def test_an_erc20_transfer_is_not_an_amount_of_ether():
    src = """contract C { function w(address to) public {
        token.transfer(to, 5); x = 0; } }"""
    site = ExposureSite(function="w", call=".transfer", callback_capable=True,
                        reason="", write_before_call=set(), write_after_call={"x"})
    assert hs._moved_value_expr(src, site) is None


def test_the_driver_parameter_is_tied_to_it():
    """Left free, `amount` bore no relation to what the pre-phase moved, and
    OBL_pre was refuted on states the contract cannot reach."""
    import tempfile
    from aegis import static_analysis
    src = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract K {
    mapping(address => uint256) public balances; uint256 public winnerFunds;
    function deposit() external payable { balances[msg.sender] += msg.value; winnerFunds += msg.value; }
    function withdraw(address to) public {
        uint256 amt = balances[msg.sender];
        (bool ok, ) = payable(to).call{value: amt}("");
        require(ok);
        balances[msg.sender] = 0;
        winnerFunds -= amt;
    }
}"""
    p = os.path.join(tempfile.mkdtemp(), "K.sol")
    open(p, "w").write(src)
    f = static_analysis.analyze(p)
    h = hs.synthesize_harness(src, f, f.exposure_sites[0],
                              "_sum_balances == winnerFunds")
    assert "require(amount == amt" in h


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL MOVED-AMOUNT TESTS PASSED")
