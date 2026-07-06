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
// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/Initializable.sol)

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
        // - construction: the contract is initialized at version 1 (no reinitialization) and the
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
     * @dev Pointer to storage slot. Allows integrators to override it with a custom storage location.
     *
     * NOTE: Consider following the ERC-7201 formula to derive storage locations.
     */
    function _initializableStorageSlot() internal pure virtual returns (bytes32) {
        return INITIALIZABLE_STORAGE;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.22;

import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Initializable} from "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC-1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC-1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC-1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC-1967 compliant implementation pointing to self.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC-1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
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
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

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
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
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
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC-1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 */
interface IERC1967 {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (proxy/Clones.sol)

pragma solidity ^0.8.20;

import {Create2} from "../utils/Create2.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[ERC-1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 */
library Clones {
    error CloneArgumentsTooLong();

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        return clone(implementation, 0);
    }

    /**
     * @dev Same as {xref-Clones-clone-address-}[clone], but with a `value` parameter to send native currency
     * to the new contract.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function clone(address implementation, uint256 value) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        assembly ("memory-safe") {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create(value, 0x09, 0x37)
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple times will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        return cloneDeterministic(implementation, salt, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneDeterministic-address-bytes32-}[cloneDeterministic], but with
     * a `value` parameter to send native currency to the new contract.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneDeterministic(
        address implementation,
        bytes32 salt,
        uint256 value
    ) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        assembly ("memory-safe") {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(value, 0x09, 0x37, salt)
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x38), deployer)
            mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff)
            mstore(add(ptr, 0x14), implementation)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73)
            mstore(add(ptr, 0x58), salt)
            mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37))
            predicted := and(keccak256(add(ptr, 0x43), 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddress(implementation, salt, address(this));
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation` with custom
     * immutable arguments. These are provided through `args` and cannot be changed after deployment. To
     * access the arguments within the implementation, use {fetchCloneArgs}.
     *
     * This function uses the create opcode, which should never revert.
     */
    function cloneWithImmutableArgs(address implementation, bytes memory args) internal returns (address instance) {
        return cloneWithImmutableArgs(implementation, args, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneWithImmutableArgs-address-bytes-}[cloneWithImmutableArgs], but with a `value`
     * parameter to send native currency to the new contract.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneWithImmutableArgs(
        address implementation,
        bytes memory args,
        uint256 value
    ) internal returns (address instance) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        assembly ("memory-safe") {
            instance := create(value, add(bytecode, 0x20), mload(bytecode))
        }
        if (instance == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behavior of `implementation` with custom
     * immutable arguments. These are provided through `args` and cannot be changed after deployment. To
     * access the arguments within the implementation, use {fetchCloneArgs}.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy the clone. Using the same
     * `implementation`, `args` and `salt` multiple times will revert, since the clones cannot be deployed twice
     * at the same address.
     */
    function cloneDeterministicWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal returns (address instance) {
        return cloneDeterministicWithImmutableArgs(implementation, args, salt, 0);
    }

    /**
     * @dev Same as {xref-Clones-cloneDeterministicWithImmutableArgs-address-bytes-bytes32-}[cloneDeterministicWithImmutableArgs],
     * but with a `value` parameter to send native currency to the new contract.
     *
     * NOTE: Using a non-zero value at creation will require the contract using this function (e.g. a factory)
     * to always have enough balance for new deployments. Consider exposing this function under a payable method.
     */
    function cloneDeterministicWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt,
        uint256 value
    ) internal returns (address instance) {
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        return Create2.deploy(value, salt, bytecode);
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministicWithImmutableArgs}.
     */
    function predictDeterministicAddressWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        bytes memory bytecode = _cloneCodeWithImmutableArgs(implementation, args);
        return Create2.computeAddress(salt, keccak256(bytecode), deployer);
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministicWithImmutableArgs}.
     */
    function predictDeterministicAddressWithImmutableArgs(
        address implementation,
        bytes memory args,
        bytes32 salt
    ) internal view returns (address predicted) {
        return predictDeterministicAddressWithImmutableArgs(implementation, args, salt, address(this));
    }

    /**
     * @dev Get the immutable args attached to a clone.
     *
     * - If `instance` is a clone that was deployed using `clone` or `cloneDeterministic`, this
     *   function will return an empty array.
     * - If `instance` is a clone that was deployed using `cloneWithImmutableArgs` or
     *   `cloneDeterministicWithImmutableArgs`, this function will return the args array used at
     *   creation.
     * - If `instance` is NOT a clone deployed using this library, the behavior is undefined. This
     *   function should only be used to check addresses that are known to be clones.
     */
    function fetchCloneArgs(address instance) internal view returns (bytes memory) {
        bytes memory result = new bytes(instance.code.length - 45); // revert if length is too short
        assembly ("memory-safe") {
            extcodecopy(instance, add(result, 32), 45, mload(result))
        }
        return result;
    }

    /**
     * @dev Helper that prepares the initcode of the proxy with immutable args.
     *
     * An assembly variant of this function requires copying the `args` array, which can be efficiently done using
     * `mcopy`. Unfortunately, that opcode is not available before cancun. A pure solidity implementation using
     * abi.encodePacked is more expensive but also more portable and easier to review.
     *
     * NOTE: https://eips.ethereum.org/EIPS/eip-170[EIP-170] limits the length of the contract code to 24576 bytes.
     * With the proxy code taking 45 bytes, that limits the length of the immutable args to 24531 bytes.
     */
    function _cloneCodeWithImmutableArgs(
        address implementation,
        bytes memory args
    ) private pure returns (bytes memory) {
        if (args.length > 24531) revert CloneArgumentsTooLong();
        return
            abi.encodePacked(
                hex"61",
                uint16(args.length + 45),
                hex"3d81600a3d39f3363d3d373d3d3d363d73",
                implementation,
                hex"5af43d82803e903d91602b57fd5bf3",
                args
            );
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.22;

import {IBeacon} from "../beacon/IBeacon.sol";
import {IERC1967} from "../../interfaces/IERC1967.sol";
import {Address} from "../../utils/Address.sol";
import {StorageSlot} from "../../utils/StorageSlot.sol";

/**
 * @dev This library provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[ERC-1967] slots.
 */
library ERC1967Utils {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit IERC1967.Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by ERC-1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit IERC1967.AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the ERC-1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit IERC1967.BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (utils/Address.sol)

pragma solidity ^0.8.20;

import {Errors} from "./Errors.sol";

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, bytes memory returndata) = recipient.call{value: amount}("");
        if (!success) {
            _revert(returndata);
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Create2.sol)

pragma solidity ^0.8.20;

import {Errors} from "./Errors.sol";

/**
 * @dev Helper to make usage of the `CREATE2` EVM opcode easier and safer.
 * `CREATE2` can be used to compute in advance the address where a smart
 * contract will be deployed, which allows for interesting new mechanisms known
 * as 'counterfactual interactions'.
 *
 * See the https://eips.ethereum.org/EIPS/eip-1014#motivation[EIP] for more
 * information.
 */
library Create2 {
    /**
     * @dev There's no code to deploy.
     */
    error Create2EmptyBytecode();

    /**
     * @dev Deploys a contract using `CREATE2`. The address where the contract
     * will be deployed can be known in advance via {computeAddress}.
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * Requirements:
     *
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     * - the factory must have a balance of at least `amount`.
     * - if `amount` is non-zero, `bytecode` must have a `payable` constructor.
     */
    function deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }
        if (bytecode.length == 0) {
            revert Create2EmptyBytecode();
        }
        assembly ("memory-safe") {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
            // if no address was created, and returndata is not empty, bubble revert
            if and(iszero(addr), not(iszero(returndatasize()))) {
                let p := mload(0x40)
                returndatacopy(p, 0, returndatasize())
                revert(p, returndatasize())
            }
        }
        if (addr == address(0)) {
            revert Errors.FailedDeployment();
        }
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy}. Any change in the
     * `bytecodeHash` or `salt` will result in a new destination address.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Get free memory pointer

            // |                   | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
            // |-------------------|---------------------------------------------------------------------------|
            // | bytecodeHash      |                                                        CCCCCCCCCCCCC...CC |
            // | salt              |                                      BBBBBBBBBBBBB...BB                   |
            // | deployer          | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
            // | 0xFF              |            FF                                                             |
            // |-------------------|---------------------------------------------------------------------------|
            // | memory            | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
            // | keccak(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |

            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := and(keccak256(start, 85), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
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
// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */
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

    struct Int256Slot {
        int256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./XpadToken.sol";

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

    function WETH() external view returns (address);

    function factory() external view returns (address);
}

interface IUniswapV2Factory02 {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

contract PumpCloneFactory is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    struct TokenInfo {
        address creator;
        address tokenAddress;
        uint256 vReserveEth;
        uint256 vReserveToken;
        uint256 rReserveEth;
        uint256 rReserveToken;
        uint256 vLastReserveEth;
        uint256 vLastReserveToken;
        uint256 migrationPlatformFee;
        uint256 migrationLotteryFee;
        uint256 totalSupply;
        address lotteryWinner;
        bool liquidityMigrated;
        bool bLotteryClaim;
    }

    mapping(address => TokenInfo) public tokens;

    address public uniswapRouter;
    address public WETH;
    address public pumpTokenImplementation;
    address public platformWallet;
    address public treasuryWallet;

    uint256 public V_ETH_RESERVE;
    uint256 public V_TOKEN_RESERVE;
    uint256 public R_TOKEN_RESERVE;
    uint256 public TOTAL_SUPPLY;
    uint256 public TRADE_FEE_BPS;
    uint256 public BPS_DENOMINATOR;
    uint256 public LIQUIDITY_MIGRATION_PLATFORM_FEE_BPS;
    uint256 public LIQUIDITY_MIGRATION_LOTTERY_FEE_BPS;
    uint256 public totalFee;
    uint256 public UNISWAP_ETH_AMOUNT;
    uint256 public UNISWAP_MAX_FEE_BPS;
    uint256 public UNISWAP_TREASURY_FEE_BPS;
    uint256 public BUNDLE_BUY_LIMIT;

    event TokenLaunched(
        address indexed token,
        string name,
        string symbol,
        address indexed creator,
        uint256 virtualEthReserves,
        uint256 virtualTokenReserves,
        uint256 totalSupply,
        uint256 autoBuyAmount,
        address pair
    );
    event LiquiditySwapped(
        address indexed token,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 virtualEthReserves,
        uint256 virtualTokenReserves
    );
    event Trade(
        address indexed mint,
        uint256 ethAmount,
        uint256 tokenAmount,
        bool isBuy,
        address indexed user,
        uint256 timestamp,
        uint256 virtualEthReserves,
        uint256 virtualTokenReserves,
        uint256 totalSupply
    );

    event Lottery(
        address indexed token,
        address indexed winner,
        uint256 amount
    );

    event ParamsUpdated(
        string indexed what,
        uint256 firstParam,
        uint256 secondParam,
        uint256 thirdParam
    );

    event ParamsUpdatedTreasury(string indexed what, address indexed treasury);

    event UpdateTokenImpl(string indexed what, address indexed newTokenImpl);

    event DebugUint(string message, uint256 value);

    event MigrationFinalized(address indexed token, address indexed caller);

    event LPBurned(
        address indexed token,
        address indexed pair,
        uint256 lpAmount
    );

    modifier onlyAdmin() {
        require(
            msg.sender == owner() || msg.sender == platformWallet,
            "Not admin or owner"
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _router,
        address _pumpTokenImplementation
    ) public initializer {
        require(_router != address(0), "Router cannot be zero address");
        require(
            _pumpTokenImplementation != address(0),
            "Pump token implementation cannot be zero address"
        );

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        uniswapRouter = _router;
        WETH = IUniswapV2Router02(_router).WETH();
        pumpTokenImplementation = _pumpTokenImplementation;

        V_ETH_RESERVE = 105 ether / 100000; //mainnet: 105 ether / 100;
        V_TOKEN_RESERVE = 1000000000 ether;
        R_TOKEN_RESERVE = 800000000 ether;
        TRADE_FEE_BPS = 100; // 1% fee in basis points
        BPS_DENOMINATOR = 10000;
        LIQUIDITY_MIGRATION_PLATFORM_FEE_BPS = 200; // 2% fee for liquidity migration
        LIQUIDITY_MIGRATION_LOTTERY_FEE_BPS = 300; // 3% fee for liquidity migration
        TOTAL_SUPPLY = 1000000000 ether; // 1 billion tokens
        UNISWAP_ETH_AMOUNT = 4 ether / 1000; //mainnet: 4 ether; // 4 ETH for initial liquidity
        treasuryWallet = 0xC4975f04420237E83558e4417136c8AF0b60137d;
        UNISWAP_MAX_FEE_BPS = 1000;
        UNISWAP_TREASURY_FEE_BPS = 2000;
        BUNDLE_BUY_LIMIT = 1 ether / 1000; //mainnet: 1 ether;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function launchToken(
        string memory _name,
        string memory _symbol,
        address _uniswapMarketingWallet,
        address _uniswapDevelopmentWallet,
        uint256 _uniswapMarketingTaxFee,
        uint256 _uniswapDevelopmentTaxFee,
        uint256 _uniswapCreatorTaxFee
    ) external payable nonReentrant {
        require(msg.value <= BUNDLE_BUY_LIMIT, "Bundle buy amount over limit");

        _launchTokenWithXpad(
            _name,
            _symbol,
            _uniswapMarketingWallet,
            _uniswapDevelopmentWallet,
            _uniswapMarketingTaxFee,
            _uniswapDevelopmentTaxFee,
            _uniswapCreatorTaxFee,
            bytes32(0), // Use zero xpad for backward compatibility
            msg.value
        );
    }

    function launchXpadToken(
        string memory _name,
        string memory _symbol,
        address _uniswapMarketingWallet,
        address _uniswapDevelopmentWallet,
        uint256 _uniswapMarketingTaxFee,
        uint256 _uniswapDevelopmentTaxFee,
        uint256 _uniswapCreatorTaxFee,
        bytes32 _xpad
    ) external payable nonReentrant {
        require(msg.value <= BUNDLE_BUY_LIMIT, "Bundle buy amount over limit");

        _launchTokenWithXpad(
            _name,
            _symbol,
            _uniswapMarketingWallet,
            _uniswapDevelopmentWallet,
            _uniswapMarketingTaxFee,
            _uniswapDevelopmentTaxFee,
            _uniswapCreatorTaxFee,
            _xpad,
            msg.value
        );
    }

    function _launchTokenWithXpad(
        string memory _name,
        string memory _symbol,
        address _uniswapMarketingWallet,
        address _uniswapDevelopmentWallet,
        uint256 _uniswapMarketingTaxFee,
        uint256 _uniswapDevelopmentTaxFee,
        uint256 _uniswapCreatorTaxFee,
        bytes32 _xpad,
        uint256 ethAmount
    ) internal {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");
        require(
            _uniswapMarketingWallet != address(0),
            "Marketing wallet cannot be zero"
        );
        require(
            _uniswapDevelopmentWallet != address(0),
            "Development wallet cannot be zero"
        );

        require(
            _uniswapMarketingTaxFee +
                _uniswapDevelopmentTaxFee +
                _uniswapCreatorTaxFee <=
                UNISWAP_MAX_FEE_BPS,
            "Exceeds max fee limit"
        );

        // Create clone
        address payable clone = payable(
            _xpad == bytes32(0)
                ? Clones.clone(pumpTokenImplementation)
                : Clones.cloneDeterministic(pumpTokenImplementation, _xpad)
        );

        // Calculate fees adjusted for treasury
        uint256 feeDenominator = BPS_DENOMINATOR - UNISWAP_TREASURY_FEE_BPS;

        uint256 uniswapMarketingFee = (_uniswapMarketingTaxFee *
            feeDenominator) / BPS_DENOMINATOR;
        uint256 uniswapDevelopmentFee = (_uniswapDevelopmentTaxFee *
            feeDenominator) / BPS_DENOMINATOR;
        uint256 uniswapCreatorFee = (_uniswapCreatorTaxFee * feeDenominator) /
            BPS_DENOMINATOR;
        uint256 uniswapTreasuryFee = (_uniswapMarketingTaxFee -
            uniswapMarketingFee) +
            (_uniswapDevelopmentTaxFee - uniswapDevelopmentFee) +
            (_uniswapCreatorTaxFee - uniswapCreatorFee);

        require(
            uniswapMarketingFee +
                uniswapDevelopmentFee +
                uniswapCreatorFee +
                uniswapTreasuryFee <=
                UNISWAP_MAX_FEE_BPS,
            "Fee breakdown exceeds limit"
        );

        // Initialize token
        XpadToken(clone).initialize(
            _name,
            _symbol,
            msg.sender,
            _uniswapMarketingWallet,
            _uniswapDevelopmentWallet,
            treasuryWallet,
            uniswapMarketingFee,
            uniswapDevelopmentFee,
            uniswapCreatorFee,
            uniswapTreasuryFee,
            TOTAL_SUPPLY,
            uniswapRouter
        );

        // Store token info
        TokenInfo storage info = tokens[clone];
        info.creator = msg.sender;
        info.tokenAddress = clone;
        info.rReserveEth = 0;
        info.rReserveToken = R_TOKEN_RESERVE;
        info.vReserveEth = V_ETH_RESERVE;
        info.vReserveToken = V_TOKEN_RESERVE;
        info.migrationPlatformFee =
            (UNISWAP_ETH_AMOUNT * LIQUIDITY_MIGRATION_PLATFORM_FEE_BPS) /
            BPS_DENOMINATOR;
        info.migrationLotteryFee =
            (UNISWAP_ETH_AMOUNT * LIQUIDITY_MIGRATION_LOTTERY_FEE_BPS) /
            BPS_DENOMINATOR;
        info.vLastReserveEth =
            info.vReserveEth +
            info.migrationPlatformFee +
            info.migrationLotteryFee +
            UNISWAP_ETH_AMOUNT;
        info.vLastReserveToken = info.vReserveToken - info.rReserveToken;
        info.totalSupply = TOTAL_SUPPLY;
        info.liquidityMigrated = false;
        info.bLotteryClaim = false;

        // Mint total supply to factory
        XpadToken(clone).mintFromFactory(address(this), TOTAL_SUPPLY);

        // Auto-buy if ETH sent
        if (ethAmount > 0) {
            _buyToken(clone, 0, ethAmount, true);
        }

        // Get factory address from router
        address factory = IUniswapV2Router02(uniswapRouter).factory();

        // Get LP pair address for token + WETH
        address pair = IUniswapV2Factory02(factory).getPair(
            clone,
            IUniswapV2Router02(uniswapRouter).WETH()
        );

        require(pair != address(0), "Pair does not exist");
        require(
            XpadToken(clone).uniswapPair() != address(0),
            "Uniswap pair does not exist"
        );
        require(
            pair == XpadToken(clone).uniswapPair(),
            "Uniswap pair not matching"
        );

        emit TokenLaunched(
            clone,
            _name,
            _symbol,
            msg.sender,
            info.vReserveEth,
            info.vReserveToken,
            info.totalSupply,
            ethAmount,
            pair
        );
    }

    function _calculateReserveAfterBuy(
        uint256 reserveEth,
        uint256 reserveToken,
        uint256 ethIn
    ) internal pure returns (uint256, uint256) {
        uint256 newReserveEth = ethIn + reserveEth;
        uint256 newReserveToken = (reserveEth * reserveToken) / newReserveEth;
        return (newReserveEth, newReserveToken);
    }

    function buyToken(
        address _token,
        uint256 minTokensOut
    ) external payable nonReentrant {
        require(msg.value > 0, "No ETH sent");
        _buyToken(_token, minTokensOut, msg.value, false);
    }

    function _buyToken(
        address _token,
        uint256 minTokensOut,
        uint256 ethAmount,
        bool isBundle
    ) internal {
        require(ethAmount > 0, "ETH amount must be > 0");

        TokenInfo storage info = tokens[_token];
        require(info.tokenAddress != address(0), "Invalid token");
        require(!info.liquidityMigrated, "Trading moved to Uniswap");
        require(TRADE_FEE_BPS < BPS_DENOMINATOR, "Invalid fee config");

        // ===== Effects first =====
        uint256 fee = (ethAmount * TRADE_FEE_BPS + BPS_DENOMINATOR / 2) /
            BPS_DENOMINATOR;
        uint256 netEthIn = ethAmount - fee;

        (
            uint256 newReserveEth,
            uint256 newReserveToken
        ) = _calculateReserveAfterBuy(
                info.vReserveEth,
                info.vReserveToken,
                netEthIn
            );

        uint256 tokensOut = info.vReserveToken - newReserveToken;

        uint256 refundAmount = 0;
        if (tokensOut > info.rReserveToken) {
            tokensOut = info.rReserveToken;
            newReserveEth = info.vLastReserveEth;
            newReserveToken = info.vLastReserveToken;

            // Recompute the exact ETH used and fee for the capped purchase
            uint256 targetNetEthIn = newReserveEth - info.vReserveEth;
            uint256 denom = BPS_DENOMINATOR - TRADE_FEE_BPS;
            // ceil division for ethUsed = ceil(targetNetEthIn * BPS_DENOMINATOR / denom)
            uint256 ethUsed = (targetNetEthIn * BPS_DENOMINATOR + denom - 1) /
                denom;
            uint256 newFee = ethUsed - targetNetEthIn;

            // Refund any unused ETH

            if (ethAmount > ethUsed) {
                refundAmount = ethAmount - ethUsed;
            }

            // Update local accounting variables to reflect the capped usage
            netEthIn = targetNetEthIn;
            fee = newFee;
        }

        require(tokensOut > 0, "Insufficient output amount");
        require(tokensOut >= minTokensOut, "Slippage too high");

        info.vReserveEth = newReserveEth;
        info.vReserveToken = newReserveToken;
        info.rReserveEth += netEthIn;
        info.rReserveToken -= tokensOut;

        // ===== Interactions =====
        IERC20 token = IERC20(_token);
        require(token.transfer(msg.sender, tokensOut), "Token transfer failed");

        if (fee > 0) {
            (bool sent, ) = payable(treasuryWallet).call{value: fee}("");
            require(sent, "Fee transfer failed");
        }

        // Perform refund early to minimize holding excess funds
        if (refundAmount > 0) {
            (bool refunded, ) = payable(msg.sender).call{value: refundAmount}(
                ""
            );
            require(refunded, "Refund failed");
        }

        if (!isBundle) {
            emit Trade(
                _token,
                netEthIn,
                tokensOut,
                true,
                msg.sender,
                block.timestamp,
                info.vReserveEth,
                info.vReserveToken,
                info.totalSupply
            );
        }

        // Auto-migrate liquidity if reserve empty
        if (info.rReserveToken == 0) {
            require(
                info.rReserveEth >=
                    info.migrationPlatformFee +
                        info.migrationLotteryFee +
                        UNISWAP_ETH_AMOUNT,
                "Not enough ETH for migration"
            );

            address payable tokenPayable = payable(_token);
            XpadToken(tokenPayable).setIsBondingCurve(false);
            _addLiquidityToUniswap(_token);
            // new
            info.liquidityMigrated = true;
        }
    }

    function sellToken(
        address _token,
        uint256 tokenAmount,
        uint256 slippageAmount
    ) external nonReentrant {
        TokenInfo storage info = tokens[_token];
        require(info.tokenAddress != address(0), "Invalid token");
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(!info.liquidityMigrated, "Trading moved to Uniswap");

        uint256 newReserveToken = info.vReserveToken + tokenAmount;
        uint256 newReserveEth = (info.vReserveEth *
            info.vReserveToken +
            newReserveToken -
            1) / newReserveToken;

        uint256 grossEthOut = info.vReserveEth - newReserveEth;
        uint256 fee = (grossEthOut * TRADE_FEE_BPS + BPS_DENOMINATOR / 2) /
            BPS_DENOMINATOR;
        uint256 netEthOut = grossEthOut - fee;

        require(
            grossEthOut > 0 && grossEthOut <= info.rReserveEth,
            "Insufficient ETH in contract"
        );

        require(
            netEthOut >= slippageAmount,
            "Swap failed: output amount too low due to slippage"
        );

        bool success = IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );
        require(success, "Transfer failed");

        info.vReserveEth = newReserveEth;
        info.vReserveToken = newReserveToken;
        info.rReserveEth -= grossEthOut;
        info.rReserveToken += tokenAmount;

        if (netEthOut > 0) {
            (bool ethTransferSuccess, ) = msg.sender.call{value: netEthOut}("");
            require(ethTransferSuccess, "ETH transfer failed");
        }

        if (fee > 0) {
            (bool sent, ) = treasuryWallet.call{value: fee}("");
            require(sent, "Fee transfer failed");
        }

        emit Trade(
            _token,
            netEthOut,
            tokenAmount,
            false,
            msg.sender,
            block.timestamp,
            info.vReserveEth,
            info.vReserveToken,
            info.totalSupply
        );
    }

    function _addLiquidityToUniswap(address _token) internal {
        TokenInfo storage info = tokens[_token];

        uint256 ethAmount = info.rReserveEth -
            info.migrationPlatformFee -
            info.migrationLotteryFee;

        require(
            ethAmount >= UNISWAP_ETH_AMOUNT,
            "not enough ETH in the Uniswap"
        );

        uint256 tokenAmount = TOTAL_SUPPLY - R_TOKEN_RESERVE;

        IERC20(_token).approve(uniswapRouter, tokenAmount);
        require(
            IERC20(_token).balanceOf(address(this)) >= tokenAmount,
            "not enough tokens for liquidity"
        );

        // add liquidity
        IUniswapV2Router02(uniswapRouter).addLiquidityETH{
            value: UNISWAP_ETH_AMOUNT
        }(
            _token,
            tokenAmount,
            tokenAmount,
            UNISWAP_ETH_AMOUNT,
            address(this),
            block.timestamp + 1200
        );

        // reset approve (optional)
        IERC20(_token).approve(uniswapRouter, 0);

        // Get factory address from router
        address factory = IUniswapV2Router02(uniswapRouter).factory();

        // Get LP pair address for token + WETH
        address pair = IUniswapV2Factory02(factory).getPair(
            _token,
            IUniswapV2Router02(uniswapRouter).WETH()
        );

        // Burn LP tokens if contract received any
        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        if (lpBalance > 0) {
            IERC20(pair).transfer(
                0x000000000000000000000000000000000000dEaD,
                lpBalance
            );
            emit LPBurned(_token, pair, lpBalance);
        }

        (bool ok, ) = payable(treasuryWallet).call{
            value: info.migrationPlatformFee
        }("");
        require(ok, "treasury transfer failed");

        emit LiquiditySwapped(
            _token,
            tokenAmount,
            UNISWAP_ETH_AMOUNT,
            info.vReserveEth,
            info.vReserveToken
        );
    }

    function _burnLiquidity(address _token) internal {
        address factory = IUniswapV2Router02(uniswapRouter).factory();
        address pair = IUniswapV2Factory02(factory).getPair(_token, WETH);
        require(pair != address(0), "Pair does not exist");

        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        require(lpBalance > 0, "No LP tokens to burn");

        // Send LP tokens to dead address
        IERC20(pair).transfer(
            address(0x000000000000000000000000000000000000dEaD),
            lpBalance
        );

        emit LPBurned(_token, pair, lpBalance);
    }

    function updateReserves(
        uint256 _vEthReserve,
        uint256 _vTokenReserve,
        uint256 _rTokenReserve
    ) external onlyOwner {
        require(_vEthReserve > 0, "Virtual ETH reserve must be positive");
        require(_vTokenReserve > 0, "Virtual token reserve must be positive");
        require(_rTokenReserve > 0, "Real token reserve must be positive");
        require(
            _rTokenReserve <= _vTokenReserve,
            "Real reserve cannot exceed virtual"
        );

        V_ETH_RESERVE = _vEthReserve;
        V_TOKEN_RESERVE = _vTokenReserve;
        R_TOKEN_RESERVE = _rTokenReserve;
        emit ParamsUpdated(
            "reserves",
            _vEthReserve,
            _vTokenReserve,
            _rTokenReserve
        );
    }

    function updateFeeRate(uint256 value) external onlyOwner {
        TRADE_FEE_BPS = value;
        emit ParamsUpdated("tradeFee", value, 0, 0);
    }

    function updateBundleBuyLimit(uint256 value) external onlyOwner {
        BUNDLE_BUY_LIMIT = value;
        emit ParamsUpdated("bundleBuyLimit", value, 0, 0);
    }

    function updateLiquidityMigrationFeeRate(
        uint256 value,
        uint256 _value
    ) external onlyOwner {
        LIQUIDITY_MIGRATION_PLATFORM_FEE_BPS = value;
        LIQUIDITY_MIGRATION_LOTTERY_FEE_BPS = _value;
        emit ParamsUpdated("migrateFee", value, _value, 0);
    }

    function updateUniswapMaxFeeRate(uint256 value) external onlyOwner {
        UNISWAP_MAX_FEE_BPS = value;
        emit ParamsUpdated("uniswapMaxFee", value, 0, 0);
    }

    function updateUniswapEthAmount(uint256 value) external onlyOwner {
        UNISWAP_ETH_AMOUNT = value;
        emit ParamsUpdated("uniswapEthAmount", value, 0, 0);
    }

    function updateTreasuryWallet(address value) external onlyOwner {
        require(value != address(0), "Treasury cannot be zero address");
        treasuryWallet = value;
        emit ParamsUpdatedTreasury("treasuryWallet", treasuryWallet);
    }

    function setAdmin(address _platformWallet) external onlyOwner {
        require(_platformWallet != address(0), "Invalid admin address");
        platformWallet = _platformWallet;
    }

    function updatePumpTokenImplementationAddress(
        address value
    ) external onlyOwner {
        require(value != address(0), "Implementation cannot be zero address");
        pumpTokenImplementation = value;
        emit UpdateTokenImpl("newTokenImplAddress", pumpTokenImplementation);
    }

    function sendLotteryWinner(
        address _token,
        address winner
    ) external onlyAdmin nonReentrant {
        require(winner != address(0), "Winner cannot be zero address");
        require(_token != address(0), "Token cannot be zero address");
        // need to open when mainnet launch
        TokenInfo storage info = tokens[_token];
        require(info.tokenAddress != address(0), "Invalid token");

        require(info.liquidityMigrated, "Not migrated to uniswap");
        require(info.bLotteryClaim == false, "Lottery already claimed");

        info.bLotteryClaim = true;
        info.lotteryWinner = winner;

        uint256 lotteryFee = info.migrationLotteryFee;
        // uint256 txFee = 2 ether / 10000; // example fixed fee

        // require(lotteryFee > txFee, "Fee exceeds reward");
        require(address(this).balance >= lotteryFee, "Not enough balance");

        // uint256 winnerAmount = lotteryFee - txFee;

        // Send reward to winner
        (bool ok, ) = payable(winner).call{value: lotteryFee}("");
        require(ok, "Transfer failed");

        // Send tx fee to caller (admin)
        // payable(msg.sender).transfer(txFee);
        emit Lottery(_token, winner, lotteryFee);
    }

    function finalizeMigration(address _token) external onlyAdmin {
        TokenInfo storage info = tokens[_token];
        require(info.liquidityMigrated, "Migration not done");
        // call token renounce from factory
        // new
        address payable tokenPayable = payable(_token);
        XpadToken(tokenPayable).renounceFactory();
        emit MigrationFinalized(_token, msg.sender);
    }

    // External wrapper to call your internal LP burn function
    function burnLiquidity(address _token) external onlyAdmin {
        _burnLiquidity(_token);
    }

    function predictTokenAddress(bytes32 xpad) external view returns (address) {
        return
            Clones.predictDeterministicAddress(
                pumpTokenImplementation,
                xpad,
                address(this)
            );
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT

/*
Powered by XPAD
---------------------
XPAD: The decentralized launchpad with lottery + low fees

Create your own token today at 
https://xpad.fun

Join us on telegram: https://t.me/Xerc20 
Join us on X: http://x.com/XERS_official
*/

pragma solidity ^0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
}

interface IUniswapV2Router {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function WETH() external pure returns (address);

    function factory() external view returns (address);
}

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract XpadToken is ReentrancyGuard {
    string public name;
    string public symbol;
    uint8 public decimals;

    address public factory;
    address payable public creator;
    address payable public treasury;
    address payable public uniswapMarketingWallet;
    address payable public uniswapDevelopmentWallet;

    IUniswapV2Router public uniswapRouter;
    address public uniswapPair;

    bool public isBondingCurve;
    bool public initialized;
    uint256 public maxSupply;

    uint256 public taxFeeToTreasury;
    uint256 public uniswapMarketingTaxFee;
    uint256 public uniswapDevelopmentTaxFee;
    uint256 public uniswapCreatorTaxFee;
    uint256 public totalSupply;
    uint256 public pendingSwapAmount;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public isFeeWhitelisted;
    mapping(address => uint256) public failedPayments;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event FactoryRenounced();
    event UniswapPairCreated(address pair);
    event FallbackToWETH(address indexed to, uint256 amount);
    event PaymentFailed(address indexed to, uint256 amount);

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can call");
        _;
    }

    function initialize(
        string memory _name,
        string memory _symbol,
        address _creator,
        address _uniswapMarketingWallet,
        address _uniswapDevelopmentWallet,
        address _treasury,
        uint256 _uniswapMarketingTaxFee,
        uint256 _uniswapDevelopmentTaxFee,
        uint256 _uniswapCreatorTaxFee,
        uint256 _feeTreasury,
        uint256 _maxSupply,
        address _uniswapRouter
    ) external {
        require(!initialized, "Already initialized");

        // Input validation
        require(_creator != address(0), "Creator cannot be zero address");
        require(_treasury != address(0), "Treasury cannot be zero address");
        require(_uniswapRouter != address(0), "Router cannot be zero address");

        name = _name;
        symbol = _symbol;
        creator = payable(_creator);
        factory = msg.sender;
        treasury = payable(_treasury);

        uniswapMarketingWallet = payable(_uniswapMarketingWallet);
        uniswapDevelopmentWallet = payable(_uniswapDevelopmentWallet);

        uniswapMarketingTaxFee = _uniswapMarketingTaxFee;
        uniswapDevelopmentTaxFee = _uniswapDevelopmentTaxFee;
        uniswapCreatorTaxFee = _uniswapCreatorTaxFee;
        taxFeeToTreasury = _feeTreasury;
        maxSupply = _maxSupply;
        uniswapRouter = IUniswapV2Router(_uniswapRouter);
        isFeeWhitelisted[msg.sender] = true;
        isFeeWhitelisted[address(this)] = true;
        pendingSwapAmount = 0;

        decimals = 18;
        isBondingCurve = true;
        initialized = true;

        // Ensure Uniswap pair exists
        address weth = uniswapRouter.WETH();
        address pair = IUniswapV2Factory(uniswapRouter.factory()).getPair(
            address(this),
            weth
        );

        require(pair == address(0), "Pair already exists");

        pair = IUniswapV2Factory(uniswapRouter.factory()).createPair(
            address(this),
            weth
        );

        require(pair != address(0), "Pair creation failed");

        uniswapPair = pair;
        emit UniswapPairCreated(pair);
    }

    /**
     * @notice Adds or removes an address from the fee whitelist.
     */
    function feeWL(address _address, bool _status) external onlyFactory {
        isFeeWhitelisted[_address] = _status;
    }

    function setIsBondingCurve(bool _isBondingCurve) external onlyFactory {
        isBondingCurve = _isBondingCurve;
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Mint to zero address");
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function mintFromFactory(address to, uint256 amount) external onlyFactory {
        require(totalSupply + amount <= maxSupply, "Cap exceeded");
        _mint(to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function renounceFactory() external onlyFactory {
        factory = address(0);
        emit FactoryRenounced();
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool) {
        allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool) {
        uint256 current = allowance[msg.sender][spender];
        require(current >= subtractedValue, "Decreased below zero");
        allowance[msg.sender][spender] = current - subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        require(to != address(0), "Transfer to zero address");
        // block transfers to uniswap pair until migration
        if (isBondingCurve && to == uniswapPair) {
            revert("Trading not enabled yet");
        }

        uint256 feeTreasury = 0;
        uint256 feeMarketing = 0;
        uint256 feeDevelopment = 0;
        uint256 feeCreator = 0;

        if (!isBondingCurve && !isFeeWhitelisted[msg.sender]) {
            feeTreasury = (amount * taxFeeToTreasury) / 10000;
            feeMarketing = (amount * uniswapMarketingTaxFee) / 10000;
            feeDevelopment = (amount * uniswapDevelopmentTaxFee) / 10000;
            feeCreator = (amount * uniswapCreatorTaxFee) / 10000;
        }

        uint256 totalFee = feeTreasury +
            feeMarketing +
            feeDevelopment +
            feeCreator;

        require(totalFee <= amount / 4, "Fee calculation error");
        uint256 amountAfterFee = amount - totalFee;

        balanceOf[msg.sender] -= amount;

        // Swap fees to ETH immediately
        if (totalFee > 0) {
            // Accumulate fees in contract
            balanceOf[address(this)] += totalFee;
            emit Transfer(msg.sender, address(this), totalFee);

            // Transfer net amount
            balanceOf[to] += amountAfterFee;
            emit Transfer(msg.sender, to, amountAfterFee);

            swapAndSendToFee(totalFee);
        } else {
            // Transfer net amount
            balanceOf[to] += amount;
            emit Transfer(msg.sender, to, amount);
        }
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(
            allowance[from][msg.sender] >= amount,
            "Insufficient allowance"
        );
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(to != address(0), "Transfer to zero address");

        // block transfers to uniswap pair until migration
        if (isBondingCurve && to == uniswapPair) {
            revert("Trading not enabled yet");
        }

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;

        uint256 feeTreasury = 0;
        uint256 feeMarketing = 0;
        uint256 feeDevelopment = 0;
        uint256 feeCreator = 0;

        if (!isBondingCurve && !isFeeWhitelisted[from]) {
            require(amount > 0, "Amount must be positive");

            feeTreasury = (amount * taxFeeToTreasury) / 10000;
            feeMarketing = (amount * uniswapMarketingTaxFee) / 10000;
            feeDevelopment = (amount * uniswapDevelopmentTaxFee) / 10000;
            feeCreator = (amount * uniswapCreatorTaxFee) / 10000;
        }

        uint256 totalFee = feeTreasury +
            feeMarketing +
            feeDevelopment +
            feeCreator;

        require(totalFee <= amount / 4, "Fee calculation error");

        uint256 amountAfterFee = amount - totalFee;

        // Swap fees to ETH immediately
        if (totalFee > 0) {
            // Accumulate fees in contract
            balanceOf[address(this)] += totalFee;
            emit Transfer(from, address(this), totalFee);

            // Transfer net amount
            balanceOf[to] += amountAfterFee;
            emit Transfer(from, to, amountAfterFee);

            swapAndSendToFee(totalFee + pendingSwapAmount);
        } else {
            // Transfer net amount
            balanceOf[to] += amount;
            emit Transfer(from, to, amount);
        }

        return true;
    }

    function swapAndSendToFee(uint256 tokenAmount) internal nonReentrant {
        uint256 initialBalance = address(this).balance;
        _swapFeeTokensToETH(tokenAmount);
        uint256 newBalance = address(this).balance - initialBalance;

        uint256 totalFeePerc = taxFeeToTreasury +
            uniswapMarketingTaxFee +
            uniswapDevelopmentTaxFee +
            uniswapCreatorTaxFee;

        if (newBalance > 0 && totalFeePerc > 0) {
            if (taxFeeToTreasury > 0)
                _safeSend(
                    treasury,
                    (newBalance * taxFeeToTreasury) /
                        totalFeePerc +
                        failedPayments[treasury]
                );
            if (uniswapMarketingTaxFee > 0)
                _safeSend(
                    uniswapMarketingWallet,
                    (newBalance * uniswapMarketingTaxFee) /
                        totalFeePerc +
                        failedPayments[uniswapMarketingWallet]
                );
            if (uniswapDevelopmentTaxFee > 0)
                _safeSend(
                    uniswapDevelopmentWallet,
                    (newBalance * uniswapDevelopmentTaxFee) /
                        totalFeePerc +
                        failedPayments[uniswapDevelopmentWallet]
                );
            if (uniswapCreatorTaxFee > 0)
                _safeSend(
                    creator,
                    (newBalance * uniswapCreatorTaxFee) /
                        totalFeePerc +
                        failedPayments[creator]
                );
        }
    }

    function _safeSend(address payable to, uint256 amount) private {
        (bool success, ) = to.call{value: amount, gas: 10000}("");
        if (!success) {
            IWETH weth = IWETH(uniswapRouter.WETH());

            try weth.deposit{value: amount}() {
                bool wethSuccess = weth.transfer(to, amount);
                require(wethSuccess, "WETH transfer failed");

                // Emit event to notify recipient they received WETH instead of ETH
                emit FallbackToWETH(to, amount);
            } catch {
                // As last resort, store failed payment for manual withdrawal
                failedPayments[to] += amount;
                emit PaymentFailed(to, amount);
            }
        }
    }

    function _swapFeeTokensToETH(uint256 tokenAmount) private {
        require(balanceOf[address(this)] >= tokenAmount, "Not enough tokens");

        _approve(address(this), address(uniswapRouter), tokenAmount);

        uint256 minEthOut = (getExpectedEthOutput(tokenAmount) * 95) / 100;
        require(minEthOut >= 0, "Min ETH output is zero");

        address[] memory path = new address[](2);
        path[0] = address(this); // Token address
        path[1] = uniswapRouter.WETH(); // WETH address

        try
            uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                minEthOut,
                path,
                address(this),
                block.timestamp + 300
            )
        {
            pendingSwapAmount = 0;
        } catch {
            pendingSwapAmount += tokenAmount;
        }
    }

    function getExpectedEthOutput(
        uint256 tokenAmount
    ) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(this); // your token
        path[1] = uniswapRouter.WETH();

        uint[] memory amounts = uniswapRouter.getAmountsOut(tokenAmount, path);
        return amounts[1]; // expected ETH output
    }

    receive() external payable {}
}
