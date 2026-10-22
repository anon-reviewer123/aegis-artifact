import shutil

P = "smoke10_v2.py"
shutil.copy(P, P + ".bak_cons")
s = open(P).read()

# Emit a conservation target for same-variable windows: `v == snapPre`.
old = '''        # same-variable window: a conservation target needs a ghost the
        # pipeline only introduces for ETH-balance patterns. Without it, the
        # only well-typed target would be the tautology `v == v`, which is
        # trivially true and drives the CHC solver into an unbounded search.
        # Skip here; these are reported NO_WINDOW until ghost support is added.
        return None
    return None'''
new = '''        # same-variable window: conservation over one accounting variable.
        # The harness snapshots v into snapPre at entry, so the honest target is
        # `v == snapPre` with exposure invariant `v == snapPre + inFlight`.
        return f"{after[0]} == snapPre"
    return None'''
if old not in s:
    raise SystemExit("smoke conservation anchor missing (apply prior patches first)")
s = s.replace(old, new)

open(P, "w").write(s)
print("patched smoke10_v2.py: same-variable windows -> `v == snapPre`")
