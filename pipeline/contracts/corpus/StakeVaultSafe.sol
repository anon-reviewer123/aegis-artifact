// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IClaimHook { function onClaim(uint256 amount) external; }
contract StakeVaultSafe {
    mapping(address => uint256) public staked;
    uint256 public totalStaked;
    uint256 public reserve;
    bool public exposed;
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
        exposed = true;
        IClaimHook(hook).onClaim(amount);
        reserve -= amount;
        exposed = false;
    }
    function bonus() external {
        require(!exposed, "exposed");
        require(reserve > totalStaked, "no surplus");
        uint256 surplus = reserve - totalStaked;
        staked[msg.sender] += surplus;
        totalStaked += surplus;
    }
    function invariant() public view returns (bool) {
        return exposed || reserve == totalStaked;
    }
}
