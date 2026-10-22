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
from aegis.experiment import SLICE_MODES, SITE_MODES, ABLATION_MODES, REPAIR_STRATEGIES


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
    ap.add_argument("--sites", default="primary", choices=SITE_MODES,
                    help="general arm: verify the highest-ranked exposure "
                         "site only (primary), or decompose every windowed "
                         "site and require the verdict at each (all)")
    ap.add_argument("--eoa-gates", default="trusted",
                    choices=("trusted", "untrusted"),
                    help="whether a tx.origin == msg.sender gate closes a "
                         "function to the re-entering contract; untrusted "
                         "keeps such functions in the closure (EIP-7702)")
    ap.add_argument("--trace", default="",
                    help="directory to keep everything the run produces: "
                         "harness, plans per round, every obligation with the "
                         "solver's raw output, the validator's messages")
    ap.add_argument("--slice", default="off", choices=SLICE_MODES,
                    help="general arm: build each obligation over a slice of "
                         "the harness holding only what it can observe")
    ap.add_argument("--fresh-harness", action="store_true",
                    help="rebuild the synthesized harness even if the cached "
                         "one matches; hand-written harnesses are never touched")
    args = ap.parse_args()
    from aegis import static_analysis as _sa
    _sa.TRUST_EOA_GATES = (args.eoa_gates == "trusted")

    res = run_aegis(args.contract, args.property, llm_backend=args.llm,
                    k=args.k, max_repair_rounds=args.max_repair_rounds,
                    smt_timeout_ms=args.smt_timeout_ms, verbose=not args.json,
                    ablate=args.ablate, repair=args.repair,
                    fresh_harness=args.fresh_harness, sites=args.sites,
                    slice_mode=args.slice,
                    trace_dir=args.trace or None)
    if args.json:
        d = {"contract": args.contract, "status": res.status,
             "backend": res.backend_used, "candidates_tried": res.candidates_tried,
             "repair_rounds": res.repair_rounds, "total_repairs": res.total_repairs,
             "obligations": res.obligations_report,
             "ablate": args.ablate, "repair_strategy": args.repair,
             # The run log goes into the JSON so a batch driver can report why
             # a contract ended where it did, instead of only that it did.
             "log": res.log}
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
        # A canary is refuted on purpose: its conclusion is assert(false), so a
        # violation means the harness body is reachable and the real verdict is
        # not vacuous. Listing it beside genuine failures reads as though the
        # tool found two bugs.
        fired = [o["obligation"] for o in res.obligations_report
                 if o["obligation"].endswith("_canary") and o["status"] == "failed"]
        for o in res.obligations_report:
            if o["status"] == "failed" and not o["obligation"].endswith("_canary"):
                print("FAILED OBLIGATION:", o["obligation"], "->", o["detail"])
        if fired:
            print("REACHABILITY CANARIES FIRED:", ", ".join(fired))


if __name__ == "__main__":
    main()
