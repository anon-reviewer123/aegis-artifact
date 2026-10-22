"""
soundness.py - The formal soundness statement of the Aegis framework.

This module is the FORMAL ARTIFACT a reviewer expects in a verification paper:
the precise theorem about when a VERIFIED result implies the target property
holds, stated in terms the implementation can be cross-referenced against.

----------------------------------------------------------------------------
THEOREM (Aegis soundness for callback-exposed contracts).

  Let C be a Solidity contract with a callback-exposed function f, target
  property phi, and MCVP M = (closure, protocol, phases, ghost_state,
  exposure_invariant, composition) produced by Aegis. Let cons(C, f) denote
  the static conservative closure: the set of public/external functions of C
  that touch storage written before or after the external call site in f.

  Suppose:
    (A1)  cons(C, f)  is a sound over-approximation of dynamically-reachable
          callbacks during f's exposed phase  -- guaranteed by the static
          analyzer's reach over the AST + inheritance.
    (A2)  M.closure.functions  is a superset of cons(C, f)
          -- enforced by validator._check_closure_soundness.
    (A3)  M.protocol.allowed_callbacks  equals  M.closure.functions
          -- enforced by validator._check_protocol.
    (A4)  M.exposure_invariant  references every storage variable named in
          M.composition.target_property
          -- enforced by validator._check_exposure_invariant (non-triviality).
    (A5)  The backend (solc SMTChecker + Eldarica CHC) discharges every
          obligation:
              OBL_pre            : {I_stable} pre-phase {I_exp}
              OBL_cb_g           : {I_exp} g {I_exp}     for every g in M.closure
              OBL_post           : {I_exp} post-phase {I_stable /\\ inFlight==0}
              OBL_stable_implies : I_stable => phi      (when phi != I_stable)

  Then phi holds in every concrete execution of C.f, including all reentrant
  callback interleavings admitted by the closure.

PROOF SKETCH.

  The A/G composition theorem instantiates as:

        A_cb  =>  ( G_pre  /\\  G_exp  /\\  G_post )  =>  phi

  where A_cb is the assumption "callbacks confined to closure" (closed by A1+A2),
  and the G_i are the phase guarantees discharged in A5. Each piece:

  * G_pre  (from OBL_pre): pre-phase body establishes I_exp from I_stable.
  * G_exp  (from {OBL_cb_g}): every g in closure preserves I_exp; by A3 the
    protocol admits exactly these callbacks, so any concrete interleaving of
    re-entrant calls during exposure is a finite composition of preservation
    steps and hence preserves I_exp.
  * G_post (from OBL_post): post-phase restores I_stable from I_exp AND
    settles the in-flight ghost to 0, i.e. fully exits the exposed phase.
  * OBL_stable_implies (composition link): I_stable entails phi (trivial when
    phi = I_stable; otherwise discharged explicitly).

  Combining: at exit of C.f the contract state satisfies I_stable /\\ inFlight==0,
  and I_stable entails phi. QED.

----------------------------------------------------------------------------
THE TCB. The trusted computing base of an Aegis verification is exactly:

  * the static analyzer (ast_analysis.py) for (A1)
  * the validator (validator.py) for (A2), (A3), (A4)
  * the obligation compiler (compiler.py) -- its lowering must preserve A/G
    semantics
  * the backend (solc SMTChecker + Eldarica) for (A5)

The LLM is NOT in the TCB. The repair loop is NOT in the TCB. The dependency
graph is NOT in the TCB (a wrong edge can only cause useless re-checks, not
unsound acceptance). The corpus and the synthesis prompt are not in the TCB.

This is the analogue of Cobblestone's "sound despite unsound LLMs": Coq's
kernel is their TCB; ours is the static analyzer + validator + solver.
----------------------------------------------------------------------------
"""

# Machine-checkable companions: each assumption above is enforced by an
# identifiable function in the code. This list is the bridge between the
# theorem and the implementation.
ASSUMPTION_TO_ENFORCER = {
    "A1": ("aegis.ast_analysis.analyze_ast",
           "sound conservative closure derivation"),
    "A2": ("aegis.validator._check_closure_soundness",
           "closure superset of conservative closure"),
    "A3": ("aegis.validator._check_protocol",
           "protocol admissible set == closure"),
    "A4": ("aegis.validator._check_exposure_invariant",
           "invariant non-triviality wrt target property"),
    "A5": ("aegis.backend.check_obligation",
           "real solver discharges each obligation"),
}


def report() -> str:
    """Render the theorem + the assumption-to-code map. Reviewer-facing."""
    out = [__doc__.strip(), "", "ASSUMPTION -> ENFORCER:"]
    for a, (fn, desc) in ASSUMPTION_TO_ENFORCER.items():
        out.append(f"  ({a}) {fn}\n        {desc}")
    return "\n".join(out)


if __name__ == "__main__":
    print(report())
