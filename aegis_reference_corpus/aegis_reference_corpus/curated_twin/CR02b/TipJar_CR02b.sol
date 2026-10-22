// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TipJar_CR02b {
    mapping(address => uint256) public tips;
    uint256 public cash;
    uint256 public owed;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "owner");
        _;
    }

    uint256 private _status = 1;

    modifier nonReentrant() {
        require(_status == 1, "reentrant");
        _status = 2;
        _;
        _status = 1;
    }

    constructor() {
        owner = msg.sender;
    }

    function tip() external payable nonReentrant {
        tips[msg.sender] += msg.value;
        cash += msg.value;
        owed += msg.value;
    }

    function claimTips() external nonReentrant {
        uint256 amt = tips[msg.sender];
        require(amt > 0, "empty");
        cash -= amt;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "send");
        owed -= tips[msg.sender];
        tips[msg.sender] = 0;
    }

    function solvent() external view returns (bool) {
        return cash >= owed;
    }
}
