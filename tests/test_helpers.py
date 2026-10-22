import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import harness_synth as hs


def _reset(internal=(), storage=(), omitted=(), arities=None):
    hs._FN_ARITIES.clear()
    hs._FN_ARITIES.update(arities or {})
    hs._INTERNAL_FNS.clear()
    hs._INTERNAL_FNS.update(internal)
    hs._CALLED_HELPERS.clear()
    hs._STORAGE_NOW.clear()
    hs._STORAGE_NOW.update(storage)
    hs._OMITTED_NOW.clear()
    hs._OMITTED_NOW.update(omitted)


def test_a_block_ends_its_statement():
    """`unchecked { ... }` glued to the `emit` after it was dropped with the
    emit, losing the balance updates inside the block."""
    _reset()
    out = hs._clean_chunk("unchecked { b[f] = x - a; b[t] += a; }\n"
                          "emit Transfer(f, t, a);", keep_requires=True)
    assert "b[t] += a;" in out and "emit" not in out


def test_else_and_do_while_stay_one_statement():
    _reset()
    out = hs._clean_chunk("if (a > 0) { x += 1; } else { y += 1; }\nz = 2;",
                          keep_requires=True)
    assert "} else {" in out and "z = 2;" in out
    out = hs._clean_chunk("do { x += 1; } while (x < 3);", keep_requires=True)
    assert "while (x < 3)" in out


def test_internal_calls_are_kept_and_renamed():
    """SHIBB's deposit moves tokens with super._transfer; dropping internal
    calls made the wrapper do less than the function it stands for."""
    _reset(internal={"_transfer", "_msgSender"})
    out = hs._clean_chunk("address from = _msgSender();\n"
                          "super._transfer(from, address(this), s);",
                          keep_requires=True)
    assert "address from = __h__msgSender();" in out
    assert "__super__transfer(from, address(this), s);" in out
    assert hs._CALLED_HELPERS == {"__h__msgSender": ("_msgSender", False, 0),
                                  "__super__transfer": ("_transfer", True, 3)}


def test_calls_to_other_contracts_are_still_dropped():
    _reset(internal={"_transfer"})
    out = hs._clean_chunk("IERC20(t).transfer(to, a);\nx += 1;",
                          keep_requires=True)
    assert "IERC20" not in out and "x += 1;" in out


def test_safemath_writes_are_kept():
    _reset()
    out = hs._clean_chunk('total = total.add(a).sub(b, "under");',
                          keep_requires=True)
    assert "total = ((total + a) - b);" in out


def test_push_is_kept_only_on_carried_storage():
    _reset(storage={"holders", "skipped"}, omitted={"skipped"})
    assert "holders.push(a);" in hs._clean_chunk("holders.push(a);", True)
    assert "skipped.push(a)" not in hs._clean_chunk("skipped.push(a);", True)
    assert "unknown.push(a)" not in hs._clean_chunk("unknown.push(a);", True)


def test_super_reaches_the_base_definition():
    src = """
contract ERC20 { mapping(address=>uint256) b;
    function _transfer(address f, address t, uint256 a) internal virtual {
        b[f] -= a; b[t] += a; } }
contract Token is ERC20 {
    function _transfer(address f, address t, uint256 a) internal override {
        super._transfer(f, t, a / 2); } }"""
    _reset(internal={"_transfer"})
    hs._CALLED_HELPERS["__super__transfer"] = ("_transfer", True, 3)
    out = hs._emit_helpers(src)
    assert "b[t] += a;" in out and "a / 2" not in out


def test_low_level_calls_in_wrappers_become_atomic():
    """WAsgard: a nested call let the solver re-enter the harness; the same
    obligation with the call removed verified."""
    a = hs._atomize_external_calls
    assert a('(bool ok, ) = msg.sender.call{value: v}("");') == \
        '(bool ok, ) = (true, bytes(""));'
    assert a('require(payable(to).send(v), "f");') == 'require(true, "f");'
    assert "excised" in a("payable(to).transfer(v);")
    assert a("IERC20(t).transfer(to, v);") == "IERC20(t).transfer(to, v);"


def test_calls_with_options_are_external():
    """`router.addLiquidityETH{value: e}(...)` was split at its option brace
    and survived as two fragments neither recognised as a call."""
    _reset()
    out = hs._clean_chunk("(uint a, uint b, uint c) = r.addLiquidityETH{value: e}"
                          "(t, 1, 0, 0, o, d);\nx += 1;", True)
    assert "addLiquidityETH" not in out and "x += 1;" in out


def test_contract_creation_options_stay_in_one_statement():
    _reset()
    out = hs._clean_chunk("Pool p = new Pool{salt: s}(a);\nz = 2;", True)
    assert "new Pool{salt: s}(a);" in out and "z = 2;" in out


def test_overloaded_helpers_are_chosen_by_argument_count():
    """KatRoyalties: checkChances() and checkChances(address)."""
    src = """contract K {
    function checkChances() internal view returns (uint256) { return 3; }
    function checkChances(address a) internal view returns (uint256) { return 7; } }"""
    _reset(internal={"checkChances"}, arities={"checkChances": {0, 1}})
    out = hs._clean_chunk("uint256 m = checkChances(); uint256 n = checkChances(msg.sender);", True)
    assert "__h_checkChances_0()" in out and "__h_checkChances_1(msg.sender)" in out
    helpers = hs._emit_helpers(src)
    assert "__h_checkChances_0()" in helpers and "return 3;" in helpers
    assert "__h_checkChances_1(address a)" in helpers and "return 7;" in helpers


def test_a_call_not_in_the_function_rejects_the_harness():
    """SHIBB: the call sits in a helper transferFrom reaches. Emitting a comment
    built a harness whose post-phase did nothing."""
    from aegis.static_analysis import ExposureSite
    src = "contract C { function f() public { g(); } function g() internal { x.call(\"\"); } }"
    site = ExposureSite(function="f", call=".call", callback_capable=True, reason="")
    assert "AEGIS-UNSUPPORTED" in hs._phase_body(src, site, "post")


_FLAT_TF = """interface IERC20 {
    function transferFrom(address recipient, uint256 amount) external returns (bool);
}
contract T {
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        return _transferFrom(sender, recipient, amount);
    }
}"""


def test_bindings_come_from_the_definition_whose_body_is_copied():
    """BPYC: the interface declares transferFrom with two parameters and the
    contract defines it with three. Binding the interface's left `sender`
    unbound in the wrapper."""
    from aegis.harness_synth import _parse_params, _param_bindings
    assert [n for _t, n in _parse_params(_FLAT_TF, "transferFrom")] == \
        ["sender", "recipient", "amount"]
    out = _param_bindings(_FLAT_TF, "transferFrom")
    assert "address sender =" in out and "address recipient =" in out


def test_each_address_parameter_gets_a_distinct_value():
    """Binding sender and recipient alike makes every callback a self
    transfer, which preserves any sum invariant."""
    from aegis.harness_synth import _param_bindings
    out = _param_bindings(_FLAT_TF, "transferFrom")
    vals = [l.split("=", 1)[1].strip() for l in out.splitlines() if "address" in l]
    assert len(vals) == 2 and vals[0] != vals[1]


def test_a_block_statement_is_not_torn_apart_by_the_ledger_stripper():
    """The stripper split on every `;`, so `if (c) { x -= a; }` came back as
    `if (c) { x -= a; };` -- and Solidity has no empty statement, which is the
    "Expected primary expression" that failed nine deployed contracts."""
    out = hs._strip_ledger_writes("if (c) {\n    x -= a;\n}")
    assert out.count("{") == out.count("}")
    assert "};" not in out.replace(" ", "")
    assert "x -= a;" in out


def test_ledger_writes_are_still_removed():
    assert hs._strip_ledger_writes("inFlight += amount") == ""
    assert hs._strip_ledger_writes("uint256 a = f(x);\n exposed = true") \
        == "uint256 a = f(x);"
    assert hs._strip_ledger_writes("x -= 1") == "x -= 1;"


def test_a_phase_body_around_a_nested_call_is_well_formed():
    from aegis.static_analysis import ExposureSite
    src = """contract C {
    uint256 public bal; uint256 public pending;
    function w(uint256 amount) public {
        if (amount > 0) {
            bal -= amount;
            (bool ok, ) = msg.sender.call{value: amount}("");
            pending = 0;
        }
        bal += 1;
    }
}"""
    site = ExposureSite(function="w", call=".call", callback_capable=True,
                        reason="", write_before_call={"bal"},
                        write_after_call={"pending"})
    for phase in ("pre", "post"):
        t = hs._phase_body(src, site, phase)
        assert t.count("{") == t.count("}"), phase
        assert "};" not in t.replace(" ", ""), phase


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL HELPER TESTS PASSED")
