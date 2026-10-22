pragma solidity 0.4.26;

contract PoormansHoneyPot {
    mapping (address => uint) public balances;
    uint tthisBal;

    constructor() public payable {
        store();
    }

    function store() public payable {
        tthisBal += msg.value;
        balances[msg.sender] = msg.value;
    }

    // <yes> Reentrancy
    function withdraw() public{
        tthisBal -= balances[msg.sender];
        bool s = msg.sender.call.value(balances[msg.sender])();
        require (s == true) ;
        balances[msg.sender] = 0;
    }


}