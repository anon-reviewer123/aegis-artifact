// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Payroll_LP02b {
    address[] public employees;
    mapping(address => uint256) public salary;
    bool public periodClosed;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addEmployee(address who) external payable onlyOwner {
        employees.push(who);
        salary[who] += msg.value;
    }

    function payAll() external {
        require(!periodClosed, "done");
        for (uint256 i = 0; i < employees.length; i++) {
            address who = employees[i];
            uint256 amt = salary[who];
            salary[who] = 0;
            payable(who).transfer(amt);
        }
        periodClosed = true;
    }
}
