import shutil

P = "smoke10_v2.py"
shutil.copy(P, P + ".bak_align")
s = open(P).read()

# The pipeline builds the harness on facts.exposure_sites[0]. The property MUST
# come from that same site, or the target variable and the snapshotted variable
# disagree and every plan is rejected. Replace the multi-site scan with a
# single-site derivation keyed on exposure_sites[0].
old = '''def derive_property(facts):
    """Derive a target property ONLY from a genuine exposed window. Two shapes:
    a cross-variable equality when the pre-write and post-write touch different
    accounting variables, and a single-variable conservation property when the
    same variable is written on both sides of the callback (the pipeline's ETH /
    ghost model lifts this to `var == var_pre + ghost`). Contracts with no
    exposed window return None and are reported NO_WINDOW rather than given a
    junk pair of unrelated storage variables."""
    for site in facts.exposure_sites:
        before = [v for v in site.write_before_call if numeric(facts, v)]
        after = [v for v in site.write_after_call if numeric(facts, v)]
        if not after:
            continue
        cross = [(a, b) for a in before for b in after if a != b]
        if cross:
            a, b = cross[0]
            return f"{a} == {b}"
        # same-variable window: conservation over one accounting variable.
        # The harness snapshots v into snapPre at entry, so the honest target is
        # `v == snapPre` with exposure invariant `v == snapPre + inFlight`.
        return f"{after[0]} == snapPre"
    return None'''
new = '''def derive_property(facts):
    """Derive the target from facts.exposure_sites[0] -- the SAME site the
    pipeline builds the harness on. Deriving from any other site desynchronizes
    the target variable from the snapshotted variable and every plan is rejected.
    Cross-variable window -> `A == B`; same-variable window -> `v == snapPre`
    (harness snapshots v into snapPre, invariant is `v == snapPre + inFlight`).
    Returns None (NO_WINDOW) when site[0] has no numeric post-call write."""
    if not facts.exposure_sites:
        return None
    site = facts.exposure_sites[0]
    before = [v for v in site.write_before_call if numeric(facts, v)]
    after = [v for v in site.write_after_call if numeric(facts, v)]
    if not after:
        return None
    cross = [(a, b) for a in before for b in after if a != b]
    if cross:
        a, b = cross[0]
        return f"{a} == {b}"
    return f"{after[0]} == snapPre"'''
if old not in s:
    raise SystemExit("align anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched smoke10_v2.py: property now derived from exposure_sites[0]")
