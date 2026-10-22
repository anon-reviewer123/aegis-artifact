 

pragma solidity 0.4.25;



contract ERC20 {
  function balanceOf(address _owner) public returns (uint256 balance) {}
  function transfer(address _to, uint256 _value) public returns (bool success) {}
}

contract PresalePool {

   
  
   
   
   
   
   
  uint8 public contractStage = 1;
  
   
   
  address public owner;
   
  uint public contributionMin;
   
  uint public contractMax;
   
  uint public feePct;
   
  address public receiverAddress;
  
   
   
  uint public submittedAmount;
   
  uint public refundPct;
   
  uint public contributorCount;
   
  address public activeToken;
  
   
  struct Contributor {
    bool refundedEth;
    uint balance;
    mapping (address => uint) tokensClaimed;
  }
   
  mapping (address => Contributor) contributors;
  
   
  struct TokenAllocation {
    ERC20 token;
    uint pct;
    uint claimRound;
    uint claimCount;
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
  event ReceiverAddressChanged ( address _addr);
  event WithdrawalsOpen (address tokenAddr);
  event ERC223Received (address token, uint value);
   
   
   
  function _toPct (uint numerator, uint denominator ) internal pure returns (uint p) {
    p = numerator*(10 ** 20) / denominator;
    return p;
  }
  
   
  function _applyPct (uint numerator, uint pct) internal pure returns (uint p) {
    p = numerator*(pct) / (10 ** 20);
    return p;
  }
  
   
  constructor(address receiver, uint individualMin, uint poolMax, uint fee) public {
    require (fee < 100);
    // require (100000000000000000 <= individualMin);
    require (10000 <= individualMin);
    require (individualMin <= poolMax);
    require (receiver != zero);
    owner = msg.sender;
    receiverAddress = receiver;
    contributionMin = individualMin;
    contractMax = poolMax;
    uint a = 100;
    feePct = _toPct(fee,a);
  }
  
   
   
  function () payable external {
    require (contractStage == 1);
    require (tthisBal <= contractMax);
   //  var c = contributors[msg.sender];
    uint newBalance = contributors[msg.sender].balance+(msg.value);
    require (newBalance >= contributionMin);
    if (contributors[msg.sender].balance == 0) {
      contributorCount = contributorCount+(1);
    }
    contributors[msg.sender].balance = newBalance;
    // ContributorBalanceChanged(msg.sender, newBalance);
  }
    
   
   
   
   
   
  function withdraw (address tokenAddr) public {
   //  var c = contributors[msg.sender];
    require (contributors[msg.sender].balance > 0);
    if (contractStage < 3) {
      uint amountToTransfer = contributors[msg.sender].balance;
      contributors[msg.sender].balance = 0;
      msg.sender.transfer(amountToTransfer);
      contributorCount = contributorCount-(1);
      // ContributorBalanceChanged(msg.sender, 0);
    } else {
      _withdraw(msg.sender,tokenAddr);
    }  
  }
  
   
   
   
  function withdrawFor (address contributor, address tokenAddr) public onlyOwner {
    require (contractStage == 3);
    require (contributors[contributor].balance > 0);
    _withdraw(contributor,tokenAddr);
  }
  
   
   
  function _withdraw (address receiver, address tokenAddr) internal {
    require (contractStage == 3);
    // var c = contributors[receiver];
    if (tokenAddr == zero) {
      tokenAddr = activeToken;
    }
    // var d = distribution[tokenAddr];
    bool s10;
    if(refundPct > 0 && contributors[receiver].refundedEth == false)
    {
      s10 = true;
    }
    else
    {
      s10 = false;
    }
    require ( distribution[tokenAddr].claimRound > contributors[receiver].tokensClaimed[tokenAddr] ||s10 == true );
    if (refundPct > 0 && contributors[receiver].refundedEth == false) {
      uint ethAmount = _applyPct(contributors[receiver].balance,refundPct);
      contributors[receiver].refundedEth = true;
      if (ethAmount == 0) return;
      if (ethAmount+10 > contributors[receiver].balance) {
        ethAmount = contributors[receiver].balance-10;
      }
      contributors[receiver].balance = contributors[receiver].balance-(ethAmount+10);
      receiver.transfer(ethAmount);
      // EthRefunded(receiver,ethAmount);
    }
    if (distribution[tokenAddr].claimRound > contributors[receiver].tokensClaimed[tokenAddr]) {
      uint amount = _applyPct(contributors[receiver].balance,distribution[tokenAddr].pct);
      contributors[receiver].tokensClaimed[tokenAddr] = distribution[tokenAddr].claimRound;
      distribution[tokenAddr].claimCount = distribution[tokenAddr].claimCount+(1);
      if (amount > 0) {
        bool s = distribution[tokenAddr].token.transfer(receiver,amount);
        require (s == true);
      }
      // TokensWithdrawn(receiver,amount);
    }
  }
  
   
   
  function modifyMaxContractBalance (uint amount) public onlyOwner {
    require (contractStage < 3);
    require (amount >= contributionMin);
    require (amount >= tthisBal);
    contractMax = amount;
  }
  
   
  function checkPoolBalance () view public returns (uint poolCap, uint balance, uint remaining) {
    remaining = contractMax-(tthisBal);
    return (contractMax,tthisBal,remaining);
  }
  
   
  function checkContributorBalance (address addr) view public returns (uint balance) {
    balance = contributors[addr].balance;
    return balance;
  }
  
   
  function checkAvailableTokens (address addr, address tokenAddr) view public returns (uint amount) {
   //  var c = contributors[addr];
   //  var d = distribution[tokenAddr];
    if (distribution[tokenAddr].claimRound == contributors[addr].tokensClaimed[tokenAddr]) return 0;
    amount = _applyPct(contributors[addr].balance,distribution[tokenAddr].pct);
    return amount;
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
    uint b = tthisBal;
    bool s = receiverAddress.call.value(amountInWei)("");
    require (s == true);
    submittedAmount = b-(tthisBal);
    refundPct = _toPct(tthisBal,b);
    contractStage = 3;
    locked = false;
  }
  
   
   
   
   
   uint dTBal;
   address constant zero = address(0);
  function enableTokenWithdrawals (address tokenAddr, bool notDefault) public onlyOwner {
    require(!locked);
    locked = true;
    require (contractStage == 3);
    if (notDefault == true) {
      require (activeToken != zero);
    } else {
      activeToken = tokenAddr;
    }
   //  var d = distribution[tokenAddr];
    require (distribution[tokenAddr].claimRound == 0 || distribution[tokenAddr].claimCount == contributorCount);
    distribution[tokenAddr].token = ERC20(tokenAddr);
    uint amount = dTBal;
    require (amount > 0);
    if (feePct > 0) {
      uint ll = _applyPct(amount,feePct);
      bool s= distribution[tokenAddr].token.transfer(owner,ll);
      require (s == true);
    }
    distribution[tokenAddr].pct = _toPct(dTBal,submittedAmount);
    distribution[tokenAddr].claimCount = 0;
    distribution[tokenAddr].claimRound = distribution[tokenAddr].claimRound+(1);
    locked = false;
  }
  
  
}