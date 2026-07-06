// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract FlashLoanPool {
    uint256 public cash;
    uint256 public loaned;

    constructor() { cash = 1000; loaned = 0; }

    function deposit(uint256 amount) external {
        cash += amount;
    }

    function flashLoan(uint256 amount, address borrower) external {
        require(cash >= amount, "liquidity");
        cash -= amount;
        loaned += amount;
        IFlashBorrower(borrower).onFlashLoan(amount);
        cash += amount;
        loaned -= amount;
    }

    function skim(address to) external {
        require(cash > loaned, "no surplus");
        uint256 surplus = cash - loaned;
        cash -= surplus;
        (bool ok, ) = to.call{value: 0}("");
        require(ok, "send");
    }

    function invariant() public view returns (bool) {
        return cash + loaned == 1000;
    }
}
