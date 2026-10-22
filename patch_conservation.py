import re
import shutil
import sys

# Generalize the conservation ghost to same-variable windows.
# Adds a snapPre snapshot ghost; when the exposed site writes the same numeric
# variable v before and after the callback, the harness snapshots v into snapPre
# at entry, and the stub emits stable target `v == snapPre` with exposure
# invariant `v == snapPre + inFlight` (paper's aum = trackedValue + inFlight,
# generalized to any accounting variable).

def patch_harness():
    P = "aegis/harness_synth.py"
    shutil.copy(P, P + ".bak_cons")
    s = open(P).read()

    if "snapPre" in s:
        print("harness_synth.py already has snapPre; skipping structural edits")
    else:
        s = s.replace(
            '_GHOST_LEDGER_VARS = {"inFlight", "exposed"}',
            '_GHOST_LEDGER_VARS = {"inFlight", "exposed", "snapPre"}')
        s = s.replace(
            '_known = (set(facts.storage_vars) - _omitted) | {"inFlight", "exposed", "amount", "who"}',
            '_known = (set(facts.storage_vars) - _omitted) | {"inFlight", "exposed", "snapPre", "amount", "who"}')

        # Compute the snapshot statement inside synthesize_harness, just before
        # the final return f-string. Detect a same-variable numeric window.
        anchor = '    return f"""// SPDX-License-Identifier: MIT'
        snap_logic = '''    # Same-variable conservation: if the exposed site writes one numeric
    # variable both before and after the callback, snapshot it at entry so the
    # stub can target `v == snapPre` with invariant `v == snapPre + inFlight`.
    def _num(v):
        t = (facts.var_types.get(v, "uint256") or "uint256")
        return t.startswith("uint") or t.startswith("int")
    _snap_var = ""
    for _s in [site]:
        _after = [v for v in _s.write_after_call if _num(v)]
        _before = [v for v in _s.write_before_call if _num(v)]
        _cross = [(a, b) for a in _before for b in _after if a != b]
        if _after and not _cross:
            _snap_var = _after[0]
            break
    snap_stmt = ("        snapPre = %s;\\n" % _snap_var) if _snap_var else ""

'''
        s = s.replace(anchor, snap_logic + anchor, 1)

        # Inject snapPre declaration + snapshot into the f-string body.
        s = s.replace(
            '    uint256 public inFlight;\n    bool    public exposed;',
            '    uint256 public inFlight;\n    uint256 public snapPre; '
            '// [ghost] entry snapshot for same-variable conservation\n'
            '    bool    public exposed;', 1)
        s = s.replace(
            '    function beginExposed(uint256 amount) public {{\n{begin_body}',
            '    function beginExposed(uint256 amount) public {{\n{snap_stmt}{begin_body}',
            1)

    open(P, "w").write(s)
    print("patched harness_synth.py (backup .bak_cons)")


def patch_synth():
    P = "aegis/synth.py"
    shutil.copy(P, P + ".bak_cons")
    s = open(P).read()

    # Teach _accounting_vars to accept `v == snapPre` (snapPre is a ghost, not a
    # storage var, so the existing `both in storage_vars` check rejects it).
    old = '''    a, b = m.group(1), m.group(2)
    sv = set(facts.storage_vars)
    if a in sv and b in sv:
        return a, b
    return None'''
    new = '''    a, b = m.group(1), m.group(2)
    sv = set(facts.storage_vars)
    if a in sv and b in sv:
        return a, b
    # same-variable conservation: `v == snapPre`, where snapPre is the entry
    # snapshot ghost injected by the harness. Treat as the accounting pair.
    if a in sv and b == "snapPre":
        return a, b
    return None'''
    if old in s:
        s = s.replace(old, new)
    open(P, "w").write(s)
    print("patched synth.py (backup .bak_cons)")


def patch_compiler():
    P = "aegis/compiler.py"
    shutil.copy(P, P + ".bak_cons")
    s = open(P).read()
    # Register snapPre as a known identifier so quoting/rename passes keep it.
    old = 'known_idents = list(facts.storage_vars) + [_CANON_GHOST, _CANON_FLAG]'
    new = 'known_idents = list(facts.storage_vars) + [_CANON_GHOST, _CANON_FLAG, "snapPre"]'
    if old in s and "snapPre" not in s:
        s = s.replace(old, new)
        open(P, "w").write(s)
        print("patched compiler.py (backup .bak_cons)")
    else:
        print("compiler.py already knows snapPre or anchor missing; skipped")


patch_harness()
patch_synth()
patch_compiler()
print("\nconservation-ghost generalization applied.")
