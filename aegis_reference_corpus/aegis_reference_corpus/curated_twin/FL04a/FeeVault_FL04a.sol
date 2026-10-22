// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFlashBorrower {
    function onFlashLoan(uint256 amount, uint256 fee) external payable;
}

contract FeeVault_FL04a {
    uint256 public constant FEE = 1e15;
    mapping(address => uint256) public shares;
    uint256 public cash;
    uint256 public deposits;
    uint256 public feesEarned;

    uint256 private _status = 1;

    modifier nonReentrant() {
        require(_status == 1, "reentrant");
        _status = 2;
        _;
        _status = 1;
    }

    function deposit() external payable nonReentrant {
        shares[msg.sender] += msg.value;
        deposits += msg.value;
        cash += msg.value;
    }

    function repay() external payable {
        cash += msg.value;
    }

    function flashLoan(uint256 amount) external nonReentrant {
        require(amount <= cash, "liquidity");
        uint256 before = cash;
        cash -= amount;
        IFlashBorrower(msg.sender).onFlashLoan{value: amount}(amount, FEE);
        require(cash >= before + FEE, "not repaid");
        feesEarned += cash - before;
    }
}
