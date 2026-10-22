pragma solidity ^0.4.26;

//Cycle is not necessary

contract Test {

    uint x;
    uint y;
    uint z;

    function Transfer_Y_And_Adjust_X() public
    {
        uint amt = y;
        z = 5;
        y = 0;
        msg.sender.call.value(amt)();
        if(z==0)
        {
            x = x+amt;
        }
    }  
}
