// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MarginDesk_CF06a {
    mapping(address => uint256) public margin;
    uint256 public collateral;
    uint256 public marginTotal;
    address public feeRecipient;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function postMargin() external payable {
        margin[msg.sender] += msg.value;
        collateral += msg.value;
        marginTotal += msg.value;
    }

    function addInsurance() external payable {
        collateral += msg.value;
    }

    function skim() external {
        require(collateral > marginTotal, "no surplus");
        uint256 surplus = collateral - marginTotal;
        margin[msg.sender] += surplus;
        marginTotal += surplus;
    }

    function closeTrade(uint256 amount) external {
        require(margin[msg.sender] >= amount, "position");
        margin[msg.sender] -= amount;
        marginTotal -= amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "payout");
        collateral -= amount;
    }

    function setFeeRecipient(address r) external onlyOwner {
        feeRecipient = r;
    }

    function surplus() external view returns (uint256) {
        return collateral > marginTotal ? collateral - marginTotal : 0;
    }
}
