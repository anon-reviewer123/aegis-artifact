"""
harness_synth.py - Auto-generate a phase-split harness from a callback-exposed
contract.

This module is what makes the pipeline contract-agnostic. The user supplies
only the .sol file and the target property; harness_synth produces a
<Name>H harness conforming to the documented interface (depositFor,
beginExposed, endExposed, one wrapper per closure callback). The synthesized
harness is then validated by harness_check the same way a user-authored
harness would be -- a malformed synthesis is caught by the same conformance
gate, so this addition does not weaken the soundness story.

Synthesis strategy: locate the exposed function and its callback site, split
its body at that site, transcribe the pre-call writes into beginExposed and
the post-call writes into endExposed, and emit one f(uint256) wrapper per
closure callback. We keep require()s inside callback wrappers because the bug
manifests when a require becomes satisfiable in the exposed phase
(claimYield's require(totalAssets > totalShares) is the canonical case). We
strip require()s from beginExposed/endExposed bodies because the obligation
compiler supplies their preconditions.

The transformation is intentionally source-level rather than AST-level: we
work with the contract's Solidity text. The validator and backend remain the
soundness authority; harness_check rejects any synthesis that does not expose
the documented interface, exactly as it would reject a malformed
user-authored harness.
"""
from __future__ import annotations
import re
from .static_analysis import ContractFacts, ExposureSite


# State variables that are part of the ghost/phase ledger and must not be
# duplicated when transcribing the original contract's storage block.
_GHOST_LEDGER_VARS = {"inFlight", "exposed", "snapPre"}

# State variables we do not transcribe into the harness because they exist
# only to model the adversary in the original contract; the harness models
# the adversary directly through the callback wrappers.
_RECEIVER_VARS = {"receiver"}

# Ledger variables the ANALYSED CONTRACT declares itself. The harness normally
# supplies its own inFlight/exposed bookkeeping and strips the contract's writes
# to avoid double-counting. When the contract declares these as real storage,
# that substitution replaces the contract's accounting with correct accounting,
# so a contract whose defect IS a missing ledger update verifies vacuously. For
# those variables we keep the contract's own writes and emit none of our own.
_CONTRACT_OWNED_LEDGER: set = set()




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


def _ghost_mappings(facts, site, stable_invariant: str = "") -> list:
    """Every mapping whose running sum the harness must track.

    That is the mapping exposed at the site, as before, and every mapping the
    target names through `_sum_<m>`. Only the exposed one used to get a ghost,
    so a target such as `_sum__balances == _totalSupply` over any other mapping
    named a ghost the harness never declared, and the obligation did not
    compile. Only single-level integer mappings can be summed this way.
    """
    out = []
    e = _exposed_mapping(facts, site) if site is not None else None
    if e:
        out.append(e)
    maps = set(_mapping_storage_vars(facts))
    if not facts.var_types:
        # The regex fallback carries no types; read the declarations instead.
        src = _SRC_CACHE.get(facts.contract, "")
        for m in re.finditer(
                r"\bmapping\s*\((?:[^()]|\([^()]*\))*\)\s*"
                r"(?:public\s+|private\s+|internal\s+)*([A-Za-z_]\w*)\s*;", src):
            if m.group(1) in facts.storage_vars:
                maps.add(m.group(1))
    for m in re.findall(r"\b_sum_([A-Za-z_]\w*)", stable_invariant or ""):
        if m in out or m not in maps:
            continue
        t = facts.var_types.get(m, "")
        if facts.var_types and not _is_numeric_type(t):
            continue
        out.append(m)
    return out


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
        _ix = r"\[((?:[^\[\]]|\[[^\[\]]*\])+)\]"
        m_pluseq = _re.search(rf"\b{_re.escape(mvar)}\s*{_ix}\s*\+=\s*(.+?);", line)
        m_minuseq = _re.search(rf"\b{_re.escape(mvar)}\s*{_ix}\s*-=\s*(.+?);", line)
        # `=(?!=)`: a comparison `m[k] == x` in a require is not a write
        m_assign = _re.search(rf"\b{_re.escape(mvar)}\s*{_ix}\s*=(?!=)\s*(.+?);", line)
        m_any = m_pluseq or m_minuseq or m_assign
        if m_any:
            # Snapshot the old value, write, then add the stored new value.
            # Re-evaluating the right-hand side after the write was wrong
            # whenever it read the entry it wrote: `m[k] = m[k] - x` moved the
            # ghost by -2x, and the SafeMath form of every tax-token transfer
            # has exactly that shape.
            key = m_any.group(1)
            tmp = f"__prev{idx}"; idx += 1
            out_lines.append(f"        uint256 {tmp} = {mvar}[{key}];")
            out_lines.append(line)
            out_lines.append(f"        {g} = {g} + {mvar}[{key}] - {tmp};")
        else:
            out_lines.append(line)
    return "\n".join(out_lines)



def _emit_view_functions(contract_src, facts, site):
    """Emit verbatim copies of public/external view functions that read state
    exposed at `site`, so OBL_view_<g> can invoke them on the harness. Views are
    side-effect-free; copying them is sound. Returns a string of full function
    definitions (may be empty)."""
    from .static_analysis import view_closure
    views = view_closure(facts, site.function)
    out = []
    for g in views:
        # Only a definition with a body: `[^{;]*` stops at the `;` of an
        # interface declaration, which `[^{]*` ran past into the next brace in
        # the file, copying the rest of the interface into the harness. The
        # last definition is the most-derived one in a flattened file.
        ms = list(re.finditer(
            rf"\bfunction\s+{re.escape(g)}\s*\([^)]*\)[^{{;]*{{",
            contract_src))
        if not ms:
            continue
        m = ms[-1]
        start = m.start()
        depth, i = 0, m.end() - 1
        while i < len(contract_src):
            if contract_src[i] == "{":
                depth += 1
            elif contract_src[i] == "}":
                depth -= 1
                if depth == 0:
                    i += 1
                    break
            i += 1
        fn_src = contract_src[start:i]
        # views may be declared `override`; strip override/virtual for the harness
        fn_src = re.sub(r"\b(override|virtual)\b", "", fn_src)
        # A modifier the harness does not carry -- `get_balance() public
        # onlyOwner view` -- stops the view harness compiling, and the view
        # was reported UNKNOWN with its canary never firing. The modifier
        # guards who may call it, which the read-only obligation does not
        # depend on: it compares the value a view returns across states.
        _hdr_end = fn_src.index("{")
        _hdr, _rest = fn_src[:_hdr_end], fn_src[_hdr_end:]
        for _mod in re.findall(r"(?<![\w.])([A-Za-z_]\w*)\s*(?:\([^)]*\))?\s*(?=\b(?:public|external|internal|private|view|pure|payable|returns|\{))",
                               _hdr.split(")", 1)[-1]):
            if _mod not in ("public", "external", "internal", "private",
                            "view", "pure", "payable", "returns", "memory",
                            "storage", "calldata"):
                _hdr = re.sub(rf"(?<![\w.]){re.escape(_mod)}\s*(\([^)]*\))?\s*",
                              "", _hdr, count=1)
        fn_src = _hdr + _rest
        out.append("    " + fn_src.strip())
    return "\n".join(out)



def _promote_cross_phase_locals(begin_body, end_body):
    """Locals declared in the PRE phase but used in the POST phase must survive
    across the (separate) beginExposed/endExposed functions. Promote them to
    harness storage: keep the PRE-phase assignment (rewritten to assign the
    field, not declare a local), drop the type in the POST usage, and return the
    field declarations. Sound: the field holds exactly the PRE-phase value."""
    # names declared with a type in the PRE body: `uint256 payment = ...;`
    pre_decls = {}
    for m in re.finditer(r"\b((?:uint256|uint|int256|int|address|bool|bytes32)\s+)"
                         r"([A-Za-z_]\w*)\s*=", begin_body):
        pre_decls[m.group(2)] = m.group(1).strip()
    if not pre_decls:
        return begin_body, end_body, ""
    # which of those are referenced in the POST body?
    post_ids = set(re.findall(r"[A-Za-z_]\w*", end_body))
    crossed = {n: t for n, t in pre_decls.items() if n in post_ids}
    # exclude names the POST body itself re-declares (already in scope there)
    for m in re.finditer(r"\b(?:uint256|uint|int256|int|address|bool|bytes32)\s+"
                         r"([A-Za-z_]\w*)\s*=", end_body):
        crossed.pop(m.group(1), None)
    if not crossed:
        return begin_body, end_body, ""
    # rewrite PRE: `uint256 payment = X;` -> `payment = X;` (assign the field)
    for n, t in crossed.items():
        begin_body = re.sub(rf"\b{re.escape(t)}\s+{re.escape(n)}\s*=",
                            f"{n} =", begin_body)
    # What each promoted field was read FROM, when that is a state expression.
    # The post-phase settles with the captured value, so restoring the stable
    # invariant needs the state it came from to be unchanged -- KatRoyalties
    # zeroes `balances[msg.sender]` and subtracts the captured `amt`, which
    # only balances out while the two are still equal. The exposure invariant
    # has to be able to say so; recorded here for the plan to pick up.
    captures = []
    for n in sorted(crossed):
        m = re.search(rf"(?<![\w.]){re.escape(n)}\s*=\s*([^;]+);", begin_body)
        if not m:
            continue
        expr = m.group(1).strip()
        if re.fullmatch(r"[A-Za-z_]\w*(\s*\[[^\]]+\])*", expr) and expr != n:
            captures.append(f"    // [capture] {n} == {expr}")
    decls = "\n".join(f"    {t} public {n};   // [cross-phase] PRE local used in POST"
                       for n, t in sorted(crossed.items()))
    if captures:
        decls = decls + "\n" + "\n".join(captures)
    return begin_body, end_body, decls


def synthesize_harness(contract_src: str, facts: ContractFacts,
                       site: ExposureSite,
                       stable_invariant: str = "") -> str:
    """Return a phase-split harness contract for the given exposure site.

    The harness contract is named <OriginalName>H and exposes the documented
    interface (beginExposed/endExposed/depositFor + one wrapper per closure
    callback)."""
    # Normalise line endings first. Mainnet sources arrive with CRLF as often
    # as not, and a stray `\r` before a newline throws off every pattern that
    # anchors on a line end.
    contract_src = contract_src.replace("\r\n", "\n").replace("\r", "\n")
    _CARRIED_TYPES.clear()
    _ARG_VARS.clear()
    _CARRIED_TYPES.update(re.findall(r"\b(?:struct|enum)\s+([A-Za-z_]\w*)",
                                     contract_src))
    name = facts.contract
    _SRC_CACHE[name] = contract_src
    _INTERNAL_FNS.clear()
    _INTERNAL_FNS.update(re.findall(r"\bfunction\s+([A-Za-z_]\w*)\s*\([^)]*\)[^{;]*\{",
                                    contract_src))
    _CALLED_HELPERS.clear()
    _FN_ARITIES.clear()
    for _fm in re.finditer(r"\bfunction\s+([A-Za-z_]\w*)\s*\(([^)]*)\)[^{;]*\{",
                           contract_src):
        _FN_ARITIES.setdefault(_fm.group(1), set()).add(
            len([p for p in _fm.group(2).split(",") if p.strip()]))
    pragma = _best_pragma(contract_src) or "pragma solidity >=0.8.0;"
    _type_defs, _defined_types = _collect_type_defs(contract_src)
    _CONTRACT_OWNED_LEDGER.clear()
    _CONTRACT_OWNED_LEDGER.update(
        set(facts.storage_vars) & (_GHOST_LEDGER_VARS - {"snapPre"}))
    storage_decls = _harness_state_block(contract_src, facts)
    _OMITTED_NOW.clear()
    _OMITTED_NOW.update(_UNREPRESENTABLE_VARS.get(name, set()))
    _STORAGE_NOW.clear()
    _STORAGE_NOW.update(facts.storage_vars)
    deposit_for = _emit_deposit_for(facts, stable_invariant)
    begin_body = _phase_body(contract_src, site, "pre").replace("msg.value", "amount")
    end_body = _phase_body(contract_src, site, "post").replace("msg.value", "amount")
    # The phase bodies inline the EXPOSED function's body, which references that
    # function's own parameter names (e.g. issue(address to, uint256 amt) uses
    # `to`/`amt`). Bind them to the harness's uniform `amount` param, exactly as
    # the closure wrappers do, so the inlined code compiles.
    _bf = _BRANCH_FIELDS.get(f"{site.function}:{getattr(site, 'index', 0)}") or []
    _branch_decls = "\n".join(
        f"    bool public {f};   // [phase] branch taken before the call"
        for f in _bf)
    _exp_bindings = _param_bindings(contract_src, site.function)
    if _exp_bindings:
        begin_body = _exp_bindings + begin_body
        end_body = _exp_bindings + end_body
    callback_stubs = _emit_callback_wrappers(contract_src, facts, site)
    view_funcs = _emit_view_functions(contract_src, facts, site)
    # the internal helpers the phase bodies, wrappers and views call, copied
    # in once everything that can call one has been built
    callback_stubs = callback_stubs + _emit_helpers(contract_src)
    # closure members run atomically in the depth-one model
    callback_stubs = _atomize_external_calls(callback_stubs)
    begin_body = _normalize_unknown_types(begin_body, _defined_types)
    end_body = _normalize_unknown_types(end_body, _defined_types)
    callback_stubs = _normalize_unknown_types(callback_stubs, _defined_types)
    view_funcs = _normalize_unknown_types(view_funcs, _defined_types)
    begin_body = _add_local_data_locations(begin_body, _defined_types)
    end_body = _add_local_data_locations(end_body, _defined_types)
    callback_stubs = _add_local_data_locations(callback_stubs, _defined_types)
    view_funcs = _add_local_data_locations(view_funcs, _defined_types)
    begin_body = _drop_assembly(begin_body)
    end_body = _drop_assembly(end_body)
    # A local named like one of the harness's own parameters is renamed first.
    # KatRoyalties reads `uint256 amount = balances[msg.sender];`, and that
    # name collides with the driver's `amount`: the local was excluded from
    # promotion, the post-phase settled with the parameter instead of the
    # value the pre-phase read, no capture was recorded, and the moved-amount
    # constraint degenerated to `amount == amount`.
    _renamed_locals = {}
    for _p in ("amount", "who"):
        _decl = re.compile(rf"\b([A-Za-z_]\w*(?:\s+(?:memory|storage|calldata))?)"
                           rf"\s+{_p}\s*=")
        if _decl.search(begin_body) or _decl.search(end_body):
            _new = f"{_p}_pre"
            begin_body = _decl.sub(rf"\1 {_new} =", begin_body)
            _word = re.compile(rf"(?<![\w.]){_p}(?![\w])")
            # only occurrences after the declaration belong to the local; the
            # pre-phase declares it, so every later use in both bodies is it
            _at = begin_body.index(_new)
            begin_body = begin_body[:_at] + _word.sub(_new, begin_body[_at:])
            end_body = _word.sub(_new, end_body)
            _renamed_locals[_p] = _new

    # Locals the pre-phase declares and the post-phase reads become harness
    # fields FIRST, while the bodies are still bodies. Isolating the returns
    # beforehand moved each body into its own function, so promotion saw only
    # the calls left behind and promoted nothing -- and a local declared in
    # __preBody was then invisible in __postBody, which referred to a name
    # that did not exist (WAsgard's `balance`).
    begin_body, end_body, _xphase_decls = _promote_cross_phase_locals(
        begin_body, end_body)
    begin_body, _pre_helper = _isolate_returns(begin_body, "__preBody")
    end_body, _post_helper = _isolate_returns(end_body, "__postBody")
    callback_stubs = callback_stubs + _pre_helper + _post_helper
    callback_stubs = _drop_assembly(callback_stubs)
    view_funcs = _drop_assembly(view_funcs)

    # Resolve identifiers the inlined bodies reference but the harness does not
    # declare (cross-phase locals, helper calls, immutables/constants). Each
    # becomes a symbolic harness state variable; no-arg helper calls are
    # rewritten to those reads. This makes the harness self-contained and
    # compilable while soundly over-approximating the unmodeled values.
    _omitted = _UNREPRESENTABLE_VARS.get(name, set())
    _known = (set(facts.storage_vars) - _omitted) | {"inFlight", "exposed", "snapPre", "amount", "who"}
    # Type names are not variables. `Sale memory sale = ...` made the resolver
    # declare `uint256 public Sale;` beside the struct of that name, and the
    # harness then had the identifier twice and would not compile.
    _known |= set(re.findall(
        r"\b(?:struct|enum|contract|library|interface)\s+([A-Za-z_]\w*)",
        contract_src))
    import re as _re_xp
    _xphase_names = set(_re_xp.findall(r"public (\w+);", _xphase_decls))
    _known = _known | _xphase_names | set(_bf) | {n for n, _t in _ARG_VARS.values()}
    _extra_decls, (begin_body, end_body, callback_stubs, view_funcs) = _resolve_unbound(
        [begin_body, end_body, callback_stubs, view_funcs], _known, _omitted,
        src=contract_src)
    if _extra_decls:
        storage_decls = storage_decls + "\n" + _extra_decls
    if _branch_decls:
        storage_decls = storage_decls + "\n" + _branch_decls

    # Same-variable conservation: if the exposed site writes one numeric
    # variable both before and after the callback, snapshot it at entry so the
    # stub can target `v == snapPre` with invariant `v == snapPre + inFlight`.
    def _num(v):
        # A variable missing from the type map is not assumed to be an integer:
        # defaulting it to uint256 is how address and array storage ended up
        # in arithmetic. Only the regex fallback, which has no type map at all,
        # keeps the old permissive behaviour.
        if facts.var_types:
            return _is_numeric_type(facts.var_types.get(v, ""))
        return True
    def _scalar(v):
        return _num(v) and not (facts.var_types.get(v, "") or "").startswith("mapping")
    _snap_var = ""
    for _s in [site]:
        # a snapshot copies one value; a mapping cannot be copied that way
        _after = [v for v in _s.write_after_call if _scalar(v)]
        _before = [v for v in _s.write_before_call if _scalar(v)]
        _cross = [(a, b) for a in _before for b in _after if a != b]
        if _after and not _cross:
            _snap_var = _after[0]
            break
    snap_stmt = ("        snapPre = %s;\n" % _snap_var) if _snap_var else ""

    _gmaps = _ghost_mappings(facts, site, stable_invariant)
    if _gmaps:
        sum_ghost_decl = f"public {_sum_ghost_name(_gmaps[0])};"
        sum_ghost_line = "".join(
            f"    uint256 public {_sum_ghost_name(m)}; // [ghost] sum over {m}\n"
            for m in _gmaps)
        xphase_line = (_xphase_decls + "\n") if _xphase_decls else ""
        for _m in _gmaps:
            begin_body = _instrument_mapping_writes(begin_body, _m)
            end_body = _instrument_mapping_writes(end_body, _m)
            # A callback that writes the mapping must move its sum too. The
            # wrappers were never instrumented, so a callback left the ghost
            # stale and an obligation over the sum checked a wrong total.
            callback_stubs = _instrument_mapping_writes(callback_stubs, _m)
    else:
        sum_ghost_decl = "public __unused_sum;"
        sum_ghost_line = ""
        xphase_line = (_xphase_decls + "\n") if _xphase_decls else ""

    exposed_decl = ("" if "exposed" in _CONTRACT_OWNED_LEDGER
                    else "    bool    public exposed;")
    inflight_decl = ("" if "inFlight" in _CONTRACT_OWNED_LEDGER
                     else "    uint256 public inFlight;\n")
    _begin_ledger, _end_ledger = "", ""
    if "inFlight" not in _CONTRACT_OWNED_LEDGER:
        _begin_ledger += "        inFlight += amount;\n"
        _end_ledger += "        inFlight -= amount;\n"
    if "exposed" not in _CONTRACT_OWNED_LEDGER:
        _begin_ledger += "        exposed   = true;\n"
        _end_ledger += "        exposed   = false;\n"
    # Tie the driver's `amount` to the quantity the contract actually hands
    # over, when the call names it. This removes executions the contract
    # cannot perform rather than adding any: without it, OBL_pre was refuted
    # on states where `amount` bore no relation to what the pre-phase moved.
    _moved = _moved_value_expr(contract_src, site)
    # the call's value may name a local the rename above moved aside
    if _moved in _renamed_locals:
        _moved = _renamed_locals[_moved]
    # The harness models the ether amount with its own `amount` parameter and
    # rewrites msg.value to it, so a call sending msg.value hands over exactly
    # `amount` and needs no constraint -- and emitting one put msg.value in a
    # non-payable function, which does not compile.
    if _moved:
        _moved = _moved.replace("msg.value", "amount").strip()
    if _moved and _moved != "amount":
        _ids = set(re.findall(r"\b[A-Za-z_]\w*\b", _moved))
        _allowed = _known | {"amount", "msg", "sender", "value", "address",
                             "this", "balance", "uint256", "uint160"}
        if _ids <= _allowed:
            begin_body = (begin_body + f"\n        require(amount == {_moved}, "
                          f"\"amount is what the call hands over\");")
        else:
            _unknown = sorted(_ids - _allowed)
            begin_body = (begin_body + f"\n        // in-flight amount is "
                          f"{_moved} (not constrained: {_unknown} not in the "
                          f"harness)")

    begin_ledger, end_ledger = _begin_ledger, _end_ledger

    _site_call = re.sub(r"\s+", " ", str(getattr(site, "call", "") or "")).strip()
    _site_reason = re.sub(r"\s+", " ",
                          str(getattr(site, "reason", "") or "")).strip()

    storage_decls = storage_decls + _config_havoc(storage_decls, facts)
    storage_decls = storage_decls + _argument_state()

    return f"""// SPDX-License-Identifier: MIT
{pragma}
/// Auto-generated phase-split harness for {name}.
/// Generated by aegis.harness_synth from exposure site:
///   function {site.function} -> {_site_call}  ({_site_reason})
contract {name}H {{
{_type_defs}{storage_decls}
{inflight_decl}{sum_ghost_line}{xphase_line}    uint256 public snapPre; // [ghost] entry snapshot for same-variable conservation
{exposed_decl}

    /// Constructor takes an address for interface uniformity with the
    /// obligation compiler, which instantiates every harness as
    /// `new {name}H(address(this))`. The address is ignored: this harness
    /// models the adversary through its callback wrappers, not through a
    /// stored receiver field.
    constructor(address /*receiver*/) {{}}

{deposit_for}

    /// PRE phase of {site.function}: establishes the exposure invariant.
    function beginExposed(uint256 amount) public {{
{snap_stmt}{begin_body}
{begin_ledger}    }}

    /// POST phase of {site.function}: restores the stable invariant.
    function endExposed(uint256 amount) public {{
        require(exposed && inFlight == amount, "phase mismatch");
{end_body}
{end_ledger}    }}

{callback_stubs}
{view_funcs}
}}
"""


def _strip_ledger_writes(stmt_line: str) -> str:
    """Remove assignments to the ghost-ledger vars (inFlight, exposed) from a
    line that may hold several `;`-separated statements, keeping everything
    else. Returns the survivors.

    Splitting is done at top level only, and a piece ending in a brace is not
    terminated with `;`. Splitting on every `;` tore block statements apart:
    `if (c) { x -= a; }` became `if (c) { x -= a` and `}`, rejoined as
    `if (c) { x -= a; };`, and Solidity has no empty statement, so every phase
    body containing an `if` block failed to compile with "Expected primary
    expression".
    """
    pieces, buf, depth = [], [], 0
    for ch in stmt_line:
        if ch in "{([":
            depth += 1
        elif ch in "})]":
            depth -= 1
        if ch == ";" and depth <= 0:
            pieces.append("".join(buf))
            buf = []
            continue
        buf.append(ch)
    if "".join(buf).strip():
        pieces.append("".join(buf))

    survivors = []
    for piece in pieces:
        s = piece.strip()
        if not s:
            continue
        is_ledger = False
        for gv in _GHOST_LEDGER_VARS:
            if gv in _CONTRACT_OWNED_LEDGER:
                continue
            if re.match(rf"{re.escape(gv)}\b\s*(\+=|-=|=)", s):
                is_ledger = True
                break
        if not is_ledger:
            survivors.append(s if s.endswith(("}", "{")) else s + ";")
    return " ".join(survivors)


def _best_pragma(src: str) -> str:
    """Pragma for the generated harness.

    Only the LOWER bound of each version range counts. A source writing
    `pragma solidity >=0.8.0 <0.9.0;` names 0.9.0 as an exclusive upper bound,
    and treating it as a floor produces a harness no released compiler can
    satisfy, so resolution falls back to whatever `solc` happens to be and the
    version check fails. The harness itself is generated 0.8 code, so a floor
    at the highest declared lower bound is all it needs.
    """
    floors = []
    for m in re.finditer(r"pragma\s+solidity\s+([^;]+);", src):
        spec = m.group(1)
        # drop upper-bound clauses: `<0.9.0`, `<=0.8.20`
        spec = re.sub(r"<=?\s*\d+\.\d+(\.\d+)?", " ", spec)
        for n in re.findall(r"(\d+)\.(\d+)\.?(\d+)?", spec):
            floors.append(tuple(int(x or 0) for x in n))
    if not floors:
        return ""
    top = max(floors)
    if top < (0, 8, 0):
        top = (0, 8, 0)
    cap = _highest_installed_solc()
    if cap and top > cap:
        top = cap
    return "pragma solidity >=%d.%d.%d;" % top


def _highest_installed_solc():
    """Highest solc build actually available, or None.

    Emitting a floor above every installed compiler leaves resolution with no
    candidate, so it falls back to whatever `solc` resolves to and the version
    check fails on a harness that would otherwise be fine.
    """
    best = None
    try:
        from .ast_analysis import _solc_artifacts_dirs
        dirs = _solc_artifacts_dirs()
    except Exception:
        return None
    for art in dirs:
        try:
            entries = os.listdir(art)
        except Exception:
            continue
        for e in entries:
            m = re.fullmatch(r"solc-(\d+)\.(\d+)\.(\d+)", e)
            if not m:
                continue
            if not os.path.isfile(os.path.join(art, e, e)):
                continue
            v = tuple(int(x) for x in m.groups())
            if best is None or v > best:
                best = v
    return best


def _extract_pragma(src: str) -> str | None:
    m = re.search(r"pragma\s+solidity[^;]*;", src)
    return m.group(0) if m else None


def _infer_type_from_source(var: str, src: str) -> str:
    """Best-effort type inference from the contract source declaration, used on
    the regex-analyzer path where the AST type map is empty. Returns "" if no
    declaration is found."""
    if not src:
        return ""
    mm = re.search(rf"(mapping\s*\([^;{{}}]*?\))\s+(?:public|private|internal)?\s*{re.escape(var)}\b", src)
    if mm:
        return re.sub(r"\s+", " ", mm.group(1))
    m = re.search(rf"\b(bool|address)\b[^;=\n]*\b{re.escape(var)}\b\s*[;=]", src)
    if m:
        return m.group(1)
    m = re.search(rf"\b(u?int\d*)\b[^;=\n]*\b{re.escape(var)}\b\s*[;=]", src)
    if m:
        return m.group(1)
    return ""


_LOC_SUFFIX = re.compile(
    r"\s+(storage(\s+(ref|pointer))?|memory|calldata|payable)\b")


def _strip_loc(t: str) -> str:
    prev = None
    while prev != t:
        prev = t
        t = _LOC_SUFFIX.sub("", t).strip()
    return t


def _scalar_harness_type(t: str):
    """Map one non-mapping type to a declaration valid inside the harness.
    Returns None only for types that cannot be declared standalone (structs and
    function types); every other type is declared unconstrained, which is a
    sound over-approximation because an unconstrained variable is havoced."""
    t = _strip_loc(t)
    if not t:
        return None
    m = re.match(r"^(.*)\[(\d*)\]$", t)
    if m:
        base = _scalar_harness_type(m.group(1))
        if base is None:
            base = "uint256"
        return "%s[%s]" % (base, m.group(2))
    if re.match(r"^u?int\d*$", t):
        return t
    if t == "bool":
        return "bool"
    if t == "address" or t.startswith("address") \
            or t.startswith("contract ") or t.startswith("interface "):
        return "address"
    if t == "string":
        return "string"
    if t == "bytes":
        return "bytes"
    if re.match(r"^bytes([1-9]|[12]\d|3[0-2])$", t):
        return t
    if t.startswith("enum "):
        return "uint256"
    if t.startswith("struct "):
        bare = t[len("struct "):].split(".")[-1].strip()
        # a struct whose definition the harness carries is declared as it is
        return bare if bare in _CARRIED_TYPES else None
    if t.startswith("function "):
        return None
    return None


def _split_mapping(t: str):
    """Split `mapping(K => V)` at the top-level arrow, tolerating nesting."""
    inner = t[t.find("(") + 1:t.rfind(")")]
    depth = 0
    for i in range(len(inner) - 1):
        c = inner[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif depth == 0 and inner[i:i + 2] == "=>":
            return inner[:i].strip(), inner[i + 2:].strip()
    return None, None


# Struct and enum names the harness carries, so a mapping to one keeps its
# value type instead of being flattened to uint256. `mapping(address => Sale)`
# declared as `mapping(address => uint256)` made `Sale memory s = sales[a];` a
# type error (SimpleSalesEth) and `tax_on[d].president` a member lookup on a
# uint256 (DLAND).
_CARRIED_TYPES: set = set()


def _mapping_harness_type(t: str):
    key, val = _split_mapping(t)
    if key is None:
        return None
    k = _scalar_harness_type(key)
    if k is None or k == "string" or k.endswith("]"):
        return None
    val = _strip_loc(val)
    if val.startswith("mapping("):
        v = _mapping_harness_type(val)
    else:
        v = _scalar_harness_type(val)
        if v is None:
            # solc writes a user-defined value type as `struct S.Sale` or
            # `enum S.Kind` -- keyword plus the declaring contract. Matching a
            # bare name missed it and the value fell back to uint256, which is
            # why `Sale memory s = sales[a][i];` would not compile.
            bare = re.sub(r"^\s*(?:struct|enum|contract)\s+", "", val).strip()
            bare = bare.split(".")[-1].split("[")[0].strip()
            if bare in _CARRIED_TYPES:
                v = bare
    if v is None:
        v = "uint256"
    return "mapping(%s => %s)" % (k, v)


def _harness_type(tstr: str, var: str, src: str):
    """Map a storage variable to a declaration type valid INSIDE the isolated
    harness contract. Returns None only when no standalone declaration exists
    (structs, function types, mappings with an unrepresentable key).

    Types the solver models poorly are still declared. Omitting them leaves the
    inlined body referencing an undeclared name, which fails to compile; leaving
    them unconstrained is sound, since a havoced variable admits every value the
    original could hold.
    """
    t = (tstr or "").strip()
    if not t:
        t = _infer_type_from_source(var, src).strip()
    if not t:
        return "uint256"
    t = _strip_loc(t)
    if t.startswith("mapping("):
        return _mapping_harness_type(t)
    return _scalar_harness_type(t)


def _harness_state_block(src: str, facts: ContractFacts) -> str:
    """Return the storage declarations needed in the harness: every storage
    variable from the original contract, with `public` visibility so getters
    are auto-generated. We skip ghost-ledger variables (inFlight, exposed --
    added separately) and receiver-style variables (the harness models the
    adversary through callback wrappers, not through an address field)."""
    # Ledger variables the contract declares itself stay in the state block:
    # the harness no longer supplies bookkeeping for them, so skipping them here
    # would leave them undeclared and resolved as unconstrained symbols.
    skip = ((_GHOST_LEDGER_VARS - _CONTRACT_OWNED_LEDGER) | _RECEIVER_VARS
            | _NEVER_DECLARE)
    lines = []
    # Declare from the analyzer's storage map (authoritative and complete),
    # not by regex-scraping the source: source declarations may carry inline
    # initializers (`uint256 public reserve = 1000;`) or pack several vars on
    # one line, both of which a terminator-anchored regex misses, leaving the
    # var referenced-but-undeclared in the harness.
    src = _SRC_CACHE.get(facts.contract) or src
    skipped = []
    # Emit in a deterministic, solver-friendly order rather than the analyzer's
    # raw alphabetical order. CHC convergence is sensitive to storage-variable
    # ordering in the inductive invariant search; a reserve-style scalar landing
    # first (e.g. `balance` sorting before the mapping `owed`) can make an
    # otherwise-provable obligation time out. Mappings first, then scalars,
    # keeps the layout uniform across contracts regardless of variable names and
    # removes this name-dependent source of UNKNOWNs.
    def _order_key(v):
        tstr = facts.var_types.get(v, "") if facts.var_types else ""
        is_mapping = "mapping" in tstr or v in _mapping_storage_vars(facts)
        return (0 if is_mapping else 1, v)
    ordered_vars = sorted((v for v in facts.storage_vars if v not in skip),
                          key=_order_key)
    for var in ordered_vars:
        tstr = facts.var_types.get(var, "") if facts.var_types else ""
        ty = _harness_type(tstr, var, src)
        if ty is None:
            skipped.append(var)
            continue
        vis = "internal" if ty in _CARRIED_TYPES else "public"
        lines.append(f"    {ty} {vis} {var};")
    if skipped:
        lines.append("    // unrepresentable storage omitted: " + ", ".join(skipped))
    _UNREPRESENTABLE_VARS[facts.contract] = set(skipped)
    return "\n".join(lines) if lines else "    // (no public storage vars)"


def _conservation_seed_vars(stable_invariant, numeric_vars, skip):
    """If the stable invariant has conservation shape `A + B + ... == C` (a sum
    of >=2 distinct terms equals a single term), return a seed set that credits
    exactly ONE left-hand term plus the right-hand total, so the invariant holds
    after depositFor (the other left terms stay 0). Returns None if the invariant
    is not conservation-shaped (e.g. plain `A == B`), so the caller falls back to
    crediting all numeric vars."""
    import re as _re
    inv = stable_invariant.strip()
    # split on the top-level == ; tolerate >= for eth-model style but only handle ==
    if "==" not in inv:
        return None
    lhs, rhs = inv.split("==", 1)
    lhs, rhs = lhs.strip(), rhs.strip()
    # left must be a sum of >= 2 identifiers; right a single identifier
    lhs_terms = [t.strip() for t in lhs.split("+")]
    ident = _re.compile(r"^[A-Za-z_]\w*$")
    if len(lhs_terms) < 2 or not all(ident.match(t) for t in lhs_terms):
        return None
    if not ident.match(rhs):
        return None
    total = rhs
    # pick the first left term that is a numeric, seedable var
    first_term = next((t for t in lhs_terms
                       if t in numeric_vars and t not in skip), None)
    if first_term is None or total not in numeric_vars or total in skip:
        return None
    return {first_term, total}


def _emit_deposit_for(facts: ContractFacts, stable_invariant: str = "") -> str:
    """Emit a depositFor(who, amount) that seeds feasible accounting state.

    Contract-agnostic: instead of hardcoding shares/totalShares/totalAssets, we
    derive the seeding from the contract's actual deposit-style function. We
    find a public function that writes the accounting storage vars and mirror
    its '+=' updates, so the seeding preserves whatever stable invariant the
    contract maintains. Falls back to incrementing every non-ghost scalar/
    mapping storage var by `amount` (which preserves any '==' accounting
    invariant of the form sum(A)==sum(B))."""
    skip = _GHOST_LEDGER_VARS | _RECEIVER_VARS
    # prefer mirroring an existing deposit-like function's writes
    deposit_fn = None
    for name, fn in facts.functions.items():
        if fn.visibility in ("public", "external") and fn.writes and \
                ("deposit" in name.lower() or "mint" in name.lower() or
                 "provide" in name.lower() or "stake" in name.lower()):
            deposit_fn = fn
            break

    # only seed NUMERIC accounting vars: address/bool storage must never get
    # `+= amount`. We detect type from the contract source declarations.
    numeric_vars = _numeric_storage_vars(facts)
    mapping_vars = _mapping_storage_vars(facts)

    lines = []
    # Seed a state that SATISFIES the stable invariant. The correct seed depends
    # on the invariant's structure, which is passed in via `stable_invariant`:
    #   * conservation A + B == C (e.g. cash + loans == totalAssets): credit only
    #     ONE additive term and the total (cash += amount; totalAssets += amount),
    #     leaving the other terms 0, so A+B == C holds.
    #   * equality A == B (e.g. aum == trackedValue), or no invariant given:
    #     credit ALL numeric vars so both sides move together.
    seed_vars = _conservation_seed_vars(stable_invariant, numeric_vars, skip) \
        if stable_invariant else None
    if seed_vars is None:
        seed_vars = {v for v in facts.storage_vars
                     if v in numeric_vars and v not in skip}
    _ghost_maps = set(_ghost_mappings(
        facts, facts.exposure_sites[0] if facts.exposure_sites else None,
        stable_invariant))
    for v in sorted(seed_vars):
        if v in skip or v not in numeric_vars:
            continue
        line = _seed_line(v, facts.var_types.get(v, ""), v in mapping_vars)
        if line is None:
            continue
        lines.append(line)
        if v in mapping_vars and v in _ghost_maps:
            lines.append(f"        _sum_{v}  += amount;   // keep sum ghost consistent")
    body = "\n".join(lines) if lines else "        // (no accounting vars to seed)"
    return ("    function depositFor(address who, uint256 amount) public {\n"
            f"{body}\n"
            "    }")


def _seed_line(var: str, tstr: str, is_mapping: bool):
    """One `depositFor` seeding statement, well-typed for the variable, or None.

    Two assumptions used to be baked in. Every mapping was indexed with `who`,
    an address, so a mapping keyed by `uint16` or `bytes32` failed to compile.
    And every value was incremented by `amount`, a uint256, which solc rejects
    for a narrower integer such as `uint8 _decimals`. On deployed contracts
    both are common, and either one stops the whole harness from compiling.

    A mapping is seeded only when it is keyed by an address, since that is the
    only key `who` can supply; a mapping with any other key is left at zero,
    which is still a feasible state. A value narrower than uint256 is written
    through an explicit conversion.
    """
    t = _REF_SUFFIX.sub("", tstr or "").strip()
    if is_mapping:
        if t and t.startswith("mapping("):
            key = t[len("mapping("):t.index("=>")].strip()
            if key not in ("address", "address payable"):
                return None
            val = t[t.rfind("=>") + 2:].strip().rstrip(")").strip()
        else:
            val = "uint256"
        conv = f"{val}(amount)" if val and val != "uint256" else "amount"
        return f"        {var}[who]  += {conv};"
    conv = f"{t}(amount)" if t and t != "uint256" and _is_int_scalar(t) \
        else "amount"
    return f"        {var}  += {conv};"


def _numeric_storage_vars(facts: ContractFacts) -> set[str]:
    """Storage vars whose type is a numeric (uint/int) scalar or a
    mapping(... => uint/int). address/bool vars are excluded so we never emit
    `addr += amount`.

    Ground truth is the AST type map (facts.var_types). A var is numeric iff
    its declared type is an integer scalar or a mapping whose value type is an
    integer. When var_types is empty (regex analyzer / no solc), we fall back
    to the previous behavior: everything except the regex/name-detected
    address/bool vars."""
    addr_bool = _addr_bool_vars(facts)
    if facts.var_types:
        result = set()
        for v in facts.storage_vars:
            if v in addr_bool:
                continue
            if _is_numeric_type(facts.var_types.get(v, "")):
                result.add(v)
        return result
    # fallback (unchanged from before): all storage vars minus addr/bool
    return {v for v in facts.storage_vars if v not in addr_bool}


_REF_SUFFIX = re.compile(r"\s+(?:storage\s+(?:ref|pointer)|memory|calldata)\b")


def _is_int_scalar(t: str) -> bool:
    """An integer value type and nothing else: uint, uint8 ... uint256, int..."""
    return bool(re.fullmatch(r"u?int\d*", t.strip()))


def _is_numeric_type(tstr: str) -> bool:
    """True if `v += amount` or `v[who] += amount` is well-typed for a storage
    variable of this solc typeString.

    That means an integer scalar, or a mapping whose value is an integer scalar
    and which is indexed once. Testing only a `uint` prefix admitted
    `uint256[50]` and `uint256[]`, whose type strings also start with `uint`,
    and a nested mapping, whose innermost value is an integer but which needs
    two indexes. The harness then emitted `arr += amount` and
    `m[who] += amount` against them, and solc rejected the whole harness --
    which is how most deployed contracts failed before any obligation ran.
    """
    if not tstr:
        return False
    t = _REF_SUFFIX.sub("", tstr).strip()
    if t.startswith("mapping("):
        if t.count("mapping(") > 1:
            return False
        inner = t[t.rfind("=>") + 2:].strip()
        if inner.endswith(")"):
            inner = inner[:-1].strip()
        return _is_int_scalar(inner)
    return _is_int_scalar(t)


def _mapping_storage_vars(facts: ContractFacts) -> set[str]:
    """Storage vars whose declared type is a mapping. Ground truth is the AST
    type map; when it is empty we fall back to the previous name allowlist."""
    if facts.var_types:
        return {v for v in facts.storage_vars
                if facts.var_types.get(v, "").startswith("mapping(")}
    # fallback (unchanged): hardcoded name hints for the regex-analyzer path
    return {v for v in facts.storage_vars
            if v.lower() in ("shares", "balances", "balanceof", "balance")}


def _addr_bool_vars(facts: ContractFacts) -> set[str]:
    """Identify address/bool storage so we never emit `addr += amount`.

    Ground truth is the AST type map (facts.var_types): a var is address/bool
    iff its declared type is exactly `address`, an address-derived type
    (e.g. `address payable`, contract/interface references), or `bool`.
    Crucially, a `mapping(address => uint256)` is NOT address/bool -- it is a
    numeric mapping -- which is exactly the glp/balanceOf misclassification the
    old declaration-text regex got wrong.

    When var_types is empty (regex analyzer / no solc), we fall back to the
    previous behavior: a declaration-text regex, then conservative name hints."""
    if facts.var_types:
        addr_bool = set()
        for v in facts.storage_vars:
            t = facts.var_types.get(v, "")
            if _is_addr_bool_type(t):
                addr_bool.add(v)
        return addr_bool
    # ---- fallback path (unchanged behavior when no AST types) ----
    src = _SRC_CACHE.get(facts.contract, "")
    addr_bool = set()
    if src:
        for v in facts.storage_vars:
            # match `address ... v ;` or `bool ... v ;` at declaration
            if re.search(rf"\b(address|bool)\b[^;\n]*\b{re.escape(v)}\b\s*;", src):
                addr_bool.add(v)
        return addr_bool
    # fallback: conservative name hints
    for v in facts.storage_vars:
        lv = v.lower()
        if lv in ("hook", "receiver", "owner", "admin", "token", "asset",
                  "exposed", "midcall", "locked", "paused"):
            addr_bool.add(v)
    return addr_bool


def _is_addr_bool_type(tstr: str) -> bool:
    """True if a solc typeString denotes an address-like or bool SCALAR (never
    a mapping, even a mapping with an address key)."""
    if not tstr or tstr.startswith("mapping("):
        return False
    if tstr == "bool":
        return True
    # address, address payable, and contract/interface reference types
    # (e.g. "contract IHook") all behave as address scalars for seeding.
    return tstr.startswith("address") or tstr.startswith("contract ") \
        or tstr.startswith("interface ")


# Cache of contract source keyed by contract name, populated by
# synthesize_harness so type classification can read real declarations.
_SRC_CACHE: dict[str, str] = {}
_SOLIDITY_KEYWORDS = {
    "require","assert","emit","return","if","else","for","while","do","new",
    "address","bool","uint","int","mapping","public","private","internal",
    "external","memory","calldata","storage","payable","this","msg","block",
    "tx","abi","true","false","wei","gwei","ether","seconds","minutes","hours",
    "days","weeks","delete","revert","unchecked","type","keccak256","function",
    "constructor","modifier","view","pure","returns","contract","interface",
    "library","struct","enum","event","using","is","virtual","override",
    # Reserved words that appear where an identifier would: `uint256 constant
    # FEE = 1;` and `address payable owner;` both leave a keyword sitting in
    # identifier position. Declaring one as a state variable is a syntax error.
    "constant","immutable","indexed","anonymous","receive","fallback",
    "try","catch","assembly","let","super","selfdestruct","gasleft",
    "returndata","import","pragma","global","transient",
}

# Reserved words must never be emitted as a declaration name, whatever the
# analyzer reports as a storage variable.
_NEVER_DECLARE = {
    "constant","immutable","payable","memory","storage","calldata","public",
    "private","internal","external","view","pure","virtual","override",
    "indexed","anonymous","returns","function","contract","interface",
    "library","struct","enum","event","modifier","constructor","receive",
    "fallback","address","mapping","bool","string","bytes","uint","int",
    "this","msg","block","tx","abi","true","false","new","delete","is",
}


def _strip_comments_strings(text: str) -> str:
    text = re.sub(r"//[^\n]*", "", text)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)
    text = re.sub(r"'(?:[^'\\]|\\.)*'", "''", text)
    return text
_TYPE_PREFIXES = ("uint", "int", "address", "bool", "bytes", "string")


_ELEMENTARY_PREFIXES = ("uint", "int", "address", "bool", "bytes", "string",
                        "mapping", "fixed", "ufixed")


class HarnessUnsupported(Exception):
    """Raised when a faithful harness cannot be built for a contract.

    Refusing is the honest outcome: emitting a harness that silently drops code
    with storage effects would let the solver prove a property the original
    contract does not satisfy.
    """


def _strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", " ", text)


def _drop_assembly(body: str) -> str:
    """Remove inline assembly blocks from a transcribed body.

    Yul cannot be reproduced meaningfully inside an isolated harness: it reads
    calldata and memory the harness does not have. A block that only computes
    local values may be dropped, since the values it feeds are already resolved
    as unconstrained symbols. A block that writes storage cannot: dropping it
    would remove a state effect the property depends on, so the contract is
    reported unsupported instead.
    """
    out, i = [], 0
    while True:
        m = re.search(r"\bassembly\b\s*(\(\s*\"memory-safe\"\s*\))?\s*\{",
                      body[i:])
        if not m:
            out.append(body[i:])
            break
        start = i + m.start()
        brace = body.find("{", i + m.start())
        depth, j = 0, brace
        while j < len(body):
            if body[j] == "{":
                depth += 1
            elif body[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        block = body[brace:j + 1]
        if re.search(r"\bsstore\b|\.slot\b", block):
            raise HarnessUnsupported(
                "inline assembly writes storage; cannot model faithfully")
        out.append(body[i:start])
        out.append("        // [assembly block omitted]\n")
        i = j + 1
    return "".join(out)


def _collect_type_defs(src: str) -> tuple:
    """Return (definition_text, defined_names) for every struct and enum in the
    source.

    The harness is a standalone contract, so a transcribed body that mentions a
    struct or enum needs that definition present. Field types naming a contract
    or interface are rewritten to `address`, which is how the harness models any
    external party anyway.
    """
    defined = set()
    blocks = []
    for m in re.finditer(r"\b(struct|enum)\s+([A-Za-z_]\w*)\s*\{", src):
        kind, name = m.group(1), m.group(2)
        if name in defined:
            continue
        open_idx = src.find("{", m.end() - 1)
        depth, j = 0, open_idx
        while j < len(src):
            if src[j] == "{":
                depth += 1
            elif src[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if j >= len(src):
            continue
        defined.add(name)
        blocks.append((kind, name, src[open_idx:j + 1]))

    out = []
    for kind, name, body in blocks:
        if kind == "enum":
            out.append("    enum %s %s" % (name, body))
            continue
        inner = _strip_comments(body[1:-1])
        fixed = []
        for field in inner.split(";"):
            f = " ".join(field.split())
            if not f:
                continue
            # Only well-formed `type name` pairs are fields; anything else is a
            # fragment of a construct the splitter did not understand and must
            # not be emitted as a declaration.
            if not re.fullmatch(r"[A-Za-z_][\w.]*(?:\s*\[[^\]]*\])*"
                                r"(?:\s+(?:memory|storage|calldata))?"
                                r"\s+[A-Za-z_]\w*", f):
                continue
            mm = re.match(r"^([A-Za-z_]\w*)((?:\s*\[[^\]]*\])?)\s+"
                          r"([A-Za-z_]\w*)$", f)
            if mm and mm.group(1) not in defined and \
                    not mm.group(1).startswith(_ELEMENTARY_PREFIXES):
                fixed.append("        address%s %s;" % (mm.group(2), mm.group(3)))
            else:
                fixed.append("        %s;" % f)
        body = "{\n%s\n    }" % "\n".join(fixed)
        out.append("    struct %s %s" % (name, body))
    return ("\n".join(out) + "\n") if out else "", defined


_REF_LOCAL = re.compile(
    r"^(\s*)([A-Za-z_]\w*(?:\s*\[[^\]]*\])*)"
    r"\s+([A-Za-z_]\w*)\s*(=|;)")


def _add_local_data_locations(body: str, structs: set = frozenset()) -> str:
    """Give reference-typed locals an explicit data location.

    `bytes`, `string`, array and struct types are reference types: as a local
    they must state `memory`, `storage` or `calldata`, though as a state
    variable they must not. Bodies are transcribed from source where the
    location was present on the original declaration or implied by a parameter,
    so re-emitting them without one fails to compile.
    """
    out = []
    for line in body.splitlines():
        m = _REF_LOCAL.match(line)
        if not m:
            out.append(line)
            continue
        indent, tname, var, tail = m.groups()
        base = tname.split("[")[0].strip()
        is_ref = (base in ("bytes", "string") or "[" in tname
                  or base in structs)
        if not is_ref:
            out.append(line)
            continue
        if re.search(r"\b(memory|storage|calldata)\b", line):
            out.append(line)
            continue
        if re.match(r"\s*(public|private|internal|constant|immutable)\b",
                    line[len(indent):]):
            out.append(line)
            continue
        sep = "" if tail == ";" else " "
        out.append("%s%s memory %s%s%s%s" % (
            indent, tname, var, sep, tail, line[m.end():]))
    return "\n".join(out)


def _normalize_unknown_types(body: str, defined: set) -> str:
    """Rewrite locals typed by a contract or interface to `address`.

    `IOwnable rollup_;` cannot compile in an isolated harness because the
    interface is not carried over; the harness models external parties as plain
    addresses, so the declaration becomes `address rollup_;`.
    """
    def repl(m):
        tname, rest, var = m.group(1), m.group(2), m.group(3)
        if tname in defined or tname.startswith(_ELEMENTARY_PREFIXES):
            return m.group(0)
        return "address%s %s" % (rest, var)
    return re.sub(r"\b([A-Z]\w*)((?:\s*\[\s*\])?)\s+"
                  r"(?:storage\s+|memory\s+|calldata\s+)?([a-z_]\w*)\s*(?==|;)",
                  repl, body)


def _declared_locals(body: str) -> set:
    """Names introduced by local declarations inside a generated phase or
    wrapper body.

    Must cover every declaration form real code uses, not just bare elementary
    scalars: array types, an explicit data location, and tuple destructuring all
    introduce names. A name missed here is treated as free by the resolver and
    redeclared as storage, which both shadows the local and rewrites the
    declaration into `uint256[] memory = amount;`.
    """
    out = set()
    body = _strip_comments_strings(body)

    elem = (r"(?:u?int\d*|address(?:\s+payable)?|bool|bytes\d*|string|"
            r"mapping\s*\([^)]*\)|[A-Z]\w*(?:\.\w+)?)")
    loc = r"(?:\s+(?:storage|memory|calldata))?"
    arr = r"(?:\s*\[[^\]]*\])*"

    # `T[] memory name = ...;`  /  `T name;`
    for m in re.finditer(rf"\b{elem}{arr}{loc}\s+([A-Za-z_]\w*)\s*(?==|;|,|\))",
                         body):
        out.add(m.group(1))

    # tuple destructuring: `(bool ok, bytes memory ret) = f();`
    for m in re.finditer(r"\(([^()]*)\)\s*=", body):
        for part in m.group(1).split(","):
            part = part.strip()
            if not part:
                continue
            mm = re.match(rf"^{elem}{arr}{loc}\s+([A-Za-z_]\w*)$", part)
            if mm:
                out.add(mm.group(1))

    out.discard("memory")
    out.discard("storage")
    out.discard("calldata")
    out.discard("payable")
    return out

def _free_identifiers(body: str) -> set:
    """Identifiers referenced in a body, excluding keywords, type names, and
    member-access suffixes (the `.x` in `a.x`)."""
    out = set()
    body = _strip_comments_strings(body)
    # custom-error / event identifiers (revert X(), emit X()) are not value
    # references -- they must not become symbolic state vars.
    err_evt = set(re.findall(r"\brevert\s+([A-Za-z_]\w*)", body))
    err_evt |= set(re.findall(r"\bemit\s+([A-Za-z_]\w*)", body))
    for m in re.finditer(r"(?<![\.\w])([A-Za-z_]\w*)", body):
        ident = m.group(1)
        if ident in _SOLIDITY_KEYWORDS:
            continue
        if any(ident.startswith(t) and ident[len(t):].isdigit() for t in ("uint","int","bytes")):
            continue
        if ident in ("uint","int","address","bool","bytes","string"):
            continue
        if ident in err_evt:
            continue
        out.add(ident)
    return out


_GLOBAL_FUNCTIONS = {"ecrecover", "keccak256", "sha256", "ripemd160", "addmod",
                     "mulmod", "blockhash", "gasleft", "selfdestruct", "type",
                     "assert", "require", "revert"}


_GHOSTS_NOT_HAVOCED = {"inFlight", "exposed", "snapPre", "_ethBal"}


def _config_havoc(storage_decls: str, facts) -> str:
    """A setter for storage no adversary-callable function writes.

    Such a variable is set by the constructor, which the harness does not
    run, or by privileged functions, which the trusted-roles assumption keeps
    out of the callback closure but not out of the contract's history: the
    owner may have configured any value before. Left at 0, a sale flag or a
    supply cap made every mint revert, the callback window unreachable and
    each proof about it vacuous. Setting them freely between transactions is
    an over-approximation of every configuration."""
    privileged = set(getattr(facts, "privileged", {}) or {})
    functions = getattr(facts, "functions", {}) or {}

    def writes(f):
        if hasattr(facts, "transitive_writes"):
            try:
                return facts.transitive_writes(f)
            except Exception:
                pass
        return getattr(functions[f], "writes", set()) or set()

    adversary_writes = set()
    for f in functions:
        if f not in privileged:
            adversary_writes |= writes(f)
    cfg = []
    for m in re.finditer(r"^    (u?int\d*|bool|address) public (\w+);\s*$",
                         storage_decls, re.M):
        t, n = m.group(1), m.group(2)
        if n in _GHOSTS_NOT_HAVOCED or n.startswith("_sum_"):
            continue
        if n in adversary_writes:
            continue
        cfg.append((t, n))
    if not cfg:
        return ""
    return _havoc_functions("__havoc_cfg", cfg)


_HAVOC_CHUNK = 8


def _havoc_functions(prefix: str, pairs: list) -> str:
    """Setters for (type, name) pairs, a few per function: one function with
    every parameter hits solc's stack limit on a large contract."""
    out = []
    for k in range(0, len(pairs), _HAVOC_CHUNK):
        chunk = pairs[k:k + _HAVOC_CHUNK]
        params = ", ".join(f"{t} __x{i}" for i, (t, _n) in enumerate(chunk))
        sets = "\n".join(f"        {n} = __x{i};" for i, (_t, n) in enumerate(chunk))
        out.append(f"\n    function {prefix}{k // _HAVOC_CHUNK}({params}) public {{\n"
                   f"{sets}\n    }}\n")
    return "".join(out)


def _function_units(body: str) -> list:
    """The function definitions in body, each as its own text, plus whatever
    lies outside them as one more unit."""
    units, rest, last = [], [], 0
    for m in re.finditer(r"\bfunction\s+[A-Za-z_]\w*\s*\([^)]*\)[^{;]*\{", body):
        if m.start() < last:
            continue
        i, d = m.end(), 1
        while i < len(body) and d:
            d += body[i] == "{"
            d -= body[i] == "}"
            i += 1
        rest.append(body[last:m.start()])
        units.append(body[m.start():i])
        last = i
    rest.append(body[last:])
    outside = "".join(rest)
    if outside.strip():
        units.append(outside)
    return units


def _resolve_unbound(bodies: list, known: set, omitted: set = frozenset(),
                     src: str = "") -> tuple:
    """Given the generated phase/wrapper bodies and the set of already-known
    identifiers (harness storage + ghosts + amount + locals), return
    (extra_decls, rewritten_bodies): symbolic harness state variables for every
    unresolved reference, and the bodies with no-arg helper calls rewritten to
    those symbolic reads. Unresolved references model immutables, constants, and
    helper results as arbitrary fixed values, which over-approximates and is
    therefore sound."""
    unresolved = set()
    local_known = set(known)
    local_known |= {"depositFor", "beginExposed", "endExposed"}
    for b in bodies:
        # the harness's own function names are not free identifiers
        for m in re.finditer(r"\bfunction\s+([A-Za-z_]\w*)\s*\(", b):
            local_known.add(m.group(1))
    # A local or parameter is known only inside the function declaring it.
    # Pooling them over all bodies let `owner`, a parameter of one helper,
    # count as declared in a wrapper that uses it after the statement
    # declaring it there was dropped, and the harness did not compile.
    for b in bodies:
        for unit in _function_units(b):
            scope = local_known | _declared_locals(unit)
            for ident in _free_identifiers(unit):
                if ident in _NEVER_DECLARE:
                    continue
                if ident not in scope and ident not in omitted:
                    unresolved.add(ident)
    # never resurrect a var the type-normalizer omitted as unrepresentable
    unresolved -= set(omitted)
    # Global functions are not state. A function the harness carries as a
    # helper copy is called through that copy: a view copied verbatim still
    # names the original, and declaring it a uint256 made the call fail.
    unresolved = {u for u in unresolved
                  if u not in _GLOBAL_FUNCTIONS and not _is_builtin_name(u)}
    helper_fns = {m.group(1) for b in bodies for m in re.finditer(
        r"\bfunction\s+(__h_[A-Za-z_]\w*)\s*\(", b)}
    via_helper = {u for u in unresolved if f"__h_{u}" in helper_fns}
    if via_helper:
        bodies = [re.sub(r"(?<![\.\w])(" + "|".join(sorted(via_helper)) + r")\s*\(",
                         lambda m: f"__h_{m.group(1)}(", b) for b in bodies]
        # a name that is also used as a value, not only called, still needs
        # its declaration: `owner` in approve is a local the split dropped,
        # while `owner()` elsewhere is the Ownable getter
        still_read = {u for u in via_helper if any(
            re.search(rf"(?<![\.\w]){re.escape(u)}\b(?!\s*\()",
                      _strip_comments_strings(b)) for b in bodies)}
        unresolved -= (via_helper - still_read)
    if not unresolved:
        return "", bodies
    # Rewrite no-arg helper calls `foo()` -> `foo` (a symbolic state read).
    rewritten = []
    for b in bodies:
        for u in unresolved:
            b = re.sub(rf"\b{re.escape(u)}\s*\(\s*\)", u, b)
        rewritten.append(b)
    joined = "\n".join(rewritten)
    lines = []
    for u in sorted(unresolved):
        # The original declaration is the best evidence of a name's type: a
        # success flag is declared `(bool ok, ) = x.call(...)` in the statement
        # the split removed, and is often returned as well as tested, so
        # usage alone does not settle it.
        dtype = _declared_type(u, src)
        if dtype.endswith("[]"):
            lines.append(f"    {dtype} public {u};   "
                         f"// symbolic (declared {dtype} in the source)")
            continue
        if dtype.startswith("address"):
            lines.append(f"    address public {u};   "
                         f"// symbolic (declared address in the source)")
            continue
        if dtype == "bool" or (not dtype and _used_as_bool(u, joined)):
            # A name used only as a condition is almost always the success
            # flag of an external call the phase split excised: `(bool ok, )
            # = x.call(...); require(ok);`. The call is modelled separately,
            # so the flag is taken as having succeeded. Declaring it uint256,
            # as every other unresolved name is, gave `require(uint256)`, which
            # has no matching overload and stopped the harness compiling.
            lines.append(f"    bool public {u} = true;   "
                         f"// success flag of an excised call")
        else:
            lines.append(f"    uint256 public {u};   "
                         f"// symbolic (immutable/helper/constant)")
    havoc = [(m.group(1), m.group(2)) for m in re.finditer(
        r"^    (uint256|address) public (\w+);   // symbolic", "\n".join(lines), re.M)]
    if havoc:
        lines.append(_havoc_functions("__havoc_sym", havoc))
    return "\n".join(lines), rewritten

def _used_as_bool(name: str, text: str) -> bool:
    """True when every use of `name` in `text` is as a whole boolean operand.

    Whole means nothing binds to it on either side but a boolean context: it
    opens a require/assert/if/while condition or follows `!`, `&&`, `||`; and
    it is followed by `)`, `,`, `&&` or `||`. Checking only the left side took
    `require(currentAllowance >= x)` for a boolean use of `currentAllowance`.
    """
    n = re.escape(name)
    uses = [m for m in re.finditer(rf"\b{n}\b", text)]
    if not uses:
        return False
    for m in uses:
        left = text[:m.start()].rstrip()
        right = text[m.end():].lstrip()
        left_ok = (re.search(r"(?:\b(?:require|assert|if|while)\s*\(\s*!?)$",
                             left) is not None
                   or re.search(r"(?:&&|\|\||!)$", left) is not None
                   and not left.endswith("!="))
        right_ok = re.match(r"(?:\)|,|;|&&|\|\|)", right) is not None
        if not (left_ok and right_ok):
            return False
    return True


def _declared_type(name: str, src: str) -> str:
    """The type `name` is declared with in the original source, or ''."""
    n = re.escape(name)
    m = re.search(rf"\b(bool|address(?:\s+payable)?|u?int\d*|bytes\d+)\s+{n}\s*[=;,)]",
                  src or "")
    if m:
        return m.group(1)
    m = re.search(rf"\b(bool|address|u?int\d*|bytes\d+)\s*\[\s*\]\s*"
                  rf"(?:memory|storage|calldata)?\s+{n}\s*[=;,)]", src or "")
    return (m.group(1) + "[]") if m else ""


_UNREPRESENTABLE_VARS: dict[str, set] = {}


def _phase_body(contract_src: str, site: ExposureSite, phase: str) -> str:
    """Extract the pre- or post-phase body of the exposure-site function by
    locating the external call and splitting around the *whole* statement that
    contains it.

    pre-phase  = statements before the external-call statement
    post-phase = statements after the external-call statement

    A call wrapped in a single-statement guard (`if (r != 0) { r.cb(); }`) is
    excised with its guard, so neither side keeps half a block. A call inside
    a larger `if` block -- other statements alongside it -- is split exactly:
    the pre side closes the block, the post side reopens it on the branch the
    pre side actually took, recorded in a harness field. See _nested_split.

    The body is taken from the implementation, not an interface declaration:
    a flattened file declares `function withdraw() external;` in an interface
    before defining it, and matching that bodiless declaration ran on into the
    next unrelated brace. The call is located at a word boundary after a `.`,
    at the site's own position among the function's calls, so neither
    `calldata` nor an earlier call is mistaken for it."""
    # Either failure leaves a phase with nothing in it. Emitting a comment and
    # carrying on built a harness whose phase did nothing, and OBL_post then
    # refuted a contract for a post-phase it never saw -- SHIBB, whose call
    # sits inside a helper transferFrom reaches, not in its own body. The
    # marker makes the conformance check reject the harness with the reason.
    body = _extract_function_body(contract_src, site.function)
    if body is None:
        return (f"        // AEGIS-UNSUPPORTED: body of {site.function} "
                f"not found in the source")

    cpos = _locate_call(body, site)
    if cpos == -1:
        return (f"        // AEGIS-UNSUPPORTED: the exposure call is not in "
                f"{site.function} itself (reached through a helper)")

    cut_start, cut_end = _guard_span(body, cpos)
    split = _nested_split(body, cut_start, cut_end, site)
    if split is not None:
        pre_text, post_text = split
        chunk = pre_text if phase == "pre" else post_text
        if "AEGIS-UNSUPPORTED" in chunk:
            # returned as is: _clean_chunk strips comments, and this marker
            # must reach the conformance check, which rejects the harness
            # rather than let empty phases stand in for the real ones
            return chunk
    else:
        chunk = body[:cut_start] if phase == "pre" else body[cut_end:]
    return _clean_chunk(chunk, keep_requires=False)


def _moved_value_expr(contract_src: str, site) -> str | None:
    """The quantity the exposure call hands over, as an expression, or None.

    `x.call{value: V}("")`, `x.transfer(V)` and `x.send(V)` all name it. The
    harness drives its phases with a free parameter `amount`, while the
    contract moves a quantity its own state decides -- the caller's balance, a
    fee, a share. Left free, the obligations quantified over amounts the
    contract can never produce and failed on states that do not exist.
    """
    body = _extract_function_body(contract_src, site.function)
    if body is None:
        return None
    pos = _locate_call(body, site)
    if pos == -1:
        return None
    start, end = _guard_span(body, pos)
    stmt = body[start:end]
    m = re.search(r"\.\s*call\s*\{[^}]*\bvalue\s*:\s*([^,}]+)", stmt)
    if m:
        return m.group(1).strip()
    m = re.search(r"\.\s*(?:transfer|send)\s*\(([^;]*)\)\s*;?\s*$", stmt.strip())
    if m and "," not in m.group(1):
        return m.group(1).strip()
    return None


def _locate_call(body: str, site) -> int:
    """Index of the site's call token in `body`, or -1.

    The token must follow a `.` and end at a word boundary, and when a function
    makes several calls of the same kind the site's own index picks which.
    """
    token = site.call.lstrip(".")
    hits = [m.start(1) for m in re.finditer(
        rf"\.\s*({re.escape(token)})\b", body)]
    if not hits:
        i = body.find(token)
        return i
    idx = getattr(site, "index", 0) or 0
    return hits[idx] if idx < len(hits) else hits[0]


def _block_header_start(body: str, bpos: int) -> int:
    """Start of the header of the block opening at `bpos`.

    A header ending in `)` -- `if (...)`, `for (...; ...; ...)` -- is walked
    back to its matching `(` and then to the keyword before it, so the
    semicolons inside a `for` header are not taken for statement ends.
    """
    j = bpos - 1
    while j >= 0 and body[j] in " \t\n":
        j -= 1
    if j >= 0 and body[j] == ")":
        depth = 0
        while j >= 0:
            if body[j] == ")":
                depth += 1
            elif body[j] == "(":
                depth -= 1
                if depth == 0:
                    break
            j -= 1
        j -= 1
    while j >= 0 and body[j] not in ";{}":
        j -= 1
    return j + 1


# Blocks the pre side leaves open around a nested call, keyed by site.
_BRANCH_FIELDS: dict = {}


def _nested_split(body: str, cut_start: int, cut_end: int, site):
    """Split a body whose call sits inside `if` / `unchecked` blocks.

    Returns (pre, post), or None when the call is not nested. For
    `if (c) { A; call; B; } C;` the result is

        pre :  __branch0 = (c);  if (__branch0) { A; }
        post:  if (__branch0) { B; }  C;

    The branch field records which way `c` went before control left, so the
    post side follows the same branch even if the callback changed what `c`
    reads -- exactly as the original, where the branch is already taken.
    `unchecked { ... }` has no condition and is simply closed and reopened.
    Any other enclosing block (a loop, an `else`) is not split: the post side
    would have to resume mid-iteration. The site is then reported unsupported
    through a harness marker, rather than emitting code that does not compile.
    """
    # the chain of blocks still open at the cut point, outermost first
    opens = []
    depth_stack = []
    i = 0
    while i < cut_start:
        c = body[i]
        if c == "{":
            depth_stack.append(i)
        elif c == "}":
            if depth_stack:
                depth_stack.pop()
        i += 1
    if not depth_stack:
        return None

    pre_parts, post_open = [], []
    key = f"{site.function}:{getattr(site, 'index', 0)}"
    fields = []
    last = 0
    for n, bpos in enumerate(depth_stack):
        header_start = _block_header_start(body, bpos)
        header = body[header_start:bpos].strip()
        m_if = re.fullmatch(r"(?:else\s+)?if\s*\((.*)\)", header, re.DOTALL)
        if header == "unchecked":
            pre_parts.append(body[last:bpos + 1])
            post_open.append("unchecked {")
        elif m_if and not header.startswith("else"):
            fname = f"__branch{len(fields)}"
            fields.append(fname)
            pre_parts.append(body[last:header_start])
            pre_parts.append(f"\n        {fname} = ({m_if.group(1)});"
                             f"\n        if ({fname}) {{")
            post_open.append(f"if ({fname}) {{")
        else:
            _BRANCH_FIELDS[key] = None
            return ("        // AEGIS-UNSUPPORTED: exposure call nested in "
                    f"`{header[:40]}`",
                    "        // AEGIS-UNSUPPORTED: exposure call nested in "
                    f"`{header[:40]}`")
        last = bpos + 1
    pre = "".join(pre_parts) + body[last:cut_start] + "\n" + \
        "}\n" * len(depth_stack)
    post = "\n".join(post_open) + "\n" + body[cut_end:]
    _BRANCH_FIELDS[key] = fields
    return pre, post


def _guard_span(body: str, call_pos: int) -> tuple[int, int]:
    """Given the index of the external-call token in a function body, return
    the [start, end) span to excise so neither side keeps a dangling brace or a
    dangling guard header.

    Three cases:
      1. braced guard:   if (...) { <call>; }   -> excise the whole block
      2. inline guard:   if (...) <call>;       -> excise `if (...)` + the stmt
      3. bare call:      <call>;                -> excise just the statement
    """
    # end of the call statement (its terminating semicolon)
    semi = body.find(";", call_pos)
    stmt_end = semi + 1 if semi != -1 else call_pos + 1

    pre = body[:call_pos]

    # Case 1: braced guard. An `if (...) {` opens just before the call with no
    # statement terminator between the brace and the call.
    brace = pre.rfind("{")
    if brace != -1 and ";" not in pre[brace + 1:] and "}" not in pre[brace + 1:]:
        header = pre[:brace]
        gstart = re.search(r"\b(if)\b[^;{}]*$", header)
        if gstart:
            depth, j = 0, brace
            while j < len(body):
                if body[j] == "{":
                    depth += 1
                elif body[j] == "}":
                    depth -= 1
                    if depth == 0:
                        return gstart.start(), j + 1
                j += 1
            return gstart.start(), stmt_end

    # Case 2: inline (brace-less) guard. An `if (...)` header sits just before
    # the call on the same statement, with no intervening `;` `{` or `}`.
    gstart = re.search(r"\b(if)\b\s*\([^;{}]*\)\s*[^;{}]*$", pre)
    if gstart:
        return gstart.start(), stmt_end

    # Case 3: bare call statement. call_pos points at the call TOKEN
    # (e.g. `onFlashLoan`), which sits mid-statement after its receiver
    # (`IFlashBorrower(borrower).`). Excising from call_pos would leave that
    # receiver stump (`IFlashBorrower(borrower).;`). Walk back to the start of
    # the containing statement (the previous `;`, `{`, or `}`) so the whole
    # call statement is removed.
    # With no earlier separator the call is the body's first statement, and
    # the statement starts at the body's start. Falling back to call_pos here
    # left exactly the receiver stump described above -- `msg.sender.;` from
    # `(bool sent,) = msg.sender.call{value: v}("");` as a first line.
    sep = max(pre.rfind(";"), pre.rfind("{"), pre.rfind("}"))
    stmt_start = sep + 1
    return stmt_start, stmt_end


# Internal functions defined in the source being synthesized, and the helper
# copies the current synthesis has called for: {harness name: (name, super?)}.
_INTERNAL_FNS: set = set()
_CALLED_HELPERS: dict = {}
# Parameter counts of each source function, so an overloaded helper is copied
# in the form the call site actually uses.
_FN_ARITIES: dict = {}


def _arg_count(text: str, open_paren: int) -> int:
    depth, i, commas, content = 0, open_paren, 0, False
    while i < len(text):
        c = text[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                break
        elif c == "," and depth == 1:
            commas += 1
        elif depth >= 1 and not c.isspace():
            content = True
        i += 1
    return commas + 1 if content else 0


# Storage the harness leaves out (dynamic arrays and the like), and all known
# storage, for the synthesis in progress.
_OMITTED_NOW: set = set()
_STORAGE_NOW: set = set()

_BUILTIN_CALLS = {
    "require", "assert", "if", "while", "for", "return", "revert", "emit",
    "address", "payable", "bool", "bytes", "string", "keccak256", "sha256",
    "ripemd160", "ecrecover", "addmod", "mulmod", "gasleft", "blockhash",
    "type", "abi", "new", "selfdestruct", "unchecked",
}
_BUILTIN_MEMBERS = {"push", "pop", "encode", "encodePacked", "encodeWithSelector",
                    "encodeWithSignature", "encodeCall", "decode", "concat"}
_SAFEMATH = {"add": "+", "sub": "-", "mul": "*", "div": "/", "mod": "%"}


def _is_builtin_name(n: str) -> bool:
    return n in _BUILTIN_CALLS or bool(re.fullmatch(r"u?int\d*|bytes\d+", n))


def _rewrite_safemath(text: str) -> str:
    """`a.add(b)` -> `(a + b)`, including the two-argument `a.sub(b, "msg")`
    form, innermost first so chains resolve. Dropping these statements lost the
    write they carried."""
    for _ in range(20):
        m = None
        for mm in re.finditer(r"\.\s*(add|sub|mul|div|mod)\s*\(", text):
            m = mm
        if m is None:
            break
        start = _receiver_start(text, m.start())
        p = text.index("(", m.end() - 1)
        depth, j = 0, p
        while j < len(text):
            if text[j] == "(":
                depth += 1
            elif text[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        args = text[p + 1:j]
        d, cut = 0, len(args)
        for k, ch in enumerate(args):
            if ch in "([":
                d += 1
            elif ch in ")]":
                d -= 1
            elif ch == "," and d == 0:
                cut = k
                break
        recv = text[start:m.start()].strip()
        if not recv:
            break
        text = (text[:start] + f"({recv} {_SAFEMATH[m.group(1)]} "
                f"{args[:cut].strip()})" + text[j + 1:])
    return text


def _rewrite_calls(stmt: str, nocmt: str):
    """(statement, keep?) -- internal calls renamed to harness helper copies,
    and False when the statement calls another contract."""
    stmt = _rewrite_safemath(stmt)
    nocmt = _rewrite_safemath(nocmt)
    # `router.addLiquidityETH{value: v}(...)` carries call options between the
    # name and its arguments; requiring `(` straight after the name let such
    # calls through, and the harness then named a member it does not have
    for m in re.finditer(r"(\w+|\)|\])\s*\.\s*(\w+)\s*(?:\{[^{}]*\}\s*)?\(", nocmt):
        recv, fn = m.group(1), m.group(2)
        if recv == "super" and fn in _INTERNAL_FNS:
            continue
        if recv == "abi":
            continue
        if fn in ("push", "pop"):
            # a storage write -- but only to an array the harness carries; an
            # array it leaves out becomes a symbolic scalar, and `.push` on
            # that does not compile
            base = re.match(r"\s*([A-Za-z_]\w*)",
                            nocmt[_receiver_start(nocmt, m.start(2) - 1):])
            if base and base.group(1) in _STORAGE_NOW \
                    and base.group(1) not in _OMITTED_NOW:
                continue
            return stmt, False
        if fn in _BUILTIN_MEMBERS:
            continue
        return stmt, False
    for m in re.finditer(r"(?<![\.\w])([A-Za-z_]\w*)\s*\(", nocmt):
        n = m.group(1)
        if _is_builtin_name(n) or n in _INTERNAL_FNS:
            continue
        return stmt, False
    # rename: super.f( -> __super_f(   and   f( -> __h_f(
    def helper_name(prefix, n, text, paren):
        k = _arg_count(text, paren)
        if len(_FN_ARITIES.get(n, ())) > 1:
            return f"{prefix}{n}_{k}", k
        return f"{prefix}{n}", k

    def sup(m):
        hn, k = helper_name("__super_", m.group(1), stmt, m.end() - 1)
        _CALLED_HELPERS[hn] = (m.group(1), True, k)
        return f"{hn}("
    stmt = re.sub(r"\bsuper\s*\.\s*(\w+)\s*\(", sup, stmt)

    def own(m):
        n = m.group(1)
        if n not in _INTERNAL_FNS or _is_builtin_name(n):
            return m.group(0)
        hn, k = helper_name("__h_", n, stmt, m.end() - 1)
        _CALLED_HELPERS[hn] = (n, False, k)
        return f"{hn}("
    stmt = re.sub(r"(?<![\.\w])([A-Za-z_]\w*)\s*\(", own, stmt)
    return stmt, True


def _function_defs(src: str, name: str) -> list:
    """(start, header, params, returns, mutability, body) for every
    definition of `name` that has a body, in source order."""
    out = []
    for m in re.finditer(rf"\bfunction\s+{re.escape(name)}\s*\(([^)]*)\)"
                         rf"([^{{;]*)\{{", src):
        i, d = m.end(), 1
        while i < len(src) and d:
            d += src[i] == "{"
            d -= src[i] == "}"
            i += 1
        tail = m.group(2)
        ret = re.search(r"returns\s*\(([^)]*)\)", tail)
        mut = re.search(r"\b(view|pure)\b", tail)
        out.append((m.start(), m.group(1), ret.group(1) if ret else "",
                    mut.group(1) if mut else "", src[m.end():i - 1]))
    return out


def _emit_helpers(src: str, limit: int = 40) -> str:
    """Harness copies of every internal function the bodies call, followed
    transitively. `__h_f` is the most-derived definition of f -- the last in a
    flattened file; `__super_f` is the one before it, which is what `super`
    reaches from the most-derived contract."""
    done, out = set(), []
    while True:
        pending = [k for k in list(_CALLED_HELPERS) if k not in done]
        if not pending or len(done) >= limit:
            break
        for hname in pending:
            done.add(hname)
            name, is_super, arity = _CALLED_HELPERS[hname]
            defs = _function_defs(src, name)
            # an overloaded name: only the definitions taking that many
            # arguments are candidates
            same = [d for d in defs
                    if len([p for p in d[1].split(",") if p.strip()]) == arity]
            if same:
                defs = same
            if not defs:
                continue
            _s, params, rets, mut, body = (defs[-2] if is_super and len(defs) > 1
                                           else defs[-1])
            cleaned = _clean_chunk(body, keep_requires=True)
            ret = f" returns ({rets})" if rets.strip() else ""
            mut = f" {mut}" if mut else ""
            out.append(f"\n    /// Internal helper: copy of {'super.' if is_super else ''}"
                       f"{name}.\n    function {hname}({params}) internal{mut}{ret} {{\n"
                       f"{cleaned}\n    }}\n")
    return "".join(out)


def _clean_chunk(chunk: str, keep_requires: bool) -> str:
    """Normalize a piece of Solidity body: drop empty lines, comments, and
    (optionally) require()s, while PRESERVING brace balance.

    require()s are stripped from phase bodies (beginExposed/endExposed)
    because the obligation compiler supplies the precondition. They are KEPT
    in callback wrappers because the bug manifests precisely when a require
    becomes satisfiable in the exposed state (the canonical case is
    claimYield's require(totalAssets > totalShares)).

    Brace handling: _phase_body now excises the entire external-call guard
    block, so the chunk handed here is already balanced. We therefore do NOT
    drop braces line-by-line (the old behavior corrupted multi-line guards);
    instead, as a safety net we count braces and drop a leading orphan `}` or a
    trailing orphan `{` only if the chunk is otherwise unbalanced."""
    # Process statement-by-statement, not line-by-line: benchmark contracts
    # frequently pack several statements on one line
    # (`require(x); supply -= burn; exposed=true;`). A line-oriented filter that
    # drops a line starting with `require(` would also discard the co-located
    # accounting writes after it, emptying the phase body. We therefore split on
    # statement terminators, but only outside braces so a brace-block (an `if {`
    # ... `}` that survived the guard excision) is kept intact as one unit.
    def _split_statements(text):
        """Split on statement-terminating semicolons.

        Depth must count parentheses and brackets as well as braces: a `for`
        header carries two semicolons inside its parentheses, and cutting there
        splits the header into fragments that cannot parse. That single omission
        accounts for the dangling-paren, primary-expression and stray-`for`
        failures seen on real contracts.
        """
        # A block closed at the top level also ends a statement. Splitting only
        # at `;` glued `unchecked { ... }` to the `emit Transfer(...)` after
        # it, and the unit was then dropped for the emit -- taking the balance
        # updates inside the block with it. The exceptions continue the same
        # statement: `} else`, the `} while (...)` of a do-loop, `} catch`.
        # Braces are of two kinds. Call options -- `x.call{value: v}`,
        # `new C{salt: s}` -- follow a member name or a `new` type and belong
        # to an expression; only a closing BLOCK brace ends a statement.
        # Treating both alike split `router.addLiquidityETH{value: e}(...)`
        # in two, and neither half was then recognised as an external call.
        def _is_options(pos):
            j = pos - 1
            while j >= 0 and text[j] in " \t\n":
                j -= 1
            k = j
            while k >= 0 and (text[k].isalnum() or text[k] == "_"):
                k -= 1
            if k == j:
                return False
            word = text[k + 1:j + 1]
            while k >= 0 and text[k] in " \t\n":
                k -= 1
            if k >= 0 and text[k] == ".":
                return True
            return bool(re.search(r"\bnew\s+$", text[:k + 1] + " ")) or \
                bool(re.search(r"\bnew\s+" + re.escape(word) + r"\s*$",
                               text[:j + 1]))

        parts, buf, depth = [], [], 0
        kinds = []
        n = len(text)
        for idx, chprev in enumerate(text):
            if chprev in "([":
                depth += 1
            elif chprev == "{":
                depth += 1
                kinds.append("options" if _is_options(idx) else "block")
            elif chprev in ")]":
                depth -= 1
            elif chprev == "}":
                depth -= 1
                closed = kinds.pop() if kinds else "block"
            buf.append(chprev)
            if chprev == ";" and depth <= 0:
                parts.append("".join(buf))
                buf = []
                depth = 0
                kinds = []
            elif chprev == "}" and depth <= 0 and closed == "block":
                rest = text[idx + 1:].lstrip()
                if not re.match(r"(else|while|catch)\b", rest):
                    parts.append("".join(buf))
                    buf = []
                    depth = 0
                    kinds = []
        if "".join(buf).strip():
            parts.append("".join(buf))
        return parts

    def _drop_leading_comments(text: str) -> str:
        """Remove comment lines that lead a statement.

        _split_statements cuts on `;`, so a comment sitting above a statement is
        absorbed into that statement's text. Testing the raw text for a leading
        `//` therefore discards the comment AND the code it documents, which
        silently empties phase bodies extracted from commented source.
        """
        prev = None
        while prev != text:
            prev = text
            text = text.strip()
            if text.startswith("//"):
                nl = text.find("\n")
                text = "" if nl == -1 else text[nl + 1:]
            elif text.startswith("/*"):
                end = text.find("*/")
                text = "" if end == -1 else text[end + 2:]
        return text.strip()

    kept = []
    for raw in _split_statements(chunk):
        stripped = _drop_leading_comments(raw)
        if not stripped:
            continue
        if not keep_requires and stripped.startswith("require("):
            continue
        # Drop statements that are external/library/member calls or emits: they
        # are not accounting writes to harness storage, and they reference
        # contract/interface types absent from the isolated harness. A member
        # call is `<recv>.<fn>(` (mappings index with [], so this never matches
        # an accounting write). The invariant is over storage, so removing these
        # is sound -- a callback's effect on THIS contract's storage is modeled
        # separately by its own OBL_cb obligation.
        _nocmt = _strip_comments_strings(stripped)
        if _nocmt.lstrip().startswith("emit "):
            continue
        # Internal calls are kept and rewritten to harness copies of the
        # helpers they reach; calls to other contracts are dropped as before.
        # Dropping internal calls too -- `_transfer(...)`, `super._transfer`,
        # `_msgSender()` -- removed writes this contract really makes, so a
        # wrapper could do less than the function it stands for, and a callback
        # that breaks the invariant through a helper looked harmless.
        stripped, _keep = _rewrite_calls(stripped, _nocmt)
        if not _keep:
            continue
        # In phase bodies (keep_requires=False), drop any statements that assign
        # to the ghost-ledger vars. A contract whose source explicitly maintains
        # inFlight/exposed (e.g. CrossFunctionVault) would otherwise have those
        # writes copied verbatim into beginExposed/endExposed AND have the
        # template append its own, double-counting the ghost. The harness owns
        # the ledger, so the contract's own ledger writes are removed here.
        if not keep_requires:
            stripped = _strip_ledger_writes(stripped)
            if not stripped:
                continue
        kept.append(stripped)

    # Safety net: repair an unbalanced chunk caused by a guard that straddled
    # the cut point. Drop a leading orphan '}' (its '{' was on the other side)
    # or a trailing orphan '{' (its '}' was on the other side).
    def balance(lines):
        return sum(l.count("{") - l.count("}") for l in lines)

    while kept and balance(kept) < 0 and kept[0] in ("}", "};"):
        kept.pop(0)
    while kept and balance(kept) > 0 and (kept[-1].endswith("{")):
        kept.pop()

    out = ["        " + l for l in kept]
    return "\n".join(out) if out else "        // (empty)"


def wrapper_name(fn: str) -> str:
    """The harness function standing for a closure member.

    An unnamed fallback or receive function is reported by the analyzer as
    `<fallback>`, which is not an identifier, so no wrapper was emitted and
    the conformance check then rejected the harness for a missing function.
    """
    return "__fallback" if fn == "<fallback>" else fn


def _extract_special_body(src: str):
    """The body of `fallback()` or `receive()`, most derived first."""
    out = None
    for m in re.finditer(r"\b(?:fallback|receive)\s*\(\s*\)[^{;]*\{", src):
        depth, i = 1, m.end()
        while i < len(src) and depth:
            depth += src[i] == "{"
            depth -= src[i] == "}"
            i += 1
        out = src[m.end():i - 1]
    return out


def _emit_callback_wrappers(contract_src: str, facts: ContractFacts,
                            site: ExposureSite) -> str:
    """For each closure callback that is not the exposed function itself,
    emit a uniform `<name>(uint256 amount)` wrapper that calls the original
    body. The wrapper exists so the obligation compiler's OBL_cb_<g>
    harnesses can invoke g(amount) without per-contract special-casing.

    The original function's body references its OWN parameter names (e.g.
    `deposit(uint256 a)` uses `a`, `transfer(address to, uint256 a)` uses both
    `to` and `a`). The wrapper, however, has a single fixed parameter `amount`.
    To keep the body compilable we bind the original parameters at the top of
    the wrapper: the first uint-typed parameter is aliased to `amount`; every
    other parameter is declared as a harness-local with a neutral default
    (address -> address(this), bool -> false, uint -> amount) so the inlined
    body's identifiers all resolve. This makes the callback drivable by the
    obligation compiler without per-contract special-casing.

    require()s inside callback bodies are KEPT -- the bug we want to localize
    manifests when a require becomes satisfiable in the exposed phase, so
    stripping it would over-approximate."""
    # Emit a wrapper for every public/external function that WRITES storage
    # (except the exposed function itself), not just the conservative closure.
    # The conservative closure only contains functions that write the exposed
    # function's own storage; but a callback exploit can also be a function that
    # writes a DIFFERENT variable the invariant depends on (e.g. a flash-loan's
    # depositDuringCallback inflates totalAssets while cash+loans is unchanged).
    # The LLM legitimately places such a function in its plan closure, so the
    # harness must expose a wrapper for it or OBL_cb_<g> fails to compile. Extra
    # wrappers are harmless: the compiler only builds OBL_cb for plan-closure
    # members, and view/pure functions (empty writes) are excluded here.
    # Writes are counted transitively, through internal calls. The closure
    # already is: a standard ERC20 `transfer` writes nothing itself and does
    # all its work in `_transfer`, so it is in the closure yet had no direct
    # writes, and no wrapper was built for it. The conformance check then
    # rejected the harness for a missing function -- the most common reason
    # deployed contracts failed before any obligation ran.
    def _writes(name, info):
        tw = getattr(facts, "transitive_writes", None)
        return tw(name) if tw else info.writes
    writing_fns = sorted(
        name for name, info in facts.functions.items()
        if info.visibility in ("public", "external") and _writes(name, info))
    wrappers = []
    for g in writing_fns:
        if g == "<fallback>":
            _fb = _extract_special_body(contract_src)
            if _fb is None:
                continue
            wrappers.append(
                f"    /// Closure callback: wraps the fallback so "
                f"OBL_cb_{wrapper_name(g)} can drive it.\n"
                f"    function {wrapper_name(g)}(uint256 amount) public {{\n"
                f"{_clean_chunk(_fb, keep_requires=True).replace('msg.value', 'amount')}"
                f"\n    }}\n")
            continue
        # The site function is wrapped too. Re-entering the very function that
        # made the call is the classic reentrancy pattern, and without a
        # wrapper the compiler had nothing to build OBL_cb_<site> from -- on a
        # contract whose closure is only that function, nothing checked the
        # callback guarantee at all and the run still reported VERIFIED.
        # Its wrapper models one re-entrant execution: the external call
        # inside it is made atomic, as for any other closure member.
        body = _extract_function_body(contract_src, g)
        if body is None:
            continue
        cleaned = _clean_chunk(body, keep_requires=True)
        # msg.value is illegal in a non-payable wrapper; the harness models the
        # ETH amount via the uniform `amount` param, so rewrite msg.value->amount.
        cleaned = cleaned.replace("msg.value", "amount")
        cleaned = _neutralize_returns(cleaned)
        bindings = _param_bindings(contract_src, g)
        wrappers.append(
            f"    /// Closure callback: wraps {g} so OBL_cb_{g} can drive it.\n"
            f"    function {g}(uint256 amount) public {{\n"
            f"{bindings}"
            f"{cleaned}\n"
            f"    }}")
    return "\n\n".join(wrappers) if wrappers else "    // (no closure callbacks)"


def _receiver_start(text: str, dot: int) -> int:
    """Start of the receiver expression ending just before `text[dot]`."""
    i = dot - 1
    while i >= 0:
        c = text[i]
        if c in ")]":
            # an index closes with `]` the same way a call closes with `)`:
            # without this `_rOwned[sender].sub(x)` had an empty receiver, the
            # SafeMath rewrite gave up, and the balance update was dropped
            close, open_ = c, "(" if c == ")" else "["
            depth = 0
            while i >= 0:
                if text[i] == close:
                    depth += 1
                elif text[i] == open_:
                    depth -= 1
                    if depth == 0:
                        break
                i -= 1
            i -= 1
            continue
        if c.isalnum() or c in "_.":
            i -= 1
            continue
        break
    return i + 1


def _call_end(text: str, pos: int) -> int:
    """End (exclusive) of a call that starts its options or arguments at pos."""
    i = pos
    while i < len(text) and text[i] in " \t\n":
        i += 1
    if i < len(text) and text[i] == "{":
        depth = 0
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    i += 1
                    break
            i += 1
        while i < len(text) and text[i] in " \t\n":
            i += 1
    if i < len(text) and text[i] == "(":
        depth = 0
        while i < len(text):
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
    return -1


_LOWLEVEL = re.compile(r"\.\s*(call|delegatecall|staticcall|send|transfer)\s*(?=[({])")


def _atomize_external_calls(text: str) -> str:
    """Replace low-level calls in closure wrappers by their successful result.

    The model is depth-one: a closure member runs atomically, without handing
    control on. A low-level call inside one is, to SMTChecker, unknown code
    that may call back into the harness -- including the harness's own
    beginExposed and depositFor, which the real contract does not have. On
    WAsgard that alone refuted the callback obligation; the same obligation
    with the call removed verified. So each call becomes the value a
    successful call returns, keeping the statement well-formed, and a call
    standing alone as a statement is removed. The ETH-model debit placed
    before it is left in place, since the ETH still leaves. Whether a member
    that yields control is within the model is the nesting gate's decision,
    which turns such a proof into UNKNOWN rather than VERIFIED.
    """
    out = text
    for m in reversed(list(_LOWLEVEL.finditer(out))):
        kind = m.group(1)
        end = _call_end(out, m.end())
        if end < 0:
            continue
        if kind == "transfer":
            # an ERC20 transfer takes two arguments; ETH transfer takes one
            args = out[out.index("(", m.end()):end]
            if "," in args:
                continue
        start = _receiver_start(out, m.start())
        before = out[:start].rstrip()
        after = out[end:].lstrip()
        standalone = (before.endswith((";", "{", "}")) or before == "") \
            and after.startswith(";")
        if standalone:
            semi = out.index(";", end)
            out = out[:start] + "/* external call excised */" + out[semi + 1:]
            continue
        repl = "true" if kind in ("send", "transfer") else '(true, bytes(""))'
        out = out[:start] + repl + out[end:]
    return out


def _neutralize_returns(body: str) -> str:
    """Make a copied body legal inside a wrapper that declares no return type.

    `return true;` from an ERC20 `transfer` does not compile in a function with
    no `returns` clause. A returned call is kept as a statement, since the call
    may write state; a returned plain value becomes a bare `return;`, which
    leaves the function at the same point without a value to return.
    """
    def repl(m):
        expr = m.group(1).strip()
        if "(" in expr:
            # keep the call for its effects, and still leave the function:
            # dropping the return let an early exit fall through
            return f"{{ {expr}; return; }}"
        return "return;"
    return re.sub(r"\breturn\s+([^;]+);", repl, body)


def _isolate_returns(body: str, helper: str):
    """(body, helper function) with any `return` confined to the helper.

    A phase body is followed by the harness's own ledger updates -- closing the
    window, settling the ghost. A `return` copied into the body would exit
    before them and leave the harness in a state the original never reaches.
    When the body contains one, it becomes an internal function called in its
    place, so the return leaves the body and the ledger still runs. Bodies
    without a return are left exactly as they were.
    """
    if not re.search(r"\breturn\b", body):
        return body, ""
    fn = (f"\n    function {helper}(uint256 amount) internal {{\n"
          f"{_neutralize_returns(body)}\n    }}\n")
    return f"        {helper}(amount);", fn


def _binding_value(ptype: str, base: str, structs: frozenset = frozenset(),
                   nth: int = 0):
    """A value of type `ptype` derived from the wrapper's `uint256 amount`.

    Every original parameter is bound inside a uniform `(uint256 amount)`
    wrapper, so the binding has to convert rather than assign: `uint16 x =
    amount;` and `uint256[] memory a = amount;` both parse but neither
    typechecks. Narrower integers are truncated explicitly, reference types get
    an empty value, and anything unmodelled is left default-initialised, which
    keeps the harness an over-approximation.
    """
    arr = "[" in ptype
    if arr:
        inner = ptype.split("[")[0].strip()
        if ptype.rstrip().endswith("]") and \
                re.search(r"\[\s*\d+\s*\]$", ptype.strip()):
            return None
        return "new %s[](0)" % inner
    if base in ("bytes", "string"):
        return '""'
    if re.fullmatch(r"bytes([1-9]|[12]\d|3[0-2])", base):
        return "%s(bytes32(amount))" % base if base != "bytes32" \
            else "bytes32(amount)"
    if base == "bool":
        return "amount != 0"
    if base.startswith("address"):
        # Distinct addresses for distinct parameters. Binding both of
        # `transferFrom(address sender, address recipient, ...)` to the same
        # value makes every callback a self-transfer, which preserves any sum
        # invariant and would let the obligation pass for the wrong reason.
        expr = ("address(uint160(amount))" if nth == 0
                else f"address(uint160(amount) ^ {nth})")
        return f"payable({expr})" if "payable" in ptype else expr
    if base == "uint256" or base == "uint":
        return "amount"
    if re.fullmatch(r"uint\d*", base):
        return "%s(amount)" % base
    if re.fullmatch(r"int\d*", base):
        return "%s(int256(amount))" % base if base != "int256" \
            else "int256(amount)"
    if base in structs:
        return None
    return None


_ARG_VARS: dict = {}


def _argument_var(fname: str, pname: str, ptype: str, base: str):
    """A harness variable standing for one value-typed parameter.

    Every parameter but the first uint used to be computed from `amount`:
    `sender = address(uint160(amount))`, `recipient = ... ^ 1`, a second uint
    equal to amount, a bool `amount != 0`. That checked only the calls whose
    arguments are those functions of the amount -- a transfer of 100 tokens
    came only from address(100) -- so a proof skipped nearly every real call.
    A variable the solver may set to anything before the call covers every
    combination, and drops the bit-level `^` that made transferFrom obligations
    time out."""
    t = None
    if base.startswith("address"):
        t = "address payable" if "payable" in ptype else "address"
    elif base == "bool" or re.fullmatch(r"u?int\d*|bytes([1-9]|[12]\d|3[0-2])", base):
        t = base
    if t is None or "[" in ptype:
        return None
    key = (fname, pname, t)
    if key not in _ARG_VARS:
        _ARG_VARS[key] = (f"__a{len(_ARG_VARS)}_{pname}", t)
    return _ARG_VARS[key][0]


def _argument_state() -> str:
    if not _ARG_VARS:
        return ""
    decls = "".join(f"\n    {t} public {n};" for n, t in _ARG_VARS.values())
    pairs = [(t.replace(" payable", ""), n) for n, t in _ARG_VARS.values()]
    return decls + "\n" + _havoc_functions("__havoc_arg", pairs)


def _param_bindings(src: str, fname: str) -> str:
    """Emit local declarations that bind the original parameters of `fname` so
    its inlined body compiles inside a uniform `(uint256 amount)` wrapper.

    The first uint-typed parameter is aliased to `amount`; any other parameter
    is given a neutral harness-local default keyed by type. Returns the binding
    lines (possibly empty) with trailing newline, ready to prepend to the body."""
    params = _parse_params(src, fname)
    if not params:
        return ""
    lines = []
    aliased_amount = False
    addr_seen = 0
    for ptype, pname in params:
        base = ptype.split()[0]  # strip 'memory'/'calldata'/'payable'
        decl = ptype
        if ("[" in ptype or base in ("bytes", "string")) and \
                not re.search(r"\b(memory|storage|calldata)\b", ptype):
            decl = ptype + " memory"
        if base in ("uint256", "uint") and not aliased_amount:
            aliased_amount = True
            if pname != "amount":
                lines.append(f"        {decl} {pname} = amount;")
            continue
        val = _argument_var(fname, pname, ptype, base)
        if val is None:
            val = _binding_value(ptype, base, nth=addr_seen)
        if base.startswith("address"):
            addr_seen += 1
        if val is None:
            lines.append(f"        {decl} {pname};")
        else:
            lines.append(f"        {decl} {pname} = {val};")
    return ("\n".join(lines) + "\n") if lines else ""


def _parse_params(src: str, fname: str) -> list[tuple[str, str]]:
    """Return [(type, name), ...] for the parameters of function `fname` in the
    contract source. Types keep leading qualifiers stripped to the base token."""
    # The parameters of the definition whose body is copied: the last one that
    # has a body. Taking the first match picked the interface declaration --
    # `transferFrom(address recipient, uint256 amount)` in IERC20 -- while the
    # body came from the real three-parameter definition, so `sender` was
    # copied into the wrapper with nothing to bind it.
    ms = list(re.finditer(rf"function\s+{re.escape(fname)}\s*\(([^)]*)\)"
                          rf"[^{{;]*\{{", src))
    if not ms:
        ms = list(re.finditer(rf"function\s+{re.escape(fname)}\s*\(([^)]*)\)",
                              src))
    if not ms:
        return []
    m = ms[-1]
    raw = m.group(1).strip()
    if not raw:
        return []
    out = []
    for part in raw.split(","):
        toks = part.split()
        if len(toks) >= 2:
            ptype = toks[0]            # base type (uint256, address, bool, ...)
            pname = toks[-1]           # parameter name
            out.append((ptype, pname))
    return out


def _extract_function_body(src: str, fname: str) -> str | None:
    """Body of the implementation of `fname`, or None if there is none.

    A flattened source declares the same function several times: once in an
    interface, with no body, then in a base contract, then perhaps overridden.
    The signature is matched only up to its opening brace -- `[^{;]*`, so a
    bodiless declaration ending in `;` is not taken for a definition and run
    on into whatever brace comes next. Of the definitions that remain, the
    last is used: flattening emits bases before the contracts deriving from
    them, so the last is the most-derived, which is the one that executes.
    """
    last = None
    for m in re.finditer(
            rf"\bfunction\s+{re.escape(fname)}\s*\([^)]*\)\s*[^{{;]*{{", src):
        last = m
    if last is None:
        return None
    start = last.end()
    depth, i = 1, start
    while i < len(src) and depth > 0:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
        i += 1
    return src[start:i - 1]
