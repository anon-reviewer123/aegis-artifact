// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract RefundUnsafe {
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
            (bool ok, ) = c.call{value: amt}(""); // INTERACTION before effect
            require(ok, "refund failed");
            owed[c] = 0;                       // effect AFTER the call
            totalOwed -= amt;
        }
    }
}
