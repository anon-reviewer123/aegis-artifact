// SPDX-License-Identifier: AGPL-v3.0
pragma solidity ^0.8.21;


// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)
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

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)
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

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)
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

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)
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

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IEmissionSchedule {
    event LockParametersSet(uint256 lockWeeks, uint256 lockDecayWeeks);
    event WeeklyPctScheduleSet(uint64[2][] schedule);

    function getReceiverWeeklyEmissions(
        uint256 id,
        uint256 week,
        uint256 totalWeeklyEmissions
    ) external returns (uint256);

    function getTotalWeeklyEmissions(
        uint256 week,
        uint256 unallocatedTotal
    ) external returns (uint256 amount, uint256 lock);

    function setLockParameters(uint64 _lockWeeks, uint64 _lockDecayWeeks) external returns (bool);

    function setWeeklyPctSchedule(uint64[2][] calldata _schedule) external returns (bool);

    function MAX_LOCK_WEEKS() external view returns (uint256);

    function getWeek() external view returns (uint256 week);

    function getWeeklyPctSchedule() external view returns (uint64[2][] memory);

    function guardian() external view returns (address);

    function lockDecayWeeks() external view returns (uint64);

    function lockWeeks() external view returns (uint64);

    function owner() external view returns (address);

    function vault() external view returns (address);

    function voter() external view returns (address);

    function weeklyPct() external view returns (uint64);
}

interface IIncentiveVoting {
    struct Vote {
        uint256 id;
        uint256 points;
    }

    struct LockData {
        uint256 amount;
        uint256 weeksToUnlock;
    }

    event AccountWeightRegistered(
        address indexed account,
        uint256 indexed week,
        uint256 frozenBalance,
        LockData[] registeredLockData
    );
    event ClearedVotes(address indexed account, uint256 indexed week);
    event NewVotes(address indexed account, uint256 indexed week, Vote[] newVotes, uint256 totalPointsUsed);

    function clearRegisteredWeight(address account) external returns (bool);

    function clearVote(address account) external;

    function getReceiverVotePct(uint256 id, uint256 week) external returns (uint256);

    function getReceiverWeightWrite(uint256 idx) external returns (uint256);

    function getTotalWeightWrite() external returns (uint256);

    function registerAccountWeight(address account, uint256 minWeeks) external;

    function registerAccountWeightAndVote(address account, uint256 minWeeks, Vote[] calldata votes) external;

    function registerNewReceiver() external returns (uint256);

    function setDelegateApproval(address _delegate, bool _isApproved) external;

    function unfreeze(address account, bool keepVote) external returns (bool);

    function vote(address account, Vote[] calldata votes, bool clearPrevious) external;

    function MAX_LOCK_WEEKS() external view returns (uint256);

    function MAX_POINTS() external view returns (uint256);

    function getAccountCurrentVotes(address account) external view returns (Vote[] memory votes);

    function getAccountRegisteredLocks(
        address account
    ) external view returns (uint256 frozenWeight, LockData[] memory lockData);

    function getReceiverWeight(uint256 idx) external view returns (uint256);

    function getReceiverWeightAt(uint256 idx, uint256 week) external view returns (uint256);

    function getTotalWeight() external view returns (uint256);

    function getTotalWeightAt(uint256 week) external view returns (uint256);

    function getWeek() external view returns (uint256 week);

    function isApprovedDelegate(address owner, address caller) external view returns (bool isApproved);

    function receiverCount() external view returns (uint256);

    function receiverDecayRate(uint256) external view returns (uint32);

    function receiverUpdatedWeek(uint256) external view returns (uint16);

    function receiverWeeklyUnlocks(uint256, uint256) external view returns (uint32);

    function tokenLocker() external view returns (address);

    function totalDecayRate() external view returns (uint32);

    function totalUpdatedWeek() external view returns (uint16);

    function totalWeeklyUnlocks(uint256) external view returns (uint32);

    function vault() external view returns (address);
}

interface ISTRDYLocker {
    struct LockData {
        uint256 amount;
        uint256 weeksToUnlock;
    }
    struct ExtendLockData {
        uint256 amount;
        uint256 currentWeeks;
        uint256 newWeeks;
    }

    event LockCreated(address indexed account, uint256 amount, uint256 _weeks);
    event LockExtended(address indexed account, uint256 amount, uint256 _weeks, uint256 newWeeks);
    event LocksCreated(address indexed account, LockData[] newLocks);
    event LocksExtended(address indexed account, ExtendLockData[] locks);
    event LocksFrozen(address indexed account, uint256 amount);
    event LocksUnfrozen(address indexed account, uint256 amount);
    event LocksWithdrawn(address indexed account, uint256 withdrawn, uint256 penalty);

    function extendLock(uint256 _amount, uint256 _weeks, uint256 _newWeeks) external returns (bool);

    function extendMany(ExtendLockData[] calldata newExtendLocks) external returns (bool);

    function freeze() external;

    function getAccountWeightWrite(address account) external returns (uint256);

    function getTotalWeightWrite() external returns (uint256);

    function lock(address _account, uint256 _amount, uint256 _weeks) external returns (bool);

    function lockMany(address _account, LockData[] calldata newLocks) external returns (bool);

    function setPenaltyWithdrawalsEnabled(bool _enabled) external returns (bool);

    function unfreeze(bool keepIncentivesVote) external;

    function withdrawExpiredLocks(uint256 _weeks) external returns (bool);

    function withdrawWithPenalty(uint256 amountToWithdraw) external returns (uint256);

    function MAX_LOCK_WEEKS() external view returns (uint256);

    function getAccountActiveLocks(
        address account,
        uint256 minWeeks
    ) external view returns (LockData[] memory lockData, uint256 frozenAmount);

    function getAccountBalances(address account) external view returns (uint256 locked, uint256 unlocked);

    function getAccountWeight(address account) external view returns (uint256);

    function getAccountWeightAt(address account, uint256 week) external view returns (uint256);

    function getTotalWeight() external view returns (uint256);

    function getTotalWeightAt(uint256 week) external view returns (uint256);

    function getWeek() external view returns (uint256 week);

    function getWithdrawWithPenaltyAmounts(
        address account,
        uint256 amountToWithdraw
    ) external view returns (uint256 amountWithdrawn, uint256 penaltyAmountPaid);

    function guardian() external view returns (address);

    function incentiveVoter() external view returns (address);

    function lockToTokenRatio() external view returns (uint256);

    function lockToken() external view returns (address);

    function owner() external view returns (address);

    function penaltyWithdrawalsEnabled() external view returns (bool);

    function totalDecayRate() external view returns (uint32);

    function totalUpdatedWeek() external view returns (uint16);
}

interface IBoostDelegate {
    /**
        @notice Get the current fee percent charged to use this boost delegate
        @dev Optional. Only called if the feePct is set to `type(uint16).max` when
             enabling delegation.
        @param claimant Address that will perform the claim
        @param amount Amount to be claimed (before applying boost or fee)
        @param previousAmount Previous amount claimed this week by this contract
        @param totalWeeklyEmissions Total weekly emissions released this week
        @return feePct Fee % charged for claims that use this contracts' delegated boost.
                      Given as a whole number out of 10000. If a claim would be rejected,
                      the preferred return value is `type(uint256).max`.
     */
    function getFeePct(
        address claimant,
        address receiver,
        uint amount,
        uint previousAmount,
        uint totalWeeklyEmissions
    ) external view returns (uint256 feePct);

    /**
        @notice Callback function for boost delegators
        @dev MUST BE INCLUDED. Called after each successful claim which used
             this contract's delegated boost.
        @param claimant Address that performed the claim
        @param amount Amount that claimed (before applying boost or fee)
        @param adjustedAmount Actual amount received by `claimant`
        @param fee Fee amount paid by `claimant`
        @param previousAmount Previous amount claimed this week by this contract
        @param totalWeeklyEmissions Total weekly emissions released this week
     */
    function delegatedBoostCallback(
        address claimant,
        address receiver,
        uint amount,
        uint adjustedAmount,
        uint fee,
        uint previousAmount,
        uint totalWeeklyEmissions
    ) external returns (bool success);
}

interface IBoostCalculator {
    function getBoostedAmount(
        address rewardContract,
        address account,
        uint256 amount
    ) external view returns (uint256 adjustedAmount);
}

contract SystemStart {
    uint256 immutable startTime;

    constructor(uint256 _startTime) {
        startTime = _startTime;
    }

    function getWeek() public view returns (uint256 week) {
        return (block.timestamp - startTime) / 1 weeks;
    }
}

interface IEmissionReceiver {
    function notifyRegisteredId(uint256[] memory assignedIds) external returns (bool);
}

interface IRewards {
    function vaultClaimReward(address claimant, address receiver) external returns (uint256);

    function claimableReward(address account, uint256) external view returns (uint256);
}

/**
    @title STRDY Vault
    @notice The total supply of STRDY is initially minted to this contract.
            The token balance held here can be considered "uncirculating". The
            vault gradually releases tokens to registered emissions receivers
            as determined by `EmissionSchedule` and `BoostCalculator`.
 */
contract STRDYVault is Ownable, SystemStart {
    using SafeERC20 for IERC20;

    IERC20 public immutable strdyToken;
    ISTRDYLocker public immutable locker;
    IIncentiveVoting public immutable voter;
    address public immutable deploymentManager;
    uint256 immutable lockToTokenRatio;

    IEmissionSchedule public emissionSchedule;
    IBoostCalculator public boostCalculator;

    // `strdyToken` balance within the treasury that is not yet allocated.
    // Starts as `strdyToken.totalSupply()` and decreases over time.
    uint128 public unallocatedTotal;
    // most recent week that `unallocatedTotal` was reduced by a call to
    // `emissionSchedule.getTotalWeeklyEmissions`
    uint64 public totalUpdateWeek;
    // number of weeks that STRDY is locked for when transferred using
    // `transferAllocatedTokens`. updated weekly by the emission schedule.
    uint64 public lockWeeks;

    // id -> receiver data
    uint16[65535] public receiverUpdatedWeek;
    // id -> address of receiver
    // not bi-directional, one receiver can have multiple ids
    mapping(uint256 => Receiver) public idToReceiver;

    // week -> total amount of tokens to be released in that week
    uint128[65535] public weeklyEmissions;

    // receiver -> remaining tokens which have been allocated but not yet distributed
    mapping(address => uint256) public allocated;

    // pending rewards for an address (dust after locking)
    mapping(address => uint256) private storedPendingReward;

    struct Receiver {
        address account;
        bool isActive;
    }

    struct InitialAllowance {
        address receiver;
        uint256 amount;
    }

    event NewReceiverRegistered(address receiver, uint256 id);
    event ReceiverIsActiveStatusModified(uint256 indexed id, bool isActive);
    event UnallocatedSupplyReduced(uint256 reducedAmount, uint256 unallocatedTotal);
    event UnallocatedSupplyIncreased(uint256 increasedAmount, uint256 unallocatedTotal);
    event IncreasedAllocation(address indexed receiver, uint256 increasedAmount);
    event EmissionScheduleSet(address emissionScheduler);
    event BoostCalculatorSet(address boostCalculator);

    constructor(
        uint256 _startTime,
        IERC20 _token,
        ISTRDYLocker _locker,
        IIncentiveVoting _voter,
        address _manager
    ) Ownable() SystemStart(_startTime) {
        strdyToken = _token;
        locker = _locker;
        voter = _voter;
        lockToTokenRatio = _locker.lockToTokenRatio();
        deploymentManager = _manager;
    }

    function setInitialParameters(
        IEmissionSchedule _emissionSchedule,
        IBoostCalculator _boostCalculator,
        uint256 totalSupply,
        uint64 initialLockWeeks,
        uint128[] memory _fixedInitialAmounts,
        InitialAllowance[] memory initialAllowances
    ) external {
        require(msg.sender == deploymentManager, "!deploymentManager");
        emissionSchedule = _emissionSchedule;
        boostCalculator = _boostCalculator;

        // set initial fixed weekly emissions
        uint256 totalAllocated;
        uint256 length = _fixedInitialAmounts.length;
        uint256 offset = getWeek() + 1;
        for (uint256 i = 0; i < length; i++) {
            uint128 amount = _fixedInitialAmounts[i];
            weeklyEmissions[i + offset] = amount;
            totalAllocated += amount;
        }

        // set initial transfer allowances for airdrops, vests, bribes
        length = initialAllowances.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 amount = initialAllowances[i].amount;
            address receiver = initialAllowances[i].receiver;
            totalAllocated += amount;
            // initial allocations are given as approvals
            strdyToken.safeApprove(receiver, amount);
        }

        unallocatedTotal = uint128(totalSupply - totalAllocated);
        totalUpdateWeek = uint64(_fixedInitialAmounts.length + offset - 1);
        lockWeeks = initialLockWeeks;

        emit EmissionScheduleSet(address(_emissionSchedule));
        emit BoostCalculatorSet(address(_boostCalculator));
        emit UnallocatedSupplyReduced(totalAllocated, unallocatedTotal);
    }

    /**
        @notice Register a new emission receiver
        @dev Once this function is called, the receiver ID is immediately
             eligible for votes within `IncentiveVoting`
        @param receiver Address of the receiver
        @param count Number of IDs to assign to the receiver
     */
    function registerReceiver(address receiver, uint256 count) external onlyOwner returns (bool) {
        uint256[] memory assignedIds = new uint256[](count);
        uint16 week = uint16(getWeek());
        for (uint256 i = 0; i < count; i++) {
            uint256 id = voter.registerNewReceiver();
            assignedIds[i] = id;
            receiverUpdatedWeek[id] = week;
            idToReceiver[id] = Receiver({ account: receiver, isActive: true });
            emit NewReceiverRegistered(receiver, id);
        }
        // notify the receiver contract of the newly registered ID
        // also serves as a sanity check to ensure the contract is capable of receiving emissions
        IEmissionReceiver(receiver).notifyRegisteredId(assignedIds);

        return true;
    }

    /**
        @notice Modify the active status of an existing receiver
        @dev Emissions directed to an inactive receiver are instead returned to
             the unallocated supply. This way potential emissions are not lost
             due to old emissions votes pointing at a receiver that was phased out.
        @param id ID of the receiver to modify the isActive status for
        @param isActive is this receiver eligible to receive emissions?
     */
    function setReceiverIsActive(uint256 id, bool isActive) external onlyOwner returns (bool) {
        Receiver memory receiver = idToReceiver[id];
        require(receiver.account != address(0), "ID not set");
        receiver.isActive = isActive;
        idToReceiver[id] = receiver;
        emit ReceiverIsActiveStatusModified(id, isActive);

        return true;
    }

    /**
        @notice Set the `emissionSchedule` contract
        @dev Callable only by the owner (the DAO admin voter, to change the emission schedule).
             The new schedule is applied from the start of the next epoch.
     */
    function setEmissionSchedule(IEmissionSchedule _emissionSchedule) external onlyOwner returns (bool) {
        _allocateTotalWeekly(emissionSchedule, getWeek());
        emissionSchedule = _emissionSchedule;
        emit EmissionScheduleSet(address(_emissionSchedule));

        return true;
    }

    function setBoostCalculator(IBoostCalculator _boostCalculator) external onlyOwner returns (bool) {
        boostCalculator = _boostCalculator;
        emit BoostCalculatorSet(address(_boostCalculator));

        return true;
    }

    /**
        @notice Transfer tokens out of the vault
     */
    function transferTokens(IERC20 token, address receiver, uint256 amount) external onlyOwner returns (bool) {
        if (address(token) == address(strdyToken)) {
            require(receiver != address(this), "Self transfer denied");
            uint256 unallocated = unallocatedTotal - amount;
            unallocatedTotal = uint128(unallocated);
            emit UnallocatedSupplyReduced(amount, unallocated);
        }
        token.safeTransfer(receiver, amount);

        return true;
    }

    /**
        @notice Receive STRDY tokens and add them to the unallocated supply
     */
    function increaseUnallocatedSupply(uint256 amount) external returns (bool) {
        strdyToken.transferFrom(msg.sender, address(this), amount);
        uint256 unallocated = unallocatedTotal + amount;
        unallocatedTotal = uint128(unallocated);
        emit UnallocatedSupplyIncreased(amount, unallocated);

        return true;
    }

    function _allocateTotalWeekly(IEmissionSchedule _emissionSchedule, uint256 currentWeek) internal {
        uint256 week = totalUpdateWeek;
        if (week >= currentWeek) return;

        if (address(_emissionSchedule) == address(0)) {
            totalUpdateWeek = uint64(currentWeek);
            return;
        }

        uint256 lock;
        uint256 weeklyAmount;
        uint256 unallocated = unallocatedTotal;
        while (week < currentWeek) {
            ++week;
            (weeklyAmount, lock) = _emissionSchedule.getTotalWeeklyEmissions(week, unallocated);
            weeklyEmissions[week] = uint128(weeklyAmount);

            unallocated = unallocated - weeklyAmount;
            emit UnallocatedSupplyReduced(weeklyAmount, unallocated);
        }

        unallocatedTotal = uint128(unallocated);
        totalUpdateWeek = uint64(currentWeek);
        lockWeeks = uint64(lock);
    }

    /**
        @notice Allocate additional `strdyToken` allowance to an emission reciever
                based on the emission schedule
        @param id Receiver ID. The caller must be the receiver mapped to this ID.
        @return uint256 Additional `strdyToken` allowance for the receiver. The receiver
                        accesses the tokens using `Vault.transferAllocatedTokens`
     */
    function allocateNewEmissions(uint256 id) external returns (uint256, uint256[] memory) {
        Receiver memory receiver = idToReceiver[id];
        require(receiver.account == msg.sender, "Receiver not registered");
        uint256 week = receiverUpdatedWeek[id];
        uint256 currentWeek = getWeek();
        uint256[] memory emissions;
        if (week == currentWeek) return (0, emissions);

        IEmissionSchedule _emissionSchedule = emissionSchedule;
        _allocateTotalWeekly(_emissionSchedule, currentWeek);

        if (address(_emissionSchedule) == address(0)) {
            receiverUpdatedWeek[id] = uint16(currentWeek);
            return (0, emissions);
        }

        uint256 amount;
        uint256 startWeek = week;
        emissions = new uint256[](currentWeek - week);
        while (week < currentWeek) {
            ++week;
            
            uint256 receiverEmission = _emissionSchedule.getReceiverWeeklyEmissions(id, week, weeklyEmissions[week]);
            amount += receiverEmission;

            emissions[week - startWeek - 1] = receiverEmission;
        }

        receiverUpdatedWeek[id] = uint16(currentWeek);
        if (receiver.isActive) {
            allocated[msg.sender] = allocated[msg.sender] + amount;
            emit IncreasedAllocation(msg.sender, amount);
            return (amount, emissions);
        } else {
            // if receiver is not active, return allocation to the unallocated supply
            uint256 unallocated = unallocatedTotal + amount;
            unallocatedTotal = uint128(unallocated);
            emit UnallocatedSupplyIncreased(amount, unallocated);
            return (0, emissions);
        }
    }

    /**
        @notice Transfer `strdyToken` tokens previously allocated to the caller
        @dev Callable only by registered receiver contracts which were previously
             allocated tokens using `allocateNewEmissions`.
        @param claimant Address that is claiming the tokens
        @param receiver Address to transfer tokens to
        @param amount Desired amount of tokens to transfer. This value always assumes max boost.
        @return bool success
     */
    function transferAllocatedTokens(address claimant, address receiver, uint256 amount) external returns (bool) {
        if (amount > 0) {
            allocated[msg.sender] -= amount;
            _transferAllocated(msg.sender, claimant, receiver, amount);
        }
        return true;
    }

    /**
        @notice Claim earned tokens from multiple reward contracts
        @param receiver Address to transfer tokens to. Any earned 3rd-party rewards
                        are also sent to this address.
        @param rewardContracts Array of addresses of registered receiver contracts where
                               the caller has pending rewards to claim.
        @return bool success
     */
    function batchClaimRewards(
        address receiver,
        IRewards[] calldata rewardContracts
    ) external returns (bool) {
        IBoostCalculator calculator = boostCalculator;
        uint256 totalAmount;
        uint256 totalAdjustedAmount;
        uint256 length = rewardContracts.length;
        for (uint256 i; i < length; ++i) {
            uint256 amount = rewardContracts[i].vaultClaimReward(msg.sender, receiver);
            if (amount == 0) continue;

            // calculate adjusted amount with actual boost applied
            uint256 adjustedAmount = amount;
            if (address(calculator) != address(0)) {
                adjustedAmount = calculator.getBoostedAmount(
                    address(rewardContracts[i]),
                    msg.sender,
                    amount
                );
            }

            allocated[address(rewardContracts[i])] -= amount;
            totalAmount += amount;
            totalAdjustedAmount += adjustedAmount;
        }

        // add `storedPendingReward` to `totalAdjustedAmount`
        // this happens after any boost modifiers, since
        // these effects were already applied to the stored value
        totalAdjustedAmount += storedPendingReward[msg.sender];

        _transferOrLock(msg.sender, receiver, totalAdjustedAmount);

        return true;
    }

    function _transferAllocated(
        address rewardContract,
        address account,
        address receiver,
        uint256 amount
    ) internal {
        if (amount > 0) {
            // calculate adjusted amount with actual boost applied
            uint256 adjustedAmount = amount;
            if (address(boostCalculator) != address(0)) {
                adjustedAmount = boostCalculator.getBoostedAmount(
                    rewardContract,
                    account,
                    amount
                );
            }
            {
                // additional tokens from boosted claims are removed from the unallocated total
                // context avoids stack-too-deep
                uint256 boostMoreClaimed = adjustedAmount - amount;
                if (boostMoreClaimed > 0) {
                    uint256 unallocated = unallocatedTotal - boostMoreClaimed;
                    unallocatedTotal = uint128(unallocated);
                    emit UnallocatedSupplyReduced(boostMoreClaimed, unallocated);
                }
            }

            // add `storedPendingReward` to `adjustedAmount`
            // this happens after any boost modifiers, since
            // these effects were already applied to the stored value
            adjustedAmount += storedPendingReward[account];

            _transferOrLock(account, receiver, adjustedAmount);
        }
    }

    function _transferOrLock(address claimant, address receiver, uint256 amount) internal {
        uint256 _lockWeeks = lockWeeks;
        if (_lockWeeks == 0) {
            storedPendingReward[claimant] = 0;
            strdyToken.transfer(receiver, amount);
        } else {
            // lock for receiver and store remaining balance in `storedPendingReward`
            uint256 lockAmount = amount / lockToTokenRatio;
            storedPendingReward[claimant] = amount - lockAmount * lockToTokenRatio;
            if (lockAmount > 0) locker.lock(receiver, lockAmount, _lockWeeks);
        }
    }

    /**
        @notice Claimable STRDY amount for `account` in `rewardContract` after applying boost
        @param account Address claiming rewards
        @param rewardContracts Address list of the contract where rewards are being claimed
        @return Amount received after boost

     */
    function claimableRewardAfterBoost(
        address account,
        address receiver,
        IRewards[] calldata rewardContracts
    ) external view returns (uint256) {
        IBoostCalculator calculator = boostCalculator;
        uint256 totalAdjustedAmount;
        uint256 length = rewardContracts.length;
        for (uint256 i; i < length; ++i) {
            uint256 amount = rewardContracts[i].claimableReward(account, 0);
            if (amount == 0) continue;

            uint256 adjustedAmount = amount;
            if (address(calculator) != address(0)) {
                adjustedAmount = calculator.getBoostedAmount(
                    address(rewardContracts[i]),
                    account,
                    amount
                );
            }

            totalAdjustedAmount += adjustedAmount;
        }

        return totalAdjustedAmount;
    }
}