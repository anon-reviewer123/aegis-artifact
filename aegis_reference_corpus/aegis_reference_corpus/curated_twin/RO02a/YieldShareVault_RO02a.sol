// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract YieldShareVault_RO02a {
    uint256 public constant BOUNTY = 1e16;
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalAssets;
    uint256 public pendingYield;
    bool public inCall;

    function deposit() external payable {
        require(!inCall, "reentrant");
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
        totalAssets += msg.value;
    }

    function addYield() external payable {
        require(!inCall, "reentrant");
        pendingYield += msg.value;
    }

    function harvest(uint256 amount) external {
        require(!inCall, "reentrant");
        require(amount <= pendingYield && amount > BOUNTY, "amount");
        pendingYield -= amount;
        totalAssets += amount - BOUNTY;
        inCall = true;
        (bool ok, ) = payable(msg.sender).call{value: BOUNTY}("");
        require(ok, "bounty");
        inCall = false;
    }

    function pricePerShare() external view returns (uint256) {
        return (totalAssets + pendingYield) * 1e18 / totalShares;
    }
}
