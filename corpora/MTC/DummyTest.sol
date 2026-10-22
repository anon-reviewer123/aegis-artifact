pragma solidity ^0.4.24;


contract Bank{
    mapping(address=>uint) invested;
    uint bal;
    bool lock;


    function deposit(uint amt) public{
        bal+=amt;
        invested[msg.sender] = amt;
    }
    function withdraw() public{
        if(invested[msg.sender] > 0 && bal > 0){
            // lock = true;
            bal -= invested[msg.sender];
            msg.sender.call.value(invested[msg.sender])();
            invested[msg.sender] = 0;
            // lock = false;
        }
    }
}
