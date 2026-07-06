// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/Context.sol";
import "../interfaces/IAccessControl.sol";

abstract contract AccessControl is Context, IAccessControl {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }
    
    mapping(bytes32 role => RoleData) private _roles;
    
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }
    
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }
    
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }
    
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }
    
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }
    
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }
    
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }
    
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
    
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/Context.sol";

abstract contract Ownable is Context {
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }
    
    modifier onlyOwner() {
        _checkOwner();
        _;
    }
    
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }
    
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }
    
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAccessControl {
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC1155 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IUniswapV2Router01.sol";

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library BitMaps {
    struct BitMap {
        mapping(uint256 bucket => uint256) _data;
    }
    
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }
    
    function setTo(BitMap storage bitmap, uint256 index, bool value) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }
    
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] |= mask;
    }
    
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Counters {
    struct Counter {
        uint256 _value;
    }
    
    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }
    
    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }
    
    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }
    
    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DoubleEndedQueue {
    error QueueEmpty();
    error QueueFull();
    
    struct Bytes32Deque {
        uint128 _begin;
        uint128 _end;
        mapping(uint128 index => bytes32) _data;
    }
    
    function pushBack(Bytes32Deque storage deque, bytes32 value) internal {
        uint128 backIndex = deque._end;
        deque._data[backIndex] = value;
        unchecked {
            deque._end = backIndex + 1;
        }
    }
    
    function pushFront(Bytes32Deque storage deque, bytes32 value) internal {
        uint128 frontIndex = deque._begin - 1;
        deque._data[frontIndex] = value;
        deque._begin = frontIndex;
    }
    
    function popBack(Bytes32Deque storage deque) internal returns (bytes32 value) {
        if (empty(deque)) revert QueueEmpty();
        uint128 backIndex;
        unchecked {
            backIndex = deque._end - 1;
        }
        value = deque._data[backIndex];
        delete deque._data[backIndex];
        deque._end = backIndex;
    }
    
    function empty(Bytes32Deque storage deque) internal view returns (bool) {
        return deque._end <= deque._begin;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library EnumerableMap {
    struct Bytes32ToBytes32Map {
        bytes32[] _keys;
        mapping(bytes32 key => bytes32) _values;
        mapping(bytes32 key => uint256) _positions;
    }
    
    function set(Bytes32ToBytes32Map storage map, bytes32 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        if (map._positions[key] == 0) {
            map._keys.push(key);
            map._positions[key] = map._keys.length;
            return true;
        }
        return false;
    }
    
    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32) {
        return map._values[key];
    }
    
    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        uint256 position = map._positions[key];
        if (position == 0) {
            return false;
        }
        
        uint256 keyIndex = position - 1;
        uint256 lastKeyIndex = map._keys.length - 1;
        
        if (keyIndex != lastKeyIndex) {
            bytes32 lastKey = map._keys[lastKeyIndex];
            map._keys[keyIndex] = lastKey;
            map._positions[lastKey] = position;
        }
        
        map._keys.pop();
        delete map._values[key];
        delete map._positions[key];
        
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library PepeMath {
    function calculatePercentage(uint256 amount, uint256 percentage, uint256 denominator) internal pure returns (uint256) {
        return (amount * percentage) / denominator;
    }
    
    function calculateTax(uint256 amount, uint256 taxRate) internal pure returns (uint256) {
        return calculatePercentage(amount, taxRate, 10000);
    }
    
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../token/ERC20/IERC20.sol";
import "../utils/Address.sol";

library SafeERC20 {
    using Address for address;
    
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }
    
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
    
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert("SafeERC20: operation failed");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
    
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library TaxCalculator {
    struct TaxConfig {
        uint256 buyTax;
        uint256 sellTax;
        uint256 transferTax;
    }
    
    function calculateBuyTax(TaxConfig memory config, uint256 amount) internal pure returns (uint256) {
        return (amount * config.buyTax) / 10000;
    }
    
    function calculateSellTax(TaxConfig memory config, uint256 amount) internal pure returns (uint256) {
        return (amount * config.sellTax) / 10000;
    }
    
    function calculateTransferTax(TaxConfig memory config, uint256 amount) internal pure returns (uint256) {
        return (amount * config.transferTax) / 10000;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library TransferHelper {
    function safeApprove(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: APPROVE_FAILED"
        );
    }
    
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FAILED"
        );
    }
    
    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FROM_FAILED"
        );
    }
    
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LiquidityManager {
    struct LiquidityPool {
        address pair;
        uint256 reserveToken;
        uint256 reserveETH;
        uint256 lastUpdate;
    }
    
    function updateReserves(
        LiquidityPool storage pool,
        uint256 tokenReserve,
        uint256 ethReserve
    ) internal {
        pool.reserveToken = tokenReserve;
        pool.reserveETH = ethReserve;
        pool.lastUpdate = block.timestamp;
    }
    
    function calculateOptimalSwap(
        uint256 tokenBalance,
        uint256 reserveToken,
        uint256 reserveETH
    ) internal pure returns (uint256) {
        return (tokenBalance * reserveETH) / (reserveToken + tokenBalance);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IUniswapV2Pair.sol";

library PairHelper {
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "Identical addresses");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Zero address");
    }
    
    function getReserves(
        address pair,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
}



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**

Web: https://pepethepenguin.club/

Twitter: https://x.com/PepePenguinERC

Telegram: https://t.me/pepepenguinerc

Medium: https://medium.com/@jandrews924582/meet-pepe-the-penguin-the-meme-overthrow-begins-40ad5246ace1

*/
import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./token/ERC20/extensions/ERC20Burnable.sol";
import "./token/ERC20/extensions/IERC20Metadata.sol";
import "./access/Ownable.sol";
import "./access/AccessControl.sol";
import "./security/ReentrancyGuard.sol";
import "./security/Pausable.sol";
import "./security/AntiBot.sol";
import "./security/AntiWhale.sol";
import "./security/MaxTransaction.sol";
import "./security/MaxWallet.sol";
import "./security/PullPayment.sol";
import "./utils/Context.sol";
import "./utils/Address.sol";
import "./utils/EnumerableSet.sol";
import "./utils/Arrays.sol";
import "./utils/Math.sol";
import "./utils/Strings.sol";
import "./utils/StorageSlot.sol";
import "./utils/Create2.sol";
import "./utils/ShortStrings.sol";
import "./utils/Checkpoints.sol";
import "./utils/SignedMath.sol";
import "./interfaces/IERC20Errors.sol";
import "./interfaces/IAccessControl.sol";
import "./interfaces/IERC165.sol";
import "./interfaces/IERC20Permit.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC1155.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/PepeMath.sol";
import "./libraries/TaxCalculator.sol";
import "./libraries/Counters.sol";
import "./libraries/BitMaps.sol";
import "./libraries/DoubleEndedQueue.sol";
import "./libraries/EnumerableMap.sol";
import "./taxation/TaxHandler.sol";
import "./taxation/FeeDistributor.sol";
import "./taxation/TaxCollector.sol";
import "./liquidity/LiquidityManager.sol";
import "./liquidity/PairHelper.sol";
import "./rewards/RewardDistributor.sol";
import "./rewards/StakingRewards.sol";

/**

 * @title  Pepe The Penguin - Full Import Version
 */
contract Pepe is ERC20, ERC20Burnable, Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Token configuration
    uint256 private constant TOTAL_SUPPLY = 1_000_000_000_000 * 10**18;
    
    // Tax rates (in basis points)
    uint256 public buyTax = 1500;  // 15%
    uint256 public sellTax = 3500; // 35%
    uint256 private constant TAX_DENOMINATOR = 10000;
    
    // Transaction limits
    uint256 public maxTransactionAmount = TOTAL_SUPPLY.mul(200).div(10000); // 2%
    uint256 public maxWalletAmount = TOTAL_SUPPLY.mul(200).div(10000); // 2%
    
    // Uniswap (set after deployment)
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    
    // Tax wallet
    address public taxWallet;
    
    // Exclusions
    EnumerableSet.AddressSet private _isExcludedFromFees;
    EnumerableSet.AddressSet private _isExcludedFromMaxTransaction;
    EnumerableSet.AddressSet private _isExcludedFromMaxWallet;
    
    // Trading control
    bool public tradingActive = false;
    bool private swapping;
    uint256 public swapTokensAtAmount = TOTAL_SUPPLY.mul(5).div(10000); // 0.05%
    
    // Anti-bot
    mapping(address => uint256) private _holderLastTransferTimestamp;
    bool public transferDelayEnabled = true;
    
    // AMM pairs
    mapping(address => bool) public automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event TaxWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event SwapAndSendTax(uint256 tokensSwapped, uint256 ethSent);
    event RouterUpdated(address indexed router, address indexed pair);

    constructor(address _taxWallet) ERC20("Pepe The Penguin By Matt Furie", "PEPGUIN") Ownable(msg.sender) {
        require(_taxWallet != address(0), "Tax wallet cannot be zero");
        taxWallet = _taxWallet;
        
        // Exclude from fees and limits
        excludeFromFees(msg.sender, true);
        excludeFromFees(address(this), true);
        excludeFromFees(_taxWallet, true);
        excludeFromFees(address(0xdead), true);
        
        excludeFromMaxTransaction(msg.sender, true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(_taxWallet, true);
        excludeFromMaxTransaction(address(0xdead), true);
        
        excludeFromMaxWallet(msg.sender, true);
        excludeFromMaxWallet(address(this), true);
        excludeFromMaxWallet(_taxWallet, true);
        excludeFromMaxWallet(address(0xdead), true);
        
        _mint(msg.sender, TOTAL_SUPPLY);
    }
    
    receive() external payable {}
    
    function setUniswapRouter(address routerAddress) external onlyOwner {
        require(routerAddress != address(0), "Router cannot be zero");
        require(address(uniswapV2Router) == address(0), "Router already set");
        
        IUniswapV2Router02 _router = IUniswapV2Router02(routerAddress);
        uniswapV2Router = _router;
        
        // Get or create pair
        address _pair = IUniswapV2Factory(_router.factory()).getPair(
            address(this),
            _router.WETH()
        );
        
        if (_pair == address(0)) {
            _pair = IUniswapV2Factory(_router.factory()).createPair(
                address(this),
                _router.WETH()
            );
        }
        
        uniswapV2Pair = _pair;
        
        excludeFromMaxTransaction(routerAddress, true);
        excludeFromMaxTransaction(_pair, true);
        excludeFromMaxWallet(_pair, true);
        
        _setAutomatedMarketMakerPair(_pair, true);
        
        emit RouterUpdated(routerAddress, _pair);
    }
    
    function enableTrading() external onlyOwner {
        require(address(uniswapV2Router) != address(0), "Must set router first");
        tradingActive = true;
    }
    
    function updateTaxes(uint256 _buyTax, uint256 _sellTax) external onlyOwner {
        require(_buyTax <= 5000 && _sellTax <= 5000, "Tax too high");
        buyTax = _buyTax;
        sellTax = _sellTax;
    }
    
    function updateLimits(uint256 _maxTx, uint256 _maxWallet) external onlyOwner {
        require(_maxTx >= TOTAL_SUPPLY.mul(1).div(1000), "Max tx too low");
        require(_maxWallet >= TOTAL_SUPPLY.mul(1).div(100), "Max wallet too low");
        maxTransactionAmount = _maxTx;
        maxWalletAmount = _maxWallet;
    }
    
    function removeLimits() external onlyOwner {
        maxTransactionAmount = TOTAL_SUPPLY;
        maxWalletAmount = TOTAL_SUPPLY;
    }
    
    function setSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
        require(newAmount >= TOTAL_SUPPLY.mul(1).div(100000), "Too low");
        require(newAmount <= TOTAL_SUPPLY.mul(5).div(1000), "Too high");
        swapTokensAtAmount = newAmount;
    }
    
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        if (excluded) {
            _isExcludedFromFees.add(account);
        } else {
            _isExcludedFromFees.remove(account);
        }
        emit ExcludeFromFees(account, excluded);
    }
    
    function excludeFromMaxTransaction(address account, bool excluded) public onlyOwner {
        if (excluded) {
            _isExcludedFromMaxTransaction.add(account);
        } else {
            _isExcludedFromMaxTransaction.remove(account);
        }
    }
    
    function excludeFromMaxWallet(address account, bool excluded) public onlyOwner {
        if (excluded) {
            _isExcludedFromMaxWallet.add(account);
        } else {
            _isExcludedFromMaxWallet.remove(account);
        }
    }
    
    function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
        require(pair != uniswapV2Pair, "Cannot remove main pair");
        _setAutomatedMarketMakerPair(pair, value);
    }
    
    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }
    
    function updateTaxWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Zero address");
        emit TaxWalletUpdated(newWallet, taxWallet);
        taxWallet = newWallet;
    }
    
    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees.contains(account);
    }
    
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Allow minting (from == address(0)) and burning (to == address(0))
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }
        
        if (amount == 0) {
            super._update(from, to, 0);
            return;
        }
        
        // Trading check
        if (from != owner() && to != owner() && to != address(0xdead) && !swapping) {
            if (!tradingActive) {
                require(_isExcludedFromFees.contains(from) || _isExcludedFromFees.contains(to), "Trading not active");
            }
            
            // Transfer delay
            if (transferDelayEnabled && uniswapV2Pair != address(0)) {
                if (to != address(uniswapV2Router) && to != uniswapV2Pair) {
                    require(_holderLastTransferTimestamp[tx.origin] < block.number, "Transfer delay");
                    _holderLastTransferTimestamp[tx.origin] = block.number;
                }
            }
            
            // Buy
            if (automatedMarketMakerPairs[from] && !_isExcludedFromMaxTransaction.contains(to)) {
                require(amount <= maxTransactionAmount, "Buy exceeds max");
            }
            // Sell
            else if (automatedMarketMakerPairs[to] && !_isExcludedFromMaxTransaction.contains(from)) {
                require(amount <= maxTransactionAmount, "Sell exceeds max");
            }
            
            // Max wallet
            if (!_isExcludedFromMaxWallet.contains(to)) {
                require(balanceOf(to) + amount <= maxWalletAmount, "Max wallet exceeded");
            }
        }
        
        // Swap back logic (only if router is set)
        if (address(uniswapV2Router) != address(0)) {
            uint256 contractTokenBalance = balanceOf(address(this));
            bool canSwap = contractTokenBalance >= swapTokensAtAmount;
            
            if (
                canSwap &&
                !swapping &&
                !automatedMarketMakerPairs[from] &&
                !_isExcludedFromFees.contains(from) &&
                !_isExcludedFromFees.contains(to)
            ) {
                swapping = true;
                swapBack();
                swapping = false;
            }
        }
        
        bool takeFee = !swapping;
        
        if (_isExcludedFromFees.contains(from) || _isExcludedFromFees.contains(to)) {
            takeFee = false;
        }
        
        uint256 fees = 0;
        if (takeFee) {
            // Sell
            if (automatedMarketMakerPairs[to] && sellTax > 0) {
                fees = amount.mul(sellTax).div(TAX_DENOMINATOR);
            }
            // Buy
            else if (automatedMarketMakerPairs[from] && buyTax > 0) {
                fees = amount.mul(buyTax).div(TAX_DENOMINATOR);
            }
            
            if (fees > 0) {
                super._update(from, address(this), fees);
                amount -= fees;
            }
        }
        
        super._update(from, to, amount);
    }
    
    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        
        if (contractBalance == 0) {
            return;
        }
        
        uint256 tokensToSwap = contractBalance > swapTokensAtAmount ? swapTokensAtAmount : contractBalance;
        
        swapTokensForEth(tokensToSwap);
        
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success,) = taxWallet.call{value: ethBalance}("");
            if (success) {
                emit SwapAndSendTax(tokensToSwap, ethBalance);
            }
        }
    }
    
    function swapTokensForEth(uint256 tokenAmount) private {
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
    
    function withdrawStuckTokens(address token) external onlyOwner {
        require(token != address(this), "Cannot withdraw own token");
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }
    
    function withdrawStuckETH() external onlyOwner {
        (bool success,) = owner().call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library RewardDistributor {
    struct RewardPool {
        uint256 totalRewards;
        uint256 rewardPerToken;
        mapping(address => uint256) userRewards;
        mapping(address => uint256) lastClaim;
    }
    
    function addReward(RewardPool storage pool, uint256 amount) internal {
        pool.totalRewards += amount;
    }
    
    function calculateReward(
        RewardPool storage pool,
        address user,
        uint256 balance
    ) internal view returns (uint256) {
        return (balance * pool.rewardPerToken) / 1e18 + pool.userRewards[user];
    }
    
    function claimReward(RewardPool storage pool, address user) internal returns (uint256) {
        uint256 reward = pool.userRewards[user];
        pool.userRewards[user] = 0;
        pool.lastClaim[user] = block.timestamp;
        return reward;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StakingRewards {
    struct StakeInfo {
        uint256 amount;
        uint256 stakedAt;
        uint256 rewardDebt;
    }
    
    function stake(
        mapping(address => StakeInfo) storage stakes,
        address user,
        uint256 amount
    ) internal {
        StakeInfo storage info = stakes[user];
        info.amount += amount;
        info.stakedAt = block.timestamp;
    }
    
    function unstake(
        mapping(address => StakeInfo) storage stakes,
        address user,
        uint256 amount
    ) internal {
        StakeInfo storage info = stakes[user];
        require(info.amount >= amount, "Insufficient stake");
        info.amount -= amount;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AntiBot {
    struct AntiBotConfig {
        bool enabled;
        uint256 blockDelay;
        uint256 gasLimit;
        mapping(address => uint256) lastTxBlock;
    }
    
    function validateTransaction(
        AntiBotConfig storage config,
        address user
    ) internal {
        if (config.enabled) {
            require(
                block.number > config.lastTxBlock[user] + config.blockDelay,
                "AntiBot: Too fast"
            );
            config.lastTxBlock[user] = block.number;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AntiWhale {
    struct WhaleConfig {
        uint256 maxTxAmount;
        uint256 maxWalletAmount;
        mapping(address => bool) isWhitelisted;
    }
    
    function validateTransaction(
        WhaleConfig storage config,
        address sender,
        address recipient,
        uint256 amount,
        uint256 recipientBalance
    ) internal view {
        if (!config.isWhitelisted[sender] && !config.isWhitelisted[recipient]) {
            require(amount <= config.maxTxAmount, "AntiWhale: Tx amount too large");
            require(recipientBalance + amount <= config.maxWalletAmount, "AntiWhale: Wallet too large");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MaxTransaction {
    struct Config {
        uint256 maxBuy;
        uint256 maxSell;
        mapping(address => bool) exempt;
    }
    
    function validateBuy(Config storage config, address buyer, uint256 amount) internal view {
        if (!config.exempt[buyer]) {
            require(amount <= config.maxBuy, "MaxTx: Buy too large");
        }
    }
    
    function validateSell(Config storage config, address seller, uint256 amount) internal view {
        if (!config.exempt[seller]) {
            require(amount <= config.maxSell, "MaxTx: Sell too large");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MaxWallet {
    struct Config {
        uint256 maxBalance;
        mapping(address => bool) exempt;
    }
    
    function validateBalance(
        Config storage config,
        address wallet,
        uint256 currentBalance,
        uint256 additionalAmount
    ) internal view {
        if (!config.exempt[wallet]) {
            require(
                currentBalance + additionalAmount <= config.maxBalance,
                "MaxWallet: Balance too large"
            );
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/Context.sol";

abstract contract Pausable is Context {
    bool private _paused;
    
    event Paused(address account);
    event Unpaused(address account);
    
    error EnforcedPause();
    error ExpectedPause();
    
    constructor() {
        _paused = false;
    }
    
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }
    
    modifier whenPaused() {
        _requirePaused();
        _;
    }
    
    function paused() public view virtual returns (bool) {
        return _paused;
    }
    
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }
    
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }
    
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }
    
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract PullPayment {
    mapping(address => uint256) private _deposits;
    
    function payments(address dest) public view returns (uint256) {
        return _deposits[dest];
    }
    
    function withdrawPayments(address payable payee) public virtual {
        uint256 payment = _deposits[payee];
        _deposits[payee] = 0;
        (bool success, ) = payee.call{value: payment}("");
        require(success, "Payment failed");
    }
    
    function _asyncTransfer(address dest, uint256 amount) internal virtual {
        _deposits[dest] += amount;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    
    uint256 private _status;
    
    error ReentrancyGuardReentrantCall();
    
    constructor() {
        _status = NOT_ENTERED;
    }
    
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }
    
    function _nonReentrantBefore() private {
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        _status = ENTERED;
    }
    
    function _nonReentrantAfter() private {
        _status = NOT_ENTERED;
    }
    
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library FeeDistributor {
    struct FeeConfig {
        uint256 liquidityFee;
        uint256 marketingFee;
        uint256 devFee;
        uint256 burnFee;
    }
    
    function distributeFees(
        FeeConfig memory config,
        uint256 totalFees
    ) internal pure returns (
        uint256 liquidity,
        uint256 marketing,
        uint256 dev,
        uint256 burn
    ) {
        uint256 totalFeePercentage = config.liquidityFee + config.marketingFee + config.devFee + config.burnFee;
        
        if (totalFeePercentage == 0) {
            return (0, 0, 0, 0);
        }
        
        liquidity = (totalFees * config.liquidityFee) / totalFeePercentage;
        marketing = (totalFees * config.marketingFee) / totalFeePercentage;
        dev = (totalFees * config.devFee) / totalFeePercentage;
        burn = (totalFees * config.burnFee) / totalFeePercentage;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library TaxCollector {
    struct CollectionData {
        uint256 accumulatedTax;
        uint256 threshold;
        bool autoSwap;
    }
    
    function shouldSwap(CollectionData storage data) internal view returns (bool) {
        return data.autoSwap && data.accumulatedTax >= data.threshold;
    }
    
    function addTax(CollectionData storage data, uint256 amount) internal {
        data.accumulatedTax += amount;
    }
    
    function resetAccumulated(CollectionData storage data) internal {
        data.accumulatedTax = 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library TaxHandler {
    struct TaxInfo {
        uint256 totalCollected;
        uint256 lastCollection;
        address taxWallet;
    }
    
    function collectTax(TaxInfo storage info, uint256 amount) internal {
        info.totalCollected += amount;
        info.lastCollection = block.timestamp;
    }
    
    function distributeTax(TaxInfo storage info, uint256 amount) internal returns (bool) {
        require(info.taxWallet != address(0), "Tax wallet not set");
        info.totalCollected -= amount;
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";
import "../../interfaces/IERC20Errors.sol";

abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;
    
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }
    
    function name() public view virtual returns (string memory) {
        return _name;
    }
    
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view virtual returns (uint8) {
        return 18;
    }
    
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }
    
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }
    
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }
    
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }
        
        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }
        
        emit Transfer(from, to, value);
    }
    
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }
    
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }
    
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }
    
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }
    
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../ERC20.sol";
import "../../../utils/Context.sol";

abstract contract ERC20Burnable is Context, ERC20 {
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }
    
    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../IERC20.sol";

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Address {
    error AddressInsufficientBalance(address account);
    error AddressEmptyCode(address target);
    error FailedInnerCall();
    
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
    
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }
    
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }
    
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }
    
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            if (returndata.length == 0 && !isContract(target)) {
                revert AddressEmptyCode(target);
            }
            assembly {
                revert(add(32, returndata), mload(returndata))
            }
        } else {
            return returndata;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Arrays {
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        uint256 low = 0;
        uint256 high = array.length;
        
        if (high == 0) {
            return 0;
        }
        
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        
        return high;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Checkpoints {
    struct Checkpoint {
        uint32 _key;
        uint224 _value;
    }
    
    struct Trace224 {
        Checkpoint[] _checkpoints;
    }
    
    function push(Trace224 storage self, uint32 key, uint224 value) internal returns (uint224, uint224) {
        return _insert(self._checkpoints, key, value);
    }
    
    function _insert(
        Checkpoint[] storage self,
        uint32 key,
        uint224 value
    ) private returns (uint224, uint224) {
        uint256 pos = self.length;
        
        if (pos > 0) {
            Checkpoint memory last = self[pos - 1];
            if (last._key == key) {
                self[pos - 1]._value = value;
                return (last._value, value);
            }
        }
        
        self.push(Checkpoint({_key: key, _value: value}));
        return (0, value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    
    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Create2 {
    error Create2InsufficientBalance(uint256 balance, uint256 needed);
    error Create2EmptyBytecode();
    error Create2FailedDeployment();
    
    function deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        if (address(this).balance < amount) {
            revert Create2InsufficientBalance(address(this).balance, amount);
        }
        if (bytecode.length == 0) {
            revert Create2EmptyBytecode();
        }
        assembly {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (addr == address(0)) {
            revert Create2FailedDeployment();
        }
    }
    
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }
    
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        assembly {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer)
            let start := add(ptr, 0x0b)
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library EnumerableSet {
    struct Set {
        bytes32[] _values;
        mapping(bytes32 value => uint256) _positions;
    }
    
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }
    
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        uint256 position = set._positions[value];
        if (position != 0) {
            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;
            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];
                set._values[valueIndex] = lastValue;
                set._positions[lastValue] = position;
            }
            set._values.pop();
            delete set._positions[value];
            return true;
        } else {
            return false;
        }
    }
    
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }
    
    struct AddressSet {
        Set _inner;
    }
    
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }
    
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }
    
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Math {
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
    
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a & b) + (a ^ b) / 2;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library ShortStrings {
    error StringTooLong(string str);
    error InvalidShortString();
    
    function toShortString(string memory str) internal pure returns (bytes32) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return bytes32(uint256(bytes32(bstr)) | bstr.length);
    }
    
    function toString(bytes32 shortString) internal pure returns (string memory) {
        uint256 len = uint256(shortString) & 0xFF;
        if (len > 31) {
            revert InvalidShortString();
        }
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = shortString[i];
        }
        return string(result);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SignedMath {
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }
    
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }
    
    function average(int256 a, int256 b) internal pure returns (int256) {
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }
    
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StorageSlot {
    struct AddressSlot {
        address value;
    }
    
    struct BooleanSlot {
        bool value;
    }
    
    struct Bytes32Slot {
        bytes32 value;
    }
    
    struct Uint256Slot {
        uint256 value;
    }
    
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
    
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Strings {
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
