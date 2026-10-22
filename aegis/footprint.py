"""
footprint.py - the admissibility premise of the read-only rule.

The read-only obligation replaces invariant preservation with a relational
check on what an external reader observes. That substitution is only valid
when no admissible callback can move the observation while the window is open.
Concretely, for an exposed view g we take the transitive observation footprint

    R*(g) = Read*(g)

and require, for every member h of the callback closure other than the
suspended function itself,

    W*(h) n R*(g) = {}

A member that writes the footprint can change what g returns without any of the
suspended function's own effects being involved, so the three-state comparison
no longer characterises the window and the site belongs to the general arm.

A member whose storage effect cannot be bounded (delegatecall, inline assembly,
an unresolved low-level call) is not admitted either: its write set is unknown,
so the premise cannot be discharged and the honest outcome is no verdict rather
than a proof.

The check is syntactic and one-directional. It can refuse a site whose callback
would in fact have left the view alone, which costs coverage. It cannot admit a
site whose callback may write the footprint, which is the direction that would
cost soundness.
"""
from __future__ import annotations
from dataclasses import dataclass


@dataclass
class ViewVerdict:
    view: str
    admitted: bool
    reason: str
    writer: str = ""          # closure member that writes the footprint
    footprint: tuple = ()     # storage the view transitively reads
    obs_type: str = ""        # solidity type the observation is compared at


_ELEMENTARY = ("uint", "int", "bool", "address", "bytes1", "bytes2", "bytes3",
               "bytes4", "bytes8", "bytes16", "bytes32", "enum")


def observation_type(facts, view: str) -> tuple[str, str]:
    """Resolve the type the three observations of `view` are compared at.

    Returns (solidity_type, "") when the value is a comparable scalar, or
    ("", reason) when it is not. Quiescence is an equality between values, so a
    view returning nothing, several values, or a reference type has no
    observation the rule can talk about. Declaring one anyway produces a
    harness that does not compile, which the backend then reports as an
    undecided obligation rather than as an inapplicable rule.
    """
    info = facts.functions.get(view)
    if info is None:
        return "", "view not found"
    rts = [t for t in (info.return_types or []) if t]
    if not rts:
        return "", "view returns no value to compare"
    if len(rts) > 1:
        return "", f"view returns {len(rts)} values; no single observation"
    t = rts[0].replace(" memory", "").replace(" calldata", "").replace(
        " storage", "").replace(" payable", "").strip()
    if t.startswith("enum"):
        return "uint256", ""          # enums compare as their ordinal
    if t.startswith("contract "):
        return "address", ""
    if not t.startswith(_ELEMENTARY):
        return "", f"view returns {t}, which is not a comparable scalar"
    if t in ("uint", "int"):
        t += "256"
    if t.startswith("bytes") and not t[5:].isdigit():
        return "", "view returns dynamic bytes, which is not a scalar"
    return t, ""


def classify_views(facts, site, views) -> list[ViewVerdict]:
    """Decide, for each candidate exposed view, whether the read-only rule
    applies. Returns one verdict per view in the order given."""
    from .guards import admissible_closure
    closure = admissible_closure(facts, site)
    out = []
    for g in views:
        otype, orr = observation_type(facts, g)
        if not otype:
            out.append(ViewVerdict(g, False, orr))
            continue
        fp = facts.transitive_reads(g) & set(facts.storage_vars)
        if not fp:
            out.append(ViewVerdict(g, False, "view reads no contract storage",
                                   obs_type=otype))
            continue
        if facts.reaches_unresolved(g):
            out.append(ViewVerdict(g, False,
                                   "view reaches an unbounded construct "
                                   "(delegatecall or assembly)", "",
                                   tuple(sorted(fp)), otype))
            continue
        blocker, why = "", ""
        for h in sorted(closure):
            if facts.reaches_unresolved(h):
                blocker, why = h, "reaches an unbounded construct"
                break
            overlap = facts.transitive_writes(h) & fp
            if overlap:
                blocker = h
                why = "writes footprint " + ",".join(sorted(overlap))
                break
        if blocker:
            out.append(ViewVerdict(g, False,
                                   f"closure member {blocker} {why}",
                                   blocker, tuple(sorted(fp)), otype))
            continue
        out.append(ViewVerdict(g, True, "closure preserves the observation "
                               "footprint", "", tuple(sorted(fp)), otype))
    return out


def admitted_views(facts, site, views) -> tuple[list[str], list[ViewVerdict]]:
    """Convenience split: (names admitted to the read-only arm, all verdicts)."""
    verdicts = classify_views(facts, site, views)
    return [v.view for v in verdicts if v.admitted], verdicts
