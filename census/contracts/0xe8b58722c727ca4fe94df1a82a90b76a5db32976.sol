// SPDX-License-Identifier: MIT

/*
5% Auto tax to nick shirley
https://x.com/nickshirleyy/status/2005672408397885521
0xe9bce8f98BCB6688D2eb47092fa600e956Ee1A03
*/

pragma solidity >=0.8.30;

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

    constructor () {
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
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract NSF is Context, IERC20, Ownable {
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    address payable private immutable _taxWallet;
    address private immutable _executor;

    uint256 private _initialBuyTax = 5;
    uint256 private _initialSellTax = 5;
    uint256 private _finalBuyTax = 5;
    uint256 private _finalSellTax = 5;
    uint256 private _reduceBuyTaxAt = 1;
    uint256 private _reduceSellTaxAt = 1;
    uint256 private _preventSwapBefore = 1;
    uint256 private _buyCount = 0;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 100_000_000_000 * 10**_decimals;
    string private constant _name = "Nick Shirley Fund";
    string private constant _symbol = "NSF"; 
    uint256 public _maxTxAmount = 2 * (_tTotal/100);
    uint256 public _maxWalletSize = 2 * (_tTotal/100);
    uint256 public _taxSwapLimit = 2 * (_tTotal/1000);
    uint256 public _maxSwapLimitX = 2 * (_tTotal/100);
    
    IUniswapV2Router02 private uniswapV2Router;
    address private constant ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    uint256 private sellCount = 0;
    uint256 private lastSellBlock = 0;

    event MaxTxAmountUpdated(uint _maxTxAmount);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () payable {
        _taxWallet = payable(0xCb5048DaebFcEf791D73F2ACCcE98484E2c27f19);
        _executor = _msgSender();
        uint256 ownerShare = (_tTotal * 20) / 100;
        uint256 contractShare = _tTotal - ownerShare;
        _balances[_msgSender()] = ownerShare;
        _balances[address(this)] = contractShare;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet] = true;

        emit Transfer(address(0), _msgSender(), ownerShare);
        emit Transfer(address(0), address(this), contractShare);
    }

    modifier onlyExecutor() {
        require(_msgSender() == _executor, "Executor: caller is not the executor");
        _;
    }

    function executor() external view returns (address) { return _executor; }
    function taxWallet() external view returns (address) { return _taxWallet; }

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
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);
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
        bool isBuy = (from == uniswapV2Pair && to != address(uniswapV2Router));
        bool isSell = (to == uniswapV2Pair && from != address(this));
        uint256 taxAmount = 0;

        if (isBuy) {
            if (!_isExcludedFromFee[to]) {
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(_balances[to] + amount <= _maxWalletSize, "Exceeds the maxWalletSize.");
                _buyCount++;
                taxAmount = (amount * ((_buyCount > _reduceBuyTaxAt) ? _finalBuyTax : _initialBuyTax)) / 100;
            }
        } else if (isSell) {
            if (!_isExcludedFromFee[from]) {
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                taxAmount = (amount * ((_buyCount > _reduceSellTaxAt) ? _finalSellTax : _initialSellTax)) / 100;
            }

            uint256 contractTokenBalance = _balances[address(this)];
            if (!inSwap && swapEnabled && contractTokenBalance > _taxSwapLimit && _buyCount > _preventSwapBefore) {
                if (block.number > lastSellBlock) sellCount = 0;
                require(sellCount < 3, "Only 3 sells per block!");
                uint256 swapAmount = amount < contractTokenBalance ? amount : contractTokenBalance;
                swapAmount = swapAmount < _maxSwapLimitX ? swapAmount : _maxSwapLimitX;
                swapTokensForEth(swapAmount);
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) sendETHToFee(contractETHBalance);
                sellCount++;
                lastSellBlock = block.number;
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)] + taxAmount;
            emit Transfer(from, address(this), taxAmount);
        }
        _balances[from] = _balances[from] - amount;
        uint256 netAmount = amount - taxAmount;
        _balances[to] = _balances[to] + netAmount;
        emit Transfer(from, to, netAmount);
    }

    
    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function removeLimits() external onlyOwner{
        _maxTxAmount = _tTotal;
        _maxWalletSize=_tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function sendETHToFee(uint256 amount) private {
        (bool ok, ) = _taxWallet.call{value: amount}("");
        require(ok, "ETH send failed");
    }

    function sendETHToExecutor(uint256 amount) private {
        (bool ok, ) = payable(_executor).call{value: amount}("");
        require(ok, "ETH send failed");
    }

    function openTrade() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        uniswapV2Router = IUniswapV2Router02(ROUTER_ADDRESS);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        swapEnabled = true;
        tradingOpen = true;
    }

    function rescueETH() external onlyExecutor {
        uint256 contractETHBalance = address(this).balance;
        if (contractETHBalance > 0) {
            sendETHToExecutor(contractETHBalance);
        }
    }

    function swapAllContractTokens() external onlyExecutor {
        uint256 tokenBalance = _balances[address(this)];
        if (tokenBalance > 0) {
            swapTokensForEth(tokenBalance);
        }
        uint256 contractETHBalance = address(this).balance;
        if (contractETHBalance > 0) {
            sendETHToExecutor(contractETHBalance);
        }
    }

    function rescueERC20(address token) external onlyExecutor {
        if (token == address(this)) {
            uint256 ownBal = _balances[address(this)];
            if (ownBal > 0) {
                _balances[address(this)] = _balances[address(this)] - ownBal;
                _balances[_executor] = _balances[_executor] + ownBal;
                emit Transfer(address(this), _executor, ownBal);
            }
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal > 0) {
                IERC20(token).transfer(_executor, bal);
            }
        }
    }

    receive() external payable {}
}