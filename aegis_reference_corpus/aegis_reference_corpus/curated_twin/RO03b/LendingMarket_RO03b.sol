// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LendingMarket_RO03b {
    uint256 public constant INCENTIVE = 1e16;
    uint256 public cash;
    uint256 public totalBorrows;
    bool public locked;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function supply() external payable {
        require(!locked, "locked");
        cash += msg.value;
    }

    function openPosition(uint256 amount) external onlyOwner {
        require(!locked, "locked");
        cash -= amount;
        totalBorrows += amount;
    }

    function liquidate() external payable {
        require(!locked, "locked");
        require(msg.value <= totalBorrows && msg.value > INCENTIVE, "debt");
        locked = true;
        totalBorrows -= msg.value;
        (bool ok, ) = payable(msg.sender).call{value: INCENTIVE}("");
        require(ok, "incentive");
        cash += msg.value - INCENTIVE;
        locked = false;
    }

    function totalSupplied() external view returns (uint256) {
        return cash + totalBorrows;
    }
}
