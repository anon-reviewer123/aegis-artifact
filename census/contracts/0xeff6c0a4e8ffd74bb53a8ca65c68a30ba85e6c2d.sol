// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
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
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 *
 * _Available since v4.8.3._
 */
interface IERC1967Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/IERC1967Upgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import {Initializable} from "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable, IERC1967Upgradeable {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            AddressUpgradeable.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data, bool forceCall) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            AddressUpgradeable.functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

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
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
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
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
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
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
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
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeTo(address newImplementation) public virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
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
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

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
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, `uint256`._
 * _Available since v4.9 for `string`, `bytes`._
 */
library StorageSlotUpgradeable {
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
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPerlinNoise {
    function noise3d(int256, int256, int256) external view returns (int256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Status} from "../lib/Types.sol";

interface ITerraforms {
    function dreamers() external view returns (uint256);

    function ownerOf(uint256) external view returns (address);

    function tokenToDreamer(uint256) external view returns (address);

    function tokenToPlacement(uint256) external view returns (uint256);

    function tokenToStatus(uint256) external view returns (Status);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITerraformsData_v0 {
    function characterSet(
        uint256,
        uint256
    ) external view returns (string[9] memory, uint256, uint256, uint256);

    function levelAndTile(
        uint256,
        uint256
    ) external view returns (uint256, uint256);

    function levelDimensions(uint256) external view returns (uint256);

    function resourceLevel(uint256, uint256) external view returns (uint256);

    function resourceName() external view returns (string memory);

    function tokenElevation(
        uint256,
        uint256,
        uint256
    ) external view returns (int256);

    function tokenZone(
        uint256,
        uint256
    ) external view returns (string[10] memory, string memory);

    function xOrigin(uint256, uint256, uint256) external view returns (int256);

    function yOrigin(uint256, uint256, uint256) external view returns (int256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITerraformsData {
    function tokenHeightmapIndices(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256[] memory
    ) external view returns (uint256[32][32] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Activation} from "../lib/Types.sol";

interface ITerraformsHelpers {
    function addressToENS(address) external view returns (string memory);

    function addressToString(address) external view returns (string memory);

    function calculateSeed(uint, uint) external pure returns (uint);

    function getActivation(uint256, uint256) external pure returns (Activation);

    function resourceDirection() external view returns (int256 result);

    function reverseUint(uint256) external view returns (uint256);

    function structureDecay(uint256) external view returns (uint256);

    function zOrigin(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) external view returns (int256);

    function zOscillation(
        uint256 level,
        uint256 decay,
        uint256 timestamp
    ) external view returns (int256 result);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AnimParams} from "../lib/Types.sol";

interface ITerraformsTokenURI {
    function tokenURI(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256[] memory
    ) external view returns (string memory);

    function tokenHTML(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256[] memory
    ) external view returns (string memory);

    function tokenSVG(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256[] memory
    ) external view returns (string memory);

    function animationParameters(
        uint256,
        uint256
    ) external view returns (AnimParams memory);

    function durations(uint256) external view returns (uint256);
    function antennaHeightmap(uint) external view returns (uint[32][32] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum AntennaStatus {
    Off,
    On,
    ConnectedToSatellite
}

enum AntennaModification {
    TurnedAntennaOff,
    TurnedAntennaOn,
    TunedToCapturedSatelliteConnection,
    CapturedSatelliteConnection
}

enum Activation {
    Cascade,
    Plague
}

enum Status {
    Terrain,
    Daydream,
    Terraformed,
    OriginDaydream,
    OriginTerraformed
}

struct SVGParams {
    uint256[32][32] heightmapIndices;
    uint256 level;
    uint256 tile;
    uint256 resourceLvl;
    uint256 resourceDirection;
    uint256 status;
    uint256 font;
    uint256 fontSize;
    uint256 biome;
    int attunement;
    AntennaStatus antenna;
    string zoneName;
    string script;
    string[9] chars;
    string[10] zoneColors;
}

struct AnimParams {
    Activation activation; // Token's animation type
    uint256 classesAnimated; // Classes animated
    uint256 duration; // Base animation duration for first class
    uint256 durationInc; // Duration increment for each class
    uint256 delay; // Base delay for first class
    uint256 delayInc; // Delay increment for each class
    uint256 bgDuration; // Animation duration for background
    uint256 bgDelay; // Delay for background
    string easing; // Animation mode, e.g. steps(), linear, ease-in-out
    string[2] altColors;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ITerraformsData} from "./interfaces/ITerraformsData.sol";
import {ITerraforms, Status} from "./interfaces/ITerraforms.sol";
import {ITerraformsHelpers, Activation} from "./interfaces/ITerraformsHelpers.sol";
import {ITerraformsTokenURI, AnimParams} from "./interfaces/ITerraformsTokenURI.sol";
import {ITerraformsData_v0} from "./interfaces/ITerraformsData_v0.sol";
import {IPerlinNoise} from "./interfaces/IPerlinNoise.sol";

/// @author xaltgeist, with code direction and consultation from 113
/// @title Token data for the Terraforms contract, version 2.0
/// @dev Terraforms data is generated on-demand; Terraforms are not stored
contract TerraformsData_v2_0 is
    ITerraformsData,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    string public version;

    // Interfaces
    ITerraforms terraforms;
    ITerraformsHelpers helpers;
    ITerraformsTokenURI TFTokenURI;
    IPerlinNoise perlinNoise;
    ITerraformsData_v0 dataV0;

    // Visualization info
    uint256 public MAX_SUPPLY;
    uint256 public TOKEN_DIMS;
    uint256 public SEED;
    int256 public STEP;
    int256[8] public topography;
    uint256[20] public levelDimensions;
    bool public isLocked;

    modifier notLocked() {
        require(isLocked == false, "Terraforms Data: Contract is locked");
        _;
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * INITIALIZER
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _helpersAddress,
        address _tokenURIAddress
    ) public initializer {
        __Ownable_init();
        version = "Version 2.0";
        terraforms = ITerraforms(0x4E1f41613c9084FdB9E34E11fAE9412427480e56);
        perlinNoise = IPerlinNoise(0x53B811757fC725aB3556Bc00237D9bBcF2c0DfDE); // Generates terrain
        helpers = ITerraformsHelpers(_helpersAddress);
        TFTokenURI = ITerraformsTokenURI(_tokenURIAddress);
        dataV0 = ITerraformsData_v0(0xA5aFC9fE76a28fB12C60954Ed6e2e5f8ceF64Ff2); // Prior implementation of TerraformsData.sol
        MAX_SUPPLY = 11104;
        TOKEN_DIMS = 32;
        SEED = 10196;
        STEP = 6619;
        topography = [
            int256(18000),
            int256(12000),
            int256(4000),
            -4000,
            -12000,
            -20000,
            -22000,
            -26000
        ];
        levelDimensions = [
            4,
            8,
            8,
            16,
            16,
            24,
            24,
            24,
            16,
            32,
            32,
            16,
            48,
            48,
            24,
            24,
            16,
            8,
            8,
            4
        ];
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner notLocked {}

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * PUBLIC: TOKEN DATA
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    /// @notice Returns a token's tokenURI
    /// @param tokenId The token ID
    /// @param status The token's status
    /// @param placement Placement of token on level/tile before rotation
    /// @param seed Seed used to rotate initial token placement
    /// @param decay Amount of decay affecting the superstructure
    /// @param canvas The canvas data of a (dreaming) token
    /// @return result A base64 encoded JSON string
    function tokenURI(
        uint256 tokenId,
        uint256 status,
        uint256 placement,
        uint256 seed,
        uint256 decay,
        uint256[] memory canvas
    ) public view returns (string memory result) {
        decay = helpers.structureDecay(block.timestamp); // Overwrite decay data
        return
            TFTokenURI.tokenURI(
                tokenId,
                status,
                placement,
                seed,
                decay,
                canvas
            );
    }

    /// @notice Returns an SVG of a token
    /// @param status The token's status
    /// @param placement Placement of token on level/tile before rotation
    /// @param seed Seed used to rotate initial token placement
    /// @param decay Amount of decay affecting the superstructure
    /// @param canvas The canvas data of a (dreaming) token
    /// @return A plaintext SVG string
    function tokenSVG(
        uint256 status,
        uint256 placement,
        uint256 seed,
        uint256 decay,
        uint256[] memory canvas
    ) public view returns (string memory) {
        decay = helpers.structureDecay(block.timestamp); // Overwrite decay data
        return TFTokenURI.tokenSVG(status, placement, seed, decay, canvas);
    }

    /// @notice Returns HTML with the token's SVG as plaintext
    /// @param status The token's status
    /// @param placement Placement of token on level/tile before rotation
    /// @param seed Seed used to rotate initial token placement
    /// @param decay Amount of decay affecting the superstructure
    /// @param canvas The canvas data of a (dreaming) token
    /// @return A plaintext HTML string
    function tokenHTML(
        uint256 status,
        uint256 placement,
        uint256 seed,
        uint256 decay,
        uint256[] memory canvas
    ) public view returns (string memory) {
        decay = helpers.structureDecay(block.timestamp); // Overwrite decay data
        return TFTokenURI.tokenHTML(status, placement, seed, decay, canvas);
    }

    /// @notice Returns the characters of a token
    /// @param status The token's status
    /// @param placement Placement of token on level/tile before rotation
    /// @param seed Seed used to rotate initial token placement
    /// @param decay Amount of decay affecting the superstructure
    /// @param canvas The canvas data of a (dreaming) token
    /// @return result A 2D array of characters (strings)
    function tokenCharacters(
        uint256 status,
        uint256 placement,
        uint256 seed,
        uint256 decay,
        uint256[] memory canvas
    ) public view returns (string[32][32] memory result) {
        decay = helpers.structureDecay(block.timestamp); // Overwrite decay data
        // Get the token's character set
        (string[9] memory chars, , , ) = dataV0.characterSet(placement, seed);

        // Get the token's heightmap (values correspond to character indices)
        uint256[32][32] memory indices = tokenHeightmapIndices(
            status,
            placement,
            seed,
            decay,
            canvas
        );

        // Translate the indices to characters. If the index is 9, it represents
        // the background, so we put a space instead
        for (uint256 y; y < TOKEN_DIMS; y++) {
            for (uint256 x; x < TOKEN_DIMS; x++) {
                result[y][x] = indices[y][x] < 9 ? chars[indices[y][x]] : " ";
            }
        }
    }

    /// @notice Returns a snapshot of an antenna
    /// @param tokenId The token ID
    /// @return result A string
    function antennaPhoto(
        uint256 tokenId
    ) public view returns (string memory result) {
        uint256 placement = terraforms.tokenToPlacement(tokenId);
        (string[9] memory chars, , , uint index) = characterSet(
            placement,
            SEED
        );
        // Biome 0 is a special case
        if (index == 0) {
            chars[0] = " ";
            chars[1] = " ";
        }
        (uint level, uint tile) = levelAndTile(placement, SEED);
        uint seed = helpers.calculateSeed(level, tile);
        uint[32][32] memory indices = TFTokenURI.antennaHeightmap(seed);
        string[32][32] memory heightmapChars = generateTokenCharacterArray(
            chars,
            indices
        );
        string[32] memory rows;
        for (uint i; i < 32; i++) {
            rows[i] = concatenateArrayOfStrings(heightmapChars[i]);
        }
        for (uint i; i < 32; i++) {
            result = concatenateArrayOfStrings(rows);
        }
    }

    /// @notice Concatenates an array of 32 strings
    /// @param arr An array of 32 strings
    /// @return result A string, terminated with a newline
    function concatenateArrayOfStrings(
        string[32] memory arr
    ) public pure returns (string memory result) {
        result = string.concat(
            arr[0],
            arr[1],
            arr[2],
            arr[3],
            arr[4],
            arr[5],
            arr[6],
            arr[7],
            arr[8],
            arr[9],
            arr[10],
            arr[11]
        );
        result = string.concat(
            result,
            arr[12],
            arr[13],
            arr[14],
            arr[15],
            arr[16],
            arr[17],
            arr[18],
            arr[19],
            arr[20],
            arr[21]
        );
        result = string.concat(
            result,
            arr[22],
            arr[23],
            arr[24],
            arr[25],
            arr[26],
            arr[27],
            arr[28],
            arr[29],
            arr[30],
            arr[31],
            "\n"
        );
    }

    /// @notice Returns a 2D array of characters (strings)
    /// @param chars An array of strings
    /// @param heightmap A 2D array of ints
    /// @return result A 2D array of characters (strings)
    function generateTokenCharacterArray(
        string[9] memory chars,
        uint[32][32] memory heightmap
    ) public view returns (string[32][32] memory result) {
        for (uint256 y; y < TOKEN_DIMS; y++) {
            for (uint256 x; x < TOKEN_DIMS; x++) {
                result[y][x] = heightmap[y][x] < 9
                    ? chars[heightmap[y][x]]
                    : " ";
            }
        }
    }

    /// @notice Returns the numbers used to create a token's topography
    /// @dev Values are positions in 3D space. Not applicable to dreaming tokens
    /// @param placement Placement of token on level/tile before rotation
    /// @param seed Value used to rotate initial token placement
    /// @param decay Amount of decay affecting the superstructure
    /// @return result A 2D array of ints
    function tokenTerrain(
        uint256 placement,
        uint256 seed,
        uint256 decay
    ) public view returns (int256[32][32] memory result) {
        decay = helpers.structureDecay(block.timestamp); // Overwrite decay data
        // The step is the increment in the noise space between each element
        // of the token
        int256 step = STEP;

        // If the structure has decayed for more than 100 years, the step sizes
        // become larger, causing the token surface to collapse inward
        if (decay > 100) {
            step += int256(decay - 99) * 100;
        }

        // Determine the level and tile on which the token is located
        (uint256 level, uint256 tile) = dataV0.levelAndTile(placement, seed);

        // Obtain the XYZ origin for the token
        int256 initX = dataV0.xOrigin(level, tile, seed);
        int256 yPos = dataV0.yOrigin(level, tile, seed);
        int256 zPos = zOrigin(level, tile, seed, decay, block.timestamp);
        int256 xPos;

        // Populate 2D array
        for (uint256 y; y < TOKEN_DIMS; y++) {
            xPos = initX; // Reset X for row alignment on each iteration
            for (uint256 x; x < TOKEN_DIMS; x++) {
                result[y][x] = perlinNoise.noise3d(xPos, yPos, zPos);
                xPos += step;
            }
            yPos += step;
        }

        return result;
    }

    /// @notice Returns a 2D array of indices into a char array
    /// @param status The token's status
    /// @param placement The placement of token on level/tile before rotation
    /// @param seed Value used to rotate initial token placement
    /// @param decay Amount of decay affecting the superstructure
    /// @param canvas The canvas data of a (dreaming) token
    /// @return result A 2D array of uints to index into a char array
    function tokenHeightmapIndices(
        uint256 status,
        uint256 placement,
        uint256 seed,
        uint256 decay,
        uint256[] memory canvas
    ) public view returns (uint256[32][32] memory result) {
        decay = helpers.structureDecay(block.timestamp); // Overwrite decay data
        Status s = Status(status);

        // If the token is in terrain mode, generate terrain
        if (s == Status.Terrain) {
            int256[32][32] memory values = tokenTerrain(placement, seed, decay);

            // Convert terrain values to heightmap indices
            for (uint256 y; y < TOKEN_DIMS; y++) {
                for (uint256 x; x < TOKEN_DIMS; x++) {
                    result[y][x] = heightmapIndexFromTerrainValue(values[y][x]);
                }
            }
        } else if (
            // If token is terraformed, draw it
            (s == Status.Terraformed || s == Status.OriginTerraformed) &&
            canvas.length == 16
        ) {
            uint256 digits;
            uint256 counter;
            // Iterate through canvas data
            for (uint256 rowPair; rowPair < 16; rowPair++) {
                // Canvas data is from left to right, so we need to reverse
                // the integers so we can isolate (modulo) the leftmost digits
                digits = helpers.reverseUint(canvas[rowPair]);
                for (uint256 digit; digit < 64; digit++) {
                    // Read 64 digits
                    result[counter / 32][counter % 32] = digits % 10;
                    digits = digits / 10; // Shift down one digit
                    counter += 1;
                }
            }
        }
        // Otherwise, the token is daydreaming, so we return an empty array
        return result;
    }

    /// @notice Returns the XYZ origins of a level in 3D space
    /// @param level The level of the superstructure
    /// @param tile The token's tile placement
    /// @param seed Value used to rotate initial token placement
    /// @param decay Amount of decay affecting the superstructure
    /// @param timestamp The time queried (structure floats and decays in time)
    /// @return Three ints representing the level's XYZ origins in 3D space
    function tileOrigin(
        uint256 level,
        uint256 tile,
        uint256 seed,
        uint256 decay,
        uint256 timestamp
    ) public view returns (int256, int256, int256) {
        decay = helpers.structureDecay(block.timestamp); // Overwrite decay data
        return (
            xOrigin(level, tile, seed),
            yOrigin(level, tile, seed),
            zOrigin(level, tile, seed, decay, timestamp)
        );
    }

    /// @notice Returns the x origin of a token in 3D space
    /// @param level The level of the superstructure
    /// @param tile The token's tile placement
    /// @param seed Value used to rotate initial token placement
    /// @return An int representing the tile's x origin in 3D space
    function xOrigin(
        uint256 level,
        uint256 tile,
        uint256 seed
    ) public view returns (int256) {
        return dataV0.xOrigin(level, tile, seed);
    }

    /// @notice Returns the y origin of a token in 3D space
    /// @param level The level of the superstructure
    /// @param tile The token's tile placement
    /// @param seed Value used to rotate initial token placement
    /// @return An int representing the tile's y origin in 3D space
    function yOrigin(
        uint256 level,
        uint256 tile,
        uint256 seed
    ) public view returns (int256) {
        return dataV0.yOrigin(level, tile, seed);
    }

    /// @notice Returns the z origin of a token in 3D space
    /// @param level The level of the superstructure
    /// @param tile The token's tile placement
    /// @param seed Value used to rotate initial token placement
    /// @param decay Amount of decay affecting the superstructure
    /// @param timestamp The time queried (structure floats and decays in time)
    /// @return An int representing the tile's z origin in 3D space
    function zOrigin(
        uint256 level,
        uint256 tile,
        uint256 seed,
        uint256 decay,
        uint256 timestamp
    ) public view returns (int256) {
        return helpers.zOrigin(level, tile, seed, decay, timestamp);
    }

    /// @notice Changes a token's elevation on a level according to its zone
    /// @param level The level of the superstructure
    /// @param tile The token's tile placement
    /// @param seed Value used to rotate initial token placement
    /// @return A signed integer in range +-4
    function tokenElevation(
        uint256 level,
        uint256 tile,
        uint256 seed
    ) public view returns (int256) {
        // Elevation is determined by the token's position on the level
        // Elevation ranges from 4 (for heightmap index 0) to -4 (index 8)
        return dataV0.tokenElevation(level, tile, seed);
    }

    /// @notice Returns a token's zone, including its name and color scheme
    /// @param placement The placement of token on level/tile before rotation
    /// @param seed Value used to rotate initial token placement
    /// @return An array of hexadecimal strings and a string
    function tokenZone(
        uint256 placement,
        uint256 seed
    ) public view returns (string[10] memory, string memory) {
        return dataV0.tokenZone(placement, seed);
    }

    /// @notice Returns a token's character set
    /// @param placement The placement of token on level/tile before rotation
    /// @param seed Value used to rotate initial token placement
    /// @return charset An array of strings
    /// @return font The index of the token's font
    /// @return fontsize The token's font size
    /// @return index The index of the character set in the storage array
    function characterSet(
        uint256 placement,
        uint256 seed
    )
        public
        view
        returns (
            string[9] memory charset,
            uint256 font,
            uint256 fontsize,
            uint256 index
        )
    {
        return dataV0.characterSet(placement, seed);
    }

    /// @notice Returns a token's biome code
    /// @param tokenId The token ID
    /// @return result The token's biome code
    function biomeCode(
        uint256 tokenId
    ) public view returns (string[9] memory result) {
        uint256 placement = terraforms.tokenToPlacement(tokenId);
        (result, , , ) = characterSet(placement, SEED);
    }

    /// @notice Returns a token's biome index
    /// @param tokenId The token ID
    /// @return result The index of the token's biome
    function biomeIndex(uint256 tokenId) public view returns (uint256 result) {
        uint256 placement = terraforms.tokenToPlacement(tokenId);
        (, , , result) = characterSet(placement, SEED);
    }

    /// @notice Returns a token's chroma trait
    /// @param tokenId The token ID
    /// @return result The name of the token's chroma
    function chroma(
        uint256 tokenId
    ) public view returns (string memory result) {
        uint256 placement = terraforms.tokenToPlacement(tokenId);
        AnimParams memory a = TFTokenURI.animationParameters(placement, SEED);
        if (a.activation == Activation.Plague) {
            return "Plague";
        } else if (a.duration == TFTokenURI.durations(0)) {
            return "Hyper";
        } else if (a.duration == TFTokenURI.durations(1)) {
            return "Pulse";
        } else {
            return "Flow";
        }
    }

    /// @notice Returns a token's resource level
    /// @param tokenId The token ID
    /// @return result The token's resource level
    function resourceLevel(uint256 tokenId) public view returns (uint256) {
        uint256 placement = terraforms.tokenToPlacement(tokenId);
        return dataV0.resourceLevel(placement, SEED);
    }

    /// @notice Returns a token's resource level
    /// @param placement The placement of token on level/tile before rotation
    /// @param seed Value used to rotate initial token placement
    /// @return result The token's resource level
    function resourceLevel(
        uint256 placement,
        uint256 seed
    ) public view returns (uint256) {
        return dataV0.resourceLevel(placement, seed);
    }

    /// @notice Determines a token's level and its position on the level
    /// @param placement The placement of token on level/tile before rotation
    /// @param seed Value used to rotate initial token placement
    /// @return level The token's level number
    /// @return tile The token's tile number
    function levelAndTile(
        uint256 placement,
        uint256 seed
    ) public view returns (uint256 level, uint256 tile) {
        return dataV0.levelAndTile(placement, seed);
    }

    /// @notice Returns the position on the z axis of a 2D level
    /// @dev Z offset cycles over a two year period
    /// @dev Intensity of the offset increases farther from center levels
    /// @param level The level of the superstructure
    /// @param decay Amount of decay affecting the superstructure
    /// @param timestamp The time queried (structure floats and decays in time)
    /// @return result An int representing the altitude of the level
    function zOscillation(
        uint256 level,
        uint256 decay,
        uint256 timestamp
    ) public view returns (int256 result) {
        return helpers.zOscillation(level, decay, timestamp);
    }

    /// @notice Converts a numeric value into an index into a char array
    /// @dev Converts terrain values into characters
    /// @param terrainValue An int from perlin noise
    /// @return An integer to index into a character array
    function heightmapIndexFromTerrainValue(
        int256 terrainValue
    ) public view returns (uint256) {
        // Iterate through the topography array until we find an elem less than
        // value
        for (uint256 i; i < 8; i++) {
            if (terrainValue > topography[i]) {
                return i;
            }
        }
        return 8; // if we fall through, return 8 (the lowest height value)
    }

    /// @notice Returns the name of the Terraforms resource
    function resourceName() public view returns (string memory) {
        return dataV0.resourceName();
    }

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * PUBLIC: ADMINISTRATIVE
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
    /// @notice Locks the contract
    function lock() public onlyOwner notLocked {
        isLocked = true;
    }

    /// @notice Transfers the contract balance to the owner
    function withdraw() public onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success);
    }

    fallback() external payable {
        _delegate();
    }

    receive() external payable {
        _delegate();
    }

    function _delegate() internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(
                gas(),
                0xA5aFC9fE76a28fB12C60954Ed6e2e5f8ceF64Ff2,
                0,
                calldatasize(),
                0,
                0
            )
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}
