pragma solidity ^0.4.26;

// S.No 1
//x remains 0 and y remains sam ein all the executions

contract Test {

    uint x;
    uint y;

    function T1() public
    {
        uint amount = x;
        x = 0;
        msg.sender.call.value(amount)();
        y = y-x;
    }    
}
