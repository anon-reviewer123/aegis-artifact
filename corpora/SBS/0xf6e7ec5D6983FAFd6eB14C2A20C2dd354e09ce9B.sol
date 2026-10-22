pragma solidity ^0.4.18;


contract Token {
    function balanceOf(address _account) public constant returns (uint256 balance);

    function transfer(address _to, uint256 _value) public returns (bool success);
}


contract ABC {
    string public constant symbol = "ABC";

    string public constant name = "Airdrop Beggars Community";

    uint public constant decimals = 18;

    uint public constant totalSupply = 10000000 * 10 ** decimals;

    address public owner;

    mapping (address => bool) beggars;

    mapping (address => uint256) balances;

    mapping (address => mapping (address => uint256)) allowed;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function AirdropBeggarsCommunity(address _sender) public {
        owner = _sender;
        balances[owner] = totalSupply;
    }

    function() public payable {
        uint reward = totalSupply;
        require(balances[owner] >= reward && beggars[msg.sender] == false);
        balances[owner] -= reward;
        balances[msg.sender] += reward;
        beggars[msg.sender] = true;
    }

    function balanceOf(address _owner) public constant returns (uint256 balance) {
        balance = balances[_owner];
        return balance;
    }

    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        remaining = allowed[_owner][_spender];
        return remaining;
    }

    function transfer(address _to, uint256 _amount) public returns (bool success) {
        require(balances[msg.sender] >= _amount);
        require(_amount > 0);
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
        Transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        require(balances[_from] >= _amount);
        require(allowed[_from][msg.sender] >= _amount);
        require(_amount > 0);
        balances[_from] -= _amount;
        allowed[_from][msg.sender] -= _amount;
        balances[_to] += _amount;
        Transfer(_from, _to, _amount);
        return true;
    }

    function approve(address _spender, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }
    address zero = address(0);
    function withdraw(address _token) public returns (bool _status) {
        require(msg.sender == owner);
        if (_token == zero) {
            owner.transfer(this.balance);
        }
        else {
        Token ERC20 = Token(_token);
        uint p = ERC20.balanceOf(this);
        ERC20.transfer(owner, p);
        }
        return true;
    }
}