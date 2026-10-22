pragma solidity ^0.4.26;



//Guarded by lock, multi functions with different variables
//No reentrancy

contract Test {

    uint stateVar;
    bool lock;
    mapping (address => uint) userBalance;

    

    function T1() public
    {
        uint amt = userBalance[msg.sender];
        if (!lock)
        {
            lock = true;
            
            msg.sender.call.value(amt)();
            lock = false;
            userBalance[msg.sender] = userBalance[msg.sender] - amt;
        }
    }  

    function T2() public
    {
        if(!lock)
        {
            lock = true;
            uint k = stateVar;
            stateVar = stateVar - k;
            msg.sender.call.value(k)();
            lock = false;
        }
    } 
}


