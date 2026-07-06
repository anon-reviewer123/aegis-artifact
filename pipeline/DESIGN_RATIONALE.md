# Aegis design rationale (reviewer-facing answers)

Every non-obvious choice below is justified by the structure of *callback
verification*, not by analogy to any external tool. Cobblestone is cited only
as motivation for the general principle "preserve validated partial work and
repair locally"; the mechanisms here are derived from our own problem.

## Q. Why an MCVP with exactly these modules?
Because proving a property under adversarial callbacks requires answering a
fixed set of questions that a stable-boundary invariant cannot: which functions
can re-enter (closure), in what order (protocol), where the callback window
begins and ends (phases), what abstract quantity explains mid-operation state
(ghost state), what must hold *during* exposure (exposure invariant), and how
the phase guarantees chain to the target (composition). Each module is one of
these questions. Dropping any one leaves a real callback behavior unmodelled
(unsoundness) or the proof inexpressible.

## Q. Why is the exposure invariant separate from (and weaker than) the stable invariant?
Because the contract is, by construction, in a partially-updated state during
the callback window. `totalAssets == totalShares` is *false* mid-withdrawal and
is the wrong fact to assert at the callback-entry point. The correct fact,
`totalAssets == totalShares + inFlight`, accounts for the committed-but-unsettled
withdrawal. This distinction is the technical core of the work; it is what makes
the verification "callback-native" rather than boundary-only.

## Q. Why is the LLM allowed to be wrong? Where does soundness come from?
The LLM only *proposes* an MCVP. Soundness rests on two non-LLM components:
(1) the conservative-closure gate in `validator.py`, which rejects any plan
whose closure is not a superset of the statically-computed over-approximation
(every public/external function touching exposed storage); and (2) the backend,
which discharges every compiled obligation. A plan is VERIFIED only when both
pass. Therefore no LLM error can produce a false VERIFIED. This is the premise
of our soundness theorem and is independent of LLM quality.

## Q. Why a fixpoint loop and not one-shot generation or tree recursion?
The seven modules are interdependent (see `depgraph.py`). Repairing the
exposure invariant re-opens every callback-preservation obligation (a callback
must preserve the *new* I_exp); repairing the closure re-opens the composition
obligation (composition assumes the closure is complete). A single pass cannot
account for these induced re-checks. We therefore iterate, marking the
dependents of each repaired module "dirty," until a fixpoint where every
obligation is discharged and nothing remains dirty. We deliberately do NOT use
tree recursion: the modules are a flat dependency DAG, not nested subgoals, so
graph reachability over dependency edges — not recursion depth — is the correct
propagation rule. Termination follows from the finite module set and a bounded
round budget.

## Q. Why localize failures to a single module instead of regenerating the whole plan?
Because the obligations are phase- and callback-local, each attributes to
exactly one responsible module. Regenerating the whole plan on any failure
would discard modules already soundly discharged by the backend, wasting LLM
budget and destabilizing a partially-correct plan. Localization keeps verified
work and repairs only what failed — the efficiency claim our ablations measure.

## Q. Why sample k candidate plans?
Diversity is an efficiency device, not a soundness device: a better first guess
shortens the fixpoint. Each candidate is still gated and checked identically, so
k affects cost (rounds, repairs, LLM tokens), never correctness. The k=1 vs k>1
comparison is a clean ablation.

## Q. Why split withdraw into phases in the harness?
The harness exposes the pre/exposed/post phases as independently invokable units
so the backend can discharge each A/G obligation in isolation (pre establishes
I_exp; each callback preserves I_exp; post restores I_stable). This is a
proof-modeling presentation of the real mid-function external call; the analyzed
contract (`MotivatingVault.sol`) contains the genuine mid-function callback. The
paper must state this modeling step explicitly.

## Q. What are the honest limitations (state these before a reviewer finds them)?
- The static analyzer is regex-based in this prototype; the solc-AST path is
  stubbed. Production soundness needs the real AST walk (inheritance, modifiers,
  assembly). The conservative closure is only as sound as the analyzer feeding
  it — this is the gating assumption of the soundness theorem.
- Scope is bounded-depth callbacks, integer arithmetic, ERC-777/1155/flash-loan
  patterns. No delegatecall-heavy or inline-assembly contracts yet.
- The simulation backend must be replaced by real solc/SMTChecker (or Certora)
  before any numbers are reported.

## Q. Why a real solc-AST analyzer, and what does it change vs. regex?
The soundness theorem requires the conservative closure to be a TRUE
over-approximation of callback-reachable functions. A regex scan cannot
guarantee that on real contracts: it misses state written inside MODIFIERS,
state INHERITED from base contracts (resolved via solc's
linearizedBaseContracts), MULTIPLE external-call sites per function, and
storage reached through index/member access. The AST analyzer
(`ast_analysis.py`) walks solc's compact JSON to handle all of these. The
pipeline records which analyzer ran (`static_analysis.LAST_ANALYZER`); a
SOUNDNESS claim is only valid for facts produced by the "ast" analyzer. The
regex analyzer is retained solely as a best-effort fallback so the framework
still executes (reporting "regex", and never claiming soundness) in
environments without a working solc. The fixture tests in `tests/test_ast.py`
lock in the inheritance/modifier/ordering behavior independently of any solc
install.

## Q. Why does the corpus include inherited-state and buggy contracts?
InheritedVault places accounting state in a base contract, exercising the AST
analyzer's inheritance resolution (a regex would only find it by accident in a
single-file case and would fail across imports). BuggyVault omits the
post-phase `inFlight` settlement so the stable invariant is genuinely not
restored; with a real solver, Aegis returns BUG_FOUND on OBL_post with a
counterexample, demonstrating that BUG_FOUND reflects a real refutation, not a
heuristic.
