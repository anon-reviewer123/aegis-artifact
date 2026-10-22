import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import backend, confirm
from aegis.backend import ObligationResult

SRC = '''contract Base {
    mapping(address => uint256) internal _balances;
    uint256 public _totalSupply;
    function _mint(address a, uint256 v) internal { _balances[a] += v; _totalSupply += v; }
}
contract Vault is Base {
    address public owner;
    constructor() { owner = msg.sender; _mint(msg.sender, 100); }
    receive() external payable {}
    function balanceOf(address a) public view returns (uint256) { return _balances[a]; }
    function withdraw(uint256 v) external returns (bool) {
        require(_balances[msg.sender] >= v);
        (bool ok,) = msg.sender.call{value: v}("");
        if (ok) _balances[msg.sender] -= v;
        _totalSupply -= v;
        return true;
    }
    function setOwner(address o) external { require(msg.sender == owner); owner = o; }
}'''
TARGET = "_sum__balances == _totalSupply"


def _built(block=False):
    return confirm.build(SRC, "Vault", TARGET, privileged={"setOwner"},
                         block_all=block)


def test_the_property_is_asserted_only_between_transactions():
    """Asserting mid-transaction would flag the torn state a safe contract
    goes through inside its own window."""
    out = _built()
    assert "require(__aegis_depth == 0); assert(_sum__balances == _totalSupply);" in out


def test_the_sum_ghost_lives_with_its_mapping_and_follows_every_write():
    out = _built()
    assert out.index("uint256 internal _sum__balances;") < out.index("contract Vault")
    assert "{ _balances[a] += v; _sum__balances += v; }" in out


def test_a_write_under_a_braceless_if_keeps_its_guard():
    assert "if (ok) { _balances[msg.sender] -= v; _sum__balances -= v; }" in _built()


def test_privileged_functions_are_never_reentered():
    out = _built()
    assert "function setOwner(address o) external __aegisTop" in out
    assert "function withdraw(uint256 v) external __aegisTx returns (bool)" in out


def test_blocking_applies_to_every_function():
    out = _built(block=True)
    assert "function withdraw(uint256 v) external __aegisTop returns (bool)" in out


def _with(results):
    """Stand in for the solver: open run first, then blocked."""
    seq = list(results)

    def fake(name, module, src, timeout_ms=0, ext_calls="trusted"):
        return ObligationResult(name, module, seq.pop(0), "")
    real = backend.check_obligation
    backend.check_obligation = fake
    confirm._CACHE.clear()
    try:
        return confirm.confirm(SRC, "Vault", TARGET, {"setOwner"}, "withdraw", 1000)[0]
    finally:
        backend.check_obligation = real


def test_violated_only_with_reentry_is_confirmed():
    assert _with(["failed", "verified"]) == "confirmed"


def test_violated_even_without_reentry_is_not_a_reentrancy_bug():
    assert _with(["failed", "failed"]) == "not_invariant"


def test_holding_with_reentry_is_not_reproduced():
    assert _with(["verified"]) == "not_reproduced"


def test_a_solver_that_cannot_decide_is_undecided():
    assert _with(["unknown"]) == "undecided"
    assert _with(["failed", "unknown"]) == "undecided"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL CONFIRM TESTS PASSED")
