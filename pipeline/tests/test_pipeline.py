"""Aegis tests. Note: tests that need a real solver are skipped automatically
when no healthy solc is present, and the pipeline is asserted to be HONEST
(UNAVAILABLE, never VERIFIED) in that case."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import static_analysis, synth, validator, depgraph, compiler, backend
from aegis import failsafe as localize_mod
from aegis.backend import ObligationResult
from aegis.pipeline import run_aegis

CONTRACT = os.path.join(os.path.dirname(__file__), "..", "contracts",
                        "MotivatingVault.sol")
HEALTHY = backend.solc_healthy()


def test_static_and_closure():
    facts = static_analysis.analyze(CONTRACT)
    site = facts.exposure_sites[0]
    assert site.function == "withdraw"
    assert "redeemAll" in facts.conservative_closure(site)


def test_validator_gate():
    facts = static_analysis.analyze(CONTRACT)
    site = facts.exposure_sites[0]
    plans = synth.sample_plans(facts, site, "totalAssets == totalShares", "stub", 4)
    assert "closure" in validator.validate(plans[0], facts, site)
    assert "exposure_invariant" in validator.validate(plans[1], facts, site)


def test_dependency_graph():
    assert "closure" in depgraph.downstream_of({"exposure_invariant"})
    assert "composition" in depgraph.downstream_of({"closure"})


def test_compiler_emits_per_obligation_harnesses():
    facts = static_analysis.analyze(CONTRACT)
    site = facts.exposure_sites[0]
    plan = synth.sample_plans(facts, site, "totalAssets == totalShares", "stub", 4)[2]
    hc = open(CONTRACT.replace(".sol", ".harness.sol")).read()
    obs = compiler.compile_obligations(plan, facts, hc)
    names = {o.name for o in obs}
    assert {"OBL_pre", "OBL_post"}.issubset(names)
    assert any(o.name.startswith("OBL_cb_") for o in obs)
    # each harness is standalone (has its own pragma + Obligation contract)
    for o in obs:
        assert "pragma solidity" in o.harness_source
        assert "contract Obligation" in o.harness_source


def test_localize_keeps_correct():
    facts = static_analysis.analyze(CONTRACT)
    site = facts.exposure_sites[0]
    plan = synth.sample_plans(facts, site, "totalAssets == totalShares", "stub", 4)[2]
    results = [
        ObligationResult("OBL_pre", "phases", "verified"),
        ObligationResult("OBL_cb_deposit", "closure", "verified"),
        ObligationResult("OBL_cb_redeemAll", "closure", "failed", "stale", "cex"),
        ObligationResult("OBL_post", "phases", "verified"),
    ]
    loc = localize_mod.localize(plan, results)
    assert "closure" in loc.in_progress_modules()
    assert "phases" in loc.correct_modules()


def test_pipeline_is_honest_without_backend():
    """The critical anti-rubber-stamp test: no healthy solc => never VERIFIED."""
    res = run_aegis(CONTRACT, "totalAssets == totalShares",
                    llm_backend="stub", k=1, verbose=False)
    if HEALTHY:
        assert res.status in ("VERIFIED", "BUG_FOUND", "UNKNOWN")
    else:
        assert res.status == "UNAVAILABLE"
        assert res.backend_used == "none"


def test_pipeline_verifies_with_real_backend():
    if not HEALTHY:
        print("  (skipped: no healthy solc)")
        return
    res = run_aegis(CONTRACT, "totalAssets == totalShares",
                    llm_backend="stub", k=4, verbose=False)
    assert res.status == "VERIFIED"
    assert "redeemAll" in res.plan.closure.functions


def test_pipeline_finds_bug_with_real_backend():
    if not HEALTHY:
        print("  (skipped: no healthy solc)")
        return
    buggy = os.path.join(os.path.dirname(__file__), "..", "contracts",
                         "corpus", "BuggyVault.sol")
    res = run_aegis(buggy, "totalAssets == totalShares",
                    llm_backend="stub", k=4, verbose=False)
    assert res.status == "BUG_FOUND"


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn(); print("PASS", name)
    print("ALL TESTS PASSED" + ("" if HEALTHY else " (solver tests skipped: no solc)"))


def test_protocol_must_admit_full_closure():
    """SOUNDNESS regression: a protocol that omits a reachable callback must be
    rejected (under-approximation). This was a latent soundness hole."""
    from aegis.mcvp import (MCVP, CallbackClosure, CallbackProtocol, Phase,
                            PhaseDecomposition, GhostVar, ExposureInvariant,
                            Composition)
    f = static_analysis.analyze(CONTRACT)
    site = f.exposure_sites[0]
    cons = sorted(f.conservative_closure(site))
    plan = MCVP("MotivatingVault",
        CallbackClosure("withdraw", ".onAssetReceived", cons, ""),
        CallbackProtocol("withdraw.exposed", ["deposit"], {"withdraw": 1}),
        PhaseDecomposition("withdraw", Phase("pre","",""),
                           Phase("exposed","",""), Phase("post","","")),
        [GhostVar("inFlight","uint256","")],
        ExposureInvariant("totalAssets == totalShares + inFlight",
                          "totalAssets == totalShares"),
        Composition("totalAssets == totalShares"))
    assert "protocol" in validator.validate(plan, f, site)


def test_ag_assumption_and_guarantee_agree():
    """The rendered A_cb admissible set must cover every callback G_exp checks."""
    import re
    from aegis import assume_guarantee as ag
    f = static_analysis.analyze(CONTRACT)
    site = f.exposure_sites[0]
    plan = synth.sample_plans(f, site, "totalAssets == totalShares", "stub", 4)[2]
    decomp = ag.derive(plan)
    a_cb = set(re.findall(r"'(\w+)'", decomp.assumption.formal))
    g_exp_fns = {o.replace("OBL_cb_", "") for o in decomp.g_exp.discharged_by}
    assert g_exp_fns.issubset(a_cb)


def test_obl_pre_failure_is_repair_not_bug():
    """A failed OBL_pre must NOT be reported as BUG_FOUND: a pre-phase that
    cannot establish I_exp signals a wrong exposure invariant (repair it),
    not a contract bug. OBL_post / OBL_cb_* failures remain real bugs."""
    from aegis import failsafe
    from aegis.backend import ObligationResult
    # OBL_pre failure routes to exposure_invariant, marking it in_progress
    results = [
        ObligationResult("OBL_pre", "phases", "failed", "cannot establish",
                         counterexample="cex"),
        ObligationResult("OBL_cb_x", "closure", "verified"),
    ]
    # need a minimal plan stub for localize signature
    class _P: pass
    loc = failsafe.localize(_P(), results)
    assert "exposure_invariant" in loc.in_progress_modules(), \
        "OBL_pre failure should localize to exposure_invariant"
    assert "phases" not in loc.in_progress_modules(), \
        "OBL_pre failure should NOT blame the phases module"
    print("PASS test_obl_pre_failure_is_repair_not_bug")
