// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IBorrowHook { function onBorrow(uint256 amount) external; }
contract LendingPool {
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;
    uint256 public cash;
    constructor() { deposits[msg.sender] = 1000; totalDeposits = 1000; cash = 1000; }
    function deposit(uint256 amount) external {
        deposits[msg.sender] += amount;
        totalDeposits += amount;
        cash += amount;
    }
    function withdraw(uint256 amount, address hook) external {
        require(deposits[msg.sender] >= amount, "deposit");
        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        IBorrowHook(hook).onBorrow(amount);
        cash -= amount;
    }
    function accrue() external {
        require(cash > totalDeposits, "no surplus");
        uint256 surplus = cash - totalDeposits;
        deposits[msg.sender] += surplus;
        totalDeposits += surplus;
    }
    function invariant() public view returns (bool) {
        return cash == totalDeposits;
    }
}
