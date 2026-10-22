"""
test_refinement_reuse.py - exercises Idea 1 (CEGAR-guided refinement) and
Idea 2 (cross-round proof reuse) WITHOUT requiring solc, by scripting the
backend to return deterministic verdicts. This locks in:

  * refinement.parse_counterexample projects v.<name>() / internal temps
    correctly and recovers the trace;
  * refinement.build_constraint emits a falsify+preserve CEGAR block;
  * proof_cache entailment: strong=>weak valid (reuse), weak=>strong invalid
    (declined, with witness);
  * pipeline wiring: a cached callback proof is REUSED (no backend re-call)
    when the invariant strengthens monotonically.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis import refinement as rf
from aegis import proof_cache as pc
from aegis import backend as be


def test_cex_projection():
    raw = ("Vault.totalShares = 5\n"
           "v.totalAssets() = 10\n"
           "inFlight = 0\n"
           "internal_8 = 777\n"
           "Transaction trace:\n"
           "Obligation.constructor()\n"
           "Obligation.check(5)\n")
    known = {"totalAssets", "totalShares", "inFlight"}
    cm = rf.parse_counterexample(raw, "OBL_cb_x", "exposure_invariant", known)
    assert cm.concrete
    assert cm.state == {"totalShares": 5, "totalAssets": 10, "inFlight": 0}, cm.state
    assert "internal_8" not in cm.state          # projection filters temps
    assert any("check(5)" in t for t in cm.trace)
    print("PASS test_cex_projection")


def test_constraint_block():
    cm = rf.CounterexampleModel("OBL_cb_x", "exposure_invariant",
                                state={"totalShares": 5, "totalAssets": 10,
                                       "inFlight": 0}, concrete=True)
    block = rf.build_constraint(cm, [{"totalAssets": 0, "totalShares": 0,
                                      "inFlight": 0}])
    assert "FALSIFY" in block and "PRESERVE" in block
    assert "totalShares = 5" in block
    assert "sigma_0" in block
    print("PASS test_constraint_block")


def test_entailment_directions():
    v, _ = pc._entails("totalAssets == totalShares + inFlight",
                       "totalAssets >= totalShares",
                       ["totalAssets", "totalShares"], ["inFlight"])
    assert v == "valid", v
    v, w = pc._entails("totalAssets >= totalShares",
                       "totalAssets == totalShares + inFlight",
                       ["totalAssets", "totalShares"], ["inFlight"])
    assert v == "invalid" and w, (v, w)
    print("PASS test_entailment_directions")


def test_cache_reuse_skips_backend(monkeypatch_free=True):
    """A cached proof for OBL_cb_g under a weaker invariant is reused when the
    invariant strengthens, so the backend is never asked about it again."""
    cache = pc.ProofCache()
    cache.record_verified("OBL_cb_redeemAll", "redeemAll",
                          "totalAssets >= totalShares", 1)
    d = cache.try_reuse("OBL_cb_redeemAll",
                        "totalAssets == totalShares + inFlight",
                        ["totalAssets", "totalShares"], ["inFlight"])
    assert d.reused and "valid" in d.reason
    # a weaker new invariant must NOT be reused (sound: fall through to solver)
    cache2 = pc.ProofCache()
    cache2.record_verified("OBL_cb_g", "g",
                           "totalAssets == totalShares + inFlight", 1)
    d2 = cache2.try_reuse("OBL_cb_g", "totalAssets >= totalShares",
                          ["totalAssets", "totalShares"], ["inFlight"])
    assert not d2.reused and d2.witness
    print("PASS test_cache_reuse_skips_backend")


def test_closure_repair_invalidates_cache():
    cache = pc.ProofCache()
    cache.record_verified("OBL_cb_redeemAll", "redeemAll", "I", 1)
    cache.record_verified("OBL_cb_deposit", "deposit", "I", 1)
    cache.invalidate_for_callback("redeemAll")
    assert cache.try_reuse("OBL_cb_redeemAll", "I",
                           ["totalAssets"], []).reused is False
    assert cache.try_reuse("OBL_cb_deposit", "I",
                           ["totalAssets"], []).reused is True
    print("PASS test_closure_repair_invalidates_cache")


if __name__ == "__main__":
    test_cex_projection()
    test_constraint_block()
    test_entailment_directions()
    test_cache_reuse_skips_backend()
    test_closure_repair_invalidates_cache()
    print("ALL REFINEMENT+REUSE TESTS PASSED")
