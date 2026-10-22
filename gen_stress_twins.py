"""
Generate stress twins for RQ1, each targeting a documented limitation of the
polyhedral ECF analysis while staying inside the three loop shapes Aegis
classifies (conserve / mutex / progress).

  depth_*      violation first arises at the third payout, beyond the two
               iterations a bounded-unrolling fallback explores
  nonlinear_*  payout computed by symbolic multiplication and division, the
               over-approximation source named as the main false-positive cause
  widening_*   an accumulator grows per iteration, forcing widening in a
               fixpoint-based analysis; an inductive step needs no fixpoint
"""
import os

TWINS = {}

TWINS["depth_tier_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract DepthTierSafe {
    mapping(address => uint256) public owed;
    uint256 public payouts;
    uint256 public bonusPaid;
    address[] public claimants;
    function settle() public {
        for (uint256 i = 0; i < claimants.length; i++) {
            address c = claimants[i];
            uint256 amt = owed[c];
            if (amt == 0) continue;
            owed[c] = 0;
            payouts += 1;
            if (payouts >= 3) { bonusPaid += amt; }
            (bool ok, ) = c.call{value: amt}("");
            require(ok, "pay failed");
        }
    }
}
'''

TWINS["depth_tier_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract DepthTierUnsafe {
    mapping(address => uint256) public owed;
    uint256 public payouts;
    uint256 public bonusPaid;
    address[] public claimants;
    function settle() public {
        for (uint256 i = 0; i < claimants.length; i++) {
            address c = claimants[i];
            uint256 amt = owed[c];
            if (amt == 0) continue;
            (bool ok, ) = c.call{value: amt}("");
            require(ok, "pay failed");
            owed[c] = 0;
            payouts += 1;
            if (payouts >= 3) { bonusPaid += amt; }
        }
    }
}
'''

TWINS["depth_streak_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract DepthStreakSafe {
    mapping(address => uint256) public owed;
    uint256 public streak;
    uint256 public extra;
    address[] public queue;
    function drain() public {
        for (uint256 i = 0; i < queue.length; i++) {
            address q = queue[i];
            uint256 amt = owed[q];
            if (amt == 0) continue;
            owed[q] = 0;
            streak += 1;
            if (streak > 4) { extra += 1; }
            (bool ok, ) = q.call{value: amt}("");
            require(ok, "drain failed");
        }
    }
}
'''

TWINS["depth_streak_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract DepthStreakUnsafe {
    mapping(address => uint256) public owed;
    uint256 public streak;
    uint256 public extra;
    address[] public queue;
    function drain() public {
        for (uint256 i = 0; i < queue.length; i++) {
            address q = queue[i];
            uint256 amt = owed[q];
            if (amt == 0) continue;
            (bool ok, ) = q.call{value: amt}("");
            require(ok, "drain failed");
            owed[q] = 0;
            streak += 1;
            if (streak > 4) { extra += 1; }
        }
    }
}
'''

TWINS["nonlinear_rate_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract NonlinearRateSafe {
    mapping(address => uint256) public principal;
    uint256 public rate;
    uint256 public disbursed;
    address[] public lenders;
    function repay() public {
        for (uint256 i = 0; i < lenders.length; i++) {
            address l = lenders[i];
            uint256 amt = principal[l] * rate / 10000;
            if (amt == 0) continue;
            principal[l] = 0;
            disbursed += amt;
            (bool ok, ) = l.call{value: amt}("");
            require(ok, "repay failed");
        }
    }
}
'''

TWINS["nonlinear_rate_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract NonlinearRateUnsafe {
    mapping(address => uint256) public principal;
    uint256 public rate;
    uint256 public disbursed;
    address[] public lenders;
    function repay() public {
        for (uint256 i = 0; i < lenders.length; i++) {
            address l = lenders[i];
            uint256 amt = principal[l] * rate / 10000;
            if (amt == 0) continue;
            (bool ok, ) = l.call{value: amt}("");
            require(ok, "repay failed");
            principal[l] = 0;
            disbursed += amt;
        }
    }
}
'''

TWINS["nonlinear_curve_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract NonlinearCurveSafe {
    mapping(address => uint256) public weight;
    uint256 public reserve;
    uint256 public totalWeight;
    bool public curving;
    address[] public holders;
    function payout() public {
        require(!curving, "reentrant");
        curving = true;
        uint256 snap = reserve;
        for (uint256 i = 0; i < holders.length; i++) {
            address h = holders[i];
            uint256 amt = snap * weight[h] / (totalWeight + 1);
            (bool ok, ) = h.call{value: amt}("");
            require(ok, "payout failed");
        }
        reserve = 0;
        curving = false;
    }
}
'''

TWINS["nonlinear_curve_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract NonlinearCurveUnsafe {
    mapping(address => uint256) public weight;
    uint256 public reserve;
    uint256 public totalWeight;
    address[] public holders;
    function payout() public {
        uint256 snap = reserve;
        for (uint256 i = 0; i < holders.length; i++) {
            address h = holders[i];
            uint256 amt = snap * weight[h] / (totalWeight + 1);
            (bool ok, ) = h.call{value: amt}("");
            require(ok, "payout failed");
        }
        reserve = 0;
    }
}
'''

TWINS["widening_accum_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract WideningAccumSafe {
    mapping(address => uint256) public due;
    uint256 public cumulative;
    uint256 public rounds;
    address[] public members;
    function distribute() public {
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            uint256 amt = due[m];
            if (amt == 0) continue;
            due[m] = 0;
            cumulative += amt;
            rounds += 1;
            (bool ok, ) = m.call{value: amt}("");
            require(ok, "distribute failed");
        }
    }
}
'''

TWINS["widening_accum_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract WideningAccumUnsafe {
    mapping(address => uint256) public due;
    uint256 public cumulative;
    uint256 public rounds;
    address[] public members;
    function distribute() public {
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            uint256 amt = due[m];
            if (amt == 0) continue;
            (bool ok, ) = m.call{value: amt}("");
            require(ok, "distribute failed");
            due[m] = 0;
            cumulative += amt;
            rounds += 1;
        }
    }
}
'''

TWINS["widening_ledger_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract WideningLedgerSafe {
    mapping(address => uint256) public credit;
    mapping(address => bool) public settled;
    uint256 public ledgerTotal;
    address[] public accounts;
    function close() public {
        for (uint256 i = 0; i < accounts.length; i++) {
            address a = accounts[i];
            uint256 amt = credit[a];
            if (amt == 0) continue;
            credit[a] = 0;
            ledgerTotal += amt;
            (bool ok, ) = a.call{value: amt}("");
            if (!ok) { credit[a] = amt; settled[a] = false; }
        }
    }
}
'''

TWINS["widening_ledger_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract WideningLedgerUnsafe {
    mapping(address => uint256) public credit;
    mapping(address => bool) public settled;
    uint256 public ledgerTotal;
    address[] public accounts;
    function close() public {
        for (uint256 i = 0; i < accounts.length; i++) {
            address a = accounts[i];
            uint256 amt = credit[a];
            if (amt == 0) continue;
            credit[a] = 0;
            ledgerTotal += amt;
            (bool ok, ) = a.call{value: amt}("");
            require(ok, "close failed");
            settled[a] = true;
        }
    }
}
'''


def main(outdir="stress_twins"):
    os.makedirs(outdir, exist_ok=True)
    for name, src in TWINS.items():
        open(os.path.join(outdir, name + ".sol"), "w").write(src)
        print(f"wrote {outdir}/{name}.sol")
    print(f"\n{len(TWINS)} contracts, {len(TWINS)//2} pairs")


if __name__ == "__main__":
    import sys
    main(sys.argv[1] if len(sys.argv) > 1 else "stress_twins")
