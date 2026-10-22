// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// Progress invariant: every non-reverting claimant is eventually paid; a single
// reverting callee cannot halt the loop (failures are recorded, not reverted).
// The safety property is liveness-flavored: index strictly advances each
// iteration regardless of callee behavior. RAVEN's unrolling can't prove this
// for arbitrary claimant counts.
contract GriefingSafe {
    mapping(address => uint256) public owed;
    address[] public claimants;
    mapping(address => bool) public failed;

    function record(address who, uint256 amount) external {
        if (owed[who] == 0) claimants.push(who);
        owed[who] += amount;
    }

    function settle() external {
        for (uint256 i = 0; i < claimants.length; i++) {
            address c = claimants[i];
            uint256 amt = owed[c];
            if (amt == 0) continue;
            owed[c] = 0;
            (bool ok, ) = c.call{value: amt}("");
            if (!ok) { owed[c] = amt; failed[c] = true; } // record, do NOT revert
        }
    }
}
