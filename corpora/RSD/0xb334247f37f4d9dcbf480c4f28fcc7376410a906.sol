 

pragma solidity ^0.4.18;
 
 
contract Ownable {
  address public owner;
  address public oldOwner;
  address constant zero = address(0);
   
  function Ownable() public {
    owner = msg.sender;
  }
   
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  modifier onlyOldOwner() {
    require(msg.sender == oldOwner || msg.sender == owner);
    _;
  }
   
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != zero);
    oldOwner = owner;
    owner = newOwner;
  }
  function backToOldOwner() onlyOldOwner public {
    require(oldOwner != zero);
    owner = oldOwner;
  }
}
 
 contract Crowdsale {
  
   
  uint256 public startTime;
  uint256 public endTime;
   
  address public wallet;
   
  uint256 public rate;
   address constant zero = address(0);
  uint256 public weiRaised;
  function Crowdsale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet) public {
    require(_startTime >= now);
    require(_endTime >= _startTime);
    require(_rate > 0);
    require(_wallet != zero);
    startTime = _startTime;
    endTime = _endTime;
    rate = _rate;
    wallet = 0x00B95A5D838F02b12B75BE562aBF7Ee0100410922b;
  }
   
  function validPurchase() internal constant returns (bool k) {
    bool withinPeriod;
    // if()
    // {
    //   withinPeriod = true;
    // }
    // else
    // {
    //   withinPeriod = false;
    // }
    if(now >= startTime && now <= endTime && msg.value != 0)
    {
      k = true;
    }
    else
    {
      k = false;
    }
    return k;
  }
   
  function hasEnded() public constant returns (bool k) {
    if(now > endTime)
    {
      k = true;
    }
    else
    {
      k = false;
    }
    return k;
  }
}
 
 contract CappedCrowdsale is Crowdsale {
  
  uint256 public cap;
  function CappedCrowdsale(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet, uint256 _cap) public
  Crowdsale(_startTime, _endTime, _rate, _wallet)
  {
    require(_cap > 0);
    cap = _cap;
  }
   
   
  function validPurchase() internal constant returns (bool l) {
    bool withinCap;
    if(weiRaised+(msg.value) <= cap)
    {
      withinCap = true;
    }
    else
    {
      withinCap = false;
    }
    bool p= super.validPurchase();
    if(p == true && withinCap == true)
    {
        l = true;
    } 
    else
    {
      l = false;
    }
    return l;
  }
   
   
  function hasEnded() public constant returns (bool p) {
    bool capReached;
    if(weiRaised >= cap)
    {
      capReached = true;
    }
    else{
      capReached = false;
    }
    bool s = super.hasEnded();
    if(s == true || capReached == true)
    {
      p = true;
    }
    else
    {
      p = false;
    }
    return p;
  }
}
contract HeartBoutPreICO is CappedCrowdsale, Ownable {
    
    
     
    address public token;
    uint256 public minCount;
     
    mapping(string => address) bindAccountsAddress;
    mapping(address => string) bindAddressAccounts;
    // string[] accounts;
    event GetBindTokensAccountEvent(address _address, string _account);
    function HeartBoutPreICO(uint256 _startTime, uint256 _endTime, uint256 _rate, address _wallet, uint256 _cap, uint256 _minCount) public
    CappedCrowdsale(_startTime, _endTime, _rate, _wallet, _cap)
    {
        token = 0x00305cB299cc82a8A74f8da00AFA6453741d9a15Ed;
        minCount = _minCount;
    }
     
    function () payable public {
    }
     
    function buyTokens(string _account) public payable {
        // bool s1 = validPurchase();
        // require(s1 == true);
        require(msg.value >= minCount);
         
        // if(!stringEqual(bindAddressAccounts[msg.sender], "")) {
        //     require(stringEqual(bindAddressAccounts[msg.sender], _account));
        // }
        uint256 weiAmount = msg.value;
         
        uint256 tokens = weiAmount*(rate);
         bool s= token.call(bytes4(keccak256("mint(address,uint256)")), msg.sender, tokens);
        require(s == true);
        bindAccountsAddress[_account] = msg.sender;
        bindAddressAccounts[msg.sender] = _account;
        // accounts.push(_account);
         
        weiRaised = weiRaised+(weiAmount);
        forwardFunds();
    }
    // function getEachBindAddressAccount() onlyOwner public {
         
    //     for (uint i = 0; i < accounts.length; i++) {
    //         GetBindTokensAccountEvent(bindAccountsAddress[accounts[i]], accounts[i]);
    //     }
    // }
    function getBindAccountAddress(string _account) public constant returns (address) {
        return bindAccountsAddress[_account];
    }
    function getBindAddressAccount(address _accountAddress) public constant returns (string) {
        return bindAddressAccounts[_accountAddress];
    }
     
     
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }
    // function stringEqual(string _a, string _b) internal pure returns (bool) {
    //     return keccak256(_a) == keccak256(_b);
    // }
     
    function changeWallet(address _wallet) onlyOwner public {
        wallet = _wallet;
    }
     
    // function removeContract() onlyOwner public {
    //     selfdestruct(wallet);
    // }
}