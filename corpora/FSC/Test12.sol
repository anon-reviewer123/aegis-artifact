pragma solidity ^0.4.26;

//Cycle is not necessary

//S.No: 13

contract Test {

    uint x;
    uint y;

    function Transfer_Y_And_Adjust_X(uint amt) public
    {
            x = x-amt;
            msg.sender.call.value(amt);
            y = y+1;
    }  
}