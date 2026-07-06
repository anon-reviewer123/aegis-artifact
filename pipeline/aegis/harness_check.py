"""
harness_check.py - Enforce the harness interface contract.

The obligation compiler assumes every harness contract <Name>H exposes a
specific interface: required functions (depositFor, beginExposed, endExposed,
plus a callable per closure callback) and required public state vars
(totalAssets / totalShares-style accounting + the inFlight ghost + exposed
flag). HARNESS_INTERFACE.md documents this; this module ENFORCES it.

Without enforcement, a non-conforming harness would silently produce broken
obligations: solc would either fail to compile (caught by the backend) or, in
the worst case, produce compiling-but-meaningless obligations that pass
vacuously. Both outcomes are unacceptable for soundness.

The check is fail-loud: if the harness does not conform, the pipeline reports
HARNESS_NONCONFORMING with a precise diagnostic and refuses to verify.
"""
from __future__ import annotations
from dataclasses import dataclass, field
import re


@dataclass
class HarnessReport:
    conforming: bool
    contract_name: str
    found_functions: set
    found_state_vars: set
    missing_functions: list = field(default_factory=list)
    missing_state_vars: list = field(default_factory=list)
    diagnostic: str = ""


# Required INTERFACE -- the contract a harness signs by being a harness.
# These are the structural requirements that make the obligation compiler work,
# not domain hardcoding: every callback-verification harness must expose its
# phase entry points and its accounting state for SMTChecker.
REQUIRED_FUNCTIONS = {"depositFor", "beginExposed", "endExposed"}
# State vars required by every obligation harness regardless of contract.
REQUIRED_STATE_VARS = {"inFlight", "exposed"}
# Plus: the obligation references the variables named in the plan's invariant
# and target, which must also be public state vars. Those are CONTRACT-SPECIFIC
# and checked separately via check_against_plan().


def check_harness(harness_src: str, closure_functions: list,
                  exposed_function: str | None = None,
                  required_ghost_vars: list | None = None) -> HarnessReport:
    """Static conformance check on the harness source. Verifies:
      (1) the harness defines a contract;
      (2) it declares the required functions (depositFor, begin/endExposed);
      (3) it declares one callable per closure callback;
      (4) it declares the required public ghost/flag state vars.

    `exposed_function` is the function split into begin/endExposed (so it is not
    required as a standalone callable). `required_ghost_vars` lets the caller
    pass the plan's actual ghost + flag names instead of the vault defaults,
    making the check contract-agnostic. Does NOT execute the harness.
    """
    cname_match = re.search(r"\bcontract\s+([A-Za-z_]\w*)", harness_src)
    contract_name = cname_match.group(1) if cname_match else "?"

    # Functions: capture every `function <name>` defined at top level.
    found_functions = set(re.findall(r"\bfunction\s+([A-Za-z_]\w*)\s*\(",
                                     harness_src))
    # Public state vars: capture `<type> public <name>` declarations.
    found_state_vars = set()
    for m in re.finditer(
            r"\b(?:u?int\d*|bool|address|mapping\s*\([^)]+\))\s+public\s+"
            r"([A-Za-z_]\w*)", harness_src):
        found_state_vars.add(m.group(1))

    # Check (2): required interface functions
    missing_fn = sorted(REQUIRED_FUNCTIONS - found_functions)

    # Check (3): every closure function EXCEPT the exposed function itself
    # (which is split into begin/endExposed) must have a callable in the harness.
    exposed = exposed_function or "withdraw"   # default keeps old behaviour
    closure_required = {f for f in closure_functions if f != exposed}
    closure_callable_missing = sorted(closure_required - found_functions)

    # Check (4): required ghost/flag state vars (plan-derived when supplied)
    required_vars = set(required_ghost_vars) if required_ghost_vars \
        else REQUIRED_STATE_VARS
    missing_sv = sorted(required_vars - found_state_vars)

    all_missing_fn = missing_fn + closure_callable_missing
    if not all_missing_fn and not missing_sv:
        return HarnessReport(
            conforming=True, contract_name=contract_name,
            found_functions=found_functions, found_state_vars=found_state_vars,
            diagnostic="harness conforms to interface")

    parts = []
    if all_missing_fn:
        parts.append(f"missing required functions: {all_missing_fn}")
    if missing_sv:
        parts.append(f"missing required public state vars: {missing_sv}")
    return HarnessReport(
        conforming=False, contract_name=contract_name,
        found_functions=found_functions, found_state_vars=found_state_vars,
        missing_functions=all_missing_fn, missing_state_vars=missing_sv,
        diagnostic=("HARNESS NON-CONFORMING: " + "; ".join(parts) +
                    f"  (see contracts/HARNESS_INTERFACE.md)"))


def check_against_plan(harness_src: str, plan_storage_idents: set) -> list:
    """Plan-specific check: every identifier the MCVP's invariant or target
    references must be a public state var in the harness (so the obligation
    compiler's v.<var>() rewrite resolves). Returns a list of missing names."""
    found_state_vars = set()
    for m in re.finditer(
            r"\b(?:u?int\d*|bool|address|mapping\s*\([^)]+\))\s+public\s+"
            r"([A-Za-z_]\w*)", harness_src):
        found_state_vars.add(m.group(1))
    return sorted(plan_storage_idents - found_state_vars)
