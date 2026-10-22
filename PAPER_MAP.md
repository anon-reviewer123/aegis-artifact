
# AEGIS: Research Paper Structure and Artifact Mapping

This document maps the AEGIS implementation components to the corresponding sections of the research paper. It identifies the relevant modules, formal foundations, implementation mechanisms, and evaluation artifacts.

## Section 2: Approach — Assume-Guarantee Verification

AEGIS employs an assume-guarantee (A/G) verification framework for analyzing smart-contract security properties.

The module `aegis/assume_guarantee.py` constructs an explicit A/G decomposition consisting of:

- `A_cb`: Assumptions governing callback behavior.
- `G_pre`: Guarantees concerning preconditions.
- `G_exp`: Guarantees concerning execution behavior.
- `G_post`: Guarantees concerning postconditions.

The verification framework uses the following composition structure:

`A_cb => (G_pre /\ G_exp /\ G_post) => phi`

The A/G decomposition is represented explicitly in the verification output, enabling inspection of the assumptions, guarantees, and target security property.

### Specification Synthesis

The framework incorporates LLM-assisted synthesis of a Modular Callback Verification Plan (MCVP).

The synthesized specification is subsequently processed by deterministic analysis and verification components. The LLM-generated specification is treated as a candidate requiring independent validation rather than as an authoritative verification result.

## Section 2.x: Soundness and Trust Boundaries

AEGIS separates specification synthesis from formal verification.

The callback assumption `A_cb` is checked through the conservative closure gate implemented in `validator.py`.

The soundness argument relies on the following conditions:

1. The callback abstraction soundly over-approximates relevant concrete callback behaviors.
2. The validator establishes the required callback-closure conditions.
3. The verification backend discharges the corresponding guarantee obligations.
4. The composition conditions establish the target security property `phi`.

Under these conditions, the discharged obligations support the security conclusion.

The LLM is excluded from the trusted computing base (TCB). Verification conclusions depend on the validator, the generated verification conditions, and the formal backend rather than on the LLM's assertions.

### Verification Obligation Validation

The development process identified and corrected specification-level issues involving:

- The distinction between `>=` and `==` in `OBL_post`.
- A missing `inFlight == 0` condition.

These cases illustrate the importance of independently checking generated verification obligations.

## Section 3: Implementation

AEGIS integrates static program analysis, specification processing, verification-condition generation, and SMT-based verification.

### Formal Verification Backend

The verification backend uses:

- Solidity compiler (`solc`) SMTChecker.
- Constrained Horn Clause (CHC) reasoning.
- Eldarica Horn-clause solver.

### Static Program Analysis

The module `ast_analysis.py` processes Solidity abstract syntax trees to support:

- Resolution of inherited state variables.
- Analysis of state modifications introduced by modifiers.
- Identification of state updates and relevant call sites.
- Analysis of statement ordering around external interactions.

A regex-based fallback is available when Solidity compiler analysis is unavailable.

### Verification Condition Generation

The module `compiler.py` constructs verification harnesses for individual proof obligations.

Each harness isolates an assertion corresponding to a particular verification condition, allowing verification failures to be associated with specific A/G components.

## Section 4: Evaluation

The evaluation framework is organized around contract-level verification outcomes, specification refinement, proof-obligation discharge, and callback-closure analysis.

The module `run_corpus.py` provides structured execution results, including JSON-formatted output.

### Evaluation Metrics

| Metric | Description |
|---|---|
| Verification status | Contract classification as `VERIFIED`, `BUG_FOUND`, or `UNKNOWN` |
| Repair rounds | Number of refinement iterations performed |
| Total repairs | Number of specification repairs |
| Obligation discharge | Number of verified obligations relative to total obligations |
| Callback closure size | Number of callbacks represented by the computed closure |

### Evaluation Dimensions

The evaluation methodology covers the following aspects.

**Verification effectiveness:** Measurement of verification outcomes across the benchmark corpus.

**Modular specification refinement:** Analysis of repair iterations and their relationship to successful verification.

**Obligation-level verification:** Examination of discharge results for individual A/G components.

**Callback abstraction:** Analysis of closure size and its effect on verification.

**Specification synthesis:** Assessment of LLM-generated candidate specifications, including first-attempt verification and refinement requirements.

**Baseline comparison:** Comparison of alternative specification configurations, including coarse-grained, expert-defined, and modular verification plans.

The relevant evaluation results should be reported from recorded experimental executions and associated artifacts.

## Artifact-to-Section Mapping

| Paper component | Implementation artifact |
|---|---|
| Assume-guarantee decomposition | `aegis/assume_guarantee.py` |
| Callback closure validation | `validator.py` |
| Solidity AST analysis | `ast_analysis.py` |
| Verification harness generation | `compiler.py` |
| Corpus execution | `run_corpus.py` |
| Structured evaluation output | `run_corpus.py --json` |

## Reproducibility

Verification claims should be supported by executable inputs, recorded tool configurations, generated verification obligations, solver outcomes, and corresponding experiment artifacts.

The research artifact distinguishes candidate specifications, verification outcomes, and unsupported or inconclusive cases. A `VERIFIED` result requires successful discharge of the associated verification obligations under the applicable assumptions and validation conditions.
