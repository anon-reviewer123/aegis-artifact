
# AEGIS: LLM-Assisted Assume-Guarantee Specification Evaluation

## Overview

This document describes the experimental framework for evaluating LLM-assisted synthesis of assume-guarantee (A/G) specifications in AEGIS.

The framework separates specification generation from formal verification. Language models generate candidate Modular Callback Verification Plans (MCVPs), while deterministic validation mechanisms and a formal verification backend evaluate the resulting proof obligations.

The primary objective is to examine the effectiveness of LLM-generated specifications, the role of conservative callback validation, and the impact of specification refinement on verification outcomes.

## Specification Synthesis Modes

AEGIS supports two specification synthesis configurations.

### Template-Based Synthesis

The `stub` synthesizer constructs candidate specifications using predefined templates and invariant patterns.

This configuration provides a deterministic reference for comparing specification generation strategies.

### LLM-Based Synthesis

The LLM-based implementation is provided through:

- `synth.py:_sample_openai`
- `synth.py:_sample_anthropic`

These components obtain candidate specifications from their respective language-model APIs.

LLM-generated specifications are treated as untrusted candidates and must satisfy the framework's validation and formal verification requirements.

The availability of these implementations does not independently establish that an experimental run has been completed or that a candidate specification has been successfully verified.

## Experimental Configuration

### Environment

The following configuration illustrates execution with an OpenAI model and the Eldarica solver.

```bash
export OPENAI_API_KEY="<OPENAI_API_KEY>"
export AEGIS_OPENAI_MODEL="gpt-4o"
export PATH="$HOME/Downloads/eldarica:$PATH"
```

The API key must be supplied through a valid credential and must not be committed to the research repository.

### Execution

The experimental driver supports LLM synthesis, repeated execution, and comparison with the template-based baseline.

```bash
python3 run_llm_experiment.py \
  --llm openai \
  --k 4 \
  --repeats 3 \
  --baseline
```

The configuration specifies:

- `--llm openai`: Selects OpenAI-based specification synthesis.
- `--k 4`: Sets the candidate-generation parameter to four.
- `--repeats 3`: Executes three repetitions for the configured experiment.
- `--baseline`: Includes template-based synthesis for comparison.

## Experimental Artifacts

The experimental pipeline is designed to produce structured results in the `results/` directory.

### Contract-Level Results

`results/<contract>.openai.json`

This artifact records contract-specific LLM synthesis and verification information, including candidate MCVPs and corresponding A/G specification representations.

### Aggregate Results

`results/summary.json`

This artifact contains aggregate experimental measurements across the evaluated contracts.

### Reported Metrics

| Metric | Description |
|---|---|
| Status agreement | Frequency with which the verification outcome matches the expected contract classification |
| First-attempt verification | Frequency of successful verification without specification repair |
| Initial specification validation | Proportion of generated specifications satisfying conservative validation requirements |
| Average repair rounds | Mean number of refinement iterations performed |
| Verification outcome | Final classification produced by the verification pipeline |

These measurements support analysis of synthesis behavior, validation effectiveness, and specification refinement.

## Research Questions

### RQ1: Specification Synthesis Quality

How effectively do LLM-generated specifications support successful formal verification?

The evaluation considers:

- First-attempt verification rate.
- Average number of repair iterations.
- Final verification outcomes.

### RQ2: Conservative Validation Effectiveness

How effectively does the validation mechanism identify candidate specifications that violate callback-closure requirements?

The evaluation examines the proportion of candidate specifications accepted or rejected by the conservative closure gate.

Validation rejection provides evidence that a proposed specification does not satisfy the required acceptance conditions. It does not, by itself, establish that the specification is semantically unsound.

### RQ3: LLM-Based Versus Template-Based Synthesis

How does LLM-assisted synthesis compare with deterministic template-based specification generation?

The evaluation compares results obtained using the `openai` and `stub` synthesis configurations under the same verification framework.

Relevant dimensions include verification success, refinement requirements, and the range of supported specification structures.

### RQ4: Cross-Model Comparison

How do different language models perform when used for assume-guarantee specification synthesis?

The framework also provides an Anthropic synthesis configuration.

An example execution is:

```bash
export ANTHROPIC_API_KEY="<ANTHROPIC_API_KEY>"
export AEGIS_ANTHROPIC_MODEL="<MODEL_IDENTIFIER>"

python3 run_llm_experiment.py \
  --llm anthropic \
  --k 4 \
  --repeats 3 \
  --baseline
```

Cross-model comparisons should use consistent benchmark inputs, evaluation metrics, and verification conditions.

## Formal Verification and Trust Boundaries

The AEGIS architecture separates LLM-based specification synthesis from proof-obligation validation.

The verification workflow consists of:

1. Generation of candidate MCVPs.
2. Construction of corresponding assume-guarantee specifications.
3. Conservative validation of callback-related assumptions.
4. Generation of formal verification obligations.
5. Verification using the configured formal backend.
6. Classification and reporting of verification outcomes.

### Trusted Computing Base

LLM-generated candidates are not accepted as formal evidence solely because they are produced by a language model.

The validity of verification conclusions depends on the soundness of the callback abstraction, validation mechanisms, verification-condition encoding, and backend reasoning.

### Verification Outcomes

- `VERIFIED`: Indicates that the required obligations have been discharged under the modeled assumptions and verification configuration.
- `BUG_FOUND`: Indicates that the backend reported a violation or counterexample according to its configured semantics.
- `UNKNOWN`: Indicates that the available analysis did not establish either successful verification or a confirmed violation.

A reported `VERIFIED` result is meaningful within the assumptions and scope of the formal model. It does not imply unrestricted correctness of the entire deployed smart contract.

Similarly, a reported counterexample must be interpreted according to the semantics and limitations of the verification backend.

## Reproducibility and Interpretation

Experimental results should be associated with the relevant contract inputs, synthesis configurations, model identifiers, validation outcomes, solver configurations, and recorded outputs.

Comparisons between LLM-based and template-based synthesis should distinguish candidate generation performance from formal verification success.

The experimental framework supports investigation of whether LLM-assisted specification synthesis improves verification effectiveness while keeping the verification decision independent of the language model.
