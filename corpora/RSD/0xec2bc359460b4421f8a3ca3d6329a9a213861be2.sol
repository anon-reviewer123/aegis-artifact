 

pragma solidity ^0.4.19;


contract ERC20Basic {
    uint256 public totalSupply;

    function balanceOf(address who) constant public returns (uint256 a);

    function transfer(address to, uint256 value) public returns (bool b);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) constant public returns (uint256 d);

    function transferFrom(address from, address to, uint256 value) public returns (bool e);

    function approve(address spender, uint256 value) public returns (bool f);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Owned {

    address public owner;

    address public newOwner;

    function Owned() public payable {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }

    function changeOwner(address _owner) onlyOwner public {
        require(_owner != 0);
        newOwner = _owner;
    }

    function confirmOwner() public {
        require(newOwner == msg.sender);
        owner = newOwner;
        delete newOwner;
    }
}

contract Blocked {

    uint public blockedUntil;

    modifier unblocked {
        require(now > blockedUntil);
        _;
    }
}

contract BasicToken is ERC20Basic, Blocked {

    mapping (address => uint256) balances;

     uint len;
    modifier onlyPayloadSize(uint size) {
        require(len >= size + 4);
        _;
        require(len >= size + 8);
    }
    uint constant p = 64;
    function transfer(address _to, uint256 _value) onlyPayloadSize(p) unblocked public returns (bool p1) {
        balances[msg.sender] = balances[msg.sender]-(_value);
        balances[_to] = balances[_to]+(_value);
        Transfer(msg.sender, _to, _value);
        p1 = true;
        return p1;
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        balance = balances[_owner];
        return balance;
    }

}

contract StandardToken is ERC20, BasicToken {

    mapping (address => mapping (address => uint256)) allowed;

    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(q) unblocked public returns (bool k) {
        uint256 _allowance = allowed[_from][msg.sender];

        balances[_to] = balances[_to]+(_value);
        balances[_from] = balances[_from]-(_value);
        allowed[_from][msg.sender] = _allowance-(_value);
        Transfer(_from, _to, _value);
        k = true;
        return k;
    }

    function approve(address _spender, uint256 _value) onlyPayloadSize(p) unblocked public returns (bool p1) {

        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        p1 = true;
        return p1;
    }
    uint constant p = 64;
    uint constant q = 96;
    function allowance(address _owner, address _spender) onlyPayloadSize(p) unblocked constant public returns (uint256 remaining) {
        remaining = allowed[_owner][_spender];
        return remaining;
    }

}

contract BurnableToken is StandardToken {

    event Burn(address indexed burner, uint256 value);

    function burn(uint256 _value) unblocked public {
        require(_value > 0);
        require(_value <= balances[msg.sender]);
         
         

        address burner = msg.sender;
        balances[burner] = balances[burner]-(_value);
        totalSupply = totalSupply-(_value);
        Burn(burner, _value);
    }
}

contract DEVCoin is BurnableToken, Owned {

    
    uint32 public constant decimals = 18;

    function DEVCoin(uint256 initialSupply, uint unblockTime) public {
        totalSupply = initialSupply;
        balances[owner] = initialSupply;
        blockedUntil = unblockTime;
    }

    function manualTransfer(address _to, uint256 _value) onlyPayloadSize(p) onlyOwner public returns (bool l) {
        balances[msg.sender] = balances[msg.sender]-(_value);
        balances[_to] = balances[_to]+(_value);
        Transfer(msg.sender, _to, _value);
        l = true;
        return l;
    }
}

contract ManualSendingCrowdsale is Owned {
    struct AmountData {
        bool exists;
        uint256 value;
    }

    mapping (uint => AmountData) public amountsByCurrency;

    function addCurrency(uint currency) external onlyOwner {
        addCurrencyInternal(currency);
    }

    function addCurrencyInternal(uint currency) internal {
        AmountData storage amountData = amountsByCurrency[currency];
        amountData.exists = true;
    }

    function manualTransferTokensToInternal(address to, uint256 givenTokens, uint currency, uint256 amount) internal returns (uint256 p) {
        AmountData memory tempAmountData = amountsByCurrency[currency];
        require(tempAmountData.exists == true);
        AmountData storage amountData = amountsByCurrency[currency];
        amountData.value = amountData.value+(amount);
        p = transferTokensTo(to, givenTokens);
        return p;
    }

    function transferTokensTo(address to, uint256 givenTokens) internal returns (uint256 l);
}

contract Crowdsale is ManualSendingCrowdsale {

    // enum State { PRE_ICO, ICO }

    uint State;

    uint StatePRE_ICO = 0;
    uint StateICO = 1;

    uint public state = StatePRE_ICO;

     
    uint public constant preICOstartTime =    1522454400;  
    uint public constant preICOendTime =      1523750400;  
    uint public constant ICOstartTime =    1524355200;  
    uint public constant ICOendTime =      1527033600;  

    uint public constant bountyAvailabilityTime = 1527033600 + 90 days;

    uint256 public constant maxTokenAmount = 108e24;  
    uint256 public constant bountyTokens =   324e23;  

    uint256 public constant maxPreICOTokenAmount = 81e23;  

    DEVCoin public token;

    uint256 public leftTokens = 0;

    uint256 public totalAmount = 0;
    uint public transactionCounter = 0;

     
     

     
    uint private firstAmountBonus = 20;
    uint256 private firstAmountBonusBarrier = 500 ether;
    uint private secondAmountBonus = 15;
    uint256 private secondAmountBonusBarrier = 100 ether;
    uint private thirdAmountBonus = 10;
    uint256 private thirdAmountBonusBarrier = 50 ether;
    uint private fourthAmountBonus = 5;
    uint256 private fourthAmountBonusBarrier = 20 ether;

     
    uint private firstPreICOTimeBarrier = 1522454400 + 1 days;
    uint private firstPreICOTimeBonus = 20;
    uint private secondPreICOTimeBarrier = 1522454400 + 7 days;
    uint private secondPreICOTimeBonus = 10;
    uint private thirdPreICOTimeBarrier = 1522454400 + 14 days;
    uint private thirdPreICOTimeBonus = 5;

     
    uint private firstICOTimeBarrier = 1524355200 + 1 days;
    uint private firstICOTimeBonus = 15;
    uint private secondICOTimeBarrier = 1524355200 + 7 days;
    uint private secondICOTimeBonus = 7;
    uint private thirdICOTimeBarrier = 1524355200 + 14 days;
    uint private thirdICOTimeBonus = 4;

     

    bool public bonusesPayed = false;

    uint256 public constant rateToEther = 9000;  

    uint256 public constant minAmountForDeal = 10**17;

    modifier canBuy() {
        bool s = isFinished();
        require(!s);
        bool l = isPreICO();
        bool l1 = isICO();
        require( l == true || l1 == true);
        _;
    }

    modifier minPayment() {
        require(msg.value >= 10**17);
        _;
    }

    function Crowdsale() public {
         
        token = new DEVCoin(108e24, 1527033600);
        leftTokens = 81e23;
        uint a = 0;
        addCurrencyInternal(a);  
    }

    function isFinished() public constant returns (bool p) {
        if( (leftTokens == 0 && state == StateICO)||now > 1527033600)
        {
            p = true;
        }
        else
        {
            p = false;
        }
    }

    function isPreICO() public constant returns (bool p ) {
        uint curTime = now;
        if( curTime < 1523750400 && curTime > 1522454400)
        {
            p = true;
        }
        else
        {
            p = false;
        }
        return p;
    }

    function isICO() public constant returns (bool p) {
        uint curTime = now;
        if( curTime < 1527033600 && curTime > 1524355200)
        {
            p = true;
        }
        else
        {
            p = false;
        }
        return p;
    }

    function() external canBuy minPayment payable {
        uint256 amount = msg.value;
        uint bonus = getBonus(amount);
        uint256 givenTokens = amount*(90)/(100 + bonus);
        uint256 providedTokens = transferTokensTo(msg.sender, givenTokens);

        if (givenTokens > providedTokens) 
        {
            uint256 needAmount = providedTokens/(100 + bonus)/(90);
            require(amount > needAmount);
            bool s = msg.sender.call.gas(3000000).value(amount - needAmount)();
            require(s == true);
            amount = needAmount;
        }
        totalAmount = totalAmount+(amount);
    }

    function manualTransferTokensToWithBonus(address to, uint256 givenTokens, uint currency, uint256 amount) external canBuy onlyOwner returns (uint256 p) {
        uint a = 0;
        uint bonus = getBonus(a);
        uint256 transferedTokens = givenTokens*(100 + bonus)/(100);
        p = manualTransferTokensToInternal(to, transferedTokens, currency, amount);
        return p;
    }

    function manualTransferTokensTo(address to, uint256 givenTokens, uint currency, uint256 amount) external onlyOwner canBuy returns (uint256 p) {
        p = manualTransferTokensToInternal(to, givenTokens, currency, amount);
        return p;
    }

    function getBonus(uint256 amount) public constant returns (uint l) {
        uint bonus = 0;
        bool s = isPreICO();
        if (s == true) {
            bonus = getPreICOBonus();
        }
        bool s1 = isICO();
        if (s1 == true) {
            bonus = getICOBonus();
        }
        uint x = getAmountBonus(amount);
        l = x+bonus;
        return l ;
    }

    function getAmountBonus(uint256 amount) public constant returns (uint p) {
        if (amount >= 500 ether) {
            p = 20;
        }
        else if (amount >= 100 ether) {
            p = 15;
        }
        else if (amount >= 50 ether) {
            p = 10;
        }
        else if (amount >= 20 ether) {
            p = 5;
        }
        else{
        p = 0;
        }
        return p;
    }

    function getPreICOBonus() public constant returns (uint p) {
        if (now < 1522454400 + 1 days) {
            p = 20;
        }
        else if (now < 1522454400 + 7 days) {
            p = 10;
        }
        else if (now < 1522454400 + 14 days) {
            p = 5;
        }
        else
        {
            p = 0;
        }
        return p;
    }

    function getICOBonus() public constant returns (uint p) {
        if (now < 1524355200 + 1 days) {
            p = 15;
        }
        else if (now < 1524355200 + 7 days) {
            p = 7;
        }
        else if (now < 1524355200 + 14 days) {
            p = 4;
        }
        else
        {
            p = 0;
        }
        return p;
    }

    function finishCrowdsale() external {
        bool s1 = isFinished();
        require(s1 == true);
        require(state == StateICO);
        if (leftTokens > 0) {
            token.burn(leftTokens);
            leftTokens = 0;
        }
    }

    function takeBounty() external onlyOwner {
        bool s1 = isFinished();
        require(s1 == true);
        require(state == StateICO);
        require(now > 1527033600 + 90 days);
        require(!bonusesPayed);
        bonusesPayed = true;
        bool s = token.transfer(msg.sender, 324e23);
        require(s == true);
    }

    function startICO() external {
        require(now > 1523750400);
        require(state == StatePRE_ICO && leftTokens <= 81e23);
        leftTokens = leftTokens+(108e24)-(81e23)-(324e23);
        state = StateICO;
    }

    function transferTokensTo(address to, uint256 givenTokens) internal returns (uint256 providedTokens) {
        providedTokens = givenTokens;
        if (givenTokens > leftTokens) {
            providedTokens = leftTokens;
        }
        leftTokens = leftTokens-(providedTokens);
        bool s = token.manualTransfer(to, providedTokens);
        require(s == true);
        transactionCounter = transactionCounter + 1;
        return providedTokens;
    }
    uint bal;
    function withdraw() external onlyOwner {
        bool s = msg.sender.call.gas(3000000).value(bal)();
        require(s == true);
    }
    
    function withdrawAmount(uint256 amount) external onlyOwner {
        uint256 givenAmount = amount;
        if (bal < amount) {
            givenAmount = bal;
        }
        bool s = msg.sender.call.gas(3000000).value(givenAmount)();
        require(s == true);
    }

}