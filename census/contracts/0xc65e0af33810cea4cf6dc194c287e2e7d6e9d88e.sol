// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.3
// Creator: Chiru Labs

pragma solidity ^0.8.4;

/**
 * @dev Interface of ERC721A.
 */
interface IERC721AUpgradeable {
    /**
     * The caller must own the token or be an approved operator.
     */
    error ApprovalCallerNotOwnerNorApproved();

    /**
     * The token does not exist.
     */
    error ApprovalQueryForNonexistentToken();

    /**
     * Cannot query the balance for the zero address.
     */
    error BalanceQueryForZeroAddress();

    /**
     * Cannot mint to the zero address.
     */
    error MintToZeroAddress();

    /**
     * The quantity of tokens minted must be more than zero.
     */
    error MintZeroQuantity();

    /**
     * The token does not exist.
     */
    error OwnerQueryForNonexistentToken();

    /**
     * The caller must own the token or be an approved operator.
     */
    error TransferCallerNotOwnerNorApproved();

    /**
     * The token must be owned by `from`.
     */
    error TransferFromIncorrectOwner();

    /**
     * Cannot safely transfer to a contract that does not implement the
     * ERC721Receiver interface.
     */
    error TransferToNonERC721ReceiverImplementer();

    /**
     * Cannot transfer to the zero address.
     */
    error TransferToZeroAddress();

    /**
     * The token does not exist.
     */
    error URIQueryForNonexistentToken();

    /**
     * The `quantity` minted with ERC2309 exceeds the safety limit.
     */
    error MintERC2309QuantityExceedsLimit();

    /**
     * The `extraData` cannot be set on an unintialized ownership slot.
     */
    error OwnershipNotInitializedForExtraData();

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Stores the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
        // Whether the token has been burned.
        bool burned;
        // Arbitrary data similar to `startTimestamp` that can be set via {_extraData}.
        uint24 extraData;
    }

    // =============================================================
    //                         TOKEN COUNTERS
    // =============================================================

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() external view returns (uint256);

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // =============================================================
    //                            IERC721
    // =============================================================

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables
     * (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in `owner`'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`,
     * checking first that contract recipients are aware of the ERC721 protocol
     * to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move
     * this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external payable;

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom}
     * whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external payable;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    // =============================================================
    //                           IERC2309
    // =============================================================

    /**
     * @dev Emitted when tokens in `fromTokenId` to `toTokenId`
     * (inclusive) is transferred from `from` to `to`, as defined in the
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309) standard.
     *
     * See {_mintERC2309} for more details.
     */
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed from, address indexed to);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

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
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
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
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

/**
 * @title Interface for IELVault
 * @notice Vault will manage methods for rewards, commissions, tax
 */
interface IELVault {
    /**
     * @notice transfer ETH
     * @param _amount transfer amount
     * @param _to transfer to address
     */
    function transfer(uint256 _amount, address _to) external;

    /**
     * @notice transfer ETH
     * @param _amount transfer amount
     */
    function reinvestment(uint256 _amount) external;
}

pragma solidity 0.8.8;

/**
 * @title Interface for ELVaultFactory
 * @notice Vault factory
 */

interface IELVaultFactory {
    /**
     * @notice create vault contract proxy
     * @param _operatorId operator id
     */
    function create(uint256 _operatorId) external returns (address);

    event ELVaultProxyDeployed(address _proxyAddress);
    event NodeOperatorRegistrySet(address _oldNodeOperatorRegistryAddress, address _nodeOperatorRegistryAddress);
    event DaoAddressChanged(address _oldDao, address _dao);
}

pragma solidity 0.8.8;

/**
 * @title Interface for LargeStaking
 * @notice Vault factory
 */

import {CLStakingExitInfo, CLStakingSlashInfo} from "src/library/ConsensusStruct.sol";

interface ILargeStaking {
    event SharedRewardPoolStart(uint256 _operatorId, address _elRewardPoolAddr);
    event LargeStake(
        uint256 _operatorId,
        uint256 _curStakingId,
        uint256 _amount,
        address _owner,
        address _elRewardAddr,
        address _withdrawCredentials,
        bool _isELRewardSharing
    );
    event MigretaStake(
        uint256 _operatorId,
        uint256 _curStakingId,
        uint256 _amount,
        address _owner,
        address _elRewardAddr,
        address _withdrawCredentials,
        bool _isELRewardSharing
    );
    event AppendStake(uint256 _stakingId, uint256 _amount);
    event AppendMigretaStake(uint256 _stakingId, uint256 _stakeAmounts);
    event ValidatorRegistered(uint256 _operatorId, uint256 _stakeingId, bytes _pubKey);
    event FastUnstake(uint256 _stakingId, uint256 _unstakeAmount);
    event LargeUnstake(uint256 _stakingId, uint256 _amount);
    event ELShareingRewardSettle(uint256 _operatorId, uint256 _daoReward, uint256 _operatorReward, uint256 _poolReward);
    event ElPrivateRewardSettle(
        uint256 _stakingId, uint256 _operatorId, uint256 _daoReward, uint256 _operatorReward, uint256 _poolReward
    );
    event UserRewardClaimed(uint256 _stakingId, address _beneficiary, uint256 _rewards);
    event OperatorRewardClaimed(uint256 _operatorId, address _rewardAddresses, uint256 _rewardAmounts);
    event OperatorPrivateRewardClaimed(uint256 _stakingId, uint256 _operatorId, uint256 _operatorRewards);
    event OperatorSharedRewardClaimed(uint256 _operatorId, uint256 _operatorRewards);
    event DaoPrivateRewardClaimed(uint256 _stakingId, address _daoVaultAddress, uint256 _daoRewards);
    event DaoSharedRewardClaimed(uint256 _operatorId, address daoVaultAddress, uint256 _daoRewards);
    event LargeStakingSlash(uint256 _stakingIds, uint256 _operatorIds, bytes _pubkey, uint256 _amounts);
    event ValidatorExitReport(uint256 _operatorId, bytes[] _pubkey);
    event DaoAddressChanged(address _oldDao, address _dao);
    event DaoVaultAddressChanged(address _oldDaoVaultAddress, address _daoVaultAddress);
    event DaoELCommissionRateChanged(uint256 _oldDaoElCommissionRate, uint256 _daoElCommissionRate);
    event NodeOperatorsRegistryChanged(address _oldNodeOperatorRegistryContract, address _nodeOperatorRegistryAddress);
    event ConsensusOracleChanged(address _oldLargeOracleContractAddr, address _largeOracleContractAddr);
    event ELRewardFactoryChanged(address _oldElRewardFactory, address _elRewardFactory);
    event OperatorSlashChanged(address _oldOperatorSlashContract, address _operatorSlashContract);
    event MinStakeAmountChanged(uint256 _oldMinStakeAmount, uint256 _minStakeAmount);
    event MaxSlashAmountChanged(uint256 _oldMaxSlashAmount, uint256 _maxSlashAmount);
    event ElRewardAddressChanged(address _oldElRewardAddr, address _elRewardAddr);

    function getOperatorValidatorCounts(uint256 _operatorId) external view returns (uint256);

    function reportCLStakingData(
        CLStakingExitInfo[] memory _clStakingExitInfo,
        CLStakingSlashInfo[] memory _clStakingSlashInfo
    ) external;
}

pragma solidity 0.8.8;

/**
 * @title Interface fro NodeDao LiquidStaking Contract
 *
 * NodeDao is a DAO that provides decentralized solutions for Ethereum liquidity,
 * jointly initiated by ChainUp Cloud, XHash, AntAlpha, ImToken, and Bitrise.
 *
 * The NodeDAO protocol is a smart contract for next-generation liquid staking derivatives,
 * which includes all the concepts of traditional liquid staking, re-staking, distributed validators, and validator NFTs in a single protocol.
 *
 * Our vision is to use our innovative liquidity solution to provide more options for the Ethereum liquidity market,
 * thereby making Ethereum staking more decentralized.
 */
interface ILiquidStaking {
    /**
     * @notice Receive Rewards
     * @param _rewards rewards amount
     */
    function receiveRewards(uint256 _rewards) external payable;

    /**
     * @notice Update the status of the corresponding nft according to the report result of the oracle machine
     * @param _tokenIds token id
     * @param _exitBlockNumbers exit block number
     */
    function nftExitHandle(uint256[] memory _tokenIds, uint256[] memory _exitBlockNumbers) external;

    /**
     * @notice According to the settlement results of the vaultManager, the income of the re-investment execution layer
     * @param _operatorIds operator id
     * @param _amounts reinvest amounts
     */
    function reinvestElRewards(uint256[] memory _operatorIds, uint256[] memory _amounts) external;

    /**
     * @notice According to the reported results of the oracle machine, the income of the consensus layer is re-invested
     * @param _operatorIds operator id
     * @param _amounts reinvest amounts
     * @param _totalAmount totalAmount
     */
    function reinvestClRewards(uint256[] memory _operatorIds, uint256[] memory _amounts, uint256 _totalAmount)
        external;

    /**
     * @notice nETH to ETH exchange rate
     * @param _nethAmountIn nETH amount
     */
    function getEthOut(uint256 _nethAmountIn) external view returns (uint256);

    /**
     * @notice ETH to nETH exchange rate
     * @param _ethAmountIn ETH amount
     */
    function getNethOut(uint256 _ethAmountIn) external view returns (uint256);

    /**
     * @notice When withdrawing a large amount, update the user's unstake quota
     * @param _operatorId operator id
     * @param _from user address
     * @param _amount unstakeETH amount
     */
    function largeWithdrawalUnstake(uint256 _operatorId, address _from, uint256 _amount) external;

    /**
     * @notice large withdrawals, when users claim eth, will trigger the burning of locked Neth
     * @param _totalRequestNethAmount totalRequestNethAmount will burn
     * @param _to burn neth address
     */
    function LargeWithdrawalRequestBurnNeth(uint256 _totalRequestNethAmount, address _to) external;

    /**
     * @notice When unstakeNFT, if the funds pledged by the user have not been deposited, the user is allowed to withdraw directly
     * @param _operatorId operator id
     * @param _tokenId tokenId
     * @param _to receiving address
     */
    function fastUnstakeNFT(uint256 _operatorId, uint256 _tokenId, address _to) external;

    /**
     * @notice When the operator is punished due to an error in operation, the penalty funds are recharged to its own pledge pool
     * @param _operatorId operator id
     * @param _amount slash amount
     */
    function addPenaltyFundToStakePool(uint256 _operatorId, uint256 _amount) external payable;

    /**
     * @notice Users claim vNFT rewards
     * @dev There is no need to judge whether this nft belongs to the liquidStaking,
     *      because the liquidStaking cannot directly reward
     * @param _operatorId operator id
     * @param _tokenIds vNFT tokenIds
     * @param _totalNftRewards _totalNftRewards
     * @param _gasHeight update claim gasHeigt
     * @param _owner _owner
     */
    function claimRewardsOfUser(
        uint256 _operatorId,
        uint256[] memory _tokenIds,
        uint256 _totalNftRewards,
        uint256 _gasHeight,
        address _owner
    ) external;

    /**
     * @notice The operator claims the operation reward
     * @param _operatorId operator Id
     * @param _rewardAddresses reward address
     * @param _rewards _rewards
     */
    function claimRewardsOfOperator(uint256 _operatorId, address[] memory _rewardAddresses, uint256[] memory _rewards)
        external;

    /**
     * @notice The dao claims to belong to the dao reward
     * @param _operatorIds operators Id
     * @param _rewards rewards
     */
    function claimRewardsOfDao(uint256[] memory _operatorIds, uint256[] memory _rewards) external;

    /**
     * @notice nETH to ETH exchange rate
     */
    function getExchangeRate() external view returns (uint256);

    event OperatorAssigned(uint256 indexed _blacklistOperatorId, uint256 _operatorId, uint256 _totalAmount);
    event EthStake(uint256 indexed _operatorId, address indexed _from, uint256 _amount, uint256 _amountOut);
    event EthUnstake(
        uint256 indexed _operatorId, uint256 targetOperatorId, address ender, uint256 _amounts, uint256 amountOut
    );
    event NftStake(uint256 indexed _operatorId, address indexed _from, uint256 _count);
    event ValidatorRegistered(uint256 indexed _operatorId, uint256 _tokenId, bytes _pubkey);
    event UserClaimRewards(uint256 _operatorId, uint256[] _tokenIds, uint256 _rewards);
    event Transferred(address _to, uint256 _amount);
    event OperatorReinvestClRewards(uint256 _operatorId, uint256 _rewards);
    event OperatorReinvestElRewards(uint256 _operatorId, uint256 _rewards);
    event RewardsReceive(uint256 _rewards);
    event LiquidStakingWithdrawalCredentialsSet(
        bytes _oldLiquidStakingWithdrawalCredentials, bytes _liquidStakingWithdrawalCredentials
    );
    event WithdrawOracleContractSet(address _oldWithdrawOracleContractSet, address _withdrawOracleContractSetAddress);
    event NodeOperatorRegistryContractSet(
        address _oldNodeOperatorRegistryContract, address _nodeOperatorRegistryContract
    );
    event DaoAddressChanged(address _oldDao, address _dao);
    event DaoVaultAddressChanged(address _oldDaoVaultAddress, address _daoVaultAddress);
    event DepositFeeRateSet(uint256 _oldFeeRate, uint256 _feeRate);
    event OperatorClaimRewards(uint256 _operatorId, uint256 _rewards);
    event DaoClaimRewards(uint256 _operatorId, uint256 _rewards);
    event NftExitBlockNumberSet(uint256[] tokenIds, uint256[] exitBlockNumbers);
    event VaultManagerContractSet(address vaultManagerContractAddress, address _vaultManagerContract);
    event ConsensusVaultContractSet(address vaultManagerContractAddress, address _consensusVaultContract);
    event OperatorCanLoanAmountsSet(uint256 operatorCanLoanAmounts, uint256 _newCanloadAmounts);
    event WithdrawalRequestContractSet(address _withdrawalRequestContract, address _withdrawalRequestContractAddress);
    event OperatorSlashContractSet(address oldOperatorSlashContract, address _operatorSlashContract);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.8;

/**
 * @title Node Operator registry
 *
 * Registration and management of Node Operator
 */
interface INodeOperatorsRegistry {
    /**
     * @notice Add node operator named `name` with reward address `rewardAddress` and _owner
     * @param _name Human-readable name
     * @param _controllerAddress Ethereum 1 address for the operator's management authority
     * @param _owner operator owner address
     * @param _rewardAddresses reward addresses
     * @param _ratios reward ratios
     * @return id a unique key of the added operator
     */
    function registerOperator(
        string calldata _name,
        address _controllerAddress,
        address _owner,
        address[] calldata _rewardAddresses,
        uint256[] calldata _ratios
    ) external payable returns (uint256 id);

    /**
     * @notice Set an operator as trusted
     * @param _id operator id
     */
    function setTrustedOperator(uint256 _id) external;

    /**
     * @notice Remove an operator as trusted
     * @param _id operator id
     */
    function removeTrustedOperator(uint256 _id) external;

    /**
     * @notice Get information about an operator
     * @param _id operator id
     * @param _fullInfo Get all information
     */
    function getNodeOperator(uint256 _id, bool _fullInfo)
        external
        view
        returns (
            bool trusted,
            string memory name,
            address owner,
            address controllerAddress,
            address vaultContractAddress
        );

    /**
     * @notice Returns total number of node operators
     */
    function getNodeOperatorsCount() external view returns (uint256);

    /**
     * @notice Get information about an operator vault contract address
     * @param _id operator id
     */
    function getNodeOperatorVaultContract(uint256 _id) external view returns (address vaultContractAddress);

    /**
     * @notice Get operator rewardSetting
     * @param operatorId operator id
     */
    function getNodeOperatorRewardSetting(uint256 operatorId)
        external
        view
        returns (address[] memory, uint256[] memory);

    /**
     * @notice Returns whether an operator is trusted
     * @param _id operator id
     */
    function isTrustedOperator(uint256 _id) external view returns (bool);

    /**
     * @notice Returns whether an operator is trusted
     * @param _controllerAddress controller address
     */
    function isTrustedOperatorOfControllerAddress(address _controllerAddress) external view returns (uint256);

    /**
     * @notice operator pledge balance
     * @param _operatorId operator id
     */
    function getPledgeInfoOfOperator(uint256 _operatorId) external view returns (uint256, uint256);

    /**
     * @notice get operator comission rate
     * @param _operatorIds operator id
     */
    function getOperatorCommissionRate(uint256[] memory _operatorIds) external view returns (uint256[] memory);

    /**
     * @notice When a validator run by an operator goes seriously offline, it will be slashed
     * @param _slashType slashType
     * @param _slashIds tokenId or stakingId
     * @param _operatorIds operator id
     * @param _amounts slash amount
     */
    function slash(
        uint256 _slashType,
        uint256[] memory _slashIds,
        uint256[] memory _operatorIds,
        uint256[] memory _amounts
    ) external;

    /**
     * @notice deposit pledge fund for operator
     * @param _operatorId operator Id
     */
    function deposit(uint256 _operatorId) external payable;

    /**
     * @notice Returns whether an operator is Blacklist
     * @param _operatorId operator id
     */
    function isBlacklistOperator(uint256 _operatorId) external view returns (bool);

    /**
     * @notice Returns whether an operator is quit
     * @param _id operator id
     */
    function isQuitOperator(uint256 _id) external view returns (bool);

    /**
     * @notice Determine whether the operator meets the pledge requirements
     * @param _operatorId operator id
     */
    function isConformBasicPledge(uint256 _operatorId) external view returns (bool);

    event NodeOperatorRegistered(
        uint256 _id,
        string _name,
        address _controllerAddress,
        address _vaultContractAddress,
        address[] _rewardAddresses,
        uint256[] _ratios
    );
    event OperatorWithdraw(uint256 _operatorId, uint256 _withdrawAmount, address _to);
    event OperatorQuit(uint256 _operatorId, uint256 _nowVault, address _to);
    event NodeOperatorTrustedSet(uint256 _id, string _name, bool _trusted);
    event NodeOperatorTrustedRemove(uint256 _id, string _name, bool _trusted);
    event NodeOperatorBlacklistSet(uint256 _id);
    event NodeOperatorBlacklistRemove(uint256 _id);
    event NodeOperatorNameSet(uint256 _id, string _name);
    event NodeOperatorRewardAddressSet(uint256 _id, address[] _rewardAddresses, uint256[] _ratios);
    event NodeOperatorControllerAddressSet(uint256 _id, string _name, address _controllerAddress);
    event NodeOperatorOwnerAddressSet(uint256 _id, string _name, address _ownerAddress);
    event Transferred(address _to, uint256 _amount);
    event Slashed(uint256 _operatorId, uint256 _amount);
    event PledgeDeposited(uint256 _amount, uint256 _operatorId);
    event Withdraw(uint256 _amount, uint256 _operatorId, address _to);
    event LiquidStakingChanged(address _from, address _to);
    event DaoAddressChanged(address _oldDao, address _dao);
    event DaoVaultAddressChanged(address _oldDaoVaultAddress, address _daoVaultAddress);
    event RegistrationFeeChanged(uint256 _oldFee, uint256 _fee);
    event PermissionlessBlockNumberSet(uint256 _blockNumber);
    event OperatorClaimRewards(uint256 _operatorId, uint256 _rewards);
    event DaoClaimRewards(uint256 _operatorId, uint256 _rewards);
    event CommissionRateChanged(uint256 _oldRate, uint256 _rate);
    event OperatorArrearsReduce(uint256 _operatorId, uint256 value);
    event OperatorArrearsIncrease(uint256 _operatorId, uint256 value);
    event VaultFactorContractSet(address _vaultFactoryContract, address _vaultFactoryContractAddress);
    event OperatorVaultContractReset(address _oldVaultContractAddress, address _vaultContractAddress);
    event OperatorSlashContractSet(address _oldOperatorSlashContract, address _operatorSlashContractAddress);
    event DefaultOperatorCommissionRateChanged(
        uint256 _oldDefaultOperatorCommission, uint256 _defaultOperatorCommission
    );
    event LargeStakingChanged(address _oldLargeStakingContractAddress, address _largeStakingContractAddress);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

/**
 * @title Interface for OperatorSlash
 * @notice OperatorSlash contract
 */
interface IOperatorSlash {
    /**
     * @notice Receive slash fund, Because the operator may have insufficient margin, _slashAmounts may be less than or equal to _requireAmounts
     * @param _slashType slashType
     * @param _slashIds exit tokenIds
     * @param _operatorIds operator
     * @param _slashAmounts slash amount
     * @param _requireAmounts require slas amount
     */
    function slashReceive(
        uint256 _slashType,
        uint256[] memory _slashIds,
        uint256[] memory _operatorIds,
        uint256[] memory _slashAmounts,
        uint256[] memory _requireAmounts
    ) external payable;

    function claimCompensated(uint256[] memory _tokenIds, address _owner) external returns (uint256);

    function claimCompensatedOfLargeStaking(uint256[] memory _stakingIds, address _owner) external returns (uint256);
    /**
     * @notice According to the report results of the oracle machine, the operator who has reduced nft will be punished
     * @param _exitTokenIds token id
     * @param _amounts slash amounts
     */
    function slashOperator(uint256[] memory _exitTokenIds, uint256[] memory _amounts) external;
    function slashOperatorOfLargeStaking(
        uint256[] memory _stakingIds,
        uint256[] memory _operatorIds,
        uint256[] memory _amounts
    ) external;

    /**
     * @notice The receiving function of the penalty, used for the automatic transfer after the operator recharges the margin
     * @param _operatorId operator Id
     * @param _amount slash amount
     */
    function slashArrearsReceive(uint256 _operatorId, uint256 _amount) external payable;

    event SlashArrearsReceive(uint256 _operatorId, uint256 _amount);
    event SlashArrearsReceiveOfNft(uint256 _operatorId, uint256 _tokenId, uint256 _amount);
    event SlashArrearsReceiveOfLargeStaking(uint256 _operatorId, uint256 stakingId, uint256 _amount);
    event SlashReceiveOfNft(uint256 _operatorId, uint256 tokenId, uint256 _slashAmount, uint256 _requirAmounts);
    event SlashReceiveOfLargeStaking(
        uint256 _operatorId, uint256 stakingId, uint256 _slashAmount, uint256 _requirAmounts
    );
    event SlashAmountPerBlockPerValidatorSet(
        uint256 _oldSlashAmountPerBlockPerValidator, uint256 _slashAmountPerBlockPerValidator
    );

    event NodeOperatorRegistryContractSet(
        address _oldNodeOperatorRegistryContract, address _nodeOperatorRegistryContract
    );
    event VaultManagerContractSet(address _oldVaultManagerContractAddress, address _vaultManagerContract);
    event WithdrawalRequestContractSet(
        address _oldWithdrawalRequestContract, address _withdrawalRequestContractAddress
    );
    event LiquidStakingChanged(address _oldLiquidStakingContract, address _liquidStakingContractAddress);
    event LargeStakingChanged(address _oldLargeStakingContractAddress, address _largeStakingContractAddress);
    event DaoAddressChanged(address oldDao, address _dao);
    event CompensatedClaimedOfNft(address _owner, uint256 _tokenId, uint256 _compensated);
    event CompensatedClaimedOfLargeStaking(address _owner, uint256 _stakingId, uint256 _compensated);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.8;

import "lib/ERC721A-Upgradeable/contracts/IERC721AUpgradeable.sol";

interface IVNFT is IERC721AUpgradeable {
    function activeNfts() external view returns (uint256[] memory);

    /**
     * @notice Returns the validators that are active (may contain validator that are yet active on beacon chain)
     */
    function activeValidatorsOfStakingPool() external view returns (bytes[] memory);

    /**
     * @notice Returns the tokenId that are active (may contain validator that are yet active on beacon chain)
     */
    function activeNftsOfStakingPool() external view returns (uint256[] memory);

    /**
     * @notice get empty nft counts
     */
    function getEmptyNftCounts() external view returns (uint256);

    /**
     * @notice Checks if a validator exists
     * @param _pubkey - A 48 bytes representing the validator's public key
     */
    function validatorExists(bytes calldata _pubkey) external view returns (bool);

    /**
     * @notice Finds the validator's public key of a nft
     * @param _tokenId - tokenId of the validator nft
     */
    function validatorOf(uint256 _tokenId) external view returns (bytes memory);

    /**
     * @notice Finds all the validator's public key of a particular address
     * @param _owner - The particular address
     */
    function validatorsOfOwner(address _owner) external view returns (bytes[] memory);

    /**
     * @notice Finds the operator id of a nft
     * @param _tokenId - tokenId of the validator nft
     */
    function operatorOf(uint256 _tokenId) external view returns (uint256);

    /**
     * @notice Get the number of operator's active nft
     * @param _operatorId - operator id
     */
    function getActiveNftCountsOfOperator(uint256 _operatorId) external view returns (uint256);

    /**
     * @notice Get the number of operator's empty nft
     * @param _operatorId - operator id
     */
    function getEmptyNftCountsOfOperator(uint256 _operatorId) external view returns (uint256);

    /**
     * @notice Get the number of user's active nft
     * @param _operatorId - operator id
     */
    function getUserActiveNftCountsOfOperator(uint256 _operatorId) external view returns (uint256);

    /**
     * @notice Finds the tokenId of a validator
     * @dev Returns MAX_SUPPLY if not found
     * @param _pubkey - A 48 bytes representing the validator's public key
     */
    function tokenOfValidator(bytes calldata _pubkey) external view returns (uint256);

    /**
     * @notice Returns the last owner before the nft is burned
     * @param _tokenId - tokenId of the validator nft
     */
    function lastOwnerOf(uint256 _tokenId) external view returns (address);

    /**
     * @notice Mints a Validator nft (vNFT)
     * @param _pubkey -  A 48 bytes representing the validator's public key
     * @param _to - The recipient of the nft
     * @param _operatorId - The operator repsonsible for operating the physical node
     */
    function whiteListMint(
        bytes calldata _pubkey,
        bytes calldata _withdrawalCredentials,
        address _to,
        uint256 _operatorId
    ) external returns (uint256);

    /**
     * @notice Burns a Validator nft (vNFT)
     * @param _tokenId - tokenId of the validator nft
     */
    function whiteListBurn(uint256 _tokenId) external;

    /**
     * @notice Obtain the withdrawal voucher used by tokenid,
     * if it is bytes(""), it means it is not the user's nft, and the voucher will be the withdrawal contract address of the nodedao protocol
     * @param _tokenId - tokenId
     */
    function getUserNftWithdrawalCredentialOfTokenId(uint256 _tokenId) external view returns (bytes memory);

    /**
     * @notice The operator obtains the withdrawal voucher to be used for the next registration of the validator.
     *  // If it is bytes (""), it means that it is not the user's NFT, and the voucher will be the withdrawal contract address of the nodedao protocol.
     * @param _operatorId - operatorId
     */
    function getNextValidatorWithdrawalCredential(uint256 _operatorId) external view returns (bytes memory);

    /**
     * @notice set nft exit height
     * @param _tokenIds - tokenIds
     * @param _exitBlockNumbers - tokenIds
     */
    function setNftExitBlockNumbers(uint256[] memory _tokenIds, uint256[] memory _exitBlockNumbers) external;

    /**
     * @notice Get the number of nft exit height
     * @param _tokenIds - tokenIds
     */
    function getNftExitBlockNumbers(uint256[] memory _tokenIds) external view returns (uint256[] memory);

    /**
     * @notice set nft gas height
     * @param _tokenId - tokenId
     * @param _number - gas height
     */
    function setUserNftGasHeight(uint256 _tokenId, uint256 _number) external;

    /**
     * @notice Get the number of user's nft gas height
     * @param _tokenIds - tokenIds
     */
    function getUserNftGasHeight(uint256[] memory _tokenIds) external view returns (uint256[] memory);

    /**
     * @notice Get the number of total active nft counts
     */
    function getTotalActiveNftCounts() external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.8;

struct WithdrawInfo {
    uint64 operatorId;
    // The income that should be issued by this operatorId in this settlement
    uint96 clReward;
    // For this settlement, whether operatorId has exit node, if no exit node is 0;
    // The value of one node exiting is 32 eth(or 32.9 ETH), and the value of two nodes exiting is 64eth (or 63 ETH).
    // If the value is less than 32, the corresponding amount will be punished
    // clCapital is the principal of nft exit held by the protocol
    uint96 clCapital;
}

struct ExitValidatorInfo {
    // Example Exit the token Id of the validator. No exit is an empty array.
    uint64 exitTokenId;
    // Height of exit block
    uint96 exitBlockNumber;
    // Amount of slash
    uint96 slashAmount;
}

// Validator quits reporting information
struct CLStakingExitInfo {
    uint128 stakingId;
    bytes[] pubkeys;
}

// Verifier penalty reporting information
struct CLStakingSlashInfo {
    uint128 stakingId;
    // Trigger penalty on operator if slash occurs
    uint128 slashAmount;
    bytes pubkey;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.8;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
import "src/interfaces/INodeOperatorsRegistry.sol";
import "src/interfaces/IELVaultFactory.sol";
import "src/interfaces/ILiquidStaking.sol";
import "src/interfaces/IVNFT.sol";
import "src/interfaces/IELVault.sol";
import "src/interfaces/IOperatorSlash.sol";
import "src/interfaces/ILargeStaking.sol";

/**
 * @title Node Operator registry
 *
 * Registration and management of Node Operator
 */
contract NodeOperatorRegistry is
    Initializable,
    OwnableUpgradeable,
    INodeOperatorsRegistry,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using Math for uint256;

    struct RewardSetting {
        address rewardAddress;
        uint256 ratio;
    }

    /// @dev Node Operator parameters
    struct NodeOperator {
        bool trusted; // Trusted operator approved by dao
        bool isQuit;
        address owner;
        address controllerAddress; // Ethereum 1 address for the operator's management authority
        address vaultContractAddress; // Ethereum 1 contract address for the operator's vault
        string name; // operator name, Human-readable name
    }

    IELVaultFactory public vaultFactoryContract;

    ILiquidStaking public liquidStakingContract;

    IVNFT public vNFTContract;

    /// @dev Mapping of all node operators. Mapping is used to be able to extend the struct.
    mapping(uint256 => NodeOperator) internal operators;

    uint256 internal constant MAX_REWARDSETTING_LENGTH = 3;
    // operator reward settings
    mapping(uint256 => RewardSetting[]) internal operatorRewardSetting;

    // trusted operator set
    mapping(address => uint256) public trustedControllerAddress;
    // The operator corresponding to the control address
    mapping(address => uint256) public controllerAddress;
    // The used control address, an address can only be used once
    mapping(address => bool) public usedControllerAddress;
    // blacklist operator set
    mapping(uint256 => bool) public blacklistOperators;

    // Total number of operators
    uint256 internal totalOperators;
    uint256 internal totalTrustedOperators;
    uint256 internal totalBlacklistOperators;

    // dao address
    address public dao;
    // dao treasury address
    address public daoVaultAddress;

    // operator registration fee
    uint256 public registrationFee;

    // The block height at the start of the permissionless phase
    uint256 public permissionlessBlockNumber;

    uint256 public constant BASIC_PLEDGE = 1 ether;
    // operator pledge funds set
    mapping(uint256 => uint256) public operatorPledgeVaultBalances;

    // v2 storage
    IOperatorSlash public operatorSlashContract;

    mapping(uint256 => uint256) public operatorSlashAmountOwed;
    mapping(uint256 => uint256) internal operatorCommissionRate;
    uint256 public defaultOperatorCommission;

    // v3 storage
    ILargeStaking public largeStakingContract;

    uint256 public globalPledgeAmount;

    error PermissionDenied();
    error InvalidAddr();
    error InvalidParameter();
    error OperatorNotFound();
    error InvalidCommission();
    error InsufficientAmount();
    error ControllerAddrUsed();
    error OperatorHasArrears();
    error OperatorHasBlacklisted();
    error InsufficientMargin();
    error OperatorHasExited();
    error OperatorExitFailed();
    error OperatorAlreadyTrusted();
    error OperatorNotTrusted();
    error OperatorNotBlacklisted();
    error NoPermissionPhase();
    error InvalidRewardRatio();
    error PermissionlessPhaseStart();

    event GlobalPledgeAmountSet(uint256 _oldGlobalPledgeAmount, uint256 _globalPledgeAmount);

    modifier onlyOperatorSlash() {
        if (msg.sender != address(operatorSlashContract)) revert PermissionDenied();
        _;
    }

    modifier onlyDao() {
        if (msg.sender != dao) revert PermissionDenied();
        _;
    }

    modifier validAddress(address _a) {
        if (_a == address(0)) revert InvalidParameter();
        _;
    }

    modifier operatorExists(uint256 _id) {
        if (_id == 0 || _id > totalOperators) revert OperatorNotFound();
        _;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    /**
     * @notice initialize NodeOperatorRegistry Contract
     * @param _dao Dao contract address
     * @param _daoVaultAddress Dao Vault Address
     * @param _vaultFactoryContractAddress vault factory contract address
     */
    function initialize(
        address _dao,
        address _daoVaultAddress,
        address _vaultFactoryContractAddress,
        address _nVNFTContractAddress
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        dao = _dao;
        daoVaultAddress = _daoVaultAddress;
        vaultFactoryContract = IELVaultFactory(_vaultFactoryContractAddress);
        vNFTContract = IVNFT(_nVNFTContractAddress);
        registrationFee = 0.1 ether;
        permissionlessBlockNumber = 0;
    }

    /**
     * @notice initializeV2 NodeOperatorRegistry Contract
     * @param _vaultFactoryContractAddress new vault factory contract address
     * @param _resetVaultOperatorIds reset vault contract
     */
    function initializeV2(
        address _vaultFactoryContractAddress,
        address _operatorSlashContractAddress,
        uint256[] memory _resetVaultOperatorIds
    ) public reinitializer(2) onlyDao {
        defaultOperatorCommission = 2000;
        emit VaultFactorContractSet(address(vaultFactoryContract), _vaultFactoryContractAddress);
        vaultFactoryContract = IELVaultFactory(_vaultFactoryContractAddress);

        emit OperatorSlashContractSet(address(operatorSlashContract), _operatorSlashContractAddress);
        operatorSlashContract = IOperatorSlash(_operatorSlashContractAddress);
        for (uint256 i = 0; i < _resetVaultOperatorIds.length; ++i) {
            _resetOperatorVaultContract(_resetVaultOperatorIds[i]);
        }
    }

    function initializeV3(address _largeStakingContractAddress) public reinitializer(3) onlyOwner {
        largeStakingContract = ILargeStaking(_largeStakingContractAddress);
    }

    /**
     * @notice Add node operator named `name` with reward address `rewardAddress` and _owner
     * @param _name Human-readable name
     * @param _controllerAddress Ethereum 1 address for the operator's management authority
     * @param _owner operator owner address
     * @param _rewardAddresses reward addresses
     * @param _ratios reward ratios
     * @return id a unique key of the added operator
     */

    function registerOperator(
        string calldata _name,
        address _controllerAddress,
        address _owner,
        address[] calldata _rewardAddresses,
        uint256[] calldata _ratios
    ) external payable nonReentrant validAddress(_controllerAddress) validAddress(_owner) returns (uint256 id) {
        if (bytes(_name).length > 32) revert InvalidParameter();
        if (msg.value < BASIC_PLEDGE + registrationFee) revert InsufficientAmount();
        if (usedControllerAddress[_controllerAddress]) revert ControllerAddrUsed();
        id = totalOperators + 1;

        totalOperators = id;

        // Generate a vault contract for the operator
        address vaultContractAddress = vaultFactoryContract.create(id);

        operators[id] = NodeOperator({
            trusted: false,
            isQuit: false,
            owner: _owner,
            controllerAddress: _controllerAddress,
            vaultContractAddress: vaultContractAddress,
            name: _name
        });

        _setNodeOperatorRewardAddress(id, _rewardAddresses, _ratios);

        usedControllerAddress[_controllerAddress] = true;
        controllerAddress[_controllerAddress] = id;

        uint256 pledgeAmount = msg.value - registrationFee;
        operatorPledgeVaultBalances[id] += pledgeAmount;
        emit PledgeDeposited(pledgeAmount, id);

        if (registrationFee > 0) {
            transfer(registrationFee, daoVaultAddress);
        }

        emit NodeOperatorRegistered(id, _name, _controllerAddress, vaultContractAddress, _rewardAddresses, _ratios);
    }

    /**
     * @notice Withdraw the deposit available to the operator, it must be sent by the operator owner
     * @param _operatorId operator id
     * @param _withdrawAmount withdrawal amount
     * @param _to receiving address
     */

    function withdrawOperator(uint256 _operatorId, uint256 _withdrawAmount, address _to) external nonReentrant {
        if (blacklistOperators[_operatorId]) revert OperatorHasBlacklisted();
        if (operatorSlashAmountOwed[_operatorId] != 0) revert OperatorHasArrears();
        if (_to == address(0)) revert InvalidAddr();

        NodeOperator memory operator = operators[_operatorId];
        if (operator.owner != msg.sender) revert PermissionDenied();

        uint256 requireVault = calcRequirePledgeBalance(_operatorId);

        // After the withdrawal is completed, the pledge funds requirements must also be met
        if (operatorPledgeVaultBalances[_operatorId] < requireVault + _withdrawAmount) revert InsufficientMargin();
        operatorPledgeVaultBalances[_operatorId] -= _withdrawAmount;
        payable(_to).transfer(_withdrawAmount);

        emit OperatorWithdraw(_operatorId, _withdrawAmount, _to);
    }

    function calcRequirePledgeBalance(uint256 _operatorId) internal view returns (uint256) {
        uint256 _globalPledgeAmount = globalPledgeAmount;
        if (_globalPledgeAmount != 0) {
            return _globalPledgeAmount;
        }

        uint256 operatorNftCounts = vNFTContract.getActiveNftCountsOfOperator(_operatorId)
            + vNFTContract.getEmptyNftCountsOfOperator(_operatorId)
            + largeStakingContract.getOperatorValidatorCounts(_operatorId);
        // Pledge the required funds based on the number of validators
        uint256 requireVault = 0;
        if (operatorNftCounts <= 100) {
            requireVault = (operatorNftCounts * 10 / 100) * 1 ether;
            if (requireVault < 1 ether) {
                requireVault = 1 ether;
            }
        } else {
            requireVault = operatorNftCounts.sqrt() * 1 ether;
        }

        return requireVault;
    }

    function setGlobalPledgeAmount(uint256 _globalPledgeAmount) onlyDao external {
        emit GlobalPledgeAmountSet(globalPledgeAmount, _globalPledgeAmount);
        globalPledgeAmount = _globalPledgeAmount;
    }

    /**
     * @notice Exit the operator. When there are no validators running, the owner of the operator has the right to opt out.
     * Unused funds must be transferred to another active operator
     * @param _operatorId operator id
     * @param _to The receiving address of the pledged funds of the withdrawn operator
     */
    function quitOperator(uint256 _operatorId, address _to) external {
        if (blacklistOperators[_operatorId]) revert OperatorHasBlacklisted();
        if (operatorSlashAmountOwed[_operatorId] != 0) revert OperatorHasArrears();
        NodeOperator memory operator = operators[_operatorId];
        if (operator.owner != msg.sender) revert PermissionDenied();
        if (operators[_operatorId].isQuit) revert OperatorHasExited();

        uint256 operatorNftCounts = vNFTContract.getActiveNftCountsOfOperator(_operatorId)
            + vNFTContract.getEmptyNftCountsOfOperator(_operatorId);
        // There are active validators and cannot exit
        if (operatorNftCounts != 0) revert OperatorExitFailed();

        uint256 nowPledge = operatorPledgeVaultBalances[_operatorId];
        operatorPledgeVaultBalances[_operatorId] = 0;

        if (_to == address(0)) revert InvalidAddr();
        payable(_to).transfer(nowPledge);
        operators[_operatorId].isQuit = true;

        emit OperatorQuit(_operatorId, nowPledge, _to);
    }

    /**
     * @notice Set an operator as trusted
     * @param _id operator id
     */

    function setTrustedOperator(uint256 _id) external onlyDao operatorExists(_id) {
        _checkPermission();

        NodeOperator memory operator = operators[_id];
        if (operator.trusted) revert OperatorAlreadyTrusted();
        operators[_id].trusted = true;
        totalTrustedOperators += 1;
        trustedControllerAddress[operator.controllerAddress] = _id;
        emit NodeOperatorTrustedSet(_id, operator.name, true);
    }

    /**
     * @notice Remove an operator as trusted
     * @param _id operator id
     */

    function removeTrustedOperator(uint256 _id) external onlyDao operatorExists(_id) {
        _checkPermission();

        NodeOperator memory operator = operators[_id];
        if (!operator.trusted) revert OperatorNotTrusted();
        operators[_id].trusted = false;
        totalTrustedOperators -= 1;
        trustedControllerAddress[operator.controllerAddress] = 0;
        emit NodeOperatorTrustedRemove(_id, operator.name, false);
    }

    /**
     * @notice Set an operator as blacklist
     * @param _id operator id
     */
    function setBlacklistOperator(uint256 _id) external onlyDao operatorExists(_id) {
        if (blacklistOperators[_id]) revert OperatorHasBlacklisted();
        blacklistOperators[_id] = true;
        totalBlacklistOperators += 1;
        emit NodeOperatorBlacklistSet(_id);
    }

    /**
     * @notice Remove an operator as blacklist
     * @param _id operator id
     */

    function removeBlacklistOperator(uint256 _id) external onlyDao operatorExists(_id) {
        if (!blacklistOperators[_id]) revert OperatorNotBlacklisted();
        blacklistOperators[_id] = false;
        totalBlacklistOperators -= 1;
        emit NodeOperatorBlacklistRemove(_id);
    }

    function _checkPermission() internal view {
        if (permissionlessBlockNumber != 0) {
            if (block.number >= permissionlessBlockNumber) revert NoPermissionPhase();
        }
    }

    function _setNodeOperatorRewardAddress(uint256 _id, address[] calldata _rewardAddresses, uint256[] calldata _ratios)
        internal
    {
        if (
            _rewardAddresses.length == 0 || _rewardAddresses.length > MAX_REWARDSETTING_LENGTH
                || _rewardAddresses.length != _ratios.length
        ) revert InvalidParameter();

        // clear old settings
        delete operatorRewardSetting[_id];

        uint256 totalRatio = 0;
        for (uint256 i = 0; i < _rewardAddresses.length; ++i) {
            if (_rewardAddresses[i] == address(0)) revert InvalidAddr();
            operatorRewardSetting[_id].push(RewardSetting({rewardAddress: _rewardAddresses[i], ratio: _ratios[i]}));

            totalRatio += _ratios[i];
        }

        // Ratio sum should be 100%
        if (totalRatio != 100) revert InvalidRewardRatio();
    }

    /**
     * @notice Get information about an operator
     * @param _id operator id
     * @param _fullInfo Get all information
     */
    function getNodeOperator(uint256 _id, bool _fullInfo)
        external
        view
        operatorExists(_id)
        returns (
            bool _trusted,
            string memory _name,
            address _owner,
            address _controllerAddress,
            address _vaultContractAddress
        )
    {
        NodeOperator memory operator = operators[_id];

        _trusted = operator.trusted;
        _name = _fullInfo ? operator.name : "";
        _owner = operator.owner;
        _controllerAddress = operator.controllerAddress;
        _vaultContractAddress = operator.vaultContractAddress;
    }

    /**
     * @notice Get information about an operator vault contract address
     * @param _id operator id
     */
    function getNodeOperatorVaultContract(uint256 _id)
        external
        view
        operatorExists(_id)
        returns (address vaultContractAddress)
    {
        return operators[_id].vaultContractAddress;
    }

    /**
     * @notice Get operator rewardSetting
     * @param _operatorId operator id
     */
    function getNodeOperatorRewardSetting(uint256 _operatorId)
        external
        view
        returns (address[] memory rewardAddresses, uint256[] memory ratios)
    {
        RewardSetting[] memory rewardSetting = operatorRewardSetting[_operatorId];
        rewardAddresses = new address[] (rewardSetting.length);
        ratios = new uint256[] (rewardSetting.length);
        for (uint256 i = 0; i < rewardSetting.length; ++i) {
            rewardAddresses[i] = rewardSetting[i].rewardAddress;
            ratios[i] = rewardSetting[i].ratio;
        }

        return (rewardAddresses, ratios);
    }

    /**
     * @notice Returns whether an operator is trusted
     * @param _operatorId operator id
     */
    function isTrustedOperator(uint256 _operatorId) external view operatorExists(_operatorId) returns (bool) {
        if (blacklistOperators[_operatorId]) {
            return false;
        }

        if (operators[_operatorId].isQuit) {
            return false;
        }

        if (permissionlessBlockNumber != 0 && block.number >= permissionlessBlockNumber) {
            return true;
        }

        return operators[_operatorId].trusted;
    }

    /**
     * @notice Returns whether an operator is quit
     * @param _operatorId operator id
     */
    function isQuitOperator(uint256 _operatorId) external view operatorExists(_operatorId) returns (bool) {
        return operators[_operatorId].isQuit;
    }

    /**
     * @notice Returns whether an operator is Blacklist
     * @param _operatorId operator id
     */
    function isBlacklistOperator(uint256 _operatorId) external view operatorExists(_operatorId) returns (bool) {
        if (blacklistOperators[_operatorId]) {
            return true;
        }

        return false;
    }

    /**
     * @notice Returns whether an operator is trusted， return operatorId
     * @param _controllerAddress controller address
     */
    function isTrustedOperatorOfControllerAddress(address _controllerAddress) external view returns (uint256) {
        uint256 _id = controllerAddress[_controllerAddress];
        if (blacklistOperators[_id]) {
            return 0;
        }

        if (operators[_id].isQuit) {
            return 0;
        }

        if (permissionlessBlockNumber != 0 && block.number >= permissionlessBlockNumber) {
            return _id;
        }

        return trustedControllerAddress[_controllerAddress];
    }

    /**
     * @notice deposit pledge fund for operator
     * @param _operatorId operator Id
     */
    function deposit(uint256 _operatorId) external payable nonReentrant {
        if (operators[_operatorId].isQuit) revert OperatorHasExited();

        uint256 amountOwed = operatorSlashAmountOwed[_operatorId];
        if (amountOwed > 0) {
            if (amountOwed > msg.value) {
                operatorSlashContract.slashArrearsReceive{value: msg.value}(_operatorId, msg.value);
                operatorSlashAmountOwed[_operatorId] -= msg.value;
                emit OperatorArrearsReduce(_operatorId, msg.value);
            } else {
                operatorSlashContract.slashArrearsReceive{value: amountOwed}(_operatorId, amountOwed);
                operatorSlashAmountOwed[_operatorId] = 0;
                operatorPledgeVaultBalances[_operatorId] += msg.value - amountOwed;
                emit OperatorArrearsReduce(_operatorId, amountOwed);
            }
        } else {
            operatorPledgeVaultBalances[_operatorId] += msg.value;
        }

        emit PledgeDeposited(msg.value, _operatorId);
    }

    function _slash(uint256 _operatorId, uint256 _amount) internal operatorExists(_operatorId) returns (uint256) {
        uint256 pledgeAmounts = operatorPledgeVaultBalances[_operatorId];
        if (pledgeAmounts == 0) {
            emit OperatorArrearsIncrease(_operatorId, _amount);
            operatorSlashAmountOwed[_operatorId] += _amount;
            return 0;
        }

        if (pledgeAmounts >= _amount) {
            operatorPledgeVaultBalances[_operatorId] -= _amount;
            emit Slashed(_operatorId, _amount);
            return _amount;
        } else {
            uint256 slashAmountAdded = _amount - pledgeAmounts;
            operatorSlashAmountOwed[_operatorId] += slashAmountAdded;
            emit OperatorArrearsIncrease(_operatorId, slashAmountAdded);
            operatorPledgeVaultBalances[_operatorId] = 0;
            emit Slashed(_operatorId, pledgeAmounts);
            return pledgeAmounts;
        }
    }

    /**
     * @notice When a validator run by an operator goes seriously offline, it will be slashed
     * @param _slashType slashType
     * @param _slashIds tokenId or stakingId
     * @param _operatorIds operator id
     * @param _amounts slash amount
     */
    function slash(
        uint256 _slashType,
        uint256[] memory _slashIds,
        uint256[] memory _operatorIds,
        uint256[] memory _amounts
    ) external nonReentrant onlyOperatorSlash {
        uint256 totalSlashAmounts = 0;
        uint256[] memory slashAmounts = new uint256[] (_operatorIds.length);
        for (uint256 i = 0; i < _operatorIds.length; ++i) {
            uint256 amount = _amounts[i];
            if (amount == 0) {
                continue;
            }

            uint256 operatorId = _operatorIds[i];
            uint256 slashAmount = _slash(operatorId, amount);
            slashAmounts[i] = slashAmount;
            totalSlashAmounts += slashAmount;
        }

        operatorSlashContract.slashReceive{value: totalSlashAmounts}(
            _slashType, _slashIds, _operatorIds, slashAmounts, _amounts
        );
    }

    /**
     * @notice Determine whether the operator meets the pledge requirements
     * @param _operatorId operator id
     */
    function isConformBasicPledge(uint256 _operatorId) external view returns (bool) {
        return operatorPledgeVaultBalances[_operatorId] >= BASIC_PLEDGE;
    }

    /**
     * @notice operator pledge balance
     * @param _operatorId operator id
     */
    function getPledgeInfoOfOperator(uint256 _operatorId) external view returns (uint256, uint256) {
        uint256 requireBalance = calcRequirePledgeBalance(_operatorId);
        return (operatorPledgeVaultBalances[_operatorId], requireBalance);
    }

    /**
     * @notice reset a new vault contract for operator
     * @param _operatorIds operators id
     */
    function resetOperatorVaultContract(uint256[] calldata _operatorIds) external onlyDao {
        for (uint256 i = 0; i < _operatorIds.length; ++i) {
            uint256 operatorId = _operatorIds[i];
            _resetOperatorVaultContract(operatorId);
        }
    }

    function _resetOperatorVaultContract(uint256 _operatorId) internal {
        address vaultContractAddress = vaultFactoryContract.create(_operatorId);
        emit OperatorVaultContractReset(operators[_operatorId].vaultContractAddress, vaultContractAddress);
        operators[_operatorId].vaultContractAddress = vaultContractAddress;
    }

    /**
     * @notice get operator commission rate
     * @param _operatorIds operator id
     */
    function getOperatorCommissionRate(uint256[] memory _operatorIds) external view returns (uint256[] memory) {
        uint256[] memory commissions = new uint256[] (_operatorIds.length);
        for (uint256 i = 0; i < _operatorIds.length; ++i) {
            if (operatorCommissionRate[_operatorIds[i]] == 0) {
                commissions[i] = defaultOperatorCommission;
            } else {
                commissions[i] = operatorCommissionRate[_operatorIds[i]];
            }
        }

        return commissions;
    }

    /**
     * @notice set operator comission rate
     * @param _operatorId operator id
     * @param _rate _rate
     */
    function setOperatorCommissionRate(uint256 _operatorId, uint256 _rate) external onlyDao {
        if (_rate >= 5000) revert InvalidCommission();
        uint256 commissionRate = operatorCommissionRate[_operatorId];
        emit CommissionRateChanged(commissionRate == 0 ? defaultOperatorCommission : commissionRate, _rate);
        operatorCommissionRate[_operatorId] = _rate;
    }

    /**
     * @notice Change the owner of the operator
     * @param _id operator id
     * @param _owner Ethereum 1 address for the operator's owner authority
     */
    function setNodeOperatorOwnerAddress(uint256 _id, address _owner) external operatorExists(_id) {
        NodeOperator memory operator = operators[_id];
        if (operator.owner != msg.sender && msg.sender != dao) revert PermissionDenied();

        operators[_id].owner = _owner;

        emit NodeOperatorOwnerAddressSet(_id, operator.name, _owner);
    }

    /**
     * @notice set operator setting
     */
    function setOperatorSetting(
        uint256 _id,
        string calldata _name,
        address _controllerAddress,
        address[] calldata _rewardAddresses,
        uint256[] calldata _ratios
    ) public operatorExists(_id) {
        NodeOperator memory operator = operators[_id];

        if (msg.sender != operator.owner) revert PermissionDenied();

        if (bytes(_name).length != 0) {
            operators[_id].name = _name;
            emit NodeOperatorNameSet(_id, _name);
        }
        if (_controllerAddress != address(0)) {
            // The same address can only be used once
            if (usedControllerAddress[_controllerAddress]) revert ControllerAddrUsed();

            if (operator.owner != msg.sender) revert PermissionDenied();
            if (trustedControllerAddress[operator.controllerAddress] == _id) {
                trustedControllerAddress[operator.controllerAddress] = 0;
                trustedControllerAddress[_controllerAddress] = _id;
            }

            // Update the control address set to ensure that the operatorid can be obtained according to the control address
            controllerAddress[operator.controllerAddress] = 0;
            controllerAddress[_controllerAddress] = _id;
            operators[_id].controllerAddress = _controllerAddress;
            usedControllerAddress[_controllerAddress] = true;

            emit NodeOperatorControllerAddressSet(_id, operator.name, _controllerAddress);
        }
        if (_rewardAddresses.length != 0) {
            _setNodeOperatorRewardAddress(_id, _rewardAddresses, _ratios);
            emit NodeOperatorRewardAddressSet(_id, _rewardAddresses, _ratios);
        }
    }

    /**
     * @notice set contract setting
     */
    function setNodeOperatorRegistrySetting(
        address _dao,
        address _daoVaultAddress,
        address _liquidStakingContractAddress,
        address _operatorSlashContractAddress,
        address _vaultFactoryContractAddress,
        address _largeStakingContractAddress,
        uint256 _defaultOperatorCommission,
        uint256 _registrationFee,
        uint256 _permissionlessBlockNumber
    ) public onlyDao {
        if (_dao != address(0)) {
            emit DaoAddressChanged(dao, _dao);
            dao = _dao;
        }

        if (_daoVaultAddress != address(0)) {
            emit DaoVaultAddressChanged(daoVaultAddress, _daoVaultAddress);
            daoVaultAddress = _daoVaultAddress;
        }

        if (_liquidStakingContractAddress != address(0)) {
            emit LiquidStakingChanged(address(liquidStakingContract), _liquidStakingContractAddress);
            liquidStakingContract = ILiquidStaking(_liquidStakingContractAddress);
        }

        if (_operatorSlashContractAddress != address(0)) {
            emit OperatorSlashContractSet(address(operatorSlashContract), _operatorSlashContractAddress);
            operatorSlashContract = IOperatorSlash(_operatorSlashContractAddress);
        }

        if (_vaultFactoryContractAddress != address(0)) {
            emit VaultFactorContractSet(address(vaultFactoryContract), _vaultFactoryContractAddress);
            vaultFactoryContract = IELVaultFactory(_vaultFactoryContractAddress);
        }

        if (_defaultOperatorCommission != 0) {
            if (_defaultOperatorCommission >= 5000) revert InvalidCommission();
            emit DefaultOperatorCommissionRateChanged(defaultOperatorCommission, _defaultOperatorCommission);
            defaultOperatorCommission = _defaultOperatorCommission;
        }

        if (_registrationFee != 0) {
            emit RegistrationFeeChanged(registrationFee, _registrationFee);
            registrationFee = _registrationFee;
        }

        if (_permissionlessBlockNumber != 0) {
            if (permissionlessBlockNumber != 0) revert PermissionlessPhaseStart();
            if (_permissionlessBlockNumber <= block.number) revert InvalidParameter();
            permissionlessBlockNumber = _permissionlessBlockNumber;
            emit PermissionlessBlockNumberSet(_permissionlessBlockNumber);
        }

        if (_largeStakingContractAddress != address(0)) {
            emit LargeStakingChanged(address(largeStakingContract), _largeStakingContractAddress);
            largeStakingContract = ILargeStaking(_largeStakingContractAddress);
        }
    }

    /**
     * @notice transfer amount to an address
     */
    function transfer(uint256 _amount, address _to) internal {
        if (_to == address(0)) revert InvalidAddr();
        payable(_to).transfer(_amount);
        emit Transferred(_to, _amount);
    }

    /**
     * @notice Returns total number of node operators
     */
    function getNodeOperatorsCount() external view returns (uint256) {
        return totalOperators;
    }
}
