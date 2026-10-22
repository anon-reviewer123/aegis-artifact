"""
Gap 1 Slice 2: loop-step harness synthesizer generalized to three shapes.

Given a LoopSite + ContractFacts, recognise the pattern class and instantiate the
matching proven inductive step template. Unrecognised -> None (report unsupported).

Shapes:
  conservation (refund)  : a mapping is written per iteration + value-bearing call.
      Safety: paidForC <= wInit. Ordering (effect vs interaction first) from the
      before/after-call write split.
  mutex (dividend)       : a bool guard flag is written in the function and gated
      (the loop pays from a snapshot). Safety: totalPaid <= poolAtStart. Safe iff
      a guard flag exists and is set around the payout (blocks re-entry).
  progress (griefing)    : the loop records failures (a bool 'failed'-like flag or
      restores state) instead of propagating a revert. Safety: the iteration
      advances regardless of callee failure.
"""
from dataclasses import dataclass


@dataclass
class LoopStepObligation:
    name: str
    harness_source: str
    kind: str
    expect_hint: str


def _types(facts):
    return getattr(facts, "var_types", {}) or {}


def _classify_writes(site, facts):
    vt = _types(facts)
    mapping_var, scalar_var = None, None
    for v in site.loop_body_writes:
        t = (vt.get(v, "") or "").strip()
        if t.startswith("mapping"):
            mapping_var = mapping_var or v
        elif t.startswith(("uint", "int")):
            scalar_var = scalar_var or v
    return mapping_var, scalar_var


def _bool_guard(site, facts):
    """A bool state var written by the loop's function (a mutex/guard candidate)."""
    vt = _types(facts)
    fn = facts.functions.get(site.function)
    if not fn:
        return None
    for v in sorted(fn.writes):
        t = (vt.get(v, "") or "").strip()
        if t.startswith("bool") and "mapping" not in t:
            return v
    return None


def _progress_flag(site, facts):
    """A failure-recording flag written INSIDE the loop body -> progress shape.
    Matches a scalar bool OR a bool-valued mapping (mapping(...=>bool))."""
    vt = _types(facts)
    for v in site.loop_body_writes:
        t = (vt.get(v, "") or "").strip()
        if t.startswith("bool") or (t.startswith("mapping") and t.rstrip().endswith("bool)")):
            return v
    return None


def _conserve_template(site, facts, mapping_var):
    zeroed_before = mapping_var in (site.writes_before_call or [])
    H = f"{facts.contract}StepH"
    if zeroed_before:
        body = '''
        uint256 amt = ownedC;
        ownedC = 0;
        callback();
        paidForC += amt;'''
        hint = "safe"
    else:
        body = '''
        uint256 amt = ownedC;
        callback();
        ownedC = 0;
        paidForC += amt;'''
        hint = "unsafe"
    src = f'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Auto-generated conservation loop-step for {facts.contract}.{site.function} (mapping {mapping_var})
contract {H} {{
    uint256 public ownedC;
    uint256 public paidForC;
    function callback() internal {{
        uint256 cur = ownedC;
        if (cur == 0) return;
        ownedC = 0; paidForC += cur;
    }}
    function check(uint256 w) public {{
        require(w > 0 && w < (1 << 128));
        ownedC = w; paidForC = 0;
        uint256 wInit = w;{body}
        assert(paidForC <= wInit);
    }}
}}
'''
    return src, hint


def _mutex_template(site, facts, guard):
    H = f"{facts.contract}StepH"
    # SAFE iff the function guards with the bool flag. We model the guard: if
    # present, the re-entrant distribute() is blocked; otherwise it re-distributes.
    src = f'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Auto-generated mutex loop-step for {facts.contract}.{site.function} (guard {guard})
contract {H} {{
    uint256 public pool;
    uint256 public totalPaid;
    bool    public {guard};
    function callback() internal {{
        if ({guard}) return;              // guard blocks re-entry
        {guard} = true;
        uint256 snap = pool; totalPaid += snap;
        {guard} = false;
    }}
    function check(uint256 P) public {{
        require(P > 0 && P < (1 << 128));
        pool = P; totalPaid = 0; {guard} = false;
        uint256 poolAtStart = pool;
        require(!{guard});
        {guard} = true;
        uint256 snapshot = pool;
        callback();
        totalPaid += snapshot;
        {guard} = false;
        assert(totalPaid <= poolAtStart);
    }}
}}
'''
    return src, "safe"


def _mutex_template_unguarded(site, facts):
    H = f"{facts.contract}StepH"
    src = f'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Auto-generated mutex loop-step for {facts.contract}.{site.function} (NO guard)
contract {H} {{
    uint256 public pool;
    uint256 public totalPaid;
    function callback() internal {{
        uint256 snap = pool; totalPaid += snap;   // no guard -> re-distributes
    }}
    function check(uint256 P) public {{
        require(P > 0 && P < (1 << 128));
        pool = P; totalPaid = 0;
        uint256 poolAtStart = pool;
        uint256 snapshot = pool;
        callback();
        totalPaid += snapshot;
        assert(totalPaid <= poolAtStart);
    }}
}}
'''
    return src, "unsafe"


def _progress_template(site, facts, flag, handles_failure):
    H = f"{facts.contract}StepH"
    if handles_failure:
        inner = '''        if (calleeFails) { ownedC = amt; failedC = true; }
        advanced = true;'''
        hint = "safe"
    else:
        inner = '''        if (calleeFails) { aborted = true; ownedC = amt; }
        else { advanced = true; }'''
        hint = "unsafe"
    src = f'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Auto-generated progress loop-step for {facts.contract}.{site.function}
contract {H} {{
    uint256 public ownedC;
    bool    public advanced;
    bool    public failedC;
    bool    public aborted;
    function check(uint256 w, bool calleeFails) public {{
        require(w > 0 && w < (1 << 128));
        ownedC = w; advanced = false; failedC = false; aborted = false;
        uint256 amt = ownedC;
        ownedC = 0;
{inner}
        assert(advanced);
    }}
}}
'''
    return src, hint


def synth_loop_step(site, facts):
    mapping_var, scalar_var = _classify_writes(site, facts)
    guard = _bool_guard(site, facts)
    pflag = _progress_flag(site, facts)

    vt = _types(facts)
    # value-bearing conservation mapping = a uint-valued mapping written per iter
    def _is_uint_mapping(v):
        t = (vt.get(v, "") or "").strip()
        return t.startswith("mapping") and not t.rstrip().endswith("bool)")
    uint_map = next((v for v in site.loop_body_writes if _is_uint_mapping(v)), None)

    # 1) PROGRESS: a failure-recording flag (bool or bool-mapping) written in the
    #    loop body is the strongest, most specific signal.
    if pflag is not None:
        src, hint = _progress_template(site, facts, pflag, handles_failure=True)
        return LoopStepObligation(f"OBL_loop_step_{site.function}", src, "progress_loop", hint)

    # 2) CONSERVATION: a uint mapping written per iteration and zeroed around call.
    if uint_map is not None and (
            uint_map in (site.writes_before_call or []) or
            uint_map in (site.writes_after_call or [])):
        src, hint = _conserve_template(site, facts, uint_map)
        return LoopStepObligation(f"OBL_loop_step_{site.function}", src, "conserve_loop", hint)

    # 3) MUTEX: no per-iteration payout mapping, but the function pays from a
    #    snapshot. Safe iff a bool guard flag is written by the function.
    #    (Dividend: loop_body_writes==[]; guard 'distributing' in fn.writes.)
    if not site.loop_body_writes:
        if guard is not None:
            src, hint = _mutex_template(site, facts, guard)
            return LoopStepObligation(f"OBL_loop_step_{site.function}", src, "mutex_loop", hint)
        else:
            src, hint = _mutex_template_unguarded(site, facts)
            return LoopStepObligation(f"OBL_loop_step_{site.function}", src, "mutex_loop", hint)

    return None


if __name__ == "__main__":
    import sys, os
    from aegis.static_analysis import analyze
    f = analyze(sys.argv[1])
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp"
    if not f.loop_sites:
        print("no loop sites"); sys.exit(0)
    for site in f.loop_sites:
        ob = synth_loop_step(site, f)
        if ob is None:
            print(f"{site.function}: unsupported loop shape"); continue
        path = os.path.join(out, f"{f.contract}_{site.function}_step.sol")
        open(path, "w").write(ob.harness_source)
        print(f"{ob.name} [{ob.kind}]: wrote {path} (hint: {ob.expect_hint})")
