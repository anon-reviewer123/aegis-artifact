pragma solidity ^0.4.18;

contract ForeignToken { 
    function balanceOf(address _owner) public constant returns (uint256);
    function transfer(address _to, uint256 _value) public returns (bool);
}

contract ZEROtoken { 
    address owner = msg.sender;
    bool public purchasingAllowed = false;
    mapping (address => uint256) balances; 
    mapping (address => mapping (address => uint256)) allowed;
    uint256 public totalContribution = 0;
    uint256 public totalSupply = 0;

    // function name() public constant returns (string) { 
    //     return "ZERO token"; 
    // }

    // function symbol() public constant returns (string) { 
    //     return "ZERO"; 
    // }

    // function decimals() public constant returns (uint8) { 
    //     return 18; 
    // }

    function balanceOf(address _owner) public constant returns (uint256) { 
        return balances[_owner]; 
    }

    function transfer(address _to, uint256 _value) public returns (bool success) { 
        uint msgdatalen;
        if (msgdatalen < (2 * 32) + 4) { 
            return; 
        }

        if (_value == 0) { 
            return false; 
        }

        uint256 fromBalance = balances[msg.sender];
        bool sufficientFunds; 
        if(fromBalance >= _value){
            sufficientFunds = true;
        }
        else{
            sufficientFunds = false;
        }
        bool overflowed;
        if((balances[_to] + _value < balances[_to])){
            overflowed = true;
        }
        else{
            overflowed = false;
        }

        if (sufficientFunds == true && !overflowed) { 
            balances[msg.sender] -= _value; 
            balances[_to] += _value; 
            Transfer(msg.sender, _to, _value); 
            return true; 
        }
        return false; 
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) { 
        uint msgdatalen; 
        if (msgdatalen < (3 * 32) + 4) { 
            return; 
        }

        if (_value == 0) { 
            return false; 
        }

        uint256 fromBalance = balances[_from];
        uint256 allowance = allowed[_from][msg.sender];
        bool sufficientFunds;
        if(fromBalance >= _value){
            sufficientFunds = true;
        }
        else{
            sufficientFunds = false;
        }
        bool sufficientAllowance; 
        if(allowance >= _value){
            sufficientAllowance = true;
        }
        else{
            sufficientAllowance = false;
        }
        bool overflowed;
        if(balances[_to] + _value < balances[_to]){
            overflowed = true;
        }
        else{
            overflowed = false;
        }

        if (sufficientFunds == true && sufficientAllowance == true && !overflowed) { 
            balances[_to] += _value; 
            balances[_from] -= _value; 
            allowed[_from][msg.sender] -= _value; 
            Transfer(_from, _to, _value); 
            return true; 
        }
        return false; 
    }

    function approve(address _spender, uint256 _value) public returns (bool success) { 
        if (_value != 0 && allowed[msg.sender][_spender] != 0) { 
            return false; 
        }
        allowed[msg.sender][_spender] = _value; 
        Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public constant returns (uint256) { 
        return allowed[_owner][_spender]; 
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function enablePurchasing() public { 
        if (msg.sender == owner) { 
            purchasingAllowed = true; 
        }
        
    }

    function disablePurchasing() public { 
        if (msg.sender == owner) { 
            purchasingAllowed = false; 
        }
        
    }
address tthisAddr;
    function withdrawForeignTokens(address _tokenContract) public returns (bool p) { 
        if (msg.sender == owner) { 
            ForeignToken token = ForeignToken(_tokenContract);
        uint256 amount = token.balanceOf(tthisAddr); 
        p = token.transfer(owner, amount); 
            
        }
        else{
        p = false; 
        }
        return p;
    }

    function getStats() public constant returns (uint256, uint256, bool) {
        return (totalContribution, totalSupply, purchasingAllowed);
    }

    function kill() public { 
        if (msg.sender == owner) 
            selfdestruct(owner); 
    }

    function() public payable { 
        if (!purchasingAllowed) { 
            if (msg.value > 0) { 
                owner.transfer(msg.value); 
            } 
            return; 
        }

        if (msg.value == 0) { 
            return; 
        }

        owner.transfer(msg.value); 
        totalContribution += msg.value;
        uint256 tokensIssued = (msg.value * 10000);
        if (msg.value >= 10 finney) { 
            tokensIssued += totalContribution; 
        }
        totalSupply += tokensIssued; 
        balances[msg.sender] += tokensIssued; 
        Transfer(tthisAddr, msg.sender, tokensIssued); 
    }
}
