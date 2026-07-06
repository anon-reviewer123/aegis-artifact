// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract BidTester {
    constructor() {}

    function simpleBid() public payable {
        (bool success, bytes memory _data) = block.coinbase.call{value: msg.value}("");
        require(success, "Failed to send Ether via .call");
    }
}