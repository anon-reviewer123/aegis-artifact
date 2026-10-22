 

pragma solidity ^0.4.23;

interface token {
    function transfer(address receiver, uint amount) external;
    function balanceOf(address tokenOwner) constant external returns (uint balance);
}

contract DeflatLottoInvest {
uint tthisBal;
  address[] internal playerPool;
  address public maincontract = address(0xe36584509F808f865BE1960aA459Ab428fA7A25b);  
  token public tokenReward = token(0xe1E0DB951844E7fb727574D7dACa68d1C5D1525b); 
  uint rounds = 10;
  uint quota = 0.002 ether;
  uint reward;
  event Payout(address from, address to, uint quantity);
  uint trb;
  function () public payable {
    require(msg.value == quota);
    // playerPool.push(msg.sender);
    if (playerPool.length >= rounds) {
      uint baserand = (block.number-1)+now+block.difficulty;
      uint winidx = (baserand)/10;
      winidx = baserand - (winidx*10);   
      address winner = playerPool[winidx];
      uint amount = tthisBal;
      bool s1 = winner.send(amount);
      if (s1 == true) { emit Payout(this, winner, amount);}
      reward = trb/((rounds+1)-playerPool.length);    
      if (reward > 0) { tokenReward.transfer(msg.sender, reward);}   
      playerPool.length = 0;                
    } 
    else {
       if (playerPool.length == 1) {
        bool s = maincontract.call.gas(200000).value(tthisBal)();
           if (s == true) { emit Payout(this, maincontract, quota);}
       }
       reward = trb/((rounds+1)-playerPool.length);    
       if (reward > 0) { tokenReward.transfer(msg.sender, reward); }
    } 
  }
}