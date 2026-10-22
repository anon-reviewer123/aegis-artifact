#!/usr/bin/env python3
"""Generate the v2 read-only twin family.

The original ro_twins cannot discriminate under Lemma 1. Both members write
every footprint variable on one side of the external call, so the mid-window
observation equals the entry observation and the three-state disjunction holds
for the unsafe member too. They also carry an unguarded public writer of the
footprint, so the admissibility premise refuses both.

Each pair here fixes both problems:

  * a mutex the exposure function holds across the call, and every other entry
    point guarded on it, so the premise admits the view;
  * identical structure in both members, so discrimination comes from the
    obligation rather than from one member being refused;
  * the safe member settles every footprint variable before yielding control,
    while the unsafe member splits them across the call, leaving the view
    reading one updated and one stale field mid-window -- an observation that
    matches neither the entry nor the settled value.

  python3 gen_ro_twins_v2.py --out ro_twins_v2 --manifest rq1_twins_v2.json
"""
import argparse
import json
import os

# name, unit noun, counter, total, view name, view body
VARIANTS = [
    ("Escrow", "escrowed", "openEscrows", "totalEscrowed", "averageEscrow",
     "return totalEscrowed / openEscrows;"),
    ("Amm", "shares", "activeLots", "reserveTotal", "quote",
     "return reserveTotal / activeLots;"),
    ("Lending", "collateral", "openLoans", "debtTotal", "healthFactor",
     "return debtTotal / openLoans;"),
    ("LpVault", "units", "lpHolders", "poolValue", "pricePerUnit",
     "return poolValue / lpHolders;"),
    ("Staking", "staked", "stakerCount", "rewardPool", "rewardIndex",
     "return rewardPool / stakerCount;"),
    ("Backing", "deposits", "openClaims", "backingTotal", "coverageRatio",
     "return backingTotal / openClaims;"),
    ("PullPayment", "credits", "openCredits", "creditTotal", "averageCredit",
     "return creditTotal / openCredits;"),
    ("FeeSplit", "entitled", "openPayees", "feeTotal", "sharePerPayee",
     "return feeTotal / openPayees;"),
]

TEMPLATE = """// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, {kind} member.
/// {note}
/// {fund_fn}() is guarded on the same flag {settle_fn}() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract {contract} {{
    mapping(address => uint256) public {unit};
    uint256 public {counter};
    uint256 public {total};
    bool public inCall;

    function {fund_fn}(address party) external payable {{
        require(!inCall, "reentrant");
        {unit}[party] += msg.value;
        {counter} += 1;
        {total} += msg.value;
    }}

    function {settle_fn}(address payable party) public {{
        require(!inCall, "reentrant");
        uint256 amt = {unit}[party];
        require(amt > 0, "nothing owed");
        {pre_body}
        inCall = true;
        (bool ok, ) = party.call{{value: amt}}("");
        require(ok, "transfer failed");
        inCall = false;
        {post_body}
    }}

    function {view_fn}() public view returns (uint256) {{
        if ({counter} == 0) return 0;
        {view_body}
    }}
}}
"""

SAFE_NOTE = ("Every footprint write is settled before control leaves the "
             "contract, so the observation during the window equals the "
             "settled observation.")
UNSAFE_NOTE = ("{counter} is decremented before the call and {total} only "
               "after it, so {view_fn}() read during the window divides a "
               "stale total by an updated count and matches neither the entry "
               "nor the settled value.")


def build(variant, safe):
    name, unit, counter, total, view_fn, view_body = variant
    fund_fn = "fund"
    settle_fn = "settle"
    if safe:
        pre = (f"{counter} -= 1;\n        {total} -= amt;\n"
               f"        {unit}[party] = 0;")
        post = "// footprint already settled before the call"
        note = SAFE_NOTE
    else:
        pre = f"{counter} -= 1;"
        post = f"{total} -= amt;\n        {unit}[party] = 0;"
        note = UNSAFE_NOTE.format(counter=counter, total=total,
                                  view_fn=view_fn)
    contract = name + ("Safe" if safe else "Unsafe")
    return TEMPLATE.format(
        kind="quiescent" if safe else "non-quiescent", note=note,
        contract=contract, unit=unit, counter=counter, total=total,
        fund_fn=fund_fn, settle_fn=settle_fn, pre_body=pre, post_body=post,
        view_fn=view_fn, view_body=view_body)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="ro_twins_v2")
    ap.add_argument("--manifest", default="rq1_twins_v2.json")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    outdir = os.path.join(here, args.out)
    os.makedirs(outdir, exist_ok=True)

    payload = {"_README": "Read-only twins v2. Both members of a pair share "
                          "the same guarded closure so the footprint premise "
                          "admits each; they differ only in whether the "
                          "exposure function's footprint writes straddle the "
                          "external call."}
    written = 0
    for v in VARIANTS:
        name, _unit, counter, total, _view, _body = v
        pair = "ro2_" + name.lower()
        for safe in (True, False):
            slug = f"{name.lower()}_{'safe' if safe else 'unsafe'}.sol"
            path = os.path.join(outdir, slug)
            with open(path, "w") as fh:
                fh.write(build(v, safe))
            written += 1
            payload[f"{args.out}/{slug}"] = {
                "pair": pair,
                "pattern": "read_only",
                "arm": "fixed",
                "label": "safe" if safe else "unsafe",
                "expected": "VERIFIED" if safe else "BUG_FOUND",
                "property": f"{total} == {counter}",
            }

    with open(os.path.join(here, args.manifest), "w") as fh:
        json.dump(payload, fh, indent=1)
    print(f"wrote {written} contract(s) to {args.out}/")
    print(f"wrote {args.manifest} with {len(payload) - 1} entries")


if __name__ == "__main__":
    main()
