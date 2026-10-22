pragma solidity ^0.4.19;

contract PIGGY_BANK
{
    mapping (address => uint) public Accounts;
    
    uint public MinSum = 1 ether;
    
    // Log LogFile;
    
    uint putBlock;
    
    // function PIGGY_BANK(address _log)
    // public 
    // {
    //     LogFile = Log(_log);
    // }
    uint blockNumber;
    function Put(address to)
    public
    payable
    {
        tthisBal += msg.value;
        Accounts[to]+=msg.value;
        // string PUT = "PUT";
        // LogFile.AddMessage(msg.sender,msg.value,PUT);
        putBlock = blockNumber;
    }
    uint tthisBal;
    function Collect(uint _am)
    public
    payable
    {
        if(Accounts[msg.sender]>=1 ether && _am<=Accounts[msg.sender] && blockNumber>putBlock)
        {
            tthisBal -= _am;
            bool s1 = msg.sender.call.value(_am)();
            if(s1 == true)
            {
                Accounts[msg.sender]-=_am;
                // string COLLECT = "Collect";
                // LogFile.AddMessage(msg.sender,_am,COLLECT);
            }
        }
    }
    
    function() 
    public 
    payable
    {
        Put(msg.sender);
    }    
    
}

// contract Log 
// {
//     struct Message
//     {
//         address Sender;
//         string  Data;
//         uint Val;
//         uint  Time;
//     }
    
//     Message[] public History;
    
//     Message LastMsg;
    
//     function AddMessage(address _adr,uint _val,string _data)
//     public
//     {
//         LastMsg.Sender = _adr;
//         LastMsg.Time = now;
//         LastMsg.Val = _val;
//         LastMsg.Data = _data;
//         History.push(LastMsg);
//     }
// }