import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis.slicer import slice_harness

H = """contract H {
    uint256 public x;
    uint256 public y;
    uint256 public w;
    uint256 public z;
    mapping(address => uint256) public m;
    uint256 public inFlight;
    bool    public exposed;
    constructor(address) {}
    function a(uint256 amount) public {
        uint256 t = y * 2;
        x += t;
        z = 7;
        m[msg.sender] += amount;
        require(z > 0, "z");
    }
    function b(uint256 amount) public {
        w = 5;
        if (w > 0) {
            x += 1;
        }
    }
    function c(uint256 amount) public {
        y = amount;
    }
}
"""

CHECK_X = "require(v.x() == 0); v.a(1); assert(v.x() == 1);"


def _sliced(check=CHECK_X):
    return slice_harness(H, check)


def test_everything_the_check_reads_stays_declared():
    out = _sliced()
    assert "uint256 public x;" in out


def test_data_dependence_is_kept():
    """x += t reads t, and t reads y, so y and whatever writes y must stay."""
    out = _sliced()
    assert "uint256 t = y * 2;" in out
    assert "x += t;" in out
    assert "uint256 public y;" in out
    assert "y = amount;" in out


def test_control_dependence_is_kept():
    """x is written under `if (w > 0)`, so w and its write must stay; dropping
    `w = 5` would leave w at 0 and silently kill the branch."""
    out = _sliced()
    assert "if (w > 0) {" in out
    assert "w = 5;" in out
    assert "uint256 public w;" in out


def test_irrelevant_writes_and_declarations_are_removed():
    out = _sliced()
    assert "m[msg.sender] += amount;" not in out
    assert "mapping(address => uint256) public m;" not in out


def test_guards_are_kept_with_what_they_read():
    """A guard is kept even over state the check never reads, and that state
    joins the slice. Dropping guards was sound but produced false alarms on
    the traces: a lock or a cap removed, and the solver walked through it."""
    out = _sliced()
    assert 'require(z > 0, "z");' in out
    assert "z = 7;" in out
    assert "uint256 public z;" in out


def test_a_local_shadowing_state_is_not_dropped():
    """KatRoyalties: `uint256 amount = ...` shadows a state `amount`. Treated
    as state it looked irrelevant and was dropped, and `amount` then read the
    parameter instead -- a different program."""
    h = """contract H {
    uint256 public amount;
    uint256 public x;
    uint256 public inFlight;
    bool    public exposed;
    function f(uint256 p) public {
        uint256 amount = x * 2;
        x += amount;
    }
}
"""
    out = slice_harness(h, "require(v.x() == 0); v.f(1); assert(v.x() == 0);")
    assert "uint256 amount = x * 2;" in out


def test_ghosts_are_always_kept():
    out = _sliced()
    assert "uint256 public inFlight;" in out
    assert "bool    public exposed;" in out


def test_nothing_removed_is_still_referenced():
    """The slice must be self-consistent: every name a kept line uses is
    either declared or a local or parameter of its function."""
    import re
    out = _sliced()
    declared = set(re.findall(r"public\s+([A-Za-z_]\w*);", out))
    for gone in ("m",):
        assert gone not in declared
        assert not re.search(rf"\b{gone}\b\s*[\[=+\-]", out), gone


def test_a_check_that_reads_everything_removes_nothing_needed():
    out = slice_harness(H, "v.x(); v.y(); v.w(); v.z(); v.m(address(this));")
    for name in ("x", "y", "w", "z"):
        assert f"uint256 public {name};" in out
    assert "mapping(address => uint256) public m;" in out


def test_locals_named_like_members_are_not_filtered_away():
    """BPYC: a local named `sender` was filtered as if it were `msg.sender`,
    so nothing marked it needed and its declaration was sliced away, leaving
    the call that used it referring to a name that no longer existed."""
    h = """contract H {
    uint256 public credits;
    uint256 public inFlight;
    bool    public exposed;
    function f(uint256 amount) public {
        address sender = address(uint160(amount));
        uint256 value = amount;
        uint256 length = amount;
        { g(sender, value, length); return; }
    }
    function g(address a, uint256 b, uint256 c) internal { credits += b + c; }
}
"""
    out = slice_harness(h, "require(v.credits() == v.inFlight()); v.f(amount);")
    for name in ("sender", "value", "length"):
        assert f"{name} = amount;" in out or f"address {name} =" in out, name


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL SLICER TESTS PASSED")
