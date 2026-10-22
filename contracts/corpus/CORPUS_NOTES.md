
# AEGIS: Corpus Design and Verification Coverage

## 1. Overview

The AEGIS contract corpus contains Solidity examples designed to evaluate callback-sensitive formal verification, conservative callback-closure analysis, and phase-specific assume-guarantee reasoning.

The corpus includes examples covering withdrawal accounting, inherited state, cross-function reentrancy, and alternative callback patterns.

Each contract is associated with an intended security classification and relevant verification obligations.

Expected verification outcomes are distinguished from results established through recorded solver execution.

## 2. Withdrawal-Based Accounting Contracts

The withdrawal-oriented examples use the following exposure invariant:

`totalAssets == totalShares + inFlight`

This invariant represents intermediate accounting states in which a withdrawal has been initiated but has not yet completed its settlement.

The contract examples are organized as follows.

| Contract | Classification | Expected Verification Outcome |
|---|---|---|
| MotivatingVault | Safe withdrawal accounting | `VERIFIED` |
| InheritedVault | Safe withdrawal accounting with inherited state | `VERIFIED` |
| BuggyVault | Missing in-flight settlement | `BUG_FOUND` |
| CrossFunctionVault | Safe cross-function callback behavior | `VERIFIED` |
| CrossFunctionBuggy | Cross-function accounting violation | `BUG_FOUND` |

These classifications describe the intended benchmark behavior. Verification outcomes depend on the applicable assumptions, generated obligations, and formal backend execution.

## 3. Cross-Function Callback Analysis

The `CrossFunctionVault` and `CrossFunctionBuggy` examples evaluate the framework's ability to reason about callback execution across different contract functions.

The exposed operation is:

`withdraw()`

The callback-reachable function is:

`transfer()`

The callback-closure analysis is intended to identify `transfer()` as a relevant function even though it differs from the original withdrawal operation.

### 3.1 CrossFunctionVault

`CrossFunctionVault` represents the safe variant.

The verification model evaluates whether the exposure invariant remains preserved when the callback invokes `transfer()`.

The expected outcome is:

`VERIFIED`

### 3.2 CrossFunctionBuggy

`CrossFunctionBuggy` represents the vulnerable variant.

The `transfer()` implementation modifies `totalShares` in a manner that violates the intended accounting relationship.

The relevant verification obligation is:

`OBL_cb_transfer`

The expected outcome is:

`BUG_FOUND`

### 3.3 Verification Significance

These examples are intended to evaluate whether conservative callback-closure analysis identifies security-relevant behavior outside the function containing the original external interaction.

A function-local analysis that excludes callback-reachable functions may fail to generate the necessary cross-function preservation obligations.

The cross-function pair therefore provides a targeted test of callback-closure construction and obligation generation.

## 4. Additional Callback Patterns

The corpus also includes models intended to evaluate callback behaviors beyond withdrawal-oriented accounting.

These models require verification conditions appropriate to their accounting and execution semantics.

### 4.1 ERC1155Vault

The `ERC1155Vault` example represents mint-oriented accounting.

Unlike withdrawal-oriented examples, its intermediate accounting relationship follows the opposite direction.

The intended exposure invariant is:

`totalShares == totalAssets + inFlight`

This formulation represents a state in which share accounting precedes the corresponding asset-accounting update.

The example is associated with the following implementation considerations:

- Construction of mint-oriented phase obligations.
- Preservation of the exposure invariant during callbacks.
- Compatibility of generated pre-exposure and post-exposure harnesses with mint-oriented accounting.
- Validation of expected outcomes using the configured formal backend.

The withdrawal-oriented harness structure cannot automatically be assumed to establish the required properties for mint-oriented operations.

### 4.2 Flash-Loan Callback Patterns

Flash-loan callback verification introduces repayment and balance-restoration requirements.

A representative postcondition is:

`balanceAfter >= balanceBefore`

This property expresses a minimum balance-restoration requirement following the callback operation.

Formal verification requires an obligation structure that captures the relevant loan execution semantics, repayment conditions, and permissible balance changes.

The adequacy of this property depends on the modeled protocol and associated assumptions.

## 5. Verification Obligation Coverage

The corpus exercises multiple categories of proof obligations.

| Obligation Category | Purpose |
|---|---|
| Pre-exposure | Establishes the required intermediate-state invariant |
| Callback preservation | Checks invariant preservation across callback-reachable functions |
| Post-exposure | Checks restoration of the stable-state invariant |
| Cross-function callback | Evaluates behavior reachable through functions other than the initiating operation |
| Accounting restoration | Checks completion of pending accounting transitions |
| Repayment condition | Evaluates balance-restoration requirements for flash-loan operations |

Different contract patterns may require different obligation structures.

A verification harness must represent the corresponding contract behavior faithfully for its results to support conclusions about the analyzed implementation.

## 6. Corpus Organization

The corpus distinguishes contract examples used for primary verification evaluation from additional models requiring separate validation.

The relevant directories are:

- `contracts/corpus/` — primary contract examples.
- `contracts/corpus_provisional/` — additional contract models whose verification status requires confirmation.

Directory membership identifies the organizational role of a contract. It does not independently establish successful solver execution.

## 7. Verification and Result Interpretation

AEGIS reports verification outcomes using the configured validation and formal verification pipeline.

### VERIFIED

Indicates successful discharge of the required verification obligations under the modeled assumptions and supported semantics.

### BUG_FOUND

Indicates that the verification backend identified a violation of the specified property or generated an applicable counterexample.

### UNKNOWN

Indicates that the available verification procedure did not establish either successful verification or a confirmed violation.

Expected benchmark labels should be distinguished from recorded verification outcomes.

For each evaluated contract, reproducibility information should include the source input, generated harnesses, solver configuration, relevant obligations, and recorded verification results.

## 8. Evaluation Scope

The corpus supports investigation of:

- Stable-state and intermediate-state accounting invariants.
- Callback-preservation obligations.
- Inherited contract state.
- Cross-function callback reachability.
- Mint-oriented callback accounting.
- Flash-loan repayment conditions.
- Verification-obligation localization.

The applicability of verification conclusions depends on the modeled execution semantics, conservative closure construction, and formal backend configuration.

## 9. Summary

The AEGIS corpus provides targeted examples for studying assume-guarantee verification under adversarial callback behavior.

The withdrawal-oriented examples exercise invariant establishment, callback preservation, and stable-state restoration.

The cross-function examples specifically examine callback-reachable behavior beyond the initiating function.

The ERC-1155 and flash-loan models extend the range of callback patterns addressed by the corpus, with their verification requirements determined by the corresponding accounting and execution semantics.

The corpus documentation distinguishes intended classifications from demonstrated verification outcomes to support transparent and reproducible evaluation.
