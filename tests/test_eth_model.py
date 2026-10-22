import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis.eth_model import transform

FLAT = """abstract contract Context { function _msgSender() internal view returns (address) { return msg.sender; } }
contract Ownable is Context { address public owner; }
contract Vault is Ownable {
    uint256 public total;
    receive() external payable {}
    function deposit() external payable { total += msg.value; }
    function w1(uint256 amt) external {
        (bool ok,) = msg.sender.call{value: amt}("");
        require(ok);
        total -= amt;
    }
    function w2(address to, uint256 amt, bool x, address token) external {
        if (x) payable(to).transfer(amt);
        IERC20(token).transfer(to, amt);
    }
}"""


def _out():
    src, prop, changed = transform(FLAT, "total <= address(this).balance")
    return src[src.index("contract Vault"):], src, prop, changed


def test_a_call_with_value_is_debited():
    """The case the first model missed: ETH leaving by call{value} left the
    ghost unchanged, so paying out without updating the books still verified."""
    body, _, _, _ = _out()
    assert '_ethBal -= amt; (bool ok,) = msg.sender.call{value: amt}("");' in body


def test_an_erc20_transfer_is_not_debited():
    body, _, _, _ = _out()
    assert "_ethBal -= amt;  IERC20" not in body
    assert "IERC20(token).transfer(to, amt);" in body


def test_a_guarded_send_keeps_its_debit_under_the_guard():
    body, _, _, _ = _out()
    assert "if (x) { _ethBal -= amt;  payable(to).transfer(amt); }" in body


def test_receive_and_payable_functions_are_credited():
    body, _, _, _ = _out()
    assert "receive() external payable { _ethBal += msg.value;" in body
    assert "function deposit() external payable { _ethBal += msg.value;" in body


def test_the_ghost_lives_in_the_target_contract():
    body, src, prop, changed = _out()
    assert changed and prop == "total <= _ethBal"
    assert src.count("uint256 public _ethBal") == 1
    assert "_ethBal" not in src[:src.index("contract Vault")]


def test_no_balance_target_means_no_change():
    src, prop, changed = transform(FLAT, "total == 0")
    assert not changed and src == FLAT


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL ETH MODEL TESTS PASSED")
