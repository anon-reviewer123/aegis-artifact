// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract YieldBook_CF05b {
    mapping(address => uint256) public principal;
    uint256 public holdings;
    uint256 public principalTotal;
    bool public exposed;
    address public feeRecipient;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function supply() external payable {
        principal[msg.sender] += msg.value;
        holdings += msg.value;
        principalTotal += msg.value;
    }

    function accrue() external payable {
        holdings += msg.value;
    }

    function harvest() external {
        require(!exposed, "exposed");
        require(holdings > principalTotal, "no surplus");
        uint256 surplus = holdings - principalTotal;
        principal[msg.sender] += surplus;
        principalTotal += surplus;
    }

    function redeem(uint256 amount) external {
        require(!exposed, "exposed");
        require(principal[msg.sender] >= amount, "position");
        principal[msg.sender] -= amount;
        principalTotal -= amount;
        exposed = true;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "payout");
        holdings -= amount;
        exposed = false;
    }

    function setFeeRecipient(address r) external onlyOwner {
        feeRecipient = r;
    }

    function surplus() external view returns (uint256) {
        return holdings > principalTotal ? holdings - principalTotal : 0;
    }
}
