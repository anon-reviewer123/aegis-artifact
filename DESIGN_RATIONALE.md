
# AEGIS: Design Rationale and Verification Architecture

## 1. Overview

AEGIS is designed to support modular assume-guarantee verification of smart contracts with adversarial callback behavior.

The framework represents callback-sensitive verification problems using a Modular Callback Verification Plan (MCVP). This representation decomposes verification into components addressing callback reachability, execution protocols, intermediate contract states, and composition of proof obligations.

The design emphasizes explicit verification assumptions, localized proof obligations, specification refinement, and separation between candidate specification synthesis and formal verification.

The framework also incorporates the principle of preserving previously validated components during iterative refinement. Related research on modular refinement, including Cobblestone, provides broader methodological context, while the MCVP structure is motivated by the requirements of callback-sensitive smart-contract analysis.

## 2. Modular Callback Verification Plan

The MCVP organizes callback verification into seven interdependent modules.

The modules address:

- Callback closure and reentrant function reachability.
- Callback execution protocols.
- Pre-exposure, exposure, and post-exposure phases.
- Ghost state representing intermediate accounting effects.
- Exposure invariants governing intermediate states.
- Composition of verification guarantees.
- Dependencies between verification components.

This decomposition enables the framework to express verification conditions that distinguish stable contract states from intermediate states exposed during external interactions.

The modules collectively represent information required by the verification procedure. Their sufficiency depends on the supported contract semantics and the soundness of the underlying analyses.

## 3. Exposure Invariants and Stable-State Invariants

Callback-sensitive contracts may enter intermediate states in which accounting updates are only partially completed.

A stable-state invariant may take the form:

`totalAssets == totalShares`

However, this relationship may not hold during an external callback occurring in the middle of a withdrawal operation.

To represent an outstanding withdrawal, the verification model introduces an auxiliary variable:

`inFlight`

The corresponding exposure invariant is:

`totalAssets == totalShares + inFlight`

This invariant accounts for the difference between stable accounting state and the intermediate state visible during callback execution.

The separation enables the verification framework to reason about intermediate contract states without requiring stable-state invariants to hold at every execution point.

The exposure invariant is intended to support reasoning across callback boundaries and subsequent restoration of stable-state properties.

## 4. Specification Synthesis and Soundness

AEGIS separates candidate specification generation from formal verification.

An LLM may propose an MCVP, but the proposed specification is not accepted solely on the basis of model output.

The verification process relies on two principal mechanisms:

1. Conservative callback-closure validation.
2. Formal discharge of generated verification obligations.

### 4.1 Conservative Callback-Closure Validation

The validator checks whether the candidate callback closure includes the functions identified by static analysis as potentially relevant to reentrant execution.

The implementation is associated with:

`validator.py`

For sound over-approximation, the underlying static analysis must conservatively represent the relevant callback-reachable behaviors under the modeled contract semantics.

A candidate specification that fails the required closure conditions is rejected.

### 4.2 Formal Verification Backend

Candidate plans that satisfy validation requirements are translated into formal verification obligations.

The backend is responsible for establishing whether those obligations hold under the specified assumptions and execution model.

A successful verification conclusion requires satisfaction of the applicable validation conditions and discharge of the required obligations.

### 4.3 Trust Boundaries

The LLM is not treated as an authoritative verification component.

The soundness of the overall result depends on:

- Correctness of the callback abstraction.
- Soundness of static program analysis.
- Correctness of validation rules.
- Faithfulness of verification-condition generation.
- Soundness of the formal backend.
- Adequacy of the modeled contract and execution semantics.

Consequently, the exclusion of the LLM from the trusted computing base does not eliminate assumptions associated with the remaining verification components.

## 5. Dependency-Aware Specification Refinement

The MCVP modules are interdependent.

The dependency structure is represented in:

`depgraph.py`

Modifying one module can invalidate verification obligations associated with dependent modules.

For example:

- Updating an exposure invariant requires reconsideration of callback-preservation obligations.
- Updating callback closure information requires reconsideration of composition assumptions.
- Changes to phase-related specifications may affect obligations associated with transitions between stable and exposed states.

AEGIS uses dependency-aware refinement to determine which verification components require reevaluation.

### 5.1 Refinement Procedure

The refinement procedure consists of:

1. Identifying an unsuccessful verification obligation.
2. Associating the obligation with the relevant specification module.
3. Updating the affected module.
4. Marking dependent obligations for reevaluation.
5. Rechecking the affected obligations.
6. Repeating the process until the required verification conditions are satisfied or the configured refinement budget is exhausted.

### 5.2 Dependency Propagation

The module dependency structure is represented as a directed acyclic graph.

Dependency propagation follows graph reachability rather than recursive decomposition into nested proof subgoals.

The refinement process uses a bounded iteration budget to control computational cost.

Because the process has a bounded number of rounds, individual executions terminate within that budget. This does not imply that all verification problems necessarily reach a successful fixpoint.

## 6. Localized Verification and Repair

AEGIS associates generated proof obligations with specific specification components.

This organization allows unsuccessful obligations to be identified and addressed without necessarily regenerating the entire MCVP.

Localized repair aims to:

- Preserve unaffected specification components.
- Reduce unnecessary candidate regeneration.
- Limit repeated LLM interactions.
- Maintain consistency between validated components.
- Reduce the computational cost of iterative refinement.

Previously discharged obligations may be reused when their assumptions and dependencies remain unchanged.

The effect of localized refinement on verification performance can be evaluated through comparisons with alternative regeneration strategies.

## 7. Candidate Sampling

AEGIS supports generation of multiple candidate verification plans.

The candidate count is controlled by the parameter `k`.

Candidate sampling is intended to increase the range of available specification proposals and reduce the number of subsequent refinement iterations when a suitable candidate is identified early.

All candidates are subject to the same validation and verification requirements.

The sampling parameter influences synthesis cost and the search process but does not independently establish correctness.

Comparisons between different values of `k` can be used to evaluate the relationship between candidate diversity, refinement requirements, and computational resources.

## 8. Phase-Based Verification Harnesses

AEGIS models callback-sensitive operations using separate execution phases.

The verification harness distinguishes:

- Pre-exposure phase.
- Callback exposure phase.
- Post-exposure phase.

For a withdrawal operation, the intended proof structure is:

1. The pre-exposure phase establishes the exposure invariant.
2. Callback operations preserve the exposure invariant under the applicable assumptions.
3. The post-exposure phase restores the stable-state invariant.

The verification harness allows phase-specific obligations to be generated and analyzed separately.

This phase decomposition is a modeling technique for reasoning about external interactions occurring within a contract function.

The correspondence between the harness and concrete contract execution is an assumption that must be established for the resulting conclusions to apply to the analyzed implementation.

The motivating example is represented by:

`MotivatingVault.sol`

## 9. Solidity AST-Based Static Analysis

The soundness of callback-closure validation depends on the completeness of the underlying static analysis.

A purely regex-based analysis cannot reliably resolve all relevant Solidity language constructs.

AEGIS includes an AST-based analysis component:

`ast_analysis.py`

### 9.1 Supported Analysis Responsibilities

The AST-based implementation is designed to support:

- Resolution of inherited contract state.
- Identification of storage writes through modifiers.
- Analysis of external-call sites.
- Identification of multiple external interactions within a function.
- Tracking of relevant storage references.
- Analysis of statement ordering around external calls.

The analyzer uses Solidity compiler-generated abstract syntax trees.

Inheritance information can be obtained through compiler metadata such as:

`linearizedBaseContracts`

### 9.2 Analysis Selection

The framework records the selected analysis implementation through:

`static_analysis.LAST_ANALYZER`

The AST-based analyzer is the intended analysis path for verification claims that depend on conservative callback-closure construction.

The regex-based analyzer is retained as a fallback for environments where compiler-based analysis is unavailable.

Results obtained through the fallback must be interpreted according to its analysis limitations and should not be treated as establishing sound callback closure without additional justification.

### 9.3 Regression Testing

The file:

`tests/test_ast.py`

contains test cases covering relevant analysis behavior, including inheritance, modifiers, and execution ordering.

These tests provide regression coverage for selected static-analysis functionality.

Passing regression tests does not independently establish soundness for every Solidity construct or all possible contract configurations.

## 10. Benchmark Design and Diagnostic Contracts

The benchmark includes contracts designed to exercise particular analysis and verification capabilities.

### 10.1 InheritedVault

`InheritedVault` places relevant accounting state within a base contract.

This example exercises inheritance resolution and identification of state inherited from parent contracts.

It supports evaluation of analysis behavior involving Solidity's contract inheritance mechanisms.

### 10.2 BuggyVault

`BuggyVault` models an incorrect post-exposure accounting transition involving the `inFlight` variable.

The contract omits a required settlement operation, preventing restoration of the intended stable-state invariant.

This example is designed to exercise the post-exposure verification obligation and the backend's ability to identify violations under the modeled semantics.

A reported counterexample must be interpreted relative to the generated verification conditions and assumptions used by the backend.

## 11. Scope and Limitations

The verification approach is subject to the supported modeling and analysis capabilities.

### 11.1 Callback Semantics

The framework focuses on callback-sensitive contract behaviors, including reentrancy-related interactions and selected token or flash-loan callback patterns.

The completeness of coverage depends on the supported callback abstraction.

### 11.2 Static Analysis

Conservative callback closure requires the static analyzer to account for relevant control flow, storage interactions, inheritance, modifiers, and external-call behavior.

Incomplete analysis may affect the validity of generated assumptions.

### 11.3 Solidity Language Coverage

Complex constructs such as delegatecall-based execution, inline assembly, and dynamic storage interactions may require additional modeling or analysis support.

### 11.4 Arithmetic and Verification Semantics

Proof outcomes depend on the arithmetic model, compiler configuration, solver semantics, and generated verification harnesses.

### 11.5 Bounded Refinement

The refinement process uses bounded execution budgets.

An inconclusive result or exhausted refinement budget does not necessarily imply that the analyzed contract is vulnerable.

### 11.6 Backend Requirements

Formal verification claims require actual execution of the configured verification backend and successful discharge of the corresponding obligations.

Simulation or template-based execution alone does not establish a formal proof.

## 12. Design Summary

AEGIS combines modular specification synthesis, conservative callback analysis, dependency-aware refinement, and formal verification of phase-specific obligations.

Its principal design characteristics are:

- Explicit separation of stable and callback-exposed states.
- Modular representation of verification assumptions and guarantees.
- Candidate specification synthesis outside the trusted computing base.
- Conservative validation of callback-related assumptions.
- Obligation-level verification and failure localization.
- Dependency-aware specification refinement.
- AST-based analysis of relevant Solidity constructs.
- Structured verification outcomes suitable for empirical evaluation.

Together, these mechanisms provide an architecture for investigating modular formal verification of callback-sensitive smart contracts, with verification conclusions dependent on the soundness and coverage of the implemented analysis and proof components.
