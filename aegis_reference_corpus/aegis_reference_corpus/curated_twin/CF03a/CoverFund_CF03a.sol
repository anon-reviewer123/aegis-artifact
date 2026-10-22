// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CoverFund_CF03a {
    mapping(address => uint256) public cover;
    uint256 public reserves;
    uint256 public coverage;
    uint256 public pendingOut;
    address public feeRecipient;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function buyCover() external payable {
        cover[msg.sender] += msg.value;
        reserves += msg.value;
        coverage += msg.value;
    }

    function topUp() external payable {
        reserves += msg.value;
    }

    function rebalance() external {
        require(reserves > coverage + pendingOut, "no surplus");
        uint256 surplus = reserves - coverage - pendingOut;
        cover[msg.sender] += surplus;
        coverage += surplus;
    }

    function payClaim(uint256 amount) external {
        require(cover[msg.sender] >= amount, "position");
        cover[msg.sender] -= amount;
        coverage -= amount;
        pendingOut += amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "payout");
        reserves -= amount;
        pendingOut -= amount;
    }

    function setFeeRecipient(address r) external onlyOwner {
        feeRecipient = r;
    }

    function surplus() external view returns (uint256) {
        return reserves > coverage ? reserves - coverage : 0;
    }
}
