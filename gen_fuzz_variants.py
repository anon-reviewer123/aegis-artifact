"""
Build fuzzer-runnable variants of the loop twins.

The benchmark contracts are verification targets: their state is not reachable
through a public interface, so an executing tool cannot drive the loop. This
script adds one `seed` function per contract that appends a claimant and sets
the amount owed. Nothing inside the loop body, and nothing about the ordering of
the external call and the state effect, is changed -- the added function only
makes the pre-state constructible.

Static results collected on the originals therefore still hold; only the fuzzer
runs on these variants, and the paper says so.
"""
import os
import re

# family -> (source dir, contract prefix, settle fn, mapping, array, extra scalar)
FAMILIES = {
    "refund":          ("loop_twins",    "Refund",         "settle",     "owed",      "claimants",     None),
    "griefing":        ("loop_twins",    "Griefing",       "settle",     "owed",      "claimants",     None),
    "batch_payout":    ("loop_twins_v2", "BatchPayout",    "settle",     "owed",      "claimants",     None),
    "escrow_release":  ("loop_twins_v2", "EscrowRelease",  "release",    "held",      "parties",       None),
    "vesting_claim":   ("loop_twins_v2", "VestingClaim",   "claimAll",   "vested",    "beneficiaries", None),
    "queue_drain":     ("loop_twins_v2", "QueueDrain",     "drain",      "pending",   "queue",         None),
    "depth_tier":      ("stress_twins",  "DepthTier",      "settle",     "owed",      "claimants",     None),
    "depth_streak":    ("stress_twins",  "DepthStreak",    "drain",      "owed",      "queue",         None),
    "nonlinear_rate":  ("stress_twins",  "NonlinearRate",  "repay",      "principal", "lenders",       "rate"),
    "widening_accum":  ("stress_twins",  "WideningAccum",  "distribute", "due",       "members",       None),
    "widening_ledger": ("stress_twins",  "WideningLedger", "close",      "credit",    "accounts",      None),
}


def seed_fn(mapping, array, scalar):
    extra = f"\n        {scalar} = r;" if scalar else ""
    param = ", uint256 r" if scalar else ""
    return f'''
    // added for fuzzing only: makes the pre-state constructible.
    function seed(address who, uint256 amount{param}) external payable {{
        {mapping}[who] = amount;
        {array}.push(who);{extra}
    }}
'''


def main(outdir="fuzz/src"):
    os.makedirs(outdir, exist_ok=True)
    n = 0
    for fam, (d, _cls, _fn, mapping, array, scalar) in FAMILIES.items():
        for variant in ("safe", "unsafe"):
            path = f"{d}/{fam}_{variant}.sol"
            if not os.path.exists(path):
                print(f"  missing {path}")
                continue
            src = open(path).read()
            if f"function seed(" in src:
                out = src
            else:
                idx = src.rstrip().rfind("}")
                out = src[:idx] + seed_fn(mapping, array, scalar) + "}\n"
            open(os.path.join(outdir, f"{fam}_{variant}.sol"), "w").write(out)
            n += 1
    print(f"wrote {n} fuzzer variants to {outdir}")


if __name__ == "__main__":
    main()
