// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PerpPool_CF01a {
    mapping(address => uint256) public glp;
    uint256 public aum;
    uint256 public trackedValue;
    address public feeRecipient;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        glp[msg.sender] += msg.value;
        aum += msg.value;
        trackedValue += msg.value;
    }

    function addFees() external payable {
        aum += msg.value;
    }

    function mintGlp() external {
        require(aum > trackedValue, "no surplus");
        uint256 surplus = aum - trackedValue;
        glp[msg.sender] += surplus;
        trackedValue += surplus;
    }

    function decreasePosition(uint256 amount) external {
        require(glp[msg.sender] >= amount, "position");
        glp[msg.sender] -= amount;
        trackedValue -= amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "payout");
        aum -= amount;
    }

    function setFeeRecipient(address r) external onlyOwner {
        feeRecipient = r;
    }

    function surplus() external view returns (uint256) {
        return aum > trackedValue ? aum - trackedValue : 0;
    }
}
