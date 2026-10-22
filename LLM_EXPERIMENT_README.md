# Running the CORE experiment: LLM-synthesized A/G specs

This is the experiment that validates the paper's central claim -- that an LLM
synthesizes the assume-guarantee specification, while a sound backend verifies
it (the LLM is never trusted).

## What has and hasn't happened yet (be honest in the paper)
Every result you have seen SO FAR used the `stub` synthesizer -- a hand-coded
fixed-template generator. The stub is the BASELINE, not the contribution. The
LLM path (`synth.py:_sample_openai` / `_sample_anthropic`) is real and sound but
has NOT been run. This experiment runs it.

## Setup
```bash
export OPENAI_API_KEY="sk-...your real key..."     # NOT the placeholder
export AEGIS_OPENAI_MODEL="gpt-4o"
export PATH="$HOME/Downloads/eldarica:$PATH"        # real Horn solver
```

## Run it
```bash
# core run: LLM synthesis + real verification, 3 repeats for honest rates
python3 run_llm_experiment.py --llm openai --k 4 --repeats 3 --baseline
```
`--baseline` also runs the stub so you get the LLM-vs-template comparison (RQ3).

## What you get (results/)
- `results/<contract>.openai.json` : the ACTUAL LLM-generated MCVP + rendered
  A/G spec for each contract. These are your real paper artifacts -- show one
  in the Approach section as "here is what the LLM synthesized."
- `results/summary.json` : per-contract aggregate metrics.
- console table with, per contract:
    match k/N            : how often the verified status matched expectation
    first-try-verify k/N : LLM spec verified with no repair (RQ1 headline)
    LLM-sound-as-proposed: how often the LLM's RAW spec passed the conservative
                           gate (RQ2: how often the LLM is unsound and caught)
    avg_rounds           : mean repair rounds to fixpoint

## The research questions this answers
- RQ1 synthesis quality: first-try-verify rate + avg repair rounds.
- RQ2 soundness in practice: LLM-sound-as-proposed < 100% is GOOD for the paper
  -- it shows the LLM does make unsound proposals and the gate catches them
  (LLM not in the trusted base, observed empirically).
- RQ3 LLM vs template: compare openai rows to stub rows (does the LLM generalize
  beyond the stub's fixed invariant family?).
- RQ4 model comparison: rerun with `--llm anthropic` (needs ANTHROPIC_API_KEY)
  and `AEGIS_ANTHROPIC_MODEL`, compare. (Cobblestone did GPT-4 vs Claude.)

## Soundness reminder for the paper
Every reported VERIFIED is a real Eldarica proof; every BUG_FOUND a real
counterexample. The LLM only PROPOSES; the conservative-closure gate + the
solver DISPOSE. We demonstrated this directly: an LLM plan that omits a
reachable callback from the closure is rejected by the gate (see
DESIGN_RATIONALE.md). That is the "sound despite unsound LLMs" guarantee.
