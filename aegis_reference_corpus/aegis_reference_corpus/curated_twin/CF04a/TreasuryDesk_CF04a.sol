// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TreasuryDesk_CF04a {
    mapping(address => uint256) public allocation;
    uint256 public treasury;
    uint256 public allocated;
    address public feeRecipient;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    uint256 private _status = 1;

    modifier nonReentrant() {
        require(_status == 1, "reentrant");
        _status = 2;
        _;
        _status = 1;
    }

    constructor() {
        owner = msg.sender;
    }

    function allocate() external payable nonReentrant {
        allocation[msg.sender] += msg.value;
        treasury += msg.value;
        allocated += msg.value;
    }

    function receiveRevenue() external payable {
        treasury += msg.value;
    }

    function sweepExcess() external nonReentrant {
        require(treasury > allocated, "no surplus");
        uint256 surplus = treasury - allocated;
        allocation[msg.sender] += surplus;
        allocated += surplus;
    }

    function release(uint256 amount) external nonReentrant {
        require(allocation[msg.sender] >= amount, "position");
        allocation[msg.sender] -= amount;
        allocated -= amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "payout");
        treasury -= amount;
    }

    function setFeeRecipient(address r) external onlyOwner {
        feeRecipient = r;
    }

    function surplus() external view returns (uint256) {
        return treasury > allocated ? treasury - allocated : 0;
    }
}
