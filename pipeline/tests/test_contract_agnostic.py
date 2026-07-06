"""
test_contract_agnostic.py - locks in that the pipeline works on a contract with
NON-VAULT variable names (no totalAssets/totalShares/shares). Catches any
regression that re-introduces hardcoded accounting names into the harness
synthesizer, obligation compiler, or stub.
"""
import sys, os, tempfile
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from aegis import static_analysis, harness_synth, harness_check, compiler
from aegis.mcvp import (MCVP, CallbackClosure, CallbackProtocol, Phase,
                        PhaseDecomposition, GhostVar, ExposureInvariant, Composition)

POOL = """// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract PoolVault {
    mapping(address => uint256) public balances;
    uint256 public totalLiquidity;
    uint256 public backingReserve;
    bool public midCall;
    address public hook;
    function provide(uint256 amount) external {
        balances[msg.sender] += amount; totalLiquidity += amount; backingReserve += amount;
    }
    function harvest() external {
        require(backingReserve > totalLiquidity, "none");
        uint256 g = backingReserve - totalLiquidity;
        balances[msg.sender] += g; totalLiquidity += g;
    }
    function redeem(uint256 amount) external {
        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount; totalLiquidity -= amount;
        if (hook != address(0)) IHook(hook).onAssetReceived(amount);
        backingReserve -= amount;
    }
}
interface IHook { function onAssetReceived(uint256 a) external; }
"""

def _facts():
    p = os.path.join(tempfile.mkdtemp(), "PoolVault.sol")
    open(p, "w").write(POOL)
    return static_analysis.analyze(p), POOL

def test_static_finds_nonvault_closure():
    f, _ = _facts()
    site = f.exposure_sites[0]
    assert site.function == "redeem"
    assert sorted(f.conservative_closure(site)) == ["harvest", "provide", "redeem"]
    print("PASS test_static_finds_nonvault_closure")

def test_harness_uses_real_names_and_compiles_shape():
    f, src = _facts()
    site = f.exposure_sites[0]
    h = harness_synth.synthesize_harness(src, f, site)
    # real names present
    assert "backingReserve" in h and "totalLiquidity" in h
    # no hardcoded vault names leaked in
    assert "totalAssets" not in h and "totalShares" not in h
    # depositFor must NOT seed address/bool vars
    assert "hook  += amount" not in h and "midCall  += amount" not in h
    # no dangling if-guard left behind
    assert "if (hook" not in h
    # conforms
    rep = harness_check.check_harness(h, sorted(f.conservative_closure(site)),
                                      exposed_function=site.function)
    assert rep.conforming, rep.diagnostic
    print("PASS test_harness_uses_real_names_and_compiles_shape")

def test_obligations_rewrite_real_names():
    f, src = _facts()
    site = f.exposure_sites[0]
    h = harness_synth.synthesize_harness(src, f, site)
    plan = MCVP(
        contract=f.contract,
        closure=CallbackClosure(site.function, site.call,
                                sorted(f.conservative_closure(site)), "x"),
        protocol=CallbackProtocol(site.function + ".exposed",
            [g for g in sorted(f.conservative_closure(site)) if g != site.function],
            {site.function: 1}),
        phases=PhaseDecomposition(site.function,
            Phase("pre", "S", "c"), Phase("exposed", "c", "r"), Phase("post", "r", "E")),
        ghost_state=[GhostVar("inFlight", "uint256", "in flight", False)],
        exposure_invariant=ExposureInvariant(
            "backingReserve == totalLiquidity + inFlight",
            "backingReserve == totalLiquidity && inFlight == 0"),
        composition=Composition("backingReserve == totalLiquidity"))
    obls = compiler.compile_obligations(plan, f, h)
    names = [o.name for o in obls]
    assert "OBL_cb_harvest" in names and "OBL_cb_provide" in names
    post = next(o for o in obls if o.name == "OBL_post").harness_source
    assert "v.backingReserve()" in post and "v.totalLiquidity()" in post
    assert "totalAssets" not in post  # no leaked hardcoded name
    print("PASS test_obligations_rewrite_real_names")

if __name__ == "__main__":
    test_static_finds_nonvault_closure()
    test_harness_uses_real_names_and_compiles_shape()
    test_obligations_rewrite_real_names()
    print("ALL CONTRACT-AGNOSTIC TESTS PASSED")
