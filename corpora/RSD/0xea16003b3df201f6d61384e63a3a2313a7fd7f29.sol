 

pragma solidity 0.4.26;

 
 

contract ERC20 {
  function balanceOf(address _owner) constant returns (uint256 balance) {}
  function transfer(address _to, uint256 _value) returns (bool success) {}
}


contract WhiteList {
   function checkMemberLevel (address addr) view public returns (uint) {}
}


contract PresalePool {

   
  uint256 public contractStage = 1;
  
   
   
  address public owner;
   
  uint[] public contributionCaps;
   
  uint public feePct;
   
  address public receiverAddress;
  
   
   
  uint constant public contributionMin = 100000000000000000;
   
  uint constant public maxGasPrice = 50000000000;
   
  WhiteList constant public whitelistContract = WhiteList(0x8D95B038cA80A986425FA240C3C17Fb2B6e9bc63);
  
  
   
   
  uint public nextCapTime;
   
  uint [] public nextContributionCaps;
   
  uint public addressChangeBlock;
   
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
   
  mapping (address => TokenAllocation) distributionMap;
  
  
   
  modifier onlyOwner () {
    require (msg.sender == owner);
    _;
  }
  
   
  bool locked;
  
  
   
   
  event ContributorBalanceChanged (address contributor, uint totalBalance);
  event ReceiverAddressSet ( address _addr);
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
  
   
   
  function PresalePool(address receiverAddr, uint[] capAmounts, uint fee) public {
    require (fee < 100);
    require (capAmounts.length>1 && capAmounts.length<256);
    for (uint256 i=1; i<capAmounts.length; i++) {
      require (capAmounts[i] <= capAmounts[0]);
    }
    owner = msg.sender;
    receiverAddress = receiverAddr;
    contributionCaps = capAmounts;
    feePct = _toPct(fee,100);
    whitelist[msg.sender].authorized = true;
  }
  
   
   
   
  function () payable public {
    if (contractStage == 1) {
      _ethDeposit();
    } else if (contractStage == 3) {
      _ethRefund();
    } else require(true == false);
  }
  
   
  function _ethDeposit () internal {
    assert (contractStage == 1);
    require (tx.gasprice <= maxGasPrice);
    require (tthisBal <= contributionCaps[0]);
    uint newBalance = whitelist[msg.sender].balance+(msg.value);
    require (newBalance >= contributionMin);
    uint x = _checkCap(msg.sender);
    require (newBalance <= x);
    whitelist[msg.sender].balance = newBalance;
    ContributorBalanceChanged(msg.sender, newBalance);
  }
  
   
  function _ethRefund () internal {
    require (contractStage == 3);
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
    require (contractStage == 3);
    // var c = whitelist[receiver];
    if (tokenAddr == zero) {
      tokenAddr = activeToken;
    }
    // var d = distributionMap[tokenAddr];
    require ( (ethRefundAmount.length > whitelist[receiver].ethRefund) || len > whitelist[receiver].tokensClaimed[tokenAddr] );
    if (ethRefundAmount.length > whitelist[receiver].ethRefund) {
      uint pct = _toPct(whitelist[receiver].balance,finalBalance);
      uint ethAmount = 0;
      for (uint i=whitelist[receiver].ethRefund; i<ethRefundAmount.length; i++) {
        uint z = _applyPct(ethRefundAmount[i],pct);
        ethAmount = ethAmount+(z);
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
        uint a = _applyPct(whitelist[receiver].balance,distributionMap[tokenAddr].pct[i]);
        tokenAmount = tokenAmount+(a);
      }
      whitelist[receiver].tokensClaimed[tokenAddr] = len;
      if (tokenAmount > 0) {
        bool s = distributionMap[tokenAddr].token.transfer(receiver,tokenAmount);
        require(s == true);
        distributionMap[tokenAddr].balanceRemaining = distributionMap[tokenAddr].balanceRemaining-(tokenAmount);
        TokensWithdrawn(receiver,tokenAmount);
      }  
    }
    
  }
  
   
   
   
  function authorize (address addr, uint cap) public onlyOwner {
    require (contractStage == 1);
    _checkWhitelistContract(addr);
    require (!whitelist[addr].authorized);
    require ((cap > 0 && cap < contributionCaps.length) || (cap >= contributionMin && cap <= contributionCaps[0]) );
    uint size;
    assembly { size := extcodesize(addr) }
    require (size == 0);
    whitelist[addr].cap = cap;
    whitelist[addr].authorized = true;
  }
  
   
   
  function authorizeMany (address[] addr, uint cap) public onlyOwner {
    require (addr.length < 255);
    require (cap > 0 && cap < contributionCaps.length);
    for (uint256 i=0; i<addr.length; i++) {
      authorize(addr[i], cap);
    }
  }
  
   
   
   
  function revoke (address addr) public onlyOwner {
    require (contractStage < 3);
    require (whitelist[addr].authorized == true);
    uint a = whitelistContract.checkMemberLevel(addr);
    require (a == 0);
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
    // var c = whitelist[addr];
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
  
   
   uint tthisBal;
  function modifyLevelCap (uint level, uint cap) public onlyOwner {
    require (contractStage < 3);
    require (level > 0 && level < contributionCaps.length);
    require (tthisBal <= cap && contributionCaps[0] >= cap);
    contributionCaps[level] = cap;
    nextCapTime = 0;
  }
  
   
   
  function modifyAllLevelCaps (uint[] cap, uint time) public onlyOwner {
    require (contractStage < 3);
    require (cap.length == contributionCaps.length-1);
    require (time == 0 || time>block.timestamp);
    if (time == 0) {
      for (uint256 i = 0; i < cap.length; i++) {
        uint p = i+1;
        modifyLevelCap(p, cap[i]);
      }
    } else {
      nextContributionCaps = contributionCaps;
      nextCapTime = time;
      for (i = 0; i < cap.length; i++) {
        require (contributionCaps[i+1] <= cap[i] && contributionCaps[0] >= cap[i]);
        nextContributionCaps[i+1] = cap[i];
      }
    }
  }
  
   
   
  function modifyMaxContractBalance (uint amount) public onlyOwner {
    require (contractStage < 3);
    require (amount >= contributionMin);
    require (amount >= tthisBal);
    contributionCaps[0] = amount;
    nextCapTime = 0;
    for (uint256 i=1; i<contributionCaps.length; i++) {
      if (contributionCaps[i]>amount) contributionCaps[i]=amount;
    }
  }
  
   
  function _checkCap (address addr) internal returns (uint p) {
    _checkWhitelistContract(addr);
    var c = whitelist[addr];
    if (!whitelist[addr].authorized) p = 0;
    if (nextCapTime>0 && block.timestamp>nextCapTime) {
      contributionCaps = nextContributionCaps;
      nextCapTime = 0;
    }
    if (whitelist[addr].cap<contributionCaps.length) p = contributionCaps[whitelist[addr].cap];
    p = whitelist[addr].cap; 
    return p;
  }
  
   
  function _checkWhitelistContract (address addr) internal {
    // var c = whitelist[addr];
    if (!whitelist[addr].authorized) {
      var level = whitelistContract.checkMemberLevel(addr);
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
    // var c = whitelist[addr];
    if (!whitelist[addr].authorized) {
      cap = whitelistContract.checkMemberLevel(addr);
      if (cap == 0) { balance = 0;cap =0;remaining=0;}
    } else {
      cap = whitelist[addr].cap;
    }
    balance = whitelist[addr].balance;
    if (contractStage == 1) {
      if (cap<contributionCaps.length) { 
        if (nextCapTime == 0 || nextCapTime > block.timestamp) {
          cap = contributionCaps[cap];
        } else {
          cap = nextContributionCaps[cap];
        }
      }
      remaining = cap-(balance);
      if (contributionCaps[0]-(tthisBal) < remaining) remaining = contributionCaps[0]-(tthisBal);
    } else {
      remaining = 0;
    }
    return (balance, cap, remaining);
  }
  
   
  function checkAvailableTokens (address addr, address tokenAddr) view public returns (uint tokenAmount) {
    // var c = whitelist[addr];
    // var d = distributionMap[tokenAddr];
    for (uint i = whitelist[addr].tokensClaimed[tokenAddr]; i < len; i++) {
        uint k = _applyPct(whitelist[addr].balance, distributionMap[tokenAddr].pct[i]);
      tokenAmount = tokenAmount+(k);
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
  
   
   
   
   
   
  function setReceiverAddress (address addr) public onlyOwner {
    require (addr != zero && receiverAddress == zero);
    require (contractStage < 3);
    receiverAddress = addr;
    addressChangeBlock = block.number;
    ReceiverAddressSet(addr);
  }

   
   
   address zero;
   
  function submitPool (uint amountInWei) public onlyOwner {
    require(!locked);
    locked = true;
    require (contractStage < 3);
    require (receiverAddress != zero);
    require (block.number >= addressChangeBlock+(6000));
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
    require(!locked);
    locked = true;
    require (contractStage == 3);
    if (notDefault == true) {
      require (activeToken != zero);
    } else {
      activeToken = tokenAddr;
    }
    // var d = distributionMap[tokenAddr];    
    if (len==0) distributionMap[tokenAddr].token = ERC20(tokenAddr);
    uint l1 = distributionMap[tokenAddr].token.balanceOf(this);
    uint amount = l1-(distributionMap[tokenAddr].balanceRemaining);
    require (amount > 0);
    if (feePct > 0) {
      uint a = _applyPct(amount,feePct);
        bool s = distributionMap[tokenAddr].token.transfer(owner,a);
      require (s == true);
    }
    uint a1 = distributionMap[tokenAddr].token.balanceOf(this);
    amount = a1-(distributionMap[tokenAddr].balanceRemaining);
    distributionMap[tokenAddr].balanceRemaining = a;
    uint k = _toPct(amount,finalBalance);
    distributionMap[tokenAddr].pct.push(k);
    locked = false;
  }
  
   
  function tokenFallback (address from, uint value, bytes data) public {
    ERC223Received (from, value);
  }
  
}