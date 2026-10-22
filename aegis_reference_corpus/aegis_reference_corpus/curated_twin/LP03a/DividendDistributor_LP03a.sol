// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DividendDistributor_LP03a {
    address[] public holders;
    mapping(address => uint256) public dividendOf;
    bool public roundDone;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addHolder(address who) external payable onlyOwner {
        holders.push(who);
        dividendOf[who] += msg.value;
    }

    function distribute() external {
        require(!roundDone, "done");
        for (uint256 i = 0; i < holders.length; i++) {
            address who = holders[i];
            uint256 amt = dividendOf[who];
            dividendOf[who] = 0;
            (bool ok, ) = payable(who).call{value: amt}("");
            require(ok, "payment failed");
        }
        roundDone = true;
    }
}
