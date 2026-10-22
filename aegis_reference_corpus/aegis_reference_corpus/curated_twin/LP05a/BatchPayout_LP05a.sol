// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BatchPayout_LP05a {
    uint256 public pool;
    uint256 public totalIn;
    uint256 public totalOut;
    address[] public payees;
    mapping(address => uint256) public owed;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function topUp() external payable {
        pool += msg.value;
        totalIn += msg.value;
    }

    function addPayee(address p, uint256 amt) external onlyOwner {
        payees.push(p);
        owed[p] += amt;
    }

    function distribute() external {
        uint256 snap = pool;
        uint256 spent;
        for (uint256 i = 0; i < payees.length; i++) {
            address p = payees[i];
            uint256 amt = owed[p];
            if (amt == 0 || spent + amt > snap) {
                continue;
            }
            owed[p] = 0;
            spent += amt;
            totalOut += amt;
            (bool ok, ) = payable(p).call{value: amt}("");
            if (!ok) {
                owed[p] = amt;
                spent -= amt;
                totalOut -= amt;
            }
        }
        pool = snap - spent;
    }
}
