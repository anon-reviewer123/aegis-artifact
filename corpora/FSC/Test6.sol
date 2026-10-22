pragma solidity ^0.4.26;

//Interaction before and after call 

//Benign Reentrancy

contract Test {

    uint x;
    uint y;
    uint z;

    function T1() public
    {
        uint amount = x;
        x = 5;
        msg.sender.call.value(amount)();
        z = z-y;
    }    
}
