import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import static_analysis

SRC = """pragma solidity ^0.8.0;
contract V {
    uint256 public total;
    address owner;
    mapping(address => bytes) public names;
    function deposit() public payable { total += msg.value; }
    function rename() public {
        (bool ok, bytes memory d) = msg.sender.delegatecall(abi.encodeWithSignature("n()"));
        require(ok);
        names[msg.sender] = d;
    }
    function scratch() public pure returns (uint256 r) { assembly { r := add(1, 2) } }
    function withdraw(uint256 a) public {
        require(msg.sender == owner);
        (bool s, ) = payable(msg.sender).call{value: a}("");
        require(s);
        total -= a;
    }
}
"""


def _facts():
    d = tempfile.mkdtemp()
    p = os.path.join(d, "V.sol")
    open(p, "w").write(SRC)
    return static_analysis.analyze(p)


def test_a_delegatecall_function_joins_the_closure():
    """SafePaymentVault: UpdateBranchName delegatecalls msg.sender and so may
    write any slot, but its visible writes miss the target, and it was left
    out of the closure the proof quantified over."""
    f = _facts()
    site = [s for s in f.exposure_sites if s.function == "withdraw"][0]
    closure = f.conservative_closure(site)
    assert "rename" in closure and f.reaches_unbounded_write("rename")


def test_memory_only_assembly_does_not():
    f = _facts()
    assert not f.reaches_unbounded_write("scratch")


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL UNBOUNDED CLOSURE TESTS PASSED")
