// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LiquidityVault_CF02a {
    mapping(address => uint256) public shares;
    uint256 public totalAssets;
    uint256 public totalClaims;
    address public feeRecipient;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function enter() external payable {
        shares[msg.sender] += msg.value;
        totalAssets += msg.value;
        totalClaims += msg.value;
    }

    function donate() external payable {
        totalAssets += msg.value;
    }

    function claimSurplus() external {
        require(totalAssets > totalClaims, "no surplus");
        uint256 surplus = totalAssets - totalClaims;
        shares[msg.sender] += surplus;
        totalClaims += surplus;
    }

    function exitPosition(uint256 amount) external {
        require(shares[msg.sender] >= amount, "position");
        shares[msg.sender] -= amount;
        totalClaims -= amount;
        totalAssets -= amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "payout");
    }

    function setFeeRecipient(address r) external onlyOwner {
        feeRecipient = r;
    }

    function surplus() external view returns (uint256) {
        return totalAssets > totalClaims ? totalAssets - totalClaims : 0;
    }
}
