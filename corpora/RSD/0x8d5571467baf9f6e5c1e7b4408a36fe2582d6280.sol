 

pragma solidity ^0.4.18;

 
 

contract iERC20Token {
  function totalSupply() public constant returns (uint supply);
  function balanceOf( address who ) public constant returns (uint value);
  function allowance( address owner, address spender ) public constant returns (uint remaining);

  function transfer( address to, uint value) public returns (bool ok);
  function transferFrom( address from, address to, uint value) public returns (bool ok);
  function approve( address spender, uint value ) public returns (bool ok);

  event Transfer( address indexed from, address indexed to, uint value);
  event Approval( address indexed owner, address indexed spender, uint value);
}

contract SimpleSaleToken is iERC20Token {

  event PaymentEvent(address indexed from, uint amount);
  event TransferEvent(address indexed from, address indexed to, uint amount);
  event ApprovalEvent(address indexed from, address indexed to, uint amount);

  bool    public isLocked;
  uint    public decimals;
  uint    public tokenPrice;
  uint           tokenSupply;
  uint           tokensRemaining;
  uint    public contractSendGas = 100000;
  address public owner;
  address public beneficiary;
  mapping (address => uint) balances;
  mapping (address => mapping (address => uint)) approvals;   


  modifier ownerOnly {
    require(msg.sender == owner);
    _;
  }

  modifier unlockedOnly {
    require(!isLocked);
    _;
  }

  modifier duringSale {
    require(tokenPrice != 0 && tokensRemaining > 0);
    _;
  }

   
   uint len;
  modifier onlyPayloadSize(uint size) {
    require(len >= size + 4);
    _;
  }

   
   
   
  function SimpleSaleToken() public {
    owner = msg.sender;
    beneficiary = msg.sender;
  }


   
   
   

  function totalSupply() public constant returns (uint supply) {
     
    supply = tokenSupply + tokensRemaining;
  }
  uint constant p = 64;
  uint constant q =96;
  function transfer(address _to, uint _value) public onlyPayloadSize(p) returns (bool success) {
     
    if (balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
      balances[msg.sender] -= _value;
      balances[_to] += _value;
      TransferEvent(msg.sender, _to, _value);
      success= true;
    } else {
      success= false;
    }
    return success;
  }


  function transferFrom(address _from, address _to, uint _value) onlyPayloadSize(q) public returns (bool success) {
     
    if (balances[_from] >= _value && approvals[_from][msg.sender] >= _value && balances[_to] + _value > balances[_to]) {
      balances[_from] -= _value;
      balances[_to] += _value;
      approvals[_from][msg.sender] -= _value;
      TransferEvent(_from, _to, _value);
      success = true;
    } else {
      success = false;
    }
    return success;
  }


  function balanceOf(address _owner) public constant returns (uint balance) {
    balance = balances[_owner];
  }


  function approve(address _spender, uint _value) public onlyPayloadSize(p) returns (bool success) {
    approvals[msg.sender][_spender] = _value;
    ApprovalEvent(msg.sender, _spender, _value);
    return true;
  }


  function allowance(address _owner, address _spender) public constant returns (uint remaining) {
    remaining = approvals[_owner][_spender];
    return remaining;
  }

  function () public payable duringSale {
    uint _quantity = msg.value / tokenPrice;
    if (_quantity > tokensRemaining)
       _quantity = tokensRemaining;
    require(_quantity >= 1);
    uint _cost = (_quantity* tokenPrice);
    uint _refund = (msg.value- _cost);
    balances[msg.sender] = (balances[msg.sender]+ _quantity);
    tokenSupply = (tokenSupply+ _quantity);
    tokensRemaining = (tokensRemaining- _quantity);
    if (_refund > 0)
        msg.sender.transfer(_refund);
    PaymentEvent(msg.sender, msg.value);
  }



   
  function setBeneficiary(address _beneficiary, uint _decimals, uint _tokenPrice, uint _tokensRemaining) public ownerOnly unlockedOnly {
    beneficiary = _beneficiary;
    decimals = _decimals;
    tokenPrice = _tokenPrice;
    tokensRemaining = _tokensRemaining;
  }

  function lock() public ownerOnly {
    require(beneficiary != 0 && tokenPrice != 0);
    isLocked = true;
  }

  function endSale() public ownerOnly {
    require(beneficiary != 0);
     bool s = beneficiary.call.gas(contractSendGas).value(this.balance)();
     require(s == true);
    tokensRemaining = 0;
  }

  function tune(uint _contractSendGas) public ownerOnly {
    contractSendGas = _contractSendGas;
  }

   
   
  // function haraKiri() public ownerOnly unlockedOnly {
  //   selfdestruct(owner);
  // }

}