from __future__ import annotations
from dataclasses import dataclass, field
import time


ABLATION_MODES = ("none", "static-facts", "closure-check",
                  "phase-split", "ghost-template", "validator")
REPAIR_STRATEGIES = ("none", "whole-regen", "raw", "cegar", "cegar-reuse")


@dataclass
class ExperimentConfig:
    ablate: str = "none"
    repair: str = "cegar-reuse"

    def __post_init__(self):
        if self.ablate not in ABLATION_MODES:
            raise ValueError(f"unknown ablation mode: {self.ablate}")
        if self.repair not in REPAIR_STRATEGIES:
            raise ValueError(f"unknown repair strategy: {self.repair}")


@dataclass
class RQ4Counters:
    smtchecker_calls: int = 0
    reuse_hits: int = 0
    wall_start: float = field(default_factory=time.time)

    def elapsed(self) -> float:
        return round(time.time() - self.wall_start, 2)
