# RQ1 Execution Guide — Aegis vs. baselines (run on YOUR machine)

You already have Aegis + solc + Eldarica working. This guide adds the three
baseline tools and runs the full RQ1 comparison. Everything emits the SAME JSON
schema, so `make_rq1_tables.py` produces Table 1 + Table 2 as drop-in LaTeX.

All commands assume you are inside `aegis_dist/`.

---

## 0. One-time: confirm your existing toolchain

```bash
solc --version                       # must show your 0.8.x with SMTChecker
echo "key set? ${OPENAI_API_KEY:+yes}"
echo "model: ${AEGIS_OPENAI_MODEL:-<unset>}"
```

---

## 1. Install the three baseline tools

These are isolated CLI tools; install in a venv or with pipx so they don't
collide with Aegis's deps. **Slither and Mythril each need solc**, which you
already manage with solc-select — they reuse it.

### 1a. Slither (static detector)
```bash
pip install slither-analyzer        # or: pipx install slither-analyzer
slither --version
```

### 1b. Mythril (symbolic-execution detector)
```bash
pip install mythril                 # or: pipx install mythril
myth version
```
> Mythril is heavier (symbolic execution). If `pip install mythril` fights your
> environment, use a separate venv:
> ```bash
> python3 -m venv ~/.venv-myth && source ~/.venv-myth/bin/activate
> pip install mythril && myth version && deactivate
> ```
> Then point `baseline_detectors.py` at it by running that script from inside
> the venv, or put `~/.venv-myth/bin` on PATH for the Mythril step only.

### 1c. SMTChecker-direct — NOTHING to install
It reuses your existing solc. No new tool.

---

## 2. Sanity check (cheap, no API spend) — confirm plumbing

```bash
# stub LLM = no API tokens; just checks the harness + backend wiring
python3 collect_aegis.py --labels benchmark.json --llm stub --out /tmp/aegis_stub.json
python3 baseline_smtchecker.py --labels benchmark.json --out /tmp/smt.json
```
Both should print one line per labeled contract and write JSON. If solc is
healthy you'll see real VERIFIED/BUG_FOUND/UNKNOWN already from the stub.

---

## 3. Run all four tools over the benchmark

```bash
# (a) Aegis — the real run (uses your OpenAI key). ~60-90s/contract.
python3 collect_aegis.py --labels benchmark.json --llm openai --k 4 \
        --out results/aegis_rq1.json

# (b) SMTChecker-direct (your backend, monolithic, no MCVP)
python3 baseline_smtchecker.py --labels benchmark.json \
        --out results/baseline_smtchecker.json

# (c) Slither
python3 baseline_detectors.py --tool slither --labels benchmark.json \
        --out results/baseline_slither.json

# (d) Mythril  (run from the venv if you used one)
python3 baseline_detectors.py --tool mythril --labels benchmark.json \
        --out results/baseline_mythril.json
```

> Each baseline needs the right solc per contract. If a contract pins a
> different version, `solc-select use <ver>` before its run, or run the tools
> per-version-group. For the current corpus everything is 0.8.26.

---

## 4. Generate Table 1 + Table 2

```bash
python3 make_rq1_tables.py --labels benchmark.json \
        --results-dir results --out-dir results
```
Outputs:
- `results/table1_main.tex`     — main comparison (Verified/Bug/Spurious/Unknown/Localized)
- `results/table2_perclass.tex` — per-class breakdown (#correct / #class)

Paste both into the paper. They compile standalone (need `booktabs`).

---

## 5. Paste results back to me

After step 3, paste the four `results/*.json` files (or just the console
summaries). I'll: (a) sanity-check the numbers, (b) tell you if any baseline
needs a fairer configuration, and (c) if Aegis's margin is thin, improve the
synth prompt / k / repair budget and give you the re-run command.

---

## Growing the benchmark to ~20/class (the real lift)

`benchmark.json` currently has your 14 existing contracts. Gaps:
`read_only_reentrancy` (0), `flash_loan_callback` (0), `griefing_liveness` (1).
See `GROW_BENCHMARK.md` for download commands (ReentrancyStudy-Data, SmartReco
ROR set, SCRUBD) and the synthetic minimal models I provide for the empty
classes. Each new contract = one `.sol` in `contracts/corpus/` + one row in
`benchmark.json`. Aegis auto-synthesizes the `.harness.sol` if absent.
