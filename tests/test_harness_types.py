import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis.harness_synth import _is_numeric_type


def test_integer_scalars_are_numeric():
    for t in ("uint256", "uint8", "uint", "int128", "int",
              "uint256 storage ref"):
        assert _is_numeric_type(t), t


def test_arrays_are_not_numeric():
    """`uint256[50]` starts with `uint`; treating it as an integer made the
    harness emit `arr += amount`, which solc rejects outright."""
    for t in ("uint256[50]", "uint256[]", "uint256[] storage ref",
              "uint8[3]"):
        assert not _is_numeric_type(t), t


def test_non_integer_scalars_are_not_numeric():
    for t in ("address", "address payable", "bool", "bytes32", "string", ""):
        assert not _is_numeric_type(t), t


def test_single_level_integer_mapping_is_numeric():
    assert _is_numeric_type("mapping(address => uint256)")
    assert _is_numeric_type("mapping(uint256 => uint8)")


def test_mappings_that_cannot_take_one_index_and_an_integer_are_not():
    """A nested mapping needs two indexes and an array-valued mapping holds
    no integer, so `m[who] += amount` is ill-typed for both."""
    for t in ("mapping(address => mapping(uint256 => uint256))",
              "mapping(address => uint256[])",
              "mapping(address => bool)",
              "mapping(address => address)"):
        assert not _is_numeric_type(t), t


def test_seeding_casts_narrow_integers():
    """`uint8 _decimals += amount` does not compile; the seed must convert."""
    from aegis.harness_synth import _seed_line
    assert _seed_line("d", "uint8", False).strip() == "d  += uint8(amount);"
    assert _seed_line("t", "uint256", False).strip() == "t  += amount;"


def test_seeding_only_indexes_address_keyed_mappings():
    """`who` is an address, so it can only index a mapping keyed by one."""
    from aegis.harness_synth import _seed_line
    assert _seed_line("b", "mapping(address => uint256)", True).strip() \
        == "b[who]  += amount;"
    assert _seed_line("m", "mapping(uint16 => uint256)", True) is None
    assert _seed_line("h", "mapping(bytes32 => uint256)", True) is None


def test_seeding_converts_narrow_mapping_values():
    from aegis.harness_synth import _seed_line
    assert _seed_line("s", "mapping(address => uint16)", True).strip() \
        == "s[who]  += uint16(amount);"


def test_success_flags_are_booleans():
    """`require(os)` after an excised call: declaring `os` as uint256 gives
    `require(uint256)`, which has no overload."""
    from aegis.harness_synth import _used_as_bool
    assert _used_as_bool("os", "require(os);")
    assert _used_as_bool("ok", "if (!ok) revert();")
    assert not _used_as_bool("fee", "x = fee * 2;")
    assert not _used_as_bool("os", "require(os); uint y = os + 1;")


def test_harness_state_names_are_exact():
    """The obligation's entry guard may only name what the harness declares."""
    from aegis.compiler import _harness_state_names
    body = """contract H {
    uint256 public a;
    uint8 b;
    mapping(uint16 => uint256) m;
    uint256 public r = 1000;
    function f(address who, uint256 amount) public {
        uint256 local = 1;
        a += amount;
    }
}"""
    assert _harness_state_names(body) == {"a", "b", "m", "r"}


_FLAT = """
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}
contract ERC20 is IERC20 {
    mapping(address=>uint256) _balances;
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    function _transfer(address f, address t, uint256 a) internal { _balances[f]-=a; }
}
contract Token is ERC20 {
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(to != address(0));
        return super.transfer(to, amount);
    }
}"""


def test_extraction_skips_bodiless_declarations():
    """An interface declares `transfer` with no body; matching it as a
    definition ran on into whatever brace came next."""
    from aegis.harness_synth import _extract_function_body
    assert _extract_function_body(_FLAT, "totalSupply") is None


def test_extraction_takes_the_most_derived_definition():
    from aegis.harness_synth import _extract_function_body
    b = _extract_function_body(_FLAT, "transfer")
    assert "super.transfer" in b and "_transfer(msg.sender" not in b


def test_returns_are_legal_in_a_wrapper_with_no_return_type():
    from aegis.harness_synth import _neutralize_returns
    assert _neutralize_returns("return true;") == "return;"
    # the call is kept for its effects AND the function still exits; turning
    # it into a bare `f(x);` let an early `if (c) return f();` fall through
    assert _neutralize_returns("return f(x);") == "{ f(x); return; }"
    assert _neutralize_returns("if (x) return;") == "if (x) return;"


def test_a_first_statement_call_leaves_no_stump():
    """`(bool sent,) = msg.sender.call{value: v}("");` as the first statement
    used to leave `(bool sent,) = msg.sender.;` behind."""
    from aegis.harness_synth import _guard_span
    body = '\n        (bool sent,) = msg.sender.call{value: bal}("");\n        require(sent);\n        bal = 0;\n'
    pos = body.index("call")
    start, end = _guard_span(body, pos)
    assert body[:start].strip() == ""
    assert "require(sent);" in body[end:]


def test_phase_body_skips_the_interface_declaration():
    """A flattened file declares `function withdraw() external;` first."""
    from aegis.harness_synth import _phase_body
    from aegis.static_analysis import ExposureSite
    src = """interface I { function withdraw() external ; }
contract D {
    mapping(address => uint256) public balances;
    function withdraw() public {
        uint256 b = balances[msg.sender];
        (bool ok,) = msg.sender.call{value: b}("");
        balances[msg.sender] = 0;
    }
}"""
    site = ExposureSite(function="withdraw", call=".call", callback_capable=True, reason="",
                        write_before_call=set(), write_after_call={"balances"})
    post = _phase_body(src, site, "post")
    assert "balances[msg.sender] = 0" in post
    assert "contract" not in post


def test_a_call_inside_an_if_block_is_split_on_the_branch_taken():
    from aegis.harness_synth import _nested_split, _guard_span, _locate_call
    from aegis.static_analysis import ExposureSite
    body = ("\n        if (c > 0) {\n            a -= 1;\n"
            "            (bool ok,) = r.call{value: 1}(\"\");\n"
            "            b -= 1;\n        }\n        d += 1;\n")
    site = ExposureSite(function="f", call=".call", callback_capable=True, reason="",
                        write_before_call={"a"}, write_after_call={"b"})
    pos = _locate_call(body, site)
    s, e = _guard_span(body, pos)
    pre, post = _nested_split(body, s, e, site)
    assert "__branch0 = (c > 0);" in pre and "a -= 1;" in pre
    assert pre.count("{") == pre.count("}")
    assert post.startswith("if (__branch0) {") and "b -= 1;" in post
    assert post.count("{") == post.count("}")


def test_a_call_inside_a_loop_is_reported_unsupported():
    from aegis.harness_synth import _nested_split, _guard_span, _locate_call
    from aegis.static_analysis import ExposureSite
    body = ("\n        for (uint i; i < n; i++) {\n            x -= 1;\n"
            "            r.call{value: 1}(\"\");\n        }\n")
    site = ExposureSite(function="f", call=".call", callback_capable=True, reason="",
                        write_before_call={"x"}, write_after_call=set())
    pos = _locate_call(body, site)
    s, e = _guard_span(body, pos)
    pre, post = _nested_split(body, s, e, site)
    assert "AEGIS-UNSUPPORTED" in pre and "AEGIS-UNSUPPORTED" in post


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL HARNESS TYPE TESTS PASSED")
