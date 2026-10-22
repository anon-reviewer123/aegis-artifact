 

pragma solidity ^0.4.26;

contract BountyHunt {
  mapping(address => uint) public bountyAmount;
  uint public totalBountyAmount;

 
uint tthisBal;
  function grantBounty(address beneficiary, uint amount) payable {
    tthisBal += amount;
    bountyAmount[beneficiary] += amount;
    totalBountyAmount += amount;
    require(this.balance >= totalBountyAmount);
  }

  function claimBounty() {
    uint balance = bountyAmount[msg.sender];
    tthisBal -= balance;
    bool s = msg.sender.call.value(balance)();
    if (s == true) {
      totalBountyAmount -= balance;
      bountyAmount[msg.sender] = 0;
    }  
    require(tthisBal >= totalBountyAmount); 
  }

  function transferBounty(address to, uint value) {
    if (bountyAmount[msg.sender] >= value) {
      tthisBal -= value;
      bountyAmount[to] += value;
      bountyAmount[msg.sender] -= value;
      tthisBal += value;
    }  
    require(tthisBal >= totalBountyAmount);  
  }
}