import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis.static_analysis import analyze
from aegis import synth, validator, compiler, backend, harness_synth


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("contract")
    ap.add_argument("--property", required=True)
    ap.add_argument("--obligation", default="OBL_post")
    ap.add_argument("--llm", default="openai")
    ap.add_argument("--save", default="")
    ap.add_argument("--run", action="store_true")
    args = ap.parse_args()

    facts = analyze(args.contract)
    site = facts.exposure_sites[0]
    plans = synth.sample_plans(facts, site, args.property,
                               backend=args.llm, k=1)
    plan = plans[0]
    failed = validator.validate(plan, facts, site)
    print(f"plan validation: {failed or 'ACCEPTED'}")
    print(f"closure        : {sorted(plan.closure.functions)}")
    print(f"exposure_inv   : {plan.exposure_invariant.formula}")
    print(f"kind           : {plan.exposure_invariant.kind}")
    print(f"ghost_state    : {[(g.name, g.sol_type) for g in plan.ghost_state]}")
    print()

    src = open(args.contract, errors="ignore").read()
    harness = harness_synth.synthesize_harness(src, facts, site,
                                               args.property)
    obs = compiler.compile_obligations(plan, facts, harness)
    names = [o.name for o in obs]
    print(f"obligations    : {names}\n")

    target = [o for o in obs if o.name == args.obligation]
    if not target:
        print(f"{args.obligation} not emitted")
        return 1
    o = target[0]

    out = args.save or f"/tmp/{args.obligation}.sol"
    with open(out, "w") as fh:
        fh.write(o.harness_source)
    print(f"wrote {out}\n")
    print(o.harness_source)

    if args.run:
        print("\n--- backend ---")
        res = backend.check_obligation(o.name, o.module, o.harness_source)
        print(f"status      : {res.status}")
        print(f"detail      : {res.detail}")
        cex = getattr(res, "counterexample", "")
        if cex:
            print("counterexample:")
            print(cex)
    return 0


if __name__ == "__main__":
    sys.exit(main())
