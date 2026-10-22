"""
coverage.py - two gates that stand between a discharged obligation and a
VERIFIED verdict.

Both gates only ever turn VERIFIED into UNKNOWN. A refutation is left alone: a
counterexample on an obligation is a real trace through the modelled semantics
whether or not the rest of the contract is inside them.

Gate 1, callback nesting. The modelled adversary re-enters at depth one: each
closure execution is atomic with respect to further callbacks. If a closure
member itself makes an external call, the real contract admits an interleaving
the obligations never checked, so a proof about them does not carry to the
contract. Reporting UNKNOWN is what makes the depth-one bound a stated scope
limit instead of a silent assumption.

Gate 2, uncovered exposure sites. Obligations are built around one site. A
second callback-capable call in the same contract opens a window this proof
says nothing about, so a whole-contract VERIFIED would be claiming more than
was checked. The gate names the sites that were not covered.
"""
from __future__ import annotations
from dataclasses import dataclass


# `address.transfer` and `address.send` forward a 2300 gas stipend, which does
# not fund a re-entrant call path. They remain exposure sites, because a
# fallback still runs and can revert, but a closure member whose only external
# call is one of these cannot re-enter and so does not take the contract
# outside the depth-one model. This is the same treatment the applicability
# funnel gives them, and the stratified audit behind it found no feasible
# re-entrant path among sampled transfer or send sites.
_STIPEND_CALLS = (".transfer", ".send")


def _can_yield_control(info) -> bool:
    """True if this function makes an external call that could fund re-entry."""
    for token in (info.external_calls or []):
        base = str(token).strip()
        if any(base.endswith(s) or s + "(" in base or s + "{" in base
               for s in _STIPEND_CALLS):
            continue
        return True
    return False


@dataclass
class GateResult:
    ok: bool
    reason: str = ""


def nesting_gate(facts, site) -> GateResult:
    """Refuse a proof whose closure can itself yield control."""
    from .guards import admissible_closure
    # The suspended function is not counted. Theorem 1 models a callback that
    # re-enters it as an atomic execution -- an external call reached from
    # inside an already re-entered g is not expanded -- so re-entering the
    # function that opened the window is inside the depth-one model, not
    # outside it. Counting it would refuse every classic-reentrancy contract,
    # whose whole shape is a re-enterable function that yields control.
    closure = admissible_closure(facts, site, include_suspended=False)
    nested = []
    for g in sorted(closure):
        info = facts.functions.get(g)
        if info is None:
            continue
        if _can_yield_control(info):
            nested.append(g)
        elif facts.reaches_unresolved(g):
            nested.append(g)
    if nested:
        return GateResult(False,
                          "closure member(s) " + ", ".join(nested)
                          + " may themselves yield control; the depth-one "
                            "callback model does not cover this contract")
    return GateResult(True)


def _has_window(s) -> bool:
    return bool(s.write_before_call) and bool(s.write_after_call)


def uncovered_sites(facts, site) -> list:
    """Exposure sites with a real window that the verified site does not cover.

    Two sites are the same when they are the same (function, call) pair, which
    is the site identity s = (f, l) the obligations are indexed by.
    """
    key = facts.site_key(site)
    out = []
    for s in facts.exposure_sites:
        if facts.site_key(s) == key:
            continue
        if _has_window(s):
            out.append(s)
    return out


def coverage_gate(facts, site) -> GateResult:
    """Refuse a whole-contract proof while a windowed site is unchecked."""
    rest = uncovered_sites(facts, site)
    if rest:
        names = ", ".join(sorted({f"{s.function}{s.call}#{s.index}"
                                  for s in rest}))
        return GateResult(False,
                          f"{len(rest)} further exposure site(s) not covered "
                          f"by this decomposition: {names}")
    return GateResult(True)


def apply_gates(facts, site, status, say) -> str:
    """Downgrade a VERIFIED status if either gate refuses. Any other status is
    returned unchanged."""
    if status != "VERIFIED":
        return status
    for name, gate in (("nesting", nesting_gate), ("coverage", coverage_gate)):
        res = gate(facts, site)
        if not res.ok:
            say(f"[gate:{name}] {res.reason}")
            say("[gate] obligations discharged, but the verdict does not cover "
                "the whole contract -- reporting UNKNOWN instead of VERIFIED")
            return "UNKNOWN"
    return status
