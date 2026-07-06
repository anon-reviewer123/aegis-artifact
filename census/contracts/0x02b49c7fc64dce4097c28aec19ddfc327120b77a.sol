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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

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
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

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

        // Any calls to nonReentrant after this point will fail
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
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title StakeFund Staking Platform
 * @dev This contract allows users to stake ETH and MATIC tokens on the Ethereum blockchain.
 *      It supports multiple staking pools with different durations and reward rates.
 */
 contract StakeFund is ReentrancyGuard, Ownable {

    event ETHRewardWithdrawn(address indexed user, uint256 rewardAmount);

    struct StakingPot {
        uint256 durationDays;
        uint256 rewardRate;
        uint256 minStake;
        uint256 maxStake;
    }

    mapping(address => StakingPot[]) private tokenAddressToDepositGroupMap;

    StakingPot[] private ethStakingPot;

    event TokensStaked(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 durationDays
    );

    string public constant ethCode = "ETH";
    string public constant maticCode = "MATIC";

    event ETHStaked(address indexed user, uint256 amount, uint256 durationDays);

    struct StakeFundPool {
        uint256 amount;
        uint256 startTime;
        uint256 poolIndex;
    }

    mapping(address => mapping(address => StakeFundPool)) public userAddressToStakeFundGroupMap;

    event RewardWithdrawn(
        address indexed user,
        address indexed token,
        uint256 rewardAmount
    );

    IERC20 public immutable maticCurrency;

    mapping(address => StakeFundPool) public ethStakeFundGroupMap;

    constructor(IERC20 _matic) Ownable(msg.sender) {
        maticCurrency =  _matic;
        // Configure ETH staking pools
        ethStakingPot.push(
            StakingPot(15, 642, 0.15 * 1e18, 28.00 * 1e18)
        );
        ethStakingPot.push(
            StakingPot(30, 977, 28.00 * 1e18, 55.00 * 1e18)
        );

        // Configure MATIC staking pools
        tokenAddressToDepositGroupMap[address(maticCurrency)].push(
            StakingPot(15, 325, 0.02 * 1e18, 4.00 * 1e18)
        );
        tokenAddressToDepositGroupMap[address(maticCurrency)].push(
            StakingPot(30, 560, 4.00 * 1e18, 8.00 * 1e18)
        );
    }

    function lookupPool(
        address token,
        uint256 poolIdx
    ) internal view returns (StakingPot memory) {
        require(poolIdx < tokenAddressToDepositGroupMap[token].length, "Invalid pool index");
        return tokenAddressToDepositGroupMap[token][poolIdx];
    }

    function exploreETHPoolDetails(
        uint256 poolIndex
    )
        external
        view
        returns (uint256 duration, uint256 rate, uint256 min, uint256 max)
    {
        StakingPot memory pool = accessETHStakingPool(poolIndex);
        return (
            pool.durationDays,
            pool.rewardRate,
            pool.minStake,
            pool.maxStake
        );
    }

    function listAvailablePools(
        address token
    ) external view returns (StakingPot[] memory) {
        require(isTokenAccepted(token), "Token not supported");
        return tokenAddressToDepositGroupMap[token];
    }

    function getReward(address token) external nonReentrant {
        StakeFundPool storage stakeData = userAddressToStakeFundGroupMap[msg.sender][token];
        require(stakeData.amount > 0, "No active stake found");

        StakingPot memory thePoolDetails = lookupPool(token, stakeData.poolIndex);
        require(
            block.timestamp >=
                stakeData.startTime + (thePoolDetails.durationDays * 1 days),
            "Staking period not yet completed"
        );

        uint256 principal = stakeData.amount;
        uint256 reward = (principal * thePoolDetails.rewardRate) / 10000; // Applying the scaled reward rate

        // Reset user's stake data
        delete userAddressToStakeFundGroupMap[msg.sender][token];

        // Transfer principal and reward back to the user
        IERC20(token).transfer(msg.sender, principal + reward);

        emit RewardWithdrawn(msg.sender, token, reward);
    }

    function accessPoolData(
        address token,
        uint256 poolIdx
    )
        external
        view
        returns (uint256 duration, uint256 rate, uint256 min, uint256 max)
    {
        StakingPot memory pool = lookupPool(token, poolIdx);
        return (
            pool.durationDays,
            pool.rewardRate,
            pool.minStake,
            pool.maxStake
        );
    }

    function redeemETHYield() external payable nonReentrant {
        StakeFundPool storage stakeInfo = ethStakeFundGroupMap[msg.sender];
        require(stakeInfo.amount > 0, "No active staking found");

        StakingPot memory poolInfo = accessETHStakingPool(stakeInfo.poolIndex);
        require(
            block.timestamp >=
                stakeInfo.startTime + (poolInfo.durationDays * 1 days),
            "Staking duration not completed"
        );

        uint256 principal = stakeInfo.amount;
        uint256 reward = (principal * poolInfo.rewardRate) / 10000; // Scaled reward calculation

        // Reset user's stake data
        delete ethStakeFundGroupMap[msg.sender];

        // Transfer principal and reward back to the user
        payable(msg.sender).transfer(principal + reward);

        emit ETHRewardWithdrawn(msg.sender, reward);
    }

    function accessETHStakingPool(
        uint256 poolIndex
    ) internal view returns (StakingPot memory) {
        require(poolIndex < ethStakingPot.length, "Invalid pool index");
        return ethStakingPot[poolIndex];
    }

    function isTokenAccepted(address token) internal view returns (bool) {
        return token == address(maticCurrency);
    }

    function gatherSupportedTokens()
        external
        view
        returns (string[] memory, address[] memory)
    {
        string[] memory symbols = new string[](2);
        address[] memory tokenAddresses = new address[](2);

        symbols[1] = ethCode;
        tokenAddresses[1] = address(0);
        symbols[2] = maticCode;
        tokenAddresses[2] = address(maticCurrency);

        return (symbols, tokenAddresses);
    }

    function lockTokens(
        address token,
        uint256 amount,
        uint256 poolIdx
    ) external nonReentrant {
        require(amount > 0, "Staking amount must be positive");
        require(isTokenAccepted(token), "Token not supported for staking");

        StakingPot memory selectedPool = lookupPool(token, poolIdx);
        require(
            amount >= selectedPool.minStake && amount <= selectedPool.maxStake,
            "Amount outside allowed staking limits"
        );

        require(
            userAddressToStakeFundGroupMap[msg.sender][token].amount == 0,
            "You have staked for this token already and cannot add more"
        );

        // Transfer tokens from the user to the contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Record the staking information
        userAddressToStakeFundGroupMap[msg.sender][token] = StakeFundPool({
            amount: amount,
            startTime: block.timestamp,
            poolIndex: poolIdx
        });

        emit TokensStaked(msg.sender, token, amount, selectedPool.durationDays);
    }

    function stakeETHAssets(uint256 poolIndex) external payable nonReentrant {
        require(msg.value > 0, "Staking amount must be positive");
        StakingPot memory selectedPool = accessETHStakingPool(poolIndex);
        if (
            !(msg.value >= selectedPool.minStake &&
                msg.value <= selectedPool.maxStake)
        ) {
            payable(msg.sender).transfer(msg.value);
        }
        require(
            msg.value >= selectedPool.minStake &&
                msg.value <= selectedPool.maxStake,
            "Staking amount outside limits"
        );

        if (!(ethStakeFundGroupMap[msg.sender].amount == 0)) {
            payable(msg.sender).transfer(msg.value);
        }
        require(
            ethStakeFundGroupMap[msg.sender].amount == 0,
            "You have staked for ETH already and cannot add more"
        );

        // Record the staking information
        ethStakeFundGroupMap[msg.sender] = StakeFundPool({
            amount: msg.value,
            startTime: block.timestamp,
            poolIndex: poolIndex
        });

        emit ETHStaked(msg.sender, msg.value, selectedPool.durationDays);
    }
}
