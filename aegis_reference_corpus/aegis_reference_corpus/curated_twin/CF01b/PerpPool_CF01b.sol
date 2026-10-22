// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PerpPool_CF01b {
    mapping(address => uint256) public glp;
    uint256 public aum;
    uint256 public trackedValue;
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

    function deposit() external payable {
        glp[msg.sender] += msg.value;
        aum += msg.value;
        trackedValue += msg.value;
    }

    function addFees() external payable {
        aum += msg.value;
    }

    function mintGlp() external {
        require(!exposed, "exposed");
        require(aum > trackedValue, "no surplus");
        uint256 surplus = aum - trackedValue;
        glp[msg.sender] += surplus;
        trackedValue += surplus;
    }

    function decreasePosition(uint256 amount) external {
        require(!exposed, "exposed");
        require(glp[msg.sender] >= amount, "position");
        glp[msg.sender] -= amount;
        trackedValue -= amount;
        exposed = true;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "payout");
        aum -= amount;
        exposed = false;
    }

    function setFeeRecipient(address r) external onlyOwner {
        feeRecipient = r;
    }

    function surplus() external view returns (uint256) {
        return aum > trackedValue ? aum - trackedValue : 0;
    }
}
