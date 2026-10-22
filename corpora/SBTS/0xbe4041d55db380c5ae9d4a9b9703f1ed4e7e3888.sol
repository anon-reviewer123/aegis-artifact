/*
 * @source: etherscan.io 
 * @author: -
 * @vulnerable_at_lines: 63
 */

pragma solidity 0.4.26;

contract MONEY_BOX   
{
    struct Holder   
    {
        uint unlockTime;
        uint balance;
    }
    
    mapping (address => Holder) public Acc;
    
    uint public MinSum;
    
    Log LogFile;
    
    bool intitalized;
    
    function SetMinSum(uint _val)
    public
    {
        require(intitalized == false);
        MinSum = _val;
    }
    
    function SetLogFile(address _log)
    public
    {
        require(intitalized == false);
        // LogFile = Log(_log);
    }
    
    function Initialized()
    public
    {
        intitalized = true;
    }
    
    function Put(uint _lockTime)
    public
    payable
    {
        // var Acc[msg.sender] = Acc[msg.sender];
        Acc[msg.sender].balance += msg.value;
        if(now+_lockTime>Acc[msg.sender].unlockTime)Acc[msg.sender].unlockTime=now+_lockTime;
        // LogFile.AddMessage(msg.sender,msg.value,"Put");
    }
    
    function Collect(uint _am)
    public
    payable
    {
        // var Acc[msg.sender] = Acc[msg.sender];
        if( Acc[msg.sender].balance>=MinSum && Acc[msg.sender].balance>=_am && now>Acc[msg.sender].unlockTime)
        {
            // <yes> <report> REENTRANCY
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
        Put(0);
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