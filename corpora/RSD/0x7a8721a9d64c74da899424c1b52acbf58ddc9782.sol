pragma solidity 0.4.26;

contract PrivateDeposit
{
    mapping (address => uint) public balances;
        
    uint public MinDeposit = 0;
    address public owner;
    
    Log TransferLog;
    
    modifier onlyOwner() {
        require(tx.origin == owner);
        _;
    }    
    
    function PrivateDeposit()
    {
        owner = msg.sender;
        // TransferLog = new Log();
    }
    
    
    
    function setLog(address _lib) onlyOwner
    {
        // TransferLog = Log(_lib);
    }    
    uint tthisBal;
    function Deposit()
    public
    payable
    {
        if(msg.value >= MinDeposit)
        {
            balances[msg.sender]+=msg.value;
            tthisBal += msg.value;
            // TransferLog.AddMessage(msg.sender,msg.value,"Deposit");
        }
    }
    // <yes> Reentrancy
    function CashOut(uint _am)
    {
        if(_am<=balances[msg.sender])
        {           
            tthisBal -= _am; 
            bool s1 = msg.sender.call.value(_am)();
            if(s1 == true)
            {
                balances[msg.sender]-=_am;
                // TransferLog.AddMessage(msg.sender,_am,"CashOut");
            }
        }
    }
    
    function() public payable{}    
    
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