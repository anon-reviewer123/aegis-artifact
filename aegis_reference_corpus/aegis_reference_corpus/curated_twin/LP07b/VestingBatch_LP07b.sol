// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VestingBatch_LP07b {
    mapping(address => uint256) public vested;
    mapping(address => uint256) public released;
    mapping(address => uint256) public withdrawable;
    uint256 public totalVested;
    uint256 public totalReleased;
    address[] public beneficiaries;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function grant(address b) external payable onlyOwner {
        if (vested[b] == 0) {
            beneficiaries.push(b);
        }
        vested[b] += msg.value;
        totalVested += msg.value;
    }

    function release(address b) external {
        uint256 amt = vested[b] - released[b];
        require(amt > 0, "nothing vested");
        released[b] += amt;
        totalReleased += amt;
        withdrawable[b] += amt;
    }

    function releaseAll() external {
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address b = beneficiaries[i];
            uint256 amt = vested[b] - released[b];
            if (amt == 0) {
                continue;
            }
            (bool ok, ) = payable(b).call{value: amt}("");
            if (ok) {
                released[b] += amt;
                totalReleased += amt;
            }
        }
    }
}
