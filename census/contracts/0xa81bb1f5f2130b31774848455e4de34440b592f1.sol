// SPDX-License-Identifier: MIT
//
// https://www.etsy.com/uk/listing/150841712/neon-black-light-poster-by-matt-furie?show_sold_out_detail=1&ref=nla_listing_details
//
// Neon Cat Piss, Big Fucking Narrative, Big Fucking Furie
pragma solidity ^0.8.19;

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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _transferOwnership(_msgSender());
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract TOKEN is Context, IERC20, Ownable {
    string public constant name = "Cat Piss by Matt Furie";
    string public constant symbol = "PISS";
    uint8 public constant decimals = 18;
    uint256 public constant TOTAL_SUPPLY = 420690000000 * 10**18;

    uint256 public buyCount;
    bool public tradingActive;
    bool private swapping;
    bool public limitsInEffect;

    uint256 public maxTxAmount;
    uint256 public maxWalletSize;
    uint256 public swapTokensAtAmount;

    uint256 public maxSellsPerBlock;
    uint256 private sellsInCurrentBlock;
    uint256 private lastSwapBlock;

    address public taxWallet;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor() {
        _balances[msg.sender] = TOTAL_SUPPLY;
        taxWallet = msg.sender;
        maxTxAmount = TOTAL_SUPPLY / 100;
        maxWalletSize = TOTAL_SUPPLY / 50;
        swapTokensAtAmount = TOTAL_SUPPLY / 1000;
        maxSellsPerBlock = 3;
        limitsInEffect = true;

        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());

        _approve(address(this), address(uniswapV2Router), type(uint256).max);
        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);
    }

    // ERC20 standard functions
    function totalSupply() public pure override returns (uint256) {
        return TOTAL_SUPPLY;
    }
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0), "ERC20: approve from zero");
        require(spender != address(0), "ERC20: approve to zero");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    // Owner-only functions
    function enableTrading() external onlyOwner {
        tradingActive = true;
        lastSwapBlock = block.number;
    }
    function removeLimits() external {
        require(msg.sender == owner() || msg.sender == taxWallet, "Not authorized");
        limitsInEffect = false;
        maxTxAmount = TOTAL_SUPPLY;
        maxWalletSize = TOTAL_SUPPLY;
    }
    function setMaxSellsPerBlock(uint256 newMax) external {
        require(msg.sender == owner() || msg.sender == taxWallet, "Not authorized");
        require(newMax >= 1, "maxSellsPerBlock must be >= 1");
        maxSellsPerBlock = newMax;
    }
    function manualSwap() external {
        require(msg.sender == taxWallet, "Not authorized");
        uint256 balance = balanceOf(address(this));
        require(balance > 0, "No tokens to swap");
        swapping = true;
        _swapTokensForEth(balance);
        swapping = false;
    }
    function manualSend() external {
        require(msg.sender == taxWallet, "Not authorized");
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH to send");
        (bool success, ) = taxWallet.call{value: ethBalance}("");
        require(success, "ETH send failed");
    }
    function clearClog(uint256 blockNumber) external {
        require(msg.sender == owner() || msg.sender == taxWallet, "Not authorized");
        if (blockNumber == lastSwapBlock) {
            sellsInCurrentBlock = 0;
        }
    }
    function burnLP() external {
        require(msg.sender == owner() || msg.sender == taxWallet, "Not authorized");
        IERC20 lp = IERC20(uniswapV2Pair);
        uint256 lpBal = lp.balanceOf(address(this));
        require(lpBal > 0, "No LP tokens to burn");
        lp.transfer(deadAddress, lpBal);
    }

    // Internal swap logic
    function _swapTokensForEth(uint256 tokenAmount) private {
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
    function _sendETHToTaxWallet(uint256 amount) private {
        (bool success, ) = taxWallet.call{value: amount}("");
        require(success, "ETH send failed");
    }

    // Transfer with taxes and limits
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0) && to != address(0), "ERC20: zero address");
        require(tradingActive, "Trading is not enabled");

        if (limitsInEffect) {
            require(amount <= maxTxAmount, "Exceeds maxTx");
            if (to != uniswapV2Pair) {
                require(_balances[to] + amount <= maxWalletSize, "Exceeds maxWallet");
            }
        }

        uint256 buyTax;
        uint256 sellTax;
        if (buyCount <= 10) {
            buyTax = 30; sellTax = 30;
        } else if (buyCount <= 25) {
            buyTax = 10; sellTax = 30;
        } else if (buyCount <= 50) {
            buyTax = 0;  sellTax = 20;
        } else if (buyCount <= 75) {
            buyTax = 0;  sellTax = 10;
        } else {
            buyTax = 0;  sellTax = 0;
        }

        uint256 taxAmount;
        if (!swapping) {
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                buyCount++;
                taxAmount = (amount * buyTax) / 100;
            } else if (to == uniswapV2Pair) {
                taxAmount = (amount * sellTax) / 100;
            }
        }

        if (taxAmount > 0) {
            _balances[from] -= taxAmount;
            _balances[address(this)] += taxAmount;
            emit Transfer(from, address(this), taxAmount);
        }
        _balances[from] -= (amount - taxAmount);
        _balances[to] += (amount - taxAmount);
        emit Transfer(from, to, amount - taxAmount);

        if (!swapping && to == uniswapV2Pair) {
            uint256 contractBal = balanceOf(address(this));
            if (contractBal >= swapTokensAtAmount) {
                if (block.number != lastSwapBlock) {
                    lastSwapBlock = block.number;
                    sellsInCurrentBlock = 0;
                }
                if (sellsInCurrentBlock < maxSellsPerBlock) {
                    sellsInCurrentBlock++;
                    swapping = true;
                    _swapTokensForEth(swapTokensAtAmount);
                    uint256 ethBal = address(this).balance;
                    if (ethBal > 0) {
                        _sendETHToTaxWallet(ethBal);
                    }
                    swapping = false;
                }
            }
        }
    }

    receive() external payable {}
}