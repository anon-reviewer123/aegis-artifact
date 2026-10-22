// SPDX-License-Identifier: MIT
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
