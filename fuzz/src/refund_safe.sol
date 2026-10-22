// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// Batch refund. Safety: total paid never exceeds total owed, even if a callee
// re-enters settle() during its .call. Owed is zeroed before the external call
// (effect-before-interaction) INSIDE the loop, so a re-entrant iteration sees 0
// for an already-paid claimant. RAVEN cannot verify this soundly: the call-site
// is inside the loop, breaking its topological-order requirement.
contract RefundSafe {
    mapping(address => uint256) public owed;
    uint256 public totalOwed;
    address[] public claimants;

    function record(address who, uint256 amount) external {
        if (owed[who] == 0) claimants.push(who);
        owed[who] += amount;
        totalOwed += amount;
    }

    function settle() external {
        for (uint256 i = 0; i < claimants.length; i++) {
            address c = claimants[i];
            uint256 amt = owed[c];
            if (amt == 0) continue;
            owed[c] = 0;                       // EFFECT before interaction
            totalOwed -= amt;
            (bool ok, ) = c.call{value: amt}(""); // external call INSIDE loop
            require(ok, "refund failed");
        }
    }

    // added for fuzzing only: makes the pre-state constructible.
    function seed(address who, uint256 amount) external payable {
        owed[who] = amount;
        claimants.push(who);
    }
}
