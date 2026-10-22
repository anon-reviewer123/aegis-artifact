import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis.access import privileged_functions

# Modifier shapes taken from the deployed development contracts.
SRC = '''
contract C {
    address _owner; address owner; mapping(address=>bool) is_auth;
    mapping(address=>bool) owners; mapping(address=>uint256) balances;
    bool paused; bool inSwap; uint256 deadline;
    modifier onlyOwnerA() { require(_owner == _msgSender(), "Ownable"); _; }
    modifier onlyOwnerB() { require(owner() == _msgSender(), "x"); _; }
    modifier onlyAuth() { require( is_auth[msg.sender] || msg.sender==owner, "no"); _; }
    modifier onlyV5() { _checkOwner(); _; }
    modifier onlyMap() { require(owners[_msgSender()] == true, "x"); _; }
    modifier onlyIsOwner() { require(isOwner(msg.sender), "!OWNER"); _; }
    modifier authorized() { require(isAuthorized(msg.sender), "!AUTH"); _; }
    modifier callerIsUser() { require(tx.origin == msg.sender, "no contracts"); _; }
    modifier whenNotPaused() { require(!paused, "paused"); _; }
    modifier lockTheSwap() { inSwap = true; _; inSwap = false; }
    function owner() public view returns (address) { return _owner; }
    function _checkOwner() internal view { if (owner() != _msgSender()) revert NotOwner(); }
    function isOwner(address a) public view returns (bool) { return a == owner; }
    function isAuthorized(address adr) public view returns (bool) { return is_auth[adr]; }
    function a1() external onlyOwnerA { }
    function a2() external onlyOwnerB { }
    function a3() external onlyAuth { }
    function a4() external onlyV5 { }
    function a5() external onlyMap { }
    function a6() external onlyIsOwner { }
    function a7() external authorized { }
    function a8() external { require(msg.sender == owner); balances[msg.sender] = 0; }
    function e1() external payable callerIsUser { }
    function n1() external whenNotPaused { }
    function n2() external lockTheSwap { }
    function n3(uint256 x) external { require(balances[msg.sender] >= x); }
    function n4() external { require(msg.sender == owner || block.timestamp > deadline); }
    function n5() external { if (paused) { require(msg.sender == owner); } }
    function n6(uint256 x) public returns (bool) { balances[msg.sender] -= x; return true; }
}'''

NAMES = ["a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8",
         "e1", "n1", "n2", "n3", "n4", "n5", "n6"]


def _kinds():
    got = privileged_functions(SRC, NAMES)
    return {n: got.get(n, (None, ""))[0] for n in NAMES}


def test_every_owner_and_role_form_is_access_control():
    k = _kinds()
    for n in ("a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8"):
        assert k[n] == "access", n


def test_a_tx_origin_gate_is_reported_separately():
    assert _kinds()["e1"] == "eoa"


def test_guards_that_do_not_restrict_the_caller_stay_callable():
    """A pause, a lock flag and a balance check constrain state, not who may
    call; excluding them would hide real reentrancy."""
    k = _kinds()
    for n in ("n1", "n2", "n3", "n6"):
        assert k[n] is None, n


def test_a_disjunction_restricts_only_if_every_side_does():
    """`msg.sender == owner || block.timestamp > deadline` lets anyone in once
    the deadline passes."""
    assert _kinds()["n4"] is None


def test_a_check_inside_a_branch_does_not_close_the_function():
    assert _kinds()["n5"] is None


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL ACCESS TESTS PASSED")
