// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PresaleRefund_LP04b {
    address[] public buyers;
    mapping(address => uint256) public paidIn;
    mapping(address => uint256) public refundCredit;
    bool public refundsDone;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addBuyer(address who) external payable onlyOwner {
        buyers.push(who);
        paidIn[who] += msg.value;
    }

    function refundAll() external {
        require(!refundsDone, "done");
        for (uint256 i = 0; i < buyers.length; i++) {
            address who = buyers[i];
            uint256 amt = paidIn[who];
            paidIn[who] = 0;
            (bool ok, ) = payable(who).call{value: amt}("");
            if (!ok) {
                refundCredit[who] += amt;
            }
        }
        refundsDone = true;
    }

    function claimFailed() external {
        uint256 amt = refundCredit[msg.sender];
        require(amt > 0, "none");
        refundCredit[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "claim");
    }
}
