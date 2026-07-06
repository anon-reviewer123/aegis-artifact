// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IRefundHook { function onRefund(uint256 amount) external; }
contract SaleVault {
    mapping(address => uint256) public contributed;
    uint256 public totalContributed;
    uint256 public raised;
    constructor() { contributed[msg.sender] = 1000; totalContributed = 1000; raised = 1000; }
    function contribute(uint256 amount) external {
        contributed[msg.sender] += amount;
        totalContributed += amount;
        raised += amount;
    }
    function refund(uint256 amount, address hook) external {
        require(contributed[msg.sender] >= amount, "contributed");
        contributed[msg.sender] -= amount;
        totalContributed -= amount;
        IRefundHook(hook).onRefund(amount);
        raised -= amount;
    }
    function claimBonus() external {
        require(raised > totalContributed, "no surplus");
        uint256 surplus = raised - totalContributed;
        contributed[msg.sender] += surplus;
        totalContributed += surplus;
    }
    function invariant() public view returns (bool) {
        return raised == totalContributed;
    }
}
