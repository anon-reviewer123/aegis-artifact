pragma solidity ^0.4.26;

//Restoring the old values of the remaining state variables after call not used in external calls

//S.No: 5

contract Test {

    uint x;

    function T1(uint amt) public
    {
        if(x > 0 && x >= amt)
        {
            uint rem_Bal = x - amt;
            x = 0;
            msg.sender.call.value(amt)();
            x = rem_Bal;
        }
    }   
}
