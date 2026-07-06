"""
assume_guarantee.py - The explicit assume-guarantee (A/G) view of an MCVP.

THIS IS THE CORE PROPOSAL ARTIFACT. The paper's central claim is that the LLM
synthesizes the assume-guarantee SPECIFICATION for callback-safe verification.
The MCVP already contains every ingredient; this module names them as A/G
components and renders the composition theorem instance the verifier discharges.

The A/G judgement we instantiate, specialized to callback verification:

    A_cb  =>  ( G_pre  /\\  G_exp  /\\  G_post )   =>   phi

where
    A_cb  : the ASSUMPTION on the adversarial environment -- callbacks are
            confined to the validated closure and protocol (over-approximated,
            so the assumption is SOUND, not merely hoped-for).
    G_pre : the pre-phase GUARANTEE -- if I_stable holds on entry then the
            exposure invariant I_exp is established before the external call.
    G_exp : the exposed-phase GUARANTEE -- every callback admitted by A_cb
            preserves I_exp (this is where the closure/protocol assumption is
            discharged against each re-entrant function).
    G_post: the post-phase GUARANTEE -- when the external call returns, the
            stable invariant I_stable is restored and ghost state is settled.
    phi   : the target property.

Soundness of the A/G inference rests on: (1) A_cb being a sound
over-approximation of concrete callback behavior (enforced by the conservative
closure gate in validator.py, NOT by the LLM), and (2) each guarantee being
discharged by the backend solver. The LLM proposes the decomposition; it never
enters the trusted base.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from .mcvp import MCVP


@dataclass
class AGComponent:
    name: str               # "A_cb" | "G_pre" | "G_exp" | "G_post"
    role: str               # "assumption" | "guarantee"
    statement: str          # human-readable logical statement
    formal: str             # the predicate / obligation it compiles to
    discharged_by: list[str] = field(default_factory=list)  # obligation names


@dataclass
class AGDecomposition:
    contract: str
    target_property: str
    assumption: AGComponent
    g_pre: AGComponent
    g_exp: AGComponent
    g_post: AGComponent
    nesting_bound: dict[str, int] = field(default_factory=dict)

    def components(self) -> list[AGComponent]:
        return [self.assumption, self.g_pre, self.g_exp, self.g_post]

    def composition_theorem(self) -> str:
        return (f"A_cb => (G_pre /\\ G_exp /\\ G_post) => {self.target_property}\n"
                f"  where callbacks are confined to {self.assumption.formal}")

    def render(self) -> str:
        lines = [f"Assume-Guarantee specification for {self.contract}",
                 f"  target property phi : {self.target_property}",
                 "",
                 f"  [A_cb]  ASSUMPTION ({self.assumption.role})",
                 f"          {self.assumption.statement}",
                 f"          formal: {self.assumption.formal}",
                 f"          discharged by: {self.assumption.discharged_by}",
                 ""]
        for g in (self.g_pre, self.g_exp, self.g_post):
            lines += [f"  [{g.name}] GUARANTEE",
                      f"          {g.statement}",
                      f"          formal: {g.formal}",
                      f"          discharged by: {g.discharged_by}",
                      ""]
        lines += ["  COMPOSITION THEOREM (instance):",
                  "    " + self.composition_theorem().replace("\n", "\n    ")]
        return "\n".join(lines)


def derive(plan: MCVP) -> AGDecomposition:
    """Project an MCVP onto its explicit A/G decomposition."""
    inv_exp = plan.exposure_invariant.formula
    inv_stable = plan.exposure_invariant.stable_formula
    fn = plan.phases.function
    closure = plan.closure.functions
    # The admissible callback set displayed in A_cb is the CLOSURE itself --
    # the sound over-approximation -- NOT the separately-stored allowed_callbacks
    # field (which the validator now forces to equal the closure anyway). This
    # guarantees A_cb and G_exp reference the same set: no display drift.
    admissible = closure

    assumption = AGComponent(
        name="A_cb", role="assumption",
        statement=(f"During {fn}'s exposed phase, re-entrant control is confined "
                   f"to the callback closure {admissible}; every such callback is "
                   f"admitted by the protocol, with bounded nesting."),
        formal=(f"admissible_callbacks={admissible}, "
                f"nesting={plan.protocol.nesting_bound}"),
        discharged_by=["OBL_closure_soundness"],  # the conservative gate
    )

    g_pre = AGComponent(
        name="G_pre", role="guarantee",
        statement=("If the stable invariant holds on entry, the pre-phase "
                   "establishes the exposure invariant before the external call."),
        formal=f"{{{inv_stable}}} pre-phase {{{inv_exp}}}",
        discharged_by=["OBL_pre"],
    )

    cb_obls = [f"OBL_cb_{f}" for f in closure if f != fn]
    g_exp = AGComponent(
        name="G_exp", role="guarantee",
        statement=("Every callback admitted by A_cb preserves the exposure "
                   "invariant while the contract is externally exposed."),
        formal=f"forall f in A_cb. {{{inv_exp}}} f {{{inv_exp}}}",
        discharged_by=cb_obls,
    )

    g_post = AGComponent(
        name="G_post", role="guarantee",
        statement=("When the external call returns, the post-phase restores the "
                   "stable invariant and fully settles the in-flight ghost state."),
        formal=f"{{{inv_exp}}} post-phase {{{inv_stable} /\\ inFlight==0}}",
        discharged_by=["OBL_post"],
    )

    return AGDecomposition(
        contract=plan.contract,
        target_property=plan.composition.target_property,
        assumption=assumption, g_pre=g_pre, g_exp=g_exp, g_post=g_post,
        nesting_bound=plan.protocol.nesting_bound,
    )
