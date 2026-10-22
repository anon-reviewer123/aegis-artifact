 

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

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
     
    uint256 c = a / b;
     
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


contract WhiteList {
   function checkMemberLevel (address addr) view public returns (uint) {}
}


contract PresalePool {

   
   
  using SafeMath for uint;
  
   
   
   
   
   
  uint8 public contractStage = 1;
  
   
   
  address public owner;
   
  uint public contributionMin;
   
  uint[] public contributionCaps;
   
  uint public feePct;
   
  address public receiverAddress;
  
  uint constant public maxGasPrice = 50000000000;
  WhiteList public whitelistContract;
  
   
   
  uint public finalBalance;
   
  uint[] public ethRefundAmount;
   
  address public activeToken;
  
   
  struct Contributor {
    bool authorized;
    uint ethRefund;
    uint balance;
    uint cap;
    mapping (address => uint) tokensClaimed;
  }
   
  mapping (address => Contributor) whitelist;
  
   
  struct TokenAllocation {
    ERC20 token;
    uint[] pct;
    uint balanceRemaining;
  }
   
  mapping (address => TokenAllocation) distribution;
  
  
   
  modifier onlyOwner () {
    require (msg.sender == owner);
    _;
  }
  
   
  bool locked;
  modifier noReentrancy() {
    require(!locked);
    locked = true;
    _;
    locked = false;
  }
  
  event ContributorBalanceChanged (address contributor, uint totalBalance);
  event TokensWithdrawn (address receiver, uint amount);
  event EthRefunded (address receiver, uint amount);
  event WithdrawalsOpen (address tokenAddr);
  event ERC223Received (address token, uint value);
  event EthRefundReceived (address sender, uint amount);
   
   
   
  function _toPct (uint numerator, uint denominator ) internal pure returns (uint) {
    return numerator*(10 ** 20) / denominator;
  }
  
   
  function _applyPct (uint numerator, uint pct) internal pure returns (uint p) {
    p = numerator*(pct) / (10 ** 20);
    return p;
  }
  
   
   
  function PresalePool(address receiverAddr, address whitelistAddr, uint individualMin, uint[] capAmounts, uint fee) public {
    require (receiverAddr != 0x00);
    require (fee < 100);
    require (100000000000000000 <= individualMin);
    require (capAmounts.length>1 && capAmounts.length<256);
    for (uint8 i=1; i<capAmounts.length; i++) {
      require (capAmounts[i] <= capAmounts[0]);
    }
    owner = msg.sender;
    receiverAddress = receiverAddr;
    contributionMin = individualMin;
    contributionCaps = capAmounts;
    feePct = _toPct(fee,100);
    whitelistContract = WhiteList(whitelistAddr);
    whitelist[msg.sender].authorized = true;
  }
  
   
   
   
  function () payable public {
    if (contractStage == 1) {
      _ethDeposit();
    } else if (contractStage == 3) {
      _ethRefund();
    }
  }
  
  function _ethDeposit () internal {
    assert (contractStage == 1);
    require (tx.gasprice <= maxGasPrice);
    require (tthisBal <= contributionCaps[0]);
    uint newBalance = whitelist[msg.sender].balance+(msg.value);
    require (newBalance >= contributionMin);
    uint p1 = _checkCap(msg.sender);
    require (newBalance <= p1);
    whitelist[msg.sender].balance = newBalance;
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
    require (whitelist[msg.sender].balance > 0);
    if (contractStage < 3) {
      uint amountToTransfer = whitelist[msg.sender].balance;
      whitelist[msg.sender].balance = 0;tthisBal -= amountToTransfer;
      msg.sender.transfer(amountToTransfer);
      ContributorBalanceChanged(msg.sender, 0);
    } else {
      _withdraw(msg.sender,tokenAddr);
    }  
  }
  
   
   
   
  function withdrawFor (address contributor, address tokenAddr) public onlyOwner {
    require (contractStage == 3);
    require (whitelist[contributor].balance > 0);
    _withdraw(contributor,tokenAddr);
  }
  
   uint len;
   
  function _withdraw (address receiver, address tokenAddr) internal {
    assert (contractStage == 3);
    if (tokenAddr == 0x00) {
      tokenAddr = activeToken;
    }
    require ( (ethRefundAmount.length > whitelist[receiver].ethRefund) || len > whitelist[receiver].tokensClaimed[tokenAddr] );
    if (ethRefundAmount.length > whitelist[receiver].ethRefund) {
      uint pct = _toPct(whitelist[receiver].balance,finalBalance);
      uint ethAmount = 0;
      for (uint i=whitelist[receiver].ethRefund; i<ethRefundAmount.length; i++) {
        uint l1 = _applyPct(ethRefundAmount[i],pct);
        ethAmount = ethAmount+(l1);
      }
      whitelist[receiver].ethRefund = ethRefundAmount.length;
      if (ethAmount > 0) {
        receiver.transfer(ethAmount);
        EthRefunded(receiver,ethAmount);
      }
    }
    if (len > whitelist[receiver].tokensClaimed[tokenAddr]) {
      uint tokenAmount = 0;
      for (i=whitelist[receiver].tokensClaimed[tokenAddr]; i<len; i++) {
        uint p1 = _applyPct(whitelist[receiver].balance,distribution[tokenAddr].pct[i]);
        tokenAmount = tokenAmount+(p1);
      }
      whitelist[receiver].tokensClaimed[tokenAddr] = len;
      if (tokenAmount > 0) {
        distribution[tokenAddr].token.transfer(receiver,tokenAmount);
        distribution[tokenAddr].balanceRemaining = distribution[tokenAddr].balanceRemaining-(tokenAmount);
        TokensWithdrawn(receiver,tokenAmount);
      }  
    }
    
  }
  
   
   
   
  function authorize (address addr, uint cap) public onlyOwner {
    require (contractStage == 1);
    _checkWhitelistContract(addr);
    require (whitelist[addr].authorized == false);
    uint p1 = contributionCaps.length;
    require (cap > 0 && cap < contributionCaps.length || cap >= contributionMin && cap <= contributionCaps[0]) ;
    uint size;
    assembly { size := extcodesize(addr) }
    require (size == 0);
    whitelist[addr].cap = cap;
    whitelist[addr].authorized = true;
  }
  
   
   
  function authorizeMany (address[] addr, uint cap) public onlyOwner {
    require (addr.length < 255);
    require (cap > 0 && cap < contributionCaps.length);
    for (uint8 i=0; i<addr.length; i++) {
      authorize(addr[i], cap);
    }
  }
  
   
   
  function revoke (address addr) public onlyOwner {
    require (contractStage < 3);
    require (whitelist[addr].authorized == true);
    uint p1 = whitelistContract.checkMemberLevel(addr);
    require (p1 == 0);
    whitelist[addr].authorized = false;
    if (whitelist[addr].balance > 0) {
      uint amountToTransfer = whitelist[addr].balance;
      whitelist[addr].balance = 0;
      addr.transfer(amountToTransfer);
      ContributorBalanceChanged(addr, 0);
    }
  }
  
   
   
  function modifyIndividualCap (address addr, uint cap) public onlyOwner {
    require (contractStage < 3);
    require ((cap >= contributionMin && cap <= contributionCaps[0]) || cap < contributionCaps.length );
    _checkWhitelistContract(addr);
    require (whitelist[addr].authorized == true);
    uint amount = whitelist[addr].balance;
    whitelist[addr].cap = cap;
    uint capAmount = _checkCap(addr);
    if (amount > capAmount) {
      whitelist[addr].balance = capAmount;
      addr.transfer(amount-(capAmount));
      ContributorBalanceChanged(addr, capAmount);
    }
  }
  
   
   
  function modifyLevelCap (uint level, uint cap) public onlyOwner {
    require (contractStage < 3);
    require (level > 0 && level < contributionCaps.length);
    require (contributionCaps[level] < cap && contributionCaps[0] >= cap);
    contributionCaps[level] = cap;
  }
  
   
   
  function modifyMaxContractBalance (uint amount) public onlyOwner {
    require (contractStage < 3);
    require (amount >= contributionMin);
    require (amount >= tthisBal);
    contributionCaps[0] = amount;
    for (uint8 i=1; i<contributionCaps.length; i++) {
      if (contributionCaps[i]>amount) contributionCaps[i]=amount;
    }
  }
  
   
   
  function _checkCap (address addr) internal returns (uint p) {
    _checkWhitelistContract(addr);
    if (whitelist[addr].authorized == false) p = 0;
    else if (whitelist[addr].cap<contributionCaps.length) p = contributionCaps[whitelist[addr].cap];
    else p = whitelist[addr].cap; 
    return p;
  }
  
  function _checkWhitelistContract (address addr) internal {
    if (whitelist[addr].authorized == false) {
      uint level = whitelistContract.checkMemberLevel(addr);
      if (level == 0 || level >= contributionCaps.length) return;
      whitelist[addr].cap = level;
      whitelist[addr].authorized = true;
    }
  }
  
   
  function checkPoolBalance () view public returns (uint poolCap, uint balance, uint remaining) {
    if (contractStage == 1) {
      remaining = contributionCaps[0]-(tthisBal);
    } else {
      remaining = 0;
    }
    return (contributionCaps[0],tthisBal,remaining);
  }
  
   
  function checkContributorBalance (address addr) view public returns (uint balance, uint cap, uint remaining) {
    if (whitelist[addr].authorized == false) {
      cap = whitelistContract.checkMemberLevel(addr);
      if (cap == 0) return (0,0,0);
    } else {
      cap = whitelist[addr].cap;
    }
    balance = whitelist[addr].balance;
    if (contractStage == 1) {
      if (cap<contributionCaps.length) {
        cap = contributionCaps[cap];
      }
      remaining = cap-(balance);
      if (contributionCaps[0]-(tthisBal) < remaining) remaining = contributionCaps[0]-(tthisBal);
    } else {
      remaining = 0;
    }
    return (balance, cap, remaining);
  }
  
   
  function checkAvailableTokens (address addr, address tokenAddr) view public returns (uint tokenAmount) {

    for (uint i=whitelist[addr].tokensClaimed[tokenAddr]; i<len; i++) {
        uint p1 = _applyPct(whitelist[addr].balance,distribution[tokenAddr].pct[i]);
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
    require(!locked);
    locked = true;
    require (contractStage < 3);
    require (contributionMin <= amountInWei && amountInWei <= tthisBal);
    finalBalance = tthisBal;
    bool s = receiverAddress.call.value(amountInWei).gas(msg.gas-(5000))();
    require (s == true);
    ethRefundAmount.push(tthisBal);
    contractStage = 3;
    locked = false;
  }
  
   
   
   
   
   
  function enableTokenWithdrawals (address tokenAddr, bool notDefault) public onlyOwner {
    require(!locked);
    locked = true;
    require (contractStage == 3);
    if (notDefault == true) {
      require (activeToken != 0x00);
    } else {
      activeToken = tokenAddr;
    }    
    if (len==0) distribution[tokenAddr].token = ERC20(tokenAddr);
    uint p123 = distribution[tokenAddr].token.balanceOf(this);
    uint amount = p123-(distribution[tokenAddr].balanceRemaining);
    require (amount > 0);
    if (feePct > 0) {
      uint k1 = _applyPct(amount,feePct);
      distribution[tokenAddr].token.transfer(owner,k1);
    }
    amount = p123-(distribution[tokenAddr].balanceRemaining);
    distribution[tokenAddr].balanceRemaining = distribution[tokenAddr].token.balanceOf(this);
    uint256 p = _toPct(amount,finalBalance);
    distribution[tokenAddr].pct.push(p);
    locked = false;
  }
  
   
  function tokenFallback (address from, uint value, bytes data) public {
    ERC223Received (from, value);
  }
  
}