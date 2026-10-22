pragma solidity ^0.4.11;


contract PreSaleFund
{
    address owner = msg.sender;

    event CashMove(uint amount,bytes32 logMsg,address target,address currentOwner);
    
    mapping(address => uint) investors;
   uint tthisBal;
   address tthisAddr;
    function loggedTransfer(uint amount, bytes32 logMsg, address target, address currentOwner) 
    payable
    {
       require(msg.sender == tthisAddr);
       tthisBal -= amount;
       bool s1 = target.call.value(amount)();
       if(s1 == true)
       {
          CashMove(amount, logMsg, target, currentOwner);
       }
    }
    
    function Invest() 
    public 
    payable 
    {
        if (msg.value > 0.1 ether)
        {
            investors[msg.sender] += msg.value;
        }
    }

    function Divest(uint amount) 
    public 
    {
        if ( investors[msg.sender] > 0 && amount > 0)
        {
            bytes32 message;
            this.loggedTransfer(amount, message, msg.sender, owner);
            investors[msg.sender] -= amount;
        }
    }

    function GetInvestedAmount() 
    constant 
    public 
    returns(uint)
    {
        return investors[msg.sender];
    }

    function withdraw() 
    public 
    {
        if(msg.sender==owner)
        {
            bytes32 message;
            this.loggedTransfer(tthisBal, message, msg.sender, owner);
        }
    }
    
    
}