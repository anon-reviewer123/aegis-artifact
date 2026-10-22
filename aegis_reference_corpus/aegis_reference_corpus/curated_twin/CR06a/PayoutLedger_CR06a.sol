// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PayoutLedger_CR06a {
    mapping(address => uint256) public credit;
    uint256 public funds;
    uint256 public promised;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function fund() external payable {
        credit[msg.sender] += msg.value;
        funds += msg.value;
        promised += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(credit[msg.sender] >= amount, "credit");
        funds -= amount;
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "send");
        promised -= credit[msg.sender];
        credit[msg.sender] = 0;
    }

    function solvent() external view returns (bool) {
        return funds >= promised;
    }
}
