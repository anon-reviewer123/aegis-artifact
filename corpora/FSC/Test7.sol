pragma solidity ^0.4.26;

// S.No 2

contract Test {

    bool x;
    uint y;
    uint z;

    function T1() public
    {
        x = false;
        uint amount = 0;
        if(!x)
        {
            amount = y;
            y = y-amount;
            y = 0;
        }
        msg.sender.call.value(amount)();
        if(!x)
        {
            z = 0;
        }
    }
    // function T2() public
    // {
    //     if(!x)
    //     {
    //         x = false;
    //     }
    // }   
}
