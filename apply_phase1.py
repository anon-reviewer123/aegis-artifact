#!/usr/bin/env python3
"""
Phase-1 installer: wire the Template abstraction into compiler.py and add the
optional ExposureInvariant.kind field. BEHAVIOR-PRESERVING: T1 (additive) is the
default and reproduces the current obligation check-bodies exactly.

Run from the aegis_dist root:  python3 apply_phase1.py
It edits aegis/compiler.py and aegis/mcvp.py in place (after backing them up).
"""
import re, shutil, os, sys

ROOT = "aegis"
COMP = os.path.join(ROOT, "compiler.py")
MCVP = os.path.join(ROOT, "mcvp.py")

if not os.path.exists(COMP):
    sys.exit("run this from the aegis_dist root (aegis/compiler.py not found)")

shutil.copy(COMP, COMP + ".bak_pretemplate")
shutil.copy(MCVP, MCVP + ".bak_pretemplate")

# ---- 1. mcvp.py: add optional `kind` to ExposureInvariant -----------------
m = open(MCVP).read()
old_inv = '''@dataclass
class ExposureInvariant:
    # A string predicate over contract storage + ghost vars. Kept as a
    # backend-agnostic expression; the compiler lowers it per backend.
    formula: str                    # e.g. "totalAssets == totalShares + inFlight"
    stable_formula: str             # e.g. "totalAssets == totalShares"'''
new_inv = '''@dataclass
class ExposureInvariant:
    # A string predicate over contract storage + ghost vars. Kept as a
    # backend-agnostic expression; the compiler lowers it per backend.
    formula: str                    # e.g. "totalAssets == totalShares + inFlight"
    stable_formula: str             # e.g. "totalAssets == totalShares"
    # Which invariant TEMPLATE this plan uses. Defaults to "additive" (T1) so
    # existing plans and serialized JSON keep working unchanged. The compiler
    # dispatches obligation lowering on this field (see aegis/templates.py).
    kind: str = "additive"'''
if old_inv not in m:
    sys.exit("ExposureInvariant block not found in mcvp.py (already patched?)")
m = m.replace(old_inv, new_inv)
open(MCVP, "w").write(m)
print("mcvp.py: added ExposureInvariant.kind (default 'additive')")

# ---- 2. compiler.py: import templates + dispatch the 3 check bodies -------
c = open(COMP).read()

# 2a. import
if "from .templates import" not in c:
    c = c.replace(
        "from .static_analysis import ContractFacts",
        "from .static_analysis import ContractFacts\n"
        "from .templates import get_template, TemplateCtx")

# 2b. build the template + ctx right after primary_ghost is computed
anchor = "    primary_ghost = _primary_ghost_name(plan)\n"
if anchor not in c:
    sys.exit("anchor (primary_ghost assignment) not found in compiler.py")
inject = anchor + '''
    # ---- invariant template dispatch (Phase 1) ----------------------------
    # The template decides the predicate each obligation establishes/preserves/
    # restores. Default is additive (T1), reproducing the original behavior.
    template = get_template(getattr(plan.exposure_invariant, "kind", "additive"))
'''
c = c.replace(anchor, inject, 1)

# 2c. We must build the ctx AFTER q() and share_guard are defined. q is defined
# just below; share_guard is defined right before OBL_pre. Insert ctx build
# immediately after the share_guard assignment.
sg_anchor = ('    share_guard = (f"require(v.{_share_mapping_name(facts)}(address(this)) >= amount);\\n"\n'
             '                   if _share_mapping_name(facts) else "")\n')
if sg_anchor not in c:
    sys.exit("share_guard anchor not found in compiler.py (formatting differs)")
ctx_build = sg_anchor + '''    _ctx = TemplateCtx(q=q, inv_exp=inv_exp, inv_stable=inv_stable,
                       target=target, flag_name=flag_name,
                       primary_ghost=primary_ghost, share_guard=share_guard)
'''
c = c.replace(sg_anchor, ctx_build, 1)

# 2d. Replace the three inline check bodies with template calls.
# OBL_pre body:
pre_old = '''        harness_source=_wrap(_trim_harness(body, {"beginExposed"}), H, f"""
        function check(uint256 amount) public {{
            // assume stable invariant holds on entry and a feasible operation
            require({q(inv_stable)});
            {share_guard}v.depositFor(address(this), amount); // seed feasible state
            v.beginExposed(amount);              // PRE phase body
            assert({q(inv_exp)});                // must establish I_exp
        }}""")))'''
pre_new = '''        harness_source=_wrap(_trim_harness(body, {"beginExposed"}), H,
                             template.pre_check(_ctx))))'''
if pre_old not in c:
    sys.exit("OBL_pre inline body not found verbatim in compiler.py")
c = c.replace(pre_old, pre_new, 1)

# OBL_cb body (inside the for loop):
cb_old = '''            harness_source=_wrap(_trim_harness(body, {"beginExposed", f}), H, f"""
            function check(uint256 amount) public {{
                require(v.{flag_name}());
                require({q(inv_exp)});           // assume I_exp before callback
                v.{f}(amount);                    // run the callback
                assert({q(inv_exp)});            // I_exp must still hold
            }}""")))'''
cb_new = '''            harness_source=_wrap(_trim_harness(body, {"beginExposed", f}), H,
                                 template.cb_check(_ctx, f))))'''
if cb_old not in c:
    sys.exit("OBL_cb inline body not found verbatim in compiler.py")
c = c.replace(cb_old, cb_new, 1)

# OBL_post body:
post_old = '''        harness_source=_wrap(_trim_harness(body, {"beginExposed", "endExposed"}), H, f"""
        function check(uint256 amount) public {{
            require(v.{flag_name}());
            require({q(inv_exp)});                // assume I_exp at call return
            require(v.{primary_ghost}() == amount); // post settles the full in-flight amount
            v.endExposed(amount);                 // POST phase body
            assert({q(inv_stable)});             // I_stable restored
            assert(v.{primary_ghost}() == 0);     // in-flight ghost fully settled
            assert(!v.{flag_name}());             // exposed phase exited
        }}""")))'''
post_new = '''        harness_source=_wrap(_trim_harness(body, {"beginExposed", "endExposed"}), H,
                             template.post_check(_ctx))))'''
if post_old not in c:
    sys.exit("OBL_post inline body not found verbatim in compiler.py")
c = c.replace(post_old, post_new, 1)

open(COMP, "w").write(c)
print("compiler.py: wired template dispatch for OBL_pre / OBL_cb / OBL_post")
print("PHASE 1 INSTALLED. Behavior should be IDENTICAL (additive default).")
