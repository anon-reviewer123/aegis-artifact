// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC1271.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 *
 * _Available since v4.1._
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

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
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
import "../../../utils/Address.sol";

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
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
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
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
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
        IERC20Permit token,
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
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
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
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
pragma solidity >=0.8.19;

// Common.sol
//
// Common mathematical functions needed by both SD59x18 and UD60x18. Note that these global functions do not
// always operate with SD59x18 and UD60x18 numbers.

/*//////////////////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when the resultant value in {mulDiv} overflows uint256.
error PRBMath_MulDiv_Overflow(uint256 x, uint256 y, uint256 denominator);

/// @notice Thrown when the resultant value in {mulDiv18} overflows uint256.
error PRBMath_MulDiv18_Overflow(uint256 x, uint256 y);

/// @notice Thrown when one of the inputs passed to {mulDivSigned} is `type(int256).min`.
error PRBMath_MulDivSigned_InputTooSmall();

/// @notice Thrown when the resultant value in {mulDivSigned} overflows int256.
error PRBMath_MulDivSigned_Overflow(int256 x, int256 y);

/*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
//////////////////////////////////////////////////////////////////////////*/

/// @dev The maximum value a uint128 number can have.
uint128 constant MAX_UINT128 = type(uint128).max;

/// @dev The maximum value a uint40 number can have.
uint40 constant MAX_UINT40 = type(uint40).max;

/// @dev The unit number, which the decimal precision of the fixed-point types.
uint256 constant UNIT = 1e18;

/// @dev The unit number inverted mod 2^256.
uint256 constant UNIT_INVERSE = 78156646155174841979727994598816262306175212592076161876661_508869554232690281;

/// @dev The the largest power of two that divides the decimal value of `UNIT`. The logarithm of this value is the least significant
/// bit in the binary representation of `UNIT`.
uint256 constant UNIT_LPOTD = 262144;

/*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Calculates the binary exponent of x using the binary fraction method.
/// @dev Has to use 192.64-bit fixed-point numbers. See https://ethereum.stackexchange.com/a/96594/24693.
/// @param x The exponent as an unsigned 192.64-bit fixed-point number.
/// @return result The result as an unsigned 60.18-decimal fixed-point number.
/// @custom:smtchecker abstract-function-nondet
function exp2(uint256 x) pure returns (uint256 result) {
    unchecked {
        // Start from 0.5 in the 192.64-bit fixed-point format.
        result = 0x800000000000000000000000000000000000000000000000;

        // The following logic multiplies the result by $\sqrt{2^{-i}}$ when the bit at position i is 1. Key points:
        //
        // 1. Intermediate results will not overflow, as the starting point is 2^191 and all magic factors are under 2^65.
        // 2. The rationale for organizing the if statements into groups of 8 is gas savings. If the result of performing
        // a bitwise AND operation between x and any value in the array [0x80; 0x40; 0x20; 0x10; 0x08; 0x04; 0x02; 0x01] is 1,
        // we know that `x & 0xFF` is also 1.
        if (x & 0xFF00000000000000 > 0) {
            if (x & 0x8000000000000000 > 0) {
                result = (result * 0x16A09E667F3BCC909) >> 64;
            }
            if (x & 0x4000000000000000 > 0) {
                result = (result * 0x1306FE0A31B7152DF) >> 64;
            }
            if (x & 0x2000000000000000 > 0) {
                result = (result * 0x1172B83C7D517ADCE) >> 64;
            }
            if (x & 0x1000000000000000 > 0) {
                result = (result * 0x10B5586CF9890F62A) >> 64;
            }
            if (x & 0x800000000000000 > 0) {
                result = (result * 0x1059B0D31585743AE) >> 64;
            }
            if (x & 0x400000000000000 > 0) {
                result = (result * 0x102C9A3E778060EE7) >> 64;
            }
            if (x & 0x200000000000000 > 0) {
                result = (result * 0x10163DA9FB33356D8) >> 64;
            }
            if (x & 0x100000000000000 > 0) {
                result = (result * 0x100B1AFA5ABCBED61) >> 64;
            }
        }

        if (x & 0xFF000000000000 > 0) {
            if (x & 0x80000000000000 > 0) {
                result = (result * 0x10058C86DA1C09EA2) >> 64;
            }
            if (x & 0x40000000000000 > 0) {
                result = (result * 0x1002C605E2E8CEC50) >> 64;
            }
            if (x & 0x20000000000000 > 0) {
                result = (result * 0x100162F3904051FA1) >> 64;
            }
            if (x & 0x10000000000000 > 0) {
                result = (result * 0x1000B175EFFDC76BA) >> 64;
            }
            if (x & 0x8000000000000 > 0) {
                result = (result * 0x100058BA01FB9F96D) >> 64;
            }
            if (x & 0x4000000000000 > 0) {
                result = (result * 0x10002C5CC37DA9492) >> 64;
            }
            if (x & 0x2000000000000 > 0) {
                result = (result * 0x1000162E525EE0547) >> 64;
            }
            if (x & 0x1000000000000 > 0) {
                result = (result * 0x10000B17255775C04) >> 64;
            }
        }

        if (x & 0xFF0000000000 > 0) {
            if (x & 0x800000000000 > 0) {
                result = (result * 0x1000058B91B5BC9AE) >> 64;
            }
            if (x & 0x400000000000 > 0) {
                result = (result * 0x100002C5C89D5EC6D) >> 64;
            }
            if (x & 0x200000000000 > 0) {
                result = (result * 0x10000162E43F4F831) >> 64;
            }
            if (x & 0x100000000000 > 0) {
                result = (result * 0x100000B1721BCFC9A) >> 64;
            }
            if (x & 0x80000000000 > 0) {
                result = (result * 0x10000058B90CF1E6E) >> 64;
            }
            if (x & 0x40000000000 > 0) {
                result = (result * 0x1000002C5C863B73F) >> 64;
            }
            if (x & 0x20000000000 > 0) {
                result = (result * 0x100000162E430E5A2) >> 64;
            }
            if (x & 0x10000000000 > 0) {
                result = (result * 0x1000000B172183551) >> 64;
            }
        }

        if (x & 0xFF00000000 > 0) {
            if (x & 0x8000000000 > 0) {
                result = (result * 0x100000058B90C0B49) >> 64;
            }
            if (x & 0x4000000000 > 0) {
                result = (result * 0x10000002C5C8601CC) >> 64;
            }
            if (x & 0x2000000000 > 0) {
                result = (result * 0x1000000162E42FFF0) >> 64;
            }
            if (x & 0x1000000000 > 0) {
                result = (result * 0x10000000B17217FBB) >> 64;
            }
            if (x & 0x800000000 > 0) {
                result = (result * 0x1000000058B90BFCE) >> 64;
            }
            if (x & 0x400000000 > 0) {
                result = (result * 0x100000002C5C85FE3) >> 64;
            }
            if (x & 0x200000000 > 0) {
                result = (result * 0x10000000162E42FF1) >> 64;
            }
            if (x & 0x100000000 > 0) {
                result = (result * 0x100000000B17217F8) >> 64;
            }
        }

        if (x & 0xFF000000 > 0) {
            if (x & 0x80000000 > 0) {
                result = (result * 0x10000000058B90BFC) >> 64;
            }
            if (x & 0x40000000 > 0) {
                result = (result * 0x1000000002C5C85FE) >> 64;
            }
            if (x & 0x20000000 > 0) {
                result = (result * 0x100000000162E42FF) >> 64;
            }
            if (x & 0x10000000 > 0) {
                result = (result * 0x1000000000B17217F) >> 64;
            }
            if (x & 0x8000000 > 0) {
                result = (result * 0x100000000058B90C0) >> 64;
            }
            if (x & 0x4000000 > 0) {
                result = (result * 0x10000000002C5C860) >> 64;
            }
            if (x & 0x2000000 > 0) {
                result = (result * 0x1000000000162E430) >> 64;
            }
            if (x & 0x1000000 > 0) {
                result = (result * 0x10000000000B17218) >> 64;
            }
        }

        if (x & 0xFF0000 > 0) {
            if (x & 0x800000 > 0) {
                result = (result * 0x1000000000058B90C) >> 64;
            }
            if (x & 0x400000 > 0) {
                result = (result * 0x100000000002C5C86) >> 64;
            }
            if (x & 0x200000 > 0) {
                result = (result * 0x10000000000162E43) >> 64;
            }
            if (x & 0x100000 > 0) {
                result = (result * 0x100000000000B1721) >> 64;
            }
            if (x & 0x80000 > 0) {
                result = (result * 0x10000000000058B91) >> 64;
            }
            if (x & 0x40000 > 0) {
                result = (result * 0x1000000000002C5C8) >> 64;
            }
            if (x & 0x20000 > 0) {
                result = (result * 0x100000000000162E4) >> 64;
            }
            if (x & 0x10000 > 0) {
                result = (result * 0x1000000000000B172) >> 64;
            }
        }

        if (x & 0xFF00 > 0) {
            if (x & 0x8000 > 0) {
                result = (result * 0x100000000000058B9) >> 64;
            }
            if (x & 0x4000 > 0) {
                result = (result * 0x10000000000002C5D) >> 64;
            }
            if (x & 0x2000 > 0) {
                result = (result * 0x1000000000000162E) >> 64;
            }
            if (x & 0x1000 > 0) {
                result = (result * 0x10000000000000B17) >> 64;
            }
            if (x & 0x800 > 0) {
                result = (result * 0x1000000000000058C) >> 64;
            }
            if (x & 0x400 > 0) {
                result = (result * 0x100000000000002C6) >> 64;
            }
            if (x & 0x200 > 0) {
                result = (result * 0x10000000000000163) >> 64;
            }
            if (x & 0x100 > 0) {
                result = (result * 0x100000000000000B1) >> 64;
            }
        }

        if (x & 0xFF > 0) {
            if (x & 0x80 > 0) {
                result = (result * 0x10000000000000059) >> 64;
            }
            if (x & 0x40 > 0) {
                result = (result * 0x1000000000000002C) >> 64;
            }
            if (x & 0x20 > 0) {
                result = (result * 0x10000000000000016) >> 64;
            }
            if (x & 0x10 > 0) {
                result = (result * 0x1000000000000000B) >> 64;
            }
            if (x & 0x8 > 0) {
                result = (result * 0x10000000000000006) >> 64;
            }
            if (x & 0x4 > 0) {
                result = (result * 0x10000000000000003) >> 64;
            }
            if (x & 0x2 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
            if (x & 0x1 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
        }

        // In the code snippet below, two operations are executed simultaneously:
        //
        // 1. The result is multiplied by $(2^n + 1)$, where $2^n$ represents the integer part, and the additional 1
        // accounts for the initial guess of 0.5. This is achieved by subtracting from 191 instead of 192.
        // 2. The result is then converted to an unsigned 60.18-decimal fixed-point format.
        //
        // The underlying logic is based on the relationship $2^{191-ip} = 2^{ip} / 2^{191}$, where $ip$ denotes the,
        // integer part, $2^n$.
        result *= UNIT;
        result >>= (191 - (x >> 64));
    }
}

/// @notice Finds the zero-based index of the first 1 in the binary representation of x.
///
/// @dev See the note on "msb" in this Wikipedia article: https://en.wikipedia.org/wiki/Find_first_set
///
/// Each step in this implementation is equivalent to this high-level code:
///
/// ```solidity
/// if (x >= 2 ** 128) {
///     x >>= 128;
///     result += 128;
/// }
/// ```
///
/// Where 128 is replaced with each respective power of two factor. See the full high-level implementation here:
/// https://gist.github.com/PaulRBerg/f932f8693f2733e30c4d479e8e980948
///
/// The Yul instructions used below are:
///
/// - "gt" is "greater than"
/// - "or" is the OR bitwise operator
/// - "shl" is "shift left"
/// - "shr" is "shift right"
///
/// @param x The uint256 number for which to find the index of the most significant bit.
/// @return result The index of the most significant bit as a uint256.
/// @custom:smtchecker abstract-function-nondet
function msb(uint256 x) pure returns (uint256 result) {
    // 2^128
    assembly ("memory-safe") {
        let factor := shl(7, gt(x, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^64
    assembly ("memory-safe") {
        let factor := shl(6, gt(x, 0xFFFFFFFFFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^32
    assembly ("memory-safe") {
        let factor := shl(5, gt(x, 0xFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^16
    assembly ("memory-safe") {
        let factor := shl(4, gt(x, 0xFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^8
    assembly ("memory-safe") {
        let factor := shl(3, gt(x, 0xFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^4
    assembly ("memory-safe") {
        let factor := shl(2, gt(x, 0xF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^2
    assembly ("memory-safe") {
        let factor := shl(1, gt(x, 0x3))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^1
    // No need to shift x any more.
    assembly ("memory-safe") {
        let factor := gt(x, 0x1)
        result := or(result, factor)
    }
}

/// @notice Calculates x*y÷denominator with 512-bit precision.
///
/// @dev Credits to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - The denominator must not be zero.
/// - The result must fit in uint256.
///
/// @param x The multiplicand as a uint256.
/// @param y The multiplier as a uint256.
/// @param denominator The divisor as a uint256.
/// @return result The result as a uint256.
/// @custom:smtchecker abstract-function-nondet
function mulDiv(uint256 x, uint256 y, uint256 denominator) pure returns (uint256 result) {
    // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
    // use the Chinese Remainder Theorem to reconstruct the 512-bit result. The result is stored in two 256
    // variables such that product = prod1 * 2^256 + prod0.
    uint256 prod0; // Least significant 256 bits of the product
    uint256 prod1; // Most significant 256 bits of the product
    assembly ("memory-safe") {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    // Handle non-overflow cases, 256 by 256 division.
    if (prod1 == 0) {
        unchecked {
            return prod0 / denominator;
        }
    }

    // Make sure the result is less than 2^256. Also prevents denominator == 0.
    if (prod1 >= denominator) {
        revert PRBMath_MulDiv_Overflow(x, y, denominator);
    }

    ////////////////////////////////////////////////////////////////////////////
    // 512 by 256 division
    ////////////////////////////////////////////////////////////////////////////

    // Make division exact by subtracting the remainder from [prod1 prod0].
    uint256 remainder;
    assembly ("memory-safe") {
        // Compute remainder using the mulmod Yul instruction.
        remainder := mulmod(x, y, denominator)

        // Subtract 256 bit number from 512-bit number.
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
    }

    unchecked {
        // Calculate the largest power of two divisor of the denominator using the unary operator ~. This operation cannot overflow
        // because the denominator cannot be zero at this point in the function execution. The result is always >= 1.
        // For more detail, see https://cs.stackexchange.com/q/138556/92363.
        uint256 lpotdod = denominator & (~denominator + 1);
        uint256 flippedLpotdod;

        assembly ("memory-safe") {
            // Factor powers of two out of denominator.
            denominator := div(denominator, lpotdod)

            // Divide [prod1 prod0] by lpotdod.
            prod0 := div(prod0, lpotdod)

            // Get the flipped value `2^256 / lpotdod`. If the `lpotdod` is zero, the flipped value is one.
            // `sub(0, lpotdod)` produces the two's complement version of `lpotdod`, which is equivalent to flipping all the bits.
            // However, `div` interprets this value as an unsigned value: https://ethereum.stackexchange.com/q/147168/24693
            flippedLpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
        }

        // Shift in bits from prod1 into prod0.
        prod0 |= prod1 * flippedLpotdod;

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
    }
}

/// @notice Calculates x*y÷1e18 with 512-bit precision.
///
/// @dev A variant of {mulDiv} with constant folding, i.e. in which the denominator is hard coded to 1e18.
///
/// Notes:
/// - The body is purposely left uncommented; to understand how this works, see the documentation in {mulDiv}.
/// - The result is rounded toward zero.
/// - We take as an axiom that the result cannot be `MAX_UINT256` when x and y solve the following system of equations:
///
/// $$
/// \begin{cases}
///     x * y = MAX\_UINT256 * UNIT \\
///     (x * y) \% UNIT \geq \frac{UNIT}{2}
/// \end{cases}
/// $$
///
/// Requirements:
/// - Refer to the requirements in {mulDiv}.
/// - The result must fit in uint256.
///
/// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
/// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
/// @return result The result as an unsigned 60.18-decimal fixed-point number.
/// @custom:smtchecker abstract-function-nondet
function mulDiv18(uint256 x, uint256 y) pure returns (uint256 result) {
    uint256 prod0;
    uint256 prod1;
    assembly ("memory-safe") {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    if (prod1 == 0) {
        unchecked {
            return prod0 / UNIT;
        }
    }

    if (prod1 >= UNIT) {
        revert PRBMath_MulDiv18_Overflow(x, y);
    }

    uint256 remainder;
    assembly ("memory-safe") {
        remainder := mulmod(x, y, UNIT)
        result :=
            mul(
                or(
                    div(sub(prod0, remainder), UNIT_LPOTD),
                    mul(sub(prod1, gt(remainder, prod0)), add(div(sub(0, UNIT_LPOTD), UNIT_LPOTD), 1))
                ),
                UNIT_INVERSE
            )
    }
}

/// @notice Calculates x*y÷denominator with 512-bit precision.
///
/// @dev This is an extension of {mulDiv} for signed numbers, which works by computing the signs and the absolute values separately.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - Refer to the requirements in {mulDiv}.
/// - None of the inputs can be `type(int256).min`.
/// - The result must fit in int256.
///
/// @param x The multiplicand as an int256.
/// @param y The multiplier as an int256.
/// @param denominator The divisor as an int256.
/// @return result The result as an int256.
/// @custom:smtchecker abstract-function-nondet
function mulDivSigned(int256 x, int256 y, int256 denominator) pure returns (int256 result) {
    if (x == type(int256).min || y == type(int256).min || denominator == type(int256).min) {
        revert PRBMath_MulDivSigned_InputTooSmall();
    }

    // Get hold of the absolute values of x, y and the denominator.
    uint256 xAbs;
    uint256 yAbs;
    uint256 dAbs;
    unchecked {
        xAbs = x < 0 ? uint256(-x) : uint256(x);
        yAbs = y < 0 ? uint256(-y) : uint256(y);
        dAbs = denominator < 0 ? uint256(-denominator) : uint256(denominator);
    }

    // Compute the absolute value of x*y÷denominator. The result must fit in int256.
    uint256 resultAbs = mulDiv(xAbs, yAbs, dAbs);
    if (resultAbs > uint256(type(int256).max)) {
        revert PRBMath_MulDivSigned_Overflow(x, y);
    }

    // Get the signs of x, y and the denominator.
    uint256 sx;
    uint256 sy;
    uint256 sd;
    assembly ("memory-safe") {
        // "sgt" is the "signed greater than" assembly instruction and "sub(0,1)" is -1 in two's complement.
        sx := sgt(x, sub(0, 1))
        sy := sgt(y, sub(0, 1))
        sd := sgt(denominator, sub(0, 1))
    }

    // XOR over sx, sy and sd. What this does is to check whether there are 1 or 3 negative signs in the inputs.
    // If there are, the result should be negative. Otherwise, it should be positive.
    unchecked {
        result = sx ^ sy ^ sd == 0 ? -int256(resultAbs) : int256(resultAbs);
    }
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - If x is not a perfect square, the result is rounded down.
/// - Credits to OpenZeppelin for the explanations in comments below.
///
/// @param x The uint256 number for which to calculate the square root.
/// @return result The result as a uint256.
/// @custom:smtchecker abstract-function-nondet
function sqrt(uint256 x) pure returns (uint256 result) {
    if (x == 0) {
        return 0;
    }

    // For our first guess, we calculate the biggest power of 2 which is smaller than the square root of x.
    //
    // We know that the "msb" (most significant bit) of x is a power of 2 such that we have:
    //
    // $$
    // msb(x) <= x <= 2*msb(x)$
    // $$
    //
    // We write $msb(x)$ as $2^k$, and we get:
    //
    // $$
    // k = log_2(x)
    // $$
    //
    // Thus, we can write the initial inequality as:
    //
    // $$
    // 2^{log_2(x)} <= x <= 2*2^{log_2(x)+1} \\
    // sqrt(2^k) <= sqrt(x) < sqrt(2^{k+1}) \\
    // 2^{k/2} <= sqrt(x) < 2^{(k+1)/2} <= 2^{(k/2)+1}
    // $$
    //
    // Consequently, $2^{log_2(x) /2} is a good first approximation of sqrt(x) with at least one correct bit.
    uint256 xAux = uint256(x);
    result = 1;
    if (xAux >= 2 ** 128) {
        xAux >>= 128;
        result <<= 64;
    }
    if (xAux >= 2 ** 64) {
        xAux >>= 64;
        result <<= 32;
    }
    if (xAux >= 2 ** 32) {
        xAux >>= 32;
        result <<= 16;
    }
    if (xAux >= 2 ** 16) {
        xAux >>= 16;
        result <<= 8;
    }
    if (xAux >= 2 ** 8) {
        xAux >>= 8;
        result <<= 4;
    }
    if (xAux >= 2 ** 4) {
        xAux >>= 4;
        result <<= 2;
    }
    if (xAux >= 2 ** 2) {
        result <<= 1;
    }

    // At this point, `result` is an estimation with at least one bit of precision. We know the true value has at
    // most 128 bits, since it is the square root of a uint256. Newton's method converges quadratically (precision
    // doubles at every iteration). We thus need at most 7 iteration to turn our partial result with one bit of
    // precision into the expected uint128 result.
    unchecked {
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;

        // If x is not a perfect square, round the result toward zero.
        uint256 roundedResult = x / result;
        if (result >= roundedResult) {
            result = roundedResult;
        }
    }
}

pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (common/access/OrigamiElevatedAccessBase.sol)

import { OrigamiElevatedAccessBase } from "contracts/common/access/OrigamiElevatedAccessBase.sol";

/**
 * @notice Inherit to add Owner roles for DAO elevated access.
 */ 
abstract contract OrigamiElevatedAccess is OrigamiElevatedAccessBase {
    constructor(address initialOwner) {
        _init(initialOwner);
    }
}

pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (common/access/OrigamiElevatedAccessBase.sol)

import { IOrigamiElevatedAccess } from "contracts/interfaces/common/access/IOrigamiElevatedAccess.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";

/**
 * @notice Inherit to add Owner roles for DAO elevated access.
 */ 
abstract contract OrigamiElevatedAccessBase is IOrigamiElevatedAccess {
    /**
     * @notice The address of the current owner.
     */ 
    address public override owner;

    /**
     * @notice Explicit approval for an address to execute a function.
     * allowedCaller => function selector => true/false
     */
    mapping(address => mapping(bytes4 => bool)) public override explicitFunctionAccess;

    /// @dev Track proposed owner
    address private _proposedNewOwner;

    /// @dev propose this as the new owner before revoking, for 2 step approval
    address private constant PROPOSED_DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function _init(address initialOwner) internal {
        if (owner != address(0)) revert CommonEventsAndErrors.InvalidAccess();
        if (initialOwner == address(0)) revert CommonEventsAndErrors.InvalidAddress(address(0));
        owner = initialOwner;
    }

    /**
     * @notice Revoke ownership. 
     * @dev To enforce a two-step revoke, it must first propose to 0x000...dEaD prior to calling.
     * This cannot be undone.
     */
    function revokeOwnership() external override onlyElevatedAccess {
        if (_proposedNewOwner != PROPOSED_DEAD_ADDRESS) revert CommonEventsAndErrors.InvalidAddress(_proposedNewOwner);

        emit NewOwnerAccepted(owner, address(0));
        owner = address(0);
    }

    /**
     * @notice Proposes a new Owner.
     * Can only be called by the current owner
     */
    function proposeNewOwner(address account) external override onlyElevatedAccess {
        if (account == address(0)) revert CommonEventsAndErrors.InvalidAddress(account);
        emit NewOwnerProposed(owner, _proposedNewOwner, account);
        _proposedNewOwner = account;
    }

    /**
     * @notice Caller accepts the role as new Owner.
     * Can only be called by the proposed owner
     */
    function acceptOwner() external override {
        if (msg.sender != _proposedNewOwner) revert CommonEventsAndErrors.InvalidAccess();

        emit NewOwnerAccepted(owner, msg.sender);
        owner = msg.sender;
        delete _proposedNewOwner;
    }

    /**
     * @notice Grant `allowedCaller` the rights to call the function selectors in the access list.
     * @dev fnSelector == bytes4(keccak256("fn(argType1,argType2,...)"))
     */
    function setExplicitAccess(address allowedCaller, ExplicitAccess[] calldata access) external override onlyElevatedAccess {
        if (allowedCaller == address(0)) revert CommonEventsAndErrors.InvalidAddress(allowedCaller);
        ExplicitAccess memory _access;
        for (uint256 i; i < access.length; ++i) {
            _access = access[i];
            emit ExplicitAccessSet(allowedCaller, _access.fnSelector, _access.allowed);
            explicitFunctionAccess[allowedCaller][_access.fnSelector] = _access.allowed;
        }
    }

    function isElevatedAccess(address caller, bytes4 fnSelector) internal view returns (bool) {
        return (
            caller == owner || 
            explicitFunctionAccess[caller][fnSelector]
        );
    }

    /**
     * @notice The owner is allowed to call, or if explicit access has been given to the caller.
     * @dev Important: Only for use when called from an *external* contract. 
     * If a function with this modifier is called internally then the `msg.sig` 
     * will still refer to the top level externally called function.
     */
    modifier onlyElevatedAccess() {
        if (!isElevatedAccess(msg.sender, msg.sig)) revert CommonEventsAndErrors.InvalidAccess();
        _;
    }
}

pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (common/swappers/OrigamiCowSwapper.sol)

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

import { IConditionalOrder } from "contracts/interfaces/external/cowprotocol/IConditionalOrder.sol";
import { GPv2Order } from "contracts/external/cowprotocol/GPv2Order.sol";

import { IOrigamiCowSwapper } from "contracts/interfaces/common/swappers/IOrigamiCowSwapper.sol";
import { IOrigamiOracle } from "contracts/interfaces/common/oracle/IOrigamiOracle.sol";
import { OrigamiElevatedAccess } from "contracts/common/access/OrigamiElevatedAccess.sol";
import { OrigamiMath } from "contracts/libraries/OrigamiMath.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";

/**
 * @title Origami Cow Swapper
 * @notice A contract to emit events and implement the correct flow for CoW swap conditional orders.
 * @dev Either LIMIT or MARKET orders can be placed by setting the relevant config
 */
contract OrigamiCowSwapper is IOrigamiCowSwapper, OrigamiElevatedAccess {
    using SafeERC20 for IERC20; 
    using GPv2Order for GPv2Order.Data;
    using OrigamiMath for uint256;

    /// @inheritdoc IOrigamiCowSwapper
    address public override immutable cowSwapRelayer;

    /// @inheritdoc IOrigamiCowSwapper
    bool public override isPaused;

    /// @notice The order configuration details used to create any new discrete orders for a given sellToken
    mapping(IERC20 sellToken => OrderConfig config) private _orderConfig;

    /// @notice For certain issues with the conditional orders, then a hint can be given
    /// to the CoW swap Watchtower so it can delay querying for more orders for this period.
    uint256 private constant ORDER_DELAY_SECONDS = 300;

    constructor(
        address _initialOwner,
        address _cowSwapRelayer
    ) OrigamiElevatedAccess(_initialOwner) {
        cowSwapRelayer = _cowSwapRelayer;
    }
    
    /// @inheritdoc IOrigamiCowSwapper
    function setPaused(bool paused) external override onlyElevatedAccess {
        isPaused = paused;
        emit PausedSet(paused);
    }

    /// @inheritdoc IOrigamiCowSwapper
    function setCowApproval(address sellToken, uint256 amount) external override onlyElevatedAccess {
        // No need to check if this sellToken is configured or not - this function may
        // be called after the order config has been removed already (or before it is configured in the first place)
        IERC20(sellToken).forceApprove(cowSwapRelayer, amount);
    }

    /// @inheritdoc IOrigamiCowSwapper
    function setOrderConfig(
        address sellToken, 
        OrderConfig calldata config
    ) external override onlyElevatedAccess {
        if (sellToken == address(0)) revert CommonEventsAndErrors.InvalidAddress(sellToken);
        if (address(config.buyToken) == address(0)) revert CommonEventsAndErrors.InvalidAddress(address(config.buyToken));
        if (sellToken == address(config.buyToken)) revert CommonEventsAndErrors.InvalidAddress(address(config.buyToken));

        if (config.maxSellAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();
        if (config.minBuyAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();

        if (address(config.limitPriceOracle) != address(0)) {
            // If the price oracle is set, then the assets must match
            if (!config.limitPriceOracle.matchAssets(sellToken, address(config.buyToken)))
                revert CommonEventsAndErrors.InvalidParam();
        } else {
            // If the price oracle is not set, then there should not be a limitPricePremiumBps
            if (config.limitPricePremiumBps > 0) revert CommonEventsAndErrors.InvalidParam();
        }

        if (config.recipient == address(0)) revert CommonEventsAndErrors.InvalidAddress(config.recipient);
        if (config.verifySlippageBps > OrigamiMath.BASIS_POINTS_DIVISOR) revert CommonEventsAndErrors.InvalidParam();
        if (config.expiryPeriodSecs == 0) revert CommonEventsAndErrors.ExpectedNonZero();
        if (config.expiryPeriodSecs > 7 days) revert CommonEventsAndErrors.InvalidParam();

        _orderConfig[IERC20(sellToken)] = config;
        emit OrderConfigSet(sellToken);
    }

    /// @inheritdoc IOrigamiCowSwapper
    function removeOrderConfig(address sellToken) external override onlyElevatedAccess {
        // Checking if it exists in the mapping already isn't necessary.
        delete _orderConfig[IERC20(sellToken)];
        emit OrderConfigRemoved(sellToken);
    }

    /// @inheritdoc IOrigamiCowSwapper
    function updateAmountsAndPremiumBps(
        address sellToken, 
        uint96 maxSellAmount,
        uint96 minBuyAmount,
        uint16 limitPricePremiumBps
    ) external override onlyElevatedAccess { 
        if (maxSellAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();
        if (minBuyAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();

        // Ensure it's configured first.
        OrderConfig storage config = _getOrderConfig(IERC20(sellToken));

        // If the price oracle is not set, then there should not be a limitPricePremiumBps
        if (address(config.limitPriceOracle) == address(0)) {
            if (limitPricePremiumBps > 0) revert CommonEventsAndErrors.InvalidParam();
        }

        config.maxSellAmount = maxSellAmount;
        config.minBuyAmount = minBuyAmount;
        config.limitPricePremiumBps = limitPricePremiumBps;

        emit OrderConfigSet(sellToken);
    }

    /**
     * @notice Recover any token
     * @dev The default implementaiton allows elevated access to recover any token. This may need
     * to be restricted for specific implementations (eg restricted from pulling vault reserve tokens)
     * @param token Token to recover
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function recoverToken(address token, address to, uint256 amount) external virtual onlyElevatedAccess {
        emit CommonEventsAndErrors.TokenRecovered(to, token, amount);
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice IOrigamiCowSwapper
     */
    function createConditionalOrder(address sellToken) external override onlyElevatedAccess {
        if (isPaused) revert CommonEventsAndErrors.IsPaused();

        // Ensure it's configured first.
        _getOrderConfig(IERC20(sellToken));

        // Owner is the key of a hashmap in Watchtower - an owner may emit multiple ConditionalOrderParams events
        // It is also passed into getTradeableOrderWithSignature() when creating discrete orders.
        address orderOwner = address(this);

        // The 'handler' isn't in this contract or watchtower. 
        // It's intended for use with the more complex ComposableCow framework they provide
        address handler = address(0);

        // The salt is unused - there will only be one valid conditional order per sellToken
        // at a time.
        // If the ConditionalOrderCreated event is emitted with the same parameters, 
        // there's no issue - Watchtower skips adding into it's registry again if the params
        // are the same
        // https://github.com/cowprotocol/watch-tower/blob/90ecbf5de87447657a36dfcd49a714b1b5105380/src/domain/events/index.ts#L206
        bytes32 conditionalOrderSalt = bytes32(0);

        // Encode the sellToken as the static input - it's the unique key used
        // for order creation and validation.
        bytes memory staticInput = abi.encode(sellToken);

        // The following event will be pickd up by the watchtower offchain
        // service, which is responsible for automatically posting CoW AMM
        // orders on the CoW Protocol orderbook.
        // See: https://github.com/cowprotocol/watch-tower/blob/90ecbf5de87447657a36dfcd49a714b1b5105380/src/domain/events/index.ts#L105
        emit IConditionalOrder.ConditionalOrderCreated(
            orderOwner,
            IConditionalOrder.ConditionalOrderParams(
                handler,
                conditionalOrderSalt,
                staticInput
            )
        );
    }

    /**
     * @inheritdoc IConditionalOrder
     */
    function getTradeableOrderWithSignature(
        address orderOwner,
        IConditionalOrder.ConditionalOrderParams calldata params,
        // Unused by watchtower
        // https://github.com/cowprotocol/watch-tower/blob/90ecbf5de87447657a36dfcd49a714b1b5105380/src/domain/polling/index.ts#L309
        bytes calldata /*offchainInput*/, 
        // Unused when using conditional orders directly (as opposed to via Safe)
        bytes32[] calldata /*proof*/
    ) external override view returns (
        GPv2Order.Data memory order, 
        bytes memory signature
    ) {
        // If the contract is paused, then give a hint to Watchtower to try again in 
        // ORDER_DELAY_SECONDS
        if (isPaused) revert PollTryAtEpoch(block.timestamp + ORDER_DELAY_SECONDS, "Paused");

        // Should match the orderOwner set in createConditionalOrder()
        if (orderOwner != address(this)) {
            revert OrderNotValid("order owner must be self");
        }

        // Should match the handler set in createConditionalOrder()
        // The order creation isn't delegated.
        if (address(params.handler) != address(0)) {
            revert OrderNotValid("handler must be unset");
        }

        // Should match the salt set in createConditionalOrder()
        if (params.salt != bytes32(0)) {
            revert OrderNotValid("salt must be unset");
        }

        // Ensure we have setup this sellToken
        IERC20 sellToken = abi.decode(params.staticInput, (IERC20));
        OrderConfig storage config = _orderConfig[sellToken];
        if (address(config.buyToken) == address(0)) {
            revert OrderNotValid("sellToken not configured");
        }

        // If no balance at all, then give a hint to Watchtower to try again in
        // ORDER_DELAY_SECONDS
        uint256 sellTokenBalance = sellToken.balanceOf(address(this));
        if (sellTokenBalance == 0) {
            revert PollTryAtEpoch(block.timestamp + ORDER_DELAY_SECONDS, "ZeroBalance");
        }

        uint256 sellAmount = _getSellAmount(
            config.maxSellAmount, 
            config.useCurrentBalanceForSellAmount, 
            sellTokenBalance
        );

        (, uint256 roundedBuyAmount) = _getBuyAmount(sellToken, sellAmount, config);
        order = _getDiscreteOrder(sellToken, sellAmount, config, roundedBuyAmount);
        signature = abi.encode(order);
    }

    /**
     * @notice Returns whether the signature provided is for a valid order as of the block it's called
     * @param signature Signature byte array, encoding the submitted GPv2Order.Data
     * @dev This function is called by the CoW swap settlement contract.
     *
     * This verify step needs to protect against unintentional/malicious orders being placed.
     * However if using a price oracle for limit orders, the buyAmount may have changed between when the (legitimate) 
     * order was placed versus this function being called by the CoW swap solvers during settlement to verify the 
     * order signature.
     *
     * - If the latest calculated buyAmount is LESS THAN the buyAmount of the originally placed order, that's ok.
     *   That original order is simply unlikely to be filled but if it does, that's an ok result.
     *   That out of the money order will expire and be replaced in the next validTo (aka expiry) period anyway.
     * - If the latest calculated buyAmount is MORE THAN the buyAmount of the originally placed order, 
     *   that is ok but ONLY WITHIN A `verifySlippageBps` TOLERANCE. It will revert if outside of this tolerance
     *   If the original order is priced a lot lower, we will get a fill for less that what we are truly looking for, 
     *   potentially at a loss (depending on the application)
     * 
     * No need to verify the `hash`, as this is constructed by the Settlement contract before this function is called.
     * https://github.com/cowprotocol/contracts/blob/5957d67d69df231c6a879ec7b64806181c86ebb6/src/contracts/mixins/GPv2Signing.sol#L156
     * It's also ignored in Curve's CowSwapBurner
     */
    function isValidSignature(bytes32 /*hash*/, bytes memory signature) external override view returns (bytes4) {
        // A revert here simply means the swap cannot be executed by a solver. The actual behaviour of that
        // order is then not defined. Best case it's picked up again in the next auction, worst case is that
        // the order is dropped by solvers. That's ok as we submit a new order in the next expiry window anyway.
        if (isPaused) revert CommonEventsAndErrors.IsPaused();

        (GPv2Order.Data memory order) = abi.decode(signature, (GPv2Order.Data));
        OrderConfig storage config = _getOrderConfig(order.sellToken);

        // Can use any sellAmount (from the decoded order) as long as it's under the
        // configured maxSellAmount
        // This does mean it's possible for a smaller order to be placed by anyone outside of getTradeableOrderWithSignature(),
        // but the minBuyAmount puts a floor on what is eligable to be filled. CoW Solvers will fill at the best price anyway since
        // it's a competitive auction.
        uint256 maxSellAmount = config.maxSellAmount;
        uint256 sellAmount = order.sellAmount < maxSellAmount ? order.sellAmount : maxSellAmount;

        // Calculate the latest buyAmount as of now, using that sellAmount
        (, uint256 latestRoundedBuyAmount) = _getBuyAmount(order.sellToken, sellAmount, config);

        // If the latest rounded buyAmount is greater than when the order is placed plus some slippage tolerance
        // then revert.
        //
        // Note: Because this (rounded) buyAmount will be in discrete steps, when the order is verified it might have moved to the next
        // divisor, which may cause it to be outside the slippage tolerance suddenly. This is ok and as expected; The 
        // order configuration just needs to take this into consideration:
        //   a/ The `verifySlippageBps` can be set a little larger than the effect of `roundDownDivisor` on that notional; or
        //   b/ The `roundDownDivisor` can be reduced; or
        //   c/ That particular order is now just deemed invalid, so will attempt again at the next expiry window.
        uint256 verifySlippageBps = config.verifySlippageBps;
        uint256 orderBuyAmountWithSlippage = (verifySlippageBps > 0)
            ? order.buyAmount.addBps(verifySlippageBps, OrigamiMath.Rounding.ROUND_DOWN)
            : order.buyAmount;

        if (latestRoundedBuyAmount > orderBuyAmountWithSlippage) {
            revert CommonEventsAndErrors.Slippage(orderBuyAmountWithSlippage, latestRoundedBuyAmount);
        }

        // Re-generate the order for the original amount and compare the hash.
        GPv2Order.Data memory generatedOrder = _getDiscreteOrder(order.sellToken, sellAmount, config, order.buyAmount);

        // All other fields in the generated order should be the same as in the signature.
        if (keccak256(abi.encode(generatedOrder)) != keccak256(signature)) {
            revert OrderDoesNotMatchTradeableOrder();
        }
        
        return this.isValidSignature.selector;
    }

    /**
     * @notice IOrigamiCowSwapper
     */
    function orderConfig(address sellToken) external override view returns (OrderConfig memory config) {
        return _orderConfig[IERC20(sellToken)];
    }

    /**
     * @notice IOrigamiCowSwapper
     */
    function getSellAmount(address sellToken) external override view returns (uint256) {
        IERC20 _sellToken = IERC20(sellToken);
        OrderConfig storage config = _getOrderConfig(_sellToken);
        return _getSellAmount(
            config.maxSellAmount, 
            config.useCurrentBalanceForSellAmount, 
            _sellToken.balanceOf(address(this))
        );
    }

    /**
     * @notice IOrigamiCowSwapper
     */
    function getBuyAmount(address sellToken) external override view returns (uint256 unroundedBuyAmount, uint256 roundedBuyAmount) {
        IERC20 _sellToken = IERC20(sellToken);
        OrderConfig storage config = _getOrderConfig(_sellToken);
        return _getBuyAmount(_sellToken, config.maxSellAmount, config);
    }

    /*
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external override pure returns (bool) {
        return interfaceId == type(IOrigamiCowSwapper).interfaceId
            || interfaceId == type(IConditionalOrder).interfaceId 
            || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC1271).interfaceId;
    }

    function _getSellAmount(
        uint256 maxSellAmount,
        bool useCurrentBalanceForSellAmount,
        uint256 sellTokenBalance
    ) internal pure returns (uint256 sellAmount) {
        // Capped by the maxSellAmount
        return useCurrentBalanceForSellAmount
            ? (sellTokenBalance < maxSellAmount ? sellTokenBalance : maxSellAmount)
            : maxSellAmount;
    }

    /**
     * @dev Calculate the buyAmount for a CoW swap order as of now, for a given sellToken
     * If applyRoundingDown, then the final amount will be rounded down to the 
     * configured power of 10.
     * This ensures that small changes in price block to block don't end up
     * in a lot of new orders being placed.
     */
    function _getBuyAmount(
        IERC20 sellToken,
        uint256 sellAmount,
        OrderConfig storage config
    ) internal view returns (uint256 unroundedBuyAmount, uint256 roundedBuyAmount) {
        IOrigamiOracle limitPriceOracle = config.limitPriceOracle;
        // ROUND_DOWN is fine in all cases as this is just the limit order price
        if (address(limitPriceOracle) != address(0)) {
            // Similarly minor precision loss from transient divisions in these calcs are also
            // acceptable.
            unroundedBuyAmount = config.limitPriceOracle.convertAmount(
                address(sellToken),
                sellAmount,
                IOrigamiOracle.PriceType.SPOT_PRICE,
                OrigamiMath.Rounding.ROUND_DOWN
            );

            // Add the premium to the buyToken amount
            uint256 limitPricePremiumBps = config.limitPricePremiumBps;
            if (limitPricePremiumBps > 0) {
                unroundedBuyAmount = unroundedBuyAmount.addBps(config.limitPricePremiumBps, OrigamiMath.Rounding.ROUND_DOWN);
            }
        }

        // Use the maximum of the two minimums (the one oracle derived buyAmount and the min set in config).  
        uint256 minBuyAmount = config.minBuyAmount;
        unroundedBuyAmount = (minBuyAmount > unroundedBuyAmount) ? minBuyAmount : unroundedBuyAmount;

        // Intentionally lose precision when rounding down to the nearest divisor.
        uint256 divisor = config.roundDownDivisor;
        roundedBuyAmount = (divisor > 0)
            ? (unroundedBuyAmount / divisor) * divisor
            : unroundedBuyAmount;

        if (roundedBuyAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();
    }
    
    function _getOrderConfig(IERC20 sellToken) internal view returns (OrderConfig storage config) {
        config = _orderConfig[sellToken];
        if (address(config.buyToken) == address(0)) revert InvalidSellToken(address(sellToken));
    }

    function _getDiscreteOrder(
        IERC20 sellToken, 
        uint256 sellAmount,
        OrderConfig storage config, 
        uint256 buyAmount
    ) internal view returns (GPv2Order.Data memory) {
        return GPv2Order.Data({
            sellToken: sellToken,
            buyToken: config.buyToken,
            receiver: config.recipient,
            sellAmount: sellAmount,
            buyAmount: buyAmount,
            validTo: _calcOrderExpiry(config.expiryPeriodSecs),
            appData: config.appData,
            feeAmount:0,
            kind: GPv2Order.KIND_SELL,
            partiallyFillable: config.partiallyFillable,
            sellTokenBalance: GPv2Order.BALANCE_ERC20,
            buyTokenBalance: GPv2Order.BALANCE_ERC20
        });
    }

    /**
     * @notice Calculate the expiry time (unix) given an expiryPeriodSecs time window.
     * `expiryPeriodSecs=300 seconds` means that an order as of 13:45:15 UTC will have an expiry
     * of the nearest 5 minute boundary, so 13:50:00 UTC
     * @dev There is a minimun of 90 seconds until the next order expiry, so with the example above
     * 13:48:45 order time will have an expiry of 13:55:00 UTC
     */
    function _calcOrderExpiry(uint32 expiryPeriodSecs) internal view returns (uint32) {
        // slither-disable-next-line divide-before-multiply
        return (
            (uint32(block.timestamp) / expiryPeriodSecs) * expiryPeriodSecs
        ) + expiryPeriodSecs;
    }
}

// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.7.6 <0.9.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @note Forked from https://github.com/cowprotocol/contracts/blob/main/src/contracts/libraries/GPv2Order.sol

/// @title Gnosis Protocol v2 Order Library
/// @author Gnosis Developers
library GPv2Order {
    /// @dev The complete data for a Gnosis Protocol order. This struct contains
    /// all order parameters that are signed for submitting to GP.
    struct Data {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint256 sellAmount;
        uint256 buyAmount;
        uint32 validTo;
        bytes32 appData;
        uint256 feeAmount;
        bytes32 kind;
        bool partiallyFillable;
        bytes32 sellTokenBalance;
        bytes32 buyTokenBalance;
    }

    /// @dev The order EIP-712 type hash for the [`GPv2Order.Data`] struct.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256(
    ///     "Order(" +
    ///         "address sellToken," +
    ///         "address buyToken," +
    ///         "address receiver," +
    ///         "uint256 sellAmount," +
    ///         "uint256 buyAmount," +
    ///         "uint32 validTo," +
    ///         "bytes32 appData," +
    ///         "uint256 feeAmount," +
    ///         "string kind," +
    ///         "bool partiallyFillable," +
    ///         "string sellTokenBalance," +
    ///         "string buyTokenBalance" +
    ///     ")"
    /// )
    /// ```
    bytes32 internal constant TYPE_HASH =
        hex"d5a25ba2e97094ad7d83dc28a6572da797d6b3e7fc6663bd93efb789fc17e489";

    /// @dev The marker value for a sell order for computing the order struct
    /// hash. This allows the EIP-712 compatible wallets to display a
    /// descriptive string for the order kind (instead of 0 or 1).
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("sell")
    /// ```
    bytes32 internal constant KIND_SELL =
        hex"f3b277728b3fee749481eb3e0b3b48980dbbab78658fc419025cb16eee346775";

    /// @dev The OrderKind marker value for a buy order for computing the order
    /// struct hash.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("buy")
    /// ```
    bytes32 internal constant KIND_BUY =
        hex"6ed88e868af0a1983e3886d5f3e95a2fafbd6c3450bc229e27342283dc429ccc";

    /// @dev The TokenBalance marker value for using direct ERC20 balances for
    /// computing the order struct hash.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("erc20")
    /// ```
    bytes32 internal constant BALANCE_ERC20 =
        hex"5a28e9363bb942b639270062aa6bb295f434bcdfc42c97267bf003f272060dc9";

    /// @dev The TokenBalance marker value for using Balancer Vault external
    /// balances (in order to re-use Vault ERC20 approvals) for computing the
    /// order struct hash.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("external")
    /// ```
    bytes32 internal constant BALANCE_EXTERNAL =
        hex"abee3b73373acd583a130924aad6dc38cfdc44ba0555ba94ce2ff63980ea0632";

    /// @dev The TokenBalance marker value for using Balancer Vault internal
    /// balances for computing the order struct hash.
    ///
    /// This value is pre-computed from the following expression:
    /// ```
    /// keccak256("internal")
    /// ```
    bytes32 internal constant BALANCE_INTERNAL =
        hex"4ac99ace14ee0a5ef932dc609df0943ab7ac16b7583634612f8dc35a4289a6ce";

    /// @dev Marker address used to indicate that the receiver of the trade
    /// proceeds should the owner of the order.
    ///
    /// This is chosen to be `address(0)` for gas efficiency as it is expected
    /// to be the most common case.
    address internal constant RECEIVER_SAME_AS_OWNER = address(0);

    /// @dev The byte length of an order unique identifier.
    uint256 internal constant UID_LENGTH = 56;

    /// @dev Returns the actual receiver for an order. This function checks
    /// whether or not the [`receiver`] field uses the marker value to indicate
    /// it is the same as the order owner.
    ///
    /// @return receiver The actual receiver of trade proceeds.
    function actualReceiver(
        Data memory order,
        address owner
    ) internal pure returns (address receiver) {
        if (order.receiver == RECEIVER_SAME_AS_OWNER) {
            receiver = owner;
        } else {
            receiver = order.receiver;
        }
    }

    /// @dev Return the EIP-712 signing hash for the specified order.
    ///
    /// @param order The order to compute the EIP-712 signing hash for.
    /// @param domainSeparator The EIP-712 domain separator to use.
    /// @return orderDigest The 32 byte EIP-712 struct hash.
    function hash(
        Data memory order,
        bytes32 domainSeparator
    ) internal pure returns (bytes32 orderDigest) {
        bytes32 structHash;

        // NOTE: Compute the EIP-712 order struct hash in place. As suggested
        // in the EIP proposal, noting that the order struct has 12 fields, and
        // prefixing the type hash `(1 + 12) * 32 = 416` bytes to hash.
        // <https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#rationale-for-encodedata>
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let dataStart := sub(order, 32)
            let temp := mload(dataStart)
            mstore(dataStart, TYPE_HASH)
            structHash := keccak256(dataStart, 416)
            mstore(dataStart, temp)
        }

        // NOTE: Now that we have the struct hash, compute the EIP-712 signing
        // hash using scratch memory past the free memory pointer. The signing
        // hash is computed from `"\x19\x01" || domainSeparator || structHash`.
        // <https://docs.soliditylang.org/en/v0.7.6/internals/layout_in_memory.html#layout-in-memory>
        // <https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#specification>
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let freeMemoryPointer := mload(0x40)
            mstore(freeMemoryPointer, "\x19\x01")
            mstore(add(freeMemoryPointer, 2), domainSeparator)
            mstore(add(freeMemoryPointer, 34), structHash)
            orderDigest := keccak256(freeMemoryPointer, 66)
        }
    }

    /// @dev Packs order UID parameters into the specified memory location. The
    /// result is equivalent to `abi.encodePacked(...)` with the difference that
    /// it allows re-using the memory for packing the order UID.
    ///
    /// This function reverts if the order UID buffer is not the correct size.
    ///
    /// @param orderUid The buffer pack the order UID parameters into.
    /// @param orderDigest The EIP-712 struct digest derived from the order
    /// parameters.
    /// @param owner The address of the user who owns this order.
    /// @param validTo The epoch time at which the order will stop being valid.
    function packOrderUidParams(
        bytes memory orderUid,
        bytes32 orderDigest,
        address owner,
        uint32 validTo
    ) internal pure {
        require(orderUid.length == UID_LENGTH, "GPv2: uid buffer overflow");

        // NOTE: Write the order UID to the allocated memory buffer. The order
        // parameters are written to memory in **reverse order** as memory
        // operations write 32-bytes at a time and we want to use a packed
        // encoding. This means, for example, that after writing the value of
        // `owner` to bytes `20:52`, writing the `orderDigest` to bytes `0:32`
        // will **overwrite** bytes `20:32`. This is desirable as addresses are
        // only 20 bytes and `20:32` should be `0`s:
        //
        //        |           1111111111222222222233333333334444444444555555
        //   byte | 01234567890123456789012345678901234567890123456789012345
        // -------+---------------------------------------------------------
        //  field | [.........orderDigest..........][......owner.......][vT]
        // -------+---------------------------------------------------------
        // mstore |                         [000000000000000000000000000.vT]
        //        |                     [00000000000.......owner.......]
        //        | [.........orderDigest..........]
        //
        // Additionally, since Solidity `bytes memory` are length prefixed,
        // 32 needs to be added to all the offsets.
        //
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(add(orderUid, 56), validTo)
            mstore(add(orderUid, 52), owner)
            mstore(add(orderUid, 32), orderDigest)
        }
    }

    /// @dev Extracts specific order information from the standardized unique
    /// order id of the protocol.
    ///
    /// @param orderUid The unique identifier used to represent an order in
    /// the protocol. This uid is the packed concatenation of the order digest,
    /// the validTo order parameter and the address of the user who created the
    /// order. It is used by the user to interface with the contract directly,
    /// and not by calls that are triggered by the solvers.
    /// @return orderDigest The EIP-712 signing digest derived from the order
    /// parameters.
    /// @return owner The address of the user who owns this order.
    /// @return validTo The epoch time at which the order will stop being valid.
    function extractOrderUidParams(
        bytes calldata orderUid
    )
        internal
        pure
        returns (bytes32 orderDigest, address owner, uint32 validTo)
    {
        require(orderUid.length == UID_LENGTH, "GPv2: invalid uid");

        // Use assembly to efficiently decode packed calldata.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            orderDigest := calldataload(orderUid.offset)
            owner := shr(96, calldataload(add(orderUid.offset, 32)))
            validTo := shr(224, calldataload(add(orderUid.offset, 52)))
        }
    }
}

pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (interfaces/common/access/IOrigamiElevatedAccess.sol)

/**
 * @notice Inherit to add Owner roles for DAO elevated access.
 */ 
interface IOrigamiElevatedAccess {
    event ExplicitAccessSet(address indexed account, bytes4 indexed fnSelector, bool indexed value);

    event NewOwnerProposed(address indexed oldOwner, address indexed oldProposedOwner, address indexed newProposedOwner);
    event NewOwnerAccepted(address indexed oldOwner, address indexed newOwner);

    struct ExplicitAccess {
        bytes4 fnSelector;
        bool allowed;
    }

    /**
     * @notice The address of the current owner.
     */ 
    function owner() external view returns (address);

    /**
     * @notice Explicit approval for an address to execute a function.
     * allowedCaller => function selector => true/false
     */
    function explicitFunctionAccess(address contractAddr, bytes4 functionSelector) external view returns (bool);

    /**
     * @notice Revoke ownership. Be very certain before calling this, as no
     * further elevated access can be called.
     */
    function revokeOwnership() external;

    /**
     * @notice Proposes a new Owner.
     * Can only be called by the current owner
     */
    function proposeNewOwner(address account) external;

    /**
     * @notice Caller accepts the role as new Owner.
     * Can only be called by the proposed owner
     */
    function acceptOwner() external;

    /**
     * @notice Grant `allowedCaller` the rights to call the function selectors in the access list.
     * @dev fnSelector == bytes4(keccak256("fn(argType1,argType2,...)"))
     */
    function setExplicitAccess(address allowedCaller, ExplicitAccess[] calldata access) external;
}

pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (interfaces/common/oracle/IOrigamiOracle.sol)

import { OrigamiMath } from "contracts/libraries/OrigamiMath.sol";

/**
 * @notice An oracle which returns prices for pairs of assets, where an asset
 * could refer to a token (eg DAI) or a currency (eg USD)
 * Convention is the same as the FX market. Given the DAI/USD pair:
 *   - DAI = Base Asset (LHS of pair)
 *   - USD = Quote Asset (RHS of pair)
 * This price defines how many USD you get if selling 1 DAI
 *
 * Further, an oracle can define two PriceType's:
 *   - SPOT_PRICE: The latest spot price, for example from a chainlink oracle
 *   - HISTORIC_PRICE: An expected (eg 1:1 peg) or calculated historic price (eg TWAP)
 *
 * For assets which do are not tokens (eg USD), an internal address reference will be used
 * since this is for internal purposes only
 */
interface IOrigamiOracle {
    error InvalidPrice(address oracle, int256 price);
    error InvalidOracleData(address oracle);
    error StalePrice(address oracle, uint256 lastUpdatedAt, int256 price);
    error UnknownPriceType(uint8 priceType);
    error BelowMinValidRange(address oracle, uint256 price, uint128 floor);
    error AboveMaxValidRange(address oracle, uint256 price, uint128 ceiling);

    event ValidPriceRangeSet(uint128 validFloor, uint128 validCeiling);

    enum PriceType {
        /// @notice The current spot price of this Oracle
        SPOT_PRICE,

        /// @notice The historic price of this Oracle. 
        /// It may be a fixed expectation (eg DAI/USD would be fixed to 1)
        /// or use a TWAP or some other moving average, etc.
        HISTORIC_PRICE
    }

    /**
     * @dev Wrapped in a struct to remove stack-too-deep constraints
     */
    struct BaseOracleParams {
        string description;
        address baseAssetAddress;
        uint8 baseAssetDecimals;
        address quoteAssetAddress;
        uint8 quoteAssetDecimals;
    }

    /**
     * @notice The address used to reference the baseAsset for amount conversions
     */
    function baseAsset() external view returns (address);

    /**
     * @notice The address used to reference the quoteAsset for amount conversions
     */
    function quoteAsset() external view returns (address);

    /**
     * @notice The number of decimals of precision the price is returned as
     */
    function decimals() external view returns (uint8);

    /**
     * @notice The precision that the cross rate oracle price is returned as: `10^decimals`
     */
    function precision() external view returns (uint256);

    /**
     * @notice A human readable description for this oracle
     */
    function description() external view returns (string memory);

    /**
     * @notice Return the latest oracle price, to `decimals` precision
     * @dev This may still revert - eg if deemed stale, div by 0, negative price
     * @param priceType What kind of price - Spot or Historic
     * @param roundingMode Round the price at each intermediate step such that the final price rounds in the specified direction.
     */
    function latestPrice(
        PriceType priceType, 
        OrigamiMath.Rounding roundingMode
    ) external view returns (uint256 price);

    /**
     * @notice Same as `latestPrice()` but for two separate prices from this oracle	
     */
    function latestPrices(
        PriceType priceType1, 
        OrigamiMath.Rounding roundingMode1,
        PriceType priceType2, 
        OrigamiMath.Rounding roundingMode2
    ) external view returns (
        uint256 price1, 
        uint256 price2, 
        address oracleBaseAsset,
        address oracleQuoteAsset
    );

    /**
     * @notice Convert either the baseAsset->quoteAsset or quoteAsset->baseAsset
     * @dev The `fromAssetAmount` needs to be in it's natural fixed point precision (eg USDC=6dp)
     * The `toAssetAmount` will also be returned in it's natural fixed point precision
     */
    function convertAmount(
        address fromAsset,
        uint256 fromAssetAmount,
        PriceType priceType,
        OrigamiMath.Rounding roundingMode
    ) external view returns (uint256 toAssetAmount);

    /**
     * @notice Match whether a pair of assets match the base and quote asset on this oracle, in either order
     */
    function matchAssets(address asset1, address asset2) external view returns (bool);
}

pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (interfaces/common/swappers/IOrigamiCowSwapper.sol)

import { IConditionalOrder } from "contracts/interfaces/external/cowprotocol/IConditionalOrder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IOrigamiOracle } from "contracts/interfaces/common/oracle/IOrigamiOracle.sol";

/**
 * @title Origami Cow Swapper
 * @notice A contract to emit events and implement the correct flow for CoW swap conditional orders
 */
interface IOrigamiCowSwapper is IConditionalOrder {
    event OrderConfigSet(address indexed sellToken);
    event OrderConfigRemoved(address indexed sellToken);
    event PausedSet(bool paused);

    /**
     * @notice On signature verification, the order within the signature does not match
     * the current tradeable order
     */
    error OrderDoesNotMatchTradeableOrder();

    /**
     * @notice This sellToken does not have an order configured.
     */
    error InvalidSellToken(address sellToken);

    /**
     * @notice The order configuration details used to create any new discrete orders for a given sellToken
     * @dev byte packed into 5x slots
     * NB: There's an opportunity for gas golfing here by packing into custom types - may revisit in future
     * iterations (adds extra complexity around encoding/decoding)
     */
    struct OrderConfig {
        /// @dev The amount of sellToken to place an order for
        /// MUST be > 0
        /// This can be set to a higher amount than the current balance the contract holds.
        /// CoW swap will still work and sell as much as it can, up until the order expiry.
        uint96 maxSellAmount;

        /// @dev The IERC20 token to buy.
        /// MUST NOT be address(0)
        /// MUST NOT be the same as `sellToken`
        IERC20 buyToken;

        // ---- END SLOT 1

        /// @dev The minimum amount of buyToken to purchase in the order
        /// Note this is total order size, not each individual fill
        /// MUST be > 0
        uint96 minBuyAmount;

        /// @dev The origami oracle to lookup the limit order price.
        /// Not used if set to address(0)
        IOrigamiOracle limitPriceOracle;

        // ---- END SLOT 2

        /// @dev The receiver of buyToken's on each fill.
        address recipient;

        /// @dev When specifying the order for watchtower, the buyAmount is rounded down to
        /// the nearest specified divisor.
        /// This is to ensure we have discrete unique orders, rather than spamming CoW swap with slightly
        /// different orders (which may get us on the deny list)
        /// Specified in full precision in the buyToken decimals
        /// Eg if buyToken is 18dp, to round down to the nearest 50 tokens, set this to 50e18
        /// Not used if set to zero
        uint96 roundDownDivisor;

        // ---- END SLOT 3

        /// @dev True if partial fills are ok, false for a 'fill or kill'
        bool partiallyFillable;

        /// @dev Set to true to use the current contract balance of sellToken for the
        /// sell amount, with a cap of maxSellAmount
        bool useCurrentBalanceForSellAmount;

        /// @dev How many basis points premium above the `limitPriceOracle` is the limit order set.
        /// Not used if set to zero
        uint16 limitPricePremiumBps;

        /// @dev The acceptable slippage (in basis points) to the unrounded buyAmount between
        /// T1. The order being picked up by watchtower. 
        /// T2. It being verified and added to the cow swap order book.
        /// Not used if set to zero
        uint16 verifySlippageBps;

        /// @dev The expiryPeriodSecs time window, used to set the expiry time of any new discrete order.
        /// `expiryPeriodSecs=300 seconds` means that an order as of 13:45:15 UTC will have an expiry
        /// of the nearest 5 minute boundary, so 13:50:00 UTC
        uint24 expiryPeriodSecs;

        // ---- END SLOT 4 (NB: there is padded space here which could be used for future use if needed)

        /// @dev The appData for any new discrete orders.
        /// It refers to an IPFS blob containing metadata, but also controls the pre and post hooks to run upon settlement.
        /// This is set on the contract in advance to avoid incorrect setting.
        /// NOTE: There are constraints around hooks - study the docs
        bytes32 appData;

        // ---- END SLOT 5
    }

    /**
     * @notice Set whether the contract is paused.
     * This will revert within getTradeableOrderWithSignature()
     * and isValidSignature()
     * Any already placed orders are not cancelled -- however
     * token approval can be set to zero.
     */
    function setPaused(bool paused) external;

    /**
     * @notice Set the token allowance of a pre-configured sellToken to the cow swap relayer
     */
    function setCowApproval(address sellToken, uint256 amount) external;

    /**
     * @notice Sets or updates the order configuration for a particular sellToken
     * @dev Registering the conditional order with CowSwap's Watchtower is done separately 
     * via createConditionalOrder()
     * It is up to elevated access to ensure there is no circular loops that may cause infinite swaps
     * back and forth (bleeding fees in the process). There may be valid situations where there is a loop
     * but with different limit prices, for example.
     */
    function setOrderConfig(
        address sellToken, 
        OrderConfig calldata config
    ) external;

    /**
     * @notice Remove the order configuration for a given sellToken
     * @dev Note the next time Watchtower polls getTradeableOrderWithSignature() for an order, 
     * it will revert with OrderNotValid. This will drop the order from Watchtower.
     */
    function removeOrderConfig(address sellToken) external;

    /**
     * @notice A convenience function to update the maxSellAmount, minBuyAmount and price premium on future discrete orders.
     */
    function updateAmountsAndPremiumBps(
        address sellToken, 
        uint96 maxSellAmount,
        uint96 minBuyAmount,
        uint16 limitPricePremiumBps
    ) external;

    /**
     * @notice Register the conditional order with Watchtower
     * @dev This is safe to call for the same sellToken multiple times as Watchtower will ignore
     * duplicates.
     * If Watchtower drops the conditional order for some reason, this is safe to be called again.
     */
    function createConditionalOrder(address sellToken) external;

    /**
     * @notice The CoW swap vault relayer - tokens need to be approved to this contract.
     */
    function cowSwapRelayer() external view returns (address);

    /**
     * @notice Whether the swapper contract is paused for all
     * orders
     */
    function isPaused() external view returns (bool);

    /**
     * @notice The order configuration details used to create any new discrete orders for a given sellToken
     */
    function orderConfig(address sellToken) external view returns (OrderConfig memory);

    /**
     * @notice Calculate the sellAmount as of now for a given token
     */
    function getSellAmount(address sellToken) external view returns (
        uint256 sellAmount
    );

    /**
     * @notice Calculate the buyAmount as of now for a given sellToken. 
     * @dev If it's a MARKET order, this is set to the `minBuyAmount`
     * If it's a LIMIT order it is derived from the `limitPriceOracle` + `limitPricePremiumBps`
     * (floored by the `minBuyAmount`)
     * `roundedBuyAmount` is the `unroundedBuyAmount` rounded down to the nearest `roundDownDivisor`
     */
    function getBuyAmount(address sellToken) external view returns (
        uint256 unroundedBuyAmount, 
        uint256 roundedBuyAmount
    );
}

pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// @note Forked from https://github.com/cowprotocol/composable-cow/blob/24d556b634e21065e0ee70dd27469a6e699a8998/src/interfaces/IConditionalOrder.sol#L12

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IWatchtowerErrors } from "contracts/interfaces/external/cowprotocol/IWatchtowerErrors.sol";
import { GPv2Order } from "contracts/external/cowprotocol/GPv2Order.sol";

interface IConditionalOrder is IERC165, IERC1271, IWatchtowerErrors {
    /**
     * @dev This event is emitted when a new conditional order needs to be created.
     * @param owner the address that has created the conditional order
     * @param params the address / salt / data of the conditional order
     *
     * https://github.com/cowprotocol/composable-cow/blob/2ba71df3d5fdbfe8b92a540837262e164a0290ab/src/ComposableCoW.sol#L51-L52
     */
    event ConditionalOrderCreated(address indexed owner, ConditionalOrderParams params);

    /**
     * @notice Parameters to identify a conditional order, generated by an owner.
     * Concurrent conditional orders by the same owner must have a unique hash:
     *   H(handler || salt || staticInput)
     *
     * https://github.com/cowprotocol/composable-cow/blob/2ba71df3d5fdbfe8b92a540837262e164a0290ab/src/interfaces/IConditionalOrder.sol#L32
     */
    struct ConditionalOrderParams {
        address handler;
        bytes32 salt;
        bytes staticInput;
    }

    /**
     * @notice The watchtower off-chain service calls this to automatically create discrete orders and
     * post them on the orderbook. It outputs an order for the parameters together with a valid signature.
     * @dev Some parameters in this interface are unused as they refer to features of ComposableCoW which
     * aren't required when implementing directly.
     * @param owner of the order.
     * @param params `ConditionalOrderParams` for the order
     * @param offchainInput any dynamic off-chain input for generating the discrete order. As of writing, watchtower sets as bytes("")
     * @param proof if using merkle-roots that H(handler || salt || staticInput) is in the merkle tree
     * @return order discrete order for submitting to CoW Protocol API
     * @return signature for submitting to CoW Protocol API
     *
     * https://github.com/cowprotocol/composable-cow/blob/2ba71df3d5fdbfe8b92a540837262e164a0290ab/src/ComposableCoW.sol#L221
     */
    function getTradeableOrderWithSignature(
        address owner,
        IConditionalOrder.ConditionalOrderParams calldata params,
        bytes calldata offchainInput,
        bytes32[] calldata proof
    ) external view returns (
        GPv2Order.Data memory order, 
        bytes memory signature
    );
}
pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// @note Used by watchtower: https://github.com/cowprotocol/watch-tower/blob/90ecbf5de87447657a36dfcd49a714b1b5105380/src/utils/contracts.ts#L93

/**
 * @title Watchtower Errors Interface
 * @dev Different error messages lead to different watchtower behaviors when creating
 * an order via `getTradeableOrderWithSignature()`
 * @dev The watchtower is a service that automatically posts orders to the CoW
 * Protocol orderbook at regular intervals.
 */
interface IWatchtowerErrors {
    /**
     * @notice No order is currently available for trading, but the watchtower should
     * try again at the specified block.
     */
    error PollTryAtBlock(uint256 blockNumber, string message);

    /**
     * @notice No order is currently available for trading, but the watchtower should
     * try again after the timestamp.
     */
    error PollTryAtEpoch(uint256 timestamp, string message);

    /**
     * @notice No order is currently available for trading, and do not retry this conditional order again.
     * A new ConditionalOrderCreated event will need to be emitted in order to
     * trigger watchtower to monitor this contract again.
     */
    error OrderNotValid(string reason);
}

pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (libraries/CommonEventsAndErrors.sol)

/// @notice A collection of common events and errors thrown within the Origami contracts
library CommonEventsAndErrors {
    error InsufficientBalance(address token, uint256 required, uint256 balance);
    error InvalidToken(address token);
    error InvalidParam();
    error InvalidAddress(address addr);
    error InvalidAmount(address token, uint256 amount);
    error ExpectedNonZero();
    error Slippage(uint256 minAmountExpected, uint256 actualAmount);
    error IsPaused();
    error UnknownExecuteError(bytes returndata);
    error InvalidAccess();
    error BreachedMaxTotalSupply(uint256 totalSupply, uint256 maxTotalSupply);

    event TokenRecovered(address indexed to, address indexed token, uint256 amount);
}

pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (libraries/OrigamiMath.sol)

import { mulDiv as prbMulDiv, PRBMath_MulDiv_Overflow } from "@prb/math/src/Common.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";

/**
 * @notice Utilities to operate on fixed point math multipliation and division
 * taking rounding into consideration
 */
library OrigamiMath {
    enum Rounding {
        ROUND_DOWN,
        ROUND_UP
    }

    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    function scaleUp(uint256 amount, uint256 scalar) internal pure returns (uint256) {
        // Special case for scalar == 1, as it's common for token amounts to not need
        // scaling if decimal places are the same
        return scalar == 1 ? amount : amount * scalar;
    }

    function scaleDown(
        uint256 amount, 
        uint256 scalar, 
        Rounding roundingMode
    ) internal pure returns (uint256 result) {
        // Special case for scalar == 1, as it's common for token amounts to not need
        // scaling if decimal places are the same
        unchecked {
            if (scalar == 1) {
                result = amount;
            } else if (roundingMode == Rounding.ROUND_DOWN) {
                result = amount / scalar;
            } else {
                // ROUND_UP uses the same logic as OZ Math.ceilDiv()
                result = amount == 0 ? 0 : (amount - 1) / scalar + 1;
            }
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision,
     * rounding up
     */
    function mulDiv(
        uint256 x, 
        uint256 y, 
        uint256 denominator,
        Rounding roundingMode
    ) internal pure returns (uint256 result) {
        result = prbMulDiv(x, y, denominator);
        if (roundingMode == Rounding.ROUND_UP) {
            if (mulmod(x, y, denominator) != 0) {
                if (result < type(uint256).max) {
                    unchecked {
                        result = result + 1;
                    }
                } else {
                    revert PRBMath_MulDiv_Overflow(x, y, denominator);
                }
            }
        }
    }

    function subtractBps(
        uint256 inputAmount, 
        uint256 basisPoints,
        Rounding roundingMode
    ) internal pure returns (uint256 result) {
        uint256 numeratorBps;
        unchecked {
            numeratorBps = BASIS_POINTS_DIVISOR - basisPoints;
        }

        result = basisPoints < BASIS_POINTS_DIVISOR
            ? mulDiv(
                inputAmount,
                numeratorBps, 
                BASIS_POINTS_DIVISOR, 
                roundingMode
            ) : 0;
    }

    function addBps(
        uint256 inputAmount,
        uint256 basisPoints,
        Rounding roundingMode
    ) internal pure returns (uint256 result) {
        uint256 numeratorBps;
        unchecked {
            numeratorBps = BASIS_POINTS_DIVISOR + basisPoints;
        }

        // Round up for max amounts out expected
        result = mulDiv(
            inputAmount,
            numeratorBps, 
            BASIS_POINTS_DIVISOR, 
            roundingMode
        );
    }

    /**
     * @notice Split the `inputAmount` into two parts based on the `basisPoints` fraction.
     * eg: 3333 BPS (33.3%) can be used to split an input amount of 600 into: (result=400, removed=200).
     * @dev The rounding mode is applied to the `result`
     */
    function splitSubtractBps(
        uint256 inputAmount, 
        uint256 basisPoints,
        Rounding roundingMode
    ) internal pure returns (uint256 result, uint256 removed) {
        result = subtractBps(inputAmount, basisPoints, roundingMode);
        unchecked {
            removed = inputAmount - result;
        }
    }

    /**
     * @notice Reverse the fractional amount of an input.
     * eg: For 3333 BPS (33.3%) and the remainder=400, the result is 600
     */
    function inverseSubtractBps(
        uint256 remainderAmount, 
        uint256 basisPoints,
        Rounding roundingMode
    ) internal pure returns (uint256 result) {
        if (basisPoints == 0) return remainderAmount; // gas shortcut for 0
        if (basisPoints >= BASIS_POINTS_DIVISOR) revert CommonEventsAndErrors.InvalidParam();

        uint256 denominatorBps;
        unchecked {
            denominatorBps = BASIS_POINTS_DIVISOR - basisPoints;
        }
        result = mulDiv(
            remainderAmount,
            BASIS_POINTS_DIVISOR, 
            denominatorBps, 
            roundingMode
        );
    }

    /**
     * @notice Calculate the relative difference of a value to a reference
     * @dev `value` and `referenceValue` must have the same precision
     * The denominator is always the referenceValue
     */
    function relativeDifferenceBps(
        uint256 value,
        uint256 referenceValue,
        Rounding roundingMode
    ) internal pure returns (uint256) {
        if (referenceValue == 0) revert CommonEventsAndErrors.InvalidParam();

        uint256 absDelta;
        unchecked {
            absDelta = value < referenceValue
                ? referenceValue - value
                : value - referenceValue;
        }

        return mulDiv(
            absDelta,
            BASIS_POINTS_DIVISOR,
            referenceValue,
            roundingMode
        );
    }
}
