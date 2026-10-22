// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStartHook {
    function onStart(uint256 committed) external;
}

contract VestingStart_PH03a {
    bool public started;
    uint256 public committed;
    uint256 public totalAllocated;
    mapping(address => uint256) public allocation;

    function register() external payable {
        require(!started, "started");
        allocation[msg.sender] += msg.value;
        totalAllocated += msg.value;
    }

    function start() external {
        require(!started, "started");
        committed = totalAllocated;
        started = true;
        IStartHook(msg.sender).onStart(committed);
    }
}
