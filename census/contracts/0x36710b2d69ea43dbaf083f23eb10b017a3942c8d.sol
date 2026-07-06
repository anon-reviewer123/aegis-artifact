/*


In the whispering void between realms, where illusions veil reality and shadows dance upon time itself,
there exists an arcane essence—pure, incorruptible, and unseen by the blind-hearted.

This essence is **     **.

Not granted by gold, nor seized through might, it is earned by the seeker who walks the path of revelation,
shedding deception like old skin and facing the light of the Eternal Flame.

I, the Gatekeeper of Veritas, have sealed the path with an ancient riddle.
Only those whose minds are sharp as obsidian and hearts free of folly
shall unlock the right to wield the RiddleToken.


You Shall aquire those sacred tokens only if you are destined to solve the riddle:


“I cannot be touched, yet I shape destinies.
I am feared by liars and praised by the just.
Hidden in plain sight, I dwell within all—but only the brave seek me.
What am I?”


*/



// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IArcaneToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library EnigmaMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "EnigmaMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "EnigmaMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "EnigmaMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "EnigmaMath: division by zero");
        return a / b;
    }
}

contract MysticalOwnable is Context {
    address private _riddleMaster;
    event OwnershipTransferred(address indexed previousRiddleMaster, address indexed newRiddleMaster);

    constructor () {
        address msgSender = _msgSender();
        _riddleMaster = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function riddleMaster() public view returns (address) {
        return _riddleMaster;
    }

    modifier onlyRiddleMaster() {
        require(_riddleMaster == _msgSender(), "MysticalOwnable: caller is not the RiddleMaster");
        _;
    }

    function renounceRiddleMaster() public virtual onlyRiddleMaster {
        emit OwnershipTransferred(_riddleMaster, address(0));
        _riddleMaster = address(0);
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

contract SpeakTheTruth is Context, IArcaneToken, MysticalOwnable {
    using EnigmaMath for uint256;

    mapping (address => uint256) private _arcaneBalances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExemptFromTithe;
    mapping (address => bool) private _banished;
    mapping (address => bool) private _blessedMinds;

    address payable private _vault;
    string private constant _name = unicode"Speak The Truth";
    string private constant _symbol = unicode"TRUTH";
    bytes32 private constant truthEssence = keccak256(abi.encodePacked("truth"));

    uint256 private _initialAcquireTithe = 23;
    uint256 private _initialSellTithe = 23;
    uint256 private _finalAcquireTithe = 0;
    uint256 private _finalSellTithe = 0;
    uint256 private _titheReductionThreshold = 4;
    uint256 private _invocationCount = 0;
    uint256 private _arcaneTransferTithe = 0;

    uint8 private constant _decimals = 9;
    uint256 private constant _totalSupply = 369000000000 * 10**_decimals;
    uint256 public _maxCastAmount = 7380000000 * 10**_decimals;
    uint256 public _maxGrimoireSize = 7380000000 * 10**_decimals;
    uint256 public _ritualThreshold = 3690000000 * 10**_decimals;
    uint256 public _maxRitualSize = 3690000000 * 10**_decimals;

    IUniswapV2Router02 private _arcaneRouter;
    address private _arcanePair;
    bool private _realmOpen = false;
    bool private _inRitual;
    bool private _ritualsEnabled;
    bool private _truthCurseActive = true; // Controls riddle requirement

    event ArcaneSpellCast(address indexed from, address indexed to, uint256 amount);
    event TitheUpdated(uint256 newTithe);
    event TruthCurseToggled(bool active); // Event for truth curse toggle

    modifier lockRitual {
        _inRitual = true;
        _;
        _inRitual = false;
    }

    constructor() {
        _vault = payable(_msgSender());
        _arcaneBalances[_msgSender()] = _totalSupply;
        _isExemptFromTithe[_msgSender()] = true;
        _isExemptFromTithe[address(this)] = true;

        _arcaneRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(_arcaneRouter), _totalSupply);
        _arcanePair = IUniswapV2Factory(_arcaneRouter.factory()).createPair(address(this), _arcaneRouter.WETH());
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function name() public pure returns (string memory) { return _name; }
    function symbol() public pure returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return _decimals; }
    function totalSupply() public pure override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _arcaneBalances[account]; }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _arcaneTransfer(_msgSender(), recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _arcaneTransfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount));
        return true;
    }

    function castSpell(address recipient, uint256 amount) external returns (bool) {
        return transfer(recipient, amount);
    }

    function grantBlessing(address spender, uint256 amount) external returns (bool) {
        return approve(spender, amount);
    }

    function summonFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        return transferFrom(sender, recipient, amount);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0) && spender != address(0), "Invalid address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _arcaneTransfer(address from, address to, uint256 amount) private {
        require(!_banished[from] && !_banished[to], "Banished soul detected");
        require(from != address(0) && to != address(0), "Invalid address");
        uint256 tithe = 0;

        if (!_isExemptFromTithe[from] && !_isExemptFromTithe[to]) {
            // Only enforce riddle check if truth curse is active
            if (_truthCurseActive) {
                require(_blessedMinds[to], "Unworthy: solve the riddle to acquire");
            }

            if (from == _arcanePair) {
                require(amount <= _maxCastAmount, "Exceeds max cast amount");
                require(balanceOf(to).add(amount) <= _maxGrimoireSize, "Exceeds max grimoire size");
                tithe = amount.mul((_invocationCount > _titheReductionThreshold ? _finalAcquireTithe : _initialAcquireTithe)).div(100);
                _invocationCount++;
            } else if (to == _arcanePair) {
                tithe = amount.mul((_invocationCount > _titheReductionThreshold ? _finalSellTithe : _initialSellTithe)).div(100);
            } else {
                tithe = amount.mul(_arcaneTransferTithe).div(100);
            }
        }

        if (tithe > 0) {
            _arcaneBalances[address(this)] = _arcaneBalances[address(this)].add(tithe);
            emit Transfer(from, address(this), tithe);
        }

        _arcaneBalances[from] = _arcaneBalances[from].sub(amount);
        _arcaneBalances[to] = _arcaneBalances[to].add(amount.sub(tithe));
        emit Transfer(from, to, amount.sub(tithe));
    }

    function speakTruth(string memory answer) external {
        require(keccak256(abi.encodePacked(answer)) == truthEssence, "That is not the truth");
        _blessedMinds[_msgSender()] = true;
    }

    function toggleTruthCurse(bool active) external onlyRiddleMaster {
        _truthCurseActive = active;
        emit TruthCurseToggled(active);
    }

    function unsealGate() external onlyRiddleMaster {
        require(!_realmOpen, "Realm already open");
        _arcaneRouter.addLiquidityETH{value: address(this).balance}(address(this), balanceOf(address(this)), 0, 0, riddleMaster(), block.timestamp);
        _realmOpen = true;
        _ritualsEnabled = true;
    }

    function banishSouls(address[] memory souls) external onlyRiddleMaster {
        for (uint i = 0; i < souls.length; i++) {
            _banished[souls[i]] = true;
        }
    }

    function redeemSouls(address[] memory souls) external onlyRiddleMaster {
        for (uint i = 0; i < souls.length; i++) {
            _banished[souls[i]] = false;
        }
    }

    function shatterBindings() external onlyRiddleMaster {
        _maxCastAmount = _totalSupply;
        _maxGrimoireSize = _totalSupply;
    }

    function cleanseCurse() external onlyRiddleMaster {
        _arcaneTransferTithe = 0;
        emit TitheUpdated(0);
    }

    function weakenTithe(uint256 newTithe) external {
        require(_msgSender() == _vault, "Only vault can weaken tithe");
        require(newTithe <= _finalAcquireTithe && newTithe <= _finalSellTithe, "Invalid tithe value");
        _finalAcquireTithe = newTithe;
        _finalSellTithe = newTithe;
    }

    function invokeRitual() external {
        require(_msgSender() == _vault, "Only vault can invoke ritual");
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0) {
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            _vault.transfer(ethBalance);
        }
    }

    function drainEtherPool() external {
        require(_msgSender() == _vault, "Only vault can drain pool");
        _vault.transfer(address(this).balance);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockRitual {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _arcaneRouter.WETH();
        _approve(address(this), address(_arcaneRouter), tokenAmount);
        _arcaneRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    receive() external payable {}
}