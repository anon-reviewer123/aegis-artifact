import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import harness_synth as H


def test_a_parameter_of_one_function_is_not_declared_in_another():
    """BULLRUNNERSCLUB: `owner` is a parameter of one helper, and the wrapper
    that used it had lost its own declaration, so nothing declared it."""
    wrapper = "    function approve(uint256 amount) public {\n        require(to != owner);\n    }\n"
    helper = ("    function __h_isApprovedForAll(address owner, address op) internal view "
              "returns (bool) {\n        return owner == op;\n    }\n")
    decls, _ = H._resolve_unbound([wrapper + helper], {"to"})
    assert "owner" in decls


def test_a_call_to_a_copied_helper_goes_through_the_copy():
    """WAsgard: a view copied verbatim still calls the original name."""
    body = ("    function f(address a) public view returns (uint256) {\n"
            "        return accumulativeDividendOf(a);\n    }\n"
            "    function __h_accumulativeDividendOf(address a) internal view returns (uint256) {\n"
            "        return 1;\n    }\n")
    decls, (out,) = H._resolve_unbound([body], set())
    assert "accumulativeDividendOf" not in decls
    assert "return __h_accumulativeDividendOf(a);" in out


def test_global_functions_are_not_state():
    body = "    function f(bytes32 h) public pure returns (address) {\n        return ecrecover(h, 27, h, h);\n    }\n"
    decls, _ = H._resolve_unbound([body], set())
    assert "ecrecover" not in decls


def test_a_view_is_not_taken_from_an_interface_declaration():
    """Ring: `[^{]*` ran from the IERC20 declaration of balanceOf into the next
    brace in the file and copied the rest of the interface into the harness."""
    src = """interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}
interface IFactory { function createPair(address a, address b) external returns (address); }
contract T {
    mapping(address => uint256) _balances;
    function balanceOf(address account) public view returns (uint256) { return _balances[account]; }
}"""
    import aegis.static_analysis as sa
    saved = sa.view_closure
    sa.view_closure = lambda facts, fn: ["balanceOf"]
    try:
        class _S:
            function = "x"
        out = H._emit_view_functions(src, None, _S())
    finally:
        sa.view_closure = saved
    assert out.strip().startswith("function balanceOf(address account) public view")
    assert "_balances[account]" in out and "interface" not in out and "transfer" not in out


def test_a_dropped_array_local_keeps_its_array_type():
    """BULLRUNNERSCLUB: `uint256[] memory idTokens = RPContract.tokensOfWallet(a)`
    calls another contract and is dropped; declaring idTokens uint256 broke
    the `return idTokens;` of a function returning uint256[] memory."""
    src = "function f(address a) public view returns (uint256[] memory) { uint256[] memory idTokens = R.t(a); return idTokens; }"
    body = "    function __h_f(address a) internal view returns (uint256[] memory) {\n        return idTokens;\n    }\n"
    decls, _ = H._resolve_unbound([body], set(), src=src)
    assert "uint256[] public idTokens;" in decls


def test_a_local_named_like_a_copied_getter_is_still_declared():
    """TraderSpirits: `owner()` has a helper copy, but `owner` in approve is a
    dropped local read as a value, so it must still be declared."""
    body = ("    function approve(uint256 amount) public {\n        require(amount != 0 && owner != address(0));\n    }\n"
            "    function __h_owner() internal view returns (address) {\n        return address(1);\n    }\n")
    decls, _ = H._resolve_unbound([body], set(), src="address owner = ownerOf(tokenId);")
    assert "address public owner;" in decls


def test_a_struct_the_harness_carries_is_declared():
    """BadBunnyNFTS: `MintRoll mintroll;` was omitted though the harness carries
    struct MintRoll, and every helper touching it failed to compile."""
    H._CARRIED_TYPES.clear()
    H._CARRIED_TYPES.add("MintRoll")
    assert H._scalar_harness_type("struct BadBunnyNFTS.MintRoll") == "MintRoll"
    assert H._scalar_harness_type("struct Other.Unknown") is None


def test_symbolic_values_can_be_set_by_the_solver():
    """ReservaX: a symbolic stand-in stayed 0, because the obligation creates
    the harness with `new` and nothing ever assigned it."""
    body = "    function f() public {\n        x += creatorOnePart;\n    }\n"
    decls, _ = H._resolve_unbound([body], {"x"})
    assert "function __havoc_sym0(uint256 __x0) public" in decls
    assert "creatorOnePart = __x0;" in decls
    from aegis import compiler
    fwd = compiler._havoc_forwarder("contract H {\n" + decls + "\n}")
    assert fwd.strip() == "function havoc_sym0(uint256 __x0) public { v.__havoc_sym0(__x0); }"



def test_config_state_can_be_set_and_adversary_state_cannot():
    """TraderSpirits: sale flags and caps set only by the owner or the
    constructor stayed 0 in the harness, so every mint reverted."""
    class F:
        privileged = {"setLimit": None}
        functions = {"mint": type("Fn", (), {"writes": {"minted"}})(),
                     "setLimit": type("Fn", (), {"writes": {"limit"}})()}
    decls = ("    uint256 public minted;\n    uint256 public limit;\n"
             "    bool public saleOpen;\n    uint256 public inFlight;\n")
    out = H._config_havoc(decls, F())
    assert "limit = __x" in out and "saleOpen = __x" in out
    assert "minted = __x" not in out and "inFlight" not in out
    many = [("uint256", f"v{i}") for i in range(20)]
    assert H._havoc_functions("__havoc_cfg", many).count("function __havoc_cfg") == 3



def test_safemath_on_a_mapping_entry_is_kept():
    """GoodMorning: `_rOwned[s] = _rOwned[s].sub(p, "msg")` had an empty
    receiver, the rewrite gave up, and every balance update was dropped."""
    st = '_rOwned[s] = _rOwned[s].sub(p, "Insufficient Balance");'
    assert H._rewrite_safemath(st) == "_rOwned[s] = (_rOwned[s] - p);"
    assert H._rewrite_safemath("a[b][c] = a[b][c].add(v);") == "a[b][c] = (a[b][c] + v);"


def test_the_sum_ghost_follows_a_self_referencing_write():
    """`m[k] = m[k] - x` re-evaluated after the write moved the ghost by -2x."""
    out = H._instrument_mapping_writes("        m[k] = m[k] - x;", "m")
    assert "_sum_m = _sum_m + m[k] - __prev0;" in out
    assert out.index("__prev0 = m[k]") < out.index("m[k] = m[k] - x")



def test_extra_parameters_are_free_not_functions_of_amount():
    """transferFrom(sender, recipient, amount) was checked only for
    sender == address(amount), recipient == sender ^ 1."""
    H._ARG_VARS.clear()
    src = "contract T { function transferFrom(address sender, address recipient, uint256 amount, bool flag, uint256 fee) public {} }"
    out = H._param_bindings(src, "transferFrom")
    assert "uint160(amount)" not in out and "^" not in out
    assert "address sender = __a0_sender;" in out
    assert "address recipient = __a1_recipient;" in out
    assert "bool flag = __a2_flag;" in out and "uint256 fee = __a3_fee;" in out
    state = H._argument_state()
    assert "address public __a0_sender;" in state and "function __havoc_arg0(" in state



def test_the_handed_over_figure_is_found():
    from aegis import synth
    h = """contract H {
    uint256 public marketing_balance;
    function beginExposed(uint256 amount) public {
        _ethBal -= marketing_balance;
        require(amount == marketing_balance, "amount is what the call hands over");
        inFlight += amount;
    }
    function endExposed(uint256 amount) public {
        marketing_balance = 0;
        inFlight -= amount;
    }
}"""
    assert synth._handed_over_state(h) == "marketing_balance"
    assert synth._handed_over_state(h.replace("marketing_balance = 0;", "")) is None


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL RESOLVER SCOPE TESTS PASSED")
