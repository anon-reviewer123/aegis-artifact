// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0 ^0.8.1 ^0.8.2 ^0.8.20 ^0.8.28;

// lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

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

// lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol

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

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

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

// lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/cryptography/ECDSA.sol)

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    /**
     * @dev The signature derives the `address(0)`.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
     * return address(0) without also returning an error description. Errors are documented using an enum (error type)
     * and a bytes32 providing additional information about the error.
     *
     * If no error is returned, then the address can be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     */
    function tryRecover(
        bytes32 hash,
        bytes memory signature
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly ("memory-safe") {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[ERC-2098 short signatures]
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address recovered, RecoverError err, bytes32 errArg) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}

// src/interfaces/allowlist/IAllowlist.sol

interface IAllowlist {
    /// @dev Mapping of addresses to their permissions
    struct Permission {
        bool isAllowed;
        bool state1;
        bool state2;
        bool state3;
        bool state4;
        bool state5;
    }

    /// @notice An event emitted when an entityId's permission status is changed
    event PermissionSet(uint256 indexed entityId, Permission permission);

    /// @notice An event emitted when an address is associated with an entityId
    event EntityIdSet(address indexed addr, uint256 indexed entityId);

    /// @dev Thrown when a request is not sent by the authorized admin
    error Unauthorized();

    /// @dev Thrown when the input for a function is invalid
    error BadData();

    /// @dev Thrown when the input is already equivalent to the storage being set
    error AlreadySet();

    /// @dev Default value for the addressEntityIds mapping is 0, so entityIds are 1 indexed and setting permissions for 0 is not allowed
    error ZeroEntityIdNotAllowed();

    /// @dev An address's entityId can not be changed once set, it can only be unset and then set to a new value
    error NonZeroEntityIdMustBeChangedToZero();

    /**
     * @notice Fetches the permissions for a given address
     * @param addr The address whose permissions are to be fetched
     * @return Permission The permissions of the address
     */
    function getPermission(address addr) external view returns (Permission memory);

    /**
     * @notice Sets the entityId for a given address. Setting to 0 removes the address from the allowlist
     * @param entityId The entityId to associate with an address
     * @param addr The address to associate with an entityId
     */
    function setEntityIdForAddress(uint256 entityId, address addr) external;

    /**
     * @notice Sets the entity Id for a list of addresses. Setting to 0 removes the address from the allowlist
     * @param entityId The entityId to associate with an address
     * @param addresses The addresses to associate with an entityId
     */
    function setEntityIdForMultipleAddresses(uint256 entityId, address[] calldata addresses) external;

    /**
     * @notice Sets permissions for a given entityId
     * @param entityId The entityId to be updated
     * @param permission The permission status to set
     */
    function setPermission(uint256 entityId, Permission calldata permission) external;

    /**
     * @notice Sets entity for an array of addresses and sets permissions for an entity
     * @param entityId The entityId to be updated
     * @param addresses The addresses to associate with an entityId
     * @param permission The permissions to set
     */
    function setEntityPermissionAndAddresses(
        uint256 entityId,
        address[] calldata addresses,
        Permission calldata permission
    ) external;

    /**
     * @notice Sets isAllowed permissions for a given entityId
     * @param entityId The entityId to be updated
     * @param value The isAllowed status to set
     */
    function setIsAllowed(uint256 entityId, bool value) external;

    /**
     * @notice Sets the nth permission for a given entityId
     * @param entityId The entityId to be updated
     * @param index The index of the permission to update
     * @param value The status to set
     * @dev Permissions are 0 indexed, meaning the first permission (isAllowed) has an index of 0
     */
    function setNthPermission(uint256 entityId, uint256 index, bool value) external;
}

// src/interfaces/allowlist/IAllowlistV2.sol

interface IAllowlistV2 {
    type EntityId is uint256;

    /// @notice An event emitted when an address's permission is changed for a fund.
    event FundPermissionSet(EntityId indexed entityId, string fundSymbol, bool permission);

    /// @notice An event emitted when a protocol's permission is changed for a fund.
    event ProtocolAddressPermissionSet(address indexed addr, string fundSymbol, bool isAllowed);

    /// @notice An event emitted when an address is associated with an entityId
    event EntityIdSet(address indexed addr, uint256 indexed entityId);

    /// @dev Thrown when the input for a function is invalid
    error BadData();

    /// @dev Thrown when the input is already equivalent to the storage being set
    error AlreadySet();

    /// @dev An address's entityId can not be changed once set, it can only be unset and then set to a new value
    error NonZeroEntityIdMustBeChangedToZero();

    /// @dev Thrown when trying to set entityId for an address that has protocol permissions
    error AddressHasProtocolPermissions();
    /// @dev Thrown when trying to set protocol permissions for an address that has an entityId
    error AddressHasEntityId();
    /// @dev Thrown when trying to set protocol permissions but the code size is 0
    error CodeSizeZero();
    /// @dev Thrown when a method is no longer supported
    error Deprecated();
    /// @dev Thrown if an attempt to call `renounceOwnership` is made
    error RenounceOwnershipDisabled();

    /**
     * @notice Gets the entityId for the provided address
     * @param addr The address to get the entityId for
     */
    function addressEntityIds(address addr) external view returns (EntityId);

    /**
     * @notice Checks whether an address is allowed to use a fund
     * @param addr The address to check permissions for
     * @param fundSymbol The fund symbol to check permissions for
     */
    function isAddressAllowedForFund(address addr, string calldata fundSymbol) external view returns (bool);

    /**
     * @notice Checks whether an Entity is allowed to use a fund
     * @param fundSymbol The fund symbol to check permissions for
     */
    function isEntityAllowedForFund(EntityId entityId, string calldata fundSymbol) external view returns (bool);

    /**
     * @notice Sets whether an Entity is allowed to use a fund
     * @param fundSymbol The fund symbol to set permissions for
     * @param isAllowed The permission value to set
     */
    function setEntityAllowedForFund(EntityId entityId, string calldata fundSymbol, bool isAllowed) external;

    /**
     * @notice Sets the entityId for a given address. Setting to 0 removes the address from the allowlist
     * @param entityId The entityId to associate with an address
     * @param addr The address to associate with an entityId
     */
    function setEntityIdForAddress(EntityId entityId, address addr) external;

    /**
     * @notice Sets the entity Id for a list of addresses. Setting to 0 removes the address from the allowlist
     * @param entityId The entityId to associate with an address
     * @param addresses The addresses to associate with an entityId
     */
    function setEntityIdForMultipleAddresses(EntityId entityId, address[] calldata addresses) external;

    /**
     * @notice Sets protocol permissions for an address
     * @param addr The address to set permissions for
     * @param fundSymbol The fund symbol to set permissions for
     * @param isAllowed The permission value to set
     */
    function setProtocolAddressPermission(address addr, string calldata fundSymbol, bool isAllowed) external;

    /**
     * @notice Sets protocol permissions for multiple addresses
     * @param addresses The addresses to set permissions for
     * @param fundSymbol The fund symbol to set permissions for
     * @param isAllowed The permission value to set
     */
    function setProtocolAddressPermissions(address[] calldata addresses, string calldata fundSymbol, bool isAllowed)
        external;

    /**
     * @notice Sets entity for an array of addresses and sets permissions for an entity
     * @param entityId The entityId to be updated
     * @param addresses The addresses to associate with an entityId
     * @param fundPermissionsToUpdate The funds to update permissions for
     * @param fundPermissions The permissions for each fund
     */
    function setEntityPermissionsAndAddresses(
        EntityId entityId,
        address[] calldata addresses,
        string[] calldata fundPermissionsToUpdate,
        bool[] calldata fundPermissions
    ) external;

    function hasAnyProtocolPermissions(address addr) external view returns (bool hasPermissions);

    function protocolPermissionsForFunds(address protocol) external view returns (uint256);

    function protocolPermissions(address, string calldata) external view returns (bool);

    function initialize() external;
}

// lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

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

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

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

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

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

// lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

// lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

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

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

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

// lib/openzeppelin-contracts-upgradeable/contracts/interfaces/IERC20Upgradeable.sol

// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

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

// lib/openzeppelin-contracts/contracts/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

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

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol

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

// lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol

// OpenZeppelin Contracts (last updated v5.1.0) (access/Ownable2Step.sol)

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This extension of the {Ownable} contract includes a two-step mechanism to transfer
 * ownership, where the new owner must call {acceptOwnership} in order to replace the
 * old one. This can help prevent common mistakes, such as transfers of ownership to
 * incorrect accounts, or to contracts that are unable to interact with the
 * permission system.
 *
 * The initial owner is specified at deployment time in the constructor for `Ownable`. This
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
     *
     * Setting `newOwner` to the zero address is allowed; this can be used to cancel an initiated ownership transfer.
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
        if (pendingOwner() != sender) {
            revert OwnableUnauthorizedAccount(sender);
        }
        _transferOwnership(sender);
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// lib/openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

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

// lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol

// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)

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

// lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable2Step.sol)

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
abstract contract Ownable2StepUpgradeable is Initializable, OwnableUpgradeable {
    function __Ownable2Step_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable2Step_init_unchained() internal onlyInitializing {
    }
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// ../redemptions/src/oracle/SuperstateOracle.sol

/// @title SuperstateOracle
/// @author Jon Walch (Superstate) https://github.com/superstateinc
/// @notice A contract that allows Superstate to price USTB by extrapolating previous prices forward in real time
contract SuperstateOracle is AggregatorV3Interface, Ownable2Step {
    /// @notice Represents a checkpoint for a Net Asset Value per Share (NAV/S) for a specific Superstate Business Day
    struct NavsCheckpoint {
        /// @notice The timestamp of 5pm ET of the Superstate Business day for this NAV/S
        uint64 timestamp;
        /// @notice The timestamp from which this NAV/S price can be used for realtime pricing
        uint64 effectiveAt;
        /// @notice The NAV/S at this checkpoint
        uint128 navs;
    }

    /// @notice Number of days in seconds to keep extrapolating from latest checkpoint
    uint256 public constant CHECKPOINT_EXPIRATION_PERIOD = 5 * 24 * 60 * 60; // 5 days in seconds

    /// @notice The address of the USTB token proxy contract that this oracle prices
    address public immutable USTB_TOKEN_PROXY_ADDRESS;

    /// @notice Decimals of SuperstateTokens
    uint8 public constant DECIMALS = 6;

    /// @notice Version number of SuperstateOracle
    uint8 public constant VERSION = 1;

    /// @notice Highest accepted delta between new Net Asset Value per Share price and the last one
    uint256 public maximumAcceptablePriceDelta;

    /// @notice Offchain Net Asset Value per Share checkpoints
    NavsCheckpoint[] public checkpoints;

    /// @notice The ```NewCheckpoint``` event is emitted when a new checkpoint is added
    /// @param timestamp The 5pm ET timestamp of when this price was calculated for offchain
    /// @param effectiveAt When this checkpoint starts being used for pricing
    /// @param navs The Net Asset Value per Share (NAV/S) price (i.e. 10123456 is 10.123456)
    event NewCheckpoint(uint64 timestamp, uint64 effectiveAt, uint128 navs);

    /// @notice The ```UpdatedMaximumAcceptablePriceDelta``` event is emitted when a new checkpoint is added
    /// @param oldDelta The old delta value
    /// @param newDelta The new delta value
    event SetMaximumAcceptablePriceDelta(uint256 oldDelta, uint256 newDelta);

    /// @dev Thrown when an argument to a function is not acceptable
    error BadArgs();

    /// @dev Thrown when there aren't at least 2 checkpoints where block.timestamp is after the effectiveAt timestamps for both
    error CantGeneratePrice();

    /// @dev Thrown when the effectiveAt argument is invalid
    error EffectiveAtInvalid();

    /// @dev Thrown when the effectiveAt argument is not chronologically valid
    error EffectiveAtNotChronological();

    /// @dev Thrown when there is an effectiveAt in the future for a previously written checkpoint
    error ExistingPendingEffectiveAt();

    /// @dev Thrown when the navs argument is too low
    error NetAssetValuePerShareTooLow();

    /// @dev Thrown when the navs argument is too high
    error NetAssetValuePerShareTooHigh();

    /// @dev Thrown when the function is not implemented
    error NotImplemented();

    /// @dev Thrown when the latest checkpoint is too stale to use to price
    error StaleCheckpoint();

    /// @dev Thrown when the timestamp argument is invalid
    error TimestampInvalid();

    /// @dev Thrown when the timestamp argument is chronologically invalid
    error TimestampNotChronological();

    constructor(address initialOwner, address ustbTokenProxy, uint256 _maximumAcceptablePriceDelta)
        Ownable(initialOwner)
    {
        USTB_TOKEN_PROXY_ADDRESS = ustbTokenProxy;
        _setMaximumAcceptablePriceDelta(_maximumAcceptablePriceDelta);
    }

    function decimals() external pure override returns (uint8) {
        return DECIMALS;
    }

    function description() external pure override returns (string memory) {
        return "Realtime USTB Net Asset Value per Share (NAV/S) Oracle";
    }

    function version() external pure override returns (uint256) {
        return VERSION;
    }

    function _setMaximumAcceptablePriceDelta(uint256 _newMaximumAcceptablePriceDelta) internal {
        if (maximumAcceptablePriceDelta == _newMaximumAcceptablePriceDelta) revert BadArgs();
        emit SetMaximumAcceptablePriceDelta({
            oldDelta: maximumAcceptablePriceDelta,
            newDelta: _newMaximumAcceptablePriceDelta
        });
        maximumAcceptablePriceDelta = _newMaximumAcceptablePriceDelta;
    }
    /**
     * @notice The ```setMaximumAcceptablePriceDelta``` function sets the max acceptable price delta between the last NAV/S price and the new one being added
     * @dev Requires msg.sender to be the owner address
     * @param _newMaximumAcceptablePriceDelta The new max acceptable price delta
     */

    function setMaximumAcceptablePriceDelta(uint256 _newMaximumAcceptablePriceDelta) external {
        _checkOwner();
        _setMaximumAcceptablePriceDelta(_newMaximumAcceptablePriceDelta);
    }

    /// @notice Adds a new NAV/S checkpoint
    /// @dev This function performs various checks to ensure the validity of the new checkpoint
    /// @param timestamp The timestamp of the checkpoint (should be 5pm ET of the business day)
    /// @param effectiveAt The time from which this checkpoint becomes effective (must be now or in the future)
    /// @param navs The Net Asset Value per Share for this checkpoint
    /// @param shouldOverrideEffectiveAt Flag to allow overriding an existing pending effective timestamp
    function _addCheckpoint(uint64 timestamp, uint64 effectiveAt, uint128 navs, bool shouldOverrideEffectiveAt)
        internal
    {
        uint256 nowTimestamp = block.timestamp;

        // timestamp should refer to 5pm ET of a previous business day
        if (timestamp >= nowTimestamp) revert TimestampInvalid();

        // effectiveAt must be now or in the future
        if (effectiveAt < nowTimestamp) revert EffectiveAtInvalid();

        // Can only add new checkpoints going chronologically forward
        if (checkpoints.length > 0) {
            NavsCheckpoint memory latest = checkpoints[checkpoints.length - 1];
            if (navs > latest.navs + maximumAcceptablePriceDelta) revert NetAssetValuePerShareTooHigh();
            if (navs < latest.navs - maximumAcceptablePriceDelta) revert NetAssetValuePerShareTooLow();

            if (latest.timestamp >= timestamp) {
                revert TimestampNotChronological();
            }

            if (latest.effectiveAt >= effectiveAt) {
                revert EffectiveAtNotChronological();
            }
        }

        // Revert if there is already a checkpoint with an effectiveAt in the future, unless override
        // Only start the check after 2 checkpoints, since two are needed to get a price at all
        if (checkpoints.length > 1 && checkpoints[checkpoints.length - 1].effectiveAt > nowTimestamp) {
            if (!shouldOverrideEffectiveAt) {
                revert ExistingPendingEffectiveAt();
            }
        }

        checkpoints.push(NavsCheckpoint({timestamp: timestamp, effectiveAt: effectiveAt, navs: navs}));

        emit NewCheckpoint({timestamp: timestamp, effectiveAt: effectiveAt, navs: navs});
    }

    /// @notice Adds a single NAV/S checkpoint
    /// @dev This function can only be called by the contract owner. Automated systems should only use this and not `addCheckpoints`
    /// @param timestamp The timestamp of the checkpoint
    /// @param effectiveAt The time from which this checkpoint becomes effective
    /// @param navs The Net Asset Value per Share for this checkpoint
    /// @param shouldOverrideEffectiveAt Flag to allow overriding an existing pending effective timestamp
    function addCheckpoint(uint64 timestamp, uint64 effectiveAt, uint128 navs, bool shouldOverrideEffectiveAt)
        external
    {
        _checkOwner();

        _addCheckpoint({
            timestamp: timestamp,
            effectiveAt: effectiveAt,
            navs: navs,
            shouldOverrideEffectiveAt: shouldOverrideEffectiveAt
        });
    }

    /// @notice Adds multiple NAV/S checkpoints at once
    /// @dev This function can only be called by the contract owner. Should not be used via automated systems.
    /// @param _checkpoints An array of NavsCheckpoint structs to be added
    function addCheckpoints(NavsCheckpoint[] calldata _checkpoints) external {
        _checkOwner();

        for (uint256 i = 0; i < _checkpoints.length; ++i) {
            _addCheckpoint({
                timestamp: _checkpoints[i].timestamp,
                effectiveAt: _checkpoints[i].effectiveAt,
                navs: _checkpoints[i].navs,
                shouldOverrideEffectiveAt: true
            });
        }
    }

    /// @notice Calculates the real-time NAV based on two checkpoints
    /// @dev Uses linear interpolation to estimate the NAV/S at the target timestamp
    /// @param targetTimestamp The timestamp for which to calculate the NAV/S
    /// @param earlierCheckpointNavs The NAV/S of the earlier checkpoint
    /// @param earlierCheckpointTimestamp The timestamp of the earlier checkpoint
    /// @param laterCheckpointNavs The NAV/S of the later checkpoint
    /// @param laterCheckpointTimestamp The timestamp of the later checkpoint
    /// @return answer The calculated real-time NAV/S
    function calculateRealtimeNavs(
        uint128 targetTimestamp,
        uint128 earlierCheckpointNavs,
        uint128 earlierCheckpointTimestamp,
        uint128 laterCheckpointNavs,
        uint128 laterCheckpointTimestamp
    ) public pure returns (uint128 answer) {
        uint128 timeSinceLastNav = targetTimestamp - laterCheckpointTimestamp;
        uint128 timeBetweenNavs = laterCheckpointTimestamp - earlierCheckpointTimestamp;

        uint128 navDelta;
        if (laterCheckpointNavs >= earlierCheckpointNavs) {
            navDelta = laterCheckpointNavs - earlierCheckpointNavs;
        } else {
            navDelta = earlierCheckpointNavs - laterCheckpointNavs;
        }

        uint128 extrapolatedChange = (navDelta * timeSinceLastNav) / timeBetweenNavs;

        if (laterCheckpointNavs >= earlierCheckpointNavs) {
            // Price is increasing or flat, this branch should almost always be taken
            answer = laterCheckpointNavs + extrapolatedChange;
        } else {
            // Price is decreasing, very rare, we might not ever see this happen
            answer = laterCheckpointNavs - extrapolatedChange;
        }
    }

    /// @notice Placeholder function to comply with the Chainlink AggregatorV3Interface
    /// @dev This function is not implemented and will always revert
    /// @dev param: roundId The round ID (unused)
    /// @return Tuple of round data (never actually returned)
    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert NotImplemented();
    }

    /// @notice Retrieves the latest NAV/S real-time price data
    /// @dev Calculates the current NAV/S based on the two most recent valid checkpoints
    /// @return roundId The ID of the latest round
    /// @return answer The current NAV/S
    /// @return startedAt The timestamp when this round started (current block timestamp)
    /// @return updatedAt The timestamp of the last update (current block timestamp, won't ever update)
    /// @return answeredInRound The round ID in which the answer was computed
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (checkpoints.length < 2) revert CantGeneratePrice(); // need at least two rounds. i.e. 0 and 1

        uint256 latestIndex = checkpoints.length - 1;
        uint128 nowTimestamp = uint128(block.timestamp);

        // We will only have one checkpoint that isn't effective yet the vast majority of the time
        while (checkpoints[latestIndex].effectiveAt > nowTimestamp) {
            latestIndex -= 1;
            if (latestIndex == 0) revert CantGeneratePrice(); // need at least two rounds i.e. 0 and 1
        }

        NavsCheckpoint memory laterCheckpoint = checkpoints[latestIndex];
        NavsCheckpoint memory earlierCheckpoint = checkpoints[latestIndex - 1];

        if (nowTimestamp > laterCheckpoint.effectiveAt + CHECKPOINT_EXPIRATION_PERIOD) {
            revert StaleCheckpoint();
        }

        uint128 realtimeNavs = calculateRealtimeNavs({
            targetTimestamp: nowTimestamp,
            earlierCheckpointNavs: earlierCheckpoint.navs,
            earlierCheckpointTimestamp: earlierCheckpoint.timestamp,
            laterCheckpointNavs: laterCheckpoint.navs,
            laterCheckpointTimestamp: laterCheckpoint.timestamp
        });

        roundId = uint80(latestIndex);
        answer = int256(uint256(realtimeNavs));
        startedAt = nowTimestamp;
        updatedAt = nowTimestamp;
        answeredInRound = uint80(latestIndex);
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}

// lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/utils/SafeERC20.sol)

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
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transferFrom, (from, to, value)));
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

// src/allowlist/v2/AllowlistV2.sol

/**
 * @title Allowlist
 * @notice A contract that provides allowlist functionalities with both entity-based and protocol address permissions
 * @author Chris Ridmann (Superstate)
 */
contract AllowlistV2 is IAllowlistV2, Ownable2StepUpgradeable {
    /**
     * @dev This empty reserved space is put in place to allow future versions to inherit from new contracts
     * without impacting the fields within `SuperstateToken`.
     */
    uint256[500] private __inheritanceGap;

    /// @notice The major version of this contract
    string public constant VERSION = "2";

    /// @notice A record of entityIds associated with each address. Setting to 0 removes the address from the allowlist.
    mapping(address => EntityId) public addressEntityIds;

    /// @notice A record of permissions for each entityId determining if they are allowed.
    mapping(EntityId => mapping(string fundSymbol => bool permission)) public fundPermissionsByEntityId;

    /// @notice A record of how many funds a protocol is allowed for
    mapping(address protocol => uint256 numberOfFunds) public protocolPermissionsForFunds;

    /// @notice Protocol address permissions, mutually exclusive with entityId permissions
    mapping(address protocol => mapping(string fundSymbol => bool permission)) public protocolPermissions;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new fields without impacting
     * any contracts that inherit `SuperstateToken`
     */
    uint256[100] private __additionalFieldsGap;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract
     */
    function initialize() public initializer {
        __Ownable2Step_init();
    }

    function isAddressAllowedForFund(address addr, string calldata fundSymbol) external view returns (bool) {
        // EntityId is 0 for unset addresses
        if (EntityId.unwrap(addressEntityIds[addr]) == 0) {
            return protocolPermissions[addr][fundSymbol];
        }

        EntityId entityId = addressEntityIds[addr];
        return isEntityAllowedForFund(entityId, fundSymbol);
    }

    function isEntityAllowedForFund(EntityId entityId, string calldata fundSymbol) public view returns (bool) {
        return fundPermissionsByEntityId[entityId][fundSymbol];
    }

    function setEntityAllowedForFund(EntityId entityId, string calldata fundSymbol, bool isAllowed) external {
        _checkOwner();
        _setEntityAllowedForFundInternal(entityId, fundSymbol, isAllowed);
    }

    function _setEntityAllowedForFundInternal(EntityId entityId, string calldata fundSymbol, bool isAllowed) internal {
        fundPermissionsByEntityId[entityId][fundSymbol] = isAllowed;
        emit FundPermissionSet(entityId, fundSymbol, isAllowed);
    }

    function _setProtocolAllowedForFundInternal(address addr, string calldata fundSymbol, bool isAllowed) internal {
        bool currentValue = protocolPermissions[addr][fundSymbol];

        if (currentValue == isAllowed) revert AlreadySet();

        uint256 codeSize;
        assembly {
            codeSize := extcodesize(addr)
        }

        if (codeSize == 0) revert CodeSizeZero();

        if (isAllowed) {
            protocolPermissionsForFunds[addr] += 1;
        } else {
            protocolPermissionsForFunds[addr] -= 1;
        }

        protocolPermissions[addr][fundSymbol] = isAllowed;
        emit ProtocolAddressPermissionSet(addr, fundSymbol, isAllowed);
    }

    /**
     * @notice Sets protocol permissions for an address
     * @param addr The address to set permissions for
     * @param fundSymbol The fund symbol to set permissions for
     * @param isAllowed The permission value to set
     */
    function setProtocolAddressPermission(address addr, string calldata fundSymbol, bool isAllowed) external {
        _checkOwner();
        if (EntityId.unwrap(addressEntityIds[addr]) != 0) revert AddressHasEntityId();

        _setProtocolAllowedForFundInternal(addr, fundSymbol, isAllowed);
    }

    /**
     * @notice Sets protocol permissions for multiple addresses
     * @param addresses The addresses to set permissions for
     * @param fundSymbol The fund symbol to set permissions for
     * @param isAllowed The permission value to set
     */
    function setProtocolAddressPermissions(address[] calldata addresses, string calldata fundSymbol, bool isAllowed)
        external
    {
        _checkOwner();

        for (uint256 i = 0; i < addresses.length; ++i) {
            if (EntityId.unwrap(addressEntityIds[addresses[i]]) != 0) revert AddressHasEntityId();
            _setProtocolAllowedForFundInternal(addresses[i], fundSymbol, isAllowed);
        }
    }

    /**
     * @notice Sets the entityId for a given address. Setting to 0 removes the address from the allowlist
     * @param entityId The entityId whose permissions are to be set
     * @param addr The address to set entity for
     * @dev the caller must check if msg.sender is authenticated
     */
    function _setEntityAddressInternal(EntityId entityId, address addr) internal {
        EntityId prevId = addressEntityIds[addr];

        if (EntityId.unwrap(prevId) == EntityId.unwrap(entityId)) revert AlreadySet();

        // Check if address has protocol permissions when trying to set a non-zero entityId
        if (EntityId.unwrap(entityId) != 0) {
            if (hasAnyProtocolPermissions(addr)) revert AddressHasProtocolPermissions();
        }

        // Must set entityId to zero before setting to a new value.
        // If prev id is nonzero, revert if entityId is not zero.
        if (EntityId.unwrap(prevId) != 0 && EntityId.unwrap(entityId) != 0) revert NonZeroEntityIdMustBeChangedToZero();

        addressEntityIds[addr] = entityId;
        emit EntityIdSet(addr, EntityId.unwrap(entityId));
    }

    /**
     * @notice Helper function to check if an address has any protocol permissions
     * @param addr The address to check
     * @return hasPermissions True if the address has any protocol permissions for any fund
     * @dev This is used to ensure an address doesn't have both entity and protocol permissions
     */
    function hasAnyProtocolPermissions(address addr) public view returns (bool hasPermissions) {
        hasPermissions = protocolPermissionsForFunds[addr] > 0;
    }

    function setEntityIdForAddress(EntityId entityId, address addr) external {
        _checkOwner();
        _setEntityAddressInternal(entityId, addr);
    }

    /**
     * @notice Sets the entity Id for a list of addresses. Setting to 0 removes the address from the allowlist
     * @param entityId The entityId to associate with an address
     * @param addresses The addresses to associate with an entityId
     */
    function setEntityIdForMultipleAddresses(EntityId entityId, address[] calldata addresses) external {
        _checkOwner();

        for (uint256 i = 0; i < addresses.length; ++i) {
            _setEntityAddressInternal(entityId, addresses[i]);
        }
    }

    /**
     * @notice Sets entity for an array of addresses and sets permissions for an entity
     * @param entityId The entityId to be updated
     * @param addresses The addresses to associate with an entityId
     * @param fundPermissionsToUpdate The funds to update permissions for
     * @param fundPermissions The permissions for each fund
     */
    function setEntityPermissionsAndAddresses(
        EntityId entityId,
        address[] calldata addresses,
        string[] calldata fundPermissionsToUpdate,
        bool[] calldata fundPermissions
    ) external {
        _checkOwner();

        // Ensure fundPermissionsToUpdate.length == fundPermissions.length
        if (fundPermissionsToUpdate.length != fundPermissions.length) {
            revert BadData();
        }

        // Check for protocol permissions and set Entity for addresses
        for (uint256 i = 0; i < addresses.length; ++i) {
            _setEntityAddressInternal(entityId, addresses[i]);
        }

        // Set permissions for entity
        for (uint256 i = 0; i < fundPermissionsToUpdate.length; ++i) {
            _setEntityAllowedForFundInternal(entityId, fundPermissionsToUpdate[i], fundPermissions[i]);
        }
    }

    function renounceOwnership() public virtual override onlyOwner {
        revert RenounceOwnershipDisabled();
    }
}

// src/interfaces/ISuperstateTokenV5_1.sol

interface ISuperstateTokenV5_1 is IERC20Upgradeable {
    // V1 remaining

    /// @dev Event emitted when tokens are minted
    event Mint(address indexed minter, address indexed to, uint256 amount);

    /// @dev Emitted when the accounting pause is triggered by `admin`.
    event AccountingPaused(address admin);

    /// @dev Emitted when the accounting pause is lifted by `admin`.
    event AccountingUnpaused(address admin);

    /// @dev Thrown when a request is not sent by the authorized admin
    error Unauthorized();

    /// @dev Thrown when an address does not have sufficient permissions, as dictated by the Allowlist
    error InsufficientPermissions();

    /// @dev Thrown when the current timestamp has surpassed the expiration time for a signature
    error SignatureExpired();

    /// @dev Thrown if the signature has an S value that is in the upper half order.
    error InvalidSignatureS();

    /// @dev Thrown if the signature is invalid or its signer does not match the expected singer
    error BadSignatory();

    /// @dev Thrown if accounting pause is already on
    error AccountingIsPaused();

    /// @dev Thrown if accounting pause is already off
    error AccountingIsNotPaused();

    /// @dev Thrown if array length arguments aren't equal
    error InvalidArgumentLengths();

    /// @dev Thrown if `to` does not share the same `entityId` as `msg.sender` during subscribe
    error MismatchEntityIds();

    /**
     * @notice Returns the domain separator used in the encoding of the
     * signature for permit
     * @return bytes32 The domain separator
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice The next expected nonce for an address, for validating authorizations via signature
    function nonces(address toFind) external view returns (uint256);

    /**
     * @notice Invokes the {Pausable-_pause} internal function
     * @dev Can only be called by the admin
     */
    function pause() external;

    /**
     * @notice Invokes the {Pausable-_unpause} internal function
     * @dev Can only be called by the admin
     */
    function unpause() external;

    /**
     * @return bool True if the accounting is currently paused, false otherwise
     */
    function accountingPaused() external view returns (bool);

    /**
     * @notice Pauses mint and burn
     * @dev Can only be called by the admin
     */
    function accountingPause() external;

    /**
     * @notice Unpauses mint and burn
     * @dev Can only be called by the admin
     */
    function accountingUnpause() external;

    /**
     * @notice Sets approval amount for a spender via signature from signatory
     * @param owner The address that signed the signature
     * @param spender The address to authorize (or rescind authorization from)
     * @param value Amount that `owner` is approving for `spender`
     * @param deadline Expiration time for the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    /**
     * @notice Mint new tokens to a recipient
     * @dev Only callable by the admin
     * @param dst Recipient of the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address dst, uint256 amount) external;

    /**
     * @notice Mint new tokens to many recipients
     * @dev Only callable by the admin
     * @param dsts Recipients of the minted tokens
     * @param amounts Amounts of tokens to mint
     */
    function bulkMint(address[] calldata dsts, uint256[] calldata amounts) external;

    /**
     * @notice Initialize the contract
     * @param _name The token name
     * @param _symbol The token symbol
     */
    function initialize(string calldata _name, string calldata _symbol) external;

    // V2 remaining

    /// @dev Thrown if an attempt to call `renounceOwnership` is made
    error RenounceOwnershipDisabled();

    /**
     * @notice Initialize version 2 of the contract.
     * @notice If creating an entirely new contract, the original `initialize` method still needs to be called.
     */
    function initializeV2() external;

    // V3 remaining

    /// @dev Struct for storing supported stablecoin configuration
    struct StablecoinConfig {
        address sweepDestination;
        uint96 fee;
    }

    /// @dev Emitted when the max oracle delay is set
    event SetMaximumOracleDelay(uint256 oldMaxOracleDelay, uint256 newMaxOracleDelay);

    /// @dev Event emitted when the address for the pricing oracle changes
    event SetOracle(address oldOracle, address newOracle);

    /// @dev Event emitted when the configuration for a supported stablecoin changes
    event SetStablecoinConfig(
        address indexed stablecoin,
        address oldSweepDestination,
        address newSweepDestination,
        uint96 oldFee,
        uint96 newFee
    );

    /// @dev Event emitted when stablecoins are used to Subscribe to a Superstate fund
    /// @param subscriber The address of the subscriber
    /// @param to The address of the recipient
    /// @param stablecoin The address of the stablecoin used to subscribe
    /// @param stablecoinInAmountAfterFee The amount of stablecoin used to subscribe, after fees are deducted
    /// @param stablecoinInAmountBeforeFee The amount of stablecoin used to subscribe, before fees are deducted
    /// @param superstateTokenOutAmount The amount of Superstate tokens received
    event SubscribeV2(
        address indexed subscriber,
        address indexed to,
        address stablecoin,
        uint256 stablecoinInAmountAfterFee,
        uint256 stablecoinInAmountBeforeFee,
        uint256 superstateTokenOutAmount
    );

    /// @dev Thrown when an argument is invalid
    error BadArgs();

    /// @dev Thrown when Chainlink Oracle data is bad
    error BadChainlinkData();

    /// @dev Thrown when owner tries to set the fee for a stablecoin too high
    error FeeTooHigh();

    /// @dev Thrown when the superstateUstbOracle is the 0 address
    error OnchainSubscriptionsDisabled();

    /// @dev Thrown when trying to calculate amount of Superstate Tokens you'd get for an unsupported stablecoin
    error StablecoinNotSupported();

    /// @dev Thrown when the msg.sender would receive 0 Superstate tokens out for their call to subscribe, or trying to bridge 0 tokens
    error ZeroSuperstateTokensOut();

    function allowlistV2() external view returns (IAllowlistV2);

    /**
     * @notice Initialize version 3 of the contract
     * @notice If creating an entirely new contract, the original `initialize` method still needs to be called.
     */
    function initializeV3(AllowlistV2 _allowlist) external;

    // V4

    /// @dev Event emitted when the admin burns tokens
    event AdminBurn(address indexed burner, address indexed src, uint256 amount);

    /// @dev Event emitted when the user wants to bridge their tokens to another chain or book entry
    event Bridge(
        address caller,
        address indexed src,
        uint256 amount,
        address indexed ethDestinationAddress,
        string otherDestinationAddress,
        uint256 chainId
    );

    /// @dev Event emitted when the users wants to redeem their shares with an offchain payout
    event OffchainRedeem(address indexed burner, address indexed src, uint256 amount);

    /// @dev Event emitted when the owner changes the redemption contract address
    event SetRedemptionContract(address oldRedemptionContract, address newRedemptionContract);

    /// @notice Emitted when a chain ID's support status is updated
    event SetChainIdSupport(uint256 indexed chainId, bool oldSupported, bool newSupported);

    /// @dev Thrown when bridge function arguments have two destinations
    error TwoDestinationsInvalid();

    /// @dev Thrown when bridge function chainId is set to 0 but onchain destination arguments are provided
    error OnchainDestinationSetForBridgeToBookEntry();

    /// @dev Thrown when bridge function chainId is not supported
    error BridgeChainIdDestinationNotSupported();

    /**
     * @notice Check permissions of an address for transferring
     * @param addr Address to check permissions for
     * @return bool True if the address has sufficient permission, false otherwise
     */
    function isAllowed(address addr) external view returns (bool);

    /**
     * @notice Burn tokens from a given source address
     * @dev Only callable by the admin
     * @param src Source address from which tokens will be burned
     * @param amount Amount of tokens to burn
     */
    function adminBurn(address src, uint256 amount) external;

    /**
     * @notice Burn tokens from the caller's address for offchain redemption
     * @param amount Amount of tokens to burn
     */
    function offchainRedeem(uint256 amount) external;

    /**
     * @notice Burn tokens from the caller's address to bridge to another chain
     * @dev If destination address on chainId isn't on allowlist, or chainID isn't supported, tokens wind up in book entry
     * @param amount Amount of tokens to burn
     * @param ethDestinationAddress ETH address to send to on another chain
     * @param otherDestinationAddress Non-EVM addresses to send to on another chain
     * @param chainId Numerical identifier of destination chain to send tokens to
     */
    function bridge(
        uint256 amount,
        address ethDestinationAddress,
        string calldata otherDestinationAddress,
        uint256 chainId
    ) external;

    /**
     * @notice Burn tokens from the caller's address to bridge to Superstate book entry
     * @param amount Amount of tokens to burn
     */
    function bridgeToBookEntry(uint256 amount) external;

    /**
     * @notice Sets redemption contract address
     * @dev Used for convenience for devs
     * @dev Set to address(0) if no such contract exists for the token
     * @param _newRedemptionContract New contract address
     */
    function setRedemptionContract(address _newRedemptionContract) external;

    /**
     * @notice Sets support status for a specific chain ID
     * @param _chainId The chain ID to update
     * @param _supported Whether the chain ID should be supported
     */
    function setChainIdSupport(uint256 _chainId, bool _supported) external;

     /**
      * @notice The ```subscribe`` function takes in stablecoins and mints SuperstateToken in the proper amount for the to address depending on the current Net Asset Value per Share.
      * @param to The address where USTB will be deposited at
      * @param inAmount The amount of the stablecoin in
      * @param stablecoin The address of the stablecoin to calculate with
      */
     function subscribe(address to, uint256 inAmount, address stablecoin) external;
 
     /**
      * @notice The ```subscribe``` function takes in stablecoins and mints SuperstateToken in the proper amount for the msg.sender depending on the current Net Asset Value per Share.
      * @param inAmount The amount of the stablecoin in
      * @param stablecoin The address of the stablecoin to calculate with
      */
     function subscribe(uint256 inAmount, address stablecoin) external;
 
     /**
      * @notice The ```setOracle``` function sets the address of the AggregatorV3Interface to be used to price the SuperstateToken
      * @dev Requires msg.sender to be the owner address
      * @param _newOracle The address of the oracle contract to update to
      */
     function setOracle(address _newOracle) external;
 
     /**
      * @notice The ```setMaximumOracleDelay``` function sets the max oracle delay to determine if Chainlink data is stale
      * @dev Requires msg.sender to be the owner address
      * @param _newMaxOracleDelay The new max oracle delay
      */
     function setMaximumOracleDelay(uint256 _newMaxOracleDelay) external;
 
     /**
      * @notice The ```setStablecoinConfig``` function sets the configuration fields for accepted stablecoins for onchain subscriptions
      * @dev Requires msg.sender to be the owner address
      * @param stablecoin The address of the stablecoin
      * @param newSweepDestination The new address to sweep stablecoin subscriptions to
      * @param newFee The new fee in basis points to charge for subscriptions in ```stablecoin```
      */
     function setStablecoinConfig(address stablecoin, address newSweepDestination, uint96 newFee) external;
 
     /**
      * @notice The ```getChainlinkPrice``` function returns the chainlink price and the timestamp of the last update
      * @return _isBadData True if the data is stale or negative
      * @return _updatedAt The timestamp of the last update
      * @return _price The price
      */
     function getChainlinkPrice() external view returns (bool _isBadData, uint256 _updatedAt, uint256 _price);
 
     /**
      * @notice Calculates the fee amount based on the input amount and subscription fee
      * @param amount The input amount to calculate fee for
      * @param subscriptionFee The fee rate to apply
      * @return The calculated fee amount
      */
     function calculateFee(uint256 amount, uint256 subscriptionFee) external pure returns (uint256);
 
     /**
      * @notice The ```calculateSuperstateTokenOut``` function calculates the total amount of Superstate tokens you'll receive for the inAmount of stablecoin. Treats all stablecoins as if they are always worth a dollar.
      * @param inAmount The amount of the stablecoin in
      * @param stablecoin The address of the stablecoin to calculate with
      * @return superstateTokenOutAmount The amount of Superstate tokens received for inAmount of stablecoin
      * @return stablecoinInAmountAfterFee The amount of stablecoin in after any fees
      * @return feeOnStablecoinInAmount The amount of the stablecoin taken in fees
      */
     function calculateSuperstateTokenOut(uint256 inAmount, address stablecoin)
         external
         view
         returns (uint256 superstateTokenOutAmount, uint256 stablecoinInAmountAfterFee, uint256 feeOnStablecoinInAmount);
 }

// src/v5_1/SuperstateTokenV5_1.sol

/**
 * @title SuperstateTokenV5
 * @notice A Pausable ERC20 token contract that interacts with the Allowlist contract to check if transfers are allowed
 * @author Superstate
 */
contract SuperstateTokenV5_1 is ISuperstateTokenV5_1, ERC20Upgradeable, PausableUpgradeable, Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;

    /**
     * @dev This empty reserved space is put in place to allow future versions to inherit from new contracts
     * without impacting the fields within `SuperstateTokenV5`.
     */
    uint256[500] private __inheritanceGap;

    /// @notice The major version of this contract
    string public constant VERSION = "5";

    /// @dev The EIP-712 typehash for authorization via permit
    bytes32 internal constant AUTHORIZATION_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @dev The EIP-712 typehash for the contract's domain
    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @notice Admin address with exclusive privileges for minting and burning
    /// @notice As of v2, this field is no longer used due to implementing Ownable2Step. The field is kept here to properly implement the transfer of ownership and will be removed in subsequent contract versions.
    address private immutable _deprecatedAdmin;

    /// @notice Address of the Allowlist contract which determines permissions for transfers
    /// @notice As of v3, this field is deprecated
    IAllowlist private immutable _deprecatedAllowlist;

    /// @notice The next expected nonce for an address, for validating authorizations via signature
    mapping(address => uint256) public nonces;

    /// @notice Amount of an address's token balance that is encumbered
    /// @notice As of v4, this field is deprecated
    mapping(address => uint256) private _deprecatedEncumberedBalanceOf;

    /// @notice Amount encumbered from owner to taker (owner => taker => balance)
    /// @notice As of v4, this field is deprecated
    mapping(address => mapping(address => uint256)) private _deprecatedEncumbrances;

    /// @notice If all minting and burning operations are paused
    bool public accountingPaused;

    /// @notice Number of decimals used for the user representation of the token
    uint8 private constant DECIMALS = 6;

    /// @notice Base 10000 for 0.01% precision
    uint256 public constant FEE_DENOMINATOR = 10_000;

    /// @notice Precision of SUPERSTATE_TOKEN
    uint256 public constant SUPERSTATE_TOKEN_PRECISION = 10 ** DECIMALS;

    /// @notice Lowest acceptable chainlink oracle price
    uint256 public immutable MINIMUM_ACCEPTABLE_PRICE;

    /// @notice Value, in seconds, that determines if chainlink data is too old
    uint256 public maximumOracleDelay;

    /// @notice The address of the oracle used to calculate the Net Asset Value per Share
    address public superstateOracle;

    /// @notice Mapping from a stablecoin's address to its configuration
    mapping(address stablecoin => StablecoinConfig) public supportedStablecoins;

    /// @notice Address of the Allowlist contract which determines permissions for transfers
    IAllowlistV2 public allowlistV2;

    /// @notice The address of the contract used to facilitate protocol redemptions, if such a contract exists.
    address public redemptionContract;

    /// @notice Supported chainIds for bridging
    mapping(uint256 chainId => bool supported) public supportedChainIds;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new fields without impacting
     * any contracts that inherit `SuperstateToken`
     */
    uint256[95] private __additionalFieldsGap;

    /**
     * @notice Construct a new ERC20 token instance with the given admin and Allowlist
     * @dev Disables initialization on the implementation contract
     */
    constructor() {
        // SUPERSTATE_TOKEN starts at $10.000000, Chainlink oracle with 6 decimals would represent as 10_000_000.
        // This math will give us 7_000_000 or $7.000000.
        MINIMUM_ACCEPTABLE_PRICE = 7 * (10 ** uint256(DECIMALS));

        _disableInitializers();
    }

    /**
     * @notice Initialize the contract
     * @param _name The token name
     * @param _symbol The token symbol
     */
    function initialize(string calldata _name, string calldata _symbol) public initializer {
        __ERC20_init(_name, _symbol);
        __Pausable_init();
    }

    /**
     * @notice Initialize version 2 of the contract.
     * @notice If creating an entirely new contract, the original `initialize` method still needs to be called.
     */
    function initializeV2() public reinitializer(2) {
        // Last usage of `_deprecatedAdmin` variable here.
        // After this call, owner() is the source of truth for authorization.
        if (msg.sender != _deprecatedAdmin) revert Unauthorized();
        __Ownable2Step_init();
    }

    /**
     * @notice Initialize version 3 of the contract
     * @notice If creating an entirely new contract, the original `initialize` method still needs to be called.
     */
    function initializeV3(AllowlistV2 _allowlist) public reinitializer(3) {
        _checkOwner();

        allowlistV2 = _allowlist;
    }

    // No need for initializeV4

    function _requireNotAccountingPaused() internal view {
        if (accountingPaused) revert AccountingIsPaused();
    }

    function _requireOnchainSubscriptionsEnabled() internal view {
        if (superstateOracle == address(0) || maximumOracleDelay == 0) revert OnchainSubscriptionsDisabled();
    }

    /**
     * @notice Invokes the {Pausable-_pause} internal function
     * @dev Can only be called by the admin
     */
    function pause() external {
        _checkOwner();
        _requireNotPaused();

        _pause();
    }

    /**
     * @notice Invokes the {Pausable-_unpause} internal function
     * @dev Can only be called by the admin
     */
    function unpause() external {
        _checkOwner();
        _requirePaused();

        _unpause();
    }

    /**
     * @notice Pauses mint and burn
     * @dev Can only be called by the admin
     */
    function accountingPause() external {
        _checkOwner();
        _requireNotAccountingPaused();

        accountingPaused = true;
        emit AccountingPaused(msg.sender);
    }

    /**
     * @notice Unpauses mint and burn
     * @dev Can only be called by the admin
     */
    function accountingUnpause() external {
        _checkOwner();
        if (!accountingPaused) revert AccountingIsNotPaused();

        accountingPaused = false;
        emit AccountingUnpaused(msg.sender);
    }

    function renounceOwnership() public virtual override onlyOwner {
        revert RenounceOwnershipDisabled();
    }

    /**
     * @notice Number of decimals used for the user representation of the token
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @notice Moves `amount` tokens from the caller's account to `dst`
     * @dev Includes extra functionality to burn tokens if `dst` is the token address, namely its TransparentUpgradeableProxy
     * @param dst Address to transfer tokens to
     * @param amount Amount of token to transfer
     * @return bool Whether the operation was successful
     */
    function transfer(address dst, uint256 amount)
        public
        override(IERC20Upgradeable, ERC20Upgradeable)
        returns (bool)
    {
        if (!isAllowed(msg.sender)) revert InsufficientPermissions();

        if (dst == address(this)) {
            _requireNotAccountingPaused();
            _burn(msg.sender, amount);
            emit OffchainRedeem({burner: msg.sender, src: msg.sender, amount: amount});
        } else {
            _requireNotPaused();
            if (!isAllowed(dst)) revert InsufficientPermissions();
            _transfer(msg.sender, dst, amount);
        }

        return true;
    }

    /**
     * @notice Moves `amount` tokens from `src` to `dst` using the
     * allowance of the caller
     * @dev Spends the caller's encumbrance from `src` first, then their
     * allowance from `src` (if necessary)
     * @param src Address to transfer tokens from
     * @param dst Address to transfer tokens to
     * @param amount Amount of token to transfer
     * @return bool Whether the operation was successful
     */
    function transferFrom(address src, address dst, uint256 amount)
        public
        override(IERC20Upgradeable, ERC20Upgradeable)
        returns (bool)
    {
        if (!isAllowed(src)) revert InsufficientPermissions();

        if (dst == address(this)) {
            _requireNotAccountingPaused();
            _spendAllowance({owner: src, spender: msg.sender, amount: amount});
            _burn(src, amount);
            // burner receives redemption payout from src
            emit OffchainRedeem({burner: msg.sender, src: src, amount: amount});
        } else {
            _requireNotPaused();
            if (!isAllowed(dst)) revert InsufficientPermissions();
            ERC20Upgradeable.transferFrom({from: src, to: dst, amount: amount});
        }

        return true;
    }

    /**
     * @notice Sets approval amount for a spender via signature from signatory
     * @param owner The address that signed the signature
     * @param spender The address to authorize (or rescind authorization from)
     * @param value Amount that `owner` is approving for `spender`
     * @param deadline Expiration time for the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (block.timestamp > deadline) revert SignatureExpired();

        uint256 nonce = nonces[owner];
        bytes32 structHash = keccak256(abi.encode(AUTHORIZATION_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));
        if (isValidSignature(owner, digest, v, r, s)) {
            nonces[owner]++;
            _approve(owner, spender, value);
        }
    }

    /**
     * @notice Check permissions of an address for transferring
     * @param addr Address to check permissions for
     * @return bool True if the address has sufficient permission, false otherwise
     */
    function isAllowed(address addr) public view virtual returns (bool) {
        return allowlistV2.isAddressAllowedForFund(addr, symbol());
    }

    function _mintLogic(address dst, uint256 amount) internal {
        if (!isAllowed(dst)) revert InsufficientPermissions();

        _mint(dst, amount);
        emit Mint(msg.sender, dst, amount);
    }

    /**
     * @notice Mint new tokens to a recipient
     * @dev Only callable by the admin
     * @param dst Recipient of the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address dst, uint256 amount) external {
        _checkOwner();
        _requireNotAccountingPaused();

        _mintLogic({dst: dst, amount: amount});
    }

    /**
     * @notice Mint new tokens to many recipients
     * @dev Only callable by the admin
     * @param dsts Recipients of the minted tokens
     * @param amounts Amounts of tokens to mint
     */
    function bulkMint(address[] calldata dsts, uint256[] calldata amounts) external {
        _checkOwner();
        _requireNotAccountingPaused();
        if (dsts.length != amounts.length || dsts.length == 0) revert InvalidArgumentLengths();

        uint256 length = dsts.length;

        for (uint256 i = 0; i < length; ++i) {
            _mintLogic({dst: dsts[i], amount: amounts[i]});
        }
    }

    /**
     * @notice Burn tokens from a given source address
     * @dev Only callable by the admin
     * @param src Source address from which tokens will be burned
     * @param amount Amount of tokens to burn
     */
    function adminBurn(address src, uint256 amount) external {
        _checkOwner();
        _requireNotAccountingPaused();

        _burn(src, amount);
        emit AdminBurn({burner: msg.sender, src: src, amount: amount});
    }

    /**
     * @notice Burn tokens from the caller's address for offchain redemption
     * @param amount Amount of tokens to burn
     */
    function offchainRedeem(uint256 amount) external {
        _requireNotAccountingPaused();
        if (!isAllowed(msg.sender)) revert InsufficientPermissions();

        _burn(msg.sender, amount);
        emit OffchainRedeem({burner: msg.sender, src: msg.sender, amount: amount});
    }

    /**
     * @notice Burn tokens from the caller's address to bridge to another chain
     * @dev If destination address on chainId isn't on allowlist, or chainID isn't supported, tokens burn to book entry.
     * @dev chainId as 0 indicates wanting to burn tokens to book entry, for use through the Superstate UI.
     * @param amount Amount of tokens to burn
     * @param ethDestinationAddress ETH address to send to on another chain
     * @param otherDestinationAddress Non-EVM addresses to send to on another chain
     * @param chainId Numerical identifier of destination chain to send tokens to
     */
    function bridge(
        uint256 amount,
        address ethDestinationAddress,
        string memory otherDestinationAddress,
        uint256 chainId
    ) public {
        _requireNotAccountingPaused();

        if (!isAllowed(msg.sender)) revert InsufficientPermissions();

        if (amount == 0) revert ZeroSuperstateTokensOut();

        if (ethDestinationAddress != address(0) && bytes(otherDestinationAddress).length != 0) {
            revert TwoDestinationsInvalid();
        }

        if (chainId == 0 && (ethDestinationAddress != address(0) || bytes(otherDestinationAddress).length != 0)) {
            revert OnchainDestinationSetForBridgeToBookEntry();
        }

        if (!supportedChainIds[chainId]) revert BridgeChainIdDestinationNotSupported();

        _burn(msg.sender, amount);
        emit Bridge({
            caller: msg.sender,
            src: msg.sender,
            amount: amount,
            ethDestinationAddress: ethDestinationAddress,
            otherDestinationAddress: otherDestinationAddress,
            chainId: chainId
        });
    }

    /**
     * @notice Burn tokens from the caller's address to bridge to Superstate book entry
     * @param amount Amount of tokens to burn
     */
    function bridgeToBookEntry(uint256 amount) external {
        bridge({
            amount: amount,
            ethDestinationAddress: address(0),
            otherDestinationAddress: string(new bytes(0)),
            chainId: 0
        });
    }

    /**
     * @notice Internal function to set chain ID support status
     * @param _chainId The chain ID to update
     * @param _supported New support status for the chain
     */
    function _setChainIdSupport(uint256 _chainId, bool _supported) internal {
        if (supportedChainIds[_chainId] == _supported) revert BadArgs();

        // Can't bridge to the chain you're already on
        if (_chainId == block.chainid) revert BridgeChainIdDestinationNotSupported();

        emit SetChainIdSupport({chainId: _chainId, oldSupported: supportedChainIds[_chainId], newSupported: _supported});

        supportedChainIds[_chainId] = _supported;
    }

    /**
     * @notice Sets support status for a specific chain ID
     * @param _chainId The chain ID to update
     * @param _supported Whether the chain ID should be supported
     */
    function setChainIdSupport(uint256 _chainId, bool _supported) external {
        _checkOwner();
        _setChainIdSupport({_chainId: _chainId, _supported: _supported});
    }

    function _setRedemptionContract(address _newRedemptionContract) internal {
        if (redemptionContract == _newRedemptionContract) revert BadArgs();
        emit SetRedemptionContract({
            oldRedemptionContract: redemptionContract,
            newRedemptionContract: _newRedemptionContract
        });
        redemptionContract = _newRedemptionContract;
    }

    /**
     * @notice Sets redemption contract address
     * @dev Used for convenience for devs
     * @dev Set to address(0) if no such contract exists for the token
     * @param _newRedemptionContract New contract address
     */
    function setRedemptionContract(address _newRedemptionContract) external {
        _checkOwner();
        _setRedemptionContract(_newRedemptionContract);
    }

    /**
     * @notice The ```setOracle``` function sets the address of the AggregatorV3Interface to be used to price the SuperstateToken
     * @dev Requires msg.sender to be the owner address
     * @param _newOracle The address of the oracle contract to update to
     */
    function setOracle(address _newOracle) external {
        _checkOwner();

        if (_newOracle == superstateOracle) revert BadArgs();
        emit SetOracle({oldOracle: superstateOracle, newOracle: _newOracle});
        superstateOracle = _newOracle;
    }

    // Oracle integration inspired by: https://github.com/FraxFinance/frax-oracles/blob/bd56532a3c33da95faed904a5810313deab5f13c/src/abstracts/ChainlinkOracleWithMaxDelay.sol
    function _setMaximumOracleDelay(uint256 _newMaxOracleDelay) internal {
        if (maximumOracleDelay == _newMaxOracleDelay) revert BadArgs();
        emit SetMaximumOracleDelay({oldMaxOracleDelay: maximumOracleDelay, newMaxOracleDelay: _newMaxOracleDelay});
        maximumOracleDelay = _newMaxOracleDelay;
    }
    /**
     * @notice The ```setMaximumOracleDelay``` function sets the max oracle delay to determine if Chainlink data is stale
     * @dev Requires msg.sender to be the owner address
     * @param _newMaxOracleDelay The new max oracle delay
     */

    function setMaximumOracleDelay(uint256 _newMaxOracleDelay) external {
        _checkOwner();
        _setMaximumOracleDelay(_newMaxOracleDelay);
    }

    /**
     * @notice The ```setStablecoinConfig``` function sets the configuration fields for accepted stablecoins for onchain subscriptions
     * @dev Requires msg.sender to be the owner address
     * @param stablecoin The address of the stablecoin
     * @param newSweepDestination The new address to sweep stablecoin subscriptions to
     * @param newFee The new fee in basis points to charge for subscriptions in ```stablecoin```
     */
    function setStablecoinConfig(address stablecoin, address newSweepDestination, uint96 newFee) external {
        if (newFee > 10) revert FeeTooHigh(); // Max 0.1% fee
        _checkOwner();

        StablecoinConfig memory oldConfig = supportedStablecoins[stablecoin];
        if (newSweepDestination == oldConfig.sweepDestination && newFee == oldConfig.fee) revert BadArgs();

        supportedStablecoins[stablecoin] = StablecoinConfig({sweepDestination: newSweepDestination, fee: newFee});

        emit SetStablecoinConfig({
            stablecoin: stablecoin,
            oldSweepDestination: oldConfig.sweepDestination,
            newSweepDestination: newSweepDestination,
            oldFee: oldConfig.fee,
            newFee: newFee
        });
    }

    function _getChainlinkPrice() internal view returns (bool _isBadData, uint256 _updatedAt, uint256 _price) {
        _requireOnchainSubscriptionsEnabled();

        (, int256 _answer,, uint256 _chainlinkUpdatedAt,) = AggregatorV3Interface(superstateOracle).latestRoundData();

        // If data is stale or below first price, set bad data to true and return
        // 1_000_000_000 is $10.000000 in the oracle format, that was our starting NAV per Share price for SUPERSTATE_TOKEN
        // The oracle should never return a price much lower than this
        _isBadData =
            _answer < int256(MINIMUM_ACCEPTABLE_PRICE) || ((block.timestamp - _chainlinkUpdatedAt) > maximumOracleDelay);
        _updatedAt = _chainlinkUpdatedAt;
        _price = uint256(_answer);
    }

    /**
     * @notice The ```getChainlinkPrice``` function returns the chainlink price and the timestamp of the last update
     * @return _isBadData True if the data is stale or negative
     * @return _updatedAt The timestamp of the last update
     * @return _price The price
     */
    function getChainlinkPrice() external view returns (bool _isBadData, uint256 _updatedAt, uint256 _price) {
        return _getChainlinkPrice();
    }

    function calculateFee(uint256 amount, uint256 subscriptionFee) public pure returns (uint256) {
        return (amount * subscriptionFee) / FEE_DENOMINATOR;
    }

    /**
     * @notice The ```calculateSuperstateTokenOut``` function calculates the total amount of Superstate tokens you'll receive for the inAmount of stablecoin. Treats all stablecoins as if they are always worth a dollar.
     * @param inAmount The amount of the stablecoin in
     * @param stablecoin The address of the stablecoin to calculate with
     * @return superstateTokenOutAmount The amount of Superstate tokens received for inAmount of stablecoin
     * @return stablecoinInAmountAfterFee The amount of the stablecoin in after any fees
     * @return feeOnStablecoinInAmount The amount of the stablecoin taken in fees
     */
    function calculateSuperstateTokenOut(uint256 inAmount, address stablecoin)
        public
        view
        returns (uint256 superstateTokenOutAmount, uint256 stablecoinInAmountAfterFee, uint256 feeOnStablecoinInAmount)
    {
        StablecoinConfig memory config = supportedStablecoins[stablecoin];
        if (config.sweepDestination == address(0)) revert StablecoinNotSupported();

        feeOnStablecoinInAmount = calculateFee({amount: inAmount, subscriptionFee: config.fee});
        stablecoinInAmountAfterFee = inAmount - feeOnStablecoinInAmount;

        (bool isBadData,, uint256 usdPerSuperstateTokenChainlinkRaw) = _getChainlinkPrice();
        if (isBadData) revert BadChainlinkData();

        uint256 stablecoinDecimals = IERC20Metadata(stablecoin).decimals();
        uint256 stablecoinPrecision = 10 ** stablecoinDecimals;
        uint256 chainlinkFeedPrecision = 10 ** AggregatorV3Interface(superstateOracle).decimals();

        // converts from a USD amount to a SUPERSTATE_TOKEN amount
        superstateTokenOutAmount = (stablecoinInAmountAfterFee * chainlinkFeedPrecision * SUPERSTATE_TOKEN_PRECISION)
            / (usdPerSuperstateTokenChainlinkRaw * stablecoinPrecision);
    }

    function _subscribe(address to, uint256 inAmount, address stablecoin) internal {
        if (
            to != msg.sender
                && IAllowlistV2.EntityId.unwrap(allowlistV2.addressEntityIds(msg.sender))
                    != IAllowlistV2.EntityId.unwrap(allowlistV2.addressEntityIds(to))
        ) revert MismatchEntityIds();

        if (inAmount == 0) revert BadArgs();
        _requireNotPaused();
        _requireNotAccountingPaused();

        (uint256 superstateTokenOutAmount, uint256 stablecoinInAmountAfterFee,) =
            calculateSuperstateTokenOut({inAmount: inAmount, stablecoin: stablecoin});

        if (superstateTokenOutAmount == 0) revert ZeroSuperstateTokensOut();

        IERC20(stablecoin).safeTransferFrom({
            from: msg.sender,
            to: supportedStablecoins[stablecoin].sweepDestination,
            value: inAmount
        });
        _mintLogic({dst: to, amount: superstateTokenOutAmount});

        emit SubscribeV2({
            subscriber: msg.sender,
            to: to,
            stablecoin: stablecoin,
            stablecoinInAmountAfterFee: stablecoinInAmountAfterFee,
            stablecoinInAmountBeforeFee: inAmount,
            superstateTokenOutAmount: superstateTokenOutAmount
        });
    }

    /**
     * @notice The ```subscribe``` function takes in stablecoins and mints SuperstateToken in the proper amount for the to address depending on the current Net Asset Value per Share.
     * @param to The address where USTB will be deposited at
     * @param inAmount The amount of the stablecoin in
     * @param stablecoin The address of the stablecoin to calculate with
     */
    function subscribe(address to, uint256 inAmount, address stablecoin) external {
        _subscribe(to, inAmount, stablecoin);
    }

    /**
     * @notice The ```subscribe``` function takes in stablecoins and mints SuperstateToken in the proper amount for the msg.sender depending on the current Net Asset Value per Share.
     * @param inAmount The amount of the stablecoin in
     * @param stablecoin The address of the stablecoin to calculate with
     */
    function subscribe(uint256 inAmount, address stablecoin) external {
        _subscribe(msg.sender, inAmount, stablecoin);
    }

    /**
     * @notice Returns the domain separator used in the encoding of the
     * signature for permit
     * @return bytes32 The domain separator
     */
    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH, keccak256(bytes(name())), keccak256(bytes(VERSION)), block.chainid, address(this)
            )
        );
    }

    /**
     * @notice Checks if a signature is valid
     * @param signer The address that signed the signature
     * @param digest The hashed message that is signed
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     * @return bool Whether the signature is valid
     */
    function isValidSignature(address signer, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address recoveredSigner, ECDSA.RecoverError recoverError,) = ECDSA.tryRecover(digest, v, r, s);

        if (recoverError == ECDSA.RecoverError.InvalidSignatureS) revert InvalidSignatureS();
        if (recoverError == ECDSA.RecoverError.InvalidSignature) revert BadSignatory();
        if (recoveredSigner != signer) revert BadSignatory();

        return true;
    }
}
