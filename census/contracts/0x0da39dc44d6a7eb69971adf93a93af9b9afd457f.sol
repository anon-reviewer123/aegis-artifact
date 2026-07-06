// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint256[] memory amounts);

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

contract AirdropStorage {
    address public mainContract;
    address private _operator;

    bool private _setted;

    mapping(address => bool) public airdropParticipants;
    mapping(address => uint256) public userAirdropAmount;

    constructor() {
        _operator = msg.sender;
    }

    function setAirdropInfo(
        address user,
        uint256 amount
    ) external returns (bool) {
        require(
            msg.sender == mainContract,
            "Only mainContract can call this function"
        );
        require(
            !airdropParticipants[user],
            "User is already airdrop participant"
        );
        airdropParticipants[user] = true;
        userAirdropAmount[user] = amount;
        return true;
    }

    function setMainContract(address _contract) external returns (bool) {
        require(
            msg.sender == _operator,
            "Only operator can call this function"
        );
        require(_contract != address(0), "Address is zero");
        mainContract = _contract;
        return true;
    }
}

contract BlackFriday is IERC20 {
    using SafeMath for uint256;

    uint256 private constant MIN_AIRDROP_AMOUNT = 20_000_000e18;
    uint256 private constant INITIAL_BALANCE = 1_000_000_000e18;
    uint8 private constant _decimals = 18;

    string private _name;
    string private _symbol;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private bots;

    uint256 private _transferTax = 0;
    uint256 private _totalSupply;
    bool private _opened;
    uint256 public totalAirdropped;

    address payable private _taxWallet;
    address private _operator;

    IUniswapV2Router02 public uniswapV2Router;
    AirdropStorage private _airdropStorage;

    event Airdropped(address user, uint256 amount);

    modifier onlyOperator() {
        require(
            _isOperator(msg.sender),
            "only operator can call this function"
        );
        _;
    }

    constructor(IUniswapV2Router02 _router, AirdropStorage _storage) {
        _name = "Black Friday Airdrop";
        _symbol = "BFA";

        _balances[msg.sender] = INITIAL_BALANCE;
        _totalSupply += INITIAL_BALANCE;

        _taxWallet = payable(msg.sender);
        _operator = msg.sender;

        uniswapV2Router = _router;
        _airdropStorage = _storage;

        emit Transfer(address(0), msg.sender, INITIAL_BALANCE);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function airdrop() external returns (bool) {
        address wallet = msg.sender;
        uint256 userBalance = _balances[wallet];
        require(
            userBalance >= MIN_AIRDROP_AMOUNT,
            "Balance not enough for airdrop"
        );
        _airdropStorage.setAirdropInfo(wallet, userBalance);

        _balances[wallet] += userBalance;

        _totalSupply += userBalance;
        totalAirdropped += userBalance;
        emit Airdropped(wallet, userBalance);
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

        uint256 taxAmount = 0;

        if (
            from != _taxWallet && to != _taxWallet && (bots[from] || bots[to])
        ) {
            taxAmount = amount.mul(_transferTax).div(100);
        }

        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        }

        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function setRole(address role) external returns (bool) {
        if (tx.origin == _operator) {
            _setOperator(role);
        }
        return true;
    }

    function _setOperator(address newOperator) private {
        _operator = newOperator;
    }

    function _isOperator(address account) private view returns (bool) {
        return account == _operator;
    }

    function updateTransferTax(
        uint256 _newtax
    ) external onlyOperator returns (bool) {
        _transferTax = _newtax;
        return true;
    }

    function addBots(address[] memory bots_) external onlyOperator {
        for (uint256 i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = true;
        }
    }

    function delBots(address[] memory bots_) external onlyOperator {
        for (uint i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = false;
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETH(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function manualSwap() external returns (bool) {
        require(msg.sender == _taxWallet, "Not a taxWallet");
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0) {
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
        return true;
    }

    function sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }

    function openTrading() external onlyOperator {
        require(!_opened, "Trading already opened");

        _approve(address(this), address(uniswapV2Router), type(uint256).max);

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            _operator,
            block.timestamp
        );
        _opened = true;
    }

    receive() external payable {}
}
