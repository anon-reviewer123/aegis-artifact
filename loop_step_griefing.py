"""
Gap 1 Step 2c: inductive loop-step obligation for the GRIEFING (progress) shape.

Griefing is a LIVENESS property ("the loop advances past every claimant even if
one callee misbehaves"). SMTChecker proves SAFETY, so we encode the checkable
safety property:

    "processing a claimant does not abort the loop due to that claimant's callee"

We model the callee's failure as a symbolic boolean `calleeFails` (a real EVM
revert just aborts and is not an assertion violation, so we model the failure
explicitly). After handling a claimant, a boolean `advanced` must be true.

SAFE (griefing_safe): on failure the contract records it (owed restored,
  failed=true) and continues -> advanced=true regardless of calleeFails -> holds.
UNSAFE (propagating analogue): on failure it does `require(ok)`, i.e. aborts ->
  advanced stays false -> assert(advanced) is violated when calleeFails.

Reachability: state seeded from parameters inside check().
"""

SAFE_STEP = r'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Progress-preserving iteration: a failing callee does NOT halt the loop.
contract GriefingSafeStepH {
    uint256 public ownedC;
    bool    public advanced;
    bool    public failedC;

    function check(uint256 w, bool calleeFails) public {
        require(w > 0 && w < (1 << 128));
        ownedC = w; advanced = false; failedC = false;
        // one iteration:
        uint256 amt = ownedC;
        ownedC = 0;
        if (calleeFails) {
            // SAFE: record the failure, DO NOT abort
            ownedC = amt;
            failedC = true;
        }
        advanced = true;                 // loop advances regardless
        assert(advanced);                // progress holds for every claimant
    }
}
'''

UNSAFE_STEP = r'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Progress-BREAKING iteration: a failing callee aborts the whole loop.
contract GriefingUnsafeStepH {
    uint256 public ownedC;
    bool    public advanced;
    bool    public aborted;

    function check(uint256 w, bool calleeFails) public {
        require(w > 0 && w < (1 << 128));
        ownedC = w; advanced = false; aborted = false;
        uint256 amt = ownedC;
        ownedC = 0;
        if (calleeFails) {
            // UNSAFE: propagate the failure -> abort (modelled as a flag, since a
            // real revert would just abort the tx). The loop does NOT advance.
            aborted = true;
            ownedC = amt;
            // note: 'advanced' is NEVER set on this path
        } else {
            advanced = true;
        }
        // progress property: every claimant is advanced past.
        assert(advanced);                // FAILS when calleeFails (advanced=false)
    }
}
'''

import sys, os
if __name__ == "__main__":
    out = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else ".")
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, "griefing_safe_step.sol"), "w").write(SAFE_STEP)
    open(os.path.join(out, "griefing_unsafe_step.sol"), "w").write(UNSAFE_STEP)
    print("wrote griefing_safe_step.sol and griefing_unsafe_step.sol to", out)
