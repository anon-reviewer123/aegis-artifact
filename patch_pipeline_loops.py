"""
Gap 1 Slice 4: wire loop verification into run_aegis(). If the contract has loop
sites, synthesize + check the inductive loop-step obligation for each and fold the
result into the verdict. Runs alongside the existing exposure-site path; a loop
contract with no exposure sites now verifies via the loop path instead of
returning "nothing to verify".
"""
import shutil

def patch():
    P = "aegis/pipeline.py"
    shutil.copy(P, P + ".bak_loops")
    s = open(P).read()

    if "loop_verification" in s:
        print("loop verification already wired"); return

    # helper function, added near the top after imports
    helper = '''
def _run_loop_verification(facts, backend, say, smt_timeout_ms):
    """Synthesize and check the inductive loop-step obligation for each loop
    site. Returns (status, reports) where status is VERIFIED / BUG_FOUND / UNKNOWN.
    A loop is safe iff its step obligation verifies (the step proves the invariant
    is preserved for an arbitrary iteration count -- no unrolling)."""
    synth_loop_step = None
    for _modname in ("aegis.loop_harness_synth", "loop_harness_synth",
                     "loop_harness_synth4"):
        try:
            _m = __import__(_modname, fromlist=["synth_loop_step"])
            synth_loop_step = _m.synth_loop_step
            break
        except Exception:
            continue
    if synth_loop_step is None:
        say("[loop] synthesizer module not found "
            "(place loop_harness_synth.py in aegis/ or on sys.path)")
        return "UNKNOWN", []
    reports = []
    any_bug = False
    any_checked = False
    for site in facts.loop_sites:
        ob = synth_loop_step(site, facts)
        if ob is None:
            say(f"[loop] {site.function}: unsupported loop shape (skipped)")
            continue
        say(f"[loop] {site.function}: {ob.kind} step obligation "
            f"(structural hint: {ob.expect_hint})")
        res = backend.check_obligation(ob.name, "loop", ob.harness_source,
                                       smt_timeout_ms, ext_calls="trusted")
        reports.append(res)
        any_checked = True
        st = getattr(res, "status", "unknown")
        say(f"      {ob.name} [{ob.kind}]: {st.upper()}"
            + (f" :: {res.detail}" if getattr(res, 'detail', '') else ""))
        if st == "failed":
            any_bug = True
    if not any_checked:
        return "UNKNOWN", reports
    if any_bug:
        return "BUG_FOUND", reports
    # all checked loop steps verified
    return "VERIFIED", reports

'''
    s = s.replace("def run_aegis(", helper + "\ndef run_aegis(", 1)

    # in run_aegis: when there are loop sites, run loop verification. Do it BEFORE
    # the "no exposure sites -> nothing to verify" early return, so pure-loop
    # contracts are handled. If there are also exposure sites, run loops first and
    # combine (a bug in either -> BUG_FOUND).
    anchor = '''    if not facts.exposure_sites:
        say("no callback-exposed sites found; nothing to verify")
        return AegisResult("UNKNOWN", None, 0, 0, 0, backend_used, [], log)'''
    new = '''    loop_status, loop_reports = ("NONE", [])
    if getattr(facts, "loop_sites", None):
        say(f"[loop] {len(facts.loop_sites)} loop-call site(s) detected")
        loop_status, loop_reports = _run_loop_verification(
            facts, backend, say, smt_timeout_ms)
        say(f"[loop] loop verification: {loop_status}")

    if not facts.exposure_sites:
        if loop_status in ("VERIFIED", "BUG_FOUND"):
            st = "VERIFIED" if loop_status == "VERIFIED" else "BUG_FOUND"
            return AegisResult(st, None, 0, 0, 0, backend_used, loop_reports, log)
        say("no callback-exposed sites found; nothing to verify")
        return AegisResult("UNKNOWN", None, 0, 0, 0, backend_used, loop_reports, log)'''
    s = s.replace(anchor, new)

    open(P, "w").write(s)
    print("patched pipeline.py: loop verification wired into run_aegis")

patch()
