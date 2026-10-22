from __future__ import annotations
from dataclasses import dataclass, field
import time


ABLATION_MODES = ("none", "static-facts", "closure-check",
                  "phase-split", "ghost-template", "validator",
                  "canary", "no-callback", "no-differential",
                  "fixed-shape", "template-harness")
SITE_MODES = ("primary", "all")

SLICE_MODES = ("off", "on")

REPAIR_STRATEGIES = ("none", "whole-regen", "raw", "cegar", "cegar-reuse")


@dataclass
class ExperimentConfig:
    ablate: str = "none"
    repair: str = "cegar-reuse"
    # "primary": run the general arm at the highest-ranked exposure site and
    # abstain on a whole-contract proof if another windowed site exists.
    # "all": decompose every windowed site, one plan per site, and require the
    # verdict to hold at each. Faithful to the site-indexed decomposition, at
    # the cost of one round of synthesis per site.
    sites: str = "primary"
    # "on": build each general-arm obligation over a slice of the harness
    # containing only what that obligation can observe (aegis/slicer.py).
    slice: str = "off"

    def __post_init__(self):
        if self.ablate not in ABLATION_MODES:
            raise ValueError(f"unknown ablation mode: {self.ablate}")
        if self.repair not in REPAIR_STRATEGIES:
            raise ValueError(f"unknown repair strategy: {self.repair}")
        if self.sites not in SITE_MODES:
            raise ValueError(f"unknown site mode: {self.sites}")
        if self.slice not in SLICE_MODES:
            raise ValueError(f"unknown slice mode: {self.slice}")


@dataclass
class RQ4Counters:
    smtchecker_calls: int = 0
    reuse_hits: int = 0
    wall_start: float = field(default_factory=time.time)

    def elapsed(self) -> float:
        return round(time.time() - self.wall_start, 2)
