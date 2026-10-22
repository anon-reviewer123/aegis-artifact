pragma solidity ^0.4.26;

//Guarding on call

//No-renetrancy


contract Test {

    uint stateVar;
    bool lock;
    mapping (address => uint) userBalance;

    function T1() public
    {
        uint amt = userBalance[msg.sender];
        userBalance[msg.sender] = userBalance[msg.sender] - amt;
        if (!lock)
        {
            lock = true;
            msg.sender.call.value(amt)();
            lock = false;
        }
        else
        {
            userBalance[msg.sender] = userBalance[msg.sender]+amt;
        }
    }  
}
