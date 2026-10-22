# Aegis -> paper section map (what to write tomorrow, from what the code emits)

The pipeline now emits the artifacts each section needs. You write prose around
real outputs; you do not invent anything.

## Sec 2 (Approach) -- the A/G core proposal
- `aegis/assume_guarantee.py` produces the EXPLICIT A/G decomposition printed on
  every VERIFIED run: A_cb (assumption), G_pre/G_exp/G_post (guarantees), and the
  composition theorem instance `A_cb => (G_pre /\ G_exp /\ G_post) => phi`.
  -> This rendered block IS your Approach figure. Paste it as a listing.
- The LLM synthesizes the MCVP from which this A/G triple is derived. That is the
  paper's one-sentence contribution: "the LLM synthesizes the assume-guarantee
  specification; a sound backend discharges it."

## Sec 2.x (Soundness) -- why the LLM is not trusted
- A_cb is discharged by the CONSERVATIVE CLOSURE GATE (`validator.py`), not the
  LLM. Theorem statement: if A_cb soundly over-approximates concrete callbacks
  (gate guarantees superset of static closure) and every guarantee obligation is
  discharged by the backend, then phi holds. The LLM never enters the TCB.
- Evidence it works: during bring-up the solver caught TWO specification bugs in
  our own obligations (OBL_post: `>=` vs `==`; missing `inFlight==0`). Document
  this in Threats/Discussion as evidence the backend is the real authority.

## Sec 3 (Implementation)
- Real solc SMTChecker (CHC engine) + Eldarica Horn solver.
- AST analyzer (`ast_analysis.py`) resolves inherited state + modifier writes +
  per-call-site ordering (regex fallback only when no solc).
- Per-obligation harnesses (`compiler.py`): one assert per VC, so failures
  localize to one A/G component.

## Sec 4 (Evaluation) -- RUN THESE TOMORROW, tabulate the output
RQ metrics already emitted by `run_corpus.py` (and `--json`):
  - status (VERIFIED / BUG_FOUND / UNKNOWN) per contract
  - repair_rounds, total_repairs  (RQ: does modular fixpoint repair help?)
  - obligations verified / total   (RQ: which A/G components discharge?)
  - callback_closure_size          (RQ: closure precision)
Still TODO by you (the real evaluation work, not codeable tonight):
  - GROW THE CORPUS (ERC-1155 hooks, flash-loan callbacks, cross-function
    reentrancy). 3 contracts is a demo, not an evaluation.
  - Run `--llm openai` with a REAL key for synthesis-quality numbers
    (first-try-verify rate vs repair-needed rate = your headline RQ).
  - Baselines: same backend with (a) no spec, (b) coarse spec, (c) expert spec,
    and monolithic-plan vs modular-plan ablation.

## The honest gap
Code is at Cobblestone's Section-2 level of completeness. Your Section 4 does
not exist yet and cannot be generated -- it requires running the corpus + LLM
and tabulating. That is tomorrow's work, and the harness is built for it.
