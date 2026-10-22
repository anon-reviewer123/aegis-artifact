import copy
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import harness_check, harness_synth, static_analysis
import aegis.static_analysis as sa

FALLBACK_SRC = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract F {
    mapping(address => uint256) public credits; uint256 public total;
    fallback() external payable { credits[msg.sender] += msg.value; total += msg.value; }
    function payOut(address to, uint256 v) public {
        credits[to] -= v; total -= v;
        (bool ok, ) = payable(to).call{value: v}(""); require(ok);
    }
}"""


def _facts_with_fallback():
    p = os.path.join(tempfile.mkdtemp(), "F.sol")
    open(p, "w").write(FALLBACK_SRC)
    f = static_analysis.analyze(p)
    fb = copy.deepcopy(f.functions["payOut"])
    fb.name, fb.writes, fb.visibility = "<fallback>", {"credits", "total"}, "external"
    f.functions["<fallback>"] = fb
    return f


def test_the_unnamed_function_gets_a_wrapper_under_a_real_name():
    """X7RLiquidityHub: `<fallback>` is not an identifier, so no wrapper was
    emitted and the conformance check rejected the harness for it."""
    f = _facts_with_fallback()
    h = harness_synth.synthesize_harness(FALLBACK_SRC, f, f.exposure_sites[0],
                                         "_sum_credits == total")
    assert "function __fallback(uint256 amount) public" in h
    rep = harness_check.check_harness(h, ["<fallback>", "payOut"],
                                      f.exposure_sites[0].function)
    assert rep.conforming, rep.problems


def test_the_fallback_wrapper_does_not_use_msg_value():
    """It is not payable; the harness models the amount with its parameter."""
    f = _facts_with_fallback()
    h = harness_synth.synthesize_harness(FALLBACK_SRC, f, f.exposure_sites[0],
                                         "_sum_credits == total")
    w = re.search(r"function __fallback.*?\n    \}", h, re.S).group(0)
    assert "msg.value" not in w and "amount" in w


def test_a_view_keeps_no_modifier_the_harness_lacks():
    """BULLRUNNERSCLUB: `get_balance() public onlyOwner view` stopped the view
    harness compiling, and the view was reported UNKNOWN with its canary
    never firing."""
    src = """contract B {
    uint public bal; address public owner;
    modifier onlyOwner() { require(msg.sender == owner); _; }
    function get_balance() public onlyOwner view returns (uint balance) { return bal; }
}"""

    class _F:
        functions = {}

    class _S:
        function = "x"
    sa.view_closure = lambda facts, fn: ["get_balance"]
    out = harness_synth._emit_view_functions(src, _F(), _S())
    assert "onlyOwner" not in out
    assert "function get_balance() public view returns (uint balance)" in out


def test_a_type_name_is_not_declared_as_a_variable():
    """SimpleSalesEth: `Sale memory sale = ...` made the resolver declare
    `uint256 public Sale;` beside the struct of that name."""
    src = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract S {
    struct Sale { address seller; uint256 price; }
    mapping(address => Sale) public sales;
    mapping(address => uint256) public credits; uint256 public total;
    function buy(address nft) public {
        Sale memory sale = sales[nft];
        credits[sale.seller] += sale.price; total += sale.price;
        (bool ok, ) = payable(sale.seller).call{value: sale.price}(""); require(ok);
        total -= sale.price;
    }
}"""
    p = os.path.join(tempfile.mkdtemp(), "S.sol")
    open(p, "w").write(src)
    f = static_analysis.analyze(p)
    h = harness_synth.synthesize_harness(src, f, f.exposure_sites[0],
                                         "_sum_credits == total")
    assert not re.search(r"public Sale\s*;", h)


def test_a_call_sending_msg_value_needs_no_constraint():
    """TraderSpirits: the harness rewrites msg.value to its own `amount`, so
    the constraint was `amount == msg.value` inside a non-payable function."""
    src = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract M {
    mapping(address => uint256) public minted; uint256 public total;
    function mintByUser(address to) public payable {
        (bool ok, ) = payable(to).call{value: msg.value}(""); require(ok);
        minted[to] += 1; total += 1;
    }
}"""
    p = os.path.join(tempfile.mkdtemp(), "M.sol")
    open(p, "w").write(src)
    f = static_analysis.analyze(p)
    h = harness_synth.synthesize_harness(src, f, f.exposure_sites[0],
                                         "_sum_minted == total")
    # only the header comment may name it; no constraint is emitted
    assert "require(amount == msg.value" not in h
    body = h[h.index("contract "):]
    assert "msg.value" not in body


def test_a_mapping_to_a_struct_keeps_its_value_type():
    """SimpleSalesEth: `mapping(address => Sale)` declared as
    `mapping(address => uint256)` made `Sale memory s = sales[a][i];` a type
    error; DLAND's `tax_on[d].president` became a member lookup on a uint256.

    solc writes the value type as `struct S.Sale` -- keyword plus declaring
    contract -- so a bare-name match missed it. Tested on the type mapper
    directly, since the form depends on whether solc or the regex analyzer
    produced the facts."""
    harness_synth._CARRIED_TYPES.clear()
    harness_synth._CARRIED_TYPES.update({"Sale"})
    m = harness_synth._mapping_harness_type
    assert m("mapping(address => mapping(uint256 => struct S.Sale))") == \
        "mapping(address => mapping(uint256 => Sale))"
    assert m("mapping(address => struct S.Sale)") == "mapping(address => Sale)"
    assert m("mapping(address => Sale)") == "mapping(address => Sale)"
    # a struct the harness does not carry stays a plain slot
    assert m("mapping(address => struct Other.Unknown)") == \
        "mapping(address => uint256)"
    assert m("mapping(address => uint256)") == "mapping(address => uint256)"


def test_the_share_guard_needs_a_real_balance_mapping():
    """Yeeter has a plain `uint256 balance`, and the guard called its getter
    with an address."""
    from aegis.compiler import _share_mapping_name

    class _F:
        def __init__(self, sv, vt):
            self.storage_vars, self.var_types = sv, vt

    assert _share_mapping_name(_F(["balance"], {"balance": "uint256"})) is None
    assert _share_mapping_name(_F(["balance"], {})) is None
    assert _share_mapping_name(
        _F(["balances"], {"balances": "mapping(address => uint256)"})) == "balances"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL WRAPPER TESTS PASSED")
