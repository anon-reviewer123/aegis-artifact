import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from aegis.static_analysis import ContractFacts, FunctionInfo, ExposureSite
from aegis import coverage, footprint


def _facts():
    """A pool whose window is opened by settle(). price() reads the exposed
    accounting through an internal helper. sync() writes it through a helper.
    tick() touches unrelated storage. probe() makes its own external call."""
    fns = {
        "settle": FunctionInfo("settle", "external",
                               reads={"aum", "tracked"}, writes={"aum", "tracked"},
                               external_calls=[".call"],
                               write_before_call={"tracked"},
                               write_after_call={"aum"}),
        "price": FunctionInfo("price", "public", mutability="view",
                              return_types=["uint256"],
                              internal_calls={"_quote"}),
        "_quote": FunctionInfo("_quote", "internal", mutability="view",
                               reads={"aum", "tracked"}),
        "sync": FunctionInfo("sync", "external", internal_calls={"_bump"}),
        "_bump": FunctionInfo("_bump", "internal", writes={"aum"}),
        "tick": FunctionInfo("tick", "external", reads={"counter"},
                             writes={"counter"}),
        "probe": FunctionInfo("probe", "external", reads={"aum"},
                              external_calls=[".call"]),
    }
    site = ExposureSite("settle", ".call", True, "low-level call",
                        exposed_storage={"aum", "tracked"},
                        write_before_call={"tracked"},
                        write_after_call={"aum"})
    return ContractFacts("Pool", ["aum", "tracked", "counter"], fns, [site])


def test_transitive_sets_close_over_helpers():
    f = _facts()
    assert f.transitive_writes("sync") == {"aum"}, f.transitive_writes("sync")
    assert f.transitive_reads("price") == {"aum", "tracked"}
    assert f.transitive_writes("tick") == {"counter"}


def test_closure_partitions():
    f = _facts()
    s = f.exposure_sites[0]
    writers = f.conservative_closure(s)
    readers = f.observation_closure(s)
    assert "sync" in writers, writers          # writes aum via a helper
    assert "tick" not in writers               # unrelated storage
    assert "price" in readers, readers         # reads aum via a helper
    assert "price" not in writers              # a reader is not a preserver
    assert f.full_closure(s) == writers | readers


def test_recursive_call_graph_terminates():
    f = _facts()
    f.functions["a"] = FunctionInfo("a", "external", writes={"aum"},
                                    internal_calls={"b"})
    f.functions["b"] = FunctionInfo("b", "internal", internal_calls={"a"})
    assert f.transitive_writes("a") == {"aum"}


def test_footprint_premise_rejects_a_writer_in_the_closure():
    f = _facts()
    s = f.exposure_sites[0]
    admitted, verdicts = footprint.admitted_views(f, s, ["price"])
    assert admitted == [], admitted
    v = verdicts[0]
    assert v.writer == "sync", v.reason
    assert "aum" in v.reason


def test_footprint_premise_admits_a_preserving_closure():
    f = _facts()
    # sync no longer touches the observation footprint
    f.functions["_bump"].writes = {"counter"}
    f.functions["probe"].external_calls = []
    s = f.exposure_sites[0]
    admitted, verdicts = footprint.admitted_views(f, s, ["price"])
    assert admitted == ["price"], verdicts[0].reason


def test_footprint_premise_refuses_an_unbounded_view():
    f = _facts()
    f.functions["_bump"].writes = {"counter"}   # closure no longer writes fp
    f.functions["probe"].external_calls = []
    f.functions["_quote"].has_unresolved_call = True   # assembly in the helper
    s = f.exposure_sites[0]
    admitted, verdicts = footprint.admitted_views(f, s, ["price"])
    assert admitted == []
    assert "unbounded" in verdicts[0].reason, verdicts[0].reason


def test_footprint_premise_refuses_an_unbounded_closure_member():
    f = _facts()
    f.functions["probe"].external_calls = []
    f.functions["_bump"].has_unresolved_call = True    # sync stays a writer
    s = f.exposure_sites[0]
    admitted, verdicts = footprint.admitted_views(f, s, ["price"])
    assert admitted == []
    assert verdicts[0].writer == "sync", verdicts[0].reason


def test_nesting_gate_refuses_a_closure_member_that_yields_control():
    f = _facts()
    s = f.exposure_sites[0]
    res = coverage.nesting_gate(f, s)
    assert not res.ok
    assert "probe" in res.reason


def test_nesting_gate_passes_a_flat_closure():
    f = _facts()
    f.functions["probe"].external_calls = []
    s = f.exposure_sites[0]
    assert coverage.nesting_gate(f, s).ok


def test_coverage_gate_names_an_unchecked_second_site():
    f = _facts()
    f.exposure_sites.append(ExposureSite("redeem", ".transfer", True, "transfer",
                                         exposed_storage={"aum"},
                                         write_before_call={"tracked"},
                                         write_after_call={"aum"}))
    res = coverage.coverage_gate(f, f.exposure_sites[0])
    assert not res.ok
    assert "redeem" in res.reason


def test_gates_never_touch_a_refutation():
    f = _facts()
    s = f.exposure_sites[0]
    said = []
    assert coverage.apply_gates(f, s, "BUG_FOUND", said.append) == "BUG_FOUND"
    assert said == []
    assert coverage.apply_gates(f, s, "VERIFIED", said.append) == "UNKNOWN"


def test_view_obligation_is_three_state():
    from aegis.templates import get_template, TemplateCtx
    c = TemplateCtx(q=lambda s: s, inv_exp="", inv_stable="", target="",
                    flag_name="exposed", primary_ghost="inFlight",
                    share_guard="", fresh_state=())
    src = get_template("additive").view_check(c, "price", "uint256")
    assert "r_entry" in src
    assert "r_exposed == r_entry || r_exposed == r_stable" in src


def test_canary_replaces_the_three_state_conclusion():
    from aegis.compiler import _canary_conclusion
    from aegis.templates import get_template, TemplateCtx
    c = TemplateCtx(q=lambda s: s, inv_exp="", inv_stable="", target="",
                    flag_name="exposed", primary_ghost="inFlight",
                    share_guard="", fresh_state=())
    src = get_template("additive").view_check(c, "price", "uint256")
    can = _canary_conclusion(src)
    assert "assert(false);" in can
    assert "r_exposed == r_entry" not in can


def test_no_differential_ablation_keeps_its_two_state_meaning():
    from aegis.templates import get_template, TemplateCtx
    c = TemplateCtx(q=lambda s: s, inv_exp="", inv_stable="", target="",
                    flag_name="exposed", primary_ghost="inFlight",
                    share_guard="", fresh_state=())
    src = get_template("additive").view_check(c, "price", "uint256",
                                              ablate="no-differential")
    assert "assert(r_exposed == r_stable);" in src
    assert "||" not in src




def test_trim_keeps_callees_of_kept_functions():
    from aegis.compiler import _trim_harness
    src = ("contract H {\n"
           "    uint256 public x;\n"
           "    constructor(address a) {}\n"
           "    function depositFor(address w, uint256 a) public { x += a; }\n"
           "    function helper(uint256 a) internal view returns (uint256) { return a + x; }\n"
           "    function deep(uint256 a) internal view returns (uint256) { return helper(a); }\n"
           "    function price() public view returns (uint256) { return deep(x); }\n"
           "    function sibling() public { x = 99; }\n"
           "}")
    out = _trim_harness(src, {"depositFor", "price"})
    for kept in ("price", "deep", "helper", "depositFor"):
        assert f"function {kept}" in out, kept
    assert "function sibling" not in out
    assert "uint256 public x;" in out


def _typed(rt):
    f = _facts()
    f.functions["price"].return_types = rt
    return f


def test_observation_type_resolves_scalars():
    from aegis.footprint import observation_type
    assert observation_type(_typed(["uint256"]), "price") == ("uint256", "")
    assert observation_type(_typed(["bool"]), "price") == ("bool", "")
    assert observation_type(_typed(["uint"]), "price") == ("uint256", "")
    assert observation_type(_typed(["address payable"]), "price") == ("address", "")
    assert observation_type(_typed(["enum Pool.Phase"]), "price") == ("uint256", "")


def test_observation_type_refuses_non_scalars():
    from aegis.footprint import observation_type
    for rt in ([], ["string memory"], ["bytes memory"],
               ["uint256", "uint256"], ["struct Pool.Data memory"]):
        t, why = observation_type(_typed(rt), "price")
        assert t == "", rt
        assert why


def test_view_with_bool_return_is_compiled_at_bool():
    f = _facts()
    f.functions["_bump"].writes = {"counter"}
    f.functions["probe"].external_calls = []
    f.functions["price"].return_types = ["bool"]
    s = f.exposure_sites[0]
    admitted, verdicts = footprint.admitted_views(f, s, ["price"])
    assert admitted == ["price"]
    assert verdicts[0].obs_type == "bool"


def test_view_returning_nothing_is_not_admitted():
    f = _facts()
    f.functions["_bump"].writes = {"counter"}
    f.functions["probe"].external_calls = []
    f.functions["price"].return_types = []
    s = f.exposure_sites[0]
    admitted, verdicts = footprint.admitted_views(f, s, ["price"])
    assert admitted == []
    assert "no value to compare" in verdicts[0].reason


def test_harness_cache_is_keyed_by_fingerprint():
    import os
    import tempfile
    from aegis import pipeline, static_analysis

    src_path = "contracts/corpus/ReadOnlyReentrancy_U01.sol"
    if not os.path.exists(src_path):
        return
    facts = static_analysis.analyze(src_path)
    site = facts.exposure_sites[0]
    csrc = open(src_path).read()
    hc = os.path.join(tempfile.mkdtemp(), "U01.harness.sol")
    quiet = lambda _s: None

    _out, why = pipeline._load_or_synthesize_harness(
        hc, src_path, csrc, facts, site, "reserve == supply", False, quiet)
    assert "wrote" in why
    assert pipeline._FP_PREFIX in open(hc).read()

    _out, why = pipeline._load_or_synthesize_harness(
        hc, src_path, csrc, facts, site, "reserve == supply", False, quiet)
    assert "reusing" in why

    _out, why = pipeline._load_or_synthesize_harness(
        hc, src_path, csrc, facts, site, "reserve == supply", True, quiet)
    assert "wrote" in why


def test_hand_written_harness_is_never_overwritten():
    import os
    import tempfile
    from aegis import pipeline, static_analysis

    src_path = "contracts/corpus/ReadOnlyReentrancy_U01.sol"
    if not os.path.exists(src_path):
        return
    facts = static_analysis.analyze(src_path)
    site = facts.exposure_sites[0]
    hand = os.path.join(tempfile.mkdtemp(), "Hand.harness.sol")
    with open(hand, "w") as fh:
        fh.write("// hand written\ncontract X {}\n")
    before = open(hand).read()
    out, why = pipeline._load_or_synthesize_harness(
        hand, src_path, open(src_path).read(), facts, site, "p", True,
        lambda _s: None)
    assert open(hand).read() == before
    assert out == before
    assert "hand-written" in why


def test_pre_fingerprint_harness_is_treated_as_stale():
    """A harness carrying the synthesizer banner but no fingerprint was
    generated by an older version and must be rebuilt, not mistaken for a
    hand-written one."""
    import os
    import tempfile
    from aegis import harness_synth, pipeline, static_analysis

    src_path = "contracts/corpus/ReadOnlyReentrancy_U01.sol"
    if not os.path.exists(src_path):
        return
    facts = static_analysis.analyze(src_path)
    site = facts.exposure_sites[0]
    csrc = open(src_path).read()
    hc = os.path.join(tempfile.mkdtemp(), "U01.harness.sol")

    old = harness_synth.synthesize_harness(csrc, facts, site,
                                           stable_invariant="reserve == supply")
    assert pipeline._GEN_MARKER in old
    assert pipeline._FP_PREFIX not in old
    with open(hc, "w") as fh:
        fh.write(old)

    _out, why = pipeline._load_or_synthesize_harness(
        hc, src_path, csrc, facts, site, "reserve == supply", False,
        lambda _s: None)
    assert "wrote" in why, why
    assert pipeline._FP_PREFIX in open(hc).read()


class _Res:
    def __init__(self, status, detail=""):
        self.status = status
        self.detail = detail


def test_canary_diagnosis_separates_unreachable_from_undecided():
    from aegis.pipeline import _canary_diagnosis

    fired, why = _canary_diagnosis(_Res("failed", "assertion violation"))
    assert fired and why == ""

    fired, why = _canary_diagnosis(_Res("verified"))
    assert not fired and "unreachable" in why

    fired, why = _canary_diagnosis(
        _Res("unknown", "SMTChecker could not prove (timeout/unsupported)"))
    assert not fired
    assert "decide reachability" in why
    assert "unreachable" not in why

    fired, why = _canary_diagnosis(
        _Res("unknown", "solc compile error: Error: Undeclared identifier."))
    assert not fired and "did not compile" in why


def _guarded():
    """A pool whose window holds inCall, with one guarded writer and one
    unguarded writer of the observation footprint."""
    f = _facts()
    f.exposure_sites[0].window_flags = {"inCall"}
    f.functions["sync"].guard_flags = {"inCall"}
    return f


def test_guard_refinement_drops_a_blocked_writer():
    from aegis import guards
    f = _guarded()
    s = f.exposure_sites[0]
    assert "sync" in f.full_closure(s)
    assert "sync" not in guards.admissible_closure(f, s)
    assert "sync" in guards.explain(f, s)


def test_guard_refinement_keeps_an_unguarded_writer():
    from aegis import guards
    f = _guarded()
    f.functions["sync"].guard_flags = {"someOtherFlag"}
    s = f.exposure_sites[0]
    assert "sync" in guards.admissible_closure(f, s)
    assert guards.explain(f, s) == ""


def test_guard_refinement_needs_the_window_to_hold_the_flag():
    from aegis import guards
    f = _guarded()
    f.exposure_sites[0].window_flags = set()   # flag not held across the call
    s = f.exposure_sites[0]
    assert "sync" in guards.admissible_closure(f, s)


def test_suspended_function_is_excluded_by_default_not_by_guards():
    """blocked_members reports guards on any function, including the one that
    opened the window, because the nesting gate needs that fact. Keeping the
    suspended function out of the premise's closure is the caller's job, via
    include_suspended."""
    from aegis import guards
    f = _guarded()
    f.functions["settle"].guard_flags = {"inCall"}
    s = f.exposure_sites[0]
    assert "settle" in guards.blocked_members(f, s)
    assert "settle" not in guards.admissible_closure(f, s)
    assert "settle" not in guards.admissible_closure(f, s,
                                                     include_suspended=True)


def test_suspended_function_appears_when_unguarded_and_requested():
    from aegis import guards
    f = _guarded()
    f.functions["settle"].guard_flags = set()
    s = f.exposure_sites[0]
    assert "settle" not in guards.admissible_closure(f, s)
    assert "settle" in guards.admissible_closure(f, s, include_suspended=True)


def test_premise_admits_a_view_once_its_writer_is_guarded():
    f = _guarded()
    f.functions["probe"].external_calls = []
    s = f.exposure_sites[0]
    admitted, verdicts = footprint.admitted_views(f, s, ["price"])
    assert admitted == ["price"], verdicts[0].reason


def test_guarded_twins_are_both_admitted():
    """Discrimination has to come from the obligation, not from one member
    being refused: both twins must enter the read-only arm."""
    import os
    from aegis import static_analysis
    from aegis.static_analysis import view_closure
    for name in ("guarded_escrow_safe.sol", "guarded_escrow_unsafe.sol"):
        path = os.path.join("ro_twins_v2", name)
        if not os.path.exists(path):
            return
        f = static_analysis.analyze(path)
        s = f.exposure_sites[0]
        assert s.window_flags == {"inCall"}, s.window_flags
        admitted, verdicts = footprint.admitted_views(
            f, s, view_closure(f, s.function))
        assert admitted, f"{name}: {[v.reason for v in verdicts]}"


def test_guarded_twins_differ_in_where_the_writes_fall():
    import os
    from aegis import static_analysis
    if not os.path.exists("ro_twins_v2/guarded_escrow_safe.sol"):
        return
    safe = static_analysis.analyze(
        "ro_twins_v2/guarded_escrow_safe.sol").exposure_sites[0]
    unsafe = static_analysis.analyze(
        "ro_twins_v2/guarded_escrow_unsafe.sol").exposure_sites[0]
    # the safe member settles the footprint before yielding control
    assert {"openEscrows", "totalEscrowed"} <= safe.write_before_call
    # the unsafe member splits it across the call
    assert "openEscrows" in unsafe.write_before_call
    assert "totalEscrowed" in unsafe.write_after_call


_TWO_WINDOWS = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract TwoWindows {
    uint256 public a; uint256 public b; uint256 public c;
    function pay(address payable x, address payable y) public {
        a -= 1;
        (bool o1,) = x.call{value: 1}("");
        require(o1);
        b -= 1;
        (bool o2,) = y.call{value: 1}("");
        require(o2);
        c -= 1;
    }
}
"""


def _two_window_facts():
    import os
    import tempfile
    from aegis import static_analysis
    path = os.path.join(tempfile.mkdtemp(), "TwoWindows.sol")
    with open(path, "w") as fh:
        fh.write(_TWO_WINDOWS)
    return static_analysis.analyze(path)


def test_two_calls_in_one_function_yield_two_sites():
    facts = _two_window_facts()
    sites = [s for s in facts.exposure_sites if s.function == "pay"]
    assert len(sites) == 2, [(s.call, s.index) for s in sites]
    assert {s.index for s in sites} == {0, 1}


def test_site_phases_stop_at_the_next_callback_boundary():
    facts = _two_window_facts()
    by_index = {s.index: s for s in facts.exposure_sites if s.function == "pay"}
    first, second = by_index[0], by_index[1]
    # the first site's post-phase ends where the second window opens
    assert "b" in first.write_after_call
    assert "c" not in first.write_after_call
    # the second site's pre-phase carries everything settled before it
    assert {"a", "b"} <= second.write_before_call
    assert "c" in second.write_after_call


def test_site_key_distinguishes_calls_in_the_same_function():
    facts = _two_window_facts()
    sites = [s for s in facts.exposure_sites if s.function == "pay"]
    assert len({facts.site_key(s) for s in sites}) == 2


def test_coverage_gate_uses_site_identity_not_just_the_function():
    from aegis import coverage
    facts = _two_window_facts()
    sites = sorted((s for s in facts.exposure_sites if s.function == "pay"),
                   key=lambda s: s.index)
    # both sites have writes on each side, so neither covers the other
    rest = coverage.uncovered_sites(facts, sites[0])
    assert any(facts.site_key(r) == facts.site_key(sites[1]) for r in rest)


def test_site_mode_is_validated():
    from aegis.experiment import ExperimentConfig
    ExperimentConfig(sites="primary")
    ExperimentConfig(sites="all")
    try:
        ExperimentConfig(sites="every")
    except ValueError:
        return
    raise AssertionError("an unknown site mode should be rejected")


def test_site_mode_defaults_to_primary():
    from aegis.experiment import ExperimentConfig
    assert ExperimentConfig().sites == "primary"


def test_decomposing_all_sites_skips_the_coverage_gate():
    """With every site decomposed there is nothing uncovered, so only the
    nesting gate may downgrade a proof."""
    from aegis import coverage
    f = _two_window_facts()
    site = sorted((s for s in f.exposure_sites if s.function == "pay"),
                  key=lambda s: s.index)[0]
    # the coverage gate would refuse, because a second windowed site exists
    assert not coverage.coverage_gate(f, site).ok
    # the nesting gate is what still applies under full decomposition
    assert coverage.nesting_gate(f, site).ok


def test_two_window_fixture_has_two_decomposable_sites():
    """The fixture --sites all is demonstrated on: two calls, each with
    storage written on both sides, so neither post-phase absorbs the other."""
    import os
    from aegis import static_analysis
    path = "contracts/corpus/TwoWindowVault.sol"
    if not os.path.exists(path):
        return
    facts = static_analysis.analyze(path)
    windowed = [s for s in facts.exposure_sites
                if s.write_before_call and s.write_after_call]
    assert len(windowed) == 2, [(s.call, s.index) for s in facts.exposure_sites]
    by_index = {s.index: s for s in windowed}
    assert "feePool" in by_index[0].write_after_call
    assert "totalDeposits" not in by_index[0].write_after_call
    assert "totalDeposits" in by_index[1].write_after_call


def test_a_site_without_a_window_is_not_decomposed():
    """FlashLoanPool has two exposure sites but one window: skim writes only
    before its call, so there is no exposed state and nothing to decompose."""
    import os
    from aegis import static_analysis
    path = "contracts/corpus/FlashLoanPool.sol"
    if not os.path.exists(path):
        return
    facts = static_analysis.analyze(path)
    windowed = [s for s in facts.exposure_sites
                if s.write_before_call and s.write_after_call]
    assert len(facts.exposure_sites) > len(windowed)


def test_stipend_transfer_does_not_count_as_yielding_control():
    from aegis import coverage
    f = _facts()
    s = f.exposure_sites[0]
    f.functions["probe"].external_calls = [".transfer"]
    assert coverage.nesting_gate(f, s).ok
    f.functions["probe"].external_calls = [".send"]
    assert coverage.nesting_gate(f, s).ok


def test_a_full_gas_call_still_counts_as_yielding_control():
    from aegis import coverage
    f = _facts()
    s = f.exposure_sites[0]
    for token in (".call", ".call{value: 1}", ".onFlashLoan"):
        f.functions["probe"].external_calls = [token]
        res = coverage.nesting_gate(f, s)
        assert not res.ok, token
        assert "probe" in res.reason


def test_a_mixed_caller_counts_as_yielding_control():
    """One stipend-capped call does not excuse a full-gas one in the same
    function."""
    from aegis import coverage
    f = _facts()
    s = f.exposure_sites[0]
    f.functions["probe"].external_calls = [".transfer", ".call"]
    assert not coverage.nesting_gate(f, s).ok


def _plan_with_equal_invariants():
    """Minimal stand-in: the validator check under test reads only the
    exposure invariant's two formulas."""
    from types import SimpleNamespace
    return SimpleNamespace(
        exposure_invariant=SimpleNamespace(
            formula="aum == tracked",
            stable_formula="aum == tracked",
            kind="additive"),
        ghost_state=[],
        composition=SimpleNamespace(target_property="aum == tracked"))


def test_equal_invariants_are_accepted_when_nothing_is_written_after_the_call():
    """A site that settles everything before yielding control leaves nothing
    torn, so the stable invariant is the correct exposure invariant. Rejecting
    it forces a ghost whose OBL_pre cannot hold."""
    from aegis import validator
    from aegis.static_analysis import ExposureSite
    plan = _plan_with_equal_invariants()
    f = _facts()
    settled = ExposureSite("settle", ".call", True, "r",
                           exposed_storage={"aum"},
                           write_before_call={"aum", "tracked"},
                           write_after_call=set())
    assert not validator._check_exposure_invariant(plan, f, settled)


def test_equal_invariants_are_still_rejected_when_the_window_is_real():
    from aegis import validator
    plan = _plan_with_equal_invariants()
    f = _facts()
    assert validator._check_exposure_invariant(plan, f, f.exposure_sites[0])


def test_equal_invariants_are_rejected_when_no_site_is_supplied():
    from aegis import validator
    plan = _plan_with_equal_invariants()
    assert validator._check_exposure_invariant(plan, _facts(), None)


def _settled_site():
    from aegis.static_analysis import ExposureSite
    return ExposureSite("settle", ".call", True, "r",
                        exposed_storage={"aum"},
                        write_before_call={"aum", "tracked"},
                        write_after_call=set())


def test_template_shape_is_not_checked_for_a_ghostless_settled_site():
    """With no post-phase and no ghost there is no ghost placement to
    constrain, so a template shape rule must not reject the plan for lacking
    a variable the contract has no use for."""
    from aegis import validator
    plan = _plan_with_equal_invariants()
    plan.exposure_invariant.kind = "conserve"   # a shape that demands a ghost
    assert validator.skip_template_shape(plan, _settled_site())


def test_template_shape_is_still_checked_when_a_ghost_is_declared():
    from aegis import validator
    from types import SimpleNamespace
    plan = _plan_with_equal_invariants()
    plan.ghost_state = [SimpleNamespace(name="inFlight", sol_type="uint256")]
    assert not validator.skip_template_shape(plan, _settled_site())


def test_template_shape_is_still_checked_when_the_window_is_real():
    from aegis import validator
    plan = _plan_with_equal_invariants()
    f = _facts()
    assert not validator.skip_template_shape(plan, f.exposure_sites[0])
    assert not validator.skip_template_shape(plan, None)


def test_degenerate_invariants_are_rejected():
    """`x == x + inFlight` reduces to the ghost being zero; the pre-phase
    obligation is then refuted for the proposer's mistake, not the contract's."""
    from aegis.validator import degenerate_invariant
    assert degenerate_invariant("president_balance == president_balance + inFlight")
    assert degenerate_invariant("a + b == b + a + inFlight")
    assert not degenerate_invariant("aum == trackedValue + inFlight")
    assert not degenerate_invariant("x + inFlight <= y")
    assert not degenerate_invariant("credits == liabilities")


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("PASS", name)
    print("ALL GATE TESTS PASSED")
