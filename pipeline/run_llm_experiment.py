#!/usr/bin/env python3
"""
run_llm_experiment.py - The CORE experiment for the paper.

Runs the corpus under a REAL LLM (the contribution) and, optionally, the stub
(the fixed-template baseline), and produces the data for the central research
questions:

  RQ1 (synthesis quality): How often does the LLM-synthesized MCVP verify, and
       how many repair rounds does it take? (first-try vs needed-repair rate)
  RQ2 (soundness in practice): How often does the LLM propose an UNSOUND spec
       that the conservative gate catches? (LLM-not-trusted, observed)
  RQ3 (LLM vs template baseline): Does the LLM generalize beyond the stub's
       fixed invariant family? Compare LLM vs stub on the same corpus.
  RQ4 (model comparison): openai vs anthropic on the same corpus (optional).

For each contract it SAVES THE ACTUAL LLM-GENERATED MCVP and rendered A/G spec
under results/ so you have real artifacts to show in the paper (not the stub's).

USAGE
  export OPENAI_API_KEY="sk-...your real key..."
  export AEGIS_OPENAI_MODEL="gpt-4o"          # or gpt-4-turbo, etc.
  export PATH="$HOME/Downloads/eldarica:$PATH"  # the Horn solver
  python3 run_llm_experiment.py --llm openai --k 4 --repeats 1

  # baseline + model comparison:
  python3 run_llm_experiment.py --llm openai --baseline --repeats 3
  python3 run_llm_experiment.py --llm anthropic   # needs ANTHROPIC_API_KEY

Notes:
  * --repeats N runs each contract N times (LLM is nondeterministic at temp=1.0)
    and reports mean first-try-verify rate -- this is how you get honest numbers.
  * Every run still goes through the conservative gate + REAL solver, so a
    reported VERIFIED is always a real proof, never the LLM's say-so.
"""
import os, glob, json, time, argparse, statistics
from aegis.pipeline import run_aegis
from aegis import static_analysis, synth, validator, assume_guarantee as ag

CORPUS = os.path.join(os.path.dirname(__file__), "contracts", "corpus")
RESULTS = os.path.join(os.path.dirname(__file__), "results")

TARGETS = {
    "MotivatingVault.sol":    ("totalAssets == totalShares", "VERIFIED"),
    "BuggyVault.sol":         ("totalAssets == totalShares", "BUG_FOUND"),
    "InheritedVault.sol":     ("totalAssets == totalShares", "VERIFIED"),
    "ERC777Vault.sol":        ("totalAssets == totalShares", "VERIFIED"),
    "ERC777Buggy.sol":        ("totalAssets == totalShares", "BUG_FOUND"),
    "NestedVault.sol":        ("totalAssets == totalShares", "VERIFIED"),
    "NestedBuggy.sol":        ("totalAssets == totalShares", "BUG_FOUND"),
    "CrossFunctionVault.sol": ("totalAssets == totalShares", "VERIFIED"),
    "CrossFunctionBuggy.sol": ("totalAssets == totalShares", "BUG_FOUND"),
}


def _capture_first_llm_plan(sol, prop, llm, k):
    """Capture the LLM's RAW first-sample MCVP (before any repair) so we can
    record what the LLM actually proposed, and whether it was sound as-proposed."""
    facts = static_analysis.analyze(sol)
    if not facts.exposure_sites:
        return None, None, None
    site = facts.exposure_sites[0]
    try:
        plans = synth.sample_plans(facts, site, prop, backend=llm, k=k)
    except Exception as e:
        return None, None, f"synthesis error: {e}"
    if not plans:
        return None, None, "no plan produced"
    first = plans[0]
    sound_as_proposed = (validator.validate(first, facts, site) == [])
    try:
        rendered = ag.derive(first).render()
    except Exception:
        rendered = None
    return first, sound_as_proposed, rendered


def run_one(sol, prop, expected, llm, k):
    base = os.path.basename(sol)
    t0 = time.time()
    # Capture the LLM's raw first proposal (artifact + RQ2 soundness-as-proposed)
    first_plan, sound_as_proposed, rendered_ag = _capture_first_llm_plan(sol, prop, llm, k)
    # Full pipeline run (synthesis -> gate -> real solver -> repair to fixpoint)
    res = run_aegis(sol, prop, llm_backend=llm, k=k, verbose=False)
    dt = time.time() - t0
    m = res.metrics or {}
    return {
        "contract": base,
        "llm": llm,
        "status": res.status,
        "expected": expected,
        "match": res.status == expected,
        "backend": res.backend_used,
        "repair_rounds": res.repair_rounds,
        "total_repairs": res.total_repairs,
        "first_try_verified": (res.repair_rounds <= 1 and res.status == "VERIFIED"),
        "llm_first_plan_sound_as_proposed": sound_as_proposed,
        "obligations": res.obligations_report,
        "seconds": round(dt, 1),
        "llm_generated_mcvp": _plan_to_dict(first_plan),
        "ag_spec_rendered": rendered_ag,
    }


def _plan_to_dict(p):
    if not p:
        return None
    import dataclasses
    try:
        return dataclasses.asdict(p)
    except Exception:
        return {"contract": getattr(p, "contract", "?"),
                "closure": getattr(p.closure, "functions", None)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--llm", default="openai", choices=["openai", "anthropic", "stub"])
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--repeats", type=int, default=1,
                    help="runs per contract (LLM is nondeterministic; >1 gives honest rates)")
    ap.add_argument("--baseline", action="store_true",
                    help="also run the stub baseline for LLM-vs-template comparison")
    args = ap.parse_args()

    os.makedirs(RESULTS, exist_ok=True)
    backends = [args.llm] + (["stub"] if args.baseline and args.llm != "stub" else [])

    all_records = []
    for llm in backends:
        print(f"\n##### backend = {llm} #####")
        for sol in sorted(glob.glob(os.path.join(CORPUS, "*.sol"))):
            base = os.path.basename(sol)
            if base.endswith(".harness.sol") or base not in TARGETS:
                continue
            prop, expected = TARGETS[base]
            runs = [run_one(sol, prop, expected, llm, args.k)
                    for _ in range(args.repeats)]
            matches = sum(r["match"] for r in runs)
            first_try = sum(r["first_try_verified"] for r in runs)
            sound_prop = sum(bool(r["llm_first_plan_sound_as_proposed"]) for r in runs)
            avg_rounds = statistics.mean(r["repair_rounds"] for r in runs)
            print(f"  {base:24} match {matches}/{args.repeats}  "
                  f"first-try-verify {first_try}/{args.repeats}  "
                  f"LLM-sound-as-proposed {sound_prop}/{args.repeats}  "
                  f"avg_rounds {avg_rounds:.1f}")
            all_records.append({"contract": base, "llm": llm,
                                "repeats": args.repeats, "matches": matches,
                                "first_try_verify": first_try,
                                "llm_sound_as_proposed": sound_prop,
                                "avg_repair_rounds": avg_rounds,
                                "runs": runs})
            # save the LLM-generated artifacts for the paper
            art = os.path.join(RESULTS, f"{base}.{llm}.json")
            with open(art, "w") as fh:
                json.dump(runs[0], fh, indent=2, default=str)

    summary = os.path.join(RESULTS, "summary.json")
    with open(summary, "w") as fh:
        json.dump(all_records, fh, indent=2, default=str)
    print(f"\nartifacts + summary written to {RESULTS}/")
    print("Each results/<contract>.<llm>.json contains the ACTUAL LLM-generated")
    print("MCVP and rendered A/G spec -- real artifacts for the paper.")


if __name__ == "__main__":
    main()
