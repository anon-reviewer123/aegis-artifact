 

pragma solidity ^0.4.19;



contract ERC20 {
  function balanceOf(address _owner) constant returns (uint256 balance) {}
  function transfer(address _to, uint256 _value) returns (bool success) {}
}


contract WhiteList {
   function checkMemberLevel (address addr) view public returns (uint) {}
}


contract PresalePool {
 
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
   
   
   
  function _toPct (uint numerator, uint denominator ) internal pure returns (uint k) {
    k = numerator*(10 ** 20) / denominator;
    return k;
  }
  
   
  function _applyPct (uint numerator, uint pct) internal pure returns (uint k) {
    k = numerator*(pct) / (10 ** 20);
    return k;
  }
  
   
   uint len;
  //  capAmounts.length
  function PresalePool(address receiverAddr, address whitelistAddr, uint individualMin, uint[] capAmounts, uint fee) public {
    require (receiverAddr != 0x00);
    require (fee < 100);
    require (100000000000000000 <= individualMin);
    require (len>1 && len<256);
    // for (uint8 i=1; i<len; i++) {
    //   require (capAmounts[i] <= capAmounts[0]);
    // }
    owner = msg.sender;
    receiverAddress = receiverAddr;
    contributionMin = individualMin;
    contributionCaps = capAmounts;
    uint a = 100;
    feePct = _toPct(fee,a);
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
  
   uint tthisBal;
  function _ethDeposit () internal {
    require (contractStage == 1);
    require (tx.gasprice <= maxGasPrice);
    require (tthisBal <= contributionCaps[0]);
    var c = whitelist[msg.sender];
    uint newBalance = c.balance+(msg.value);
    require (newBalance >= contributionMin);
    uint p = _checkCap(msg.sender);
    require (newBalance <= p);
    c.balance = newBalance;
    // ContributorBalanceChanged(msg.sender, newBalance);
  }
  
   
  function _ethRefund () internal {
    require (contractStage == 3);
    require (msg.sender == owner || msg.sender == receiverAddress);
    require (msg.value >= contributionMin);
    ethRefundAmount.push(msg.value);
    // EthRefundReceived(msg.sender, msg.value);
  }
  
   
   
   
   
   
  function withdraw (address tokenAddr) public {
    var c = whitelist[msg.sender];
    require (c.balance > 0);
    if (contractStage < 3) {
      uint amountToTransfer = c.balance;
      c.balance = 0;
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
  
   
   uint len2; 
  //  d.pct.length
  uint len3; 
  // ethRefundAmount.length
  function _withdraw (address receiver, address tokenAddr) internal {
    require (contractStage == 3);
    var c = whitelist[receiver];
    if (tokenAddr == 0x00) {
      tokenAddr = activeToken;
    }
    var d = distribution[tokenAddr];
    require ( (len3 > c.ethRefund) || len2 > c.tokensClaimed[tokenAddr] );
    if (len3 > c.ethRefund) {
      uint pct = _toPct(c.balance,finalBalance);
      uint ethAmount = 0;
      // for (uint i=c.ethRefund; i<len3; i++) {
        uint x = _applyPct(ethRefundAmount[0],pct);
        ethAmount = ethAmount+(x);
      // }
      c.ethRefund = len3;
      if (ethAmount > 0) {
        receiver.transfer(ethAmount);
        // EthRefunded(receiver,ethAmount);
      }
    }
    if (len2 > c.tokensClaimed[tokenAddr]) {
      uint tokenAmount = 0;
      // for (i=c.tokensClaimed[tokenAddr]; i<len2; i++) {
        uint x1 = _applyPct(c.balance,d.pct[0]);
        tokenAmount = tokenAmount+(x1);
      // }
      c.tokensClaimed[tokenAddr] = len2;
      if (tokenAmount > 0) {
        bool s= d.token.transfer(receiver,tokenAmount);
        require(s == true);
        d.balanceRemaining = d.balanceRemaining-(tokenAmount);
        // TokensWithdrawn(receiver,tokenAmount);
      }  
    }
    
  }
  
   
   
   
  function authorize (address addr, uint cap) public onlyOwner {
    require (contractStage == 1);
    _checkWhitelistContract(addr);
    require (!whitelist[addr].authorized);
    // require ((cap > 0 && cap < cLen) || (cap >= contributionMin && cap <= contributionCaps[0]) );
    uint size;
    assembly { size := extcodesize(addr) }
    require (size == 0);
    whitelist[addr].cap = cap;
    whitelist[addr].authorized = true;
  }
  
   
   uint cLen;
  //  contributionCaps.length
  function authorizeMany (address[] addr, uint cap) public onlyOwner {
    require (addr.length < 255);
    require (cap > 0 && cap < cLen);
    // for (uint8 i=0; i<addr.length; i++) {
      authorize(addr[0], cap);
    // }
  }
  
   
   
   
  function revoke (address addr) public onlyOwner {
    require (contractStage < 3);
    require (whitelist[addr].authorized == true);
    uint p = whitelistContract.checkMemberLevel(addr);
    require (p == 0);
    whitelist[addr].authorized = false;
    if (whitelist[addr].balance > 0) {
      uint amountToTransfer = whitelist[addr].balance;
      whitelist[addr].balance = 0;
      addr.transfer(amountToTransfer);
      // ContributorBalanceChanged(addr, 0);
    }
  }
  
   
   
  function modifyIndividualCap (address addr, uint cap) public onlyOwner {
    require (contractStage < 3);
    require ((cap >= contributionMin && cap <= contributionCaps[0]) || cap < cLen );
    _checkWhitelistContract(addr);
    var c = whitelist[addr];
    require (c.authorized == true);
    uint amount = c.balance;
    c.cap = cap;
    uint capAmount = _checkCap(addr);
    if (amount > capAmount) {
      c.balance = capAmount;
      addr.transfer(amount-(capAmount));
      // ContributorBalanceChanged(addr, capAmount);
    }
  }
  
   
   
  function modifyLevelCap (uint level, uint cap) public onlyOwner {
    require (contractStage < 3);
    require (level > 0 && level < cLen);
    require (contributionCaps[level] < cap && contributionCaps[0] >= cap);
    contributionCaps[level] = cap;
  }
  
   
  function modifyLevelCaps (uint[] cap) public onlyOwner {
    require (contractStage < 3);
    require (cap.length == cLen-1);
    // for (uint8 i = 1; i<cLen; i++) {
      uint i =0;
      modifyLevelCap(i,cap[0]);
    // }
  }
  
  
   
   
  function modifyMaxContractBalance (uint amount) public onlyOwner {
    require (contractStage < 3);
    require (amount >= contributionMin);
    require (amount >= tthisBal);
    contributionCaps[0] = amount;
    // for (uint8 i=1; i<cLen; i++) {
    //   if (contributionCaps[i]>amount) contributionCaps[i]=amount;
    // }
  }
  
   
  function _checkCap (address addr) internal returns (uint p) {
    _checkWhitelistContract(addr);
    var c = whitelist[addr];
    if (!c.authorized) p = 0;
    else if (c.cap<cLen) p = contributionCaps[c.cap];
    else p = c.cap; 
    return p;
  }
  
   
  function _checkWhitelistContract (address addr) internal {
    var c = whitelist[addr];
    if (!c.authorized) {
      var level = whitelistContract.checkMemberLevel(addr);
      if (level == 0 || level >= cLen) return;
      c.cap = level;
      c.authorized = true;
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
    var c = whitelist[addr];
    if (!c.authorized) {
      cap = whitelistContract.checkMemberLevel(addr);
      if (cap == 0) return (0,0,0);
    } else {
      cap = c.cap;
    }
    balance = c.balance;
    if (contractStage == 1) {
      if (cap<cLen) {
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
    var c = whitelist[addr];
    var d = distribution[tokenAddr];
    // for (uint i=c.tokensClaimed[tokenAddr]; i<len2; i++) {
    //   uint z = _applyPct(c.balance,d.pct[i]);
    //   tokenAmount = tokenAmount+(z);
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
  

   
   
   
   
  function submitPool (uint amountInWei) public onlyOwner {
    require(!locked);
    locked = true;
    require (contractStage < 3);
    require (contributionMin <= amountInWei && amountInWei <= tthisBal);
    finalBalance = tthisBal;
    bool s = receiverAddress.call.value(amountInWei).gas(msg.gas-(5000))();
    require (s == true);
    // ethRefundAmount.push(tthisBal);
    contractStage = 3;
    locked = false;
  }
  
   
   
   
   address constant zero = address(0);
   uint dTBal;
  //  d.token.balanceOf(this)
  function enableTokenWithdrawals (address tokenAddr, bool notDefault) public onlyOwner {
    require(!locked);
    locked = true;
    require (contractStage == 3);
    if (notDefault == true) {
      require (activeToken != zero);
    } else {
      activeToken = tokenAddr;
    }
    var d = distribution[tokenAddr];    
    if (len2==0) d.token = ERC20(tokenAddr);
    uint amount = dTBal-(d.balanceRemaining);
    require (amount > 0);
    if (feePct > 0) {
      uint ll = _applyPct(amount,feePct);
      bool s1 = d.token.transfer(owner,ll);
      require (s1 == true);
    }
    amount = dTBal-(d.balanceRemaining);
    d.balanceRemaining = dTBal;
    locked = false;
    // d.pct.push(_toPct(amount,finalBalance));
  }
  
   
  // function tokenFallback (address from, uint value, bytes data) public {
  //   ERC223Received (from, value);
  // }
  
}