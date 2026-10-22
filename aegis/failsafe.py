"""
localize.py (failsafe.py) - Module-level obligation localization.

Each obligation already carries its responsible MCVP module (set by the
compiler). Localization attributes every failed/unknown obligation to its
module; modules with no failing obligation stay "correct" and are never
re-synthesized. This is the keep-correct-work property, realized over the
A/G obligation set.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from .backend import ObligationResult
from .mcvp import MCVP
from .depgraph import ALL_MODULES


@dataclass
class ModuleStatus:
    module: str
    status: str                       # "correct" | "in_progress"
    failing_obligations: list[str] = field(default_factory=list)
    detail: str = ""


@dataclass
class LocalizedPlan:
    plan: MCVP
    modules: dict[str, ModuleStatus]

    def correct_modules(self):
        return [m for m, s in self.modules.items() if s.status == "correct"]

    def in_progress_modules(self):
        return {m for m, s in self.modules.items() if s.status == "in_progress"}

    def all_correct(self):
        return all(s.status == "correct" for s in self.modules.values())


def localize(plan: MCVP, results: list[ObligationResult]) -> LocalizedPlan:
    mods = {m: ModuleStatus(module=m, status="correct") for m in ALL_MODULES}
    # Deterministic operative obligations decide safety reliably; when one is
    # present and verified, a phase-obligation (OBL_post) failure is a solver-
    # unstable model artifact and must not block the VERIFIED verdict.
    for r in results:
        if r.status == "verified":
            # A verified canary is the bad case: its assert(false) could not be
            # reached, so the state it probes -- a callback running inside the
            # window -- does not exist in this model, and a proof resting on it
            # shows nothing about reentrancy.
            if r.name.endswith("_canary"):
                mods.get(r.module, mods["exposure_invariant"]).status = "in_progress"
            continue
        # A canary is meant to FAIL: its assertion is reachable exactly when
        # the harness body is, which is what makes the proof beside it
        # non-vacuous. Every other obligation must be discharged.
        if r.name.endswith("_canary"):
            if r.status == "unknown":
                # Reachability was not established either way, so the premise
                # the proof rests on is unconfirmed. VERIFIED has to mean
                # something; an undecided canary leaves that in doubt.
                mods.get(r.module, mods["exposure_invariant"]).status = "in_progress"
            continue
        # Nothing else is waved through. An obligation the solver could not
        # decide is not discharged, and a proof may not rest on it: OBL_post
        # timing out used to be treated as non-blocking, and TraderSpirits was
        # reported VERIFIED with its post-phase never proven -- and, with the
        # closure holding only the site function, no callback obligation
        # either. A failed OBL_post likewise blocks: whether it is a real
        # defect is decided upstream, by reproducing it on the contract.
        if r.name == "OBL_pre" and r.status in ("failed", "unknown"):
            s_mod = mods["exposure_invariant"]
        else:
            s_mod = mods.get(r.module) or mods["exposure_invariant"]
        s_mod.status = "in_progress"
        s_mod.failing_obligations.append(r.name)
        if r.detail:
            s_mod.detail = r.detail
    return LocalizedPlan(plan=plan, modules=mods)
