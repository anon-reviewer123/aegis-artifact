// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";
import {Context} from "../utils/Context.sol";
import {ERC165} from "../utils/introspection/ERC165.sol";

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
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
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
        return _roles[role].hasRole[account];
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
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
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
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
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
     *
     * CAUTION: See Security Considerations above.
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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC20Permit} from "../extensions/IERC20Permit.sol";
import {Address} from "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
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
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "./IERC165.sol";

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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
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
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

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

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
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

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
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
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
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
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

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
    bool private _paused;

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
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {TokenSaleRegistry} from "./TokenSaleRegistry.sol";

/**
 * @title Pre-sale Contract for SNOVA Tokens
 * @dev Manages the pre-sale phase of SNOVA tokens, incorporating price feeds for dynamic pricing and allowing for contributions
 * in the native currency and other stablecoins (USDT, USDC, DAI). This contract leverages the OpenZeppelin library for role management,
 * token safety, reentrancy checks, and operational controls (pause/unpause). It is closely tied to the TokenSaleRegistry, from which
 * it retrieves information about token sale rounds and referral incentives, ensuring consistent and secure transaction processing.
 *
 * Key functionalities include token purchasing, token and native currency recovery, and configuration of operational parameters.
 */
contract PresaleSNOVA is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    bytes32 public constant PURCHASE_AGENT_ROLE = keccak256("PURCHASE_AGENT_ROLE");
    address internal constant NATIVE_CURRENCY_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    struct Currency {
        AggregatorV3Interface priceFeed;
        uint256 decimals; // 18 or 6 depends on token and network
        bool useStaticPrice; // If true, use a static price of $1
        uint256 totalCollected; // Total collected amount of the currency
    }

    TokenSaleRegistry private _presaleStorage;
    mapping(address => Currency) private _currencies; // Mapping to store whitelisted currencies for purchase
    mapping(address => uint256) private _novaPoints; // Mapping to store Nova Points for each user
    mapping(address => uint256) private _referralCount; // Mapping to store referral count for each user
    mapping(address => bool) private _hasPurchased; // Mapping to track if a user has already made a purchase
    mapping(address => address) private _referrer; // Mapping to track referrer for each user
    uint256 private _priceThresholdSeconds;

    /**
     * @notice Emitted when the price threshold time is updated.
     * @param priceFeedTimeThreshold New threshold in seconds for price feed update times.
     */
    event PriceThresholdUpdated(uint256 priceFeedTimeThreshold);

    /**
     * @notice Emitted when native currency is retrieved from the contract.
     * @param amount The amount of native currency retrieved.
     */
    event NativeCurrencyRetrieved(uint256 amount);

    /**
     * @notice Emitted when ERC20 tokens are retrieved from the contract.
     * @param token The address of the ERC20 token retrieved.
     * @param amount The amount of tokens retrieved.
     */
    event TokensRetrieved(address token, uint256 amount);

    /**
     * @notice Emitted when tokens are purchased during the pre-sale.
     * @param user The address of the user who purchased the tokens.
     * @param ref The referral address provided.
     * @param amount The amount of native currency used for the purchase.
     * @param price The price of the token at the moment of purchase.
     * @param sold The number of tokens sold in the transaction.
     * @param round The current round of the sale during which the purchase was made.
     * @param investmentUSD The amount the user invested in USD.
     * @param currencyPrice The price of the currency during the purchase.
     * @param novaPoints The number of Nova Points awarded.
     */
    event TokensPurchased(
        address indexed user,
        address indexed ref,
        uint256 amount,
        uint256 price,
        uint256 sold,
        uint256 round,
        uint256 investmentUSD,
        int256 currencyPrice,
        uint256 novaPoints
    );

    /**
     * @notice Emitted when Nova Points are awarded to a user or referrer.
     * @param user The address of the user receiving the Nova Points.
     * @param points The number of Nova Points awarded.
     */
    event NovaPointsAwarded(address indexed user, uint256 points);

    /**
     * @notice Emitted when a referral is registered.
     * @param referrer The address of the referrer.
     */
    event ReferralRegistered(address indexed referrer);

    /**
     * @notice Thrown when trying to purchase with a currency that is not whitelisted.
     */
    error ErrCurrencyNotWhitelisted();

    /**
     * @notice Thrown when attempting an operation while the sale is not active.
     */
    error ErrSaleNotActive();

    /**
     * @notice Thrown when attempting to interact with a sale round that is closed.
     */
    error ErrRoundClosed();

    /**
     * @notice Thrown when a null address is provided where a valid address is required.
     */
    error ErrNullAddress();

    /**
     * @notice Thrown when an invalid decimals value is provided.
     */
    error ErrInvalidDecimals();

    /**
     * @notice Thrown when the `amount_` parameter is not 0 for native currency purchases.
     */
    error ErrAmountValidation();

    /**
     * @notice Thrown when `msg.value` is not 0 for ERC20 token purchases.
     */
    error ErrValueValidation();

    /**
     * @notice Thrown when the price threshold is set to an invalid value.
     */
    error ErrInvalidPriceThreshold();

    /**
     * @notice Thrown when the presale price is invalid (e.g., zero).
     */
    error ErrInvalidPrice();

    /**
     * @notice Thrown when an allocation error occurs in a sale round due to supply limits.
     */
    error ErrRoundAllocation();

    /**
     * @notice Thrown when the price feed update is beyond the acceptable time threshold.
     */
    error ErrPriceThreshold();

    /**
     * @notice Thrown when a user address provided is a null address.
     */
    error ErrUserNullAddress();

    /**
     * @notice Thrown when the native currency amount for a purchase is zero.
     */
    error ErrAmountZero();

    /**
     * @notice Thrown when an invalid referral is used.
     */
    error ErrReferral();

    /**
     * @notice Thrown when a transfer of funds fails.
     */
    error ErrTransferFailure();

    /**
     * @notice Thrown when the amount provided is below the minimum required.
     * @param amount_ The amount provided.
     * @param min_ The minimum required amount.
     */
    error ErrMin(uint256 amount_, uint256 min_);

    /**
     * @notice Thrown when the amount provided exceeds the maximum allowed.
     * @param amount_ The amount provided.
     * @param max_ The maximum allowed amount.
     */
    error ErrMax(uint256 amount_, uint256 max_);

    /**
     * @notice Initializes a new PresaleSNOVA contract with necessary configuration.
     * @dev Sets up roles, price feed interface, and initial thresholds.
     * Assigns the DEFAULT_ADMIN_ROLE to the deployer, ensuring control over critical functions.
     * @param storage_ Address of the TokenSaleRegistry, storing sale rounds and referral details.
     * @param priceThresholdSeconds_ Time threshold to validate the recency of price updates.
     */
    constructor(address payable storage_, uint256 priceThresholdSeconds_) {
        if (storage_ == address(0)) {
            revert ErrNullAddress();
        }
        if (priceThresholdSeconds_ == 0) {
            revert ErrInvalidPriceThreshold();
        }

        _presaleStorage = TokenSaleRegistry(storage_);
        _priceThresholdSeconds = priceThresholdSeconds_;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Adds a new currency and its associated price feed.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * Validates the `tokenAddress_` and `decimals_`.
     * @param tokenAddress_ The address of the ERC20 token.
     * @param priceFeed_ The address of the new price feed, or zero address for static price.
     * @param decimals_ The decimals used by the currency.
     * @param useStaticPrice_ If true, use a static price of $1 instead of a price feed.
     * Reverts with `ErrNullAddress` if `tokenAddress_` is zero.
     * Reverts with `ErrInvalidDecimals` if `decimals_` is zero or greater than 18.
     */
    function addCurrency(
        address tokenAddress_,
        address priceFeed_,
        uint256 decimals_,
        bool useStaticPrice_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tokenAddress_ == address(0)) {
            revert ErrNullAddress();
        }
        if (decimals_ == 0 || decimals_ > 18) {
            revert ErrInvalidDecimals();
        }
        _addCurrency(tokenAddress_, priceFeed_, decimals_, useStaticPrice_);
    }

    function _addCurrency(address tokenAddress_, address priceFeed_, uint256 decimals_, bool useStaticPrice_) internal {
        _currencies[tokenAddress_] = Currency(AggregatorV3Interface(priceFeed_), decimals_, useStaticPrice_, 0);
    }

    /**
     * @notice Pauses the contract, preventing operations like token purchase.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the contract, allowing operations like token purchase to resume.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Purchases tokens using the specified currency directly sent to the contract.
     * @dev Validates the `tokenAddress_` to ensure it is not the zero address unless it's the native currency address.
     * @param ref_ Optional referral address provided by the user to potentially earn referral bonuses.
     * @param tokenAddress_ The address of the ERC20 token used for purchase, or the native currency address.
     * @param amount_ The amount of currency to be used for purchase. For native currency, this should be 0 as `msg.value` is used.
     * @notice Reverts with `ErrNullAddress` if `tokenAddress_` is the zero address and not the native currency address.
     * Reverts if the currency is not whitelisted, the sale is not active, or the round is closed.
     */
    function purchaseTokens(address ref_, address tokenAddress_, uint256 amount_) external payable nonReentrant {
        if (tokenAddress_ == address(0)) {
            revert ErrNullAddress();
        }
        if (_currencies[tokenAddress_].decimals == 0) {
            revert ErrCurrencyNotWhitelisted();
        }
        if (tokenAddress_ == NATIVE_CURRENCY_ADDRESS) {
            if (amount_ != 0) {
                revert ErrAmountValidation();
            }
            _processPurchase(_msgSender(), ref_, tokenAddress_, msg.value, false);
        } else {
            if (msg.value != 0) {
                revert ErrValueValidation();
            }
            _processPurchase(_msgSender(), ref_, tokenAddress_, amount_, false);
        }
    }

    /**
     * @notice Enables a designated purchase agent to buy tokens on behalf of another user using the specified currency sent with the transaction.
     * This action must comply with the terms set for the current sale round in the TokenSaleRegistry.
     * @dev This function can be invoked by any user possessing the `PURCHASE_AGENT_ROLE` when the contract is not paused.
     * It is designed to facilitate purchases where the actual buyer cannot interact directly with the contract.
     * @param user_ The address of the user for whom the tokens are being purchased.
     * @param ref_ Optional referral address provided to potentially earn referral bonuses.
     * @param tokenAddress_ The address of the ERC20 token used for purchase, or zero address for native currency.
     * @param amount_ The amount of currency to be used for purchase. For native currency, this should be 0 as `msg.value` is used.
     * @notice Reverts if the currency is not whitelisted, the sale is not active, or the round is closed.
     */
    function purchaseTokensFor(
        address user_,
        address ref_,
        address tokenAddress_,
        uint256 amount_
    ) external payable onlyRole(PURCHASE_AGENT_ROLE) nonReentrant {
        if (_currencies[tokenAddress_].decimals == 0) {
            revert ErrCurrencyNotWhitelisted();
        }

        if (tokenAddress_ == NATIVE_CURRENCY_ADDRESS) {
            if (amount_ != 0) {
                revert ErrAmountValidation();
            }
            _processPurchase(user_, ref_, tokenAddress_, msg.value, true);
        } else {
            if (msg.value != 0) {
                revert ErrValueValidation();
            }
            _processPurchase(user_, ref_, tokenAddress_, amount_, true);
        }
    }

    /**
     * @notice Updates the time threshold for considering the price feed valid.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param priceThresholdSeconds_ The new time threshold in seconds.
     * Emits a {PriceThresholdUpdated} event on successful update.
     */
    function setPriceThreshold(uint256 priceThresholdSeconds_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (priceThresholdSeconds_ == 0) {
            revert ErrInvalidPriceThreshold();
        }
        _priceThresholdSeconds = priceThresholdSeconds_;
        emit PriceThresholdUpdated(priceThresholdSeconds_);
    }

    /**
     * @notice Retrieves native currency sent to the contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @notice Requires successful transfer to the caller.
     * Emits a {NativeCurrencyRetrieved} event on successful retrieval.
     */
    function retrieveNativeCurrency() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(_msgSender()), balance);
        emit NativeCurrencyRetrieved(balance);
    }

    /**
     * @notice Retrieves ERC20 tokens sent to the contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param token_ The address of the ERC20 token to retrieve.
     * @param amount_ The amount of tokens to retrieve.
     * Emits a {TokensRetrieved} event on successful retrieval.
     */
    function retrieveTokens(address token_, uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        IERC20(token_).safeTransfer(_msgSender(), amount_);
        emit TokensRetrieved(token_, amount_);
    }

    /**
     * @notice Retrieves the address of the token sale storage contract.
     * @dev Returns the current address stored in `_presaleStorage`.
     * @return address The address of the token sale registry.
     */
    function getStorage() external view returns (address) {
        return address(_presaleStorage);
    }

    /**
     * @notice Retrieves the address of the price feed contract used for pricing information.
     * @dev Returns the current address stored in `_currencies`.
     * @param tokenAddress_ The address of the ERC20 token used for price feed, or zero address for native currency.
     * @return address The address of the price feed contract.
     */
    function getPriceFeed(address tokenAddress_) external view returns (address) {
        return address(_currencies[tokenAddress_].priceFeed);
    }

    /**
     * @notice Returns the total amount of token or native currency collected through sales.
     * @dev Accesses the Currency from `_currencies` to provide the total collected funds.
     * @return uint256 The total amount of token or native currency collected.
     */
    function getTotalCollected(address tokenAddress_) external view returns (uint256) {
        Currency memory currency = _currencies[tokenAddress_];
        return currency.totalCollected;
    }

    /**
     * @notice Gets the current threshold for price updates, in seconds.
     * @dev Returns the time period in seconds that is considered acceptable for a price update delay.
     * @return uint256 The current price update threshold in seconds.
     */
    function getPriceThreshold() external view returns (uint256) {
        return _priceThresholdSeconds;
    }

    /**
     * @notice Returns the referral count for a user.
     * @param user_ The address of the user to retrieve the referral count for.
     * @return uint256 The referral count for the specified user.
     */
    function getReferralCount(address user_) external view returns (uint256) {
        return _referralCount[user_];
    }

    /**
     * @notice Returns the Nova Points balance for a user.
     * @param user_ The address of the user to retrieve the Nova Points balance for.
     * @return uint256 The Nova Points balance for the specified user.
     */
    function getNovaPoints(address user_) external view returns (uint256) {
        return _novaPoints[user_];
    }

    /**
     * @dev Internal function to handle the purchase of tokens during the pre-sale.
     * This function orchestrates several key operations:
     * - Validation of the input parameters and state conditions to ensure the purchase can proceed.
     * - Interaction with the TokenSaleRegistry to retrieve and validate the current sale round.
     * - Calculation of the number of tokens that can be bought based on the native currency provided and the current token price.
     * - Handling of referral rewards if a valid referral is provided.
     * - Transfer of funds to the treasury and issuance of tokens and referral rewards.
     * - Calculation and awarding of Nova Points to the user.
     * - Calculation and awarding of Nova Points to the referrer, if applicable.
     * Each step involves checks and balances to ensure transaction integrity and security.
     * @param user_ The address of the user who is making the purchase.
     * @param ref_ Optional referral address that may entitle the referrer to rewards, if applicable.
     * @param tokenAddress_ The address of the ERC20 token used for purchase, or zero address for native currency.
     * @param amount_ The amount of currency to be used for purchase.
     * @param max_ Indicates whether the transaction should respect the maximum limit for contributions.
     * @return uint256 The number of tokens that were sold to the user.
     * Emits a {TokensPurchased} event upon successful completion of the purchase.
     * Emits a {NovaPointsAwarded} event when Nova Points are awarded to the user and the referrer.
     * @notice Reverts if the contract is paused, `user_` is a null address, the amount is zero, the sale is not active,
     * the sale round is closed, or the funds transfer fails.
     */
    function _processPurchase(
        address user_,
        address ref_,
        address tokenAddress_,
        uint256 amount_,
        bool max_
    ) internal whenNotPaused returns (uint256) {
        _validatePurchaseParameters(user_, ref_, amount_);
        TokenSaleRegistry.Round memory round = _getAndValidateSaleRound();
        uint256 tokensToSell = _calculateTokensToSell(amount_, tokenAddress_, round);
        uint256 funds = _calculateFundsInUSD(tokenAddress_, amount_);
        _validateFundsAndLimits(user_, funds, max_);

        ref_ = _handleReferral(user_, ref_);

        Currency storage currency = _currencies[tokenAddress_];
        int256 currencyPrice = _getCurrencyPrice(currency);

        (address ref, uint256 coinFunds, uint256 tokenFunds) = _calculateReferralRewards(
            user_,
            ref_,
            amount_,
            tokenAddress_
        );
        _transferPurchaseFunds(tokenAddress_, amount_, coinFunds);

        _recordSale(user_, tokenAddress_, funds, tokensToSell, ref_, coinFunds, tokenFunds);
        uint256 novaPoints = _awardNovaPoints(user_, funds);

        _updateCurrencyCollectedAmount(currency, amount_);

        _emitTokensPurchased(user_, ref, amount_, tokensToSell, funds, currencyPrice, novaPoints);
        _handleReferrerRewards(user_, ref, novaPoints);

        return tokensToSell;
    }

    /**
     * @dev Validates the input parameters for the purchase.
     * @param user_ The address of the user who is making the purchase.
     * @param ref_ The referral address provided by the user.
     * @param amount_ The amount of currency to be used for purchase.
     * @notice Reverts if the user address is null, user address equals referral address,
     * the amount is zero, or the sale is not active.
     */
    function _validatePurchaseParameters(address user_, address ref_, uint256 amount_) internal view {
        if (user_ == address(0)) revert ErrUserNullAddress();
        if (user_ == ref_) revert ErrReferral();
        if (amount_ == 0) revert ErrAmountZero();
        if (!_presaleStorage.isActive()) revert ErrSaleNotActive();
    }

    /**
     * @dev Retrieves and validates the current sale round from the TokenSaleRegistry.
     * @return TokenSaleRegistry.Round memory The current sale round.
     * @notice Reverts if the sale round is not started.
     */
    function _getAndValidateSaleRound() internal view returns (TokenSaleRegistry.Round memory) {
        TokenSaleRegistry.Round memory round = _presaleStorage.getRound(_presaleStorage.getCurrentRound());
        if (round.state != TokenSaleRegistry.State.Started) revert ErrRoundClosed();
        return round;
    }

    /**
     * @dev Calculates the number of tokens to sell based on the provided amount and token address.
     * @param amount_ The amount of currency to be used for purchase.
     * @param tokenAddress_ The address of the ERC20 token used for purchase, or zero address for native currency.
     * @param round The current sale round information.
     * @return uint256 The number of tokens to sell.
     * @notice Reverts if the round allocation is insufficient.
     */
    function _calculateTokensToSell(
        uint256 amount_,
        address tokenAddress_,
        TokenSaleRegistry.Round memory round
    ) internal view returns (uint256) {
        uint256 tokensToSell = _calculateTokensSold(amount_, tokenAddress_);
        if (round.supply < round.sold + tokensToSell) revert ErrRoundAllocation();
        return tokensToSell;
    }

    /**
     * @dev Validates the provided funds against the minimum and maximum limits.
     * @param user_ The address of the user who is making the purchase.
     * @param funds The amount of funds calculated in USD.
     * @param max_ Indicates whether the transaction should respect the maximum limit for contributions.
     * @notice Reverts if the funds are below the minimum or above the user's limit.
     */
    function _validateFundsAndLimits(address user_, uint256 funds, bool max_) internal view {
        if (_presaleStorage.getMin() > funds) revert ErrMin(funds, _presaleStorage.getMin());
        uint256 limit = max_ ? _presaleStorage.maxLimitOf(user_) : _presaleStorage.limitOf(user_);
        if (limit < funds) revert ErrMax(funds, limit);
    }

    /**
     * @dev Handles the referral logic by checking and updating the referral information.
     * @param user_ The address of the user who is making the purchase.
     * @param ref_ The referral address provided by the user.
     * @return address The updated referral address.
     */
    function _handleReferral(address user_, address ref_) internal returns (address) {
        if (_hasPurchased[user_]) {
            ref_ = _referrer[user_];
        } else {
            _referrer[user_] = ref_;
        }
        return ref_;
    }

    /**
     * @dev Retrieves the current price of the currency.
     * @param currency The currency information.
     * @return int256 The current price of the currency.
     */
    function _getCurrencyPrice(Currency storage currency) internal view returns (int256) {
        return currency.useStaticPrice ? int256(1e8) : _getLatestPrice(currency.priceFeed);
    }

    /**
     * @dev Records the sale by processing and recording the sale details in the presale storage.
     * @param user_ The address of the user who is making the purchase.
     * @param tokenAddress_ The address of the ERC20 token used for purchase.
     * @param funds The amount of funds calculated in USD.
     * @param tokensToSell The number of tokens to be sold.
     * @param ref_ The referral address.
     * @param coinFunds The funds associated with the referral in coins.
     * @param tokenFunds The funds associated with the referral in tokens.
     */
    function _recordSale(
        address user_,
        address tokenAddress_,
        uint256 funds,
        uint256 tokensToSell,
        address ref_,
        uint256 coinFunds,
        uint256 tokenFunds
    ) internal {
        _presaleStorage.processAndRecordSale(user_, tokenAddress_, funds, tokensToSell, ref_, coinFunds, tokenFunds);
    }

    /**
     * @dev Awards Nova Points to the user based on the provided funds.
     * @param user_ The address of the user who is making the purchase.
     * @param funds The amount of funds calculated in USD.
     * @return uint256 The number of Nova Points awarded to the user.
     */
    function _awardNovaPoints(address user_, uint256 funds) internal returns (uint256) {
        uint256 novaPoints = _calculateNovaPoints(funds);
        _novaPoints[user_] += novaPoints;
        return novaPoints;
    }

    /**
     * @dev Updates the total collected amount for the given currency.
     * @param currency The currency information.
     * @param amount_ The amount to be added to the total collected amount.
     */
    function _updateCurrencyCollectedAmount(Currency storage currency, uint256 amount_) internal {
        currency.totalCollected += amount_;
    }

    /**
     * @dev Emits the TokensPurchased and NovaPointsAwarded events.
     * @param user_ The address of the user who is making the purchase.
     * @param ref The referral address.
     * @param amount_ The amount of currency used for purchase.
     * @param tokensToSell The number of tokens sold.
     * @param funds The amount of funds calculated in USD.
     * @param currencyPrice The current price of the currency.
     * @param novaPoints The number of Nova Points awarded to the user.
     */
    function _emitTokensPurchased(
        address user_,
        address ref,
        uint256 amount_,
        uint256 tokensToSell,
        uint256 funds,
        int256 currencyPrice,
        uint256 novaPoints
    ) internal {
        uint256 snovaPrice = _presaleStorage.getPrice();
        emit TokensPurchased(
            user_,
            ref,
            amount_,
            snovaPrice,
            tokensToSell,
            _presaleStorage.getCurrentRound(),
            funds,
            currencyPrice,
            novaPoints
        );
        emit NovaPointsAwarded(user_, novaPoints);
    }

    /**
     * @dev Handles the rewards for the referrer by awarding Nova Points and updating referral information.
     * @param user_ The address of the user who is making the purchase.
     * @param ref The referral address.
     * @param novaPoints The number of Nova Points awarded to the user.
     */
    function _handleReferrerRewards(address user_, address ref, uint256 novaPoints) internal {
        if (ref != address(0)) {
            uint256 referrerNovaPoints = (novaPoints * 20) / 100;
            _novaPoints[ref] += referrerNovaPoints;
            emit NovaPointsAwarded(ref, referrerNovaPoints);
            if (!_hasPurchased[user_]) {
                _hasPurchased[user_] = true;
                _referralCount[ref] += 1;
                emit ReferralRegistered(ref);
            }
        }
    }

    /**
     * @dev Retrieves the latest price from the price feed and ensures the data is recent and valid.
     * Adds a check to ensure the price is greater than zero.
     * @param priceFeed The price feed contract.
     * @return int256 The latest price.
     * @notice Reverts with `ErrPriceThreshold` if the price feed update is beyond the acceptable time threshold.
     * Reverts with `ErrInvalidPrice` if the price is zero or negative.
     */
    function _getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (int256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        if (block.timestamp - updatedAt > _priceThresholdSeconds) {
            revert ErrPriceThreshold();
        }
        if (price <= 0) {
            revert ErrInvalidPrice();
        }
        return price;
    }

    /**
     * @dev Converts a specified amount of tokens (native currency, USDT, USDC, or DAI) into its equivalent value in USD.
     * This conversion is based on the latest available price of the native currency in terms of USD.
     * @param tokenAddress_ The address of the ERC20 token used for purchase, or zero address for native currency.
     * @param amount_ The amount of tokens to be converted.
     * @return uint256 The equivalent amount in USD.
     */
    function _calculateFundsInUSD(address tokenAddress_, uint256 amount_) internal view returns (uint256) {
        Currency storage currency = _currencies[tokenAddress_];
        uint8 decimals = currency.useStaticPrice ? 8 : currency.priceFeed.decimals();
        int256 price = currency.useStaticPrice ? int256(1e8) : _getLatestPrice(currency.priceFeed);

        uint256 amountAdjusted = currency.decimals == 6 ? amount_ * 1e12 : amount_;

        return (amountAdjusted * uint256(price)) / (10 ** decimals);
    }

    /**
     * @dev Calculates the number of tokens that can be purchased with a given amount of currency.
     * Includes a check to prevent division by zero if the presale price is zero.
     * @param amount_ The amount of currency provided for the purchase.
     * @param tokenAddress_ The address of the ERC20 token used for purchase, or the native currency address.
     * @return uint256 The calculated number of tokens that can be bought with the specified amount of currency.
     * @notice Reverts with `ErrInvalidPrice` if the presale price is zero.
     */
    function _calculateTokensSold(uint256 amount_, address tokenAddress_) internal view returns (uint256) {
        Currency storage currency = _currencies[tokenAddress_];
        uint8 decimals = currency.useStaticPrice ? 8 : currency.priceFeed.decimals();
        int256 price = currency.useStaticPrice ? int256(1e8) : _getLatestPrice(currency.priceFeed);

        uint256 amountAdjusted = currency.decimals == 6 ? amount_ * 1e12 : amount_;
        uint256 presalePrice = _presaleStorage.getPrice();

        if (presalePrice == 0) {
            revert ErrInvalidPrice();
        }

        return (amountAdjusted * uint256(price) * 1e18) / (presalePrice * (10 ** decimals));
    }

    /**
     * @dev Calculates the referral rewards based on the purchase amount and the rates applicable to the referrer.
     * Handles different decimals for different tokens.
     * @param user_ The user who made the purchase.
     * @param ref_ The referral address.
     * @param amount_ The amount of currency used in the purchase.
     * @param tokenAddress_ The address of the ERC20 token used for purchase, or zero address for native currency.
     * @return address The effective referral address.
     * @return uint256 The amount of native currency as a referral reward.
     * @return uint256 The amount of tokens as a referral reward.
     */
    function _calculateReferralRewards(
        address user_,
        address ref_,
        uint256 amount_,
        address tokenAddress_
    ) internal view returns (address, uint256, uint256) {
        address ref = _presaleStorage.getRef(user_, ref_);
        if (ref == address(0)) {
            return (ref, 0, 0);
        }

        (uint256 fRate, uint256 sRate) = _presaleStorage.getRefRates(ref);

        uint256 coinFunds = (amount_ * fRate) / 1000;
        uint256 tokenFunds = (amount_ * sRate) / 1000;

        uint256 tokenSold = _calculateTokensSold(tokenFunds, tokenAddress_);

        return (ref, coinFunds, tokenSold);
    }

    /**
     * @dev Transfers the purchase funds and referral rewards to the appropriate recipients.
     *      Handles different decimal places for currencies and ensures precise calculations.
     * @param tokenAddress_ The address of the ERC20 token used for purchase, or zero address for native currency.
     * @param amount_ The total amount of the currency used for purchase.
     * @param reward_ The amount of the currency to be transferred as a referral reward.
     */
    function _transferPurchaseFunds(address tokenAddress_, uint256 amount_, uint256 reward_) internal {
        address treasury = _presaleStorage.getFundsWallet();

        if (tokenAddress_ != NATIVE_CURRENCY_ADDRESS) {
            IERC20(tokenAddress_).safeTransferFrom(_msgSender(), treasury, amount_ - reward_);

            if (reward_ > 0) {
                IERC20(tokenAddress_).safeTransferFrom(_msgSender(), address(_presaleStorage), reward_);
            }
        } else {
            Address.sendValue(payable(treasury), amount_ - reward_);

            if (reward_ > 0) {
                Address.sendValue(payable(address(_presaleStorage)), reward_);
            }
        }
    }

    /**
     * @notice Calculates the number of Nova Points awarded based on the investment amount in USD.
     * @dev The investment amount is in USD and the multipliers are predefined for different investment ranges.
     * @param investment_ The investment amount in USD (in 18 decimal places).
     * @return The number of Nova Points awarded.
     */
    function _calculateNovaPoints(uint256 investment_) internal pure returns (uint256) {
        uint256 multiplier = 0;
        if (investment_ >= 20000 * 1e18) {
            multiplier = 20;
        } else if (investment_ >= 15000 * 1e18) {
            multiplier = 16;
        } else if (investment_ >= 10000 * 1e18) {
            multiplier = 13;
        } else if (investment_ >= 5000 * 1e18) {
            multiplier = 10;
        } else if (investment_ >= 1000 * 1e18) {
            multiplier = 9;
        } else if (investment_ >= 500 * 1e18) {
            multiplier = 8;
        } else if (investment_ >= 250 * 1e18) {
            multiplier = 7;
        } else if (investment_ >= 50 * 1e18) {
            multiplier = 6;
        }

        return (investment_ * multiplier) / 1e18;
    }

    /**
     * @dev Fallback function to allow the contract to receive Ether directly.
     */
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Token Sale Registry
 * @dev Manages the lifecycle of token sale rounds, including referral programs and fund allocation.
 * This contract allows for the configuration of sale rounds, referral rates, and the claiming of referral rewards.
 * It implements AccessControl for administrative actions and utilizes SafeERC20 for token interactions.
 */
contract TokenSaleRegistry is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /**
     * @notice Tracks the state of the token sale.
     * @dev Used to manage the lifecycle stages of a sale round within the contract.
     * @param Reset Initial state, no sale is active.
     * @param Started Sale round has started and is currently active.
     * @param Ended Sale round has completed, and no further sales are possible.
     */
    enum State {
        Reset,
        Started,
        Ended
    }

    /**
     * @notice Structure representing a sale round within the token sale.
     * @dev Stores details pertinent to a single round of the sale.
     * @param defined Boolean indicating if the round is defined, used to check initialization.
     * @param state Current state of the round, corresponding to the State enum.
     * @param sold Total number of tokens sold in this round.
     * @param supply Total number of tokens available for sale in this round.
     */
    struct Round {
        bool defined;
        State state;
        uint256 price;
        uint256 sold;
        uint256 supply;
    }

    /**
     * @notice Details about a referral account used in the token sale.
     * @dev Tracks whether a referral is active and the rates applicable for commission.
     * @param defined Boolean indicating if the referral account is set up in the system.
     * @param enabled Boolean indicating if the referral account is currently enabled.
     * @param primaryRefRate Referral rate for direct referrals, expressed as a percentage of the sale.
     * @param secondaryRefRate Referral rate for secondary referrals, affecting indirect sales influence.
     */
    struct Referral {
        bool defined;
        bool enabled;
        uint256 primaryRefRate;
        uint256 secondaryRefRate;
    }

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    address internal constant NATIVE_CURRENCY_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant TOKEN = 0x0000000000000000000000000000000000000001;
    uint256 internal constant MAX_ALLOCATION = 1e25;
    uint256 internal constant MIN_CONTRIBUTION = 49e18;

    address private _fundsManagementWallet;
    State private _state;

    Round[] private _rounds;
    uint256 private _currentRound;

    uint256 private _max;
    uint256 private _min;

    uint256 private _authLimit;
    mapping(address => bool) private _auth;

    uint256 private _primaryRefRate = 150;
    uint256 private _secondaryRefRate = 50;

    uint256 private _totalSold;
    mapping(address => uint256) private _funds;
    mapping(address => mapping(uint256 => uint256)) private _balances;

    mapping(address => Referral) private _refs;
    mapping(address => address) private _refsUsers;
    mapping(address => mapping(address => uint256)) private _refsBalances;

    /**
     * @notice Emitted when the state of the token sale is updated.
     * @param state The new state of the token sale.
     */
    event StateUpdated(State state);

    /**
     * @notice Emitted when a new sale round starts.
     * @param round The index of the sale round that has started.
     */
    event SaleRoundStarted(uint256 indexed round);

    /**
     * @notice Emitted when a sale round ends.
     * @param round The index of the sale round that has ended.
     */
    event SaleRoundEnded(uint256 indexed round);

    /**
     * @notice Emitted when a new sale round is configured.
     * @param price The price per token.
     * @param supply The total supply of tokens for the round.
     */
    event SaleRoundConfigured(uint256 price, uint256 supply);

    /**
     * @notice Emitted when the pricing of a sale round is adjusted.
     * @param round The index of the sale round.
     * @param price The new price per token.
     */
    event SaleRoundPricingAdjusted(uint256 indexed round, uint256 price);

    /**
     * @notice Emitted when the token supply for a sale round is adjusted.
     * @param round The index of the sale round.
     * @param supply The new total supply for the round.
     */
    event SaleRoundSupplyAdjusted(uint256 indexed round, uint256 supply);

    /**
     * @notice Emitted when native currency is retrieved from the contract.
     * @param amount The amount of native currency retrieved.
     */
    event NativeCurrencyRetrieved(uint256 amount);

    /**
     * @notice Emitted when ERC20 tokens are retrieved from the contract.
     * @param token The address of the ERC20 token retrieved.
     * @param amount The amount of tokens retrieved.
     */
    event TokensRetrieved(address token, uint256 amount);

    /**
     * @notice Emitted when the authorization threshold for participants is updated.
     * @param limit The new authorization limit.
     */
    event AuthorizationThresholdUpdated(uint256 limit);

    /**
     * @notice Emitted when a user's authorization status is updated.
     * @param user The address of the user.
     * @param value The new authorization value (true for authorized, false for not authorized).
     */
    event AuthUserUpdated(address indexed user, bool value);

    /**
     * @notice Emitted when the maximum contribution limit is updated.
     * @param amount The new maximum contribution limit.
     */
    event MaxUpdated(uint256 amount);

    /**
     * @notice Emitted when the minimum contribution limit is updated.
     * @param amount The new minimum contribution limit.
     */
    event MinUpdated(uint256 amount);

    /**
     * @notice Emitted when the funds management wallet address is updated.
     * @param fundsManagementWallet The new funds management wallet address.
     */
    event FundsManagementWalletUpdated(address indexed fundsManagementWallet);

    /**
     * @notice Emitted when referral rates are configured.
     * @param primaryRefRate The primary referral rate.
     * @param secondaryRefRate The secondary referral rate.
     */
    event ReferralRatesConfigured(uint256 primaryRefRate, uint256 secondaryRefRate);

    /**
     * @notice Emitted when a new referral account is initialized.
     * @param ref The address of the referral.
     * @param primaryRefRate The primary referral rate for this account.
     * @param secondaryRefRate The secondary referral rate for this account.
     */
    event ReferralAccountInitialized(address indexed ref, uint256 primaryRefRate, uint256 secondaryRefRate);

    /**
     * @notice Emitted when a referral account is enabled.
     * @param ref The address of the referral account that was enabled.
     */
    event ReferralEnabled(address indexed ref);

    /**
     * @notice Emitted when a referral account is disabled.
     * @param ref The address of the referral account that was disabled.
     */
    event ReferralDisabled(address indexed ref);

    /**
     * @notice Emitted when referral rewards are claimed.
     * @param ref The address of the referral claiming the rewards.
     * @param token The token in which the rewards are claimed.
     * @param amount The amount of rewards claimed.
     */
    event ReferralRewardsClaimed(address indexed ref, address indexed token, uint256 amount);

    /**
     * @notice Thrown when an operation is attempted with invalid parameters.
     */
    error ErrInvalidParameters();

    /**
     * @notice Thrown when an operation is attempted to start a sale that has already been started.
     */
    error ErrSaleAlreadyStarted();

    /**
     * @notice Thrown when an operation is attempted on a sale that is not active.
     */
    error ErrSaleNotActive();

    /**
     * @notice Thrown when a zero address is used where a valid address is required.
     */
    error ErrNullAddress();

    /**
     * @notice Thrown when a specified sale round does not exist.
     * @param index_ The index of the sale round.
     */
    error ErrUndefinedSaleRound(uint256 index_);

    /**
     * @notice Thrown when an operation is attempted on a sale round that has already started.
     * @param index_ The index of the sale round.
     */
    error ErrRoundStarted(uint256 index_);

    /**
     * @notice Thrown when an invalid price is set (e.g., zero).
     */
    error ErrInvalidPrice();

    /**
     * @notice Thrown when an invalid supply is set (e.g., zero).
     */
    error ErrInvalidSupply();

    /**
     * @notice Thrown when an operation is attempted on a sale round that has already ended.
     * @param index_ The index of the sale round.
     */
    error ErrRoundEnded(uint256 index_);

    /**
     * @notice Thrown when there is insufficient supply in a sale round for an operation.
     * @param index_ The index of the sale round.
     */
    error ErrInsufficientRoundSupply(uint256 index_);

    /**
     * @notice Thrown when the amount provided is below the required minimum.
     * @param amount_ The amount provided.
     * @param min_ The minimum required amount.
     */
    error ErrMin(uint256 amount_, uint256 min_);

    /**
     * @notice Thrown when the amount provided exceeds the allowed maximum.
     * @param amount_ The amount provided.
     * @param max_ The maximum allowed amount.
     */
    error ErrMax(uint256 amount_, uint256 max_);

    /**
     * @notice Thrown when the authorization limit is set outside the allowed range.
     * @param limit_ The authorization limit.
     * @param min_ The minimum allowed limit.
     * @param max_ The maximum allowed limit.
     */
    error ErrAuthLimitOutsideAllowedRange(uint256 limit_, uint256 min_, uint256 max_);

    /**
     * @notice Thrown when the total of referral rates exceeds the limit of 100%.
     * @param rates_ The total referral rates.
     */
    error ErrReferralRatesExceedLimit(uint256 rates_);

    /**
     * @notice Thrown when an undefined referral account is referenced.
     * @param ref_ The referral account address.
     */
    error ErrUndefinedReferralAccount(address ref_);

    /**
     * @notice Thrown when trying to enable an already enabled referral account.
     * @param ref_ The referral account address.
     */
    error ErrReferralAlreadyEnabled(address ref_);

    /**
     * @notice Thrown when trying to disable a referral account that is not enabled.
     * @param ref_ The referral account address.
     */
    error ErrReferralNotEnabled(address ref_);

    /**
     * @notice Thrown when an empty list of tokens is used where it is not permitted.
     */
    error ErrEmptyTokenList();

    /**
     * @notice Thrown when a transfer of funds fails.
     */
    error ErrTransferFailure();

    /**
     * @notice Initializes the TokenSaleRegistry with the specified funds management wallet.
     * @param fundsManagementWallet_ The wallet that will manage the funds collected from token sales. Must be a non-zero address.
     * @dev Sets up the initial admin and operator roles and assigns them to the message sender. Ensures that the contract starts
     * in a predictable state.
     */
    constructor(address fundsManagementWallet_) {
        if (fundsManagementWallet_ == address(0)) {
            revert ErrNullAddress();
        }
        _fundsManagementWallet = fundsManagementWallet_;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(OPERATOR_ROLE, _msgSender());
    }

    /**
     * @notice Activates the token sale, allowing rounds to be configured and started.
     * @dev Transitions the contract state from 'Reset' to 'Started'. This change is crucial as it permits the creation and management
     * of sale rounds.
     * Reverts if attempting to activate when already active to prevent reinitialization of the sale process.
     * Emits a {StateUpdated} event on success.
     */
    function activateSale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_state != State.Reset) {
            revert ErrSaleAlreadyStarted();
        }
        _state = State.Started;

        emit StateUpdated(_state);
    }

    /**
     * @notice Deactivates the token sale, preventing any new rounds from starting.
     * @dev Sets the contract state to `Ended`. Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * Reverts if the contract is already inactive.
     * Emits a {StateUpdated} event on success.
     */
    function deactivateSale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!isActive()) {
            revert ErrSaleNotActive();
        }
        _state = State.Ended;

        emit StateUpdated(_state);
    }

    /**
     * @notice Configures a new sale round with specified prices and supply.
     * @dev Adds validation to prevent setting the price or supply to zero.
     * @param price_ The price for the 'SNOVA' token.
     * @param supply_ The total token supply for the round.
     * Reverts with `ErrInvalidPrice` if the price is zero.
     * Reverts with `ErrInvalidSupply` if the supply is zero.
     * Emits a {SaleRoundConfigured} event on success.
     */
    function configureSaleRound(uint256 price_, uint256 supply_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isInactive()) {
            revert ErrSaleNotActive();
        }
        if (price_ == 0) {
            revert ErrInvalidPrice();
        }
        if (supply_ == 0) {
            revert ErrInvalidSupply();
        }
        _rounds.push(Round({defined: true, state: State.Reset, price: price_, sold: 0, supply: supply_}));

        emit SaleRoundConfigured(price_, supply_);
    }

    /**
     * @notice Sets the referral rates for primary and secondary referrals.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`. Rates are expressed in tenths of a percent (i.e., 10 equals 1%).
     * @param primaryRefRate_ The referral rate for primary referrals, determining the percentage of the sale amount credited as a reward.
     * @param secondaryRefRate_ The referral rate for secondary referrals, used to calculate secondary rewards based on the sale amount.
     * Emits a {ReferralRatesConfigured} event on success.
     */
    function configureReferralRates(
        uint256 primaryRefRate_,
        uint256 secondaryRefRate_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isInactive()) {
            revert ErrSaleNotActive();
        }
        uint256 refRatesSum = primaryRefRate_ + secondaryRefRate_;
        if (refRatesSum > 1000) {
            revert ErrReferralRatesExceedLimit(refRatesSum);
        }
        _primaryRefRate = primaryRefRate_;
        _secondaryRefRate = secondaryRefRate_;

        emit ReferralRatesConfigured(_primaryRefRate, _secondaryRefRate);
    }

    /**
     * @notice Initializes referral accounts with specific primary and secondary referral rates.
     * @dev Configures each referral account provided in the `refs_` array with rates specified in `primaryRefRate_` and `secondaryRefRate_` arrays.
     *      This method should be used carefully as it directly affects the incentives structure.
     * @param refs_ Array of addresses to be set up as referral accounts.
     * @param primaryRefRate_ Array of primary referral rates corresponding to each address in `refs_`.
     * @param secondaryRefRate_ Array of secondary referral rates corresponding to each address in `refs_`.
     * Emits a {ReferralAccountInitialized} event for each referral account on success.
     */
    function initializeReferralAccounts(
        address[] calldata refs_,
        uint256[] calldata primaryRefRate_,
        uint256[] calldata secondaryRefRate_
    ) external onlyRole(OPERATOR_ROLE) {
        if (isInactive()) {
            revert ErrSaleNotActive();
        }
        if (refs_.length != primaryRefRate_.length || refs_.length != secondaryRefRate_.length) {
            revert ErrInvalidParameters();
        }
        for (uint256 index = 0; index < refs_.length; index++) {
            _refs[refs_[index]] = Referral({
                defined: true,
                enabled: true,
                primaryRefRate: primaryRefRate_[index],
                secondaryRefRate: secondaryRefRate_[index]
            });

            emit ReferralAccountInitialized(refs_[index], primaryRefRate_[index], secondaryRefRate_[index]);
        }
    }

    /**
     * @notice Adjusts the pricing for a specific sale round.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`. The round must exist and be in the `Reset` state.
     * Adds validation to prevent setting the price to zero.
     * @param index_ The index of the sale round to adjust.
     * @param price_ The new investment price.
     * Reverts with `ErrInvalidPrice` if the price is zero.
     * Reverts if the sale is not active, the round does not exist, or the round is not in the `Reset` state.
     * Emits a {SaleRoundPricingAdjusted} event on success.
     */
    function adjustRoundPricing(uint256 index_, uint256 price_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isInactive()) {
            revert ErrSaleNotActive();
        }
        if (!_rounds[index_].defined) {
            revert ErrUndefinedSaleRound(index_);
        }
        if (_rounds[index_].state != State.Reset) {
            revert ErrRoundStarted(index_);
        }
        if (price_ == 0) {
            revert ErrInvalidPrice();
        }
        _rounds[index_].price = price_;

        emit SaleRoundPricingAdjusted(index_, price_);
    }

    /**
     * @notice Adjusts the supply for a specific sale round.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`. The round must exist and cannot be in the `Ended` state.
     * Adds validation to prevent setting the supply to zero.
     * @param index_ The index of the sale round to adjust.
     * @param supply_ The new supply for the round.
     * Reverts with `ErrInvalidSupply` if the supply is zero.
     * Reverts if the sale is not active, the round does not exist, or the round is in the `Ended` state.
     * Emits a {SaleRoundSupplyAdjusted} event on success.
     */
    function adjustRoundSupply(uint256 index_, uint256 supply_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isInactive()) {
            revert ErrSaleNotActive();
        }
        if (!_rounds[index_].defined) {
            revert ErrUndefinedSaleRound(index_);
        }
        if (_rounds[index_].state == State.Ended) {
            revert ErrRoundEnded(index_);
        }
        if (_rounds[index_].sold > supply_) {
            revert ErrInsufficientRoundSupply(index_);
        }
        if (supply_ == 0) {
            revert ErrInvalidSupply();
        }
        _rounds[index_].supply = supply_;

        emit SaleRoundSupplyAdjusted(index_, supply_);
    }

    /**
     * @notice Starts a specific sale round, allowing tokens to be sold.
     * @dev Can only be called by an account with the `OPERATOR_ROLE`. The round must exist and be in the `Reset` state.
     * @param index_ The index of the sale round to start.
     * Reverts if the sale is not active, the round does not exist, or the round is not in the `Reset` state.
     * Emits a {SaleRoundStarted} event on success.
     */
    function startSaleRound(uint256 index_) external onlyRole(OPERATOR_ROLE) {
        if (!isActive()) {
            revert ErrSaleNotActive();
        }
        if (!_rounds[index_].defined) {
            revert ErrUndefinedSaleRound(index_);
        }
        if (_rounds[index_].state != State.Reset) {
            revert ErrRoundStarted(index_);
        }
        if (_rounds[_currentRound].state == State.Started) {
            _rounds[_currentRound].state = State.Ended;
        }
        _rounds[index_].state = State.Started;
        _currentRound = index_;

        emit SaleRoundStarted(index_);
    }

    /**
     * @notice Ends a specific sale round, stopping any further token sales.
     * @dev Can only be called by an account with the `OPERATOR_ROLE`. The round must exist and be in the `Started` state.
     * @param index_ The index of the sale round to end.
     * Reverts if the round does not exist or is not in the `Started` state.
     * Emits a {SaleRoundEnded} event on success.
     */
    function endSaleRound(uint256 index_) external onlyRole(OPERATOR_ROLE) {
        if (!_rounds[index_].defined) {
            revert ErrUndefinedSaleRound(index_);
        }
        if (_rounds[index_].state != State.Started) {
            revert ErrRoundEnded(index_);
        }
        _rounds[index_].state = State.Ended;

        emit SaleRoundEnded(index_);
    }

    /**
     * @notice Authorizes or deauthorizes a participant for the token sale.
     * @dev Can only be called by an account with the `OPERATOR_ROLE`.
     * @param user_ The address of the participant to authorize or deauthorize.
     * @param value_ A boolean where `true` authorizes the participant and `false` deauthorizes them.
     * Emits an {AuthUserUpdated} event on success.
     */
    function authorizeParticipant(address user_, bool value_) external onlyRole(OPERATOR_ROLE) {
        _auth[user_] = value_;

        emit AuthUserUpdated(user_, value_);
    }

    /**
     * @notice Batch authorizes or deauthorizes participants for the token sale.
     * @dev Can only be called by an account with the `OPERATOR_ROLE`.
     * @param users_ The addresses of the participants to authorize or deauthorize.
     * @param values_ An array of booleans where `true` authorizes and `false` deauthorizes the corresponding participant.
     * Reverts if the length of `users_` and `values_` arrays do not match.
     * Emits an {AuthUserUpdated} event for each participant on success.
     */

    function batchAuthorizeParticipants(
        address[] calldata users_,
        bool[] calldata values_
    ) external onlyRole(OPERATOR_ROLE) {
        if (users_.length != values_.length) {
            revert ErrInvalidParameters();
        }
        for (uint256 index = 0; index < users_.length; index++) {
            _auth[users_[index]] = values_[index];

            emit AuthUserUpdated(users_[index], values_[index]);
        }
    }

    /**
     * @notice Updates the maximum allocation allowed per participant.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param amount_ The new maximum allocation amount.
     * Reverts if `amount_` is greater than `MAX_ALLOCATION` or less than the current minimum contribution limit.
     * Emits a {MaxUpdated} event on success.
     */
    function updateMaximumAllocation(uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (amount_ > MAX_ALLOCATION) {
            revert ErrMax(amount_, MAX_ALLOCATION);
        }
        if (amount_ < _min) {
            revert ErrMin(amount_, _min);
        }
        _max = amount_;

        emit MaxUpdated(_max);
    }

    /**
     * @notice Updates the minimum contribution required to participate in the sale.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param amount_ The new minimum contribution amount.
     * Reverts if `amount_` is less than `MIN_CONTRIBUTION` or greater than the current maximum allocation limit.
     * Emits a {MinUpdated} event on success.
     */

    function updateMinimumContribution(uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (amount_ < MIN_CONTRIBUTION) {
            revert ErrMin(amount_, MIN_CONTRIBUTION);
        }
        if (amount_ > _max) {
            revert ErrMax(amount_, _max);
        }
        _min = amount_;

        emit MinUpdated(_min);
    }

    /**
     * @notice Sets the threshold for which participants are automatically authorized.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param amount_ The new authorization threshold amount.
     * Reverts if `amount_` is not within the bounds of the minimum and maximum contribution limits.
     * Emits an {AuthorizationThresholdUpdated} event on success.
     */
    function updateAuthorizationThreshold(uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_min > amount_ || amount_ > _max) {
            revert ErrAuthLimitOutsideAllowedRange(amount_, _min, _max);
        }
        _authLimit = amount_;

        emit AuthorizationThresholdUpdated(amount_);
    }

    /**
     * @notice Updates the wallet address used for managing funds collected from the sale.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param fundsManagementWallet_ The new funds management wallet address.
     * Reverts if `fundsManagementWallet_` is the zero address.
     * Emits a {FundsManagementWalletUpdated} event on success.
     */
    function updateFundsWallet(address fundsManagementWallet_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (fundsManagementWallet_ == address(0)) {
            revert ErrNullAddress();
        }
        _fundsManagementWallet = fundsManagementWallet_;

        emit FundsManagementWalletUpdated(fundsManagementWallet_);
    }

    /**
     * @notice Processes and records a sale transaction, distributing rewards if applicable.
     * @dev This function can only be called by an account with the `OPERATOR_ROLE`. It handles the processing of sales,
     * updates the total sold amount, participant's funds, and manages referral rewards if a valid referral is provided.
     * Refactoring involves separate functions for processing sales, recording, and updating referrals.
     * @param user_ The address of the user participating in the sale.
     * @param token_ The token in which the sale is conducted.
     * @param amount_ The amount of funds involved in the transaction.
     * @param sold_ The amount of tokens sold in this transaction.
     * @param ref_ The referral's address, if any.
     * @param primaryReward_ The 'SNOVA' reward amount for the referral.
     * @param secondaryReward_ The COIN reward amount based on the sale amount.
     */
    function processAndRecordSale(
        address user_,
        address token_,
        uint256 amount_,
        uint256 sold_,
        address ref_,
        uint256 primaryReward_,
        uint256 secondaryReward_
    ) external onlyRole(OPERATOR_ROLE) {
        processSale(user_, amount_, sold_);
        recordReferral(ref_);

        if (ref_ != address(0)) {
            updateReferralRewards(ref_, token_, primaryReward_, secondaryReward_);
        }
        _refsUsers[user_] = ref_;
    }

    /**
     * @notice Enables a referral account, allowing it to receive referral rewards.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`. Marks a referral as enabled.
     * @param ref_ The address of the referral account to enable.
     * Reverts if the referral account is already enabled or undefined.
     * Emits a {ReferralEnabled} event upon success.
     */
    function enableReferral(address ref_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_refs[ref_].defined) {
            revert ErrUndefinedReferralAccount(ref_);
        }
        if (_refs[ref_].enabled) {
            revert ErrReferralAlreadyEnabled(ref_);
        }
        _refs[ref_].enabled = true;

        emit ReferralEnabled(ref_);
    }

    /**
     * @notice Disables a referral account, preventing it from receiving further referral rewards.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`. Marks a referral as disabled.
     * @param ref_ The address of the referral account to disable.
     * Reverts if the referral account is already disabled or undefined.
     * Emits a {ReferralDisabled} event upon success.
     */
    function disableReferral(address ref_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!_refs[ref_].defined) {
            revert ErrUndefinedReferralAccount(ref_);
        }
        if (!_refs[ref_].enabled) {
            revert ErrReferralNotEnabled(ref_);
        }
        _refs[ref_].enabled = false;

        emit ReferralDisabled(ref_);
    }

    /**
     * @notice Allows referral accounts to claim their accrued rewards for specified tokens.
     * @dev Can only be executed by the referral account itself. It transfers the accrued rewards for each token specified in the `tokens_` array.
     * @param tokens_ An array of token addresses for which to claim rewards.
     * Reverts if the caller has no rewards to claim for a specified token or if the referral account is not enabled.
     * Emits a {ReferralRewardsClaimed} event for each token with rewards being claimed.
     */
    function claimRef(address[] calldata tokens_) external nonReentrant {
        address ref_ = _msgSender();

        if (tokens_.length == 0) {
            revert ErrEmptyTokenList();
        }
        if (!_refs[ref_].defined) {
            revert ErrUndefinedReferralAccount(ref_);
        }
        if (!_refs[ref_].enabled) {
            revert ErrReferralNotEnabled(ref_);
        }

        for (uint256 i = 0; i < tokens_.length; i++) {
            address token = tokens_[i];
            uint256 balance = _refsBalances[ref_][token];

            if (balance == 0) {
                continue;
            }

            _refsBalances[ref_][token] = 0;

            if (token == NATIVE_CURRENCY_ADDRESS) {
                payable(ref_).sendValue(balance);
            } else {
                IERC20(token).safeTransfer(ref_, balance);
            }

            emit ReferralRewardsClaimed(ref_, token, balance);
        }
    }

    /**
     * @notice Retrieves native currency sent to the contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @notice Requires successful transfer to the caller.
     * Emits a {NativeCurrencyRetrieved} event on successful retrieval.
     */
    function retrieveNativeCurrency() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(_msgSender()), balance);
        emit NativeCurrencyRetrieved(balance);
    }

    /**
     * @notice Retrieves ERC20 tokens sent to the contract.
     * @dev Can only be called by an account with the `DEFAULT_ADMIN_ROLE`.
     * @param token_ The address of the ERC20 token to retrieve.
     * @param amount_ The amount of tokens to retrieve.
     * Emits a {TokensRetrieved} event on successful retrieval.
     */
    function retrieveTokens(address token_, uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        IERC20(token_).safeTransfer(_msgSender(), amount_);
        emit TokensRetrieved(token_, amount_);
    }

    /**
     * @notice Returns the address of the funds management wallet.
     * @dev Getter function for the address where the funds collected from the sales are managed.
     * @return The address of the funds management wallet.
     */
    function getFundsWallet() external view returns (address) {
        return _fundsManagementWallet;
    }

    /**
     * @notice Retrieves the maximum allowed allocation per participant in the token sale.
     * @dev This getter function provides the maximum amount a participant can contribute to the token sale.
     * @return The maximum allocation amount in the token sale's currency.
     */
    function getMax() external view returns (uint256) {
        return _max;
    }

    /**
     * @notice Retrieves the minimum required contribution for participating in the token sale.
     * @dev This getter function provides the minimum amount required to participate in the token sale.
     * @return The minimum contribution amount in the token sale's currency.
     */
    function getMin() external view returns (uint256) {
        return _min;
    }

    /**
     * @notice Returns the total number of sale rounds configured in the contract.
     * @dev Provides a count of how many rounds have been added to the sale, regardless of their state.
     * @return The total number of sale rounds.
     */
    function getRoundsCount() external view returns (uint256) {
        return _rounds.length;
    }

    /**
     * @notice Retrieves the identifier of the currently active sale round.
     * @dev This function provides the index of the currently active round. Rounds are indexed starting from 0.
     * @return The index of the currently active sale round.
     */
    function getCurrentRound() external view returns (uint256) {
        return _currentRound;
    }

    /**
     * @notice Provides detailed information about a specific sale round.
     * @dev Fetches round data, including prices and state, based on the round index provided.
     * @param index_ The index of the sale round to retrieve information for.
     * @return A `Round` struct containing details about the specified sale round.
     * Reverts if the round index is out of bounds.
     */
    function getRound(uint256 index_) external view returns (Round memory) {
        return _rounds[index_];
    }

    /**
     * @notice Retrieves the total amount of tokens sold across all rounds.
     * @dev Sums up the total tokens sold in all rounds to give a cumulative figure.
     * @return The total amount of tokens sold in the token sale.
     */
    function getTotalSold() external view returns (uint256) {
        return _totalSold;
    }

    /**
     * @notice Checks the amount of tokens a user has purchased in a specific sale round.
     * @dev Provides the number of tokens a given user has bought in a particular round.
     * @param user_ The address of the user.
     * @param round_ The index of the sale round.
     * @return The number of tokens purchased by the user in the specified round.
     */
    function balanceOf(address user_, uint256 round_) external view returns (uint256) {
        return _balances[user_][round_];
    }

    /**
     * @notice Retrieves the referral rewards balance for a user in a specific token.
     * @dev Indicates how much of a particular token a user has earned as referral rewards.
     * @param user_ The address of the user or referral.
     * @param token_ The token for which the referral balance is queried.
     * @return The referral rewards balance for the user in the specified token.
     */
    function refBalanceOf(address user_, address token_) external view returns (uint256) {
        return _refsBalances[user_][token_];
    }

    /**
     * @notice Calculates the remaining allocation a user is allowed to contribute.
     * @dev Determines how much more a user can contribute based on their current contributions and the authorization limit.
     * @param user_ The address of the user.
     * @return The remaining amount the user is allowed to contribute.
     */
    function limitOf(address user_) external view returns (uint256) {
        uint256 amount = _funds[user_];
        uint256 limit = _authLimit;
        if (isAuth(user_)) {
            limit = _max;
        }
        return amount < limit ? limit - amount : 0;
    }

    /**
     * @notice Calculates the maximum limit a user can contribute based on their current contributions.
     * @dev Determines the maximum amount a user is still allowed to contribute towards the sale.
     * @param user_ The address of the participant.
     * @return The maximum remaining contribution amount for the user.
     */
    function maxLimitOf(address user_) external view returns (uint256) {
        uint256 amount = _funds[user_];
        return amount < _max ? _max - amount : 0;
    }

    /**
     * @notice Retrieves the total amount of funds a user has contributed to the sale.
     * @dev Provides the cumulative contribution amount of a user across all sale rounds.
     * @param user_ The address of the user.
     * @return The total contribution amount of the user in the token sale's currency.
     */
    function getFundsOfUser(address user_) external view returns (uint256) {
        return _funds[user_];
    }

    /**
     * @notice Returns the authorization limit for participants.
     * @dev Provides the threshold above which users need special authorization to contribute.
     * @return The authorization limit for contributions.
     */
    function getAuthLimit() external view returns (uint256) {
        return _authLimit;
    }

    /**
     * @notice Determines the referral associated with a user or transaction.
     * @dev Identifies the referral, if any, responsible for a user's participation in the sale.
     * @param user_ The address of the user whose referral is to be identified.
     * @param ref_ A potential referral address provided by the user.
     * @return The address of the referral, if valid and enabled; otherwise, the zero address.
     */
    function getRef(address user_, address ref_) external view returns (address) {
        Referral memory ref = _refs[_refsUsers[user_]];
        if (ref.defined && ref.enabled) {
            return _refsUsers[user_];
        }
        ref = _refs[ref_];
        if (!ref.defined || ref.enabled) {
            return ref_;
        }
        return address(0);
    }

    /**
     * @notice Provides the detailed referral structure for a given referral account.
     * @dev Fetches detailed referral information, including rates and enabled status.
     * @param user_ The address of the referral account.
     * @return The `Referral` struct containing detailed information about the referral.
     */
    function getReferralStruct(address user_) external view returns (Referral memory) {
        return _refs[user_];
    }

    /**
     * @notice Retrieves the referral rates for a specific referral account.
     * @dev Provides the custom referral rates set for a specific referral, if defined; otherwise, returns the global rates.
     * @param ref_ The address of the referral account.
     * @return The primary and secondary referral rates for the specified account.
     */
    function getRefRates(address ref_) external view returns (uint256, uint256) {
        Referral memory ref = _refs[ref_];
        if (ref.defined) {
            return (Math.max(ref.primaryRefRate, _primaryRefRate), Math.max(ref.secondaryRefRate, _secondaryRefRate));
        }
        return (_primaryRefRate, _secondaryRefRate);
    }

    /**
     * @notice Retrieves global referral rates for the sale.
     * @dev Provides the default referral rates applied to all referrals unless overridden.
     * @return The primary and secondary referral rates.
     */
    function getGlobalRefRates() external view returns (uint256, uint256) {
        return (_primaryRefRate, _secondaryRefRate);
    }

    /**
     * @notice Checks if the token sale is currently active.
     * @dev Utility function to determine if the sale is in the `Started` state.
     * @return `true` if the sale is active, `false` otherwise.
     */
    function isActive() public view returns (bool) {
        return _state == State.Started;
    }

    /**
     * @notice Checks if the token sale is currently inactive or ended.
     * @dev Utility function to determine if the sale is in the `Ended` state.
     * @return `true` if the sale is inactive, `false` otherwise.
     */
    function isInactive() public view returns (bool) {
        return _state == State.Ended;
    }

    /**
     * @notice Retrieves the sale price for tokens.
     * @dev Provides the price for the currently active round.
     * @return The sale price per token for the currently active round.
     */
    function getPrice() public view returns (uint256) {
        if (_rounds[_currentRound].state == State.Started) {
            return _rounds[_currentRound].price;
        }
        return 0;
    }

    /**
     * @notice Checks if a user is authorized for '_max' contributions.
     * @dev Determines if a user has been marked as authorized to bypass the standard contribution limit.
     * @param user_ The address of the user to check.
     * @return `true` if the user is authorized, `false` otherwise.
     */
    function isAuth(address user_) public view returns (bool) {
        return _auth[user_];
    }

    /**
     * @dev Updates the internal accounting for the sale, including total funds received and tokens sold.
     * @param user_ The address of the user participating in the sale.
     * @param amount_ The amount of funds involved in the transaction.
     * @param sold_ The amount of tokens sold in this transaction.
     */
    function processSale(address user_, uint256 amount_, uint256 sold_) private {
        _funds[user_] += amount_;
        _totalSold += sold_;
        _rounds[_currentRound].sold += sold_;
        _balances[user_][_currentRound] += sold_;
    }

    /**
     * @dev Updates the referral rewards balances for the given referral.
     * @param ref_ The address of the referral.
     * @param token_ The token in which the sale is conducted.
     * @param primaryReward_ The 'SNOVA' reward amount for the referral.
     * @param secondaryReward_ The COIN reward amount based on the sale amount.
     */
    function updateReferralRewards(
        address ref_,
        address token_,
        uint256 primaryReward_,
        uint256 secondaryReward_
    ) private {
        _refsBalances[ref_][token_] += primaryReward_;
        _refsBalances[ref_][TOKEN] += secondaryReward_;
    }

    /**
     * @dev Handles referral initialization and updates the referral tracking if applicable.
     * @param ref_ The referral's address, if any.
     */
    function recordReferral(address ref_) private {
        if (ref_ != address(0) && !_refs[ref_].defined) {
            _refs[ref_].defined = true;
            _refs[ref_].enabled = true;
            emit ReferralAccountInitialized(ref_, _primaryRefRate, _secondaryRefRate);
        }
    }

    /**
     * @dev Fallback function to allow the contract to receive Ether directly.
     */
    receive() external payable {}
}
