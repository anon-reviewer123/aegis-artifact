// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RebateDesk_EO01b {
    mapping(address => uint256) public rebate;
    uint256 public rebatePool;
    uint256 public rebateDebt;

    function accrue() external payable {
        rebate[msg.sender] += msg.value;
        rebatePool += msg.value;
        rebateDebt += msg.value;
    }

    function claim() external {
        uint256 x = rebate[msg.sender];
        require(x > 0, "none");
        rebatePool -= x;
        (bool ok, ) = payable(msg.sender).call{value: x}("");
        require(ok, "send");
        rebateDebt -= rebate[msg.sender];
        rebate[msg.sender] = 0;
    }
}
