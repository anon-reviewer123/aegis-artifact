// SPDX-License-Identifier: MIT

// Real Estate Alliance League, Illinois, USA
// Token Sale Phase 1: 1,100,000 REAL available @ $5 each
// Token Sale Page:    https://app.thisisreal.io/sale  
// https://ThisIsREAL.io    /    email: support@thisisreal.io 
// Real Estate Educational Platform with DAO
// Tokenomics Maximum Supply 100,000,000  /  Initial Circulating Supply is 21,000,000
// See Token Details at our website ThisIsREAL.io including token supply dispursement and vesting schedules.


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;


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

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
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
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
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
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
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

// File: @chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol


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

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

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
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
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

// File: @openzeppelin/contracts/interfaces/IERC20.sol


// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

pragma solidity ^0.8.20;


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


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

// File: @openzeppelin/contracts/interfaces/IERC165.sol


// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

pragma solidity ^0.8.20;


// File: @openzeppelin/contracts/interfaces/IERC1363.sol


// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)

pragma solidity ^0.8.20;



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

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v5.2.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;



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

// File: @openzeppelin/contracts/utils/Pausable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;


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

// File: TokenSaleREAL.sol



// Real Estate Alliance League, Illinois, USA
// Token Sale Phase 1: 1,100,000 REAL available @ $5 each
// Token Sale Page:    https://app.thisisreal.io/sale  
// https://ThisIsREAL.io    /    email: support@thisisreal.io 
// Real Estate Educational Platform with DAO
// Tokenomics Maximum Supply 100,000,000  /  Initial Circulating Supply is 21,000,000
// See Token Details at our website ThisIsREAL.io including token supply dispursement and vesting schedules.

pragma solidity ^0.8.28;







contract TokenSaleREAL is Ownable, ReentrancyGuard, Pausable {
    uint256 public HARDCAP;
    uint256 public totalBought;
    uint64 public icoDuration; // in seconds
    uint64 public icoStartTime;

    AggregatorV3Interface internal priceFeed;

    IERC20Metadata public immutable real;
    IERC20Metadata public immutable usdt;
    IERC20Metadata public immutable usdc;
    IERC20Metadata public immutable dai;

    mapping(uint32 => mapping(address => uint256)) public userBought;

    struct Stage {
        uint64 timeToStart;
        uint64 timeToEnd;
        uint256 totalRealBought;
        uint256 totalETHCollected;
        uint256 totalUSDTCollected;
        uint256 totalUSDCCollected;
        uint256 totalDAICollected;
        uint256 price;
    }

    struct UserBoughtData {
        uint32 stageID;
        uint256 amount;
    }

    Stage[] public stages;

    event ICOStarted(
        uint64 _icoStartTime,
        uint64 _icoEndTime,
        uint64 _icoDuration
    );
    event StageCreated(
        uint32 indexed _stageId,
        uint64 _timeToStart,
        uint64 _timeToEnd,
        uint256 _price
    );
    event StageUpdated(
        uint32 indexed _stageId,
        uint64 _timeToStart,
        uint64 _timeToEnd,
        uint256 _price
    );
    event REALPurchasedWithETH(
        address indexed _user,
        uint32 indexed _stage,
        uint256 _baseAmount,
        uint256 _quoteAmount
    );
    event REALPurchasedWithUSDT(
        address indexed _user,
        uint32 indexed _stage,
        uint256 _baseAmount,
        uint256 _quoteAmount
    );
    event REALPurchasedWithUSDC(
        address indexed _user,
        uint32 indexed _stage,
        uint256 _baseAmount,
        uint256 _quoteAmount
    );
    event REALPurchasedWithDAI(
        address indexed _user,
        uint32 indexed _stage,
        uint256 _baseAmount,
        uint256 _quoteAmount
    );
    event ETHWithdrawn(uint256 _amount);
    event USDTWithdrawn(uint256 _amount);
    event USDCWithdrawn(uint256 _amount);
    event REALWithdrawn(uint256 _amount);
    // REAL 0x325Aa344761c19F7ab6dc45A95f01d6907A30DCA
    // USDT 0xdAC17F958D2ee523a2206206994597C13D831ec7
    // USDC 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    // DAI  0x6B175474E89094C44Da98b954EedeAC495271d0F


    receive() external payable {}

    fallback() external payable {}

    modifier validStage(uint32 _stageId) {
        require(_stageId < stages.length, "Presale: Invalid stage ID");
        _;
    }

    constructor(
        address _real,
        address _usdt,
        address _usdc,
        address _dai,
        uint256 _hardCAP
    ) Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
            );
        //priceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);

        real = IERC20Metadata(_real);
        usdt = IERC20Metadata(_usdt);
        usdc = IERC20Metadata(_usdc);
        dai = IERC20Metadata(_dai);
        HARDCAP = _hardCAP;
    }

    function startICO(uint64 _icoDuration) external onlyOwner {
        icoDuration = _icoDuration;
        icoStartTime = uint64(block.timestamp);

        emit ICOStarted(
            icoStartTime,
            (icoStartTime + icoDuration),
            icoDuration
        );
    }

    function createStage(
        uint64 _timeToStart,
        uint64 _timeToEnd,
        uint256 _price
    ) external onlyOwner {
        stages.push(
            Stage({
                timeToStart: _timeToStart,
                timeToEnd: _timeToEnd,
                totalRealBought: 0,
                totalETHCollected: 0,
                totalUSDTCollected: 0,
                totalUSDCCollected: 0,
                totalDAICollected: 0,
                price: _price
            })
        );

        emit StageCreated(
            uint32(stages.length - 1),
            _timeToStart,
            _timeToEnd,
            _price
        );
    }

    function updateStage(
        uint32 _stageId,
        uint64 _timeToStart,
        uint64 _timeToEnd,
        uint256 _price
    ) external onlyOwner validStage(_stageId) {
        Stage storage stage = stages[_stageId];
        stage.timeToStart = _timeToStart;
        stage.timeToEnd = _timeToEnd;
        stage.price = _price;

        emit StageUpdated(_stageId, _timeToStart, _timeToEnd, _price);
    }

    function buyREALWithETH(
        uint32 _stageId
    ) external payable whenNotPaused nonReentrant validStage(_stageId) {
        require(getStageStatus(_stageId), "Presale: In-active stage ID");
        require(getICOStatus(), "Presale: In-active ICO");

        Stage storage stage = stages[_stageId];

        require(msg.value > 0, "Presale: Should be greater than 0");

        (uint256 price, uint256 updatedAt) = getLatestETHPrice();
        require(price > 0, "Invalid price feed data");
        require(block.timestamp - updatedAt < 1 hours, "Stale price");

        uint256 buyAmount = (msg.value * price) /
            (stage.price * 10 ** real.decimals());

        userBought[_stageId][msg.sender] += buyAmount;
        totalBought += buyAmount;
        stage.totalRealBought += buyAmount;
        stage.totalETHCollected += msg.value;

        require(totalBought <= HARDCAP, "Presale: Hardcap reached");

        SafeERC20.safeTransfer(IERC20(address(real)), msg.sender, buyAmount);

        emit REALPurchasedWithETH(msg.sender, _stageId, msg.value, buyAmount);
    }

    function buyREALWithUSDT(
        uint32 _stageId,
        uint256 _amount
    ) external whenNotPaused nonReentrant validStage(_stageId) {
        require(getStageStatus(_stageId), "Presale: In-active stage ID");
        require(getICOStatus(), "Presale: In-active ICO");

        Stage storage stage = stages[_stageId];

        require(_amount > 0, "Presale: Should be greater than 0");

        SafeERC20.safeTransferFrom(
            IERC20(address(usdt)),
            msg.sender,
            address(this),
            _amount
        );

        uint256 buyAmount = (_amount * (10 ** real.decimals())) /
            (stage.price * (10 ** usdt.decimals()));

        userBought[_stageId][msg.sender] += buyAmount;
        totalBought += buyAmount;
        stage.totalRealBought += buyAmount;
        stage.totalUSDTCollected += _amount;

        require(totalBought <= HARDCAP, "Presale: Hardcap reached");

        SafeERC20.safeTransfer(IERC20(address(real)), msg.sender, buyAmount);

        emit REALPurchasedWithUSDT(msg.sender, _stageId, _amount, buyAmount);
    }

    function buyREALWithUSDC(
        uint32 _stageId,
        uint256 _amount
    ) external whenNotPaused nonReentrant validStage(_stageId) {
        require(getStageStatus(_stageId), "Presale: In-active stage ID");
        require(getICOStatus(), "Presale: In-active ICO");

        Stage storage stage = stages[_stageId];

        require(_amount > 0, "Presale: Should be greater than 0");

        SafeERC20.safeTransferFrom(
            IERC20(address(usdc)),
            msg.sender,
            address(this),
            _amount
        );

        uint256 buyAmount = (_amount * (10 ** real.decimals())) /
            (stage.price * (10 ** usdc.decimals()));

        userBought[_stageId][msg.sender] += buyAmount;
        totalBought += buyAmount;
        stage.totalRealBought += buyAmount;
        stage.totalUSDCCollected += _amount;

        require(totalBought <= HARDCAP, "Presale: Hardcap reached");

        SafeERC20.safeTransfer(IERC20(address(real)), msg.sender, buyAmount);

        emit REALPurchasedWithUSDC(msg.sender, _stageId, _amount, buyAmount);
    }

    function buyREALWithDAI(
        uint32 _stageId,
        uint256 _amount
    ) external whenNotPaused nonReentrant validStage(_stageId) {
        require(getStageStatus(_stageId), "Presale: In-active stage ID");
        require(getICOStatus(), "Presale: In-active ICO");

        Stage storage stage = stages[_stageId];

        require(_amount > 0, "Presale: Should be greater than 0");

        SafeERC20.safeTransferFrom(
            IERC20(address(dai)),
            msg.sender,
            address(this),
            _amount
        );

        uint256 buyAmount = (_amount * (10 ** real.decimals())) /
            (stage.price * (10 ** dai.decimals()));

        userBought[_stageId][msg.sender] += buyAmount;
        totalBought += buyAmount;
        stage.totalRealBought += buyAmount;
        stage.totalDAICollected += _amount;

        require(totalBought <= HARDCAP, "Presale: Hardcap reached");

        SafeERC20.safeTransfer(IERC20(address(real)), msg.sender, buyAmount);

        emit REALPurchasedWithDAI(msg.sender, _stageId, _amount, buyAmount);
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(
            address(this).balance >= amount,
            "Presale: Not enough ETH in contract"
        );
        payable(msg.sender).transfer(amount);

        emit ETHWithdrawn(amount);
    }

    function withdrawUSDT(uint256 amount) external onlyOwner {
        require(
            usdt.balanceOf(address(this)) >= amount,
            "Presale: Not enough USDT in contract"
        );
        SafeERC20.safeTransfer(IERC20(address(usdt)), msg.sender, amount);

        emit USDTWithdrawn(amount);
    }

    function withdrawUSDC(uint256 amount) external onlyOwner {
        require(
            usdc.balanceOf(address(this)) >= amount,
            "Presale: Not enough USDC in contract"
        );
        SafeERC20.safeTransfer(IERC20(address(usdc)), msg.sender, amount);

        emit USDCWithdrawn(amount);
    }

    function withdrawREAL(uint256 amount) external onlyOwner {
        require(
            real.balanceOf(address(this)) >= amount,
            "Presale: Not enough REAL in contract"
        );
        SafeERC20.safeTransfer(IERC20(address(real)), msg.sender, amount);

        emit REALWithdrawn(amount);
    }

    function pause() public whenNotPaused onlyOwner{
        _pause();
    }

    function unpause() public whenPaused onlyOwner{
        _unpause();
    }

    // method `setHARDCAP`
    // @dev - for testing purpose only
    function setHARDCAP(uint256 hardcap) public onlyOwner {
        HARDCAP = hardcap;
    }

    // method `setICODuration`
    // @dev - for testing purpose only
    function setICODuration(uint64 _icoDuration) public onlyOwner {
        icoDuration = _icoDuration;
    }

    function getLatestETHPrice() public view returns (uint256, uint256) {
        (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        return ((uint256(price) * 10 ** 10), updatedAt); // Convert to 18 decimals
    }

    function getStageStatus(
        uint32 _stageId
    ) public view returns (bool _status) {
        if (
            block.timestamp >= uint256(stages[_stageId].timeToStart) &&
            block.timestamp <= uint256(stages[_stageId].timeToEnd)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function getICOStatus() public view returns (bool _status) {
        if (icoStartTime == 0 || block.timestamp < uint256(icoStartTime)) {
            return false;
        }

        if (totalBought >= HARDCAP) {
            return false;
        }
            if (block.timestamp > uint256(icoStartTime + icoDuration)) {
            return false;
        }
        return true;
    }

    function userTotalBought(
        address user
    )
        public
        view
        returns (UserBoughtData[] memory data, uint256 _userTotalBought)
    {
        data = new UserBoughtData[](stages.length);
        for (uint32 i = 0; i < stages.length; i++) {
            data[uint(i)].stageID = i;
            data[uint(i)].amount = userBought[i][user];
            _userTotalBought += userBought[i][user];
        }
    }
}