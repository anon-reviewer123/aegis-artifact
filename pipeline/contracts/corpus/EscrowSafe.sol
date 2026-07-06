// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IPayeeHook { function onWithdraw(uint256 amount) external; }
contract EscrowSafe {
    mapping(address => uint256) public owed;
    uint256 public totalOwed;
    uint256 public balance;
    bool public exposed;
    constructor() { owed[msg.sender] = 1000; totalOwed = 1000; balance = 1000; }
    function fund(uint256 amount) external {
        owed[msg.sender] += amount;
        totalOwed += amount;
        balance += amount;
    }
    function claim(uint256 amount, address hook) external {
        require(owed[msg.sender] >= amount, "owed");
        owed[msg.sender] -= amount;
        totalOwed -= amount;
        exposed = true;
        IPayeeHook(hook).onWithdraw(amount);
        balance -= amount;
        exposed = false;
    }
    function sweep() external {
        require(!exposed, "exposed");
        require(balance > totalOwed, "no surplus");
        uint256 surplus = balance - totalOwed;
        owed[msg.sender] += surplus;
        totalOwed += surplus;
    }
    function invariant() public view returns (bool) {
        return exposed || balance == totalOwed;
    }
}
