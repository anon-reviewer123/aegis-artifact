import shutil

PATH = "smoke10_v2.py"
shutil.copy(PATH, PATH + ".bak_prop")
src = open(PATH).read()

old = '''def derive_property(facts):
    best = None
    for site in facts.exposure_sites:
        before = [v for v in site.write_before_call if numeric(facts, v)]
        after = [v for v in site.write_after_call if numeric(facts, v)]
        if after and (before or after):
            for a in (before or after):
                for b in after:
                    if a != b:
                        return f"{a} == {b}"
    nums = [v for v in facts.storage_vars if numeric(facts, v)
            and "mapping" not in facts.var_types.get(v, "")]
    if len(nums) >= 2:
        return f"{nums[0]} == {nums[1]}"
    return None'''

new = '''def derive_property(facts):
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
        # same-variable window: conservation over the single exposed variable
        return f"{after[0]} == {after[0]}"
    return None'''

if old not in src:
    raise SystemExit("derive_property anchor missing")
src = src.replace(old, new)

# Relabel the no-property outcome as NO_WINDOW for clarity.
src = src.replace('rec["error"] = "no numeric property derivable"',
                  'rec["error"] = "no exposed window"')
src = src.replace('print(f"{addr[:12]}  NO_PROPERTY   sites={rec[\'exposure_sites\']}")',
                  'print(f"{addr[:12]}  NO_WINDOW     sites={rec[\'exposure_sites\']}")')

open(PATH, "w").write(src)
print("patched smoke10_v2.py property derivation (backup at .bak_prop)")
