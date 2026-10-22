// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// Griefing-VULNERABLE: a failing callee HALTS the whole loop, because the call's
// failure is propagated via require(ok). One malicious claimant that always
// reverts blocks every subsequent claimant from being paid. No progress guarantee.
contract GriefingUnsafe {
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
            require(ok, "refund failed");   // PROPAGATES failure -> halts the loop
            failed[c] = false;
        }
    }
}
