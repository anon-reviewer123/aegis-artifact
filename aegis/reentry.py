"""
reentry.py - classic self-reentrancy obligation for Aegis.

When the exposed function is in its own closure, the exploit is re-entry through
that SAME function during its callback (DAO-style). The phase-split harness
linearizes execution and cannot see this interleaving, so the additive template
verifies a contract that is actually drainable.

This module builds an OBL_reentry obligation that runs the ORIGINAL (eth-modeled)
contract through SMTChecker with ext-calls=untrusted (the callback may re-enter
any public function), after injecting a snapshot ghost that asserts the caller's
per-account balance is unchanged across the callback window:

    require(<map>[msg.sender] >= amount);
    uint256 _entryBal = <map>[msg.sender];     // snapshot after the guard
    ... ICallback(cb).onCallback() ...          // re-entry window
    assert(<map>[msg.sender] == _entryBal);     // must be unchanged
    <map>[msg.sender] -= amount;

A nested re-entrant withdraw mutates <map>[msg.sender] mid-callback, so the
assert fails -> BUG_FOUND. A nonReentrant guard blocks the nested entry, so the
balance is stable -> SAFE. This distinguishes the safe/unsafe twins soundly.
"""
from __future__ import annotations
import os
import re


def _function_body_span(src, fn):
    m = re.search(r"function\s+" + re.escape(fn) + r"\b[^{]*\{", src)
    if not m:
        return None
    bstart = m.end() - 1
    depth = 0
    j = bstart
    n = len(src)
    while j < n:
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return (bstart, j + 1)
        j += 1
    return None


def build_reentry_source(contract_name, exposed_fn):
    """Return injected eth-modeled source for OBL_reentry, or None if the
    contract does not match the classic per-account self-reentry shape."""
    base = os.path.join("contracts", "corpus", contract_name)
    src = None
    for cand in (base + ".ethmodel.sol", base + ".sol"):
        if os.path.exists(cand):
            src = open(cand).read()
            break
    if src is None:
        return None

    span = _function_body_span(src, exposed_fn)
    if span is None:
        return None
    bstart, bend = span
    body = src[bstart:bend]

    # per-account guard: require(<map>[msg.sender] >= <amt> ...)
    gm = re.search(
        r"require\(\s*([A-Za-z_]\w*)\s*\[\s*msg\.sender\s*\]\s*>=\s*([A-Za-z_]\w*)",
        body)
    if not gm:
        return None
    mapv = gm.group(1)

    # the decrement we protect: <map>[msg.sender] -=
    dm = re.search(re.escape(mapv) + r"\[\s*msg\.sender\s*\]\s*-=", body)
    if not dm:
        return None

    # inject snapshot right after the guard statement
    guard_end = body.find(";", gm.end())
    if guard_end == -1:
        return None
    guard_end += 1
    snap = "\n        uint256 _entryBal = " + mapv + "[msg.sender];"
    new_body = body[:guard_end] + snap + body[guard_end:]

    # insert assert right before the (recomputed) decrement
    dm2 = re.search(re.escape(mapv) + r"\[\s*msg\.sender\s*\]\s*-=", new_body)
    assert_stmt = "assert(" + mapv + "[msg.sender] == _entryBal); "
    new_body = new_body[:dm2.start()] + assert_stmt + new_body[dm2.start():]

    return src[:bstart] + new_body + src[bend:]


def _strip_flag_guard(pred):
    """Turn `exposed || reserve == supply` into `reserve == supply`.
    The safe twin guards its invariant with `<flag> ||`; the obligation asserts
    the RAW consistency the view depends on, so the view-call gate (which
    reverts in the guarded safe contract) is what distinguishes the twins."""
    pred = pred.strip().rstrip(";").strip()
    # drop a leading `<ident> ||`
    m = re.match(r"^[A-Za-z_]\w*\s*\|\|\s*(.+)$", pred)
    if m:
        return m.group(1).strip()
    return pred


def _invariant_predicate(src):
    """Extract the boolean expression returned by `function invariant()`."""
    m = re.search(r"function\s+invariant\s*\([^)]*\)[^{]*\{\s*return\s+([^;]+);",
                  src)
    if not m:
        return None
    return _strip_flag_guard(m.group(1))


def _observable_view(src, exposed_fn):
    """Find a public view function (not invariant) whose body reads state.
    Returns its name, or None. This is the read-only 'observation' point."""
    for m in re.finditer(
            r"function\s+([A-Za-z_]\w*)\s*\([^)]*\)\s*public\s+view\b", src):
        name = m.group(1)
        if name in ("invariant", exposed_fn):
            continue
        return name
    return None


def build_readonly_obligation(contract_name, exposed_fn):
    """Read-only reentrancy obligation: at the callback window, an attacker can
    observe a view function. If the view is observable while the consistency
    invariant is broken, that is the bug.

    We inject at the callback point:   <view>(); assert(<raw_invariant>);
    - <view>() acts as an observability GATE: in the safe twin it reverts
      (require(!exposed)), so execution stops and nothing is asserted -> SAFE.
    - <raw_invariant> (e.g. reserve == supply) is the LINEAR consistency the
      view depends on; in the unsafe twin the state is desynced at the callback
      -> assert fails -> VIOLATION. (Linear, so CHC refutes it cleanly.)

    Returns injected source string, or None if the contract is not read-only
    shaped (no observable view, or no invariant predicate)."""
    base = os.path.join("contracts", "corpus", contract_name)
    src = None
    for cand in (base + ".ethmodel.sol", base + ".sol"):
        if os.path.exists(cand):
            src = open(cand).read()
            break
    if src is None:
        return None

    view = _observable_view(src, exposed_fn)
    if view is None:
        return None
    pred = _invariant_predicate(src)
    if pred is None:
        return None

    # locate the external callback call inside the exposed function
    span = _function_body_span(src, exposed_fn)
    if span is None:
        return None
    bstart, bend = span
    body = src[bstart:bend]

    # find the external callback call: <Iface>(<arg>).<method>(...);
    cm = re.search(r"[A-Za-z_]\w*\s*\(\s*[A-Za-z_]\w*\s*\)\s*\.\s*"
                   r"[A-Za-z_]\w*\s*\([^;]*\)\s*;", body)
    if not cm:
        return None

    # The call may be the body of a braceless `if (cond) <call>;`. Injecting
    # between the `if` and the call would detach the probe's gate from its
    # assert and make the assert unconditional. So we inject the probe before
    # the ENCLOSING statement: scan back from the call to the start of its
    # statement (the preceding `;` or `{`, or the `if (...)` that guards it).
    stmt_start = cm.start()
    # walk back over an optional `if (...)` guard immediately preceding the call
    pre = body[:cm.start()]
    gm = re.search(r"if\s*\([^)]*\)\s*$", pre)
    if gm:
        stmt_start = gm.start()
    else:
        # otherwise inject right after the previous statement terminator
        sep = max(pre.rfind(";"), pre.rfind("{"))
        stmt_start = sep + 1 if sep != -1 else cm.start()

    probe = " " + view + "(); assert(" + pred + "); "
    new_body = body[:stmt_start] + probe + body[stmt_start:]
    return src[:bstart] + new_body + src[bend:]


def build_conservation_obligation(contract_name, exposed_fn):
    """Flash-loan / conservation reentrancy obligation.

    A flash loan relocates value across the callback (cash -> loans -> cash)
    while keeping a conservation invariant (cash + loans == totalAssets) intact
    THROUGHOUT the window. The exploit is a state-mutating callback (e.g.
    depositDuringCallback) that runs during the window and breaks conservation
    by crediting one side only (totalAssets += amt without cash += amt). A safe
    contract guards the window (require(!inFlash)) so the mutation reverts.

    We inject, right after the external callback call, an assertion of the
    conservation invariant, and run under ext-calls=untrusted so the attacker's
    mutating call is modeled. In the unsafe twin the callback breaks
    conservation -> VIOLATION; in the safe twin the guard reverts -> SAFE. The
    assertion is the contract's own invariant() predicate (flag-guard stripped),
    so it is the exact relation the protocol promises.

    Returns injected source string, or None if not conservation-shaped (no
    multi-term invariant, or no locatable callback)."""
    base = os.path.join("contracts", "corpus", contract_name)
    src = None
    for cand in (base + ".ethmodel.sol", base + ".sol"):
        if os.path.exists(cand):
            src = open(cand).read()
            break
    if src is None:
        return None

    pred = _invariant_predicate(src)   # reuses the read-only helper (strips flag)
    if pred is None:
        return None
    # only a multi-term (conservation) invariant needs this obligation; a plain
    # A == B is handled by the standard closure/phase machinery.
    if "+" not in pred:
        return None

    span = _function_body_span(src, exposed_fn)
    if span is None:
        return None
    bstart, bend = span
    body = src[bstart:bend]

    cm = re.search(r"[A-Za-z_]\w*\s*\(\s*[A-Za-z_]\w*\s*\)\s*\.\s*"
                   r"[A-Za-z_]\w*\s*\([^;]*\)\s*;", body)
    if not cm:
        return None

    inject = " assert(" + pred + ");"
    new_body = body[:cm.end()] + inject + body[cm.end():]
    return src[:bstart] + new_body + src[bend:]
