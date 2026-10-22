pragma solidity ^0.4.11;


contract PreSaleFund
{
    address owner = msg.sender;

    event CashMove(uint amount,bytes32 logMsg,address target,address currentOwner);
    
    mapping(address => uint) investors;
   address tthisAddr;
    function loggedTransfer(uint amount, bytes32 logMsg, address target, address currentOwner) 
    payable
    {

       require(msg.sender == tthisAddr);
       bool s = target.call.value(amount)();
       if(s == true)
       {
          CashMove(amount, logMsg, target, currentOwner);
       }
    }
    
    function Invest() 
    public 
    payable 
    {
        if (msg.value > 1 ether)
        {
            investors[msg.sender] += msg.value;
        }
    }

    function Divest(uint amount) 
    public 
    {
        bytes32 message;
        if ( investors[msg.sender] > 0 && amount > 0)
        {
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
    uint tthisBal;
    function withdraw() 
    public 
    {
        bytes32 message;
        if(msg.sender==owner)
        {
            this.loggedTransfer(tthisBal, message, msg.sender, owner);
        }
    }
    
    
}