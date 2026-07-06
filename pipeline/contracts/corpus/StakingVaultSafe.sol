// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IRewardHook { function onClaim(uint256 amount) external; }

contract StakingVaultSafe {
    mapping(address => uint256) public staked;
    uint256 public totalStaked;
    uint256 public reserve;

    constructor() { staked[msg.sender] = 1000; totalStaked = 1000; reserve = 1000; }

    function stake(uint256 amount) external {
        staked[msg.sender] += amount;
        totalStaked += amount;
        reserve += amount;
    }

    function unstake(uint256 amount, address hook) external {
        require(staked[msg.sender] >= amount, "staked");
        staked[msg.sender] -= amount;
        totalStaked -= amount;
        reserve -= amount;
        IRewardHook(hook).onClaim(amount);
    }

    function invariant() public view returns (bool) {
        return reserve == totalStaked;
    }
}
