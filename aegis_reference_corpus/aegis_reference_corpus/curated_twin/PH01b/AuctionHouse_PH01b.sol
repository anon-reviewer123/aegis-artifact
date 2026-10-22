// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AuctionHouse_PH01b {
    uint8 public constant OPEN = 1;
    uint8 public constant CLOSED = 2;
    uint8 public phase;
    address public seller;
    uint256 public escrow;
    mapping(address => uint256) public bids;

    constructor(address s) {
        seller = s;
        phase = OPEN;
    }

    function bid() external payable {
        require(phase == OPEN, "closed");
        bids[msg.sender] += msg.value;
        escrow += msg.value;
    }

    function close() external {
        require(phase == OPEN, "closed");
        uint256 proceeds = escrow;
        escrow = 0;
        phase = CLOSED;
        (bool ok, ) = payable(seller).call{value: proceeds}("");
        require(ok, "payout");
    }
}
