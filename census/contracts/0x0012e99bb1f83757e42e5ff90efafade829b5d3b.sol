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
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ContextUpgradeable} from "../../utils/ContextUpgradeable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20, IERC20Metadata, IERC20Errors {
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20
    struct ERC20Storage {
        mapping(address account => uint256) _balances;

        mapping(address account => mapping(address spender => uint256)) _allowances;

        uint256 _totalSupply;

        string _name;
        string _symbol;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        ERC20Storage storage $ = _getERC20Storage();
        $._name = name_;
        $._symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        ERC20Storage storage $ = _getERC20Storage();
        return $._allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            $._totalSupply += value;
        } else {
            uint256 fromBalance = $._balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                $._balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                $._balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        ERC20Storage storage $ = _getERC20Storage();
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        $._allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
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
// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC-165 should inherit from this contract and override {supportsInterface} to check
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
// OpenZeppelin Contracts (last updated v5.1.0) (access/IAccessControl.sol)

pragma solidity ^0.8.20;

/**
 * @dev External interface of AccessControl declared to support ERC-165 detection.
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
     * `sender` is the account that originated the contract call. This account bears the admin role (for the granted role).
     * Expected in cases where the role was granted using the internal {AccessControl-_grantRole}.
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
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

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
// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
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
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AllStars Staking Pool
 * @notice A staking contract that allows users to stake approved ERC20 tokens and earn rewards in STAR tokens.
 * @dev Implements role-based access control, pausable functionality, and reentrancy protection.
 */
contract AllStarsStakingPoolV3 is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /// @notice Role identifier for administrative functions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Constant representing the zero address
    address internal constant ZERO_ADDRESS = address(0);

    /// @notice Constant used for rewards precision
    uint256 internal constant REWARDS_PRECISION = 1e18;

    /// @notice The ERC20 token used for rewards
    IERC20 public starToken;

    /// @notice Number of reward tokens minted per block
    uint256 public rewardTokensPerBlock;

    /// @notice Block number at which staking ends
    uint256 public stakingEndBlock;

    /// @notice List of tokens allowed for staking
    address[] private allowedTokenArray;

    /// @notice address of Super Admin
    address public superAdmin;

    // Struct representing a staker's data within a pool
    struct PoolStaker {
        uint256 amount; // Total tokens staked by the user.
        uint256 stakedTime; // Timestamp when the tokens were staked.
        uint256 lastUpdatedBlock; // Last block when rewards were calculated.
        uint256 rewardDebt; // Rewards the user cannot claim yet.
        uint256 rewardClaimed; // Rewards the user claimed.
    }

    // Struct representing detailed staking information
    struct StakeDetails {
        uint256 stakeId; // Identifier for the stake.
        uint256 amount; // Amount staked in this instance.
        uint256 stakedTime; // Timestamp when the stake was made.
        bool claimed; // Whether the stake has been claimed.
    }

    /// @notice Mapping of token address to total staked amount
    mapping(address => uint256) public tokensStaked;

    /// @notice Mapping of token address to last rewarded block
    mapping(address => uint256) public lastRewardedBlock;

    /// @notice Mapping of token address to accumulated rewards per share
    mapping(address => uint256) public accumulatedRewardsPerShare;

    /// @notice Mapping of user address to token address to stake ID index
    mapping(address => mapping(address => uint256))
        public userTokenStakeIdIndex;

    /// @notice Mapping of user address to token address to last withdrawn stake ID
    mapping(address => mapping(address => uint256)) public lastWithdrawStakeId;

    /// @notice Mapping of user address to token address to stake details
    mapping(address => mapping(address => mapping(uint256 => StakeDetails)))
        public userTokenStakeDetails;

    /// @notice Mapping of token address to staker address to staker details
    mapping(address => mapping(address => PoolStaker)) public poolStakers;

    /// @notice Mapping of user addresses to blacklist status
    mapping(address => bool) public isBlacklisted;

    /// @notice Mapping of user addresses to locked rewards
    mapping(address => uint256) public userLockedRewards;

    /// @notice Mapping of user addresses to locked rewards
    mapping(address => mapping(address => uint256)) public newUserLockedRewards;

    /// @notice Minimum STARS token balance required for staking
    uint256 public minimumStarsBalance;

    /// @notice Event emitted when a deposit is made
    event Deposit(address indexed token, address indexed user, uint256 amount);

    /// @notice Event emitted when a withdrawal is made
    event Withdraw(address indexed token, address indexed user, uint256 amount);

    /// @notice Event emitted when the allowed tokens list is updated
    event AllowedTokensUpdated(address[] newAllowedTokens);

    /// @notice Event emitted when the Super Admin is changed
    event SuperAdminChanged(
        address indexed oldSuperAdmin,
        address indexed newSuperAdmin
    );

    /// @notice Event emitted when the Star Token is withdrawn
    event StarTokensWithdrawn(address indexed recipient, uint256 amount);

    /**
     * @notice Modifier to restrict function access to the superAdmin only.
     */
    modifier onlySuperAdmin() {
        require(
            _msgSender() == superAdmin,
            "AllStarsStakingPool: Caller is not the superAdmin"
        );
        _;
    }

    /**
     * @notice Initializes the contract with initial parameters.
     * @param starToken_ The address of the STAR ERC20 token contract.
     * @param adminAddress The address of the admin.
     * @param allowedTokens_ The list of allowed tokens for staking.
     * @param rewardTokensPerBlock_ Number of STAR tokens distributed per block.
     * @param stakingEndBlock_ Block number at which staking ends.
     */
    function initialize(
        IERC20 starToken_,
        address adminAddress,
        address[] memory allowedTokens_,
        uint256 rewardTokensPerBlock_,
        uint256 stakingEndBlock_,
        uint256 minimumStarsBalance_
    ) public initializer {
        require(
            rewardTokensPerBlock_ > 0,
            "AllStarsStakingPool: Reward tokens must be greater than zero"
        );
        require(
            stakingEndBlock_ > 0,
            "AllStarsStakingPool: Staking end block must be greater than zero"
        );
        require(
            address(starToken_) != ZERO_ADDRESS && adminAddress != ZERO_ADDRESS,
            "AllStarsStakingPool: Zero address provided for STAR token or admin"
        );
        require(
            allowedTokens_.length > 0,
            "AllStarsStakingPool: No allowed tokens provided"
        );
        require(
            minimumStarsBalance_ > 0,
            "AllStarsStakingPool: Minimum STARS balance must be greater than zero"
        );

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        starToken = starToken_;
        allowedTokenArray = allowedTokens_;
        rewardTokensPerBlock = rewardTokensPerBlock_;
        stakingEndBlock = stakingEndBlock_;
        superAdmin = adminAddress;
        minimumStarsBalance = minimumStarsBalance_;

        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, superAdmin);
    }

    
    // ==================== SEEDING LOGIC START ====================

    /**
     * @notice Function for seeding data of mapping:userLockedRewards
     * @param _users Array of user addresses.
     * @param _lockedRewards Array of locked reward amounts.
     */
    function seedUserLockedRewardsData(
        address[] calldata _users,
        uint256[] calldata _lockedRewards
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalUsers = _users.length;
        require(totalUsers == _lockedRewards.length, "ArrayLengthMismatch");
        for(uint256 i=0; i<totalUsers; ++i) {
            userLockedRewards[_users[i]] = _lockedRewards[i];
        }
    }


    struct TokenDataSeed {
        address token; //token address
        uint256 tokensStakedData; // token's value for mapping: tokensStaked
        uint256 lastRewardedBlockData; // token's value for mapping: lastRewardedBlock
        uint256 accumulatedRewardsPerShareData; // token's value for mapping: accumulatedRewardsPerShare 
    }

    /**
     * @notice Function for seeding token's data of mappings: tokensStaked,lastRewardedBlock,accumulatedRewardsPerShare
     * @param _tokensDataSeed Array of data to seed as per TokenDataSeed struct.
     */
    function seedTokensData(
        TokenDataSeed[] calldata _tokensDataSeed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalTokens = _tokensDataSeed.length;
        for(uint256 i=0; i<totalTokens; ++i) {
            TokenDataSeed calldata seed = _tokensDataSeed[i];
            tokensStaked[seed.token] = seed.tokensStakedData;
            lastRewardedBlock[seed.token] = seed.lastRewardedBlockData;
            accumulatedRewardsPerShare[seed.token] = seed.accumulatedRewardsPerShareData;
        }
    }


    struct UserTokenStakeIdIndexSeed {
        address token; // token address
        address[] users; // Array of user addresses
        uint256[] stakeIndexes; // Array of user stake indexes
    }

    /**
     * @notice Function for seeding data of mapping: userTokenStakeIdIndex
     * @param _userTokenStakeIdIndexSeed Array of data to seed as per struct UserTokenStakeIdIndexSeed.
     */
    function seedUserTokenStakeIdIndexData(
        UserTokenStakeIdIndexSeed[] calldata _userTokenStakeIdIndexSeed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalTokens = _userTokenStakeIdIndexSeed.length; 
        for(uint256 i=0; i<totalTokens; ++i) {
            UserTokenStakeIdIndexSeed calldata seed = _userTokenStakeIdIndexSeed[i];
            address token = seed.token;
            uint256 totalUsers = seed.users.length;
            require(totalUsers == seed.stakeIndexes.length, "ArrayLengthMismatch");
            for(uint256 j=0; j<totalUsers; ++j) {
                userTokenStakeIdIndex[token][seed.users[j]] = seed.stakeIndexes[j];
            }
        }
    }


    struct LastWithdrawStakeIdSeed {
        address token; // token address
        address[] users; // Array of user addresses
        uint256[] lastWithdrawIds; // Array of last withdraw stake ids
    }

    /**
     * @notice Function for seeding data of mapping:lastWithdrawStakeId
     * @param _lastWithdrawStakeIdSeed Array of data to seed as per struct LastWithdrawStakeIdSeed.
     */
    function seedLastWithdrawStakeIdData(
        LastWithdrawStakeIdSeed[] calldata _lastWithdrawStakeIdSeed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalTokens = _lastWithdrawStakeIdSeed.length;
        for(uint256 i=0; i<totalTokens; ++i) {
            LastWithdrawStakeIdSeed calldata seed = _lastWithdrawStakeIdSeed[i];
            address token = seed.token;
            uint256 totalUsers = seed.users.length;
            require(totalUsers == seed.lastWithdrawIds.length, "ArrayLengthMismatch");
            for(uint256 j=0; j<totalUsers; ++j) {
                lastWithdrawStakeId[token][seed.users[j]] = seed.lastWithdrawIds[j];
            }
        }
    }


    struct NewUserLockedRewardsSeed {
        address token; // token address
        address[] users; // Array of user addresses.
        uint256[] lockedRewards; // Array of new locked rewards amounts.
    }

    /**
     * @notice Function for seeding data of mapping: newUserLockedRewards
     * @param _newUserLockedRewardsSeed Array of data to seed as per struct NewUserLockedRewardsSeed.
     */
    function seedNewUserLockedRewardsData(
        NewUserLockedRewardsSeed[] calldata _newUserLockedRewardsSeed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalTokens = _newUserLockedRewardsSeed.length;
        for(uint256 i=0; i<totalTokens; ++i) {
            NewUserLockedRewardsSeed calldata seed = _newUserLockedRewardsSeed[i];
            address token = seed.token;
            uint256 totalUsers = seed.users.length;
            require(totalUsers == seed.lockedRewards.length, "ArrayLengthMismatch");
            for(uint256 j=0; j<totalUsers; ++j) {
                newUserLockedRewards[token][seed.users[j]] = seed.lockedRewards[j];
            }
        }
    }


    struct PoolStakersSeed {
        address token; // token address
        address[] users; // Array of user addresses
        PoolStaker[] poolStakerData; // Array of PoolStaker data
    }

    /**
     * @notice Function for seeding data of mapping: poolStakers
     * @param _poolStakersSeed Array of data to seed as per struct PoolStakersSeed.
     */
    function seedPoolStakersData(
        PoolStakersSeed[] calldata _poolStakersSeed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalTokens = _poolStakersSeed.length;
        for(uint256 i=0; i<totalTokens; ++i) {
            PoolStakersSeed calldata seed = _poolStakersSeed[i];
            address token = seed.token;
            uint256 totalUsers = seed.users.length;
            require(totalUsers == seed.poolStakerData.length, "ArrayLengthMismatch");
            for(uint256 j=0; j<totalUsers; ++j) {
                PoolStaker calldata psCalldata = seed.poolStakerData[j];
                PoolStaker storage psStorage = poolStakers[token][seed.users[j]];
                psStorage.amount = psCalldata.amount;
                psStorage.stakedTime = psCalldata.stakedTime;
                psStorage.lastUpdatedBlock = psCalldata.lastUpdatedBlock;
                psStorage.rewardDebt = psCalldata.rewardDebt;
                psStorage.rewardClaimed = psCalldata.rewardClaimed;
            }
        }
    }


    struct UserStakeDetailsSeed {
        address user; // user address
        StakeDetails[] stakes; // Array of user's stakes
    }

    struct UserTokenStakeDetailsSeed {
        address token; // token address
        UserStakeDetailsSeed[] users; // Array of user' details for token stakes
    }

    /**
     * @notice Function for seeding data of mapping: userTokenStakeDetails
     * @param _userTokenStakeDetailsSeed Array of data to seed as per struct UserTokenStakeDetailsSeed.
     */
    function seedUserTokenStakeDetailsData(
        UserTokenStakeDetailsSeed[] calldata _userTokenStakeDetailsSeed
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalTokens = _userTokenStakeDetailsSeed.length;
        for(uint256 i=0; i<totalTokens; ++i) {
            UserTokenStakeDetailsSeed calldata seed = _userTokenStakeDetailsSeed[i];
            address token = seed.token;
            uint256 users = seed.users.length;
            for(uint256 j=0; j<users; ++j) {
                UserStakeDetailsSeed calldata userDetails = seed.users[j];
                uint256 userTotalStakes = userDetails.stakes.length;
                for(uint256 k=0; k<userTotalStakes; ++k) {
                    StakeDetails calldata stakeCalldata = userDetails.stakes[k];
                    StakeDetails storage stakeStorage = userTokenStakeDetails[token][userDetails.user][stakeCalldata.stakeId];
                    stakeStorage.stakeId = stakeCalldata.stakeId;
                    stakeStorage.amount = stakeCalldata.amount;
                    stakeStorage.stakedTime = stakeCalldata.stakedTime;
                    stakeStorage.claimed = stakeCalldata.claimed;
                }
            }
        }
    }    
    // ==================== SEEDING LOGIC END ====================


    /**
     * @notice Allows a user to stake tokens.
     * @param token The address of the token to stake.
     * @param amount The amount of tokens to stake.
     */
    function stake(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(
            !isBlacklisted[_msgSender()],
            "AllStarsStakingPool: Address is Blacklisted"
        );
        require(
            token != ZERO_ADDRESS,
            "AllStarsStakingPool: Token is zero address"
        );
        require(
            amount > 0,
            "AllStarsStakingPool: Stake amount must be greater than zero"
        );
        require(
            block.number < stakingEndBlock,
            "AllStarsStakingPool: Staking has ended"
        );
        require(
            tokenAllowedForStake(token),
            "AllStarsStakingPool: Token is not allowed"
        );
        require(
            starToken.balanceOf(_msgSender()) >= minimumStarsBalance,
            "AllStarsStakingPool: Insufficient $STARS token balance"
        );

        updateRewards(token, _msgSender());

        PoolStaker storage staker = poolStakers[token][_msgSender()];
        staker.amount += amount;
        staker.rewardDebt =
            (staker.amount * accumulatedRewardsPerShare[token]) /
            REWARDS_PRECISION;
        staker.stakedTime = block.timestamp;
        staker.lastUpdatedBlock = block.number;

        uint256 stakeId = ++userTokenStakeIdIndex[token][_msgSender()];
        userTokenStakeDetails[token][_msgSender()][stakeId] = StakeDetails({
            stakeId: stakeId,
            amount: amount,
            stakedTime: block.timestamp,
            claimed: false
        });

        tokensStaked[token] += amount;

        emit Deposit(token, _msgSender(), amount);
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
    }

    /**
     * @notice Allows a user to withdraw their staked tokens and rewards.
     * @param token The address of the token to withdraw.
     */
    function withdraw(address token) external nonReentrant whenNotPaused {
        require(
            token != ZERO_ADDRESS,
            "AllStarsStakingPool: Token is zero address"
        );
        require(
            tokenAllowedForStake(token),
            "AllStarsStakingPool: Token is not allowed"
        );

        PoolStaker memory staker = poolStakers[token][_msgSender()];
        uint256 amount = staker.amount;
        require(
            amount > 0,
            "AllStarsStakingPool: Withdraw amount cannot be zero"
        );

        uint256 rewardTokens = getRewards(token, _msgSender());
        updateRewards(token, _msgSender());

        uint256 stakeIndex = userTokenStakeIdIndex[token][_msgSender()] + 1;
        uint256 lastWithdrawId = ++lastWithdrawStakeId[token][_msgSender()];
        for (uint256 i = lastWithdrawId; i < stakeIndex; i++) {
            userTokenStakeDetails[token][_msgSender()][i].claimed = true;
        }

        tokensStaked[token] -= amount;
        delete poolStakers[token][_msgSender()];
        newUserLockedRewards[token][_msgSender()] = 0;

        emit Withdraw(token, _msgSender(), amount);
        if (amount > 0) IERC20(token).transfer(_msgSender(), amount);
        if (rewardTokens > 0) starToken.transfer(_msgSender(), rewardTokens);
    }

    /**
     * @notice Claims only the accumulated rewards without withdrawing staked tokens.
     * @param token The address of the token for which rewards are being claimed.
     */
    function claimRewards(address token) external nonReentrant whenNotPaused {
        require(
            token != ZERO_ADDRESS,
            "AllStarsStakingPool: Token is zero address"
        );
        require(
            tokenAllowedForStake(token),
            "AllStarsStakingPool: Token is not allowed"
        );

        PoolStaker storage staker = poolStakers[token][_msgSender()];
        require(
            staker.amount > 0,
            "AllStarsStakingPool: No staked tokens to claim rewards"
        );

        uint256 rewardTokens = getRewards(token, _msgSender());
        staker.rewardClaimed += rewardTokens;

        emit Withdraw(address(starToken), _msgSender(), rewardTokens);

        starToken.transfer(_msgSender(), rewardTokens);
    }

    /**
     * @notice Updates rewards for a user and token.
     * @param token The token address.
     * @param user The user's address.
     */
    function updateRewards(address token, address user) private {
        updatePoolRewards(token);
        PoolStaker storage staker = poolStakers[token][user];
        uint256 rewardsToUpdate = ((staker.amount *
            accumulatedRewardsPerShare[token]) / REWARDS_PRECISION) -
            staker.rewardDebt;
        if (rewardsToUpdate == 0) {
            return;
        }
        if (rewardsToUpdate > 0) {
            staker.rewardDebt =
                (staker.amount * accumulatedRewardsPerShare[token]) /
                REWARDS_PRECISION;
            newUserLockedRewards[token][user] += rewardsToUpdate;
        }
    }

    /**
     * @notice Updates rewards for the entire pool.
     * @param token The token address.
     */
    function updatePoolRewards(address token) private {
        if (tokensStaked[token] == 0) {
            lastRewardedBlock[token] = block.number;
            return;
        }
        uint256 blocksSinceLastReward = block.number > stakingEndBlock
            ? stakingEndBlock - lastRewardedBlock[token]
            : block.number - lastRewardedBlock[token];
        uint256 rewards = blocksSinceLastReward * rewardTokensPerBlock;
        accumulatedRewardsPerShare[token] +=
            (rewards * REWARDS_PRECISION) /
            tokensStaked[token];
        lastRewardedBlock[token] = block.number > stakingEndBlock
            ? stakingEndBlock
            : block.number;
    }

    /**
     * @notice Returns the total rewards for a user for a specific token.
     * @param token The token address.
     * @param user The user's address.
     * @return rewards The total rewards.
     */
    function getRewards(
        address token,
        address user
    ) public view returns (uint256) {
        require(
            token != ZERO_ADDRESS,
            "AllStarsStakingPool: Token is zero address"
        );
        require(
            tokenAllowedForStake(token),
            "AllStarsStakingPool: Token is not allowed"
        );
        if (tokensStaked[token] == 0) {
            return 0;
        }
        uint256 blocksSinceLastReward = block.number > stakingEndBlock
            ? stakingEndBlock - lastRewardedBlock[token]
            : block.number - lastRewardedBlock[token];
        uint256 rewards = blocksSinceLastReward * rewardTokensPerBlock;
        uint256 accCalc = accumulatedRewardsPerShare[token] +
            ((rewards * REWARDS_PRECISION) / tokensStaked[token]);
        PoolStaker memory staker = poolStakers[token][user];
        return
            ((staker.amount * accCalc) / REWARDS_PRECISION) +
            newUserLockedRewards[token][user] -
            staker.rewardDebt -
            staker.rewardClaimed;
    }

    /**
     * @notice Provides details for the user for stakes.
     * @param token The token address.
     * @param user The user's address.
     */
    function getUserDetailsForToken(
        address token,
        address user
    )
        external
        view
        returns (
            uint256 stakes,
            uint256 total,
            uint256 rewards,
            uint256 rewardPerBlock
        )
    {
        PoolStaker memory staker = poolStakers[token][user];
        stakes = staker.amount;
        total = tokensStaked[token];
        rewards = getRewards(token, user);
        rewardPerBlock = rewardTokensPerBlock;
    }

    /**
     * @notice Provides the staking history for a user for a specific token.
     * @param token The token address.
     * @param user The user's address.
     * @param stakeIndex The list of stake IDs to retrieve.
     * @return stakingHistory An array of StakeDetails containing the user's staking history.
     */
    function getStakingHistory(
        address token,
        address user,
        uint256[] memory stakeIndex
    ) external view returns (StakeDetails[] memory stakingHistory) {
        uint256 length = stakeIndex.length;
        stakingHistory = new StakeDetails[](length);
        for (uint256 index = 0; index < stakeIndex.length; index++) {
            uint256 stakeDetail = stakeIndex[index];
            stakingHistory[index] = userTokenStakeDetails[token][user][
                stakeDetail
            ];
        }
    }

    /**
     * @notice Updates the list of allowed tokens.
     * @param newAllowedTokens The new list of allowed tokens.
     */
    function updateAllowedTokens(
        address[] memory newAllowedTokens
    ) external onlyRole(ADMIN_ROLE) {
        require(
            newAllowedTokens.length > 0,
            "AllStarsStakingPool: No allowed tokens provided"
        );
        allowedTokenArray = newAllowedTokens;
        emit AllowedTokensUpdated(newAllowedTokens);
    }

    /**
     * @notice Returns whether the token is allowed in the game.
     * @param token The token address.
     */
    function tokenAllowedForStake(address token) internal view returns (bool) {
        uint256 allowedTokenLength = allowedTokenArray.length;
        for (uint8 index = 0; index < allowedTokenLength; index++) {
            if (allowedTokenArray[index] == token) return true;
        }
        return false;
    }

    /**
     * @notice Adds users to the blacklist.
     * @param usersToBlacklist The list of addresses to blacklist.
     */
    function blacklistUsers(
        address[] calldata usersToBlacklist
    ) external onlyRole(ADMIN_ROLE) {
        require(
            usersToBlacklist.length > 0,
            "AllStarsStakingPool: No address to blacklist"
        );
        for (uint256 i = 0; i < usersToBlacklist.length; i++) {
            isBlacklisted[usersToBlacklist[i]] = true;
        }
    }

    /**
     * @notice Removes users from the blacklist.
     * @param usersToRemove The list of addresses to remove from the blacklist.
     */
    function removeFromBlacklist(
        address[] calldata usersToRemove
    ) external onlyRole(ADMIN_ROLE) {
        require(
            usersToRemove.length > 0,
            "AllStarsStakingPool: No address to remove from blacklist"
        );
        for (uint256 i = 0; i < usersToRemove.length; i++) {
            isBlacklisted[usersToRemove[i]] = false;
        }
    }

    /**
     * @notice Changes the superAdmin to a new address.
     * @dev Only callable by the current superAdmin.
     * @param newSuperAdmin The address of the new superAdmin.
     */
    function changeSuperAdmin(address newSuperAdmin) external onlySuperAdmin {
        require(
            newSuperAdmin != ZERO_ADDRESS,
            "AllStarsStakingPool: New superAdmin is the zero address"
        );
        _grantRole(ADMIN_ROLE, newSuperAdmin);
        _revokeRole(ADMIN_ROLE, msg.sender);

        emit SuperAdminChanged(superAdmin, newSuperAdmin);
        superAdmin = newSuperAdmin;
    }

    /**
     * @notice Allows the superAdmin to withdraw STAR tokens from the contract.
     * @dev Ensures sufficient balance and prevents reentrancy.
     * @param amount The amount of STAR tokens to withdraw.
     */

    function withdrawStarTokens(
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(
            amount > 0,
            "AllStarsStakingPool: Amount must be greater than zero"
        );
        require(
            starToken.balanceOf(address(this)) >= amount,
            "AllStarsStakingPool: Insufficient STAR tokens"
        );
        emit StarTokensWithdrawn(superAdmin, amount);
        starToken.transfer(superAdmin, amount);
    }

    /**
     * @notice Returns the list of allowed tokens for staking.
     * @return The list of allowed tokens.
     */
    function stakingAllowedTokens() external view returns (address[] memory) {
        return allowedTokenArray;
    }

    /**
     * @notice Pauses the contract, preventing certain functions from being executed.
     * @dev Only callable by an ADMIN_ROLE holder.
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the contract, allowing all functions to be executed
     * @dev Only callable by an ADMIN_ROLE holder
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Function to set the minimum STARS balance
     * @dev Only callable by an ADMIN_ROLE holder
     * @param newMinimumStarsBalance The new minimum STARS balance required for staking.
     */
    function setMinimumStarsBalance(uint256 newMinimumStarsBalance) external onlyRole(ADMIN_ROLE) {
        require(
            newMinimumStarsBalance > 0,
            "AllStarsStakingPool: Minimum STARS balance must be greater than zero"
        );
        require(
            minimumStarsBalance != newMinimumStarsBalance,
            "AllStarsStakingPool: Minimum Stars balance same as previous"
        );
        minimumStarsBalance = newMinimumStarsBalance;
    }

    /**
     * @notice Function to update the user locked rewards
     * @dev Only callable by an ADMIN_ROLE holder
     */
    function updateUserLockedRewards(address[] memory token, address[] memory user, uint256[] memory lockedRewards) external onlyRole(ADMIN_ROLE) {
        require(
            (token.length == user.length) && (user.length == lockedRewards.length),
            "AllStarsStakingPool: Parameter length mismatch"
        );
        for (uint256 index = 0; index < token.length; index++) {
            newUserLockedRewards[token[index]][user[index]] += lockedRewards[index];
        }
    }

    /**
     * @notice Function to set the actual claimed rewards for user
     * @dev Only callable by an ADMIN_ROLE holder
     */
    function updateUserClaimedRewards(address[] memory token, address[] memory user, uint256[] memory alreadyClaimed) external onlyRole(ADMIN_ROLE) {
        require(
            (token.length == user.length) && (user.length == alreadyClaimed.length),
            "AllStarsStakingPool: Parameter length mismatch"
        );
        for (uint256 index = 0; index < token.length; index++) {
            PoolStaker storage staker = poolStakers[token[index]][user[index]];
            staker.rewardClaimed -= alreadyClaimed[index];
        }
    }
}
