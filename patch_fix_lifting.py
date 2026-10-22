import shutil

P = "aegis/ast_analysis.py"
shutil.copy(P, P + ".bak_liftfix")
s = open(P).read()

# Fix 1: only lift base sites that ALREADY have a genuine window. A windowless
# leaf (e.g. a bare `.transfer(amount)` to an EOA wallet with no straddling
# state writes) is not an exposed accounting window; lifting must not
# manufacture one by accumulating an ancestor's unrelated writes.
old_head = '''    lifted = []
    lifted_keys = set()
    for s in list(exposure_sites):
        fi = functions.get(s.function)
        if fi is None or fi.visibility in ("public", "external"):
            continue
        frontier = [(s.function, set(s.write_before_call), set(s.write_after_call))]'''
new_head = '''    lifted = []
    lifted_keys = set()
    for s in list(exposure_sites):
        fi = functions.get(s.function)
        if fi is None or fi.visibility in ("public", "external"):
            continue
        # Only lift a base site that already has a real straddling window.
        # Without this, a windowless leaf accumulates callers' unrelated writes
        # and becomes a fabricated window on a contract that has none.
        if not (s.write_before_call and s.write_after_call):
            continue
        frontier = [(s.function, set(s.write_before_call), set(s.write_after_call))]'''

if old_head not in s:
    raise SystemExit("lifting head anchor missing")
s = s.replace(old_head, new_head)

# Fix 2: at each lift level, the propagated window must come from writes that
# actually straddle the call to the child in THIS caller. The child's own
# window (hb/ha) is only valid if the child's external call is the thing being
# reached; the caller's writes before/after the call statement are wb/wa. We
# keep wb|hb / wa|ha (that part is correct once the base has a window), but we
# additionally require the child contributed a non-empty window so we never
# widen a caller's incidental writes into a window on their own.
old_prop = '''                    _, wb = _referenced_state({"statements": stmts[:hit]},
                                              state_ids, state_names)
                    _, wa = _referenced_state({"statements": stmts[hit + 1:]},
                                              state_ids, state_names)
                    wbc = wb | hb
                    wac = wa | ha'''
new_prop = '''                    # The child must carry a real window up; a windowless
                    # child cannot seed a window in the caller.
                    if not (hb and ha):
                        continue
                    _, wb = _referenced_state({"statements": stmts[:hit]},
                                              state_ids, state_names)
                    _, wa = _referenced_state({"statements": stmts[hit + 1:]},
                                              state_ids, state_names)
                    wbc = wb | hb
                    wac = wa | ha'''

if old_prop not in s:
    raise SystemExit("lifting propagate anchor missing")
s = s.replace(old_prop, new_prop)

open(P, "w").write(s)
print("patched ast_analysis.py: lifting requires a genuine base window")
print("(backup at .bak_liftfix)")
