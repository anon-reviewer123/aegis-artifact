pragma solidity ^0.4.26;

//T1-T2

contract Test {

    uint x;
    bool y;

    function T1() public
    {
        uint amt = x;
        x = x-amt;
        msg.sender.call.value(amt)();
        if(y == true)
        {
            x = 0;
        }
    }

    // function T2() public
    // {
    //     if(x==0)
    //     {
    //         msg.sender.call.value(10);
    //         y = true;
    //     }
    // }    
}
