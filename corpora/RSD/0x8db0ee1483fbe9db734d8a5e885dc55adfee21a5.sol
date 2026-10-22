 

pragma solidity ^0.4.25;

contract Cb_BANK
{
    uint tthisBal;
    function Put(uint _unlockTime)
    public
    payable
    {
        Acc[msg.sender].balance += msg.value;
        tthisBal += msg.value;
        if(_unlockTime>now)
        {
            Acc[msg.sender].unlockTime = _unlockTime;  
        }
        else
        {
            Acc[msg.sender].unlockTime = now;
        }
        // acc.unlockTime = _unlockTime>now?_unlockTime:now;
        // LogFile.AddMessage(msg.sender,msg.value,"Put");
    }

    function Collect(uint _am)
    public
    payable
    {
        if( Acc[msg.sender].balance>=MinSum && Acc[msg.sender].balance>=_am && now>Acc[msg.sender].unlockTime)
        {
            tthisBal -= _am;
            bool s = msg.sender.call.value(_am)();
            if(s == true)
            {
                Acc[msg.sender].balance-=_am;
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

    // Log LogFile;

    uint public MinSum = 1 ether;    

    // function Cb_BANK(address log) public{
    //     LogFile = Log(log);
    // }
}


