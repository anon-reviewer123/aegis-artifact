import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import one_step

HARNESS = """// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract VH {
    mapping(address => uint256) public bal;
    uint256 public total;
    uint256 public _sum_bal;
    bool public exposed;
    constructor(address) {}
    function transfer(uint256 amount) public {
        address to = address(uint160(amount));
        uint256 p = bal[msg.sender];
        bal[msg.sender] = p - amount;
        _sum_bal = _sum_bal + bal[msg.sender] - p;
        uint256 q = bal[to];
        bal[to] = q + amount;
        _sum_bal = _sum_bal + bal[to] - q;
    }
BODY
}
"""

OBLIGATION = """
contract Obligation {
    VH v;
    constructor() { v = new VH(address(this)); }
    function havoc_cfg0(uint256 __x0) public { v.__havoc_cfg0(__x0); }
    function check(uint256 amount) public {
        require(v.exposed());
        require(v._sum_bal() == v.total());
        v.transfer(amount);
        assert(v._sum_bal() == v.total());
        assert(v.bal(msg.sender) >= 0);
    }
}
"""


def _src(body=""):
    return HARNESS.replace("BODY", body) + OBLIGATION


def test_check_moves_into_the_harness():
    out = one_step.to_one_step(_src())
    assert "contract Obligation" not in out
    assert "function __aegis_check(uint256 amount) public {" in out
    assert "require(exposed);" in out and "transfer(amount);" in out
    assert "assert(_sum_bal == total);" in out
    assert "assert(bal[msg.sender] >= 0);" in out


def _reached(extra):
    """The check calls f, which calls g."""
    return (HARNESS.replace("BODY", extra)
            + OBLIGATION.replace("v.transfer(amount);", "v.transfer(amount); v.f(amount);"))


def test_a_reached_loop_or_recursion_keeps_the_obligation_on_chc():
    loop = ("    function f(uint256 n) public { g(n); }\n"
            "    function g(uint256 n) internal { for (uint256 i = 0; i < n; i++) { total += 1; } }")
    rec = ("    function f(uint256 n) public { g(n); }\n"
           "    function g(uint256 n) internal { if (n > 0) { g(n - 1); } }")
    assert one_step.to_one_step(_reached(loop)) is None
    assert one_step.to_one_step(_reached(rec)) is None


def test_a_loop_the_check_cannot_reach_does_not_matter():
    """TraderSpirits-style contracts carry looping views no obligation calls."""
    loop = "    function f(uint256 n) public { for (uint256 i = 0; i < n; i++) { total += 1; } }"
    assert one_step.to_one_step(_src(loop)) is not None


def test_the_obligation_contract_becomes_the_caller():
    """In check(), address(this) is the caller every harness function sees;
    inside the harness that account is msg.sender."""
    src = _src().replace("assert(v.bal(msg.sender) >= 0);",
                         "assert(v.bal(address(this)) >= 0);")
    out = one_step.to_one_step(src)
    assert out is not None and "assert(bal[msg.sender] >= 0);" in out


def test_other_uses_of_this_keep_the_obligation_on_chc():
    src = _src().replace("assert(v.bal(msg.sender) >= 0);",
                         "assert(this.x() >= 0);")
    assert one_step.to_one_step(src) is None


def test_canaries_and_other_obligations_are_not_eligible():
    assert one_step.eligible("OBL_cb_transfer")
    assert one_step.eligible("OBL_post")
    assert not one_step.eligible("OBL_reach_transfer_canary")
    assert not one_step.eligible("OBL_reentry")
    assert not one_step.eligible("OBL_view_get_balance")



def test_the_contracts_own_address_is_the_harness():
    """QuantumEnergy: `balanceOf[address(this)]` reaches check() as
    v.balanceOf(address(v)); inside the harness it is address(this)."""
    ob = OBLIGATION.replace("v.bal(msg.sender) >= 0", "v.bal(address(v)) >= 0")
    src = one_step.to_one_step(HARNESS.replace("BODY", "") + ob)
    assert src is not None
    assert "bal[address(this)] >= 0" in src


def test_the_formula_names_the_harness_for_the_own_address():
    from aegis import compiler
    out = compiler._q("feeQueue <= balanceOf[address(this)]",
                      ["feeQueue", "balanceOf"])
    assert "v.balanceOf(address(v))" in out



def test_a_silent_solc_is_skipped_for_one_that_answers():
    """solc 0.8.30 from solc-select printed nothing for a BMC run; an empty
    output must not be read as an answer, and the next binary is tried."""
    calls = []

    def fake(src, ms, b):
        calls.append(b)
        if b == "silent":
            return False, ""
        return True, "Info: BMC: Assertion violation check is safe!"
    saved = one_step._bmc_once
    one_step._bmc_once = fake
    os.environ["AEGIS_BMC_SOLC"] = "silent"
    try:
        proved, out = one_step.bmc_proves("src", 1000, "pinned")
    finally:
        one_step._bmc_once = saved
        os.environ.pop("AEGIS_BMC_SOLC", None)
    assert proved and calls == ["silent", "solc"]



def test_a_witness_needs_the_canary_to_be_the_only_assertion():
    two = "contract H { function f() public { assert(x > 0); } function __aegis_check() public { assert(false); } }"
    found, why = one_step.bmc_witness(two, 1000)
    assert not found and why == "not a single-assert canary"
    none = "contract H { function __aegis_check() public { require(true); } }"
    assert one_step.bmc_witness(none, 1000)[0] is False



def test_the_harness_is_never_its_own_caller():
    out = one_step.to_one_step(_src())
    body = out[out.index("function __aegis_check"):]
    assert body.index("require(msg.sender != address(this));") < body.index("transfer(amount);")



def test_setters_for_unread_variables_are_dropped():
    from aegis.compiler import prune_dead_havoc
    src = """contract H {
    address public used;
    address public dead;
    function __havoc_arg0(address __x0, address __x1) public {
        used = __x0;
        dead = __x1;
    }
    function __havoc_arg1(address __x0) public {
        dead = __x0;
    }
    function f() public { require(used != address(0)); }
}
contract Obligation {
    H v;
    function havoc_arg0(address __x0, address __x1) public { v.__havoc_arg0(__x0, __x1); }
    function havoc_arg1(address __x0) public { v.__havoc_arg1(__x0); }
}"""
    out = prune_dead_havoc(src)
    assert "used = __x0;" in out and "dead = __x1;" not in out
    assert "__havoc_arg1" not in out and "havoc_arg1" not in out
    assert "function havoc_arg0(address __x0, address __x1) public { v.__havoc_arg0(__x0, __x1); }" in out



def test_a_read_only_canary_inside_the_harness_is_accepted():
    src = """contract H {
    uint256 public x;
    function get() public view returns (uint256) { return x; }
    function check(uint256 amount) public {
        uint256 a = get();
        assert(false);
    }
}"""
    assert one_step.internal_canary(src) == src
    looped = src.replace("return x;", "uint256 s; for (uint256 i = 0; i < x; i++) { s += i; } return s;")
    assert one_step.internal_canary(looped) is None
    assert one_step.internal_canary(src + "\ncontract Obligation {}") is None



def test_writes_to_an_undeclared_sum_ghost_are_dropped():
    from aegis.compiler import drop_undeclared_ghost_writes
    src = """contract H {
    uint256 public _sum__balances;
    function depositFor(address who, uint256 amount) public {
        _sum__balances  += amount;   // keep sum ghost consistent
        _sum_deposits  += amount;   // keep sum ghost consistent
    }
}"""
    out = drop_undeclared_ghost_writes(src)
    assert "_sum_deposits" not in out and "_sum__balances  += amount;" in out


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL ONE-STEP TESTS PASSED")
