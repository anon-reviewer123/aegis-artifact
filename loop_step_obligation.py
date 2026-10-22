"""
Gap 1 Step 2: inductive loop-step obligation (sound, discriminating, reachable).

Per-claimant safety invariant for one loop iteration:  paidForC <= wInit
(a claimant is paid at most what they were owed). Double-payment via loop
re-entrancy makes paidForC = 2*wInit and is caught.

Reachability fix: the pre-state (ownedC > 0, paidForC == 0) is established INSIDE
check() from a symbolic parameter, so SMTChecker sees a reachable path (a harness
with no setter leaves ownedC == 0 forever, making the check vacuously unreachable).

Statement order mirrors the real contracts:
  SAFE   : capture; owed=0; call; pay captured   (effect before interaction)
  UNSAFE : capture; call; owed=0; pay captured   (interaction before effect)
"""

SAFE_STEP = r'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract RefundSafeStepH {
    uint256 public ownedC;
    uint256 public paidForC;

    // re-entrant settle() on claimant c: pays whatever is STILL owed now.
    function callback() internal {
        uint256 cur = ownedC;
        if (cur == 0) return;
        ownedC = 0;
        paidForC += cur;
    }

    // w is symbolic; we set up a feasible pre-state so the body is reachable.
    function check(uint256 w) public {
        require(w > 0 && w < (1 << 128));   // feasible, no overflow
        ownedC = w;                          // establish pre-state
        paidForC = 0;
        uint256 wInit = w;
        // SAFE: capture, EFFECT (zero), INTERACTION (call), pay captured
        uint256 amt = ownedC;
        ownedC = 0;
        callback();                          // sees ownedC==0 -> no extra pay
        paidForC += amt;
        assert(paidForC <= wInit);
    }
}
'''

UNSAFE_STEP = r'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract RefundUnsafeStepH {
    uint256 public ownedC;
    uint256 public paidForC;

    function callback() internal {
        uint256 cur = ownedC;
        if (cur == 0) return;
        ownedC = 0;
        paidForC += cur;
    }

    function check(uint256 w) public {
        require(w > 0 && w < (1 << 128));
        ownedC = w;
        paidForC = 0;
        uint256 wInit = w;
        // UNSAFE: capture, INTERACTION (call), EFFECT (zero), pay captured
        uint256 amt = ownedC;
        callback();                          // sees ownedC==w -> pays c once
        ownedC = 0;
        paidForC += amt;                     // pays captured amt AGAIN -> double
        assert(paidForC <= wInit);           // FAILS: paidForC == 2*w
    }
}
'''

import sys, os
if __name__ == "__main__":
    out = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else ".")
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, "refund_safe_step.sol"), "w").write(SAFE_STEP)
    open(os.path.join(out, "refund_unsafe_step.sol"), "w").write(UNSAFE_STEP)
    print("wrote refund_safe_step.sol and refund_unsafe_step.sol to", out)
