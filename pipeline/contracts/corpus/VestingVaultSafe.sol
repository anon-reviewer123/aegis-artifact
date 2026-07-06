// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IVestHook { function onRelease(uint256 amount) external; }
contract VestingVaultSafe {
    mapping(address => uint256) public locked;
    uint256 public totalLocked;
    uint256 public vault;
    bool public exposed;
    constructor() { locked[msg.sender] = 1000; totalLocked = 1000; vault = 1000; }
    function lock(uint256 amount) external {
        locked[msg.sender] += amount;
        totalLocked += amount;
        vault += amount;
    }
    function release(uint256 amount, address hook) external {
        require(locked[msg.sender] >= amount, "locked");
        locked[msg.sender] -= amount;
        totalLocked -= amount;
        exposed = true;
        IVestHook(hook).onRelease(amount);
        vault -= amount;
        exposed = false;
    }
    function topUp() external {
        require(!exposed, "exposed");
        require(vault > totalLocked, "no surplus");
        uint256 surplus = vault - totalLocked;
        locked[msg.sender] += surplus;
        totalLocked += surplus;
    }
    function invariant() public view returns (bool) {
        return exposed || vault == totalLocked;
    }
}
