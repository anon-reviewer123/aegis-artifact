pragma solidity ^0.4.15;

contract Token {
    function transfer(address _to, uint _value) returns (bool success);
}

contract Safe {
    uint256 public lock = 1541422740;
    address public owner;

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
    uint blocktimestamp;
    function withdrawal(Token token, address to, uint value) returns (bool) {
        require(msg.sender == owner);
        require(block.timestamp >= lock);
        require(to != zero);
        return token.transfer(to, value);
    }
}