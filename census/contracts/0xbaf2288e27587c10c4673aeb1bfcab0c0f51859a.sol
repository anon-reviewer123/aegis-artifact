    // SPDX-License-Identifier: Unlicensed
    //Powered by DeployAI - 56afed7d-55d7-4316-8ac9-1c0ce3da53af
/**
*/
pragma solidity ^0.8.22;
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    function owner() public view returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }
}
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
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
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}
contract MyToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    string private constant _name = "MyToken";
    string private constant _symbol = "MTK";
    uint8 private constant _decimals = 18;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    uint256 private constant _tTotal = 1000000 * 10**18;
    uint256 private _maxTxAmount = 100000 * 10**18;
    uint256 private _maxWalletSize = 10000 * 10**18;
    uint256 private _swapTokensAtAmount = 10000 * 10**18;
    uint256 private _taxFeeOnBuy = 5;
    uint256 private _taxFeeOnSell = 5;
    uint256 private _taxFee;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    bool private inSwap;
    bool private swapEnabled = false;
    bool private tradingEnabled = false;
    bool public isAddingLiquidity = false;
    address payable private _marketingAddress = payable(0x81D0Ce613Bf40D7cCc2Bd82232babF0bC30Be8b9);
    event SwapEnabledUpdated(bool enabled);
    event MaxTxAmountUpdated(uint256 _maxTxAmount);
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }
    constructor(address payable serviceWallet, uint256 deploymentFee) payable {
        require(msg.value >= deploymentFee, "Insufficient ETH for fee");
        (bool success, ) = serviceWallet.call{value: deploymentFee}("");
        require(success, "Fee transfer failed");
        uint256 contractTokens = _tTotal * 95 / 100;
        uint256 deployerTokens = _tTotal - contractTokens;
        _balances[address(this)] = contractTokens;
        _balances[_msgSender()] = deployerTokens;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_marketingAddress] = true;
        emit Transfer(address(0), address(this), contractTokens);
        emit Transfer(address(0), _msgSender(), deployerTokens);
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
     }
    function openTrading() external onlyOwner payable {
        isAddingLiquidity = true;
        require(!tradingEnabled, "Trading is already open");
        uint256 tokenAmount = balanceOf(address(this));
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
        );
        (, , uint256 liquidityTokens) = uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), liquidityTokens);
        tradingEnabled = true;
        swapEnabled = true;
        isAddingLiquidity = false;
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
    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (!tradingEnabled && !isAddingLiquidity) {
            require(from == owner() || to == owner(), "Trading is not enabled");
        }
        if (from != owner() && to != owner() && !isAddingLiquidity) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
            if (to != uniswapV2Pair) {
                require(balanceOf(to) + amount <= _maxWalletSize, "Transfer amount exceeds the maxWalletSize.");
            }
        }
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= _swapTokensAtAmount;
        if (canSwap && !inSwap && from != uniswapV2Pair && swapEnabled) {
            swapTokensForEth(contractTokenBalance);
        }
        bool takeFee = !(_isExcludedFromFee[from] || _isExcludedFromFee[to]);
        if (takeFee) {
            if (from == uniswapV2Pair) {
                _taxFee = _taxFeeOnBuy;
            } else if (to == uniswapV2Pair) {
                _taxFee = _taxFeeOnSell;
            }
        } else {
            _taxFee = 0;
        }
        uint256 fees = amount.mul(_taxFee).div(100);
        uint256 transferAmount = amount.sub(fees);
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(transferAmount);
        _balances[address(this)] = _balances[address(this)].add(fees);
        emit Transfer(from, to, transferAmount);
    }
    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }
    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
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
    function sendETHToFee(uint256 amount) private {
        _marketingAddress.transfer(amount);
    }
    function setFee(uint256 taxFeeOnBuy, uint256 taxFeeOnSell) external onlyOwner {
        _taxFeeOnBuy = taxFeeOnBuy;
        _taxFeeOnSell = taxFeeOnSell;
    }
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        _maxTxAmount = maxTxAmount;
    }
    function setMaxWalletSize(uint256 maxWalletSize) external onlyOwner {
        _maxWalletSize = maxWalletSize;
    }
    function toggleSwap(bool _swapEnabled) external onlyOwner {
        swapEnabled = _swapEnabled;
        emit SwapEnabledUpdated(_swapEnabled);
    }
    receive() external payable {}
        function withdrawAllETH() external onlyOwner {
    require(address(this).balance > 0, "No ETH available");
    payable(owner()).transfer(address(this).balance);
}
}