// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {ERC165Upgradeable} from "../utils/introspection/ERC165Upgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControl, ERC165Upgradeable {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;


    /// @custom:storage-location erc7201:openzeppelin.storage.AccessControl
    struct AccessControlStorage {
        mapping(bytes32 role => RoleData) _roles;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.AccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AccessControlStorageLocation = 0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;

    function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
        assembly {
            $.slot := AccessControlStorageLocation
        }
    }

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        AccessControlStorage storage $ = _getAccessControlStorage();
        bytes32 previousAdminRole = getRoleAdmin(role);
        $._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (!hasRole(role, account)) {
            $._roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (hasRole(role, account)) {
            $._roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
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
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Context.sol)

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
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
// OpenZeppelin Contracts (last updated v5.0.0) (access/IAccessControl.sol)

pragma solidity ^0.8.20;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/Proxy.sol)

pragma solidity ^0.8.20;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback
     * function and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
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
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

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
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
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
     * {FailedInnerCall} error.
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
            revert AddressInsufficientBalance(address(this));
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
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
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
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableReadonlyDS} from "./OwnableReadonlyDS.sol";

abstract contract AccessControlDS is AccessControlUpgradeable, OwnableReadonlyDS {
    function hasRole(bytes32 _role, address _account) public view virtual override returns (bool) {
        return (isOwnerRole(_role) && _owner() == _account) || super.hasRole(_role, _account);
    }

    function isOwnerRole(bytes32 _role) private pure returns (bool) {
        return _role == DEFAULT_ADMIN_ROLE;
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {UnauthorizedAccount} from "contracts/interfaces/base/CommonErrors.sol";
import {Address} from "contracts/libraries/Address.sol";

/**
 * @dev We intentionally do not expose "owner()" publicly
 * due to possible conflicts with "OwnershipFacet"
 * https://github.com/mudgen/diamond-3-hardhat/blob/main/contracts/facets/OwnershipFacet.sol
 */
abstract contract OwnableReadonly {
    using Address for bytes32;

    modifier onlyOwner() {
        enforceIsContractOwner();
        _;
    }

    function _owner() internal view returns (address) {
        return _ownerSlot().get();
    }

    function _ownerSlot() internal pure virtual returns (bytes32);

    function enforceIsContractOwner() private view {
        if (msg.sender != _owner()) revert UnauthorizedAccount(msg.sender);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {DiamondLibrary} from "contracts/libraries/DiamondLibrary.sol";
import {OwnableReadonly} from "./OwnableReadonly.sol";

/**
 * @notice Use DiamondStorage's owner slot for OwnableReadonly
 */
abstract contract OwnableReadonlyDS is OwnableReadonly {
    function _ownerSlot() internal pure override returns (bytes32 slot_) {
        DiamondLibrary.DiamondStorage storage ds = DiamondLibrary.diamondStorage();
        assembly {
            // DiamondLib will not change so it's safe to hardcode owner offset here
            let ownerOffsetInDiamondStorage := 4
            slot_ := add(ds.slot, ownerOffsetInDiamondStorage)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.22;

import {
    PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPausable} from "contracts/interfaces/base/pauser/IPausable.sol";

abstract contract PausableBase is IPausable, PausableUpgradeable {
    bytes32 public constant override PAUSER_ROLE = keccak256("Pauser Role");

    modifier onlyPauserRole() {
        _checkRole(PAUSER_ROLE);
        _;
    }

    function pause() external override onlyPauserRole {
        _pause();
    }

    function unpause() external override onlyPauserRole {
        _unpause();
    }

    function paused() public view override(IPausable, PausableUpgradeable) returns (bool) {
        return PausableUpgradeable.paused();
    }

    /*
     * @dev Contracts inheriting from PausableBase should inherit OpenZeppelin's AccessControlUpgradeable
     *      override and implement _checkRole()
     */
    /* solhint-disable-next-line no-empty-blocks */
    function _checkRole(bytes32 role) internal view virtual {}
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.22;

import {AccessControlDS, AccessControlUpgradeable} from "contracts/base/auth/AccessControlDS.sol";
import {PausableBase} from "contracts/base/pauser/base/PausableBase.sol";

contract PausableDS is PausableBase, AccessControlDS {
    function _checkRole(
        bytes32 role
    ) internal view override(AccessControlUpgradeable, PausableBase) {
        AccessControlUpgradeable._checkRole(role);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IBeacon} from "contracts/interfaces/base/proxy/IBeacon.sol";

import {OwnableReadonlyDS} from "contracts/base/auth/OwnableReadonlyDS.sol";
import {PausableDS} from "contracts/base/pauser/PausableDS.sol";

import {BeaconImplementation} from "./BeaconImplementation.sol";

abstract contract BeaconDS is IBeacon, BeaconImplementation, OwnableReadonlyDS, PausableDS {
    /* @dev Implementation is not set in the BeaconDS,
     *   contracts inheriting from this contract should override and implement setImplementation()
     */
    /* solhint-disable-next-line no-empty-blocks */
    function setImplementation(address newImplementation) external virtual override whenPaused {}

    function implementation() external view override whenNotPaused returns (address) {
        return _implementation();
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {AlreadyUpToDate} from "contracts/interfaces/base/CommonErrors.sol";

abstract contract BeaconImplementation {
    // keccak256("Implementation slot inside BeaconImplementation")
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x5a8947f50575ddcaa31a5721cef4bf0d765e78dbe7d7a1182efca602a9dfd034;

    function _setImplementation(address newImpl) internal {
        address impl;
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
        if (impl == newImpl) revert AlreadyUpToDate();
        assembly {
            sstore(IMPLEMENTATION_SLOT, newImpl)
        }
    }

    function _implementation() internal view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IBeacon} from "contracts/interfaces/base/proxy/IBeacon.sol";
import {SafeCall} from "contracts/libraries/SafeCall.sol";

contract ImmutableBeaconProxy is Proxy {
    using {SafeCall.safeDelegateCall} for address;

    address private immutable beacon;

    error BeaconCallFailed();
    error BeaconReturnedUnexpectedNumberOfBytes(uint256);
    error BeaconReturnedAddressZero();

    constructor(bytes memory initDataWithSelector) {
        beacon = msg.sender;

        if (initDataWithSelector.length > 0) {
            _implementation().safeDelegateCall(initDataWithSelector);
        }
    }

    function _implementation() internal view override returns (address impl) {
        (bool success, bytes memory result) = beacon.staticcall(
            abi.encodeWithSelector(IBeacon.implementation.selector)
        );

        if (!success) revert BeaconCallFailed();
        if (result.length != 32) revert BeaconReturnedUnexpectedNumberOfBytes(result.length);

        impl = abi.decode(result, (address));
        if (impl == address(0)) revert BeaconReturnedAddressZero();
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {LibBit} from "solady/src/utils/LibBit.sol";

type State is uint256;

using {and as &, neq as !=, eq as ==, or as |, includes, isInitialized, isValid} for State global;

function and(State self, State value) pure returns (State) {
    return State.wrap(State.unwrap(self) & State.unwrap(value));
}

function neq(State self, State value) pure returns (bool) {
    return State.unwrap(self) != State.unwrap(value);
}

function eq(State self, State value) pure returns (bool) {
    return State.unwrap(self) == State.unwrap(value);
}

function or(State self, State value) pure returns (State) {
    return State.wrap(State.unwrap(self) | State.unwrap(value));
}

function includes(State bitmap, State state) pure returns (bool) {
    return State.unwrap(bitmap) & State.unwrap(state) != 0;
}

function isInitialized(State self) pure returns (bool answer_) {
    return State.unwrap(self) != 0;
}

function isValid(State self) pure returns (bool) {
    // most significant bit is reserved for the undefined state
    uint256 mask = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    return LibBit.isPo2(State.unwrap(self) & mask);
}

abstract contract StateMachine {
    struct StateStorage {
        State currentState;
        mapping(bytes32 transitionId => function(bytes memory) external transition) transitions;
    }

    // Undefined state cannot be zero because it will break bitmap comparison math in `onlyState`
    /* solhint-disable-next-line immutable-vars-naming */
    State internal immutable STATE_UNDEFINED = _newStateFromIdUnchecked(STATE_UNDEFINED_ID);
    uint8 private constant STATE_UNDEFINED_ID = type(uint8).max;
    // keccak256("StateMachine storage slot V2");
    bytes32 private constant STORAGE_SLOT_STATE_MACHINE =
        0xde4001bbdfdfed078acd4ae5c1023679bf2e3e2982cfd37f7c839d62304fe30d;

    event StateChanged(State from, State to);

    error TransitionAlreadyExists(State from, State to);
    error TransitionDoesNotExist(State from, State to);

    error UnexpectedState(State expectedStatesBitmap, State currentState);
    // If transition function exists on current contract
    // then it must be called only from the current contract.
    error HostedTransitionMustBeCalledFromSelf();
    // A valid state must be in form of 2^n, where n ∈ {x | x ∈ uint8, x < STATE_UNDEFINED_ID}.
    error InvalidState(State);
    error IdIsReservedForUndefinedState(uint256);

    modifier onlyState(State _expectedStatesBitmap) {
        State state = _currentState(_stateStorage());
        if (!_expectedStatesBitmap.includes(state))
            revert UnexpectedState(_expectedStatesBitmap, state);
        _;
    }

    modifier transition() {
        if (msg.sender != address(this)) revert HostedTransitionMustBeCalledFromSelf();
        _;
    }

    function createTransition(
        State _from,
        State _to,
        function(bytes memory) external _transition
    ) internal {
        bytes32 id = _getTransitionId(_from, _to);
        if (_isTransitionExists(id)) revert TransitionAlreadyExists(_from, _to);

        _stateStorage().transitions[id] = _transition;
    }

    function changeState(State _newState) internal {
        changeState(_newState, "");
    }

    function changeState(State _newState, bytes memory _transitionArgs) internal {
        if (!_newState.isValid()) revert InvalidState(_newState);
        StateStorage storage $ = _stateStorage();
        State state = _currentState($);

        bytes32 id = _getTransitionId(state, _newState);
        if (!_isTransitionExists(id)) revert TransitionDoesNotExist(state, _newState);

        emit StateChanged(state, _newState);
        $.currentState = _newState;

        $.transitions[id](_transitionArgs);
    }

    function currentState() internal view returns (State currentState_) {
        return _currentState(_stateStorage());
    }

    function newStateFromId(uint8 _stateId) internal pure returns (State) {
        if (_stateId == STATE_UNDEFINED_ID) revert IdIsReservedForUndefinedState(_stateId);
        return _newStateFromIdUnchecked(_stateId);
    }

    function _currentState(StateStorage storage $) private view returns (State state) {
        state = $.currentState;
        // We substitute 0 with STATE_UNDEFINED here in order to avoid storage
        // initialization with default value to save gas
        if (!state.isInitialized()) state = STATE_UNDEFINED;
    }

    function _isTransitionExists(bytes32 _transitionId) private view returns (bool exists_) {
        mapping(bytes32 => function(bytes memory) external) storage map = _stateStorage()
            .transitions;
        assembly {
            // we won't use this memory location after keccak so it's safe to use 0x00 and 0x20
            mstore(0x00, _transitionId)
            mstore(0x20, map.slot)
            let position := keccak256(0x00, 64)
            // callback = map[_transition]
            let callback := sload(position)
            // exists_ = callback != null
            exists_ := iszero(iszero(callback))
        }
    }

    function _getTransitionId(State _from, State _to) private view returns (bytes32) {
        if (_from != STATE_UNDEFINED && !_from.isValid()) revert InvalidState(_from);
        if (!_to.isValid()) revert InvalidState(_to);
        return keccak256(abi.encodePacked(_from, _to));
    }

    function _newStateFromIdUnchecked(uint8 _stateId) private pure returns (State) {
        return State.wrap(1 << _stateId);
    }

    function _stateStorage() private pure returns (StateStorage storage $) {
        assembly {
            $.slot := STORAGE_SLOT_STATE_MACHINE
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

/**
 * @notice An error indicating that the amount for the specified token is zero.
 * @param token The address of the token with a zero amount.
 */
error AmountMustNotBeZero(address token);

/**
 * @notice An error indicating that an address must not be zero.
 */
error AddressMustNotBeZero();

/**
 * @notice An error indicating that an array must not be empty.
 */
error ArrayMustNotBeEmpty();

/**
 * @notice An error indicating storage is already up to date and doesn't need further processing.
 * @dev This error is thrown when attempting to update an entity(s) that is(are) already up to date.
 */
error AlreadyUpToDate();

/**
 * @notice An error indicating that an action is unauthorized for the specified account.
 * @param account The address of the unauthorized account.
 */
error UnauthorizedAccount(address account);

/**
 * @notice An error indicating that the min amount out must not be zero.
 */
error MinAmountOutMustNotBeZero();

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

/* solhint-disable no-unused-import */
import {
    IERC165
} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
/* solhint-enable no-unused-import */

/**
 * @notice An error indicating that an address does not support the expected interface
 * @param implementation The address that does not implement the required interface
 */
error UnsupportedInterface(address implementation);

/**
 * @dev Extended interface of the ERC165 standard to ensure compatibility
 * with Diamond facets as defined in EIP-2535.
 *
 * This interface extends the basic ERC165 mechanism to provide additional
 * flexibility for querying supported interfaces, which can then be
 * dynamically resolved by one of facets in a Diamond.
 */
interface IERC165Extended {
    /**
     * @notice Checks if the given interface ID is supported by the contract.
     * @param interfaceId The ID of the interface to query.
     * @return isSupported Boolean value indicating whether the interface is supported.
     */
    function supportsInterfaceExtended(bytes4 interfaceId) external pure returns (bool isSupported);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/**
 * @dev Interface for contracts that can be paused or unpaused.
 * This interface provides the methods to pause and unpause the contract
 * as well as check its paused status. It also includes the definition of
 * the `PAUSER_ROLE` that is required to perform the pause/unpause actions.
 */
interface IPausable {
    /**
     * @notice Pauses the contract.
     * @dev Can only be called by an address with the `PAUSER_ROLE`.
     *      This function will halt any operations that are paused in the contract.
     */
    function pause() external;

    /**
     * @notice Unpauses the contract.
     * @dev Can only be called by an address with the `PAUSER_ROLE`.
     *      This function will resume any operations that were paused in the contract.
     */
    function unpause() external;

    /**
     * @notice Returns whether the contract is paused.
     * @return bool True if the contract is paused, false otherwise.
     * @dev This function checks the contract's paused status, which is typically
     *      managed by an internal flag set by the `pause` and `unpause` functions.
     */
    function paused() external view returns (bool);

    /**
     * @notice Returns the role identifier for the `PAUSER_ROLE`.
     * @return bytes32 The role identifier for the `PAUSER_ROLE`.
     * @dev The `PAUSER_ROLE` is required for the caller to invoke the `pause` or `unpause` functions.
     */
    /* solhint-disable-next-line func-name-mixedcase */
    function PAUSER_ROLE() external view returns (bytes32);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

interface IBeacon {
    error InvalidImplementation(address implementation);

    /**
     * This upgrade will affect all Beacon Proxies that use this Beacon
     * @param newImplementation New implementation to delegate calls from Beacon Proxies
     */
    function setImplementation(address newImplementation) external;

    /**
     * Returns address of the current used by Beacon Proxies
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

interface IInitializable {
    function initialize() external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Asset} from "contracts/libraries/AssetLibrary.sol";
import {Command} from "../Command.sol";
import {PositionDescriptor} from "./PositionDescriptor.sol";

interface IDecreasePositionEvaluator {
    /**
     * @notice Request structure for decreasing a position.
     * @dev `descriptor`: The [`PositionDescriptor`](/interfaces/compiler/adapters/PositionDescriptor.sol/struct.PositionDescriptor.html)
     *  struct.
     * @dev `liquidity`: Abstract amount that can be interpreted differently in different protocols (e.g., amount of LP tokens to burn).
     * @dev `minOutput`: [`Asset`](/interfaces/compliance/Asset.sol/struct.Asset.html) array with minimum amounts that must be retrieved from the position.
     */
    struct DecreasePositionRequest {
        PositionDescriptor descriptor;
        uint256 liquidity;
        Asset[] minOutput;
    }

    /**
     * @notice Evaluate a decrease position request.
     * @param _operator Address which initiated the request
     * @param _request The [`DecreasePositionRequest`](#decreasepositionrequest) struct containing decrease position details.
     * @return cmds_ An array of [`Command`](../../Command.sol/struct.Command.html) to execute the request.
     */
    function evaluate(
        address _operator,
        DecreasePositionRequest calldata _request
    ) external returns (Command[] memory cmds_);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Command} from "../Command.sol";

/**
 * @title IExchangeEvaluator
 * @notice Interface for compiling commands for token exchanges for different protocols.
 */
interface IExchangeEvaluator {
    /**
     * @notice Structure for an exchange token request.
     * @dev `path`: Encoded path of tokens to follow in the exchange, including pool identifiers.
     * 20 bytes(tokenA) + 4 byte(poolId_A_B) + 20 bytes(tokenB) + ...
     * ... + 4 byte(poolId_N-1_N) + 20 bytes(tokenN).
     * @dev `extraData`: Additional data specific to a particular protocol, such as the response from a 1Inch Exchange API.
     * @dev `amountIn`: The amount of tokenA to spend.
     * @dev `minAmountOut`: The minimum amount of tokenN to receive.
     * @dev `recipient`: The recipient of tokenN.
     */
    struct ExchangeRequest {
        bytes path;
        bytes extraData;
        uint256 amountIn;
        uint256 minAmountOut;
        address recipient;
    }

    /**
     * @notice Constructs an exchange token request.
     * @param _operator Address which initiated the request
     * @param _request The [`ExchangeRequest`](#exchangerequest) struct containing exchange token details.
     * @return cmds_ An array of [`Command`](../../Command.sol/struct.Command.html) to execute the request.
     */
    function evaluate(
        address _operator,
        ExchangeRequest calldata _request
    ) external view returns (Command[] memory cmds_);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Asset} from "contracts/libraries/AssetLibrary.sol";
import {Command} from "../Command.sol";
import {PositionDescriptor} from "./PositionDescriptor.sol";

interface IIncreasePositionEvaluator {
    /**
     * @notice Structure for an increase position request.
     * @dev `descriptor`: The [`PositionDescriptor`](/interfaces/compiler/adapters/PositionDescriptor.sol/struct.PositionDescriptor.html)
     *  struct.
     * @dev `input`: An array of [`Asset`](/interfaces/compliance/Asset.sol/struct.Asset.html) representing the token-amounts that will be added to the position.
     * @dev `minLiquidityOut`: An abstract amount that can be interpreted differently in different protocols (e.g., minimum amount of LP tokens to receive).
     */
    struct IncreasePositionRequest {
        PositionDescriptor descriptor;
        Asset[] input;
        uint256 minLiquidityOut;
    }

    /**
     * @notice Evaluate a increase position request.
     * @param _operator Address which initiated the request
     * @param _request The [`IncreasePositionRequest`](#increasepositionrequest) struct containing increase position details.
     * @return cmds_ An array of [`Command`](../../Command.sol/struct.Command.html) to execute the request.
     */
    function evaluate(
        address _operator,
        IncreasePositionRequest calldata _request
    ) external returns (Command[] memory cmds_);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

// TODO CRYPTO-145: Possibly move into appropriate interface?
/**
 * @notice Used to determine the required position for an operation.
 * @dev `poolId`: An identifier that is unique within a single protocol.
 * @dev `extraData`: Additional data used to specify the position, for example
 * this is used in OneInchV5Evaluator to pass swap tx generated via 1inch API.
 */
struct PositionDescriptor {
    uint256 poolId;
    bytes extraData;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {CommandLibrary} from "contracts/libraries/CommandLibrary.sol";

/**
 * @title Command
 * @notice Contains arguments for a low-level call.
 * @dev This struct allows deferring the call's execution, suspending it by passing it to another function or contract.
 * @dev `target` The address to be called.
 * @dev `value` Value to send in the call.
 * @dev `payload` Encoded call with function selector and arguments.
 */
struct Command {
    address target;
    uint256 value;
    bytes payload;
}

using CommandLibrary for Command global;

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IERC165Extended} from "contracts/interfaces/base/IERC165Extended.sol";

import {IDecreasePositionEvaluator} from "./adapters/IDecreasePositionEvaluator.sol";
import {IExchangeEvaluator} from "./adapters/IExchangeEvaluator.sol";
import {IIncreasePositionEvaluator} from "./adapters/IIncreasePositionEvaluator.sol";
import {Command} from "./Command.sol";
import {Script} from "./Script.sol";

/**
 * @title IJitCompiler
 * @notice Compiles a script or an instruction into an array of [Commands](/interfaces/compiler/Command.sol/struct.Command.html) using protocol evaluator matching `protocol` field in the underlying instruction.
 */
interface IJitCompiler is IERC165Extended {
    /**
     * @notice Instruction designed to increase:
     *  1. Caller's magnitude of the position determined by the [PositionDescriptor](../adapters/PositionDescriptor.sol/struct.PositionDescriptor.html).
     *  2. Callee's balance of token(s).
     * @notice and decrease:
     *  1. Caller's balance of token(s).
     *  2. (*Optional*) callee's supply of the position determined by the [PositionDescriptor](../adapters/PositionDescriptor.sol/struct.PositionDescriptor.html).
     * @dev This instruction will be evaluated in [IncreasePositionEvaluator](../adapters/IIncreasePositionEvaluator.sol/interface.IIncreasePositionEvaluator.html).
     * @dev `protocol` The name of the underlying protocol where instruction should be evaluated. For example: `curvefi`, `oneinchv5`
     * @dev `request` The [`IncreasePositionRequest`](../adapters/IIncreasePositionEvaluator.sol/interface.IIncreasePositionEvaluator.html#increasepositionrequest) containing all information required for instruction evaluation.
     */
    struct IncreasePositionInstruction {
        string protocol;
        IIncreasePositionEvaluator.IncreasePositionRequest request;
    }

    /**
     * @notice Instruction designed to increase:
     *  1. Caller's balance of token(s).
     *  2. (*Optional*) callee's supply of the position determined by the [PositionDescriptor](../adapters/PositionDescriptor.sol/struct.PositionDescriptor.html).
     * @notice and decrease:
     *  1. Caller's magnitude of the position determined by the [PositionDescriptor](../adapters/PositionDescriptor.sol/struct.PositionDescriptor.html).
     *  2. Callee's balance of token(s).
     * @dev This instruction will be evaluated in [DecreasePositionEvaluator](../adapters/IDecreasePositionEvaluator.sol/interface.IDecreasePositionEvaluator.html).
     * @dev `protocol` The name of the underlying protocol where instruction should be evaluated. For example: `curvefi`, `oneinchv5`
     * @dev `request` The [`DecreasePositionRequest`](../adapters/IDecreasePositionEvaluator.sol/interface.IDecreasePositionEvaluator.html#decreasepositionrequest) containing all information required for instruction evaluation.
     */
    struct DecreasePositionInstruction {
        string protocol;
        IDecreasePositionEvaluator.DecreasePositionRequest request;
    }

    /**
     * @notice Instruction designed to increase:
     *  1. (*Optional*) caller's balance of output token.
     *  2. Callee's balance of input token.
     * @notice and decrease:
     *  1. Caller's balance of input token.
     *  2. (*Optional*) callee's balance of output token.
     * @dev This instruction will be evaluated in [ExchangeEvaluator](../adapters/IExchangeEvaluator.sol/interface.IExchangeEvaluator.html).
     * @dev `protocol` The name of the underlying protocol where instruction should be evaluated. For example: `curvefi`, `oneinchv5`
     * @dev `request` The [`ExchangeRequest`](../adapters/IExchangeEvaluator.sol/interface.IExchangeEvaluator.html#exchangerequest) containing all information required for instruction evaluation.
     */
    struct ExchangeInstruction {
        string protocol;
        IExchangeEvaluator.ExchangeRequest request;
    }

    /**
     * @notice Instruction designed to increase:
     *  1. (*Optional*) caller's balance of output token.
     *  2. Callee's balance of input token.
     * @notice and decrease:
     *  1. Caller's balance of input token.
     *  2. (*Optional*) callee's balance of output token.
     * @dev This instruction will be evaluated in [ExchangeEvaluator](../adapters/IExchangeEvaluator.sol/interface.IExchangeEvaluator.html).
     * @dev **Important note:** this instruction has an identical structure to [ExchangeInstruction](#exchangeinstruction), but differs from it in that [ExchangeInstruction](#exchangeinstruction) is static and [ExchangeAllInstruction](#exchangeallinstruction) is dynamic. This means that the `amountIn` field will be set at runtime by the compiler to the caller's balance by the input token.
     * @dev `protocol` The name of the underlying protocol where instruction should be evaluated. For example: `curvefi`, `oneinchv5`
     * @dev `request` The [`ExchangeRequest`](../adapters/IExchangeEvaluator.sol/interface.IExchangeEvaluator.html#exchangerequest) containing all information required for instruction evaluation. The `amountIn` field will be set at runtime by the compiler to the caller's balance by the input token.
     */
    struct ExchangeAllInstruction {
        string protocol;
        IExchangeEvaluator.ExchangeRequest request;
    }

    /**
     * @notice Compiles a [Script](../Script.sol/struct.Script.html).
     * @dev **Important note:** don't put two instructions to the same script if one depend on the other because content of the script will be compiled at once meaning that balance changes will be applied only after the compilation of the entire script. If you have two instructions and one depends on the other, put them into different scripts.
     * @param script Script to compile
     * @return An array of [`Commands`](../Command.sol/struct.Command.html) to execute the instruction.
     */
    function compile(Script calldata script) external returns (Command[] memory);

    /**
     * @notice Compiles an increase position instruction.
     * @param instruction The [`IncreasePositionInstruction`](#increasepositioninstruction) struct.
     * @return An array of [`Commands`](../Command.sol/struct.Command.html) to execute the instruction.
     */
    function compileIncreasePositionInstruction(
        IncreasePositionInstruction calldata instruction
    ) external returns (Command[] memory);

    /**
     * @notice Compiles a decrease position instruction.
     * @param instruction The [`DecreasePositionInstruction`](#decreasepositioninstruction) struct.
     * @return An array of [`Commands`](../Command.sol/struct.Command.html) to execute the instruction.
     */
    function compileDecreasePositionInstruction(
        DecreasePositionInstruction calldata instruction
    ) external returns (Command[] memory);

    /**
     * @notice Compiles an exchange instruction.
     * @param instruction The [`ExchangeInstruction`](#exchangeinstruction) struct.
     * @return An array of [`Commands`](../Command.sol/struct.Command.html) to execute the instruction.
     */
    function compileExchangeInstruction(
        ExchangeInstruction calldata instruction
    ) external returns (Command[] memory);

    /**
     * @notice Sets the `amountIn` field to the balance of the caller by the input token and compiles an underlying exchange instruction.
     * @dev `amountIn` will be overridden with the balance of the caller by the input token.
     * @param instruction The [`ExchangeAllInstruction`](#exchangeallinstruction) struct.
     * @return An array of [`Commands`](../Command.sol/struct.Command.html) to execute the instruction.
     */
    function compileExchangeAllInstruction(
        ExchangeAllInstruction calldata instruction
    ) external returns (Command[] memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IJitCompiler} from "./IJitCompiler.sol";

/**
 * @title Script
 * @notice A structure defining a script with various instructions for a JIT compiler.
 * @notice The [JIT compiler](../IJitCompiler.sol/interface.IJitCompiler.html)
 * will compile it the following way:
 *  1. Flatten content's instructions arrays into a single-dimensional array: `flattened =
 *  [...increasePositionInstructions, ...decreasePositionInstructions,
      ...exchangeInstructions, ...exchangeAllInstructions]`.
 *  2. Execute `flattened[PC]` where `PC = sequence[i]` where `i` is the
 *    index of current loop iteration, starting from `i = 0`.
 *  3. Increment current loop iteration index: `i = i + 1`.
 *  4. If `i < length(flattened)` go to step 2.
 *
 * @dev `canFail` Determines whether the script can silently fail. If true
 * transaction will not be reverted but execution will be terminated.
 * @dev `sequence` Auto-incrementing read-only program counter. Determines the
 * order of execution of the instruction within the script.
 * @dev `increasePositionInstructions` An array of
 * [`IncreasePositionInstructions`](../IJitCompiler.sol/interface.IJitCompiler.html#increasepositioninstruction).
 * @dev `decreasePositionInstructions` An array of
 * [`DecreasePositionInstructions`](../IJitCompiler.sol/interface.IJitCompiler.html#decreasepositioninstruction).
 * @dev `exchangeInstructions` An array of
 * [`ExchangeInstructions`](../IJitCompiler.sol/interface.IJitCompiler.html#exchangeinstruction).
 * @dev `exchangeAllInstructions` An array of
 * [`ExchangeAllInstructions`](../IJitCompiler.sol/interface.IJitCompiler.html#exchangeallinstruction).
 */
struct Script {
    bool canFail;
    uint256[] sequence;
    IJitCompiler.IncreasePositionInstruction[] increasePositionInstructions;
    IJitCompiler.DecreasePositionInstruction[] decreasePositionInstructions;
    IJitCompiler.ExchangeInstruction[] exchangeInstructions;
    IJitCompiler.ExchangeAllInstruction[] exchangeAllInstructions;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {AssetLibrary} from "contracts/libraries/AssetLibrary.sol";

/**
 * @title Asset
 * @dev Represents an asset with its token address and the amount.
 * @param token The address of the asset's token.
 * @param amount The amount of the asset.
 */
struct Asset {
    address token;
    uint256 amount;
}

using AssetLibrary for Asset global;

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IInitializable} from "contracts/interfaces/common/IInitializable.sol";
import {IAccountStateMachine} from "contracts/interfaces/marginAccount/IAccountStateMachine.sol";

import {State} from "contracts/base/StateMachine.sol";
import {Asset} from "contracts/libraries/AssetLibrary.sol";

import {Command} from "../compiler/Command.sol";
import {Script} from "../compiler/Script.sol";

interface IAccount is IInitializable, IAccountStateMachine {
    event AccountRegistered(address owner, address agreement, Asset[] collateral, Asset leverage);
    event AccountOpened(address owner);
    event AccountSuspended(address owner);
    event AccountClosed(address previousOwner);

    /**
     * @notice Thrown when a function is called more than once within the same block.
     * @dev This error is used by the `blockGuard` modifier to prevent repeated transactions within a single block,
     *      mitigating the risks of double sandwiching attacks, where multiple front-running and back-running attacks
     *      are performed in the same block to manipulate prices and extract profits.
     */
    error ReentrantTransactionInSameBlock();

    /**
     * @notice Receive Ether and log the transaction.
     * @dev This function is called when the margin account receives Ether without a specific function call.
     */
    receive() external payable;

    /**
     * @notice Registers a margin account, transitioning it to the registered state.
     * @param user The address that will be assigned as the owner of the margin account.
     * @param agreement The address of the agreement associated with the margin account.
     * @param collateral An array of [`Asset`](/interfaces/compliance/Asset.sol/struct.Asset.html) representing the collateral that must be transferred to the margin account before this function is called.
     * @param requestedLeverage An [`Asset`](/interfaces/compliance/Asset.sol/struct.Asset.html) representing the leverage to be supplied to the margin account to transition its state to "opened."
     * @dev The function will revert if:
     * - The assets transferred before the call are insufficient.
     * - The margin account is in an invalid state.
     *
     * Emits:
     * - `AccountRegistered` event indicating the margin account has been successfully registered.
     */
    function register(
        address user,
        address agreement,
        Asset[] calldata collateral,
        Asset calldata requestedLeverage
    ) external;

    /**
     * @notice This method opens margin account by receiving requested leverage.
     * @dev Reverts if account is in an invalid state or sender is not a dispatcher.
     */
    function supply() external;

    /**
     * @notice Immediately switches the account to the suspended state and
     * tries to execute provided scripts
     * @dev Reverts if either script's compilation failed in [compiler](/interfaces/compiler/index.html)
     * or account's state cannot be switched to the suspended state
     * @param closeStrategy An array of [`Script`](/interfaces/compiler/Script.sol/struct.Script.html) representing the strategy to close the account.
     * If all scripts are executed successfully,
     * the account will be switched to the closed state.
     * @return success Whether the account was switched to the closed state
     */
    function close(Script[] calldata closeStrategy) external returns (bool success);

    /**
     * @notice Immediately switches the account to the suspended state and
     * tries to execute provided scripts
     * @dev Reverts if either script's compilation failed in [compiler](/interfaces/compiler/index.html)
     * or account's state cannot be switched to the suspended state
     * @param liquidationStrategy An array of [`Script`](/interfaces/compiler/Script.sol/struct.Script.html) representing the strategy to liquidate the account.
     * If all scripts are executed successfully,
     * @return success Whether the account was switched to the closed state
     */
    function liquidate(Script[] calldata liquidationStrategy) external returns (bool success);

    function withdraw(address token, address recipient, uint256 amount) external;

    /**
     * @notice Allows margin account's owner to execute any low level call
     * @dev Reverts if either validation failed, call failed or account
     * is in an invalid state
     * @param cmd Parameters of the call: target, value and payload.
     * All the parameters will be validated in validation hub before execution.
     * All the approvals will performed automatically, owner does not need to
     * do it manually
     */
    function execute(Command calldata cmd) external;

    /**
     * @notice Leverage asset allocated (or being allocated) to the account
     */
    function leverage() external view returns (address, uint256);

    /**
     * @return currentState In which state the state machine is running now
     * @return switchTimestamp Time, when state was switched to the underlying state
     */
    function stateInfo() external view returns (State currentState, uint256 switchTimestamp);

    function allocationInfo()
        external
        view
        returns (
            State currentState,
            uint256 stateSwitchTimestamp,
            address owner,
            address leverageToken,
            uint256 leverageAmount
        );

    /**
     * @notice Returns the address of the current agreement contract.
     * @return The address of the agreement contract.
     * @dev This function provides the address of the contract responsible for managing agreements. It is useful for interacting with or querying details related to the agreement.
     */
    function agreement() external view returns (address);

    /**
     * @notice Returns the owner of the margin account.
     * @return The address of the the margin account owner.
     */
    function owner() external view returns (address);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IERC165Extended} from "contracts/interfaces/base/IERC165Extended.sol";

interface IAccountFactory is IERC165Extended {
    /// @notice Logged when new margin account is deployed
    event AccountDeployed(address indexed account);
    /// @notice Logged every time a margin account being assigned to a new owner
    event AccountBorrowed(address indexed account);
    /// @notice Logged every time a margin account being unassigned from the previous owner
    event AccountReturned(address indexed account);

    /**
     * @notice Allows *Margin Engine* to borrow an account for registration.
     * @return Address of the borrowed account.
     */
    function borrowAccount() external returns (address);

    /**
     * @notice After account was closed or liquidated *Margin Engine* returns it to the factory for later reuse.
     * @param account Address of the account to return.
     */
    function returnAccount(address account) external;

    /**
     * @notice Utility to deploy multiple margin accounts for future use
     * @param count Number of margin accounts to deploy
     */
    function deployMarginAccounts(uint256 count) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

interface IAccountStateMachine {
    function registerAccount(bytes calldata _args) external;

    function openAccount(bytes calldata) external;

    function suspendAccount(bytes calldata) external;

    function closeAccount(bytes calldata) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

library Address {
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function set(bytes32 _slot, address _value) internal {
        assembly {
            sstore(_slot, _value)
        }
    }

    function get(bytes32 _slot) internal view returns (address result_) {
        assembly {
            result_ := sload(_slot)
        }
    }

    function isEth(address _token) internal pure returns (bool) {
        return _token == ETH || _token == address(0);
    }

    function sort(address _a, address _b) internal pure returns (address, address) {
        return _a < _b ? (_a, _b) : (_b, _a);
    }

    function sort(address[4] memory _array) internal pure returns (address[4] memory _sorted) {
        // Sorting network for the array of length 4
        (_sorted[0], _sorted[1]) = sort(_array[0], _array[1]);
        (_sorted[2], _sorted[3]) = sort(_array[2], _array[3]);

        (_sorted[0], _sorted[2]) = sort(_sorted[0], _sorted[2]);
        (_sorted[1], _sorted[3]) = sort(_sorted[1], _sorted[3]);
        (_sorted[1], _sorted[2]) = sort(_sorted[1], _sorted[2]);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {AmountMustNotBeZero} from "contracts/interfaces/base/CommonErrors.sol";
import {Asset} from "contracts/interfaces/compliance/Asset.sol";

import {Address} from "./Address.sol";

library AssetLibrary {
    using SafeTransferLib for address;
    using Address for address;

    error NotEnoughReceived(address token, uint256 expected, uint256 received);

    function forward(Asset calldata self, address _to) internal {
        if (self.amount == 0) revert AmountMustNotBeZero(self.token);

        if (self.token.isEth()) _to.safeTransferETH(self.amount);
        else self.token.safeTransferFrom(msg.sender, _to, self.amount);
    }

    function approve(Asset calldata self, address to) internal {
        self.token.safeApprove(to, self.amount);
    }

    function receiveFrom(Asset storage self, address from) internal {
        self.token.safeTransferFrom(from, address(this), self.amount);
    }

    function receiveFrom(Asset calldata self, address from) internal {
        self.token.safeTransferFrom(from, address(this), self.amount);
    }

    function enforceReceived(Asset calldata self) internal view {
        if (self.amount == 0) revert AmountMustNotBeZero(self.token);

        uint256 balance = self.token.isEth()
            ? address(this).balance
            : self.token.balanceOf(address(this));

        if (balance < self.amount) revert NotEnoughReceived(self.token, self.amount, balance);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Command} from "contracts/interfaces/compiler/Command.sol";
import {SafeCall} from "contracts/libraries/SafeCall.sol";

/**
 * @notice Utility to convert often-used methods into a Command object
 */
library CommandPresets {
    function approve(
        address _token,
        address _to,
        uint256 _amount
    ) internal pure returns (Command[] memory result_) {
        result_ = new Command[](2);
        result_[0] = Command(_token, 0, abi.encodeCall(IERC20.approve, (_to, 0)));
        result_[1] = Command(_token, 0, abi.encodeCall(IERC20.approve, (_to, _amount)));
    }

    function transfer(
        address _token,
        address _to,
        uint256 _amount
    ) internal pure returns (Command memory cmd_) {
        cmd_.target = _token;
        cmd_.payload = abi.encodeCall(IERC20.transfer, (_to, _amount));
    }
}

library CommandExecutor {
    using SafeCall for Command[];

    function execute(Command[] calldata _cmds) external {
        _cmds.safeCallAll();
    }
}

library CommandLibrary {
    using CommandLibrary for Command[];

    function last(Command[] memory _self) internal pure returns (Command memory) {
        return _self[_self.length - 1];
    }

    function asArray(Command memory _self) internal pure returns (Command[] memory result_) {
        result_ = new Command[](1);
        result_[0] = _self;
    }

    function append(
        Command[] memory _self,
        Command[] memory _cmds
    ) internal pure returns (Command[] memory result_) {
        result_ = new Command[](_self.length + _cmds.length);
        uint256 i;
        for (; i < _self.length; i++) {
            result_[i] = _self[i];
        }
        for (; i < result_.length; i++) {
            result_[i] = _cmds[i - _self.length];
        }
    }

    function push(
        Command[] memory _self,
        Command memory _cmd
    ) internal pure returns (Command[] memory result_) {
        result_ = new Command[](_self.length + 1);
        for (uint256 i; i < _self.length; i++) {
            result_[i] = _self[i];
        }
        result_[_self.length] = _cmd;
    }

    function populateWithApprove(
        Command memory _self,
        address _token,
        uint256 _amount
    ) internal pure returns (Command[] memory result_) {
        if (_amount != 0) {
            result_ = CommandPresets.approve(_token, _self.target, _amount).push(_self);
        } else {
            result_ = _self.asArray();
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

library DiamondLibrary {
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
    }

    // keccak256("diamond.standard.diamond.storage")
    bytes32 private constant DIAMOND_STORAGE_SLOT =
        0xc8fcad8db84d3cc18b4c41d551ea0ee66dd599cde068d998e57d5e09332c131c;

    function diamondStorage() internal pure returns (DiamondStorage storage $) {
        assembly {
            $.slot := DIAMOND_STORAGE_SLOT
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Command} from "contracts/interfaces/compiler/Command.sol";

/**
 * @notice Safe methods performing a low-level calls that revert
 * if the call was not successful
 */
library SafeCall {
    using Address for address;

    function safeCallAll(Command[] memory _cmds) internal {
        for (uint256 i; i < _cmds.length; i++) {
            safeCall(_cmds[i]);
        }
    }

    function safeCall(Command memory _cmd) internal returns (bytes memory result_) {
        result_ = safeCall(_cmd.target, _cmd.value, _cmd.payload);
    }

    function safeCall(address _target, bytes memory _data) internal returns (bytes memory result_) {
        result_ = safeCall(_target, 0, _data);
    }

    function safeCall(
        address _target,
        uint256 _value,
        bytes memory _data
    ) internal returns (bytes memory result_) {
        result_ = _target.functionCallWithValue(_data, _value);
    }

    function safeDelegateCall(
        address _target,
        bytes memory _data
    ) internal returns (bytes memory result_) {
        result_ = _target.functionDelegateCall(_data);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {
    IERC165
} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import {IInitializable} from "contracts/interfaces/common/IInitializable.sol";
import {IAccount} from "contracts/interfaces/marginAccount/IAccount.sol";
import {IAccountFactory} from "contracts/interfaces/marginAccount/IAccountFactory.sol";

import {BeaconDS} from "contracts/base/proxy/BeaconDS.sol";
import {ImmutableBeaconProxy} from "contracts/base/proxy/ImmutableBeaconProxy.sol";

import {AccountFactoryRepository as Repository} from "./libraries/AccountFactoryRepository.sol";

contract AccountFactory is IAccountFactory, BeaconDS {
    bytes32 public constant MARGIN_ENGINE_ROLE = keccak256("Margin Engine");

    function setImplementation(address implementation) external override whenPaused onlyOwner {
        if (!IERC165(implementation).supportsInterface(type(IAccount).interfaceId))
            revert InvalidImplementation(implementation);
        _setImplementation(implementation);
    }

    function borrowAccount()
        external
        override
        whenNotPaused
        onlyRole(MARGIN_ENGINE_ROLE)
        returns (address account)
    {
        account = Repository.isMarginAccountsPoolEmpty()
            ? deployMarginAccount()
            : Repository.popMarginAccount();

        emit AccountBorrowed(account);
    }

    function returnAccount(
        address account
    ) external override whenNotPaused onlyRole(MARGIN_ENGINE_ROLE) {
        Repository.pushMarginAccount(account);
        emit AccountReturned(address(account));
    }

    function deployMarginAccounts(uint256 _count) external override whenNotPaused onlyOwner {
        for (uint256 i; i < _count; i++) {
            Repository.pushMarginAccount(deployMarginAccount());
        }
    }

    function deployMarginAccount() internal returns (address) {
        bytes memory initData = abi.encodeCall(IInitializable.initialize, ());
        address acc = address(new ImmutableBeaconProxy(initData));
        emit AccountDeployed(acc);
        return acc;
    }

    /* solhint-disable ordering */
    function supportsInterfaceExtended(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IAccountFactory).interfaceId;
    }
    /* solhint-enable ordering */
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

library AccountFactoryRepository {
    struct Storage {
        uint256 __gap;
        address[] pool;
    }

    // keccak256("Margin Account Factory State V1")
    bytes32 private constant STORAGE_SLOT =
        0x543a5afad456720a20bb954f3229d0931809b27405d3298f8b5e666962637d83;

    error MarginAccountsPoolIsEmpty();
    error MarginAccountImplementationNotFound();

    function pushMarginAccount(address _account) internal {
        _storage().pool.push(_account);
    }

    function popMarginAccount() internal returns (address account_) {
        if (isMarginAccountsPoolEmpty()) revert MarginAccountsPoolIsEmpty();
        Storage storage $ = _storage();
        uint256 last = $.pool.length - 1;
        account_ = $.pool[last];
        $.pool.pop();
    }

    function isMarginAccountsPoolEmpty() internal view returns (bool) {
        return _storage().pool.length == 0;
    }

    function _storage() private pure returns (Storage storage $) {
        assembly {
            $.slot := STORAGE_SLOT
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for bit twiddling and boolean operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibBit.sol)
/// @author Inspired by (https://graphics.stanford.edu/~seander/bithacks.html)
library LibBit {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  BIT TWIDDLING OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Find last set.
    /// Returns the index of the most significant bit of `x`,
    /// counting from the least significant bit position.
    /// If `x` is zero, returns 256.
    /// Equivalent to `log2(x)`, but without reverting for the zero case.
    function fls(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(8, iszero(x))

            r := or(r, shl(7, lt(0xffffffffffffffffffffffffffffffff, x)))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))

            // For the remaining 32 bits, use a De Bruijn lookup.
            x := shr(r, x)
            x := or(x, shr(1, x))
            x := or(x, shr(2, x))
            x := or(x, shr(4, x))
            x := or(x, shr(8, x))
            x := or(x, shr(16, x))

            // forgefmt: disable-next-item
            r := or(r, byte(shr(251, mul(x, shl(224, 0x07c4acdd))),
                0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f))
        }
    }

    /// @dev Count leading zeros.
    /// Returns the number of zeros preceding the most significant one bit.
    /// If `x` is zero, returns 256.
    function clz(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            let t := add(iszero(x), 255)

            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))

            // For the remaining 32 bits, use a De Bruijn lookup.
            x := shr(r, x)
            x := or(x, shr(1, x))
            x := or(x, shr(2, x))
            x := or(x, shr(4, x))
            x := or(x, shr(8, x))
            x := or(x, shr(16, x))

            // forgefmt: disable-next-item
            r := sub(t, or(r, byte(shr(251, mul(x, shl(224, 0x07c4acdd))),
                0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f)))
        }
    }

    /// @dev Find first set.
    /// Returns the index of the least significant bit of `x`,
    /// counting from the least significant bit position.
    /// If `x` is zero, returns 256.
    /// Equivalent to `ctz` (count trailing zeros), which gives
    /// the number of zeros following the least significant one bit.
    function ffs(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            r := shl(8, iszero(x))

            // Isolate the least significant bit.
            x := and(x, add(not(x), 1))

            r := or(r, shl(7, lt(0xffffffffffffffffffffffffffffffff, x)))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))

            // For the remaining 32 bits, use a De Bruijn lookup.
            // forgefmt: disable-next-item
            r := or(r, byte(shr(251, mul(shr(r, x), shl(224, 0x077cb531))), 
                0x00011c021d0e18031e16140f191104081f1b0d17151310071a0c12060b050a09))
        }
    }

    /// @dev Returns the number of set bits in `x`.
    function popCount(uint256 x) internal pure returns (uint256 c) {
        /// @solidity memory-safe-assembly
        assembly {
            let max := not(0)
            let isMax := eq(x, max)
            x := sub(x, and(shr(1, x), div(max, 3)))
            x := add(and(x, div(max, 5)), and(shr(2, x), div(max, 5)))
            x := and(add(x, shr(4, x)), div(max, 17))
            c := or(shl(8, isMax), shr(248, mul(x, div(max, 255))))
        }
    }

    /// @dev Returns whether `x` is a power of 2.
    function isPo2(uint256 x) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `x && !(x & (x - 1))`.
            result := iszero(add(and(x, sub(x, 1)), iszero(x)))
        }
    }

    /// @dev Returns `x` reversed at the bit level.
    function reverseBits(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Computing masks on-the-fly reduces bytecode size by about 500 bytes.
            let m := not(0)
            r := x
            for { let s := 128 } 1 {} {
                m := xor(m, shl(s, m))
                r := or(and(shr(s, r), m), and(shl(s, r), not(m)))
                s := shr(1, s)
                if iszero(s) { break }
            }
        }
    }

    /// @dev Returns `x` reversed at the byte level.
    function reverseBytes(uint256 x) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Computing masks on-the-fly reduces bytecode size by about 200 bytes.
            let m := not(0)
            r := x
            for { let s := 128 } 1 {} {
                m := xor(m, shl(s, m))
                r := or(and(shr(s, r), m), and(shl(s, r), not(m)))
                s := shr(1, s)
                if eq(s, 4) { break }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     BOOLEAN OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `x & y`.
    function and(bool x, bool y) internal pure returns (bool z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := and(x, y)
        }
    }

    /// @dev Returns `x | y`.
    function or(bool x, bool y) internal pure returns (bool z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := or(x, y)
        }
    }

    /// @dev Returns a non-zero number if `b` is true, else 0.
    /// If `b` is from plain Solidity, the non-zero number will be 1.
    function toUint(bool b) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := b
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Caution! This library won't check that a token has code, responsibility is delegated to the caller.
library SafeTransferLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The ETH transfer has failed.
    error ETHTransferFailed();

    /// @dev The ERC20 `transferFrom` has failed.
    error TransferFromFailed();

    /// @dev The ERC20 `transfer` has failed.
    error TransferFailed();

    /// @dev The ERC20 `approve` has failed.
    error ApproveFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Suggested gas stipend for contract receiving ETH
    /// that disallows any storage writes.
    uint256 internal constant _GAS_STIPEND_NO_STORAGE_WRITES = 2300;

    /// @dev Suggested gas stipend for contract receiving ETH to perform a few
    /// storage reads and writes, but low enough to prevent griefing.
    /// Multiply by a small constant (e.g. 2), if needed.
    uint256 internal constant _GAS_STIPEND_NO_GRIEF = 100000;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ETH OPERATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` (in wei) ETH to `to`.
    /// Reverts upon failure.
    function safeTransferETH(address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, amount, 0, 0, 0, 0)) {
                // Store the function selector of `ETHTransferFailed()`.
                mstore(0x00, 0xb12d13eb)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    /// The `gasStipend` can be set to a low enough value to prevent
    /// storage writes or gas griefing.
    ///
    /// If sending via the normal procedure fails, force sends the ETH by
    /// creating a temporary contract which uses `SELFDESTRUCT` to force send the ETH.
    ///
    /// Reverts if the current contract has insufficient balance.
    function forceSafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal {
        /// @solidity memory-safe-assembly
        assembly {
            // If insufficient balance, revert.
            if lt(selfbalance(), amount) {
                // Store the function selector of `ETHTransferFailed()`.
                mstore(0x00, 0xb12d13eb)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(gasStipend, to, amount, 0, 0, 0, 0)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                // We can directly use `SELFDESTRUCT` in the contract creation.
                // Compatible with `SENDALL`: https://eips.ethereum.org/EIPS/eip-4758
                if iszero(create(amount, 0x0b, 0x16)) {
                    // For better gas estimation.
                    if iszero(gt(gas(), 1000000)) { revert(0, 0) }
                }
            }
        }
    }

    /// @dev Force sends `amount` (in wei) ETH to `to`, with a gas stipend
    /// equal to `_GAS_STIPEND_NO_GRIEF`. This gas stipend is a reasonable default
    /// for 99% of cases and can be overriden with the three-argument version of this
    /// function if necessary.
    ///
    /// If sending via the normal procedure fails, force sends the ETH by
    /// creating a temporary contract which uses `SELFDESTRUCT` to force send the ETH.
    ///
    /// Reverts if the current contract has insufficient balance.
    function forceSafeTransferETH(address to, uint256 amount) internal {
        // Manually inlined because the compiler doesn't inline functions with branches.
        /// @solidity memory-safe-assembly
        assembly {
            // If insufficient balance, revert.
            if lt(selfbalance(), amount) {
                // Store the function selector of `ETHTransferFailed()`.
                mstore(0x00, 0xb12d13eb)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(_GAS_STIPEND_NO_GRIEF, to, amount, 0, 0, 0, 0)) {
                mstore(0x00, to) // Store the address in scratch space.
                mstore8(0x0b, 0x73) // Opcode `PUSH20`.
                mstore8(0x20, 0xff) // Opcode `SELFDESTRUCT`.
                // We can directly use `SELFDESTRUCT` in the contract creation.
                // Compatible with `SENDALL`: https://eips.ethereum.org/EIPS/eip-4758
                if iszero(create(amount, 0x0b, 0x16)) {
                    // For better gas estimation.
                    if iszero(gt(gas(), 1000000)) { revert(0, 0) }
                }
            }
        }
    }

    /// @dev Sends `amount` (in wei) ETH to `to`, with a `gasStipend`.
    /// The `gasStipend` can be set to a low enough value to prevent
    /// storage writes or gas griefing.
    ///
    /// Simply use `gasleft()` for `gasStipend` if you don't need a gas stipend.
    ///
    /// Note: Does NOT revert upon failure.
    /// Returns whether the transfer of ETH is successful instead.
    function trySafeTransferETH(address to, uint256 amount, uint256 gasStipend)
        internal
        returns (bool success)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and check if it succeeded or not.
            success := call(gasStipend, to, amount, 0, 0, 0, 0)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC20 OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sends `amount` of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for
    /// the current contract to manage.
    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.

            mstore(0x60, amount) // Store the `amount` argument.
            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            // Store the function selector of `transferFrom(address,address,uint256)`.
            mstore(0x0c, 0x23b872dd000000000000000000000000)

            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `TransferFromFailed()`.
                mstore(0x00, 0x7939f424)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends all of ERC20 `token` from `from` to `to`.
    /// Reverts upon failure.
    ///
    /// The `from` account must have at least `amount` approved for
    /// the current contract to manage.
    function safeTransferAllFrom(address token, address from, address to)
        internal
        returns (uint256 amount)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.

            mstore(0x40, to) // Store the `to` argument.
            mstore(0x2c, shl(96, from)) // Store the `from` argument.
            // Store the function selector of `balanceOf(address)`.
            mstore(0x0c, 0x70a08231000000000000000000000000)
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x60, 0x20)
                )
            ) {
                // Store the function selector of `TransferFromFailed()`.
                mstore(0x00, 0x7939f424)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Store the function selector of `transferFrom(address,address,uint256)`.
            mstore(0x00, 0x23b872dd)
            // The `amount` argument is already written to the memory word at 0x6c.
            amount := mload(0x60)

            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x1c, 0x64, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `TransferFromFailed()`.
                mstore(0x00, 0x7939f424)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x60, 0) // Restore the zero slot to zero.
            mstore(0x40, m) // Restore the free memory pointer.
        }
    }

    /// @dev Sends `amount` of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransfer(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            // Store the function selector of `transfer(address,uint256)`.
            mstore(0x00, 0xa9059cbb000000000000000000000000)

            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `TransferFailed()`.
                mstore(0x00, 0x90b8ec18)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Restore the part of the free memory pointer that was overwritten.
            mstore(0x34, 0)
        }
    }

    /// @dev Sends all of ERC20 `token` from the current contract to `to`.
    /// Reverts upon failure.
    function safeTransferAll(address token, address to) internal returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x70a08231) // Store the function selector of `balanceOf(address)`.
            mstore(0x20, address()) // Store the address of the current contract.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), token, 0x1c, 0x24, 0x34, 0x20)
                )
            ) {
                // Store the function selector of `TransferFailed()`.
                mstore(0x00, 0x90b8ec18)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            mstore(0x14, to) // Store the `to` argument.
            // The `amount` argument is already written to the memory word at 0x34.
            amount := mload(0x34)
            // Store the function selector of `transfer(address,uint256)`.
            mstore(0x00, 0xa9059cbb000000000000000000000000)

            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `TransferFailed()`.
                mstore(0x00, 0x90b8ec18)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Restore the part of the free memory pointer that was overwritten.
            mstore(0x34, 0)
        }
    }

    /// @dev Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
    /// Reverts upon failure.
    function safeApprove(address token, address to, uint256 amount) internal {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, to) // Store the `to` argument.
            mstore(0x34, amount) // Store the `amount` argument.
            // Store the function selector of `approve(address,uint256)`.
            mstore(0x00, 0x095ea7b3000000000000000000000000)

            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0x00), 1), iszero(returndatasize())),
                    call(gas(), token, 0, 0x10, 0x44, 0x00, 0x20)
                )
            ) {
                // Store the function selector of `ApproveFailed()`.
                mstore(0x00, 0x3e3f8f73)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
            // Restore the part of the free memory pointer that was overwritten.
            mstore(0x34, 0)
        }
    }

    /// @dev Returns the amount of ERC20 `token` owned by `account`.
    /// Returns zero if the `token` does not exist.
    function balanceOf(address token, address account) internal view returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, account) // Store the `account` argument.
            // Store the function selector of `balanceOf(address)`.
            mstore(0x00, 0x70a08231000000000000000000000000)
            amount :=
                mul(
                    mload(0x20),
                    and( // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                    )
                )
        }
    }
}
