// SPDX-License-Identifier: MIT
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
