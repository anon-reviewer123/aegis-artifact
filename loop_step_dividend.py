"""
Gap 1 Step 2b: inductive loop-step obligation for the DIVIDEND (mutex) shape.

Safety invariant:  totalPaid <= poolAtStart
The bug is re-entrant distribute() re-reading the same pool snapshot and paying
holders a second time. The SAFE contract blocks this with a `distributing` mutex;
the UNSAFE one has none.

We model one distribution as: snapshot the pool, pay it out, with the external
call modelled as a re-entrant distribute() (the callback). The callback attempts
a second full distribution.
  SAFE:   the mutex is set before the callback, so the re-entrant distribute()
          hits require(!distributing) and reverts -> pays nothing extra.
  UNSAFE: no mutex, so the callback re-distributes the same snapshot -> double pay.

Reachability: pool is seeded from a symbolic parameter inside check().
"""

SAFE_STEP = r'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract DividendSafeStepH {
    uint256 public pool;
    uint256 public totalPaid;
    bool    public distributing;

    // re-entrant distribute(): guarded by the mutex.
    function callback() internal {
        if (distributing) return;          // mutex blocks re-entry -> pays nothing
        distributing = true;
        uint256 snap = pool;
        totalPaid += snap;
        distributing = false;
    }

    function check(uint256 P) public {
        require(P > 0 && P < (1 << 128));
        pool = P; totalPaid = 0; distributing = false;
        uint256 poolAtStart = pool;
        // one distribution WITH the mutex held across the payout + callback:
        require(!distributing);
        distributing = true;               // SAFE: mutex set for the whole op
        uint256 snapshot = pool;
        callback();                        // re-entrant distribute() -> blocked
        totalPaid += snapshot;             // pay this distribution's snapshot
        distributing = false;
        assert(totalPaid <= poolAtStart);
    }
}
'''

UNSAFE_STEP = r'''// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
contract DividendUnsafeStepH {
    uint256 public pool;
    uint256 public totalPaid;

    // re-entrant distribute(): NO mutex -> re-reads the snapshot and pays again.
    function callback() internal {
        uint256 snap = pool;               // same pool, not yet zeroed
        totalPaid += snap;
    }

    function check(uint256 P) public {
        require(P > 0 && P < (1 << 128));
        pool = P; totalPaid = 0;
        uint256 poolAtStart = pool;
        // UNSAFE: no mutex around the payout
        uint256 snapshot = pool;
        callback();                        // re-entrant distribute() pays a snapshot
        totalPaid += snapshot;             // outer distribution pays again
        assert(totalPaid <= poolAtStart);  // FAILS: totalPaid == 2*P
    }
}
'''

import sys, os
if __name__ == "__main__":
    out = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else ".")
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, "dividend_safe_step.sol"), "w").write(SAFE_STEP)
    open(os.path.join(out, "dividend_unsafe_step.sol"), "w").write(UNSAFE_STEP)
    print("wrote dividend_safe_step.sol and dividend_unsafe_step.sol to", out)
