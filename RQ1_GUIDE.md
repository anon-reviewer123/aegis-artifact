
# AEGIS: RQ1 Experimental Evaluation Guide

## 1. Overview

This document describes the experimental procedure for evaluating AEGIS against established smart-contract security analysis tools.

The evaluation compares four approaches:

1. AEGIS — LLM-assisted assume-guarantee verification.
2. SMTChecker-direct — direct formal analysis without MCVP synthesis.
3. Slither — static analysis-based vulnerability detection.
4. Mythril — symbolic execution-based vulnerability detection.

All evaluation tools produce results in a common JSON format, enabling consistent aggregation and comparison.

The `make_rq1_tables.py` utility generates LaTeX tables summarizing the experimental results.

All commands are executed from the `aegis_dist/` directory.

---

## 2. Environment and Toolchain

### 2.1 Solidity Compiler

AEGIS uses the Solidity compiler (`solc`) with SMTChecker support.

Verify the installed compiler:

```bash
solc --version
```

The benchmark configuration described in this guide uses Solidity 0.8.26.

### 2.2 LLM Configuration

For LLM-assisted specification synthesis, configure the required API credentials and model identifier.

```bash
export OPENAI_API_KEY="<OPENAI_API_KEY>"
export AEGIS_OPENAI_MODEL="gpt-4o"
```

Verify the configuration without displaying the API key:

```bash
echo "API key configured: ${OPENAI_API_KEY:+yes}"
echo "Model: ${AEGIS_OPENAI_MODEL:-<unset>}"
```

API credentials should be managed through environment variables or an appropriate secrets-management mechanism and must not be committed to the repository.

### 2.3 Formal Verification Backend

AEGIS uses Solidity SMTChecker and a Horn-clause solver for formal verification.

The Eldarica executable must be accessible through the system PATH.

Example configuration:

```bash
export PATH="$HOME/Downloads/eldarica:$PATH"
```

---

## 3. Baseline Tool Installation

### 3.1 Slither

Slither performs static analysis of Solidity smart contracts.

Install:

```bash
pip install slither-analyzer
```

Alternatively:

```bash
pipx install slither-analyzer
```

Verify:

```bash
slither --version
```

### 3.2 Mythril

Mythril performs symbolic execution and vulnerability analysis of Ethereum smart contracts.

Install:

```bash
pip install mythril
```

Alternatively:

```bash
pipx install mythril
```

Verify:

```bash
myth version
```

For dependency isolation, Mythril may be installed in a dedicated Python virtual environment:

```bash
python3 -m venv ~/.venv-myth
source ~/.venv-myth/bin/activate
pip install mythril
myth version
deactivate
```

The Mythril executable must be accessible when executing the corresponding baseline.

### 3.3 SMTChecker-Direct

The SMTChecker-direct baseline uses the installed Solidity compiler and does not require an additional tool installation.

This baseline evaluates contracts using direct SMTChecker-based verification without AEGIS's synthesized Modular Callback Verification Plan.

---

## 4. Pipeline Validation

Before running the full evaluation, the execution pipeline can be checked using deterministic template-based synthesis.

### 4.1 AEGIS Template-Based Execution

```bash
python3 collect_aegis.py \
  --labels benchmark.json \
  --llm stub \
  --out /tmp/aegis_stub.json
```

The `stub` configuration uses predefined synthesis templates and does not require LLM API access.

### 4.2 SMTChecker-Direct Execution

```bash
python3 baseline_smtchecker.py \
  --labels benchmark.json \
  --out /tmp/smt.json
```

These executions provide an initial check of contract loading, verification-backend integration, and structured result generation.

Successful execution of these checks does not independently establish the outcome of the full LLM-assisted evaluation.

---

## 5. RQ1 Experimental Execution

### 5.1 AEGIS

Run AEGIS with LLM-assisted specification synthesis:

```bash
python3 collect_aegis.py \
  --labels benchmark.json \
  --llm openai \
  --k 4 \
  --out results/aegis_rq1.json
```

This configuration uses OpenAI-based candidate specification synthesis followed by the AEGIS validation and verification pipeline.

### 5.2 SMTChecker-Direct

```bash
python3 baseline_smtchecker.py \
  --labels benchmark.json \
  --out results/baseline_smtchecker.json
```

This baseline uses direct SMTChecker analysis without an MCVP.

### 5.3 Slither

```bash
python3 baseline_detectors.py \
  --tool slither \
  --labels benchmark.json \
  --out results/baseline_slither.json
```

### 5.4 Mythril

```bash
python3 baseline_detectors.py \
  --tool mythril \
  --labels benchmark.json \
  --out results/baseline_mythril.json
```

### 5.5 Compiler Compatibility

Each evaluated contract must be analyzed using a compatible Solidity compiler version.

Where contracts require different compiler versions, the environment can be configured using `solc-select`:

```bash
solc-select use <VERSION>
```

Compiler versions and relevant tool configurations should be recorded alongside the experimental results.

---

## 6. Results Aggregation

The evaluation framework uses a common JSON result schema across the compared tools.

Generate the LaTeX evaluation tables using:

```bash
python3 make_rq1_tables.py \
  --labels benchmark.json \
  --results-dir results \
  --out-dir results
```

### 6.1 Main Comparison

Output:

`results/table1_main.tex`

This table summarizes the primary evaluation outcomes, including:

- Verified classifications.
- Detected vulnerabilities.
- Spurious findings.
- Unknown outcomes.
- Localization information.

### 6.2 Per-Class Evaluation

Output:

`results/table2_perclass.tex`

This table summarizes results for individual vulnerability categories, including the number of correct classifications relative to the number of evaluated contracts.

The generated LaTeX tables use the `booktabs` package.

### 6.3 Result Interpretation

The experimental analysis should account for differences between static detection, symbolic execution, and formal verification.

The interpretation of `VERIFIED`, `BUG_FOUND`, and `UNKNOWN` depends on the semantics of the corresponding tool.

Where tools expose different result categories or levels of evidence, the mapping into the common evaluation schema should be documented.

Comparative performance claims should be derived from recorded executions and verified output artifacts.

---

## 7. Benchmark Composition and Extension

The evaluation framework supports expansion of the benchmark across additional smart-contract vulnerability classes.

The benchmark configuration is maintained in:

`benchmark.json`

Supporting Solidity contracts are organized under:

`contracts/corpus/`

Additional benchmark acquisition and preparation procedures are described in:

`GROW_BENCHMARK.md`

### 7.1 Vulnerability Categories

Relevant evaluation categories include:

- Read-only reentrancy.
- Flash-loan callback interactions.
- Griefing and liveness vulnerabilities.
- Cross-function reentrancy.
- Other callback-sensitive smart-contract security properties.

### 7.2 Benchmark Integration

To incorporate an additional contract:

1. Add the Solidity source file to `contracts/corpus/`.
2. Add its corresponding entry to `benchmark.json`.
3. Specify the appropriate vulnerability classification and expected outcome.
4. Verify compatibility with the selected Solidity compiler.
5. Execute the analysis and record the resulting artifacts.

AEGIS supports generation of verification harnesses when a compatible `.harness.sol` file is not already available.

### 7.3 Dataset Provenance

Benchmark sources should be documented with sufficient information to establish their origin and intended evaluation role.

Where applicable, dataset documentation should distinguish:

- Real-world deployed contracts.
- Vulnerable and patched contract variants.
- Adapted benchmark examples.
- Synthetic minimal models.
- Contracts with independently established ground-truth classifications.

Synthetic and adapted cases should not be represented as original deployed contracts.

---

## 8. Experimental Reproducibility

A reproducible RQ1 evaluation should preserve:

- Benchmark input files and ground-truth labels.
- Tool and compiler versions.
- Model identifiers and synthesis parameters.
- Verification-backend configuration.
- Per-contract results.
- Aggregate evaluation outputs.
- Generated LaTeX tables.

The structured outputs allow the comparison tables to be regenerated from the recorded experimental data.

## 9. Evaluation Scope

The experiment assesses the behavior of AEGIS and the selected baselines on the configured benchmark.

Verification effectiveness, detection coverage, false positives, inconclusive outcomes, and computational requirements should be interpreted relative to the evaluated contracts and each tool's supported analysis semantics.

The evaluation framework distinguishes the implementation of an experimental procedure from empirical evidence obtained through its execution. Conclusions should be supported by the corresponding recorded results.
