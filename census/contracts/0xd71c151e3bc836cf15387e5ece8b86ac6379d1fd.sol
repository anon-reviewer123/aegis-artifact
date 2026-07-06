// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

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
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
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
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
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
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
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
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Pausable
    struct PausableStorage {
        bool _paused;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Pausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PausableStorageLocation = 0xcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300;

    function _getPausableStorage() private pure returns (PausableStorage storage $) {
        assembly {
            $.slot := PausableStorageLocation
        }
    }

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
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
        PausableStorage storage $ = _getPausableStorage();
        return $._paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = true;
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
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    /// @custom:storage-location erc7201:openzeppelin.storage.ReentrancyGuard
    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReentrancyGuardStorageLocation = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = NOT_ENTERED;
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
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if ($._status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        $._status = ENTERED;
    }

    function _nonReentrantAfter() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        return $._status == ENTERED;
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

//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface Aggregator {
  function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface StakingManager {
  function depositByPresale(address _user, uint256 _amount) external;
}

contract PresaleV1 is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable, PausableUpgradeable {
  uint256 public totalTokensSold;
  uint256 public startTime;
  uint256 public endTime;
  uint256 public claimStart;
  address public saleToken;
  uint256 public baseDecimals;
  uint256 public maxTokensToBuy;
  uint256 public currentStep;
  uint256 public checkPoint;
  uint256 public usdRaised;
  uint256 public timeConstant;
  uint256 public totalBoughtAndStaked;
  uint256[][3] public rounds;
  uint256[] public prevCheckpoints;
  uint256[] public remainingTokensTracker;
  uint256[] public percentages;
  address[] public wallets;
  address public paymentWallet;
  address public admin;
  bool public dynamicTimeFlag;
  bool public whitelistClaimOnly;
  bool public stakeingWhitelistStatus;

  IERC20 public USDTInterface;
  Aggregator public aggregatorInterface;
  mapping(address => uint256) public userDeposits;
  mapping(address => bool) public hasClaimed;
  mapping(address => bool) public isBlacklisted;
  mapping(address => bool) public isWhitelisted;
  mapping(address => bool) public wertWhitelisted;

  StakingManager public stakingManagerInterface;

  event SaleTimeSet(uint256 _start, uint256 _end, uint256 timestamp);
  event SaleTimeUpdated(bytes32 indexed key, uint256 prevValue, uint256 newValue, uint256 timestamp);
  event TokensBought(address indexed user, uint256 indexed tokensBought, address indexed purchaseToken, uint256 amountPaid, uint256 usdEq, uint256 timestamp);
  event TokensAdded(address indexed token, uint256 noOfTokens, uint256 timestamp);
  event TokensClaimed(address indexed user, uint256 amount, uint256 timestamp);
  event ClaimStartUpdated(uint256 prevValue, uint256 newValue, uint256 timestamp);
  event MaxTokensUpdated(uint256 prevValue, uint256 newValue, uint256 timestamp);
  event TokensBoughtAndStaked(address indexed user, uint256 indexed tokensBought, address indexed purchaseToken, uint256 amountPaid, uint256 usdEq, uint256 timestamp);
  event TokensClaimedAndStaked(address indexed user, uint256 amount, uint256 timestamp);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() initializer {}

  /**
   * @dev Initializes the contract and sets key parameters
   * @param _oracle Oracle contract to fetch ETH/USDT price
   * @param _usdt USDT token contract address
   * @param _startTime start time of the presale
   * @param _endTime end time of the presale
   * @param _rounds array of round details
   * @param _maxTokensToBuy amount of max tokens to buy
   * @param _paymentWallet address to recive payments
   */
  function initialize(address _oracle, address _usdt, uint256 _startTime, uint256 _endTime, uint256[][3] memory _rounds, uint256 _maxTokensToBuy, address _paymentWallet) external initializer {
    require(_oracle != address(0), "Zero aggregator address");
    require(_usdt != address(0), "Zero USDT address");
    require(_startTime > block.timestamp && _endTime > _startTime, "Invalid time");
    __Pausable_init_unchained();
    __Ownable_init_unchained(msg.sender);
    __ReentrancyGuard_init_unchained();
    baseDecimals = (10 ** 18);
    aggregatorInterface = Aggregator(_oracle);
    USDTInterface = IERC20(_usdt);
    startTime = _startTime;
    endTime = _endTime;
    rounds = _rounds;
    maxTokensToBuy = _maxTokensToBuy;
    paymentWallet = _paymentWallet;
    emit SaleTimeSet(startTime, endTime, block.timestamp);
  }

  /**
   * @dev To pause the presale
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @dev To unpause the presale
   */
  function unpause() external onlyOwner {
    _unpause();
  }

  /**
   * @dev To calculate the price in USD for given amount of tokens.
   * @param _amount No of tokens
   */
  function calculatePrice(uint256 _amount) public view returns (uint256) {
    uint256 USDTAmount;
    uint256 total = checkPoint == 0 ? totalTokensSold : checkPoint;
    require(_amount <= maxTokensToBuy, "Amount exceeds max tokens to buy");
    if (_amount + total > rounds[0][currentStep] || block.timestamp >= rounds[2][currentStep]) {
      require(currentStep < (rounds[0].length - 1), "Wrong params");
      if (block.timestamp >= rounds[2][currentStep]) {
        require(rounds[0][currentStep] + _amount <= rounds[0][currentStep + 1], "Cant Purchase More in individual tx");
        USDTAmount = _amount * rounds[1][currentStep + 1];
      } else {
        uint256 tokenAmountForCurrentPrice = rounds[0][currentStep] - total;
        USDTAmount = tokenAmountForCurrentPrice * rounds[1][currentStep] + (_amount - tokenAmountForCurrentPrice) * rounds[1][currentStep + 1];
      }
    } else USDTAmount = _amount * rounds[1][currentStep];
    return USDTAmount;
  }

  /**
   * @dev To update the sale times
   * @param _startTime New start time
   * @param _endTime New end time
   */
  function changeSaleTimes(uint256 _startTime, uint256 _endTime) external onlyOwner {
    require(_startTime > 0 || _endTime > 0, "Invalid parameters");
    if (_startTime > 0) {
      require(block.timestamp < startTime, "Sale already started");
      require(block.timestamp < _startTime, "Sale time in past");
      uint256 prevValue = startTime;
      startTime = _startTime;
      emit SaleTimeUpdated(bytes32("START"), prevValue, _startTime, block.timestamp);
    }
    if (_endTime > 0) {
      require(_endTime > startTime, "Invalid endTime");
      uint256 prevValue = endTime;
      endTime = _endTime;
      emit SaleTimeUpdated(bytes32("END"), prevValue, _endTime, block.timestamp);
    }
  }

  /**
   * @dev To get latest ETH price in 10**18 format
   */
  function getLatestPrice() public view returns (uint256) {
    (, int256 price, , , ) = aggregatorInterface.latestRoundData();
    price = (price * (10 ** 10));
    return uint256(price);
  }

  function setSplits(address[] memory _wallets, uint256[] memory _percentages) public onlyOwner {
    require(_wallets.length == _percentages.length, "Mismatched arrays");
    delete wallets;
    delete percentages;
    uint256 totalPercentage = 0;

    for (uint256 i = 0; i < _wallets.length; i++) {
      require(_percentages[i] > 0, "Percentage must be greater than 0");
      totalPercentage += _percentages[i];
      wallets.push(_wallets[i]);
      percentages.push(_percentages[i]);
    }

    require(totalPercentage == 100, "Total percentage must equal 100");
  }

  modifier checkSaleState(uint256 amount) {
    require(block.timestamp >= startTime && block.timestamp <= endTime, "Invalid time for buying");
    require(amount > 0, "Invalid sale amount");
    _;
  }

  /**
   * @dev To buy into a presale using USDT
   * @param amount No of tokens to buy
   * @param stake boolean flag for token staking
   */
  function buyWithUSDT(uint256 amount, bool stake) external checkSaleState(amount) whenNotPaused returns (bool) {
    uint256 usdPrice = calculatePrice(amount);
    totalTokensSold += amount;
    uint256 price = usdPrice / (10 ** 12);
    if (checkPoint != 0) checkPoint += amount;
    uint256 total = totalTokensSold > checkPoint ? totalTokensSold : checkPoint;
    if (total > rounds[0][currentStep] || block.timestamp >= rounds[2][currentStep]) {
      if (block.timestamp >= rounds[2][currentStep]) {
        checkPoint = rounds[0][currentStep] + amount;
      }
      if (dynamicTimeFlag) {
        manageTimeDiff();
      }
      uint256 unsoldTokens = total > rounds[0][currentStep] ? 0 : rounds[0][currentStep] - total - amount;
      remainingTokensTracker.push(unsoldTokens);
      currentStep += 1;
    }
    if (stake) {
      if (stakeingWhitelistStatus) {
        require(isWhitelisted[_msgSender()], "User not whitelisted for stake");
      }
      stakingManagerInterface.depositByPresale(_msgSender(), amount * baseDecimals);
      totalBoughtAndStaked += amount;
      emit TokensBoughtAndStaked(_msgSender(), amount, address(USDTInterface), price, usdPrice, block.timestamp);
    } else {
      userDeposits[_msgSender()] += (amount * baseDecimals);
      emit TokensBought(_msgSender(), amount, address(USDTInterface), price, usdPrice, block.timestamp);
    }
    usdRaised += usdPrice;
    uint256 ourAllowance = USDTInterface.allowance(_msgSender(), address(this));
    require(price <= ourAllowance, "Make sure to add enough allowance");
    splitUSDTValue(price);

    return true;
  }

  /**
   * @dev To buy into a presale using ETH
   * @param amount No of tokens to buy
   * @param stake boolean flag for token staking
   */
  function buyWithEth(uint256 amount, bool stake) external payable checkSaleState(amount) whenNotPaused nonReentrant returns (bool) {
    uint256 usdPrice = calculatePrice(amount);
    uint256 ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
    require(msg.value >= ethAmount, "Less payment");
    uint256 excess = msg.value - ethAmount;
    totalTokensSold += amount;
    if (checkPoint != 0) checkPoint += amount;
    uint256 total = totalTokensSold > checkPoint ? totalTokensSold : checkPoint;
    if (total > rounds[0][currentStep] || block.timestamp >= rounds[2][currentStep]) {
      if (block.timestamp >= rounds[2][currentStep]) {
        checkPoint = rounds[0][currentStep] + amount;
      }
      if (dynamicTimeFlag) {
        manageTimeDiff();
      }
      uint256 unsoldTokens = total > rounds[0][currentStep] ? 0 : rounds[0][currentStep] - total - amount;
      remainingTokensTracker.push(unsoldTokens);
      currentStep += 1;
    }
    if (stake) {
      if (stakeingWhitelistStatus) {
        require(isWhitelisted[_msgSender()], "User not whitelisted for stake");
      }
      stakingManagerInterface.depositByPresale(_msgSender(), amount * baseDecimals);
      totalBoughtAndStaked += amount;
      emit TokensBoughtAndStaked(_msgSender(), amount, address(0), ethAmount, usdPrice, block.timestamp);
    } else {
      userDeposits[_msgSender()] += (amount * baseDecimals);
      emit TokensBought(_msgSender(), amount, address(0), ethAmount, usdPrice, block.timestamp);
    }
    usdRaised += usdPrice;
    splitETHValue(ethAmount);
    if (excess > 0) sendValue(payable(_msgSender()), excess);
    return true;
  }

  /**
   * @dev To buy ETH directly from wert .*wert contract address should be whitelisted if wertBuyRestrictionStatus is set true
   * @param _user address of the user
   * @param _amount No of ETH to buy
   * @param stake boolean flag for token staking
   */
  function buyWithETHWert(address _user, uint256 _amount, bool stake) external payable checkSaleState(_amount) whenNotPaused nonReentrant returns (bool) {
    require(wertWhitelisted[_msgSender()], "User not whitelisted for this tx");
    uint256 usdPrice = calculatePrice(_amount);
    uint256 ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
    require(msg.value >= ethAmount, "Less payment");
    uint256 excess = msg.value - ethAmount;
    totalTokensSold += _amount;
    if (checkPoint != 0) checkPoint += _amount;
    uint256 total = totalTokensSold > checkPoint ? totalTokensSold : checkPoint;
    if (total > rounds[0][currentStep] || block.timestamp >= rounds[2][currentStep]) {
      if (block.timestamp >= rounds[2][currentStep]) {
        checkPoint = rounds[0][currentStep] + _amount;
      }
      if (dynamicTimeFlag) {
        manageTimeDiff();
      }
      uint256 unsoldTokens = total > rounds[0][currentStep] ? 0 : rounds[0][currentStep] - total - _amount;
      remainingTokensTracker.push(unsoldTokens);
      currentStep += 1;
    }
    if (stake) {
      if (stakeingWhitelistStatus) {
        require(isWhitelisted[_user], "User not whitelisted for stake");
      }
      stakingManagerInterface.depositByPresale(_user, _amount * baseDecimals);
      totalBoughtAndStaked += _amount;
      emit TokensBoughtAndStaked(_user, _amount, address(0), ethAmount, usdPrice, block.timestamp);
    } else {
      userDeposits[_user] += (_amount * baseDecimals);
      emit TokensBought(_user, _amount, address(0), ethAmount, usdPrice, block.timestamp);
    }
    usdRaised += usdPrice;
    splitETHValue(ethAmount);
    if (excess > 0) sendValue(payable(_user), excess);
    return true;
  }

  /**
   * @dev Helper funtion to get ETH price for given amount
   * @param amount No of tokens to buy
   */
  function ethBuyHelper(uint256 amount) external view returns (uint256 ethAmount) {
    uint256 usdPrice = calculatePrice(amount);
    ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
  }

  /**
   * @dev Helper funtion to get USDT price for given amount
   * @param amount No of tokens to buy
   */
  function usdtBuyHelper(uint256 amount) external view returns (uint256 usdPrice) {
    usdPrice = calculatePrice(amount);
    usdPrice = usdPrice / (10 ** 12);
  }

  function sendValue(address payable recipient, uint256 amount) internal {
    require(address(this).balance >= amount, "Low balance");
    (bool success, ) = recipient.call{value: amount}("");
    require(success, "ETH Payment failed");
  }

  function splitETHValue(uint256 _amount) internal {
    if (wallets.length == 0) {
      require(paymentWallet != address(0), "Payment wallet not set");
      sendValue(payable(paymentWallet), _amount);
    } else {
      uint256 tempCalc;
      for (uint256 i = 0; i < wallets.length; i++) {
        uint256 amountToTransfer = (_amount * percentages[i]) / 100;
        sendValue(payable(wallets[i]), amountToTransfer);
        tempCalc += amountToTransfer;
      }
      if ((_amount - tempCalc) > 0) {
        sendValue(payable(wallets[wallets.length - 1]), _amount - tempCalc);
      }
    }
  }

  function splitUSDTValue(uint256 _amount) internal {
    if (wallets.length == 0) {
      require(paymentWallet != address(0), "Payment wallet not set");
      (bool success, ) = address(USDTInterface).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), paymentWallet, _amount));
      require(success, "Token payment failed");
    } else {
      uint256 tempCalc;
      for (uint256 i = 0; i < wallets.length; i++) {
        uint256 amountToTransfer = (_amount * percentages[i]) / 100;
        (bool success, ) = address(USDTInterface).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), wallets[i], amountToTransfer));
        require(success, "Token payment failed");
        tempCalc += amountToTransfer;
      }
      if ((_amount - tempCalc) > 0) {
        (bool success, ) = address(USDTInterface).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), wallets[wallets.length - 1], _amount - tempCalc));
        require(success, "Token payment failed");
      }
    }
  }

  /**
   * @dev to initialize staking manager with new addredd
   * @param _stakingManagerAddress address of the staking smartcontract
   */
  function setStakingManager(address _stakingManagerAddress) external onlyOwner {
    require(_stakingManagerAddress != address(0), "staking manager cannot be inatialized with zero address");
    stakingManagerInterface = StakingManager(_stakingManagerAddress);
    IERC20(saleToken).approve(_stakingManagerAddress, type(uint256).max);
  }

  /**
   * @dev To set the claim start time and sale token address by the owner
   * @param _claimStart claim start time
   * @param noOfTokens no of tokens to add to the contract
   * @param _saleToken sale toke address
   */
  function startClaim(uint256 _claimStart, uint256 noOfTokens, address _saleToken, address _stakingManagerAddress) external onlyOwner returns (bool) {
    require(_saleToken != address(0), "Zero token address");
    require(claimStart == 0, "Claim already set");
    claimStart = _claimStart;
    saleToken = _saleToken;
    whitelistClaimOnly = true;
    stakingManagerInterface = StakingManager(_stakingManagerAddress);
    IERC20(_saleToken).approve(_stakingManagerAddress, type(uint256).max);
    bool success = IERC20(_saleToken).transferFrom(_msgSender(), address(this), noOfTokens);
    require(success, "Token transfer failed");
    emit TokensAdded(_saleToken, noOfTokens, block.timestamp);
    return true;
  }

  /**
   * @dev To set status for claim whitelisting
   * @param _status bool value
   */
  function setStakeingWhitelistStatus(bool _status) external onlyOwner {
    stakeingWhitelistStatus = _status;
  }

  /**
   * @dev To change the claim start time by the owner
   * @param _claimStart new claim start time
   */
  function changeClaimStart(uint256 _claimStart) external onlyOwner returns (bool) {
    require(claimStart > 0, "Initial claim data not set");
    require(_claimStart > endTime, "Sale in progress");
    require(_claimStart > block.timestamp, "Claim start in past");
    uint256 prevValue = claimStart;
    claimStart = _claimStart;
    emit ClaimStartUpdated(prevValue, _claimStart, block.timestamp);
    return true;
  }

  /**
   * @dev To claim tokens after claiming starts
   */
  function claim() external whenNotPaused returns (bool) {
    require(saleToken != address(0), "Sale token not added");
    require(!isBlacklisted[_msgSender()], "This Address is Blacklisted");
    if (whitelistClaimOnly) {
      require(isWhitelisted[_msgSender()], "User not whitelisted for claim");
    }
    require(block.timestamp >= claimStart, "Claim has not started yet");
    require(!hasClaimed[_msgSender()], "Already claimed");
    hasClaimed[_msgSender()] = true;
    uint256 amount = userDeposits[_msgSender()];
    require(amount > 0, "Nothing to claim");
    delete userDeposits[_msgSender()];
    bool success = IERC20(saleToken).transfer(_msgSender(), amount);
    require(success, "Token transfer failed");
    emit TokensClaimed(_msgSender(), amount, block.timestamp);
    return true;
  }

  function claimAndStake() external whenNotPaused returns (bool) {
    require(saleToken != address(0), "Sale token not added");
    require(!isBlacklisted[_msgSender()], "This Address is Blacklisted");
    if (stakeingWhitelistStatus) {
      require(isWhitelisted[_msgSender()], "User not whitelisted for stake");
    }
    uint256 amount = userDeposits[_msgSender()];
    require(amount > 0, "Nothing to stake");
    stakingManagerInterface.depositByPresale(_msgSender(), amount);
    delete userDeposits[_msgSender()];
    emit TokensClaimedAndStaked(_msgSender(), amount, block.timestamp);
    return true;
  }

  /**
   * @dev To add wert contract addresses to whitelist
   * @param _addressesToWhitelist addresses of the contract
   */
  function whitelistUsersForWERT(address[] calldata _addressesToWhitelist) external onlyOwner {
    for (uint256 i = 0; i < _addressesToWhitelist.length; i++) {
      wertWhitelisted[_addressesToWhitelist[i]] = true;
    }
  }

  /**
   * @dev To remove wert contract addresses to whitelist
   * @param _addressesToRemoveFromWhitelist addresses of the contracts
   */
  function removeFromWhitelistForWERT(address[] calldata _addressesToRemoveFromWhitelist) external onlyOwner {
    for (uint256 i = 0; i < _addressesToRemoveFromWhitelist.length; i++) {
      wertWhitelisted[_addressesToRemoveFromWhitelist[i]] = false;
    }
  }

  function changeMaxTokensToBuy(uint256 _maxTokensToBuy) external onlyOwner {
    require(_maxTokensToBuy > 0, "Zero max tokens to buy value");
    uint256 prevValue = maxTokensToBuy;
    maxTokensToBuy = _maxTokensToBuy;
    emit MaxTokensUpdated(prevValue, _maxTokensToBuy, block.timestamp);
  }

  function changeRoundsData(uint256[][3] memory _rounds) external onlyOwner {
    rounds = _rounds;
  }

  /**
   * @dev To add users to blacklist which restricts blacklisted users from claiming
   * @param _usersToBlacklist addresses of the users
   */
  function blacklistUsers(address[] calldata _usersToBlacklist) external onlyOwner {
    for (uint256 i = 0; i < _usersToBlacklist.length; i++) {
      isBlacklisted[_usersToBlacklist[i]] = true;
    }
  }

  /**
   * @dev To remove users from blacklist which restricts blacklisted users from claiming
   * @param _userToRemoveFromBlacklist addresses of the users
   */
  function removeFromBlacklist(address[] calldata _userToRemoveFromBlacklist) external onlyOwner {
    for (uint256 i = 0; i < _userToRemoveFromBlacklist.length; i++) {
      isBlacklisted[_userToRemoveFromBlacklist[i]] = false;
    }
  }

  /**
   * @dev To add users to whitelist which restricts users from claiming if claimWhitelistStatus is true
   * @param _usersToWhitelist addresses of the users
   */
  function whitelistUsers(address[] calldata _usersToWhitelist) external onlyOwner {
    for (uint256 i = 0; i < _usersToWhitelist.length; i++) {
      isWhitelisted[_usersToWhitelist[i]] = true;
    }
  }

  /**
   * @dev To remove users from whitelist which restricts users from claiming if claimWhitelistStatus is true
   * @param _userToRemoveFromWhitelist addresses of the users
   */
  function removeFromWhitelist(address[] calldata _userToRemoveFromWhitelist) external onlyOwner {
    for (uint256 i = 0; i < _userToRemoveFromWhitelist.length; i++) {
      isWhitelisted[_userToRemoveFromWhitelist[i]] = false;
    }
  }

  /**
   * @dev To set status for claim whitelisting
   * @param _status bool value
   */
  function setClaimWhitelistStatus(bool _status) external onlyOwner {
    whitelistClaimOnly = _status;
  }

  /**
   * @dev To set payment wallet address
   * @param _newPaymentWallet new payment wallet address
   */
  function changePaymentWallet(address _newPaymentWallet) external onlyOwner {
    require(_newPaymentWallet != address(0), "address cannot be zero");
    paymentWallet = _newPaymentWallet;
  }

  /**
   * @dev To manage time gap between two rounds
   */
  function manageTimeDiff() internal {
    for (uint256 i; i < rounds[2].length - currentStep; i++) {
      rounds[2][currentStep + i] = block.timestamp + i * timeConstant;
    }
  }

  /**
   * @dev To set time constant for manageTimeDiff()
   * @param _timeConstant time in <days>*24*60*60 format
   */
  function setTimeConstant(uint256 _timeConstant) external onlyOwner {
    timeConstant = _timeConstant;
  }

  /**
   * @dev To get array of round details at once
   * @param _no array index
   */
  function roundDetails(uint256 _no) external view returns (uint256[] memory) {
    return rounds[_no];
  }

  /**
   * @dev to update userDeposits for purchases made on BSC
   * @param _users array of users
   * @param _userDeposits array of userDeposits associated with users
   */
  function updateFromBSC(address[] calldata _users, uint256[] calldata _userDeposits) external onlyOwner {
    require(_users.length == _userDeposits.length, "Length mismatch");
    for (uint256 i = 0; i < _users.length; i++) {
      userDeposits[_users[i]] += _userDeposits[i];
    }
  }

  /**
   * @dev To increment the rounds from backend
   */
  function incrementCurrentStep() external {
    require(msg.sender == admin || msg.sender == owner(), "caller not admin or owner");
    prevCheckpoints.push(checkPoint);
    if (dynamicTimeFlag) {
      manageTimeDiff();
    }
    if (checkPoint < rounds[0][currentStep]) {
      if (currentStep == 0) {
        remainingTokensTracker.push(rounds[0][currentStep] - totalTokensSold);
      } else {
        remainingTokensTracker.push(rounds[0][currentStep] - checkPoint);
      }
      checkPoint = rounds[0][currentStep];
    }
    currentStep++;
  }

  /**
   * @dev To set admin
   * @param _admin new admin wallet address
   */
  function setAdmin(address _admin) external onlyOwner {
    admin = _admin;
  }

  /**
   * @dev To change details of the round
   * @param _step round for which you want to change the details
   * @param _checkpoint token tracker amount
   */
  function setCurrentStep(uint256 _step, uint256 _checkpoint) external onlyOwner {
    currentStep = _step;
    checkPoint = _checkpoint;
  }

  /**
   * @dev To set time shift functionality on/off
   * @param _dynamicTimeFlag bool value
   */
  function setDynamicTimeFlag(bool _dynamicTimeFlag) external onlyOwner {
    dynamicTimeFlag = _dynamicTimeFlag;
  }

  /**
   * @dev     Function to return remainingTokenTracker Array
   */
  function trackRemainingTokens() external view returns (uint256[] memory) {
    return remainingTokensTracker;
  }

  /**
   * @dev     To update remainingTokensTracker Array
   * @param   _unsoldTokens  input parameters in uint256 array format
   */
  function setRemainingTokensArray(uint256[] memory _unsoldTokens) public {
    require(msg.sender == admin || msg.sender == owner(), "caller not admin or owner");
    require(_unsoldTokens.length != 0, "cannot update invalid values");
    delete remainingTokensTracker;
    for (uint256 i; i < _unsoldTokens.length; i++) {
      remainingTokensTracker.push(_unsoldTokens[i]);
    }
  }
}