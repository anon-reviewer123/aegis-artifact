// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)

pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IERC165} from "./IERC165.sol";

/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";

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
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC1363} from "../../../interfaces/IERC1363.sol";
import {Address} from "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
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
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
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
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Address.sol)

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

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert Errors.FailedCall();
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
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAdminVault} from "../interfaces/IAdminVault.sol";
import {ILogger} from "../interfaces/ILogger.sol";
import {Errors} from "../Errors.sol";

/// @title ActionBase - Base contract for all actions in the protocol
/// @notice Implements common functionality and interfaces for all actions
/// @dev This contract should be inherited by all specific action contracts
/// @notice Found a vulnerability? Please contact security@bravalabs.xyz - we appreciate responsible disclosure and reward ethical hackers
abstract contract ActionBase {
    using SafeERC20 for IERC20;

    /// @notice Interface for the admin vault
    IAdminVault public immutable ADMIN_VAULT;

    /// @notice Interface for the logger
    ILogger public immutable LOGGER;

    /// @notice Basis points for fee calculations (100% = 10000)
    uint256 public constant FEE_BASIS_POINTS = 10000;

    /// @notice Duration of a fee period (1 year)
    uint256 public constant FEE_PERIOD = 365 days;

    /// @notice Enum representing different types of actions
    enum ActionType {
        DEPOSIT_ACTION,
        WITHDRAW_ACTION,
        SWAP_ACTION,
        COVER_ACTION,
        FEE_ACTION,
        TRANSFER_ACTION,
        CUSTOM_ACTION
    }

    /// @notice Enum representing different types of logs
    // List of log types, this list should be updated with each new log type added to the system.
    //   Existing values should not be changed/removed, as they may be already in use by a deployed action.
    //   UNUSED keeps the enum starting at index 1 for off-chain processing.
    enum LogType {
        UNUSED,
        BALANCE_UPDATE,
        BUY_COVER,
        CURVE_3POOL_SWAP,
        SEND_TOKEN,
        PULL_TOKEN,
        PARASWAP_SWAP,
        UPGRADE_ACTION,
        WITHDRAWAL_REQUEST,
        BUY_COVER_WITH_PREMIUM
    }

    /// @notice Initializes the ActionBase contract
    /// @param _adminVault Address of the admin vault
    /// @param _logger Address of the logger contract
    constructor(address _adminVault, address _logger) {
        ADMIN_VAULT = IAdminVault(_adminVault);
        LOGGER = ILogger(_logger);
    }

    /// @notice Executes the implemented action
    /// @dev This function should be overridden by inheriting contracts
    /// @param _callData Encoded input data for the action
    /// @param _strategyId The ID of the strategy executing this action (for logging use only)
    function executeAction(bytes memory _callData, uint16 _strategyId) public payable virtual;

    /// @notice Returns the type of action being implemented
    /// @return uint8 The action type as defined in the ActionType enum
    function actionType() public pure virtual returns (uint8);

    /// @notice Processes the fee taking, figures out if it's a supply and we need to initialize the fee timestamp
    /// @param _pool Address of the pool
    /// @param _feePercentage Fee percentage in basis points
    /// @param _feeToken Address of the fee token
    /// @return feeInTokens The amount of fee taken
    /// @dev it's rare but in some cases the _pool does differ from the _feeToken
    function _processFee(
        address _pool,
        uint256 _feePercentage,
        address _feeToken
    ) internal returns (uint256 feeInTokens) {
        uint256 lastFeeTimestamp = ADMIN_VAULT.getLastFeeTimestamp(_pool);

        // Initialize timestamp if not set, this will be the users first interaction with the pool
        if (lastFeeTimestamp == 0) {
            ADMIN_VAULT.setFeeTimestamp(_pool);
            return 0;
        }

        uint256 currentTimestamp = block.timestamp;
        if (lastFeeTimestamp == currentTimestamp) {
            return 0; // Don't take fees twice in the same block
        }

        IERC20 vault = IERC20(_feeToken);
        uint256 balance = vault.balanceOf(address(this));
        uint256 fee = _calculateFee(balance, _feePercentage, lastFeeTimestamp, currentTimestamp);
        if (fee > 0) {
            vault.safeTransfer(ADMIN_VAULT.feeConfig().recipient, fee);
        }
        ADMIN_VAULT.setFeeTimestamp(_pool);
        return fee;
    }

    /// @notice Calculates the fee due from the vault
    /// @param _totalDeposit Total amount deposited in the vault
    /// @param _feePercentage Fee percentage in basis points
    /// @param _lastFeeTimestamp Timestamp of the last fee collection
    /// @param _currentTimestamp Current timestamp
    /// @return uint256 The calculated fee amount
    function _calculateFee(
        uint256 _totalDeposit,
        uint256 _feePercentage,
        uint256 _lastFeeTimestamp,
        uint256 _currentTimestamp
    ) internal pure returns (uint256) {
        uint256 secondsPassed = _currentTimestamp - _lastFeeTimestamp;
        uint256 annualFee = (_totalDeposit * _feePercentage) / FEE_BASIS_POINTS;
        uint256 feeForPeriod = (annualFee * secondsPassed) / FEE_PERIOD;
        return feeForPeriod;
    }

    /// @notice Generates a pool ID from an address
    /// @param _addr Address to generate the pool ID from
    /// @return bytes4 The generated pool ID
    function _poolIdFromAddress(address _addr) internal pure returns (bytes4) {
        return bytes4(keccak256(abi.encodePacked(_addr)));
    }

    /// @notice Encodes balance update information
    /// @param _strategyId ID of the strategy
    /// @param _poolId ID of the pool
    /// @param _balanceBefore Balance before the action
    /// @param _balanceAfter Balance after the action
    /// @param _feeInTokens Amount of fee taken in tokens
    /// @return bytes Encoded balance update information
    function _encodeBalanceUpdate(
        uint16 _strategyId,
        bytes4 _poolId,
        uint256 _balanceBefore,
        uint256 _balanceAfter,
        uint256 _feeInTokens
    ) internal pure returns (bytes memory) {
        return abi.encode(_strategyId, _poolId, _balanceBefore, _balanceAfter, _feeInTokens);
    }

    function _checkFeesTaken(address _token) internal view {
        uint256 feeTimestamp = ADMIN_VAULT.getLastFeeTimestamp(_token);
        require(feeTimestamp == 0 || feeTimestamp >= block.timestamp, Errors.Action_FeesNotPaid(protocolName(), actionType(), _token));
    }

    /// @notice Returns the name of the protocol
    /// @return string The name of the protocol
    function protocolName() public pure virtual returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {Errors} from "../../Errors.sol";
import {IERC4626} from "../../interfaces/common/IERC4626.sol";
import {ActionBase} from "../ActionBase.sol";

/// @title ERC4626Withdraw - Burns vault shares and receives underlying tokens in return
/// @notice This contract allows users to withdraw tokens from any ERC4626 vault
/// @dev Inherits from ActionBase and implements generic withdraw functionality
/// @notice Found a vulnerability? Please contact security@bravalabs.xyz - we appreciate responsible disclosure and reward ethical hackers
abstract contract ERC4626Withdraw is ActionBase {
    /// @notice Parameters for the withdraw action
    /// @param poolId ID of vault contract
    /// @param feeBasis Fee percentage to apply (in basis points, e.g., 100 = 1%)
    /// @param withdrawRequest Amount of underlying token to withdraw
    /// @param maxSharesBurned Maximum amount of shares to burn
    struct Params {
        bytes4 poolId;
        uint16 feeBasis;
        uint256 withdrawRequest;
        uint256 maxSharesBurned;
    }

    constructor(address _adminVault, address _logger) ActionBase(_adminVault, _logger) {}

    ///  -----   Core logic -----  ///

    /// @inheritdoc ActionBase
    function executeAction(bytes memory _callData, uint16 _strategyId) public payable override {
        // Parse inputs
        Params memory inputData = _parseInputs(_callData);

        // Check inputs
        ADMIN_VAULT.checkFeeBasis(inputData.feeBasis);
        address vault = ADMIN_VAULT.getPoolAddress(protocolName(), inputData.poolId);

        // Execute action
        (uint256 sharesBefore, uint256 sharesAfter, uint256 feeInTokens) = _withdrawFromVault(inputData, vault);

        // Log event
        LOGGER.logActionEvent(
            LogType.BALANCE_UPDATE,
            _encodeBalanceUpdate(_strategyId, inputData.poolId, sharesBefore, sharesAfter, feeInTokens)
        );
    }

    /// @dev Withdraw logic, external calls are separated out to allow for overrides
    function _withdrawFromVault(
        Params memory _inputData,
        address _vaultAddress
    ) private returns (uint256 sharesBefore, uint256 sharesAfter, uint256 feeInTokens) {
        // for logging, get the balance before
        sharesBefore = _getBalance(_vaultAddress);

        feeInTokens = _processFee(_vaultAddress, _inputData.feeBasis, _vaultAddress);

        uint256 maxWithdrawAmount = _getMaxWithdraw(_vaultAddress);
        uint256 amountToWithdraw = _inputData.withdrawRequest > maxWithdrawAmount
            ? maxWithdrawAmount
            : _inputData.withdrawRequest;

        require(amountToWithdraw != 0, Errors.Action_ZeroAmount(protocolName(), uint8(actionType())));

        // Perform the withdraw
        uint256 sharesBurned = _executeWithdraw(_vaultAddress, amountToWithdraw);

        // check we didn't burn more shares than we were allowed to
        require(
            sharesBurned <= _inputData.maxSharesBurned,
            Errors.Action_MaxSharesBurnedExceeded(
                protocolName(),
                uint8(actionType()),
                sharesBurned,
                _inputData.maxSharesBurned
            )
        );

        // for logging, get the balance after
        sharesAfter = _getBalance(_vaultAddress);
    }

    /// @notice Parses the input data from bytes to Params struct
    /// @param _callData Encoded call data
    /// @return inputData Decoded Params struct
    function _parseInputs(bytes memory _callData) private pure returns (Params memory inputData) {
        inputData = abi.decode(_callData, (Params));
    }

    /// @inheritdoc ActionBase
    function actionType() public pure override returns (uint8) {
        return uint8(ActionType.WITHDRAW_ACTION);
    }

    /// -----  Protocol specific overrides ----- ///

    /// @notice Executes the withdraw from the vault
    /// @dev Override for non-standard withdraw implementations
    /// @param _vaultAddress The vault address
    /// @param amount The amount of underlying token to withdraw
    /// @return _sharesBurned The amount of shares burned
    function _executeWithdraw(address _vaultAddress, uint256 amount) internal virtual returns (uint256 _sharesBurned) {
        _sharesBurned = IERC4626(_vaultAddress).withdraw(amount, address(this), address(this));
    }

    /// @dev Override for non-standard balance calculations
    function _getBalance(address _vaultAddress) internal view virtual returns (uint256) {
        return IERC4626(_vaultAddress).balanceOf(address(this));
    }

    /// @dev Override for non-standard max withdraw calculations
    function _getMaxWithdraw(address _vaultAddress) internal view virtual returns (uint256) {
        return IERC4626(_vaultAddress).maxWithdraw(address(this));
    }

    /// @inheritdoc ActionBase
    function protocolName() public pure virtual override returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {ERC4626Withdraw} from "../common/ERC4626Withdraw.sol";

/// @title MorphoV1Withdraw - Withdraws tokens from Morpho V1 vault
/// @notice This contract allows users to withdraw tokens from a Morpho V1 vault
/// @notice Found a vulnerability? Please contact security@bravalabs.xyz - we appreciate responsible disclosure and reward ethical hackers
contract MorphoV1Withdraw is ERC4626Withdraw {
    /// @notice Initializes the MorphoV1Withdraw contract
    /// @param _adminVault Address of the admin vault
    /// @param _logger Address of the logger contract
    constructor(address _adminVault, address _logger) ERC4626Withdraw(_adminVault, _logger) {}

    /// @inheritdoc ERC4626Withdraw
    /// @notice Returns the protocol name
    /// @return string "MorphoV1"
    function protocolName() public pure override returns (string memory) {
        return "MorphoV1";
    }
}

// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

/// @title Errors
/// @notice This contract contains all custom errors used across the protocol
/// @notice Found a vulnerability? Please contact security@bravalabs.xyz - we appreciate responsible disclosure and reward ethical hackers
contract Errors {
    // Generic errors
    error InvalidInput(string _contract, string _function);

    // AccessControlDelayed errors
    error AccessControlDelayed_InvalidDelay();
    error AccessControlDelayed_MustHaveAdminRole(address account, bytes32 role);
    error AccessControlDelayed_CannotGrantOwnerRole();
    error AccessControlDelayed_MustHaveRoleManagerOrOwner(address account);

    // AdminVault errors
    error AdminVault_FeePercentageOutOfRange(uint256 _providedPercentage, uint256 _minAllowed, uint256 _maxAllowed);
    error AdminVault_InvalidFeeRange(uint256 _minFee, uint256 _maxFee);
    error AdminVault_NotInitialized();
    error AdminVault_DelayNotPassed(uint256 _currentTime, uint256 _requiredTime);
    error AdminVault_NotFound(string _entityType, bytes4 _entityId);
    error AdminVault_NotProposed();
    error AdminVault_AlreadyProposed();
    error AdminVault_NotAdded();
    error AdminVault_AlreadyAdded();
    error AdminVault_NotPool(address _pool);
    error AdminVault_AlreadyGranted();
    error AdminVault_NotGranted();
    error AdminVault_TransactionNotProposed();
    error AdminVault_TransactionAlreadyApproved();
    error AdminVault_TransactionNotApproved(bytes32 txHash);
    error AdminVault_MissingRole(bytes32 role, address account);

    // FeeTakeSafeModule errors
    error FeeTakeSafeModule_SenderNotFeeTaker(address _sender);
    error FeeTakeSafeModule_InvalidActionType(bytes4 _actionId);
    error FeeTakeSafeModule_ExecutionFailed();

    // Generic Action errors
    error Action_ZeroAmount(string _protocolName, uint8 _actionType);
    error Action_InsufficientSharesReceived(
        string _protocolName,
        uint8 _actionType,
        uint256 _sharesReceived,
        uint256 _minSharesReceived
    );
    error Action_MaxSharesBurnedExceeded(
        string _protocolName,
        uint8 _actionType,
        uint256 _sharesBurned,
        uint256 _maxAllowed
    );
    error Action_InvalidPool(string _protocolName, uint8 _actionType);
    error Action_UnderlyingReceivedLessThanExpected(uint256 _underlyingReceived, uint256 _expected);
    error Action_FeesNotPaid(string _protocolName, uint8 _actionType, address _token);

    // CompoundV2Supply errors
    error Action_CompoundError(string _protocolName, uint8 _actionType, uint256 _errorCode);

    // Curve3PoolSwap errors
    error Curve3Pool__InvalidTokenIndices(int128 _fromToken, int128 _toToken);

    // ParaswapSwap errors
    error Paraswap__SwapFailed();
    error Paraswap__InsufficientOutput(uint256 _amountReceived, uint256 _minToAmount);
    error Paraswap__TokenNotApproved(address token);
    error Paraswap__TokenMismatch(address expected, address actual);
    error Paraswap__InvalidCalldata();
    error Paraswap__UnsupportedSelector(bytes4 selector);

    // SendToken errors
    error Action_InvalidRecipient(string _protocolName, uint8 _actionType);

    // UpgradeAction errors
    error UpgradeAction_TransactionNotApproved(bytes32 txHash);
    error UpgradeAction_ExecutionFailed();
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC4626
 * @dev Interface for the ERC4626 Tokenized Vault Standard
 * https://eips.ethereum.org/EIPS/eip-4626
 */
interface IERC4626 is IERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the underlying token used for the Vault
    function asset() external view returns (address assetTokenAddress);

    /// @notice Total amount of the underlying asset managed by vault
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT/WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit assets and receive shares
     * @param assets Amount of assets to deposit
     * @param receiver Address to receive the shares
     * @return shares Amount of shares minted
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @notice Mint exact shares by depositing assets
     * @param shares Amount of shares to mint
     * @param receiver Address to receive the shares
     * @return assets Amount of assets deposited
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @notice Withdraw assets by burning shares
     * @param assets Amount of assets to withdraw
     * @param receiver Address to receive assets
     * @param owner Owner of the shares
     * @return shares Amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @notice Redeem shares for assets
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive assets
     * @param owner Owner of the shares
     * @return assets Amount of assets withdrawn
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Preview deposit
     * @param assets Amount of assets to deposit
     * @return shares Expected amount of shares to mint
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Preview mint
     * @param shares Amount of shares to mint
     * @return assets Expected amount of assets needed
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @notice Preview withdraw
     * @param assets Amount of assets to withdraw
     * @return shares Expected amount of shares needed
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Preview redeem
     * @param shares Amount of shares to redeem
     * @return assets Expected amount of assets to receive
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /*//////////////////////////////////////////////////////////////
                            CONVERSION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Convert assets to shares
     * @param assets Amount of assets to convert
     * @return shares Equivalent amount of shares
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Convert shares to assets
     * @param shares Amount of shares to convert
     * @return assets Equivalent amount of assets
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /*//////////////////////////////////////////////////////////////
                            LIMITS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Maximum deposit possible
     * @param receiver Address that would receive shares
     * @return maxAssets Maximum amount of assets that can be deposited
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @notice Maximum mint possible
     * @param receiver Address that would receive shares
     * @return maxShares Maximum amount of shares that can be minted
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @notice Maximum withdrawal possible
     * @param owner Address that owns the shares
     * @return maxAssets Maximum amount of assets that can be withdrawn
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @notice Maximum redemption possible
     * @param owner Address that owns the shares
     * @return maxShares Maximum amount of shares that can be redeemed
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);
}

// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

interface IAdminVault {
    // Errors
    error SenderNotAdmin();
    error SenderNotOwner();
    error FeeTimestampNotInitialized();
    error FeeTimestampAlreadyInitialized();
    error FeePercentageOutOfRange();
    error InvalidRange();
    error InvalidRecipient();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error AccessControlBadConfirmation();

    // Structs
    struct FeeConfig {
        address recipient;
        uint256 minBasis;
        uint256 maxBasis;
        uint256 proposalTime;
    }

    // View Functions
    // solhint-disable-next-line func-name-mixedcase
    function LOGGER() external view returns (address);
    // solhint-disable-next-line func-name-mixedcase
    function OWNER_ROLE() external view returns (bytes32);
    // solhint-disable-next-line func-name-mixedcase
    function ADMIN_ROLE() external view returns (bytes32);
    function feeConfig() external view returns (FeeConfig memory);
    function pendingFeeConfig() external view returns (FeeConfig memory);
    function lastFeeTimestamp(address, address) external view returns (uint256);
    function protocolPools(uint256 protocolId, bytes4 poolId) external view returns (address);
    function actionAddresses(bytes4 actionId) external view returns (address);
    function getPoolAddress(string calldata _protocolName, bytes4 _poolId) external view returns (address);
    function getActionAddress(bytes4 _actionId) external view returns (address);
    function getLastFeeTimestamp(address _vault) external view returns (uint256);
    function checkFeeBasis(uint256 _feeBasis) external view;
    function getPoolProposalTime(string calldata protocolName, address poolAddress) external view returns (uint256);
    function getActionProposalTime(bytes4 actionId, address actionAddress) external view returns (uint256);

    // Role Management Functions
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;

    // Fee Management Functions
    function proposeFeeConfig(address recipient, uint256 min, uint256 max) external;
    function cancelFeeConfigProposal() external;
    function setFeeConfig() external;
    function setFeeTimestamp(address _vault) external;

    // Pool Management Functions
    function proposePool(string calldata protocolName, address poolAddress) external;
    function cancelPoolProposal(string calldata protocolName, address poolAddress) external;
    function addPool(string calldata protocolName, address poolAddress) external;
    function removePool(string calldata protocolName, address poolAddress) external;

    // Action Management Functions
    function proposeAction(bytes4 actionId, address actionAddress) external;
    function cancelActionProposal(bytes4 actionId, address actionAddress) external;
    function addAction(bytes4 actionId, address actionAddress) external;
    function removeAction(bytes4 actionId) external;

    // Transaction Management Functions
    function proposeTransaction(bytes32 txHash) external;
    function cancelTransactionProposal(bytes32 txHash) external;
    function approveTransaction(bytes32 txHash) external;
    function revokeTransaction(bytes32 txHash) external;
    function isApprovedTransaction(bytes32 txHash) external view returns (bool);

    // Delay Management Functions
    function getDelayTimestamp() external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {ActionBase} from "../actions/ActionBase.sol";

interface ILogger {
    event ActionEvent(address caller, ActionBase.LogType logId, bytes data);
    event AdminVaultEvent(uint256 logId, bytes data);

    function logActionEvent(ActionBase.LogType _logType, bytes memory _data) external;
    function logAdminVaultEvent(uint256 _logId, bytes memory _data) external;
}
