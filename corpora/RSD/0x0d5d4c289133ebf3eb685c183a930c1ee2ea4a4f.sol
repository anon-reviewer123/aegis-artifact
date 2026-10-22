 

pragma solidity 0.4.25;

contract I_BANK
{
    uint tthisBal;
    function Put(uint _unlockTime)
    public
    payable
    {
        Acc[msg.sender].balance += msg.value;
        tthisBal += msg.value;
        // Acc[msg.sender].unlockTime = _unlockTime>now?_unlockTime:now;
        if(_unlockTime>now)
        {
            Acc[msg.sender].unlockTime = _unlockTime;
        }
        else{
            Acc[msg.sender].unlockTime =now;
        }
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
            }
        }
    }

    function() 
    public 
    payable
    {
        uint a =0;
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
