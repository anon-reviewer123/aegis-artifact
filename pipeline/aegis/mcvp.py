"""
mcvp.py - The Modular Callback Verification Plan data model.

This is the central formal object of Aegis. It is deliberately a STRICT,
TYPED schema (not free-form prose) so that it can be: parsed, validated,
compiled to obligations, ablated, and repaired module-by-module.

Mapping to the paper's nine modules:
    closure        -> CallbackClosure
    protocol       -> CallbackProtocol
    phases         -> PhaseDecomposition
    ghost_state    -> list[GhostVar]
    exposure_inv   -> ExposureInvariant
    callback_oblig -> derived in the compiler from closure + exposure_inv
    composition    -> Composition
    (linearization is recorded inside PhaseDecomposition.linearization_point)
"""
from __future__ import annotations
from dataclasses import dataclass, field, asdict
from typing import Optional
import json


@dataclass
class CallbackClosure:
    """Which functions may re-enter from the risky external-call site."""
    site_function: str              # e.g. "withdraw"
    site_call: str                  # e.g. "receiver.onAssetReceived"
    functions: list[str]            # e.g. ["deposit", "redeemAll", "withdraw"]
    justification: str = ""


@dataclass
class CallbackProtocol:
    """Admissible callback event sequences (an over-approximating automaton)."""
    during_phase: str               # e.g. "withdraw.exposed"
    allowed_callbacks: list[str]    # subset/equal of closure.functions
    nesting_bound: dict[str, int] = field(default_factory=dict)  # {"withdraw": 1}


@dataclass
class Phase:
    name: str                       # "pre" | "exposed" | "post"
    from_marker: str                # human/CFG marker
    to_marker: str


@dataclass
class PhaseDecomposition:
    function: str
    pre: Phase
    exposed: Phase
    post: Phase
    linearization_point: str = ""   # where the semantic effect commits


@dataclass
class GhostVar:
    name: str                       # e.g. "inFlight"
    sol_type: str                   # e.g. "uint256"
    meaning: str = ""
    # Whether this ghost already exists as real storage in the contract.
    backed_by_storage: bool = False


@dataclass
class ExposureInvariant:
    # A string predicate over contract storage + ghost vars. Kept as a
    # backend-agnostic expression; the compiler lowers it per backend.
    formula: str                    # e.g. "totalAssets == totalShares + inFlight"
    stable_formula: str             # e.g. "totalAssets == totalShares"
    # Which invariant TEMPLATE this plan uses. Defaults to "additive" (T1) so
    # existing plans and serialized JSON keep working unchanged. The compiler
    # dispatches obligation lowering on this field (see aegis/templates.py).
    # Canonical kinds: additive, conserve, bounded, phase, mapconserve,
    # multiconserve, monotone, linear; paper-style names (conservation,
    # bounded-drift, phase-consistency, mapping-conservation,
    # multi-variable-conservation, monotonic-bound, general-linear-equality)
    # are accepted as aliases.
    kind: str = "additive"


@dataclass
class Composition:
    # The assume-guarantee composition statement (human-readable rule + the
    # target property the whole plan is meant to establish).
    target_property: str            # e.g. "totalAssets == totalShares"
    rule: str = (
        "If pre establishes I_exp, every admissible callback preserves I_exp, "
        "the protocol over-approximates concrete callbacks, and post restores "
        "I_stable, then the target property holds under adversarial callbacks."
    )


@dataclass
class MCVP:
    contract: str
    closure: CallbackClosure
    protocol: CallbackProtocol
    phases: PhaseDecomposition
    ghost_state: list[GhostVar]
    exposure_invariant: ExposureInvariant
    composition: Composition

    # ---- serialization helpers -------------------------------------------
    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=2)

    @staticmethod
    def from_dict(d: dict) -> "MCVP":
        return MCVP(
            contract=d["contract"],
            closure=CallbackClosure(**d["closure"]),
            protocol=CallbackProtocol(**d["protocol"]),
            phases=PhaseDecomposition(
                function=d["phases"]["function"],
                pre=Phase(**d["phases"]["pre"]),
                exposed=Phase(**d["phases"]["exposed"]),
                post=Phase(**d["phases"]["post"]),
                linearization_point=d["phases"].get("linearization_point", ""),
            ),
            ghost_state=[GhostVar(**g) for g in d["ghost_state"]],
            exposure_invariant=ExposureInvariant(**d["exposure_invariant"]),
            composition=Composition(**d["composition"]),
        )

    @staticmethod
    def from_json(s: str) -> "MCVP":
        return MCVP.from_dict(json.loads(s))
