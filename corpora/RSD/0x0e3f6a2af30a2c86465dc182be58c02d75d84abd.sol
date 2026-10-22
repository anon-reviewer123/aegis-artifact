/**
 *Submitted for verification at Etherscan.io on 2021-05-17
*/

pragma solidity ^ 0.5.1;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns(uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns(uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns(uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns(uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns(uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns(uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns(uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns(uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Ownable {
    address private _owner;
address zero;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() internal {
        _owner = msg.sender;
        emit OwnershipTransferred(zero, msg.sender);
    }

    function owner() public view returns(address) {
        return _owner;
    }

    modifier onlyOwner() {
        bool pk = isOwner();
        require(pk == true, "Ownable: caller is not the owner");
        _;
    }

    function isOwner() public view returns(bool p) {
        if(msg.sender == _owner){
            p = true;
        }
        else{
            p = false;
        }
        return p;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, zero);
        _owner = zero;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != zero, "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    struct ExcludeAddress {
        bool isExist;
    }
    // Frontrans and Sniper bots will be blocked
    mapping(address => ExcludeAddress) public blackList;
    // only ICO contract and owner able to transfers before listing to uniswap
    mapping(address => ExcludeAddress) public whiteList;
    // ICO contract and Rewards wallet will be send without tax
    mapping(address => ExcludeAddress) public taxFree;

    // blocked transfers (exclude whiteList)
    // to avoid fake listing not from the team
    bool public isWhiteListOnly = true;
    // the address that will receive taxes and send out rewards
    address public rewardsWallet;

    // Token params
    string public constant name = "msgt.io";
    string public constant symbol = "MSGT";
    uint public constant decimals = 18;
    uint constant total = 53750;
    uint256 private _totalSupply;
    uint lastCheck = now;
    uint periodRebalance = 12 hours;
    // -- Token params

    //Taxes
    uint public taxPercent = 6;
    uint public taxPercentSell = 6;
    uint public taxPercentBuy = 6;
    
    address public liqAddress = zero;
    // baseBalance - this is the balance of the reward wallet, to which the wallet will be rebalanced in case of exceeding +-10%
    uint constant public baseBalance = 3500 * 10 ** decimals;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebalance(uint256 balance);
    event Tax(uint256 taxedAmount);

    constructor() public {
        _mint(msg.sender, total * 10 ** decimals);
    }

    function totalSupply() public view returns(uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns(uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns(bool) {
        _taxTransfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns(uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns(bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns(bool) {
        _taxTransfer(sender, recipient, amount);
        uint k1 = _allowances[sender][msg.sender]-(amount);
        _approve(sender, msg.sender, k1);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns(bool) {
        uint k2 = _allowances[msg.sender][spender]+(addedValue);
        _approve(msg.sender, spender, k2);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns(bool) {
        uint k3 = _allowances[msg.sender][spender]-(subtractedValue);
        _approve(msg.sender, spender, k3);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != zero, "ERC20: transfer from the zero address");
        require(recipient != zero, "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender]-(amount);
        _balances[recipient] = _balances[recipient]+(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != zero, "ERC20: mint to the zero address");

        _totalSupply = _totalSupply+(amount);
        _balances[account] = _balances[account]+(amount);
        emit Transfer(zero, account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != zero, "ERC20: approve from the zero address");
        require(spender != zero, "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _taxTransfer(address _sender, address _recipient, uint256 _amount) internal returns(bool) {
        require(!blackList[_sender].isExist, 'Address blocked');
        require(!isWhiteListOnly || whiteList[_sender].isExist == true, 'White List only'); // unlock after listing

        if (taxFree[_sender].isExist == true) {
            _transfer(_sender, _recipient, _amount);
        } else {
            // calc tax
            uint tax;
            if(_sender == liqAddress) {tax = taxPercentBuy;} // buy token
            else if(_recipient == liqAddress) {tax = taxPercentSell;} // sell token
            else {tax = taxPercent;} // Wallet to Wallet
            
            uint _taxedAmount = _amount*(tax)/(100);
            uint _transferedAmount = _amount-(_taxedAmount);

            _transfer(_sender, rewardsWallet, _taxedAmount); // tax to rewardsWallet
            _transfer(_sender, _recipient, _transferedAmount); // amount - tax to recipient
            emit Tax(_taxedAmount);
        }

        rebalanceRW();
    }

    // If the balance of the reward changes from the base value by 10%, its balance is returned to the base value.
    // In this case, the extra tokens are burned, and the shortage is minted.
    function rebalanceRW () public {
        if (isWhiteListOnly == true || lastCheck > now - periodRebalance) {
            return;
        }

        lastCheck = now; // cached time of rebalance
        uint balance = balanceOf(rewardsWallet);
        // 10% constant
        if (balance < (baseBalance*(90))/(100)) { // positive
            emit Rebalance(balance);
            _balances[rewardsWallet] = baseBalance;
            _totalSupply = _totalSupply+(baseBalance - balance);
        } else if (balance > (baseBalance*(110))/(100)) { // negative
            emit Rebalance(balance);
            _balances[rewardsWallet] = baseBalance;
            _totalSupply = _totalSupply-(balance - baseBalance);
        }
    }

    // OWNER utils
    function toggleWhiteList(address addr) public onlyOwner {
        if(whiteList[addr].isExist == true){
            whiteList[addr].isExist = false;
        } 
        else{
            whiteList[addr].isExist = true;
        }
    }
    function toggleTaxFeeList(address addr) public onlyOwner {
        if(taxFree[addr].isExist == true){
            taxFree[addr].isExist = false;
        } 
        else{
            taxFree[addr].isExist = true;
        }
        
    }

    function toggleBlackList(address addr) public onlyOwner {
        if(blackList[addr].isExist == true){
            // if address is blocked, then unblock
            blackList[addr].isExist = false;
        } 
        else{
            blackList[addr].isExist = false;
        }
    }
    function toggleIsWhiteListOnly() public onlyOwner {
        if(isWhiteListOnly == true){
            // if whiteList only, then allow all
            isWhiteListOnly = false;
        }
        else{
            isWhiteListOnly = true;
        }
    }

    function changePercentOfTax(uint percent) public onlyOwner {
        taxPercent = percent;
    }
    function changePercentOfTaxSell(uint percent) public onlyOwner {
        taxPercentSell = percent;
    }
    function changePercentOfTaxBuy(uint percent) public onlyOwner {
        taxPercentBuy = percent;
    }

    // When change the reward wallet, tokens are sent from the old wallet to the new one.
    // Thus, an extra balance is not possible when changing wallets.
    function changeRewardsWallet(address addr) public onlyOwner {
        if(rewardsWallet != zero){
            _transfer(rewardsWallet, addr, _balances[rewardsWallet]);   
        }
        taxFree[rewardsWallet].isExist = false;
        taxFree[addr].isExist = true;
        rewardsWallet = addr;
    }

    // need after listing only
    function blockSell(address _liqAddress) public onlyOwner {
        changeLiqAddress(_liqAddress);
        isWhiteListOnly = true;
    }
    function changeLiqAddress(address _liqAddress) public onlyOwner {
        liqAddress = _liqAddress;
        whiteList[liqAddress].isExist = true;
    }
    // Tokens of adresess which was blocked send to reward wallet
    function sendBlockedTokensToRw(address addr) public onlyOwner {
        require(blackList[addr].isExist == true, 'Address is not blocked');
        _transfer(addr, rewardsWallet, _balances[addr]);
    }
}

contract Crowdsale {
    using SafeMath for uint256;
    address payable owner;
    address me = address(this);
    uint sat = 1e18;
    struct IsExist {bool isExist;}
    mapping(address => IsExist) public whiteList;
    // 
    // *** Config ***
    uint startIco = 1621260000;
    // uint startIco = now;
    uint stopIco = startIco + 48 hours;

    uint countBy1EthIfWL = 25; // 1ETH -> 25 MSGT
    uint countBy1EthIfNotWL = 24; // 1 ETH -> 24 MSGT
    uint amountWL = 10500 * sat; // amount for WL users
    uint amountNotWL = 10500 * sat; // amount for not WL users
    uint maxTokensToOnceHandWl = 75 * sat;
    uint maxTokensToOnceHandNoWl = 360 * sat;
    // --- Config ---
    ERC20 token = new ERC20();

    constructor() public {
        owner = msg.sender;

        token.toggleWhiteList(address(this));
        token.toggleTaxFeeList(address(this));

        token.toggleWhiteList(owner);
        token.toggleTaxFeeList(owner);

        token.transfer(owner, token.totalSupply() - (amountWL + amountNotWL));
        token.transferOwnership(owner);
    }

    function () external payable {
        require(startIco < now && now < stopIco, "Period error");
        uint k1 = getPrice();
        uint amount = msg.value*(k1);
        bool userIsWl = whiteList[msg.sender].isExist;
        uint k2 = token.balanceOf(msg.sender);
        uint k3 = (userIsWl == true ? maxTokensToOnceHandWl : maxTokensToOnceHandNoWl);
        require(k2 + amount <= k3, "The purchase limit of tokens has been exceeded");
        uint k4 = token.balanceOf(address(this));
        require(amount <= k4, "Infucient token balance in ICO");
        uint leftTokens = userIsWl == true ? amountWL : amountNotWL;
        require(amount <= leftTokens, "Infucient token balance in ICO for group");
        token.transfer(msg.sender, amount);
        if(userIsWl == true){ amountWL -= amount; } 
        else { amountNotWL -= amount; }
    }

    
    modifier onlyOw() {
        require(msg.sender == owner, "You is not owner");
        _;
    }
    // OWNER ONLY
    
    function pushWhiteList(address[] memory addressess) public onlyOw {
        for (uint i = 0; i < addressess.length; i++) {
            whiteList[addressess[i]].isExist = true;
        }
    }
    
    function manualGetETH () public payable onlyOw {
        owner.transfer(address(this).balance);
    }

    function getLeftTokens () public onlyOw {
        uint pl = token.balanceOf(address(this));
        token.transfer(owner, pl);
    }
    // run after 1h 
    function sendAmountWlToNoWL () public onlyOw {
        amountNotWL += amountWL;
        amountWL = 0;
    }
    

    //--- end OWNER ONLY
    

    function getPrice() public view returns(uint p) {
        p = (whiteList[msg.sender].isExist == true ? countBy1EthIfWL : countBy1EthIfNotWL);
        return p;
    }

    // Utils
    function getStartICO() public view returns(uint p) {
        p = (startIco - now) / 60;
        return p;
    }
    function getOwner() public view returns(address) {
        return owner;
    }
    function getStopIco() public view returns(uint p) {
        p = (stopIco - now) / 60;
        return p;
    }
    function tokenAddress() public view returns(address) {
        return address(token);
    }
    function IcoDeposit() public view returns(uint) {
        return token.balanceOf(address(this)) / sat;
    }
    function myBalancex10() public view returns(uint) {
        return token.balanceOf(msg.sender) / 1e17;
    }
    function myBalancex1000() public view returns(uint) {
        return token.balanceOf(msg.sender) / 1e15;
    }
    function leftAmountForWL () public view returns(uint) {
        return amountWL;
    }
    function leftAmountForNotWL () public view returns(uint) {
        return amountNotWL;
    }
}