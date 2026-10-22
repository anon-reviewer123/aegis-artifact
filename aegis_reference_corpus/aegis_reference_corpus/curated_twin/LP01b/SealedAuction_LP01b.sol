// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SealedAuction_LP01b {
    address[] public bidders;
    mapping(address => uint256) public refunds;
    bool public finalized;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addBidder(address who) external payable onlyOwner {
        bidders.push(who);
        refunds[who] += msg.value;
    }

    function settle() external {
        require(!finalized, "done");
        for (uint256 i = 0; i < bidders.length; i++) {
            address who = bidders[i];
            uint256 amt = refunds[who];
            refunds[who] = 0;
            (bool ok, ) = payable(who).call{value: amt}("");
            require(ok, "payment failed");
        }
        finalized = true;
    }
}
