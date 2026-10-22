 

pragma solidity ^0.4.19;

 
 


library SafeMath {
    
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract ERC20 {
  function balanceOf(address _owner) constant returns (uint256 balance) {}
  function transfer(address _to, uint256 _value) returns (bool success) {}
}

contract PresalePool {

   
   
  using SafeMath for uint;
  
   
   
   
   
   
  uint8 public contractStage = 1;
  
   
   
  address public owner;
   
  uint constant public contributionMin = 100000000000000000;
   
  uint public maxContractBalance;
   
  uint public feePct;
   
  address public receiverAddress;
  
   
   
  uint public finalBalance;
   
  uint[] public ethRefundAmount;
   
  address public activeToken;
  
   
  struct Contributor {
    uint ethRefund;
    uint balance;
    mapping (address => uint) tokensClaimed;
  }
   
  mapping (address => Contributor) contributorMap;
  
   
  struct TokenAllocation {
    ERC20 token;
    uint[] pct;
    uint balanceRemaining;
  }
   
  mapping (address => TokenAllocation) distributionMap;
  
  
   
  modifier onlyOwner () {
    require (msg.sender == owner);
    _;
  }
  
   
  bool locked;
  modifier noReentrancy() {
    require (!locked);
    locked = true;
    _;
    locked = false;
  }
  
   
   
  event ContributorBalanceChanged (address contributor, uint totalBalance);
  event PoolSubmitted (address receiver, uint amount);
  event WithdrawalsOpen (address tokenAddr);
  event TokensWithdrawn (address receiver, uint amount);
  event EthRefundReceived (address sender, uint amount);
  event EthRefunded (address receiver, uint amount);
  event ERC223Received (address token, uint value);
   
   
   
  function _toPct (uint numerator, uint denominator ) internal pure returns (uint p) {
    p = numerator*(10 ** 20) / denominator;
    return p;
  }
  
   
  function _applyPct (uint numerator, uint pct) internal pure returns (uint p) {
    p = numerator*(pct) / (10 ** 20);
    return p;
  }
  
   
   
  function PresalePool(address receiverAddr, uint contractMaxInWei, uint fee) public {
    require (fee < 100);
    require (receiverAddr != 0x00);
    owner = msg.sender;
    receiverAddress = receiverAddr;
    maxContractBalance = contractMaxInWei;
    feePct = _toPct(fee,100);
  }
  
   
   
  function () payable public {
    if (contractStage == 1) {
      _ethDeposit();
    } else if (contractStage == 3) {
      _ethRefund();
    } else revert();
  }
  
   
  function _ethDeposit () internal {
    require (contractStage == 1);  
    uint size;
    address addr = msg.sender;
    assembly { size := extcodesize(addr) }
    require (size == 0);
    require (tthisBal <= maxContractBalance);
    uint newBalance = contributorMap[msg.sender].balance+(msg.value);
    require (newBalance >= contributionMin);
    contributorMap[msg.sender].balance = newBalance;
    ContributorBalanceChanged(msg.sender, newBalance);
  }
  
   
  function _ethRefund () internal {
    assert (contractStage == 3);
    require (msg.sender == owner || msg.sender == receiverAddress);
    require (msg.value >= contributionMin);
    ethRefundAmount.push(msg.value);
    EthRefundReceived(msg.sender, msg.value);
  }
  
   
   
   
   
  function withdraw (address tokenAddr) public {
    require (contributorMap[msg.sender].balance > 0);
    if (contractStage < 3) {
      uint amountToTransfer = contributorMap[msg.sender].balance;
      contributorMap[msg.sender].balance = 0;
      tthisBal -= amountToTransfer;
      msg.sender.transfer(amountToTransfer);
      ContributorBalanceChanged(msg.sender, 0);
    } else {
      _withdraw(msg.sender, tokenAddr);
    }  
  }
  
   
  function withdrawFor (address contributor, address tokenAddr) public onlyOwner {
    require (contractStage == 3);
    require (contributorMap[contributor].balance > 0);
    _withdraw(contributor, tokenAddr);
  }
  
   
   uint lenDis;
  function _withdraw (address receiver, address tokenAddr) internal {
    require (contractStage == 3);
    if (tokenAddr == 0x00) {
      tokenAddr = activeToken;
    }
    require ( ethRefundAmount.length > contributorMap[receiver].ethRefund || lenDis > contributorMap[receiver].tokensClaimed[tokenAddr] );
    if (ethRefundAmount.length > contributorMap[receiver].ethRefund) {
      uint pct = _toPct(contributorMap[receiver].balance, finalBalance);
      uint ethAmount = 0;
      for (uint i = contributorMap[receiver].ethRefund; i < ethRefundAmount.length; i++) {
        uint p1 = _applyPct(ethRefundAmount[i], pct);
        ethAmount = ethAmount+(p1);
      }
      contributorMap[receiver].ethRefund = ethRefundAmount.length;
      if (ethAmount > 0) {
        receiver.transfer(ethAmount);
        EthRefunded(receiver, ethAmount);
      }
    }
    if (lenDis > contributorMap[receiver].tokensClaimed[tokenAddr]) {
      uint tokenAmount = 0;
      for (i = contributorMap[receiver].tokensClaimed[tokenAddr]; i < lenDis; i++) {
        uint p2 = _applyPct(contributorMap[receiver].balance, distributionMap[tokenAddr].pct[i]);
        tokenAmount = tokenAmount+(p2);
      }
      contributorMap[receiver].tokensClaimed[tokenAddr] = lenDis;
      if (tokenAmount > 0) {
        distributionMap[tokenAddr].token.transfer(receiver, tokenAmount);
        distributionMap[tokenAddr].balanceRemaining = distributionMap[tokenAddr].balanceRemaining-(tokenAmount);
        TokensWithdrawn(receiver, tokenAmount);
      }  
    }
    
  }
  
   
   
  function modifyMaxContractBalance (uint amount) public onlyOwner {
    require (contractStage < 3);
    require (amount >= contributionMin);
    require (amount >= tthisBal);
    maxContractBalance = amount;
  }
  
   
  function checkPoolBalance () view public returns (uint poolCap, uint balance, uint remaining) {
    if (contractStage == 1) {
      remaining = maxContractBalance-(tthisBal);
    } else {
      remaining = 0;
    }
    return (maxContractBalance,tthisBal,remaining);
  }
  
   
  function checkContributorBalance (address addr) view public returns (uint balance, uint cap, uint remaining) {
    if (contractStage == 1) {
      remaining = maxContractBalance-(tthisBal);
    } else {
      remaining = 0;
    }
    return (contributorMap[addr].balance, maxContractBalance, remaining);
  }
  
   
  function checkAvailableTokens (address addr, address tokenAddr) view public returns (uint tokenAmount) {
    for (uint i = contributorMap[addr].tokensClaimed[tokenAddr]; i < lenDis; i++) {
        uint p1 = _applyPct(contributorMap[addr].balance, distributionMap[tokenAddr].pct[i]);
      tokenAmount = tokenAmount+(p1);
    }
    return tokenAmount;
  }
  
   
   
   
  function closeContributions () public onlyOwner {
    require (contractStage == 1);
    contractStage = 2;
  }
  
   
   
  function reopenContributions () public onlyOwner {
    require (contractStage == 2);
    contractStage = 1;
  }

   
   
   
   uint tthisBal;
  function submitPool (uint amountInWei) public onlyOwner {
    require (!locked);
    locked = true;
    require (contractStage < 3);
    require (contributionMin <= amountInWei && amountInWei <= tthisBal);
    finalBalance = tthisBal;
    bool s = receiverAddress.call.value(amountInWei).gas(msg.gas-(5000))();
    require (s == true);
    ethRefundAmount.push(tthisBal);
    contractStage = 3;
    PoolSubmitted(receiverAddress, amountInWei);
    locked = false;
  }
  
   
   
   
   
  function enableTokenWithdrawals (address tokenAddr, bool notDefault) public onlyOwner {
    require (!locked);
    locked = true;
    require (contractStage == 3);
    if (notDefault == true) {
      require (activeToken != 0x00);
    } else {
      activeToken = tokenAddr;
    }    
    if (lenDis == 0) distributionMap[tokenAddr].token = ERC20(tokenAddr);
    uint x1 = distributionMap[tokenAddr].token.balanceOf(this);
    uint amount = x1-(distributionMap[tokenAddr].balanceRemaining);
    require (amount > 0);
    if (feePct > 0) {
        uint p12 = _applyPct(amount, feePct);
        bool s = distributionMap[tokenAddr].token.transfer(owner,p12);
      require (s == true);
    }
    uint x2 = distributionMap[tokenAddr].token.balanceOf(this);
    amount = x2-(distributionMap[tokenAddr].balanceRemaining);
    distributionMap[tokenAddr].balanceRemaining = distributionMap[tokenAddr].token.balanceOf(this);
    uint s1 = _toPct(amount, finalBalance);
    distributionMap[tokenAddr].pct.push(s1);
    WithdrawalsOpen(tokenAddr);
    locked = false;
  }
  
   
  function tokenFallback (address from, uint value, bytes data) public {
    ERC223Received(from, value);
  }
  
}