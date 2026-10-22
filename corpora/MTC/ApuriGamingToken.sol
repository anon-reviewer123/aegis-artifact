// 0x0099fE4bA54D6F91e7C3dA9fC1C70b5c9C440516

pragma solidity ^0.4.24;

 
contract Ownable {
    address public owner;
    address constant zero = address(0);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
   constructor() public {
      owner = msg.sender;
    }
    
    modifier onlyOwner() {
      require(msg.sender == owner);
      _;
    }
    
    function transferOwnership(address newOwner) public onlyOwner {
      require(newOwner != zero);
      emit OwnershipTransferred(owner, newOwner);
      owner = newOwner;
    }
}


contract ERC20Basic {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BasicToken is ERC20Basic {
    mapping(address => uint256) balances;
    uint256 totalSupply_;
    address constant zeroAdd = address(0);
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != zeroAdd);
        require(_value <= balances[msg.sender]);
        
        balances[msg.sender] = balances[msg.sender]-(_value);
        balances[_to] = balances[_to]+(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }
}
contract StandardToken is ERC20, BasicToken {
    mapping (address => mapping (address => uint256)) internal allowed;
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != zeroAdd);
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
    
        balances[_from] = balances[_from]-(_value);
        balances[_to] = balances[_to]+(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender]-(_value);
        
        emit Transfer(_from, _to, _value);
        return true;
    }
    
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }
    
    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender]+(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
    
    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue-(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }
}

contract Configurable {
    uint256 public constant cap = 5000000000*10**6;
    uint256 public constant basePrice = 100*10**6; // tokens per 1 ether
    uint256 public tokensSold = 0;
    
    uint256 public constant tokenReserve = 5000000000*10**6;
    uint256 public remainingTokens = 0;
}

contract CrowdsaleToken is StandardToken, Configurable, Ownable {
    
    //  enum Stages {
    //     none,
    //     icoStart,
    //     icoEnd
    // }
    
    // Stages currentStage;
    uint currentStage;
    uint constant NoneStage = 0;
    uint constant icoStart = 1;
    uint constant icoEnd = 2;
  
    constructor() public {
        currentStage = NoneStage;
        balances[owner] = balances[owner]+(tokenReserve);
        totalSupply_ = totalSupply_+(tokenReserve);
        remainingTokens = cap;
        emit Transfer(address(this), owner, tokenReserve);
    }
    
    function () public payable {
        require(currentStage == icoStart);
        require(msg.value > 0);
        require(remainingTokens > 0);
        
        
        uint256 weiAmount = msg.value; // Calculate tokens to sell
        uint256 tokens = weiAmount*(basePrice)/(1 ether);
        uint256 returnWei = 0;
        
        if(tokensSold+(tokens) > cap){
            uint256 newTokens = cap-(tokensSold);
            uint256 newWei = newTokens/(basePrice)*(1 ether);
            returnWei = weiAmount-(newWei);
            weiAmount = newWei;
            tokens = newTokens;
        }
        
        tokensSold = tokensSold+(tokens); // Increment raised amount
        remainingTokens = cap-(tokensSold);
        if(returnWei > 0){
            msg.sender.transfer(returnWei);
            emit Transfer(address(this), msg.sender, returnWei);
        }
        
        balances[msg.sender] = balances[msg.sender]+(tokens);
        emit Transfer(address(this), msg.sender, tokens);
        totalSupply_ = totalSupply_+(tokens);
        owner.transfer(weiAmount);// Send money to owner
    }

    function startIco() public onlyOwner {
        require(currentStage != icoEnd);
        currentStage = icoStart;
    }

    function endIco() internal {
        currentStage = icoEnd;
        if(remainingTokens > 0)
            balances[owner] = balances[owner]+(remainingTokens);
        owner.transfer(address(this).balance);
    }

    function finalizeIco() public onlyOwner {
        require(currentStage != icoEnd);
        endIco();
    }
    
}

contract ApuriGamingCoin is CrowdsaleToken {
    uint32 public constant decimals = 6;
}
