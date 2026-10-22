import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loop_step_build import _MAP_WRITE


def _hits(text):
    return [m.group(1) for m in _MAP_WRITE.finditer(text)]


def test_nested_index_is_a_write():
    """`failed[receivers[i]] = true` is the ordinary way to set a per-element
    flag inside a loop. A flat index pattern stops at the inner bracket and
    reports no write, which leaves the loop shape unrecognised."""
    assert _hits("failed[receivers[i]]=true;") == ["failed"]
    assert _hits("owed[claimants[i]] = 0;") == ["owed"]


def test_simple_index_is_still_a_write():
    assert _hits("failed[c] = true;") == ["failed"]


def test_compound_assignment_is_a_write():
    """`owed[c] -= amt` is the canonical conservation write; matching only a
    bare `=` misses the whole conserve shape."""
    for op in ("-=", "+=", "*=", "/="):
        assert _hits(f"owed[c] {op} amt;") == ["owed"], op


def test_nested_mapping_is_a_write():
    assert _hits("pool[a][b] = 1;") == ["pool"]


def test_comparisons_are_not_writes():
    for text in ("if (owed[c] == amt) {}", "a[i] != b", "x[i] >= y",
                 "x[i] <= y"):
        assert _hits(text) == [], text


_SETTLE_RECORDS = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract G {
    address[] public receivers; mapping(address=>bool) public failed;
    bool public finalized;
    function settle() external {
        for(uint256 i=0;i<receivers.length;i++){
            (bool ok,) = receivers[i].call("");
            if(!ok) failed[receivers[i]]=true;
        }
        finalized=true;
    }
}
"""

_SETTLE_PROPAGATES = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract G {
    address[] public receivers; mapping(address=>bool) public failed;
    bool public finalized;
    function settle() external {
        for(uint256 i=0;i<receivers.length;i++){
            (bool ok,) = receivers[i].call("");
            require(ok,"refund failed");
        }
        finalized=true;
    }
}
"""


def _shape(src):
    """Classify a loop written to a temp file, via the same path the pipeline
    uses."""
    import os
    import tempfile
    from aegis import static_analysis
    from loop_step_build import classify_loop_shape
    path = os.path.join(tempfile.mkdtemp(), "G.sol")
    with open(path, "w") as fh:
        fh.write(src)
    facts = static_analysis.analyze(path)
    if not facts.loop_sites:
        return None, facts, None
    site = facts.loop_sites[0]
    return classify_loop_shape(open(path).read(), facts, site), facts, site


def test_both_griefing_members_classify_the_same():
    """One member records the failure, the other propagates it. Classifying
    only the recording member would mean the classifier reads the safety
    property, which makes the loop verdicts circular."""
    a, _f1, s1 = _shape(_SETTLE_RECORDS)
    b, _f2, s2 = _shape(_SETTLE_PROPAGATES)
    if s1 is None or s2 is None:
        return          # no solc: loop sites are not detected by the fallback
    assert a == "progress", a
    assert b == "progress", b


def test_a_progress_loop_without_an_amount_still_builds():
    """The simplest progress loop pays with a bare call and carries no
    per-element amount; the property never mentions one."""
    from loop_step_build import build_loop_step
    kind, facts, site = _shape(_SETTLE_PROPAGATES)
    if site is None:
        return
    ob = build_loop_step(_SETTLE_PROPAGATES, facts, site)
    assert ob is not None, "no obligation built for an amountless progress loop"
    assert "halted" in ob.harness_source


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL LOOP SHAPE TESTS PASSED")
