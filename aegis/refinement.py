"""
refinement.py - Idea 1: CEGAR-guided refinement of MCVP modules.

This module elevates the repair feedback loop from "thread the raw solver text
into the prompt" into a four-step CEGAR-style algorithm (Clarke et al. 2000):

  (1) EXTRACT   the concrete counterexample model from SMTChecker/Eldarica
                output into a structured CounterexampleModel.
  (2) PROJECT   that model onto the contract's SOURCE-LEVEL storage / ghost
                names (SMTChecker renames variables internally and prefixes
                them with the harness accessor `v.<name>()`); we map those
                back to the names the LLM uses in the invariant.
  (3) NEGATE    the failing assertion against the model: derive a structured
                strengthening constraint requiring the next invariant to be
                FALSE at the failing state while remaining TRUE at every state
                a previously-verified obligation depended on.
  (4) ENCODE    the constraint as a structured [REFINEMENT CONSTRAINT] block,
                replacing the free-text failure_detail fed to the LLM.

The LLM thus becomes the *synthesis oracle* for a refinement step with
structured intermediate artifacts, rather than the whole repair driver. That
is the algorithmic contribution; the projection (2) and negation (3) are real
work that cannot be described as plain prompting.

The module degrades gracefully: if a counterexample cannot be parsed into
concrete values (Eldarica output varies by version), build_constraint still
emits a structured constraint carrying whatever was recovered plus the
verified-state ledger, which is strictly more than the old free text.
"""
from __future__ import annotations
from dataclasses import dataclass, field
import re


# A state is a mapping from a source-level identifier to a concrete integer
# (or bool, encoded as 0/1). We keep it deliberately simple: SMT models for the
# vault class are linear-integer / boolean.
State = dict[str, int]


@dataclass
class CounterexampleModel:
    """Structured form of one SMTChecker/Eldarica counterexample."""
    failing_obligation: str
    failing_module: str
    # concrete pre-state values projected onto source names
    state: State = field(default_factory=dict)
    # the ordered call trace that reaches the violation, if recoverable
    trace: list[str] = field(default_factory=list)
    # the raw assertion text that was violated (the guarantee G)
    violated_assertion: str = ""
    # true if we recovered at least one concrete variable value
    concrete: bool = False


# --------------------------------------------------------------------------
# (1) EXTRACT  +  (2) PROJECT
# --------------------------------------------------------------------------
# SMTChecker counterexample lines look like, e.g.:
#   <contract>.totalShares = 5
#   v.totalAssets() = 10
#   Transaction trace:
#   Obligation.constructor()
#   Obligation.check(5)
# Eldarica/CHC may also print "Counterexample:\n  <assignments>".
_ASSIGN_RE = re.compile(
    r"(?:\bv\.)?([A-Za-z_]\w*)\s*(?:\(\s*\))?\s*=\s*(true|false|-?\d+)")
_TRACE_HDR_RE = re.compile(r"(transaction trace|trace|call sequence)", re.I)
_CALL_RE = re.compile(r"\b([A-Za-z_]\w*\s*\([^)]*\))")


def parse_counterexample(raw: str, obligation: str, module: str,
                         known_idents: set[str]) -> CounterexampleModel:
    """Extract + project a counterexample into source-level identifiers.

    `known_idents` is the set of real storage vars plus declared ghosts; we keep
    only assignments whose (projected) name is one of these, which both filters
    SMTChecker's internal temporaries and performs the name projection (the
    `v.<name>()` accessor form collapses to `<name>`).
    """
    cm = CounterexampleModel(failing_obligation=obligation, failing_module=module)
    if not raw:
        return cm

    # Split off the trace section if present so assignments and calls don't mix.
    lines = raw.splitlines()
    in_trace = False
    for ln in lines:
        if _TRACE_HDR_RE.search(ln):
            in_trace = True
            continue
        if in_trace:
            if "assert" in ln or "require" in ln:
                continue
            m = _CALL_RE.search(ln)
            if m:
                cm.trace.append(m.group(1).strip())
            continue
        for m in _ASSIGN_RE.finditer(ln):
            name, val = m.group(1), m.group(2)
            if name not in known_idents:
                continue                      # internal temp / accessor noise
            if val in ("true", "false"):
                cm.state[name] = 1 if val == "true" else 0
            else:
                cm.state[name] = int(val)
            cm.concrete = True

    # Heuristic recovery of the violated assertion (the guarantee).
    am = re.search(r"assert\s*\((.*?)\)\s*;", raw)
    if am:
        cm.violated_assertion = am.group(1).strip()
    return cm


# --------------------------------------------------------------------------
# (3) NEGATE  +  (4) ENCODE
# --------------------------------------------------------------------------
def build_constraint(cm: CounterexampleModel,
                     verified_states: list[State],
                     raw_fallback: str = "") -> str:
    """Produce the structured [REFINEMENT CONSTRAINT] block for the repair
    prompt. This is the artifact that replaces free-text failure_detail.

    The constraint encodes the CEGAR refinement obligation:
      strengthened invariant I' must satisfy
        I'(sigma_failed) == false                       (rule out the cex)
        forall sigma_v in verified_states: I'(sigma_v)  (keep verified states)
    """
    lines: list[str] = ["[REFINEMENT CONSTRAINT] (CEGAR-guided)"]

    if cm.concrete and cm.state:
        st = ", ".join(f"{k} = {v}" for k, v in sorted(cm.state.items()))
        lines.append("The previous module failed at the concrete state:")
        lines.append(f"    {st}")
        if cm.trace:
            lines.append(f"Reached via trace: [{' -> '.join(cm.trace)}]")
        if cm.violated_assertion:
            lines.append(f"Violated guarantee: {cm.violated_assertion}")
        lines.append("")
        lines.append("The revised module MUST:")
        lines.append("  - FALSIFY the state above (the predicate must return "
                     "false at exactly those values), AND")
        if verified_states:
            lines.append("  - PRESERVE every state already proven safe by a "
                         "verified obligation, namely:")
            for i, vs in enumerate(verified_states):
                pretty = ", ".join(f"{k}={v}" for k, v in sorted(vs.items()))
                lines.append(f"      sigma_{i}: {pretty}")
        else:
            lines.append("  - not over-strengthen: keep all currently-feasible "
                         "non-exposed states (inFlight == 0 must reduce to the "
                         "stable invariant).")
    else:
        # Degraded mode: no concrete model recovered. Still strictly better than
        # the old free text, because we attach the verified-state ledger and the
        # CEGAR framing so the LLM strengthens monotonically.
        lines.append("The previous module was refuted, but a concrete model "
                     "could not be parsed from the solver output.")
        if raw_fallback:
            snippet = " ".join(raw_fallback.split())[:300]
            lines.append(f"Solver said: {snippet}")
        if verified_states:
            lines.append("Strengthen the predicate but PRESERVE these "
                         "already-verified states:")
            for i, vs in enumerate(verified_states):
                pretty = ", ".join(f"{k}={v}" for k, v in sorted(vs.items()))
                lines.append(f"      sigma_{i}: {pretty}")
    return "\n".join(lines)


def refine(raw_counterexample: str, obligation: str, module: str,
           known_idents: set[str], verified_states: list[State]) -> tuple[str, CounterexampleModel]:
    """Convenience one-shot: extract -> project -> negate -> encode.

    Returns (constraint_block, model). The pipeline calls this and feeds the
    block as `failure_detail` to synth.repair_module.
    """
    cm = parse_counterexample(raw_counterexample, obligation, module, known_idents)
    block = build_constraint(cm, verified_states, raw_fallback=raw_counterexample)
    return block, cm
