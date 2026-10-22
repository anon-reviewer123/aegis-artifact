import shutil

# A local declared in the PRE phase (begin_body) but referenced in the POST
# phase (end_body) is out of scope in the generated endExposed() function, since
# Solidity scopes locals per-function. _resolve_unbound wrongly treats all phase
# locals as globally known (it unions _declared_locals across bodies), so it does
# not catch this. Fix: detect such cross-phase locals, promote them to harness
# storage fields, and remove their re-declaration from the POST body so the value
# snapshotted in the PRE phase persists into the POST phase.

def patch():
    P = "aegis/harness_synth.py"
    shutil.copy(P, P + ".bak_xphase")
    s = open(P).read()
    if "_promote_cross_phase_locals" in s:
        print("cross-phase promotion already present; skip"); return

    helper = '''
def _promote_cross_phase_locals(begin_body, end_body):
    """Locals declared in the PRE phase but used in the POST phase must survive
    across the (separate) beginExposed/endExposed functions. Promote them to
    harness storage: keep the PRE-phase assignment (rewritten to assign the
    field, not declare a local), drop the type in the POST usage, and return the
    field declarations. Sound: the field holds exactly the PRE-phase value."""
    # names declared with a type in the PRE body: `uint256 payment = ...;`
    pre_decls = {}
    for m in re.finditer(r"\\b((?:uint256|uint|int256|int|address|bool|bytes32)\\s+)"
                         r"([A-Za-z_]\\w*)\\s*=", begin_body):
        pre_decls[m.group(2)] = m.group(1).strip()
    if not pre_decls:
        return begin_body, end_body, ""
    # which of those are referenced in the POST body?
    post_ids = set(re.findall(r"[A-Za-z_]\\w*", end_body))
    crossed = {n: t for n, t in pre_decls.items() if n in post_ids}
    # exclude names the POST body itself re-declares (already in scope there)
    for m in re.finditer(r"\\b(?:uint256|uint|int256|int|address|bool|bytes32)\\s+"
                         r"([A-Za-z_]\\w*)\\s*=", end_body):
        crossed.pop(m.group(1), None)
    if not crossed:
        return begin_body, end_body, ""
    # rewrite PRE: `uint256 payment = X;` -> `payment = X;` (assign the field)
    for n, t in crossed.items():
        begin_body = re.sub(rf"\\b{re.escape(t)}\\s+{re.escape(n)}\\s*=",
                            f"{n} =", begin_body)
    decls = "\\n".join(f"    {t} public {n};   // [cross-phase] PRE local used in POST"
                       for n, t in sorted(crossed.items()))
    return begin_body, end_body, decls

'''
    anchor = "def synthesize_harness("
    s = s.replace(anchor, helper + "\n" + anchor, 1)

    # call it right after begin_body/end_body are built (after the msg.value
    # rewrite and _exp_bindings, before mapping instrumentation), and add the
    # promoted field declarations to the harness via the existing sum_ghost_line
    # slot is not ideal; instead append into storage_decls. Insert the call and
    # thread the decls into the template through a new placeholder.
    call_anchor = "    _extra_decls, (begin_body, end_body, callback_stubs, view_funcs) = _resolve_unbound("
    inject = ("    begin_body, end_body, _xphase_decls = _promote_cross_phase_locals(\n"
              "        begin_body, end_body)\n"
              + call_anchor)
    s = s.replace(call_anchor, inject, 1)

    # add _xphase_decls into the template. Reuse the sum_ghost_line insertion
    # point: append a new line after it.
    s = s.replace("{sum_ghost_line}", "{sum_ghost_line}{xphase_line}", 1)

    # compute xphase_line next to sum_ghost_line assignment
    s = s.replace(
        'sum_ghost_line = f"    uint256 public {_sg}; // [ghost] sum over {_mvar}\\n"',
        'sum_ghost_line = f"    uint256 public {_sg}; // [ghost] sum over {_mvar}\\n"\n'
        '        xphase_line = (_xphase_decls + "\\n") if _xphase_decls else ""')
    s = s.replace(
        'sum_ghost_line = ""',
        'sum_ghost_line = ""\n        xphase_line = (_xphase_decls + "\\n") if _xphase_decls else ""')

    open(P, "w").write(s)
    print("patched: cross-phase PRE locals promoted to harness fields")

patch()
