// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

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
// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(account),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
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
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
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
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
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
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
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
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
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
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./extensions/IERC20MetadataUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
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
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

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
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
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
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
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
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/ERC20Pausable.sol)

pragma solidity ^0.8.0;

import "../ERC20Upgradeable.sol";
import "../../../security/PausableUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev ERC20 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 *
 * IMPORTANT: This contract does not include public pause and unpause functions. In
 * addition to inheriting this contract, you must define both functions, invoking the
 * {Pausable-_pause} and {Pausable-_unpause} internal functions, with appropriate
 * access control, e.g. using {AccessControl} or {Ownable}. Not doing so will
 * make the contract unpausable.
 */
abstract contract ERC20PausableUpgradeable is Initializable, ERC20Upgradeable, PausableUpgradeable {
    function __ERC20Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __ERC20Pausable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20Upgradeable token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && AddressUpgradeable.isContract(address(token));
    }
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
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

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
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMathUpgradeable {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";
import "./math/SignedMathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMathUpgradeable.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSetUpgradeable {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
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
pragma solidity 0.8.9;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {EnumerableSetUpgradeable as EnumerableSet} from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

import "../interfaces/IManageableVault.sol";
import "../interfaces/IMToken.sol";
import "../interfaces/IDataFeed.sol";

import "../access/Greenlistable.sol";
import "../access/Blacklistable.sol";
import "../abstract/WithSanctionsList.sol";

import "../libraries/DecimalsCorrectionLibrary.sol";
import "../access/Pausable.sol";

/**
 * @title ManageableVault
 * @author RedDuck Software
 * @notice Contract with base Vault methods
 */
abstract contract ManageableVault is
    Pausable,
    IManageableVault,
    Blacklistable,
    Greenlistable,
    WithSanctionsList
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using DecimalsCorrectionLibrary for uint256;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    /**
     * @notice address that represents off-chain USD bank transfer
     */
    address public constant MANUAL_FULLFILMENT_TOKEN = address(0x0);

    /**
     * @notice stable coin static rate 1:1 USD in 18 decimals
     */
    uint256 public constant STABLECOIN_RATE = 10**18;

    /**
     * @notice last request id
     */
    Counters.Counter public currentRequestId;

    /**
     * @notice 100 percent with base 100
     * @dev for example, 10% will be (10 * 100)%
     */
    uint256 public constant ONE_HUNDRED_PERCENT = 100 * 100;

    uint256 public constant MAX_UINT = type(uint256).max;

    /**
     * @notice mToken token
     */
    IMToken public mToken;

    /**
     * @notice mToken data feed contract
     */
    IDataFeed public mTokenDataFeed;

    /**
     * @notice address to which tokens and mTokens will be sent
     */
    address public tokensReceiver;

    /**
     * @dev fee for initial operations 1% = 100
     */
    uint256 public instantFee;

    /**
     * @dev daily limit for initial operations
     * if user exceed this limit he will need
     * to create requests
     */
    uint256 public instantDailyLimit;

    /**
     * @dev mapping days (number from 1970) to limit amount
     */
    mapping(uint256 => uint256) public dailyLimits;

    /**
     * @notice address to which fees will be sent
     */
    address public feeReceiver;

    /**
     * @notice variation tolerance of tokenOut rates for "safe" requests approve
     */
    uint256 public variationTolerance;

    /**
     * @notice address restriction with zero fees
     */
    mapping(address => bool) public waivedFeeRestriction;

    /**
     * @dev tokens that can be used as USD representation
     */
    EnumerableSet.AddressSet internal _paymentTokens;

    /**
     * @notice mapping, token address to token config
     */
    mapping(address => TokenConfig) public tokensConfig;

    /**
     * @notice basic min operations amount
     */
    uint256 public minAmount;

    /**
     * @notice mapping, user address => is free frmo min amounts
     */
    mapping(address => bool) public isFreeFromMinAmount;

    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @dev checks that msg.sender do have a vaultRole() role
     */
    modifier onlyVaultAdmin() {
        _onlyRole(vaultRole(), msg.sender);
        _;
    }

    /**
     * @dev upgradeable pattern contract`s initializer
     * @param _ac address of MidasAccessControll contract
     * @param _mTokenInitParams init params for mToken
     * @param _receiversInitParams init params for receivers
     * @param _instantInitParams init params for instant operations
     * @param _sanctionsList address of sanctionsList contract
     * @param _variationTolerance percent of prices diviation 1% = 100
     * @param _minAmount basic min amount for operations
     */
    // solhint-disable func-name-mixedcase
    function __ManageableVault_init(
        address _ac,
        MTokenInitParams calldata _mTokenInitParams,
        ReceiversInitParams calldata _receiversInitParams,
        InstantInitParams calldata _instantInitParams,
        address _sanctionsList,
        uint256 _variationTolerance,
        uint256 _minAmount
    ) internal onlyInitializing {
        _validateAddress(_mTokenInitParams.mToken, false);
        _validateAddress(_mTokenInitParams.mTokenDataFeed, false);
        _validateAddress(_receiversInitParams.tokensReceiver, true);
        _validateAddress(_receiversInitParams.feeReceiver, true);
        require(_instantInitParams.instantDailyLimit > 0, "zero limit");
        _validateFee(_variationTolerance, true);
        _validateFee(_instantInitParams.instantFee, false);

        mToken = IMToken(_mTokenInitParams.mToken);
        __Pausable_init(_ac);
        __Greenlistable_init_unchained();
        __Blacklistable_init_unchained();
        __WithSanctionsList_init_unchained(_sanctionsList);

        tokensReceiver = _receiversInitParams.tokensReceiver;
        feeReceiver = _receiversInitParams.feeReceiver;
        instantFee = _instantInitParams.instantFee;
        instantDailyLimit = _instantInitParams.instantDailyLimit;
        minAmount = _minAmount;
        variationTolerance = _variationTolerance;
        mTokenDataFeed = IDataFeed(_mTokenInitParams.mTokenDataFeed);
    }

    /**
     * @inheritdoc IManageableVault
     */
    function withdrawToken(
        address token,
        uint256 amount,
        address withdrawTo
    ) external onlyVaultAdmin {
        IERC20(token).safeTransfer(withdrawTo, amount);

        emit WithdrawToken(msg.sender, token, withdrawTo, amount);
    }

    /**
     * @inheritdoc IManageableVault
     */
    function addPaymentToken(
        address token,
        address dataFeed,
        uint256 tokenFee,
        uint256 allowance,
        bool stable
    ) external onlyVaultAdmin {
        require(_paymentTokens.add(token), "MV: already added");
        _validateAddress(dataFeed, false);
        _validateFee(tokenFee, false);

        tokensConfig[token] = TokenConfig({
            dataFeed: dataFeed,
            fee: tokenFee,
            allowance: allowance,
            stable: stable
        });
        emit AddPaymentToken(
            msg.sender,
            token,
            dataFeed,
            tokenFee,
            allowance,
            stable
        );
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts if token is not presented
     */
    function removePaymentToken(address token) external onlyVaultAdmin {
        require(_paymentTokens.remove(token), "MV: not exists");
        delete tokensConfig[token];
        emit RemovePaymentToken(token, msg.sender);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts if new allowance zero
     */
    function changeTokenAllowance(address token, uint256 allowance)
        external
        onlyVaultAdmin
    {
        if (token != MANUAL_FULLFILMENT_TOKEN) {
            _requireTokenExists(token);
        }

        require(allowance > 0, "MV: zero allowance");
        tokensConfig[token].allowance = allowance;
        emit ChangeTokenAllowance(token, msg.sender, allowance);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts if new fee > 100%
     */
    function changeTokenFee(address token, uint256 fee)
        external
        onlyVaultAdmin
    {
        _requireTokenExists(token);
        _validateFee(fee, false);

        tokensConfig[token].fee = fee;
        emit ChangeTokenFee(token, msg.sender, fee);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts if new tolerance zero
     */
    function setVariationTolerance(uint256 tolerance) external onlyVaultAdmin {
        _validateFee(tolerance, true);

        variationTolerance = tolerance;
        emit SetVariationTolerance(msg.sender, tolerance);
    }

    /**
     * @inheritdoc IManageableVault
     */
    function setMinAmount(uint256 newAmount) external onlyVaultAdmin {
        minAmount = newAmount;
        emit SetMinAmount(msg.sender, newAmount);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts if account is already added
     */
    function addWaivedFeeAccount(address account) external onlyVaultAdmin {
        require(!waivedFeeRestriction[account], "MV: already added");
        waivedFeeRestriction[account] = true;
        emit AddWaivedFeeAccount(account, msg.sender);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts if account is already removed
     */
    function removeWaivedFeeAccount(address account) external onlyVaultAdmin {
        require(waivedFeeRestriction[account], "MV: not found");
        waivedFeeRestriction[account] = false;
        emit RemoveWaivedFeeAccount(account, msg.sender);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts address zero or equal address(this)
     */
    function setFeeReceiver(address receiver) external onlyVaultAdmin {
        _validateAddress(receiver, true);

        feeReceiver = receiver;

        emit SetFeeReceiver(msg.sender, receiver);
    }

    /**
     * @inheritdoc IManageableVault
     * @dev reverts address zero or equal address(this)
     */
    function setTokensReceiver(address receiver) external onlyVaultAdmin {
        _validateAddress(receiver, true);

        tokensReceiver = receiver;

        emit SetTokensReceiver(msg.sender, receiver);
    }

    /**
     * @inheritdoc IManageableVault
     */
    function setInstantFee(uint256 newInstantFee) external onlyVaultAdmin {
        _validateFee(newInstantFee, false);

        instantFee = newInstantFee;
        emit SetInstantFee(msg.sender, newInstantFee);
    }

    /**
     * @inheritdoc IManageableVault
     */
    function setInstantDailyLimit(uint256 newInstantDailyLimit)
        external
        onlyVaultAdmin
    {
        require(newInstantDailyLimit > 0, "MV: limit zero");
        instantDailyLimit = newInstantDailyLimit;
        emit SetInstantDailyLimit(msg.sender, newInstantDailyLimit);
    }

    /**
     * @inheritdoc IManageableVault
     */
    function freeFromMinAmount(address user, bool enable)
        external
        onlyVaultAdmin
    {
        require(isFreeFromMinAmount[user] != enable, "DV: already free");

        isFreeFromMinAmount[user] = enable;

        emit FreeFromMinAmount(user, enable);
    }

    /**
     * @notice returns array of stablecoins supported by the vault
     * can be called only from permissioned actor.
     * @return paymentTokens array of payment tokens
     */
    function getPaymentTokens() external view returns (address[] memory) {
        return _paymentTokens.values();
    }

    /**
     * @notice AC role of vault administrator
     * @return role bytes32 role
     */
    function vaultRole() public view virtual returns (bytes32);

    /**
     * @inheritdoc WithSanctionsList
     */
    function sanctionsListAdminRole()
        public
        view
        virtual
        override
        returns (bytes32)
    {
        return vaultRole();
    }

    /**
     * @inheritdoc Pausable
     */
    function pauseAdminRole() public view override returns (bytes32) {
        return vaultRole();
    }

    /**
     * @dev do safeTransferFrom on a given token
     * and converts `amount` from base18
     * to amount with a correct precision. Sends tokens
     * from `msg.sender` to `tokensReceiver`
     * @param token address of token
     * @param to address of user
     * @param amount amount of `token` to transfer from `user` (decimals 18)
     * @param tokenDecimals token decimals
     */
    function _tokenTransferFromUser(
        address token,
        address to,
        uint256 amount,
        uint256 tokenDecimals
    ) internal returns (uint256 transferAmount) {
        transferAmount = amount.convertFromBase18(tokenDecimals);

        require(
            amount == transferAmount.convertToBase18(tokenDecimals),
            "MV: invalid rounding"
        );

        IERC20(token).safeTransferFrom(msg.sender, to, transferAmount);
    }

    /**
     * @dev do safeTransferFrom on a given token
     * and converts `amount` from base18
     * to amount with a correct precision.
     * @param token address of token
     * @param from address
     * @param to address
     * @param amount amount of `token` to transfer from `user`
     * @param tokenDecimals token decimals
     */
    function _tokenTransferFromTo(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 tokenDecimals
    ) internal {
        uint256 transferAmount = amount.convertFromBase18(tokenDecimals);

        require(
            amount == transferAmount.convertToBase18(tokenDecimals),
            "MV: invalid rounding"
        );

        IERC20(token).safeTransferFrom(from, to, transferAmount);
    }

    /**
     * @dev do safeTransfer on a given token
     * and converts `amount` from base18
     * to amount with a correct precision. Sends tokens
     * from `contract` to `user`
     * @param token address of token
     * @param to address of user
     * @param amount amount of `token` to transfer from `user` (decimals 18)
     * @param tokenDecimals token decimals
     */
    function _tokenTransferToUser(
        address token,
        address to,
        uint256 amount,
        uint256 tokenDecimals
    ) internal {
        uint256 transferAmount = amount.convertFromBase18(tokenDecimals);

        require(
            amount == transferAmount.convertToBase18(tokenDecimals),
            "MV: invalid rounding"
        );

        IERC20(token).safeTransfer(to, transferAmount);
    }

    /**
     * @dev retreives decimals of a given `token`
     * @param token address of token
     * @return decimals decinmals value of a given `token`
     */
    function _tokenDecimals(address token) internal view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }

    /**
     * @dev checks that `token` is presented in `_paymentTokens`
     * @param token address of token
     */
    function _requireTokenExists(address token) internal view virtual {
        require(_paymentTokens.contains(token), "MV: token not exists");
    }

    /**
     * @dev check if operation exceed daily limit and update limit data
     * @param amount operation amount (decimals 18)
     */
    function _requireAndUpdateLimit(uint256 amount) internal {
        uint256 currentDayNumber = block.timestamp / 1 days;
        uint256 nextLimitAmount = dailyLimits[currentDayNumber] + amount;

        require(nextLimitAmount <= instantDailyLimit, "MV: exceed limit");

        dailyLimits[currentDayNumber] = nextLimitAmount;
    }

    /**
     * @dev check if operation exceed token allowance and update allowance
     * @param token address of token
     * @param amount operation amount (decimals 18)
     */
    function _requireAndUpdateAllowance(address token, uint256 amount)
        internal
    {
        uint256 prevAllowance = tokensConfig[token].allowance;
        if (prevAllowance == MAX_UINT) return;

        require(prevAllowance >= amount, "MV: exceed allowance");

        tokensConfig[token].allowance -= amount;
    }

    /**
     * @dev returns calculated fee amount depends on parameters
     * if additionalFee not zero, token fee replaced with additionalFee
     * @param sender sender address
     * @param token token address
     * @param amount amount of token (decimals 18)
     * @param isInstant is instant operation
     * @param additionalFee fee for fiat operations
     * @return fee amount of input token
     */
    function _getFeeAmount(
        address sender,
        address token,
        uint256 amount,
        bool isInstant,
        uint256 additionalFee
    ) internal view returns (uint256) {
        if (waivedFeeRestriction[sender]) return 0;

        uint256 feePercent;
        if (additionalFee == 0) {
            TokenConfig storage tokenConfig = tokensConfig[token];
            feePercent = tokenConfig.fee;
        } else {
            feePercent = additionalFee;
        }

        if (isInstant) feePercent += instantFee;

        if (feePercent > ONE_HUNDRED_PERCENT) feePercent = ONE_HUNDRED_PERCENT;

        return (amount * feePercent) / ONE_HUNDRED_PERCENT;
    }

    /**
     * @dev check if prev and new prices diviation fit variationTolerance
     * @param prevPrice previous rate
     * @param newPrice new rate
     */
    function _requireVariationTolerance(uint256 prevPrice, uint256 newPrice)
        internal
        view
    {
        uint256 priceDif = newPrice >= prevPrice
            ? newPrice - prevPrice
            : prevPrice - newPrice;

        uint256 priceDifPercent = (priceDif * ONE_HUNDRED_PERCENT) / prevPrice;

        require(
            priceDifPercent <= variationTolerance,
            "MV: exceed price diviation"
        );
    }

    function _validateUserAccess(address user)
        internal
        view
        onlyGreenlisted(user)
        onlyNotBlacklisted(user)
        onlyNotSanctioned(user)
    {}

    /**
     * @dev convert value to inputted decimals precision
     * @param value value for format
     * @param decimals decimals
     * @return converted amount
     */
    function _truncate(uint256 value, uint256 decimals)
        internal
        pure
        returns (uint256)
    {
        return value.convertFromBase18(decimals).convertToBase18(decimals);
    }

    /**
     * @dev check if fee <= 100% and check > 0 if needs
     * @param fee fee value
     * @param checkMin if need to check minimum
     */
    function _validateFee(uint256 fee, bool checkMin) internal pure {
        require(fee <= ONE_HUNDRED_PERCENT, "fee > 100%");
        if (checkMin) require(fee > 0, "fee == 0");
    }

    /**
     * @dev check if address not zero and not address(this)
     * @param addr address to check
     * @param selfCheck check if address not address(this)
     */
    function _validateAddress(address addr, bool selfCheck) internal view {
        require(addr != address(0), "zero address");
        if (selfCheck) require(addr != address(this), "invalid address");
    }

    /**
     * @dev get token rate depends on data feed and stablecoin flag
     * @param dataFeed address of dataFeed from token config
     * @param stable is stablecoin
     */
    function _getTokenRate(address dataFeed, bool stable)
        internal
        view
        virtual
        returns (uint256)
    {
        // @dev if dataFeed returns rate, all peg checks passed
        uint256 rate = IDataFeed(dataFeed).getDataInBase18();

        if (stable) return STABLECOIN_RATE;

        return rate;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title MidasInitializable
 * @author RedDuck Software
 * @notice Base Initializable contract that implements constructor
 * that calls _disableInitializers() to prevent
 * initialization of implementation contract
 */
abstract contract MidasInitializable is Initializable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../interfaces/ISanctionsList.sol";
import "../access/WithMidasAccessControl.sol";
import "./MidasInitializable.sol";

/**
 * @title WithSanctionsList
 * @notice Base contract that uses sanctions oracle from
 * Chainalysis to check that user is not sanctioned
 * @author RedDuck Software
 */
abstract contract WithSanctionsList is WithMidasAccessControl {
    /**
     * @notice address of Chainalysis sanctions oracle
     */
    address public sanctionsList;

    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @param caller function caller (msg.sender)
     * @param newSanctionsList new address of `sanctionsList`
     */
    event SetSanctionsList(
        address indexed caller,
        address indexed newSanctionsList
    );

    /**
     * @dev checks that a given `user` is not sanctioned
     */
    modifier onlyNotSanctioned(address user) {
        address _sanctionsList = sanctionsList;
        if (_sanctionsList != address(0)) {
            require(
                !ISanctionsList(_sanctionsList).isSanctioned(user),
                "WSL: sanctioned"
            );
        }
        _;
    }

    /**
     * @dev upgradeable pattern contract`s initializer
     */
    // solhint-disable func-name-mixedcase
    function __WithSanctionsList_init(
        address _accesControl,
        address _sanctionsList
    ) internal onlyInitializing {
        __WithMidasAccessControl_init(_accesControl);
        __WithSanctionsList_init_unchained(_sanctionsList);
    }

    /**
     * @dev upgradeable pattern contract`s initializer unchained
     */
    // solhint-disable func-name-mixedcase
    function __WithSanctionsList_init_unchained(address _sanctionsList)
        internal
        onlyInitializing
    {
        sanctionsList = _sanctionsList;
    }

    /**
     * @notice updates `sanctionsList` address.
     * can be called only from permissioned actor that have
     * `sanctionsListAdminRole()` role
     * @param newSanctionsList new sanctions list address
     */
    function setSanctionsList(address newSanctionsList) external {
        _onlyRole(sanctionsListAdminRole(), msg.sender);

        sanctionsList = newSanctionsList;
        emit SetSanctionsList(msg.sender, newSanctionsList);
    }

    /**
     * @notice AC role of sanctions list admin
     * @dev address that have this role can use `setSanctionsList`
     * @return role bytes32 role
     */
    function sanctionsListAdminRole() public view virtual returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./WithMidasAccessControl.sol";

/**
 * @title Blacklistable
 * @notice Base contract that implements basic functions and modifiers
 * to work with blacklistable
 * @author RedDuck Software
 */
abstract contract Blacklistable is WithMidasAccessControl {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @dev checks that a given `account` doesnt
     * have BLACKLISTED_ROLE
     */
    modifier onlyNotBlacklisted(address account) {
        _onlyNotBlacklisted(account);
        _;
    }

    /**
     * @dev upgradeable pattern contract`s initializer
     * @param _accessControl MidasAccessControl contract address
     */
    // solhint-disable func-name-mixedcase
    function __Blacklistable_init(address _accessControl)
        internal
        onlyInitializing
    {
        __WithMidasAccessControl_init(_accessControl);
        __Blacklistable_init_unchained();
    }

    /**
     * @dev upgradeable pattern contract`s initializer unchained
     */
    // solhint-disable func-name-mixedcase
    function __Blacklistable_init_unchained() internal onlyInitializing {}

    /**
     * @dev checks that a given `account` doesnt
     * have BLACKLISTED_ROLE
     */
    function _onlyNotBlacklisted(address account)
        internal
        view
        onlyNotRole(BLACKLISTED_ROLE, account)
    {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./WithMidasAccessControl.sol";

/**
 * @title Greenlistable
 * @notice Base contract that implements basic functions and modifiers
 * to work with greenlistable
 * @author RedDuck Software
 */
abstract contract Greenlistable is WithMidasAccessControl {
    /**
     * @notice is greenlist enabled
     */
    bool public greenlistEnabled;

    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    event SetGreenlistEnable(address indexed sender, bool enable);

    /**
     * @dev checks that a given `account`
     * have `greenlistedRole()`
     */
    modifier onlyGreenlisted(address account) {
        if (greenlistEnabled) _onlyGreenlisted(account);
        _;
    }

    /**
     * @dev checks that a given `account`
     * have `greenlistedRole()`
     * do the check even if greenlist check is off
     */
    modifier onlyAlwaysGreenlisted(address account) {
        _onlyGreenlisted(account);
        _;
    }

    /**
     * @dev upgradeable pattern contract`s initializer
     * @param _accessControl MidasAccessControl contract address
     */
    // solhint-disable func-name-mixedcase
    function __Greenlistable_init(address _accessControl)
        internal
        onlyInitializing
    {
        __WithMidasAccessControl_init(_accessControl);
        __Greenlistable_init_unchained();
    }

    /**
     * @dev upgradeable pattern contract`s initializer unchained
     */
    // solhint-disable func-name-mixedcase
    function __Greenlistable_init_unchained() internal onlyInitializing {}

    /**
     * @notice enable or disable greenlist.
     * can be called only from permissioned actor.
     * @param enable enable
     */
    function setGreenlistEnable(bool enable) external {
        _onlyGreenlistToggler(msg.sender);
        require(greenlistEnabled != enable, "GL: same enable status");
        greenlistEnabled = enable;
        emit SetGreenlistEnable(msg.sender, enable);
    }

    /**
     * @notice AC role of a greenlist
     * @return role bytes32 role
     */
    function greenlistedRole() public view virtual returns (bytes32) {
        return GREENLISTED_ROLE;
    }

    /**
     * @notice AC role of a greenlist toggler
     * @return role bytes32 role
     */
    function greenlistTogglerRole() public view virtual returns (bytes32);

    /**
     * @dev checks that a given `account`
     * have a `greenlistedRole()`
     */
    function _onlyGreenlisted(address account)
        private
        view
        onlyRole(greenlistedRole(), account)
    {}

    /**
     * @dev checks that a given `account`
     * have a `greenlistTogglerRole()`
     */
    function _onlyGreenlistToggler(address account)
        internal
        view
        onlyRole(greenlistTogglerRole(), account)
    {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./MidasAccessControlRoles.sol";
import "../abstract/MidasInitializable.sol";

/**
 * @title MidasAccessControl
 * @notice Smart contract that stores all roles for Midas project
 * @author RedDuck Software
 */
contract MidasAccessControl is
    AccessControlUpgradeable,
    MidasInitializable,
    MidasAccessControlRoles
{
    /**
     * @notice upgradeable pattern contract`s initializer
     */
    function initialize() external initializer {
        __AccessControl_init();
        _setupRoles(msg.sender);
    }

    /**
     * @notice grant multiple roles to multiple users
     * in one transaction
     * @dev length`s of 2 arays should match
     * @param roles array of bytes32 roles
     * @param addresses array of user addresses
     */
    function grantRoleMult(bytes32[] memory roles, address[] memory addresses)
        external
    {
        require(roles.length == addresses.length, "MAC: mismatch arrays");

        for (uint256 i = 0; i < roles.length; i++) {
            _checkRole(getRoleAdmin(roles[i]), msg.sender);
            _grantRole(roles[i], addresses[i]);
        }
    }

    /**
     * @notice revoke multiple roles from multiple users
     * in one transaction
     * @dev length`s of 2 arays should match
     * @param roles array of bytes32 roles
     * @param addresses array of user addresses
     */
    function revokeRoleMult(bytes32[] memory roles, address[] memory addresses)
        external
    {
        require(roles.length == addresses.length, "MAC: mismatch arrays");
        for (uint256 i = 0; i < roles.length; i++) {
            _checkRole(getRoleAdmin(roles[i]), msg.sender);
            _revokeRole(roles[i], addresses[i]);
        }
    }

    //solhint-disable disable-next-line
    function renounceRole(bytes32, address) public pure override {
        revert("MAC: Forbidden");
    }

    /**
     * @dev setup roles during the contracts initialization
     */
    function _setupRoles(address admin) private {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        _setRoleAdmin(BLACKLISTED_ROLE, BLACKLIST_OPERATOR_ROLE);
        _setRoleAdmin(GREENLISTED_ROLE, GREENLIST_OPERATOR_ROLE);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title MidasAccessControlRoles
 * @notice Base contract that stores all roles descriptors
 * @author RedDuck Software
 */
abstract contract MidasAccessControlRoles {
    /**
     * @notice actor that can change green list statuses of addresses
     */
    bytes32 public constant GREENLIST_OPERATOR_ROLE =
        keccak256("GREENLIST_OPERATOR_ROLE");

    /**
     * @notice actor that can change black list statuses of addresses
     */
    bytes32 public constant BLACKLIST_OPERATOR_ROLE =
        keccak256("BLACKLIST_OPERATOR_ROLE");

    /**
     * @notice actor that is greenlisted
     */
    bytes32 public constant GREENLISTED_ROLE = keccak256("GREENLISTED_ROLE");

    /**
     * @notice actor that is blacklisted
     */
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../access/WithMidasAccessControl.sol";

/**
 * @title Pausable
 * @notice Base contract that implements basic functions and modifiers
 * with pause functionality
 * @author RedDuck Software
 */
abstract contract Pausable is WithMidasAccessControl, PausableUpgradeable {
    mapping(bytes4 => bool) public fnPaused;

    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @param caller caller address (msg.sender)
     * @param fn function id
     */
    event PauseFn(address indexed caller, bytes4 fn);

    /**
     * @param caller caller address (msg.sender)
     * @param fn function id
     */
    event UnpauseFn(address indexed caller, bytes4 fn);

    modifier whenFnNotPaused(bytes4 fn) {
        _requireNotPaused();
        require(!fnPaused[fn], "Pausable: fn paused");
        _;
    }
    /**
     * @dev checks that a given `account`
     * has a determinedPauseAdminRole
     */
    modifier onlyPauseAdmin() {
        _onlyRole(pauseAdminRole(), msg.sender);
        _;
    }

    /**
     * @dev upgradeable pattern contract`s initializer
     * @param _accessControl MidasAccessControl contract address
     */
    // solhint-disable-next-line func-name-mixedcase
    function __Pausable_init(address _accessControl) internal onlyInitializing {
        super.__Pausable_init();
        __WithMidasAccessControl_init(_accessControl);
    }

    function pause() external onlyPauseAdmin {
        _pause();
    }

    function unpause() external onlyPauseAdmin {
        _unpause();
    }

    /**
     * @dev pause specific function
     * @param fn function id
     */
    function pauseFn(bytes4 fn) external onlyPauseAdmin {
        require(!fnPaused[fn], "Pausable: fn paused");
        fnPaused[fn] = true;
        emit PauseFn(msg.sender, fn);
    }

    /**
     * @dev unpause specific function
     * @param fn function id
     */
    function unpauseFn(bytes4 fn) external onlyPauseAdmin {
        require(fnPaused[fn], "Pausable: fn unpaused");
        fnPaused[fn] = false;
        emit UnpauseFn(msg.sender, fn);
    }

    /**
     * @dev virtual function to determine pauseAdmin role
     */
    function pauseAdminRole() public view virtual returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./MidasAccessControl.sol";
import "../abstract/MidasInitializable.sol";

/**
 * @title WithMidasAccessControl
 * @notice Base contract that consumes MidasAccessControl
 * @author RedDuck Software
 */
abstract contract WithMidasAccessControl is
    MidasInitializable,
    MidasAccessControlRoles
{
    /**
     * @notice admin role
     */
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @notice MidasAccessControl contract address
     */
    MidasAccessControl public accessControl;

    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @dev checks that given `address` have `role`
     */
    modifier onlyRole(bytes32 role, address account) {
        _onlyRole(role, account);
        _;
    }

    /**
     * @dev checks that given `address` do not have `role`
     */
    modifier onlyNotRole(bytes32 role, address account) {
        _onlyNotRole(role, account);
        _;
    }

    /**
     * @dev upgradeable pattern contract`s initializer
     */
    // solhint-disable func-name-mixedcase
    function __WithMidasAccessControl_init(address _accessControl)
        internal
        onlyInitializing
    {
        require(_accessControl != address(0), "zero address");
        accessControl = MidasAccessControl(_accessControl);
    }

    /**
     * @dev checks that given `address` have `role`
     */
    function _onlyRole(bytes32 role, address account) internal view {
        require(accessControl.hasRole(role, account), "WMAC: hasnt role");
    }

    /**
     * @dev checks that given `address` do not have `role`
     */
    function _onlyNotRole(bytes32 role, address account) internal view {
        require(!accessControl.hasRole(role, account), "WMAC: has role");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";

import "./interfaces/IDepositVault.sol";
import "./interfaces/IDataFeed.sol";

import "./abstract/ManageableVault.sol";

/**
 * @title DepositVault
 * @notice Smart contract that handles mToken minting
 * @author RedDuck Software
 */
contract DepositVault is ManageableVault, IDepositVault {
    using Counters for Counters.Counter;

    /**
     * @notice return data of _calcAndValidateDeposit
     * packed into a struct to avoid stack too deep errors
     */
    struct CalcAndValidateDepositResult {
        /// @notice tokenIn amount converted to USD
        uint256 tokenAmountInUsd;
        /// @notice fee amount in tokenIn
        uint256 feeTokenAmount;
        /// @notice tokenIn amount without fee
        uint256 amountTokenWithoutFee;
        /// @notice mToken amount for mint
        uint256 mintAmount;
        /// @notice tokenIn rate
        uint256 tokenInRate;
        /// @notice mToken rate
        uint256 tokenOutRate;
        /// @notice tokenIn decimals
        uint256 tokenDecimals;
    }

    /**
     * @dev default role that grants admin rights to the contract
     */
    bytes32 private constant _DEFAULT_DEPOSIT_VAULT_ADMIN_ROLE =
        keccak256("DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @dev selector for deposit instant
     */
    bytes4 private constant _DEPOSIT_INSTANT_SELECTOR =
        bytes4(keccak256("depositInstant(address,uint256,uint256,bytes32)"));

    /**
     * @dev selector for deposit instant with custom recipient
     */
    bytes4 private constant _DEPOSIT_INSTANT_WITH_CUSTOM_RECIPIENT_SELECTOR =
        bytes4(
            keccak256("depositInstant(address,uint256,uint256,bytes32,address)")
        );

    /**
     * @dev selector for deposit request
     */
    bytes4 private constant _DEPOSIT_REQUEST_SELECTOR =
        bytes4(keccak256("depositRequest(address,uint256,bytes32)"));

    /**
     * @dev selector for deposit request with custom recipient
     */
    bytes4 private constant _DEPOSIT_REQUEST_WITH_CUSTOM_RECIPIENT_SELECTOR =
        bytes4(keccak256("depositRequest(address,uint256,bytes32,address)"));

    /**
     * @notice minimal USD amount for first user`s deposit
     */
    uint256 public minMTokenAmountForFirstDeposit;

    /**
     * @notice mapping, requestId => request data
     */
    mapping(uint256 => Request) public mintRequests;

    /**
     * @dev depositor address => amount minted
     */
    mapping(address => uint256) public totalMinted;

    /**
     * @notice max supply cap value in mToken
     * @dev if after the deposit, mToken.totalSupply() > maxSupplyCap,
     * the tx will be reverted
     */
    uint256 public maxSupplyCap;

    /**
     * @dev leaving a storage gap for futures updates
     *
     * used slots:
     * 50 - `maxSupplyCap`
     */
    uint256[49] private __gap;

    /**
     * @notice upgradeable pattern contract`s initializer
     * @dev Calls all versioned initializers (V1, V2, ...) in chronological order.
     * This ensures that every deployment, whether fresh or upgraded, ends up
     * initialized to the latest contract state without breaking the
     * initializer/reinitializer versioning rules.
     * @param _ac address of MidasAccessControll contract
     * @param _mTokenInitParams init params for mToken
     * @param _receiversInitParams init params for receivers
     * @param _instantInitParams init params for instant operations
     * @param _sanctionsList address of sanctionsList contract
     * @param _variationTolerance percent of prices diviation 1% = 100
     * @param _minAmount basic min amount for operations in mToken
     * @param _minMTokenAmountForFirstDeposit min amount for first deposit in mToken
     * @param _maxSupplyCap max supply cap for mToken
     */
    function initialize(
        address _ac,
        MTokenInitParams calldata _mTokenInitParams,
        ReceiversInitParams calldata _receiversInitParams,
        InstantInitParams calldata _instantInitParams,
        address _sanctionsList,
        uint256 _variationTolerance,
        uint256 _minAmount,
        uint256 _minMTokenAmountForFirstDeposit,
        uint256 _maxSupplyCap
    ) public {
        initializeV1(
            _ac,
            _mTokenInitParams,
            _receiversInitParams,
            _instantInitParams,
            _sanctionsList,
            _variationTolerance,
            _minAmount,
            _minMTokenAmountForFirstDeposit
        );

        initializeV2(_maxSupplyCap);
    }

    /**
     * @notice v1 initializer
     * @param _ac address of MidasAccessControll contract
     * @param _mTokenInitParams init params for mToken
     * @param _receiversInitParams init params for receivers
     * @param _instantInitParams init params for instant operations
     * @param _sanctionsList address of sanctionsList contract
     * @param _variationTolerance percent of prices diviation 1% = 100
     * @param _minAmount basic min amount for operations in mToken
     * @param _minMTokenAmountForFirstDeposit min amount for first deposit in mToken
     */
    function initializeV1(
        address _ac,
        MTokenInitParams calldata _mTokenInitParams,
        ReceiversInitParams calldata _receiversInitParams,
        InstantInitParams calldata _instantInitParams,
        address _sanctionsList,
        uint256 _variationTolerance,
        uint256 _minAmount,
        uint256 _minMTokenAmountForFirstDeposit
    ) public initializer {
        __ManageableVault_init(
            _ac,
            _mTokenInitParams,
            _receiversInitParams,
            _instantInitParams,
            _sanctionsList,
            _variationTolerance,
            _minAmount
        );
        minMTokenAmountForFirstDeposit = _minMTokenAmountForFirstDeposit;
    }

    /**
     * @notice v2 initializer
     * @param _maxSupplyCap max supply cap for mToken
     */
    function initializeV2(uint256 _maxSupplyCap) public reinitializer(2) {
        maxSupplyCap = _maxSupplyCap;
    }

    /**
     * @inheritdoc IDepositVault
     */
    function depositInstant(
        address tokenIn,
        uint256 amountToken,
        uint256 minReceiveAmount,
        bytes32 referrerId
    ) external whenFnNotPaused(_DEPOSIT_INSTANT_SELECTOR) {
        _validateUserAccess(msg.sender);

        CalcAndValidateDepositResult memory result = _depositInstant(
            tokenIn,
            amountToken,
            minReceiveAmount,
            msg.sender
        );

        emit DepositInstant(
            msg.sender,
            tokenIn,
            result.tokenAmountInUsd,
            amountToken,
            result.feeTokenAmount,
            result.mintAmount,
            referrerId
        );
    }

    /**
     * @inheritdoc IDepositVault
     */
    function depositInstant(
        address tokenIn,
        uint256 amountToken,
        uint256 minReceiveAmount,
        bytes32 referrerId,
        address recipient
    )
        external
        whenFnNotPaused(_DEPOSIT_INSTANT_WITH_CUSTOM_RECIPIENT_SELECTOR)
    {
        _validateUserAccess(msg.sender);

        if (recipient != msg.sender) {
            _validateUserAccess(recipient);
        }

        CalcAndValidateDepositResult memory result = _depositInstant(
            tokenIn,
            amountToken,
            minReceiveAmount,
            recipient
        );

        emit DepositInstantWithCustomRecipient(
            msg.sender,
            tokenIn,
            recipient,
            result.tokenAmountInUsd,
            amountToken,
            result.feeTokenAmount,
            result.mintAmount,
            referrerId
        );
    }

    /**
     * @inheritdoc IDepositVault
     */
    function depositRequest(
        address tokenIn,
        uint256 amountToken,
        bytes32 referrerId
    )
        external
        whenFnNotPaused(_DEPOSIT_REQUEST_SELECTOR)
        returns (
            uint256 /*requestId*/
        )
    {
        _validateUserAccess(msg.sender);

        (
            uint256 requestId,
            CalcAndValidateDepositResult memory calcResult
        ) = _depositRequest(tokenIn, amountToken, msg.sender);

        emit DepositRequest(
            requestId,
            msg.sender,
            tokenIn,
            amountToken,
            calcResult.tokenAmountInUsd,
            calcResult.feeTokenAmount,
            calcResult.tokenOutRate,
            referrerId
        );

        return requestId;
    }

    /**
     * @inheritdoc IDepositVault
     */
    function depositRequest(
        address tokenIn,
        uint256 amountToken,
        bytes32 referrerId,
        address recipient
    )
        external
        whenFnNotPaused(_DEPOSIT_REQUEST_WITH_CUSTOM_RECIPIENT_SELECTOR)
        returns (
            uint256 /*requestId*/
        )
    {
        _validateUserAccess(msg.sender);

        if (recipient != msg.sender) {
            _validateUserAccess(recipient);
        }

        (
            uint256 requestId,
            CalcAndValidateDepositResult memory calcResult
        ) = _depositRequest(tokenIn, amountToken, recipient);

        bytes32 referrerIdCopy = referrerId;

        emit DepositRequestWithCustomRecipient(
            requestId,
            msg.sender,
            tokenIn,
            recipient,
            amountToken,
            calcResult.tokenAmountInUsd,
            calcResult.feeTokenAmount,
            calcResult.tokenOutRate,
            referrerIdCopy
        );

        return requestId;
    }

    /**
     * @inheritdoc IDepositVault
     */
    function safeBulkApproveRequestAtSavedRate(uint256[] calldata requestIds)
        external
        onlyVaultAdmin
    {
        for (uint256 i = 0; i < requestIds.length; i++) {
            uint256 rate = mintRequests[requestIds[i]].tokenOutRate;
            bool success = _approveRequest(requestIds[i], rate, true, false);

            if (!success) {
                continue;
            }

            emit SafeApproveRequest(requestIds[i], rate);
        }
    }

    /**
     * @inheritdoc IDepositVault
     */
    function safeBulkApproveRequest(uint256[] calldata requestIds) external {
        uint256 currentMTokenRate = _getMTokenRate();
        safeBulkApproveRequest(requestIds, currentMTokenRate);
    }

    /**
     * @inheritdoc IDepositVault
     */
    function safeApproveRequest(uint256 requestId, uint256 newOutRate)
        external
        onlyVaultAdmin
    {
        _approveRequest(requestId, newOutRate, true, true);

        emit SafeApproveRequest(requestId, newOutRate);
    }

    /**
     * @inheritdoc IDepositVault
     */
    function approveRequest(uint256 requestId, uint256 newOutRate)
        external
        onlyVaultAdmin
    {
        _approveRequest(requestId, newOutRate, false, true);

        emit ApproveRequest(requestId, newOutRate);
    }

    /**
     * @inheritdoc IDepositVault
     */
    function rejectRequest(uint256 requestId) external onlyVaultAdmin {
        Request memory request = mintRequests[requestId];

        require(request.sender != address(0), "DV: request not exist");
        require(
            request.status == RequestStatus.Pending,
            "DV: request not pending"
        );

        mintRequests[requestId].status = RequestStatus.Canceled;

        emit RejectRequest(requestId, request.sender);
    }

    /**
     * @inheritdoc IDepositVault
     */
    function setMinMTokenAmountForFirstDeposit(uint256 newValue)
        external
        onlyVaultAdmin
    {
        minMTokenAmountForFirstDeposit = newValue;

        emit SetMinMTokenAmountForFirstDeposit(msg.sender, newValue);
    }

    /**
     * @inheritdoc IDepositVault
     */
    function setMaxSupplyCap(uint256 newValue) external onlyVaultAdmin {
        maxSupplyCap = newValue;

        emit SetMaxSupplyCap(msg.sender, newValue);
    }

    /**
     * @inheritdoc IDepositVault
     */
    function safeBulkApproveRequest(
        uint256[] calldata requestIds,
        uint256 newOutRate
    ) public onlyVaultAdmin {
        for (uint256 i = 0; i < requestIds.length; i++) {
            bool success = _approveRequest(
                requestIds[i],
                newOutRate,
                true,
                false
            );

            if (!success) {
                continue;
            }

            emit SafeApproveRequest(requestIds[i], newOutRate);
        }
    }

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure virtual override returns (bytes32) {
        return _DEFAULT_DEPOSIT_VAULT_ADMIN_ROLE;
    }

    /**
     * @inheritdoc Greenlistable
     */
    function greenlistTogglerRole()
        public
        view
        virtual
        override
        returns (bytes32)
    {
        return vaultRole();
    }

    /**
     * @dev internal deposit instant logic
     * @param tokenIn tokenIn address
     * @param amountToken amount of tokenIn (decimals 18)
     * @param minReceiveAmount min amount of mToken to receive (decimals 18)
     * @param recipient recipient address
     *
     * @return result calculated deposit result
     */
    function _depositInstant(
        address tokenIn,
        uint256 amountToken,
        uint256 minReceiveAmount,
        address recipient
    ) internal virtual returns (CalcAndValidateDepositResult memory result) {
        address user = msg.sender;

        result = _calcAndValidateDeposit(user, tokenIn, amountToken, true);

        require(
            result.mintAmount >= minReceiveAmount,
            "DV: minReceiveAmount > actual"
        );

        totalMinted[user] += result.mintAmount;

        _requireAndUpdateLimit(result.mintAmount);

        _instantTransferTokensToTokensReceiver(
            tokenIn,
            result.amountTokenWithoutFee,
            result.tokenDecimals
        );

        if (result.feeTokenAmount > 0)
            _tokenTransferFromUser(
                tokenIn,
                feeReceiver,
                result.feeTokenAmount,
                result.tokenDecimals
            );

        mToken.mint(recipient, result.mintAmount);

        _validateMaxSupplyCap(true);
    }

    /**
     * @dev internal deposit request logic
     * @param tokenIn tokenIn address
     * @param amountToken amount of tokenIn (decimals 18)
     * @param recipient recipient address
     *
     * @return requestId request id
     * @return calcResult calculated deposit result
     */
    function _depositRequest(
        address tokenIn,
        uint256 amountToken,
        address recipient
    )
        private
        returns (
            uint256 requestId,
            CalcAndValidateDepositResult memory calcResult
        )
    {
        address user = msg.sender;

        requestId = currentRequestId.current();
        currentRequestId.increment();

        calcResult = _calcAndValidateDeposit(user, tokenIn, amountToken, false);

        _tokenTransferFromUser(
            tokenIn,
            tokensReceiver,
            calcResult.amountTokenWithoutFee,
            calcResult.tokenDecimals
        );

        if (calcResult.feeTokenAmount > 0)
            _tokenTransferFromUser(
                tokenIn,
                feeReceiver,
                calcResult.feeTokenAmount,
                calcResult.tokenDecimals
            );

        mintRequests[requestId] = Request({
            sender: recipient,
            tokenIn: tokenIn,
            status: RequestStatus.Pending,
            depositedUsdAmount: calcResult.tokenAmountInUsd,
            usdAmountWithoutFees: (calcResult.amountTokenWithoutFee *
                calcResult.tokenInRate) / 10**18,
            tokenOutRate: calcResult.tokenOutRate
        });
    }

    /**
     * @dev approving request
     * Checks price diviation if safe
     * Mints mTokens to user
     * @param requestId request id
     * @param newOutRate mToken rate
     */
    function _approveRequest(
        uint256 requestId,
        uint256 newOutRate,
        bool isSafe,
        bool revertAboveSupplyCap
    )
        private
        returns (
            bool /* success */
        )
    {
        Request memory request = mintRequests[requestId];

        require(request.sender != address(0), "DV: request not exist");
        require(
            request.status == RequestStatus.Pending,
            "DV: request not pending"
        );

        if (isSafe)
            _requireVariationTolerance(request.tokenOutRate, newOutRate);

        uint256 amountMToken = (request.usdAmountWithoutFees * (10**18)) /
            newOutRate;

        if (!_validateMaxSupplyCap(amountMToken, revertAboveSupplyCap)) {
            return false;
        }

        mToken.mint(request.sender, amountMToken);

        totalMinted[request.sender] += amountMToken;

        request.status = RequestStatus.Processed;
        request.tokenOutRate = newOutRate;
        mintRequests[requestId] = request;

        return true;
    }

    /**
     * @dev internal transfer tokens to tokens receiver
     * @param tokenIn tokenIn address
     * @param amountToken amount of tokenIn (decimals 18)
     * @param tokensDecimals tokens decimals
     */
    function _instantTransferTokensToTokensReceiver(
        address tokenIn,
        uint256 amountToken,
        uint256 tokensDecimals
    ) internal virtual {
        _tokenTransferFromUser(
            tokenIn,
            tokensReceiver,
            amountToken,
            tokensDecimals
        );
    }

    /**
     * @dev validate deposit and calculate mint amount
     * @param user user address
     * @param tokenIn tokenIn address
     * @param amountToken tokenIn amount (decimals 18)
     * @param isInstant is instant operation
     *
     * @return result calculated deposit result
     */
    function _calcAndValidateDeposit(
        address user,
        address tokenIn,
        uint256 amountToken,
        bool isInstant
    ) internal returns (CalcAndValidateDepositResult memory result) {
        require(amountToken > 0, "DV: invalid amount");

        result.tokenDecimals = _tokenDecimals(tokenIn);

        _requireTokenExists(tokenIn);

        (uint256 amountInUsd, uint256 tokenInUSDRate) = _convertTokenToUsd(
            tokenIn,
            amountToken
        );
        result.tokenAmountInUsd = amountInUsd;
        result.tokenInRate = tokenInUSDRate;
        address userCopy = user;

        _requireAndUpdateAllowance(tokenIn, amountToken);

        result.feeTokenAmount = _truncate(
            _getFeeAmount(userCopy, tokenIn, amountToken, isInstant, 0),
            result.tokenDecimals
        );
        result.amountTokenWithoutFee = amountToken - result.feeTokenAmount;

        uint256 feeInUsd = (result.feeTokenAmount * result.tokenInRate) /
            10**18;

        (uint256 mTokenAmount, uint256 mTokenRate) = _convertUsdToMToken(
            result.tokenAmountInUsd - feeInUsd
        );
        result.mintAmount = mTokenAmount;
        result.tokenOutRate = mTokenRate;

        if (!isFreeFromMinAmount[userCopy]) {
            _validateMinAmount(userCopy, result.mintAmount);
        }
        require(result.mintAmount > 0, "DV: invalid mint amount");
    }

    /**
     * @dev validates that inputted USD amount >= minAmountToDepositInUsd()
     * and amount >= minAmount()
     * @param user user address
     * @param amountMTokenWithoutFee amount of mToken without fee (decimals 18)
     */
    function _validateMinAmount(address user, uint256 amountMTokenWithoutFee)
        internal
        view
    {
        require(amountMTokenWithoutFee >= minAmount, "DV: mToken amount < min");

        if (totalMinted[user] != 0) return;

        require(
            amountMTokenWithoutFee >= minMTokenAmountForFirstDeposit,
            "DV: mint amount < min"
        );
    }

    /**
     * @dev validates that mToken.totalSupply() <= maxSupplyCap
     *
     * @param revertOnError if true, will revert if supply is exceeded
     * if false, will return false if supply is exceeded without reverting
     *
     * @return true if supply is valid, false otherwise
     */
    function _validateMaxSupplyCap(bool revertOnError)
        internal
        view
        returns (bool)
    {
        return _validateMaxSupplyCap(0, revertOnError);
    }

    /**
     * @dev validates that mToken.totalSupply() <= maxSupplyCap
     *
     * @param mintAmount amount of mToken to mint
     * @param revertOnError if true, will revert if supply is exceeded
     * if false, will return false if supply is exceeded without reverting
     *
     * @return true if supply is valid, false otherwise
     */
    function _validateMaxSupplyCap(uint256 mintAmount, bool revertOnError)
        internal
        view
        returns (bool)
    {
        bool isExceeded = mToken.totalSupply() + mintAmount > maxSupplyCap;

        if (!revertOnError) {
            return !isExceeded;
        }

        require(!isExceeded, "DV: max supply cap exceeded");

        return true;
    }

    /**
     * @dev calculates USD amount from tokenIn amount
     * @param tokenIn tokenIn address
     * @param amount amount of tokenIn (decimals 18)
     *
     * @return amountInUsd converted amount to USD
     * @return rate conversion rate
     */
    function _convertTokenToUsd(address tokenIn, uint256 amount)
        internal
        view
        virtual
        returns (uint256 amountInUsd, uint256 rate)
    {
        require(amount > 0, "DV: amount zero");

        TokenConfig storage tokenConfig = tokensConfig[tokenIn];

        rate = _getTokenRate(tokenConfig.dataFeed, tokenConfig.stable);
        require(rate > 0, "DV: rate zero");

        amountInUsd = (amount * rate) / (10**18);
    }

    /**
     * @dev calculates mToken amount from USD amount
     * @param amountUsd amount of USD (decimals 18)
     *
     * @return amountMToken converted USD to mToken
     * @return mTokenRate conversion rate
     */
    function _convertUsdToMToken(uint256 amountUsd)
        internal
        view
        virtual
        returns (uint256 amountMToken, uint256 mTokenRate)
    {
        mTokenRate = _getMTokenRate();

        amountMToken = (amountUsd * (10**18)) / mTokenRate;
    }

    /**
     * @dev gets and validates mToken rate
     * @return mTokenRate mToken rate
     */
    function _getMTokenRate() private view returns (uint256 mTokenRate) {
        mTokenRate = _getTokenRate(address(mTokenDataFeed), false);
        require(mTokenRate > 0, "DV: rate zero");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../access/WithMidasAccessControl.sol";
import "../libraries/DecimalsCorrectionLibrary.sol";

/**
 * @title IDataFeed
 * @author RedDuck Software
 */
interface IDataFeed {
    /**
     * @notice fetches answer from aggregator
     * and converts it to the base18 precision
     * @return answer fetched aggregator answer
     */
    function getDataInBase18() external view returns (uint256 answer);

    /**
     * @dev describes a role, owner of which can manage this feed
     * @return role descriptor
     */
    function feedAdminRole() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./IManageableVault.sol";

/**
 * @notice Mint request scruct
 * @param sender user address who create
 * @param tokenIn tokenIn address
 * @param status request status
 * @param depositedUsdAmount amout USD, tokenIn -> USD
 * @param usdAmountWithoutFees amout USD, tokenIn - fees -> USD
 * @param tokenOutRate rate of mToken at request creation time
 */
struct Request {
    address sender;
    address tokenIn;
    RequestStatus status;
    uint256 depositedUsdAmount;
    uint256 usdAmountWithoutFees;
    uint256 tokenOutRate;
}

/**
 * @title IDepositVault
 * @author RedDuck Software
 */
interface IDepositVault is IManageableVault {
    /**
     * @param caller function caller (msg.sender)
     * @param newValue new min amount to deposit value
     */
    event SetMinMTokenAmountForFirstDeposit(
        address indexed caller,
        uint256 newValue
    );

    /**
     * @param caller function caller (msg.sender)
     * @param newValue new max supply cap value
     */
    event SetMaxSupplyCap(address indexed caller, uint256 newValue);

    /**
     * @param user function caller (msg.sender)
     * @param tokenIn address of tokenIn
     * @param amountUsd amount of tokenIn converted to USD
     * @param amountToken amount of tokenIn
     * @param fee fee amount in tokenIn
     * @param minted amount of minted mTokens
     * @param referrerId referrer id
     */
    event DepositInstant(
        address indexed user,
        address indexed tokenIn,
        uint256 amountUsd,
        uint256 amountToken,
        uint256 fee,
        uint256 minted,
        bytes32 referrerId
    );

    /**
     * @param user function caller (msg.sender)
     * @param tokenIn address of tokenIn
     * @param recipient address that receives the mTokens
     * @param amountUsd amount of tokenIn converted to USD
     * @param amountToken amount of tokenIn
     * @param fee fee amount in tokenIn
     * @param minted amount of minted mTokens
     * @param referrerId referrer id
     */
    event DepositInstantWithCustomRecipient(
        address indexed user,
        address indexed tokenIn,
        address recipient,
        uint256 amountUsd,
        uint256 amountToken,
        uint256 fee,
        uint256 minted,
        bytes32 referrerId
    );

    /**
     * @param requestId mint request id
     * @param user function caller (msg.sender)
     * @param tokenIn address of tokenIn
     * @param amountToken amount of tokenIn
     * @param amountUsd amount of tokenIn converted to USD
     * @param fee fee amount in tokenIn
     * @param tokenOutRate mToken rate
     * @param referrerId referrer id
     */
    event DepositRequest(
        uint256 indexed requestId,
        address indexed user,
        address indexed tokenIn,
        uint256 amountToken,
        uint256 amountUsd,
        uint256 fee,
        uint256 tokenOutRate,
        bytes32 referrerId
    );

    /**
     * @param requestId mint request id
     * @param user function caller (msg.sender)
     * @param recipient address that receives the mTokens
     * @param tokenIn address of tokenIn
     * @param amountToken amount of tokenIn
     * @param amountUsd amount of tokenIn converted to USD
     * @param fee fee amount in tokenIn
     * @param tokenOutRate mToken rate
     * @param referrerId referrer id
     */
    event DepositRequestWithCustomRecipient(
        uint256 indexed requestId,
        address indexed user,
        address indexed tokenIn,
        address recipient,
        uint256 amountToken,
        uint256 amountUsd,
        uint256 fee,
        uint256 tokenOutRate,
        bytes32 referrerId
    );

    /**
     * @param requestId mint request id
     * @param newOutRate mToken rate inputted by admin
     */
    event ApproveRequest(uint256 indexed requestId, uint256 newOutRate);

    /**
     * @param requestId mint request id
     * @param newOutRate mToken rate inputted by admin
     */
    event SafeApproveRequest(uint256 indexed requestId, uint256 newOutRate);

    /**
     * @param requestId mint request id
     * @param user address of user
     */
    event RejectRequest(uint256 indexed requestId, address indexed user);

    /**
     * @param user address that was freed from min deposit check
     */
    event FreeFromMinDeposit(address indexed user);

    /**
     * @notice depositing proccess with auto mint if
     * account fit daily limit and token allowance.
     * Transfers token from the user.
     * Transfers fee in tokenIn to feeReceiver.
     * Mints mToken to user.
     * @param tokenIn address of tokenIn
     * @param amountToken amount of `tokenIn` that will be taken from user (decimals 18)
     * @param minReceiveAmount minimum expected amount of mToken to receive (decimals 18)
     * @param referrerId referrer id
     */
    function depositInstant(
        address tokenIn,
        uint256 amountToken,
        uint256 minReceiveAmount,
        bytes32 referrerId
    ) external;

    /**
     * @notice Does the same as original `depositInstant` but allows specifying a custom tokensReceiver address.
     * @param tokenIn address of tokenIn
     * @param amountToken amount of `tokenIn` that will be taken from user (decimals 18)
     * @param minReceiveAmount minimum expected amount of mToken to receive (decimals 18)
     * @param referrerId referrer id
     * @param tokensReceiver address to receive the tokens (instead of msg.sender)
     */
    function depositInstant(
        address tokenIn,
        uint256 amountToken,
        uint256 minReceiveAmount,
        bytes32 referrerId,
        address tokensReceiver
    ) external;

    /**
     * @notice depositing proccess with mint request creating if
     * account fit token allowance.
     * Transfers token from the user.
     * Transfers fee in tokenIn to feeReceiver.
     * Creates mint request.
     * @param tokenIn address of tokenIn
     * @param amountToken amount of `tokenIn` that will be taken from user (decimals 18)
     * @param referrerId referrer id
     * @return request id
     */
    function depositRequest(
        address tokenIn,
        uint256 amountToken,
        bytes32 referrerId
    ) external returns (uint256);

    /**
     * @notice Does the same as original `depositRequest` but allows specifying a custom tokensReceiver address.
     * @param tokenIn address of tokenIn
     * @param amountToken amount of `tokenIn` that will be taken from user (decimals 18)
     * @param referrerId referrer id
     * @param recipient address that receives the mTokens
     * @return request id
     */
    function depositRequest(
        address tokenIn,
        uint256 amountToken,
        bytes32 referrerId,
        address recipient
    ) external returns (uint256);

    /**
     * @notice approving requests from the `requestIds` array
     * with the mToken rate from the request.
     * Does same validation as `safeApproveRequest`.
     * Mints mToken to request users.
     * Sets request flags to Processed.
     * @param requestIds request ids array
     */
    function safeBulkApproveRequestAtSavedRate(uint256[] calldata requestIds)
        external;

    /**
     * @notice approving requests from the `requestIds` array
     * with the current mToken rate.
     * Does same validation as `safeApproveRequest`.
     * Mints mToken to request users.
     * Sets request flags to Processed.
     * @param requestIds request ids array
     */
    function safeBulkApproveRequest(uint256[] calldata requestIds) external;

    /**
     * @notice approving requests from the `requestIds` array using the `newOutRate`.
     * Does same validation as `safeApproveRequest`.
     * Mints mToken to request users.
     * Sets request flags to Processed.
     * @param requestIds request ids array
     * @param newOutRate new mToken rate inputted by vault admin
     */
    function safeBulkApproveRequest(
        uint256[] calldata requestIds,
        uint256 newOutRate
    ) external;

    /**
     * @notice approving request if inputted token rate fit price deviation percent
     * Mints mToken to user.
     * Sets request flag to Processed.
     * @param requestId request id
     * @param newOutRate mToken rate inputted by vault admin
     */
    function safeApproveRequest(uint256 requestId, uint256 newOutRate) external;

    /**
     * @notice approving request without price deviation check
     * Mints mToken to user.
     * Sets request flag to Processed.
     * @param requestId request id
     * @param newOutRate mToken rate inputted by vault admin
     */
    function approveRequest(uint256 requestId, uint256 newOutRate) external;

    /**
     * @notice rejecting request
     * Sets request flag to Canceled.
     * @param requestId request id
     */
    function rejectRequest(uint256 requestId) external;

    /**
     * @notice sets new minimal amount to deposit in EUR.
     * can be called only from vault`s admin
     * @param newValue new min. deposit value
     */
    function setMinMTokenAmountForFirstDeposit(uint256 newValue) external;

    /**
     * @notice sets new max supply cap value
     * can be called only from vault`s admin
     * @param newValue new max supply cap value
     */
    function setMaxSupplyCap(uint256 newValue) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./IMToken.sol";
import "./IDataFeed.sol";

/**
 * @param dataFeed data feed token/USD address
 * @param fee fee by token, 1% = 100
 * @param allowance token allowance (decimals 18)
 */
struct TokenConfig {
    address dataFeed;
    uint256 fee;
    uint256 allowance;
    bool stable;
}

enum RequestStatus {
    Pending,
    Processed,
    Canceled
}

struct MTokenInitParams {
    address mToken;
    address mTokenDataFeed;
}
struct ReceiversInitParams {
    address tokensReceiver;
    address feeReceiver;
}
struct InstantInitParams {
    uint256 instantFee;
    uint256 instantDailyLimit;
}

/**
 * @title IManageableVault
 * @author RedDuck Software
 */
interface IManageableVault {
    /**
     * @param caller function caller (msg.sender)
     * @param token token that was withdrawn
     * @param withdrawTo address to which tokens were withdrawn
     * @param amount `token` transfer amount
     */
    event WithdrawToken(
        address indexed caller,
        address indexed token,
        address indexed withdrawTo,
        uint256 amount
    );

    /**
     * @param caller function caller (msg.sender)
     * @param token address of token that
     * @param dataFeed token dataFeed address
     * @param fee fee 1% = 100
     * @param allowance token allowance (decimals 18)
     * @param stable stablecoin flag
     */
    event AddPaymentToken(
        address indexed caller,
        address indexed token,
        address indexed dataFeed,
        uint256 fee,
        uint256 allowance,
        bool stable
    );

    /**
     * @param token address of token that
     * @param caller function caller (msg.sender)
     * @param allowance new allowance
     */
    event ChangeTokenAllowance(
        address indexed token,
        address indexed caller,
        uint256 allowance
    );

    /**
     * @param token address of token that
     * @param caller function caller (msg.sender)
     * @param fee new fee
     */
    event ChangeTokenFee(
        address indexed token,
        address indexed caller,
        uint256 fee
    );

    /**
     * @param token address of token that
     * @param caller function caller (msg.sender)
     */
    event RemovePaymentToken(address indexed token, address indexed caller);

    /**
     * @param account address of account
     * @param caller function caller (msg.sender)
     */
    event AddWaivedFeeAccount(address indexed account, address indexed caller);

    /**
     * @param account address of account
     * @param caller function caller (msg.sender)
     */
    event RemoveWaivedFeeAccount(
        address indexed account,
        address indexed caller
    );

    /**
     * @param caller function caller (msg.sender)
     * @param newFee new operation fee value
     */
    event SetInstantFee(address indexed caller, uint256 newFee);

    /**
     * @param caller function caller (msg.sender)
     * @param newAmount new min amount for operation
     */
    event SetMinAmount(address indexed caller, uint256 newAmount);

    /**
     * @param caller function caller (msg.sender)
     * @param newLimit new operation daily limit
     */
    event SetInstantDailyLimit(address indexed caller, uint256 newLimit);

    /**
     * @param caller function caller (msg.sender)
     * @param newTolerance percent of price diviation 1% = 100
     */
    event SetVariationTolerance(address indexed caller, uint256 newTolerance);

    /**
     * @param caller function caller (msg.sender)
     * @param reciever new reciever address
     */
    event SetFeeReceiver(address indexed caller, address indexed reciever);

    /**
     * @param caller function caller (msg.sender)
     * @param reciever new reciever address
     */
    event SetTokensReceiver(address indexed caller, address indexed reciever);

    /**
     * @param user user address
     * @param enable is enabled
     */
    event FreeFromMinAmount(address indexed user, bool enable);

    /**
     * @notice The mTokenDataFeed contract address.
     * @return The address of the mTokenDataFeed contract.
     */
    function mTokenDataFeed() external view returns (IDataFeed);

    /**
     * @notice The mToken contract address.
     * @return The address of the mToken contract.
     */
    function mToken() external view returns (IMToken);

    /**
     * @notice withdraws `amount` of a given `token` from the contract.
     * can be called only from permissioned actor.
     * @param token token address
     * @param amount token amount
     * @param withdrawTo withdraw destination address
     */
    function withdrawToken(
        address token,
        uint256 amount,
        address withdrawTo
    ) external;

    /**
     * @notice adds a token to the stablecoins list.
     * can be called only from permissioned actor.
     * @param token token address
     * @param dataFeed dataFeed address
     * @param fee 1% = 100
     * @param allowance token allowance (decimals 18)
     * @param stable is stablecoin flag
     */
    function addPaymentToken(
        address token,
        address dataFeed,
        uint256 fee,
        uint256 allowance,
        bool stable
    ) external;

    /**
     * @notice removes a token from stablecoins list.
     * can be called only from permissioned actor.
     * @param token token address
     */
    function removePaymentToken(address token) external;

    /**
     * @notice set new token allowance.
     * if MAX_UINT = infinite allowance
     * prev allowance rewrites by new
     * can be called only from permissioned actor.
     * @param token token address
     * @param allowance new allowance (decimals 18)
     */
    function changeTokenAllowance(address token, uint256 allowance) external;

    /**
     * @notice set new token fee.
     * can be called only from permissioned actor.
     * @param token token address
     * @param fee new fee percent 1% = 100
     */
    function changeTokenFee(address token, uint256 fee) external;

    /**
     * @notice set new prices diviation percent.
     * can be called only from permissioned actor.
     * @param tolerance new prices diviation percent 1% = 100
     */
    function setVariationTolerance(uint256 tolerance) external;

    /**
     * @notice set new min amount.
     * can be called only from permissioned actor.
     * @param newAmount min amount for operations in mToken
     */
    function setMinAmount(uint256 newAmount) external;

    /**
     * @notice adds a account to waived fee restriction.
     * can be called only from permissioned actor.
     * @param account user address
     */
    function addWaivedFeeAccount(address account) external;

    /**
     * @notice removes a account from waived fee restriction.
     * can be called only from permissioned actor.
     * @param account user address
     */
    function removeWaivedFeeAccount(address account) external;

    /**
     * @notice set new reciever for fees.
     * can be called only from permissioned actor.
     * @param reciever new fee reciever address
     */
    function setFeeReceiver(address reciever) external;

    /**
     * @notice set new reciever for tokens.
     * can be called only from permissioned actor.
     * @param reciever new token reciever address
     */
    function setTokensReceiver(address reciever) external;

    /**
     * @notice set operation fee percent.
     * can be called only from permissioned actor.
     * @param newInstantFee new instant operations fee percent 1& = 100
     */
    function setInstantFee(uint256 newInstantFee) external;

    /**
     * @notice set operation daily limit.
     * can be called only from permissioned actor.
     * @param newInstantDailyLimit new operation daily limit (decimals 18)
     */
    function setInstantDailyLimit(uint256 newInstantDailyLimit) external;

    /**
     * @notice frees given `user` from the minimal deposit
     * amount validation in `initiateDepositRequest`
     * @param user address of user
     */
    function freeFromMinAmount(address user, bool enable) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title IMToken
 * @author RedDuck Software
 */
interface IMToken is IERC20Upgradeable {
    /**
     * @notice mints mToken token `amount` to a given `to` address.
     * should be called only from permissioned actor
     * @param to addres to mint tokens to
     * @param amount amount to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice burns mToken token `amount` to a given `to` address.
     * should be called only from permissioned actor
     * @param from addres to burn tokens from
     * @param amount amount to burn
     */
    function burn(address from, uint256 amount) external;

    /**
     * @notice updates contract`s metadata.
     * should be called only from permissioned actor
     * @param key metadata map. key
     * @param data metadata map. value
     */
    function setMetadata(bytes32 key, bytes memory data) external;

    /**
     * @notice puts mToken token on pause.
     * should be called only from permissioned actor
     */
    function pause() external;

    /**
     * @notice puts mToken token on pause.
     * should be called only from permissioned actor
     */
    function unpause() external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// TODO: add natspec
interface ISanctionsList {
    function isSanctioned(address addr) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @title DecimalsCorrectionLibrary
 * @author RedDuck Software
 */
library DecimalsCorrectionLibrary {
    /**
     * @dev converts `originalAmount` with `originalDecimals` into
     * amount with `decidedDecimals`
     * @param originalAmount amount to convert
     * @param originalDecimals decimals of the original amount
     * @param decidedDecimals decimals for the output amount
     * @return amount converted amount with `decidedDecimals`
     */
    function convert(
        uint256 originalAmount,
        uint256 originalDecimals,
        uint256 decidedDecimals
    ) internal pure returns (uint256) {
        if (originalAmount == 0) return 0;
        if (originalDecimals == decidedDecimals) return originalAmount;

        uint256 adjustedAmount;

        if (originalDecimals > decidedDecimals) {
            adjustedAmount =
                originalAmount /
                (10**(originalDecimals - decidedDecimals));
        } else {
            adjustedAmount =
                originalAmount *
                (10**(decidedDecimals - originalDecimals));
        }

        return adjustedAmount;
    }

    /**
     * @dev converts `originalAmount` with decimals 18 into
     * amount with `decidedDecimals`
     * @param originalAmount amount to convert
     * @param decidedDecimals decimals for the output amount
     * @return amount converted amount with `decidedDecimals`
     */
    function convertFromBase18(uint256 originalAmount, uint256 decidedDecimals)
        internal
        pure
        returns (uint256)
    {
        return convert(originalAmount, 18, decidedDecimals);
    }

    /**
     * @dev converts `originalAmount` with `originalDecimals` into
     * amount with decimals 18
     * @param originalAmount amount to convert
     * @param originalDecimals decimals of the original amount
     * @return amount converted amount with 18 decimals
     */
    function convertToBase18(uint256 originalAmount, uint256 originalDecimals)
        internal
        pure
        returns (uint256)
    {
        return convert(originalAmount, originalDecimals, 18);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../../DepositVault.sol";
import "./MEvUsdMidasAccessControlRoles.sol";

/**
 * @title MEvUsdDepositVault
 * @notice Smart contract that handles mEVUSD minting
 * @author RedDuck Software
 */
contract MEvUsdDepositVault is DepositVault, MEvUsdMidasAccessControlRoles {
    /**
     * @dev leaving a storage gap for futures updates
     */
    uint256[50] private __gap;

    /**
     * @inheritdoc ManageableVault
     */
    function vaultRole() public pure override returns (bytes32) {
        return M_EV_USD_DEPOSIT_VAULT_ADMIN_ROLE;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/**
 * @title MEvUsdMidasAccessControlRoles
 * @notice Base contract that stores all roles descriptors for mEVUSD contracts
 * @author RedDuck Software
 */
abstract contract MEvUsdMidasAccessControlRoles {
    /**
     * @notice actor that can manage MEvUsdDepositVault
     */
    bytes32 public constant M_EV_USD_DEPOSIT_VAULT_ADMIN_ROLE =
        keccak256("M_EV_USD_DEPOSIT_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage MEvUsdRedemptionVault
     */
    bytes32 public constant M_EV_USD_REDEMPTION_VAULT_ADMIN_ROLE =
        keccak256("M_EV_USD_REDEMPTION_VAULT_ADMIN_ROLE");

    /**
     * @notice actor that can manage MEvUsdCustomAggregatorFeed and MEvUsdDataFeed
     */
    bytes32 public constant M_EV_USD_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE =
        keccak256("M_EV_USD_CUSTOM_AGGREGATOR_FEED_ADMIN_ROLE");
}
