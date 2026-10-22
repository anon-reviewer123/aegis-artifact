"""
guards.py - which closure members can actually run during the window.

The conservative closure over-approximates the adversary: it takes every public
or external function that touches exposed storage. That is the right starting
point, but it counts functions the contract itself makes unreachable during the
window. The common case is a mutex. The exposure function sets a boolean before
it yields control and clears it after, and every other entry point begins with

    require(!inCall);

Such a function reverts for the whole duration of the window, so no admissible
callback schedule contains it. Keeping it in the closure is not unsound, only
imprecise, and the imprecision is expensive: the read-only rule needs every
member of the closure to preserve the observation footprint, so one guarded
writer is enough to push an otherwise provable site into the general arm.

Excluding it is sound under one condition, which is what this module checks:
the flag must be set in the pre-phase of the very site being analysed and
cleared in its post-phase, so it is true throughout the window, and the member
must require it to be false. Both facts come from the analyzers, which see the
statement order and the guard expressions; nothing here re-parses source.

The refinement only ever removes members that provably cannot execute. A
function whose guard cannot be established stays in the closure.
"""
from __future__ import annotations


def window_flags(site) -> set[str]:
    """Booleans that are true for the whole of this site's callback window."""
    return set(getattr(site, "window_flags", set()) or set())


def blocked_members(facts, site) -> dict:
    """Closure members the window's own guard excludes, as {name: flag}."""
    flags = window_flags(site)
    if not flags:
        return {}
    out = {}
    for name, info in facts.functions.items():
        held = set(getattr(info, "guard_flags", set()) or set()) & flags
        if held:
            out[name] = sorted(held)[0]
    return out


def admissible_closure(facts, site, include_suspended=False) -> set[str]:
    """Closure(s) restricted to members that can execute during the window.

    Guarded members are dropped because the flag they check is held for the
    duration. What remains is the set an admissible callback schedule can draw
    from.

    include_suspended decides whether the function that opened the window is
    part of that set, and the two callers want different answers.

    The read-only premise asks which callbacks can move the observation. The
    suspended function moves it by construction -- that is what makes the
    window -- so counting it would refuse every site and the premise would
    never apply. It is excluded there.

    The nesting gate asks which functions can yield control while the window is
    open, and re-entering the same function is the commonest way that happens:
    a hook calling back into the function it interrupted reaches that
    function's own external call, which is a second level of callback and
    outside the depth-one model. Excluding it there hides exactly the case the
    gate exists to catch. It is included, and the guard refinement removes it
    again when a mutex makes re-entry impossible.
    """
    closure = facts.full_closure(site)
    if not include_suspended:
        closure = closure - {site.function}
    return closure - set(blocked_members(facts, site))


def explain(facts, site) -> str:
    """One line describing what the refinement removed, for the run log."""
    blocked = blocked_members(facts, site)
    if not blocked:
        return ""
    parts = ", ".join(f"{fn} (requires !{flag})"
                      for fn, flag in sorted(blocked.items()))
    return f"guarded out of the closure: {parts}"
