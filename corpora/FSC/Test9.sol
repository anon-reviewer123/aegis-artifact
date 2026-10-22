pragma solidity ^0.4.26;

contract Test {

    uint x;
    function T1() public
    {
        x = 20;
        uint amt = x;
        x = 0;
        msg.sender.call.value(amt)();
        x = 10;
    }    
}
