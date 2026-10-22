"""
Generate state-diverging loop-callback twins for RQ1.

Each pair differs only in whether a state effect is applied before or after the
in-loop external call, or whether a guard is present. Unlike the first twin set,
every pair diverges in a STATE VARIABLE under re-entry, not only in transferred
ether, so tools whose safety property is defined over state variables are
answering the same question Aegis answers.
"""
import os

TWINS = {}

TWINS["batch_payout_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract BatchPayoutSafe {
    mapping(address => uint256) public owed;
    uint256 public paidCount;
    address[] public claimants;
    function settle() public {
        for (uint256 i = 0; i < claimants.length; i++) {
            address c = claimants[i];
            uint256 amt = owed[c];
            if (amt == 0) continue;
            owed[c] = 0;
            paidCount += 1;
            (bool ok, ) = c.call{value: amt}("");
            require(ok, "pay failed");
        }
    }
}
'''

TWINS["batch_payout_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract BatchPayoutUnsafe {
    mapping(address => uint256) public owed;
    uint256 public paidCount;
    address[] public claimants;
    function settle() public {
        for (uint256 i = 0; i < claimants.length; i++) {
            address c = claimants[i];
            uint256 amt = owed[c];
            if (amt == 0) continue;
            (bool ok, ) = c.call{value: amt}("");
            require(ok, "pay failed");
            owed[c] = 0;
            paidCount += 1;
        }
    }
}
'''

TWINS["escrow_release_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract EscrowReleaseSafe {
    mapping(address => uint256) public held;
    uint256 public released;
    address[] public parties;
    function release() public {
        for (uint256 i = 0; i < parties.length; i++) {
            address p = parties[i];
            uint256 amt = held[p];
            if (amt == 0) continue;
            held[p] = 0;
            released += amt;
            (bool ok, ) = p.call{value: amt}("");
            require(ok, "release failed");
        }
    }
}
'''

TWINS["escrow_release_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract EscrowReleaseUnsafe {
    mapping(address => uint256) public held;
    uint256 public released;
    address[] public parties;
    function release() public {
        for (uint256 i = 0; i < parties.length; i++) {
            address p = parties[i];
            uint256 amt = held[p];
            if (amt == 0) continue;
            (bool ok, ) = p.call{value: amt}("");
            require(ok, "release failed");
            held[p] = 0;
            released += amt;
        }
    }
}
'''

TWINS["vesting_claim_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract VestingClaimSafe {
    mapping(address => uint256) public vested;
    uint256 public claimedTotal;
    address[] public beneficiaries;
    function claimAll() public {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address b = beneficiaries[i];
            uint256 amt = vested[b];
            if (amt == 0) continue;
            vested[b] = 0;
            claimedTotal += amt;
            (bool ok, ) = b.call{value: amt}("");
            require(ok, "claim failed");
        }
    }
}
'''

TWINS["vesting_claim_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract VestingClaimUnsafe {
    mapping(address => uint256) public vested;
    uint256 public claimedTotal;
    address[] public beneficiaries;
    function claimAll() public {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address b = beneficiaries[i];
            uint256 amt = vested[b];
            if (amt == 0) continue;
            (bool ok, ) = b.call{value: amt}("");
            require(ok, "claim failed");
            vested[b] = 0;
            claimedTotal += amt;
        }
    }
}
'''

TWINS["fee_split_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract FeeSplitSafe {
    mapping(address => uint256) public shareOf;
    uint256 public feePool;
    uint256 public distributed;
    bool public splitting;
    address[] public earners;
    function split() public {
        require(!splitting, "reentrant");
        splitting = true;
        uint256 snapshot = feePool;
        for (uint256 i = 0; i < earners.length; i++) {
            address e = earners[i];
            uint256 amt = snapshot * shareOf[e] / 100;
            (bool ok, ) = e.call{value: amt}("");
            require(ok, "split failed");
        }
        distributed += snapshot;
        feePool = 0;
        splitting = false;
    }
}
'''

TWINS["fee_split_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract FeeSplitUnsafe {
    mapping(address => uint256) public shareOf;
    uint256 public feePool;
    uint256 public distributed;
    address[] public earners;
    function split() public {
        uint256 snapshot = feePool;
        for (uint256 i = 0; i < earners.length; i++) {
            address e = earners[i];
            uint256 amt = snapshot * shareOf[e] / 100;
            (bool ok, ) = e.call{value: amt}("");
            require(ok, "split failed");
        }
        distributed += snapshot;
        feePool = 0;
    }
}
'''

TWINS["airdrop_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract AirdropSafe {
    mapping(address => uint256) public alloc;
    uint256 public sentTotal;
    bool public sending;
    address[] public recipients;
    function airdrop() public {
        require(!sending, "reentrant");
        sending = true;
        uint256 budget = sentTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 amt = budget * alloc[r] / 100;
            (bool ok, ) = r.call{value: amt}("");
            require(ok, "airdrop failed");
        }
        sentTotal = 0;
        sending = false;
    }
}
'''

TWINS["airdrop_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract AirdropUnsafe {
    mapping(address => uint256) public alloc;
    uint256 public sentTotal;
    address[] public recipients;
    function airdrop() public {
        uint256 budget = sentTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 amt = budget * alloc[r] / 100;
            (bool ok, ) = r.call{value: amt}("");
            require(ok, "airdrop failed");
        }
        sentTotal = 0;
    }
}
'''

TWINS["queue_drain_safe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract QueueDrainSafe {
    mapping(address => uint256) public pending;
    mapping(address => bool) public stuck;
    address[] public queue;
    function drain() public {
        for (uint256 i = 0; i < queue.length; i++) {
            address q = queue[i];
            uint256 amt = pending[q];
            if (amt == 0) continue;
            pending[q] = 0;
            (bool ok, ) = q.call{value: amt}("");
            if (!ok) { pending[q] = amt; stuck[q] = true; }
        }
    }
}
'''

TWINS["queue_drain_unsafe"] = '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract QueueDrainUnsafe {
    mapping(address => uint256) public pending;
    mapping(address => bool) public stuck;
    address[] public queue;
    function drain() public {
        for (uint256 i = 0; i < queue.length; i++) {
            address q = queue[i];
            uint256 amt = pending[q];
            if (amt == 0) continue;
            pending[q] = 0;
            (bool ok, ) = q.call{value: amt}("");
            require(ok, "drain failed");
            stuck[q] = false;
        }
    }
}
'''


def main(outdir="loop_twins_v2"):
    os.makedirs(outdir, exist_ok=True)
    for name, src in TWINS.items():
        path = os.path.join(outdir, name + ".sol")
        open(path, "w").write(src)
        print(f"wrote {path}")
    print(f"\n{len(TWINS)} contracts, {len(TWINS)//2} pairs")


if __name__ == "__main__":
    import sys
    main(sys.argv[1] if len(sys.argv) > 1 else "loop_twins_v2")
