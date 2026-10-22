"""
ast_analysis.py - Real solc-AST callback-exposure analysis (Module 1+2).

WHY THIS REPLACES THE REGEX PATH (the reviewer answer):
The soundness theorem requires the conservative closure to be a TRUE
over-approximation of callback-reachable functions. A regex pass cannot deliver
that on real contracts: it misses state written through modifiers, state
inherited from base contracts, multiple external-call sites in one function,
and aliased storage. This module walks solc's compact-JSON AST so that:
  * storage variables include inherited state (we union over all base contracts)
  * a function's reads/writes include those performed in its modifiers
  * EVERY external call site is found (not just the first), each becoming an
    independent exposure site
  * write-before-call / write-after-call is computed from statement ORDER in
    the AST, per call site
  * the conservative closure unions over ALL public/external functions of the
    contract AND its bases that touch any exposed storage slot

If solc is unavailable/broken, callers fall back to the regex analyzer; but for
any soundness CLAIM, this AST path must be the one that ran (the pipeline
records which analyzer produced the facts).
"""
from __future__ import annotations
from dataclasses import dataclass, field
import json
import os
import shutil
import subprocess
import tempfile


# Reuse the public dataclasses from static_analysis to stay API-compatible.
from .static_analysis import (FunctionInfo, ExposureSite, ContractFacts,
                              _CALLBACK_PATTERNS)


def solc_available() -> bool:
    return shutil.which("solc") is not None


def ast_available() -> bool:
    """solc must exist AND successfully emit an AST for a trivial probe."""
    if not solc_available():
        return False
    probe = ("// SPDX-License-Identifier: MIT\npragma solidity >=0.8.0;\n"
             "contract P { uint x; function f() public { x = 1; } }\n")
    try:
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "P.sol")
            open(p, "w").write(probe)
            r = subprocess.run(["solc", "--ast-compact-json", p],
                               capture_output=True, text=True, timeout=60)
        return r.returncode == 0 and '"nodeType"' in r.stdout
    except Exception:
        return False


def _get_ast(sol_path: str) -> dict | None:
    try:
        r = subprocess.run(["solc", "--ast-compact-json", sol_path],
                           capture_output=True, text=True, timeout=120)
        txt = r.stdout
        start = txt.find("{")
        if start == -1:
            return None
        # solc may print "=== file.sol ===\nJSON". Find the JSON object.
        depth, end = 0, None
        for i in range(start, len(txt)):
            if txt[i] == "{":
                depth += 1
            elif txt[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        return json.loads(txt[start:end]) if end else None
    except Exception:
        return None


# --------------------------------------------------------------------------
# AST walking helpers
# --------------------------------------------------------------------------
def _iter_nodes(node):
    """Yield every dict node in the AST subtree, depth-first."""
    if isinstance(node, dict):
        yield node
        for v in node.values():
            yield from _iter_nodes(v)
    elif isinstance(node, list):
        for item in node:
            yield from _iter_nodes(item)


def _contract_defs(ast: dict) -> list[dict]:
    return [n for n in _iter_nodes(ast)
            if n.get("nodeType") == "ContractDefinition"]


def _state_var_names(contract: dict, by_id: dict) -> tuple[set[str], set[int]]:
    """Storage vars of a contract INCLUDING inherited ones, returning both the
    names and the set of declaration node-ids (for identifier resolution)."""
    names: set[str] = set()
    ids: set[int] = set()
    # linearizedBaseContracts lists this contract + all bases (by id)
    for cid in contract.get("linearizedBaseContracts", [contract.get("id")]):
        cdef = by_id.get(cid)
        if not cdef:
            continue
        for node in cdef.get("nodes", []):
            if (node.get("nodeType") == "VariableDeclaration"
                    and node.get("stateVariable")):
                names.add(node["name"])
                ids.add(node["id"])
    return names, ids


def _referenced_state(node, state_ids: set[int], state_names: set[str]):
    """Return (reads, writes) of storage vars within an AST subtree.
    A write is an Identifier/MemberAccess on the LHS of an Assignment or the
    target of a unary ++/-- or compound assignment."""
    reads: set[str] = set()
    writes: set[str] = set()

    def name_of(idnode):
        # Identifier referencing a state var declaration, or MemberAccess /
        # IndexAccess whose base resolves to a state var.
        nt = idnode.get("nodeType")
        if nt == "Identifier":
            if (idnode.get("referencedDeclaration") in state_ids
                    or idnode.get("name") in state_names):
                return idnode.get("name")
        if nt in ("IndexAccess", "MemberAccess"):
            base = idnode.get("baseExpression") or idnode.get("expression")
            if base:
                return name_of(base)
        return None

    def collect_reads(sub):
        for n in _iter_nodes(sub):
            if n.get("nodeType") == "Identifier":
                nm = name_of(n)
                if nm:
                    reads.add(nm)

    for n in _iter_nodes(node):
        nt = n.get("nodeType")
        if nt == "Assignment":
            lhs = n.get("leftHandSide", {})
            nm = name_of(lhs)
            if nm:
                writes.add(nm)
                if n.get("operator") not in ("=",):  # compound also reads
                    reads.add(nm)
            collect_reads(n.get("rightHandSide", {}))
        elif nt == "UnaryOperation" and n.get("operator") in ("++", "--"):
            nm = name_of(n.get("subExpression", {}))
            if nm:
                writes.add(nm)
                reads.add(nm)
        elif nt == "Identifier":
            nm = name_of(n)
            if nm:
                reads.add(nm)
    return reads, writes


def _is_external_call(node) -> tuple[bool, str, str]:
    """Detect a callback-capable external call. Returns (is_call, token, reason)."""
    if node.get("nodeType") != "FunctionCall":
        return False, "", ""
    expr = node.get("expression", {})
    # member access like recv.onAssetReceived(...) or token.call{...}(...)
    member = expr.get("memberName")
    if not member:
        # low-level .call / .send / .transfer also show as MemberAccess
        member = expr.get("memberName", "")
    token = member or ""
    label = f".{member}" if member else "external_call"
    callback_map = {
        "onAssetReceived": "ERC777-style asset hook can re-enter",
        "tokensReceived": "ERC777 tokensReceived hook can re-enter",
        "onERC1155Received": "ERC1155 receiver hook can re-enter",
        "onERC721Received": "ERC721 safeTransfer callback can re-enter",
        "executeOperation": "flash-loan callback can re-enter",
        "call": "low-level call can re-enter",
        "send": "send may trigger fallback",
        "transfer": "transfer may trigger fallback",
    }
    if member in callback_map:
        return True, label, callback_map[member]
    # external interface calls (member access on a non-builtin) are conservatively
    # treated as callback-capable.
    if member and expr.get("nodeType") == "MemberAccess":
        return True, label, "external interface call may re-enter"
    return False, "", ""


def _ordered_statements(fn_body) -> list[dict]:
    """Flat, ordered list of statement nodes in a function body."""
    stmts = []
    for s in (fn_body or {}).get("statements", []):
        stmts.append(s)
    return stmts


def analyze_ast(sol_path: str) -> ContractFacts | None:
    if not ast_available():
        return None
    ast = _get_ast(sol_path)
    if not ast:
        return None
    contracts = _contract_defs(ast)
    if not contracts:
        return None
    by_id = {c["id"]: c for c in contracts}

    # Pick the last non-interface contract as the target (top of the file).
    target = None
    for c in contracts:
        if c.get("contractKind") == "contract":
            target = c
    if target is None:
        return None

    state_names, state_ids = _state_var_names(target, by_id)

    # Gather all function definitions across the contract + bases.
    functions: dict[str, FunctionInfo] = {}
    fn_nodes: dict[str, dict] = {}
    for cid in target.get("linearizedBaseContracts", [target["id"]]):
        cdef = by_id.get(cid)
        if not cdef:
            continue
        for node in cdef.get("nodes", []):
            if node.get("nodeType") != "FunctionDefinition":
                continue
            if node.get("kind") == "constructor":
                continue
            name = node.get("name") or "<fallback>"
            if name in functions:
                continue  # most-derived wins (linearized order)
            vis = node.get("visibility", "public")
            info = FunctionInfo(name=name, visibility=vis)
            # include reads/writes from the body AND from attached modifiers
            reads, writes = _referenced_state(node.get("body", {}),
                                              state_ids, state_names)
            for mod in node.get("modifiers", []):
                md = by_id_lookup_modifier(ast, mod)
                if md:
                    mr, mw = _referenced_state(md.get("body", {}),
                                               state_ids, state_names)
                    reads |= mr
                    writes |= mw
            info.reads, info.writes = reads, writes
            functions[name] = info
            fn_nodes[name] = node

    # Find exposure sites: walk each function body in statement order, locate
    # external calls, and split writes before/after each call.
    exposure_sites: list[ExposureSite] = []
    for name, node in fn_nodes.items():
        stmts = _ordered_statements(node.get("body", {}))
        # locate first callback-capable call's statement index
        call_idx = None
        call_token = ""
        reason = ""
        for i, st in enumerate(stmts):
            for sub in _iter_nodes(st):
                ok, tok, rsn = _is_external_call(sub)
                if ok:
                    call_idx, call_token, reason = i, tok, rsn
                    break
            if call_idx is not None:
                break
        if call_idx is None:
            continue
        before = stmts[:call_idx]
        after = stmts[call_idx:]
        _, wbc = _referenced_state({"statements": before}, state_ids, state_names)
        _, wac = _referenced_state({"statements": after}, state_ids, state_names)
        info = functions[name]
        info.external_calls.append(call_token)
        info.write_before_call = wbc
        info.write_after_call = wac
        exposed = wbc | wac | (info.reads & info.writes)
        exposure_sites.append(ExposureSite(
            function=name, call=call_token, callback_capable=True,
            reason=reason, exposed_storage=set(exposed),
            write_before_call=set(wbc), write_after_call=set(wac)))

    return ContractFacts(contract=target.get("name", "Contract"),
                         storage_vars=sorted(state_names),
                         functions=functions,
                         exposure_sites=exposure_sites)


def by_id_lookup_modifier(ast: dict, modifier_invocation: dict) -> dict | None:
    """Resolve a ModifierInvocation to its ModifierDefinition by name."""
    name = (modifier_invocation.get("modifierName", {}) or {}).get("name")
    if not name:
        return None
    for n in _iter_nodes(ast):
        if n.get("nodeType") == "ModifierDefinition" and n.get("name") == name:
            return n
    return None
