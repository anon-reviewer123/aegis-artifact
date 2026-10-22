"""
Foundry invariant tests for the fuzzer-runnable twin variants.

Every family gets the same solvency invariant: the target is funded with ten
times what it owes the single seeded claimant, so at most one unit may ever
leave. A re-entrant double payment breaks that. The invariant names no function,
no statement and no ordering, so the fuzzer has to find the violation itself.
"""
import os

FAMILIES = {
    "refund":          ("Refund",         "settle()"),
    "griefing":        ("Griefing",       "settle()"),
    "batch_payout":    ("BatchPayout",    "settle()"),
    "escrow_release":  ("EscrowRelease",  "release()"),
    "vesting_claim":   ("VestingClaim",   "claimAll()"),
    "queue_drain":     ("QueueDrain",     "drain()"),
    "depth_tier":      ("DepthTier",      "settle()"),
    "depth_streak":    ("DepthStreak",    "drain()"),
    "widening_accum":  ("WideningAccum",  "distribute()"),
    "widening_ledger": ("WideningLedger", "close()"),
}
NONLINEAR = {"nonlinear_rate": ("NonlinearRate", "repay()")}

TPL = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/{fam}_{variant}.sol";
import "../Attacker.sol";

contract {cls}{V}Inv is Test {{
    {cls}{V} internal target;
    Attacker internal attacker;

    uint256 constant OWED   = 1 ether;
    uint256 constant FUNDED = 10 ether;

    function setUp() public {{
        target = new {cls}{V}();
        attacker = new Attacker();
        attacker.configure(address(target), abi.encodeWithSignature("{fn}"));
        vm.deal(address(target), FUNDED);
        target.seed{seedargs}(address(attacker), OWED);
        targetContract(address(attacker));
    }}

    /// At most what is owed may ever leave the contract.
    function invariant_solvent() public view {{
        assertGe(address(target).balance, FUNDED - OWED);
    }}
}}
'''


def main(outdir="fuzz/test"):
    os.makedirs(outdir, exist_ok=True)
    n = 0
    for fam, (cls, fn) in list(FAMILIES.items()) + list(NONLINEAR.items()):
        seedargs = ""
        for variant in ("safe", "unsafe"):
            src = TPL.format(fam=fam, variant=variant, cls=cls,
                             V=variant.title(), fn=fn, seedargs=seedargs)
            if fam == "nonlinear_rate":
                src = src.replace("target.seed(address(attacker), OWED);",
                                  "target.seed(address(attacker), OWED, 10000);")
            open(os.path.join(outdir, f"{fam}_{variant}.t.sol"), "w").write(src)
            n += 1
    print(f"wrote {n} invariant tests")


if __name__ == "__main__":
    main()
