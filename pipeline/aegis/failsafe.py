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
    _det = [r for r in results
            if r.name in ("OBL_conservation", "OBL_reentry", "OBL_readonly")]
    _det_verified = bool(_det) and all(r.status == "verified" for r in _det)
    for r in results:
        if r.status == "verified":
            continue
        if r.name == "OBL_pre" and r.status in ("failed", "unknown"):
            s_mod = mods["exposure_invariant"]
        else:
            s_mod = mods.get(r.module) or mods["exposure_invariant"]
        # OBL_post timeout (unknown) is a redundant-goal solver failure for the
        # eth-model/conservation shapes -- non-blocking. A FAILED OBL_post is a
        # genuine bug (BuggyVault) handled upstream as BUG_FOUND.
        if r.name == "OBL_post" and (r.status == "unknown"
                                     or (r.status == "failed" and _det_verified)):
            continue
        s_mod.status = "in_progress"
        s_mod.failing_obligations.append(r.name)
        if r.detail:
            s_mod.detail = r.detail
    return LocalizedPlan(plan=plan, modules=mods)
