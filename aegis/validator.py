"""
validator.py - Module 5: MCVP schema + conservative-soundness validation.

Returns a list of FAILED MODULE NAMES (empty list => plan accepted).
The most important check is `_check_closure_soundness`: the LLM-proposed
closure must be a SUPERSET of (or equal to) the conservative over-approximation
computed by static analysis. If the LLM dropped a callback-reachable function,
the plan is unsound and we flag "closure" for repair. This is what keeps the
LLM out of the trusted computing base.
"""
from __future__ import annotations
import sys
from .mcvp import MCVP
from .static_analysis import ContractFacts, ExposureSite
from .templates import get_template, canonical_kind


def validate(plan: MCVP, facts: ContractFacts, site: ExposureSite,
             ablate: str = "none") -> list[str]:
    failed: list[str] = []

    # RQ3: --ablate closure-check → skip the closure-soundness gate
    if ablate != "closure-check":
        if _check_closure_soundness(plan, facts, site):
            failed.append("closure")
    if _check_protocol(plan):
        failed.append("protocol")
    if _check_phases(plan, facts):
        failed.append("phases")
    if _check_ghost(plan, facts):
        failed.append("ghost_state")
    if _check_exposure_invariant(plan, facts, site):
        failed.append("exposure_invariant")
    # Template-specific well-formedness: each invariant kind checks the shape
    # its obligation lowering assumes (RQ3 --ablate ghost-template forces the
    # additive template, so its shape checks are skipped consistently).
    # Template shape checks constrain where a ghost sits in the formula. A site
    # that writes no storage after the call needs no ghost -- its exposure
    # invariant is the stable invariant -- so there is no placement to check,
    # and applying the shape rule there rejects the one correct plan for
    # lacking a variable the contract has no use for.
    _ghostless = skip_template_shape(plan, site)
    if _ghostless:
        print("  [validator] template shape check skipped: no post-phase "
              "writes and no ghost declared, so there is no ghost placement "
              "to constrain", file=sys.stderr)
    if (ablate != "ghost-template" and "exposure_invariant" not in failed
            and not _ghostless):
        template = get_template(getattr(plan.exposure_invariant, "kind", None))
        for msg in template.validate(plan, facts):
            print(f"  [validator] template '{template.kind}': {msg}",
                  file=sys.stderr)
            if "exposure_invariant" not in failed:
                failed.append("exposure_invariant")
    return failed


def skip_template_shape(plan, site) -> bool:
    """True when the template's shape rule should not be applied.

    Template shapes constrain where a ghost sits in the exposure invariant. A
    site that writes no storage after the external call leaves nothing torn,
    so its exposure invariant is the stable invariant and carries no ghost.
    There is no placement to constrain, and applying the rule anyway rejects
    the one correct plan for lacking a variable the contract has no use for.
    """
    if site is None or getattr(plan, "ghost_state", None):
        return False
    if getattr(plan.exposure_invariant, "derived_from_pre", False):
        return True
    if not site.write_after_call:
        return True
    # The mirror case: a pre-phase that writes none of the invariant's
    # variables leaves it holding at the call, so the exposure invariant is
    # the stable one, ghost-free, with no placement to check.
    inv = plan.exposure_invariant
    return (inv.formula.strip() == inv.stable_formula.strip()
            and not pre_touches_invariant(inv.stable_formula, site))


def _check_closure_soundness(plan, facts, site) -> bool:
    """True == FAILED. Closure must over-approximate the conservative set."""
    conservative = facts.conservative_closure(site)
    proposed = set(plan.closure.functions)
    missing = conservative - proposed
    if missing:
        print(f"  [validator] closure UNSOUND: missing reachable callbacks "
              f"{sorted(missing)} (conservative={sorted(conservative)})", file=sys.stderr)
        return True
    return False


def _check_protocol(plan) -> bool:
    """SOUNDNESS: the protocol's admissible callback set must EQUAL the closure.

    Two failure modes, both unsound or ill-formed:
    - allowed is a STRICT SUBSET of closure: the proof would only check some
      callbacks, but the closure says more can re-enter. Proving safety under a
      weaker environment than reality is UNSOUND (under-approximation).
    - allowed contains functions NOT in closure: ill-formed (proving about
      callbacks the closure says cannot occur).
    Either way the protocol must be repaired to match the closure exactly."""
    allowed = set(plan.protocol.allowed_callbacks)
    closure = set(plan.closure.functions)
    # The exposed function itself re-enters under the nesting bound, so it is
    # admissible without being listed separately; compare modulo it.
    fn = plan.phases.function
    allowed_eff = allowed | {fn}
    closure_eff = closure | {fn}
    if allowed_eff != closure_eff:
        missing = closure_eff - allowed_eff
        extra = allowed_eff - closure_eff
        if missing:
            print(f"  [validator] protocol UNSOUND: closure callbacks "
                  f"{sorted(missing)} are not admitted by the protocol "
                  f"(under-approximation)", file=sys.stderr)
        if extra:
            print(f"  [validator] protocol references non-closure functions "
                  f"{sorted(extra)}", file=sys.stderr)
        return True
    return False


def _check_phases(plan, facts) -> bool:
    if plan.phases.function not in facts.functions:
        print(f"  [validator] phase function {plan.phases.function} not found", file=sys.stderr)
        return True
    return False


def _check_ghost(plan, facts) -> bool:
    for g in plan.ghost_state:
        if g.sol_type not in ("uint256", "uint", "int256", "bool", "address"):
            print(f"  [validator] ghost var {g.name} has bad type {g.sol_type}", file=sys.stderr)
            return True
    return False


_GHOST_NAMES = ("inFlight", "snapPre")


def degenerate_invariant(formula: str, ghosts=()) -> bool:
    """True when an equality is the same expression on both sides once ghost
    terms are taken out -- `x == x + inFlight`, `a + b == b + a + g`.

    Such an invariant says nothing about storage; it reduces to `ghost == 0`,
    which fails as soon as anything is in flight. The pre-phase obligation is
    then refuted for a reason that has nothing to do with the contract, and
    the refutation is spent on the proposer's mistake. Rejecting it here sends
    the plan back for repair before any solver runs.
    """
    import re as _re
    names = set(_GHOST_NAMES) | set(ghosts)
    parts = formula.split("==")
    if len(parts) != 2 or "!" in formula or "<" in formula or ">" in formula:
        return False

    def terms(side):
        toks = _re.findall(r"[+-]?\s*[^+\-]+", side.strip())
        out = []
        for t in toks:
            t = t.replace(" ", "")
            sign = "-" if t.startswith("-") else "+"
            body = t.lstrip("+-")
            if body in names or not body:
                continue
            out.append(sign + body)
        return sorted(out)

    left, right = terms(parts[0]), terms(parts[1])
    return bool(left) and left == right


def pre_touches_invariant(formula: str, site) -> bool:
    """Whether the site's pre-phase writes any variable the formula reads.

    A mapping sum `_sum_<m>` reads m; the ETH ghost `_ethBal` is written by the
    debit the ETH model places before a call that sends value, so a pre-phase
    that pays out does touch a balance invariant."""
    import re as _re
    reads = set()
    for t in _re.findall(r"[A-Za-z_]\w*", formula or ""):
        reads.add(t[len("_sum_"):] if t.startswith("_sum_") else t)
    return bool(reads & set(getattr(site, "write_before_call", ()) or ()))


def _check_exposure_invariant(plan, facts, site=None) -> bool:
    inv = plan.exposure_invariant
    ghosts = [g.name for g in (getattr(plan, "ghost_state", None) or [])]
    if degenerate_invariant(inv.formula, ghosts):
        print(f"  [validator] exposure invariant DEGENERATE: `{inv.formula}` "
              f"is the same on both sides apart from ghosts, so it reduces "
              f"to the ghost being zero", file=sys.stderr)
        return True
    if inv.formula.strip() == inv.stable_formula.strip() and \
            getattr(inv, "derived_from_pre", False):
        print("  [validator] exposure invariant equals stable invariant, "
              "accepted: derived from the pre-phase, whose writes cancel on "
              "the invariant", file=sys.stderr)
    elif inv.formula.strip() == inv.stable_formula.strip():
        # Normally the two differ: mid-operation some storage is updated and
        # some is not, so the exposed phase needs its own weaker predicate, and
        # proposing the stable invariant for it is a mistake worth rejecting.
        #
        # A site whose post-phase writes no storage is the exception. Nothing
        # is left torn when control is handed out, so the stable invariant does
        # hold throughout the window and is the correct exposure invariant.
        # Rejecting it there forces a ghost the contract has no use for, whose
        # OBL_pre cannot hold, and the repair loop then spends the whole budget
        # failing to mend a plan that was right to begin with.
        # An earlier version keyed this on the plan declaring no ghost instead,
        # which also admitted sites whose pre- and post-phase writes happen to
        # cancel. That was measured on the flash-loan and EOA families and was
        # worse: three non-verdicts became false positives and one true
        # positive became a false negative, with nothing newly decided.
        # Whether a window is real is a property of the site, so the site is
        # what it is decided on.
        if site is not None and not site.write_after_call:
            print("  [validator] exposure invariant equals stable invariant, "
                  "accepted: this site writes no storage after the call, so "
                  "nothing is exposed in a torn state", file=sys.stderr)
        elif site is not None and not pre_touches_invariant(inv.stable_formula,
                                                            site):
            # The mirror case. When the pre-phase writes none of the
            # invariant's variables, the state the invariant sees at the call
            # is the state it saw on entry, so the stable invariant holds at
            # the call and OBL_pre is immediate. Rejecting it forced the
            # proposer to invent a ghost the pre-phase could not establish;
            # on the development traces that was 4 of the 9 OBL_pre failures.
            # Unlike the broad relaxation measured earlier, this is decided on
            # what the site writes, not on whether a ghost is declared.
            print("  [validator] exposure invariant equals stable invariant, "
                  "accepted: the pre-phase writes none of its variables, so it "
                  "still holds when control is handed out", file=sys.stderr)
        else:
            print("  [validator] exposure invariant equals stable invariant "
                  "(too strong for the exposed phase)", file=sys.stderr)
            return True
    # every identifier in the formula must be a storage var or a ghost var
    _HARNESS_GHOSTS = {"inFlight", "exposed", "snapPre"}
    # mapping-sum ghosts _sum_<m> for every mapping storage var
    _sum_ghosts = {"_sum_" + v for v in facts.storage_vars}
    known = (set(facts.storage_vars) | {g.name for g in plan.ghost_state}
             | _HARNESS_GHOSTS | _sum_ghosts)
    import re
    idents = set(re.findall(r"[A-Za-z_]\w*", inv.formula))
    unknown = {i for i in idents if i not in known and not i.isdigit()
               and not _is_keyword_or_literal(i)}
    if unknown:
        print(f"  [validator] exposure invariant uses unknown identifiers "
              f"{sorted(unknown)}", file=sys.stderr)
        return True

    # SOUNDNESS: invariant non-triviality.
    # The exposure invariant must reference EVERY storage variable that the
    # target property mentions. Otherwise an invariant like
    #   virtualTotalAssets + inFlight == virtualShares + totalShares
    # (where virtualX are unconstrained ghosts) is vacuously satisfiable and
    # gives a FALSE VERIFIED on a buggy contract -- the actual failure mode we
    # observed with GPT-4o on CrossFunctionBuggy. This rule forces the LLM to
    # constrain the target's variables, not hide them behind unbacked ghosts.
    # It applies to the equality-shaped template kinds; monotone monitors a
    # single observable and phase states a boolean relation, so their formulas
    # are checked by the template's own validate() instead.
    if canonical_kind(getattr(inv, "kind", None)) not in ("monotone", "phase"):
        target_idents = set(re.findall(r"[A-Za-z_]\w*",
                                       plan.composition.target_property))
        target_storage = {i for i in target_idents
                          if i in set(facts.storage_vars)}
        formula_idents = set(re.findall(r"[A-Za-z_]\w*", inv.formula))
        missing_in_inv = target_storage - formula_idents
        if missing_in_inv:
            print(f"  [validator] exposure invariant VACUOUS: target property "
                  f"mentions storage vars {sorted(missing_in_inv)} that the "
                  f"invariant does not constrain (likely hidden behind unconstrained "
                  f"ghosts)", file=sys.stderr)
            return True
    else:
        formula_idents = set(re.findall(r"[A-Za-z_]\w*", inv.formula))

    # SOUNDNESS: invariant tightness for equality targets. If the target is an
    # equality (A == B) but the exposure invariant is only an inequality
    # (A <= B + g), a buggy callback that grows the slack side keeps it true and
    # slips past the solver -> FALSE VERIFIED. Observed on PerpVault: GPT-4o gave
    # `aum <= trackedValue + inFlight` instead of `aum == trackedValue + inFlight`.
    # Templates whose window predicate is legitimately not an equality are
    # exempt: bounded checks both bounds of the band, mapconserve relates a
    # per-account entry to a total, monotone is snapshot-based.
    tgt = plan.composition.target_property
    inv_f = inv.formula
    target_is_eq = ("==" in tgt) and not any(op in tgt for op in ("<=", ">=", "<", ">"))
    inv_is_ineq = any(op in inv_f for op in ("<=", ">=")) and "==" not in inv_f
    kind = canonical_kind(getattr(inv, "kind", None))
    if target_is_eq and inv_is_ineq and kind not in ("bounded", "mapconserve",
                                                     "monotone"):
        print(f"  [validator] exposure invariant TOO WEAK: target is equality "
              f"({tgt.strip()}) but invariant is inequality ({inv_f.strip()}). "
              f"REWRITE I_exp using '==' NOT '<='/'>='; the ghost must EXACTLY "
              f"account for the gap as A == B + ghost (declare the ghost in "
              f"ghost_state). Do NOT use any inequality operator in the exposure "
              f"invariant.", file=sys.stderr)
        return True

    # Every ghost the invariant references that is NOT backed by storage must
    # be constrained by ANOTHER part of the invariant -- otherwise it can take
    # any value and trivially satisfies the formula. A simple proxy: a ghost
    # not backed by storage is suspect unless it appears in BOTH sides of an
    # equality together with a real storage var. We enforce a stricter rule:
    # an exposure invariant may reference at most one unbacked ghost (typically
    # the in-flight counter), to avoid the LLM's tendency to invent free
    # variables that vacuously satisfy any equality.
    # Harness-provided ghosts are constrained by harness semantics (snapPre is
    # the entry snapshot; inFlight is the amount ledger). They are not free
    # LLM-invented variables and must not count as unconstrained.
    _HARNESS_CONSTRAINED = {"inFlight", "snapPre", "exposed"}
    unbacked = {g.name for g in plan.ghost_state
                if not g.backed_by_storage and g.name not in _HARNESS_CONSTRAINED}
    unbacked_in_inv = unbacked & formula_idents
    if len(unbacked_in_inv) > 1:
        print(f"  [validator] exposure invariant uses {len(unbacked_in_inv)} "
              f"unconstrained ghost vars {sorted(unbacked_in_inv)} -- these are "
              f"free and make the invariant vacuously satisfiable",
              file=sys.stderr)
        return True
    return False


def _is_keyword_or_literal(s: str) -> bool:
    # boolean literals/connectives plus the expression tokens the template
    # formula conventions use: `account`/`msg.sender` for the acting account
    # (lowered by the compiler to address(this)) and `old(...)` in
    # monotone-style formulas.
    return s in {"true", "false", "and", "or", "not", "AND", "OR", "NOT",
                 "account", "msg", "sender", "address", "this", "old"}
