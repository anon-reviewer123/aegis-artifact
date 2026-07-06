#!/usr/bin/env python3
"""Aegis CLI: verify a callback-exposed Solidity contract against a target
property via MCVP synthesis + real SMTChecker discharge + fixpoint repair.

Usage:
  python3 run_aegis.py contracts/MotivatingVault.sol \
      --property "totalAssets == totalShares" \
      --llm openai --k 4 --max-repair-rounds 8 --smt-timeout-ms 0
"""
import argparse, json
from aegis.pipeline import run_aegis
from aegis.experiment import ABLATION_MODES, REPAIR_STRATEGIES


def main():
    ap = argparse.ArgumentParser(description="Aegis callback verification")
    ap.add_argument("contract")
    ap.add_argument("--property", required=True)
    ap.add_argument("--llm", default="stub", choices=["stub", "anthropic", "openai"])
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--max-repair-rounds", type=int, default=8)
    ap.add_argument("--smt-timeout-ms", type=int, default=90000,
                    help="per-obligation SMTChecker timeout in ms (0 = solver default)")
    ap.add_argument("--json", action="store_true", help="emit machine-readable report")
    ap.add_argument("--ablate", default="none", choices=ABLATION_MODES,
                    help="RQ3: disable one MCVP module (default: none)")
    ap.add_argument("--repair", default="cegar-reuse", choices=REPAIR_STRATEGIES,
                    help="RQ4: repair strategy (default: cegar-reuse)")
    args = ap.parse_args()

    res = run_aegis(args.contract, args.property, llm_backend=args.llm,
                    k=args.k, max_repair_rounds=args.max_repair_rounds,
                    smt_timeout_ms=args.smt_timeout_ms, verbose=not args.json,
                    ablate=args.ablate, repair=args.repair)
    if args.json:
        d = {"contract": args.contract, "status": res.status,
             "backend": res.backend_used, "candidates_tried": res.candidates_tried,
             "repair_rounds": res.repair_rounds, "total_repairs": res.total_repairs,
             "obligations": res.obligations_report,
             "ablate": args.ablate, "repair_strategy": args.repair}
        d.update(res.metrics)
        print(json.dumps(d, indent=2))
        return
    print("\n=================== RESULT ===================")
    print("STATUS:", res.status)
    print("BACKEND:", res.backend_used)
    print("CANDIDATES TRIED:", res.candidates_tried)
    print("REPAIR ROUNDS:", res.repair_rounds)
    print("TOTAL MODULE REPAIRS:", res.total_repairs)
    if res.plan:
        print("FINAL CLOSURE:", res.plan.closure.functions)
        print("EXPOSURE INVARIANT:", res.plan.exposure_invariant.formula)
    if res.status in ("BUG_FOUND",):
        for o in res.obligations_report:
            if o["status"] == "failed":
                print("FAILED OBLIGATION:", o["obligation"], "->", o["detail"])


if __name__ == "__main__":
    main()
