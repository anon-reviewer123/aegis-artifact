pragma solidity ^0.4.15;

contract Token {
    function transfer(address _to, uint _value) returns (bool success);
}

contract Safe {
    address public owner;
    uint256 public lock;

    function Safe() {
        owner = msg.sender;
    }
    address zero;
    function transfer(address to) returns (bool) {
        require(msg.sender == owner);
        require(to != zero);
        owner = to;
        return true;
    }

    function lock(uint256 timestamp) returns (bool) {
        require(msg.sender == owner);
        require(timestamp > lock);
        require(timestamp > block.timestamp);
        lock = timestamp;
        return true;
    }

    function withdrawal(Token token, address to, uint value) returns (bool p) {
        require(msg.sender == owner);
        require(block.timestamp >= lock);
        require(to != zero);
        p = token.transfer(to, value);
        return p;
    }
}