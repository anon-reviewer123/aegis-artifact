// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DividendDistributor_LP03b {
    address[] public holders;
    mapping(address => uint256) public dividendOf;
    mapping(address => uint256) public unclaimed;
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
            if (!ok) {
                unclaimed[who] += amt;
            }
        }
        roundDone = true;
    }

    function claimFailed() external {
        uint256 amt = unclaimed[msg.sender];
        require(amt > 0, "none");
        unclaimed[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "claim");
    }
}
