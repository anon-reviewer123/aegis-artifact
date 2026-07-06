"""
backend.py - Module 7: the REAL verification backend (solc SMTChecker).

For each compiled Obligation, we write its standalone harness to a temp file
and invoke:
    solc --model-checker-engine chc \
         --model-checker-targets assert \
         --model-checker-timeout <ms> \
         <file>
SMTChecker's CHC engine either proves the single `assert` in the Obligation
contract or reports a counterexample. We parse stdout/stderr to classify each
obligation as verified / failed (with counterexample) / unknown (timeout or
unsupported).

If solc is NOT installed, we DO NOT silently fake success. We return status
"no_backend" for every obligation and the pipeline reports UNAVAILABLE, never
VERIFIED. This is the fix for the earlier 'simulation rubber-stamp' problem:
a result is only ever VERIFIED when a real solver discharged it.
"""
from __future__ import annotations
from dataclasses import dataclass, field
import os
import re
import shutil
import subprocess
import tempfile


@dataclass
class ObligationResult:
    name: str
    module: str
    status: str               # "verified" | "failed" | "unknown" | "no_backend"
    detail: str = ""
    counterexample: str = ""


def solc_available() -> bool:
    return shutil.which("solc") is not None

def _resolve_solc_for(source: str) -> str:
    """Pick the solc binary whose version matches the harness's pragma, reusing
    the same artifact-resolution the AST analyzer uses. This avoids the
    PATH-shadow problem where a stray solc (e.g. 0.8.26) compiles a harness that
    pins a different version (e.g. 0.8.30) and fails at the model-checker step."""
    try:
        from .ast_analysis import _required_solc_version, _solc_binary_for
        return _solc_binary_for(_required_solc_version(source))
    except Exception:
        return "solc"



_HEALTH_CACHE: dict[str, bool] = {}


def solc_healthy() -> bool:
    """True only if solc is on PATH AND actually compiles a trivial contract.
    A stale solc-select shim that cannot fetch its binary is NOT healthy; we
    must treat it as no-backend rather than emit misleading UNKNOWNs forever."""
    if "ok" in _HEALTH_CACHE:
        return _HEALTH_CACHE["ok"]
    if not solc_available():
        _HEALTH_CACHE["ok"] = False
        return False
    probe = ("// SPDX-License-Identifier: MIT\npragma solidity >=0.8.0;\n"
             "contract P { function f() public pure returns (uint){ return 1; } }\n")
    try:
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "P.sol")
            open(p, "w").write(probe)
            r = subprocess.run(["solc", "--bin", p],
                               capture_output=True, text=True, timeout=60)
        # Healthy = solc exited cleanly and actually produced bytecode.
        # We do NOT fail on the word "Error" in warnings; a real failure shows
        # up as a non-zero return code or absent bytecode.
        ok = (r.returncode == 0
              and "Forbidden" not in (r.stderr + r.stdout)
              and "Binary:" in r.stdout)
    except Exception:
        ok = False
    _HEALTH_CACHE["ok"] = ok
    return ok


def check_obligation(name: str, module: str, harness_source: str,
                     timeout_ms: int = 0,
                     ext_calls: str = "trusted") -> ObligationResult:
    if not solc_healthy():
        return ObligationResult(name, module, "no_backend",
                                "no working solc on PATH; install solc 0.8.26")
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "Obligation.sol")
        with open(path, "w") as fh:
            fh.write(harness_source)
        solc_bin = _resolve_solc_for(harness_source)
        try:
            proc = subprocess.run(
                [solc_bin,
                 "--model-checker-engine", "chc",
                 "--model-checker-targets", "assert",
                 # Eldarica is the Horn solver that actually works here; solc's
                 # bundled z3 binding needs a specific libz3.so that is often
                 # missing. Eldarica is Java-based and has no .so dependency.
                 "--model-checker-solvers", os.environ.get("AEGIS_SOLVER", "eld"),
                 # Mode is per-obligation: "trusted" lets CHC reason about
                 # the harness's own `new Contract(...)`; "untrusted" lets the
                 # external callback re-enter any public fn (classic reentrancy).
                 "--model-checker-ext-calls", ext_calls,
                 "--model-checker-timeout", str(timeout_ms),
                 "--model-checker-show-unproved",
                 path],
                capture_output=True, text=True,
                # Eldarica IGNORES --model-checker-timeout, so enforce a REAL
                # wall-clock kill here: timeout_ms + 5s margin, or 120s default.
                timeout=((timeout_ms/1000.0 + 5) if timeout_ms > 0 else 120),
            )
        except subprocess.TimeoutExpired:
            return ObligationResult(name, module, "unknown",
                                    "solc wall-clock timeout")
        out = (proc.stdout or "") + "\n" + (proc.stderr or "")
        return _classify(name, module, out)


def _classify(name: str, module: str, out: str) -> ObligationResult:
    # (0) The solver must actually be present and enabled. solc 0.8.x prints
    # these warnings when no Horn solver (z3/Eldarica) is available, in which
    # case the CHC engine runs NOTHING -- absence of a violation then means
    # "not checked", NOT "safe". Treat as no_backend so the pipeline reports
    # UNAVAILABLE rather than a false VERIFIED.
    solver_missing = (
        "no Horn solver was found" in out
        or "was selected for SMTChecker but it is not available" in out
        or "CHC analysis was not possible" in out
        or "None of the installed solvers" in out)
    if solver_missing:
        return ObligationResult(name, module, "no_backend",
                                "SMTChecker has no working Horn solver "
                                "(install z3 matching solc, or Eldarica)")

    # (1) Compile errors mean the harness is malformed -> unknown.
    if re.search(r"Error:", out) and "Assertion" not in out:
        first = next((ln for ln in out.splitlines() if "Error:" in ln), "")
        return ObligationResult(name, module, "unknown",
                                f"solc compile error: {first.strip()[:160]}")

    # (2) Explicit assertion violation -> failed (with counterexample).
    has_violation = (("Assertion violation happens here" in out
                      or "CHC: Assertion violation" in out)
                     and "might happen here" not in out)
    if has_violation:
        cex = _extract_counterexample(out)
        return ObligationResult(name, module, "failed",
                                "SMTChecker found an assertion violation", cex)

    # (3) Explicit "could not prove" -> unknown.
    has_unproved = ("might happen here" in out
                    or "could not be proved" in out
                    or "Assertion checker does not yet support" in out)
    if has_unproved:
        return ObligationResult(name, module, "unknown",
                                "SMTChecker could not prove (timeout/unsupported)")

    # (4) PROVED SAFE. Calibrated against real solc 0.8.x + Eldarica output:
    # when CHC proves the assertion, solc emits "Compiler run successful"
    # and says NOTHING about the assertion (no violation, no "could not be
    # proved"). This is sound to treat as verified ONLY because we have
    # already excluded, above: (0) no working solver, (2) a violation, and
    # (3) an explicit could-not-prove. So reaching here with a clean success
    # line means the CHC engine ran and raised no target -> proved safe.
    clean_success = ("Compiler run successful" in out
                     or "0 verification conditions could not be proved" in out
                     or "proved safe!" in out
                     or re.search(r"\d+ verification condition.*proved safe",
                                  out, re.I) is not None
                     or re.search(r"all \d+ verification conditions.*safe",
                                  out, re.I) is not None)
    # Guard: there must be no leftover negative signal we failed to catch.
    # (Steps 2-3 already caught real violations/unproved; this is belt-and-
    # suspenders against phrasings we might have missed. We do NOT block on
    # every "Warning: CHC" because benign trusted-mode deployment notes use
    # that prefix too.)
    no_negative = ("Assertion violation" not in out
                   and "could not be proved" not in out
                   and "might happen here" not in out)
    if clean_success and no_negative:
        return ObligationResult(name, module, "verified",
                                "SMTChecker (CHC/Eldarica) proved the assertion safe")

    # (5) Anything else: we did NOT get positive proof -> unknown, never verified.
    snippet = " ".join(out.split())[:160]
    return ObligationResult(name, module, "unknown",
                            f"no positive proof from solc (output: {snippet})")


def _extract_counterexample(out: str) -> str:
    # SMTChecker prints a "Counterexample:" block with variable values.
    m = re.search(r"Counterexample:(.*?)(?:\n\n|\Z)", out, re.S)
    if m:
        return m.group(1).strip()[:400]
    # fall back to the line(s) around the violation
    for i, ln in enumerate(out.splitlines()):
        if "Assertion violation" in ln:
            return ln.strip()[:200]
    return ""


def run(obligations, timeout_ms: int = 0) -> list[ObligationResult]:
    """Check every obligation. `obligations` is a list of compiler.Obligation."""
    results = []
    for ob in obligations:
        results.append(check_obligation(ob.name, ob.module,
                                        ob.harness_source, timeout_ms,
                                        getattr(ob, "ext_calls", "trusted")))
    return results
