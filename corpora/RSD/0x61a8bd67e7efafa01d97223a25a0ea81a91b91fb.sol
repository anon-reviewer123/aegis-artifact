/**
 *Submitted for verification at Etherscan.io on 2021-05-31
*/
pragma solidity 0.4.26;
contract Alfa_BANK
{
    uint tthisBal;
    function Put(uint _unlockTime)
    public
    payable
    {
        
        Acc[msg.sender].balance += msg.value;
        tthisBal += msg.value;
        Acc[msg.sender].unlockTime = _unlockTime>now?_unlockTime:now;
        // LogFile.AddMessage(msg.sender,msg.value,"Put");
    }

    function Collect(uint _am)
    public
    payable
    {
        
        if( Acc[msg.sender].balance>=MinSum && Acc[msg.sender].balance>=_am && now>Acc[msg.sender].unlockTime)
        {
            tthisBal -= _am;
            bool cd = msg.sender.call.value(_am)();
            if(cd == true)
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
        Put(0);
    }

    struct Holder   
    {
        uint unlockTime;
        uint balance;
    }

    mapping (address => Holder) public Acc;

    Log LogFile;

    uint public MinSum = 1 ether;    

    function Alfa_BANK(address log) public{
        // LogFile = Log(log);
    }
}


contract Log 
{
    struct Message
    {
        address Sender;
        string  Data;
        uint Val;
        uint  Time;
    }

    Message[] public History;

    Message LastMsg;

    function AddMessage(address _adr,uint _val,string _data)
    public
    {
        LastMsg.Sender = _adr;
        LastMsg.Time = now;
        LastMsg.Val = _val;
        LastMsg.Data = _data;
        History.push(LastMsg);
    }
}