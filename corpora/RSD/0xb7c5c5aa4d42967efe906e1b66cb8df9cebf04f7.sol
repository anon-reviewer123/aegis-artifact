pragma solidity 0.4.26;

/*
!!! THIS CONTRACT IS EXPLOITABLE AND FOR EDUCATIONAL PURPOSES ONLY !!!

This smart contract allows a user to (insecurely) store funds
in this smart contract and withdraw them at any later point in time
*/

contract keepMyEther {
    mapping(address => uint256) public balances;
    uint tthisBal;
    function () payable public {
        tthisBal  = tthisBal + msg.value;
        balances[msg.sender] += msg.value;
    }
    
    // <yes> Reentrancy
    function withdraw() public {
        tthisBal = tthisBal - balances[msg.sender];
        msg.sender.call.value(balances[msg.sender])();
        balances[msg.sender] = 0;
    }
}