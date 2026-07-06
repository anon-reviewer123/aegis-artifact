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
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
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
library SignedMath {
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

import "./math/Math.sol";
import "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
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
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMath.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
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

pragma solidity ^0.8.0;

library Errors {
    /// Common error
    string constant CM_CONTRACT_HAS_BEEN_INITIALIZED = "CM-01"; 
    string constant CM_FACTORY_ADDRESS_IS_NOT_CONFIGURED = "CM-02";
    string constant CM_VICS_ADDRESS_IS_NOT_CONFIGURED = "CM-03";
    string constant CM_VICS_EXCHANGE_IS_NOT_CONFIGURED = "CM-04";
    string constant CM_CEX_FUND_MANAGER_IS_NOT_CONFIGURED = "CM-05";
    string constant CM_TREASURY_MANAGER_IS_NOT_CONFIGURED = "CM-06";
    string constant CM_CEX_DEFAULT_MASTER_ACCOUNT_IS_NOT_CONFIGURED = "CM-07";
    string constant CM_ADDRESS_IS_NOT_ICEXDABOTCERTTOKEN = "CM-08";
    string constant CM_INDEX_OUT_OF_RANGE = "CM-09";
    string constant CM_UNAUTHORIZED_CALLER = "CM-10";
    string constant CM_PROXY_ADMIN_IS_NOT_CONFIGURED = "CM-11";
    

    /// IBCertToken error  (Bot Certificate Token)
    string constant BCT_CALLER_IS_NOT_OWNER = "BCT-01"; 
    string constant BCT_REQUIRE_ALL_TOKENS_BURNT = "BCT-02";
    string constant BCT_UNLOCK_AMOUNT_EXCEEDS_TOTAL_LOCKED = "BCT-03";
    string constant BCT_INSUFFICIENT_LIQUID_FOR_UNLOCKING = "BCT-04a";
    string constant BCT_INSUFFICIENT_LIQUID_FOR_LOCKING = "BCT-04b";
    string constant BCT_AMOUNT_EXCEEDS_TOTAL_STAKE = "BCT-05";
    string constant BCT_CANNOT_MINT_TO_ZERO_ADDRESS = "BCT-06";
    string constant BCT_INSUFFICIENT_LIQUID_FOR_BURN = "BCT-07";
    string constant BCT_INSUFFICIENT_ACCOUNT_FUND = "BCT-08";
    string constant BCT_CALLER_IS_NEITHER_BOT_NOR_CERTLOCKER = "BCT-09";
    string constant BCT_VALUE_MISMATCH_ASSET_AMOUNT = "BCT-10";

    /// IBCEXCertToken error (Cex Bot Certificate Token)
    string constant CBCT_CALLER_IS_NOT_FUND_MANAGER = "CBCT-01";

    /// GovernToken error (Bot Governance Token)
    string constant BGT_CALLER_IS_NOT_OWNED_BOT = "BGT-01";
    string constant BGT_CANNOT_MINT_TO_ZERO_ADDRESS = "BGT-02";
    string constant BGT_CALLER_IS_NOT_GOVERNANCE = "BGT-03";

    // VaultBase error (VB)
    string constant VB_CALLER_IS_NOT_DABOT = "VB-01a";
    string constant VB_CALLER_IS_NOT_OWNER_BOT = "VB-01b";
    string constant VB_INVALID_VAULT_ID = "VB-02";
    string constant VB_INVALID_VAULT_TYPE = "VB-03";
    string constant VB_INVALID_SNAPSHOT_ID = "VB-04";

    // RegularVault Error (RV)
    string constant RV_VAULT_IS_RESTRICTED = "RV-01";
    string constant RV_DEPOSIT_LOCKED = "RV-02";
    string constant RV_WITHDRAWL_AMOUNT_EXCEED_DEPOSIT = "RV-03";

    // BotVaultManager (VM)
    string constant VM_VAULT_EXISTS = "VM-01";

    // BotManager (BM)
    string constant BM_DOES_NOT_SUPPORT_IDABOT = "BM-01";
    string constant BM_DUPLICATED_BOT_QUALIFIED_NAME = "BM-02";
    string constant BM_TEMPLATE_IS_NOT_REGISTERED = "BM-03";
    string constant BM_GOVERNANCE_TOKEN_IS_NOT_DEPLOYED = "BM-04";
    string constant BM_BOT_IS_NOT_REGISTERED = "BM-05";

    // DABotModule (BMOD)
    string constant BMOD_CALLER_IS_NOT_OWNER = "BMOD-01";
    string constant BMOD_CALLER_IS_NOT_BOT_MANAGER = "BMOD-02";
    string constant BMOD_BOT_IS_ABANDONED = "BMOD-03";

    // DABotControllerLib (BCL)
    string constant BCL_DUPLICATED_MODULE = "BCL-01";
    string constant BCL_CERT_TOKEN_IS_NOT_CONFIGURED = "BCL-02";
    string constant BCL_GOVERN_TOKEN_IS_NOT_CONFIGURED = "BCL-03";
    string constant BCL_GOVERN_TOKEN_IS_NOT_DEPLOYED = "BCL-04";
    string constant BCL_WARMUP_LOCKER_IS_NOT_CONFIGURED = "BCL-05";
    string constant BCL_COOLDOWN_LOCKER_IS_NOT_CONFIGURED = "BCL-06";
    string constant BCL_UKNOWN_MODULE_ID = "BCL-07";
    string constant BCL_BOT_MANAGER_IS_NOT_CONFIGURED = "BCL-08";

    // DABotController (BCMOD)
    string constant BCMOD_CANNOT_CALL_TEMPLATE_METHOD_ON_BOT_INSTANCE = "BCMOD-01";
    string constant BCMOD_CALLER_IS_NOT_OWNER = "BCMOD-02";
    string constant BCMOD_MODULE_HANDLER_NOT_FOUND_FOR_METHOD_SIG = "BCMOD-03";
    string constant BCMOD_NEW_OWNER_IS_ZERO = "BCMOD-04";

    // CEXFundManagerModule (CFMOD)
    string constant CFMOD_DUPLICATED_BENEFITCIARY = "CFMOD-01";
    string constant CFMOD_INVALID_CERTIFICATE_OF_ASSET = "CFMOD-02";
    string constant CFMOD_CALLER_IS_NOT_FUND_MANAGER = "CFMOD-03";

    // DABotSettingLib (BSL)
    string constant BSL_CALLER_IS_NOT_OWNER = "BSL-01";
    string constant BSL_CALLER_IS_NOT_GOVERNANCE_EXECUTOR = "BSL-02";
    string constant BSL_IBO_ENDTIME_IS_SOONER_THAN_IBO_STARTTIME = "BSL-03";
    string constant BSL_BOT_IS_ABANDONED = "BSL-04";

    // DABotSettingModule (BSMOD)
    string constant BSMOD_IBO_ENDTIME_IS_SOONER_THAN_IBO_STARTTIME =  "BSMOD-01";
    string constant BSMOD_INIT_DEPOSIT_IS_LESS_THAN_CONFIGURED_THRESHOLD = "BSMOD-02";
    string constant BSMOD_FOUNDER_SHARE_IS_ZERO = "BSMOD-03";
    string constant BSMOD_INSUFFICIENT_MAX_SHARE = "BSMOD-04";
    string constant BSMOD_FOUNDER_SHARE_IS_GREATER_THAN_IBO_SHARE = "BSMOD-05";

    // DABotCertLocker (LOCKER)
    string constant LOCKER_CALLER_IS_NOT_OWNER_BOT = "LOCKER-01";

    // DABotStakingModule (BSTMOD)
    string constant BSTMOD_PRE_IBO_REQUIRED = "BSTMOD-01";
    string constant BSTMOD_AFTER_IBO_REQUIRED = "BSTMOD-02";
    string constant BSTMOD_INVALID_PORTFOLIO_ASSET = "BSTMOD-03";
    string constant BSTMOD_PORTFOLIO_FULL = "BSTMOD-04";
    string constant BSTMOD_INVALID_CERTIFICATE_ASSET = "BSTMOD-05";
    string constant BSTMOD_PORTFOLIO_ASSET_NOT_FOUND = "BSTMOD-06";
    string constant BSTMOD_ASSET_IS_ZERO = "BSTMOD-07";
    string constant BSTMOD_INVALID_STAKING_CAP = "BSTMOD-08";
    string constant BSTMOD_INSUFFICIENT_FUND = "BSTMOD-09";
    string constant BSTMOD_CAP_IS_ZERO = "BSTMOD-10";
    string constant BSTMOD_CAP_IS_LESS_THAN_STAKED_AND_IBO_CAP = "BSTMOD-11";
    string constant BSTMOD_WERIGHT_IS_ZERO = "BSTMOD-12";

    // CEX FundManager (CFM)
    string constant CFM_REQ_TYPE_IS_MISMATCHED = "CFM-01";
    string constant CFM_INVALID_REQUEST_ID = "CFM-02";
    string constant CFM_CALLER_IS_NOT_BOT_TOKEN = "CFM-03";
    string constant CFM_CLOSE_TYPE_VALUE_IS_NOT_SUPPORTED = "CFM-04";
    string constant CFM_UNKNOWN_REQUEST_TYPE = "CFM-05";
    string constant CFM_CALLER_IS_NOT_REQUESTER = "CFM-06";
    string constant CFM_CALLER_IS_NOT_APPROVER = "CFM-07";
    string constant CFM_CEX_CERTIFICATE_IS_REQUIRED = "CFM-08";
    string constant CFM_TREASURY_ASSET_CERTIFICATE_IS_REQUIRED = "CFM-09";
    string constant CFM_FAIL_TO_TRANSFER_VALUE = "CFM-10";
    string constant CFM_AWARDED_ASSET_IS_NOT_TREASURY = "CFM-11";
    string constant CFM_INSUFFIENT_ASSET_TO_MINT_STOKEN = "CFM-12";

    // FarmBot Module (FBM)  string constant FBM_ = "FBM-";
    string constant FBM_CANNOT_REMOVE_WORKER = "FBM-01";
    string constant FBM_NULL_OPERATOR_ACCOUNT = "FBM-02";
    string constant FBM_INVALID_WORKER = "FBM-03";
    string constant FBM_REPAY_ERROR = "FBM-04";
    string constant FBM_INVALID_SWAP_ADAPTER = "FBM-05";
    string constant FBM_INVALID_SWAP_PATH = "FBM-06";
    string constant FBM_INSUFFICIENT_FUND = "FBM-07";

    // TreasuryAsset (TA)
    string constant TA_MINT_ZERO_AMOUNT = "TA-01";
    string constant TA_LOCK_AMOUNT_EXCEED_BALANCE = "TA-02";
    string constant TA_UNLOCK_AMOUNT_AND_PASSED_VALUE_IS_MISMATCHED = "TA-03";
    string constant TA_AMOUNT_EXCEED_AVAILABLE_BALANCE = "TA-04";
    string constant TA_AMOUNT_EXCEED_VALUE_BALANCE = "TA-05";
    string constant TA_FUND_MANAGER_IS_NOT_SET = "TA-06";
    string constant TA_FAIL_TO_TRANSFER_VALUE = "TA-07";

    // Governance (GOV)
    string constant GOV_DEFAULT_STRATEGY_IS_NOT_SET = "GOV-01";
    string constant GOV_INSUFFICIENT_POWER_TO_CREATE_PROPOSAL = "GOV-02";
    string constant GOV_INSUFFICIENT_VICS_TO_CREATE_PROPOSAL = "GOV-03";
    string constant GOV_INVALID_PROPOSAL_ID = "GOV-04";
    string constant GOV_REQUIRED_PROPOSER_OR_GUARDIAN = "GOV-05";
    string constant GOV_TARGET_SHOULD_BE_ZERO_OR_REGISTERED_BOT = "GOV-06";
    string constant GOV_INSUFFICIENT_POWER_TO_VOTE = "GOV-07";
    string constant GOV_INVALID_NEW_STATE = "GOV-08";
    string constant GOV_CANNOT_CHANGE_STATE_OF_CLOSED_PROPOSAL = "GOV-08";
    string constant GOV_INVALID_CREATION_DATA = "GOV-09";
    string constant GOV_CANNOT_CHANGE_STATE_OF_ON_CHAIN_PROPOSAL = "GOV-10";
    string constant GOV_PROPOSAL_DONT_ACCEPT_VOTE = "GOV-11";
    string constant GOV_DUPLICATED_VOTE = "GOV-12";
    string constant GOV_CAN_ONLY_QUEUE_PASSED_PROPOSAL = "GOV-13";
    string constant GOV_DUPLICATED_ACTION = "GOV-14";
    string constant GOV_INVALID_VICS_ADDRESS = "GOV-15";

    // Timelock Executor (TLE)
    string constant TLE_DELAY_SHORTER_THAN_MINIMUM = "TLE-01";
    string constant TLE_DELAY_LONGER_THAN_MAXIMUM = "TLE-02";
    string constant TLE_ONLY_BY_ADMIN = "TLE-03";
    string constant TLE_ONLY_BY_PENDING_ADMIN = "TLE-04";
    string constant TLE_ONLY_BY_THIS_TIMELOCK = "TLE-05";
    string constant TLE_EXECUTION_TIME_UNDERESTIMATED = "TLE-06";
    string constant TLE_ACTION_NOT_QUEUED = "TLE-07";
    string constant TLE_TIMELOCK_NOT_FINISHED = "TLE-08";
    string constant TLE_GRACE_PERIOD_FINISHED = "TLE-09";
    string constant TLE_NOT_ENOUGH_MSG_VALUE = "TLE-10";

    // DABotVoteStrategy (BVS) string constant BVS_ = "BVS-";
    string constant BVS_NOT_A_REGISTERED_DABOT = "BVS-01";

    // DABotWhiteList (BWL) string constant BWL_ = "BWL-";
    string constant BWL_ACCOUNT_IS_ZERO = "BWL-01";
    string constant BWL_ACCOUNT_IS_NOT_WHITELISTED = "BWL-02";

    // Marginal Lending Worker string constant MLF_ = "MLF-";
    string constant MLF_ZERO_DEPOSIT = "MLF-01";
    string constant MLF_UNKNOWN_CONFIG_TOPIC = "MLF-02";
    string constant MLF_REGISTERED_COLLATERAL_ID_EXPECTED = "MLF-03";
    string constant MLF_CONFIG_TOPICS_AND_VALUES_MISMATCHED = "MLF-04";
    string constant MLF_ADAPTER_IS_NOT_CONFIGURED = "MLF-05";
    string constant MLF_CANNOT_REMOVE_IN_USED_COLLATERAL = "MLF-06";
    string constant MLF_CANNOT_CHANGE_LENDING_ADAPTER = "MLF-07";
    string constant MLF_INVALID_PLATFORM_TOKEN = "MLF-08";
    string constant MLF_CANNOT_CHANGE_IN_USED_LEVERAGE_ASSET = "MLF-09";
    string constant MLF_INVALID_EXPECTED_HEALTH_FACTOR = "MLF-10";
    string constant MLF_LEVERAGE_ASSET_IS_NOT_SET = "MLF-11";
    string constant MLF_INVALID_PRECISION = "MLF-12";
    string constant MLF_INTERNAL_ERROR = "MLF-13";

    // FarmCertTokenModule (FTM) string constant FTM_ = "FTM-";
    string constant FTM_INSUFFICICIENT_AMOUNT_TO_DEPOSIT = "FTM-01";

    // ILendingAdapter (ILA) string constant ILA_ = "ILA-";
    string constant ILA_INVALID_EXPECTED_HEALTH_FACTOR = "ILA-01";
    string constant ILA_DEPOSIT_FAILED = "ILA-02";
    string constant ILA_WITHDRAW_FAILED = "ILA-03";
    string constant ILA_BORROW_FAILED = "ILA-04";
    string constant ILA_REPAY_BORROW_FAILED = "ILA-05";

    // RoboFi game string constant RFG_ = "RFG-";
    string constant RFG_CALLER_IS_NOT_REGISTERED_BOT = "RFG-01";
    string constant RFG_CALLER_IS_NOT_BOT_OWNER = "RFG-02";
    string constant RFG_CALLER_IS_NOT_VAULT = "RFG-03";
    string constant RFG_ROUND_NOT_FINISHED = "RFG-04";
    string constant RFG_ROUND_NOT_IN_COMMIT_PHASE = "RFG-05";
    string constant RFG_ROUND_NOT_IN_REVEAL_PHASE = "RFG-06";
    string constant RFG_ROUND_NOT_READY_CLOSE = "RFG-07";
    string constant RFG_ROUND_NOT_CLOSED_YET = "RFG-08";
    string constant RFG_INVALID_SECRET_NUMBER = "RFG-09";
    string constant RFG_WINNER_IS_REQUIRE = "RFG-10";
    string constant RFG_INVALID_SUBMIT_WINNERS = "RFG-11";
    string constant RFG_INVALID_NUMBER_OF_WINNERS = "RFG-12";
    string constant RFG_INVALID_WON_NUMBER = "RFG-13";
    string constant RFG_INVALID_VICS_ADDRESS = "RFG-14";
    string constant RFG_INVALID_COMMIT_DURATION = "RFG-15";
    string constant RFG_INVALID_REVEAL_DURATION = "RFG-16";
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


library Roles {
    bytes32 constant ROLE_ADMIN = keccak256('operator.dabot.role');
    bytes32 constant ROLE_OPERATORS = keccak256('operator.dabot.role');
    bytes32 constant ROLE_TEMPLATE_CREATOR = keccak256('creator.template.dabot.role');
    bytes32 constant ROLE_BOT_CREATOR = keccak256('creator.dabot.role');
    bytes32 constant ROLE_FUND_APPROVER = keccak256('approver.fund.role');
}

library AddressBook {
    bytes32 constant ADDR_FACTORY = keccak256('factory.address');
    bytes32 constant ADDR_VICS = keccak256('vics.address');
    bytes32 constant ADDR_TAX = keccak256('tax.address');
    bytes32 constant ADDR_GOVERNANCE = keccak256('governance.address');
    bytes32 constant ADDR_GOVERNANCE_EXECUTOR = keccak256('executor.governance.address');
    bytes32 constant ADDR_BOT_MANAGER = keccak256('botmanager.address');
    bytes32 constant ADDR_VICS_EXCHANGE = keccak256('exchange.vics.address');
    bytes32 constant ADDR_TREASURY_MANAGER = keccak256('treasury-manager.address');
    bytes32 constant ADDR_CEX_FUND_MANAGER = keccak256('fund-manager.address');
    bytes32 constant ADDR_CEX_DEFAULT_MASTER_ACCOUNT = keccak256('default.master.address');
    bytes32 constant ADDR_ROBOFI_GAME = keccak256('robofi-game.address');
}

library Config {
    /// The amount of VICS that a proposer has to pay when create a new proposal
    bytes32 constant PROPOSAL_DEPOSIT = keccak256('deposit.proposal.config');

    /// The percentage of proposal creation fee distributed to the account that execute a propsal
    bytes32 constant PROPOSAL_REWARD_PERCENT = keccak256('reward.proposal.config');

    /// The minimum VICS a bot creator has to deposit to a newly created bot
    bytes32 constant CREATOR_DEPOSIT = keccak256('deposit.creator.config');

    /// The minim 
    bytes32 constant PROPOSAL_CREATOR_MININUM_POWER = keccak256('minpower.goverance.config');
    
    /// The minimum percentage of for-votes over total votes a proposal has to achieve to be passed
    bytes32 constant PROPOSAL_MINIMUM_QUORUM = keccak256('minquorum.governance.config');

    /// The minimum difference (in percentage) between for-votes and against-vote for a proposal to be passed
    bytes32 constant PROPOSAL_VOTE_DIFFERENTIAL = keccak256('differential.governance.config');

    /// The voting duration of a proposal
    bytes32 constant PROPOSAL_DURATION = keccak256('duration.goverance.config');

    /// The interval that a passed proposed is waiting in queue before being executed
    bytes32 constant PROPOSAL_EXECUTION_DELAY = keccak256('execdelay.governance.config');

    // Number of winners of RoboFi Game
    bytes32 constant GAME_NUMBER_WINNER = keccak256('num-of-winner.game.config');

    // The commit phase duration of a game
    bytes32 constant GAME_COMMIT_DURATION = keccak256('commit.game.config');

    // The reveal phase duration of a game
    bytes32 constant GAME_REVEAL_DURATION = keccak256('reveal.game.config');
}

interface IConfigurator {
    function addressOf(bytes32 addrId) external view returns(address);
    function configOf(bytes32 configId) external view returns(uint);
    function bytesConfigOf(bytes32 configId) external view returns(bytes memory);

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);

    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
}


// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRoboFiFactory {
    function deploy(address masterContract, 
                    bytes calldata data, 
                    bool useCreate2) 
        external 
        payable 
        returns(address);
}


// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../common/Errors.sol";
import "../interfaces/IBotTemplateController.sol";
import "../interfaces/IDABotGovernToken.sol";
import "../interfaces/IDABotManager.sol";
import "../DABotCommon.sol";

struct BotTemplateController {
    mapping(bytes4 => bytes32) selectors;
    mapping(bytes32 => address) moduleAddresses;
    bytes32[] modules;
}

struct BotCoreData {
    BotTemplateController controller;
    BotMetaData metadata;
    BotSetting setting;
}

library DABotTemplateControllerLib {

    using DABotTemplateControllerLib for BotTemplateController;

    bytes32 constant CORE_STORAGE_POSITION = keccak256("core.dabot.storage");

    function coredata() internal pure returns(BotCoreData storage ds) {
        bytes32 position = CORE_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function controller() internal view returns (BotTemplateController storage) {
        return coredata().controller;
    }

    function requireNewModule(bytes32 moduleId) internal view {
        BotTemplateController storage ds = controller();
        require(ds.module(moduleId) == address(0), Errors.BCL_DUPLICATED_MODULE);
    }

    function module(BotTemplateController storage ds, bytes32 moduleId) internal view returns(address) {
        return ds.moduleAddresses[moduleId];
    }

    function moduleOfSelector(BotTemplateController storage ds, bytes4 selector) internal view returns(address) {
        bytes32 moduleId = ds.selectors[selector];
        return ds.moduleAddresses[moduleId];
    }

    function registerModule(BotTemplateController storage ds, bytes32 moduleId, address moduleAddress) internal returns(address oldModuleAddress) {
        oldModuleAddress = ds.moduleAddresses[moduleId];
        ds.moduleAddresses[moduleId] = moduleAddress;
    }

    function registerSelectors(BotTemplateController storage ds, bytes32 moduleId, bytes4[] memory selectors) internal {
        for(uint i = 0; i < selectors.length; i++)
            ds.selectors[selectors[i]] = moduleId;
    }

    
}

library DABotMetaLib {

    using DABotMetaLib for BotMetaData;
    using DABotTemplateControllerLib for BotTemplateController;

    bytes32 constant CORE_STORAGE_POSITION = keccak256("core.dabot.storage");

    function coredata() internal pure returns(BotCoreData storage ds) {
        bytes32 position = CORE_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function metadata() internal view returns (BotMetaData storage) {
        return coredata().metadata;
    }

    function manager(BotMetaData storage ds) internal view returns(IDABotManager _manager) {
        _manager = IDABotManager(ds.botManager);
        require(address(_manager) != address(0), Errors.BCL_BOT_MANAGER_IS_NOT_CONFIGURED);
    }

    function configurator(BotMetaData storage ds) internal view returns(IConfigurator _config) {
        _config = ds.manager().configurator();
    }

    function factory(BotMetaData storage ds) internal view returns(IRoboFiFactory _factory) {
        IConfigurator config = ds.configurator();
        _factory = IRoboFiFactory(config.addressOf(AddressBook.ADDR_FACTORY));
        require(address(_factory) != address(0), Errors.CM_FACTORY_ADDRESS_IS_NOT_CONFIGURED);
    }

    function governToken(BotMetaData storage ds) internal view returns(IDABotGovernToken) {
        address gToken = ds.gToken;
        require(gToken != address(0), Errors.BCL_GOVERN_TOKEN_IS_NOT_DEPLOYED);
        return IDABotGovernToken(gToken);
    }

    function module(BotMetaData storage ds, bytes32 moduleId) internal view returns(address) {
        if (ds.botTemplate == address(0)) {
            return DABotTemplateControllerLib.controller().module(moduleId);
        }
        return IBotTemplateController(ds.botTemplate).module(moduleId);
    }

    function deployCertToken(BotMetaData storage ds, address asset) internal returns(address) {
        address certTokenMaster = ds.module(BOT_CERT_TOKEN_TEMPLATE_ID);
        if (certTokenMaster == address(0)) {
            revert(string(abi.encodePacked(
                Errors.BCL_CERT_TOKEN_IS_NOT_CONFIGURED, 
                '. template: ', 
                Strings.toHexString(uint160(ds.botTemplate), 20)
                )));
        }
        require(certTokenMaster != address(0), Errors.BCL_CERT_TOKEN_IS_NOT_CONFIGURED);

        return ds.factory().deploy(
            certTokenMaster,
            abi.encode(address(this), asset),
            false
        );
    }

    function deployGovernanceToken(BotMetaData storage ds) internal returns(address) {
        address governTokenMaster = ds.module(BOT_GOV_TOKEN_TEMPLATE_ID);
        require(governTokenMaster != address(0), Errors.BCL_GOVERN_TOKEN_IS_NOT_CONFIGURED);

        return ds.factory().deploy(
            governTokenMaster,
            abi.encode(address(this)),
            false
        );
    }

    function deployLocker(BotMetaData storage ds, bytes32 lockerType, LockerData memory data) internal returns(address) {
        address lockerMaster = ds.module(lockerType);
        if (lockerMaster == address(0)) {
            if (lockerType == BOT_CERT_TOKEN_COOLDOWN_HANDLER_ID) 
                revert(Errors.BCL_COOLDOWN_LOCKER_IS_NOT_CONFIGURED);
            revert(Errors.BCL_UKNOWN_MODULE_ID);
        }
        return ds.factory().deploy(
            lockerMaster,
            abi.encode(data),
            false
        );
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

import "./interfaces/IDABotComponent.sol";

enum BotStatus { PRE_IBO, IN_IBO, ACTIVE, ABANDONED }

struct BotModuleInitData {
    bytes32 moduleId;
    bytes data;
}

struct BotSetting {             // for saving storage, the meta-fields of a bot are encoded into a single uint256 byte slot.
    uint64 iboTime;             // 32 bit low: iboStartTime (unix timestamp), 
                                // 32 bit high: iboEndTime (unix timestamp)
    uint24 stakingTime;         // 8 bit low: warm-up time, 
                                // 8 bit mid: cool-down time
                                // 8 bit high: time unit (0 - day, 1 - hour, 2 - minute, 3 - second)
    uint32 pricePolicy;         // 16 bit low: price multiplier (fixed point, 2 digits for decimal)
                                // 16 bit high: commission fee in percentage (fixed point, 2 digit for decimal)
    uint128 profitSharing;      // packed of 16bit profit sharing: bot-creator, gov-user, stake-user, and robofi-game
    uint initDeposit;           // the intial deposit (in VICS) of bot-creator
    uint initFounderShare;      // the intial shares (i.e., governance token) distributed to bot-creator
    uint maxShare;              // max cap of gtoken supply
    uint iboShare;              // max supply of gtoken for IBO. Constraint: maxShare >= iboShare + initFounderShare
}

struct BotMetaData {
    string name;
    string symbol;
    string version;
    uint8 botType;
    bool abandoned;
    bool isTemplate;        // determine this module is a template, not a bot instance
    bool initialized;       // determines whether the bot has been initialized 
    address botOwner;       // the public address of the bot owner
    address botManager;
    address botTemplate;    // address of the template contract 
    address gToken;         // address of the governance token
}

struct BotDetail { // represents a detail information of a bot, merely use for bot infomation query
    uint id;                    // the unique id of a bot within its manager.
                                // note: this id only has value when calling {DABotManager.queryBots}
    address botAddress;         // the contract address of the bot.

    BotStatus status;           // 0 - PreIBO, 1 - InIBO, 2 - Active, 3 - Abandonned
    uint8 botType;              // type of the bot (inherits from the bot's template)
    string botSymbol;           // get the bot name.
    string botName;             // get the bot full name.
    address governToken;        // the address of the governance token
    address template;           // the address of the master contract which defines the behaviors of this bot.
    string templateName;        // the template name.
    string templateVersion;     // the template version.
    uint iboStartTime;          // the time when IBO starts (unix second timestamp)
    uint iboEndTime;            // the time when IBO ends (unix second timestamp)
    uint warmup;                // the duration (in days) for which the staking profit starts counting
    uint cooldown;              // the duration (in days) for which users could claim back their stake after submiting the redeem request.
    uint priceMul;              // the price multiplier to calculate the price per gtoken (based on the IBO price).
    uint commissionFee;         // the commission fee when buying gtoken after IBO time.
    uint initDeposit;           
    uint initFounderShare;
    uint144 profitSharing;
    uint maxShare;              // max supply of governance token.
    uint circulatedShare;       // the current supply of governance token.
    uint iboShare;              // the max supply of gtoken for IBO.
    uint userShare;             // the amount of governance token in the caller's balance.
    UserPortfolioAsset[] portfolio;
}

struct BotModuleInfo {
    string name;
    string version;
    address handler;
}

struct PortfolioCreationData {
    address asset;
    uint256 cap;            // the maximum stake amount for this asset (bot-lifetime).
    uint256 iboCap;         // the maximum stake amount for this asset within the IBO.
    uint256 weight;         // preference weight for this asset. Use to calculate the max purchasable amount of governance tokens.
}

struct PortfolioAsset {
    address certToken;    // the certificate asset to return to stake-users
    uint256 cap;            // the maximum stake amount for this asset (bot-lifetime).
    uint256 iboCap;         // the maximum stake amount for this asset within the IBO.
    uint256 weight;         // preference weight for this asset. Use to calculate the max purchasable amount of governance tokens.
}

struct UserPortfolioAsset {
    address asset;
    PortfolioAsset info;
    uint256 userStake;
    uint256 totalStake;     // the total stake of all users.
    uint256 certSupply;     // the total supply of the certificated token
}

/**
@dev Records warming-up certificate tokens of a DABot.
*/
struct LockerData {         
    address bot;            // the DABOT which creates this locker.
    address owner;          // the locker owner, who is albe to unlock and get tokens after the specified release time.
    address token;          // the contract of the certificate token.
    uint64 created_at;      // the moment when locker is created.
    uint64 release_at;      // the monent when locker could be unlock. 
}

/**
@dev Provides detail information of a warming-up token lock, plus extra information.
    */
struct LockerInfo {
    address locker;
    LockerData info;
    uint256 amount;         // the locked amount of cert token within this locker.
    uint256 reward;         // the accumulated rewards
    address asset;          // the stake asset beyond the certificated token
}

struct MintableShareDetail {
    address asset;
    uint stakeAmount;
    uint mintableShare;
    uint weight;
    uint iboCap;
}

struct AwardingDetail {
    address asset;
    uint compound;
    uint reward;
    uint compoundMode;  // 0 - increase, 1 - decrrease
}

struct StakingReward {
    address asset;
    uint amount;
}

struct BenefitciaryInfo {
    address account;
    string name;
    string shortName;
    uint weight;
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "../common/Errors.sol";
import "./DABotCommon.sol";
import "./interfaces/IDABotModule.sol";
import "./whitelist/DABotWhitelistLib.sol";
import "./controller/DABotControllerLib.sol";

abstract contract DABotModule is IDABotModule, Context {

    using DABotMetaLib for BotMetaData;
    using DABotTemplateControllerLib for BotTemplateController;

    

    modifier onlyTemplateAdmin() {
        BotMetaData storage ds = DABotMetaLib.metadata();
        require(ds.isTemplate && (ds.botOwner == _msgSender()), 
            "BotModule: caller is not template admin");
        _;
    }

    modifier onlyBotOwner() {
        BotMetaData storage ds = DABotMetaLib.metadata();
        require(!ds.isTemplate && (!ds.initialized || ds.botOwner == _msgSender()), Errors.BMOD_CALLER_IS_NOT_OWNER);
        _;
    }

    modifier onlyBotManager() {
        BotMetaData storage ds = DABotMetaLib.metadata();
        require(!ds.initialized || ds.botManager == _msgSender(), Errors.BMOD_CALLER_IS_NOT_BOT_MANAGER);
        _;
    }

    modifier activeBot() {
        BotMetaData storage ds = DABotMetaLib.metadata();
        require(!ds.abandoned, Errors.BMOD_BOT_IS_ABANDONED);
        _;
    }

    modifier whitelistCheck(address account, uint scope) {
        require(DABotWhitelistLib.isWhitelist(account, scope), Errors.BWL_ACCOUNT_IS_NOT_WHITELISTED);
        _;
    }

    modifier initializer() {
        BotMetaData storage ds = DABotMetaLib.metadata();
        require(!ds.initialized, Errors.CM_CONTRACT_HAS_BEEN_INITIALIZED);
        _;
    }

    function configurator() internal view returns(IConfigurator) {
        BotMetaData storage meta = DABotMetaLib.metadata();
        return meta.manager().configurator();
    }

    function onRegister(address moduleAddress) external override onlyTemplateAdmin {
        _onRegister(moduleAddress);
    }

    function onInitialize(bytes calldata data) external override initializer {
        _initialize(data);
    }

    function _initialize(bytes calldata data) internal virtual;
    function _onRegister(address moduleAddress) internal virtual;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IBotTemplateController {
    function registerModule(address moduleHandler) external;
    function updateModuleHandler(bytes32 moduleId, address newModuleAddress) external;
    function module(bytes32 moduleId) external view returns(address);
    function moduleOfSelector(bytes32 selector) external view returns(address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../token/IRoboFiERC20.sol";

struct VaultData {
    address botToken;
    IERC20 asset;
    address bot;
    uint8 index;                // the index-th vault generated from botToken
                                //  0 - warmup vault, 1 - regular vault, 2 - VIP vault
    bytes4 vaultType;           // type of the vault, used to determine the vault handler
}

struct UserInfo {
    uint deposit;
    uint debtPoints;
    uint debt;
    uint lockPeriod;
    uint lastDepositTime;
}

struct VaultInfo {
    VaultData data;             
    UserInfo user;
    uint totalDeposit;          // total deposits in the vault
    uint accRewardPerShare;     // the pending reward per each unit of deposit
    uint lastRewardTime;        // the block time of the last reward transaction
    uint pendingReward;         // the pending reward for the caller
    bytes option;               // vault option
} 

struct RegularVaultOption {
    bool restricted;    // restrict deposit activity to bot only
}


interface IBotVaultEvent {
    event Deposit(uint vID, address indexed payor, address indexed account, uint amount);
    event Widthdraw(uint vID, address indexed account, uint amount);
    event RewardAdded(uint vID, uint assetAmount);
    event RewardClaimed(uint vID, address indexed account, uint amount);
    event Snapshot(uint vID, uint snapshotId);
}

interface IBotVault is IBotVaultEvent {
    function deposit(uint vID, uint amount) external;
    function delegateDeposit(uint vID, address payor, address account, uint amount, uint lockTime) external;
    function withdraw(uint vID, uint amount) external;
    function delegateWithdraw(uint vID, address account, uint amount) external;
    function pendingReward(uint vID, address account) external view returns(uint);
    function balanceOf(uint vID, address account) external view returns(uint);
    function balanceOfAt(uint vID, address account, uint blockNo) external view returns(uint);
    function updateReward(uint vID, uint assetAmount) external;
    function claimReward(uint vID, address account) external;

    /**
    @dev Queries user deposit info for the given vault.
    @param vID the vault ID to query.
    @param account the user account to query.
     */
    function getUserInfo(uint vID, address account) external view returns(UserInfo memory result);
    function getVaultInfo(uint vID, address account) external view returns(VaultInfo memory);
    function getVaultOption(uint vID) external view returns(bytes memory);
    function setVaultOption(uint vID, bytes calldata option) external;
}

interface IBotVaultManagerEvent is IBotVaultEvent {
    event OpenVault(uint vID, VaultData data);
    event DestroyVault(uint vID);
    event RegisterHandler(bytes4 vaultType, address handler);
    event BotManagerUpdated(address indexed botManager);
}

interface IBotVaultManager is IBotVault, IBotVaultManagerEvent {
    function vaultOf(uint vID) external view returns(VaultData memory result);
    function validVault(uint vID) external view returns(bool);
    function createVault(VaultData calldata data) external returns(uint);
    function destroyVault(uint vID) external;
    function vaultId(address botToken, uint8 vaultIndex) external pure returns(uint);
    function registerHandler(bytes4 vaultType, IBotVault handler) external;
    function botManager() external view returns(address);
    function setBotManager(address account) external;
    function snapshot(uint vID) external;
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../token/IRoboFiERC20.sol";
import "../DABotCommon.sol";

interface IDABotCertLocker is IRoboFiERC20 {
    function asset() external view returns(IRoboFiERC20);
    function detail() external view returns(LockerInfo memory);
    function lockedBalance() external view returns(uint);
    function unlockerable() external view returns(bool);
    function tryUnlock() external returns(bool, uint);
    function finalize() external payable;
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDABotCertTokenEvent {
    /**
    @dev Triggered when the bot owner locked an amount of certificate token for trading (or yield farming).
    @param assetAmount the amount of the underlying asset locked.
     */
    event Lock(uint assetAmount);

    /**
    @dev Triggered when the bot owner unlocked an amount of certificate token.
    @param assetAmount the amount of the underlying asset unlocked.
     */
    event Unlock(uint assetAmount);

    /**
    @dev Triggered when the amount of pegged assets of this certificate token has been changed.
    @param amount the changed amount.
    @param profitOrLoss true if the the pegged assets increase, false on otherwise.
     */
    event Compound(uint amount, bool profitOrLoss);
}

interface IDABotCertToken is IERC20, IDABotCertTokenEvent {

    function isCertToken() external view returns(bool);

    /**
    @dev Gets the total deposit of the underlying asset within this certificate.
     */
    function totalStake() external view returns(uint);

    function totalLiquid() external view returns(uint);

    /**
    @dev Queries the bot who owned this certificate.
     */
    function owner() external view returns(address);
    
    /**
    @dev Gets the underlying asset of this certificate.
     */
    function asset() external view returns (IERC20);
    
    /**
    @dev Returns the equivalent amount of the underlying asset for the given amount
        of certificate tokens.
    @param certTokenAmount - the amount of certificate tokens.
     */
    function value(uint certTokenAmount) external view returns(uint);

    function lock(uint assetAmount) external;

    function unlock(uint assetAmount) external;

    /**
    @dev Mints an amount of certificate tokens to the given amount. The equivalent of
        underlying asset should be tranfered to this certificate contract by the caller.
    @param account - the address to recieve minted tokens.
    @param certTokenAmount - the amount of tokens to mint.
    @notice Only the owner bot can call this function.
     */
    function mint(address account, uint certTokenAmount) external returns(uint);

    /**
    @dev Burns an amount of certificate tokens, and returns the equivalant amount of
        the underlying asset to the specified account.
    @param account - the address holing certificate tokens to burn.
    @param certTokenAmount - the amount of certificate token to burn.
    @return the equivalent amount of underlying asset tranfered to the specified account.
    @notice Only the owner bot can call this function.
     */
    function burn(address account, uint certTokenAmount) external returns (uint);

    /**
    @dev Burns an amount of certificate tokens, and returns the equivalent amount of the 
        underlying asset to the caller.
    @param amount - the amount of certificate token to burn.
    @return the equivalent amount of underlying asset transfered to the caller.
     */
    function burn(uint amount) external returns(uint);

    /**
    @dev Burns an amount of certificate tokens without returning any underlying assets.
    @param account - the account holding certificate tokens to burn.
    @param amount - the amount of certificate tokens to burn.
    @notice Only owner bot can call this function.
     */
    function slash(address account, uint amount) external;

    /**
    @dev Compound a given amount of the underlying asset to the total deposit. 
        The compoud could be either profit or loss.
    @param amount - the compound amount.
    @param profitOrLoss - `true` to increase the total deposit, `false` to decrease.
     */
    function compound(uint amount, bool profitOrLoss) external;

    /**
    @dev Deletes this certificate token contracts.
     */
    function finalize() external payable;
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

bytes32 constant IDABotFarmingModuleID = keccak256("farming.module");
bytes32 constant IDABotFundManagerModuleID = keccak256('fundmanager.module');
bytes32 constant IDABotStakingModuleID = keccak256("staking.module");
bytes32 constant IDABotGovernModuleID = keccak256('governance.module');
bytes32 constant IDABotSettingModuleID = keccak256('setting.module');
bytes32 constant IDABotWhitelistModuleID = keccak256("whitelist.module");

bytes32 constant GovTokenHandlerID = keccak256('govtokenimpl.dabot.module');
bytes32 constant CertTokenHandlerID = keccak256('certtokenimpl.dabot.module');

bytes32 constant BOT_CERT_TOKEN_COOLDOWN_HANDLER_ID = keccak256("cooldown.dabot.module");

bytes32 constant BOT_CERT_TOKEN_TEMPLATE_ID = keccak256("certificate-token.dabot.module");
bytes32 constant BOT_GOV_TOKEN_TEMPLATE_ID = keccak256("governance-token.dabot.module");

//bytes32 constant BOT_MODULE_COOLDOWN_LOCKER = keccak256("cooldown.dabot.module");

interface IDABotComponent {   
    function moduleInfo() external view returns(string memory name, string memory version, bytes32 moduleId);
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDABotGovernToken is IERC20 {

    function isGovernToken() external view returns(bool);
    
    function owner() external view returns(address);
    function asset() external view returns (IERC20);
    function value(uint amount) external view returns(uint);
    function mint(address account, uint amount) external;
    function burn(uint amount) external returns(uint);

    function snapshot() external;
    function totalSupplyAt(uint256 snapshotId) external view returns(uint256);
    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256);
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IBotVault.sol";
import "../DABotCommon.sol";
import "../../common/IRoboFiFactory.sol";
import "../../common/IConfigurator.sol";

interface IDABotManagerEvent {
    event BotRemoved(address indexed bot);
    event BotDeployed(uint botId, address indexed bot, BotDetail detail); 
    event TemplateRegistered(address indexed template, string name, string version, uint8 templateType);
}

interface IDABotManager is IDABotManagerEvent {
    
    function configurator() external view returns(IConfigurator);
    function vaultManager() external view returns(IBotVaultManager);
    function addTemplate(address template) external;
    function templates() external view returns(address[] memory);
    function isRegisteredTemplate(address template) external view returns(bool);
    function isRegisteredBot(address botAccount) external view returns(bool);
    function totalBots() external view returns(uint);
    function botIdOf(string calldata qualifiedName) external view returns(int);
    function queryBots(uint[] calldata botId) external view returns(BotDetail[] memory output);
    function deployBot(address template, 
                        string calldata symbol, 
                        string calldata name,
                        BotModuleInitData[] calldata initData
                        ) external;
    function snapshot(address botAccount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IDABotComponent.sol";



/**
@dev An common interface of a DABot module.
 */
interface IDABotModule is IDABotComponent {
    event ModuleRegistered(string name, bytes32 moduleId, address indexed moduleAddress);
    
    function onRegister(address moduleAddress) external;
    function onInitialize(bytes calldata data) external;
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../DABotCommon.sol";

interface IDABotSettingModuleEvent {
    event SettingChanged(uint what, BotSetting setting);  
    event AddressWritten(bytes32 itemId, address indexed value);
    event UintWritten(bytes32 itemId, uint value);
    event BytesWritten(bytes32 itemId, bytes value);
}

interface IDABotSettingModule is IDABotSettingModuleEvent {   
    function status() external view returns(uint);
    function iboTime() external view returns(uint startTime, uint endTime);
    function stakingTime() external view returns(uint warmup, uint cooldown, uint unit);
    function pricePolicy() external view returns(uint priceMul, uint commission);
    function profitSharing() external view returns(uint128);
    function setIBOTime(uint startTime, uint endTime) external;
    function setStakingTime(uint warmup, uint cooldown, uint unit) external;
    function setPricePolicy(uint priceMul, uint commission) external;
    function setProfitSharing(uint sharingScheme) external;

    function readAddress(bytes32 itemId, address defaultAddress) external view returns(address);
    function readUint(bytes32 itemId, uint defaultValue) external view returns(uint);
    function readBytes(bytes32 itemId, bytes calldata defaultValue) external view returns(bytes memory);

    function writeAddress(bytes32 itemId, address value) external;
    function writeUint(bytes32 itemId, uint value) external;
    function writeBytes(bytes32 itemId, bytes calldata value) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IDABotCertToken.sol";
import "../DABotCommon.sol";
import "../interfaces/IBotVault.sol";

interface IDABotStakingModuleEvent {
     event PortfolioUpdated(address indexed asset, address indexed certToken, uint maxCap, uint iboCap, uint weight);
     event AssetRemoved(address indexed asset, address indexed certToken);   
     event Stake(address indexed asset, uint amount, address indexed certToken, uint certAmount, address indexed locker);
     event Unstake(address indexed certToken, uint certAmount, address indexed asset, 
          uint assetAmount, address indexed locker, uint releaseTime);
}

interface IDABotStakingModule is IDABotStakingModuleEvent {

     /**
     @dev Gets the detailed information of the bot's portfolio.
     @return the arrays of UserPortfolioAsset struct.
      */
     function portfolioDetails() external view returns(UserPortfolioAsset[] memory);

     /**
     @dev Gets the portfolio information for the given asset.
     @param asset - the asset to query.
      */
     function portfolioOf(address asset) external view returns(UserPortfolioAsset memory);

     /**
     @dev Adds or update an asset in the bot's portfolio.
     @param asset - the crypto asset to add/update in the portfolio.
     @param maxCap - the maximum amount of crypto asset to stake to the bot.
     @param iboCap - the maximum amount of crypto asset to stake during the bot's IBO.
     @param weight - the preference index of an asset in the portfolio. This is used
               to calculate the mintable amount of governance shares in accoardance to 
               staked amount. 

               Gven the same USD-worth amount of two assets, the one with higher weight 
               will contribute more to the mintable amount of shares than the other.
      */
     function updatePortfolioAsset(address asset, uint maxCap, uint iboCap, uint weight) external;

     /**
     @dev Removes an asset from the bot's portfolio.
     @param asset - the crypto asset to remove.
     @notice asset could only be removed before the IBO. After that, asset could only be
               remove if there is no tokens of this asset staked to the bot.
      */
     function removePortfolioAsset(address asset) external;

     /**
     @dev Creates vaults for each asset in the portfolio. This method should be called 
          internally by the bot manager.
      */
     function createPortfolioVaults() external;

     /**
     @dev Gets the vaults of certificate tokens in the portfolio.
     @param certToken the certificate token.
     @param account the account to query deposit/reward information
      */
     function certificateVaults(address certToken, address account) external view returns(VaultInfo[] memory);

     /**
     @dev Queries the total staking reward of the specific certificate token of the given account
     @param certToken the certificate token.
     @param account the account to query.
      */
     function stakingReward(address certToken, address account) external view returns(uint);

     /**
     @dev Claims all pending staking rewards of the callers.
      */
     function harvestStakingReward() external; 

     /**
     @dev Moves certificate tokens staked in warm-up vault to regular vault.
          If the tokens are locked, the operation will be reverted.
      */
     function upgradeVault(address certToken) external;

     /**
     @dev Gets the maximum amount of crypto asset that could be staked  to the bot.
     @param asset - the crypto asset to check.
     @return the maximum amount of crypto asset to stake.
      */
     function getMaxStake(address asset) external returns(uint);

     /**
     @dev Stakes an amount of crypto asset to the bot to receive staking certificate tokens.
     @param asset - the asset to stake.
     @param amount - the amount to stake.
      */
     function stake(address asset, uint amount) external;

     /**
     @dev Burns an amount of staking certificates to get back underlying asset.
     @param certToken - the certificate to burn.
     @param amount - the amount to burn.
      */
     function unstake(IDABotCertToken certToken, uint amount) external;

     /**
     @dev Gets the total staking balance of an account for the specific asset.
          The balance includes pending stakes (i.e., warmup) and excludes 
          pending unstakes (i.e., cooldown)
     @param account - the account to query.
     @param asset - the crypto asset to query.
     @return the total staked amount of the asset.
      */
     function stakeBalanceOf(address account, address asset) external view returns(uint);

     /**
     @dev Gets the total pending stake balance of an account for the specific asset.
     @param account - the account to query.
     @param asset - the asset to query.
     @return the total pending stake.
      */
     function warmupBalanceOf(address account, address asset) external view returns(uint);

     /**
     @dev Gets to total pending unstake balance of an account for the specific certificate.
     @param account - the account to query.
     @param certToken - the certificate token to query.
     @return the total pending unstake.
      */
     function cooldownBalanceOf(address account, address certToken) external view returns(uint);

     /**
     @dev Gets the certificate contract of an asset of a bot.
     @param asset - to crypto asset to query.
     @return the address of the certificate contract.
      */
     function certificateOf(address asset) external view returns(address);

     /**
     @dev Gets the underlying asset of a certificate.
     @param certToken - the address of the certificate contract.
     @return the address of the underlying crypto asset.
      */
     function assetOf(address certToken) external view returns(address);

     /**
     @dev Determines whether an account is a certificate locker.
     @param account - the account to check.
     @return true - if the account is an certificate locker instance creatd by the bot.
      */
     function isCertLocker(address account) external view returns(bool);

     /**
     @dev Gets the details of lockers for pending stake.
     @param account - the account to query.
     @return the array of LockerInfo struct.
      */
     function warmupDetails(address account) external view returns(LockerInfo[] memory);

     /**
     @dev Gets the details of lockers for pending unstake.
     @param account - the account to query.
     @return the array of LockerInfo struct.
      */
     function cooldownDetails(address account) external view returns(LockerInfo[] memory);

     /**
     @dev Releases tokens in all pending stake lockers. 
     @notice At most 20 lockers are unlocked. If the caller has more than 20, additional 
          transactions are required.
      */
     function releaseWarmups() external;

     /**
     @dev Releases token in all pending unstake lockers.
     @notice At most 20 lockers are unlocked. If the caller has more than 20, additional 
          transactions are required.
      */
     function releaseCooldowns() external;

     
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

uint constant WHITELIST_CHECK_STAKE_USERS = 1;
uint constant WHITELIST_CHECK_GOV_USERS = 2;

interface IDABotWhitelistModuleEvent {
    event WhitelistScope(uint scope);
    event WhitelistAdd(address indexed account, uint scope);
    event WhitelistRemove(address indexed account);
}

interface IDABotWhitelistModule is IDABotWhitelistModuleEvent {

    function whitelistScope() external view returns(uint);
    function setWhitelistScope(uint scope) external;
    function addWhitelist(address account, uint scope) external;
    function removeWhitelist(address account) external;
    function isWhitelist(address acount, uint scope) external view returns(bool);
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "../../common/Errors.sol";
import "../../common/IConfigurator.sol";
import "../interfaces/IDABotSettingModule.sol";
import "../controller/DABotControllerLib.sol";
import "../DABotCommon.sol";

struct SettingStorage { 
    mapping(bytes32 => address) addrStorage;
    mapping(bytes32 => uint) uintStorage;
    mapping(bytes32 => bytes) blobStorage;
}

library DABotSettingLib {

    using DABotSettingLib for BotSetting;
    using DABotMetaLib for BotMetaData;

    bytes32 constant CORE_STORAGE_POSITION = keccak256("core.dabot.storage");
    bytes32 constant SETTING_STORAGE_POSITION = keccak256("setting.dabot.storage");

    function coredata() internal pure returns(BotCoreData storage ds) {
        bytes32 position = CORE_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setting() internal view returns(BotSetting storage) {
        return coredata().setting;
    }

    function settingStorage() internal pure returns(SettingStorage storage ds) {
        bytes32 position = SETTING_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function status(BotSetting storage _setting) internal view returns(BotStatus result) {
        BotMetaData storage meta = DABotMetaLib.metadata();

        if (meta.abandoned) return BotStatus.ABANDONED;
        if (block.timestamp < _setting.iboStartTime()) return BotStatus.PRE_IBO;
        if (block.timestamp < _setting.iboEndTime()) return BotStatus.IN_IBO;
        return BotStatus.ACTIVE;
    }

    /**
    @dev Ensures that following conditions are met
        1) bot is not abandoned, and
        2) either bot is pre-ibo stage and sender is bot owner, or the sender is vote controller module
     */
    function requireSettingChangable(address account) internal view {
        BotMetaData storage _metadata = DABotMetaLib.metadata();
        
        require(!_metadata.abandoned, Errors.BSL_BOT_IS_ABANDONED);

        if (_metadata.isTemplate) {
            require(account == _metadata.botOwner, Errors.BSL_CALLER_IS_NOT_OWNER);
            return;
        }

        BotSetting storage _setting = DABotSettingLib.setting();
        if (block.timestamp < _setting.iboStartTime()) {
            require(account == _metadata.botOwner, Errors.BSL_CALLER_IS_NOT_OWNER);
            return;
        }
        address executor = _metadata.configurator().addressOf(AddressBook.ADDR_GOVERNANCE_EXECUTOR);
        require(account == executor, Errors.BSL_CALLER_IS_NOT_GOVERNANCE_EXECUTOR);
    }

    function readAddress(SettingStorage storage ds, bytes32 itemId, address defaultAddress) internal view returns(address result) {
        result = ds.addrStorage[itemId]; 
        if (result == address(0)) { 
            BotMetaData storage _metadata = DABotMetaLib.metadata();
             if (_metadata.botManager == address(0))
                return result;
            if (_metadata.botTemplate != address(0))
                result = IDABotSettingModule(_metadata.botTemplate).readAddress(itemId, defaultAddress);
            if (result == address(0))
                result = _metadata.configurator().addressOf(itemId);
            if (result == address(0))
                result = defaultAddress;
        }
    }

    function writeAddress(SettingStorage storage ds, bytes32 itemId, address value) internal {
        ds.addrStorage[itemId] = value;
    }

    function readUint(SettingStorage storage ds, bytes32 itemId, uint defaultValue) internal view returns(uint result) {
        result = ds.uintStorage[itemId];
        if (result == 0) {
            BotMetaData storage _metadata = DABotMetaLib.metadata();
            if (_metadata.botManager == address(0))
                return result;
            if (_metadata.botTemplate != address(0))
                result = IDABotSettingModule(_metadata.botTemplate).readUint(itemId, defaultValue);
            if (result == 0)
                result = _metadata.configurator().configOf(itemId);
            if (result == 0)
                result = defaultValue;
        }

    }

    function writeUint(SettingStorage storage ds, bytes32 itemId, uint value) internal {
        ds.uintStorage[itemId] = value;
    }

    function readBytes(SettingStorage storage ds, bytes32 itemId, bytes calldata defaultValue) internal view returns(bytes memory result) {
        result = ds.blobStorage[itemId];
        if (result.length == 0) {
            BotMetaData storage _metadata = DABotMetaLib.metadata();
            if (_metadata.botManager == address(0))
                return result;
            if (_metadata.botTemplate != address(0))
                result = IDABotSettingModule(_metadata.botTemplate).readBytes(itemId, defaultValue);
            if (result.length == 0)
                result = _metadata.configurator().bytesConfigOf(itemId);
            if (result.length == 0)
                result = defaultValue;
        }
    }

    function writeBytes(SettingStorage storage ds, bytes32 itemId, bytes calldata defaultValue) internal {
        ds.blobStorage[itemId] = defaultValue;
    }

    function iboStartTime(BotSetting memory info) internal pure returns(uint) {
        return info.iboTime & 0xFFFFFFFF;
    }

    function iboEndTime(BotSetting memory info) internal pure returns(uint) {
        return info.iboTime >> 32;
    }

    function setIboTime(BotSetting storage info, uint start, uint end) internal {
        require(start < end, Errors.BSL_IBO_ENDTIME_IS_SOONER_THAN_IBO_STARTTIME);
        info.iboTime = uint64((end << 32) | start);
    }

    function warmupTime(BotSetting storage info) internal view returns(uint) {
        return info.stakingTime & 0xFF;
    }

    function cooldownTime(BotSetting storage info) internal view returns(uint) {
        return (info.stakingTime >> 8) & 0xFF;
    }

    function getStakingTimeMultiplier(BotSetting storage info) internal view returns (uint) {
        uint unit = stakingTimeUnit(info);
        if (unit == 0) return 1 days;
        if (unit == 1) return 1 hours;
        if (unit == 2) return 1 minutes;
        return 1 seconds;
    }

    function stakingTimeUnit(BotSetting storage info) internal view returns (uint) {
        return (info.stakingTime >> 16);
    }

    function setStakingTime(BotSetting storage info, uint warmup, uint cooldown, uint unit) internal {
        info.stakingTime = uint24((unit << 16) | (cooldown << 8) | warmup);
    }

    function priceMultiplier(BotSetting storage info) internal view returns(uint) {
        return info.pricePolicy & 0xFFFF;
    }

    function commission(BotSetting storage info) internal view returns(uint) {
        return info.pricePolicy >> 16;
    }

    function setPricePolicy(BotSetting storage info, uint _priceMul, uint _commission) internal {
        info.pricePolicy = uint32((_commission << 16) | _priceMul);
    }

    function profitShare(BotSetting storage info, uint actor) internal view returns(uint) {
        return (info.profitSharing >> actor * 16) & 0xFFFF;
    }

    function setProfitShare(BotSetting storage info, uint sharingScheme) internal {
        info.profitSharing = uint128(sharingScheme);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../token/IRoboFiERC20.sol";
import "../../common/Errors.sol";
import "../interfaces/IDABotCertLocker.sol";
import "../interfaces/IDABotCertToken.sol";
import "../DABotCommon.sol";
import "../controller/DABotControllerLib.sol";


struct BotStakingData {
    IRoboFiERC20[]  assets; 
    mapping(IRoboFiERC20 => PortfolioAsset) portfolio;
    mapping(address => IDABotCertLocker[]) warmup;
    mapping(address => IDABotCertLocker[]) cooldown;
    mapping(address => bool) lockers;
}

library DABotStakingLib {
    bytes32 constant STAKING_STORAGE_POSITION = keccak256("staking.dabot.storage");

    using DABotStakingLib for BotStakingData;
    using DABotMetaLib for BotMetaData;

    function staking() internal pure returns(BotStakingData storage ds) {
        bytes32 position = STAKING_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function stakeBalanceOf(BotStakingData storage ds, address account, IRoboFiERC20 asset) internal view returns(uint) {
        BotMetaData storage meta = DABotMetaLib.metadata();
        IBotVaultManager vault = IDABotManager(meta.botManager).vaultManager();
        IDABotCertToken certToken = ds.certificateOf(asset);
        uint vID = vault.vaultId(address(certToken), 0);

        return certToken.balanceOf(account)
                // + ds.warmupBalanceOf(account, asset)
                + vault.balanceOf(vID, account)
                + vault.balanceOf(vID + 1, account)
                + vault.balanceOf(vID + 2, account)
                + ds.cooldownBalanceOf(account, ds.certificateOf(asset));
    }

    function totalStake(BotStakingData storage ds, IRoboFiERC20 asset) internal view returns(uint) {
        return IDABotCertToken(ds.portfolio[asset].certToken).totalStake();
    }

    function warmupBalanceOf(BotStakingData storage ds, address account, IRoboFiERC20 asset) internal view returns(uint) {
        IDABotCertLocker[] storage lockers = ds.warmup[account];
        return lockedBalance(lockers, address(asset));
    }

    function cooldownBalanceOf(BotStakingData storage ds, address account, IDABotCertToken certToken) internal view returns(uint) {
        IDABotCertLocker[] storage lockers = ds.cooldown[account];
        return lockedBalance(lockers, address(certToken.asset()));
    }
    
    function certificateOf(BotStakingData storage ds, IRoboFiERC20 asset) internal view returns(IDABotCertToken) {
        return IDABotCertToken(ds.portfolio[asset].certToken); 
    }

    function assetOf(address certToken) public view returns(IERC20) {
        return IDABotCertToken(certToken).asset(); 
    }

    function lockedBalance(IDABotCertLocker[] storage lockers, address asset) internal view returns(uint result) {
        result = 0;
        for (uint i = 0; i < lockers.length; i++) 
            if (address(lockers[i].asset()) == asset)
                result += lockers[i].lockedBalance();
    }

    function portfolioDetails(BotStakingData storage ds) internal view returns(UserPortfolioAsset[] memory output) {
        output = new UserPortfolioAsset[](ds.assets.length);
        for(uint i = 0; i < ds.assets.length; i++) {
            IRoboFiERC20 asset = ds.assets[i];
            output[i].asset = address(asset);
            output[i].info = ds.portfolio[asset];
            output[i].userStake = ds.stakeBalanceOf(msg.sender, asset);
            output[i].totalStake = ds.totalStake(asset);
            output[i].certSupply = IERC20(ds.portfolio[asset].certToken).totalSupply();
        }
    }

    function portfolioOf(BotStakingData storage ds, IRoboFiERC20 asset) internal view returns(UserPortfolioAsset memory  output) {
        output.asset = address(asset);
        output.info = ds.portfolio[asset];
        output.userStake = ds.stakeBalanceOf(msg.sender, asset);
        output.totalStake = ds.totalStake(asset);
        output.certSupply = IERC20(ds.portfolio[asset].certToken).totalSupply();
    }

    function updatePortfolioAsset(BotStakingData storage ds, IRoboFiERC20 asset, uint maxCap, uint iboCap, uint weight) internal {
        PortfolioAsset storage pAsset = ds.portfolio[asset];

        if (address(pAsset.certToken) == address(0)) {
            pAsset.certToken = DABotMetaLib.metadata().deployCertToken(address(asset));
            ds.assets.push(asset);
        }

        if (maxCap > 0) pAsset.cap = maxCap;
        if (iboCap > 0) pAsset.iboCap = iboCap;
        if (weight > 0) pAsset.weight = weight;

        uint _totalStake = IDABotCertToken(pAsset.certToken).totalStake();

        require((pAsset.cap >= _totalStake) && (pAsset.cap >= pAsset.iboCap), Errors.BSTMOD_INVALID_STAKING_CAP);
    }

    function removePortfolioAsset(BotStakingData storage ds, IRoboFiERC20 asset) internal returns(address) {
        require(address(asset) != address(0), Errors.BSTMOD_ASSET_IS_ZERO);
        for(uint i = 0; i < ds.assets.length; i++)
            if (address(ds.assets[i]) == address(asset)) {
                address certToken = ds.portfolio[asset].certToken;
                IDABotCertToken(certToken).finalize(); 
                delete ds.portfolio[asset];
                ds.assets[i] = ds.assets[ds.assets.length - 1];
                ds.assets.pop();
                return certToken;
            }
        revert(Errors.BSTMOD_PORTFOLIO_ASSET_NOT_FOUND);
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../common/Errors.sol";
import "../DABotCommon.sol";
import "../DABotModule.sol";
import "../interfaces/IBotVault.sol";
import "../interfaces/IDABotStakingModule.sol";
import "../controller/DABotControllerLib.sol";
import "../setting/DABotSettingLib.sol";
import "./DABotStakingLib.sol";

contract DABotStakingModule is DABotModule, IDABotStakingModuleEvent {
    using DABotStakingLib for BotStakingData;
    using DABotSettingLib for BotSetting;
    using DABotMetaLib for BotMetaData;
    using DABotTemplateControllerLib for BotTemplateController;
    using SafeERC20 for IERC20;

    IBotVaultManager private immutable vaultManager;

    bytes4 constant WARMUP_VAULT = 0x5f0378a7; // warmup.vault
    bytes4 constant REGULAR_VAULT = 0x3e472239; //regular.vault
    bytes4 constant VIP_VAULT = 0x2c52665a; // vip.vault

    constructor(IBotVaultManager _vault) {
        vaultManager = _vault;
    }

    function _onRegister(address moduleAddress) internal override {
        BotTemplateController storage ds = DABotTemplateControllerLib.controller();
        ds.registerModule(IDABotStakingModuleID, moduleAddress); 
        bytes4[22] memory selectors =  [
            IDABotStakingModule.portfolioDetails.selector,
            IDABotStakingModule.portfolioOf.selector,
            IDABotStakingModule.updatePortfolioAsset.selector,
            IDABotStakingModule.removePortfolioAsset.selector,
            IDABotStakingModule.createPortfolioVaults.selector,
            IDABotStakingModule.certificateVaults.selector,
            IDABotStakingModule.stakingReward.selector,
            IDABotStakingModule.harvestStakingReward.selector,
            IDABotStakingModule.upgradeVault.selector,
            IDABotStakingModule.getMaxStake.selector,
            IDABotStakingModule.stake.selector,
            IDABotStakingModule.unstake.selector,
            IDABotStakingModule.stakeBalanceOf.selector,
            IDABotStakingModule.warmupBalanceOf.selector,
            IDABotStakingModule.cooldownBalanceOf.selector,
            IDABotStakingModule.certificateOf.selector,
            IDABotStakingModule.assetOf.selector,
            IDABotStakingModule.isCertLocker.selector,
            IDABotStakingModule.warmupDetails.selector,
            IDABotStakingModule.cooldownDetails.selector,
            IDABotStakingModule.releaseWarmups.selector,
            IDABotStakingModule.releaseCooldowns.selector 
        ];
        for (uint i = 0; i < selectors.length; i++)
            ds.selectors[selectors[i]] = IDABotStakingModuleID;

        emit ModuleRegistered("IDABotStakingModule", IDABotStakingModuleID, moduleAddress);
    }

    function _initialize(bytes calldata data) internal override {
        PortfolioCreationData[] memory portfolio = abi.decode(data, (PortfolioCreationData[]));

        for(uint idx = 0; idx < portfolio.length; idx++) 
            updatePortfolioAsset(IRoboFiERC20(portfolio[idx].asset), portfolio[idx].cap, portfolio[idx].iboCap, portfolio[idx].weight);
    }

    function moduleInfo() external pure override returns(string memory name, string memory version, bytes32 moduleId) {
        name = "DABotStakingModule";
        version = "v0.1.211202";
        moduleId = IDABotStakingModuleID;
    }

    function portfolioDetails() external view returns(UserPortfolioAsset[] memory) {
        return DABotStakingLib.staking().portfolioDetails();
    }

    function portfolioOf(IRoboFiERC20 asset) external view returns(UserPortfolioAsset memory) {
        return DABotStakingLib.staking().portfolioOf(asset);
    }

    function updatePortfolioAsset(IRoboFiERC20 asset, uint maxCap, uint iboCap, uint weight) public onlyBotOwner {
        BotMetaData storage meta = DABotMetaLib.metadata();
        BotStakingData storage ds = DABotStakingLib.staking();
        BotSetting storage setting = DABotSettingLib.setting();
        PortfolioAsset storage pAsset = ds.portfolio[asset];
        require(address(asset) != address(0), Errors.BSTMOD_INVALID_PORTFOLIO_ASSET);

        bool newAsset = address(pAsset.certToken) == address(0);

        if (newAsset) {
            require(!meta.initialized || block.timestamp < setting.iboStartTime(), Errors.BSTMOD_PRE_IBO_REQUIRED);
            require(maxCap > 0, Errors.BSTMOD_CAP_IS_ZERO);
            require(weight > 0, Errors.BSTMOD_WERIGHT_IS_ZERO);
        }
        
        ds.updatePortfolioAsset(asset, maxCap, iboCap, weight);

        if (newAsset && meta.initialized)   
            // Only create vaults when bot is intialized and has be recognized by the bot manager.
            // Otherwise, the vault manager will reject the vault creation.
            _createVaults(pAsset.certToken);

        emit PortfolioUpdated(address(asset), address(pAsset.certToken), pAsset.cap, pAsset.iboCap, pAsset.weight);
    }

    function createPortfolioVaults() external onlyBotManager {
         BotStakingData storage ds = DABotStakingLib.staking();
         for (uint i = 0; i < ds.assets.length; i++) {
             _createVaults(ds.portfolio[ds.assets[i]].certToken);
         }
    }

    function certificateVaults(address certToken, address account) external view returns(VaultInfo[] memory result) {
        uint vID = vaultManager.vaultId(certToken, 0);
        result = new VaultInfo[](3);
        result[0] = vaultManager.getVaultInfo(vID, account);
        result[1] = vaultManager.getVaultInfo(vID + 1, account);
        result[2] = vaultManager.getVaultInfo(vID + 2, account);
    }

    function harvestStakingReward() external {
        BotStakingData storage ds = DABotStakingLib.staking();
        for (uint i = 0; i < ds.assets.length; i++) {
            _harvestStakingReward(ds.portfolio[ds.assets[i]].certToken);
        }
    }

    function stakingReward(address certToken, address account) external view returns(uint) {
        uint vID = vaultManager.vaultId(certToken, 0);
        return vaultManager.pendingReward(vID, account)
            + vaultManager.pendingReward(vID + 1, account)
            + vaultManager.pendingReward(vID + 2, account);
    }

    function _harvestStakingReward(address certToken) internal {
        uint vID = vaultManager.vaultId(certToken, 0);
        address caller = _msgSender();
        vaultManager.claimReward(vID, caller);
        vaultManager.claimReward(vID + 1, caller);
        vaultManager.claimReward(vID + 2, caller);
    }

    function upgradeVault(address certToken) external {
        _upgradeVault(IDABotCertToken(certToken), _msgSender());
    }

    function _createVaults(address certToken) private {
        IERC20 asset = IERC20(IDABotCertToken(certToken).asset());
        uint vID0 = vaultManager.createVault(VaultData(certToken, asset, address(this), 0, WARMUP_VAULT));
        vaultManager.createVault(VaultData(certToken, asset, address(this), 1, REGULAR_VAULT));
        uint vID2 = vaultManager.createVault(VaultData(certToken, asset, address(this), 2, VIP_VAULT));

        vaultManager.setVaultOption(vID0, abi.encode(RegularVaultOption(true))); 
        vaultManager.setVaultOption(vID2, abi.encode(RegularVaultOption(true))); 
    }

    function _upgradeVault(IDABotCertToken certToken, address account) private {
        require(certToken.owner() == address(this), Errors.BSTMOD_INVALID_CERTIFICATE_ASSET);
        uint vID0 = vaultManager.vaultId(address(certToken), 0);
        uint amount = vaultManager.balanceOf(vID0, account);
        if (amount == 0)
            return;
        vaultManager.delegateWithdraw(vID0, account, amount);
        vaultManager.delegateDeposit(vID0 + 1, account, account, amount, 0);
    }

    /**
    @dev Removes an asset from the bot's porfolio. 

    It requires that none is currently staking to this asset. Otherwise, the transaction fails.
     */
    function removePortfolioAsset(IRoboFiERC20 asset) public onlyBotOwner {
        BotStakingData storage ds = DABotStakingLib.staking();
        address certToken = ds.portfolio[asset].certToken;
        _destroyVaults(certToken);
        ds.removePortfolioAsset(asset);
        emit AssetRemoved(address(asset), certToken);
    }

    function _destroyVaults(address certToken) internal {
        uint vID = vaultManager.vaultId(certToken, 0);
        vaultManager.destroyVault(vID);
        vaultManager.destroyVault(vID + 1);
        vaultManager.destroyVault(vID + 2);
    }

    /**
    @dev Retrieves the max stakable amount for the specified asset.

    During IBO, the max stakable amount is bound by the {portfolio[asset].iboCap}.
    After IBO, it is limited by {portfolio[asset].cap}.
     */
    function getMaxStake(IRoboFiERC20 asset) public view returns(uint) {
        BotSetting storage setting = DABotSettingLib.setting();
        BotStakingData storage staking = DABotStakingLib.staking();

        if (block.timestamp < setting.iboStartTime())
            return 0;

        PortfolioAsset storage pAsset = staking.portfolio[asset];

        uint totalStake = IDABotCertToken(pAsset.certToken).totalStake();

        if (block.timestamp < setting.iboEndTime())
            return pAsset.iboCap - totalStake;

        return pAsset.cap - totalStake;
    }

    /**
    @dev Stakes an mount of crypto asset to the bot and get back the certificate token.

    The staking function is only valid after the IBO starts and on ward. Before that calling 
    to this function will be failt.

    When users stake during IBO time, users will immediately get the certificate token. After the
    IBO time, certificate token will be issued after a [warm-up] period.
     */
    function stake(IRoboFiERC20 asset, uint amount) 
        external 
        virtual 
        activeBot 
        whitelistCheck(_msgSender(), WHITELIST_CHECK_STAKE_USERS) 
    {
        if (amount == 0) return;

        BotStakingData storage ds = DABotStakingLib.staking();
        BotSetting storage setting = DABotSettingLib.setting();
        PortfolioAsset storage pAsset = ds.portfolio[asset];

        require(setting.iboStartTime() <= block.timestamp, Errors.BSTMOD_PRE_IBO_REQUIRED);
        require(address(asset) != address(0), Errors.BSTMOD_INVALID_PORTFOLIO_ASSET);
        require(pAsset.certToken != address(0), Errors.BSTMOD_INVALID_CERTIFICATE_ASSET);

        uint maxStakeAmount = getMaxStake(asset);
        require(maxStakeAmount > 0, Errors.BSTMOD_PORTFOLIO_FULL);

        uint stakeAmount = amount > maxStakeAmount ? maxStakeAmount : amount;
        _mintCertificate(asset, pAsset, stakeAmount);        
    }

    /**
    @dev Redeems an amount of certificate token to get back the original asset.

    All unstake requests are denied before ending of IBO.
     */
    function unstake(IDABotCertToken certToken, uint amount) external virtual {
        if (amount == 0) return;
        BotSetting storage setting = DABotSettingLib.setting();
        IERC20 asset = certToken.asset();
        require(address(asset) != address(0), Errors.BSTMOD_INVALID_CERTIFICATE_ASSET);
        require(setting.iboEndTime() <= block.timestamp, Errors.BSTMOD_AFTER_IBO_REQUIRED);
        require(certToken.balanceOf(_msgSender()) >= amount, Errors.BSTMOD_INSUFFICIENT_FUND);

        _unstake(_msgSender(), certToken, amount);
    }

    function _mintCertificate(IERC20 asset, PortfolioAsset storage pAsset, uint amount) internal {
        BotSetting storage setting = DABotSettingLib.setting();
        IDABotCertToken token = IDABotCertToken(pAsset.certToken);
        BotStatus status = setting.status();
        
        asset.safeTransferFrom(_msgSender(), address(token), amount);
        uint certTokenAmount = token.mint(address(vaultManager), amount); 

        uint vID = vaultManager.vaultId(pAsset.certToken, 0);
        if (status == BotStatus.IN_IBO) {
            vaultManager.delegateDeposit(vID + 2 /* VIP Vault */, address(0), _msgSender(), amount, 0);
        } else {
            uint64 duration = uint64(setting.warmupTime() * setting.getStakingTimeMultiplier());
            vaultManager.delegateDeposit(vID + (duration == 0 ? 1 : 0), address(0), _msgSender(), certTokenAmount, duration);
        }

        emit Stake(address(asset), amount, address(pAsset.certToken), certTokenAmount, address(0));
    }

    function _unstake(address account, IDABotCertToken certToken, uint amount) internal virtual {
        BotSetting storage setting = DABotSettingLib.setting();
        uint duration = setting.cooldownTime() * setting.getStakingTimeMultiplier(); 
        address asset = address(certToken.asset()); 
        uint assetAmount = certToken.value(amount);

        if (duration == 0) {
            certToken.burn(_msgSender(), amount);
            emit Unstake(address(certToken), amount, asset, assetAmount, address(0), block.timestamp);
            return;
        }

        BotMetaData storage meta = DABotMetaLib.metadata();
        BotStakingData storage ds = DABotStakingLib.staking();

        address locker = meta.deployLocker(BOT_CERT_TOKEN_COOLDOWN_HANDLER_ID,
                LockerData(address(this), 
                _msgSender(), 
                address(certToken), 
                uint64(block.timestamp), 
                uint64(block.timestamp + duration))
            );

        ds.cooldown[account].push(IDABotCertLocker(locker));
        ds.lockers[locker] = true;
        certToken.transferFrom(account, locker, amount);

        emit Unstake(address(certToken), amount, asset, assetAmount, locker, block.timestamp + duration);
    }

    function stakeBalanceOf(address account, IRoboFiERC20 asset) external view returns(uint) {
        return DABotStakingLib.staking().stakeBalanceOf(account, asset);
    }

    function warmupBalanceOf(address account, IRoboFiERC20 asset) external view returns(uint) {
        return DABotStakingLib.staking().warmupBalanceOf(account, asset);
    }

    function cooldownBalanceOf(address account, IDABotCertToken certToken) external view returns(uint) {
        return DABotStakingLib.staking().cooldownBalanceOf(account, certToken);
    }

    function certificateOf(IRoboFiERC20 asset) external view returns(IDABotCertToken) {
        return DABotStakingLib.staking().certificateOf(asset);
    }

    function assetOf(address certToken) external view returns(IERC20) {
        return IDABotCertToken(certToken).asset();
    }

    function isCertLocker(address account) external view returns(bool) {
        return DABotStakingLib.staking().lockers[account];
    }

    /**
    @dev Gets detail information of warming-up certificate tokens (for all staked assets).
    */
    function warmupDetails(address account) public view returns(LockerInfo[] memory) {
        BotStakingData storage ds = DABotStakingLib.staking();
        IDABotCertLocker[] storage lockers = ds.warmup[account];
        return _lockerInfo(lockers);
    }

    /**
    @dev Gets detail information of cool-down requests (for all certificate tokens)
     */
    function cooldownDetails(address account) public view returns(LockerInfo[] memory) {
        BotStakingData storage ds = DABotStakingLib.staking();
        IDABotCertLocker[] storage lockers = ds.cooldown[account];
         return _lockerInfo(lockers);
    }

    function _lockerInfo(IDABotCertLocker[] storage lockers) internal view returns(LockerInfo[] memory result) {
        result = new LockerInfo[](lockers.length);
        for (uint i = 0; i < lockers.length; i++) {
            result[i] = lockers[i].detail();
        }
    }

    /**
    @dev Itegrates all lockers of the caller, and try to unlock these lockers if time condition meets.
        The unlocked lockers will be removed from the global `_warmup`.

        The function will return when one of the below conditions meet:
        (1) 20 lockers has been unlocked,
        (2) All lockers have been checked
     */
    function releaseWarmups() public {
        _releaseLockers(DABotStakingLib.staking(), _msgSender(), false);
    }

    function releaseCooldowns() public {
        _releaseLockers(DABotStakingLib.staking(), _msgSender(), true);
    }

    function _releaseLockers(BotStakingData storage ds, address account, bool isCooldown) internal {
        IDABotCertLocker[] storage lockers = isCooldown ? ds.cooldown[account] : ds.warmup[account];
        uint max = lockers.length < 20 ? lockers.length : 20;
        uint idx = 0;
        for (uint count = 0; count < max && idx < lockers.length;) {
            IDABotCertLocker locker = lockers[idx];
            (bool unlocked,) = locker.tryUnlock(); 
            if (!unlocked) {
                idx++;
                continue;
            }
            // if (isCooldown)
            //     IERC20(locker.asset()).safeTransfer(account, amount);
            ds.lockers[address(locker)] = false;
            locker.finalize(); 
            lockers[idx] = lockers[lockers.length - 1];
            lockers.pop();
            count++;
        }
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IDABotWhitelist.sol";

struct BotWhitelistData {
    uint scope;    // an integer flag to determine the scope where whitelist is apply
    mapping(address => uint) whitelist;
}

library DABotWhitelistLib {

    bytes32 constant WHITELIST_STORAGE_POSITION = keccak256("whitelist.dabot.storage");

    function whitelist() internal pure returns(BotWhitelistData storage ds) {
        bytes32 position = WHITELIST_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function isWhitelist(address account, uint scope) internal view returns(bool) {
        BotWhitelistData storage data = whitelist();
        if (data.scope & scope == 0)
            return true;
        return (data.whitelist[account] & scope) > 0;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRoboFiERC20 is IERC20 {
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
}