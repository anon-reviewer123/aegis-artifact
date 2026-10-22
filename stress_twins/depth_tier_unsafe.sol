// SPDX-License-Identifier: MIT
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
