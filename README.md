# Aegis — Modular Callback Verification Plans for Smart Contracts

An LLM synthesizes a **Modular Callback Verification Plan (MCVP)** for a
callback-exposed Solidity contract; the plan is compiled into independent
**assume-guarantee obligations**; a **real verifier (solc SMTChecker)**
discharges each; failing **modules** are localized and repaired by a
**dependency-driven fixpoint** loop. The LLM is never trusted — soundness rests
on a conservative static gate plus the real solver.

## Honesty guarantee (read this first)
A result is **VERIFIED only if a real solver discharged every obligation.**
If `solc` is not installed (or is a broken solc-select shim that cannot fetch
its binary), Aegis prints a banner and returns **UNAVAILABLE — never a fake
VERIFIED.** A concrete solver counterexample yields **BUG_FOUND** with the trace.

## Architecture (9 modules)
```
static_analysis.py  front-end + callback-exposure analysis; conservative closure (soundness anchor)
mcvp.py             the MCVP schema (closure, protocol, phases, ghost state, exposure invariant, composition)
synth.py            k-sampled MCVP synthesis: stub | openai | anthropic; per-module repair
validator.py        schema + CONSERVATIVE-CLOSURE soundness gate (keeps LLM out of trusted base)
compiler.py         lowers MCVP -> per-obligation standalone SMTChecker harnesses (assume/assert framing)
backend.py          REAL solc SMTChecker (CHC); health-checks solc; parses verified/failed+cex/unknown
failsafe.py         localizes each failed obligation to its responsible module (keeps correct work)
depgraph.py         A/G dependency DAG driving fixpoint repair propagation
pipeline.py         Aegis(C, phi): validate -> compile -> verify -> localize -> repair to fixpoint
```

## Setup

Python only (will report UNAVAILABLE without solc, but runs the full logic):
```bash
cd aegis_dist
python3 tests/test_pipeline.py
python3 run_aegis.py contracts/MotivatingVault.sol --property "totalAssets == totalShares" --llm stub
```

Real verifier (required for real results):
```bash
pip install solc-select
solc-select install 0.8.26 && solc-select use 0.8.26
sudo apt-get update && sudo apt-get install -y z3
solc --version
```
If you previously had a broken solc-select shim, the above fixes it; Aegis
health-checks solc and will say REAL SMTChecker in the banner once it works.

Real LLM (OpenAI):
```bash
pip install openai
export OPENAI_API_KEY="sk-..."
export AEGIS_OPENAI_MODEL="gpt-4o"
python3 run_aegis.py contracts/MotivatingVault.sol --property "totalAssets == totalShares" --llm openai --k 4
```

## Expected results with a real solver
```
MotivatingVault.sol  -> VERIFIED   (pre establishes I_exp; deposit/redeemAll preserve it; post restores I_stable)
BuggyVault.sol       -> BUG_FOUND  (OBL_post fails: inFlight not cleared, so I_stable not restored)
```

## Corpus / evaluation harness
```bash
python3 run_corpus.py          # runs every contract in contracts/corpus/ and tabulates results
```
Extend `contracts/corpus/` with `<Name>.sol` + `<Name>.harness.sol` (phase-split
version exposing beginExposed/endExposed + callbacks) and add a target to the
TARGETS map in run_corpus.py.

## JSON output (for experiments)
```bash
python3 run_aegis.py contracts/corpus/BuggyVault.sol --property "totalAssets == totalShares" --llm stub --json
```

See DESIGN_RATIONALE.md for the reviewer-facing justification of every choice.
