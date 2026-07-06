// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

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
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
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
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
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
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
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
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
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
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
import "../proxy/utils/Initializable.sol";

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
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
interface IERC165Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
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
    /// otherwise, please consider using `updatePriceFeeds`. This method may store the price updates on-chain, if they
    /// are more recent than the current stored prices.
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
    /// this method will return the first update. This method may store the price updates on-chain, if they
    /// are more recent than the current stored prices.
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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title Quoter Interface
/// @notice Supports quoting the calculated amounts from exact input or exact output swaps
/// @dev These functions are not marked view because they rely on calling non-view functions and reverting
/// to compute the result. They are also not gas efficient and should not be called on-chain.
interface IQuoter {
    /// @notice Returns the amount out received for a given exact input swap without executing the swap
    /// @param path The path of the swap, i.e. each token pair and the pool fee
    /// @param amountIn The amount of the first token to swap
    /// @return amountOut The amount of the last token that would be received
    function quoteExactInput(bytes memory path, uint256 amountIn) external returns (uint256 amountOut);

    /// @notice Returns the amount out received for a given exact input but for a swap of a single pool
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param fee The fee of the token pool to consider for the pair
    /// @param amountIn The desired input amount
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountOut The amount of `tokenOut` that would be received
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);

    /// @notice Returns the amount in required for a given exact output swap without executing the swap
    /// @param path The path of the swap, i.e. each token pair and the pool fee. Path must be provided in reverse order
    /// @param amountOut The amount of the last token to receive
    /// @return amountIn The amount of first token required to be paid
    function quoteExactOutput(bytes memory path, uint256 amountOut) external returns (uint256 amountIn);

    /// @notice Returns the amount in required to receive the given exact output amount but for a swap of a single pool
    /// @param tokenIn The token being swapped in
    /// @param tokenOut The token being swapped out
    /// @param fee The fee of the token pool to consider for the pair
    /// @param amountOut The desired output amount
    /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
    /// @return amountIn The amount required as the input for the swap in order to receive `amountOut`
    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountIn);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IActivityRewardDistributorStorage, IERC20, IPrimexDNSV3, ITraderBalanceVault} from "./IActivityRewardDistributorStorage.sol";
import {IWhiteBlackList} from "../WhiteBlackList/WhiteBlackList/IWhiteBlackList.sol";
import {IBucketV3} from "../Bucket/IBucket.sol";
import {IPausable} from "../interfaces/IPausable.sol";

interface IActivityRewardDistributor is IActivityRewardDistributorStorage, IPausable {
    enum Role {
        LENDER,
        TRADER
    }

    struct BucketWithRole {
        address bucketAddress;
        Role role;
    }

    /**
     * @notice Emitted on claimReward()
     * @param user The address of the user who claimed reward
     * @param bucket The address of the bucket this reward is related to
     * @param role User role - TRADER or LENDER
     * @param amount Claimed amount
     */
    event ClaimReward(address indexed user, address indexed bucket, Role indexed role, uint256 amount);

    /**
     * @notice  Initializes the ActivityRewardDistributor contract.
     * @dev This function should only be called once during the initial setup of the contract.
     * @param _pmx The address of the PMXToken contract.
     * @param _dns The address of the PrimexDNS contract.
     * @param _registry The address of the PrimexRegistry contract.
     * @param _treasury The address of the treasury where fees will be collected.
     * @param _traderBalanceVault The address of the TraderBalanceVault contract.
     * @param _whiteBlackList The address of the WhiteBlackList contract.
     */
    function initialize(
        IERC20 _pmx,
        IPrimexDNSV3 _dns,
        address _registry,
        address _treasury,
        ITraderBalanceVault _traderBalanceVault,
        IWhiteBlackList _whiteBlackList
    ) external;

    /**
     * @notice  Saves user activity in the protocol for reward calculation
     * @param   bucket  The address of the bucket
     * @param   user  User address
     * @param   newBalance  User balance after action
     * @param   role  User role - TRADER or LENDER
     */
    function updateUserActivity(IBucketV3 bucket, address user, uint256 newBalance, Role role) external;

    /**
     * @notice  Saves activity of multiple users in the protocol for reward calculation
     * @param   bucket  The address of the bucket
     * @param   users  Array of user addresses
     * @param   newBalances  Array of users balances after action
     * @param   length  The length of the users and oldBalances arrays
     * @param   role  User role - TRADER or LENDER
     */
    function updateUsersActivities(
        IBucketV3 bucket,
        address[] calldata users,
        uint256[] calldata newBalances,
        uint256 length,
        Role role
    ) external;

    /**
     * @notice Allows the caller to claim their accumulated reward from the specified buckets.
     * @param bucketsArray The array of BucketWithRole objects containing the buckets from which to claim the rewards.
     */
    function claimReward(BucketWithRole[] calldata bucketsArray) external;

    /**
     * @notice Sets up activity rewards distribution in bucket with the specified role and reward parameters.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param bucket The address of the bucket to set up.
     * @param role The role associated with the bucket.
     * @param increaseAmount The amount by which to increase the total reward for the bucket (in PMX).
     * Adds specified amount to totalReward of the bucket. Initial value of totalReward is 0.
     * @param rewardPerDay The reward amount per day for the bucket.
     */
    function setupBucket(address bucket, Role role, uint256 increaseAmount, uint256 rewardPerDay) external;

    /**
     * @notice Allows the caller to withdraw PMX tokens from a specific bucket.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param bucket The address of the bucket from which to withdraw PMX tokens.
     * @param role The role associated with the bucket.
     * @param amount The amount of PMX tokens to withdraw.
     */
    function withdrawPmx(address bucket, Role role, uint256 amount) external;

    /**
     * @notice Decreases the reward per day for a bucket and role.
     * @dev Only callable by the EMERGENCY_ADMIN role.
     * @param bucket The address of the bucket for which to decrease the reward per day.
     * @param role The role associated with the bucket.
     * @param rewardPerDay The amount by which to decrease the reward per day.
     */
    function decreaseRewardPerDay(address bucket, Role role, uint256 rewardPerDay) external;

    /**
     * @notice Returns the accumulated reward for a specific bucket and role.
     * @param bucket The address of the bucket for which to retrieve the accumulated reward.
     * @param role The role associated with the bucket.
     * @return The accumulated reward for the specified bucket and role.
     */
    function getBucketAccumulatedReward(address bucket, Role role) external view returns (uint256);

    /**
     * @notice Returns the claimable reward for a user across multiple buckets.
     * @param bucketsArray The array of BucketWithRole objects containing the buckets to check for claimable rewards.
     * @param user The address of the user for whom to calculate the claimable reward.
     * @return The total claimable reward for the specified user across all provided buckets.
     */
    function getClaimableReward(BucketWithRole[] calldata bucketsArray, address user) external view returns (uint256);

    /**
     * @notice Retrieves the user information from a specific bucket and role.
     * @param bucket The address of the bucket from which to retrieve the user information.
     * @param role The role associated with the bucket.
     * @param user The address of the user for whom to retrieve the information.
     * @return A UserInfo struct containing the user information.
     */
    function getUserInfoFromBucket(address bucket, Role role, address user) external view returns (UserInfo memory);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {ITraderBalanceVault} from "../TraderBalanceVault/ITraderBalanceVault.sol";

interface IActivityRewardDistributorStorage {
    /*
     * @param oldBalance last updated balance for user
     * @param fixedReward the accumulated value of the reward at the time lastUpdatedRewardIndex
     * @param lastUpdatedRewardIndex last index with which the user's reward was accumulated
     */
    struct UserInfo {
        uint256 fixedReward;
        uint256 lastUpdatedRewardIndex;
        uint256 oldBalance;
    }

    /*
     * @param users data to calculate users rewards in this bucket
     * @param rewardIndex an index that accumulates user rewards
     * @param lastUpdatedTimestamp timestamp of the last update of user activity
     * @param rewardPerToken current reward for one token(PToken or DebtToken of bucket)
     * @param isFinished Shows that the bucket has distributed all the rewards
     * @param fixedReward reward distributed by a bucket over the past period
     * with a certain reward per day or with the entire reward fully distributed
     * @param lastUpdatedRewardTimestamp timestamp of last fixed reward update
     * @param rewardPerDay current reward distributed for 1 day
     * @param totalReward Full distributable reward
     * @param endTimestamp end time of the distribution of rewards, which is calculated relative to the rewardPerDay and totalReward
     */
    struct BucketInfo {
        mapping(address => UserInfo) users;
        //accumulated reward per token
        uint256 rewardIndex;
        uint256 lastUpdatedTimestamp;
        uint256 rewardPerToken;
        uint256 scaledTotalSupply;
        bool isFinished;
        // setted by admin's actions
        uint256 fixedReward;
        uint256 lastUpdatedRewardTimestamp;
        uint256 rewardPerDay;
        uint256 totalReward;
        uint256 endTimestamp;
    }

    function pmx() external returns (IERC20);

    function dns() external returns (IPrimexDNSV3);

    function registry() external returns (address);

    function traderBalanceVault() external returns (ITraderBalanceVault);

    function treasury() external view returns (address);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IFeeExecutorStorage} from "./IFeeExecutorStorage.sol";

interface IFeeExecutor is IFeeExecutorStorage {
    /**
     * @dev Sets tier bonuses for a specific bucket.
     * @param _bucket The address of the bucket.
     * @param _tiers The array of tier values.
     * @param _bonuses The array of NFT bonus parameters.
     */
    function setTierBonus(address _bucket, uint256[] calldata _tiers, NFTBonusParams[] calldata _bonuses) external;

    /**
     * @dev Updates the accumulatedAmount and the lastUpdatedIndex of the existing ActivatedBonus. Called by the Debt-Token
     * @param _user User for which the bonus will be updated. If user doesn't have the bonus for paused
     * @param _oldScaledBalance Balance of the user before the operation at which the updateBonus function was called (e.g mint/burn)
     * @param _bucket The Bucket to which the ActivatedBonus relates
     **/
    function updateBonus(address _user, uint256 _oldScaledBalance, address _bucket, uint256 _currentIndex) external;

    /**
     * @dev Updates the accumulatedAmount and the lastUpdatedIndex of the existing ActivatedBonus. Called directly by the user
     * @param _nftId Id of activated token
     **/
    function updateBonus(uint256 _nftId) external;

    /**
     * @dev Updates the accumulatedAmount and the lastUpdatedIndex of the existing ActivatedBonus. Called by the P-Token or Debt-Token
     * @param _users Array of the users for whom the bonus will be updated.
     * @param _oldBalances Array of the balances before the operation at which the updateBonus function was called (e.g mint/transfer)
     * @param _bucket The Bucket to which the ActivatedBonus relates
     **/
    function updateBonuses(
        address[] memory _users,
        uint256[] memory _oldBalances,
        address _bucket,
        uint256 _currentIndex
    ) external;

    /**
     * @dev Returns accumulated amount of p-tokens at the moment
     * @param _user The user for which the accumatedAmount will return. If the bonus does not exist will return 0.
     * If the NFT does not exist will throw an error
     * @param _nftId Id of activated token
     * @return The accumulated amount.
     */
    function getAccumulatedAmount(address _user, uint256 _nftId) external returns (uint256);

    /**
     * @dev Returns the available amount (accumulated - claimedAmount) of p-tokens at the moment.
     * @param _user The user for which the available amount will return. If the bonus does not exist will return 0.
     * If the NFT does not exist will throw an error
     * @param _nftId Id of activated token
     **/
    function getAvailableAmount(address _user, uint256 _nftId) external returns (uint256);

    /**
     * @dev Retrieves the bonus information for a user and NFT.
     * @param _user The address of the user.
     * @param _nftId The ID of the NFT.
     * @return bonus The activated bonus information.
     */
    function getBonus(address _user, uint256 _nftId) external view returns (ActivatedBonus memory);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IBucketV3} from "../Bucket/IBucket.sol";

interface IFeeExecutorStorage {
    struct ActivatedBonus {
        uint256 nftId;
        IBucketV3 bucket;
        uint256 percent;
        uint256 maxAmount;
        uint256 accumulatedAmount;
        uint256 lastUpdatedIndex;
        uint256 deadline;
        //if we allow to claim funds before the end of the bonus
        uint256 claimedAmount;
    }

    struct NFTBonusParams {
        uint256 percent;
        uint256 maxAmount;
        uint256 duration;
    }
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PrimexPricingLibrary} from "../libraries/PrimexPricingLibrary.sol";

import {IPToken} from "../PToken/IPToken.sol";
import {IDebtToken} from "../DebtToken/IDebtToken.sol";
import {IPositionManager, IPositionManagerV2} from "../PositionManager/IPositionManager.sol";
import {IPriceOracle} from "../PriceOracle/IPriceOracle.sol";
import {IPrimexDNS, IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {IWhiteBlackList} from "../WhiteBlackList/WhiteBlackList/IWhiteBlackList.sol";
import {IReserve} from "../Reserve/IReserve.sol";
import {ILiquidityMiningRewardDistributor} from "../LiquidityMiningRewardDistributor/ILiquidityMiningRewardDistributor.sol";
import {IInterestRateStrategy} from "../interfaces/IInterestRateStrategy.sol";
import {ISwapManager} from "../SwapManager/ISwapManager.sol";
import {IBucketStorage} from "./IBucketStorage.sol";
import {IBucketEvents} from "./IBucketEvents.sol";

interface IBucket is IBucketStorage, IBucketEvents {
    struct ConstructorParams {
        string name;
        IPToken pToken;
        IDebtToken debtToken;
        IPositionManager positionManager;
        IPriceOracle priceOracle;
        IPrimexDNS dns;
        IReserve reserve;
        IWhiteBlackList whiteBlackList;
        address[] assets;
        IERC20Metadata borrowedAsset;
        uint256 feeBuffer;
        uint256 withdrawalFeeRate;
        uint256 reserveRate;
        // liquidityMining params
        ILiquidityMiningRewardDistributor liquidityMiningRewardDistributor;
        uint256 liquidityMiningAmount;
        uint256 liquidityMiningDeadline;
        uint256 stabilizationDuration;
        IInterestRateStrategy interestRateStrategy;
        uint128 estimatedBar;
        uint128 estimatedLar;
        uint256 maxAmountPerUser;
        bool isReinvestToAaveEnabled;
        bytes barCalcParams;
        uint256 maxTotalDeposit;
    }

    event Deposit(address indexed depositer, address indexed pTokenReceiver, uint256 amount);

    event DepositToAave(address indexed pool, uint256 amount);

    event FeeBufferChanged(uint256 feeBuffer);

    event ReserveRateChanged(uint256 reserveRate);

    event RatesIndexesUpdated(
        uint128 bar,
        uint128 lar,
        uint128 variableBorrowIndex,
        uint128 liquidityIndex,
        uint256 timestamp
    );

    event WithdrawalFeeChanged(uint256 withdrawalFeeRate);

    event InterestRateStrategyChanged(address interestRateStrategy);

    event AddAsset(address addedAsset);

    event RemoveAsset(address deletedAsset);

    event MaxTotalDepositChanged(uint256 maxTotalDeposit);

    event BarCalculationParamsChanged(bytes params);

    event BucketLaunched();

    /**
     * @dev Initializes the contract with the given parameters.
     * @param _params The ConstructorParams struct containing initialization parameters.
     * @param _registry The address of the registry contract.
     */
    function initialize(ConstructorParams memory _params, address _registry) external;

    /**
     * @dev Function to add new trading asset for this bucket
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _newAsset The address of trading asset
     */
    function addAsset(address _newAsset) external;

    /**
     * @notice Removes a trading asset from this bucket.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _assetToDelete The address of the asset to be removed.
     */
    function removeAsset(address _assetToDelete) external;

    /**
     * @dev Sets barCalculationParams (urOptimal, k0, k1, b0, b1)
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     */
    function setBarCalculationParams(bytes memory _params) external;

    /**
     * @dev Sets the reserve rate.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _reserveRate The new reserve rate value.
     */
    function setReserveRate(uint256 _reserveRate) external;

    /**
     * @dev Sets the new fee buffer.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _feeBuffer The new fee buffer value.
     */
    function setFeeBuffer(uint256 _feeBuffer) external;

    /**
     * @dev Sets the withdrawal fee.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _withdrawalFee The new withdrawal fee value.
     */
    function setWithdrawalFee(uint256 _withdrawalFee) external;

    /**
     * @dev Sets the interest rate strategy contract address.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _interestRateStrategy The address of the interest rate strategy contract.
     */
    function setInterestRateStrategy(address _interestRateStrategy) external;

    /**
     * @notice The function sets the max total deposit for the particular bucket
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _maxTotalDeposit The amount of max total deposit for the bucket
     */
    function setMaxTotalDeposit(uint256 _maxTotalDeposit) external;

    /**
     * @dev Deposits the 'amount' of underlying asset into the bucket. The 'PTokenReceiver' receives overlying pTokens.
     * @param _pTokenReceiver The address to receive the deposited pTokens.
     * @param _amount The amount of underlying tokens to be deposited
     */
    function deposit(address _pTokenReceiver, uint256 _amount) external;

    /**
     * @dev Withdraws the 'amount' of underlying asset from the bucket. The 'amount' of overlying pTokens will be burned.
     * @param _borrowAssetReceiver The address of receiver of the borrowed asset.
     * @param amount The amount of underlying tokens to be withdrawn.
     */
    function withdraw(address _borrowAssetReceiver, uint256 amount) external;

    /**
     * @notice Allows the BIG_TIMELOCK_ADMIN role to withdraw a specified amount of tokens after delisting.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdrawAfterDelisting(uint256 _amount) external;

    /**
     * @dev Receives a deposit and distributes it to the specified pToken receiver.
     * @dev Can be called only by another bucket.
     * @param _pTokenReceiver The address of the recipient of the pToken.
     * @param _amount The amount of tokens being deposited.
     * @param _duration The blocking time for a fixed-term deposit (if it's 0, then it will be a usual deposit)
     * @param _bucketFrom The name of the bucket from which the deposit is being made.
     */
    function receiveDeposit(
        address _pTokenReceiver,
        uint256 _amount,
        uint256 _duration,
        string memory _bucketFrom
    ) external;

    /**
     * @notice Deposits (reinvests) funds from a bucket to another bucket.
     * Used only in the case of failed liquidity mining in the bucket from where the transfer happens.
     * @param _bucketTo The name of the destination bucket.
     * @param _swapManager The address of the swap manager.
     * @param _megaRoutes The array of routes for swapping tokens.
     * @param _amountOutMin The minimum amount of tokens to receive from the swap.
     */
    function depositFromBucket(
        string calldata _bucketTo,
        ISwapManager _swapManager,
        PrimexPricingLibrary.MegaRoute[] calldata _megaRoutes,
        uint256 _amountOutMin
    ) external;

    /**
     * @dev Allows the SMALL_TIMELOCK_ADMIN to withdraw all liquidity from Aave to Bucket.
     */
    function returnLiquidityFromAaveToBucket() external;

    /**
     * @dev Function to update rates and indexes when a trader opens a trading position.
     * Mints debt tokens to trader. Calls only by positionManager contract.
     * @param _trader The address of the trader, who opens position.
     * @param _amount The 'amount' for which the deal is open, and 'amount' of debtTokens will be minted to the trader.
     * @param _to The address to transfer the borrowed asset to.
     */

    function increaseDebt(address _trader, uint256 _amount, address _to) external;

    /**
     * @dev Function to update rates and indexes.
     * Burns debt tokens of trader. Called only by positionManager contract.
     * @param _trader The address of the trader, who opened position.
     * @param _debtToBurn The 'amount' of trader's debtTokens will be burned by the trader.
     * @param _receiverOfAmountToReturn Treasury in case of liquidation. TraderBalanceVault in other cases
     * @param _amountToReturn Amount to transfer from bucket
     * @param _permanentLossAmount The amount of the protocol's debt to creditors accrued for this position
     */
    function decreaseTraderDebt(
        address _trader,
        uint256 _debtToBurn,
        address _receiverOfAmountToReturn,
        uint256 _amountToReturn,
        uint256 _permanentLossAmount
    ) external;

    /**
     * @notice Batch decreases the debt of multiple traders.
     * @dev This function can only be called by the BATCH_MANAGER_ROLE.
     * @param _traders An array of addresses representing the traders.
     * @param _debtsToBurn An array of uint256 values representing the debts to burn for each trader.
     * @param _receiverOfAmountToReturn The address that will receive the amount to be returned.
     * @param _amountToReturn The amount to be returned.
     * @param _permanentLossAmount The amount of permanent loss.
     * @param _length The length of the traders array.
     */
    function batchDecreaseTradersDebt(
        address[] memory _traders,
        uint256[] memory _debtsToBurn,
        address _receiverOfAmountToReturn,
        uint256 _amountToReturn,
        uint256 _permanentLossAmount,
        uint256 _length
    ) external;

    /**
     * @notice This function allows a user to pay back a permanent loss by burning his pTokens.
     * @param amount The amount of pTokens to be burned to pay back the permanent loss.
     */
    function paybackPermanentLoss(uint256 amount) external;

    /**
     * @dev Calculates the permanent loss based on the scaled permanent loss and the normalized income.
     * @return The amount of permanent loss.
     */
    function permanentLoss() external view returns (uint256);

    /**
     * @dev Checks if the bucket is deprecated in the protocol.
     * @return Whether the bucket is deprecated or not.
     */
    function isDeprecated() external view returns (bool);

    /**
     * @dev Returns a boolean value indicating whether the bucket is delisted.
     * @return True if the bucket is delisted, otherwise false.
     */
    function isDelisted() external view returns (bool);

    /**
     * @dev Checks if an admin can withdraw from the bucket after delisting.
     * @return A boolean indicating whether withdrawal is available.
     */
    function isWithdrawAfterDelistingAvailable() external view returns (bool);

    /**
     * @dev Checks if this bucket is active in the protocol.
     * @return bool True if the bucket is active, false otherwise.
     */
    function isActive() external view returns (bool);

    /**
     * @dev Returns the parameters for liquidity mining.
     * @return LMparams The liquidity mining parameters.
     */
    function getLiquidityMiningParams() external view returns (LiquidityMiningParams memory);

    /**
     * @dev Returns a boolean value indicating whether the bucket is stable in the liquidity mining event.
     * @return A boolean value representing the stability of the bucket.
     */
    function isBucketStable() external view returns (bool);

    /**
     * @dev Calculates the max leverage according to the following formula:
     * ((1 + maintenanceBuffer) * feeBuffer) / ((1 + maintenanceBuffer) * feeBuffer - (1 - securityBuffer) *
     * (1 - pairPriceDropBA) * (1 - oracleTolerableLimitAB) * (1 - oracleTolerableLimitBA))
     * @param _asset The address of trading asset
     * @return The maximum leverage as a uint256 value.
     */
    function maxAssetLeverage(address _asset) external view returns (uint256);

    /**
     * @dev Returns the normalized income per unit of underlying asset, expressed in ray
     * @return The normalized income per unit of underlying asset, expressed in ray
     */
    function getNormalizedIncome() external view returns (uint256);

    /**
     * @dev Returns the normalized variable debt per unit of underlying asset, expressed in ray
     */
    function getNormalizedVariableDebt() external view returns (uint256);

    /**
     * @dev Returns allowed trading assets for current bucket
     * @return List of addresses of allowed assets
     */
    function getAllowedAssets() external view returns (address[] memory);

    /**
     * @dev Returns current avalable liquidity of borrowedAsset for trading.
     * @return The amount of available borrowedAsset
     */
    function availableLiquidity() external view returns (uint256);
}

interface IBucketV2 is IBucket {
    /**
     * @dev Deposits the 'amount' of underlying asset into the bucket. The 'PTokenReceiver' receives overlying pTokens.
     * @param _pTokenReceiver The address to receive the deposited pTokens.
     * @param _amount The amount of underlying tokens to be deposited
     * @param _takeDepositFromWallet A flag indicating whether to make the deposit from user wallet
     */
    function deposit(address _pTokenReceiver, uint256 _amount, bool _takeDepositFromWallet) external;
}

interface IBucketV3 is IBucketV2 {
    event ChangedBucketExtension(address newBucketExtension);

    /**
     * @dev Calculates the max leverage according to the following formula:
     * ((1 + maintenanceBuffer) * feeBuffer) / ((1 + maintenanceBuffer) * feeBuffer - (1 - securityBuffer) *
     * (1 - pairPriceDropBA) * (1 - oracleTolerableLimitAB) * (1 - oracleTolerableLimitBA) + protocolFeeInPositiontAsset / positionSize)
     * @param _asset The address of trading asset
     * @param _feeRate The ratio of protocolFeeInPositionAsset to positionSize
     * @return The maximum leverage as a uint256 value.
     */
    function maxAssetLeverage(address _asset, uint256 _feeRate) external view returns (uint256);

    /**
     * @notice Sets the bucketExtension.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _newBucketExtension The address of BucketExtension contract.
     */
    function setBucketExtension(address _newBucketExtension) external;
}

interface IBucketV4 is IBucketV3 {
    /**
     * @notice Performs a flash loan transfer of a specified amount to a receiver address.
     * @dev Only callable by the FLASH_LOAN_MANAGER_ROLE role.
     * @param _to The address to which the flash loan amount will be transferred.
     * @param _amount The amount of tokens to transfer in the flash loan.
     */
    function performFlashLoanTransfer(address _to, uint256 _amount) external;

    /**
     * @notice Accumulates a predefined amount of asset to the bucket as a fixed, instantaneous income. Used
     * to accumulate the flashloan fee to the bucket, and spread it between all the suppliers.
     * @dev Only callable by the FLASH_LOAN_MANAGER_ROLE role.
     * @param amount The amount to accumulate
     * @param availableLiquidity The availableLiquidity before flashLoan
     */
    function cumulateToLiquidityIndex(uint256 amount, uint256 availableLiquidity) external;

    /**
     * @notice Updates bucket's BAR and LAR.
     * @dev Only callable by the FLASH_LOAN_MANAGER_ROLE role.
     */
    function updateRates() external;
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IBucketEvents {
    event WithdrawFromAave(address indexed pool, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed borrowAssetReceiver, uint256 amount);
    event TopUpTreasury(address indexed sender, uint256 amount);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IPToken} from "../PToken/IPToken.sol";
import {IDebtToken} from "../DebtToken/IDebtToken.sol";
import {IPositionManagerV2} from "../PositionManager/IPositionManager.sol";
import {IPriceOracleV2} from "../PriceOracle/IPriceOracle.sol";
import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {IReserve} from "../Reserve/IReserve.sol";
import {ILiquidityMiningRewardDistributor} from "../LiquidityMiningRewardDistributor/ILiquidityMiningRewardDistributor.sol";
import {IWhiteBlackList} from "../WhiteBlackList/WhiteBlackList/IWhiteBlackList.sol";
import {IInterestRateStrategy} from "../interfaces/IInterestRateStrategy.sol";

interface IBucketStorage {
    /**
     * @dev Parameters of liquidity mining
     */
    struct LiquidityMiningParams {
        ILiquidityMiningRewardDistributor liquidityMiningRewardDistributor;
        bool isBucketLaunched;
        uint256 accumulatingAmount;
        uint256 deadlineTimestamp;
        uint256 stabilizationDuration;
        uint256 stabilizationEndTimestamp;
        uint256 maxAmountPerUser; // if maxAmountPerUser is >= accumulatingAmount then check on maxAmountPerUser is off
        // Constant max variables are used for calculating users' points.
        // These intervals are used for fair distribution of points among Lenders.
        // Lenders who brought liquidity earlier receive more than the ones who deposited later.
        // To get maximum points per token, a Lender should deposit immediately after the Bucket deployment.
        uint256 maxDuration;
        uint256 maxStabilizationEndTimestamp;
    }
    //                                        1. Corner case of bucket launch
    //
    //                                              maxDuration
    //       ------------------------------------------------------------------------------------------------
    //      |                                                                                               |
    //      |                                                                        stabilizationDuration  |
    //      |                                                                      -------------------------|
    //      |                                                                     | bucket launch           |
    //   +--+---------------------------------------------------------------------+-------------------------+------> time
    //      bucket deploy                                                         deadlineTimestamp         maxStabilizationEndTimestamp
    //                                                                                                       (=stabilizationEndTimestamp here)
    //                                  (corner case of bucket launch)

    //                                        2. One of cases of bucket launch
    //
    //      |                     stabilizationDuration
    //      |                   -------------------------
    //      |                  |                         |
    //   +--+------------------+-------------------------+------------------------+-------------------------+------> time
    //      bucket deploy      bucket launch            stabilizationEndTimestamp  deadlineTimestamp        maxStabilizationEndTimestamp
    //                                                                            (after deadline bucket can't be launched)

    struct Asset {
        uint256 index;
        bool isSupported;
    }

    function liquidityIndex() external returns (uint128);

    function variableBorrowIndex() external returns (uint128);

    function name() external view returns (string memory);

    function registry() external view returns (address);

    function positionManager() external view returns (IPositionManagerV2);

    function reserve() external view returns (IReserve);

    function permanentLossScaled() external view returns (uint256);

    function pToken() external view returns (IPToken);

    function debtToken() external view returns (IDebtToken);

    function borrowedAsset() external view returns (IERC20Metadata);

    function feeBuffer() external view returns (uint256);

    function withdrawalFeeRate() external view returns (uint256);

    /**
     * @notice bar = borrowing annual rate (originally APR)
     */
    function bar() external view returns (uint128);

    /**
     * @notice lar = lending annual rate (originally APY)
     */
    function lar() external view returns (uint128);

    function interestRateStrategy() external view returns (IInterestRateStrategy);

    function estimatedBar() external view returns (uint128);

    function estimatedLar() external view returns (uint128);

    function allowedAssets(address _asset) external view returns (uint256, bool);

    function whiteBlackList() external view returns (IWhiteBlackList);

    function maxTotalDeposit() external view returns (uint256);
}

interface IBucketStorageV2 {
    function bucketExtension() external view returns (address);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;
import {IArbGasInfo} from "./interfaces/IArbGasInfo.sol";
import {IOVM_GasPriceOracle} from "./interfaces/IOVM_GasPriceOracle.sol";

// admin roles
bytes32 constant BIG_TIMELOCK_ADMIN = 0x00; // It's primary admin.
bytes32 constant MEDIUM_TIMELOCK_ADMIN = keccak256("MEDIUM_TIMELOCK_ADMIN");
bytes32 constant SMALL_TIMELOCK_ADMIN = keccak256("SMALL_TIMELOCK_ADMIN");
bytes32 constant EMERGENCY_ADMIN = keccak256("EMERGENCY_ADMIN");
bytes32 constant GUARDIAN_ADMIN = keccak256("GUARDIAN_ADMIN");
bytes32 constant NFT_MINTER = keccak256("NFT_MINTER");
bytes32 constant TRUSTED_TOLERABLE_LIMIT_ROLE = keccak256("TRUSTED_TOLERABLE_LIMIT_ROLE");

// inter-contract interactions roles
bytes32 constant NO_FEE_ROLE = keccak256("NO_FEE_ROLE");
bytes32 constant VAULT_ACCESS_ROLE = keccak256("VAULT_ACCESS_ROLE");
bytes32 constant PM_ROLE = keccak256("PM_ROLE");
bytes32 constant LOM_ROLE = keccak256("LOM_ROLE");
bytes32 constant BATCH_MANAGER_ROLE = keccak256("BATCH_MANAGER_ROLE");
bytes32 constant FLASH_LOAN_MANAGER_ROLE = keccak256("FLASH_LOAN_MANAGER_ROLE");
bytes32 constant FLASH_LOAN_FREE_BORROWER_ROLE = keccak256("FLASH_LOAN_FREE_BORROWER_ROLE");

// token constants
address constant NATIVE_CURRENCY = address(uint160(bytes20(keccak256("NATIVE_CURRENCY"))));
address constant USD = 0x0000000000000000000000000000000000000348;
address constant NATIVE_CURRENCY_CURVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
uint256 constant USD_MULTIPLIER = 10 ** (18 - 8); // usd decimals in chainlink is 8
uint8 constant MAX_ASSET_DECIMALS = 18;

// time constants
uint256 constant SECONDS_PER_YEAR = 365 days;
uint256 constant SECONDS_PER_DAY = 1 days;
uint256 constant HOUR = 1 hours;
uint256 constant TEN_WAD = 10 ether;

// constants for Arbitrum payment model
IArbGasInfo constant ARB_NITRO_ORACLE = IArbGasInfo(0x000000000000000000000000000000000000006C);
uint256 constant TRANSACTION_METADATA_BYTES = 140;

IOVM_GasPriceOracle constant OVM_GASPRICEORACLE = IOVM_GasPriceOracle(0x420000000000000000000000000000000000000F);

uint256 constant GAS_FOR_BYTE = 16;

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import {IDebtTokenStorage, IBucket, IFeeExecutor, IERC20Upgradeable, IActivityRewardDistributor} from "./IDebtTokenStorage.sol";

interface IDebtToken is IDebtTokenStorage {
    /**
     * @dev Emitted after the mint action
     * @param from The address performing the mint
     * @param value The amount being
     **/
    event Mint(address indexed from, uint256 value);

    /**
     * @dev Emitted after DebtTokens are burned
     * @param from The owner of the aTokens, getting them burned
     * @param value The amount being burned
     **/
    event Burn(address indexed from, uint256 value);

    /**
     * @dev contract initializer
     * @param _name The name of the ERC20 token.
     * @param _symbol The symbol of the ERC20 token.
     * @param _decimals The number of decimals for the ERC20 token.
     * @param _bucketsFactory Address of the buckets factory that will call the setBucket fucntion
     */
    function initialize(string memory _name, string memory _symbol, uint8 _decimals, address _bucketsFactory) external;

    /**
     * @dev Sets the bucket for the contract.
     * @param _bucket The address of the bucket to set.
     */
    function setBucket(IBucket _bucket) external;

    /**
     * @dev Sets the FeeDecreaser for current DebtToken.
     * @param _feeDecreaser The interest increaser address.
     */
    function setFeeDecreaser(IFeeExecutor _feeDecreaser) external;

    /**
     * @dev Sets the trader reward distributor contract address.
     * @param _traderRewardDistributor The address of the trader reward distributor contract.
     * Only the BIG_TIMELOCK_ADMIN role can call this function.
     */
    function setTraderRewardDistributor(IActivityRewardDistributor _traderRewardDistributor) external;

    /**
     * @dev Mints `amount` DebtTokens to `user`
     * @param _user The address receiving the minted tokens
     * @param _amount The amount of tokens getting minted
     * @param _index The current variableBorrowIndex
     */
    function mint(address _user, uint256 _amount, uint256 _index) external;

    /**
     * @dev Burns DebtTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
     * @param _user The owner of the DebtTokens, getting them burned
     * @param _amount The amount being burned
     * @param _index The current variableBorrowIndex
     **/
    function burn(address _user, uint256 _amount, uint256 _index) external;

    /**
     * @dev Burns a batch of tokens from multiple users.
     * @param _users An array of user addresses whose tokens will be burned.
     * @param _amounts An array of token amounts to be burned for each user.
     * @param _index The index used to calculate the scaled amounts.
     * @param _length The length of the user and amounts arrays.
     */
    function batchBurn(address[] memory _users, uint256[] memory _amounts, uint256 _index, uint256 _length) external;

    /**
     * @dev Returns the principal debt balance of the user
     * @param _user The address of the user.
     * @return The scaled balance of the user.
     */
    function scaledBalanceOf(address _user) external view returns (uint256);

    /**
     * @dev Returns the scaled total supply of debtToken.
     * @return The scaled total supply of the debtToken.
     */
    function scaledTotalSupply() external view returns (uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {IBucket, IBucketV3} from "../Bucket/IBucket.sol";
import {IFeeExecutor} from "../BonusExecutor/IFeeExecutor.sol";
import {IActivityRewardDistributor} from "../ActivityRewardDistributor/IActivityRewardDistributor.sol";

interface IDebtTokenStorage is IERC20Upgradeable {
    function bucket() external view returns (IBucketV3);

    function feeDecreaser() external view returns (IFeeExecutor);

    function traderRewardDistributor() external view returns (IActivityRewardDistributor);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {WadRayMath} from "../libraries/utils/WadRayMath.sol";

import {TokenTransfersLibrary} from "../libraries/TokenTransfersLibrary.sol";
import {FlashLoanManagerStorage, IERC165Upgradeable} from "./FlashLoanManagerStorage.sol";
import {BIG_TIMELOCK_ADMIN, SMALL_TIMELOCK_ADMIN, EMERGENCY_ADMIN, FLASH_LOAN_FREE_BORROWER_ROLE} from "../Constants.sol";
import "../libraries/Errors.sol";

import {IFlashLoanReceiver} from "../interfaces/IFlashLoanReceiver.sol";
import {IFlashLoanManager, IPausable} from "./IFlashLoanManager.sol";
import {IBucketV4} from "../Bucket/IBucket.sol";
import {IPrimexDNS} from "../PrimexDNS/IPrimexDNS.sol";
import {IPrimexDNSStorage} from "../PrimexDNS/IPrimexDNSStorage.sol";
import {IWhiteBlackList} from "../WhiteBlackList/WhiteBlackList/IWhiteBlackList.sol";

contract FlashLoanManager is IFlashLoanManager, FlashLoanManagerStorage {
    using WadRayMath for uint256;

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Throws if caller is not granted with _role
     * @param _role The role that is being checked for a function caller
     */
    modifier onlyRole(bytes32 _role) {
        _require(registry.hasRole(_role, msg.sender), Errors.FORBIDDEN.selector);
        _;
    }

    /**
     * @dev Modifier to check if the sender is not blacklisted.
     */
    modifier notBlackListed() {
        _require(!whiteBlackList.isBlackListed(msg.sender), Errors.SENDER_IS_BLACKLISTED.selector);
        _;
    }

    /**
     * @inheritdoc IFlashLoanManager
     */
    function initialize(
        address _registry,
        address _primexDNS,
        address _whiteBlackList,
        uint256 _flashLoanFeeRate,
        uint256 _flashLoanProtocolRate
    ) external override initializer {
        _require(
            IERC165Upgradeable(_registry).supportsInterface(type(IAccessControl).interfaceId) &&
                IERC165Upgradeable(_primexDNS).supportsInterface(type(IPrimexDNS).interfaceId) &&
                IERC165Upgradeable(_whiteBlackList).supportsInterface(type(IWhiteBlackList).interfaceId),
            Errors.ADDRESS_NOT_SUPPORTED.selector
        );
        whiteBlackList = IWhiteBlackList(_whiteBlackList);
        registry = IAccessControl(_registry);
        primexDNS = IPrimexDNS(_primexDNS);
        _setFlashLoanRates(_flashLoanFeeRate, _flashLoanProtocolRate);
    }

    /**
     * @inheritdoc IFlashLoanManager
     */
    function setFlashLoanRates(
        uint256 _newFlashLoanFeeRate,
        uint256 _newFlashLoanProtocolRate
    ) external override onlyRole(BIG_TIMELOCK_ADMIN) {
        _setFlashLoanRates(_newFlashLoanFeeRate, _newFlashLoanProtocolRate);
    }

    /**
     * @inheritdoc IFlashLoanManager
     */
    function flashLoan(
        address receiver,
        address[] calldata buckets,
        uint256[] calldata amounts,
        bytes calldata params
    ) external override nonReentrant notBlackListed whenNotPaused {
        _require(buckets.length == amounts.length, Errors.INCONSISTENT_FLASHLOAN_PARAMS.selector);
        _hasNoBucketsDuplicates(buckets);
        bool isZeroFee = registry.hasRole(FLASH_LOAN_FREE_BORROWER_ROLE, msg.sender);
        address[] memory assets = new address[](buckets.length);
        uint256[] memory flashLoanFees = new uint256[](buckets.length);
        uint256[] memory availableLiquidities = new uint256[](buckets.length);

        for (uint256 i; i < buckets.length; i++) {
            IBucketV4 bucket = IBucketV4(buckets[i]);
            (address bucketAddress, IPrimexDNSStorage.Status status, , ) = primexDNS.buckets(bucket.name());
            _require(buckets[i] == bucketAddress, Errors.BUCKET_OUTSIDE_PRIMEX_PROTOCOL.selector);
            _require(status == IPrimexDNSStorage.Status.Active, Errors.BUCKET_IS_NOT_ACTIVE.selector);
            assets[i] = address(bucket.borrowedAsset());
            flashLoanFees[i] = isZeroFee ? 0 : amounts[i].wmul(flashLoanFeeRate);
            availableLiquidities[i] = bucket.availableLiquidity();
            bucket.performFlashLoanTransfer(receiver, amounts[i]);
        }

        _require(
            IFlashLoanReceiver(receiver).executeOperation(assets, amounts, flashLoanFees, msg.sender, params),
            Errors.INVALID_FLASHLOAN_EXECUTOR_RETURN.selector
        );

        for (uint256 i; i < buckets.length; i++) {
            _handleFlashLoanRepayment(
                IBucketV4(buckets[i]),
                assets[i],
                amounts[i],
                flashLoanFees[i],
                availableLiquidities[i],
                receiver
            );
        }
    }

    /**
     * @inheritdoc IPausable
     */
    function pause() external override onlyRole(EMERGENCY_ADMIN) {
        _pause();
    }

    /**
     * @inheritdoc IPausable
     */
    function unpause() external override onlyRole(SMALL_TIMELOCK_ADMIN) {
        _unpause();
    }

    /**
     * @notice Interface checker
     * @param _interfaceId The interface id to check
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IFlashLoanManager).interfaceId || super.supportsInterface(_interfaceId);
    }

    /**
     * @notice Handles repayment of flashloaned assets + flashLoanFee
     * @dev Will pull the amount + flashLoanFee from the receiver to the Bucket and Treasury
     */
    function _handleFlashLoanRepayment(
        IBucketV4 bucket,
        address asset,
        uint256 amount,
        uint256 flashLoanFee,
        uint256 availableLiquidity,
        address receiver
    ) internal {
        uint256 feeToTreasury = flashLoanFee.wmul(flashLoanProtocolRate);
        uint256 feeToBucket = flashLoanFee - feeToTreasury;
        uint256 amountPlusFeeToBucket = amount + feeToBucket;
        // Accumulates a predefined amount of asset to the bucket as a fixed, instantaneous income
        bucket.cumulateToLiquidityIndex(feeToBucket, availableLiquidity);

        // The receiver should approve the flash loaned amount + fee for the FlashLoanManager.
        TokenTransfersLibrary.doTransferFromTo(asset, receiver, address(bucket), amountPlusFeeToBucket);
        TokenTransfersLibrary.doTransferFromTo(asset, receiver, primexDNS.treasury(), feeToTreasury);

        bucket.updateRates();
        emit FlashLoan(receiver, msg.sender, asset, amount, flashLoanFee, feeToTreasury);
    }

    function _setFlashLoanRates(uint256 _newFlashLoanFeeRate, uint256 _newFlashLoanProtocolRate) internal {
        _require(_newFlashLoanFeeRate <= WadRayMath.WAD / 10, Errors.FLASH_LOAN_FEE_RATE_IS_MORE_10_PERCENT.selector);
        _require(
            _newFlashLoanProtocolRate <= WadRayMath.WAD / 2,
            Errors.FLASH_LOAN_PROTOCOL_RATE_IS_MORE_50_PERCENT.selector
        );
        flashLoanFeeRate = _newFlashLoanFeeRate;
        flashLoanProtocolRate = _newFlashLoanProtocolRate;
        emit ChangedFlashLoanRates(_newFlashLoanFeeRate, _newFlashLoanProtocolRate);
    }

    /**
     * @notice Checks if an array of has no duplicate addresses.
     * @param _addresses The array of buckets addresses to be checked. The array should be sorted in ascending order before being passed.
     */
    function _hasNoBucketsDuplicates(address[] calldata _addresses) internal pure {
        if (_addresses.length > 1) {
            for (uint256 i = 1; i < _addresses.length; i++) {
                _require(_addresses[i - 1] < _addresses[i], Errors.SHOULD_NOT_HAVE_DUPLICATES.selector);
            }
        }
    }
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {ERC165Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IWhiteBlackList} from "../WhiteBlackList/WhiteBlackList/IWhiteBlackList.sol";
import {IPrimexDNS} from "../PrimexDNS/IPrimexDNS.sol";

import {IFlashLoanManagerStorage} from "./IFlashLoanManagerStorage.sol";

abstract contract FlashLoanManagerStorage is
    IFlashLoanManagerStorage,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    ERC165Upgradeable
{
    IAccessControl public override registry;
    IPrimexDNS public override primexDNS;
    IWhiteBlackList public whiteBlackList;
    uint256 public override flashLoanFeeRate;
    uint256 public override flashLoanProtocolRate;
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IPausable} from "../interfaces/IPausable.sol";

interface IFlashLoanManager is IPausable {
    event FlashLoan(
        address indexed target,
        address indexed initiator,
        address indexed asset,
        uint256 amount,
        uint256 flashLoanFee,
        uint256 flashLoanProtocolFee
    );

    event ChangedFlashLoanRates(uint256 flashLoanFeeRate, uint256 flashLoanProtocolRate);

    /**
     * @notice Initializes the contract with the specified parameters.
     * @param _registry The address of the PrimexRegistry contract.
     * @param _primexDNS The address of the PrimexDNS contract.
     * @param _whiteBlackList The address of the WhiteBlackList contract.
     * @param _flashLoanFeeRate The percent that is paid by the borrower.
     * @param _flashLoanProtocolRate The percent of the fee paid by the borrower that goes to the Treasury.
     */
    function initialize(
        address _registry,
        address _primexDNS,
        address _whiteBlackList,
        uint256 _flashLoanFeeRate,
        uint256 _flashLoanProtocolRate
    ) external;

    /**
     * @notice Set flashLoanFeeRate and flashLoanProtocolRate.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     */
    function setFlashLoanRates(uint256 _flashLoanFeeRate, uint256 _flashLoanProtocolRate) external;

    /**
     * @notice Borrows without collateral the amounts of tokens from the buckets, transfers them to the receiver.
     * After the call transfers the debts and flashloan fees from the receiver to the buckets and treasury.
     * All of these happens in 1 transaction.
     * @param _receiver The address of the contract that will receive the flash borrowed funds. Must implement the IFlashLoanReceiver interface.
     * @param _buckets The addresses of the buckets from where the assets will be flash borrowed.
     * Buckets should be sorted in ascending order before being passed.
     * @param _amounts The amounts of assets being requested for flash borrow. This needs to contain the same number of entries as assets.
     * @param _params The arbitrary bytes-encoded params that will be passed to executeOperation() method of the receiver contract
     */
    function flashLoan(
        address _receiver,
        address[] calldata _buckets,
        uint256[] calldata _amounts,
        bytes calldata _params
    ) external;
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IPrimexDNS} from "../PrimexDNS/IPrimexDNS.sol";
import {IWhiteBlackList} from "../WhiteBlackList/WhiteBlackList/IWhiteBlackList.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

interface IFlashLoanManagerStorage {
    /**
     * @notice Retrieves the instance of PrimexRegistry contract.
     */
    function registry() external view returns (IAccessControl);

    /**
     * @notice Retrieves the instance of PrimexDNS contract.
     */
    function primexDNS() external view returns (IPrimexDNS);

    /**
     * @notice Retrieves the instance of WhiteBlackList contract.
     */
    function whiteBlackList() external view returns (IWhiteBlackList);

    /**
     * @notice Retrieves the percentage of the flash loan size that is paid by the borrower.
     * Expressed in the WAD format: 1e17 = 10%, 1e18 = 100%, and so forth.
     */
    function flashLoanFeeRate() external view returns (uint256);

    /**
     * @notice Retrieves the percentage of the flash loan fee paid by the borrower that goes to the Treasury.
     * Expressed in the WAD format: 1e17 = 10%, 1e18 = 100%, and so forth.
     */
    function flashLoanProtocolRate() external view returns (uint256);
}

// Copyright 2020 Compound Labs, Inc.
// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.10;

/**
 * @title EIP20NonStandardInterface
 * @dev Version of ERC20 with no return values for `transfer` and `transferFrom`
 *  See https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
 */
interface EIP20NonStandardInterface {
    /**
     * @notice Get the total number of tokens in circulation
     * @return The supply of tokens
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return balance The balance
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transfer` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     */
    function transfer(address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transferFrom` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     */
    function transferFrom(address src, address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `approve` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved
     */
    function approve(address spender, uint256 amount) external;

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return remaining The number of tokens allowed to be spent
     */
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}

pragma solidity ^0.8.18;

/// Precompiled contract that exists in every Arbitrum Nitro chain at 0x000000000000000000000000000000000000006c.
interface IArbGasInfo {
    // get ArbOS's estimate of the L1 gas price in wei
    function getL1BaseFeeEstimate() external view returns (uint256);

    /// @notice Get gas prices. Uses the caller's preferred aggregator, or the default if the caller doesn't have a preferred one.
    /// @return return gas prices in wei
    ///        (
    ///            per L2 tx,
    ///            per L1 calldata byte
    ///            per storage allocation,
    ///            per ArbGas base,
    ///            per ArbGas congestion,
    ///            per ArbGas total
    ///        )
    function getPricesInWei() external view returns (uint256, uint256, uint256, uint256, uint256, uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {PositionLibrary} from "../libraries/PositionLibrary.sol";
import {LimitOrderLibrary} from "../libraries/LimitOrderLibrary.sol";
import {PrimexPricingLibrary} from "../libraries/PrimexPricingLibrary.sol";

interface IConditionalClosingManager {
    /**
     * @notice Checks if a position can be closed.
     * @param _position The position details.
     * @param _params The encoded parameters for closing the position.
     * @param _additionalParams Additional encoded parameters (not used).
     * @param _closeAmount The amount of the position to be closed, measured in the same decimal format as the position's asset.
     * @param _borowedAssetAmount The amount of borrowed asset.
     * @return A boolean indicating whether the position can be closed.
     */
    function canBeClosedAfterSwap(
        PositionLibrary.Position calldata _position,
        bytes calldata _params,
        bytes calldata _additionalParams,
        uint256 _closeAmount,
        uint256 _borowedAssetAmount,
        bytes calldata _positionSoldAssetOracleData
    ) external payable returns (bool);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {LimitOrderLibrary} from "../libraries/LimitOrderLibrary.sol";
import {PrimexPricingLibrary} from "../libraries/PrimexPricingLibrary.sol";

interface IConditionalOpeningManager {
    /**
     * @notice Checks if a limit order can be filled based on the exchange rate.
     * @dev This function compares the exchange rate with the limit price.
     * @param _order The limit order details.
     * @param _params Open condition parameters for the order.
     * @param _additionalParams Additional parameters for the order.
     * @param _exchangeRate The exchange rate in WAD format to compare with the limit price.
     * @return A boolean value indicating if the limit order can be filled based on the exchange rate.
     */
    function canBeFilledAfterSwap(
        LimitOrderLibrary.LimitOrder calldata _order,
        bytes calldata _params,
        bytes calldata _additionalParams,
        uint256 _exchangeRate
    ) external pure returns (bool);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IQuoter} from "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {ICurveCalc} from "./routers/ICurveCalc.sol";
import {ICurveRegistry} from "./routers/ICurveRegistry.sol";
import {PrimexPricingLibrary} from "../libraries/PrimexPricingLibrary.sol";

interface IDexAdapter {
    /**
     * @notice Possible dex types
     */
    enum DexType {
        none, // 0
        UniswapV2, // 1  "uniswap", "sushiswap", "quickswap" (v2)
        UniswapV3, // 2
        Curve, // 3
        Balancer, // 4
        AlgebraV3, // 5
        Meshswap, // 6
        Paraswap, //7
        Enso //8
    }

    /*
     * @param encodedPath Swap path encoded in bytes
     * Encoded differently for different dexes:
     * Uniswap v2 - just encoded array of asset addresses
     * Uniswap v3 - swap path is a sequence of bytes. In Solidity, a path can be built like that:
     *      bytes.concat(bytes20(address(weth)), bytes3(uint24(pool1Fee)), bytes20(address(usdc)), bytes3(uint24(pool2Fee)) ...)
     * Quickswap - swap path is a sequence of bytes. In Solidity, a path can be built like that:
     *      bytes.concat(bytes20(address(weth)), bytes20(address(usdc)), bytes20(address(usdt) ...)
     * Curve - encoded array of asset addresses and pool addresses
     * Balancer - encoded array of asset addresses, pool ids and asset limits
     * @param _amountIn TokenA amount in
     * @param _amountOutMin Min tokenB amount out
     * @param _to Destination address for swap
     * @param _deadline Timestamp deadline for swap
     * @param _dexRouter Dex router address
     */
    struct SwapParams {
        bytes encodedPath;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        address to;
        uint256 deadline;
        address dexRouter;
    }

    /*
     * @param encodedPath Swap path encoded in bytes
     * @param _amountIn TokenA amount in
     * @param _dexRouter Dex router address
     */
    struct GetAmountsParams {
        bytes encodedPath;
        uint256 amount; // amountIn or amountOut
        address dexRouter;
    }

    struct AmountParams {
        address tokenA;
        address tokenB;
        uint256 amount;
        PrimexPricingLibrary.MegaRoute[] megaRoutes;
    }

    struct MegaSwapVars {
        uint256 sumOfShares;
        uint256 amountOnMegaRoute;
        uint256 totalAmount;
        uint256 remainder;
    }

    event QuoterChanged(address indexed dexRouter, address indexed quoter);
    event DexTypeChanged(address indexed dexRouter, uint256 indexed dexType);

    /**
     * @param _dexRouter The router address for which the quoter is set
     * @param _quoter The quoter address to set
     */
    function setQuoter(address _dexRouter, address _quoter) external;

    /**
     * @notice Set a dex type for a dex router
     * @param _dexRouter The dex router address
     * @param _dexType The dex type from enum DexType
     */
    function setDexType(address _dexRouter, uint256 _dexType) external;

    /**
     * @notice Swap ERC20 tokens
     * @param _params SwapParams struct
     */
    function swapExactTokensForTokens(SwapParams memory _params) external payable returns (uint256[3] memory);

    /**
     * @notice Performs chained getAmountOut calculations
     * @notice given an input amount of an asset, returns the maximum output amount of the other asset
     * @param _params GetAmountsParams struct
     */
    function getAmountsOut(GetAmountsParams memory _params) external returns (uint256[3] memory);

    /**
     * @notice Performs chained getAmountIn calculations
     * @notice given an output amount of an asset, returns the maximum input amount of the other asset
     * @param _params GetAmountsParams struct
     */
    function getAmountsIn(GetAmountsParams memory _params) external returns (uint256[3] memory);

    /**
     * @notice Dex type mapping dexRouter => dex type
     */
    function dexType(address) external view returns (DexType);

    /**
     * @notice Mapping from the dexRouter to its quoter
     */
    function quoters(address) external view returns (address);

    /**
     * @return The address of the Registry contract
     */
    function registry() external view returns (address);

    /**
     * @notice Gets the average amount of gas that is required for the swap on some dex
     * @param dexRouter The address of a router
     */
    function getGas(address dexRouter) external view returns (uint256);

    /**
     * @notice perform swap of ERC20 tokens by Path structs
     * @param tokenIn source token
     * @param tokenOut destination token
     * @param amountIn amount in the source token
     * @param receiver destination address for swap
     * @param paths Array of Path structs
     */
    function performPathsSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address receiver,
        PrimexPricingLibrary.Path[] calldata paths
    ) external payable returns (uint256);

    /**
      @notice Performs chained getAmountOut calculations by Path structs
      @dev The function may not support some types of dex, e.g. the Paraswap
     * @param amountIn amount in the source token
     * @param paths Array of Path structs
     */

    function getAmountsOutByPaths(
        uint256 amountIn,
        PrimexPricingLibrary.Path[] calldata paths
    ) external returns (uint256);

    /**
      @notice Performs chained getAmountsIn calculations by Path structs
      @dev The function may not support some types of dex, e.g. the Paraswap
     * @param amountOut amount in the destination token
     * @param paths Array of Path structs
     */

    function getAmountsInByPaths(
        uint256 amountOut,
        PrimexPricingLibrary.Path[] calldata paths
    ) external returns (uint256);

    /**
       @notice perform swap of ERC20 tokens by MegaRoute structs
     * @param _params MegaSwapParams struct
     */
    function performMegaRoutesSwap(
        PrimexPricingLibrary.MegaSwapParams calldata _params
    ) external payable returns (uint256);

    /**
     * @notice perform swap of ERC20 tokens by Route structs
     * @param tokenIn source token
     * @param amountIn amount in the source token
     * @param receiver destination address for swap
     * @param routes Array of Route structs
     */
    function performRoutesSwap(
        address tokenIn,
        uint256 amountIn,
        address receiver,
        PrimexPricingLibrary.Route[] calldata routes
    ) external payable returns (uint256);

    /**
    @notice Performs chained getAmountsOut calculations by Route structs
      @dev The function may not support some types of dex, e.g. the Paraswap
     * @param amountIn amount in the source token
     * @param routes Array of Route structs
     */

    function getAmountsOutByRoutes(
        uint256 amountIn,
        PrimexPricingLibrary.Route[] calldata routes
    ) external returns (uint256);

    /**
       @notice Performs chained getAmountsOut calculations by MegaRoute structs
       @dev The function may not support some types of dex, e.g. the Paraswap
     * @param _params AmountParams struct
     */
    function getAmountOutByMegaRoutes(AmountParams calldata _params) external returns (uint256);

    /**
      @notice Performs chained  getAmountsIn calculations by Route structs
      @dev The function may not support some types of dex, e.g. the Paraswap
     * @param amountOut amountin the destination token
     * @param routes Array of Route structs
     */

    function getAmountsInByRoutes(
        uint256 amountOut,
        PrimexPricingLibrary.Route[] calldata routes
    ) external returns (uint256);

    /**
       @notice Performs chained getAmountsIn calculations by MegaRoute structs
       @dev The function may not support some types of dex, e.g. the Paraswap
     * @param _params AmountParams struct
     */
    function getAmountInByMegaRoutes(AmountParams calldata _params) external returns (uint256);

    receive() external payable;

    /**
     * @notice  Initializes the DexAdapter contract.
     * @dev This function should only be called once during the initial setup of the contract.
     * @param _primexDNS The address of the PrimexDNS contract.
     */
    function initialize(address _primexDNS) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

/**
 * @title IFlashLoanReceiver
 * @notice Defines the basic interface of a flashloan-receiver contract.
 * @dev Implement this interface to develop a flashloan-compatible flashLoanReceiver contract
 */
interface IFlashLoanReceiver {
    /**
     * @notice Executes an operation after receiving the flash-borrowed assets
     * @dev Ensure that the contract can return the debt + flashLoanFee, e.g., has
     * enough funds to repay and has approved the FlashLoanManager to pull the total amount
     * @param assets The addresses of the flash-borrowed assets
     * @param amounts The amounts of the flash-borrowed assets
     * @param flashLoanFees The fee of each flash-borrowed asset
     * @param initiator The address of the flashloan initiator
     * @param params The byte-encoded params passed when initiating the flashloan
     * @return True if the execution of the operation succeeds, false otherwise
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata flashLoanFees,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IInterestRateStrategy {
    /**
     * @dev parameters for BAR calculation - they differ depending on bucket's underlying asset
     */
    struct BarCalculationParams {
        uint256 urOptimal;
        uint256 k0;
        uint256 k1;
        uint256 b0;
        int256 b1;
    }

    event BarCalculationParamsChanged(
        address indexed bucket,
        uint256 urOptimal,
        uint256 k0,
        uint256 k1,
        uint256 b0,
        int256 b1
    );

    /**
     * @dev Updates bucket's BAR and LAR.
     * Calculates using utilization ratio (UR):
     * BAR = UR <= URoptimal ? (k0 * UR + b0) : (k1 * UR + b1), where 'b1' may be < 0,
     * LAR = BAR * UR,
     * if reserveRate != 0, then LAR = LAR * (1 - reserveRate)
     * @param ur Utilization ratio
     * @param reserveRate The reserve portion of the interest that goes to the Primex reserve
     * @return tuple containing BAR and LAR
     */

    function calculateInterestRates(uint256 ur, uint256 reserveRate) external returns (uint128, uint128);

    /**
     * @dev Set parameters for BAR calculation.
     * @param _params parameters are represented in byte string
     */

    function setBarCalculationParams(bytes memory _params) external;

    /**
     * @dev Retrieves the calculation parameters for the Bar calculation.
     * @param _address an address of the bucket
     * @return BarCalculationParams struct containing the parameters.
     */
    function getBarCalculationParams(address _address) external view returns (BarCalculationParams memory);
}

pragma solidity ^0.8.18;

/// Precompiled contract that exist on opBNB chain at 0x420000000000000000000000000000000000000F.
interface IOVM_GasPriceOracle {
    /// @notice Retrieves the latest known L1 base fee.
    /// @return Latest known L1 base fee.
    function l1BaseFee() external view returns (uint256);

    /// @notice Retrieves the current fee overhead.
    /// @return Current fee overhead.
    function overhead() external view returns (uint256);

    /// @notice Retrieves the current fee scalar.
    /// @return Current fee scalar.
    function scalar() external view returns (uint256);
}

// Copyright (c) 2016-2024 zOS Global Limited and contributors
// SPDX-License-Identifier: MIT

// Interface for OpenZeppelin's Pausable contract from https://github.com/OpenZeppelin/openzeppelin-contracts/
pragma solidity ^0.8.18;

interface IPausable {
    /**
     * @dev Triggers stopped state.
     * This function can only be called by an address with the EMERGENCY_ADMIN role.
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external;

    /**
     * @dev Returns to normal state.
     * This function can only be called by an address with the SMALL_TIMELOCK_ADMIN or MEDIUM_TIMELOCK_ADMIN role depending on the contract.
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ISupraOraclePull {
    //Verified price data
    struct PriceData {
        // List of pairs
        uint256[] pairs;
        // List of prices
        // prices[i] is the price of pairs[i]
        uint256[] prices;
        // List of decimals
        // decimals[i] is the decimals of pairs[i]
        uint256[] decimals;
    }

    function verifyOracleProof(bytes calldata _bytesproof) external returns (PriceData memory);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/* solhint-disable var-name-mixedcase */
interface ISupraSValueFeed {
    struct derivedData {
        int256 roundDifference;
        uint256 derivedPrice;
        uint256 decimals;
    }

    struct priceFeed {
        uint256 round;
        uint256 decimals;
        uint256 time;
        uint256 price;
    }

    function getDerivedSvalue(
        uint256 pair_id_1,
        uint256 pair_id_2,
        uint256 operation
    ) external view returns (derivedData memory);

    function getSvalue(uint256 _pairIndex) external view returns (priceFeed memory);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {PositionLibrary} from "../libraries/PositionLibrary.sol";
import {PrimexPricingLibrary} from "../libraries/PrimexPricingLibrary.sol";

interface ITakeProfitStopLossCCM {
    struct CanBeClosedParams {
        uint256 takeProfitPrice;
        uint256 stopLossPrice;
    }

    /**
     * @notice Checks if the take profit has been reached based on the given parameters.
     * @dev Used in closeBatchPositions() function.
     * @param _params The encoded parameters.
     * @param exchangeRate The exchange rate in WAD format.
     * @return A boolean indicating whether the take profit has been reached.
     */
    function isTakeProfitReached(bytes calldata _params, uint256 exchangeRate) external view returns (bool);

    /**
     * @notice Checks if the stop loss price has been reached for a given position.
     * @param _position The position details.
     * @param _stopLossPrice The stop loss price in WAD format to compare against.
     * @return True if the stop loss price is reached, false otherwise.
     */
    function isStopLossReached(
        PositionLibrary.Position calldata _position,
        uint256 _stopLossPrice,
        bytes calldata _positionSoldAssetOracleData
    ) external returns (bool);

    /**
     * @notice Checks if the stop loss price has been reached on the given parameters.
     * @dev The takeProfitPrice and stopLossPrice values can be obtained from the encoded data via CanBeClosedParams struct.
     * @param _params The encoded closing condition parameters containing stop loss price.
     * @param oracleExchangeRate The current exchange rate from the oracle in WAD format.
     * @return True if the stop loss price is reached, false otherwise.
     */
    function isStopLossReached(bytes calldata _params, uint256 oracleExchangeRate) external view returns (bool);

    /**
     * @notice Retrieves the take profit and stop loss prices from the given parameters.
     * @param _params The encoded parameters for closing a position.
     * @return takeProfitPrice The take profit price.
     * @return stopLossPrice The stop loss price.
     */
    function getTakeProfitStopLossPrices(bytes calldata _params) external view returns (uint256, uint256);

    /**
     * @notice Initializes the TakeProfitStopLossCCM contract.
     * @dev This function should only be called once during the initial setup of the contract.
     * @param _primexDNS The address of the PrimexDNS contract.
     * @param _priceOracle The address of the PriceOracle contract.
     */
    function initialize(address _primexDNS, address _priceOracle) external;
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface ICurveCalc {
    // solhint-disable func-name-mixedcase
    function get_dx(
        // solhint-disable-next-line var-name-mixedcase
        int128 n_coins,
        uint256[8] memory balances,
        uint256 amp,
        uint256 fee,
        uint256[8] memory rates,
        uint256[8] memory precisions,
        bool underlying,
        int128 i,
        int128 j,
        uint256 dy
    ) external pure returns (uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface ICurveRegistry {
    // solhint-disable func-name-mixedcase
    function get_n_coins(address _pool) external view returns (uint256[2] memory);

    function get_rates(address _pool) external view returns (uint256[8] memory);

    function get_coin_indices(address _pool, address _from, address _to) external view returns (int128, int128, bool);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IKeeperRewardDistributorStorage, IKeeperRewardDistributorStorageV2} from "./IKeeperRewardDistributorStorage.sol";
import {IPausable} from "../interfaces/IPausable.sol";

interface IKeeperRewardDistributorV3 is IKeeperRewardDistributorStorageV2, IPausable {
    struct DecreasingGasByReasonParams {
        DecreasingReason reason;
        uint256 amount;
    }
    struct MaxGasPerPositionParams {
        KeeperActionType actionType;
        KeeperActionRewardConfig config;
    }

    /**
     * @dev     Params for initialize() function
     * @param   priceOracle Address of the PriceOracle contract
     * @param   registry Address of the Registry contract
     * @param   pmx Address of PMXToken
     * @param   treasury Address of the Treasury contract
     * @param   pmxPartInReward Percentage of PMX in reward (in WAD)
     * @param   nativePartInReward  Percentage of native token in reward (in WAD)
     * @param   positionSizeCoefficient The reward param which is needed to calculate rewards, in WAD
     * @param   additionalGas Additional gas added to actual gas spent
     * @param   defaultMaxGasPrice Max gas price allowed during reward calculation (used when no oracle price found)
     * @param   oracleGasPriceTolerance Percentage by which oracle gas price can be exceeded (in WAD)
     * @param   paymentModel The model of payment for gas in the network
     * @param   maxGasPerPositionParams Parameters for the setMaxGasPerPosition function
     * @param   decreasingGasByReasonParams Parameters for the setDecreasingGasByReason function
     */
    struct InitParams {
        address priceOracle;
        address registry;
        address pmx;
        address treasury;
        address whiteBlackList;
        uint256 pmxPartInReward;
        uint256 nativePartInReward;
        uint256 positionSizeCoefficient;
        uint256 additionalGas;
        uint256 defaultMaxGasPrice;
        uint256 oracleGasPriceTolerance;
        PaymentModel paymentModel;
        MaxGasPerPositionParams[] maxGasPerPositionParams;
        DecreasingGasByReasonParams[] decreasingGasByReasonParams;
    }

    event ClaimFees(address indexed keeper, address indexed asset, uint256 amount);
    event DefaultMaxGasPriceChanged(uint256 indexed defaultMaxGasPrice);
    event OracleGasPriceToleranceChanged(uint256 indexed oracleGasPriceTolerance);
    event MaxGasPerPositionChanged(KeeperActionType indexed actionType, KeeperActionRewardConfig config);
    event DataLengthRestrictionsChanged(KeeperCallingMethod callingMethod, uint256 maxRoutesLength, uint256 baseLength);
    event DecreasingGasByReasonChanged(DecreasingReason indexed reason, uint256 amount);
    event PmxPartInRewardChanged(uint256 indexed pmxPartInReward);
    event NativePartInRewardChanged(uint256 indexed nativePartInReward);
    event PositionSizeCoefficientChanged(uint256 indexed positionSizeCoefficient);
    event AdditionalGasChanged(uint256 indexed additionalGas);
    event KeeperRewardUpdated(address indexed keeper, uint256 rewardInPmx, uint256 rewardInNativeCurrency);
    event MinPositionSizeAddendChanged(uint256 newMinPositionSizeAddend);
    event OptimisticGasCoefficientChanged(uint256 newOptimismGasCoefficient);

    /**
     * @notice Initializes the KeeperRewardDistributor contract.
     * @param _params  Parameters for initialization
     */
    function initialize(InitParams calldata _params) external;

    /**
     * @dev Params for the updateReward function
     * @param keeper  Address of the keeper
     * @param positionAsset  Address of the position asset
     * @param positionSize  Size of the position
     * @param action  The action that was performed by the keeper
     * @param numberOfActions  Number of actions performed by the keeper
     * @param gasSpent Gas spent on executing transaction
     * @param decreasingCounter An array where each index contains the number of decreasing reasons according to the DecreasingReason enum
     * @param routesLength  The length of routes provided as input to the protocol function,
     * subject to an additional commission in the ARBITRUM payment model.
     */

    struct UpdateRewardParams {
        address keeper;
        address positionAsset;
        uint256 positionSize;
        KeeperActionType action;
        uint256 numberOfActions;
        uint256 gasSpent;
        uint256[] decreasingCounter;
        uint256 routesLength;
        bytes nativePmxOracleData;
        bytes positionNativeAssetOracleData;
    }

    /**
     * @notice Updates reward for keeper for closing position or executing order
     * @dev Only callable by the PM_ROLE, LOM_ROLE, BATCH_MANAGER_ROLE roles.
     * @param _params The UpdateRewardParams params
     */
    function updateReward(UpdateRewardParams calldata _params) external;

    /**
     * @notice Claims earned reward of the keeper
     * @param _pmxAmount  Amount of PMX token to claim
     * @param _nativeAmount  Amount of native token to claim
     */
    function claim(uint256 _pmxAmount, uint256 _nativeAmount) external;

    /**
     * @notice Sets the default maximum gas price allowed.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _defaultMaxGasPrice The new default maximum gas price value.
     */
    function setDefaultMaxGasPrice(uint256 _defaultMaxGasPrice) external;

    /**
     * @notice Sets the amount of gas to be removed for the specified reason
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _reason The reason for which an amount is set
     * @param _amount Gas amount.
     */
    function setDecreasingGasByReason(DecreasingReason _reason, uint256 _amount) external;

    /**
     * @notice Sets the KeeperActionRewardConfig for the specified action type
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _actionType The action type for which the config is set
     * @param _config The KeeperActionRewardConfig struct
     */

    function setMaxGasPerPosition(KeeperActionType _actionType, KeeperActionRewardConfig calldata _config) external;

    /**
     * @notice Sets the dataLengthRestrictions for the specified KeeperCallingMethod.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _callingMethod The calling method for which dataLengthRestrictions is set
     * @param _maxRoutesLength The maximum routes length for which an additional fee will be paid in the ARBITRUM payment model, in bytes
     * @param _baseLength The length of the data entering the protocol function including method signature
     * and excluding dynamic types(e.g, routesLength), in bytes
     */
    function setDataLengthRestrictions(
        KeeperCallingMethod _callingMethod,
        uint256 _maxRoutesLength,
        uint256 _baseLength
    ) external;

    /**
     * @notice Sets the tolerance for gas price fluctuations from the oracle price.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _oracleGasPriceTolerance The new oracle gas price tolerance value (percent expressed as WAD).
     */
    function setOracleGasPriceTolerance(uint256 _oracleGasPriceTolerance) external;

    /**
     * @notice Sets the PMX token's portion in the reward calculation.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _pmxPartInReward The new PMX token's portion in the reward calculation (percent expressed as WAD).
     */
    function setPmxPartInReward(uint256 _pmxPartInReward) external;

    /**
     * @notice Sets the native token's portion in the reward calculation.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _nativePartInReward The new native token's portion in the reward calculation (percent expressed as WAD).
     */
    function setNativePartInReward(uint256 _nativePartInReward) external;

    /**
     * @notice Sets the position size coefficients for reward calculations.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _positionSizeCoefficient The new positionSizeCoefficient value (in WAD).
     */
    function setPositionSizeCoefficient(uint256 _positionSizeCoefficient) external;

    /**
     * @notice Sets the additional gas value for reward calculations.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _additionalGas The new additionalGas value.
     */
    function setAdditionalGas(uint256 _additionalGas) external;

    /**
     * @notice Sets the minPositionSizeAddend for reward calculations.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _minPositionSizeAddend The new minPositionSizeAddend value (in WAD).
     */

    function setMinPositionSizeAddend(uint256 _minPositionSizeAddend) external;

    /**
     * @notice Retrieves gas calculation params.
     *
     * @return oracleGasPriceTolerance The tolerance for gas price fluctuations based on the oracle.
     * @return defaultMaxGasPrice The default maximum gas price allowed.
     */
    function getGasCalculationParams() external view returns (uint256, uint256, uint256, PaymentModel);

    /**
     * @notice Sets the optimisticGasCoefficient for optimism paymentModel.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _newOptimisticGasCoefficient The new optimisticGasCoefficient value (in WAD).
     */
    function setOptimisticGasCoefficient(uint256 _newOptimisticGasCoefficient) external;
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IKeeperRewardDistributorStorage {
    enum DecreasingReason {
        NonExistentIdForLiquidation,
        NonExistentIdForSLOrTP,
        IncorrectConditionForLiquidation,
        IncorrectConditionForSL,
        ClosePostionInTheSameBlock
    }

    enum KeeperActionType {
        OpenByOrder,
        StopLoss,
        TakeProfit,
        Liquidation,
        BucketDelisted
    }

    enum KeeperCallingMethod {
        ClosePositionByCondition,
        OpenPositionByOrder,
        CloseBatchPositions
    }

    /**
     * @dev Structure used in the calculation of keeper rewards in the ARBITRUM payment model
     * @param maxRoutesLength The maximum length of routes for which will be paid keeper rewards, depending on KeeperCallingMethod
     * @param baseLength The static length of the data entering the protocol function, depending on KeeperCallingMethod
     */
    struct DataLengthRestrictions {
        uint256 maxRoutesLength;
        uint256 baseLength;
    }

    /**
     * @dev Structure used in the calculation of maximum gas per position
     * @param baseMaxGas1 Base gas amount that used to calculate max gas amount
     * @param baseMaxGas2 Base gas amount that used to calculate max gas amount when number of keeper actions > inflectionPoint
     * @param multiplier2 The multiplier which is multiplied by the number of keeper actions when number of keeper actions > inflectionPoint
     * @param inflectionPoint Number of actions after which the multiplier2 takes effect
     */
    struct KeeperActionRewardConfig {
        uint256 baseMaxGas1;
        uint256 baseMaxGas2;
        uint256 multiplier1;
        uint256 multiplier2;
        uint256 inflectionPoint;
    }

    struct KeeperBalance {
        uint256 pmxBalance;
        uint256 nativeBalance;
    }
    enum PaymentModel {
        DEFAULT,
        ARBITRUM,
        OPTIMISTIC
    }

    function priceOracle() external view returns (address);

    function registry() external view returns (address);

    function pmx() external view returns (address);

    function treasury() external view returns (address payable);

    function pmxPartInReward() external view returns (uint256);

    function nativePartInReward() external view returns (uint256);

    function positionSizeCoefficient() external view returns (uint256);

    function positionSizeCoefficientB() external view returns (int256);

    function additionalGas() external view returns (uint256);

    function defaultMaxGasPrice() external view returns (uint256);

    function oracleGasPriceTolerance() external view returns (uint256);

    function paymentModel() external view returns (PaymentModel);

    function keeperBalance(address) external view returns (uint256, uint256);

    function maxGasPerPosition(KeeperActionType) external view returns (uint256, uint256, uint256, uint256, uint256);

    function dataLengthRestrictions(KeeperCallingMethod) external view returns (uint256, uint256);

    function decreasingGasByReason(DecreasingReason) external view returns (uint256);

    function totalBalance() external view returns (uint256, uint256);
}

interface IKeeperRewardDistributorStorageV2 is IKeeperRewardDistributorStorage {
    function minPositionSizeAddend() external view returns (uint256);

    function optimisticGasCoefficient() external view returns (uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

// solhint-disable-next-line func-visibility
function _require(bool condition, bytes4 selector) pure {
    if (!condition) _revert(selector);
}

// solhint-disable-next-line func-visibility
function _revert(bytes4 selector) pure {
    // solhint-disable-next-line no-inline-assembly
    assembly ("memory-safe") {
        let free_mem_ptr := mload(64)
        mstore(free_mem_ptr, selector)
        revert(free_mem_ptr, 4)
    }
}

library Errors {
    event Log(bytes4 error);

    //common
    error ADDRESS_NOT_SUPPORTED();
    error FORBIDDEN();
    error AMOUNT_IS_0();
    error CALLER_IS_NOT_TRADER();
    error CONDITION_INDEX_IS_OUT_OF_BOUNDS();
    error INVALID_PERCENT_NUMBER();
    error INVALID_SECURITY_BUFFER();
    error INVALID_MAINTENANCE_BUFFER();
    error TOKEN_ADDRESS_IS_ZERO();
    error IDENTICAL_TOKEN_ADDRESSES();
    error ASSET_DECIMALS_EXCEEDS_MAX_VALUE();
    error CAN_NOT_ADD_WITH_ZERO_ADDRESS();
    error SHOULD_BE_DIFFERENT_ASSETS_IN_SPOT();
    error TOKEN_NOT_SUPPORTED();
    error INSUFFICIENT_DEPOSIT();
    error SHOULD_NOT_HAVE_DUPLICATES();
    error SWAP_DEADLINE_PASSED();
    // error LIMIT_PRICE_IS_ZERO();
    error BUCKET_IS_NOT_ACTIVE();
    error DIFFERENT_DATA_LENGTH();
    error RECIPIENT_OR_SENDER_MUST_BE_ON_WHITE_LIST();
    error SLIPPAGE_TOLERANCE_EXCEEDED();
    error OPERATION_NOT_SUPPORTED();
    error SENDER_IS_BLACKLISTED();
    error NATIVE_CURRENCY_CANNOT_BE_ASSET();
    error INVALID_AMOUNT();
    error POOL_CALL_FAILED();

    // bonus executor
    error CALLER_IS_NOT_NFT();
    error BONUS_FOR_BUCKET_ALREADY_ACTIVATED();
    error WRONG_LENGTH();
    error BONUS_DOES_NOT_EXIST();
    error CALLER_IS_NOT_DEBT_TOKEN();
    error CALLER_IS_NOT_P_TOKEN();
    error MAX_BONUS_COUNT_EXCEEDED();
    error TIER_IS_NOT_ACTIVE();
    error BONUS_PERCENT_IS_ZERO();

    // bucket
    error INCORRECT_LIQUIDITY_MINING_PARAMS();
    error PAIR_PRICE_DROP_IS_NOT_CORRECT();
    error ASSET_IS_NOT_SUPPORTED();
    error BUCKET_OUTSIDE_PRIMEX_PROTOCOL();
    error DEADLINE_IS_PASSED();
    error DEADLINE_IS_NOT_PASSED();
    error BUCKET_IS_NOT_LAUNCHED();
    error BURN_AMOUNT_EXCEEDS_PROTOCOL_DEBT();
    error LIQUIDITY_INDEX_OVERFLOW();
    error BORROW_INDEX_OVERFLOW();
    error BAR_OVERFLOW();
    error LAR_OVERFLOW();
    error UR_IS_MORE_THAN_1();
    error ASSET_ALREADY_SUPPORTED();
    error DEPOSIT_IS_MORE_AMOUNT_PER_USER();
    error DEPOSIT_EXCEEDS_MAX_TOTAL_DEPOSIT();
    error MINING_AMOUNT_WITHDRAW_IS_LOCKED_ON_STABILIZATION_PERIOD();
    error WITHDRAW_RATE_IS_MORE_10_PERCENT();
    error INVALID_FEE_BUFFER();
    error RESERVE_RATE_SHOULD_BE_LESS_THAN_1();
    error MAX_TOTAL_DEPOSIT_IS_ZERO();
    error AMOUNT_SCALED_SHOULD_BE_GREATER_THAN_ZERO();
    error NOT_ENOUGH_LIQUIDITY_IN_THE_BUCKET();

    // p/debt token, PMXToken
    error BUCKET_IS_IMMUTABLE();
    error INVALID_MINT_AMOUNT();
    error INVALID_BURN_AMOUNT();
    error TRANSFER_NOT_SUPPORTED();
    error APPROVE_NOT_SUPPORTED();
    error CALLER_IS_NOT_BUCKET();
    error CALLER_IS_NOT_A_BUCKET_FACTORY();
    error CALLER_IS_NOT_P_TOKEN_RECEIVER();
    error DURATION_MUST_BE_MORE_THAN_0();
    error INCORRECT_ID();
    error THERE_ARE_NO_LOCK_DEPOSITS();
    error LOCK_TIME_IS_NOT_EXPIRED();
    error TRANSFER_AMOUNT_EXCEED_ALLOWANCE();
    error CALLER_IS_NOT_A_MINTER();
    error ACTION_ONLY_WITH_AVAILABLE_BALANCE();
    error FEE_DECREASER_CALL_FAILED();
    error TRADER_REWARD_DISTRIBUTOR_CALL_FAILED();
    error INTEREST_INCREASER_CALL_FAILED();
    error LENDER_REWARD_DISTRIBUTOR_CALL_FAILED();
    error DEPOSIT_DOES_NOT_EXIST();
    error RECIPIENT_IS_BLACKLISTED();

    //LOM
    error ORDER_CAN_NOT_BE_FILLED();
    error ORDER_DOES_NOT_EXIST();
    error ORDER_IS_NOT_SPOT();
    error LEVERAGE_MUST_BE_MORE_THAN_1();
    error CANNOT_CHANGE_SPOT_ORDER_TO_MARGIN();
    error SHOULD_HAVE_OPEN_CONDITIONS();
    error INCORRECT_LEVERAGE();
    error INCORRECT_DEADLINE();
    error LEVERAGE_SHOULD_BE_1();
    error LEVERAGE_EXCEEDS_MAX_LEVERAGE();
    error SHOULD_OPEN_POSITION();
    error IS_SPOT_ORDER();
    error SHOULD_NOT_HAVE_CLOSE_CONDITIONS();
    error ORDER_HAS_EXPIRED();
    error INCORRECT_BORROWED_AMOUNT();

    // LiquidityMiningRewardDistributor
    error BUCKET_IS_NOT_STABLE();
    error ATTEMPT_TO_WITHDRAW_MORE_THAN_DEPOSITED();
    error WITHDRAW_PMX_BY_ADMIN_FORBIDDEN();

    // nft
    error TOKEN_IS_BLOCKED();
    error ONLY_MINTERS();
    error PROGRAM_IS_NOT_ACTIVE();
    error CALLER_IS_NOT_OWNER();
    error TOKEN_IS_ALREADY_ACTIVATED();
    error WRONG_NETWORK();
    error ID_DOES_NOT_EXIST();
    error WRONG_URIS_LENGTH();

    // PM
    error ASSET_ADDRESS_NOT_SUPPORTED();
    error IDENTICAL_ASSET_ADDRESSES();
    error POSITION_DOES_NOT_EXIST();
    error AMOUNT_IS_MORE_THAN_POSITION_AMOUNT();
    error BORROWED_AMOUNT_IS_ZERO();
    error IS_SPOT_POSITION();
    error AMOUNT_IS_MORE_THAN_DEPOSIT();
    error DECREASE_AMOUNT_IS_ZERO();
    error INSUFFICIENT_DEPOSIT_SIZE();
    error IS_NOT_RISKY_OR_CANNOT_BE_CLOSED();
    error BUCKET_SHOULD_BE_UNDEFINED();
    error DEPOSIT_IN_THIRD_ASSET_ROUTES_LENGTH_SHOULD_BE_0();
    error POSITION_CANNOT_BE_CLOSED_FOR_THIS_REASON();
    error ADDRESS_IS_ZERO();
    error WRONG_TRUSTED_MULTIPLIER();
    error POSITION_SIZE_EXCEEDED();
    error POSITION_BUCKET_IS_INCORRECT();
    error THERE_MUST_BE_AT_LEAST_ONE_POSITION();
    error NOTHING_TO_CLOSE();

    // BatchManager
    error PARAMS_LENGTH_MISMATCH();
    error BATCH_CANNOT_BE_CLOSED_FOR_THIS_REASON();
    error CLOSE_CONDITION_IS_NOT_CORRECT();
    error SOLD_ASSET_IS_INCORRECT();

    // Price Oracle
    error THERE_IS_DIRECT_ROUTE();
    error ZERO_EXCHANGE_RATE();
    error NO_PRICEFEED_FOUND();
    error NO_PRICE_DROP_FEED_FOUND();
    error WRONG_ORACLE_ROUTES_LENGTH();
    error WRONG_ASSET_B();
    error INCORRECT_ROUTE_SEQUENCE();
    error INCORRECT_PYTH_PRICE();
    error TOKEN_PAIR_IS_NOT_TRUSTED();
    error INCORRECT_TOKEN_TO();
    error INCORRECT_PYTH_ROUTE();
    error INCORRECT_CHAINLINK_ROUTE();
    error NOT_ENOUGH_MSG_VALUE();
    error PUBLISH_TIME_EXCEEDS_THRESHOLD_TIME();
    //DNS
    error INCORRECT_FEE_RATE();
    error INCORRECT_RESTRICTIONS();
    error BUCKET_ALREADY_FROZEN();
    error BUCKET_IS_ALREADY_ADDED();
    error DEX_IS_ALREADY_ACTIVATED();
    error DEX_IS_ALREADY_FROZEN();
    error DEX_IS_ALREADY_ADDED();
    error BUCKET_NOT_ADDED();
    error BUCKET_ALREADY_ACTIVATED();
    error DEX_NOT_ADDED();
    error BUCKET_IS_INACTIVE();
    error WITHDRAWAL_NOT_ALLOWED();
    error BUCKET_IS_ALREADY_DEPRECATED();
    error LEVERAGE_TOLERANCE_IS_NOT_CORRECT();

    // Primex upkeep
    error NUMBER_IS_0();

    //referral program, WhiteBlackList
    error CALLER_ALREADY_REGISTERED();
    error MISMATCH();
    error PARENT_NOT_WHITELISTED();
    error ADDRESS_ALREADY_WHITELISTED();
    error ADDRESS_ALREADY_BLACKLISTED();
    error ADDRESS_NOT_BLACKLISTED();
    error ADDRESS_NOT_WHITELISTED();
    error ADDRESS_NOT_UNLISTED();
    error ADDRESS_IS_WHITELISTED();
    error ADDRESS_IS_NOT_CONTRACT();

    //Reserve
    error BURN_AMOUNT_IS_ZERO();
    error CALLER_IS_NOT_EXECUTOR();
    error ADDRESS_NOT_PRIMEX_BUCKET();
    error NOT_SUFFICIENT_RESERVE_BALANCE();
    error INCORRECT_TRANSFER_RESTRICTIONS();

    //Vault
    error AMOUNT_EXCEEDS_AVAILABLE_BALANCE();
    error INSUFFICIENT_FREE_ASSETS();
    error CALLER_IS_NOT_SPENDER();

    //Pricing Library
    error IDENTICAL_ASSETS();
    error SUM_OF_SHARES_SHOULD_BE_GREATER_THAN_ZERO();
    error DIFFERENT_PRICE_DEX_AND_ORACLE();
    error LEVERAGE_TOLERANCE_EXCEEDED();
    error TAKE_PROFIT_IS_LTE_LIMIT_PRICE();
    error STOP_LOSS_IS_GTE_LIMIT_PRICE();
    error STOP_LOSS_IS_LTE_LIQUIDATION_PRICE();
    error INSUFFICIENT_POSITION_SIZE();
    error INCORRECT_PATH();
    error DEPOSITED_TO_BORROWED_ROUTES_LENGTH_SHOULD_BE_0();
    error INCORRECT_CM_TYPE();
    error FEE_RATE_IN_NATIVE_IS_ZERO();
    error MIN_PROTOCOL_FEE_IS_GREATER_THAN_PAYMENT_AMOUNT();

    // Token transfers
    error TOKEN_TRANSFER_IN_FAILED();
    error TOKEN_TRANSFER_IN_OVERFLOW();
    error TOKEN_TRANSFER_OUT_FAILED();
    error TOKEN_APPROVE_FAILED();
    error NATIVE_TOKEN_TRANSFER_FAILED();

    // Conditional Managers
    error LOW_PRICE_ROUND_IS_LESS_HIGH_PRICE_ROUND();
    error TRAILING_DELTA_IS_INCORRECT();
    error DATA_FOR_ROUND_DOES_NOT_EXIST();
    error HIGH_PRICE_TIMESTAMP_IS_INCORRECT();
    error NO_PRICE_FEED_INTERSECTION();
    error SHOULD_BE_CCM();
    error SHOULD_BE_COM();

    //Lens
    error DEPOSITED_AMOUNT_IS_0();
    error SPOT_DEPOSITED_ASSET_SHOULD_BE_EQUAL_BORROWED_ASSET();
    error ZERO_ASSET_ADDRESS();
    error ASSETS_SHOULD_BE_DIFFERENT();
    error ZERO_SHARES();
    error SHARES_AMOUNT_IS_GREATER_THAN_AMOUNT_TO_SELL();
    error NO_ACTIVE_DEXES();

    //Bots
    error WRONG_BALANCES();
    error INVALID_INDEX();
    error INVALID_DIVIDER();
    error ARRAYS_LENGTHS_IS_NOT_EQUAL();
    error DENOMINATOR_IS_0();

    //DexAdapter
    error ZERO_AMOUNT_IN();
    error ZERO_AMOUNT();
    error UNKNOWN_DEX_TYPE();
    error REVERTED_WITHOUT_A_STRING_TRY_TO_CHECK_THE_ANCILLARY_DATA();
    error DELTA_OF_TOKEN_OUT_HAS_POSITIVE_VALUE();
    error DELTA_OF_TOKEN_IN_HAS_NEGATIVE_VALUE();
    error QUOTER_IS_NOT_PROVIDED();
    error DEX_ROUTER_NOT_SUPPORTED();
    error QUOTER_NOT_SUPPORTED();

    //SpotTradingRewardDistributor
    error PERIOD_DURATION_IS_ZERO();
    error REWARD_AMOUNT_IS_ZERO();
    error REWARD_PER_PERIOD_IS_NOT_CORRECT();

    //ActivityRewardDistributor
    error TOTAL_REWARD_AMOUNT_IS_ZERO();
    error REWARD_PER_DAY_IS_NOT_CORRECT();
    error ZERO_BUCKET_ADDRESS();
    //KeeperRewardDistributor
    error INCORRECT_PART_IN_REWARD();
    error INCORRECT_MULTIPLIER();
    error INCORRECT_OPTIMISM_GAS_COEFFICIENT();

    //Treasury
    error TRANSFER_RESTRICTIONS_NOT_MET();
    error INSUFFICIENT_NATIVE_TOKEN_BALANCE();
    error INSUFFICIENT_TOKEN_BALANCE();
    error EXCEEDED_MAX_AMOUNT_DURING_TIMEFRAME();
    error EXCEEDED_MAX_SPENDING_LIMITS();
    error SPENDING_LIMITS_ARE_INCORRECT();
    error SPENDER_IS_NOT_EXIST();

    //FlashLoan
    error INCONSISTENT_FLASHLOAN_PARAMS();
    error INVALID_FLASHLOAN_EXECUTOR_RETURN();
    error FLASH_LOAN_FEE_RATE_IS_MORE_10_PERCENT();
    error FLASH_LOAN_PROTOCOL_RATE_IS_MORE_50_PERCENT();
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {WadRayMath} from "./utils/WadRayMath.sol";

import {PrimexPricingLibrary} from "./PrimexPricingLibrary.sol";
import {TokenTransfersLibrary} from "./TokenTransfersLibrary.sol";

import {NATIVE_CURRENCY} from "../Constants.sol";
import {ITraderBalanceVault} from "../TraderBalanceVault/ITraderBalanceVault.sol";
import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {IPrimexDNSStorageV3} from "../PrimexDNS/IPrimexDNSStorage.sol";
import {IPriceOracleV2} from "../PriceOracle/IPriceOracle.sol";
import {IBucketV3} from "../Bucket/IBucket.sol";
import {IConditionalOpeningManager} from "../interfaces/IConditionalOpeningManager.sol";
import {IConditionalClosingManager} from "../interfaces/IConditionalClosingManager.sol";
import {IPositionManagerV2} from "../PositionManager/IPositionManager.sol";
import {ISwapManager} from "../SwapManager/ISwapManager.sol";

import "./Errors.sol";

library LimitOrderLibrary {
    using WadRayMath for uint256;

    enum CloseReason {
        FilledMargin,
        FilledSpot,
        FilledSwap,
        Cancelled
    }

    struct Condition {
        uint256 managerType;
        bytes params;
    }

    /**
     * @dev Creates a limit order and locks the deposit asset in the traderBalanceVault
     * @param bucket The bucket, from which the loan will be taken
     * @param positionAsset The address of output token for exchange
     * @param depositAsset The address of the deposit token
     * @param depositAmount The amount of deposit trader funds for deal
     * @param feeToken An asset in which the fee will be paid. At this point it could be the pmx, the epmx or a positionAsset
     * @param trader The trader, who has created the order
     * @param deadline Unix timestamp after which the order will not be filled
     * @param id The unique id of the order
     * @param leverage leverage for trading
     * @param shouldOpenPosition The flag to indicate whether position should be opened
     * @param createdAt The timeStamp when the order was created
     * @param updatedConditionsAt The timestamp when the open condition was updated
     */
    struct LimitOrder {
        IBucketV3 bucket;
        address positionAsset;
        address depositAsset;
        uint256 depositAmount;
        address feeToken;
        uint256 protocolFee;
        address trader;
        uint256 deadline;
        uint256 id;
        uint256 leverage;
        bool shouldOpenPosition;
        uint256 createdAt;
        uint256 updatedConditionsAt;
        // The byte-encoded params, can be used for future updates
        bytes extraParams;
    }

    /**
     * @dev Structure for the сreateLimitOrder with parameters necessary to create limit order
     * @param bucket The bucket, from which the loan will be taken
     * @param depositAsset The address of the deposit token (collateral for margin trade or
     * locked funds for spot)
     * @param depositAmount The amount of deposit funds for deal
     * @param positionAsset The address output token for exchange
     * @param deadline Unix timestamp after which the order will not be filled
     * @param takeDepositFromWallet Bool, add a collateral deposit within the current transaction
     * @param leverage leverage for trading
     * @param shouldOpenPosition Bool, indicate whether position should be opened
     * @param openingManagerAddresses Array of contract addresses that will be called in canBeFilled
     * @param openingManagerParams Array of bytes representing params for contracts in openingManagerAddresses
     * @param closingManagerAddresses Array of contract addresses that will be called in canBeClosed
     * @param closingManagerParams Array of bytes representing params for contracts in closingManagerAddresses
     */
    struct CreateLimitOrderParams {
        string bucket;
        uint256 depositAmount;
        address depositAsset;
        address positionAsset;
        uint256 deadline;
        bool takeDepositFromWallet;
        uint256 leverage;
        bool shouldOpenPosition;
        Condition[] openConditions;
        Condition[] closeConditions;
        bool isProtocolFeeInPmx;
        bytes nativeDepositAssetOracleData;
        bytes[][] pullOracleData;
        uint256[] pullOracleTypes;
    }

    struct CreateLimitOrderVars {
        bool isSpot;
        IBucketV3 bucket;
        uint256 positionSize;
        address priceOracle;
        uint256 rate;
        IPrimexDNSStorageV3.TradingOrderType tradingOrderType;
        bool isThirdAsset;
    }

    /**
     * @dev Opens a position on an existing order
     * @param orderId order id
     * @param com address of ConditionalOpeningManager
     * @param comAdditionalParams  params needed for ConditionalOpeningManager to calc canBeFilled
     * @param firstAssetMegaRoutes routes to swap first asset
     * @param depositInThirdAssetMegaRoutes routes to swap deposit asset
     */
    struct OpenPositionParams {
        uint256 orderId;
        uint256 conditionIndex;
        bytes comAdditionalParams;
        PrimexPricingLibrary.MegaRoute[] firstAssetMegaRoutes;
        PrimexPricingLibrary.MegaRoute[] depositInThirdAssetMegaRoutes;
        address keeper;
        bytes firstAssetOracleData;
        bytes thirdAssetOracleData;
        bytes depositSoldAssetOracleData;
        bytes nativePmxOracleData;
        bytes positionNativeAssetOracleData;
        bytes nativePositionAssetOracleData;
        bytes pmxPositionAssetOracleData;
        bytes positionUsdOracleData;
        bytes nativeSoldAssetOracleData;
        bytes[][] pullOracleData;
        uint256[] pullOracleTypes;
        uint256 borrowedAmount;
    }

    struct OpenPositionByOrderVars {
        address assetIn;
        address assetOut;
        uint256 amountIn;
        uint256 amountOut;
        CloseReason closeReason;
        uint256 newPositionId;
        uint256 exchangeRate;
        uint256 feeInPositionAsset;
        uint256 feeInPmx;
    }

    /**
     * @dev Params for PositionManager to open position
     * @param order order
     * @param firstAssetMegaRoutes routes to swap first asset on dex
     * (borrowedAmount + depositAmount if deposit in borrowedAsset)
     * @param depositInThirdAssetMegaRoutes routes to swap deposit in third asset on dex
     */
    struct OpenPositionByOrderParams {
        address sender;
        LimitOrder order;
        Condition[] closeConditions;
        PrimexPricingLibrary.MegaRoute[] firstAssetMegaRoutes;
        PrimexPricingLibrary.MegaRoute[] depositInThirdAssetMegaRoutes;
        bytes firstAssetOracleData;
        bytes thirdAssetOracleData;
        bytes depositSoldAssetOracleData;
        bytes positionUsdOracleData;
        bytes nativePositionAssetOracleData;
        bytes pmxPositionAssetOracleData;
        bytes nativeSoldAssetOracleData;
        uint256 borrowedAmount;
    }

    /**
     * @dev Structure for the updateOrder with parameters necessary to update limit order
     * @param orderId order id to update
     * @param depositAmount The amount of deposit funds for deal
     * @param makeDeposit Bool, add a collateral deposit within the current transaction
     * @param leverage leverage for trading
     * @param takeDepositFromWallet Bool, add a collateral deposit within the current transaction
     */
    struct UpdateLimitOrderParams {
        uint256 orderId;
        uint256 depositAmount;
        uint256 leverage;
        bool isProtocolFeeInPmx;
        bool takeDepositFromWallet;
        bytes nativeDepositOracleData;
        bytes[][] pullOracleData;
        uint256[] pullOracleTypes;
    }

    /**
     * @notice Updates the leverage of a limit order.
     * @param _order The limit order to update.
     * @param _leverage The new leverage value in WAD format for the order.
     * @param _primexDNS The instance of the PrimexDNS contract
     */
    function updateLeverage(LimitOrder storage _order, uint256 _leverage, IPrimexDNSV3 _primexDNS) public {
        _require(_leverage > WadRayMath.WAD, Errors.LEVERAGE_MUST_BE_MORE_THAN_1.selector);
        _require(_order.leverage != WadRayMath.WAD, Errors.CANNOT_CHANGE_SPOT_ORDER_TO_MARGIN.selector);

        _require(
            _leverage <
                _order.bucket.maxAssetLeverage(
                    _order.positionAsset,
                    _primexDNS.protocolFeeRates(IPrimexDNSStorageV3.FeeRateType.MarginLimitOrderExecuted)
                ),
            Errors.LEVERAGE_EXCEEDS_MAX_LEVERAGE.selector
        );
        _order.leverage = _leverage;
    }

    /**
     * @notice Updates the deposit details of a LimitOrder.
     * @param _order The LimitOrder to update.
     * @param _amount The amount of the asset being deposited.
     * @param _takeDepositFromWallet Boolean indicating whether to make a deposit or unlock the deposited asset.
     * @param traderBalanceVault The instance of ITraderBalanceVault used for deposit and unlock operations.
     */
    function updateDeposit(
        LimitOrderLibrary.LimitOrder storage _order,
        uint256 _amount,
        bool _takeDepositFromWallet,
        ITraderBalanceVault traderBalanceVault
    ) public {
        depositLockOrUnlock(
            traderBalanceVault,
            _order.depositAsset,
            (_amount > _order.depositAmount) ? _amount - _order.depositAmount : _order.depositAmount - _amount,
            _takeDepositFromWallet,
            _amount > _order.depositAmount
        );
        _order.depositAmount = _amount;
    }

    /**
     * @notice Sets the open conditions for a LimitOrder.
     * @param _order The limit order.
     * @param openConditionsMap The mapping of order IDs to open conditions.
     * @param openConditions The array of open conditions.
     * @param primexDNS The instance of the Primex DNS contract.
     */
    function setOpenConditions(
        LimitOrderLibrary.LimitOrder memory _order,
        mapping(uint256 => Condition[]) storage openConditionsMap,
        Condition[] memory openConditions,
        IPrimexDNSV3 primexDNS
    ) public {
        _require(hasNoConditionManagerTypeDuplicates(openConditions), Errors.SHOULD_NOT_HAVE_DUPLICATES.selector);
        _require(openConditions.length > 0, Errors.SHOULD_HAVE_OPEN_CONDITIONS.selector);
        if (openConditionsMap[_order.id].length > 0) {
            delete openConditionsMap[_order.id];
        }
        Condition memory condition;
        for (uint256 i; i < openConditions.length; i++) {
            condition = openConditions[i];
            _require(
                IERC165Upgradeable(primexDNS.cmTypeToAddress(condition.managerType)).supportsInterface(
                    type(IConditionalOpeningManager).interfaceId
                ),
                Errors.SHOULD_BE_COM.selector
            );
            openConditionsMap[_order.id].push(condition);
        }
    }

    /**
     * @notice Sets the close conditions for a LimitOrder.
     * @param _order The limit order.
     * @param closeConditionsMap The mapping of order IDs to close conditions.
     * @param closeConditions The array of close conditions to set.
     * @param primexDNS The Primex DNS contract address.
     */
    function setCloseConditions(
        LimitOrderLibrary.LimitOrder memory _order,
        mapping(uint256 => Condition[]) storage closeConditionsMap,
        Condition[] memory closeConditions,
        IPrimexDNSV3 primexDNS
    ) public {
        _require(hasNoConditionManagerTypeDuplicates(closeConditions), Errors.SHOULD_NOT_HAVE_DUPLICATES.selector);
        _require(
            _order.shouldOpenPosition || closeConditions.length == 0,
            Errors.SHOULD_NOT_HAVE_CLOSE_CONDITIONS.selector
        );

        if (closeConditionsMap[_order.id].length > 0) {
            delete closeConditionsMap[_order.id];
        }
        Condition memory condition;
        for (uint256 i; i < closeConditions.length; i++) {
            condition = closeConditions[i];
            _require(
                IERC165Upgradeable(primexDNS.cmTypeToAddress(condition.managerType)).supportsInterface(
                    type(IConditionalClosingManager).interfaceId
                ),
                Errors.SHOULD_BE_CCM.selector
            );
            closeConditionsMap[_order.id].push(condition);
        }
    }

    /**
     * @notice Creates a limit order.
     * @param _params The struct containing the order parameters.
     * @param pm The instance of the PositionManager contract.
     * @param traderBalanceVault The instance of the TraderBalanceVault contract.
     * @param primexDNS The instance of the PrimexDNS contract.
     * @return The created limit order.
     */
    function createLimitOrder(
        CreateLimitOrderParams calldata _params,
        IPositionManagerV2 pm,
        ITraderBalanceVault traderBalanceVault,
        IPrimexDNSV3 primexDNS
    ) public returns (LimitOrder memory) {
        _require(_params.leverage >= WadRayMath.WAD, Errors.INCORRECT_LEVERAGE.selector);
        _require(_params.deadline > block.timestamp, Errors.INCORRECT_DEADLINE.selector);

        CreateLimitOrderVars memory vars;
        vars.isSpot = bytes(_params.bucket).length == 0;
        vars.positionSize = _params.depositAmount.wmul(_params.leverage);
        vars.priceOracle = address(pm.priceOracle());
        if (vars.isSpot) {
            _require(_params.leverage == WadRayMath.WAD, Errors.LEVERAGE_SHOULD_BE_1.selector);
            _require(_params.depositAsset != _params.positionAsset, Errors.SHOULD_BE_DIFFERENT_ASSETS_IN_SPOT.selector);
            vars.tradingOrderType = _params.shouldOpenPosition
                ? IPrimexDNSStorageV3.TradingOrderType.SpotLimitOrder
                : IPrimexDNSStorageV3.TradingOrderType.SwapLimitOrder;
        } else {
            _require(_params.shouldOpenPosition, Errors.SHOULD_OPEN_POSITION.selector);
            _require(_params.leverage > WadRayMath.WAD, Errors.LEVERAGE_MUST_BE_MORE_THAN_1.selector);
            vars.bucket = IBucketV3(primexDNS.getBucketAddress(_params.bucket));
            _require(vars.bucket.getLiquidityMiningParams().isBucketLaunched, Errors.BUCKET_IS_NOT_LAUNCHED.selector);

            (, bool tokenAllowed) = vars.bucket.allowedAssets(_params.positionAsset);
            _require(tokenAllowed, Errors.TOKEN_NOT_SUPPORTED.selector);
            _require(
                _params.leverage <
                    vars.bucket.maxAssetLeverage(
                        _params.positionAsset,
                        primexDNS.protocolFeeRates(IPrimexDNSStorageV3.FeeRateType.MarginLimitOrderExecuted)
                    ),
                Errors.LEVERAGE_EXCEEDS_MAX_LEVERAGE.selector
            );
            vars.isThirdAsset =
                _params.depositAsset != address(vars.bucket.borrowedAsset()) &&
                _params.depositAsset != _params.positionAsset;
            vars.tradingOrderType = vars.isThirdAsset
                ? IPrimexDNSStorageV3.TradingOrderType.MarginLimitOrderDepositInThirdAsset
                : IPrimexDNSStorageV3.TradingOrderType.MarginLimitOrder;
        }
        LimitOrder memory order = LimitOrder({
            bucket: IBucketV3(address(0)),
            positionAsset: _params.positionAsset,
            depositAsset: _params.depositAsset,
            depositAmount: _params.depositAmount,
            feeToken: _params.isProtocolFeeInPmx ? primexDNS.pmx() : _params.positionAsset,
            protocolFee: 0,
            trader: msg.sender,
            deadline: _params.deadline,
            id: 0,
            leverage: _params.leverage,
            shouldOpenPosition: _params.shouldOpenPosition,
            createdAt: block.timestamp,
            updatedConditionsAt: block.timestamp,
            extraParams: ""
        });
        order.bucket = vars.bucket;

        PrimexPricingLibrary.validateMinPositionSize(
            vars.positionSize,
            order.depositAsset,
            vars.priceOracle,
            pm.keeperRewardDistributor(),
            primexDNS,
            vars.tradingOrderType,
            _params.nativeDepositAssetOracleData
        );

        // deposit locking
        depositLockOrUnlock(
            traderBalanceVault,
            order.depositAsset,
            order.depositAmount,
            _params.takeDepositFromWallet,
            true
        );

        return order;
    }

    /**
     * @notice Opens a position by order.
     * @param order The LimitOrder storage containing order details.
     * @param _params The OpenPositionParams calldata containing additional position parameters.
     * @param _closeConditions The Condition array containing close conditions for the position.
     * @param pm The instance of the PositionManager contract.
     * @param traderBalanceVault The instance of the TraderBalanceVault contract.
     * @param swapManager The instance of the SwapManager contract.
     * @return vars The OpenPositionByOrderVars struct containing the result of the open position operation.
     */
    function openPositionByOrder(
        LimitOrder storage order,
        OpenPositionParams calldata _params,
        Condition[] memory _closeConditions,
        IPositionManagerV2 pm,
        ITraderBalanceVault traderBalanceVault,
        ISwapManager swapManager,
        uint256 _initialGasLeft
    ) public returns (OpenPositionByOrderVars memory) {
        OpenPositionByOrderVars memory vars;
        bool isSpot = address(order.bucket) == address(0);

        if (order.protocolFee != 0) {
            traderBalanceVault.unlockAsset(
                ITraderBalanceVault.UnlockAssetParams({
                    trader: order.trader,
                    receiver: order.trader,
                    asset: order.feeToken,
                    amount: order.protocolFee
                })
            );
            order.protocolFee = 0;
            order.feeToken = order.positionAsset;
        }

        if (order.shouldOpenPosition) {
            vars.closeReason = isSpot ? CloseReason.FilledSpot : CloseReason.FilledMargin;
            (vars.amountIn, vars.amountOut, vars.newPositionId, vars.exchangeRate, vars.feeInPositionAsset) = pm
                .openPositionByOrder(
                    OpenPositionByOrderParams({
                        sender: msg.sender,
                        order: order,
                        closeConditions: _closeConditions,
                        firstAssetMegaRoutes: _params.firstAssetMegaRoutes,
                        depositInThirdAssetMegaRoutes: _params.depositInThirdAssetMegaRoutes,
                        firstAssetOracleData: _params.firstAssetOracleData,
                        thirdAssetOracleData: _params.thirdAssetOracleData,
                        depositSoldAssetOracleData: _params.depositSoldAssetOracleData,
                        positionUsdOracleData: _params.positionUsdOracleData,
                        nativePositionAssetOracleData: _params.nativePositionAssetOracleData,
                        pmxPositionAssetOracleData: _params.pmxPositionAssetOracleData,
                        nativeSoldAssetOracleData: _params.nativeSoldAssetOracleData,
                        borrowedAmount: _params.borrowedAmount
                    })
                );
        } else {
            _require(
                _params.depositInThirdAssetMegaRoutes.length == 0,
                Errors.DEPOSIT_IN_THIRD_ASSET_ROUTES_LENGTH_SHOULD_BE_0.selector
            );
            vars.closeReason = CloseReason.FilledSwap;
            vars.amountIn = order.depositAmount;
            traderBalanceVault.unlockAsset(
                ITraderBalanceVault.UnlockAssetParams({
                    trader: order.trader,
                    receiver: address(this),
                    asset: order.depositAsset,
                    amount: order.depositAmount
                })
            );

            (vars.amountOut, vars.feeInPositionAsset) = swapManager.swapInLimitOrder(
                ISwapManager.SwapInLimitOrderParams({
                    depositAsset: order.depositAsset,
                    positionAsset: order.positionAsset,
                    depositAmount: order.depositAmount,
                    megaRoutes: _params.firstAssetMegaRoutes,
                    trader: order.trader,
                    deadline: order.deadline,
                    feeToken: order.feeToken,
                    keeperRewardDistributor: address(pm.keeperRewardDistributor()),
                    gasSpent: _initialGasLeft - gasleft(),
                    depositPositionAssetOracleData: _params.firstAssetOracleData,
                    pmxPositionAssetOracleData: _params.pmxPositionAssetOracleData,
                    nativePositionAssetOracleData: _params.nativePositionAssetOracleData
                }),
                pm.getOracleTolerableLimit(order.depositAsset, order.positionAsset)
            );

            uint256 multiplierDepositAsset = 10 ** (18 - IERC20Metadata(order.depositAsset).decimals());
            uint256 multiplierPositionAsset = 10 ** (18 - IERC20Metadata(order.positionAsset).decimals());
            vars.exchangeRate =
                (vars.amountIn * multiplierDepositAsset).wdiv(
                    (vars.amountOut + vars.feeInPositionAsset) * multiplierPositionAsset
                ) /
                multiplierDepositAsset;
        }

        vars.assetIn = isSpot ? order.depositAsset : address(order.bucket.borrowedAsset());
        vars.assetOut = order.positionAsset;
        return vars;
    }

    /**
     * @notice Checks if an array of Condition structs has no duplicate manager types.
     * @param conditions The array of Condition structs to be checked.
     * @return bool Boolean value indicating whether the array has no duplicate manager types.
     */
    function hasNoConditionManagerTypeDuplicates(Condition[] memory conditions) public pure returns (bool) {
        if (conditions.length == 0) {
            return true;
        }
        for (uint256 i; i < conditions.length - 1; i++) {
            for (uint256 j = i + 1; j < conditions.length; j++) {
                if (conditions[i].managerType == conditions[j].managerType) {
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * @notice This function is used to either deposit or unlock assets in the trader balance vault.
     * @param traderBalanceVault The instance of the trader balance vault.
     * @param _depositAsset The address of the asset to be deposited or unlocked.
     * @param _amount The amount of the asset to be deposited or unlocked.
     * @param _takeDepositFromWallet Boolean indicating whether to make a deposit or not.
     * @param _isAdd Boolean indicating whether to lock or unlock asset. Should lock asset, if true.
     */
    function depositLockOrUnlock(
        ITraderBalanceVault traderBalanceVault,
        address _depositAsset,
        uint256 _amount,
        bool _takeDepositFromWallet,
        bool _isAdd
    ) internal {
        if (!_isAdd) {
            traderBalanceVault.unlockAsset(
                ITraderBalanceVault.UnlockAssetParams(msg.sender, msg.sender, _depositAsset, _amount)
            );
            return;
        }
        if (_takeDepositFromWallet) {
            if (_depositAsset == NATIVE_CURRENCY) {
                _require(msg.value >= _amount, Errors.INSUFFICIENT_DEPOSIT.selector);
                traderBalanceVault.increaseLockedBalance{value: _amount}(msg.sender, _depositAsset, _amount);
                if (msg.value > _amount) {
                    uint256 rest = msg.value - _amount;
                    traderBalanceVault.topUpAvailableBalance{value: rest}(msg.sender, NATIVE_CURRENCY, rest);
                }
                return;
            }
            TokenTransfersLibrary.doTransferFromTo(_depositAsset, msg.sender, address(traderBalanceVault), _amount);
            traderBalanceVault.increaseLockedBalance(msg.sender, _depositAsset, _amount);
            return;
        }
        traderBalanceVault.useTraderAssets(
            ITraderBalanceVault.LockAssetParams(
                msg.sender,
                address(0),
                _depositAsset,
                _amount,
                ITraderBalanceVault.OpenType.CREATE_LIMIT_ORDER
            )
        );
    }
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {WadRayMath} from "./utils/WadRayMath.sol";

import {PrimexPricingLibrary} from "./PrimexPricingLibrary.sol";
import {TokenTransfersLibrary} from "./TokenTransfersLibrary.sol";
import {LimitOrderLibrary} from "./LimitOrderLibrary.sol";
import "./Errors.sol";

import {NATIVE_CURRENCY} from "../Constants.sol";
import {ITraderBalanceVault} from "../TraderBalanceVault/ITraderBalanceVault.sol";
import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {IPrimexDNSStorageV3} from "../PrimexDNS/IPrimexDNSStorage.sol";
import {IPriceOracleV2} from "../PriceOracle/IPriceOracle.sol";
import {IBucketV3} from "../Bucket/IBucket.sol";
import {IConditionalClosingManager} from "../interfaces/IConditionalClosingManager.sol";
import {ITakeProfitStopLossCCM} from "../interfaces/ITakeProfitStopLossCCM.sol";
import {IKeeperRewardDistributorStorage, IKeeperRewardDistributorV3} from "../KeeperRewardDistributor/IKeeperRewardDistributor.sol";

library PositionLibrary {
    using WadRayMath for uint256;

    event ClosePosition(
        uint256 indexed positionId,
        address indexed trader,
        address indexed closedBy,
        address bucketAddress,
        address soldAsset,
        address positionAsset,
        uint256 decreasePositionAmount,
        int256 profit,
        uint256 positionDebt,
        uint256 amountOut,
        PositionLibrary.CloseReason reason
    );

    event PaidProtocolFee(
        uint256 indexed positionId,
        address indexed trader,
        address paymentAsset,
        IPrimexDNSStorageV3.FeeRateType indexed feeRateType,
        uint256 feeInPaymentAsset,
        uint256 feeInPmx
    );

    /**
     * @notice This struct represents a trading position
     * @param id unique identifier for the position
     * @param scaledDebtAmount scaled debt amount associated with the position
     * @param bucket instance of the Bucket associated for trading
     * @param soldAsset bucket asset in the case of margin trading or deposit asset in the case of spot trading
     * @param depositAmountInSoldAsset equivalent of trader deposit size (this deposit can be in any asset) in the sold asset
     * or just deposit amount for spot trading
     * @param positionAsset asset of the trading position
     * @param positionAmount amount of the trading position
     * @param trader address of the trader holding the position
     * @param openBorrowIndex variable borrow index when position was opened
     * @param createdAt timestamp when the position was created
     * @param updatedConditionsAt timestamp when the close condition was updated
     * @param extraParams byte-encoded params, utilized for the feeToken address
     */
    struct Position {
        uint256 id;
        uint256 scaledDebtAmount;
        IBucketV3 bucket;
        address soldAsset;
        uint256 depositAmountInSoldAsset;
        address positionAsset;
        uint256 positionAmount;
        address trader;
        uint256 openBorrowIndex;
        uint256 createdAt;
        uint256 updatedConditionsAt;
        bytes extraParams;
    }

    struct IncreaseDepositParams {
        uint256 amount;
        address asset;
        bool takeDepositFromWallet;
        PrimexPricingLibrary.MegaRoute[] megaRoutes;
        IPrimexDNSV3 primexDNS;
        IPriceOracleV2 priceOracle;
        ITraderBalanceVault traderBalanceVault;
        uint256 amountOutMin;
    }

    struct DecreaseDepositParams {
        uint256 amount;
        IPrimexDNSV3 primexDNS;
        IPriceOracleV2 priceOracle;
        ITraderBalanceVault traderBalanceVault;
        uint256 pairPriceDrop;
        uint256 securityBuffer;
        uint256 oracleTolerableLimit;
        uint256 maintenanceBuffer;
        address keeperRewardDistributor;
        bytes positionSoldAssetOracleData;
        bytes nativeSoldAssetOracleData;
    }

    struct MegaSwapParams {
        address tokenA;
        address tokenB;
        uint256 amountTokenA;
        PrimexPricingLibrary.MegaRoute[] megaRoutes;
        address receiver;
        uint256 deadline;
        bool takeDepositFromWallet;
        IPrimexDNSV3 primexDNS;
        IPriceOracleV2 priceOracle;
        ITraderBalanceVault traderBalanceVault;
    }

    struct ClosePositionParams {
        uint256 closeAmount;
        uint256 depositDecrease;
        uint256 scaledDebtAmount;
        address depositReceiver;
        PrimexPricingLibrary.MegaRoute[] megaRoutes;
        uint256 amountOutMin;
        uint256 oracleTolerableLimit;
        IPrimexDNSV3 primexDNS;
        IPriceOracleV2 priceOracle;
        ITraderBalanceVault traderBalanceVault;
        LimitOrderLibrary.Condition closeCondition;
        bytes ccmAdditionalParams;
        bool borrowedAmountIsNotZero;
        uint256 pairPriceDrop;
        uint256 securityBuffer;
        bool needOracleTolerableLimitCheck;
        uint256 initialGasLeft;
        address keeperRewardDistributor;
        bytes positionSoldAssetOracleData;
        bytes pmxSoldAssetOracleData;
        bytes nativeSoldAssetOracleData;
    }

    struct ClosePositionVars {
        address payable dexAdapter;
        uint256 borowedAssetAmount;
        uint256 amountToReturn;
        uint256 permanentLoss;
        uint256 fee;
        uint256 gasSpent;
    }

    struct ClosePositionEventData {
        int256 profit;
        uint256 debtAmount;
        uint256 amountOut;
        uint256 amountOutAfterFee;
        IKeeperRewardDistributorStorage.KeeperActionType actionType;
        address trader;
        address paymentAsset;
        IPrimexDNSStorageV3.FeeRateType feeRateType;
        uint256 feeInPaymentAsset;
        uint256 feeInPmx;
    }

    struct OpenPositionVars {
        PrimexPricingLibrary.MegaRoute[] firstAssetMegaRoutes;
        PrimexPricingLibrary.MegaRoute[] depositInThirdAssetMegaRoutes;
        PrimexPricingLibrary.DepositData depositData;
        uint256 borrowedAmount;
        uint256 amountOutMin;
        uint256 deadline;
        bool isSpot;
        bool isThirdAsset;
        bool takeDepositFromWallet;
        bool byOrder;
        uint256 orderLeverage;
        address sender;
        LimitOrderLibrary.Condition[] closeConditions;
        bool needOracleTolerableLimitCheck;
        bytes firstAssetOracleData;
        bytes thirdAssetOracleData;
        bytes positionUsdOracleData;
        bytes nativePositionAssetOracleData;
        bytes pmxPositionAssetOracleData;
        bytes nativeSoldAssetOracleData;
    }

    struct OpenPositionEventData {
        uint256 feeInPositionAsset;
        uint256 feeInPmx;
        uint256 entryPrice;
        uint256 leverage;
        IPrimexDNSStorageV3.FeeRateType feeRateType;
    }

    /**
     * The struct for openPosition function local vars
     */
    struct OpenPositionLocalData {
        uint256 amountToTransfer;
        address payable dexAdapter;
        address depositReceiver;
        uint256 depositInPositionAsset;
        bool isSpot;
        IPrimexDNSStorageV3.TradingOrderType tradingOrderType;
        uint256 positionAmountAfterFeeInSoldAsset;
        uint256 borrowedAmountInPositionAsset;
        uint256 leverage;
        uint256 multiplierBorrowedAsset;
        uint256 multiplierPositionAsset;
        address positionAsset;
        uint256 positionAmount;
    }

    /**
     * @dev Structure for the OpenPositionParams when margin trading is activated
     * @param bucket The bucket, from which the loan will be taken
     * @param borrowedAmount The amount of tokens borrowed to be exchanged
     * @param depositInThirdAssetMegaRoutes routes to swap deposit in third asset on dex
     */
    struct OpenPositionMarginParams {
        string bucket;
        uint256 borrowedAmount;
        PrimexPricingLibrary.MegaRoute[] depositInThirdAssetMegaRoutes;
    }

    /**
     * @dev Structure for the openPosition with parameters necessary to open a position
     * @param marginParams margin trading related params
     * @param firstAssetMegaRoutes routes to swap first asset on dex
     * (borrowedAmount + depositAmount if deposit in borrowedAsset)
     * @param depositAsset The address of the deposit token (collateral for margin trade or
     * locked funds for spot)
     * @param depositAmount The amount of deposit funds for deal
     * @param positionAsset The address output token for exchange
     * @param amountOutMin The minimum amount of output tokens
     * that must be received for the transaction not to revert.
     * @param deadline Unix timestamp after which the transaction will revert.
     * @param takeDepositFromWallet Bool, add a deposit within the current transaction
     * @param closeConditions Array of conditions that position can be closed by
     */
    struct OpenPositionParams {
        OpenPositionMarginParams marginParams;
        PrimexPricingLibrary.MegaRoute[] firstAssetMegaRoutes;
        address depositAsset;
        uint256 depositAmount;
        address positionAsset;
        uint256 amountOutMin;
        uint256 deadline;
        bool takeDepositFromWallet;
        bool isProtocolFeeInPmx;
        LimitOrderLibrary.Condition[] closeConditions;
        bytes firstAssetOracleData;
        bytes thirdAssetOracleData;
        bytes depositSoldAssetOracleData;
        bytes positionUsdOracleData;
        bytes nativePositionAssetOracleData;
        bytes pmxPositionAssetOracleData;
        bytes nativeSoldAssetOracleData;
        bytes[][] pullOracleData;
        uint256[] pullOracleTypes;
    }
    struct PositionManagerParams {
        IPrimexDNSV3 primexDNS;
        IPriceOracleV2 priceOracle;
        ITraderBalanceVault traderBalanceVault;
        uint256 oracleTolerableLimit;
        uint256 oracleTolerableLimitForThirdAsset;
        uint256 maxPositionSize;
        uint256 initialGasLeft;
        address keeperRewardDistributor;
    }

    struct ScaledParams {
        uint256 decreasePercent;
        uint256 scaledDebtAmount;
        uint256 depositDecrease;
        bool borrowedAmountIsNotZero;
    }

    enum CloseReason {
        CLOSE_BY_TRADER,
        RISKY_POSITION,
        BUCKET_DELISTED,
        LIMIT_CONDITION,
        BATCH_LIQUIDATION,
        BATCH_STOP_LOSS,
        BATCH_TAKE_PROFIT
    }

    /**
     * @dev Increases the deposit amount for a position.
     * @param position The storage reference to the position.
     * @param params The parameters for increasing the deposit.
     * @return The amount of trader debtTokens burned.
     */
    function increaseDeposit(Position storage position, IncreaseDepositParams memory params) public returns (uint256) {
        _require(msg.sender == position.trader, Errors.CALLER_IS_NOT_TRADER.selector);
        _require(position.scaledDebtAmount != 0, Errors.BORROWED_AMOUNT_IS_ZERO.selector);
        address borrowedAsset = position.soldAsset;

        uint256 depositAmountInBorrowed;
        address depositReceiver = params.primexDNS.dexAdapter();
        if (params.asset == borrowedAsset) {
            depositReceiver = address(position.bucket);
            depositAmountInBorrowed = params.amount;
        }

        if (params.takeDepositFromWallet) {
            TokenTransfersLibrary.doTransferFromTo(params.asset, msg.sender, depositReceiver, params.amount);
        } else {
            params.traderBalanceVault.useTraderAssets(
                ITraderBalanceVault.LockAssetParams(
                    msg.sender,
                    depositReceiver,
                    params.asset,
                    params.amount,
                    ITraderBalanceVault.OpenType.OPEN
                )
            );
        }

        if (params.asset != borrowedAsset) {
            depositAmountInBorrowed = PrimexPricingLibrary.megaSwap(
                PrimexPricingLibrary.MegaSwapParams({
                    tokenA: params.asset,
                    tokenB: borrowedAsset,
                    amountTokenA: params.amount,
                    megaRoutes: params.megaRoutes,
                    receiver: address(position.bucket),
                    deadline: block.timestamp
                }),
                0,
                payable(params.primexDNS.dexAdapter()),
                address(params.priceOracle),
                false,
                new bytes(0)
            );
            _require(depositAmountInBorrowed >= params.amountOutMin, Errors.SLIPPAGE_TOLERANCE_EXCEEDED.selector);
        }

        uint256 debt = getDebt(position);
        uint256 amountToTrader;
        uint256 debtToBurn = depositAmountInBorrowed;

        if (depositAmountInBorrowed >= debt) {
            amountToTrader = depositAmountInBorrowed - debt;
            debtToBurn = debt;
            position.scaledDebtAmount = 0;
            if (amountToTrader > 0)
                params.traderBalanceVault.topUpAvailableBalance(position.trader, borrowedAsset, amountToTrader);
        } else {
            position.scaledDebtAmount =
                position.scaledDebtAmount -
                debtToBurn.rdiv(position.bucket.getNormalizedVariableDebt());
        }

        position.depositAmountInSoldAsset += debtToBurn;

        position.bucket.decreaseTraderDebt(
            position.trader,
            debtToBurn,
            address(params.traderBalanceVault),
            amountToTrader,
            0
        );
        return debtToBurn;
    }

    /**
     * @dev Decreases the deposit amount for a position.
     * @param position The storage reference to the position.
     * @param params The parameters for the decrease deposit operation.
     */
    function decreaseDeposit(Position storage position, DecreaseDepositParams memory params) public {
        _require(msg.sender == position.trader, Errors.CALLER_IS_NOT_TRADER.selector);
        _require(position.bucket != IBucketV3(address(0)), Errors.IS_SPOT_POSITION.selector);
        _require(position.bucket.isActive(), Errors.BUCKET_IS_NOT_ACTIVE.selector);
        _require(params.amount > 0, Errors.DECREASE_AMOUNT_IS_ZERO.selector);
        _require(params.amount <= position.depositAmountInSoldAsset, Errors.AMOUNT_IS_MORE_THAN_DEPOSIT.selector);
        position.depositAmountInSoldAsset -= params.amount;
        position.scaledDebtAmount =
            position.scaledDebtAmount +
            params.amount.rdiv(position.bucket.getNormalizedVariableDebt());

        params.traderBalanceVault.topUpAvailableBalance(position.trader, position.soldAsset, params.amount);

        uint256 feeInPaymentAsset = decodeFeeTokenAddress(position.extraParams) == address(0)
            ? 0
            : PrimexPricingLibrary.calculateFeeInPaymentAsset(
                PrimexPricingLibrary.CalculateFeeInPaymentAssetParams({
                    primexDNS: params.primexDNS,
                    priceOracle: address(params.priceOracle),
                    feeRateType: IPrimexDNSStorageV3.FeeRateType.MarginPositionClosedByKeeper,
                    paymentAsset: position.soldAsset,
                    paymentAmount: params.amount,
                    keeperRewardDistributor: params.keeperRewardDistributor,
                    gasSpent: 0,
                    isFeeProhibitedInPmx: true,
                    nativePaymentAssetOracleData: params.nativeSoldAssetOracleData
                })
            );
        _require(
            health(
                position,
                params.priceOracle,
                params.pairPriceDrop,
                params.securityBuffer,
                params.oracleTolerableLimit,
                feeInPaymentAsset,
                params.positionSoldAssetOracleData
            ) >= WadRayMath.WAD + params.maintenanceBuffer,
            Errors.INSUFFICIENT_DEPOSIT_SIZE.selector
        );
        position.bucket.increaseDebt(position.trader, params.amount, address(params.traderBalanceVault));
    }

    /**
     * @notice Closes a position.
     * @param position The position to be closed.
     * @param params The parameters for closing the position.
     * @param reason The reason for closing the position.
     * @return posEventData The event data for the closed position.
     */
    function closePosition(
        Position memory position,
        ClosePositionParams memory params,
        CloseReason reason
    ) public returns (ClosePositionEventData memory) {
        ClosePositionEventData memory posEventData;
        ClosePositionVars memory vars;

        if (params.borrowedAmountIsNotZero) {
            posEventData.debtAmount = params.scaledDebtAmount.rmul(position.bucket.getNormalizedVariableDebt());
        }

        vars.dexAdapter = payable(params.primexDNS.dexAdapter());

        TokenTransfersLibrary.doTransferOut(position.positionAsset, vars.dexAdapter, params.closeAmount);
        posEventData.amountOut = PrimexPricingLibrary.megaSwap(
            PrimexPricingLibrary.MegaSwapParams({
                tokenA: position.positionAsset,
                tokenB: position.soldAsset,
                amountTokenA: params.closeAmount,
                megaRoutes: params.megaRoutes,
                receiver: address(this),
                deadline: block.timestamp
            }),
            params.oracleTolerableLimit,
            vars.dexAdapter,
            address(params.priceOracle),
            params.needOracleTolerableLimitCheck,
            params.positionSoldAssetOracleData
        );

        posEventData.paymentAsset = decodeFeeTokenAddress(position.extraParams);

        if (reason == CloseReason.CLOSE_BY_TRADER) {
            posEventData.feeRateType = params.borrowedAmountIsNotZero
                ? IPrimexDNSStorageV3.FeeRateType.MarginPositionClosedByTrader
                : IPrimexDNSStorageV3.FeeRateType.SpotPositionClosedByTrader;
            vars.gasSpent = 0;
        } else {
            posEventData.feeRateType = params.borrowedAmountIsNotZero
                ? IPrimexDNSStorageV3.FeeRateType.MarginPositionClosedByKeeper
                : IPrimexDNSStorageV3.FeeRateType.SpotPositionClosedByKeeper;
            vars.gasSpent = params.initialGasLeft - gasleft();
        }

        (posEventData.feeInPaymentAsset, posEventData.feeInPmx) = PrimexPricingLibrary.payProtocolFee(
            PrimexPricingLibrary.ProtocolFeeParams({
                feeToken: posEventData.paymentAsset,
                trader: position.trader,
                priceOracle: address(params.priceOracle),
                feeRateType: posEventData.feeRateType,
                traderBalanceVault: params.traderBalanceVault,
                swapManager: address(0),
                keeperRewardDistributor: params.keeperRewardDistributor,
                primexDNS: params.primexDNS,
                paymentAsset: position.soldAsset,
                paymentAmount: posEventData.amountOut,
                gasSpent: vars.gasSpent,
                isFeeProhibitedInPmx: reason == CloseReason.RISKY_POSITION,
                pmxPaymentAssetOracleData: params.pmxSoldAssetOracleData,
                nativePaymentAssetOracleData: params.nativeSoldAssetOracleData
            })
        );

        posEventData.amountOutAfterFee = posEventData.amountOut - posEventData.feeInPaymentAsset;

        TokenTransfersLibrary.doTransferOut({
            token: position.soldAsset,
            to: params.borrowedAmountIsNotZero ? address(position.bucket) : address(params.traderBalanceVault),
            amount: posEventData.amountOutAfterFee
        });

        _require(
            posEventData.amountOut >= params.amountOutMin && posEventData.amountOut > 0,
            Errors.SLIPPAGE_TOLERANCE_EXCEEDED.selector
        );

        bool canBeClosed;
        if (reason == CloseReason.CLOSE_BY_TRADER) {
            canBeClosed = position.trader == msg.sender;
        } else if (reason == CloseReason.RISKY_POSITION) {
            canBeClosed =
                health(
                    position,
                    params.priceOracle,
                    params.pairPriceDrop,
                    params.securityBuffer,
                    params.oracleTolerableLimit,
                    posEventData.feeInPaymentAsset,
                    params.positionSoldAssetOracleData
                ) <
                WadRayMath.WAD;
            posEventData.actionType = IKeeperRewardDistributorStorage.KeeperActionType.Liquidation;
        } else if (reason == CloseReason.LIMIT_CONDITION) {
            address cm = params.primexDNS.cmTypeToAddress(params.closeCondition.managerType);
            _require(cm != address(0), Errors.INCORRECT_CM_TYPE.selector);

            canBeClosed = IConditionalClosingManager(cm).canBeClosedAfterSwap(
                position,
                params.closeCondition.params,
                params.ccmAdditionalParams,
                params.closeAmount,
                posEventData.amountOut,
                params.positionSoldAssetOracleData
            );
            posEventData.actionType = IKeeperRewardDistributorStorage.KeeperActionType.StopLoss;
        } else if (reason == CloseReason.BUCKET_DELISTED) {
            canBeClosed = position.bucket != IBucketV3(address(0)) && position.bucket.isDelisted();
            posEventData.actionType = IKeeperRewardDistributorStorage.KeeperActionType.BucketDelisted;
        }
        _require(canBeClosed, Errors.POSITION_CANNOT_BE_CLOSED_FOR_THIS_REASON.selector);

        if (posEventData.amountOutAfterFee > posEventData.debtAmount) {
            unchecked {
                vars.amountToReturn = posEventData.amountOutAfterFee - posEventData.debtAmount;
            }
        } else {
            unchecked {
                vars.permanentLoss = posEventData.debtAmount - posEventData.amountOutAfterFee;
            }
        }

        posEventData.profit = -int256(params.depositDecrease);

        if (reason != CloseReason.RISKY_POSITION) {
            if (vars.amountToReturn > 0) {
                posEventData.profit += int256(vars.amountToReturn);
                params.traderBalanceVault.topUpAvailableBalance(
                    reason == CloseReason.CLOSE_BY_TRADER ? params.depositReceiver : position.trader,
                    position.soldAsset,
                    vars.amountToReturn
                );
            }
        }

        if (params.borrowedAmountIsNotZero) {
            position.bucket.decreaseTraderDebt(
                position.trader,
                posEventData.debtAmount,
                reason == CloseReason.RISKY_POSITION ? params.primexDNS.treasury() : address(params.traderBalanceVault),
                vars.amountToReturn,
                vars.permanentLoss
            );
        }

        // to avoid stack to deep
        CloseReason _reason = reason;
        if (params.closeAmount == position.positionAmount) {
            emit ClosePosition({
                positionId: position.id,
                trader: position.trader,
                closedBy: msg.sender,
                bucketAddress: address(position.bucket),
                soldAsset: position.soldAsset,
                positionAsset: position.positionAsset,
                decreasePositionAmount: position.positionAmount,
                profit: posEventData.profit,
                positionDebt: posEventData.debtAmount,
                amountOut: posEventData.amountOutAfterFee,
                reason: _reason
            });
        }
        posEventData.trader = position.trader;
        return posEventData;
    }

    /**
     * @dev Sets the maximum position size between two tokens.
     * @param maxPositionSize The storage mapping for maximum position sizes.
     * @param token0 The address of token0.
     * @param token1 The address of token1.
     * @param amountInToken0 The maximum position size in token0.
     * @param amountInToken1 The maximum position size in token1.
     */
    function setMaxPositionSize(
        mapping(address => mapping(address => uint256)) storage maxPositionSize,
        address token0,
        address token1,
        uint256 amountInToken0,
        uint256 amountInToken1
    ) public {
        _require(token0 != address(0) && token1 != address(0), Errors.TOKEN_ADDRESS_IS_ZERO.selector);
        _require(token0 != token1, Errors.IDENTICAL_ASSET_ADDRESSES.selector);

        maxPositionSize[token1][token0] = amountInToken0;
        maxPositionSize[token0][token1] = amountInToken1;
    }

    /**
     * @dev Sets the tolerable limit for an oracle between two assets.
     * @param oracleTolerableLimits The mapping to store oracle tolerable limits.
     * @param assetA The address of the first asset.
     * @param assetB The address of the second asset.
     * @param percent The percentage tolerable limit for the oracle in WAD format (1 WAD = 100%).
     */
    function setOracleTolerableLimit(
        mapping(address => mapping(address => uint256)) storage oracleTolerableLimits,
        address assetA,
        address assetB,
        uint256 percent
    ) public {
        _require(assetA != address(0) && assetB != address(0), Errors.ASSET_ADDRESS_NOT_SUPPORTED.selector);
        _require(assetA != assetB, Errors.IDENTICAL_ASSET_ADDRESSES.selector);
        _require(percent <= WadRayMath.WAD && percent > 0, Errors.INVALID_PERCENT_NUMBER.selector);
        oracleTolerableLimits[assetA][assetB] = percent;
        oracleTolerableLimits[assetB][assetA] = percent;
    }

    /**
     * @dev Sets the close conditions for a given position.
     * @param position The position for which to set the close conditions.
     * @param closeConditionsMap The storage mapping of close conditions for each position ID.
     * @param closeConditions The array of close conditions to be set.
     * @param primexDNS The address of the IPrimexDNS contract.
     */
    function setCloseConditions(
        Position memory position,
        mapping(uint256 => LimitOrderLibrary.Condition[]) storage closeConditionsMap,
        LimitOrderLibrary.Condition[] memory closeConditions,
        IPrimexDNSV3 primexDNS
    ) public {
        _require(
            LimitOrderLibrary.hasNoConditionManagerTypeDuplicates(closeConditions),
            Errors.SHOULD_NOT_HAVE_DUPLICATES.selector
        );
        if (closeConditionsMap[position.id].length > 0) {
            delete closeConditionsMap[position.id];
        }
        LimitOrderLibrary.Condition memory condition;
        for (uint256 i; i < closeConditions.length; i++) {
            condition = closeConditions[i];
            _require(
                IERC165Upgradeable(primexDNS.cmTypeToAddress(condition.managerType)).supportsInterface(
                    type(IConditionalClosingManager).interfaceId
                ),
                Errors.SHOULD_BE_CCM.selector
            );

            closeConditionsMap[position.id].push(condition);
        }
    }

    /**
     * @notice Opens a position by depositing assets and borrowing funds (except when the position is spot)
     * @param _position The position to be opened
     * @param _vars Variables related to the position opening
     * @param _pmParams Parameters for the PositionManager contract
     * @return The updated position and event data
     */
    function openPosition(
        Position memory _position,
        OpenPositionVars memory _vars,
        PositionManagerParams memory _pmParams
    ) public returns (Position memory, OpenPositionEventData memory) {
        OpenPositionLocalData memory data;
        if (_vars.isSpot) {
            data.tradingOrderType = _vars.byOrder
                ? IPrimexDNSStorageV3.TradingOrderType.SpotLimitOrder
                : IPrimexDNSStorageV3.TradingOrderType.SpotMarketOrder;
        } else {
            if (_vars.byOrder) {
                data.tradingOrderType = _vars.isThirdAsset
                    ? IPrimexDNSStorageV3.TradingOrderType.MarginLimitOrderDepositInThirdAsset
                    : IPrimexDNSStorageV3.TradingOrderType.MarginLimitOrder;
            } else {
                data.tradingOrderType = IPrimexDNSStorageV3.TradingOrderType.MarginMarketOrder;
            }
        }
        PrimexPricingLibrary.validateMinPositionSize(
            _vars.borrowedAmount + _position.depositAmountInSoldAsset,
            _position.soldAsset,
            address(_pmParams.priceOracle),
            IKeeperRewardDistributorV3(_pmParams.keeperRewardDistributor),
            _pmParams.primexDNS,
            data.tradingOrderType,
            _vars.nativeSoldAssetOracleData
        );
        data.amountToTransfer = _vars.borrowedAmount;
        data.dexAdapter = payable(_pmParams.primexDNS.dexAdapter());
        data.depositReceiver = data.dexAdapter;
        if (_vars.depositData.depositAsset == _position.positionAsset) {
            _position.positionAmount = _vars.depositData.depositAmount;
            data.depositInPositionAsset = _vars.depositData.depositAmount;
            data.depositReceiver = address(this);
        } else if (_vars.depositData.depositAsset == _position.soldAsset) {
            data.amountToTransfer += _vars.depositData.depositAmount;
        }

        data.isSpot = _vars.borrowedAmount == 0;
        if (data.isSpot) _vars.depositData.depositAsset = _position.soldAsset;

        if (_vars.takeDepositFromWallet) {
            TokenTransfersLibrary.doTransferFromTo(
                _vars.depositData.depositAsset,
                msg.sender,
                data.depositReceiver,
                _vars.depositData.depositAmount
            );
        } else {
            _pmParams.traderBalanceVault.useTraderAssets(
                ITraderBalanceVault.LockAssetParams({
                    trader: _position.trader,
                    depositReceiver: data.depositReceiver,
                    depositAsset: _vars.depositData.depositAsset,
                    depositAmount: _vars.depositData.depositAmount,
                    openType: _vars.byOrder
                        ? ITraderBalanceVault.OpenType.OPEN_BY_ORDER
                        : ITraderBalanceVault.OpenType.OPEN
                })
            );
        }

        if (!data.isSpot) {
            _position.bucket.increaseDebt(_position.trader, _vars.borrowedAmount, data.dexAdapter);
            // @note You need to write index only after opening a position in bucket.
            // Since when opening position in the bucket, index becomes relevant (containing accumulated profit)
            _position.openBorrowIndex = _position.bucket.variableBorrowIndex();
            _position.scaledDebtAmount = _vars.borrowedAmount.rdiv(_position.openBorrowIndex);
        }
        if (_vars.isThirdAsset) {
            data.depositInPositionAsset = PrimexPricingLibrary.megaSwap(
                PrimexPricingLibrary.MegaSwapParams({
                    tokenA: _vars.depositData.depositAsset,
                    tokenB: _position.positionAsset,
                    amountTokenA: _vars.depositData.depositAmount,
                    megaRoutes: _vars.depositInThirdAssetMegaRoutes,
                    receiver: address(this),
                    deadline: _vars.deadline
                }),
                _pmParams.oracleTolerableLimitForThirdAsset,
                data.dexAdapter,
                address(_pmParams.priceOracle),
                true,
                _vars.thirdAssetOracleData
            );
            _position.positionAmount += data.depositInPositionAsset;
        } else {
            _require(
                _vars.depositInThirdAssetMegaRoutes.length == 0,
                Errors.DEPOSIT_IN_THIRD_ASSET_ROUTES_LENGTH_SHOULD_BE_0.selector
            );
        }

        data.borrowedAmountInPositionAsset = PrimexPricingLibrary.megaSwap(
            PrimexPricingLibrary.MegaSwapParams({
                tokenA: _position.soldAsset,
                tokenB: _position.positionAsset,
                amountTokenA: data.isSpot ? _vars.depositData.depositAmount : data.amountToTransfer,
                megaRoutes: _vars.firstAssetMegaRoutes,
                receiver: address(this),
                deadline: _vars.deadline
            }),
            _pmParams.oracleTolerableLimit,
            data.dexAdapter,
            address(_pmParams.priceOracle),
            _vars.needOracleTolerableLimitCheck,
            _vars.firstAssetOracleData
        );
        _position.positionAmount += data.borrowedAmountInPositionAsset;

        OpenPositionEventData memory posEventData;

        if (_vars.byOrder) {
            posEventData.feeRateType = data.isSpot
                ? IPrimexDNSStorageV3.FeeRateType.SpotLimitOrderExecuted
                : IPrimexDNSStorageV3.FeeRateType.MarginLimitOrderExecuted;
            (posEventData.feeInPositionAsset, posEventData.feeInPmx) = PrimexPricingLibrary.payProtocolFee(
                PrimexPricingLibrary.ProtocolFeeParams({
                    feeToken: decodeFeeTokenAddress(_position.extraParams),
                    trader: _position.trader,
                    priceOracle: address(_pmParams.priceOracle),
                    feeRateType: posEventData.feeRateType,
                    traderBalanceVault: _pmParams.traderBalanceVault,
                    swapManager: address(0),
                    keeperRewardDistributor: _pmParams.keeperRewardDistributor,
                    primexDNS: _pmParams.primexDNS,
                    paymentAsset: _position.positionAsset,
                    paymentAmount: _position.positionAmount,
                    gasSpent: _pmParams.initialGasLeft - gasleft(),
                    isFeeProhibitedInPmx: false,
                    pmxPaymentAssetOracleData: _vars.pmxPositionAssetOracleData,
                    nativePaymentAssetOracleData: _vars.nativePositionAssetOracleData
                })
            );
            _position.positionAmount -= posEventData.feeInPositionAsset;
        }
        _require(_position.positionAmount >= _vars.amountOutMin, Errors.SLIPPAGE_TOLERANCE_EXCEEDED.selector);

        data.leverage = WadRayMath.WAD;
        if (!data.isSpot) {
            _require(_pmParams.maxPositionSize >= _position.positionAmount, Errors.POSITION_SIZE_EXCEEDED.selector);
            if (_vars.depositData.depositAsset == _position.soldAsset) {
                data.positionAmountAfterFeeInSoldAsset =
                    (data.amountToTransfer * _position.positionAmount) /
                    (_position.positionAmount + posEventData.feeInPositionAsset);
                _require(
                    data.positionAmountAfterFeeInSoldAsset > _vars.borrowedAmount,
                    Errors.INSUFFICIENT_DEPOSIT.selector
                );
                data.leverage = data.positionAmountAfterFeeInSoldAsset.wdiv(
                    data.positionAmountAfterFeeInSoldAsset - _vars.borrowedAmount
                );
            } else {
                _require(
                    data.depositInPositionAsset > posEventData.feeInPositionAsset,
                    Errors.INSUFFICIENT_DEPOSIT.selector
                );
                data.leverage = _position.positionAmount.wdiv(
                    data.depositInPositionAsset - posEventData.feeInPositionAsset
                );
            }

            // to avoid stack to deep
            data.positionAsset = _position.positionAsset;
            data.positionAmount = _position.positionAmount;
            // protocolFee calculated in position Asset
            _require(
                data.leverage <=
                    _position.bucket.maxAssetLeverage(
                        _position.positionAsset,
                        PrimexPricingLibrary
                            .calculateFeeInPaymentAsset(
                                PrimexPricingLibrary.CalculateFeeInPaymentAssetParams({
                                    primexDNS: _pmParams.primexDNS,
                                    priceOracle: address(_pmParams.priceOracle),
                                    feeRateType: IPrimexDNSStorageV3.FeeRateType.MarginPositionClosedByKeeper,
                                    paymentAsset: data.positionAsset,
                                    paymentAmount: data.positionAmount,
                                    keeperRewardDistributor: _pmParams.keeperRewardDistributor,
                                    gasSpent: 0,
                                    isFeeProhibitedInPmx: true,
                                    nativePaymentAssetOracleData: _vars.nativePositionAssetOracleData
                                })
                            )
                            .wdiv(data.positionAmount)
                    ),
                Errors.INSUFFICIENT_DEPOSIT.selector
            );
            if (_vars.byOrder) {
                uint256 leverageTolerance = _pmParams.primexDNS.leverageTolerance();
                _require(
                    data.leverage <= _vars.orderLeverage.wmul(WadRayMath.WAD + leverageTolerance) &&
                        data.leverage >= _vars.orderLeverage.wmul(WadRayMath.WAD - leverageTolerance),
                    Errors.LEVERAGE_TOLERANCE_EXCEEDED.selector
                );
            }
        }

        if (!_vars.byOrder) {
            _vars.depositData.leverage = data.leverage;
        }

        data.multiplierBorrowedAsset = 10 ** (18 - IERC20Metadata(_position.soldAsset).decimals());
        data.multiplierPositionAsset = 10 ** (18 - IERC20Metadata(_position.positionAsset).decimals());
        posEventData.entryPrice =
            ((_vars.borrowedAmount + _position.depositAmountInSoldAsset) * data.multiplierBorrowedAsset).wdiv(
                (_position.positionAmount + posEventData.feeInPositionAsset) * data.multiplierPositionAsset
            ) /
            data.multiplierBorrowedAsset;
        posEventData.leverage = _vars.depositData.leverage;
        return (_position, posEventData);
    }

    /**
     * @dev Retrieves the debt amount for a given position.
     * @param position The Position struct representing the position to get the debt amount for.
     * @return The debt amount in debtTokens.
     */
    function getDebt(Position memory position) public view returns (uint256) {
        if (position.scaledDebtAmount == 0) return 0;
        return position.scaledDebtAmount.rmul(position.bucket.getNormalizedVariableDebt());
    }

    /**
     * @dev Calculates the health of a position.
     * @dev health = ((1 - securityBuffer) * (1 - oracleTolerableLimit) * (1 - priceDrop) * positionAmountInBorrowedAsset) /
     (feeBuffer * debt)
     * @param position The position object containing relevant information.
     * @param priceOracle The price oracle contract used for obtaining asset prices.
     * @param pairPriceDrop The priceDrop in WAD format of the asset pair.
     * @param securityBuffer The security buffer in WAD format for the position.
     * @param oracleTolerableLimit The tolerable limit in WAD format for the price oracle.
     * @return The health value in WAD format of the position.
     */
    function health(
        Position memory position,
        IPriceOracleV2 priceOracle,
        uint256 pairPriceDrop,
        uint256 securityBuffer,
        uint256 oracleTolerableLimit,
        uint256 feeInPaymentAsset,
        bytes memory positionSoldAssetOracleData
    ) public returns (uint256) {
        if (position.scaledDebtAmount == 0) return WadRayMath.WAD;
        return
            health(
                PrimexPricingLibrary.getOracleAmountsOut(
                    position.positionAsset,
                    position.soldAsset,
                    position.positionAmount,
                    address(priceOracle),
                    positionSoldAssetOracleData
                ) - feeInPaymentAsset,
                pairPriceDrop,
                securityBuffer,
                oracleTolerableLimit,
                getDebt(position),
                position.bucket.feeBuffer()
            );
    }

    /**
     * @dev Creates a new position based on the given parameters.
     * @param _params The input parameters for creating the position.
     * @param primexDNS The address of the PrimexDNS contract.
     * @param priceOracle The address of the PriceOracle contract.
     * @return position The created Position struct.
     * @return vars The OpenPositionVars struct.
     */
    function createPosition(
        OpenPositionParams calldata _params,
        IPrimexDNSV3 primexDNS,
        IPriceOracleV2 priceOracle
    ) public returns (Position memory, OpenPositionVars memory) {
        OpenPositionVars memory vars = OpenPositionVars({
            firstAssetMegaRoutes: _params.firstAssetMegaRoutes,
            depositInThirdAssetMegaRoutes: _params.marginParams.depositInThirdAssetMegaRoutes,
            depositData: PrimexPricingLibrary.DepositData({
                depositAsset: address(0),
                depositAmount: _params.depositAmount,
                leverage: 0
            }),
            borrowedAmount: _params.marginParams.borrowedAmount,
            amountOutMin: _params.amountOutMin,
            deadline: _params.deadline,
            isSpot: _params.marginParams.borrowedAmount == 0,
            isThirdAsset: false,
            takeDepositFromWallet: _params.takeDepositFromWallet,
            byOrder: false,
            orderLeverage: 0,
            sender: address(0),
            closeConditions: _params.closeConditions,
            needOracleTolerableLimitCheck: _params.marginParams.borrowedAmount > 0,
            firstAssetOracleData: _params.firstAssetOracleData,
            thirdAssetOracleData: _params.thirdAssetOracleData,
            positionUsdOracleData: _params.positionUsdOracleData,
            nativePositionAssetOracleData: _params.nativePositionAssetOracleData,
            pmxPositionAssetOracleData: _params.pmxPositionAssetOracleData,
            nativeSoldAssetOracleData: _params.nativeSoldAssetOracleData
        });

        PositionLibrary.Position memory position = PositionLibrary.Position({
            id: 0,
            scaledDebtAmount: 0,
            bucket: IBucketV3(address(0)),
            soldAsset: address(0),
            depositAmountInSoldAsset: 0,
            positionAsset: _params.positionAsset,
            positionAmount: 0,
            trader: msg.sender,
            openBorrowIndex: 0,
            createdAt: block.timestamp,
            updatedConditionsAt: block.timestamp,
            extraParams: ""
        });

        if (vars.isSpot) {
            _require(_params.depositAsset != _params.positionAsset, Errors.SHOULD_BE_DIFFERENT_ASSETS_IN_SPOT.selector);
            _require(bytes(_params.marginParams.bucket).length == 0, Errors.BUCKET_SHOULD_BE_UNDEFINED.selector);
            position.soldAsset = _params.depositAsset;
            position.depositAmountInSoldAsset = vars.depositData.depositAmount;
            vars.depositData.leverage = WadRayMath.WAD;
        } else {
            position.bucket = IBucketV3(primexDNS.getBucketAddress(_params.marginParams.bucket));
            position.soldAsset = address(position.bucket.borrowedAsset());
            vars.depositData.depositAsset = _params.depositAsset;
            (, bool tokenAllowed) = position.bucket.allowedAssets(_params.positionAsset);
            _require(tokenAllowed, Errors.TOKEN_NOT_SUPPORTED.selector);

            vars.isThirdAsset =
                _params.depositAsset != position.soldAsset &&
                _params.depositAsset != _params.positionAsset;

            position.depositAmountInSoldAsset = PrimexPricingLibrary.getOracleAmountsOut(
                _params.depositAsset,
                position.soldAsset,
                _params.depositAmount,
                address(priceOracle),
                _params.depositSoldAssetOracleData
            );
        }
        address feeToken = _params.isProtocolFeeInPmx ? primexDNS.pmx() : position.soldAsset;
        position.extraParams = abi.encode(feeToken);

        return (position, vars);
    }

    /**
     * @notice Creates a position based on the provided order parameters.
     * @dev This function calculates and returns a Position and OpenPositionVars struct.
     * @param _params The OpenPositionByOrderParams struct containing the order parameters.
     * @param priceOracle The price oracle contract used for retrieving asset prices.
     * @return position The Position struct representing the created position.
     * @return vars The OpenPositionVars struct containing additional variables related to the position.
     */
    function createPositionByOrder(
        LimitOrderLibrary.OpenPositionByOrderParams calldata _params,
        IPriceOracleV2 priceOracle,
        IPrimexDNSV3 primexDNS
    ) public returns (Position memory, OpenPositionVars memory) {
        OpenPositionVars memory vars = OpenPositionVars({
            firstAssetMegaRoutes: _params.firstAssetMegaRoutes,
            depositInThirdAssetMegaRoutes: _params.depositInThirdAssetMegaRoutes,
            depositData: PrimexPricingLibrary.DepositData({
                depositAsset: address(0),
                depositAmount: _params.order.depositAmount,
                leverage: _params.order.leverage
            }),
            borrowedAmount: _params.borrowedAmount,
            amountOutMin: 0,
            orderLeverage: _params.order.leverage,
            deadline: _params.order.deadline,
            isSpot: _params.order.leverage == WadRayMath.WAD,
            isThirdAsset: false,
            takeDepositFromWallet: false,
            byOrder: true,
            sender: _params.sender,
            closeConditions: _params.closeConditions,
            needOracleTolerableLimitCheck: address(_params.order.bucket) != address(0),
            firstAssetOracleData: _params.firstAssetOracleData,
            thirdAssetOracleData: _params.thirdAssetOracleData,
            positionUsdOracleData: _params.positionUsdOracleData,
            nativePositionAssetOracleData: _params.nativePositionAssetOracleData,
            pmxPositionAssetOracleData: _params.pmxPositionAssetOracleData,
            nativeSoldAssetOracleData: _params.nativeSoldAssetOracleData
        });

        Position memory position = Position({
            id: 0,
            scaledDebtAmount: 0,
            bucket: IBucketV3(address(0)),
            soldAsset: address(0),
            depositAmountInSoldAsset: 0,
            positionAsset: _params.order.positionAsset,
            positionAmount: 0,
            trader: _params.order.trader,
            openBorrowIndex: 0,
            createdAt: block.timestamp,
            updatedConditionsAt: block.timestamp,
            extraParams: ""
        });

        if (vars.isSpot) {
            position.soldAsset = _params.order.depositAsset;
            position.depositAmountInSoldAsset = vars.depositData.depositAmount;
        } else {
            position.bucket = _params.order.bucket;
            position.soldAsset = address(position.bucket.borrowedAsset());
            vars.depositData.depositAsset = _params.order.depositAsset;
            vars.isThirdAsset =
                _params.order.depositAsset != position.soldAsset &&
                _params.order.depositAsset != _params.order.positionAsset;

            position.depositAmountInSoldAsset = PrimexPricingLibrary.getOracleAmountsOut(
                _params.order.depositAsset,
                position.soldAsset,
                _params.order.depositAmount,
                address(priceOracle),
                _params.depositSoldAssetOracleData
            );
            if (_params.order.depositAsset == position.soldAsset) {
                _require(
                    vars.borrowedAmount == _params.order.depositAmount.wmul(_params.order.leverage - WadRayMath.WAD),
                    Errors.INCORRECT_BORROWED_AMOUNT.selector
                );
            }
        }
        address feeToken = _params.order.feeToken == primexDNS.pmx() ? primexDNS.pmx() : position.soldAsset;
        position.extraParams = abi.encode(feeToken);

        return (position, vars);
    }

    /**
     * @notice Decodes a fee token address from the provided encoded data.
     * @param data The encoded data containing the fee token address.
     * @return The decoded fee token address.
     */
    function decodeFeeTokenAddress(bytes memory data) public pure returns (address) {
        // Check if there is data in the bytes extraParams
        if (data.length == 0) {
            // If there is no data, return address(0)
            return address(0);
        } else {
            // Decode the data into an address and return the result
            return abi.decode(data, (address));
        }
    }

    /**
     * @notice Calculates the health score for a position.
     * @param positionAmountInBorrowedAsset The position size in borrow asset.
     * @param pairPriceDrop The priceDrop in WAD format of the pair.
     * @param securityBuffer The security buffer in WAD format.
     * @param oracleTolerableLimit The tolerable limit in WAD format for the oracle.
     * @param positionDebt The debt of the position.
     * @param feeBuffer The buffer for fees.
     * @return The health score of the position.
     */
    function health(
        uint256 positionAmountInBorrowedAsset,
        uint256 pairPriceDrop,
        uint256 securityBuffer,
        uint256 oracleTolerableLimit,
        uint256 positionDebt,
        uint256 feeBuffer
    ) public pure returns (uint256) {
        return
            (
                (WadRayMath.WAD - securityBuffer)
                    .wmul(WadRayMath.WAD - oracleTolerableLimit)
                    .wmul(WadRayMath.WAD - pairPriceDrop)
                    .wmul(positionAmountInBorrowedAsset)
            ).wdiv(feeBuffer.wmul(positionDebt));
    }
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {BytesLib} from "./utils/BytesLib.sol";
import {WadRayMath} from "./utils/WadRayMath.sol";

import {NATIVE_CURRENCY, USD, USD_MULTIPLIER, ARB_NITRO_ORACLE, OVM_GASPRICEORACLE, GAS_FOR_BYTE, TRANSACTION_METADATA_BYTES} from "../Constants.sol";
import {IDexAdapter} from "../interfaces/IDexAdapter.sol";
import {IPriceOracle} from "../PriceOracle/IPriceOracle.sol";
import {IKeeperRewardDistributorStorage, IKeeperRewardDistributorV3} from "../KeeperRewardDistributor/IKeeperRewardDistributor.sol";
import {IPrimexDNSV3, IPrimexDNSStorageV3} from "../PrimexDNS/IPrimexDNS.sol";
import {IBucketV3} from "../Bucket/IBucket.sol";
import {IPositionManagerV2} from "../PositionManager/IPositionManager.sol";
import {ITraderBalanceVault} from "../TraderBalanceVault/ITraderBalanceVault.sol";
import {TokenTransfersLibrary} from "./TokenTransfersLibrary.sol";
import {IPriceOracleStorageV2} from "../PriceOracle/IPriceOracleStorage.sol";
import {IPriceOracleV2} from "../PriceOracle/IPriceOracle.sol";
import "./Errors.sol";

library PrimexPricingLibrary {
    using WadRayMath for uint256;
    using BytesLib for bytes;

    /**
     * @param dexName The name of the DEX.
     * @param shares the share that will be allocated from the total amount for the route
     * @param payload payload data encoded in bytes
     */

    struct Path {
        string dexName;
        uint256 shares;
        bytes payload;
    }

    /**
     * @param to the destination token of the route
     * @param paths path array through which the swap will be made up to the destination token this the route
     */

    struct Route {
        address to;
        Path[] paths;
    }

    /**
     * @param shares the share that will be allocated from the total amount for this MegaRoute
     * @param routes array of routes through which the swap will be made up to TokenB
     */
    struct MegaRoute {
        uint256 shares;
        Route[] routes;
    }

    struct MegaSwapParams {
        address tokenA;
        address tokenB;
        uint256 amountTokenA;
        MegaRoute[] megaRoutes;
        address receiver;
        uint256 deadline;
    }

    struct AmountParams {
        address tokenA;
        address tokenB;
        uint256 amount;
        MegaRoute[] megaRoutes;
        address dexAdapter;
        address primexDNS;
    }

    struct DepositData {
        address depositAsset;
        uint256 depositAmount;
        uint256 leverage;
    }

    /**
     * @param feeToken An asset in which the fee will be paid.
     * @param trader The trader address
     * @param priceOracle PriceOracle contract address
     * @param orderType Type of possible order in Primex protocol
     * @param traderBalanceVault TraderBalanceVault contract address
     * @param primexDNS PrimexDNS contract address
     */
    struct ProtocolFeeParams {
        address feeToken;
        address trader;
        address priceOracle;
        IPrimexDNSStorageV3.FeeRateType feeRateType;
        ITraderBalanceVault traderBalanceVault;
        address swapManager;
        address keeperRewardDistributor;
        IPrimexDNSV3 primexDNS;
        address paymentAsset;
        uint256 paymentAmount;
        uint256 gasSpent;
        bool isFeeProhibitedInPmx;
        bytes pmxPaymentAssetOracleData;
        bytes nativePaymentAssetOracleData;
    }

    struct ProtocolFeeParamsBatchClose {
        uint256 numberOfPositions;
        address[] feeTokens;
        address[] traders;
        uint256[] paymentAmounts;
        address paymentAsset;
        address priceOracle;
        IPrimexDNSStorageV3.FeeRateType feeRateType;
        ITraderBalanceVault traderBalanceVault;
        address keeperRewardDistributor;
        IPrimexDNSV3 primexDNS;
        uint256 estimatedGasAmount;
        bool isFeeProhibitedInPmx;
        uint256 estimatedBaseLength;
        bytes nativePaymentAssetOracleData;
        bytes pmxPaymentAssetOracleData;
    }

    struct CalculateFeeInPaymentAssetParams {
        IPrimexDNSV3 primexDNS;
        address priceOracle;
        IPrimexDNSStorageV3.FeeRateType feeRateType;
        address paymentAsset;
        uint256 paymentAmount;
        address keeperRewardDistributor;
        uint256 gasSpent;
        bool isFeeProhibitedInPmx;
        bytes nativePaymentAssetOracleData;
    }

    struct MinProtocolFeeParams {
        uint256 restrictedGasSpent;
        address paymentAsset;
        address priceOracle;
        IKeeperRewardDistributorV3 keeperRewardDistributor;
        IPrimexDNSV3 primexDNS;
        bool isFeeProhibitedInPmx;
        IPrimexDNSStorageV3.FeeRateType feeRateType;
        bytes nativePaymentAssetOracleData;
    }

    /**
     * The struct for payProtocolFee function
     */
    struct ProtocolFeeVars {
        address pmx;
        address treasury;
        uint256 feeInPaymentAssetWithDiscount;
        uint256 pmxTraderBalance;
        uint256 pmxTraderBalanceInPaymentAsset;
        uint256 pmxDiscountMultiplier;
    }

    /**
     * The struct for calculateFeeInPaymentAssetVars function
     */
    struct FeeInPaymentAssetVars {
        uint256 protocolFeeRate;
        uint256 maxProtocolFee;
        uint256 feeInPaymentAsset;
        uint256 maxProtocolFeeInPaymentAsset;
        uint256 minProtocolFeeInPaymentAsset;
    }

    /**
     * The struct for minProtocolFee function
     */
    struct MinProtocolFeeVars {
        uint256 maxGasAmount;
        uint256 restrictedGasPrice;
        uint256 l1CostWei;
        uint256 liquidationGasAmount;
        uint256 protocolFeeCoefficient;
        uint256 additionalGasSpent;
        uint256 minProtocolFeeInNativeAsset;
        uint256 totalGasSpent;
        uint256 baseLength;
        uint256 optimisticGasCoefficient;
        IPrimexDNSStorageV3.CallingMethod callingMethod;
        IKeeperRewardDistributorStorage.PaymentModel paymentModel;
    }

    /**
     * The struct for calculateFeeInPaymentAssetBatchClose function
     */
    struct CalculateFeeInPaymentAssetBatchCloseVars {
        uint256[] feeInPaymentAsset;
        uint256 protocolFeeRate;
        uint256 maxProtocolFee;
        uint256 maxProtocolFeeInPaymentAsset;
        uint256 minProtocolFeeInPaymentAsset;
    }

    /**
     * The struct for calculateRestrictedGasPrice function
     */
    struct RestrictedGasPriceVars {
        int256 oracleGasPrice;
        uint256 maxGasPrice;
        uint256 defaultMaxGasPrice;
        uint256 oracleGasPriceTolerance;
    }

    /**
     * The struct for getLiquidationPrice and getLiquidationPriceByOrder functions
     */
    struct LiquidationPriceData {
        IBucketV3 bucket;
        IPositionManagerV2 positionManager;
        IPriceOracleV2 priceOracle;
        IERC20Metadata borrowedAsset;
    }

    event Withdraw(
        address indexed withdrawer,
        address borrowAssetReceiver,
        address borrowedAsset,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @notice Encodes the given parameters into a bytes array based on the specified DEX type.
     * @param path The token path for the swap.
     * @param dexRouter The address of the DEX router.
     * @param ancillaryData Additional data required for certain DEX types.
     * @param dexAdapter The address of the DEX adapter.
     * @param isAmountToBuy A flag indicating whether it is the path for the swap with fixed amountIn or amountOut.
     * Swap with fixed amountIn, if true.
     * @return The encoded bytes array.
     */
    function encodePath(
        address[] memory path,
        address dexRouter,
        bytes32 ancillaryData,
        address payable dexAdapter,
        bool isAmountToBuy
    ) external view returns (bytes memory) {
        IDexAdapter.DexType type_ = IDexAdapter(dexAdapter).dexType(dexRouter);

        if (type_ == IDexAdapter.DexType.UniswapV2 || type_ == IDexAdapter.DexType.Meshswap) {
            return abi.encode(path);
        }
        if (type_ == IDexAdapter.DexType.UniswapV3) {
            if (isAmountToBuy)
                return bytes.concat(bytes20(path[1]), bytes3(uint24(uint256(ancillaryData))), bytes20(path[0]));
            return bytes.concat(bytes20(path[0]), bytes3(uint24(uint256(ancillaryData))), bytes20(path[1]));
        }
        if (type_ == IDexAdapter.DexType.AlgebraV3) {
            if (isAmountToBuy) return bytes.concat(bytes20(path[1]), bytes20(path[0]));
            return bytes.concat(bytes20(path[0]), bytes20(path[1]));
        }
        if (type_ == IDexAdapter.DexType.Curve) {
            address[] memory pools = new address[](1);
            pools[0] = address(uint160(uint256(ancillaryData)));
            return abi.encode(path, pools);
        }
        if (type_ == IDexAdapter.DexType.Balancer) {
            int256[] memory limits = new int256[](2);
            limits[0] = type(int256).max;
            bytes32[] memory pools = new bytes32[](1);
            pools[0] = ancillaryData;
            return abi.encode(path, pools, limits);
        }
        _revert(Errors.UNKNOWN_DEX_TYPE.selector);
    }

    /**
     * @notice Calculates the amount of deposit assets in borrowed assets.
     * @param _params The parameters for the calculation.
     * @param _isThirdAsset A flag indicating if deposit is in a third asset.
     * @param _priceOracle The address of the price oracle.
     * @return The amount of deposit assets is measured in borrowed assets.
     */
    function getDepositAmountInBorrowed(
        IDexAdapter.AmountParams calldata _params,
        bool _isThirdAsset,
        address payable _dexAdapter,
        address _priceOracle,
        bytes calldata _oracleData
    ) public returns (uint256) {
        _require(
            IERC165(_priceOracle).supportsInterface(type(IPriceOracleV2).interfaceId),
            Errors.ADDRESS_NOT_SUPPORTED.selector
        );
        if (_params.tokenA == _params.tokenB) {
            _require(_params.megaRoutes.length == 0, Errors.DEPOSITED_TO_BORROWED_ROUTES_LENGTH_SHOULD_BE_0.selector);
            return _params.amount;
        }

        uint256 depositAmountInBorrowed = IDexAdapter(_dexAdapter).getAmountOutByMegaRoutes(_params);
        if (_isThirdAsset) {
            uint256 oracleDepositAmountOut = getOracleAmountsOut(
                _params.tokenA,
                _params.tokenB,
                _params.amount,
                _priceOracle,
                _oracleData
            );
            if (depositAmountInBorrowed > oracleDepositAmountOut) depositAmountInBorrowed = oracleDepositAmountOut;
        }

        return depositAmountInBorrowed;
    }

    /**
     * @notice Performs a multi-hop swap transaction using the specified parameters.
     * @dev This function executes a series of token swaps on different DEXs based on the provided routes.
     * @param _params The struct containing all the necessary parameters for the multi-hop swap.
     * @param _maximumOracleTolerableLimit The maximum tolerable limit in WAD format (1 WAD = 100%)
     * for the price difference between DEX and the oracle.
     * @param _dexAdapter The address of the Dex adapter contract.
     * @param _priceOracle The address of the price oracle contract.
     * @param _needOracleTolerableLimitCheck Flag indicating whether to perform an oracle tolerable limit check.
     * @return The final balance of the _params.tokenB in the receiver's address after the multi-hop swap.
     */
    function megaSwap(
        MegaSwapParams calldata _params,
        uint256 _maximumOracleTolerableLimit,
        address payable _dexAdapter,
        address _priceOracle,
        bool _needOracleTolerableLimitCheck,
        bytes calldata _oracleData
    ) public returns (uint256) {
        uint256 balance = IERC20Metadata(_params.tokenB).balanceOf(_params.receiver);
        IDexAdapter(_dexAdapter).performMegaRoutesSwap(_params);

        balance = IERC20Metadata(_params.tokenB).balanceOf(_params.receiver) - balance;
        if (_needOracleTolerableLimitCheck) {
            _require(
                balance >=
                    getOracleAmountsOut(_params.tokenA, _params.tokenB, _params.amountTokenA, _priceOracle, _oracleData)
                        .wmul(WadRayMath.WAD - _maximumOracleTolerableLimit),
                Errors.DIFFERENT_PRICE_DEX_AND_ORACLE.selector
            );
        }

        return balance;
    }

    /**
     * @notice Pays the protocol fee.
     * @dev This function transfers the protocol fee from the trader to the protocol treasury.
     * @param params The parameters for paying the protocol fee.
     * @return feeInPaymentAsset The amount of the protocol fee in a payment asset
     * (position asset for the limit order execution, sold asset when the position is closed.)
     * @return feeInPmx The amount of the protocol fee in pmx asset paid.
     */
    function payProtocolFee(
        ProtocolFeeParams memory params
    ) public returns (uint256 feeInPaymentAsset, uint256 feeInPmx) {
        // This is done to ensure that after upgrading the contracts, positions that have already been opened
        // and had fees paid for them will not incur additional fees upon closure
        if (params.feeToken == address(0)) {
            return (0, 0);
        }

        ProtocolFeeVars memory vars;
        (vars.pmx, vars.treasury, , , vars.pmxDiscountMultiplier) = params.primexDNS.getPrimexDNSParams(
            params.feeRateType
        );
        feeInPaymentAsset = calculateFeeInPaymentAsset(
            CalculateFeeInPaymentAssetParams({
                primexDNS: params.primexDNS,
                priceOracle: params.priceOracle,
                feeRateType: params.feeRateType,
                paymentAsset: params.paymentAsset,
                paymentAmount: params.paymentAmount,
                keeperRewardDistributor: params.keeperRewardDistributor,
                gasSpent: params.gasSpent,
                isFeeProhibitedInPmx: params.isFeeProhibitedInPmx,
                nativePaymentAssetOracleData: params.nativePaymentAssetOracleData
            })
        );
        (vars.pmxTraderBalance, ) = params.traderBalanceVault.balances(params.trader, vars.pmx);
        if (params.feeToken == vars.pmx && vars.pmxTraderBalance > 0 && !params.isFeeProhibitedInPmx) {
            // pmx => payment asset data
            uint256 pmxTraderBalanceInPaymentAsset = getOracleAmountsOut(
                vars.pmx,
                params.paymentAsset,
                vars.pmxTraderBalance,
                params.priceOracle,
                params.pmxPaymentAssetOracleData
            );

            uint256 feeInPaymentAssetWithDiscount = feeInPaymentAsset.wmul(vars.pmxDiscountMultiplier);

            feeInPmx = (feeInPaymentAssetWithDiscount * vars.pmxTraderBalance) / pmxTraderBalanceInPaymentAsset;

            if (pmxTraderBalanceInPaymentAsset >= feeInPaymentAssetWithDiscount) {
                feeInPaymentAsset = 0;
                params.traderBalanceVault.withdrawFrom(params.trader, vars.treasury, vars.pmx, feeInPmx, false);
            } else {
                feeInPmx = vars.pmxTraderBalance;
                feeInPaymentAsset -= pmxTraderBalanceInPaymentAsset.wdiv(vars.pmxDiscountMultiplier);
                params.traderBalanceVault.withdrawFrom(
                    params.trader,
                    vars.treasury,
                    vars.pmx,
                    vars.pmxTraderBalance,
                    false
                );
                TokenTransfersLibrary.doTransferOut(params.paymentAsset, vars.treasury, feeInPaymentAsset);
            }
        } else {
            TokenTransfersLibrary.doTransferOut(params.paymentAsset, vars.treasury, feeInPaymentAsset);
        }
    }

    /**
     * @notice Calculate and return protocol fee
     * @return The amount of the protocol fee in '_feeToken' which needs to be paid according to the specified deposit parameters.
     */
    function calculateFeeInPaymentAsset(CalculateFeeInPaymentAssetParams memory params) public returns (uint256) {
        FeeInPaymentAssetVars memory vars;
        (, , vars.protocolFeeRate, vars.maxProtocolFee, ) = params.primexDNS.getPrimexDNSParams(params.feeRateType);
        // Calculate protocol fee in position asset
        vars.feeInPaymentAsset = params.paymentAmount.wmul(vars.protocolFeeRate);

        // Calculate max protocol fee in position asset
        vars.maxProtocolFeeInPaymentAsset = vars.maxProtocolFee == type(uint256).max
            ? type(uint256).max
            : getOracleAmountsOut(
                NATIVE_CURRENCY,
                params.paymentAsset,
                vars.maxProtocolFee,
                params.priceOracle,
                params.nativePaymentAssetOracleData
            );

        // The minProtocolFee is applied only if the order/position is processed by Keepers

        if (
            params.feeRateType == IPrimexDNSStorageV3.FeeRateType.MarginPositionClosedByTrader ||
            params.feeRateType == IPrimexDNSStorageV3.FeeRateType.SpotPositionClosedByTrader ||
            params.feeRateType == IPrimexDNSStorageV3.FeeRateType.SwapMarketOrder
        ) {
            vars.feeInPaymentAsset = min(vars.feeInPaymentAsset, vars.maxProtocolFeeInPaymentAsset);
        } else {
            vars.minProtocolFeeInPaymentAsset = minProtocolFee(
                MinProtocolFeeParams({
                    restrictedGasSpent: params.gasSpent,
                    paymentAsset: params.paymentAsset,
                    priceOracle: params.priceOracle,
                    keeperRewardDistributor: IKeeperRewardDistributorV3(params.keeperRewardDistributor),
                    primexDNS: params.primexDNS,
                    isFeeProhibitedInPmx: params.isFeeProhibitedInPmx,
                    feeRateType: params.feeRateType,
                    nativePaymentAssetOracleData: params.nativePaymentAssetOracleData
                })
            );
            _require(
                vars.minProtocolFeeInPaymentAsset < params.paymentAmount,
                Errors.MIN_PROTOCOL_FEE_IS_GREATER_THAN_PAYMENT_AMOUNT.selector
            );

            vars.feeInPaymentAsset = min(
                max(vars.feeInPaymentAsset, vars.minProtocolFeeInPaymentAsset),
                vars.maxProtocolFeeInPaymentAsset
            );
        }
        return vars.feeInPaymentAsset;
    }

    function payProtocolFeeBatchClose(
        ProtocolFeeParamsBatchClose calldata params
    ) public returns (uint256[] memory, uint256[] memory) {
        ProtocolFeeVars memory vars;
        uint256[] memory feeInPaymentAsset = new uint256[](params.numberOfPositions);
        uint256[] memory feeInPmx = new uint256[](params.numberOfPositions);

        (vars.pmx, vars.treasury, , , vars.pmxDiscountMultiplier) = params.primexDNS.getPrimexDNSParams(
            params.feeRateType
        );
        feeInPaymentAsset = calculateFeeInPaymentAssetBatchClose(
            params.numberOfPositions,
            params.primexDNS,
            params.priceOracle,
            params.feeRateType,
            params.paymentAsset,
            params.paymentAmounts,
            params.keeperRewardDistributor,
            params.estimatedGasAmount,
            params.estimatedBaseLength,
            params.nativePaymentAssetOracleData
        );
        for (uint256 i; i < params.numberOfPositions; i++) {
            // This is done to ensure that after upgrading the contracts, positions that have already been opened
            // and had fees paid for them will not incur additional fees upon closure
            if (params.feeTokens[i] == address(0)) {
                feeInPaymentAsset[i] = 0;
                feeInPmx[i] = 0;
                continue;
            }

            (vars.pmxTraderBalance, ) = params.traderBalanceVault.balances(params.traders[i], vars.pmx);

            if (!params.isFeeProhibitedInPmx && params.feeTokens[i] == vars.pmx && vars.pmxTraderBalance > 0) {
                vars.pmxTraderBalanceInPaymentAsset = getOracleAmountsOut(
                    vars.pmx,
                    params.paymentAsset,
                    vars.pmxTraderBalance,
                    params.priceOracle,
                    params.pmxPaymentAssetOracleData
                );

                vars.feeInPaymentAssetWithDiscount = feeInPaymentAsset[i].wmul(vars.pmxDiscountMultiplier);
                feeInPmx[i] =
                    (vars.feeInPaymentAssetWithDiscount * vars.pmxTraderBalance) /
                    vars.pmxTraderBalanceInPaymentAsset;
                if (vars.pmxTraderBalanceInPaymentAsset >= vars.feeInPaymentAssetWithDiscount) {
                    feeInPaymentAsset[i] = 0;
                    params.traderBalanceVault.withdrawFrom(
                        params.traders[i],
                        vars.treasury,
                        vars.pmx,
                        feeInPmx[i],
                        false
                    );
                } else {
                    feeInPmx[i] = vars.pmxTraderBalance;
                    feeInPaymentAsset[i] -= vars.pmxTraderBalanceInPaymentAsset.wdiv(vars.pmxDiscountMultiplier);
                    params.traderBalanceVault.withdrawFrom(
                        params.traders[i],
                        vars.treasury,
                        vars.pmx,
                        vars.pmxTraderBalance,
                        false
                    );
                }
            }
        }
        return (feeInPaymentAsset, feeInPmx);
    }

    /**
     * @notice Calculate and return protocol fee
     * @return The amount of the protocol fee in '_feeToken' which needs to be paid according to the specified deposit parameters.
     */
    function calculateFeeInPaymentAssetBatchClose(
        uint256 numberOfPositions,
        IPrimexDNSV3 primexDNS,
        address priceOracle,
        IPrimexDNSStorageV3.FeeRateType feeRateType,
        address paymentAsset,
        uint256[] memory paymentAmounts,
        address keeperRewardDistributor,
        uint256 estimatedGasAmount,
        uint256 estimatedBaseLength,
        bytes calldata _nativePaymentAssetOracleData
    ) public returns (uint256[] memory) {
        CalculateFeeInPaymentAssetBatchCloseVars memory vars;
        (, , vars.protocolFeeRate, vars.maxProtocolFee, ) = primexDNS.getPrimexDNSParams(feeRateType);
        // Calculate max protocol fee in payment (sold) asset
        vars.maxProtocolFeeInPaymentAsset = vars.maxProtocolFee == type(uint256).max
            ? type(uint256).max
            : getOracleAmountsOut(
                NATIVE_CURRENCY,
                paymentAsset,
                vars.maxProtocolFee,
                priceOracle,
                _nativePaymentAssetOracleData
            );

        vars.minProtocolFeeInPaymentAsset = minProtocolFeeCloseBatch(
            paymentAsset,
            priceOracle,
            IKeeperRewardDistributorV3(keeperRewardDistributor),
            estimatedGasAmount,
            estimatedBaseLength,
            primexDNS,
            _nativePaymentAssetOracleData
        );

        vars.feeInPaymentAsset = new uint256[](numberOfPositions);
        // Calculate protocol fee in position asset
        for (uint256 i; i < numberOfPositions; i++) {
            vars.feeInPaymentAsset[i] = paymentAmounts[i].wmul(vars.protocolFeeRate);
            _require(
                vars.minProtocolFeeInPaymentAsset < paymentAmounts[i],
                Errors.MIN_PROTOCOL_FEE_IS_GREATER_THAN_PAYMENT_AMOUNT.selector
            );
            vars.feeInPaymentAsset[i] = min(
                max(vars.feeInPaymentAsset[i], vars.minProtocolFeeInPaymentAsset),
                vars.maxProtocolFeeInPaymentAsset
            );
        }

        return vars.feeInPaymentAsset;
    }

    /**
     * @notice Calculate minProtocolFee based on the gas price
     */
    function minProtocolFee(MinProtocolFeeParams memory params) public returns (uint256 minProtocolFeeInPositionAsset) {
        MinProtocolFeeVars memory vars;
        (vars.restrictedGasPrice) = calculateRestrictedGasPrice(params.priceOracle, params.keeperRewardDistributor);
        if (
            params.feeRateType == IPrimexDNSStorageV3.FeeRateType.MarginPositionClosedByKeeper ||
            params.feeRateType == IPrimexDNSStorageV3.FeeRateType.SpotPositionClosedByKeeper
        ) {
            vars.callingMethod = IPrimexDNSStorageV3.CallingMethod.ClosePositionByCondition;
        } else {
            vars.callingMethod = IPrimexDNSStorageV3.CallingMethod.OpenPositionByOrder;
        }
        (
            vars.liquidationGasAmount,
            vars.protocolFeeCoefficient,
            vars.additionalGasSpent,
            vars.maxGasAmount,
            vars.baseLength
        ) = params.primexDNS.getParamsForMinProtocolFee(vars.callingMethod);

        vars.l1CostWei = _calculateL1CostWei(vars.baseLength, params.keeperRewardDistributor);

        if (params.isFeeProhibitedInPmx) {
            vars.minProtocolFeeInNativeAsset =
                vars.liquidationGasAmount *
                vars.restrictedGasPrice +
                vars.l1CostWei +
                vars.protocolFeeCoefficient;
        } else {
            if (vars.callingMethod == IPrimexDNSStorageV3.CallingMethod.ClosePositionByCondition) {
                vars.minProtocolFeeInNativeAsset =
                    vars.maxGasAmount *
                    vars.restrictedGasPrice +
                    vars.l1CostWei +
                    vars.protocolFeeCoefficient;
            } else {
                vars.totalGasSpent = params.restrictedGasSpent + vars.additionalGasSpent;
                vars.totalGasSpent = min(vars.totalGasSpent, vars.maxGasAmount);

                vars.minProtocolFeeInNativeAsset =
                    vars.totalGasSpent *
                    vars.restrictedGasPrice +
                    vars.l1CostWei +
                    vars.protocolFeeCoefficient;
            }
        }
        minProtocolFeeInPositionAsset = getOracleAmountsOut(
            NATIVE_CURRENCY,
            params.paymentAsset,
            vars.minProtocolFeeInNativeAsset,
            params.priceOracle,
            params.nativePaymentAssetOracleData
        );
    }

    /**
     * @notice Calculate minProtocolFee based on the gas price in closeBatchPositions
     */
    function minProtocolFeeCloseBatch(
        address _paymentAsset,
        address _priceOracle,
        IKeeperRewardDistributorV3 _keeperRewardDistributor,
        uint256 _estimatedGasAmount,
        uint256 _estimatedBaseLength,
        IPrimexDNSV3 primexDNS,
        bytes calldata _nativePaymentAssetOracleData
    ) public returns (uint256 minProtocolFeeInPositionAsset) {
        uint256 restrictedGasPrice = calculateRestrictedGasPrice(_priceOracle, _keeperRewardDistributor);

        uint256 l1CostWei = _calculateL1CostWei(_estimatedBaseLength, _keeperRewardDistributor);

        uint256 minProtocolFeeInNativeAsset = _estimatedGasAmount *
            restrictedGasPrice +
            l1CostWei +
            primexDNS.protocolFeeCoefficient();

        minProtocolFeeInPositionAsset = getOracleAmountsOut(
            NATIVE_CURRENCY,
            _paymentAsset,
            minProtocolFeeInNativeAsset,
            _priceOracle,
            _nativePaymentAssetOracleData
        );
    }

    /**
     * @notice Calculate minPositionSize based on the gas price
     */
    function minPositionSize(
        address _priceOracle,
        IKeeperRewardDistributorV3 _keeperRewardDistributor,
        IPrimexDNSV3 _primexDNS,
        IPrimexDNSStorageV3.TradingOrderType _tradingOrderType
    ) public view returns (uint256 minPositionSizeInNativeAsset) {
        uint256 restrictedGasPrice = calculateRestrictedGasPrice(_priceOracle, _keeperRewardDistributor);
        (
            uint256 baseLength,
            uint256 averageGasPerAction,
            uint256 protocolFeeCoefficient,
            uint256 gasPriceBuffer
        ) = _primexDNS.getParamsForMinPositionSize(_tradingOrderType);
        uint256 l1CostWei = _calculateL1CostWei(baseLength, _keeperRewardDistributor);

        minPositionSizeInNativeAsset = (averageGasPerAction * restrictedGasPrice + l1CostWei + protocolFeeCoefficient)
            .wmul(gasPriceBuffer);
    }

    function calculateRestrictedGasPrice(
        address _priceOracle,
        IKeeperRewardDistributorV3 _keeperRewardDistributor
    ) internal view returns (uint256 restrictedGasPrice) {
        RestrictedGasPriceVars memory vars;
        restrictedGasPrice = tx.gasprice;
        vars.oracleGasPrice = IPriceOracle(_priceOracle).getGasPrice();
        (vars.oracleGasPriceTolerance, vars.defaultMaxGasPrice, , ) = _keeperRewardDistributor
            .getGasCalculationParams();

        vars.maxGasPrice = vars.oracleGasPrice > 0
            ? uint256(vars.oracleGasPrice).wmul(WadRayMath.WAD + vars.oracleGasPriceTolerance)
            : vars.defaultMaxGasPrice;

        if (restrictedGasPrice > vars.maxGasPrice || restrictedGasPrice == 0) {
            restrictedGasPrice = vars.maxGasPrice;
        }
    }

    function getOracleAmountsOut(
        address _tokenA,
        address _tokenB,
        uint256 _amountAssetA,
        address _priceOracle,
        bytes memory _oracleData
    ) public returns (uint256) {
        _require(
            IERC165(_priceOracle).supportsInterface(type(IPriceOracleV2).interfaceId),
            Errors.ADDRESS_NOT_SUPPORTED.selector
        );
        if (_tokenA == _tokenB) {
            return _amountAssetA;
        }
        uint256 exchangeRate = IPriceOracleV2(_priceOracle).getExchangeRate(_tokenA, _tokenB, _oracleData);
        return (_amountAssetA * _getAssetMultiplier(_tokenA)).wmul(exchangeRate) / _getAssetMultiplier(_tokenB);
    }

    /**
     * @param _tokenA asset for sell
     * @param _tokenB asset to buy
     * @param _amountsAssetA An array of amounts of tokenA to sell
     * @param _priceOracle PriceOracle contract address
     * @return returns an array of amounts of `tokenB` by the `amountsAssetA` by the price of the oracle
     */
    function getBatchOracleAmountsOut(
        address _tokenA,
        address _tokenB,
        uint256[] memory _amountsAssetA,
        address _priceOracle,
        bytes calldata _oracleData
    ) public returns (uint256[] memory) {
        _require(
            IERC165(_priceOracle).supportsInterface(type(IPriceOracleV2).interfaceId),
            Errors.ADDRESS_NOT_SUPPORTED.selector
        );
        if (_tokenA == _tokenB) {
            return _amountsAssetA;
        }
        uint256[] memory amountsAssetB = new uint256[](_amountsAssetA.length);
        uint256 exchangeRate = IPriceOracleV2(_priceOracle).getExchangeRate(_tokenA, _tokenB, _oracleData);
        uint256 multiplier1 = 10 ** (18 - IERC20Metadata(_tokenA).decimals());
        uint256 multiplier2 = 10 ** (18 - IERC20Metadata(_tokenB).decimals());
        for (uint256 i; i < _amountsAssetA.length; i++) {
            amountsAssetB[i] = (_amountsAssetA[i] * multiplier1).wmul(exchangeRate) / multiplier2;
        }
        return amountsAssetB;
    }

    /**
     * @notice Calculates the liquidation price for a position.
     * @dev liquidationPrice = (feeBuffer * debt) /
     * ((1 - securityBuffer) * (1 - oracleTolerableLimit) * (1 - priceDrop) * positionAmount))
     * @param _bucket The address of the related bucket.
     * @param _positionAsset The address of the position asset.
     * @param _positionAmount The size of the opened position.
     * @param _positionDebt The debt amount in debtTokens associated with the position.
     * @return The calculated liquidation price in borrowed asset.
     */
    function getLiquidationPrice(
        address _bucket,
        address _positionAsset,
        uint256 _positionAmount,
        uint256 _positionDebt,
        address _primexDNS
    ) public view returns (uint256) {
        _require(_positionAsset != address(0), Errors.ADDRESS_NOT_SUPPORTED.selector);
        LiquidationPriceData memory data;
        data.bucket = IBucketV3(_bucket);
        data.positionManager = data.bucket.positionManager();
        data.borrowedAsset = data.bucket.borrowedAsset();
        data.priceOracle = data.positionManager.priceOracle();

        uint256 multiplier1 = 10 ** (18 - data.borrowedAsset.decimals());
        uint256 denominator = (WadRayMath.WAD - data.positionManager.securityBuffer())
            .wmul(
                WadRayMath.WAD -
                    data.positionManager.getOracleTolerableLimit(_positionAsset, address(data.borrowedAsset))
            )
            .wmul(WadRayMath.WAD - data.priceOracle.getPairPriceDrop(_positionAsset, address(data.borrowedAsset)))
            .wmul(_positionAmount)
            .wmul(
                WadRayMath.WAD -
                    IPrimexDNSV3(_primexDNS).protocolFeeRates(
                        IPrimexDNSStorageV3.FeeRateType.MarginPositionClosedByKeeper
                    )
            ) * 10 ** (18 - IERC20Metadata(_positionAsset).decimals());
        // numerator = data.bucket.feeBuffer().wmul(_positionDebt) * multiplier1;
        return (data.bucket.feeBuffer().wmul(_positionDebt) * multiplier1).wdiv(denominator) / multiplier1;
    }

    /**
     * @notice Validates if a position meets the minimum size requirement.
     * @param _amount The amount of the asset in the position.
     * @param _asset The asset associated with the position.
     * @param _priceOracle The address of the price oracle contract.
     * @param _nativeAssetOracleData NativeCurrency => Asset
     */
    function validateMinPositionSize(
        uint256 _amount,
        address _asset,
        address _priceOracle,
        IKeeperRewardDistributorV3 _keeperRewardDistributor,
        IPrimexDNSV3 _primexDNS,
        IPrimexDNSStorageV3.TradingOrderType _tradingOrderType,
        bytes calldata _nativeAssetOracleData
    ) public {
        _require(
            isGreaterThanMinPositionSize(
                _asset,
                _amount,
                _priceOracle,
                _keeperRewardDistributor,
                _primexDNS,
                _tradingOrderType,
                _nativeAssetOracleData
            ),
            Errors.INSUFFICIENT_POSITION_SIZE.selector
        );
    }

    /**
     * @notice Checks if the given amount of _asset corresponds to the minimum position size _minPositionSize,
     * based on the _minPositionAsset and the provided _priceOracle.
     * Returns true if the amount corresponds to or exceeds the minimum position size, otherwise returns false.
     * @param _asset The address of the asset being checked.
     * @param _amount The amount of _asset being checked.
     * @param _priceOracle The address of the price oracle contract.
     * @return A boolean value indicating whether the amount corresponds to or exceeds the minimum position size.
     */
    function isGreaterThanMinPositionSize(
        address _asset,
        uint256 _amount,
        address _priceOracle,
        IKeeperRewardDistributorV3 _keeperRewardDistributor,
        IPrimexDNSV3 _primexDNS,
        IPrimexDNSStorageV3.TradingOrderType _tradingOrderType,
        bytes calldata _nativeAssetOracleData
    ) public returns (bool) {
        uint256 minPositionSizeInNativeCurrency = minPositionSize(
            _priceOracle,
            _keeperRewardDistributor,
            _primexDNS,
            _tradingOrderType
        );
        uint256 minPositionSizeInAsset = getOracleAmountsOut(
            NATIVE_CURRENCY,
            _asset,
            minPositionSizeInNativeCurrency,
            _priceOracle,
            _nativeAssetOracleData
        );
        return _amount >= minPositionSizeInAsset;
    }

    /**
     * @notice Decodes an encoded path and returns an array of addresses.
     * @param encodedPath The encoded path to be decoded.
     * @param dexRouter The address of the DEX router.
     * @param dexAdapter The address of the DEX adapter.
     * @return path An array of addresses representing the decoded path.
     */
    function decodePath(
        bytes memory encodedPath,
        address dexRouter,
        address payable dexAdapter
    ) public view returns (address[] memory path) {
        IDexAdapter.DexType type_ = IDexAdapter(dexAdapter).dexType(dexRouter);

        if (type_ == IDexAdapter.DexType.UniswapV2 || type_ == IDexAdapter.DexType.Meshswap) {
            path = abi.decode(encodedPath, (address[]));
        } else if (type_ == IDexAdapter.DexType.UniswapV3) {
            uint256 skip;
            uint256 offsetSize = 23; // address size(20) + fee size(3)
            uint256 pathLength = encodedPath.length / offsetSize + 1;
            path = new address[](pathLength);
            for (uint256 i; i < pathLength; i++) {
                path[i] = encodedPath.toAddress(skip, encodedPath.length);
                skip += offsetSize;
            }
        } else if (type_ == IDexAdapter.DexType.Curve) {
            (path, ) = abi.decode(encodedPath, (address[], address[]));
        } else if (type_ == IDexAdapter.DexType.Balancer) {
            (path, , ) = abi.decode(encodedPath, (address[], bytes32[], int256[]));
        } else if (type_ == IDexAdapter.DexType.AlgebraV3) {
            uint256 skip;
            uint256 offsetSize = 20; // address size(20)
            uint256 pathLength = encodedPath.length / offsetSize;
            path = new address[](pathLength);
            for (uint256 i; i < pathLength; i++) {
                path[i] = encodedPath.toAddress(skip, encodedPath.length);
                skip += offsetSize;
            }
        } else {
            _revert(Errors.UNKNOWN_DEX_TYPE.selector);
        }
    }

    /**
     * @notice Returns the asset multiplier for a given asset.
     * @dev If the asset is the native currency, the function returns 1.
     * If the asset is USD, the function returns the value stored in the constant USD_MULTIPLIER.
     * For any other asset, the function calculates the multiplier based on the number of decimals of the token.
     * @param _asset The address of the asset.
     * @return The asset multiplier. It is a number with 10 raised to a power of decimals of a given asset.
     */
    function _getAssetMultiplier(address _asset) internal view returns (uint256) {
        if (_asset == NATIVE_CURRENCY) return 1;
        if (_asset == USD) return USD_MULTIPLIER;

        return 10 ** (18 - IERC20Metadata(_asset).decimals());
    }

    function _calculateL1CostWei(
        uint256 _baseLength,
        IKeeperRewardDistributorV3 _keeperRewardDistributor
    ) internal view returns (uint256 l1CostWei) {
        (
            ,
            ,
            uint256 optimisticGasCoefficient,
            IKeeperRewardDistributorStorage.PaymentModel paymentModel
        ) = _keeperRewardDistributor.getGasCalculationParams();
        if (paymentModel == IKeeperRewardDistributorStorage.PaymentModel.ARBITRUM) {
            return
                l1CostWei =
                    ARB_NITRO_ORACLE.getL1BaseFeeEstimate() *
                    GAS_FOR_BYTE *
                    (_baseLength + TRANSACTION_METADATA_BYTES);
        }
        if (paymentModel == IKeeperRewardDistributorStorage.PaymentModel.OPTIMISTIC) {
            // Adds 68 bytes of padding to account for the fact that the input does not have a signature.
            uint256 l1GasUsed = GAS_FOR_BYTE * (_baseLength + OVM_GASPRICEORACLE.overhead() + 68);
            return
                l1CostWei =
                    (OVM_GASPRICEORACLE.l1BaseFee() *
                        l1GasUsed *
                        OVM_GASPRICEORACLE.scalar() *
                        optimisticGasCoefficient) /
                    10 ** 6;
        }
        return 0;
    }

    /**
     * @notice Utility function to get the minimum of two values
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Utility function to get the maximum of two values
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}

// Copyright 2020 Compound Labs, Inc.
// (c) 2024 Primex.finance
// SPDX-License-Identifier: BSD-3-Clause

// Modified version of token transfer logic that allows working with non-standart ERC-20 tokens, added method doTransferFromTo,
// modified doTransferIn

pragma solidity 0.8.18;

import "./Errors.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP20NonStandardInterface} from "../interfaces/EIP20NonStandardInterface.sol";

library TokenTransfersLibrary {
    function doTransferIn(address token, address from, uint256 amount) public returns (uint256) {
        return doTransferFromTo(token, from, address(this), amount);
    }

    function doTransferFromTo(address token, address from, address to, uint256 amount) public returns (uint256) {
        uint256 balanceBefore = IERC20(token).balanceOf(to);
        // The returned value is checked in the assembly code below.
        // Arbitrary `from` should be checked at a higher level. The library function cannot be called by the user.
        // slither-disable-next-line unchecked-transfer arbitrary-send-erc20
        EIP20NonStandardInterface(token).transferFrom(from, to, amount);

        bool success;
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            switch returndatasize()
            case 0 {
                // This is a non-standard ERC-20
                success := not(0) // set success to true
            }
            case 32 {
                // This is a compliant ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0) // Set `success = returndata` of external call
            }
            default {
                // This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        _require(success, Errors.TOKEN_TRANSFER_IN_FAILED.selector);

        // Calculate the amount that was *actually* transferred
        uint256 balanceAfter = IERC20(token).balanceOf(to);
        _require(balanceAfter >= balanceBefore, Errors.TOKEN_TRANSFER_IN_OVERFLOW.selector);

        return balanceAfter - balanceBefore; // underflow already checked above, just subtract
    }

    function doTransferOut(address token, address to, uint256 amount) public {
        // The returned value is checked in the assembly code below.
        // slither-disable-next-line unchecked-transfer
        EIP20NonStandardInterface(token).transfer(to, amount);

        bool success;
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            switch returndatasize()
            case 0 {
                // This is a non-standard ERC-20
                success := not(0) // set success to true
            }
            case 32 {
                // This is a complaint ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0) // Set `success = returndata` of external call
            }
            default {
                // This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        _require(success, Errors.TOKEN_TRANSFER_OUT_FAILED.selector);
    }

    function doTransferOutETH(address to, uint256 value) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call{value: value}(new bytes(0));
        _require(success, Errors.NATIVE_TOKEN_TRANSFER_FAILED.selector);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

// A modified version of BytesLib
// Origin: https://github.com/1inch/universal-router/blob/b972662f8d3f0ba55ef99411720f613f77c3fab5/contracts/modules/uniswap/v3/BytesLib.sol
// Unused methods and constants were removed
pragma solidity 0.8.18;

library BytesLib {
    error ToAddressOverflow();
    error ToAddressOutOfBounds();

    /// @notice Returns the address starting at byte `_start`
    /// @dev _bytesLength must equal _bytes.length for this to function correctly
    /// @param _bytes The input bytes string to slice
    /// @param _start The starting index of the address
    /// @param _bytesLength The length of _bytes
    /// @return tempAddress The address starting at _start
    function toAddress(
        bytes memory _bytes,
        uint256 _start,
        uint256 _bytesLength
    ) internal pure returns (address tempAddress) {
        unchecked {
            if (_start + 20 < _start) revert ToAddressOverflow();
            if (_bytesLength < _start + 20) revert ToAddressOutOfBounds();
        }

        assembly {
            tempAddress := mload(add(add(_bytes, 0x14), _start))
        }
    }
}

// SPDX-License-Identifier: GPL-3.0

// A modified version of ds-math library
// Origin: https://github.com/dapphub/ds-math/blob/master/src/math.sol
// Unused methods were removed, errors changed

pragma solidity 0.8.18;
error DS_MATH_ADD_OVERFLOW();
error DS_MATH_MUL_OVERFLOW();

library WadRayMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        if ((z = x + y) < x) revert DS_MATH_ADD_OVERFLOW();
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        if (!(y == 0 || (z = x * y) / y == x)) revert DS_MATH_MUL_OVERFLOW();
    }

    uint256 internal constant WAD = 10 ** 18;
    uint256 internal constant RAY = 10 ** 27;

    //rounds to zero if x*y < WAD / 2
    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    //rounds to zero if x*y < RAY / 2
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    //rounds to zero if x*y < WAD / 2
    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    //rounds to zero if x*y < RAY / 2
    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, RAY), y / 2) / y;
    }
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {ITraderBalanceVault} from "../TraderBalanceVault/ITraderBalanceVault.sol";
import {IWhiteBlackList} from "../WhiteBlackList/WhiteBlackList/IWhiteBlackList.sol";
import {ILiquidityMiningRewardDistributorStorage} from "./ILiquidityMiningRewardDistributorStorage.sol";
import {IPausable} from "../interfaces/IPausable.sol";

interface ILiquidityMiningRewardDistributor is ILiquidityMiningRewardDistributorStorage, IPausable {
    struct RewardsInPMX {
        uint256 minReward;
        uint256 maxReward;
        uint256 extraReward;
    }

    /**
     * @notice Emitted when a reward is claimed by a receiver from a specific bucket.
     * @param receiver The address of the receiver.
     * @param bucket The address of the bucket from which the reward is claimed.
     * @param amount The amount of the claimed reward.
     */
    event ClaimedReward(address indexed receiver, address indexed bucket, uint256 amount);
    /**
     * @notice Emitted when PMX tokens are withdrawn by an admin.
     * @param amount The amount of PMX tokens withdrawn.
     */
    event WithdrawPmxByAdmin(uint256 indexed amount);

    /**
     * @notice Initializes the contract with the specified parameters.
     * @param _primexDNS The address of the IPrimexDNS contract.
     * @param _pmx The address of the PMX token contract.
     * @param _traderBalanceVault The address of the TraderBalanceVault contract.
     * @param _registry The address of the registry contract.
     * @param _treasury The address of the treasury contract.
     * @param _reinvestmentRate The rate at which rewards are reinvested.
     * @param _reinvestmentDuration The duration for which rewards are reinvested.
     * @param _whiteBlackList The address of the WhiteBlackList contract.
     */
    function initialize(
        IPrimexDNSV3 _primexDNS,
        IERC20 _pmx,
        ITraderBalanceVault _traderBalanceVault,
        address _registry,
        address _treasury,
        uint256 _reinvestmentRate,
        uint256 _reinvestmentDuration,
        IWhiteBlackList _whiteBlackList
    ) external;

    /**
     * @notice Updates the reward amount for a specific bucket.
     * @dev Only callable by the PrimexDNS contract.
     * @param _bucketName The name of the bucket.
     * @param _pmxRewardsAmount The amount of PMX rewards to be allocated to the bucket.
     */
    function updateBucketReward(string memory _bucketName, uint256 _pmxRewardsAmount) external;

    /**
     * @notice Adds points for a user for future reward distribution.
     * @dev Only callable by the Bucket contract.
     * @param _bucketName The name of the bucket.
     * @param _user The address of the user.
     * @param _miningAmount The amount of mining points to be added.
     * @param _maxStabilizationPeriodEnd The maximum end timestamp of the stabilization period.
     * @param _maxPeriodTime The maximum period time.
     * @param _currentTimestamp The current timestamp.
     */
    function addPoints(
        string memory _bucketName,
        address _user,
        uint256 _miningAmount,
        uint256 _maxStabilizationPeriodEnd,
        uint256 _maxPeriodTime,
        uint256 _currentTimestamp
    ) external;

    /**
     * @notice Removes points for a user.
     * @dev Only callable by the Bucket contract.
     * @param _name The name of the bucket.
     * @param _user The address of the user.
     * @param _amount The amount of mining points to be removed.
     */
    function removePoints(string memory _name, address _user, uint256 _amount) external;

    /**
     * @notice Claims the accumulated rewards for a specific bucket.
     * @param _bucketName The name of the bucket.
     */
    function claimReward(string memory _bucketName) external;

    /**
     * @notice Moves rewards from one bucket to another.
     * @dev Only callable by the Bucket contract.
     * @param _bucketFrom The name of the source bucket.
     * @param _bucketTo The name of the destination bucket.
     * @param _user The address of the user.
     * @param _isBucketLaunched A flag indicating if the destination bucket is launched.
     * @param _liquidityMiningDeadline The deadline for liquidity mining
     */
    function reinvest(
        string memory _bucketFrom,
        string memory _bucketTo,
        address _user,
        bool _isBucketLaunched,
        uint256 _liquidityMiningDeadline
    ) external;

    /**
     * @dev The function to withdraw PMX from a delisted bucket or a bucket where liquidity mining failed (after reinvesting period).
     * Emits WithdrawPmxByAdmin event.
     * @param _bucketFrom Name of the bucket with failed liquidity mining event.
     */
    function withdrawPmxByAdmin(string memory _bucketFrom) external;

    /**
     * @notice Retrieves information about a lender in a specific bucket.
     * @param _bucketName The name of the bucket.
     * @param _lender The address of the lender.
     * @param _timestamp The timestamp for which the information is queried.
     * @return amountInMining The amount of tokens the lender has in mining for the given bucket.
     * @return currentPercent The current percentage of rewards the lender is eligible to receive for the given bucket.
     * Measured in WAD (1 WAD = 100%).
     * @return rewardsInPMX An object containing information about the lender's rewards in PMX for the given bucket.
     */
    function getLenderInfo(
        string calldata _bucketName,
        address _lender,
        uint256 _timestamp
    ) external view returns (uint256 amountInMining, uint256 currentPercent, RewardsInPMX memory rewardsInPMX);

    /**
     * @notice Retrieves rewards information about a specific bucket.
     * @param _bucketName The name of the bucket.
     * @return totalPmxReward The total amount of PMX reward in the bucket.
     * @return withdrawnRewards The total amount of withdrawn rewards from the bucket.
     * @return totalPoints The total number of mining points in the bucket.
     */
    function getBucketInfo(
        string calldata _bucketName
    ) external view returns (uint256 totalPmxReward, uint256 withdrawnRewards, uint256 totalPoints);

    /**
     * @notice Retrieves the amount of tokens a lender has in mining for a specific bucket.
     * @param _bucket The name of the bucket.
     * @param _lender The address of the lender.
     * @return The amount of tokens the lender has in mining for the given bucket.
     */
    function getLenderAmountInMining(string calldata _bucket, address _lender) external view returns (uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {ITraderBalanceVault} from "../TraderBalanceVault/ITraderBalanceVault.sol";

interface ILiquidityMiningRewardDistributorStorage {
    struct LenderInfo {
        uint256 points;
        uint256 depositedAmount;
    }

    struct BucketInfo {
        uint256 totalPoints;
        uint256 totalPmxReward;
        uint256 withdrawnRewards;
        mapping(address => LenderInfo) lendersInfo;
    }

    function primexDNS() external view returns (IPrimexDNSV3);

    function pmx() external view returns (IERC20);

    function traderBalanceVault() external view returns (ITraderBalanceVault);

    function registry() external view returns (address);

    function reinvestmentRate() external view returns (uint256);

    function reinvestmentDuration() external view returns (uint256);

    function extraRewards(address, string calldata) external view returns (uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {LimitOrderLibrary} from "../libraries/LimitOrderLibrary.sol";
import {PrimexPricingLibrary} from "../libraries/PrimexPricingLibrary.sol";
import {PositionLibrary} from "../libraries/PositionLibrary.sol";

import {IPositionManagerStorage, IPositionManagerStorageV2, IKeeperRewardDistributorV3} from "./IPositionManagerStorage.sol";
import {IPositionManagerEvents} from "./IPositionManagerEvents.sol";
import {IPrimexDNSStorageV3} from "../PrimexDNS/IPrimexDNSStorage.sol";
import {IPausable} from "../interfaces/IPausable.sol";

interface IPositionManagerV2 is IPositionManagerStorageV2, IPositionManagerStorage, IPositionManagerEvents, IPausable {
    struct ClosePositionVars {
        PositionLibrary.Position position;
        bool borrowedAmountIsNotZero;
        uint256 oracleTolerableLimit;
        bool needOracleTolerableLimitCheck;
    }

    event ChangePositionManagerExtension(address indexed newPositionManagerExtension);

    event IncreaseDeposit(
        uint256 indexed positionId,
        address indexed trader,
        uint256 depositDelta,
        uint256 scaledDebtAmount
    );

    struct ClosePositionByConditionParams {
        uint256 id;
        address keeper;
        PrimexPricingLibrary.MegaRoute[] megaRoutes;
        uint256 conditionIndex;
        bytes ccmAdditionalParams;
        PositionLibrary.CloseReason closeReason;
        bytes positionSoldAssetOracleData;
        bytes nativePmxOracleData;
        bytes positionNativeAssetOracleData;
        bytes pmxSoldAssetOracleData;
        bytes nativeSoldAssetOracleData;
        bytes[][] pullOracleData;
        uint256[] pullOracleTypes;
    }

    /**
     * @notice Initializes the contract with the specified addresses and initializes inherited contracts.
     * @param _registry The address of the Registry contract.
     * @param _primexDNS The address of the PrimexDNS contract.
     * @param _traderBalanceVault The address of the TraderBalanceVault contract.
     * @param _priceOracle The address of the PriceOracle contract.
     * @param _keeperRewardDistributor The address of the KeeperRewardDistributor contract.
     * @param _whiteBlackList The address of the WhiteBlacklist contract.
     * @param _positionManagerExtension The address of the PositionManagerExtension contract.
     */
    function initialize(
        address _registry,
        address _primexDNS,
        address payable _traderBalanceVault,
        address _priceOracle,
        address _keeperRewardDistributor,
        address _whiteBlackList,
        address _positionManagerExtension
    ) external;

    /**
     * @notice Sets the positionManagerExtension.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _newPositionManagerExtension The address of PositionManagerExtension contract.
     */
    function setPositionManagerExtension(address _newPositionManagerExtension) external;

    /**
     * @notice Sets protocol parameters through an administrative delegatecall.
     * @dev This function allows an admin to update protocol parameters using a delegatecall to the PositionManagerExtension contract.
     * @param _data The data containing the encoded function call to be executed by the delegatecall.
     */
    function setProtocolParamsByAdmin(bytes calldata _data) external;

    /**
     * @notice Opens a position based on the provided order parameters.
     * @dev Only callable by the LOM_ROLE role.
     * @param _params The parameters for opening a position.
     * @return The total borrowed amount, position amount, position ID, and entry price of the new position.
     */
    function openPositionByOrder(
        LimitOrderLibrary.OpenPositionByOrderParams calldata _params
    ) external returns (uint256, uint256, uint256, uint256, uint256);

    /**
     * @notice Opens margin position.
     * @dev Locks trader's collateral in TraderBalanceVault. Takes loan from bucket for deal.
     * Makes swap bucket borrowedAsset amount on '_dex'. Updates rates and indexes in the '_bucket'.
     * Mints debtToken for trader (msg.sender)
     * @param _params The parameters required to open a position.
     */
    function openPosition(PositionLibrary.OpenPositionParams calldata _params) external payable;

    /**
     * @notice Close trader's active position or liquidate risky position.
     * @dev Protocol will fall down (revert) if two conditions occur both:
     * 1. (token1Price + position.depositedAmount).wdiv(positionDebt) will become lower than 1,
     * so position will make loss for Protocol.
     * 2. Not enough liquidity in bucket to pay that loss.
     * @param _id Position id for `msg.sender`.
     * @param _dealReceiver The receiver of the rest of trader's deposit.
     * @param _megaRoutes swap routes on dexes
     * @param _amountOutMin minimum allowed amount out for position
     */
    function closePosition(
        uint256 _id,
        address _dealReceiver,
        PrimexPricingLibrary.MegaRoute[] calldata _megaRoutes,
        uint256 _amountOutMin,
        bytes calldata _positionSoldAssetOracleData,
        bytes calldata _pmxSoldAssetOracleData,
        bytes calldata _nativeSoldAssetOracleData,
        bytes[][] calldata _pullOracleData,
        uint256[] calldata _pullOracleTypes
    ) external payable;

    // /**
    //  * @notice Closes trader's active position by closing condition
    //  * @param _id Position id.
    //  * @param _keeper The address of the keeper or the recipient of the reward.
    //  * @param _megaRoutes An array of routes for executing trades, swap routes on dexes.
    //  * @param _conditionIndex The index of the condition to be used for closing the position.
    //  * @param _ccmAdditionalParams Additional params needed for canBeClosedAfterSwap of the ConditionalClosingManager.
    //  * @param _closeReason The reason for closing the position.
    //  */
    function closePositionByCondition(ClosePositionByConditionParams calldata _params) external payable;

    /**
     * @notice Updates the position with the given position ID by setting new close conditions.
     * @param _positionId The ID of the position to update.
     * @param _closeConditions An array of close conditions for the position.
     * @dev The caller of this function must be the trader who owns the position.
     * @dev Emits an `UpdatePositionConditions` event upon successful update.
     */
    function updatePositionConditions(
        uint256 _positionId,
        LimitOrderLibrary.Condition[] calldata _closeConditions
    ) external;

    /**
     * @notice Increases the deposit amount for a given position.
     * @param _positionId The ID of the position to increase the deposit for.
     * @param _amount The amount to increase the deposit by.
     * @param _asset The address of the asset to deposit.
     * @param _takeDepositFromWallet A flag indicating whether to make the deposit immediately.
     * @param _megaRoutes An array of routes to use for trading.
     * @param _amountOutMin The minimum amount of the output asset to receive from trading.
     */
    function increaseDeposit(
        uint256 _positionId,
        uint256 _amount,
        address _asset,
        bool _takeDepositFromWallet,
        PrimexPricingLibrary.MegaRoute[] calldata _megaRoutes,
        uint256 _amountOutMin
    ) external;

    /**
     * @notice Decreases the deposit amount for a given position.
     * @param _positionId The ID of the position.
     * @param _amount The amount to decrease the deposit by.
     */
    function decreaseDeposit(
        uint256 _positionId,
        uint256 _amount,
        bytes calldata _positionSoldAssetOracleData,
        bytes calldata _nativeSoldAssetOracleData,
        bytes[][] calldata _pullOracleData,
        uint256[] calldata _pullOracleTypes
    ) external payable;

    /**
     * @notice Deletes a positions by their IDs from a specific bucket for a given traders.
     * @param _ids The IDs of the positions to be deleted.
     * @param _traders The addresses of the traders who owns the position.
     * @param _length The length of the traders array.
     * @param _bucket The address of the bucket from which the position is to be deleted.
     */
    function deletePositions(
        uint256[] calldata _ids,
        address[] calldata _traders,
        uint256 _length,
        address _bucket
    ) external;

    /**
     * @notice Allows the trader to partially close a position.
     * @param _positionId The ID of the position to be partially closed.
     * @param _amount The amount of the position asset to be closed from the position.
     * @param _depositReceiver The address where the remaining deposit will be sent.
     * @param _megaRoutes The routing information for swapping assets.
     * @param _amountOutMin The minimum amount to be received after swapping, measured in the same decimal format as the position's asset.
     */
    function partiallyClosePosition(
        uint256 _positionId,
        uint256 _amount,
        address _depositReceiver,
        PrimexPricingLibrary.MegaRoute[] calldata _megaRoutes,
        uint256 _amountOutMin,
        bytes calldata _positionSoldAssetOracleData,
        bytes calldata _nativePositionAssetOracleData,
        bytes calldata _nativeSoldAssetOracleData,
        bytes calldata _pmxSoldAssetOracleData,
        bytes[][] calldata _pullOracleData,
        uint256[] calldata _pullOracleTypes
    ) external payable;

    /**
     * @notice Transfers a specified amount of tokens from the contract to a specified address.
     * @dev Only callable by the BATCH_MANAGER_ROLE role.
     * @param _token The address of the token to be transferred.
     * @param _to The address to which the tokens will be transferred.
     * @param _amount The amount of tokens to be transferred.
     */
    function doTransferOut(address _token, address _to, uint256 _amount) external;

    /**
     * @notice Returns the oracle tolerable limit for the given asset pair.
     * @param assetA The address of the first asset in the pair.
     * @param assetB The address of the second asset in the pair.
     * @return The oracle tolerable limit in WAD format (1 WAD = 100%) for the asset pair.
     */
    function getOracleTolerableLimit(address assetA, address assetB) external view returns (uint256);

    /**
     * @notice Retrieves the position information for a given ID.
     * @param _id The ID of the position to retrieve.
     * @return position The position information associated with the given ID.
     */
    function getPosition(uint256 _id) external view returns (PositionLibrary.Position memory);

    /**
     * @notice Retrieves the position at the specified index.
     * @param _index The index of the position to retrieve.
     * @return The Position struct at the specified index.
     */
    function getPositionByIndex(uint256 _index) external view returns (PositionLibrary.Position memory);

    /**
     * @notice Returns the length of the positions array.
     * @return The length of the positions array.
     */
    function getAllPositionsLength() external view returns (uint256);

    /**
     * @notice Returns the length of the array containing the positions of a specific trader.
     * @param _trader The address of the trader.
     * @return The number of positions the trader has.
     */
    function getTraderPositionsLength(address _trader) external view returns (uint256);

    /**
     * @notice Returns the length of the array containing the positions of a specific bucket.
     * @param _bucket The address of the bucket.
     * @return The number of positions the bucket has.
     */
    function getBucketPositionsLength(address _bucket) external view returns (uint256);

    /**
     * @notice Returns the debt of a position with the given ID.
     * @param _id The ID of the position.
     * @return The debt of the position, measured in the same decimal format as debtTokens.
     */
    function getPositionDebt(uint256 _id) external view returns (uint256);

    /**
     * @notice Retrieves the close conditions for a specific position.
     * @param _positionId The ID of the position.
     * @return An array of close conditions associated with the position.
     */
    function getCloseConditions(uint256 _positionId) external view returns (LimitOrderLibrary.Condition[] memory);

    /**
     * @notice Retrieves the close condition for a given position and index.
     * @param _positionId The identifier of the position.
     * @param _index The index of the close condition.
     * @return The close condition at the specified position and index.
     */
    function getCloseCondition(
        uint256 _positionId,
        uint256 _index
    ) external view returns (LimitOrderLibrary.Condition memory);

    /**
     * @notice Checks if a position with the given ID is delisted.
     * @param _id The ID of the position.
     * @return A boolean indicating whether the position is delisted or not.
     */
    function isDelistedPosition(uint256 _id) external view returns (bool);
}

interface IPositionManager is IPositionManagerStorage, IPausable {
    struct ClosePositionVars {
        PositionLibrary.Position position;
        bool borrowedAmountIsNotZero;
        uint256 oracleTolerableLimit;
        bool needOracleTolerableLimitCheck;
    }

    event SetMaxPositionSize(address token0, address token1, uint256 amountInToken0, uint256 amountInToken1);
    event SetDefaultOracleTolerableLimit(uint256 indexed oracleTolerableLimit);
    event SecurityBufferChanged(uint256 indexed securityBuffer);
    event MaintenanceBufferChanged(uint256 indexed maintenanceBuffer);
    event SetOracleTolerableLimit(address indexed assetA, address indexed assetB, uint256 oracleTolerableLimit);
    event KeeperRewardDistributorChanged(address indexed _keeperRewardDistributor);
    event MinPositionSizeAndAssetChanged(uint256 indexed _minPositionSize, address indexed _minPositionAsset);
    event OracleTolerableLimitMultiplierChanged(uint256 indexed newMultiplier);

    event OpenPosition(
        uint256 indexed positionId,
        address indexed trader,
        address indexed openedBy,
        PositionLibrary.Position position,
        address feeToken,
        uint256 protocolFee,
        uint256 entryPrice,
        uint256 leverage,
        LimitOrderLibrary.Condition[] closeConditions
    );

    event PartialClosePosition(
        uint256 indexed positionId,
        address indexed trader,
        address bucketAddress,
        address soldAsset,
        address positionAsset,
        uint256 decreasePositionAmount,
        uint256 depositedAmount,
        uint256 scaledDebtAmount,
        int256 profit,
        uint256 positionDebt,
        uint256 amountOut
    );

    event IncreaseDeposit(
        uint256 indexed positionId,
        address indexed trader,
        uint256 depositDelta,
        uint256 scaledDebtAmount
    );

    event DecreaseDeposit(
        uint256 indexed positionId,
        address indexed trader,
        uint256 depositDelta,
        uint256 scaledDebtAmount
    );

    event UpdatePositionConditions(
        uint256 indexed positionId,
        address indexed trader,
        LimitOrderLibrary.Condition[] closeConditions
    );

    /**
     * @notice Initializes the contract with the specified addresses and initializes inherited contracts.
     * @param _registry The address of the Registry contract.
     * @param _primexDNS The address of the PrimexDNS contract.
     * @param _traderBalanceVault The address of the TraderBalanceVault contract.
     * @param _priceOracle The address of the PriceOracle contract.
     * @param _keeperRewardDistributor The address of the KeeperRewardDistributor contract.
     * @param _whiteBlackList The address of the WhiteBlacklist contract.
     */
    function initialize(
        address _registry,
        address _primexDNS,
        address payable _traderBalanceVault,
        address _priceOracle,
        address _keeperRewardDistributor,
        address _whiteBlackList
    ) external;

    /**
     * @notice Sets the maximum position size for a pair of tokens.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _token0 The address of the first token in the pair.
     * @param _token1 The address of the second token in the pair.
     * @param _amountInToken0 The maximum amount of token0 allowed in the position.
     * @param _amountInToken1 The maximum amount of token1 allowed in the position.
     */
    function setMaxPositionSize(
        address _token0,
        address _token1,
        uint256 _amountInToken0,
        uint256 _amountInToken1
    ) external;

    /**
     * @notice Sets the default oracle tolerable limit for the protocol.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _percent The new value for the default oracle tolerable limit. Measured in WAD (1 WAD = 100%).
     */
    function setDefaultOracleTolerableLimit(uint256 _percent) external;

    /**
     * @notice Sets the oracle tolerable limit between two assets.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _assetA The address of the first asset.
     * @param _assetB The address of the second asset.
     * @param _percent The new value for the oracle tolerable limit between two assets. Measured in WAD (1 WAD = 100%).
     */
    function setOracleTolerableLimit(address _assetA, address _assetB, uint256 _percent) external;

    /**
     * @notice Function to set oracleTolerableLimitMultiplier.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param newMultiplier New multiplier in WAD format.
     */
    function setOracleTolerableLimitMultiplier(uint256 newMultiplier) external;

    /**
     * @notice Sets the security buffer value.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * 0 <= newSecurityBuffer < 1.
     * Buffer security parameter is used in calculating the liquidation conditions
     * https://docs.google.com/document/d/1kR8eaqV4289MAbLKgIfKsZ2NgjFpeC0vpVL7jVUTvho/edit#bookmark=id.i9v508hvrv42
     * @param newSecurityBuffer The new value of the security buffer in WAD format.
     */
    function setSecurityBuffer(uint256 newSecurityBuffer) external;

    /**
     * @notice Sets the maintenance buffer value.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * The new maintenance buffer value should be greater than zero and less than one.
     * Maintenance buffer is used in calculating the maximum leverage
     * https://docs.google.com/document/d/1kR8eaqV4289MAbLKgIfKsZ2NgjFpeC0vpVL7jVUTvho/edit#bookmark=id.87oc1j1s9z21
     * @param newMaintenanceBuffer The new value of the maintenance buffer in WAD format.
     */
    function setMaintenanceBuffer(uint256 newMaintenanceBuffer) external;

    /**
     * @notice Sets the address of the SpotTradingRewardDistributor contract.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _spotTradingRewardDistributor The address of the SpotTradingRewardDistributor contract.
     */
    function setSpotTradingRewardDistributor(address _spotTradingRewardDistributor) external;

    /**
     * @notice Sets the KeeperRewardDistributor contract.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _keeperRewardDistributor The address of the KeeperRewardDistributor contract.
     */
    function setKeeperRewardDistributor(IKeeperRewardDistributorV3 _keeperRewardDistributor) external;

    /**
     * @notice Opens a position based on the provided order parameters.
     * @dev Only callable by the LOM_ROLE role.
     * @param _params The parameters for opening a position.
     * @return The total borrowed amount, position amount, position ID, and entry price of the new position.
     */
    function openPositionByOrder(
        LimitOrderLibrary.OpenPositionByOrderParams calldata _params
    ) external returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Opens margin position.
     * @dev Locks trader's collateral in TraderBalanceVault. Takes loan from bucket for deal.
     * Makes swap bucket borrowedAsset amount on '_dex'. Updates rates and indexes in the '_bucket'.
     * Mints debtToken for trader (msg.sender)
     * @param _params The parameters required to open a position.
     */
    function openPosition(PositionLibrary.OpenPositionParams calldata _params) external payable;

    /**
     * @notice Close trader's active position or liquidate risky position.
     * @dev Protocol will fall down (revert) if two conditions occur both:
     * 1. (token1Price + position.depositedAmount).wdiv(positionDebt) will become lower than 1,
     * so position will make loss for Protocol.
     * 2. Not enough liquidity in bucket to pay that loss.
     * @param _id Position id for `msg.sender`.
     * @param _dealReceiver The receiver of the rest of trader's deposit.
     * @param _megaRoutes swap routes on dexes
     * @param _amountOutMin minimum allowed amount out for position
     */
    function closePosition(
        uint256 _id,
        address _dealReceiver,
        PrimexPricingLibrary.MegaRoute[] memory _megaRoutes,
        uint256 _amountOutMin
    ) external;

    /**
     * @notice Closes trader's active position by closing condition
     * @param _id Position id.
     * @param _keeper The address of the keeper or the recipient of the reward.
     * @param _megaRoutes An array of routes for executing trades, swap routes on dexes.
     * @param _conditionIndex The index of the condition to be used for closing the position.
     * @param _ccmAdditionalParams Additional params needed for canBeClosedAfterSwap of the ConditionalClosingManager.
     * @param _closeReason The reason for closing the position.
     */
    function closePositionByCondition(
        uint256 _id,
        address _keeper,
        PrimexPricingLibrary.MegaRoute[] calldata _megaRoutes,
        uint256 _conditionIndex,
        bytes calldata _ccmAdditionalParams,
        PositionLibrary.CloseReason _closeReason
    ) external;

    /**
     * @notice Allows the trader to partially close a position.
     * @param _positionId The ID of the position to be partially closed.
     * @param _amount The amount of the position asset to be closed from the position.
     * @param _depositReceiver The address where the remaining deposit will be sent.
     * @param _megaRoutes The routing information for swapping assets.
     * @param _amountOutMin The minimum amount to be received after swapping, measured in the same decimal format as the position's asset.
     */
    function partiallyClosePosition(
        uint256 _positionId,
        uint256 _amount,
        address _depositReceiver,
        PrimexPricingLibrary.MegaRoute[] calldata _megaRoutes,
        uint256 _amountOutMin
    ) external;

    /**
     * @notice Updates the position with the given position ID by setting new close conditions.
     * @param _positionId The ID of the position to update.
     * @param _closeConditions An array of close conditions for the position.
     * @dev The caller of this function must be the trader who owns the position.
     * @dev Emits an `UpdatePositionConditions` event upon successful update.
     */
    function updatePositionConditions(
        uint256 _positionId,
        LimitOrderLibrary.Condition[] calldata _closeConditions
    ) external;

    /**
     * @notice Increases the deposit amount for a given position.
     * @param _positionId The ID of the position to increase the deposit for.
     * @param _amount The amount to increase the deposit by.
     * @param _asset The address of the asset to deposit.
     * @param _takeDepositFromWallet A flag indicating whether to make the deposit immediately.
     * @param _megaRoutes An array of routes to use for trading.
     * @param _amountOutMin The minimum amount of the output asset to receive from trading.
     */
    function increaseDeposit(
        uint256 _positionId,
        uint256 _amount,
        address _asset,
        bool _takeDepositFromWallet,
        PrimexPricingLibrary.MegaRoute[] calldata _megaRoutes,
        uint256 _amountOutMin
    ) external;

    /**
     * @notice Decreases the deposit amount for a given position.
     * @param _positionId The ID of the position.
     * @param _amount The amount to decrease the deposit by.
     */
    function decreaseDeposit(uint256 _positionId, uint256 _amount) external;

    /**
     * @notice Sets the minimum position size and the corresponding asset for positions.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _minPositionSize The new minimum position size.
     * @param _minPositionAsset The address of the asset associated with the minimum position size.
     */
    function setMinPositionSize(uint256 _minPositionSize, address _minPositionAsset) external;

    /**
     * @notice Deletes a positions by their IDs from a specific bucket for a given traders.
     * @param _ids The IDs of the positions to be deleted.
     * @param _traders The addresses of the traders who owns the position.
     * @param _length The length of the traders array.
     * @param _bucket The address of the bucket from which the position is to be deleted.
     */
    function deletePositions(
        uint256[] calldata _ids,
        address[] calldata _traders,
        uint256 _length,
        address _bucket
    ) external;

    /**
     * @notice Transfers a specified amount of tokens from the contract to a specified address.
     * @dev Only callable by the BATCH_MANAGER_ROLE role.
     * @param _token The address of the token to be transferred.
     * @param _to The address to which the tokens will be transferred.
     * @param _amount The amount of tokens to be transferred.
     */
    function doTransferOut(address _token, address _to, uint256 _amount) external;

    /**
     * @notice Returns the oracle tolerable limit for the given asset pair.
     * @param assetA The address of the first asset in the pair.
     * @param assetB The address of the second asset in the pair.
     * @return The oracle tolerable limit in WAD format (1 WAD = 100%) for the asset pair.
     */
    function getOracleTolerableLimit(address assetA, address assetB) external view returns (uint256);

    /**
     * @notice Retrieves the position information for a given ID.
     * @param _id The ID of the position to retrieve.
     * @return position The position information associated with the given ID.
     */
    function getPosition(uint256 _id) external view returns (PositionLibrary.Position memory);

    /**
     * @notice Retrieves the position at the specified index.
     * @param _index The index of the position to retrieve.
     * @return The Position struct at the specified index.
     */
    function getPositionByIndex(uint256 _index) external view returns (PositionLibrary.Position memory);

    /**
     * @notice Returns the length of the positions array.
     * @return The length of the positions array.
     */
    function getAllPositionsLength() external view returns (uint256);

    /**
     * @notice Returns the length of the array containing the positions of a specific trader.
     * @param _trader The address of the trader.
     * @return The number of positions the trader has.
     */
    function getTraderPositionsLength(address _trader) external view returns (uint256);

    /**
     * @notice Returns the length of the array containing the positions of a specific bucket.
     * @param _bucket The address of the bucket.
     * @return The number of positions the bucket has.
     */
    function getBucketPositionsLength(address _bucket) external view returns (uint256);

    /**
     * @notice Returns the debt of a position with the given ID.
     * @param _id The ID of the position.
     * @return The debt of the position, measured in the same decimal format as debtTokens.
     */
    function getPositionDebt(uint256 _id) external view returns (uint256);

    /**
     * @notice Retrieves the close conditions for a specific position.
     * @param _positionId The ID of the position.
     * @return An array of close conditions associated with the position.
     */
    function getCloseConditions(uint256 _positionId) external view returns (LimitOrderLibrary.Condition[] memory);

    /**
     * @notice Retrieves the close condition for a given position and index.
     * @param _positionId The identifier of the position.
     * @param _index The index of the close condition.
     * @return The close condition at the specified position and index.
     */
    function getCloseCondition(
        uint256 _positionId,
        uint256 _index
    ) external view returns (LimitOrderLibrary.Condition memory);

    /**
     * @notice Checks if a position with the given ID is delisted.
     * @param _id The ID of the position.
     * @return A boolean indicating whether the position is delisted or not.
     */
    function isDelistedPosition(uint256 _id) external view returns (bool);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {LimitOrderLibrary} from "../libraries/LimitOrderLibrary.sol";
import {PositionLibrary} from "../libraries/PositionLibrary.sol";

interface IPositionManagerEvents {
    event SetMaxPositionSize(address token0, address token1, uint256 amountInToken0, uint256 amountInToken1);
    event SetDefaultOracleTolerableLimit(uint256 indexed oracleTolerableLimit);
    event SecurityBufferChanged(uint256 indexed securityBuffer);
    event MaintenanceBufferChanged(uint256 indexed maintenanceBuffer);
    event SetOracleTolerableLimit(address indexed assetA, address indexed assetB, uint256 oracleTolerableLimit);
    event KeeperRewardDistributorChanged(address indexed _keeperRewardDistributor);
    event OracleTolerableLimitMultiplierChanged(uint256 indexed newMultiplier);

    event OpenPosition(
        uint256 indexed positionId,
        address indexed trader,
        address indexed openedBy,
        PositionLibrary.Position position,
        uint256 entryPrice,
        uint256 leverage,
        LimitOrderLibrary.Condition[] closeConditions
    );

    event PartialClosePosition(
        uint256 indexed positionId,
        address indexed trader,
        address bucketAddress,
        address soldAsset,
        address positionAsset,
        uint256 decreasePositionAmount,
        uint256 depositedAmount,
        uint256 scaledDebtAmount,
        int256 profit,
        uint256 positionDebt,
        uint256 amountOut
    );

    event DecreaseDeposit(
        uint256 indexed positionId,
        address indexed trader,
        uint256 depositDelta,
        uint256 scaledDebtAmount
    );

    event UpdatePositionConditions(
        uint256 indexed positionId,
        address indexed trader,
        LimitOrderLibrary.Condition[] closeConditions
    );
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {PositionLibrary} from "../libraries/PositionLibrary.sol";
import {LimitOrderLibrary} from "../libraries/LimitOrderLibrary.sol";

import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {IPriceOracleV2} from "../PriceOracle/IPriceOracle.sol";
import {ITraderBalanceVault} from "../TraderBalanceVault/ITraderBalanceVault.sol";
import {IKeeperRewardDistributorV3} from "../KeeperRewardDistributor/IKeeperRewardDistributor.sol";
import {ISpotTradingRewardDistributorV2} from "../SpotTradingRewardDistributor/ISpotTradingRewardDistributor.sol";

interface IPositionManagerStorage {
    function maxPositionSize(address, address) external returns (uint256);

    function defaultOracleTolerableLimit() external returns (uint256);

    function securityBuffer() external view returns (uint256);

    function maintenanceBuffer() external view returns (uint256);

    function positionsId() external view returns (uint256);

    function traderPositionIds(address _trader, uint256 _index) external view returns (uint256);

    function bucketPositionIds(address _bucket, uint256 _index) external view returns (uint256);

    function registry() external view returns (IAccessControl);

    function traderBalanceVault() external view returns (ITraderBalanceVault);

    function primexDNS() external view returns (IPrimexDNSV3);

    function priceOracle() external view returns (IPriceOracleV2);

    function keeperRewardDistributor() external view returns (IKeeperRewardDistributorV3);

    function spotTradingRewardDistributor() external view returns (ISpotTradingRewardDistributorV2);

    function minPositionSize() external view returns (uint256);

    function minPositionAsset() external view returns (address);
}

interface IPositionManagerStorageV2 {
    function positionManagerExtension() external view returns (address);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IPriceOracleStorage, IPriceOracleStorageV3} from "./IPriceOracleStorage.sol";

interface IPriceOracleV2 is IPriceOracleStorageV3 {
    event ChainlinkPriceFeedUpdated(address indexed token, address indexed priceFeed);
    event PairPriceDropChanged(address indexed assetA, address indexed assetB, uint256 pairPriceDrop);
    event PriceFeedUpdated(address indexed assetA, address indexed assetB, address indexed priceFeed);
    event PriceDropFeedUpdated(address indexed assetA, address indexed assetB, address indexed priceDropFeed);
    event GasPriceFeedChanged(address priceFeed);
    event PythPairIdUpdated(address indexed token, bytes32 indexed priceFeedId);
    event Univ3OracleUpdated(uint256 indexed oracleType, address indexed oracle);
    event TimeToleranceUpdated(uint256 timeTolerance);
    event SupraDataFeedUpdated(address indexed tokenA, address indexed tokenB, uint256 id);

    event Univ3TrustedPairUpdated(
        uint256 indexed oracleType,
        address indexed tokenA,
        address indexed tokenB,
        bool isTrusted
    );

    struct UpdateUniv3TrustedPairParams {
        uint256 oracleType;
        address tokenA;
        address tokenB;
        bool isTrusted;
    }

    enum UpdatePullOracle {
        Pyth,
        Supra
    }

    struct UpdateSupraDataFeedParams {
        address tokenA;
        address tokenB;
        SupraDataFeedId feedData;
    }

    /**
     * @param assetA The address of the first asset in the pair.
     * @param assetB The address of the second asset in the pair.
     * @param priceDropFeed The chain link priceDrop feed address for the pair assetA/assetB
     */
    struct UpdatePriceDropFeedsParams {
        address assetA;
        address assetB;
        address priceDropFeed;
    }

    /**
     * @param _registry The address of PrimexRegistry contract
     * @param _eth Weth address if eth isn't native token of network. Otherwise set to zero address.
     * @param _usdt Address of the USDT token
     * @param _treasury Address of the Treasury
     */
    function initialize(address _registry, address _eth, address _usdt, address _treasury) external;

    /**
     * @notice Function to set (change) the pair priceDrop of the trading assets
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN.
     * @param _assetA The address of position asset
     * @param _assetB The address of borrowed asset
     * @param _pairPriceDrop The pair priceDrop (in wad)
     */
    function setPairPriceDrop(address _assetA, address _assetB, uint256 _pairPriceDrop) external;

    /**
     * @notice Increases the priceDrop of a pair of assets in the system.
     * @dev Only callable by the EMERGENCY_ADMIN role.
     * The _pairPriceDrop value must be greater than the current priceDrop value for the pair
     * and less than the maximum allowed priceDrop (WadRayMath.WAD / 2).
     * @param _assetA The address of position asset
     * @param _assetB The address of borrowed asset
     * @param _pairPriceDrop The new priceDrop value for the pair (in wad)
     */
    function increasePairPriceDrop(address _assetA, address _assetB, uint256 _pairPriceDrop) external;

    /**
     * @notice Sets the gas price feed contract address.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param priceFeed The address of the gas price feed contract.
     */
    function setGasPriceFeed(address priceFeed) external;

    /**
     * @notice Updates the priceDrop feed for a specific pair of assets.
     * @dev Add or update priceDrop feed for assets pair.
     * Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _updateParams The array of the UpdatePriceDropFeedsParams structs
     */
    function updatePriceDropFeeds(UpdatePriceDropFeedsParams[] calldata _updateParams) external;

    /**
     * @notice Updates the priceDrop feed for a specific pair of assets.
     * @dev Add or update priceDrop feed for assets pair.
     * Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param assetA The address of the first asset in the pair.
     * @param assetB The address of the second asset in the pair.
     * @param priceDropFeed The chain link priceDrop feed address for the pair assetA/assetB
     */
    function updatePriceDropFeed(address assetA, address assetB, address priceDropFeed) external;

    /**
     * @notice Retrieves the current gas price from the specified gas price feed.
     * @return The current gas price.
     */
    function getGasPrice() external view returns (int256);

    /**
     * @notice For a given asset pair retrieves the priceDrop rate which is the higher
     * of the oracle pair priceDrop and the historical pair priceDrop.
     * @param _assetA The address of asset A.
     * @param _assetB The address of asset B.
     * @return The priceDrop rate.
     */
    function getPairPriceDrop(address _assetA, address _assetB) external view returns (uint256);

    /**
     * @notice Retrieves the priceDrop rate between two assets based on the oracle pair priceDrop.
     * @param assetA The address of the first asset.
     * @param assetB The address of the second asset.
     * @return The priceDrop rate as a uint256 value.
     */
    function getOraclePriceDrop(address assetA, address assetB) external view returns (uint256);

    /**
     * @notice Retreives a priceDrop feed address from the oraclePriceDropFeeds mapping
     * @param assetA The address of the first asset in the pair.
     * @param assetB The address of the second asset in the pair.
     * @return priceDropFeed The address of the priceDrop feed associated with the asset pair.
     */
    function getOraclePriceDropFeed(address assetA, address assetB) external view returns (address);

    /**
     * @notice Calculates exchange rate of one token to another according to the specific oracle route
     * @param assetA The address of the first asset in the pair.
     * @param assetB The address of the second asset in the pair.
     * @param oracleData The list of oracles to use for price calculations
     * @return exchangeRate for assetA/assetB in 10**18 decimality
     */
    function getExchangeRate(
        address assetA,
        address assetB,
        bytes calldata oracleData
    ) external payable returns (uint256);

    /**
     * @notice Sets or updates the Chainlink price feed for the list of tokens to usd.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _tokens Array of token addresses.
     * @param _feeds Array of price feeds.
     */
    function updateChainlinkPriceFeedsUsd(address[] calldata _tokens, address[] calldata _feeds) external;

    /**
     * @notice Sets or updates the Pyth pair ids for the list of tokens.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _tokens Array of token addresses.
     * @param _priceFeedIds Array of pair ids.
     */
    function updatePythPairId(address[] calldata _tokens, bytes32[] calldata _priceFeedIds) external;

    /**
     * @notice Sets or updates the Supra price feeds for the list of tokens.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _params Array of token pairs and Supra ids.
     */
    function updateSupraDataFeed(UpdateSupraDataFeedParams[] calldata _params) external;

    /**
     * @notice Sets Uni v3-based TWAP price oracle contracts.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _oracleTypes Array of ids of TWAP contracts.
     * @param _oracles Array of TWAP contract addresses.
     */
    function updateUniv3TypeOracle(uint256[] calldata _oracleTypes, address[] calldata _oracles) external;

    /**
     * @notice Sets or updates the Supra price feeds for the list of tokens.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _updateParams Array of token pairs, their DEXs and new trusted status.
     */
    function updateUniv3TrustedPair(UpdateUniv3TrustedPairParams[] calldata _updateParams) external;

    /**
     * @notice Sets the Pyth address
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _pyth the address of the Pyth oracle
     */

    function setPyth(address _pyth) external;

    /**
     * @notice Sets the Supra pull oracle address
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _supraPullOracle the address of the Supra pull oracle
     */
    function setSupraPullOracle(address _supraPullOracle) external;

    /**
     * @notice Sets the Supra storage address
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _supraStorageOracle the address of the Supra storage
     */
    function setSupraStorageOracle(address _supraStorageOracle) external;

    /**
     * @notice Updates pull oracle data for passed oracle types
     * @param _data An array of update data for passed oracles
     * @param _pullOracleTypes An array of oracle types  (Must conform to the UpdatePullOracle struct)
     */

    function updatePullOracle(bytes[][] calldata _data, uint256[] calldata _pullOracleTypes) external payable;

    /**
     * @notice Sets the time tolerance
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _timeTolerance Time tolerance in seconds
     */

    function setTimeTolerance(uint256 _timeTolerance) external;

    /**
     * @notice Sets the usdt address
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _usdt the address of the USDT
     */

    function setUSDT(address _usdt) external;

    /**
     * @notice Sets the treasury address
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _treasury the address of the treasury
     */
    function setTreasury(address _treasury) external;
}

interface IPriceOracle is IPriceOracleStorage {
    event PairPriceDropChanged(address indexed assetA, address indexed assetB, uint256 pairPriceDrop);
    event PriceFeedUpdated(address indexed assetA, address indexed assetB, address indexed priceFeed);
    event PriceDropFeedUpdated(address indexed assetA, address indexed assetB, address indexed priceDropFeed);
    event GasPriceFeedChanged(address priceFeed);

    /**
     * @param _registry The address of PrimexRegistry contract
     * @param _eth Weth address if eth isn't native token of network. Otherwise set to zero address.
     */
    function initialize(address _registry, address _eth) external;

    /**
     * @notice Function to set (change) the pair priceDrop of the trading assets
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN.
     * @param _assetA The address of position asset
     * @param _assetB The address of borrowed asset
     * @param _pairPriceDrop The pair priceDrop (in wad)
     */
    function setPairPriceDrop(address _assetA, address _assetB, uint256 _pairPriceDrop) external;

    /**
     * @notice Increases the priceDrop of a pair of assets in the system.
     * @dev Only callable by the EMERGENCY_ADMIN role.
     * The _pairPriceDrop value must be greater than the current priceDrop value for the pair
     * and less than the maximum allowed priceDrop (WadRayMath.WAD / 2).
     * @param _assetA The address of position asset
     * @param _assetB The address of borrowed asset
     * @param _pairPriceDrop The new priceDrop value for the pair (in wad)
     */
    function increasePairPriceDrop(address _assetA, address _assetB, uint256 _pairPriceDrop) external;

    /**
     * @notice Add or update price feed for assets pair. For only the admin role.
     * @param assetA The first currency within the currency pair quotation (the base currency).
     * @param assetB The second currency within the currency pair quotation (the quote currency).
     * @param priceFeed The chain link price feed address for the pair assetA/assetB
     */
    function updatePriceFeed(address assetA, address assetB, address priceFeed) external;

    /**
     * @notice Sets the gas price feed contract address.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param priceFeed The address of the gas price feed contract.
     */
    function setGasPriceFeed(address priceFeed) external;

    /**
     * @notice Updates the priceDrop feed for a specific pair of assets.
     * @dev Add or update priceDrop feed for assets pair.
     * Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param assetA The address of the first asset in the pair.
     * @param assetB The address of the second asset in the pair.
     * @param priceDropFeed The chain link priceDrop feed address for the pair assetA/assetB
     */
    function updatePriceDropFeed(address assetA, address assetB, address priceDropFeed) external;

    /**
     * @notice Requests two priceFeeds - assetA/ETH and assetB/ETH (or assetA/USD and assetB/USD).
     * @dev If there is no price feed found, the code will return a message that no price feed found.
     * @param baseAsset The first currency within the currency pair quotation (the base currency).
     * @param quoteAsset The second currency within the currency pair quotation (the quote currency).
     * @return A tuple of basePriceFeed and quotePriceFeed. The addresses of the price feed for the base asset and quote asset respectively.
     */
    function getPriceFeedsPair(address baseAsset, address quoteAsset) external view returns (address, address);

    /**
     * @notice Requests priceFeed for the actual exchange rate for an assetA/assetB pair.
     * @dev If no price feed for the pair found, USD and ETH are used as intermediate tokens.
     * A price for assetA/assetB can be derived if two data feeds exist:
     * assetA/ETH and assetB/ETH (or assetA/USD and assetB/USD).
     * If there is no price feed found, the code will return a message that no price feed found.
     * @param assetA The first currency within the currency pair quotation (the base currency).
     * @param assetB The second currency within the currency pair quotation (the quote currency).
     * @return exchangeRate for assetA/assetB in 10**18 decimality which will be recalucaled in PrimexPricingLibrary.
     * @return direction of a pair as it stored in chainLinkPriceFeeds (i.e. returns 'true' for assetA/assetB, and 'false' for assetB/assetA).
     * Throws if priceFeed wasn't found or priceFeed hasn't answer is 0.
     */
    function getExchangeRate(address assetA, address assetB) external view returns (uint256, bool);

    /**
     * @notice Retrieves the direct price feed for the given asset pair.
     * @param assetA The address of the first asset.
     * @param assetB The address of the second asset.
     * @return priceFeed The address of the direct price feed.
     */
    function getDirectPriceFeed(address assetA, address assetB) external view returns (address);

    /**
     * @notice Retrieves the current gas price from the specified gas price feed.
     * @return The current gas price.
     */
    function getGasPrice() external view returns (int256);

    /**
     * @notice For a given asset pair retrieves the priceDrop rate which is the higher
     * of the oracle pair priceDrop and the historical pair priceDrop.
     * @param _assetA The address of asset A.
     * @param _assetB The address of asset B.
     * @return The priceDrop rate.
     */
    function getPairPriceDrop(address _assetA, address _assetB) external view returns (uint256);

    /**
     * @notice Retrieves the priceDrop rate between two assets based on the oracle pair priceDrop.
     * @param assetA The address of the first asset.
     * @param assetB The address of the second asset.
     * @return The priceDrop rate as a uint256 value.
     */
    function getOraclePriceDrop(address assetA, address assetB) external view returns (uint256);

    /**
     * @notice Retreives a priceDrop feed address from the oraclePriceDropFeeds mapping
     * @param assetA The address of the first asset in the pair.
     * @param assetB The address of the second asset in the pair.
     * @return priceDropFeed The address of the priceDrop feed associated with the asset pair.
     */
    function getOraclePriceDropFeed(address assetA, address assetB) external view returns (address);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {ISupraOraclePull} from "../interfaces/ISupraOraclePull.sol";
import {ISupraSValueFeed} from "../interfaces/ISupraSValueFeed.sol";

interface IPriceOracleStorage {
    function registry() external view returns (address);

    function eth() external view returns (address);

    function gasPriceFeed() external view returns (address);

    function pairPriceDrops(address, address) external view returns (uint256);
}

interface IPriceOracleStorageV2 is IPriceOracleStorage {
    enum OracleType {
        Pyth,
        Chainlink,
        Uniswapv3,
        Supra
    }

    struct OracleRoute {
        address tokenTo;
        OracleType oracleType;
        bytes oracleData;
    }

    function pyth() external view returns (IPyth);

    function timeTolerance() external view returns (uint256);

    function chainlinkPriceFeedsUsd(address) external view returns (address);

    function pythPairIds(address) external view returns (bytes32);

    function univ3TypeOracles(uint256) external view returns (address);

    function univ3TrustedPairs(uint256, address, address) external view returns (bool);
}

interface IPriceOracleStorageV3 is IPriceOracleStorageV2 {
    struct SupraDataFeedId {
        uint256 id;
        bool initialize;
    }

    function supraPullOracle() external view returns (ISupraOraclePull);

    function supraStorageOracle() external view returns (ISupraSValueFeed);

    function supraDataFeedID(address, address) external view returns (uint256, bool);

    function usdt() external view returns (address);

    function treasury() external view returns (address);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IPrimexDNSStorage, IPrimexDNSStorageV3} from "./IPrimexDNSStorage.sol";

interface IPrimexDNSV3 is IPrimexDNSStorageV3 {
    event AddNewBucket(BucketData newBucketData);
    event BucketDeprecated(address bucketAddress, uint256 delistingTime);
    event AddNewDex(DexData newDexData);
    event ConditionalManagerChanged(uint256 indexed cmType, address indexed cmAddress);
    event PMXchanged(address indexed pmx);
    event AavePoolChanged(address indexed aavePool);
    event BucketActivated(address indexed bucketAddress);
    event BucketFrozen(address indexed bucketAddress);
    event DexAdapterChanged(address indexed newAdapterAddress);
    event DexActivated(address indexed routerAddress);
    event DexFrozen(address indexed routerAddress);

    event ChangeProtocolFeeRate(FeeRateType indexed feeRateType, uint256 indexed feeRate);
    event ChangeAverageGasPerAction(TradingOrderType indexed tradingOrderType, uint256 indexed averageGasPerAction);
    event ChangeMaxProtocolFee(uint256 indexed maxProtocolFee);
    event ChangeProtocolFeeCoefficient(uint256 indexed protocolFeeCoefficient);
    event ChangeLiquidationGasAmount(uint256 indexed liquidationGasAmount);
    event ChangePmxDiscountMultiplier(uint256 indexed pmxDiscountMultiplier);
    event ChangeAdditionalGasSpent(uint256 indexed additionalGasSpent);
    event ChangeGasPriceBuffer(uint256 indexed gasPriceBuffer);
    event ChangeMinFeeRestrictions(CallingMethod indexed callingMethod, MinFeeRestrictions minFeeRestrictions);
    event ChangeLeverageTolerance(uint256 leverageTolerance);

    /**
     * @param feeRateType The order type for which the rate is set
     * @param feeRate Setting rate in WAD format (1 WAD = 100%)
     */
    struct FeeRateParams {
        FeeRateType feeRateType;
        uint256 feeRate;
    }

    struct AverageGasPerActionParams {
        TradingOrderType tradingOrderType;
        uint256 averageGasPerAction;
    }

    /**
     * @dev Params for initialize() function
     * @param registry The address of the PrimexRegistry contract.
     * @param pmx The address of the PMX token contract.
     * @param treasury The address of the Treasury contract.
     * @param delistingDelay The time (in seconds) between deprecation and delisting of a bucket.
     * @param adminWithdrawalDelay The time (in seconds) between delisting of a bucket and an adminDeadline.
     * @param feeRateParams An array of structs to set protocol fee rate on the corresponding
     * @param averageGasPerActionParams An array of structs to set average amount of gas spent by Keeper on the corresponding action
     * @param maxProtocolFee MaxProtocolFee that can be charged. Measured in NATIVE_CURRENCY
     * @param liquidationGasAmount Average gas amount spent for a single liquidation, measured in wei.
     * @param protocolFeeCoefficient Additional coefficient to calculate minProtocolFee, measured in wei.
     * @param additionalGasSpent Gas that will be additionally spend after gasSpent calculation.
     * @param pmxDiscountMultiplier Multiplier for PMX discount calculation
     * @param gasPriceBuffer Multiplier which protects position from immediate liquidation after gas price changed
     */
    struct InitParams {
        address registry;
        address pmx;
        address treasury;
        uint256 delistingDelay;
        uint256 adminWithdrawalDelay;
        FeeRateParams[] feeRateParams;
        AverageGasPerActionParams[] averageGasPerActionParams;
        uint256 maxProtocolFee;
        uint256 liquidationGasAmount;
        uint256 protocolFeeCoefficient;
        uint256 additionalGasSpent;
        uint256 pmxDiscountMultiplier;
        uint256 gasPriceBuffer;
        uint256 leverageTolerance;
    }

    /**
     * @notice Initializes the contract with the specified parameters.
     */
    function initialize(InitParams calldata _params) external;

    /**
     * @notice Deprecates a bucket.
     * @dev This function is used to deprecate a bucket by changing its current status to "Deprecated".
     * Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _bucket The name of the bucket to deprecate.
     * Emits a BucketDeprecated event with the bucket address and the delisting time.
     */
    function deprecateBucket(string memory _bucket) external;

    /**
     * @notice This function is used to set the address of the Aave pool contract.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _aavePool The address of the Aave pool contract to be set.
     */
    function setAavePool(address _aavePool) external;

    /**
     * @notice Sets the address of the PMX token contract.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _pmx The address of the PMX token contract.
     */
    function setPMX(address _pmx) external;

    /**
     * @notice Activates a bucket by changing its status from inactive to active.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _bucket The bucket to activate.
     */
    function activateBucket(string memory _bucket) external;

    /**
     * @notice Freezes a bucket, preventing further operations on it,
     * by changing its status from active to inactive.
     * @dev Only callable by the EMERGENCY_ADMIN role.
     * @param _bucket The bucket to be frozen.
     */
    function freezeBucket(string memory _bucket) external;

    /**
     * @notice Adds a new bucket.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _newBucket The address of the new bucket to be added.
     * @param _pmxRewardAmount The amount of PMX tokens to be rewarded from the bucket.
     * Emits a AddNewBucket event with the struct BucketData of the newly added bucket.
     */
    function addBucket(address _newBucket, uint256 _pmxRewardAmount) external;

    /**
     * @notice Activates a DEX by changing flag isActive on to true.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _dex The name of the DEX to activate.
     */
    function activateDEX(string memory _dex) external;

    /**
     * @notice Freezes a DEX by changing flag isActive to false.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _dex The name of the DEX to be frozen.
     */
    function freezeDEX(string memory _dex) external;

    /**
     * @notice Adds a new DEX to the protocol.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _name The name of the DEX.
     * @param _routerAddress The address of the DEX router.
     */
    function addDEX(string memory _name, address _routerAddress) external;

    /**
     * @notice Sets the address of the DEX adapter.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param newAdapterAddress The address of the new DEX adapter.
     */
    function setDexAdapter(address newAdapterAddress) external;

    /**
     * @notice Set min protocol fee restrictions for different calling method.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     */
    function setMinFeeRestrictions(
        CallingMethod _callingMethod,
        MinFeeRestrictions calldata _minFeeRestrictions
    ) external;

    /**
     * @dev The function to specify the address of conditional manager of some type
     * 1 => LimitPriceCOM
     * 2 => TakeProfitStopLossCCM
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _address Address to be set for a conditional manager
     * @param _cmType The type of a conditional manager
     */
    function setConditionalManager(uint256 _cmType, address _address) external;

    /**
     * @notice Retrieves the address of a bucket by its name.
     * @param _name The name of the bucket.
     * @return The address of the bucket.
     */
    function getBucketAddress(string memory _name) external view returns (address);

    /**
     * @notice Retrieves the address of the DEX router based on the given DEX name.
     * @param _name The name of the DEX.
     * @return The address of the DEX router.
     */
    function getDexAddress(string memory _name) external view returns (address);

    /**
     * @notice Retrieves the names of Dexes registered in the protocol.
     * @return An array of strings containing the names of all Dexes.
     */
    function getAllDexes() external view returns (string[] memory);

    /**
     * @notice Set the protocol fee rate for one type of order.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     */
    function setProtocolFeeRate(FeeRateParams calldata _feeRateType) external;

    /**
     * @notice Set average gas amount of gas spent by Keeper on the corresponding action.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     */
    function setAverageGasPerAction(AverageGasPerActionParams calldata _averageGasPerActionParams) external;

    /**
     * @notice Set the max protocol fee.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _maxProtocolFee The new max protocol fee.
     */
    function setMaxProtocolFee(uint256 _maxProtocolFee) external;

    /**
     * @notice Set protocol fee coefficient. Used to calculate the minProtocol fee
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     */
    function setProtocolFeeCoefficient(uint256 _maxProtocolFee) external;

    /**
     * @notice Set liquidation gas amount (average gas amount spent for a single liquidation).
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     */
    function setLiquidationGasAmount(uint256 _maxProtocolFee) external;

    /**
     * @notice Set pmxDiscountMultiplier.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     */
    function setPmxDiscountMultiplier(uint256 _pmxDiscountMultiplier) external;

    /**
     * @notice Set new additionalGas. Used to calculate the minProtocol fee
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     */
    function setAdditionalGasSpent(uint256 _additionalGasSpent) external;

    /**
     * @notice Set new gasPriceBuffer.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     */
    function setGasPriceBuffer(uint256 _gasPriceBuffer) external;

    /**
     * @notice Set new leverageTolerance.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     */
    function setLeverageTolerance(uint256 _leverageTolerance) external;

    /**
     * @notice Retrieves pmx, treasury, feeRateType, maxProtocolFee, pmxDiscountMultiplier
     */
    function getPrimexDNSParams(
        FeeRateType _feeRateType
    ) external view returns (address, address, uint256, uint256, uint256);

    /**
     * @notice Retrieves liquidationGasAmount, protocolFeeCoefficient, additionalGasSpent, maxGasAmount and baseLength
     */
    function getParamsForMinProtocolFee(
        CallingMethod _callingMethod
    ) external view returns (uint256, uint256, uint256, uint256, uint256);

    /**
     * @notice Retrieves baseLength, averageGasPerAction, protocolFeeCoefficient and gasPriceBuffer
     */
    function getParamsForMinPositionSize(
        TradingOrderType _tradingOrderType
    ) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Retrieves baseLength for L2 chain payment model depending from tradingOrderType
     */
    function getL1BaseLengthForTradingOrderType(TradingOrderType _tradingOrderType) external view returns (uint256);
}

interface IPrimexDNS is IPrimexDNSStorage {
    event AddNewBucket(BucketData newBucketData);
    event BucketDeprecated(address bucketAddress, uint256 delistingTime);
    event AddNewDex(DexData newDexData);
    event ChangeFeeRate(OrderType orderType, address token, uint256 rate);
    event ConditionalManagerChanged(uint256 indexed cmType, address indexed cmAddress);
    event PMXchanged(address indexed pmx);
    event AavePoolChanged(address indexed aavePool);
    event BucketActivated(address indexed bucketAddress);
    event BucketFrozen(address indexed bucketAddress);
    event DexAdapterChanged(address indexed newAdapterAddress);
    event DexActivated(address indexed routerAddress);
    event DexFrozen(address indexed routerAddress);

    /**
     * @param orderType The order type for which the rate is set
     * @param feeToken The token address for which the rate is set
     * @param rate Setting rate in WAD format (1 WAD = 100%)
     */
    struct FeeRateParams {
        OrderType orderType;
        address feeToken;
        uint256 rate;
    }

    /**
     * @notice Initializes the contract with the specified parameters.
     * @param _registry The address of the PrimexRegistry contract.
     * @param _pmx The address of the PMX token contract.
     * @param _treasury The address of the Treasury contract.
     * @param _delistingDelay The time (in seconds) between deprecation and delisting of a bucket.
     * @param _adminWithdrawalDelay The time (in seconds) between delisting of a bucket and an adminDeadline.
     * @param _feeRateParams Initial fee params
     */
    function initialize(
        address _registry,
        address _pmx,
        address _treasury,
        uint256 _delistingDelay,
        uint256 _adminWithdrawalDelay,
        FeeRateParams[] calldata _feeRateParams
    ) external;

    /**
     * @notice Deprecates a bucket.
     * @dev This function is used to deprecate a bucket by changing its current status to "Deprecated".
     * Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _bucket The name of the bucket to deprecate.
     * Emits a BucketDeprecated event with the bucket address and the delisting time.
     */
    function deprecateBucket(string memory _bucket) external;

    /**
     * @notice This function is used to set the address of the Aave pool contract.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _aavePool The address of the Aave pool contract to be set.
     */
    function setAavePool(address _aavePool) external;

    /**
     * @notice Sets the protocol rate in PMX.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     */
    function setFeeRate(FeeRateParams calldata _feeRateParams) external;

    /**
     * @notice Sets the address of the PMX token contract.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _pmx The address of the PMX token contract.
     */
    function setPMX(address _pmx) external;

    /**
     * @notice Activates a bucket by changing its status from inactive to active.
     * @dev Only callable by the SMALL_TIMELOCK_ADMIN role.
     * @param _bucket The bucket to activate.
     */
    function activateBucket(string memory _bucket) external;

    /**
     * @notice Freezes a bucket, preventing further operations on it,
     * by changing its status from active to inactive.
     * @dev Only callable by the EMERGENCY_ADMIN role.
     * @param _bucket The bucket to be frozen.
     */
    function freezeBucket(string memory _bucket) external;

    /**
     * @notice Adds a new bucket.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param _newBucket The address of the new bucket to be added.
     * @param _pmxRewardAmount The amount of PMX tokens to be rewarded from the bucket.
     * Emits a AddNewBucket event with the struct BucketData of the newly added bucket.
     */
    function addBucket(address _newBucket, uint256 _pmxRewardAmount) external;

    /**
     * @notice Activates a DEX by changing flag isActive on to true.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _dex The name of the DEX to activate.
     */
    function activateDEX(string memory _dex) external;

    /**
     * @notice Freezes a DEX by changing flag isActive to false.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _dex The name of the DEX to be frozen.
     */
    function freezeDEX(string memory _dex) external;

    /**
     * @notice Adds a new DEX to the protocol.
     * @dev Only callable by the MEDIUM_TIMELOCK_ADMIN role.
     * @param _name The name of the DEX.
     * @param _routerAddress The address of the DEX router.
     */
    function addDEX(string memory _name, address _routerAddress) external;

    /**
     * @notice Sets the address of the DEX adapter.
     * @dev Only callable by the BIG_TIMELOCK_ADMIN role.
     * @param newAdapterAddress The address of the new DEX adapter.
     */
    function setDexAdapter(address newAdapterAddress) external;

    /**
     * @dev The function to specify the address of conditional manager of some type
     * 1 => LimitPriceCOM
     * 2 => TakeProfitStopLossCCM
     * @param _address Address to be set for a conditional manager
     * @param _cmType The type of a conditional manager
     */
    function setConditionalManager(uint256 _cmType, address _address) external;

    /**
     * @notice Retrieves the address of a bucket by its name.
     * @param _name The name of the bucket.
     * @return The address of the bucket.
     */
    function getBucketAddress(string memory _name) external view returns (address);

    /**
     * @notice Retrieves the address of the DEX router based on the given DEX name.
     * @param _name The name of the DEX.
     * @return The address of the DEX router.
     */
    function getDexAddress(string memory _name) external view returns (address);

    /**
     * @notice Retrieves the names of Dexes registered in the protocol.
     * @return An array of strings containing the names of all Dexes.
     */
    function getAllDexes() external view returns (string[] memory);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IPrimexDNSStorage {
    enum Status {
        Inactive,
        Active,
        Deprecated
    }

    enum OrderType {
        MARKET_ORDER,
        LIMIT_ORDER,
        SWAP_MARKET_ORDER,
        SWAP_LIMIT_ORDER
    }

    struct BucketData {
        address bucketAddress;
        Status currentStatus;
        uint256 delistingDeadline;
        // The deadline is for the admin to call Bucket.withdrawAfterDelisting().
        uint256 adminDeadline;
    }
    struct DexData {
        address routerAddress;
        bool isActive;
    }

    struct AdapterData {
        string[] dexes;
        bool isAdded;
    }

    function registry() external view returns (address);

    function delistingDelay() external view returns (uint256);

    function adminWithdrawalDelay() external view returns (uint256);

    function buckets(string memory) external view returns (address, Status, uint256, uint256);

    function dexes(string memory) external view returns (address, bool);

    function cmTypeToAddress(uint256 cmType) external view returns (address);

    function dexAdapter() external view returns (address);

    function pmx() external view returns (address);

    function treasury() external view returns (address);

    function aavePool() external view returns (address);

    function feeRates(OrderType _orderType, address _token) external view returns (uint256);
}

interface IPrimexDNSStorageV2 is IPrimexDNSStorage {
    struct FeeRestrictions {
        uint256 minProtocolFee;
        uint256 maxProtocolFee;
    }

    function feeRestrictions(
        OrderType _orderType
    ) external view returns (uint256 minProtocolFee, uint256 maxProtocolFee);
}

interface IPrimexDNSStorageV3 is IPrimexDNSStorageV2 {
    enum FeeRateType {
        MarginPositionClosedByTrader,
        SpotPositionClosedByTrader,
        MarginPositionClosedByKeeper,
        SpotPositionClosedByKeeper,
        MarginLimitOrderExecuted,
        SpotLimitOrderExecuted,
        SwapLimitOrderExecuted,
        SwapMarketOrder
    }

    enum TradingOrderType {
        MarginMarketOrder,
        SpotMarketOrder,
        MarginLimitOrder,
        MarginLimitOrderDepositInThirdAsset,
        SpotLimitOrder,
        SwapLimitOrder
    }

    enum CallingMethod {
        OpenPositionByOrder,
        ClosePositionByCondition
    }
    struct MinFeeRestrictions {
        uint256 maxGasAmount;
        uint256 baseLength;
    }

    function protocolFeeRates(FeeRateType _feeRateType) external view returns (uint256);

    function averageGasPerAction(TradingOrderType _tradingOrderType) external view returns (uint256);

    function minFeeRestrictions(
        CallingMethod _callingMethod
    ) external view returns (uint256 maxGasAmount, uint256 baseLength);

    function maxProtocolFee() external view returns (uint256);

    function protocolFeeCoefficient() external view returns (uint256);

    function liquidationGasAmount() external view returns (uint256);

    function additionalGasSpent() external view returns (uint256);

    function pmxDiscountMultiplier() external view returns (uint256);

    function gasPriceBuffer() external view returns (uint256);

    function leverageTolerance() external view returns (uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import {IPTokenStorage, IBucket, IBucketV3, IFeeExecutor, IERC20MetadataUpgradeable, IActivityRewardDistributor} from "./IPTokenStorage.sol";

interface IPToken is IPTokenStorage {
    /**
     * @dev Emitted after the mint action
     * @param from The address performing the mint
     * @param value The amount being
     */
    event Mint(address indexed from, uint256 value);

    /**
     * @dev Emitted after pTokens are burned
     * @param from The owner of the aTokens, getting them burned
     * @param value The amount being burned
     */
    event Burn(address indexed from, uint256 value);

    /**
     * @dev Emitted during the transfer action
     * @param from The user whose tokens are being transferred
     * @param to The recipient
     * @param amount The amount being transferred
     * @param index The new liquidity index of the reserve
     */
    event BalanceTransfer(address indexed from, address indexed to, uint256 amount, uint256 index);

    event LockDeposit(address indexed user, uint256 indexed id, uint256 deadline, uint256 amount);
    event UnlockDeposit(address indexed user, uint256 indexed id);

    /**
     * @dev contract initializer
     * @param _name The name of the ERC20 token.
     * @param _symbol The symbol of the ERC20 token.
     * @param _decimals The number of decimals for the ERC20 token.
     * @param _bucketsFactory Address of the buckets factory that will call the setBucket fucntion
     */
    function initialize(string memory _name, string memory _symbol, uint8 _decimals, address _bucketsFactory) external;

    /**
     * @dev Sets the bucket for the contract.
     * @param _bucket The address of the bucket to set.
     */
    function setBucket(IBucket _bucket) external;

    /**
     * @dev Sets the InterestIncreaser for current PToken.
     * @param _interestIncreaser The interest increaser address.
     */
    function setInterestIncreaser(IFeeExecutor _interestIncreaser) external;

    /**
     * @dev Sets the lender reward distributor contract address.
     * @param _lenderRewardDistributor The address of the lender reward distributor contract.
     */
    function setLenderRewardDistributor(IActivityRewardDistributor _lenderRewardDistributor) external;

    /**
     * @notice Locks a deposit for a specified user.
     * @param _user The address of the user for whom the deposit is being locked.
     * @param _amount The amount to be locked as a deposit.
     * @param _duration The duration for which the deposit will be locked.
     * @dev This function can only be called externally and overrides the corresponding function in the parent contract.
     * @dev The user must not be blacklisted.
     */
    function lockDeposit(address _user, uint256 _amount, uint256 _duration) external;

    /**
     * @dev Unlocks a specific deposit.
     * @param _depositId The ID of the deposit to be unlocked.
     */
    function unlockDeposit(uint256 _depositId) external;

    /**
     * @dev Mints `amount` pTokens to `user`
     * @param _user The address receiving the minted tokens
     * @param _amount The amount of tokens getting minted
     * @param _index The current liquidityIndex
     * @return Minted amount of PTokens
     */
    function mint(address _user, uint256 _amount, uint256 _index) external returns (uint256);

    /**
     * @dev Mints pTokens to the reserve address
     * Compared to the normal mint, we don't revert when the amountScaled is equal to the zero. Additional checks were also removed
     * Only callable by the Bucket
     * @param _reserve The address of the reserve
     * @param _amount The amount of tokens getting minted
     * @param _index The current liquidityIndex
     */
    function mintToReserve(address _reserve, uint256 _amount, uint256 _index) external;

    /**
     * @dev Burns pTokens from `user` and sends the equivalent amount of underlying to `receiverOfUnderlying`
     * @param _user The owner of the pTokens, getting them burned
     * @param _amount The amount of underlying token being returned to receiver
     * @param _index The current liquidityIndex
     * @return Burned amount of PTokens
     */
    function burn(address _user, uint256 _amount, uint256 _index) external returns (uint256);

    /**
     * @dev Returns the scaled balance of the user.
     * @param _user The owner of pToken
     * @return The scaled balances of the user
     */
    function scaledBalanceOf(address _user) external view returns (uint256);

    /**
     * @dev Returns available balance of the user.
     * @param _user The owner of pToken
     * @return The available balance of the user
     */
    function availableBalanceOf(address _user) external view returns (uint256);

    /**
     * @dev Returns locked deposits and balance of user
     * @param _user The owner of locked deposits
     * @return Structure with deposits and total locked balance of user
     */
    function getUserLockedBalance(address _user) external view returns (LockedBalance memory);

    /**
     * @dev Returns the scaled total supply of pToken.
     * @return The scaled total supply of the pToken.
     */
    function scaledTotalSupply() external view returns (uint256);

    /**
     * @dev Function to get a deposit index in user's deposit array.
     * @param id Deposit id.
     * @return index Deposit index in user's 'deposit' array.
     */
    function getDepositIndexById(uint256 id) external returns (uint256 index);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {IBucket, IBucketV3} from "../Bucket/IBucket.sol";
import {IFeeExecutor} from "../BonusExecutor/IFeeExecutor.sol";
import {IActivityRewardDistributor} from "../ActivityRewardDistributor/IActivityRewardDistributor.sol";

interface IPTokenStorage is IERC20MetadataUpgradeable {
    struct Deposit {
        uint256 lockedBalance;
        uint256 deadline;
        uint256 id;
    }

    struct LockedBalance {
        uint256 totalLockedBalance;
        Deposit[] deposits;
    }

    function bucket() external view returns (IBucketV3);

    function interestIncreaser() external view returns (IFeeExecutor);

    function lenderRewardDistributor() external view returns (IActivityRewardDistributor);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IBucketV3} from "../Bucket/IBucket.sol";
import {IPrimexDNSV3} from "../PrimexDNS/IPrimexDNS.sol";
import {IReserveStorage} from "./IReserveStorage.sol";
import {IPausable} from "../interfaces/IPausable.sol";

interface IReserve is IReserveStorage, IPausable {
    event BurnAmountCalculated(uint256 burnAmount);
    event TransferRestrictionsChanged(address indexed pToken, TransferRestrictions newTransferRestrictions);

    /**
     * @dev contract initializer
     * @param dns The address of PrimexDNS contract
     * @param registry The address of Registry contract
     */
    function initialize(IPrimexDNSV3 dns, address registry) external;

    /**
     * @dev Burns the permanent loss amount (presented in pTokens) from the Reserve for a particular bucket
     * @param bucket The address of a bucket
     * Emits BurnAmountCalculated(burnAmount) event
     */
    function paybackPermanentLoss(IBucketV3 bucket) external;

    /**
     * @dev Transfers some bonus in pTokens to receiver from Reserve
     * Can be called by executor only
     * @param _bucketName The bucket where the msg.sender should be a fee decreaser (for debtToken) or
     * interest increaser (for pToken)
     * @param _to The receiver of bonus pTokens
     * @param _amount The amount of bonus pTokens to transfer
     */
    function payBonus(string memory _bucketName, address _to, uint256 _amount) external;

    /**
     * @dev Function to transfer tokens to the Treasury. Only MEDIUM_TIMELOCK_ADMIN can call it.
     * @param bucket The bucket from which to transfer pTokens
     * @param amount The amount of pTokens to transfer
     */
    function transferToTreasury(address bucket, uint256 amount) external;

    /**
     * @dev Function to set transfer restrictions for a token.
     * @notice Only MEDIUM_TIMELOCK_ADMIN can call it.
     * @param pToken pToken to set restrictions for
     * @param transferRestrictions Min amount to be left in the Reserve
     */
    function setTransferRestrictions(address pToken, TransferRestrictions calldata transferRestrictions) external;
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IReserveStorage {
    struct TransferRestrictions {
        uint256 minAmountToBeLeft;
        uint256 minPercentOfTotalSupplyToBeLeft;
    }

    event TransferFromReserve(address pToken, address to, uint256 amount);

    function transferRestrictions(address pToken) external view returns (uint256, uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {ISpotTradingRewardDistributorStorage} from "./ISpotTradingRewardDistributorStorage.sol";
import {IPausable} from "../interfaces/IPausable.sol";

interface ISpotTradingRewardDistributorV2 is ISpotTradingRewardDistributorStorage, IPausable {
    event SpotTradingClaimReward(address indexed trader, uint256 amount);
    event RewardPerPeriodDecreased(uint256 indexed rewardPerPeriod);
    event TopUpUndistributedPmxBalance(uint256 indexed amount);
    event RewardPerPeriodChanged(uint256 indexed rewardPerPeriod);
    event PmxWithdrawn(uint256 indexed amount);

    /**
     * @dev contract initializer
     * @param registry The address of Registry contract
     * @param periodDuration The duration of a reward period
     * @param priceOracle The address of PriceOracle contract
     * @param pmx The address of PMX token
     * @param traderBalanceVault The address of TraderBalanceVault contract
     * @param treasury The address of Treasury contract
     */
    function initialize(
        address registry,
        uint256 periodDuration,
        address priceOracle,
        address pmx,
        address payable traderBalanceVault,
        address treasury
    ) external;

    /**
     * @dev Function to update spot trader activity. Only PM_ROLE can call it.
     * @param trader Address of a trader
     * @param positionAsset Address of a position asset
     * @param positionAmount Amount of a position asset
     */
    function updateTraderActivity(
        address trader,
        address positionAsset,
        uint256 positionAmount,
        bytes calldata positionUsdOracleDataoracleData
    ) external;

    /**
     * @dev Function to claim reward for spot trading activity.
     * Transfer rewards on the balance in traderBalanceVault
     * Emits SpotTradingClaimReward(address trader, uint256 amount)
     */
    function claimReward() external;

    /**
     * @dev Function to set new reward per period. Only MEDIUM_TIMELOCK_ADMIN can call it.
     * @param rewardPerPeriod New value for reward per period
     */
    function setRewardPerPeriod(uint256 rewardPerPeriod) external;

    /**
     * @dev Function to decrease reward per period. Only EMERGENCY_ADMIN can call it.
     * @param _rewardPerPeriod New value for reward per period, must be less than the current value
     */
    function decreaseRewardPerPeriod(uint256 _rewardPerPeriod) external;

    /**
     * @dev Function to topUp the contract PMX balance
     * @param amount PMX amount to add to the contract balance
     */
    function topUpUndistributedPmxBalance(uint256 amount) external;

    /**
     * @dev Function to withdraw PMX from the contract to treasury
     * @dev Only BIG_TIMELOCK_ADMIN can call it.
     * @param amount Amount of PMX to withdraw from the contract
     */
    function withdrawPmx(uint256 amount) external;

    /**
     * @dev Function to get SpotTraderActivity
     * @param periodNumber Period number
     * @param traderAddress Address of a trader
     * @return A struct with activity and hasClaimed members
     */
    function getSpotTraderActivity(uint256 periodNumber, address traderAddress) external view returns (uint256);

    /**
     * @dev Get information for the period corresponding to the given timestamp
     * @param timestamp The timestamp to get information about
     * @return totalReward Total reward for the corresponding period
     * @return totalActivity Total activity for the corresponding period
     */
    function getPeriodInfo(uint256 timestamp) external view returns (uint256, uint256);

    /**
     * @dev Function to get an array of period numbers when trader had any activity
     * @param trader Address of a trader
     * @return An array of period numbers with trader activity
     */
    function getPeriodsWithTraderActivity(address trader) external view returns (uint256[] memory);

    /**
     * @dev Function to calculate trader's reward for her activities during periods
     * @param trader Address of a trader
     * @return reward Amount of reward
     * @return currentPeriod The current period
     */
    function calculateReward(address trader) external view returns (uint256 reward, uint256 currentPeriod);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface ISpotTradingRewardDistributorStorage {
    struct PeriodInfo {
        uint256 totalReward;
        // map trader address to her activity
        mapping(address => uint256) traderActivity;
        uint256 totalActivity;
    }

    function registry() external view returns (address);

    function dns() external view returns (address);

    function periodDuration() external view returns (uint256);

    function initialPeriodTimestamp() external view returns (uint256);

    function rewardPerPeriod() external view returns (uint256);

    function pmx() external view returns (address);

    function priceOracle() external view returns (address);

    function treasury() external view returns (address);

    function traderBalanceVault() external view returns (address payable);

    function undistributedPMX() external view returns (uint256);

    function periods(uint256 periodNumber) external view returns (uint256, uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {PrimexPricingLibrary} from "../libraries/PrimexPricingLibrary.sol";

import {IPrimexDNSV3, IPrimexDNSStorageV3} from "../PrimexDNS/IPrimexDNS.sol";
import {IPausable} from "../interfaces/IPausable.sol";

interface ISwapManager is IPausable {
    event SpotSwap(
        address indexed trader,
        address indexed receiver,
        address tokenA,
        address tokenB,
        uint256 amountSold,
        uint256 amountBought
    );
    event PaidProtocolFee(
        address indexed trader,
        address indexed boughtAsset,
        IPrimexDNSStorageV3.FeeRateType indexed feeRateType,
        uint256 feeInPositionAsset,
        uint256 feeInPmx
    );

    /**
     * @param tokenA The address of the asset to be swapped from.
     * @param tokenB The address of the asset to be received in the swap.
     * @param amountTokenA The amount of tokenA to be swapped.
     * @param amountOutMin The minimum amount of tokenB expected to receive.
     * @param routes An array of PrimexPricingLibrary.Route structs representing the routes for the swap.
     * @param receiver The address where the swapped tokens will be received.
     * @param deadline The deadline for the swap transaction.
     * @param isSwapFromWallet A flag indicating whether the swap is perfomed from a wallet or a protocol balance.
     * @param isSwapToWallet A flag indicating whether the swapped tokens will be sent to a wallet or a protocol balance.
     * @param isSwapFeeInPmx A flag indicating whether the swap fee is paid in PMX or in native token.
     */
    struct SwapParams {
        address tokenA;
        address tokenB;
        uint256 amountTokenA;
        uint256 amountOutMin;
        PrimexPricingLibrary.MegaRoute[] megaRoutes;
        address receiver;
        uint256 deadline;
        bool isSwapFromWallet;
        bool isSwapToWallet;
        bool isSwapFeeInPmx;
        bytes tokenAtokenBOracleData;
        bytes pmxPositionAssetOracleData;
        bytes nativePositionAssetOracleData;
        bytes[][] pullOracleData;
        uint256[] pullOracleTypes;
    }

    /**
     * @param depositAsset The address of the deposited asset.
     * @param positionAsset The address of the position asset.
     * @param depositAmount Amount of tokens in a deposit asset.
     * @param megaRoutes An array of PrimexPricingLibrary.Route structs representing the routes for the swap.
     * @param trader The trader address, who has created the order.
     * @param deadline The deadline for the swap transaction.
     * @param feeToken An asset in which the fee will be paid. At this point it could be the pmx, the epmx or a positionAsset
     * @param keeperRewardDistributor The address of KeeperRewardDistributor contract.
     * @param gasSpent Gas spent on executing transaction.
     */
    struct SwapInLimitOrderParams {
        address depositAsset;
        address positionAsset;
        uint256 depositAmount;
        PrimexPricingLibrary.MegaRoute[] megaRoutes;
        address trader;
        uint256 deadline;
        address feeToken;
        address keeperRewardDistributor;
        uint256 gasSpent;
        bytes depositPositionAssetOracleData;
        bytes pmxPositionAssetOracleData;
        bytes nativePositionAssetOracleData;
    }

    /**
     * @notice Initializes the contract with the specified parameters.
     * @param _registry The address of the PrimexRegistry contract.
     */
    function initialize(address _registry) external;

    /**
     * @notice Re-initializes the contract with the specified parameters.
     * @dev Only BIG_TIMELOCK_ADMIN can call it.
     * @param _primexDNS The address of the PrimexDNS contract.
     * @param _traderBalanceVault The address of the TraderBalanceVault contract.
     * @param _priceOracle The address of the PriceOracle contract.
     * @param _whiteBlackList The address of the WhiteBlackList contract.
     */
    function initializeAfterUpgrade(
        address _primexDNS,
        address payable _traderBalanceVault,
        address _priceOracle,
        address _whiteBlackList
    ) external;

    /**
     * @notice Executes a swap on dexes defined in routes
     * @param params The SwapParams struct containing the details of the swap transaction.
     * @param maximumOracleTolerableLimit The maximum tolerable limit in WAD format (1 WAD = 100%)
     * @param needOracleTolerableLimitCheck Flag indicating whether to perform an oracle tolerable limit check.
     * @return The resulting amount after the swap.
     */
    function swap(
        SwapParams calldata params,
        uint256 maximumOracleTolerableLimit,
        bool needOracleTolerableLimitCheck
    ) external payable returns (uint256);

    /**
     * @notice Executes a swap on dexes defined in routes
     * @dev Only callable by the LOM_ROLE role.
     * @param params The SwapInLimitOrderParams struct containing the details of the swap transaction.
     * @param maximumOracleTolerableLimit The maximum tolerable limit in WAD format (1 WAD = 100%)
     * @return The resulting amount after the swap and feeInPositionAsset.
     */
    function swapInLimitOrder(
        SwapInLimitOrderParams calldata params,
        uint256 maximumOracleTolerableLimit
    ) external returns (uint256, uint256);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {ITraderBalanceVaultStorage} from "./ITraderBalanceVaultStorage.sol";
import {IPausable} from "../interfaces/IPausable.sol";

interface ITraderBalanceVault is ITraderBalanceVaultStorage, IPausable {
    /**
     * Types of way to open a position or order
     */
    enum OpenType {
        OPEN_BY_ORDER,
        OPEN,
        CREATE_LIMIT_ORDER
    }

    /**
     * @param trader The trader, who opens margin deal
     * @param depositReceiver the address to which the deposit is transferred when blocked.
     * This happens because the trader's deposit is involved in the position
     * @param borrowedAsset The token to lock for deal in a borrowed asset
     * @param depositAsset The token is a deposit asset
     * (it is blocked when creating a limit order
     * For others, the operations is transferred to the account of the receiver of the deposit and is swapped )
     * @param depositAmount Amount of tokens in a deposit asset
     * @param depositInBorrowedAmount Amount of tokens to lock for deal in a borrowed asset
     * @param openType Corresponds to the purpose of locking
     */
    struct LockAssetParams {
        address trader;
        address depositReceiver;
        address depositAsset;
        uint256 depositAmount;
        OpenType openType;
    }

    /**
     * @param trader The trader who opened the position
     * @param receiver The receiver of the rest of trader deposit.
     * @param asset Borrowed asset of the position being closed (the need for accrual of profit).
     * @param unlockAmount The amount of unlocked collateral for deal
     * @param returnToTrader The returned to trader amount when position was closed.
     */
    struct UnlockAssetParams {
        address trader;
        address receiver;
        address asset;
        uint256 amount;
    }

    /**
     * @param traders An array of traders for which available balance should be increased
     * @param amounts An array of amounts corresponding to traders' addresses that should be added to their available balances
     * @param asset Asset address which amount will be increased
     * @param length The amount of traders in an array
     */
    struct BatchTopUpAvailableBalanceParams {
        address[] traders;
        uint256[] amounts;
        address asset;
        uint256 length;
    }

    event Deposit(address indexed depositer, address indexed asset, uint256 amount);
    event Withdraw(address indexed withdrawer, address asset, uint256 amount);

    /**
     * @dev contract initializer
     * @param _registry The address of Registry contract
     * @param _whiteBlackList The address of WhiteBlackList contract
     */
    function initialize(address _registry, address _whiteBlackList) external;

    receive() external payable;

    /**
     * @dev Deposits trader collateral for margin deal
     * @param _asset The collateral asset for deal
     * @param _amount The amount of '_asset' to deposit
     */
    function deposit(address _asset, uint256 _amount) external payable;

    /**
     * @dev Withdraws the rest of trader's deposit after closing deal
     * @param _asset The collateral asset for withdraw
     * @param _amount The amount of '_asset' to withdraw
     */
    function withdraw(address _asset, uint256 _amount) external;

    /**
     * @dev Traders lock their collateral for the limit order.
     * @param _trader The owner of collateral
     * @param _asset The collateral asset for deal
     * @param _amount The amount of '_asset' to deposit
     */
    function increaseLockedBalance(address _trader, address _asset, uint256 _amount) external payable;

    /**
     * @dev Locks deposited trader's assets as collateral for orders.
     * Decreases the available balance when opening position.
     * Transfers deposited amount to the deposit receiver.
     * @param _params parameters necessary to lock asset
     */
    function useTraderAssets(LockAssetParams calldata _params) external;

    /**
     * @dev Unlocks trader's collateral when open position by order or update deposit.
     * @param _params parameters necessary to unlock asset
     */
    function unlockAsset(UnlockAssetParams calldata _params) external;

    /**
     * The function to increase available balance for several traders
     * @param _params A struct containing BatchTopUpAvailableBalanceParams
     */
    function batchTopUpAvailableBalance(BatchTopUpAvailableBalanceParams calldata _params) external;

    /**
     * Withdraws an asset amount from an asset holder to a receiver
     * @param _from Withdraw from address
     * @param _to Withdraw to address
     * @param _asset Address of an asset
     * @param _amount Amount of an asset
     * @param fromLocked True if withdraw from locked balance
     */
    function withdrawFrom(address _from, address _to, address _asset, uint256 _amount, bool fromLocked) external;

    /**
     * Increases available balance of a receiver in the protocol
     * @param receiver The address of an asset receiver
     * @param asset The asset address for which available balance will be increased
     * @param amount The amount of an asset
     */
    function topUpAvailableBalance(address receiver, address asset, uint256 amount) external payable;
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface ITraderBalanceVaultStorage {
    struct TraderBalance {
        uint256 availableBalance;
        uint256 lockedBalance;
    }

    function registry() external view returns (address);

    /**
     *
     * @param trader Trader's address
     * @param asset Asset address
     * @return availableBalance availableBalance
     * @return lockedBalance lockedBalance
     */
    function balances(
        address trader,
        address asset
    ) external view returns (uint256 availableBalance, uint256 lockedBalance);
}

// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IWhiteBlackList {
    enum AccessType {
        UNLISTED,
        WHITELISTED,
        BLACKLISTED
    }
    event WhitelistedAddressAdded(address indexed addr);
    event WhitelistedAddressRemoved(address indexed addr);
    event BlacklistedAddressAdded(address indexed addr);
    event BlacklistedAddressRemoved(address indexed addr);

    function addAddressToWhitelist(address _address) external;

    function addAddressesToWhitelist(address[] calldata _addresses) external;

    function removeAddressFromWhitelist(address _address) external;

    function removeAddressesFromWhitelist(address[] calldata _addresses) external;

    function addAddressToBlacklist(address _address) external;

    function addAddressesToBlacklist(address[] calldata _addresses) external;

    function removeAddressFromBlacklist(address _address) external;

    function removeAddressesFromBlacklist(address[] calldata _addresses) external;

    function getAccessType(address _address) external view returns (AccessType);

    function isBlackListed(address _address) external view returns (bool);

    function registry() external view returns (address);
}
