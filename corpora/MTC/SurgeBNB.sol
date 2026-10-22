pragma solidity 0.8.0;

contract SurgeToken {
// is IERC20, Context, Ownable,
// ReentrancyGuard {

    // string constant _name = "Surge";
    // string constant _symbol = "SURGE";
    uint8 constant _decimals = 0;
    uint256 _totalSupply = 1 * 10**9;
    uint256 public sellFee = 94;
    uint256 public spreadDivisor = 94;
    uint256 public transferFee = 98;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;
    address constant zeroAddress = address(0);
    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;
    bool public hyperInflatePrice = false;
    bool inSwap;
    address immutable curAddress;
    uint256 contractBalance;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor () {
        curAddress = address(this);
        address msgSender = msg.sender;
        _owner = msg.sender;
        emit OwnershipTransferred(zeroAddress, msgSender);
        _status = _NOT_ENTERED;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(zeroAddress, msg.sender, _totalSupply);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function renounceOwnership() public {
        require(_owner == msg.sender);
        emit OwnershipTransferred(_owner, zeroAddress);
        _owner = zeroAddress;
    }

    function transferOwnership(address newOwner) public {
        require(_owner == msg.sender);
        require(newOwner != zeroAddress);
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function geUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    function lock(uint256 time) public virtual {
        require(_owner == msg.sender);
        _previousOwner = _owner;
        _owner = zeroAddress;
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, zeroAddress);
    }

    function unlock() public virtual {
        require(_previousOwner == msg.sender);
        require(block.timestamp > _lockTime);
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }

    // function name() public pure returns (string memory) {
    //     return _name;
    // }

    // function symbol() public pure returns (string memory) {
    //     return _symbol;
    // }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
  
    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(recipient != zeroAddress);
        require(amount > 0);
        uint256 tAmount = amount * transferFee/10**2;
        uint256 tax = amount-tAmount;
        require(_balances[msg.sender]>amount);
        _balances[msg.sender] = _balances[msg.sender]-amount;
        _balances[recipient] = _balances[recipient]+tAmount;
        _totalSupply = _totalSupply-tax;
        emit Transfer(msg.sender, recipient, tAmount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(sender == msg.sender);
        require(recipient != zeroAddress);
        require(amount > 0);
        uint256 tAmount = amount * transferFee/10**2;
        uint256 tax = amount-tAmount;
        require(_balances[sender]>amount);
        _balances[sender] = _balances[sender]-amount;
        _balances[recipient] = _balances[recipient]+tAmount;
        _totalSupply = _totalSupply-tax;
        emit Transfer(sender, recipient, tAmount);
        return true;
    }
    
    function sell(uint256 tokenAmount) public returns (bool) {
        require(_status != _ENTERED);
        _status = _ENTERED;
        address seller = msg.sender;
        require(_balances[seller] >= tokenAmount);
        uint256 tokensToSwap = tokenAmount*sellFee/10**2;
        uint256 amountBNB = tokensToSwap*contractBalance/_totalSupply;
        (bool successful,) = payable(seller).call{value: amountBNB, gas: 40000}("");
        if (successful == true) {
            require(_balances[seller]>=tokenAmount);
            _balances[seller] = _balances[seller]-tokenAmount;
            _totalSupply = _totalSupply-tokenAmount;
        } else {
            revert();
        }
        emit Transfer(seller, curAddress, tokenAmount);
        _status = _NOT_ENTERED;
        return true;
    }
    
    function calculatePrice() public view returns (uint256 k) {
        k = contractBalance/_totalSupply;
        return k;
    }
    
    function getBNBQuantityInContract() public view returns(uint256 k){
        k = contractBalance;
        return k;
    }
    
    function getValueOfHoldings(address holder) public view returns(uint256 k) {
        k = _balances[holder]*contractBalance/_totalSupply;
        return k;
    }
    
    // receive() external payable {
    //     uint256 val = msg.value;
    //     address buyer = msg.sender;
    //     require(val <= contractBalance);
    //     uint256 prevBNBAmount = contractBalance-val;
    //     prevBNBAmount = prevBNBAmount == 0 ? contractBalance : prevBNBAmount;
    //     uint256 nShouldPurchase = hyperInflatePrice ? _totalSupply*val/contractBalance : _totalSupply*val/prevBNBAmount;
    //     uint256 tokensToSend = nShouldPurchase*spreadDivisor/10**2;
    //     if (tokensToSend < 1) {
    //         revert('Must Buy More Than One Surge');
    //     }
    //     _balances[buyer] = _balances[buyer]+tokensToSend;
    //     _totalSupply = _totalSupply+tokensToSend;
    //     emit Transfer(curAddress, buyer, tokensToSend);
    // }
}
