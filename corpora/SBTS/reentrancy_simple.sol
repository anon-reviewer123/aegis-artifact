/*
 * @source: https://github.com/trailofbits/not-so-smart-contracts/blob/master/reentrancy/Reentrancy.sol
 * @author: -
 * @vulnerable_at_lines: 24
 */

 pragma solidity 0.4.26;

 contract Reentrance {
     mapping (address => uint) userBalance;
     uint tthisBal;

     function getBalance(address u) constant returns(uint){
         return userBalance[u];
     }

     function addToBalance() payable{
        tthisBal += msg.value;
         userBalance[msg.sender] += msg.value;
     }

     function withdrawBalance(){
         // send userBalance[msg.sender] ethers to msg.sender
         // if mgs.sender is a contract, it will call its fallback function
         // <yes> <report> REENTRANCY
         tthisBal -= userBalance[msg.sender];
         bool s = msg.sender.call.value(userBalance[msg.sender])() ;
         require(s == true);
         userBalance[msg.sender] = 0;
     }
 }
