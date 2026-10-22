// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RewardPool_CR03a {
    mapping(address => uint256) public pendingReward;
    uint256 public rewardCash;
    uint256 public rewardDebt;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function accrue(address user) external payable onlyOwner {
        pendingReward[user] += msg.value;
        rewardCash += msg.value;
        rewardDebt += msg.value;
    }

    function claimRewards() external {
        uint256 amt = pendingReward[msg.sender];
        require(amt > 0, "empty");
        rewardCash -= amt;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "send");
        rewardDebt -= pendingReward[msg.sender];
        pendingReward[msg.sender] = 0;
    }

    function solvent() external view returns (bool) {
        return rewardCash >= rewardDebt;
    }
}
