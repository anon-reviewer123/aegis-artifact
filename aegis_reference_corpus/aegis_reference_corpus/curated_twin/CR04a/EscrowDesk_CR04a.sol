// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EscrowDesk_CR04a {
    mapping(address => uint256) public escrowed;
    uint256 public held;
    uint256 public committed;
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

    function lock() external payable nonReentrant {
        escrowed[msg.sender] += msg.value;
        held += msg.value;
        committed += msg.value;
    }

    function releaseAll() external nonReentrant {
        uint256 amt = escrowed[msg.sender];
        require(amt > 0, "empty");
        held -= amt;
        (bool ok, ) = payable(msg.sender).call{value: amt}("");
        require(ok, "send");
        committed -= escrowed[msg.sender];
        escrowed[msg.sender] = 0;
    }

    function solvent() external view returns (bool) {
        return held >= committed;
    }
}
