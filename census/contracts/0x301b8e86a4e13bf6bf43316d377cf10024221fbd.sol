// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

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
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
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
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
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
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
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
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC3156FlashBorrower.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC3156 FlashBorrower, as defined in
 * https://eips.ethereum.org/EIPS/eip-3156[ERC-3156].
 */
interface IERC3156FlashBorrower {
    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.20;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
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

pragma solidity ^0.8.0;

type UAddress is uint256;

/**
 * @dev Library for working with addresses encoded as uint256 values, which can include flags in the highest bits.
 */
library AddressLib {
    uint256 private constant _LOW_160_BIT_MASK = (1 << 160) - 1;

    /**
     * @notice Returns the address representation of a uint256.
     * @param a The uint256 value to convert to an address.
     * @return The address representation of the provided uint256 value.
     */
    function get(UAddress a) internal pure returns (address) {
        return address(uint160(UAddress.unwrap(a) & _LOW_160_BIT_MASK));
    }

    /**
     * @notice Checks if a given flag is set for the provided address.
     * @param a The address to check for the flag.
     * @param flag The flag to check for in the provided address.
     * @return True if the provided flag is set in the address, false otherwise.
     */
    function getFlag(UAddress a, uint256 flag) internal pure returns (bool) {
        return (UAddress.unwrap(a) & flag) != 0;
    }

    /**
     * @notice Returns a uint32 value stored at a specific bit offset in the provided address.
     * @param a The address containing the uint32 value.
     * @param offset The bit offset at which the uint32 value is stored.
     * @return The uint32 value stored in the address at the specified bit offset.
     */
    function getUint32(UAddress a, uint256 offset) internal pure returns (uint32) {
        return uint32(UAddress.unwrap(a) >> offset);
    }

    /**
     * @notice Returns a uint64 value stored at a specific bit offset in the provided address.
     * @param a The address containing the uint64 value.
     * @param offset The bit offset at which the uint64 value is stored.
     * @return The uint64 value stored in the address at the specified bit offset.
     */
    function getUint64(UAddress a, uint256 offset) internal pure returns (uint64) {
        return uint64(UAddress.unwrap(a) >> offset);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for making arbitrary calls during swap
interface IAggregationExecutor {
    /// @notice propagates information about original msg.sender and executes arbitrary data
    function execute(address msgSender) external payable returns (uint256); // 0x4b64e492
}

interface IAggregationRouterV6 {
    type Address is uint256;

    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    function swap(IAggregationExecutor executor, SwapDescription calldata desc, bytes calldata data)
        external
        returns (uint256 returnAmount, uint256 spentAmount);

    // uno

    /**
     * @notice Swaps `amount` of the specified `token` for another token using an Unoswap-compatible exchange's pool,
     *         with a minimum return specified by `minReturn`.
     * @param token The address of the token to be swapped.
     * @param amount The amount of tokens to be swapped.
     * @param minReturn The minimum amount of tokens to be received after the swap.
     * @param dex The address of the Unoswap-compatible exchange's pool.
     * @return returnAmount The actual amount of tokens received after the swap.
     */
    function unoswap(Address token, uint256 amount, uint256 minReturn, Address dex)
        external
        returns (uint256 returnAmount);

    /**
     * @notice Swaps ETH for another token using an Unoswap-compatible exchange's pool, with a minimum return specified by `minReturn`.
     *         The function is payable and requires the sender to attach ETH.
     *         It is necessary to check if it's cheaper to use _WETH_NOT_WRAP_FLAG in `dex` Address (for example: for Curve pools).
     * @param minReturn The minimum amount of tokens to be received after the swap.
     * @param dex The address of the Unoswap-compatible exchange's pool.
     * @return returnAmount The actual amount of tokens received after the swap.
     */
    function ethUnoswap(uint256 minReturn, Address dex) external payable returns (uint256 returnAmount);

    /**
     * @notice Swaps `amount` of the specified `token` for another token using two Unoswap-compatible exchange pools (`dex` and `dex2`) sequentially,
     *         with a minimum return specified by `minReturn`.
     * @param token The address of the token to be swapped.
     * @param amount The amount of tokens to be swapped.
     * @param minReturn The minimum amount of tokens to be received after the swap.
     * @param dex The address of the first Unoswap-compatible exchange's pool.
     * @param dex2 The address of the second Unoswap-compatible exchange's pool.
     * @return returnAmount The actual amount of tokens received after the swap through both pools.
     */
    function unoswap2(Address token, uint256 amount, uint256 minReturn, Address dex, Address dex2)
        external
        returns (uint256 returnAmount);

    /**
     * @notice Swaps ETH for another token using two Unoswap-compatible exchange pools (`dex` and `dex2`) sequentially,
     *         with a minimum return specified by `minReturn`. The function is payable and requires the sender to attach ETH.
     *         It is necessary to check if it's cheaper to use _WETH_NOT_WRAP_FLAG in `dex` Address (for example: for Curve pools).
     * @param minReturn The minimum amount of tokens to be received after the swap.
     * @param dex The address of the first Unoswap-compatible exchange's pool.
     * @param dex2 The address of the second Unoswap-compatible exchange's pool.
     * @return returnAmount The actual amount of tokens received after the swap through both pools.
     */
    function ethUnoswap2(uint256 minReturn, Address dex, Address dex2)
        external
        payable
        returns (uint256 returnAmount);

    /**
     * @notice Swaps `amount` of the specified `token` for another token using three Unoswap-compatible exchange pools
     *         (`dex`, `dex2`, and `dex3`) sequentially, with a minimum return specified by `minReturn`.
     * @param token The address of the token to be swapped.
     * @param amount The amount of tokens to be swapped.
     * @param minReturn The minimum amount of tokens to be received after the swap.
     * @param dex The address of the first Unoswap-compatible exchange's pool.
     * @param dex2 The address of the second Unoswap-compatible exchange's pool.
     * @param dex3 The address of the third Unoswap-compatible exchange's pool.
     * @return returnAmount The actual amount of tokens received after the swap through all three pools.
     */
    function unoswap3(Address token, uint256 amount, uint256 minReturn, Address dex, Address dex2, Address dex3)
        external
        returns (uint256 returnAmount);

    /**
     * @notice Swaps ETH for another token using three Unoswap-compatible exchange pools (`dex`, `dex2`, and `dex3`) sequentially,
     *         with a minimum return specified by `minReturn`. The function is payable and requires the sender to attach ETH.
     *         It is necessary to check if it's cheaper to use _WETH_NOT_WRAP_FLAG in `dex` Address (for example: for Curve pools).
     * @param minReturn The minimum amount of tokens to be received after the swap.
     * @param dex The address of the first Unoswap-compatible exchange's pool.
     * @param dex2 The address of the second Unoswap-compatible exchange's pool.
     * @param dex3 The address of the third Unoswap-compatible exchange's pool.
     * @return returnAmount The actual amount of tokens received after the swap through all three pools.
     */
    function ethUnoswap3(uint256 minReturn, Address dex, Address dex2, Address dex3)
        external
        payable
        returns (uint256 returnAmount);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

/**
 * @title IRewardsController
 * @author Aave
 * @notice Defines the basic interface for a Rewards Controller.
 */
interface IRewardsController {
    /**
     * @dev Emitted when a new address is whitelisted as claimer of rewards on behalf of a user
     * @param user The address of the user
     * @param claimer The address of the claimer
     */
    event ClaimerSet(address indexed user, address indexed claimer);

    /**
     * @dev Emitted when rewards are claimed
     * @param user The address of the user rewards has been claimed on behalf of
     * @param reward The address of the token reward is claimed
     * @param to The address of the receiver of the rewards
     * @param claimer The address of the claimer
     * @param amount The amount of rewards claimed
     */
    event RewardsClaimed(
        address indexed user, address indexed reward, address indexed to, address claimer, uint256 amount
    );

    /**
     * @dev Emitted when a transfer strategy is installed for the reward distribution
     * @param reward The address of the token reward
     * @param transferStrategy The address of TransferStrategy contract
     */
    event TransferStrategyInstalled(address indexed reward, address indexed transferStrategy);

    /**
     * @dev Emitted when the reward oracle is updated
     * @param reward The address of the token reward
     * @param rewardOracle The address of oracle
     */
    event RewardOracleUpdated(address indexed reward, address indexed rewardOracle);

    /**
     * @dev Whitelists an address to claim the rewards on behalf of another address
     * @param user The address of the user
     * @param claimer The address of the claimer
     */
    function setClaimer(address user, address claimer) external;

    /**
     * @dev Get the price aggregator oracle address
     * @param reward The address of the reward
     * @return The price oracle of the reward
     */
    function getRewardOracle(address reward) external view returns (address);

    /**
     * @dev Returns the whitelisted claimer for a certain address (0x0 if not set)
     * @param user The address of the user
     * @return The claimer address
     */
    function getClaimer(address user) external view returns (address);

    /**
     * @dev Returns the Transfer Strategy implementation contract address being used for a reward address
     * @param reward The address of the reward
     * @return The address of the TransferStrategy contract
     */
    function getTransferStrategy(address reward) external view returns (address);

    /**
     * @dev Called by the corresponding asset on transfer hook in order to update the rewards distribution.
     * @dev The units of `totalSupply` and `userBalance` should be the same.
     * @param user The address of the user whose asset balance has changed
     * @param totalSupply The total supply of the asset prior to user balance change
     * @param userBalance The previous user balance prior to balance change
     *
     */
    function handleAction(address user, uint256 totalSupply, uint256 userBalance) external;

    /**
     * @dev Claims reward for a user to the desired address, on all the assets of the pool, accumulating the pending rewards
     * @param assets List of assets to check eligible distributions before claiming rewards
     * @param amount The amount of rewards to claim
     * @param to The address that will be receiving the rewards
     * @param reward The address of the reward token
     * @return The amount of rewards claimed
     *
     */
    function claimRewards(address[] calldata assets, uint256 amount, address to, address reward)
        external
        returns (uint256);

    /**
     * @dev Claims reward for a user on behalf, on all the assets of the pool, accumulating the pending rewards. The
     * caller must be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
     * @param assets The list of assets to check eligible distributions before claiming rewards
     * @param amount The amount of rewards to claim
     * @param user The address to check and claim rewards
     * @param to The address that will be receiving the rewards
     * @param reward The address of the reward token
     * @return The amount of rewards claimed
     *
     */
    function claimRewardsOnBehalf(address[] calldata assets, uint256 amount, address user, address to, address reward)
        external
        returns (uint256);

    /**
     * @dev Claims reward for msg.sender, on all the assets of the pool, accumulating the pending rewards
     * @param assets The list of assets to check eligible distributions before claiming rewards
     * @param amount The amount of rewards to claim
     * @param reward The address of the reward token
     * @return The amount of rewards claimed
     *
     */
    function claimRewardsToSelf(address[] calldata assets, uint256 amount, address reward) external returns (uint256);

    /**
     * @dev Claims all rewards for a user to the desired address, on all the assets of the pool, accumulating the pending rewards
     * @param assets The list of assets to check eligible distributions before claiming rewards
     * @param to The address that will be receiving the rewards
     * @return rewardsList List of addresses of the reward tokens
     * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardList"
     *
     */
    function claimAllRewards(address[] calldata assets, address to)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

    /**
     * @dev Claims all rewards for a user on behalf, on all the assets of the pool, accumulating the pending rewards. The caller must
     * be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
     * @param assets The list of assets to check eligible distributions before claiming rewards
     * @param user The address to check and claim rewards
     * @param to The address that will be receiving the rewards
     * @return rewardsList List of addresses of the reward tokens
     * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardsList"
     *
     */
    function claimAllRewardsOnBehalf(address[] calldata assets, address user, address to)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

    /**
     * @dev Claims all reward for msg.sender, on all the assets of the pool, accumulating the pending rewards
     * @param assets The list of assets to check eligible distributions before claiming rewards
     * @return rewardsList List of addresses of the reward tokens
     * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardsList"
     *
     */
    function claimAllRewardsToSelf(address[] calldata assets)
        external
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./libraries/types/DataTypes.sol";

/**
 * @title IPool
 * @author Aave
 * @notice Defines the basic interface for an Aave Pool.
 */
interface IPoolV3 {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;

    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);

    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function setUserEMode(uint8 categoryId) external;

    function getUserEMode(address user) external view returns (uint256);

    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library DataTypes {
    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        //aToken address
        address aTokenAddress;
        //stableDebtToken address
        address stableDebtTokenAddress;
        //variableDebtToken address
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the current treasury balance, scaled
        uint128 accruedToTreasury;
        //the outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        //the outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60: asset is paused
        //bit 61: borrowing in isolation mode is enabled
        //bit 62-63: reserved
        //bit 64-79: reserve factor
        //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
        //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
        //bit 152-167 liquidation protocol fee
        //bit 168-175 eMode category
        //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
        //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
        //bit 252-255 unused
        uint256 data;
    }

    struct UserConfigurationMap {
        /**
         * @dev Bitmap of the users collaterals and borrows. It is divided in pairs of bits, one pair per asset.
         * The first bit indicates if an asset is used as collateral by the user, the second whether an
         * asset is borrowed by the user.
         */
        uint256 data;
    }

    struct EModeCategory {
        // each eMode category has a custom ltv and liquidation threshold
        uint16 ltv;
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        // each eMode category may or may not have a custom oracle to override the individual assets price oracles
        address priceSource;
        string label;
    }

    enum InterestRateMode {
        NONE,
        STABLE,
        VARIABLE
    }

    struct ReserveCache {
        uint256 currScaledVariableDebt;
        uint256 nextScaledVariableDebt;
        uint256 currPrincipalStableDebt;
        uint256 currAvgStableBorrowRate;
        uint256 currTotalStableDebt;
        uint256 nextAvgStableBorrowRate;
        uint256 nextTotalStableDebt;
        uint256 currLiquidityIndex;
        uint256 nextLiquidityIndex;
        uint256 currVariableBorrowIndex;
        uint256 nextVariableBorrowIndex;
        uint256 currLiquidityRate;
        uint256 currVariableBorrowRate;
        uint256 reserveFactor;
        ReserveConfigurationMap reserveConfiguration;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        uint40 reserveLastUpdateTimestamp;
        uint40 stableDebtLastUpdateTimestamp;
    }

    struct ExecuteLiquidationCallParams {
        uint256 reservesCount;
        uint256 debtToCover;
        address collateralAsset;
        address debtAsset;
        address user;
        bool receiveAToken;
        address priceOracle;
        uint8 userEModeCategory;
        address priceOracleSentinel;
    }

    struct ExecuteSupplyParams {
        address asset;
        uint256 amount;
        address onBehalfOf;
        uint16 referralCode;
    }

    struct ExecuteBorrowParams {
        address asset;
        address user;
        address onBehalfOf;
        uint256 amount;
        InterestRateMode interestRateMode;
        uint16 referralCode;
        bool releaseUnderlying;
        uint256 maxStableRateBorrowSizePercent;
        uint256 reservesCount;
        address oracle;
        uint8 userEModeCategory;
        address priceOracleSentinel;
    }

    struct ExecuteRepayParams {
        address asset;
        uint256 amount;
        InterestRateMode interestRateMode;
        address onBehalfOf;
        bool useATokens;
    }

    struct ExecuteWithdrawParams {
        address asset;
        uint256 amount;
        address to;
        uint256 reservesCount;
        address oracle;
        uint8 userEModeCategory;
    }

    struct ExecuteSetUserEModeParams {
        uint256 reservesCount;
        address oracle;
        uint8 categoryId;
    }

    struct FinalizeTransferParams {
        address asset;
        address from;
        address to;
        uint256 amount;
        uint256 balanceFromBefore;
        uint256 balanceToBefore;
        uint256 reservesCount;
        address oracle;
        uint8 fromEModeCategory;
    }

    struct FlashloanParams {
        address receiverAddress;
        address[] assets;
        uint256[] amounts;
        uint256[] interestRateModes;
        address onBehalfOf;
        bytes params;
        uint16 referralCode;
        uint256 flashLoanPremiumToProtocol;
        uint256 flashLoanPremiumTotal;
        uint256 maxStableRateBorrowSizePercent;
        uint256 reservesCount;
        address addressesProvider;
        uint8 userEModeCategory;
        bool isAuthorizedFlashBorrower;
    }

    struct FlashloanSimpleParams {
        address receiverAddress;
        address asset;
        uint256 amount;
        bytes params;
        uint16 referralCode;
        uint256 flashLoanPremiumToProtocol;
        uint256 flashLoanPremiumTotal;
    }

    struct FlashLoanRepaymentParams {
        uint256 amount;
        uint256 totalPremium;
        uint256 flashLoanPremiumToProtocol;
        address asset;
        address receiverAddress;
        uint16 referralCode;
    }

    struct CalculateUserAccountDataParams {
        UserConfigurationMap userConfig;
        uint256 reservesCount;
        address user;
        address oracle;
        uint8 userEModeCategory;
    }

    struct ValidateBorrowParams {
        ReserveCache reserveCache;
        UserConfigurationMap userConfig;
        address asset;
        address userAddress;
        uint256 amount;
        InterestRateMode interestRateMode;
        uint256 maxStableLoanPercent;
        uint256 reservesCount;
        address oracle;
        uint8 userEModeCategory;
        address priceOracleSentinel;
        bool isolationModeActive;
        address isolationModeCollateralAddress;
        uint256 isolationModeDebtCeiling;
    }

    struct ValidateLiquidationCallParams {
        ReserveCache debtReserveCache;
        uint256 totalDebt;
        uint256 healthFactor;
        address priceOracleSentinel;
    }

    struct CalculateInterestRatesParams {
        uint256 unbacked;
        uint256 liquidityAdded;
        uint256 liquidityTaken;
        uint256 totalStableDebt;
        uint256 totalVariableDebt;
        uint256 averageStableBorrowRate;
        uint256 reserveFactor;
        address reserve;
        address aToken;
    }

    struct InitReserveParams {
        address asset;
        address aTokenAddress;
        address stableDebtAddress;
        address variableDebtAddress;
        address interestRateStrategyAddress;
        uint16 reservesCount;
        uint16 maxNumberReserves;
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

interface IFlashloanHelper {
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _params)
        external
        returns (bool);

    function addToWhitelist(address _account) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

interface IStrategy {
    function getNetAssets() external returns (uint256);

    function onTransferIn(address token, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

interface IVault {
    event UpdateMarketCapacity(uint256 oldCapacityLimit, uint256 newCapacityLimit);
    event UpdateManagementFee(uint256 oldManagementFee, uint256 newManagementFee);
    event UpdateManagementFeeClaimPeriod(uint256 oldManagementFeeClaimPeriod, uint256 newManagementFeeClaimPeriod);
    event UpdateMaxPriceUpdatePeriod(uint256 oldMaxPriceUpdatePeriod, uint256 newMaxPriceUpdatePeriod);
    event UpdateRevenueRate(uint256 oldRevenueRate, uint256 newRevenueRate);
    event UpdateExitFeeRate(uint256 oldExitFeeRate, uint256 newExitFeeRate);
    event UpdateRebalancer(address oldRebalancer, address newRebalancer);
    event UpdateUnbackedMinter(address oldUnbackedMinter, address newUnbackedMinter);
    event UpdateFeeReceiver(address oldFeeReceiver, address newFeeReceiver);
    event UpdateRedeemOperator(address oldRedeemOperator, address newRedeemOperator);
    event UpdateExchangePrice(uint256 newExchangePrice, uint256 newRevenue);
    event TransferToStrategy(address token, uint256 amount, uint256 strategyIndex);
    event OptionalDeposit(address caller, address token, uint256 assets, address receiver, address referral);
    event OptionalRedeem(address token, uint256 shares, address receiver, address owner);
    event RequestRedeem(address user, uint256 shares, address token);
    event CollectManagementFee(uint256 assets);
    event CollectRevenue(uint256 revenue);
    event AddToken(address token);
    event RemoveToken(address token);

    /**
     * @dev Parameters for initializing the vault contract.
     * @param underlyingToken The address of the underlying token for the vault.
     * @param name The name of the vault token.
     * @param symbol The symbol of the vault token.
     * @param marketCapacity The maximum market capacity of the vault.
     * @param managementFeeRate The rate of the management fee.
     * @param managementFeeClaimPeriod The period for claiming the management fee.
     * @param maxPriceUpdatePeriod The maximum allowed price update period.
     * @param revenueRate The rate of the revenue fee.
     * @param exitFeeRate The rate of the exit fee.
     * @param admin The address of the administrator.
     * @param rebalancer The address responsible for rebalancing the vault.
     * @param feeReceiver The address that will receive the fees.
     * @param redeemOperator The address of the operator responsible for redeeming shares
     */
    struct VaultParams {
        address underlyingToken;
        string name;
        string symbol;
        uint256 marketCapacity;
        uint256 managementFeeRate;
        uint256 managementFeeClaimPeriod;
        uint256 maxPriceUpdatePeriod;
        uint256 revenueRate;
        uint256 exitFeeRate;
        address admin;
        address rebalancer;
        address feeReceiver;
        address redeemOperator;
    }

    /**
     * @dev
     * @param exchangePrice The exchange rate used during user deposit and withdrawal operations.
     * @param revenueExchangePrice The exchange rate used when calculating performance fees,Performance fees will be recorded when the real exchange rate exceeds this rate.
     * @param revenue Collected revenue, stored in pegged ETH.
     * @param lastClaimMngFeeTime The last time the management fees were charged.
     * @param lastUpdatePriceTime The last time the exchange price was updated.
     */
    struct VaultState {
        uint256 exchangePrice;
        uint256 revenueExchangePrice;
        uint256 revenue;
        uint256 lastClaimMngFeeTime;
        uint256 lastUpdatePriceTime;
    }

    function optionalRedeem(address _token, uint256 _shares, uint256 _cutPercentage, address _receiver, address _owner)
        external
        returns (uint256 assetsAfterFee_);

    function getWithdrawFee(uint256 _amount) external view returns (uint256 amount_);

    function exchangePrice() external view returns (uint256);

    function revenueExchangePrice() external view returns (uint256);

    function revenue() external view returns (uint256);

    function lastExchangePrice() external view returns (uint256);

    function getPrecison() external view returns (uint256);

    function burnUnbacked(uint256 _amount) external;

    function mintUnbacked(uint256 _amount) external;

    function optionalDeposit(address _token, uint256 _assets, address _receiver, address _referral)
        external
        payable
        returns (uint256 shares_);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IstETH is IERC20 {
    function submit(address _referral) external payable returns (uint256);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IWithdrawalNft {
    /// @notice output format struct for `_getWithdrawalStatus()` method
    struct WithdrawalRequestStatus {
        /// @notice stETH token amount that was locked on withdrawal queue for this request
        uint256 amountOfStETH;
        /// @notice amount of stETH shares locked on withdrawal queue for this request
        uint256 amountOfShares;
        /// @notice address that can claim or transfer this request
        address owner;
        /// @notice timestamp of when the request was created, in seconds
        uint256 timestamp;
        /// @notice true, if request is finalized
        bool isFinalized;
        /// @notice true, if request is claimed. Request is claimable if (isFinalized && !isClaimed)
        bool isClaimed;
    }

    function requestWithdrawals(uint256[] calldata _amounts, address _owner)
        external
        returns (uint256[] memory requestIds);

    function claimWithdrawal(uint256 _requestId) external;

    function getWithdrawalStatus(uint256[] calldata _requestIds)
        external
        view
        returns (WithdrawalRequestStatus[] memory statuses);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWstETH is IERC20 {
    function wrap(uint256 _stETHAmount) external returns (uint256);

    function unwrap(uint256 _stETHAmount) external returns (uint256);

    function tokensPerStEth() external view returns (uint256);

    function stEthPerToken() external view returns (uint256);

    function getStETHByWstETH(uint256 _stETHAmount) external view returns (uint256);

    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

abstract contract Constants {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../interfaces/weth/IWETH.sol";
import "../../interfaces/lido/IstETH.sol";
import "../../interfaces/lido/IWithdrawalNft.sol";
import "./Constants.sol";
import "../libraries/Errors.sol";

abstract contract MultiETH is IERC721Receiver, Constants {
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e18;

    IWithdrawalNft internal constant lidoQueue = IWithdrawalNft(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);
    uint256 public lidoUnstakeId;

    event ConvertToken(address srcToken, address toToken, uint256 amount);
    event ClaimUnstake(address srcToken);

    function _convertToken(address _srcToken, address _toToken, uint256 _amount) internal {
        if (_srcToken == ETH) {
            if (_toToken == WETH) {
                IWETH(WETH).deposit{value: _amount}();
            } else if (_toToken == STETH) {
                IstETH(STETH).submit{value: _amount}(address(0));
            } else {
                revert Errors.InvalidAsset();
            }
        } else if (_srcToken == WETH) {
            IWETH(WETH).withdraw(_amount);
            if (_toToken == ETH) {
                // do nothing
            } else if (_toToken == STETH) {
                IstETH(STETH).submit{value: _amount}(address(0));
            } else {
                revert Errors.InvalidAsset();
            }
        } else if (_srcToken == STETH) {
            if (_toToken == ETH) {
                if (lidoUnstakeId != 0) revert Errors.IncorrectState();
                uint256[] memory amounts_ = new uint256[](1);
                amounts_[0] = _amount;
                IERC20(STETH).safeIncreaseAllowance(address(lidoQueue), _amount);
                uint256[] memory newLidoUnstakeIds_ = lidoQueue.requestWithdrawals(amounts_, address(this));
                lidoUnstakeId = newLidoUnstakeIds_[0];
            } else {
                revert Errors.InvalidAsset();
            }
        } else {
            revert Errors.InvalidAsset();
        }

        emit ConvertToken(_srcToken, _toToken, _amount);
    }

    function _claimUnstake(address _srcToken) internal {
        if (_srcToken == STETH) {
            if (lidoUnstakeId == 0) revert Errors.IncorrectState();
            lidoQueue.claimWithdrawal(lidoUnstakeId);
            lidoUnstakeId = 0;
        } else {
            revert Errors.IncorrectState();
        }

        emit ClaimUnstake(_srcToken);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // to = ETH
    function getUnstakingAmount(address _srcToken) public view returns (uint256) {
        if (_srcToken == STETH) {
            if (lidoUnstakeId == 0) return 0;
            uint256[] memory requestIds_ = new uint256[](1);
            requestIds_[0] = lidoUnstakeId;
            IWithdrawalNft.WithdrawalRequestStatus[] memory statuses_ = lidoQueue.getWithdrawalStatus(requestIds_);
            return statuses_[0].amountOfStETH;
        } else {
            revert Errors.InvalidAsset();
        }
    }

    function getTotalETHBalance() public view returns (uint256) {
        uint256 ethBalance_ = address(this).balance;
        uint256 wethBalance_ = IERC20(WETH).balanceOf(address(this));
        uint256 stethBalance_ = IERC20(STETH).balanceOf(address(this));
        uint256 unstaking_ = getUnstakingAmount(STETH);

        // Assuming 1:1 conversion rate for simplicity
        return ethBalance_ + wethBalance_ + stethBalance_ + unstaking_;
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

library Errors {
    // Revert Errors:
    error CallerNotOperator(); // 0xa5523ee5
    error CallerNotRebalancer(); // 0xbd72e291
    error CallerNotVault(); // 0xedd7338f
    error CallerNotMinter(); // 0x5eee367a
    error ExitFeeRateTooHigh(); // 0xf4d1caab
    error FlashloanInProgress(); // 0x772ac4e8
    error IncorrectState(); // 0x508c9390
    error InfoExpired(); // 0x4ddf4a65
    error InvalidAccount(); // 0x6d187b28
    error InvalidAdapter(); // 0xfbf66df1
    error InvalidAdmin(); // 0xb5eba9f0
    error InvalidAsset(); // 0xc891add2
    error InvalidCaller(); // 0x48f5c3ed
    error InvalidClaimTime(); // 0x1221b97b
    error InvalidFeeReceiver(); // 0xd200485c
    error InvalidFlashloanCall(); // 0xd2208d52
    error InvalidFlashloanHelper(); // 0x8690f016
    error InvalidFlashloanProvider(); // 0xb6b48551
    error InvalidGasLimit(); // 0x98bdb2e0
    error InvalidInitiator(); // 0xbfda1f28
    error InvalidLength(); // 0x947d5a84
    error InvalidLimit(); // 0xe55fb509
    error InvalidManagementFeeClaimPeriod(); // 0x4022e4f6
    error InvalidManagementFeeRate(); // 0x09aa66eb
    error InvalidMarketCapacity(); // 0xc9034604
    error InvalidNetAssets(); // 0x6da79d69
    error InvalidNewOperator(); // 0xba0cdec5
    error InvalidOperator(); // 0xccea9e6f
    error InvalidRebalancer(); // 0xff288a8e
    error InvalidRedeemOperator(); // 0xd214a597
    error InvalidSafeProtocolRatio(); // 0x7c6b23d6
    error InvalidShares(); // 0x6edcc523
    error InvalidTarget(); // 0x82d5d76a
    error InvalidToken(); // 0xc1ab6dc1
    error InvalidTokenId(); // 0x3f6cc768
    error InvalidUnderlyingToken(); // 0x2fb86f96
    error InvalidVault(); // 0xd03a6320
    error InvalidWithdrawalUser(); // 0x36c17319
    error ManagementFeeRateTooHigh(); // 0x09aa66eb
    error ManagementFeeClaimPeriodTooShort(); // 0x4022e4f6
    error MarketCapacityTooLow(); // 0xc9034604
    error NotSupportedYet(); // 0xfb89ba2a
    error PriceNotUpdated(); // 0x1f4bcb2b
    error PriceUpdatePeriodTooLong(); // 0xe88d3ecb
    error RatioOutOfRange(); // 0x9179cbfa
    error RevenueFeeRateTooHigh(); // 0x0674143f
    error UnSupportedOperation(); // 0xe9ec8129
    error UnsupportedToken(); // 0x6a172882
    error WithdrawZero(); // 0x7ea773a9

    // for 1inch swap
    error OneInchInvalidReceiver(); // 0xd540519e
    error OneInchInvalidToken(); // 0x8e7ad912
    error OneInchInvalidInputAmount(); // 0x672b500f
    error OneInchInvalidFunctionSignature(); // 0x247f51aa
    error OneInchUnexpectedSpentAmount(); // 0x295ada05
    error OneInchUnexpectedReturnAmount(); // 0x05e64ca8
    error OneInchNotSupported(); // 0x04b2de78
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../../interfaces/flashloanHelper/IFlashloanHelper.sol";
import "../../../interfaces/lido/IWstETH.sol";
import "../../../interfaces/IVault.sol";
import "../../../interfaces/aave/v3/IPoolV3.sol";
import "../../../interfaces/aave/IAaveOracle.sol";
import "../../../interfaces/aave/IRewardsController.sol";
import "../../../interfaces/IStrategy.sol";
import "../../libraries/Errors.sol";
import "../../swap/OneInchCallerV6.sol";
import "../../common/MultiETH.sol";

/**
 * @title StrategyAAVEV3LIDO contract
 * @author Naturelab
 * @dev This contract is the actual address of the strategy pool, which
 * manages some assets in aaveV3.
 */
contract StrategyAAVEV3LIDO is IStrategy, MultiETH, OneInchCallerV6, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    // The version of the contract
    string public constant VERSION = "1.0";

    // The maximum allowable ratio for the protocol, set to 93%
    uint256 public constant MAX_PROTOCOL_RATIO = 0.93e18;

    // The address of the AAVE v3 aToken for wstETH
    address internal constant A_WSTETH_AAVEV3 = 0xC035a7cf15375cE2706766804551791aD035E0C2;

    // The address of the AAVE v3 variable debt token for WETH
    address internal constant D_WETH_AAVEV3 = 0x91b7d78BF92db564221f6B5AeE744D1727d1Dd1e;

    address internal constant A_WETH_AAVEV3 = 0xfA1fDbBD71B0aA16162D76914d69cD8CB3Ef92da;

    // The address of the AAVE v3 Oracle contract
    IAaveOracle internal constant ORACLE_AAVEV3 = IAaveOracle(0xE3C061981870C0C7b1f3C4F4bB36B95f1F260BE6);

    // The address of the AAVE v3 Pool contract
    IPoolV3 internal constant POOL_AAVEV3 = IPoolV3(0x4e033931ad43597d96D6bcc25c280717730B58B1);

    IRewardsController internal constant rewardsController =
        IRewardsController(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb);

    // The address of the Vault contract that manages user shares
    address public vault;

    // The intermediary contract for executing flashloan operations
    address public flashloanHelper;

    // The address used to prevent flashloan re-entry attacks
    address public executor;

    // The address of the position adjustment manager
    address public rebalancer;

    // The safe collateral rate for the protocol
    uint256 public safeProtocolRatio;

    event UpdateFlashloanHelper(address oldFlashloanHelper, address newFlashloanHelper);
    event UpdateRebalancer(address oldRebalancer, address newRebalancer);
    event UpdateSafeProtocolRatio(uint256 oldSafeProtocolRatio, uint256 newSafeProtocolRatio);
    event OnTransferIn(address token, uint256 amount);
    event TransferToVault(address token, uint256 amount);
    event Wrap(uint256 stEthAmount, uint256 wstEthAmount);
    event Unwrap(uint256 wstEthAmount, uint256 stEthAmount);
    event Leverage(uint256 deposit, uint256 debtAmount, bytes swapData, uint256 flashloanSelector);
    event Deleverage(uint256 deleverageAmount, uint256 withdrawAmount, bytes swapData, uint256 flashloanSelector);
    event Repay(uint256 amount);

    /**
     * @dev Ensure that this method is only called by the Vault contract.
     */
    modifier onlyVault() {
        if (msg.sender != vault) revert Errors.CallerNotVault();
        _;
    }

    /**
     * @dev  Ensure that this method is only called by authorized portfolio managers.
     */
    modifier onlyRebalancer() {
        if (msg.sender != rebalancer) revert Errors.CallerNotRebalancer();
        _;
    }

    /**
     * @dev Initialize the strategy with given parameters.
     * @param _initBytes Initialization data
     */
    function initialize(bytes calldata _initBytes) external initializer {
        (uint256 safeProtocolRatio_, address admin_, address flashloanHelper_, address rebalancer_) =
            abi.decode(_initBytes, (uint256, address, address, address));
        if (admin_ == address(0)) revert Errors.InvalidAdmin();
        if (flashloanHelper_ == address(0)) revert Errors.InvalidFlashloanHelper();
        if (safeProtocolRatio_ > MAX_PROTOCOL_RATIO) revert Errors.InvalidSafeProtocolRatio();
        if (rebalancer_ == address(0)) revert Errors.InvalidRebalancer();
        __Ownable_init(admin_);
        flashloanHelper = flashloanHelper_;
        safeProtocolRatio = safeProtocolRatio_;
        rebalancer = rebalancer_;
        vault = msg.sender;
        enterProtocol();
    }

    /**
     * @dev Update the address of the intermediary contract used for flashloan operations.
     * @param _newFlashloanHelper The new contract address.
     */
    function updateFlashloanHelper(address _newFlashloanHelper) external onlyOwner {
        if (_newFlashloanHelper == address(0)) revert Errors.InvalidFlashloanHelper();
        emit UpdateFlashloanHelper(flashloanHelper, _newFlashloanHelper);
        flashloanHelper = _newFlashloanHelper;
    }

    /**
     * @dev Add a new address to the position adjustment whitelist.
     * @param _newRebalancer The new address to be added.
     */
    function updateRebalancer(address _newRebalancer) external onlyOwner {
        if (_newRebalancer == address(0)) revert Errors.InvalidRebalancer();
        emit UpdateRebalancer(rebalancer, _newRebalancer);
        rebalancer = _newRebalancer;
    }

    function updateSafeProtocolRatio(uint256 _newRatio) external onlyOwner {
        if (_newRatio > MAX_PROTOCOL_RATIO) revert Errors.InvalidSafeProtocolRatio();
        emit UpdateSafeProtocolRatio(safeProtocolRatio, _newRatio);
        safeProtocolRatio = _newRatio;
    }

    function convertToken(address _srcToken, address _toToken, uint256 _amount) external onlyRebalancer {
        _convertToken(_srcToken, _toToken, _amount);
    }

    function claimUnstake(address _srcToken) external onlyRebalancer {
        _claimUnstake(_srcToken);
    }

    /**
     * @dev Transfers funds from the vault contract to this contract.
     * This function is called by the vault to move tokens into this contract.
     * It uses the `safeTransferFrom` function from the SafeERC20 library to ensure the transfer is successful.
     * @param _token The address of the token to be transferred.
     * @param _amount The amount of tokens to be transferred.
     * @return A boolean indicating whether the transfer was successful.
     */
    function onTransferIn(address _token, uint256 _amount) external onlyVault returns (bool) {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit OnTransferIn(_token, _amount);
        return true;
    }

    /**
     * @dev Transfer tokens to the Vault.
     * @param _token The address of the token to transfer.
     * @param _amount The amount of tokens to transfer.
     */
    function transferToVault(address _token, uint256 _amount) external onlyRebalancer {
        IERC20(_token).safeTransfer(vault, _amount);
        emit TransferToVault(_token, _amount);
    }

    /**
     * @dev Wrap STETH to WSTETH.
     */
    function wrap() external onlyRebalancer {
        uint256 stEthAmount_ = IERC20(STETH).balanceOf(address(this));
        IERC20(STETH).safeIncreaseAllowance(WSTETH, stEthAmount_);
        uint256 wstETHAmount_ = IWstETH(WSTETH).wrap(stEthAmount_);

        emit Wrap(stEthAmount_, wstETHAmount_);
    }

    /**
     * @dev Unwrap WSTETH to STETH.
     */
    function unwrap() external onlyRebalancer {
        uint256 wstETHAmount_ = IERC20(WSTETH).balanceOf(address(this));
        uint256 stEthAmount_ = IWstETH(WSTETH).unwrap(wstETHAmount_);

        emit Unwrap(wstETHAmount_, stEthAmount_);
    }

    function repay(uint256 _amount) external onlyRebalancer {
        executeRepay(WETH, _amount);

        emit Repay(_amount);
    }

    /**
     * @dev Execute a leverage operation.
     * @param _deposit The amount to deposit.
     * @param _leverageAmount The amount to leverage.
     * @param _swapData The swap data.
     * @param _swapGetMin The minimum amount to get from the swap.
     * @param _flashloanSelector The flashloan selector.
     */
    function leverage(
        uint256 _deposit,
        uint256 _leverageAmount,
        bytes calldata _swapData,
        uint256 _swapGetMin,
        uint256 _flashloanSelector
    ) external onlyRebalancer {
        executeDeposit(STETH, _deposit);
        checkProtocolRatio();
        if (_leverageAmount == 0) return;
        uint256 availableBorrowsETH_ = getAvailableBorrowsETH();
        if (_leverageAmount < availableBorrowsETH_) {
            leverageSelf(_leverageAmount, _swapData, _swapGetMin);
        } else {
            executeFlashLoan(true, _leverageAmount, _swapData, _swapGetMin, _flashloanSelector);
        }
        checkProtocolRatio();

        emit Leverage(_deposit, _leverageAmount, _swapData, _flashloanSelector);
    }

    /**
     * @dev Execute a deleverage operation.
     * @param _withdraw The amount to withdraw.
     * @param _deleverageAmount The amount to deleverage.
     * @param _swapData The swap data.
     * @param _swapGetMin The minimum amount to get from the swap.
     * @param _flashloanSelector The flashloan selector.
     */
    function deleverage(
        uint256 _withdraw,
        uint256 _deleverageAmount,
        bytes calldata _swapData,
        uint256 _swapGetMin,
        uint256 _flashloanSelector
    ) external onlyRebalancer {
        if (_deleverageAmount > 0) {
            uint256 availableWithdrawWeETH = getAvailableWithdrawsStETH();
            if (_deleverageAmount < availableWithdrawWeETH) deleverageSelf(_deleverageAmount, _swapData, _swapGetMin);
            else executeFlashLoan(false, _deleverageAmount, _swapData, _swapGetMin, _flashloanSelector);
        }
        executeWithdraw(STETH, _withdraw);
        checkProtocolRatio();
        emit Deleverage(_deleverageAmount, _withdraw, _swapData, _flashloanSelector);
    }

    /**
     * @dev Callback function for flashloan operations.
     * @param _initiator The address of the initiator.
     * @param _token The address of the token.
     * @param _amount The amount of tokens.
     * @param _fee The fee for the flashloan.
     * @param _params The parameters for the flashloan.
     * @return A bytes32 value indicating success.
     */
    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _params)
        external
        returns (bytes32)
    {
        if (msg.sender != flashloanHelper || executor == address(0) || _initiator != address(this)) {
            revert Errors.InvalidFlashloanCall();
        }
        (bool isLeverage_, bytes memory swapData_, uint256 swapGetMin_) = abi.decode(_params, (bool, bytes, uint256));
        isLeverage_
            ? leverageCallback(_amount, _fee, swapData_, swapGetMin_)
            : deleverageCallback(_amount, _fee, swapData_, swapGetMin_);
        IERC20(_token).safeIncreaseAllowance(msg.sender, _amount + _fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function claimRewards(address[] calldata _assets) external {
        rewardsController.claimAllRewards(_assets, address(this));
    }

    /**
     * @dev Get the available borrows in ETH.
     * @return availableBorrowsETH_ The amount of available borrows in ETH.
     */
    function getAvailableBorrowsETH() public view returns (uint256 availableBorrowsETH_) {
        (,, uint256 availableBorrowsInUsd_,,,) = POOL_AAVEV3.getUserAccountData(address(this));
        if (availableBorrowsInUsd_ > 0) {
            uint256 WEthPrice_ = ORACLE_AAVEV3.getAssetPrice(WETH);
            availableBorrowsETH_ = availableBorrowsInUsd_ * PRECISION / WEthPrice_;
        }
    }

    /**
     * @dev Get the available withdrawable amount in stETH.
     * @return maxWithdrawsStETH_ The maximum amount of stETH that can be withdrawn.
     */
    function getAvailableWithdrawsStETH() public view returns (uint256 maxWithdrawsStETH_) {
        (uint256 colInUsd_, uint256 debtInUsd_,,, uint256 ltv_,) = POOL_AAVEV3.getUserAccountData(address(this));
        if (colInUsd_ > 0) {
            uint256 colMin_ = debtInUsd_ * 1e4 / ltv_;
            uint256 maxWithdrawsInUsd_ = colInUsd_ > colMin_ ? colInUsd_ - colMin_ : 0;
            uint256 WstEthPrice_ = ORACLE_AAVEV3.getAssetPrice(WSTETH);
            uint256 maxWithdrawsWstETH_ = maxWithdrawsInUsd_ * PRECISION / WstEthPrice_;
            maxWithdrawsStETH_ = IWstETH(WSTETH).getStETHByWstETH(maxWithdrawsWstETH_);
        }
    }

    function getRatio() public view returns (uint256 ratio_) {
        (uint256 stEthAmount_, uint256 debtEthAmount_) = getProtocolAccountData();
        ratio_ = stEthAmount_ == 0 ? 0 : debtEthAmount_ * PRECISION / stEthAmount_;
    }

    /**
     * @dev Get the collateral ratio and its status.
     * @return collateralRatio_ The collateral ratio.
     * @return isOK_ Boolean indicating whether the ratio is within safe limits.
     */
    function getCollateralRatio() public view returns (uint256 collateralRatio_, bool isOK_) {
        (uint256 totalCollateralBase_, uint256 totalDebtBase_,,,,) = POOL_AAVEV3.getUserAccountData(address(this));
        collateralRatio_ = totalCollateralBase_ == 0 ? 0 : totalDebtBase_ * PRECISION / totalCollateralBase_;
        isOK_ = safeProtocolRatio > collateralRatio_;
    }

    /**
     * @dev Get the amount for leverage or deleverage operation.
     * @param _isDepositOrWithdraw Boolean indicating whether the operation is a deposit or withdrawal.
     * @param _depositOrWithdraw The amount to deposit or withdraw.
     * @return isLeverage_ Boolean indicating whether the operation is leverage.
     * @return loanAmount_ The loan amount.
     */
    function getLeverageAmount(bool _isDepositOrWithdraw, uint256 _depositOrWithdraw)
        public
        view
        returns (bool isLeverage_, uint256 loanAmount_)
    {
        uint256 wstPrice_ = ORACLE_AAVEV3.getAssetPrice(WSTETH);
        uint256 ethPrice_ = ORACLE_AAVEV3.getAssetPrice(WETH);
        uint256 totalCollateralETH_ = IERC20(A_WSTETH_AAVEV3).balanceOf(address(this)) * wstPrice_ / ethPrice_;
        uint256 totalDebtETH_ = IERC20(D_WETH_AAVEV3).balanceOf(address(this));
        uint256 depositOrWithdrawInETH_ = IWstETH(WSTETH).getWstETHByStETH(_depositOrWithdraw) * wstPrice_ / ethPrice_;

        totalCollateralETH_ = _isDepositOrWithdraw
            ? (totalCollateralETH_ + depositOrWithdrawInETH_)
            : (totalCollateralETH_ - depositOrWithdrawInETH_);
        if (totalCollateralETH_ != 0) {
            uint256 ratio = totalCollateralETH_ == 0 ? 0 : totalDebtETH_ * PRECISION / totalCollateralETH_;
            isLeverage_ = ratio < safeProtocolRatio ? true : false;
            if (isLeverage_) {
                loanAmount_ = (safeProtocolRatio * totalCollateralETH_ - totalDebtETH_ * PRECISION)
                    / (PRECISION - safeProtocolRatio);
            } else {
                loanAmount_ = (totalDebtETH_ * PRECISION - safeProtocolRatio * totalCollateralETH_)
                    / (PRECISION - safeProtocolRatio);
            }
        }
    }

    /**
     * @dev Get the protocol account data.
     * @return stEthAmount_ The amount of supplied wstETH in stETH.
     * @return debtEthAmount_ The amount of debt in ETH.
     */
    function getProtocolAccountData() public view returns (uint256 stEthAmount_, uint256 debtEthAmount_) {
        uint256 wstEthAmount_ = IERC20(A_WSTETH_AAVEV3).balanceOf(address(this));
        stEthAmount_ = IWstETH(WSTETH).getStETHByWstETH(wstEthAmount_);
        debtEthAmount_ = IERC20(D_WETH_AAVEV3).balanceOf(address(this));
    }

    /**
     * @dev Get the amount of net assets in the protocol.
     * @return net_ The amount of net assets.
     */
    function getProtocolNetAssets() public view returns (uint256 net_) {
        (uint256 stEthAmount_, uint256 debtEthAmount_) = getProtocolAccountData();
        net_ = stEthAmount_ - debtEthAmount_;
    }

    /**
     * @dev Get the amount of assets in all lending protocols involved in this contract for the strategy pool.
     * @return netAssets The total amount of net assets.
     */
    function getNetAssets() public view returns (uint256) {
        uint256 wstETHAmount_ = IWstETH(WSTETH).balanceOf(address(this));
        return getProtocolNetAssets() + IWstETH(WSTETH).getStETHByWstETH(wstETHAmount_) + getTotalETHBalance();
    }

    /**
     * @dev Execute a self-leverage operation.
     * @param _loanAmount The amount to loan.
     * @param _swapData The swap data.
     * @param _swapGetMin The minimum amount to get from the swap.
     */
    function leverageSelf(uint256 _loanAmount, bytes calldata _swapData, uint256 _swapGetMin) internal {
        executeBorrow(WETH, _loanAmount);
        IERC20(WETH).safeIncreaseAllowance(ONEINCH_ROUTER, _loanAmount);
        (uint256 return_,) = executeSwap(_loanAmount, WETH, STETH, _swapData, _swapGetMin);
        executeDeposit(STETH, return_);
    }

    /**
     * @dev Execute a self-deleverage operation.
     * @param _deleverageAmount The amount to deleverage.
     * @param _swapData The swap data.
     * @param _swapGetMin The minimum amount to get from the swap.
     */
    function deleverageSelf(uint256 _deleverageAmount, bytes calldata _swapData, uint256 _swapGetMin) internal {
        executeWithdraw(STETH, _deleverageAmount);
        IERC20(STETH).safeIncreaseAllowance(ONEINCH_ROUTER, _deleverageAmount);
        (uint256 return_,) = executeSwap(_deleverageAmount, STETH, WETH, _swapData, _swapGetMin);
        executeRepay(WETH, return_);
    }

    /**
     * @dev Execute a flashloan operation.
     * @param _isLeverage Boolean indicating whether the operation is leverage.
     * @param _loanAmount The amount to loan.
     * @param _swapData The swap data.
     * @param _swapGetMin The minimum amount to get from the swap.
     * @param _flashloanSelector The flashloan selector.
     */
    function executeFlashLoan(
        bool _isLeverage,
        uint256 _loanAmount,
        bytes calldata _swapData,
        uint256 _swapGetMin,
        uint256 _flashloanSelector
    ) internal {
        bytes memory params_ = abi.encode(_isLeverage, _swapData, _swapGetMin);
        bytes memory dataBytes_ = abi.encode(_flashloanSelector, this.onFlashLoan.selector, params_);

        if (executor != address(0)) revert Errors.FlashloanInProgress();
        executor = msg.sender;
        IFlashloanHelper(flashloanHelper).flashLoan(IERC3156FlashBorrower(address(this)), WETH, _loanAmount, dataBytes_);
        executor = address(0);
    }

    /**
     * @dev Execute a deposit operation in the AAVE protocol.
     * @param _asset The address of the asset to deposit.
     * @param _amount The amount of the asset to deposit.
     */
    function executeDeposit(address _asset, uint256 _amount) internal {
        if (_asset != STETH) revert Errors.InvalidAsset();
        if (_amount == 0) return;
        uint256 wst_ = IWstETH(WSTETH).wrap(_amount);
        POOL_AAVEV3.supply(WSTETH, wst_, address(this), 0);
    }

    /**
     * @dev Execute a withdrawal operation in the AAVE protocol.
     * @param _asset The address of the asset to withdraw.
     * @param _amount The amount of the asset to withdraw.
     */
    function executeWithdraw(address _asset, uint256 _amount) internal {
        if (_asset != STETH) revert Errors.InvalidAsset();
        if (_amount == 0) return;
        /// @dev If you don't add 1wei, it will return 1wei less steth than expected.
        uint256 withdraw_ = IWstETH(WSTETH).getWstETHByStETH(_amount + 1);
        POOL_AAVEV3.withdraw(WSTETH, withdraw_, address(this));
        IWstETH(WSTETH).unwrap(withdraw_);
    }

    /**
     * @dev Execute a borrow operation in the AAVE protocol.
     * @param _asset The address of the asset to borrow.
     * @param _amount The amount of the asset to borrow.
     */
    function executeBorrow(address _asset, uint256 _amount) internal {
        if (_asset != WETH) revert Errors.InvalidAsset();
        if (_amount == 0) return;
        POOL_AAVEV3.borrow(_asset, _amount, 2, 0, address(this));
    }

    /**
     * @dev Execute a repay operation in the AAVE protocol.
     * @param _asset The address of the asset to repay.
     * @param _amount The amount of the asset to repay.
     */
    function executeRepay(address _asset, uint256 _amount) internal {
        if (_asset != WETH) revert Errors.InvalidAsset();
        if (_amount == 0) return;
        POOL_AAVEV3.repay(_asset, _amount, 2, address(this));
    }

    /**
     * @dev Enter the AAVE protocol by approving tokens.
     */
    function enterProtocol() internal {
        IERC20(WETH).safeIncreaseAllowance(address(POOL_AAVEV3), type(uint256).max);
        IERC20(WSTETH).safeIncreaseAllowance(address(POOL_AAVEV3), type(uint256).max);
        IERC20(STETH).safeIncreaseAllowance(WSTETH, type(uint256).max);
        POOL_AAVEV3.setUserEMode(1);
    }

    /**
     * @dev Check the health status of a specific protocol after an operation
     * to prevent the strategy pool from being in a risky position.
     */
    function checkProtocolRatio() internal view {
        (, bool isOK_) = getCollateralRatio();
        if (!isOK_) revert Errors.RatioOutOfRange();
    }

    /**
     * @dev Callback function for leverage flashloan.
     * @param _loanAmount The loan amount.
     * @param _fee The fee for the flashloan.
     * @param _swapData The swap data.
     * @param _swapGetMin The minimum amount to get from the swap.
     */
    function leverageCallback(uint256 _loanAmount, uint256 _fee, bytes memory _swapData, uint256 _swapGetMin)
        internal
    {
        IERC20(WETH).safeIncreaseAllowance(ONEINCH_ROUTER, _loanAmount);
        (uint256 return_,) = executeSwap(_loanAmount, WETH, STETH, _swapData, _swapGetMin);
        executeDeposit(STETH, return_);
        executeBorrow(WETH, _loanAmount + _fee);
    }

    /**
     * @dev Callback function for deleverage flashloan.
     * @param _loanAmount The loan amount.
     * @param _fee The fee for the flashloan.
     * @param _swapData The swap data.
     * @param _swapGetMin The minimum amount to get from the swap.
     */
    function deleverageCallback(uint256 _loanAmount, uint256 _fee, bytes memory _swapData, uint256 _swapGetMin)
        internal
    {
        executeRepay(WETH, _loanAmount);
        executeWithdraw(STETH, _loanAmount);
        IERC20(STETH).safeIncreaseAllowance(ONEINCH_ROUTER, _loanAmount);
        (uint256 return_,) = executeSwap(_loanAmount, STETH, WETH, _swapData, _swapGetMin);
        uint256 repayFlashloan_ = _loanAmount + _fee;
        uint256 borrowAgain_ = repayFlashloan_ - return_;
        executeBorrow(WETH, borrowAgain_);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../interfaces/1inch/AddressLib.sol";
import "../../interfaces/1inch/IAggregationRouterV6.sol";
import "../libraries/Errors.sol";
import "../common/Constants.sol";

/**
 * @title OneInchCallerV6 contract
 * @author Naturelab
 * @notice The focal point of interacting with the 1inch protocol.
 * @dev This contract will be inherited by the strategy contract and the wrapper contract,
 * used for the necessary exchange between different tokens when necessary.
 * @dev When using this contract, it is necessary to first obtain the calldata through 1inch API.
 * The contract will then extract and verify the calldata before proceeding with the exchange.
 */
contract OneInchCallerV6 is Constants {
    // 1inch v6 protocol is currently in use.
    address public constant ONEINCH_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;

    using AddressLib for UAddress;

    /**
     * @dev Separate the function signature and detailed parameters in the calldata.
     * This approach is used because memory variables in Solidity do not support slicing
     * operations directly. By using inline assembly, we can manually handle memory operations
     * to extract and copy the necessary parts of the data efficiently.
     * @param _swapData Calldata of 1inch.
     * @return functionSignature_ Function signature of the swap method.
     * @return remainingBytes_ The remaining bytes after the function signature.
     */
    function parseSwapCalldata(bytes memory _swapData)
        internal
        pure
        returns (bytes4 functionSignature_, bytes memory remainingBytes_)
    {
        assembly {
            // Extract function signature (first 4 bytes)
            functionSignature_ := mload(add(_swapData, 32))

            // Calculate remaining data length
            let remainingLength := sub(mload(_swapData), 4)

            // Allocate memory and copy remaining data
            remainingBytes_ := mload(0x40)
            mstore(remainingBytes_, remainingLength)
            let dst := add(remainingBytes_, 32)
            let src := add(_swapData, 36)

            for { let end := add(dst, remainingLength) } lt(dst, end) {
                dst := add(dst, 32)
                src := add(src, 32)
            } { mstore(dst, mload(src)) }

            // Update free memory pointer
            mstore(0x40, add(remainingBytes_, add(remainingLength, 32)))
        }
    }

    /**
     * @dev Executes the swap operation and verify the validity of the parameters and results.
     * @param _amount The maximum amount of currency spent.
     * @param _srcToken The token to be spent.
     * @param _dstToken The token to be received.
     * @param _swapData Calldata of 1inch.
     * @param _swapGetMin Minimum amount of the token to be received.
     * @return returnAmount_ Actual amount of the token spent.
     * @return spentAmount_ Actual amount of the token received.
     */
    function executeSwap(
        uint256 _amount,
        address _srcToken,
        address _dstToken,
        bytes memory _swapData,
        uint256 _swapGetMin
    ) internal returns (uint256 returnAmount_, uint256 spentAmount_) {
        (bytes4 functionSignature_, bytes memory remainingBytes_) = parseSwapCalldata(_swapData);
        bytes memory returnData_;
        if (functionSignature_ == IAggregationRouterV6.swap.selector) {
            (, IAggregationRouterV6.SwapDescription memory desc_,) =
                abi.decode(remainingBytes_, (IAggregationExecutor, IAggregationRouterV6.SwapDescription, bytes));
            if (address(this) != desc_.dstReceiver) revert Errors.OneInchInvalidReceiver();
            if (IERC20(_srcToken) != desc_.srcToken || IERC20(_dstToken) != desc_.dstToken) {
                revert Errors.OneInchInvalidToken();
            }
            if (_amount < desc_.amount) revert Errors.OneInchInvalidInputAmount();

            if (_srcToken == ETH) {
                returnData_ = Address.functionCallWithValue(ONEINCH_ROUTER, _swapData, _amount);
            } else {
                returnData_ = Address.functionCall(ONEINCH_ROUTER, _swapData);
            }
            (returnAmount_, spentAmount_) = abi.decode(returnData_, (uint256, uint256));
            if (spentAmount_ > desc_.amount) revert Errors.OneInchUnexpectedSpentAmount();
            if (returnAmount_ < _swapGetMin) revert Errors.OneInchUnexpectedReturnAmount();
            return (returnAmount_, spentAmount_);
        }

        if (
            functionSignature_ == IAggregationRouterV6.ethUnoswap.selector
                || functionSignature_ == IAggregationRouterV6.ethUnoswap2.selector
                || functionSignature_ == IAggregationRouterV6.ethUnoswap3.selector
        ) {
            if (_srcToken != ETH || _dstToken == ETH) revert Errors.OneInchNotSupported();
            uint256 tokenBefore_ = IERC20(_dstToken).balanceOf(address(this));
            uint256 ethBal_ = address(this).balance;
            returnData_ = Address.functionCallWithValue(ONEINCH_ROUTER, _swapData, _amount);
            spentAmount_ = ethBal_ - address(this).balance;
            returnAmount_ = IERC20(_dstToken).balanceOf(address(this)) - tokenBefore_;
            if (spentAmount_ != _amount) revert Errors.OneInchUnexpectedSpentAmount();
            if (returnAmount_ < _swapGetMin) revert Errors.OneInchUnexpectedReturnAmount();
            return (returnAmount_, spentAmount_);
        }

        UAddress srcTokenFromCalldata_;
        if (
            functionSignature_ == IAggregationRouterV6.unoswap.selector
                || functionSignature_ == IAggregationRouterV6.unoswap2.selector
                || functionSignature_ == IAggregationRouterV6.unoswap3.selector
        ) {
            (srcTokenFromCalldata_, spentAmount_) = abi.decode(remainingBytes_, (UAddress, uint256));
        } else {
            revert Errors.OneInchInvalidFunctionSignature();
        }
        if (srcTokenFromCalldata_.get() != _srcToken || _srcToken == ETH) revert Errors.OneInchNotSupported();
        if (_amount < spentAmount_) revert Errors.OneInchInvalidInputAmount();
        uint256 unoswapTokenBefore_ = IERC20(_dstToken).balanceOf(address(this));
        returnData_ = Address.functionCall(ONEINCH_ROUTER, _swapData);
        returnAmount_ = IERC20(_dstToken).balanceOf(address(this)) - unoswapTokenBefore_;
        if (returnAmount_ < _swapGetMin) revert Errors.OneInchUnexpectedReturnAmount();
    }

    receive() external payable {}
}
