// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
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
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
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
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
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
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

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
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

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
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
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
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant, _status will be ENTERED
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract KWEStaking is Ownable, ReentrancyGuard {
    IERC20 public kweToken;
    IERC20 public usdtToken;
    address public collectorAddress;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardClaim;
        bool active;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public pendingRewards;

    // Constants
    uint256 public constant LOCK_PERIOD = 7 days;
    uint256 public constant REWARD_INTERVAL = 7 days; // Weekly rewards
    uint256 public constant INITIAL_APY = 20; // 20%
    uint256 public constant FINAL_APY = 10; // 10%
    uint256 public constant APY_DECREASE_PERIOD = 180 days; // 6 months
    uint256 public constant START_TIME = 1735084800; // Dec 25, 2025 00:00:00 UTC

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 penalty);
    event RewardClaimed(address indexed user, uint256 amount);
    event PurchasedWithUSDT(
        address indexed user,
        uint256 usdtAmount,
        uint256 kweAmount
    );

    constructor(
        address _kweToken,
        address _usdtToken,
        address _collectorAddress,
        address initialOwner
    ) Ownable(initialOwner) {
        kweToken = IERC20(_kweToken);
        usdtToken = IERC20(_usdtToken);
        collectorAddress = _collectorAddress;
    }

    // Calculate current APY based on time elapsed
    function getCurrentAPY() public view returns (uint256) {
        if (block.timestamp < START_TIME) return INITIAL_APY;

        uint256 timeElapsed = block.timestamp - START_TIME;
        uint256 periodsElapsed = timeElapsed / APY_DECREASE_PERIOD;

        if (periodsElapsed >= 10) return FINAL_APY; // After ~5 years, stay at 10%

        uint256 currentAPY = INITIAL_APY - periodsElapsed;
        return currentAPY < FINAL_APY ? FINAL_APY : currentAPY;
    }

    // Calculate pending rewards for a user
    function calculateRewards(address user) public view returns (uint256) {
        Stake memory userStake = stakes[user];
        if (!userStake.active || userStake.amount == 0) return 0;

        uint256 timeElapsed = block.timestamp - userStake.lastRewardClaim;
        uint256 rewardIntervals = timeElapsed / REWARD_INTERVAL;

        if (rewardIntervals == 0) return 0;

        uint256 currentAPY = getCurrentAPY();
        uint256 annualReward = (userStake.amount * currentAPY) / 100;
        uint256 weeklyReward = annualReward / 52;

        return weeklyReward * rewardIntervals;
    }

    // Stake KWE tokens
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            kweToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        Stake storage userStake = stakes[msg.sender];

        if (userStake.active) {
            // Claim any pending rewards before restaking
            uint256 rewards = calculateRewards(msg.sender);
            if (rewards > 0) {
                pendingRewards[msg.sender] += rewards;
            }
            userStake.amount += amount;
        } else {
            userStake.amount = amount;
            userStake.startTime = block.timestamp;
            userStake.active = true;
        }

        userStake.lastRewardClaim = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    // Unstake with penalty check
    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.active, "No active stake");

        uint256 penalty = 0;
        uint256 timeStaked = block.timestamp - userStake.startTime;

        if (timeStaked < LOCK_PERIOD) {
            // Early unstaking - lose all rewards
            penalty = pendingRewards[msg.sender] + calculateRewards(msg.sender);
            pendingRewards[msg.sender] = 0;
        } else {
            // Normal unstaking - claim rewards
            uint256 rewards = pendingRewards[msg.sender] +
                calculateRewards(msg.sender);
            if (rewards > 0) {
                require(
                    kweToken.transfer(msg.sender, rewards),
                    "Reward transfer failed"
                );
                emit RewardClaimed(msg.sender, rewards);
            }
            pendingRewards[msg.sender] = 0;
        }

        uint256 stakeAmount = userStake.amount;
        userStake.active = false;
        userStake.amount = 0;

        require(
            kweToken.transfer(msg.sender, stakeAmount),
            "Stake transfer failed"
        );

        emit Unstaked(msg.sender, stakeAmount, penalty);
    }

    // Claim rewards without unstaking
    function claimRewards() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.active, "No active stake");

        uint256 rewards = pendingRewards[msg.sender] +
            calculateRewards(msg.sender);
        require(rewards > 0, "No rewards to claim");

        pendingRewards[msg.sender] = 0;
        userStake.lastRewardClaim = block.timestamp;

        require(
            kweToken.transfer(msg.sender, rewards),
            "Reward transfer failed"
        );

        emit RewardClaimed(msg.sender, rewards);
    }

    // Purchase KWE with USDT (1 USDT = 1 KWE for simplicity)
    function purchaseWithUSDT(uint256 usdtAmount) external nonReentrant {
        require(usdtAmount > 0, "Amount must be greater than 0");
        require(
            usdtToken.transferFrom(msg.sender, collectorAddress, usdtAmount),
            "USDT transfer failed"
        );

        // For now, assume 1:1 ratio. Owner can mint/buy KWE tokens
        // In production, this would integrate with a DEX or minting system
        // Adjust for decimals: USDT has 6 decimals, KWE has 18 decimals
        uint256 kweAmount = usdtAmount * 1e12; // 1 USDT = 1 KWE

        require(
            kweToken.transfer(msg.sender, kweAmount),
            "KWE transfer failed"
        );

        emit PurchasedWithUSDT(msg.sender, usdtAmount, kweAmount);
    }

    // View functions
    function getStakeInfo(
        address user
    )
        external
        view
        returns (
            uint256 amount,
            uint256 startTime,
            uint256 lockEndTime,
            uint256 pendingRewardAmount,
            uint256 currentAPY,
            bool canUnstake
        )
    {
        Stake memory userStake = stakes[user];
        uint256 rewards = calculateRewards(user);
        uint256 currentApy = getCurrentAPY();
        bool canUnstakeFlag = userStake.active &&
            (block.timestamp >= userStake.startTime + LOCK_PERIOD);

        return (
            userStake.amount,
            userStake.startTime,
            userStake.startTime + LOCK_PERIOD,
            pendingRewards[user] + rewards,
            currentApy,
            canUnstakeFlag
        );
    }

    // Emergency functions for owner
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        kweToken.transfer(owner(), amount);
    }

    function setUSDTToken(address _usdtToken) external onlyOwner {
        usdtToken = IERC20(_usdtToken);
    }
}
