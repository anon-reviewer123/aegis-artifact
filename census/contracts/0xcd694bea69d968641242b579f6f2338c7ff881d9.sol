/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import './utils/Withdrawable.sol';
import './utils/IWETH.sol';


/// @title ITBContract contract that implements common owner only functions accross all strategies
/// @author IntoTheBlock Corp
/// @dev Abstract
abstract contract ITBContract is Withdrawable {
    using SafeERC20 for IERC20;
    event ApproveToken(address indexed token, address guy, uint256 wad);
    address payable immutable public WNATIVE;

    /// @param _executors Executor addresses
    constructor(address[] memory _executors, address payable _wnative) Executable(_executors) {
        WNATIVE = _wnative;
    }

    /// @notice Set allowance for a given token, amount and spender
    /// @param _token Token to spend
    /// @param _guy Spender
    /// @param _wad Max amount to spend
    function _approveToken(address _token, address _guy, uint256 _wad) internal {
        if (_wad != 0) {
            if (IERC20(_token).allowance(address(this), _guy) >= _wad)
                return;
            IERC20(_token).safeApprove(_guy, 0);
        }
        IERC20(_token).safeApprove(_guy, _wad);
        emit ApproveToken(_token, _guy, _wad);
    }

    /// @notice Check current allowance and, if necessary, set it to a new amount for a given token, amount and spender
    /// @param _token Token to spend
    /// @param _guy Spender
    /// @param _amount New max amount to spend
    function _checkAllowanceAndApprove(address _token, address _guy, uint256 _amount) internal {
        if (IERC20(_token).allowance(address(this), _guy) < _amount)
            _approveToken(_token, _guy, type(uint256).max);
    }

    /// @notice Only owner. Set allowance for a given token, amount and spender
    /// @param _token Token to spend
    /// @param _guy Spender
    /// @param _wad Max amount to spend
    function approveToken(address _token, address _guy, uint256 _wad) external onlyOwner {
        _approveToken(_token, _guy, _wad);
    }

    /// @notice Only owner. Revoke allowance for a given token and spender
    /// @param _token Token to spend
    /// @param _guy Spender
    function revokeToken(address _token, address _guy) external onlyOwner {
        _approveToken(_token, _guy, 0);
    }

    /// @notice Only owner. Execute an arbitrary call
    /// @param _to Target address
    /// @param _value Value (i. e. msg.value)
    /// @param _data Invocation data
    function execute(address _to, uint256 _value, bytes calldata _data) external payable onlyOwner {
        (bool success, bytes memory returnData) = _to.call{ value: _value }(_data);
        require(success, string(returnData));
    }

    /// @notice Only owner. Execute multiple arbitrary calls in order
    /// @param _tos Target address for each call
    /// @param _values Value for each call (i. e. msg.value)
    /// @param _datas Invocation data for each call
    function batchExecute(address[] calldata _tos, uint256[] calldata _values, bytes[] calldata _datas) external payable onlyOwner {
        require(_tos.length == _values.length && _tos.length == _datas.length, "Arguments length mismatch");
        for (uint256 i = 0; i < _tos.length; i++) {
            (bool success, bytes memory returnData) = _tos[i].call{ value: _values[i] }(_datas[i]);
            require(success, string(returnData));
        }
    }

    function wrapNative(uint256 _amount) public onlyExecutor {
        IWETH(WNATIVE).deposit{ value: _amount }();
    }

    function unwrapNative(uint256 _amount) public onlyExecutor {
        IWETH(WNATIVE).withdraw(_amount);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title Base contract that implements executor related functions
/// @author IntoTheBlock Corp
/// @dev Abstract
abstract contract Executable is Ownable2Step {
    mapping(address => bool) public executors;

    event ExecutorUpdated(address indexed executor, bool enabled);

    /// @param _executors Initial whitelisted executor addresses
    constructor(address[] memory _executors) {
        for (uint256 i = 0; i < _executors.length; i++) {
            addExecutor(_executors[i]);
        }
    }

    /// @notice Revert if call is not being made from the owner or an executor
    modifier onlyExecutor() {
        require(owner() == msg.sender || executors[msg.sender], "Executable: caller is not the executor");
        _;
    }

    /// @notice Only owner. Add an executor
    /// @param _executor New executor address
    function addExecutor(address _executor) public onlyOwner {
        emit ExecutorUpdated(_executor, true);
        executors[_executor] = true;
    }

    /// @notice Only owner. Remove an executor
    /// @param _executor Executor address to remove
    function removeExecutor(address _executor) external onlyOwner {
        emit ExecutorUpdated(_executor, false);
        executors[_executor] = false;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IWETH {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);

    fallback() external payable;
    receive() external payable;
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function totalSupply() external view returns (uint256);
    function approve(address guy, uint256 wad) external returns (bool);
    function transfer(address dst, uint256 wad) external returns (bool);
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import './Executable.sol';

/**
    Ensures that any contract that inherits from this contract is able to
    withdraw funds that are accidentally received or stuck.
 */

/// @title Base contract that implements withdrawal related functions
/// @author IntoTheBlock Corp
/// @dev Abstract
abstract contract Withdrawable is Executable {
    using SafeERC20 for IERC20;
    address constant ETHER = address(0);

    event LogWithdraw(
        address indexed _to,
        address indexed _asset_address,
        uint256 amount
    );

    receive() external payable {}

    /// @notice ERC20 or ETH balance of this contract given a token address
    /// @param _asset_address Token address or address(0) for ETH
    /// @return Balance    
    function _balance(address _asset_address) internal view returns (uint256) {
        return _asset_address == ETHER ? address(this).balance : IERC20(_asset_address).balanceOf(address(this));
    }
    
    /// @notice ERC20 balance of given account
    /// @param _asset_address Token address 
    /// @param _account Account address 
    /// @return Balance  
    function balanceOf(address _asset_address, address _account) public view returns (uint256) {
        return IERC20(_asset_address).balanceOf(_account);
    }

    /// @notice Send the given amount of the given token or ETH to the given receiver
    /// @param _asset_address Token address or address(0) for ETH
    /// @param _amount Amount to send
    /// @param _to Receiver address
    function _withdraw_to(address _asset_address, uint256 _amount, address payable _to) internal {
        require(_to != address(0), 'Invalid address');
        uint256 balance = _balance(_asset_address);
        require(balance >= _amount, 'Insufficient funds');
        if (_asset_address == ETHER) {
            (bool success, ) = _to.call{value: _amount}(''); /* carry gas over so it works with contracts with custom fallback, we dont care about reentrancy on onlyOwner */
            require(success, 'Native transfer failed.');
        } else
            IERC20(_asset_address).safeTransfer(_to, _amount);
        emit LogWithdraw(_to, _asset_address, _amount);
    }

    /// @notice Only owner. Send the given amount of the given token or ETH to the caller
    /// @param _asset_address Token address or address(0) for ETH
    /// @param _amount Amount to send
    function withdraw(address _asset_address, uint256 _amount) external onlyOwner {
        _withdraw_to(_asset_address, _amount, payable(msg.sender));
    }

    /// @notice Only owner. Send the given amount of the given token or ETH to the given receiver
    /// @param _asset_address Token address or address(0) for ETH
    /// @param _amount Amount to send
    /// @param _to Receiver address
    function withdrawTo(address _asset_address, uint256 _amount, address payable _to) external onlyOwner {
        _withdraw_to(_asset_address, _amount, _to);
    }

    /// @notice Only owner. Send its entire balance of the given token or ETH to the caller
    /// @param _asset_address Token address or address(0) for ETH
    function withdrawAll(address _asset_address) external onlyOwner {
        uint256 balance = _balance(_asset_address);
        _withdraw_to(_asset_address, balance, payable(msg.sender));
    }

    /// @notice Only owner. Send its entire balance of the given token or ETH to the given receiver
    /// @param _asset_address Token address or address(0) for ETH
    /// @param _to Receiver address
    function withdrawAllTo(address _asset_address, address payable _to) external onlyOwner {
        uint256 balance = _balance(_asset_address);
        _withdraw_to(_asset_address, balance, _to);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.0;

import "./Ownable.sol";

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership} and {acceptOwnership}.
 *
 * This module is used through inheritance. It will make available all functions
 * from parent (Ownable).
 */
abstract contract Ownable2Step is Ownable {
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    /**
     * @dev The new owner accepts the ownership transfer.
     */
    function acceptOwnership() public virtual {
        address sender = _msgSender();
        require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
        _transferOwnership(sender);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

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
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

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

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

interface IDelegation {

  struct QueuedWithdrawalParams {
      address[] strategies;
      uint256[] shares;
      address withdrawer;
  }

  struct Withdrawal {
      address staker;
      address delegatedTo;
      address withdrawer;
      uint256 nonce;
      uint32 startBlock;
      address[] strategies;
      uint256[] shares;
  } 

  struct SignatureWithExpiry {
    bytes signature;
    uint expiry;
  }

  function queueWithdrawals(QueuedWithdrawalParams[] memory) external returns (uint256 shares);
  
  function getWithdrawalDelay(address[] memory) external view returns (uint256);

  function delegatedTo(address) external view returns (address);
  
  function delegateTo(address, SignatureWithExpiry memory, bytes32) external;

  function undelegate(address) external returns (bytes32[] memory);
  
  function cumulativeWithdrawalsQueued(address) external view returns (uint);

  function completeQueuedWithdrawal(Withdrawal memory, address[] memory, uint, bool) external;

  function calculateWithdrawalRoot(Withdrawal memory) external pure returns (bytes32);

  function pendingWithdrawals(bytes32) external view returns (bool); 

  function delegationApprover(address operator) external view returns (address);
}

/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

interface ILiquidStaking {

  function sharesToUnderlying(uint) external view returns (uint256 shares);

  function shares(address) external view returns (uint256 shares);
  
  function totalShares() external view returns (uint256);
  
}

/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

interface IStrategyManager {

  function depositIntoStrategy(address strategy, address token, uint256 amount) external returns (uint256 shares);

}

/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import '@itb/quant-common/contracts/solidity8/ITBContract.sol';
import './interfaces/IStrategyManager.sol';
import './interfaces/ILiquidStaking.sol';
import './interfaces/IDelegation.sol';

/// @title PositionManager for EigenLayer
/// @author IntoTheBlock Corp
contract PositionManager is ITBContract {
    struct PositionConfig {
        address liquid_staking;
        address underlying;
        address delegate_to;
    }

    struct QueuedWithdrawal {
        uint withdrawal_block;
        address[] tokens;
        IDelegation.Withdrawal withdrawal;
    }

    event Deposit(address indexed caller, address token, uint amount, uint lpt_change);
    event StartWithdrawal(address indexed caller, address token, uint withdrawal_nonce, uint withdrawal_index, uint start_block, uint withdrawal_block, uint lpt_amount);
    event Withdraw(address indexed caller, address token, uint withdrawal_nonce, uint withdrawal_index, uint amount, uint lpt_change);

    event Assemble(address indexed caller, address[] tokens, uint[] amounts, uint lpt_change);
    event Disassemble(address indexed caller, address[] tokens, uint[] amounts, uint lpt_change);
    event UpdateStrategyManager(address indexed caller, address strategy_manager);
    event UpdateDelegationManager(address indexed caller, address delegation_manager);
    event UpdatePositionConfig(address indexed caller, address liquid_staking, address underlying, address delegate_to);

    PositionConfig public positionConfig;
    
    IStrategyManager public strategyManager;
    IDelegation public delegationManager;

    mapping(uint => QueuedWithdrawal) public withdrawalQueue;
    uint public cumulativeWithdrawalsQueued;
    uint public indexNextWithdrawal;

    function VERSION() external pure returns (string memory) {
        return "1.0.0";
    }

    constructor(address[] memory _executors, address payable _wnative, address _strategy_manager, address _delegation_manager, address _liquid_staking, address _underlying, address _delegate_to) ITBContract(_executors, _wnative) {
        updateStrategyManager(_strategy_manager);
        updateDelegationManager(_delegation_manager);
        updatePositionConfig(_liquid_staking, _underlying, _delegate_to);
        if (_delegate_to != address(0))
            delegate();
    }

    function updateStrategyManager(address _strategy_manager) public onlyOwner {
        strategyManager = IStrategyManager(_strategy_manager);
        emit UpdateStrategyManager(msg.sender, _strategy_manager);
    }

    function updateDelegationManager(address _delegation_manager) public onlyOwner {
        delegationManager = IDelegation(_delegation_manager);
        emit UpdateDelegationManager(msg.sender, _delegation_manager);
    }

    function updatePositionConfig(address _liquid_staking, address _underlying, address _delegate_to) public onlyOwner {
        positionConfig = PositionConfig(
            _liquid_staking,
            _underlying,
            _delegate_to
        );
        emit UpdatePositionConfig(msg.sender, _liquid_staking, _underlying, _delegate_to);
    }

    modifier hasConfig() {
        require(positionConfig.liquid_staking != address(0), 'A3'); // position_config is missing
        _;
    }

    function _percentageAmount(uint _amount, uint _percentage) internal pure returns (uint) {
        return _amount * _percentage / 1e18;
    }

    function getWithdrawalDelay() public view returns (uint) {
        address[] memory strategies = new address[](1);
        strategies[0] = address(strategyManager);
        return delegationManager.getWithdrawalDelay(strategies);
    }

    function getPositionAssets() public view returns (address[] memory) {
        address[] memory assets = new address[](1);
        assets[0] = positionConfig.underlying;
        return assets;
    }

    function getUnderlyings() external view returns (address[] memory assets, uint[] memory amounts) {
        address[] memory tokens = getPositionAssets();
        uint[] memory balances = new uint[](tokens.length);
        balances[0] = ILiquidStaking(positionConfig.liquid_staking).sharesToUnderlying(getTotalLPT());
        return (tokens, balances);
    }

    function getLPTStaked() public view returns (uint) {
        return ILiquidStaking(positionConfig.liquid_staking).shares(address(this));
    }

    function lptPendingOfWithdraw() public view returns (uint amount_pending) { 
        for (uint i = indexNextWithdrawal; i < cumulativeWithdrawalsQueued; i++)
            amount_pending += withdrawalQueue[i].withdrawal.shares[0];
    }

    function getTotalLPT() public view returns (uint) {
        return getLPTStaked() + lptPendingOfWithdraw();
    }

    function haveWithdrawalsQueued() public view returns (bool) {
        return cumulativeWithdrawalsQueued > indexNextWithdrawal;
    }

    function withdrawalIsPending(uint _withdrawal_index) public view returns (bool) {
        bytes32 root = delegationManager.calculateWithdrawalRoot(withdrawalQueue[_withdrawal_index].withdrawal);
        return delegationManager.pendingWithdrawals(root);
    }

    function withdrawalIsReady(uint _withdrawal_index) public view returns (bool) {
        QueuedWithdrawal memory w = withdrawalQueue[_withdrawal_index];
        return withdrawalIsPending(_withdrawal_index) && block.number >= w.withdrawal_block;
    }

    function nextWithdrawalIsReady() public view returns (bool) {
        return withdrawalIsReady(indexNextWithdrawal);
    }

    function canCompleteWithdrawals() public view returns (bool) {
        return haveWithdrawalsQueued() && nextWithdrawalIsReady();
    }

    function delegate() public onlyExecutor hasConfig {
        _delegate(new bytes(0), 0, bytes32(0));
    }

    function delegateWithSignature(bytes memory _signature, uint _expiry, bytes32 _salt) public onlyOwner hasConfig {
        _delegate(_signature, _expiry, _salt);
    }

    function _delegate(bytes memory _signature, uint _expiry, bytes32 _salt) internal {
        if (delegationManager.delegatedTo(address(this)) != address(0))
            undelegate();
        delegationManager.delegateTo(positionConfig.delegate_to, IDelegation.SignatureWithExpiry(_signature, _expiry), _salt);
    }

    function undelegate() public onlyExecutor hasConfig {
        uint lpt = getTotalLPT();
        require(lpt == 0, 'D1');
        delegationManager.undelegate(address(this));
    }

    function deposit(uint _amount, uint _min_lpt_out) public onlyExecutor hasConfig returns (uint lpt_out) {
        PositionConfig memory c = positionConfig;

        lpt_out = strategyManager.depositIntoStrategy(c.liquid_staking, c.underlying, _amount);
        require(lpt_out >= _min_lpt_out);

        emit Deposit(msg.sender, c.underlying, _amount, lpt_out);
    }
    
    function startWithdrawal(uint _shares_amount) public onlyExecutor hasConfig {
        PositionConfig memory c = positionConfig;
        uint nonce = delegationManager.cumulativeWithdrawalsQueued(address(this));
        uint withdrawal_block = block.number + getWithdrawalDelay();
        uint withdrawal_index = cumulativeWithdrawalsQueued;

        {
            address[] memory strategies = new address[](1);
            strategies[0] = c.liquid_staking;
            uint[] memory shares = new uint[](1);
            shares[0] = _shares_amount;
            address[] memory tokens = new address[](1);
            tokens[0] = c.underlying;
            IDelegation.Withdrawal memory withdrawal = IDelegation.Withdrawal({
                staker: address(this),
                delegatedTo: delegationManager.delegatedTo(address(this)),
                withdrawer: address(this),
                nonce: nonce,
                startBlock: uint32(block.number),
                strategies: strategies,
                shares: shares
            });
            withdrawalQueue[withdrawal_index] = QueuedWithdrawal({
                withdrawal_block: withdrawal_block,
                tokens: tokens,
                withdrawal: withdrawal
            });
            
            IDelegation.QueuedWithdrawalParams[] memory queuedWithdrawalParams = new IDelegation.QueuedWithdrawalParams[](1);
            queuedWithdrawalParams[0] = IDelegation.QueuedWithdrawalParams({
                strategies: strategies,
                shares: shares,
                withdrawer: address(this)
            });
            delegationManager.queueWithdrawals(queuedWithdrawalParams);
            cumulativeWithdrawalsQueued++;
        }

        emit StartWithdrawal(msg.sender, c.underlying, nonce, withdrawal_index, block.number, withdrawal_block, _shares_amount);
    }

    /// @dev Should not be used under normal circumstances, will break withdrawal index flow
    function completeWithdrawal(uint _withdrawal_index, uint _min_out) public onlyExecutor hasConfig returns (uint lpt_burnt, uint coin_out) {
        require(withdrawalIsPending(_withdrawal_index), 'W1');
        require(withdrawalIsReady(_withdrawal_index), 'W2');

        QueuedWithdrawal memory w = withdrawalQueue[_withdrawal_index];
        address underlying = w.tokens[0];
        uint underlying_before = _balance(underlying);
        
        delegationManager.completeQueuedWithdrawal(w.withdrawal, w.tokens, 0, true);

        lpt_burnt = w.withdrawal.shares[0];
        coin_out = _balance(underlying) - underlying_before;
        require(coin_out >= _min_out, 'W3');

        emit Withdraw(msg.sender, underlying, w.withdrawal.nonce, _withdrawal_index, coin_out, lpt_burnt);
    }

    function completeNextWithdrawal(uint _min_out) public onlyExecutor hasConfig returns (uint lpt_burnt, uint coin_out) {
        (lpt_burnt, coin_out) = completeWithdrawal(indexNextWithdrawal, _min_out);
        indexNextWithdrawal++;
    }

    function completeNextWithdrawals(uint _min_out) public onlyExecutor hasConfig returns (uint total_lpt_burnt, uint total_coin_out) {
        while (canCompleteWithdrawals()) {
            (uint lpt_burnt, uint coin_out) = completeNextWithdrawal(0);
            total_lpt_burnt += lpt_burnt;
            total_coin_out += coin_out;
        }
        require(total_coin_out >= _min_out, 'W4');
    }

    /// @dev Should not be used under normal circumstances
    function overrideWithdrawalIndexes(uint _cumulativeWithdrawalsQueued, uint _indexNextWithdrawal) external onlyExecutor {
        cumulativeWithdrawalsQueued = _cumulativeWithdrawalsQueued;
        indexNextWithdrawal = _indexNextWithdrawal;
    }

    function assemble(uint _min_lpt_out) public onlyExecutor hasConfig returns (uint lpt_out) {
        PositionConfig memory c = positionConfig;
        uint underlying_amount = _balance(c.underlying);

        lpt_out = deposit(underlying_amount, _min_lpt_out);

        address[] memory tokens = getPositionAssets();
        uint[] memory underlyings_change = new uint[](tokens.length);
        underlyings_change[0] = underlying_amount - _balance(c.underlying);

        emit Assemble(msg.sender, tokens, underlyings_change, lpt_out);
    }

    function disassemble(uint _percentage, uint _min_coin_out) public onlyExecutor hasConfig returns (uint coin_out) {
        uint lpt_burnt;
        
        if (_percentage > 0) {
            uint lpt_amount = _percentageAmount(getLPTStaked(), _percentage);
            startWithdrawal(lpt_amount);
        }
        (lpt_burnt, coin_out) = completeNextWithdrawals(_min_coin_out);
        
        address[] memory tokens = getPositionAssets();
        uint[] memory underlyings_change = new uint[](tokens.length);
        underlyings_change[0] = coin_out;
        emit Disassemble(msg.sender, tokens, underlyings_change, lpt_burnt);
    }

    function fullDisassemble(uint _min_coin_out) public onlyExecutor hasConfig returns (uint) {
        return disassemble(1e18, _min_coin_out);
    }
}