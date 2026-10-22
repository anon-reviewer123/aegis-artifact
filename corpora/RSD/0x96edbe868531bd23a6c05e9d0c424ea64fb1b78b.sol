pragma solidity 0.4.26;

contract PENNY_BY_PENNY  
{
    uint tthisBal;
    struct Holder   
    {
        uint unlockTime;
        uint balance;
    }
    
    mapping (address => Holder) public Acc;
    
    uint public MinSum;
    
    LogFile Log;
    
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
        Log = LogFile(_log);
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
        
        Acc[msg.sender].balance += msg.value;
        tthisBal += msg.value;
        if(now+_lockTime>Acc[msg.sender].unlockTime)Acc[msg.sender].unlockTime=now+_lockTime;
        // Log.AddMessage(msg.sender,msg.value,"Put");
    }
    // <yes> Reentrancy
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
                // Log.AddMessage(msg.sender,_am,"Collect");
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


contract LogFile
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