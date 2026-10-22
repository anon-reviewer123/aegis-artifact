/**
 *Submitted for verification at Etherscan.io on 2017-09-03
 0x5CA9a71B1d01849C0a95490Cc00559717fCF0D1d
*/

pragma solidity ^0.4.24;

contract HumanStandardToken {

    uint8 public decimals;
    uint256 public totalSupply;

    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function () {
        //if ether is sent to this address, send it back.
        //require(true == false);
    }

    function HumanStandardToken(
        uint256 _initialAmount,
        uint8 _decimalUnits
        ) {
        balances[msg.sender] = _initialAmount;               // Give the creator all initial tokens
        totalSupply = _initialAmount;                        // Update total supply
        decimals = _decimalUnits;                            // Amount of decimals for display purposes
    }

    function transfer(address _to, uint256 _value) returns (bool success) {
                require(balances[msg.sender] >= _value);
        require(_value >= 0);
                balances[msg.sender] -= _value;
                balances[_to] += _value;
                Transfer(msg.sender, _to, _value);
                return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
                require(balances[_from] >= _value);
        require(allowed[_from][msg.sender] >= _value);
        require(_value >= 0);
                balances[_to] += _value;
                balances[_from] -= _value;
                allowed[_from][msg.sender] -= _value;
                Transfer(_from, _to, _value);
                return true;
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

  

    /* Approves and then calls the receiving contract */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);

        // call the receiveApproval function on the contract you want to be notified.
        // This crafts the function signature manually so one doesn't have to include
        // a contract in here just for this.
        // receiveApproval(address _from, uint256 _value, address _tokenContract, bytes _extraData)
        // it is assumed that when does this that the call *should* succeed, otherwise
        // one would use vanilla approve instead.
        bool s = _spender.call(bytes4(bytes32(sha3("receiveApproval(address,uint256,address,bytes)"))), msg.sender, _value, this, _extraData);
                require(s == true);
        return true;
    }
}

contract PrefilledToken is HumanStandardToken {

  bool public prefilled = false;
  address public creator = msg.sender;
  address constant zeroAddress = address(0);

  function prefill (address[] _addresses, uint[] _values)
  {
    require(prefilled == false);
    require(msg.sender == creator);
    uint total = totalSupply;

    for (uint i = 0; i < _addresses.length; i++) {
      address who = _addresses[i];
      uint val = _values[i];

      if (balances[who] != val) {
        total -= balances[who];

        balances[who] = val;
        total += val;
                Transfer(zeroAddress, who, val);
      }
    }

    totalSupply = total;
  }

  function launch ()
  {
    require(prefilled == false);
    require(msg.sender == creator);
    prefilled = true;
  }

  function transfer(address _to, uint256 _value) returns (bool success) {
        require(prefilled == true);
    require(balances[msg.sender] >= _value);
    require(_value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    // Transfer(msg.sender, _to, _value);
    return true;
  }
  

  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        require(prefilled == true);
    require(balances[_from] >= _value);
    require(allowed[_from][msg.sender] >= _value);
    require(_value >= 0);
    balances[_to] += _value;
    balances[_from] -= _value;
    allowed[_from][msg.sender] -= _value;
    Transfer(_from, _to, _value);
    return true;
  }

  function approve(address _spender, uint256 _value) returns (bool success) {
        require(prefilled == true);
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

}

contract AEToken is PrefilledToken {

  uint public transferableUntil;

  function AEToken() {
    uint nYears = 2;

    transferableUntil = now + (60 * 60 * 24 * 365 * nYears);
  }

  function transfer(address _to, uint256 _value) returns (bool success) {
    require(now <= transferableUntil);
    require(prefilled == true);
    require(balances[msg.sender] >= _value);
    require(_value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    Transfer(msg.sender, _to, _value);
    return true;
  }

  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
    require(now <= transferableUntil);
    require(prefilled == true);
    require(balances[_from] >= _value);
    require(allowed[_from][msg.sender] >= _value);
    require(_value >= 0);
    balances[_to] += _value;
    balances[_from] -= _value;
    allowed[_from][msg.sender] -= _value;
    Transfer(_from, _to, _value);
    return true;
  }
}
