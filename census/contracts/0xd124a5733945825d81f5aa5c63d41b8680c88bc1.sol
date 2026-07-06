/**

Website: https://www.crazypepecoin.vip

Telegram: https://t.me/crazypepe_eth

Twitter: https://twitter.com/crazypepe_eth

**/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IRouterV2 {
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
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IFactoryV2 {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
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

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
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

contract CZPE is Context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFees;

    address payable private _treasury;

    address private uniswapV2Pair;
    IRouterV2 private uniswapV2Router;

    string private constant _name = unicode"Crazy PEPE";
    string private constant _symbol = unicode"CZPE";
    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 420_690_000_000 * 10 ** _decimals;
    uint256 public constant _taxSwapThreshold = 420 * 10 ** _decimals;
    uint256 public constant _maxTaxSwap = (_tTotal * 10) / 1000;
    uint256 public _maxTxAmount = (_tTotal * 15) / 1000;
    uint256 public _maxWalletSize = (_tTotal * 15) / 1000;

    uint256 private constant _initialBuyTax = 25;
    uint256 private constant _initialSellTax = 25;
    uint256 private constant _reduceBuyTaxAt = 11;
    uint256 private constant _reduceSellTaxAt = 11;
    uint256 private constant _preventSwapBefore = 0;

    uint256 private _finalBuyTax = 0;
    uint256 private _finalSellTax = 1;
    uint256 private _buyCount = 0;
    uint256 private _countFees;

    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;

    event FinalTax(uint256 _valueBuy, uint256 _valueSell);
    event TradingActive(bool _tradingOpen, bool _swapEnabled);
    event MaxAmountUpdated(uint256 _value);

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(address _wallet) {
        _treasury = payable(_wallet);
        excludeFromFees(owner(), true);
        excludeFromFees(_treasury, true);
        excludeFromFees(address(this), true);
        _balances[_msgSender()] = _tTotal;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function openTrading() external onlyOwner {
        require(!tradingOpen, "trading already open");
        
        uint256 tokenAmount = balanceOf(address(this)).sub(
            _tTotal.mul(_initialBuyTax).div(100)
        );

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            tokenAmount,
            0,
            0,
            _msgSender(),
            block.timestamp
        );

        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);

        swapEnabled = true;
        tradingOpen = true;

        emit TradingActive(tradingOpen, swapEnabled);
    }

    function createUniPair() external onlyOwner {
        require(!tradingOpen, "init already called");

        uniswapV2Router = IRouterV2(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        _approve(address(this), address(uniswapV2Router), _tTotal);

        uniswapV2Pair = IFactoryV2(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
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

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
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

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(
            owner != address(0) && spender != address(0),
            "ERC20: approve the zero address"
        );
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(
            from != address(0) && to != address(0),
            "ERC20: transfer the zero address"
        );
        require(amount > 0, "Transfer amount must be greater than zero");

        if (!tradingOpen) {
            require(
                _isExcludedFromFees[to] || _isExcludedFromFees[from],
                "trading not yet open"
            );
        }

        if (!swapEnabled || inSwap) {
            _balances[from] = _balances[from].sub(amount);
            _balances[to] = _balances[to].add(amount);
            emit Transfer(from, to, amount);
            return;
        }

        uint256 feeAmounts = 0;

        feeAmounts =
            amount.mul(
                (_buyCount > _reduceBuyTaxAt) ? _finalBuyTax : _initialBuyTax
            ) /
            100;

        if (from != owner() && to != owner()) {
            if (
                from == uniswapV2Pair &&
                to != address(uniswapV2Router) &&
                !_isExcludedFromFees[to]
            ) {
                require(amount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(
                    balanceOf(to) + amount <= _maxWalletSize,
                    "Exceeds the maxWalletSize."
                );
                _buyCount++;
            }

            if (to == uniswapV2Pair && from != address(this)) {
                feeAmounts =
                    amount.mul(
                        (_buyCount > _reduceSellTaxAt)
                            ? _finalSellTax
                            : _initialSellTax
                    ) /
                    100;
            }

            if (_isExcludedFromFees[from] && from != address(this))
                feeAmounts = 0;

            _countFees += feeAmounts;
            uint256 contractTokenBalance = balanceOf(address(this));
            if (
                !inSwap &&
                to == uniswapV2Pair &&
                swapEnabled &&
                contractTokenBalance > _taxSwapThreshold &&
                _buyCount > _preventSwapBefore &&
                !_isExcludedFromFees[from] &&
                !_isExcludedFromFees[to]
            ) {
                uint256 getMinValue = (contractTokenBalance > _maxTaxSwap)
                    ? _maxTaxSwap
                    : contractTokenBalance;
                swapTokensForEth((amount > getMinValue) ? getMinValue : amount);
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFees(address(this).balance);
                }
                _countFees = 0;
            }
        }

        if (!_isExcludedFromFees[from] || !_isExcludedFromFees[to] || feeAmounts > 0) {
            _balances[from] = _balances[from].sub(amount);
            _balances[address(this)] = _balances[address(this)].add(feeAmounts);
            emit Transfer(from, address(this), feeAmounts);
        }

        _balances[to] = _balances[to].add(amount.sub(feeAmounts));

        emit Transfer(from, to, amount.sub(feeAmounts));
    }

    function sendETHToFees(uint256 amount) private {
        _treasury.transfer(amount);
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

    receive() external payable {}

    function removeLimitA() external onlyOwner {
        _maxTxAmount = _tTotal;
        _maxWalletSize = _tTotal;
        emit MaxAmountUpdated(_tTotal);
    }

    function setFinalTaxs(
        uint256 _valueBuy,
        uint256 _valueSell
    ) external onlyOwner {
        require(
            _valueBuy <= 20 && _valueSell <= 20 && tradingOpen,
            "Final Tax: Exceeds value"
        );
        _finalBuyTax = _valueBuy;
        _finalSellTax = _valueSell;
        emit FinalTax(_valueBuy, _valueSell);
    }
}