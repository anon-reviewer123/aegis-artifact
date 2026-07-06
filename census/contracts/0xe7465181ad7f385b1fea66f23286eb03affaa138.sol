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
pragma solidity 0.8.24;
pragma abicoder v1;

import "../interfaces/AerodromeBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AerodromeBaseHelper
 * @notice Helper that performs onchain calculation required to call an Aerodrome base pool
 */
abstract contract AerodromeBaseHelper {
    function swapAerodromeBase(
        uint256 amount,
        AerodromBasePool pool,
        address tokenIn,
        address tokenOut
    ) external view returns (address target, address sourceTokenInteractionTarget, uint256 actualSwapAmount, bytes memory data) {
        uint256 amountOut = pool.getAmountOut(amount, tokenIn);

        (address token0, ) = sortTokens(tokenIn, tokenOut);

        (uint256 amount0Out, uint256 amount1Out) = tokenIn == token0
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        bytes memory resultData = abi.encodeCall(pool.swap, (amount0Out, amount1Out, msg.sender, ""));
        return (address(pool), address(pool), amount, resultData);
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../interfaces/AmbientSwapDex.sol";

abstract contract AmbientHelper{
    uint128 internal constant MIN_SQRT_RATIO = 65538;
    uint128 internal constant MAX_SQRT_RATIO = 21267430153580247136652501917186561138;

    function swapAmbient(
        AmbientSwapDex pool, address base,
        address quote, uint256 poolIdx,
        bool isBuy, uint128 qty,
        uint128 minOut
    ) external pure returns (
        address target, address sourceTokenInteractionTarget,
        uint256 actualSwapAmount, bytes memory data
    ){

        bool inBaseQty = isBuy;
        uint128 limitPrice = isBuy ? MAX_SQRT_RATIO : MIN_SQRT_RATIO;

        bytes memory callParams = abi.encode(
            base,
            quote,
            poolIdx,
            isBuy,
            inBaseQty,
            qty,
            0, // Set tip to 0
            limitPrice,
            minOut,
            0 // set Settle flags to 0
        );

        bytes memory resultData = abi.encodeCall(pool.userCmd, (1, callParams));
        return (address(pool), address(pool), uint256(qty), resultData);

    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

import "../interfaces/DodoV1.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DodoV1Helper
 * @notice Helper that performs onchain calculation required to call a Dodo v1 contract and returns corresponding caller and data
 */
abstract contract DodoV1Helper {
    using SafeERC20 for IERC20;

    function swapQuoteTokenDodoV1(
        uint256 sellAmount,
        IDODO pool,
        IDODOHelper helper
    ) external view returns (address target, address sourceTokenInteractionTarget, uint256 actualSwapAmount, bytes memory data) {
        uint256 boughtAmount = helper.querySellQuoteToken(pool, sellAmount);
        bytes memory resultData = abi.encodeCall(pool.buyBaseToken, (boughtAmount, sellAmount, ""));
        return (address(pool), address(pool), sellAmount, resultData);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

import "../interfaces/DssPsm.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DssPsmHelper
 * @notice Helper that allows to use dai amount to buy gem
 */
abstract contract DssPsmHelper {
    using SafeERC20 for IERC20;

    uint256 constant private WAD = 1e18;
    uint256 constant private TO18CONVERSION_FACTOR = 1000000000000;

    function buyGemInverted(
        uint256 amountSpecified,
        DssPsm dssPsm,
        address recipient
    ) external view returns (address target, address sourceTokenInteractionTarget, uint256 actualSwapAmount, bytes memory data) {
        uint256 tout = dssPsm.tout();
        uint256 gemAmt = amountSpecified / TO18CONVERSION_FACTOR;
        if (tout > 0) {
            gemAmt = (amountSpecified * WAD)/(WAD + tout);
        }
        bytes memory resultData = abi.encodeCall(dssPsm.buyGem, (recipient, gemAmt));
        // Value is 0 because DssPsm is not payable
        return (address(dssPsm), address(dssPsm), amountSpecified, resultData);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../interfaces/Hashflow.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title HashflowHelper
 * @notice Helper that performs onchain calculation required to call a Haashflow contract and returns corresponding caller and data
 */
abstract contract HashflowHelper {
    using SafeERC20 for IERC20;

    function swapHashflow(
        uint256 amount,
        IHashflowRouter hashflow,
        IHashflowRouter.RFQTQuote memory quote
    ) external pure returns (address target, address sourceTokenInteractionTarget, uint256 actualSwapAmount, bytes memory data) {
        if (amount > quote.baseTokenAmount) {
            quote.effectiveBaseTokenAmount = quote.baseTokenAmount;
        } else {
            quote.effectiveBaseTokenAmount = amount;
        }
        bytes memory resultData = abi.encodeCall(hashflow.tradeRFQT, quote);
        return (address(hashflow), address(hashflow), quote.effectiveBaseTokenAmount, resultData);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

import "../interfaces/UniswapV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title HashflowHelper
 * @notice Helper that performs onchain calculation required to call a Uniswap V2 contract and returns corresponding caller and data
 */
abstract contract UniswapV2Helper {
    using SafeERC20 for IERC20;

    function swapUniswapV2(
        uint256 amountSpecified,
        IUniswapV2Pair pair,
        address recipient,
        IERC20 sourceToken,
        IERC20 targetToken
    ) external view returns (address target, address sourceTokenInteractionTarget, uint256 actualSwapAmount, bytes memory data) {
        (uint256 result0, uint256 result1) = _calcInOutAmounts(
            pair,
            sourceToken,
            targetToken,
            amountSpecified
        );
        bytes memory resultData = abi.encodeCall(pair.swap, (result0, result1, recipient, ""));
        return (address(pair), address(pair), amountSpecified, resultData);
    }

    function _calcInOutAmounts(
        IUniswapV2Pair pair,
        IERC20 sourceToken,
        IERC20 targetToken,
        uint256 amountIn
    ) private view returns (uint256 result0, uint256 result1) {
        (uint256 reserveIn, uint256 reserveOut, ) = pair.getReserves();
        if (sourceToken > targetToken) {
            (reserveIn, reserveOut) = (reserveOut, reserveIn);
        }
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        unchecked {
            uint256 amountOut = numerator / denominator;

            return
                address(sourceToken) < address(targetToken)
                    ? (uint256(0), amountOut)
                    : (amountOut, uint256(0));
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

import "../libs/LowLevelHelper.sol";

abstract contract UniswapV4Helper {
    function swapUniswapV4(
        bytes calldata originalData,
        uint256 newAmountIn,
        uint256 offset1,
        uint256 offset2,
        address routerAddress
    ) external pure returns (address target, address sourceTokenInteractionTarget, uint256 actualSwapAmount, bytes memory data) {
        data = LowLevelHelper.patchUint2(originalData,
            newAmountIn, /* -> */ offset1,
            newAmountIn, /* -> */ offset2
        );

        target = routerAddress;
        sourceTokenInteractionTarget = routerAddress;
        actualSwapAmount = newAmountIn;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

import "../libs/LowLevelHelper.sol";

abstract contract ValantisHelper {
    function swapValantis(
        bytes calldata originalData,
        uint256 newAmountIn,
        uint256 offsetIn,
        uint256 offsetOut,
        address poolAddress
    ) external pure returns (address target, address sourceTokenInteractionTarget, uint256 actualSwapAmount, bytes memory data) {
        uint256 origAmountIn = LowLevelHelper.readUint(originalData, offsetIn);

        if (newAmountIn < origAmountIn) {
            uint256 newAmountOut = LowLevelHelper.readUint(originalData, offsetOut) * newAmountIn / origAmountIn;
            data = LowLevelHelper.patchUint2(originalData,
                newAmountOut, /* -> */ offsetOut,
                newAmountIn,  /* -> */ offsetIn
            );
        } else {
            newAmountIn = origAmountIn;
            data = originalData;
        }

        target = poolAddress;
        sourceTokenInteractionTarget = poolAddress;
        actualSwapAmount = newAmountIn;
    }
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.24;

interface AerodromBasePool {
    /// @notice This low-level function should be called from a contract which performs important safety checks
    /// @param amount0Out   Amount of token0 to send to `to`
    /// @param amount1Out   Amount of token1 to send to `to`
    /// @param to           Address to recieve the swapped output
    /// @param data         Additional calldata for flashloans
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice Get the amount of tokenOut given the amount of tokenIn
    /// @param amountIn Amount of token in
    /// @param tokenIn  Address of token
    /// @return Amount out
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface AmbientSwapDex {
    function readSlot (uint256 slot) external view returns (uint256 data);

    function userCmd (uint16 callpath, bytes calldata cmd)
        external payable returns (bytes memory);

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

interface IDODO {
    function sellBaseToken(
        uint256 amount,
        uint256 minReceiveQuote,
        bytes calldata data
    ) external returns (uint256);

    function buyBaseToken(
        uint256 amount,
        uint256 maxPayQuote,
        bytes calldata data
    ) external returns (uint256);
}

interface IDODOHelper {
    function querySellQuoteToken(IDODO dodo, uint256 amount)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

interface DssPsm {
    function tin() external view returns (uint256);
    function tout() external view returns (uint256);

    function sellGem(address usr, uint256 gemAmt) external;
    function buyGem(address usr, uint256 gemAmt) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IQuote
/// @author Victor Ionescu
/**
 * @notice Interface for quote structs used for trading. There are two major types of trades:
 * - intra-chain: atomic transactions within one chain
 * - cross-chain: multi-leg transactions between two chains, which utilize interoperability protocols
 *                such as Wormhole.
 *
 * Separately, there are two trading modes:
 * - RFQ-T: the trader signs the transaction, the market maker signs the quote
 * - RFQ-M: both the trader and Market Maker sign the quote, any relayer can sign the transaction
 */
interface IQuote {
    /// @notice Used for intra-chain RFQ-T trades.
    struct RFQTQuote {
        /// @notice The address of the HashflowPool to trade against.
        address pool;
        /**
         * @notice The external account linked to the HashflowPool.
         * If the HashflowPool holds funds, this should be address(0).
         */
        address externalAccount;
        /// @notice The recipient of the quoteToken at the end of the trade.
        address trader;
        /**
         * @notice The account "effectively" making the trade (ultimately receiving the funds).
         * This is commonly used by aggregators, where a proxy contract (the 'trader')
         * receives the quoteToken, and the effective trader is the user initiating the call.
         *
         * This field DOES NOT influence movement of funds. However, it is used to check against
         * quote replay.
         */
        address effectiveTrader;
        /// @notice The token that the trader sells.
        address baseToken;
        /// @notice The token that the trader buys.
        address quoteToken;
        /**
         * @notice The amount of baseToken sold in this trade. The exchange rate
         * is going to be preserved as the quoteTokenAmount / baseTokenAmount ratio.
         *
         * Most commonly, effectiveBaseTokenAmount will == baseTokenAmount.
         */
        uint256 effectiveBaseTokenAmount;
        /// @notice The max amount of baseToken sold.
        uint256 baseTokenAmount;
        /// @notice The amount of quoteToken bought when baseTokenAmount is sold.
        uint256 quoteTokenAmount;
        /// @notice The Unix timestamp (in seconds) when the quote expires.
        /// @dev This gets checked against block.timestamp.
        uint256 quoteExpiry;
        /// @notice The nonce used by this effectiveTrader. Nonces are used to protect against replay.
        uint256 nonce;
        /// @notice Unique identifier for the quote.
        /// @dev Generated off-chain via a distributed UUID generator.
        bytes32 txid;
        /// @notice Signature provided by the market maker (EIP-191).
        bytes signature;
    }

    /// @notice Used for intra-chain RFQ-M trades.
    struct RFQMQuote {
        /// @notice The address of the HashflowPool to trade against.
        address pool;
        /**
         * @notice The external account linked to the HashflowPool.
         * If the HashflowPool holds funds, this should be address(0).
         */
        address externalAccount;
        /// @notice The account that will be debited baseToken / credited quoteToken.
        address trader;
        /// @notice The token that the trader sells.
        address baseToken;
        /// @notice The token that the trader buys.
        address quoteToken;
        /// @notice The amount of baseToken sold.
        uint256 baseTokenAmount;
        /// @notice The amount of quoteToken bought.
        uint256 quoteTokenAmount;
        /// @notice The Unix timestamp (in seconds) when the quote expires.
        /// @dev This gets checked against block.timestamp.
        uint256 quoteExpiry;
        /// @notice Unique identifier for the quote.
        /// @dev Generated off-chain via a distributed UUID generator.
        bytes32 txid;
        /// @notice Signature provided by the trader (EIP-712).
        bytes takerSignature;
        /// @notice Signature provided by the market maker (EIP-191).
        bytes makerSignature;
    }

    /// @notice Used for cross-chain RFQ-T trades.
    struct XChainRFQTQuote {
        /// @notice The Hashflow Chain ID of the source chain.
        uint16 srcChainId;
        /// @notice The Hashflow Chain ID of the destination chain.
        uint16 dstChainId;
        /// @notice The address of the HashflowPool to trade against on the source chain.
        address srcPool;
        /// @notice The HashflowPool to disburse funds on the destination chain.
        /// @dev This is bytes32 in order to anticipate non-EVM chains.
        bytes32 dstPool;
        /**
         * @notice The external account linked to the HashflowPool on the source chain.
         * If the HashflowPool holds funds, this should be address(0).
         */
        address srcExternalAccount;
        /**
         * @notice The external account linked to the HashflowPool on the destination chain.
         * If the HashflowPool holds funds, this should be bytes32(0).
         */
        bytes32 dstExternalAccount;
        /// @notice The recipient of the quoteToken on the destination chain.
        bytes32 dstTrader;
        /// @notice The token that the trader sells on the source chain.
        address baseToken;
        /// @notice The token that the trader buys on the destination chain.
        bytes32 quoteToken;
        /**
         * @notice The amount of baseToken sold in this trade. The exchange rate
         * is going to be preserved as the quoteTokenAmount / baseTokenAmount ratio.
         *
         * Most commonly, effectiveBaseTokenAmount will == baseTokenAmount.
         */
        uint256 effectiveBaseTokenAmount;
        /// @notice The amount of baseToken sold.
        uint256 baseTokenAmount;
        /// @notice The amount of quoteToken bought.
        uint256 quoteTokenAmount;
        /**
         * @notice The Unix timestamp (in seconds) when the quote expire. Only enforced
         * on the source chain.
         */
        /// @dev This gets checked against block.timestamp.
        uint256 quoteExpiry;
        /// @notice The nonce used by this trader.
        uint256 nonce;
        /// @notice Unique identifier for the quote.
        /// @dev Generated off-chain via a distributed UUID generator.
        bytes32 txid;
        /**
         * @notice The address of the IHashflowXChainMessenger contract used for
         * cross-chain communication.
         */
        address xChainMessenger;
        /// @notice Signature provided by the market maker (EIP-191).
        bytes signature;
    }

    /// @notice Used for Cross-Chain RFQ-M trades.
    struct XChainRFQMQuote {
        /// @notice The Hashflow Chain ID of the source chain.
        uint16 srcChainId;
        /// @notice The Hashflow Chain ID of the destination chain.
        uint16 dstChainId;
        /// @notice The address of the HashflowPool to trade against on the source chain.
        address srcPool;
        /// @notice The HashflowPool to disburse funds on the destination chain.
        /// @dev This is bytes32 in order to anticipate non-EVM chains.
        bytes32 dstPool;
        /**
         * @notice The external account linked to the HashflowPool on the source chain.
         * If the HashflowPool holds funds, this should be address(0).
         */
        address srcExternalAccount;
        /**
         * @notice The external account linked to the HashflowPool on the destination chain.
         * If the HashflowPool holds funds, this should be bytes32(0).
         */
        bytes32 dstExternalAccount;
        /// @notice The account that will be debited baseToken on the source chain.
        address trader;
        /// @notice The recipient of the quoteToken on the destination chain.
        bytes32 dstTrader;
        /// @notice The token that the trader sells on the source chain.
        address baseToken;
        /// @notice The token that the trader buys on the destination chain.
        bytes32 quoteToken;
        /// @notice The amount of baseToken sold.
        uint256 baseTokenAmount;
        /// @notice The amount of quoteToken bought.
        uint256 quoteTokenAmount;
        /**
         * @notice The Unix timestamp (in seconds) when the quote expire. Only enforced
         * on the source chain.
         */
        /// @dev This gets checked against block.timestamp.
        uint256 quoteExpiry;
        /// @notice Unique identifier for the quote.
        /// @dev Generated off-chain via a distributed UUID generator.
        bytes32 txid;
        /**
         * @notice The address of the IHashflowXChainMessenger contract used for
         * cross-chain communication.
         */
        address xChainMessenger;
        /// @notice Signature provided by the trader (EIP-712).
        bytes takerSignature;
        /// @notice Signature provided by the market maker (EIP-191).
        bytes makerSignature;
    }
}

/// @title IHashflowRouter
/// @author Victor Ionescu
/**
 * @notice In terms of user-facing functionality, the Router is responsible for:
 * - orchestrating trades
 * - managing cross-chain permissions
 *
 * Every trade requires consent from two parties: the Trader and the Market Maker.
 * However, there are two models to establish consent:
 * - RFQ-T: in this model, the Market Maker provides an EIP-191 signature for the quote,
 *   while the Trader signs the transaction and submits it on-chain
 * - RFQ-M: in this model, the Trader provides an EIP-712 signature for the quote,
 *   the Market Maker provides an EIP-191 signature, and a 3rd party relays the trade.
 *   The 3rd party can be the Market Maker itself.
 *
 * In terms of Hashflow internals, the Router maintains a set of authorized pool
 * contracts that are allowed to be used for trading. This allowlist creates
 * guarantees against malicious behavior, as documented in specific places.
 *
 * The Router contract is not upgradeable. In order to change functionality, a new
 * Router has to be deployed, and new HashflowPool contracts have to be deployed
 * by the Market Makers.
 */
/// @dev Trade / liquidity events are emitted at the HashflowPool level, rather than the router.
interface IHashflowRouter is IQuote {
    /**
     * @notice X-Chain message received from an X-Chain Messenger. This is used by the
     * Router to communicate a fill to a HashflowPool.
     */
    struct XChainFillMessage {
        /// @notice The Hashflow Chain ID of the source chain.
        uint16 srcHashflowChainId;
        /// @notice The address of the HashflowPool on the source chain.
        bytes32 srcPool;
        /// @notice The HashflowPool to disburse funds on the destination chain.
        address dstPool;
        /**
         * @notice The external account linked to the HashflowPool on the destination chain.
         * If the HashflowPool holds funds, this should be bytes32(0).
         */
        address dstExternalAccount;
        /// @notice The recipient of the quoteToken on the destination chain.
        address dstTrader;
        /// @notice The token that the trader buys on the destination chain.
        address quoteToken;
        /// @notice The amount of quoteToken bought.
        uint256 quoteTokenAmount;
        /// @notice Unique identifier for the quote.
        /// @dev Generated off-chain via a distributed UUID generator.
        bytes32 txid;
        /// @notice The caller of the trade function on the source chain.
        bytes32 srcCaller;
        /// @notice The contract to call, if any.
        address dstContract;
        /// @notice The calldata for the contract.
        bytes dstContractCalldata;
    }

    /// @notice Emitted when the authorization status of a pool changes.
    /// @param pool The pool whose status changed.
    /// @param authorized The new auth status.
    event UpdatePoolAuthorizaton(address pool, bool authorized);

    /// @notice Emitted when a sender pool authorization changes.
    /// @param pool Pool address on this chain.
    /// @param otherHashflowChainId Hashflow Chain ID of the other chain.
    /// @param otherChainPool Pool address on the other chain.
    /// @param authorized Whether the pool is authorized.
    event UpdateXChainPoolAuthorization(
        address indexed pool,
        uint16 otherHashflowChainId,
        bytes32 otherChainPool,
        bool authorized
    );

    /// @notice Emitted when the authorization of an x-caller changes.
    /// @param pool Pool address on this chain.
    /// @param otherHashflowChainId Hashflow Chain ID of the other chain.
    /// @param caller Caller address on the other chain.
    /// @param authorized Whether the caller is authorized.
    event UpdateXChainCallerAuthorization(
        address indexed pool,
        uint16 otherHashflowChainId,
        bytes32 caller,
        bool authorized
    );

    /// @notice Emitted when the authorization status of an X-Chain Messenger changes for a pool.
    /// @param pool Pool address for which the Messenger authorization changes.
    /// @param xChainMessenger Address of the Messenger.
    /// @param authorized Whether the X-Chain Messenger is authorized.
    event UpdateXChainMessengerAuthorization(
        address indexed pool,
        address xChainMessenger,
        bool authorized
    );

    /// @notice Emitted when the authorized status of an X-Chain Messenger changes for a callee.
    /// @param callee Address of the callee.
    /// @param xChainMessenger Address of the Messenger.
    /// @param authorized Whether the X-Chain Messenger is authorized.
    event UpdateXChainMessengerCallerAuthorization(
        address indexed callee,
        address xChainMessenger,
        bool authorized
    );

    /// @notice Emitted when the Limit Order Guardian address is updated.
    /// @param guardian The new Guardian address.
    event UpdateLimitOrderGuardian(address guardian);

    /// @notice Initializes the Router. Called one time.
    /// @param factory The address of the HashflowFactory contract.
    function initialize(address factory) external;

    /// @notice Returns the address of the associated HashflowFactor contract.
    function factory() external view returns (address);

    function authorizedXChainPools(
        bytes32 dstPool,
        uint16 srcHChainId,
        bytes32 srcPool
    ) external view returns (bool);

    function authorizedXChainCallers(
        address dstContract,
        uint16 srcHashflowChainId,
        bytes32 caller
    ) external view returns (bool);

    function authorizedXChainMessengersByPool(address pool, address messenger)
        external
        view
        returns (bool);

    function authorizedXChainMessengersByCallee(
        address callee,
        address messenger
    ) external view returns (bool);

    /// @notice Executes an intra-chain RFQ-T trade.
    /// @param quote The quote data to be executed.
    function tradeRFQT(RFQTQuote memory quote) external payable;

    /// @notice Executes an intra-chain RFQ-T trade, leveraging an ERC-20 permit.
    /// @param quote The quote data to be executed.
    /// @dev Does not support native tokens for the baseToken.
    function tradeRFQTWithPermit(
        RFQTQuote memory quote,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 amountToApprove
    ) external;

    /// @notice Executes an intra-chain RFQ-T trade.
    /// @param quote The quote to be executed.
    function tradeRFQM(RFQMQuote memory quote) external;

    /// @notice Executes an intra-chain RFQ-T trade, leveraging an ERC-20 permit.
    /// @param quote The quote to be executed.
    /// @param deadline The deadline of the ERC-20 permit.
    /// @param v v-part of the signature.
    /// @param r r-part of the signature.
    /// @param s s-part of the signature.
    /// @param amountToApprove The amount being approved.
    function tradeRFQMWithPermit(
        RFQMQuote memory quote,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 amountToApprove
    ) external;

    /// @notice Executes an intra-chain RFQ-T trade.
    /// @param quote The quote to be executed.
    /// @param guardianSignature A signature issued by the Limit Order Guardian.
    function tradeRFQMLimitOrder(
        RFQMQuote memory quote,
        bytes memory guardianSignature
    ) external;

    /// @notice Executes an intra-chain RFQ-T trade, leveraging an ERC-20 permit.
    /// @param quote The quote to be executed.
    /// @param guardianSignature A signature issued by the Limit Order Guardian.
    /// @param deadline The deadline of the ERC-20 permit.
    /// @param v v-part of the signature.
    /// @param r r-part of the signature.
    /// @param s s-part of the signature.
    /// @param amountToApprove The amount being approved.
    function tradeRFQMLimitOrderWithPermit(
        RFQMQuote memory quote,
        bytes memory guardianSignature,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 amountToApprove
    ) external;

    /// @notice Executes an RFQ-T cross-chain trade.
    /// @param quote The quote to be executed.
    /// @param dstContract The address of the contract to be called on the destination chain.
    /// @param dstCalldata The calldata for the smart contract call.
    function tradeXChainRFQT(
        XChainRFQTQuote memory quote,
        bytes32 dstContract,
        bytes memory dstCalldata
    ) external payable;

    /// @notice Executes an RFQ-T cross-chain trade, leveraging an ERC-20 permit.
    /// @param quote The quote to be executed.
    /// @param dstContract The address of the contract to be called on the destination chain.
    /// @param dstCalldata The calldata for the smart contract call.
    /// @param deadline The deadline of the ERC-20 permit.
    /// @param v v-part of the signature.
    /// @param r r-part of the signature.
    /// @param s s-part of the signature.
    /// @param amountToApprove The amount being approved.
    function tradeXChainRFQTWithPermit(
        XChainRFQTQuote memory quote,
        bytes32 dstContract,
        bytes memory dstCalldata,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 amountToApprove
    ) external payable;

    /// @notice Executes an RFQ-M cross-chain trade.
    /// @param quote The quote to be executed.
    /// @param dstContract The address of the contract to be called on the destination chain.
    /// @param dstCalldata The calldata for the smart contract call.
    function tradeXChainRFQM(
        XChainRFQMQuote memory quote,
        bytes32 dstContract,
        bytes memory dstCalldata
    ) external payable;

    /// @notice Similar to tradeXChainRFQm, but includes a spend permit for the baseToken.
    /// @param quote The quote to be executed.
    /// @param dstContract The address of the contract to be called on the destination chain.
    /// @param dstCalldata The calldata for the smart contract call.
    /// @param deadline The deadline of the ERC-20 permit.
    /// @param v v-part of the signature.
    /// @param r r-part of the signature.
    /// @param s s-part of the signature.
    /// @param amountToApprove The amount to approve.
    function tradeXChainRFQMWithPermit(
        XChainRFQMQuote memory quote,
        bytes32 dstContract,
        bytes memory dstCalldata,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 amountToApprove
    ) external payable;

    /// @notice Completes the second leg of a cross-chain trade.
    /// @param fillMessage Payload containing information necessary to complete the trade.
    function fillXChain(XChainFillMessage memory fillMessage) external;

    /// @notice Returns whether the pool is authorized for trading.
    /// @param pool The address of the HashflowPool.
    function authorizedPools(address pool) external view returns (bool);

    /// @notice Allows the owner to unauthorize a potentially compromised pool. Cannot be reverted.
    /// @param pool The address of the HashflowPool.
    function forceUnauthorizePool(address pool) external;

    /// @notice Authorizes a HashflowPool for trading.
    /// @dev Can only be called by the HashflowFactory or the admin.
    function updatePoolAuthorization(address pool, bool authorized) external;

    /// @notice Updates the authorization status of an X-Chain pool pair.
    /// @param otherHashflowChainId The Hashflow Chain ID of the peer chain.
    /// @param otherPool The 32-byte representation of the Pool address on the peer chain.
    /// @param authorized Whether the pool is authorized to communicate with the sender pool.
    function updateXChainPoolAuthorization(
        uint16 otherHashflowChainId,
        bytes32 otherPool,
        bool authorized
    ) external;

    /// @notice Updates the authorization status of an X-Chain caller.
    /// @param otherHashflowChainId The Hashflow Chain ID of the peer chain.
    /// @param caller The caller address.
    /// @param authorized Whether the caller is authorized to send an x-call to the sender pool.
    function updateXChainCallerAuthorization(
        uint16 otherHashflowChainId,
        bytes32 caller,
        bool authorized
    ) external;

    /// @notice Updates the authorization status of an X-Chain Messenger app.
    /// @param xChainMessenger The address of the Messenger App.
    /// @param authorized The new authorization status.
    function updateXChainMessengerAuthorization(
        address xChainMessenger,
        bool authorized
    ) external;

    /// @notice Updates the authorization status of an X-Chain Messenger app.
    /// @param xChainMessenger The address of the Messenger App.
    /// @param authorized The new authorization status.
    function updateXChainMessengerCallerAuthorization(
        address xChainMessenger,
        bool authorized
    ) external;

    /// @notice Used to stop all operations on a pool, in case of an emergency.
    /// @param pool The address of the HashflowPool.
    /// @param enabled Whether the pool is enabled.
    function killswitchPool(address pool, bool enabled) external;

    /// @notice Used to update the Limit Order Guardian.
    /// @param guardian The address of the new Guardian.
    function updateLimitOrderGuardian(address guardian) external;

    /// @notice Allows the owner to withdraw excess funds from the Router.
    /// @dev Under normal operations, the Router should not have excess funds.
    function withdrawFunds(address token) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

interface IUniswapV2Pair {
    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function sync() external;

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v1;

/**
 * @title LowLevelHelper
 * @notice Library for replacing uint256 by offset in calldata. Crucial for use cases like make a call with data from some previous call
 */
library LowLevelHelper {
    /// @notice offset should include 36 byte padding for selector and array length
    function patchUint(bytes calldata data, uint256 value, uint256 offset)
        internal
        pure
        returns (bytes memory result)
    {
        result = data;
        assembly {
            mstore(add(result, offset), value)
        }
    }

    /// @notice offsetN should include 36 byte padding for selector and array length
    function patchUint2(bytes calldata data, uint256 value1, uint256 offset1, uint256 value2, uint256 offset2)
        internal
        pure
        returns (bytes memory result)
    {
        result = data;
        assembly {
            mstore(add(result, offset1), value1)
            mstore(add(result, offset2), value2)
        }
    }

    /// @notice offset should include 36 byte padding for selector and array length
    function readUint(bytes calldata data, uint256 offset)
        internal
        pure
        returns (uint256 value)
    {
        assembly {
            value := calldataload(sub(add(data.offset, offset), 32))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./helpers/AerodromeBaseHelper.sol";
import "./helpers/AmbientHelper.sol";
import "./helpers/DodoV1Helper.sol";
import "./helpers/DssPsmHelper.sol";
import "./helpers/HashflowHelper.sol";
import "./helpers/UniswapV2Helper.sol";
import "./helpers/ValantisHelper.sol";
import "./helpers/UniswapV4Helper.sol";


/**
 * @title ProtocolHelper
 * @notice Aggregated helper that includes all other helpers for simplicity sake
 */
// solhint-disable-next-line no-empty-blocks
contract ProtocolHelper is
    AmbientHelper,
    AerodromeBaseHelper,
    DodoV1Helper,
    DssPsmHelper,
    HashflowHelper,
    UniswapV2Helper,
    ValantisHelper,
    UniswapV4Helper
{

}
