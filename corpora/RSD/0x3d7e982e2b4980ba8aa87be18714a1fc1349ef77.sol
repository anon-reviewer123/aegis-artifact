 

pragma solidity ^0.4.25;

contract CA_BANK
{
    function Put(uint _unlockTime)
    public
    payable
    {
        var acc = Acc[msg.sender];
        acc.balance += msg.value;
        if(_unlockTime>now)
        {
            acc.unlockTime = _unlockTime;
        }
        else
        {
            acc.unlockTime = now;
        }
        
        // LogFile.AddMessage(msg.sender,msg.value,"Put");
    }

    function Collect(uint _am)
    public
    payable
    {
        var acc = Acc[msg.sender];
        if( acc.balance>=MinSum && acc.balance>=_am && now>acc.unlockTime)
        {
            bool s = msg.sender.call.value(_am)();
            if(s == true)
            {
                acc.balance-=_am;
                // LogFile.AddMessage(msg.sender,_am,"Collect");
            }
        }
    }

    function() 
    public 
    payable
    {
        uint a = 0;
        Put(a);
    }

    struct Holder   
    {
        uint unlockTime;
        uint balance;
    }

    mapping (address => Holder) public Acc;



    uint public MinSum = 2 ether;    

}

