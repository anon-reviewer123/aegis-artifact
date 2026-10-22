// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TicketPool_RO04b {
    uint256 public constant PRICE = 1e17;
    mapping(address => uint256) public ticketsOf;
    uint256 public soldTickets;
    uint256 public pot;
    bool public inCall;

    function buy() external payable {
        require(!inCall, "reentrant");
        require(msg.value == PRICE, "price");
        ticketsOf[msg.sender] += 1;
        soldTickets += 1;
        pot += PRICE;
    }

    function sponsor() external payable {
        require(!inCall, "reentrant");
        pot += msg.value;
    }

    function cancel(uint256 n) external {
        require(!inCall, "reentrant");
        require(ticketsOf[msg.sender] >= n, "tickets");
        ticketsOf[msg.sender] -= n;
        soldTickets -= n;
        inCall = true;
        (bool ok, ) = payable(msg.sender).call{value: n * PRICE}("");
        require(ok, "refund");
        inCall = false;
        pot -= n * PRICE;
    }

    function unbackedPot() external view returns (uint256) {
        return pot - soldTickets * PRICE;
    }
}
