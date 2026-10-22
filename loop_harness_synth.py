"""
Gap 1 Slice 1: parametric inductive loop-step harness synthesizer (refund shape).

Given a LoopSite (external call inside a loop that pays a per-iteration amount out
of a mapping), emit the inductive step obligation harness that we proved by hand:
one iteration, re-entrant callback on the same claimant, per-claimant safety bound
paidForC <= wInit. The statement ORDER (effect vs interaction first) is taken from
the site's writes_before_call / writes_after_call, so a contract that zeroes the
mapping AFTER the call (interaction-before-effect) produces a harness whose
assertion is violated -- exactly the unsafe signature.

This is a PATTERN-CLASS synthesizer: it recognises the refund/value-transfer loop
and instantiates a verified template parametrised on the real variable names. For
loop shapes it does not recognise it returns None (the pipeline then reports the
loop as unsupported rather than emitting an unsound harness) -- a verifier should
decline, not guess.
"""
from dataclasses import dataclass


@dataclass
class LoopStepObligation:
    name: str
    harness_source: str
    kind: str          # "conserve_loop"
    expect_hint: str   # "safe" or "unsafe" structural signature (for canary docs)


def _classify_writes(site, facts):
    """Split loop writes into (mapping_var, scalar_total_var) using var_types."""
    mapping_var, scalar_var = None, None
    vt = getattr(facts, "var_types", {}) or {}
    for v in site.loop_body_writes:
        t = (vt.get(v, "") or "").strip()
        if t.startswith("mapping"):
            mapping_var = mapping_var or v
        elif t.startswith(("uint", "int")):
            scalar_var = scalar_var or v
    return mapping_var, scalar_var


def synth_loop_step(site, facts):
    """Return a LoopStepObligation for a recognised refund-shape loop, else None."""
    mapping_var, scalar_var = _classify_writes(site, facts)
    # refund signature: a mapping is written per iteration and the call is
    # value-bearing. We need to know if the mapping is zeroed BEFORE or AFTER the
    # call -- that is the safety-relevant ordering.
    if mapping_var is None:
        return None   # not a per-claimant payout loop -> unsupported here

    zeroed_before = mapping_var in (site.writes_before_call or [])
    zeroed_after = mapping_var in (site.writes_after_call or [])
    if not (zeroed_before or zeroed_after):
        return None   # mapping not zeroed around the call -> not this pattern

    H = f"{facts.contract}StepH"
    # The re-entrant callback pays whatever is STILL owed to the claimant now.
    # In the safe order the mapping is 0 by the time the callback runs; in the
    # unsafe order it is still wInit, so the callback pays and the outer effect
    # pays the captured amount again -> double pay.
    if zeroed_before:
        body = f'''
        uint256 amt = ownedC;
        ownedC = 0;                 // EFFECT before INTERACTION (from AST ordering)
        callback();                 // re-entry sees ownedC==0 -> no extra pay
        paidForC += amt;'''
    else:
        body = f'''
        uint256 amt = ownedC;
        callback();                 // INTERACTION before EFFECT (from AST ordering)
        ownedC = 0;
        paidForC += amt;            // pays captured amt again -> double pay'''

    src = f'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Auto-generated inductive loop-step obligation for {facts.contract}.{site.function}
// Pattern: per-claimant refund loop; mapping `{mapping_var}` paid out per iteration.
// Safety (per-claimant): paidForC <= wInit  (a claimant is paid at most owed).
contract {H} {{
    uint256 public ownedC;      // models {mapping_var}[c] for this iteration
    uint256 public paidForC;    // ghost: total paid to c this iteration

    // re-entrant {site.function}() on claimant c: pays whatever is still owed now.
    function callback() internal {{
        uint256 cur = ownedC;
        if (cur == 0) return;
        ownedC = 0;
        paidForC += cur;
    }}

    function check(uint256 w) public {{
        require(w > 0 && w < (1 << 128));
        ownedC = w; paidForC = 0;
        uint256 wInit = w;{body}
        assert(paidForC <= wInit);
    }}
}}
'''
    return LoopStepObligation(
        name=f"OBL_loop_step_{site.function}",
        harness_source=src,
        kind="conserve_loop",
        expect_hint="safe" if zeroed_before else "unsafe")


if __name__ == "__main__":
    import sys
    from aegis.static_analysis import analyze
    f = analyze(sys.argv[1])
    if not f.loop_sites:
        print("no loop sites"); sys.exit(0)
    for site in f.loop_sites:
        ob = synth_loop_step(site, f)
        if ob is None:
            print(f"{site.function}: unsupported loop shape (no harness emitted)")
            continue
        out = sys.argv[2] if len(sys.argv) > 2 else "/tmp"
        import os
        path = os.path.join(out, f"{f.contract}_{site.function}_step.sol")
        open(path, "w").write(ob.harness_source)
        print(f"{ob.name}: wrote {path}  (structural hint: {ob.expect_hint})")
