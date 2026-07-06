// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Oracle/ChainlinkETHUSDPriceConsumer.sol";
import "../Oracle/ChainlinkXAGUSDPriceConsumer.sol";

interface ITreasuryPool {
    function withdrawETHForFunction(uint256 amount) external returns (bool);
    function updateLastExecutionTimestamp(uint256 timestamp) external;
    function receiveETH(uint256 amount) external payable;
    function receiveXSD(uint256 amount) external;
}

interface IPIDController {
    function xsd_updated_price() external view returns (uint256);
    function bankx_updated_price() external view returns (uint256);
    function global_collateral_ratio() external view returns (uint256);
    function bucket1() external view returns (bool);
    function bucket2() external view returns (bool);
    function diff1() external view returns (uint);
    function diff2() external view returns (uint);
    function amountpaid1() external view returns (uint);
    function amountpaid2() external view returns (uint);
    function systemCalculations() external;
}

interface IRouter {
    function swapETHForXSD(uint256 amountOutMin, uint256 deadline) external payable;
    function userAddLiquidityETH(address pool, uint256 deadline) external payable;
    function swapETHForBankX(uint256 amountOutMin, uint256 deadline) external payable;
}

interface IXSDWETHPool {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IBankXWETHPool {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IRewardManager {
    function userProvideXSDLiquidity(address to) external;
    function userProvideBankXLiquidity(address to) external;
}

interface IBankX {
    function burn(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract RulesEngine is Ownable, Pausable, ReentrancyGuard {
    address public treasuryPool;
    address public ethUsdFeed;
    address public silverUsdFeed;
    address public bankxPidController;
    address public rewardManager;
    address public router;
    address public xsdWethPool;
    address public bankxWethPool;
    address public xsdToken;
    address public bankxToken;
    
    uint256 public lastExecutionTimestamp;
    
    // XSD Purchase parameters
    bool public pidRunCompleted;
    uint256 public lastPidCalculationTimestamp;
    uint256 public minTimeBetweenSteps = 10; // 10 seconds
    uint256 public pegThreshold = 500; // 5% (basis points)
    uint256 public purchaseAmountUsd = 10000000; // $10 with 6 decimals
    uint256 public maxSlippage = 150; // In tenths of a percent (15.0%)
    uint256 public gasCostBuffer = 1000000000000000; // 0.001 ETH
    uint256 public transactionDeadlineWindow = 300; // 5 minutes
    
    // Liquidity Sell parameters
    bool public liquidityPidRunCompleted;
    uint256 public lastLiquidityPidCalculationTimestamp;
    
    // BankX Buy and Burn parameters
    uint256 public bankxPurchaseAmountUsd = 10000000; // $10 with 6 decimals
    uint256 public bankxMaxSlippage = 200; // In tenths of a percent (20.0%)
    uint256 public unburnedBankXBalance;
    bool public bankxPidRunCompleted;
    uint256 public lastBankxPidCalculationTimestamp;
    uint256 public lastBankxBurnTimestamp;
    uint256 public burnCooldown = 86400; // 24 hours
    
    // New tracking variables
    uint256 public totalBankXPurchased;
    uint256 public totalBankXBurned;

    uint256 private constant PRICE_PRECISION = 1e18; // Increased from 1e6 to 1e18
    uint256 private constant BASIS_POINTS = 10000; // Remain at 10000 for basis points
    uint256 private constant HIGH_PRECISION = 1e18; // Added for high precision calculations
    
    event RulesEngineExecuted(uint256 timestamp);
    event PIDCalculationCompleted(uint256 timestamp, bool success);
    event XSDBought(uint256 ethAmount, uint256 xsdAmount, uint256 timestamp);
    event BuyFailed(string reason, uint256 timestamp);
    event XSDTransferredToTreasury(uint256 amount, uint256 timestamp);
    event LiquidityPidCalculationCompleted(uint256 timestamp, bool success);
    event LiquiditySellInitiated(uint256 availableCapacity, uint256 timestamp);
    event LiquiditySold(uint256 ethAmount, uint256 timestamp);
    event LiquiditySellFailed(string reason, uint256 timestamp);
    event ETHWithdrawnForLiquidity(uint256 amount, uint256 timestamp);
    event DeficitValidated(uint256 capacity, uint256 timestamp);
    event BankXPidCalculationCompleted(uint256 timestamp, bool success);
    event BankXBuyInitiated(uint256 ethAmount, uint256 timestamp);
    event BankXBought(uint256 ethAmount, uint256 bankxAmount, uint256 timestamp);
    event SlippageValidated(uint256 slippage, uint256 maxSlippage, uint256 timestamp);
    event ETHWithdrawnForBankX(uint256 amount, uint256 timestamp);
    event BankXBurnAttempted(uint256 amount, uint256 timestamp);
    event BankXBurned(uint256 amount, uint256 timestamp);
    event BankXBurnFailed(string reason, uint256 amount, uint256 timestamp);
    event NumericalCheck(string operation, uint256 value1, uint256 value2, bool passed);

    constructor(
        address _ethUsdFeed,
        address _silverUsdFeed,
        address _treasuryPool,
        address _bankxPidController,
        address _router,
        address _xsdWethPool,
        address _bankxWethPool,
        address _xsdToken,
        address _bankxToken,
        address _rewardManager
    ) Ownable() {
        require(
            _ethUsdFeed != address(0) &&
            _silverUsdFeed != address(0) &&
            _treasuryPool != address(0) &&
            _bankxPidController != address(0) &&
            _router != address(0) &&
            _xsdWethPool != address(0) &&
            _bankxWethPool != address(0) &&
            _xsdToken != address(0) &&
            _bankxToken != address(0) &&
            _rewardManager != address(0),
            "Rules Engine: Zero address detected"
        );
        
        ethUsdFeed = _ethUsdFeed;
        silverUsdFeed = _silverUsdFeed;
        treasuryPool = _treasuryPool;
        bankxPidController = _bankxPidController;
        router = _router;
        xsdWethPool = _xsdWethPool;
        bankxWethPool = _bankxWethPool;
        xsdToken = _xsdToken;
        bankxToken = _bankxToken;
        rewardManager = _rewardManager;
        
        lastExecutionTimestamp = block.timestamp;
    }

    function executeRules() external nonReentrant whenNotPaused returns (bool) {
        uint256 currentTimestamp = block.timestamp;
        
        // Priority 1: XSD below peg
        if (_checkXsdBelowPeg()) {
            if (pidRunCompleted) {
                if (block.timestamp >= lastPidCalculationTimestamp + minTimeBetweenSteps) {
                    _executeXsdBuyAfterPidRun();
                }
            } else {
                _initiateXsdPurchasePidRun();
            }
        }
        // Priority 2: Liquidity selling
        else if (_checkXsdAtPeg() && _canSellLiquidity()) {
            if (liquidityPidRunCompleted) {
                if (block.timestamp >= lastLiquidityPidCalculationTimestamp + minTimeBetweenSteps) {
                    _executeXsdLiquiditySell();
                }
            } else {
                _initiateLiquidityPidRun();
            }
        }
        // Priority 3: BankX buy and burn
        else if (_checkXsdAtPeg() && _canBuyAndBurnBankX()) {
            if (bankxPidRunCompleted) {
                if (block.timestamp >= lastBankxPidCalculationTimestamp + minTimeBetweenSteps) {
                    _executeBankxBuyAfterPidRun();
                }
            } else {
                _initiateBankxPurchasePidRun();
            }
        }
        
        lastExecutionTimestamp = currentTimestamp;
        ITreasuryPool(treasuryPool).updateLastExecutionTimestamp(currentTimestamp);
        
        // Check for BankX burn opportunity
        _attemptBankXBurn();
        
        emit RulesEngineExecuted(currentTimestamp);
        return true;
    }

    function getNativeTokenPrice() public view returns (uint256) {
        (int256 price) = ChainlinkETHUSDPriceConsumer(ethUsdFeed).getLatestPrice();
        require(price > 0, "Rules Engine: Invalid ETH/USD price");
        uint8 decimals = ChainlinkETHUSDPriceConsumer(ethUsdFeed).getDecimals();
        
        // Convert to HIGH_PRECISION for maximum precision
        uint256 priceWithPrecision;
        if (decimals < 18) {
            priceWithPrecision = uint256(price) * (10 ** (18 - decimals));
        } else {
            priceWithPrecision = uint256(price) / (10 ** (decimals - 18));
        }
        
        // Add safety check for unusually low values
        require(priceWithPrecision > 0, "Rules Engine: Price converted to zero");
        
        return priceWithPrecision;
    }

    function getSilverPrice() public view returns (uint256) {
        (int256 price) = ChainlinkXAGUSDPriceConsumer(silverUsdFeed).getLatestPrice();
        require(price > 0, "Rules Engine: Invalid Silver/USD price");
        uint8 decimals = ChainlinkXAGUSDPriceConsumer(silverUsdFeed).getDecimals();
        
        // Convert to HIGH_PRECISION for maximum precision
        uint256 priceWithPrecision;
        if (decimals < 18) {
            priceWithPrecision = uint256(price) * (10 ** (18 - decimals));
        } else {
            priceWithPrecision = uint256(price) / (10 ** (decimals - 18));
        }
        
        // Add safety check for unusually low values
        require(priceWithPrecision > 0, "Rules Engine: Price converted to zero");
        
        return priceWithPrecision;
    }

    function getBankXBalance() public view returns (uint256) {
        return IBankX(bankxToken).balanceOf(address(this)) + unburnedBankXBalance;
    }

    function _checkXsdBelowPeg() private returns (bool) {
        uint256 xsdPrice = IPIDController(bankxPidController).xsd_updated_price();
        // Convert the price to high precision
        xsdPrice = xsdPrice * (PRICE_PRECISION / 1e6);
        
        uint256 silverPrice = getSilverPrice();
        uint256 thresholdPrice = (silverPrice * (BASIS_POINTS - pegThreshold)) / BASIS_POINTS;
        
        emit NumericalCheck("XSD below peg check", xsdPrice, thresholdPrice, xsdPrice < thresholdPrice);
        
        return xsdPrice < thresholdPrice;
    }

    function _checkXsdAtPeg() private returns (bool) {
        uint256 xsdPrice = IPIDController(bankxPidController).xsd_updated_price();
        // Convert the price to high precision
        xsdPrice = xsdPrice * (PRICE_PRECISION / 1e6);
        
        uint256 silverPrice = getSilverPrice();
        uint256 lowerBound = (silverPrice * (BASIS_POINTS - pegThreshold)) / BASIS_POINTS;
        uint256 upperBound = (silverPrice * (BASIS_POINTS + pegThreshold)) / BASIS_POINTS;
        
        bool inRange = (xsdPrice >= lowerBound && xsdPrice <= upperBound);
        emit NumericalCheck("XSD at peg check", xsdPrice, silverPrice, inRange);
        
        return inRange;
    }

    function _initiateXsdPurchasePidRun() private {
        IPIDController(bankxPidController).systemCalculations();
        pidRunCompleted = true;
        lastPidCalculationTimestamp = block.timestamp;
        emit PIDCalculationCompleted(block.timestamp, true);
    }

    function _executeXsdBuyAfterPidRun() private {
        if (!_checkXsdBelowPeg()) {
            emit BuyFailed("XSD not below peg", block.timestamp);
            return;
        }

        // Get high precision ETH price
        uint256 ethUsdPrice = getNativeTokenPrice();
        
        // FIX 3: Simplified ETH amount calculation
        // purchaseAmountUsd has 6 decimals, ethUsdPrice has 18 decimals
        // To get ETH (18 decimals): (USD_6 * 1e18) / price_18 = (USD * 1e24) / price_18 = ETH_18
        uint256 ethAmount = (purchaseAmountUsd * 1e30) / ethUsdPrice;
        
        if (ethAmount == 0) {
            emit BuyFailed("ETH amount calculated as zero", block.timestamp);
            return;
        }
        emit NumericalCheck("ETH amount calculation", ethAmount, gasCostBuffer, ethAmount > 0);
        
        uint256 totalEthNeeded = ethAmount + gasCostBuffer;

        (uint112 xsdReserve, uint112 wethReserve) = _getPoolData();
        if (xsdReserve == 0 || wethReserve == 0) {
            emit BuyFailed("Pool reserves are zero", block.timestamp);
            return;
        }

        address payable treasuryPoolPayable = payable(treasuryPool);
        if (treasuryPoolPayable.balance < totalEthNeeded) {
            emit BuyFailed("Insufficient ETH", block.timestamp);
            return;
        }

        bool withdrawSuccess = ITreasuryPool(treasuryPool).withdrawETHForFunction(totalEthNeeded);
        if (!withdrawSuccess) {
            emit BuyFailed("ETH withdrawal failed", block.timestamp);
            return;
        }
        
        // FIX 3: Use pool reserves for expected output calculation
        uint256 expectedXsdOut = (ethAmount * uint256(xsdReserve)) / uint256(wethReserve);
        
        if (expectedXsdOut == 0) {
            emit BuyFailed("Expected XSD output is zero", block.timestamp);
            _returnETHToTreasury(ethAmount);
            return;
        }
        
        // Convert admin-set slippage (in tenths of percent) to basis points
        uint256 slippageBasisPoints = maxSlippage * 10;
        uint256 minXsdOut = (expectedXsdOut * (BASIS_POINTS - slippageBasisPoints)) / BASIS_POINTS;
        uint256 deadline = block.timestamp + transactionDeadlineWindow;

        // FIX 1: Removed unnecessary approval
        // FIX 2: Track XSD balance before and after swap
        uint256 xsdBalanceBefore = IERC20(xsdToken).balanceOf(address(this));
        IRouter(router).swapETHForXSD{value: ethAmount}(minXsdOut, deadline);
        uint256 xsdBalanceAfter = IERC20(xsdToken).balanceOf(address(this));
        uint256 xsdReceived = xsdBalanceAfter - xsdBalanceBefore;

        // Need to approve Treasury Pool to take the XSD via transferFrom
        IERC20(xsdToken).approve(treasuryPool, xsdReceived);
        ITreasuryPool(treasuryPool).receiveXSD(xsdReceived);
        emit XSDTransferredToTreasury(xsdReceived, block.timestamp);

        pidRunCompleted = false;
        emit XSDBought(ethAmount, xsdReceived, block.timestamp);
    }

    function _canSellLiquidity() private view returns (bool) {
        bool inDeficit = IPIDController(bankxPidController).bucket1();
        if (!inDeficit) {
            return false;
        }
        
        uint256 deficit = IPIDController(bankxPidController).diff1();
        uint256 amountPaid = IPIDController(bankxPidController).amountpaid1();
        
        if (deficit <= amountPaid) {
            return false;
        }
        
        return true;
    }

    function _initiateLiquidityPidRun() private {
        IPIDController(bankxPidController).systemCalculations();
        liquidityPidRunCompleted = true;
        lastLiquidityPidCalculationTimestamp = block.timestamp;
        emit LiquidityPidCalculationCompleted(block.timestamp, true);
    }

    function _executeXsdLiquiditySell() private {
        uint256 deficit = IPIDController(bankxPidController).diff1();
        uint256 amountPaid = IPIDController(bankxPidController).amountpaid1();
        
        uint256 availableCapacity = deficit - amountPaid;
        emit DeficitValidated(availableCapacity, block.timestamp);
        emit LiquiditySellInitiated(availableCapacity, block.timestamp);
        
        address payable treasuryPoolPayable = payable(treasuryPool);
        
        // First, ensure we have enough for gas buffer
        if (treasuryPoolPayable.balance <= gasCostBuffer) {
            emit LiquiditySellFailed("Insufficient ETH for gas", block.timestamp);
            return;
        }
        
        // Calculate max ETH after reserving gas buffer
        uint256 maxEthAmount = ((treasuryPoolPayable.balance - gasCostBuffer) * 95) / 100;
        
        // Get high precision ETH price
        uint256 ethUsdPrice = getNativeTokenPrice();
        
        // Convert with higher precision
        uint256 availableCapacityHighPrecision = availableCapacity * (PRICE_PRECISION / 1e6);
        uint256 capacityInEth = (availableCapacityHighPrecision * PRICE_PRECISION) / ethUsdPrice;
        uint256 ethAmount = maxEthAmount < capacityInEth ? maxEthAmount : capacityInEth;
        
        if (ethAmount == 0) {
            emit LiquiditySellFailed("Calculated ETH amount is zero", block.timestamp);
            return;
        }
        emit NumericalCheck("Liquidity sell ETH amount", ethAmount, availableCapacity, ethAmount > 0);
        
        // Now totalEthNeeded is guaranteed to be <= treasuryPoolPayable.balance
        uint256 totalEthNeeded = ethAmount + gasCostBuffer;
        
        bool success = ITreasuryPool(treasuryPool).withdrawETHForFunction(totalEthNeeded);
        if (!success) {
            emit LiquiditySellFailed("Failed to withdraw ETH from Treasury Pool", block.timestamp);
            return;
        }
        emit ETHWithdrawnForLiquidity(totalEthNeeded, block.timestamp);
        
        uint256 deadline = block.timestamp + transactionDeadlineWindow;
        
        IRouter(router).userAddLiquidityETH{value: ethAmount}(xsdWethPool, deadline);
        emit LiquiditySold(ethAmount, block.timestamp);
        
        liquidityPidRunCompleted = false;
    }

    function _initiateBankxPurchasePidRun() private {
        IPIDController(bankxPidController).systemCalculations();
        bankxPidRunCompleted = true;
        lastBankxPidCalculationTimestamp = block.timestamp;
        emit BankXPidCalculationCompleted(block.timestamp, true);
    }

    function _executeBankxBuyAfterPidRun() private {
        if (!_checkXsdAtPeg()) {
            emit BankXBurnFailed("XSD not at peg", 0, block.timestamp);
            return;
        }

        if (_canSellLiquidity()) {
            emit BankXBurnFailed("Liquidity capacity available", 0, block.timestamp);
            return;
        }

       // CHECK RESERVES FIRST - BEFORE ANY ETH OPERATIONS
        (uint112 bankxReserve, uint112 wethReserve) = _getBankxPoolData();
        if (bankxReserve == 0 || wethReserve == 0) {
        emit BankXBurnFailed("Pool reserves are zero", 0, block.timestamp);
        return;
        }

        // Get high precision ETH price
        uint256 ethUsdPrice = getNativeTokenPrice();
        
        // Use same calculation as XSD
        uint256 ethAmount = (bankxPurchaseAmountUsd * 1e30) / ethUsdPrice;
        
        if (ethAmount == 0) {
            emit BankXBurnFailed("ETH amount calculated as zero", 0, block.timestamp);
            return;
        }
        emit NumericalCheck("BankX ETH amount calculation", ethAmount, bankxPurchaseAmountUsd, ethAmount > 0);
        
        uint256 totalEthNeeded = ethAmount + gasCostBuffer;

        address payable treasuryPoolPayable = payable(treasuryPool);
        if (treasuryPoolPayable.balance < totalEthNeeded) {
            emit BankXBurnFailed("Insufficient ETH", 0, block.timestamp);
            return;
        }

        bool withdrawSuccess = ITreasuryPool(treasuryPool).withdrawETHForFunction(totalEthNeeded);
        if (!withdrawSuccess) {
            emit BankXBurnFailed("ETH withdrawal failed", 0, block.timestamp);
            return;
        }
        emit ETHWithdrawnForBankX(totalEthNeeded, block.timestamp);
        
        // Use same calculation as XSD
        uint256 expectedBankxOut = (ethAmount * uint256(bankxReserve)) / uint256(wethReserve);

        // Convert admin-set slippage (in tenths of percent) to basis points
        uint256 slippageBasisPoints = bankxMaxSlippage * 10;
        emit SlippageValidated(slippageBasisPoints, bankxMaxSlippage, block.timestamp);

        if (expectedBankxOut == 0) {
            emit BankXBurnFailed("Expected BankX output is zero", 0, block.timestamp);
            _returnETHToTreasury(totalEthNeeded);
            return;
        }

        uint256 minBankxOut = (expectedBankxOut * (BASIS_POINTS - slippageBasisPoints)) / BASIS_POINTS;
        uint256 deadline = block.timestamp + transactionDeadlineWindow;

        // FIX 4: Track BankX balance before and after swap
        uint256 bankxBalanceBefore = IERC20(bankxToken).balanceOf(address(this));
        
        // FIX 1: Execute swap without expecting return value
        IRouter(router).swapETHForBankX{value: ethAmount}(minBankxOut, deadline);
        
        // FIX 4: Calculate received amount
        uint256 bankxBalanceAfter = IERC20(bankxToken).balanceOf(address(this));
        uint256 bankxReceived = bankxBalanceAfter - bankxBalanceBefore;
        
        totalBankXPurchased += bankxReceived;
        
        emit BankXBought(ethAmount, bankxReceived, block.timestamp);

        bankxPidRunCompleted = false;
    }

    function _attemptBankXBurn() private {
        if (block.timestamp < lastBankxBurnTimestamp + burnCooldown) {
            return;
        }

        uint256 bankxBalance = IBankX(bankxToken).balanceOf(address(this));
        bankxBalance += unburnedBankXBalance;
        
        if (bankxBalance == 0) {
            return;
        }
        
        emit BankXBurnAttempted(bankxBalance, block.timestamp);
        
        // Store current balance before burn attempt
        uint256 balanceBefore = IBankX(bankxToken).balanceOf(address(this));
        
        // Attempt to burn
        IBankX(bankxToken).burn(bankxBalance);
        
        // Check if burn was successful by comparing balances
        uint256 balanceAfter = IBankX(bankxToken).balanceOf(address(this));
        
        if (balanceBefore > balanceAfter) {
            // Burn was successful (at least partially)
            uint256 burnedAmount = balanceBefore - balanceAfter;
            unburnedBankXBalance = bankxBalance - burnedAmount;
            lastBankxBurnTimestamp = block.timestamp;
            totalBankXBurned += burnedAmount;
            emit BankXBurned(burnedAmount, block.timestamp);
        } else {
            // Burn failed completely
            unburnedBankXBalance = bankxBalance;
            emit BankXBurnFailed("Burn operation failed", bankxBalance, block.timestamp);
        }
    }

    function _getPoolData() private view returns (uint112 xsdReserve, uint112 wethReserve) {
        (xsdReserve, wethReserve, ) = IXSDWETHPool(xsdWethPool).getReserves();
        return (xsdReserve, wethReserve);
    }

    function _getBankxPoolData() private view returns (uint112 bankxReserve, uint112 wethReserve) {
        (bankxReserve, wethReserve, ) = IBankXWETHPool(bankxWethPool).getReserves();
        return (bankxReserve, wethReserve);
    }

    function _canBuyAndBurnBankX() private returns (bool) {
        address payable treasuryPoolPayable = payable(treasuryPool);
        
        // Get high precision ETH price
        uint256 ethUsdPrice = getNativeTokenPrice();
        
        // Calculate minimum ETH amount with same pattern as XSD
        uint256 minBankxPurchaseUsd = 5000000; // $5 with 6 decimals (lower threshold)
        uint256 minEthAmount = (minBankxPurchaseUsd * 1e30) / ethUsdPrice;
        
        // Add buffer to minimum required amount
        uint256 minRequiredAmount = minEthAmount + gasCostBuffer;
        
        bool hasEnoughETH = treasuryPoolPayable.balance > minRequiredAmount;
        emit NumericalCheck("BankX purchase check", treasuryPoolPayable.balance, minRequiredAmount, hasEnoughETH);
        
        return hasEnoughETH;
    }

    function _returnETHToTreasury(uint256 amount) private {
        ITreasuryPool(treasuryPool).receiveETH{value: amount}(amount);
    }

    // Helper function to extract error message from revert reason bytes
    function _extractErrorMessage(bytes memory reason) private pure returns (string memory) {
        if (reason.length > 0) {
            // Try to extract error message if it's a standard revert reason
            // This works for standard revert("message") style errors
            if (reason.length > 4 && reason[0] == 0x08 && reason[1] == 0xc3 && 
                reason[2] == 0x79 && reason[3] == 0xa0) {
                // Standard revert
                uint256 strLength;
                assembly {
                    strLength := mload(add(reason, 36))
                }
                
                bytes memory strBytes = new bytes(strLength);
                for (uint256 i = 0; i < strLength; i++) {
                    strBytes[i] = reason[i + 68];
                }
                
                return string(strBytes);
            }
            return "Unknown error";
        }
        return "Empty error reason";
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function resetPidRunState() external onlyOwner {
        pidRunCompleted = false;
        lastPidCalculationTimestamp = 0;
        liquidityPidRunCompleted = false;
        lastLiquidityPidCalculationTimestamp = 0;
        bankxPidRunCompleted = false;
        lastBankxPidCalculationTimestamp = 0;
    }

    function setPurchaseAmountUsd(uint256 _purchaseAmountUsd) external onlyOwner {
        require(_purchaseAmountUsd > 0, "Purchase amount must be > 0");
        purchaseAmountUsd = _purchaseAmountUsd;
    }

    function setBankxPurchaseAmountUsd(uint256 _bankxPurchaseAmountUsd) external onlyOwner {
        require(_bankxPurchaseAmountUsd > 0, "Purchase amount must be > 0");
        bankxPurchaseAmountUsd = _bankxPurchaseAmountUsd;
    }

    function setPegThreshold(uint256 _pegThreshold) external onlyOwner {
        require(_pegThreshold > 0 && _pegThreshold <= 1500, "Invalid peg threshold");
        pegThreshold = _pegThreshold;
    }

    function setMaxSlippage(uint256 _maxSlippage) external onlyOwner {
        require(_maxSlippage > 0 && _maxSlippage <= 500, "Invalid max slippage (0.1%-50%)");
        maxSlippage = _maxSlippage;
    }

    function setBankxMaxSlippage(uint256 _bankxMaxSlippage) external onlyOwner {
        require(_bankxMaxSlippage > 0 && _bankxMaxSlippage <= 500, "Invalid max slippage (0.1%-50%)");
        bankxMaxSlippage = _bankxMaxSlippage;
    }

    function setGasCostBuffer(uint256 _gasCostBuffer) external onlyOwner {
        require(_gasCostBuffer > 0, "Gas cost buffer must be > 0");
        gasCostBuffer = _gasCostBuffer;
    }

    function setTransactionDeadlineWindow(uint256 _transactionDeadlineWindow) external onlyOwner {
        require(_transactionDeadlineWindow > 0, "Transaction deadline window must be > 0");
        transactionDeadlineWindow = _transactionDeadlineWindow;
    }

    function setMinTimeBetweenSteps(uint256 _minTimeBetweenSteps) external onlyOwner {
        require(_minTimeBetweenSteps > 0, "Min time between steps must be > 0");
        minTimeBetweenSteps = _minTimeBetweenSteps;
    }

    function setTreasuryPool(address _treasuryPool) external onlyOwner {
        require(_treasuryPool != address(0), "Treasury Pool cannot be zero address");
        treasuryPool = _treasuryPool;
    }

    function setRewardManager(address _rewardManager) external onlyOwner {
        require(_rewardManager != address(0), "Reward Manager cannot be zero address");
        rewardManager = _rewardManager;
    }

    function setRouterAddress(address _router) external onlyOwner{
        require(_router != address(0), "Router address cannot be zero address");
        router = _router;
    }

    function flushBankX(address to) external onlyOwner {
        require(to != address(0), "Cannot flush to zero address");
        uint256 balance = IBankX(bankxToken).balanceOf(address(this));
        balance += unburnedBankXBalance;
        if (balance > 0) {
            IERC20(bankxToken).transfer(to, balance);
            unburnedBankXBalance = 0;
        }
    }

    function flushXSD(address to) external onlyOwner {
        require(to != address(0), "Cannot flush to zero address");
        uint256 balance = IERC20(xsdToken).balanceOf(address(this));
        if (balance > 0) {
            IERC20(xsdToken).transfer(to, balance);
        }
    }

    function recoverETH(address to) external onlyOwner {
        require(to != address(0), "Cannot recover to zero address");
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(to).call{value: balance}("");
            require(success, "ETH transfer failed");
        }
    }

    receive() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {

  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AggregatorV3Interface.sol";

contract ChainlinkETHUSDPriceConsumer {

    AggregatorV3Interface internal priceFeed;
    //Arbitrum: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
    //Ethereum: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
    //Polygon: 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
    //Optimism: 0x13e3Ee699D1909E989722E753853AE30b17e08c5
    //Avalanche: 0x0A77230d17318075983913bC2145DB16C7366156
    //Fantom: 0xf4766552D15AE4d256Ad41B6cf2933482B0680dc
    constructor() {
        priceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID
            , 
            int price,
            ,
            ,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        require(answeredInRound >= roundID);
        return price;
    }
    
    function getDecimals() public view returns (uint8) {
        return priceFeed.decimals();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AggregatorV3Interface.sol";

contract ChainlinkXAGUSDPriceConsumer {

    AggregatorV3Interface priceFeed;
    //Arbitrum: 0xC56765f04B248394CF1619D20dB8082Edbfa75b1
    //Ethereum: 0x379589227b15F1a12195D3f2d90bBc9F31f95235
    //Polygon: 0x461c7B8D370a240DdB46B402748381C3210136b3
    //Optimism:0x290dd71254874f0d4356443607cb8234958DEe49
    //Avalanche:0x4305FB66699C3B2702D4d05CF36551390A4c69C6
    constructor() {
        priceFeed = AggregatorV3Interface(0x379589227b15F1a12195D3f2d90bBc9F31f95235);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID
            , 
            int price,
            ,
            ,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        require(answeredInRound >= roundID);
        return price;
    }
    
    function getDecimals() public view returns (uint8) {
        return priceFeed.decimals();
    }
}