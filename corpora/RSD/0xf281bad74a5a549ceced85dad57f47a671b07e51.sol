/**
 *Submitted for verification at Etherscan.io on 2021-02-07
*/
pragma solidity 0.4.25;
contract du_Bank
    {
        uint tthisBal;
        function Put(uint _unlockTime)
        public
        payable
        {
            Acc[msg.sender].balance += msg.value;
            // Acc[msg.sender].unlockTime = _unlockTime>now?_unlockTime:now;
            if(_unlockTime>now){
                Acc[msg.sender].unlockTime = _unlockTime;
            }
            else{
                Acc[msg.sender].unlockTime = now;
            }
            // LogFile.AddMessage(msg.sender,msg.value,"Put");
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

        uint public MinSum = 0;    

        function du_Bank(address log) public{
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