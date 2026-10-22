pragma solidity 0.4.26;

contract Test {

    uint x;
    // uint allowance;
    // uint _value;

    function T1() public
    {
        // if ((allowance > 0 && _value == 0) || (allowance == 0 && _value > 0))
        // {
            
        // }
        x = 100;
        uint amt = 100;
        x = x-amt;
        msg.sender.call.value(amt);
        x = 0;
    }   
}


