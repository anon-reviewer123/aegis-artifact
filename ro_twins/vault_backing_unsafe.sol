// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract VaultBackingUnsafe {
    mapping(address => uint256) public shares;
    uint256 public totalAssets;
    uint256 public totalShares;
    function deposit() external payable {
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
        totalAssets += msg.value;
    }
    function redeem(address payable to, uint256 amt) public {
        require(shares[to] >= amt, "insufficient");
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "redeem failed");
        shares[to] -= amt;
        totalShares -= amt;
        totalAssets -= amt;
    }
    function backing() public view returns (uint256) {
        return totalAssets + totalShares;
    }
}
