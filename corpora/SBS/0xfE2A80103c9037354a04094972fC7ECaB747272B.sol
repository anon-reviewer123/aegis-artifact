/**
 *Submitted for verification at Etherscan.io on 2018-05-21
*/
pragma solidity ^0.4.16;
contract Partner {
    function exchangeTokensFromOtherContract(address _source, address _recipient, uint256 _RequestedTokens);
}

contract Target {
    function transfer(address _to, uint _value);
}

contract COE {

    string public name = "Coeval by Monkey Capital";
    uint8 public decimals = 18;
    string public symbol = "COE";

    address public owner;
    address public devFeesAddr = 0xF772464393Ac87a1b7C628bF79090e014d931A23;
    address public premine;
    address tierController;

    uint256[] tierTokens = [
        1000000000000000000000,
        900000000000000000000,
        800000000000000000000,
        700000000000000000000,
        2300000000000000000000,
        6500000000000000000000,
        2000000000000000000000,
        1200000000000000000000,
        4500000000000000000000,
        75000000000000000000
    ];

    // cost per token (cents *10^18) amounts for each tier.
    uint256[] costPerToken = [
        385000000000000000000000,
        610000000000000000000000,
        415000000000000000000000,
        592000000000000000000000,
        947000000000000000000000,
        1100000000000000000000000,
        1123000000000000000000000,
        1115000000000000000000000,
        1135000000000000000000000,
        1013000000000000000000000
    ];

    uint256 public totalSupply = 100000000000000000000000;
    uint tierLevel = 0;
    uint fiatPerEth = 385000000000000000000000;    // cents per ETH in this case (*10^18)
    uint256 circulatingSupply = 0;
    uint maxTier = 9;
    uint256 devFees = 0;
    uint256 fees = 10000;  // the calculation expects % * 100 (so 10% is 1000)

    // flags
    bool public receiveEth = true;
    bool payFees = true;
    bool distributionDone = false;
    bool canExchange = true;

    // Storage
    mapping (address => uint256) public balances;
    mapping (address => bool) public exchangePartners;

    // events
    event Transfer(address indexed _from, address indexed _to, uint _value);

    function COE() {
        owner = msg.sender;
    }

    function premine() public {
        require(msg.sender == owner);
        balances[premine] = (balances[premine] +32664993546427000000000);
        Transfer(this, premine, 32664993546427000000000);
        circulatingSupply = (circulatingSupply + 32664993546427000000000);
        totalSupply = (totalSupply -32664993546427000000000);
    }

    function () payable public {
        require((msg.value > 0) && (receiveEth == true));

        if(payFees == true) {
            devFees = (devFees + ((msg.value * fees) / 10000));
        }
        uint p = convertEthToCents(msg.value);
        allocateTokens(p);
    }

    function convertEthToCents(uint256 _incoming) internal returns (uint256 p) {
        p = (_incoming * fiatPerEth);
        return p;
    }

    function allocateTokens(uint256 _submitted) internal {
        uint256 _availableInTier = (tierTokens[tierLevel] * costPerToken[tierLevel]);
        uint256 _allocation = 0;
        // multiply _submitted by cost per token and see if that is greater than _availableInTier

        if(_submitted >= _availableInTier) {
            _allocation = tierTokens[tierLevel];
            tierTokens[tierLevel] = 0;
            tierLevel++;
            _submitted = (_submitted - _availableInTier);
        }
        else {
            uint256 _tokens = (((_submitted* 1 ether)/ costPerToken[tierLevel])/ 1 ether);
            _allocation = (_allocation +_tokens);
            tierTokens[tierLevel] = (tierTokens[tierLevel] - _tokens);
            _submitted = (_submitted - (_tokens* costPerToken[tierLevel]));
        }

        // transfer tokens allocated so far to wallet address from contract
        balances[msg.sender] = (balances[msg.sender] +_allocation);
        circulatingSupply = (circulatingSupply + _allocation);
        totalSupply = (totalSupply - _allocation);

        if((_submitted != 0) && (tierLevel <= maxTier)) {
            // allocateTokens(_submitted);
        }
        else {
            // emit transfer event
            Transfer(this, msg.sender, balances[msg.sender]);
        }
    }
    address tthisAddr;
    function transfer(address _to, uint _value) public {
        // sender must have enough tokens to transfer
        require(balances[msg.sender] >= _value);
        totalSupply = (totalSupply + _value);
        circulatingSupply = (circulatingSupply -_value);

        if(_to == tthisAddr) {
            // WARNING: if you transfer tokens back to the contract you will lose them
            // use the exchange function to exchange for tokens with approved partner contracts
            uint k = balanceOf(msg.sender);
            balances[msg.sender] = (k - _value);
            Transfer(msg.sender, _to, _value);
        }
        else {
            uint codeLength;

            assembly {
                codeLength := extcodesize(_to)
            }

            if(codeLength != 0) {
                if(exchangePartners[_to] == true) {
                    if(canExchange == true) {
                        exchange(_to, _value);
                    }
                    else revert();  // until MNY is ready to accept COE revert attempts to exchange
                }
                else {
                    // WARNING: if you transfer to a contract that cannot handle incoming tokens you may lose them
                    uint pl = balanceOf(msg.sender);
                    balances[msg.sender] = (pl - _value);
                    balances[_to] = (balances[_to] + _value);
                    Transfer(msg.sender, _to, _value);
                }
            }
            else {
                uint plk = balanceOf(msg.sender);
                balances[msg.sender] = (plk - _value);
                balances[_to] = (balances[_to]+ _value);
                Transfer(msg.sender, _to, _value);
            }
        }
    }

    function exchange(address _partner, uint _amount) internal {
        require(exchangePartners[_partner] == true);
        bool s = requestTokensFromOtherContract(_partner, this, msg.sender, _amount);
        require(s == true);
        uint p1 = balanceOf(msg.sender);
        balances[msg.sender] = (p1 -_amount);
        circulatingSupply = (circulatingSupply - _amount);
        totalSupply = (totalSupply + _amount);
        Transfer(msg.sender, this, _amount);
    }

    function requestTokensFromOtherContract(address _targetContract, address _sourceContract, address _recipient, uint256 _value) internal returns (bool){
        Partner p = Partner(_targetContract);
        p.exchangeTokensFromOtherContract(_sourceContract, _recipient, _value);
        return true;
    }

    function balanceOf(address _receiver) public constant returns (uint256) {
        return balances[_receiver];
    }

    function balanceInTier() public constant returns (uint256) {
        return tierTokens[tierLevel];
    }

    function currentTier() public constant returns (uint256) {
        return tierLevel;
    }

    function setFiatPerEthRate(uint256 _newRate) {
        require(msg.sender == owner);
        fiatPerEth = _newRate;
    }

    function addExchangePartnerTargetAddress(address _partner) public {
        require(msg.sender == owner);
        exchangePartners[_partner] = true;
    }

    function canContractExchange(address _contract) public constant returns (bool) {
        return exchangePartners[_contract];
    }

    function removeExchangePartnerTargetAddress(address _partner) public {
        require(msg.sender == owner);
        exchangePartners[_partner] = false;
    }

    function withdrawDevFees() public {
        require(payFees == true);
        devFeesAddr.transfer(devFees);
        devFees = 0;
    }

    function changeDevFees(address _devFees) public {
        require(msg.sender == owner);
        devFeesAddr = _devFees;
    }

    function changePreMine(address _preMine) {
        require(msg.sender == owner);
        premine = _preMine;
    }

    function payFeesToggle() {
        require(msg.sender == owner);
        if(payFees == true) {
            payFees = false;
        }
        else {
            payFees = true;
        }
    }

    function safeWithdrawal(address _receiver, uint256 _value) public {
        require(msg.sender == owner);
        // check balance before transferring
        require(_value <= this.balance);
        _receiver.transfer(_value);
    }

    // enables fee update - must be between 0 and 100 (%)
    function updateFeeAmount(uint _newFee) public {
        require(msg.sender == owner);
        require((_newFee >= 0) && (_newFee <= 100));
        fees = _newFee * 100;
    }

    function handleTokensFromOtherContracts(address _contract, address _recipient, uint256 _tokens) {
        require(msg.sender == owner);
        Target t;
        t = Target(_contract);
        t.transfer(_recipient, _tokens);
    }

    function changeOwner(address _recipient) {
        require(msg.sender == owner);
        owner = _recipient;
    }

    function changeTierController(address _controller) {
        require(msg.sender == owner);
        tierController = _controller;
    }

    function setTokenAndRate(uint256 _tokens, uint256 _rate) {
        require((msg.sender == owner) || (msg.sender == tierController));
        maxTier++;
        tierTokens[maxTier] = _tokens;
        costPerToken[maxTier] = _rate;
    }

    function setPreMineAddress(address _premine) {
        require(msg.sender == owner);
        premine = _premine;
    }

    function toggleReceiveEth() {
        require(msg.sender == owner);
        if(receiveEth == true) {
            receiveEth = false;
        }
        else receiveEth = true;
    }

    function toggleTokenExchange() {
        require(msg.sender == owner);
        if(canExchange == true) {
            canExchange = false;
        }
        else canExchange = true;
    }
}