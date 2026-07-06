// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../utils/TwoStepOwnable.sol";
import {IERC20 as ERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {IVedaDepositor, IHourglassDepositor} from "@interfaces/IHourglassDepositor.sol";

/// @title VedaZapper
/// @notice Facilitates zapping into an instance of HourglassVedaLockDepositor
contract VedaZapper is TwoStepOwnable {
    using SafeERC20 for IERC20;
    using Address for address;

    /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The address of the deposit token for the depositor this contract supports zapping into
    address public immutable depositToken;
    /// @dev The list of tokens that can be used to zap into the depositor
    address[] private _startingTokens;
    /// @dev Boolean mapping of whether a token is a starting token
    mapping(address => bool) public isStartingToken;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(address _owner, address _depositToken, address[] memory initialStartingTokens) {
        _setInitialOwner(_owner);
        depositToken = _depositToken;
        for (uint256 i = 0; i < initialStartingTokens.length; i++) {
            _addStartingToken(initialStartingTokens[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function startingTokens() external view returns (address[] memory) {
        return _startingTokens;
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Zaps into an instance of HourglassVedaLockDepositor
    /// @param depositor The address of the depositor to zap into
    /// @param maturity The maturity timestamp of the depositor
    /// @param startingToken The address of the token to zap in with
    /// @param amount The amount of the starting token to zap in
    /// @param amountOutMinBps The amount required as output (in basis points) after slippage when zapping.
    ///     ex: amountOutMinBps = 9900 means up to 1% slippage is allowed.
    /// @param receiveSplit Whether to split the depositable token between the sender and the recipient
    /// @return sharesOut The amount of receipt tokens minted
    function zap(
        address depositor,
        uint256 maturity,
        address startingToken,
        uint256 amount,
        uint256 amountOutMinBps,
        bool receiveSplit
    ) external returns (uint256 sharesOut) {
        // Argument validation
        if (IHourglassDepositor(depositor).getUnderlying() != depositToken) revert InvalidDepositorDepositToken();
        if (IHourglassDepositor(depositor).maturity() != maturity) revert InvalidDepositorMaturity();
        if (amount == 0) revert InvalidAmount();
        if (!isStartingToken[startingToken]) revert InvalidInputToken();

        // Perform Zap
        // 1. enter the depositor, acquires re-entrancy lock
        IHourglassDepositor(depositor).enter(amount);
        // 2. push the starting token to the depositor
        IERC20(startingToken).safeTransferFrom(msg.sender, depositor, amount);
        // 3. mints the veda vault shares to the depositor (bypassing timelock as shares are already in depositor contract)
        sharesOut = IVedaDepositor(depositor).mintLockedUnderlying(startingToken, amountOutMinBps);
        // 4. finalize the deposit, mints the end user their receipt tokens
        IHourglassDepositor(depositor).depositTo(msg.sender, msg.sender, sharesOut, receiveSplit);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INTERNAL  NON-CONSTANT FUNCTIONS 
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new token to the list of starting tokens
     * @param token The address of the token to add
     */
    function _addStartingToken(address token) internal {
        if (isStartingToken[token]) revert TokenToAddExists();
        _startingTokens.push(token);
        isStartingToken[token] = true;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     ADMIN FUNCTIONS - OWNER ONLY
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new token to the list of starting tokens
     * @dev Only callable by the contract owner
     * @param token The address of the token to add
     */
    function addStartingToken(address token) external onlyOwner {
        _addStartingToken(token);
    }

    /**
     * @notice Removes a token from the list of starting tokens
     * @dev Only callable by the contract owner
     * @param token The address of the token to remove
     */
    function removeStartingToken(address token) external onlyOwner {
        for (uint256 i = 0; i < _startingTokens.length; i++) {
            if (_startingTokens[i] == token) {
                // Copy last element of starting tokens to the current position, which overwrites the token that is to be removed
                _startingTokens[i] = _startingTokens[_startingTokens.length - 1];
                _startingTokens.pop();
                isStartingToken[token] = false;
                return;
            }
        }
        revert TokenToRemoveNotFound();
    }

    /**
     * @notice Allows the owner of this contract to recover a stuck tokens.
     *          This contract should never custody assets.
     * @dev Only callable by the contract owner
     * @param token The address of the token to recover
     */
    function recoverTokens(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
        } else {
            IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
        }
    }

    error InvalidAmount();
    error InvalidInputToken();
    error InvalidDepositorMaturity();
    error InvalidDepositorDepositToken();
    error TokenToAddExists();
    error TokenToRemoveNotFound();
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./TwoStepOwnableInterface.sol";

/**
 * @title   TwoStepOwnable
 * @author  OpenSea Protocol Team
 * @notice  TwoStepOwnable provides access control for inheriting contracts,
 *          where the ownership of the contract can be exchanged via a two step
 *          process. A potential owner is set by the current owner by calling
 *          `transferOwnership`, then accepted by the new potential owner by
 *          calling `acceptOwnership`.
 */
abstract contract TwoStepOwnable is TwoStepOwnableInterface {
    // The address of the owner.
    address private _owner;

    // The address of the new potential owner.
    address private _potentialOwner;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        // Ensure that the caller is the owner.
        if (msg.sender != _owner) {
            revert CallerIsNotOwner();
        }

        // Continue with function execution.
        _;
    }

    /**
     * @notice Initiate ownership transfer by assigning a new potential owner
     *         to this contract. Once set, the new potential owner may call
     *         `acceptOwnership` to claim ownership. Only the owner may call
     *         this function.
     *
     * @param newPotentialOwner The address for which to initiate ownership
     *                          transfer to.
     */
    function transferOwnership(address newPotentialOwner) external override onlyOwner {
        // Ensure the new potential owner is not an invalid address.
        if (newPotentialOwner == address(0)) {
            revert NewPotentialOwnerIsNullAddress();
        }

        // Emit an event indicating that the potential owner has been updated.
        emit PotentialOwnerUpdated(newPotentialOwner);

        // Set the new potential owner as the potential owner.
        _potentialOwner = newPotentialOwner;
    }

    /**
     * @notice Clear the currently set potential owner, if any. Only the owner
     *         of this contract may call this function.
     */
    function cancelOwnershipTransfer() external override onlyOwner {
        // Emit an event indicating that the potential owner has been cleared.
        emit PotentialOwnerUpdated(address(0));

        // Clear the current new potential owner.
        delete _potentialOwner;
    }

    /**
     * @notice Accept ownership of this contract. Only the account that the
     *         current owner has set as the new potential owner may call this
     *         function.
     */
    function acceptOwnership() external override {
        // Ensure the caller is the potential owner.
        if (msg.sender != _potentialOwner) {
            // Revert, indicating that caller is not current potential owner.
            revert CallerIsNotNewPotentialOwner();
        }

        // Emit an event indicating that the potential owner has been cleared.
        emit PotentialOwnerUpdated(address(0));

        // Clear the current new potential owner.
        delete _potentialOwner;

        // Set the caller as the owner of this contract.
        _setOwner(msg.sender);
    }

    /**
     * @notice An external view function that returns the potential owner.
     *
     * @return The address of the potential owner.
     */
    function potentialOwner() external view override returns (address) {
        return _potentialOwner;
    }

    /**
     * @notice A public view function that returns the owner.
     *
     * @return The address of the owner.
     */
    function owner() public view override returns (address) {
        return _owner;
    }

    /**
     * @notice Internal function that sets the inital owner of the base
     *         contract. The initial owner must not already be set.
     *         To be called in the constructor or when initializing a proxy.
     *
     * @param initialOwner The address to set for initial ownership.
     */
    function _setInitialOwner(address initialOwner) internal {
        // Ensure that an initial owner has been supplied.
        if (initialOwner == address(0)) {
            revert InitialOwnerIsNullAddress();
        }

        // Ensure that the owner has not already been set.
        if (_owner != address(0)) {
            revert OwnerAlreadySet(_owner);
        }

        // Set the initial owner.
        _setOwner(initialOwner);
    }

    /**
     * @notice Private function that sets a new owner and emits a corresponding
     *         event.
     *
     * @param newOwner The address to assign as the new owner.
     */
    function _setOwner(address newOwner) private {
        // Emit an event indicating that the new owner has been set.
        emit OwnershipTransferred(_owner, newOwner);

        // Set the new owner.
        _owner = newOwner;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";

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
pragma solidity ^0.8.20;

interface IHourglassDepositor {
    function creationBlock() external view returns (uint256);
    function deposit(uint256 amount, bool receiveSplit) external;
    function depositFor(address user, uint256 amount, bool receiveSplit) external;
    function depositTo(address principalRecipient, address pointRecipient, uint256 amount, bool receiveSplit)
        external;
    function enter(uint256 amountToBeDeposited) external;
    function factory() external view returns (address);
    function getPointToken() external view returns (address);
    function getPrincipalToken() external view returns (address);
    function getTokens() external view returns (address[] memory);
    function getUnderlying() external view returns (address);
    function maturity() external view returns (uint256);
    function recombine(uint256 amount) external;
    function recoverToken(address token, address rewardsDistributor) external returns (uint256 amount);
    function redeem(uint256 amount) external;
    function redeemPrincipal(uint256 amount) external;
    function setMaxDeposits(uint256 _depositCap) external;
    function split(uint256 amount) external;

    event Deposit(address user, uint256 amount);
    event DepositedTo(address principalRecipient, address pointRecipient, uint256 amount);
    event Initialized(uint64 version);
    event NewMaturityCreated(address combined, address principal, address yield);
    event Recombine(address user, uint256 amount);
    event Redeem(address user, uint256 amount);
    event Split(address user, uint256 amount);

    error AddressEmptyCode(address target);
    error AddressInsufficientBalance(address account);
    error AlreadyEntered();
    error AmountMismatch();
    error CallerNotEntrant();
    error DepositCapExceeded();
    error FailedInnerCall();
    error InsufficientAssetSupplied();
    error InsufficientDeposit();
    error InsufficientFunds();
    error InvalidDecimals();
    error InvalidInitialization();
    error InvalidMaturity();
    error InvalidUnderlying();
    error Matured();
    error NoCode();
    error NotEntered();
    error NotInitializing();
    error PrematureRedeem();
    error RecipientMismatch();
    error SafeERC20FailedOperation(address token);
    error UnauthorizedCaller();
}

interface IVedaDepositor {
    function mintLockedUnderlying(address depositAsset, uint256 amountOutMinBps)
        external
        returns (uint256 amountOut);
}

interface IEthFiLUSDDepositor {
    function mintLockedUnderlying(uint256 minMintReceivedSlippageBps, address lusdDepositAsset, address sourceOfFunds)
        external
        returns (uint256 amountDepositAssetMinted);
}

interface IEthFiLiquidDepositor {
    function mintLockedUnderlying(uint256 minMintReceivedSlippageBps, address lusdDepositAsset, address sourceOfFunds)
        external
        returns (uint256 amountDepositAssetMinted);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title   TwoStepOwnableInterface
 * @author  OpenSea Protocol
 * @notice  TwoStepOwnableInterface contains all external function interfaces,
 *          events and errors for the TwoStepOwnable contract.
 */

interface TwoStepOwnableInterface {
    /**
     * @dev Emit an event whenever the contract owner registers a new potential
     *      owner.
     *
     * @param newPotentialOwner The new potential owner of the contract.
     */
    event PotentialOwnerUpdated(address newPotentialOwner);

    /**
     * @dev Emit an event whenever contract ownership is transferred.
     *
     * @param previousOwner The previous owner of the contract.
     * @param newOwner      The new owner of the contract.
     */
    event OwnershipTransferred(address previousOwner, address newOwner);

    /**
     * @dev Revert with an error when attempting to set an initial owner when
     *      one has already been set.
     */
    error OwnerAlreadySet(address currentOwner);

    /**
     * @dev Revert with an error when attempting to call a function with the
     *      onlyOwner modifier from an account other than that of the owner.
     */
    error CallerIsNotOwner();

    /**
     * @dev Revert with an error when attempting to register an initial owner
     *      and supplying the null address.
     */
    error InitialOwnerIsNullAddress();

    /**
     * @dev Revert with an error when attempting to register a new potential
     *      owner and supplying the null address.
     */
    error NewPotentialOwnerIsNullAddress();

    /**
     * @dev Revert with an error when attempting to claim ownership of the
     *      contract with a caller that is not the current potential owner.
     */
    error CallerIsNotNewPotentialOwner();

    /**
     * @notice Initiate ownership transfer by assigning a new potential owner
     *         to this contract. Once set, the new potential owner may call
     *         `acceptOwnership` to claim ownership. Only the owner may call
     *         this function.
     *
     * @param newPotentialOwner The address for which to initiate ownership
     *                          transfer to.
     */
    function transferOwnership(address newPotentialOwner) external;

    /**
     * @notice Clear the currently set potential owner, if any. Only the owner
     *         of this contract may call this function.
     */
    function cancelOwnershipTransfer() external;

    /**
     * @notice Accept ownership of this contract. Only the account that the
     *         current owner has set as the new potential owner may call this
     *         function.
     */
    function acceptOwnership() external;

    /**
     * @notice An external view function that returns the potential owner.
     *
     * @return The address of the potential owner.
     */
    function potentialOwner() external view returns (address);

    /**
     * @notice An external view function that returns the owner.
     *
     * @return The address of the owner.
     */
    function owner() external view returns (address);
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
