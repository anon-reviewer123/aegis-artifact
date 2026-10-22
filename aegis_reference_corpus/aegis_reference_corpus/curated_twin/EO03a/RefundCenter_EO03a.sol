// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RefundCenter_EO03a {
    mapping(address => uint256) public refundOf;
    uint256 public refundCash;
    uint256 public refundDebt;

    function accrue() external payable {
        refundOf[msg.sender] += msg.value;
        refundCash += msg.value;
        refundDebt += msg.value;
    }

    function claim() external {
        uint256 x = refundOf[msg.sender];
        require(x > 0, "none");
        refundOf[msg.sender] = 0;
        refundDebt -= x;
        refundCash -= x;
        (bool ok, ) = payable(msg.sender).call{value: x}("");
        require(ok, "send");
    }
}
