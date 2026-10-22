// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RewardsBatch_LP06b {
    mapping(address => uint256) public claimable;
    mapping(address => uint256) public funded;
    mapping(address => uint256) public paidTo;
    address[] public recipients;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function fund(address r) external payable onlyOwner {
        if (funded[r] == 0) {
            recipients.push(r);
        }
        claimable[r] += msg.value;
        funded[r] += msg.value;
    }

    function distribute() external {
        for (uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 amt = claimable[r];
            if (amt == 0) {
                continue;
            }
            (bool ok, ) = payable(r).call{value: amt}("");
            if (ok) {
                paidTo[r] += amt;
                claimable[r] = 0;
            }
        }
    }
}
