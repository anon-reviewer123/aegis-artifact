pragma solidity ^0.4.13;

contract ForeignToken {
    function balanceOf(address _owner) constant returns (uint256);
    function transfer(address _to, uint256 _value) returns (bool);
}


contract tokenHodl {
    event Hodl(address indexed hodler, uint indexed amount);
    event Party(address indexed hodler, uint indexed amount);
    mapping (address => uint) public hodlers;
    uint partyTime = 1522093545; // test
    function() payable {
        hodlers[msg.sender] += msg.value;
        // Hodl(msg.sender, msg.value);
    }
    function party() {
        require (block.timestamp > partyTime && hodlers[msg.sender] > 0);
        uint value = hodlers[msg.sender];
        uint amount = value/100;
        hodlers[msg.sender] = 0;
        msg.sender.transfer(amount);
        // Party(msg.sender, amount);
        partyTime = partyTime + 120;
    }
    address tthisAddr;
    function withdrawForeignTokens(address _tokenContract) returns (bool p) {
        address x;
        if (msg.sender != x) { throw; }
        require (block.timestamp > partyTime);
        
        ForeignToken token = ForeignToken(_tokenContract);
        uint p1 = token.balanceOf(tthisAddr);
        uint256 amount = p1/100;
        address l;
        p = token.transfer(l, amount);
        partyTime = partyTime + 120;
        return p;
    }
}