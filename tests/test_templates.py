"""Template-family tests: every invariant kind the paper describes must
resolve to a distinct implemented template, lower to well-formed obligation
check bodies, and pass or fail the validator's shape checks as documented."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis.templates import (get_template, canonical_kind, TemplateCtx,
                             _REGISTRY)
from aegis.compiler import _q
from aegis.mcvp import (MCVP, CallbackClosure, CallbackProtocol, Phase,
                        PhaseDecomposition, GhostVar, ExposureInvariant,
                        Composition)
from aegis import static_analysis, validator


CANONICAL_KINDS = {"additive", "conserve", "bounded", "phase", "mapconserve",
                   "multiconserve", "monotone", "linear"}

PAPER_NAMES = {
    "additive": "additive",
    "conservation": "conserve",
    "bounded-drift": "bounded",
    "phase-consistency": "phase",
    "mapping-conservation": "mapconserve",
    "multi-variable-conservation": "multiconserve",
    "monotonic-bound": "monotone",
    "general-linear-equality": "linear",
}


def _ctx(inv_exp, inv_stable="totalAssets == totalShares",
         known=None):
    known = known or ["totalAssets", "totalShares", "reserve", "balances",
                      "totalSupply", "pendingA", "pendingB", "finalized",
                      "inFlight", "exposed"]
    return TemplateCtx(q=lambda s: _q(s, known), inv_exp=inv_exp,
                       inv_stable=inv_stable,
                       target="totalAssets == totalShares",
                       flag_name="exposed", primary_ghost="inFlight",
                       share_guard="")


def _plan(formula, stable, kind, ghosts=None):
    ghosts = ghosts if ghosts is not None else [
        GhostVar("inFlight", "uint256", "", backed_by_storage=False)]
    return MCVP(
        contract="T",
        closure=CallbackClosure("withdraw", "hook.onX", ["deposit"]),
        protocol=CallbackProtocol("withdraw.exposed", ["deposit"],
                                  {"withdraw": 1}),
        phases=PhaseDecomposition(
            "withdraw",
            Phase("pre", "entry", "call"), Phase("exposed", "call", "return"),
            Phase("post", "return", "exit")),
        ghost_state=ghosts,
        exposure_invariant=ExposureInvariant(formula, stable, kind=kind),
        composition=Composition(target_property=stable))


def test_registry_covers_paper_family():
    assert set(_REGISTRY) == CANONICAL_KINDS
    for paper_name, canonical in PAPER_NAMES.items():
        assert canonical_kind(paper_name) == canonical
        assert get_template(paper_name).kind == canonical


def test_unknown_kind_falls_back_to_additive():
    assert get_template(None).kind == "additive"
    assert get_template("").kind == "additive"
    assert get_template("no-such-kind").kind == "additive"


def test_equality_kinds_lower_to_require_run_assert():
    for kind, formula in (
            ("additive", "totalAssets == totalShares + inFlight"),
            ("conserve", "totalSupply == totalShares + inFlight"),
            ("multiconserve", "pendingA + pendingB == totalSupply + inFlight"),
            ("linear", "2*pendingA + pendingB == totalSupply + inFlight")):
        t = get_template(kind)
        c = _ctx(formula)
        pre, cb, post = t.pre_check(c), t.cb_check(c, "deposit"), t.post_check(c)
        assert "v.beginExposed(amount)" in pre and "assert(" in pre
        assert "v.deposit(amount)" in cb
        assert "v.endExposed(amount)" in post
        assert "assert(v.inFlight() == 0)" in post
        assert "assert(!v.exposed())" in post


def test_bounded_derives_lower_bound():
    t = get_template("bounded-drift")
    c = _ctx("totalAssets <= totalShares + inFlight")
    cb = t.cb_check(c, "deposit")
    assert "(v.totalAssets()) >= (v.totalShares())" in cb
    assert "(v.totalAssets()) <= (v.totalShares()) + v.inFlight()" in cb


def test_monotone_snapshots_the_monitored_expression():
    t = get_template("monotonic-bound")
    c = _ctx("reserve")
    pre, cb = t.pre_check(c), t.cb_check(c, "deposit")
    assert "uint256 entryValue = v.reserve();" in pre
    assert "assert(v.reserve() >= entryValue);" in cb
    c2 = _ctx("reserve >= old(reserve)")
    assert "uint256 entryValue = v.reserve();" in t.cb_check(c2, "deposit")


def test_q_lowers_mapping_access_and_account():
    known = ["balances", "totalSupply", "inFlight", "allowance"]
    out = _q("balances[account] <= totalSupply + inFlight", known)
    assert out == "v.balances(address(this)) <= v.totalSupply() + v.inFlight()"
    out2 = _q("balances[msg.sender] <= totalSupply", known)
    assert out2 == "v.balances(address(this)) <= v.totalSupply()"
    out3 = _q("allowance[account][account] == 0", known)
    assert out3 == "v.allowance(address(this), address(this)) == 0"


def test_template_shape_validation():
    good = {
        "conserve": ("totalSupply == totalShares + inFlight",
                     "totalSupply == totalShares"),
        "bounded": ("totalAssets <= totalShares + inFlight",
                    "totalAssets == totalShares"),
        "phase": ("!finalized", "true"),
        "mapconserve": ("balances[account] <= totalSupply + inFlight",
                        "balances[account] <= totalSupply"),
        "multiconserve": ("pendingA + pendingB == totalSupply + inFlight",
                          "pendingA + pendingB == totalSupply"),
        "monotone": ("reserve", "totalAssets == totalShares"),
        "linear": ("2*pendingA + pendingB == totalSupply + inFlight",
                   "2*pendingA + pendingB == totalSupply"),
    }
    for kind, (formula, stable) in good.items():
        t = get_template(kind)
        assert t.validate(_plan(formula, stable, kind)) == [], kind

    bad = {
        "conserve": "balances[account] == totalSupply + inFlight",
        "bounded": "totalAssets == totalShares + inFlight",
        "phase": "totalAssets == totalShares + inFlight",
        "mapconserve": "totalAssets <= totalShares + inFlight",
        "multiconserve": "totalAssets == totalShares + inFlight",
        "linear": "totalAssets <= totalShares + inFlight",
    }
    for kind, formula in bad.items():
        t = get_template(kind)
        assert t.validate(_plan(formula, "x == y", kind)) != [], kind


def test_validator_accepts_each_kind_end_to_end():
    contract = os.path.join(os.path.dirname(__file__), "..", "contracts",
                            "MotivatingVault.sol")
    facts = static_analysis.analyze(contract)
    site = facts.exposure_sites[0]
    closure = sorted(facts.conservative_closure(site))
    allowed = [f for f in closure if f != site.function]

    def plan_for(kind, formula, stable):
        p = _plan(formula, stable, kind)
        p.contract = facts.contract
        p.closure = CallbackClosure(site.function, site.call, closure)
        p.protocol = CallbackProtocol(f"{site.function}.exposed", allowed,
                                      {site.function: 1})
        p.phases = PhaseDecomposition(
            site.function,
            Phase("pre", "entry", "call"), Phase("exposed", "call", "return"),
            Phase("post", "return", "exit"))
        p.composition = Composition(target_property=stable)
        return p

    accepted = {
        "additive": ("totalAssets == totalShares + inFlight",
                     "totalAssets == totalShares"),
        "conservation": ("totalAssets == totalShares + inFlight",
                         "totalAssets == totalShares"),
        "bounded-drift": ("totalAssets <= totalShares + inFlight",
                          "totalAssets == totalShares"),
        "multi-variable-conservation":
            ("totalAssets + totalShares == totalShares + inFlight",
             "totalAssets == totalShares"),
        "general-linear-equality":
            ("totalAssets == totalShares + inFlight",
             "totalAssets == totalShares"),
        "monotonic-bound": ("totalAssets", "totalAssets == totalShares"),
    }
    for kind, (formula, stable) in accepted.items():
        p = plan_for(kind, formula, stable)
        failed = validator.validate(p, facts, site)
        assert failed == [], f"{kind}: {failed}"

    p = plan_for("bounded-drift", "totalAssets == totalShares + inFlight",
                 "totalAssets == totalShares")
    assert "exposure_invariant" in validator.validate(p, facts, site)


if __name__ == "__main__":
    for n, fn in sorted(globals().items()):
        if n.startswith("test_") and callable(fn):
            fn(); print("PASS", n)
    print("ALL TEMPLATE TESTS PASSED")
