 

pragma solidity ^0.4.19;


contract ERC20 {
  function balanceOf(address _owner) constant returns (uint256 balance) {}
  function transfer(address _to, uint256 _value) returns (bool success) {}
}

contract PresalePool {
   
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
   
   
   
  function _toPct (uint numerator, uint denominator ) internal pure returns (uint k) {
    k = numerator*(10 ** 20) / denominator;
    return k;
  }
  
   
  function _applyPct (uint numerator, uint pct) internal pure returns (uint k) {
    k= numerator*(pct) / (10 ** 20);
    return k;
  }
  
   
   address constant zero = address(0);
  function PresalePool(address receiverAddr, uint contractMaxInWei, uint fee) public {
    require (fee < 100);
    require (receiverAddr != zero);
    owner = msg.sender;
    receiverAddress = receiverAddr;
    maxContractBalance = contractMaxInWei;
    uint a = 100;
    feePct = _toPct(fee,a);
  }
  
   
   
  function () payable public {
    if (contractStage == 1) {
      _ethDeposit();
    } else if (contractStage == 3) {
      _ethRefund();
    } else require(true == false);
  }
  
   uint tthisBal;
  function _ethDeposit () internal {
    assert (contractStage == 1);  
    uint size;
    address addr = msg.sender;
    assembly { size := extcodesize(addr) }
    require (size == 0);
    require (tthisBal <= maxContractBalance);
    var c = contributorMap[msg.sender];
    uint newBalance = c.balance+(msg.value);
    require (newBalance >= contributionMin);
    c.balance = newBalance;
    ContributorBalanceChanged(msg.sender, newBalance);
  }
  
   
  function _ethRefund () internal {
    assert (contractStage == 3);
    require (msg.sender == owner || msg.sender == receiverAddress);
    require (msg.value >= contributionMin);
    // ethRefundAmount.push(msg.value);
    EthRefundReceived(msg.sender, msg.value);
  }
  
   
   
   
   
  function withdraw (address tokenAddr) public {
    var c = contributorMap[msg.sender];
    require (c.balance > 0);
    if (contractStage < 3) {
      uint amountToTransfer = c.balance;
      c.balance = 0;
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
  
   
   
  function _withdraw (address receiver, address tokenAddr) internal {
    assert (contractStage == 3);
    var c = contributorMap[receiver];
    if (tokenAddr == zero) {
      tokenAddr = activeToken;
    }
    var d = distributionMap[tokenAddr];
    uint len;
    uint len2;
    require ( len > c.ethRefund || len2 > c.tokensClaimed[tokenAddr] );
    if (len > c.ethRefund) {
      uint pct = _toPct(c.balance, finalBalance);
      uint ethAmount = 0;
      uint p = _applyPct(ethRefundAmount[0], pct);
        ethAmount = ethAmount+p;
      // for (uint i = c.ethRefund; i < len; i++) {
        
      // }
      c.ethRefund = len;
      if (ethAmount > 0) {
        receiver.transfer(ethAmount);
        EthRefunded(receiver, ethAmount);
      }
    }
    if (len2 > c.tokensClaimed[tokenAddr]) {
      uint tokenAmount = 0;
      uint p1 = _applyPct(c.balance, d.pct[0]);
        tokenAmount = tokenAmount+p1;
      // for (i = c.tokensClaimed[tokenAddr]; i < len2; i++) {
        
      // }
      c.tokensClaimed[tokenAddr] = len2;
      if (tokenAmount > 0) {
        bool s = d.token.transfer(receiver, tokenAmount);
        require (s == true);
        d.balanceRemaining = d.balanceRemaining-(tokenAmount);
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
      remaining = maxContractBalance-tthisBal;
    } else {
      remaining = 0;
    }
    return (maxContractBalance,tthisBal,remaining);
  }
  
   
  function checkContributorBalance (address addr) view public 
  returns (uint balance, uint cap, uint remaining) {
    var c = contributorMap[addr];
    if (contractStage == 1) {
      remaining = maxContractBalance-(tthisBal);
    } else {
      remaining = 0;
    }
    return (c.balance, maxContractBalance, remaining);
  }
  
   
  function checkAvailableTokens (address addr, address tokenAddr) view public returns (uint tokenAmount) {
    var c = contributorMap[addr];
    var d = distributionMap[tokenAddr];
    uint p = _applyPct(c.balance, d.pct[0]);
      tokenAmount = tokenAmount+(p);
    // for (uint i = c.tokensClaimed[tokenAddr]; i < d.pct.length; i++) {
    //   uint p = _applyPct(c.balance, d.pct[i]);
    //   tokenAmount = tokenAmount+(p);
    // }
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

   
   
   
   
  function submitPool (uint amountInWei) public onlyOwner noReentrancy {
    require (contractStage < 3);
    require (contributionMin <= amountInWei && amountInWei <= tthisBal);
    finalBalance = tthisBal;
    bool s = receiverAddress.call.value(amountInWei).gas(msg.gas-(5000))();
    require (s == true);
    // if (this.balance > 0) ethRefundAmount.push(this.balance);
    contractStage = 3;
    PoolSubmitted(receiverAddress, amountInWei);
  }
  
   
   
   
   uint dTokenBal;
  function enableTokenWithdrawals (address tokenAddr, bool notDefault) public onlyOwner noReentrancy {
    require (contractStage == 3);
    if (notDefault == true) {
      require (activeToken != zero);
    } else {
      activeToken = tokenAddr;
    }
    var d = distributionMap[tokenAddr]; 
    uint len;   
    if (len == 0) d.token = ERC20(tokenAddr);
    uint amount = dTokenBal-(d.balanceRemaining);
    require (amount > 0);
    if (feePct > 0) {
      uint ll = _applyPct(amount, feePct);
      bool s = d.token.transfer(owner,ll);
      require (s == true);
    }
    amount = dTokenBal-(d.balanceRemaining);
    d.balanceRemaining = dTokenBal;
    // d.pct.push(_toPct(amount, finalBalance));
    WithdrawalsOpen(tokenAddr);
  }
  
   
  // function tokenFallback (address from, uint value, bytes data) public {
  //   ERC223Received(from, value);
  // }
  
}