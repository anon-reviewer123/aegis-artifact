// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFlashBorrower {
    function onFlashLoan(uint256 amount, uint256 fee) external payable;
}

contract FlashVault_FL02b {
    uint256 public constant FEE = 1e15;
    mapping(address => uint256) public shares;
    uint256 public cash;
    uint256 public totalShares;
    uint256 public repaid;
    bool public inLoan;

    function deposit() external payable {
        shares[msg.sender] += msg.value;
        totalShares += msg.value;
        cash += msg.value;
    }

    function repay() external payable {
        cash += msg.value;
        repaid += msg.value;
    }

    function flashLoan(uint256 amount) external {
        require(!inLoan, "nested");
        require(amount <= cash, "liquidity");
        uint256 before = cash;
        uint256 r0 = repaid;
        inLoan = true;
        cash -= amount;
        IFlashBorrower(msg.sender).onFlashLoan{value: amount}(amount, FEE);
        inLoan = false;
        require(repaid >= r0 + amount + FEE, "not repaid");
    }
}
