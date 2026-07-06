"""
depgraph.py - The A/G dependency structure of the MCVP, DERIVED not hardcoded.

Each module declares its own incoming dependencies together with the A/G
reason. The global graph is the union of these declarations. This is the
soundness-defensible form of a dependency graph: every edge is justified at
its source, and adding a new module forces a documented justification rather
than letting a graph-edit go unaudited.
"""
from __future__ import annotations
from dataclasses import dataclass


@dataclass(frozen=True)
class ModuleDep:
    upstream: str
    reason: str          # the A/G justification for this edge


@dataclass(frozen=True)
class ModuleSpec:
    name: str
    declares: str        # what A/G role this module plays
    depends_on: tuple


MODULES: dict[str, ModuleSpec] = {
    "closure": ModuleSpec(
        name="closure",
        declares="A_cb's admissible callback set (the conservative closure)",
        depends_on=(
            ModuleDep("exposure_invariant",
                      "closure obligations OBL_cb_f assert I_exp preservation; "
                      "changing I_exp re-opens every callback proof"),
        )),
    "protocol": ModuleSpec(
        name="protocol",
        declares="the protocol restriction on A_cb (admissible set + nesting)",
        depends_on=(
            ModuleDep("closure",
                      "the protocol's allowed_callbacks must equal the closure"),
        )),
    "ghost_state": ModuleSpec(
        name="ghost_state",
        declares="auxiliary variables witnessing in-flight effects",
        depends_on=()),
    "exposure_invariant": ModuleSpec(
        name="exposure_invariant",
        declares="I_exp -- the weaker invariant that holds DURING exposure",
        depends_on=(
            ModuleDep("ghost_state",
                      "I_exp is written over ghosts; the available ghost set "
                      "bounds what I_exp can express"),
        )),
    "phases": ModuleSpec(
        name="phases",
        declares="the pre/exposed/post phase decomposition and obligations",
        depends_on=(
            ModuleDep("exposure_invariant",
                      "OBL_pre must ESTABLISH I_exp; OBL_post must RESTORE "
                      "I_stable from I_exp -- both stated over I_exp"),
        )),
    "composition": ModuleSpec(
        name="composition",
        declares="the A/G composition theorem instance: "
                 "A_cb => (G_pre /\\ G_exp /\\ G_post) => phi",
        depends_on=(
            ModuleDep("closure",
                      "composition assumes A_cb's admissible set is sound"),
            ModuleDep("protocol",
                      "composition assumes the protocol restriction holds"),
            ModuleDep("phases",
                      "composition chains G_pre, G_exp, G_post"),
            ModuleDep("exposure_invariant",
                      "the chain is stated over I_exp"),
        )),
}

ALL_MODULES = tuple(MODULES.keys())


def _derive_dependents() -> dict:
    dependents = {m: [] for m in MODULES}
    for downstream, spec in MODULES.items():
        for dep in spec.depends_on:
            if dep.upstream not in dependents:
                raise ValueError(f"module {downstream!r} depends on unknown "
                                 f"upstream {dep.upstream!r}")
            dependents[dep.upstream].append(downstream)
    return dependents


DEPENDENTS: dict = _derive_dependents()


def downstream_of(repaired):
    dirty = set()
    frontier = set(repaired)
    while frontier:
        m = frontier.pop()
        for d in DEPENDENTS.get(m, []):
            if d not in dirty:
                dirty.add(d); frontier.add(d)
    return dirty


def repair_order(in_progress):
    score = {m: len(downstream_of({m})) for m in in_progress}
    return sorted(in_progress, key=lambda m: (-score[m], m))


def explain(module: str) -> str:
    spec = MODULES[module]
    if not spec.depends_on:
        return f"{module}: no upstream dependencies."
    lines = [f"{module} (declares: {spec.declares})", "  depends on:"]
    for d in spec.depends_on:
        lines.append(f"    {d.upstream}: {d.reason}")
    return "\n".join(lines)
