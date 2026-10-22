pragma solidity ^0.4.26;
// Based on S.No1
contract Test {

    uint x;
    uint y;

    function T1() public
    {
        uint amount = x;
        x = 0;
        msg.sender.call.value(amount)();
        y = x;
    }   
}
