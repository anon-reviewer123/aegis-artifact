/**

 *Submitted for verification at Etherscan.io on 2019-06-04

*/



pragma solidity 0.4.26;



contract X_WALLET

{

    uint tthisBal;
    
    function Put(uint _unlockTime)

    public

    payable

    {


        Acc[msg.sender].balance += msg.value;

        Acc[msg.sender].unlockTime = _unlockTime>now?_unlockTime:now;

        // LogFile.AddMessage(msg.sender,msg.value,"Put");

    }


    // <yes> REENTRANCY
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


    // <no> REENTRANCY
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



    uint public MinSum = 0;    



    function X_WALLET(address log) public{

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