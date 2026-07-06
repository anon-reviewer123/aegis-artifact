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

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./PythStructs.sol";
import "./IPythEvents.sol";

/// @title Consume prices from the Pyth Network (https://pyth.network/).
/// @dev Please refer to the guidance at https://docs.pyth.network/documentation/pythnet-price-feeds/best-practices for how to consume prices safely.
/// @author Pyth Data Association
interface IPyth is IPythEvents {
    /// @notice Returns the period (in seconds) that a price feed is considered valid since its publish time
    function getValidTimePeriod() external view returns (uint validTimePeriod);

    /// @notice Returns the price and confidence interval.
    /// @dev Reverts if the price has not been updated within the last `getValidTimePeriod()` seconds.
    /// @param id The Pyth Price Feed ID of which to fetch the price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPrice(
        bytes32 id
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price and confidence interval.
    /// @dev Reverts if the EMA price is not available.
    /// @param id The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPrice(
        bytes32 id
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceUnsafe(
        bytes32 id
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceUnsafe(
        bytes32 id
    ) external view returns (PythStructs.Price memory price);

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    function getEmaPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view returns (PythStructs.Price memory price);

    /// @notice Update price feeds with given update messages.
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    /// Prices will be updated if they are more recent than the current stored prices.
    /// The call will succeed even if the update is not the most recent.
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    function updatePriceFeeds(bytes[] calldata updateData) external payable;

    /// @notice Wrapper around updatePriceFeeds that rejects fast if a price update is not necessary. A price update is
    /// necessary if the current on-chain publishTime is older than the given publishTime. It relies solely on the
    /// given `publishTimes` for the price feeds and does not read the actual price update publish time within `updateData`.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    /// `priceIds` and `publishTimes` are two arrays with the same size that correspond to senders known publishTime
    /// of each priceId when calling this method. If all of price feeds within `priceIds` have updated and have
    /// a newer or equal publish time than the given publish time, it will reject the transaction to save gas.
    /// Otherwise, it calls updatePriceFeeds method to update the prices.
    ///
    /// @dev Reverts if update is not needed or the transferred fee is not sufficient or the updateData is invalid.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param publishTimes Array of publishTimes. `publishTimes[i]` corresponds to known `publishTime` of `priceIds[i]`
    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable;

    /// @notice Returns the required fee to update an array of price updates.
    /// @param updateData Array of price update data.
    /// @return feeAmount The required fee in Wei.
    function getUpdateFee(
        bytes[] calldata updateData
    ) external view returns (uint feeAmount);

    /// @notice Parse `updateData` and return price feeds of the given `priceIds` if they are all published
    /// within `minPublishTime` and `maxPublishTime`.
    ///
    /// You can use this method if you want to use a Pyth price at a fixed time and not the most recent price;
    /// otherwise, please consider using `updatePriceFeeds`. This method does not store the price updates on-chain.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    ///
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid or there is
    /// no update for any of the given `priceIds` within the given time range.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param minPublishTime minimum acceptable publishTime for the given `priceIds`.
    /// @param maxPublishTime maximum acceptable publishTime for the given `priceIds`.
    /// @return priceFeeds Array of the price feeds corresponding to the given `priceIds` (with the same order).
    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable returns (PythStructs.PriceFeed[] memory priceFeeds);

    /// @notice Similar to `parsePriceFeedUpdates` but ensures the updates returned are
    /// the first updates published in minPublishTime. That is, if there are multiple updates for a given timestamp,
    /// this method will return the first update.
    ///
    ///
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid or there is
    /// no update for any of the given `priceIds` within the given time range and uniqueness condition.
    /// @param updateData Array of price update data.
    /// @param priceIds Array of price ids.
    /// @param minPublishTime minimum acceptable publishTime for the given `priceIds`.
    /// @param maxPublishTime maximum acceptable publishTime for the given `priceIds`.
    /// @return priceFeeds Array of the price feeds corresponding to the given `priceIds` (with the same order).
    function parsePriceFeedUpdatesUnique(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable returns (PythStructs.PriceFeed[] memory priceFeeds);
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @title IPythEvents contains the events that Pyth contract emits.
/// @dev This interface can be used for listening to the updates for off-chain and testing purposes.
interface IPythEvents {
    /// @dev Emitted when the price feed with `id` has received a fresh update.
    /// @param id The Pyth Price Feed ID.
    /// @param publishTime Publish time of the given price update.
    /// @param price Price of the given price update.
    /// @param conf Confidence interval of the given price update.
    event PriceFeedUpdate(
        bytes32 indexed id,
        uint64 publishTime,
        int64 price,
        uint64 conf
    );

    /// @dev Emitted when a batch price update is processed successfully.
    /// @param chainId ID of the source chain that the batch price update comes from.
    /// @param sequenceNumber Sequence number of the batch price update.
    event BatchPriceFeedUpdate(uint16 chainId, uint64 sequenceNumber);
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract PythStructs {
    // A price with a degree of uncertainty, represented as a price +- a confidence interval.
    //
    // The confidence interval roughly corresponds to the standard error of a normal distribution.
    // Both the price and confidence are stored in a fixed-point numeric representation,
    // `x * (10^expo)`, where `expo` is the exponent.
    //
    // Please refer to the documentation at https://docs.pyth.network/documentation/pythnet-price-feeds/best-practices for how
    // to how this price safely.
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }

    // PriceFeed represents a current aggregate price from pyth publisher feeds.
    struct PriceFeed {
        // The price ID.
        bytes32 id;
        // Latest available price
        Price price;
        // Latest available exponentially-weighted moving average price
        Price emaPrice;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

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

// contracts/Bridge.sol
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ILiquidationCalculator} from "../interfaces/ILiquidationCalculator.sol";
import {IHubPriceUtilities} from "../interfaces/IHubPriceUtilities.sol";
import {IAssetRegistry} from "../interfaces/IAssetRegistry.sol";
import {IWormholeTunnel} from "../interfaces/IWormholeTunnel.sol";

/**
 * @title HubSpokeStructs
 * @notice A set of structs and enums used in the Hub and Spoke contracts
 */
library HubSpokeStructs {
    /**
     * @param wormhole: Address of the Wormhole contract
     * @param tokenBridge: Address of the TokenBridge contract
     * @param wormholeRelayer: Address of the WormholeRelayer contract
     * @param consistencyLevel: Desired level of finality the Wormhole guardians will reach before signing the messages
     * NOTE: consistencyLevel = 200 will result in an instant message, while all other values will wait for finality
     * Recommended finality levels can be found here: https://book.wormhole.com/reference/contracts.html
     * @param pythAddress: Address of the Pyth oracle on the Hub chain
     * @param priceStandardDeviations: priceStandardDeviations = (psd * priceStandardDeviationsPrecision), where psd is
     * the number of standard deviations that we use for our price intervals in calculations relating to allowing
     * withdraws, borrows, or liquidations
     * @param priceStandardDeviationsPrecision: A precision number that allows us to represent our desired noninteger
     * price standard deviation as an integer (psd = priceStandardDeviations/priceStandardDeviationsPrecision)
     * @param maxLiquidationPortionPrecision: A precision number that allows us to represent our desired noninteger
     * max liquidation portion mlp as an integer (mlp = maxLiquidationPortion/maxLiquidationPortionPrecision)
     * @param interestAccrualIndexPrecision: A precision number that allows us to represent our noninteger interest
     * accrual indices as integers; we store each index as its true value multiplied by interestAccrualIndexPrecision
     * @param collateralizationRatioPrecision: A precision number that allows us to represent our noninteger
     * collateralization ratios as integers; we store each ratio as its true value multiplied by
     * collateralizationRatioPrecision
     * @param liquidationFee: The fee taken by the protocol on liquidation
     * @param _circleMessageTransmitter: Cicle Message Transmitter contract (cctp)
     * @param _circleTokenMessenger: Cicle Token Messenger contract (cctp)
     * @param _USDC: USDC token contract (cctp)
     */
    struct ConstructorArgs {
        /* Liquidation Information */
        uint256 interestAccrualIndexPrecision;
        uint256 liquidationFee;
        uint256 liquidationFeePrecision;
        /* WormholeTunnel */
        IWormholeTunnel wormholeTunnel;
    }

    struct StoredVaultAmount {
        DenormalizedVaultAmount amounts;
        AccrualIndices accrualIndices;
    }

    struct DenormalizedVaultAmount {
        uint256 deposited;
        uint256 borrowed;
    }

    struct NotionalVaultAmount {
        uint256 deposited;
        uint256 borrowed;
    }

    struct AccrualIndices {
        uint256 deposited;
        uint256 borrowed;
    }

    struct UserActionPayload {
        bytes32 user;
        Action action;
        bytes32 asset;
        uint256 amount;
    }

    struct InstantActionPayload {
        bytes32 user;
        Action action;
        bytes32 token;
        uint256 amount;
        uint256 nonce;
        uint256 spokeDeposits;
    }

    struct ConfirmCreditPayload {
        Credit credit;
    }

    struct ReleaseFundsPayload {
        bytes32 user;
        bytes32 token;
        uint256 amount;
        uint256 nonce;
        bool unwrapWeth;
    }

    struct ConfirmTopUpPayload {
        bytes32 token;
        uint256 amount;
    }

    struct ConfirmFixLostCreditPayload {
        bytes32 token;
        uint256 amount;
    }

    struct FinalizeCreditPayload {
        Credit credit;
    }

    enum Action {      // mapping to use in Laika so that I don't have to count each time
        Deposit,       // 0
        Borrow,        // 1
        Withdraw,      // 2
        Repay,         // 3
        DepositNative, // 4
        RepayNative,   // 5
        WithdrawNative,// 6
        BorrowNative   // 7
    }

    enum ActionDirection {
        Inbound, // receiving tokens from user: Deposit (+native), Repay (+native)
        Outbound // sending tokens to user: Withdraw (+native), Borrow (+native)
    }

    enum CreditStatus {
        PENDING,     // before confirmation arrives
        CONFIRMED,   // after Hub confirms it
        REFUNDABLE,  // if it gets finalized, but hasn't been confirmed earlier
        FINALIZED,   // after it gets finalized. terminal status.
        REFUNDED,    // after a refund is processed. terminal status.
        LOST         // after a credit conflict is found. this means that the deposit/repay was accounted for, but the Credit got reorg'd and there now is a deficit. terminal status.
    }

    struct Credit {
        bytes32 user;
        bytes32 token;
        uint256 creditedAmount;
        uint256 forwardedAmount;
        uint256 nonce;
        uint256 createdAt;
        uint256 updatedAt;
        CreditStatus status;
    }

    struct SpokeBalances {
        uint256 creditGiven; // amount of tokens sent by the user to the Spoke, but not yet finalized
        uint256 creditLost; // amount of credit that got reorg'd and then stolen
        uint256 unlocksPending; // amount of non-finalized Spoke-side deposits
        uint256 creditLimit; // the limit of tokens that can be sent in flight
        uint256 custodyLimit; // the limit of tokens that can be held in custody
        uint256 transactionLimit; // the limit of tokens that can be transferred in a single TX
        uint256 deposits; // the amount of finalized tokens that are user deposits (as opposed to credit or protocol reserves. deposits = balance - reserve - credit)
        uint256 lastUpdated; // the last block timestamp the balances were updated
    }

    struct SpokeFundRelease {
        uint256 nonce;     // the user nonce of the release
        bytes32 user;      // the user receiving the released tokens
        bytes32 token;     // the token being released
        uint256 amount;    // the amount being released
        uint256 releasedAt;// the timestamp of the release
    }

    struct HubSpokeBalances {
        uint256 finalized;
        uint256 unfinalized;
    }

    struct SpokeState {
        bytes32 spoke; // the address of the Spoke
        bytes32 wrappedNativeAsset; // the address of the wrapped native asset on the Spoke chain
        // token address as bytes32 => SpokeBalances
        mapping(bytes32 => HubSpokeBalances) balances;
        // user as bytes32 => nonce => Credit struct
        mapping(bytes32 => mapping(uint256 => Credit)) credits;
        // user as bytes32 => nonce
        mapping(bytes32 => uint256) maxNonces;

        uint256[50] __gap; // gap for additional params
    }

    struct HubState {
        // number of confirmations for wormhole messages
        uint8 _deprecated_consistencyLevel;
        // vault for lending. user => token => amounts
        mapping(address => mapping(address => HubSpokeStructs.StoredVaultAmount)) vault;
        // total asset amounts (tokenAddress => (uint256, uint256))
        mapping(address => HubSpokeStructs.StoredVaultAmount) totalAssets;
        // interest accrual indices
        mapping(address => HubSpokeStructs.AccrualIndices) indices;
        // last timestamp for update
        mapping(address => uint256) lastActivityBlockTimestamps;
        // interest accrual rate precision level
        uint256 interestAccrualIndexPrecision;
        // calculator for liquidation amounts
        ILiquidationCalculator liquidationCalculator;
        // price utilities for getting prices
        IHubPriceUtilities priceUtilities;
        // asset registry for getting asset info
        IAssetRegistry assetRegistry;
        // protocol fee taken on liquidation
        uint256 liquidationFee;
        // for wormhole relay quotes
        uint256 defaultGasLimit;
        // for refunding of returnCost amount
        uint256 refundGasLimit;
        // toggle for using CCTP for asset => USDC
        bool _deprecated_isUsingCCTP;
        // the precision of the liquidation fee
        uint256 liquidationFeePrecision;
        // chainId => SpokeParams
        mapping(uint16 => SpokeState) spokeStates;

        IWormholeTunnel wormholeTunnel;

        // this mirrors the spokeBalances but as wrapped addresses
        // this is done so that reserves can be computed without knowing the Spoke address of the token
        // this will be deprecated once we move to full Spoke custody of funds
        mapping(address => HubSpokeBalances) wrappedTokenSpokeBalances;
    }

    struct SpokeCommunicationState {
        IWormholeTunnel wormholeTunnel;
        uint16 hubChainId;
        bytes32 hubContractAddress;
        uint256 defaultGasLimitRoundtrip;
        uint256[50] __gap;
    }

    struct SpokeOptimisticFinalityState {
        uint256 inboundTokenInstantMessageFee; // the percentage fee for instant messages accepting tokens. INSTANT_MESSAGE_FEE_PRECISION = 100%
        uint256 outboundTokenInstantMessageFee; // the percentage fee for instant messages sending tokens. INSTANT_MESSAGE_FEE_PRECISION = 100%
        mapping(bytes32 => HubSpokeStructs.SpokeBalances) tokenBalances; // bytes32 (wormhole format) address of the token => SpokeBalances
        mapping(address => mapping(uint256 => HubSpokeStructs.Credit)) storedCredits; // user => nonce => Credit
        mapping(address => mapping(uint256 => HubSpokeStructs.SpokeFundRelease)) fundReleases; // user => nonce => SpokeFundRelease
        mapping(address => uint256) lastInstantActionNonces; // user => nonce
        uint256 avgTransactionsPerTopUp;
        uint256[50] __gap;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "@wormhole/interfaces/IWETH.sol";
import "../contracts/HubSpokeStructs.sol";

interface IAssetRegistry {
    struct AssetInfo {
        uint256 collateralizationRatioDeposit;
        uint256 collateralizationRatioBorrow;
        uint8 decimals;
        address interestRateCalculator;
        bool exists;
        uint256 borrowLimit;
        uint256 supplyLimit;
        uint256 maxLiquidationPortion;
        uint256 maxLiquidationBonus; // 1e6 precision; 130e4 = 130% = 1.3; the liquidator gets 30% over what he repays
    }

    function registerAsset(
        address assetAddress,
        uint256 collateralizationRatioDeposit,
        uint256 collateralizationRatioBorrow,
        address interestRateCalculator,
        uint256 maxLiquidationPortion,
        uint256 maxLiquidationBonus
    ) external;

    function getAssetInfo(address assetAddress) external view returns (AssetInfo memory);

    function setAssetParams(
        address assetAddress,
        uint256 borrowLimit,
        uint256 supplyLimit,
        uint256 maxLiquidationPortion,
        uint256 maxLiquidationBonus,
        address interestRateCalculatorAddress
    ) external;

    function setCollateralizationRatios(address _asset, uint256 _deposit, uint256 _borrow) external;

    function getRegisteredAssets() external view returns (address[] memory);

    function getCollateralizationRatioPrecision() external view returns (uint256);

    function getMaxLiquidationPortionPrecision() external view returns (uint256);

    function WETH() external view returns (IWETH);

    function getMaxDecimals() external view returns (uint8);
}

// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "../contracts/HubSpokeStructs.sol";
import "./ILiquidationCalculator.sol";
import "./IHubPriceUtilities.sol";
import "./IAssetRegistry.sol";
import {IWormholeTunnel} from "./IWormholeTunnel.sol";

/**
 * @notice interface for external contracts that need to access Hub state
 */
interface IHub {
    function checkVaultHasAssets(address vault, address assetAddress, uint256 normalizedAmount)
        external
        view;

    function checkProtocolGloballyHasAssets(
        address assetAddress,
        uint256 normalizedAmount
    ) external view;

    function checkProtocolGloballyHasAssets(
        address assetAddress,
        uint256 normalizedAmount,
        uint256 borrowLimit
    ) external view;

    function getInterestAccrualIndices(address assetAddress)
        external
        view
        returns (HubSpokeStructs.AccrualIndices memory);

    function getInterestAccrualIndexPrecision() external view returns (uint256);

    function getVaultAmounts(address vaultOwner, address assetAddress)
        external
        view
        returns (HubSpokeStructs.DenormalizedVaultAmount memory);

    function getCurrentAccrualIndices(address assetAddress)
        external
        view
        returns (HubSpokeStructs.AccrualIndices memory);

    function updateAccrualIndices(address assetAddress) external;

    function getLastActivityBlockTimestamp(address assetAddress) external view returns (uint256);

    function getGlobalAmounts(address assetAddress) external view returns (HubSpokeStructs.DenormalizedVaultAmount memory);

    function getReserveAmount(address assetAddress) external view returns (uint256);

    function getSpokeBalances(uint16 chainId, bytes32 homeAddress) external view returns (HubSpokeStructs.HubSpokeBalances memory);

    function getSpokeBalances(address wrappedTokenAddress) external view returns (HubSpokeStructs.HubSpokeBalances memory);

    function getLiquidationCalculator() external view returns (ILiquidationCalculator);

    function getPriceUtilities() external view returns (IHubPriceUtilities);

    function getAssetRegistry() external view returns (IAssetRegistry);

    function getLiquidationFeeAndPrecision() external view returns (uint256, uint256);

    function liquidation(ILiquidationCalculator.LiquidationInput memory input) external;

    function userActions(HubSpokeStructs.Action action, address asset, uint256 amount) external payable;

    function userActionMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external payable;

    function instantActionMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external;

    function finalizeCreditMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external;

    function confirmTopUpMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external;

    function confirmFixLostCreditMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "./IHub.sol";
import "./IAssetRegistry.sol";
import "./ISynonymPriceOracle.sol";
import "../contracts/HubSpokeStructs.sol";

interface IHubPriceUtilities {
    function getAssetRegistry() external view returns (IAssetRegistry);
    function getPrices(address assetAddress) external view returns (uint256, uint256, uint256, uint256);
    function getVaultEffectiveNotionals(address vaultOwner, bool collateralizationRatios) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function calculateNotionals(address asset, HubSpokeStructs.DenormalizedVaultAmount memory vaultAmount) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function calculateEffectiveNotionals(address asset, HubSpokeStructs.DenormalizedVaultAmount memory vaultAmount) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function invertNotionals(address asset, HubSpokeStructs.NotionalVaultAmount memory realValues) external view returns (HubSpokeStructs.DenormalizedVaultAmount memory);
    function applyCollateralizationRatios(address asset, HubSpokeStructs.NotionalVaultAmount memory vaultAmount) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function removeCollateralizationRatios(address asset, HubSpokeStructs.NotionalVaultAmount memory vaultAmount) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function getHub() external view returns (IHub);
    function setHub(IHub _hub) external;
    function getPriceOracle() external view returns (ISynonymPriceOracle);
    function setPriceOracle(ISynonymPriceOracle _priceOracle) external;
    function getPriceStandardDeviations() external view returns (uint256, uint256);
    function setPriceStandardDeviations(uint256 _priceStandardDeviations, uint256 _precision) external;
}

// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "../contracts/HubSpokeStructs.sol";

interface ILiquidationCalculator {
    /**
     * @param assetAddress - The address of the repaid/received asset
     * @param repaidAmount - The amount of the asset that is being repaid (can be zero)
     * @param receivedAmount - The amount of the asset that is being received (can be zero)
     * @param depositTakeover - A flag if the liquidator will take the deposit of the debtor instead of collateral tokens
     */
    struct DenormalizedLiquidationAsset {
        address assetAddress;
        uint256 repaidAmount;
        uint256 receivedAmount;
        bool depositTakeover;
    }

    /**
     * @param vault - the address of the vault that is being liquidated
     */
    struct LiquidationInput {
        address vault;
        DenormalizedLiquidationAsset[] assets;
    }

    function getMaxHealthFactor() external view returns (uint256, uint256);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ISynonymPriceSource} from "./ISynonymPriceSource.sol";

interface ISynonymPriceOracle is ISynonymPriceSource {
    struct PriceSource {
        ISynonymPriceSource priceSource;
        uint256 maxPriceAge;
    }

    function sequencerUptimeFeed() external view returns (AggregatorV3Interface);
    function sequencerGracePeriod() external view returns (uint256);
    function getPrice(address _asset) external view returns (Price memory price);
    function setPriceSource(address _asset, PriceSource memory _priceSource) external;
    function removePriceSource(address _asset) external;
    function getPriceSource(address _asset) external view returns (PriceSource memory);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ISynonymPriceSource {
    error NoPriceForAsset();
    error StalePrice();

    struct Price {
        uint256 price;
        uint256 confidence;
        uint256 precision;
        uint256 updatedAt;
    }

    function getPrice(address _asset, uint256 _maxAge) external view returns (Price memory price);
    function priceAvailable(address _asset) external view returns (bool);
    function outputAsset() external view returns (string memory);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWormholeTunnel {
    error InsufficientMsgValue();
    error InvalidCCTPConfig();
    error InvalidTunnelMessage();
    error InvalidVaa();
    error OnlyWormholeRelayer();
    error ReplayProtection();
    error SameChainCallsNotSupported();
    error TransferFailed();
    error TunnelEndNotRegistered();

    event CCTPConfigChanged(address indexed messageTransmitter, address indexed tokenMessenger, address indexed usdc);
    event TunnelEndRegistered(uint16 indexed chainId, bytes32 indexed sender, bool supportsCCTP);
    event TargetReverted(bytes ret);

    enum MessageFinality {
        FINALIZED,
        SAFE,
        INSTANT
    }

    struct TunnelMessage {
        MessageSource source; // defines the sender of the message and the chain it's coming from
        MessageTarget target; // defines the recipient of the message and the chain it's going to
        bytes32 token; // the address of the token sent along with the message (optional)
        uint256 amount; // the amount of the token sent along with the message (optional)
        uint256 receiverValue; // the value that the message recipient is supposed to receive in target chain native currency (optional)
        MessageFinality finality; // the finality of the message
    }

    struct MessageSource {
        uint16 chainId; // the chain id of the sender
        bytes32 sender; // the address of the sender
        // the address that should receive any WH cost refunds on target chain.
        // in case the message recipient reverts and tokens were sent, the tokens will be returned to this address on source chain
        bytes32 refundRecipient;
    }

    struct MessageTarget {
        uint16 chainId; // the chain id of the recipient
        bytes32 recipient; // the address of the recipient of the message on the target chain
        bytes4 selector; // if the recipient is a contract, the selector of the function to call (optional)
        bytes payload; // if the recipient is a contract, the data to send to the function call (optional)
    }

    /**
     * @dev sends a message assuming the target chain is EVM
     * @param _message the message to send
     * @param _gasLimit the gas limit for the message
     */
    function sendEvmMessage(
        TunnelMessage calldata _message,
        uint256 _gasLimit
    ) external payable;

    /**
     * @dev sends a message providing no additional execution parameters (for gasless chains or custom relayers)
     * @param _message the message to send
     */
    function sendMessage(
        TunnelMessage calldata _message
    ) external payable;

    /**
     * @dev sends a message providing additional encoded execution parameters
     * @param _message the message to send
     * @param encodedExecutionParams the encoded execution parameters
     */
    function sendMessage(
        TunnelMessage calldata _message,
        bytes calldata encodedExecutionParams
    ) external payable;

    /**
     * @dev whether this tunnel supports Circle's CCTP
     */
    function supportsCCTP() external view returns (bool);

    /**
     * @dev whether the tunnel end on a given chain supports Circle's CCTP
     */
    function tunnelEndSupportsCCTP(uint16 _chainId) external view returns (bool);

    /**
     * @dev the chain id of the tunnel
     */
    function chainId() external view returns (uint16);

    /**
     * @dev the gas required for the tunnel to send a message with a token transfer
     *      this is on top of any gas required with cross chain contract calls and only covers what the tunnel uses
     */
    function GAS_USAGE_WITH_TOKEN() external view returns (uint256);


    /**
     * @dev the gas required for the tunnel to send a message without a token transfer
     *      same as above, but without the token transfer
     */
    function GAS_USAGE_WITHOUT_TOKEN() external view returns (uint256);

    /**
     * @dev gets the address of a token on the current chain
     *      handles both CCTP USDC translation and TokenBridge wrapped tokens (native addr -> wrapped addr)
     *      can't handle "unbridging" tokens (getting the original token asset from a bridged asset address)
     * @param tokenHomeChain the chain id of the token
     * @param tokenHomeAddress the address of the token on the home chain
     */
    function getTokenAddressOnThisChain(uint16 tokenHomeChain, bytes32 tokenHomeAddress) external view returns (address);

    /**
     * @dev gets the cost of sending a message
     * @param _targetChain the chain id of the target chain
     * @param _gasLimitOnTarget the gas limit for parsing and executing the message
     * @param _receiverValue the value that the message recipient is supposed to receive in target chain native currency
     * @param _withTokenTransfer whether the message includes a token transfer
     */
    function getMessageCost(uint16 _targetChain, uint256 _gasLimitOnTarget, uint256 _receiverValue, bool _withTokenTransfer) external view returns (uint256 cost);

    /**
     * @dev checks if an amount is valid for a token transfer. WH TokenBridge limits amounts to 8 decimals. USDC through CCTP is assumed ok.
     * @param token the address of the token
     * @param amount the amount to transfer
     */
    function isValidAmount(IERC20 token, uint256 amount) external view returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "@wormhole/interfaces/IWETH.sol";

import {HubSpokeStructs} from "../../../contracts/HubSpokeStructs.sol";

library CommonAccountingLogic {
    using SafeERC20 for IERC20;

    error InsufficientMsgValue();
    error UnusedParameterMustBeZero();

    function handleInboundTokensAndAdjustAction(
        HubSpokeStructs.Action _action,
        address _asset,
        uint256 _amount,
        IWETH _weth
    ) public returns (
        HubSpokeStructs.Action action,
        address asset,
        uint256 amount
    ) {
        (action, asset, amount, ) = handleInboundTokensAndAdjustAction(_action, _asset, _amount, _weth, 0);
    }

    function handleInboundTokensAndAdjustAction(
        HubSpokeStructs.Action _action,
        address _asset,
        uint256 _amount,
        IWETH _weth,
        uint256 _cost
    ) public returns (
        HubSpokeStructs.Action action,
        address asset,
        uint256 amount,
        uint256 remainingMsgValue
    ) {
        action = _action;
        asset = _asset;
        amount = _amount;
        remainingMsgValue = msg.value;
        if (action == HubSpokeStructs.Action.RepayNative || action == HubSpokeStructs.Action.DepositNative) {
            if (asset != address(0) || amount != 0) revert UnusedParameterMustBeZero();
            if (msg.value <= _cost) {
                revert InsufficientMsgValue();
            }

            asset = address(_weth);
            amount = msg.value - _cost;
            _weth.deposit{value: amount}();
            action = action == HubSpokeStructs.Action.RepayNative ? HubSpokeStructs.Action.Repay : HubSpokeStructs.Action.Deposit;
            remainingMsgValue = _cost;
        } else if (action == HubSpokeStructs.Action.Deposit || action == HubSpokeStructs.Action.Repay) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        }
        // the else case here is that the action was a Withdraw (+native) or a Borrow (+native), which have no inbound tokens
        // in such case, this function is a no-op pass-through
    }
}