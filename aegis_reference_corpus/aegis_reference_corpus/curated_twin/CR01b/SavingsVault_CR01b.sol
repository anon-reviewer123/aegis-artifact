// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SavingsVault_CR01b {
    mapping(address => uint256) public balances;
    uint256 public reserve;
    uint256 public liabilities;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        reserve += msg.value;
        liabilities += msg.value;
    }

    function withdrawAll() external {
        uint256 amt = balances[msg.sender];
        require(amt > 0, "empty");
        balances[msg.sender] = 0;
        liabilities -= amt;
        reserve -= amt;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "send");
    }

    function solvent() external view returns (bool) {
        return reserve >= liabilities;
    }
}
