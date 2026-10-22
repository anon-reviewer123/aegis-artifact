// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EscrowBatch_LP08a {
    mapping(address => uint256) public deposits;
    mapping(address => bool) public refunded;
    mapping(address => uint256) public refundedAmount;
    uint256 public totalDeposited;
    address[] public depositors;

    function deposit() external payable {
        require(deposits[msg.sender] == 0, "once");
        deposits[msg.sender] = msg.value;
        depositors.push(msg.sender);
        totalDeposited += msg.value;
    }

    function refundAll() external {
        for (uint256 i = 0; i < depositors.length; i++) {
            address d = depositors[i];
            if (refunded[d]) {
                continue;
            }
            uint256 amt = deposits[d];
            refunded[d] = true;
            refundedAmount[d] += amt;
            (bool ok, ) = payable(d).call{value: amt}("");
            if (!ok) {
                refunded[d] = false;
                refundedAmount[d] -= amt;
            }
        }
    }
}
