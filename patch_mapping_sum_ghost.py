import shutil

# ============================================================================
# Mapping-sum conservation ghost for read-only reentrancy.
#
# For an exposed mapping m (mapping(addr=>uint)), introduce a scalar ghost
# _sumM tracking sum_k m[k]. Instrument m[k] writes in the copied phase bodies
# to keep _sumM in step. The view-safety obligation then checks the real
# read-only-reentrancy backing invariant _sumM <= address(this).balance, which
# must hold even mid-callback. This is expressible because _sumM is a scalar
# ghost; RAVEN's polyhedral domain cannot sum an unbounded mapping, so this is
# the wedge for the read-only class.
# ============================================================================


def patch_harness():
    P = "aegis/harness_synth.py"
    shutil.copy(P, P + ".bak_sumghost")
    s = open(P).read()

    if "_sum_ghost_name" in s:
        print("mapping-sum ghost already present; skip")
        return

    # --- helper: name + detection ---
    helpers = '''
def _sum_ghost_name(mvar):
    return "_sum_" + mvar


def _exposed_mapping(facts, site):
    """The numeric-valued mapping exposed at `site`, if any. This is the state a
    read-only view reads mid-callback; its running sum is the backing invariant."""
    exposed = set(site.write_before_call) | set(site.write_after_call)
    fi = facts.functions.get(site.function)
    if fi is not None:
        exposed |= (set(fi.reads) & set(fi.writes))
    mvars = _mapping_storage_vars(facts)
    for v in sorted(exposed):
        if v in mvars and _is_numeric_type(facts.var_types.get(v, "")):
            return v
    return None


def _instrument_mapping_writes(body, mvar):
    """After each write to mvar[k], update the sum ghost so _sum_mvar stays equal
    to sum_k mvar[k]. Handles `mvar[k] = 0;`, `mvar[k] = e;`, `mvar[k] += e;`,
    `mvar[k] -= e;`. For a plain assignment we cannot know the previous value
    symbolically, so we snapshot it: tmp = mvar[k]; mvar[k] = e; sum += e - tmp.
    """
    g = _sum_ghost_name(mvar)
    out_lines = []
    import re as _re
    idx = 0
    for line in body.splitlines():
        m_pluseq = _re.search(rf"\\b{_re.escape(mvar)}\\s*\\[([^\\]]+)\\]\\s*\\+=\\s*(.+?);", line)
        m_minuseq = _re.search(rf"\\b{_re.escape(mvar)}\\s*\\[([^\\]]+)\\]\\s*-=\\s*(.+?);", line)
        m_assign = _re.search(rf"\\b{_re.escape(mvar)}\\s*\\[([^\\]]+)\\]\\s*=\\s*(.+?);", line)
        if m_pluseq:
            out_lines.append(line)
            out_lines.append(f"        {g} += {m_pluseq.group(2)};")
        elif m_minuseq:
            out_lines.append(line)
            out_lines.append(f"        {g} -= {m_minuseq.group(2)};")
        elif m_assign:
            key = m_assign.group(1)
            rhs = m_assign.group(2)
            tmp = f"__prev{idx}"; idx += 1
            # snapshot old value BEFORE the assignment to update the sum soundly
            out_lines.append(f"        uint256 {tmp} = {mvar}[{key}];")
            out_lines.append(line)
            out_lines.append(f"        {g} = {g} + {rhs} - {tmp};")
        else:
            out_lines.append(line)
    return "\\n".join(out_lines)

'''
    # insert helpers before synthesize_harness
    anchor = "def synthesize_harness("
    s = s.replace(anchor, helpers + "\n" + anchor, 1)

    # --- declare the ghost + instrument phase bodies inside synthesize_harness ---
    # compute the exposed mapping and its ghost right after begin/end bodies built
    decl_anchor = "    uint256 public inFlight;\n    bool    public exposed;"
    decl_new = ("    uint256 public inFlight;\n"
                "    uint256 public {sum_ghost_decl}\n"
                "    bool    public exposed;")
    s = s.replace(decl_anchor, decl_new)

    # we need sum_ghost_decl and instrumented bodies computed before the f-string.
    # Find where begin_body/end_body are finalized and inject computation.
    inj_anchor = "    begin_body = _sanitize_payable(begin_body)\n    end_body = _sanitize_payable(end_body)"
    if inj_anchor not in s:
        # fall back: inject right before the return f-string
        inj_anchor = '    return f"""// SPDX-License-Identifier: MIT'
        inject = '''    _mvar = _exposed_mapping(facts, site)
    if _mvar:
        _sg = _sum_ghost_name(_mvar)
        sum_ghost_decl = f"public {_sg}; // [ghost] sum over {_mvar}"
        begin_body = _instrument_mapping_writes(begin_body, _mvar)
        end_body = _instrument_mapping_writes(end_body, _mvar)
    else:
        sum_ghost_decl = "public __unused_sum; // (no exposed mapping)"

''' + inj_anchor
        s = s.replace(inj_anchor, inject)
    else:
        inject = inj_anchor + '''
    _mvar = _exposed_mapping(facts, site)
    if _mvar:
        _sg = _sum_ghost_name(_mvar)
        sum_ghost_decl = f"public {_sg}; // [ghost] sum over {_mvar}"
        begin_body = _instrument_mapping_writes(begin_body, _mvar)
        end_body = _instrument_mapping_writes(end_body, _mvar)
    else:
        sum_ghost_decl = "public __unused_sum; // (no exposed mapping)"'''
        s = s.replace(inj_anchor, inject)

    open(P, "w").write(s)
    print("patched harness_synth.py: mapping-sum ghost declared + writes instrumented")


def patch_view_check_backing():
    """Make view_check use the mapping-sum backing invariant when the exposed
    state is a mapping: assert _sum_m <= address(this).balance under I_exp."""
    P = "aegis/compiler.py"
    shutil.copy(P, P + ".bak_sumghost")
    s = open(P).read()
    if "_backing_invariant" in s:
        print("compiler backing already present; skip"); return
    # Where OBL_view is emitted, prefer the backing invariant if an exposed
    # mapping exists. We pass a stronger assertion string to view_check via ctx.
    # Minimal change: annotate the ctx's inv_stable for the view when a mapping
    # sum ghost exists.
    old = '''            from .static_analysis import view_closure
            for g in view_closure(facts, plan.phases.function):'''
    new = '''            from .static_analysis import view_closure
            from .harness_synth import _exposed_mapping, _sum_ghost_name
            _site_obj = None
            for _s in facts.exposure_sites:
                if _s.function == plan.phases.function:
                    _site_obj = _s; break
            _mv = _exposed_mapping(facts, _site_obj) if _site_obj else None
            _backing_invariant = (f"{_sum_ghost_name(_mv)} <= address(this).balance"
                                  if _mv else None)
            for g in view_closure(facts, plan.phases.function):'''
    if old not in s:
        raise SystemExit("compiler view_closure anchor missing")
    s = s.replace(old, new)

    # pass the backing invariant into view_check
    old2 = '''                    harness_source=_wrap(_trim_harness(body, {"beginExposed"}),
                                         H, template.view_check(
                                             _ctx, g, "uint256",
                                             param_types=gi.param_types))))'''
    new2 = '''                    harness_source=_wrap(_trim_harness(body, {"beginExposed"}),
                                         H, template.view_check(
                                             _ctx, g, "uint256",
                                             param_types=gi.param_types,
                                             backing=_backing_invariant))))'''
    if old2 not in s:
        raise SystemExit("compiler view_check call anchor missing")
    s = s.replace(old2, new2)
    open(P, "w").write(s)
    print("patched compiler.py: view obligation uses mapping-sum backing invariant")


def patch_template_backing():
    P = "aegis/templates.py"
    shutil.copy(P, P + ".bak_sumghost")
    s = open(P).read()
    if "backing=None" in s:
        print("template backing already present; skip"); return
    old = '''    def view_check(self, c: TemplateCtx, g: str, ret_type: str,
                   param_types=None) -> str:'''
    new = '''    def view_check(self, c: TemplateCtx, g: str, ret_type: str,
                   param_types=None, backing=None) -> str:'''
    s = s.replace(old, new)
    # swap the asserted invariant: if a backing invariant is supplied, assert it
    old_assert = '''        sig = ", ".join(decls)
        call_args = ", ".join(args)
        return f"""
            function check({sig}) public {{
                require(v.{c.flag_name}());
                require({c.q(pred)});           // assume I_exp (mid-callback)
                v.{g}({call_args});              // observe the view now
                assert({c.q(c.inv_stable)});    // view-return consistent with I_stable
            }}"""'''
    new_assert = '''        sig = ", ".join(decls)
        call_args = ", ".join(args)
        safety = c.q(backing) if backing else c.q(c.inv_stable)
        return f"""
            function check({sig}) public {{
                require(v.{c.flag_name}());
                require({c.q(pred)});           // assume I_exp (mid-callback)
                v.{g}({call_args});              // observe the view now
                assert({safety});               // backing invariant holds mid-callback
            }}"""'''
    if old_assert not in s:
        raise SystemExit("template view_check body anchor missing")
    s = s.replace(old_assert, new_assert)
    open(P, "w").write(s)
    print("patched templates.py: view_check asserts backing invariant when present")


patch_harness()
patch_view_check_backing()
patch_template_backing()
print("\nmapping-sum ghost feature applied. Note: c.q() must accept the balance")
print("expression; if it rejects address(this).balance, we handle in next step.")
