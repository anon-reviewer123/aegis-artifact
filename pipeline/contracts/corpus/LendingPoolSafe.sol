// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IBorrowHook { function onBorrow(uint256 amount) external; }
contract LendingPoolSafe {
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;
    uint256 public cash;
    bool public exposed;
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
        exposed = true;
        IBorrowHook(hook).onBorrow(amount);
        cash -= amount;
        exposed = false;
    }
    function accrue() external {
        require(!exposed, "exposed");
        require(cash > totalDeposits, "no surplus");
        uint256 surplus = cash - totalDeposits;
        deposits[msg.sender] += surplus;
        totalDeposits += surplus;
    }
    function invariant() public view returns (bool) {
        return exposed || cash == totalDeposits;
    }
}
