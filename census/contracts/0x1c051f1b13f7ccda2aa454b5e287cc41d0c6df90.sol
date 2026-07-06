// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981Upgradeable is IERC165Upgradeable {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
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
// OpenZeppelin Contracts (last updated v4.9.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "../../interfaces/IERC2981Upgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000, meaning the
 * fee is specified in basis points by default.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC2981Upgradeable is Initializable, IERC2981Upgradeable, ERC165Upgradeable {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    function __ERC2981_init() internal onlyInitializing {
    }

    function __ERC2981_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165Upgradeable, ERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981Upgradeable
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721Upgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "./extensions/IERC721MetadataUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/StringsUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC721Upgradeable, IERC721MetadataUpgradeable {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Upgradeable.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721Upgradeable.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721ReceiverUpgradeable(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal virtual {}

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * WARNING: Anyone calling this MUST ensure that the balances remain consistent with the ownership. The invariant
     * being that for any address `a` the value returned by `balanceOf(a)` must be equal to the number of tokens such
     * that `ownerOf(tokenId)` is `a`.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __unsafe_increaseBalance(address account, uint256 amount) internal {
        _balances[account] += amount;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721MetadataUpgradeable is IERC721Upgradeable {
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
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
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
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
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

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
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
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
// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;
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
import {Initializable} from "../../proxy/utils/Initializable.sol";

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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
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
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMathUpgradeable {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";
import "./math/SignedMathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMathUpgradeable.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {File} from "./IFileStore.sol";
import {IEAI721Intelligence} from "../../interfaces/IEAI721Intelligence.sol";

interface IAgent {
    event CodePointerCreated(
        uint256 indexed version,
        uint256 indexed pIndex,
        IEAI721Intelligence.CodePointer newPointer
    );

    error Unauthenticated();
    error InvalidData();
    error ZeroAddress();
    error InvalidVersion();

    function publishAgentCode(
        string calldata codeLanguage,
        IEAI721Intelligence.CodePointer[] calldata pointers,
        address[] calldata depsAgents
    ) external returns (uint16 version);

    function setAgentName(string calldata agentName) external;

    function getDepsAgents(
        uint16 version
    ) external view returns (address[] memory);

    function getAgentCode(
        uint16 version
    ) external view returns (string memory code);

    function getCodeLanguage() external view returns (string memory);

    function getCurrentVersion() external view returns (uint16);

    function getCollectionId() external view returns (uint256);

    function getAgentName() external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAgent, IEAI721Intelligence} from "./IAgent.sol";

interface IAgentFactory {
    event AgentCreated(
        address collection,
        bytes32 agentId,
        address indexed agent
    );
    event ImplementationSet(address indexed implementation);
    event AgentNameSet(bytes32 indexed agentId, string agentName);

    function collectionIdToAgentId(
        uint256 nftId
    ) external view returns (bytes32);

    function isNameRegistered(
        string calldata agentName
    ) external view returns (bool);

    function agents(bytes32 agentId) external view returns (address);

    function createAgent(
        bytes32 agentId,
        string calldata agentName,
        string calldata codeLanguage,
        IEAI721Intelligence.CodePointer[] memory pointers,
        address[] calldata depsAgents,
        uint256 nftId
    ) external returns (address agent);

    function publishAgentCode(
        bytes32 agentId,
        string calldata codeLanguage,
        IEAI721Intelligence.CodePointer[] calldata pointers,
        address[] calldata depsAgents
    ) external returns (uint16 agentVersion);

    function publishAgentCodeSingleTx(
        bytes32 agentId,
        string calldata codeLanguage,
        address[] calldata depsAgents,
        bytes[] calldata datas, // salt and data
        string calldata fileName,
        IEAI721Intelligence.FileType fileType,
        bytes memory metadata
    ) external returns (uint16 agentVersion);

    function setAgentName(bytes32 agentId, string calldata agentName) external;

    function getAgentName(
        bytes32 agentId
    ) external view returns (string memory);

    function getImplementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {File, BytecodeSlice} from "../utility-agent/File.sol";

/// @title EthFS FileStore interface
/// @notice Specifies a content-addressable onchain file store
interface IFileStore {
    event Deployed();

    /**
     * @dev Emitted when a new file is created
     * @param indexedFilename The indexed filename for easier finding by filename in logs
     * @param pointer The pointer address of the file
     * @param filename The name of the file
     * @param size The total size of the file
     * @param metadata Additional metadata of the file, only emitted for use in offchain indexers
     */
    event FileCreated(
        string indexed indexedFilename,
        address indexed pointer,
        string filename,
        uint256 size,
        bytes metadata
    );

    /**
     * @dev Error thrown when a requested file is not found
     * @param filename The name of the file requested
     */
    error FileNotFound(string filename);

    /**
     * @dev Error thrown when a filename already exists
     * @param filename The name of the file attempted to be created
     */
    error FilenameExists(string filename);

    /**
     * @dev Error thrown when attempting to create an empty file
     */
    error FileEmpty();

    /**
     * @dev Error thrown when a provided slice for a file is empty
     * @param pointer The contract address where the bytecode lives
     * @param start The byte offset to start the slice (inclusive)
     * @param end The byte offset to end the slice (exclusive)
     */
    error SliceEmpty(address pointer, uint32 start, uint32 end);

    /**
     * @dev Error thrown when the provided pointer's bytecode does not have the expected STOP opcode prefix from SSTORE2
     * @param pointer The SSTORE2 pointer address
     */
    error InvalidPointer(address pointer);

    /**
     * @notice Returns the address of the CREATE2 deterministic deployer used by this FileStore
     * @return The address of the CREATE2 deterministic deployer
     */
    function deployer() external view returns (address);

    /**
     * @notice Retrieves the pointer address of a file by its filename
     * @param filename The name of the file
     * @return pointer The pointer address of the file
     */
    function files(
        string memory filename
    ) external view returns (address pointer);

    /**
     * @notice Checks if a file exists for a given filename
     * @param filename The name of the file to check
     * @return True if the file exists, false otherwise
     */
    function fileExists(string memory filename) external view returns (bool);

    /**
     * @notice Retrieves the pointer address for a given filename
     * @param filename The name of the file
     * @return pointer The pointer address of the file
     */
    function getPointer(
        string memory filename
    ) external view returns (address pointer);

    /**
     * @notice Retrieves a file by its filename
     * @param filename The name of the file
     * @return file The file associated with the filename
     */
    function getFile(
        string memory filename
    ) external view returns (File memory file);

    /**
     * @notice Creates a new file with the provided file contents
     * @dev This is a convenience method to simplify small file uploads. It's recommended to use `createFileFromPointers` or `createFileFromSlices` for larger files. This particular method splits `contents` into 24575-byte chunks before storing them via SSTORE2.
     * @param filename The name of the new file
     * @param contents The contents of the file
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFile(
        string memory filename,
        string memory contents
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file with the provided file contents and file metadata
     * @dev This is a convenience method to simplify small file uploads. It's recommended to use `createFileFromPointers` or `createFileFromSlices` for larger files. This particular method splits `contents` into 24575-byte chunks before storing them via SSTORE2.
     * @param filename The name of the new file
     * @param contents The contents of the file
     * @param metadata Additional file metadata, usually a JSON-encoded string, for offchain indexers
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFile(
        string memory filename,
        string memory contents,
        bytes memory metadata
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file where its content is composed of the provided string chunks
     * @dev This is a convenience method to simplify small and nuanced file uploads. It's recommended to use `createFileFromPointers` or `createFileFromSlices` for larger files. This particular will store each chunk separately via SSTORE2. For best gas efficiency, each chunk should be as large as possible (up to the contract size limit) and at least 32 bytes.
     * @param filename The name of the new file
     * @param chunks The string chunks composing the file
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromChunks(
        string memory filename,
        string[] memory chunks
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file with the provided string chunks and file metadata
     * @dev This is a convenience method to simplify small and nuanced file uploads. It's recommended to use `createFileFromPointers` or `createFileFromSlices` for larger files. This particular will store each chunk separately via SSTORE2. For best gas efficiency, each chunk should be as large as possible (up to the contract size limit) and at least 32 bytes.
     * @param filename The name of the new file
     * @param chunks The string chunks composing the file
     * @param metadata Additional file metadata, usually a JSON-encoded string, for offchain indexers
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromChunks(
        string memory filename,
        string[] memory chunks,
        bytes memory metadata
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file where its content is composed of the provided SSTORE2 pointers
     * @param filename The name of the new file
     * @param pointers The SSTORE2 pointers composing the file
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromPointers(
        string memory filename,
        address[] memory pointers
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file with the provided SSTORE2 pointers and file metadata
     * @param filename The name of the new file
     * @param pointers The SSTORE2 pointers composing the file
     * @param metadata Additional file metadata, usually a JSON-encoded string, for offchain indexers
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromPointers(
        string memory filename,
        address[] memory pointers,
        bytes memory metadata
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file where its content is composed of the provided bytecode slices
     * @param filename The name of the new file
     * @param slices The bytecode slices composing the file
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromSlices(
        string memory filename,
        BytecodeSlice[] memory slices
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file with the provided bytecode slices and file metadata
     * @param filename The name of the new file
     * @param slices The bytecode slices composing the file
     * @param metadata Additional file metadata, usually a JSON-encoded string, for offchain indexers
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromSlices(
        string memory filename,
        BytecodeSlice[] memory slices,
        bytes memory metadata
    ) external returns (address pointer, File memory file);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title EthFS File
 * @notice A representation of an onchain file, composed of slices of contract bytecode and utilities to construct the file contents from those slices.
 * @dev For best gas efficiency, it's recommended using `File.read()` as close to the output returned by the contract call as possible. Lots of gas is consumed every time a large data blob is passed between functions.
 */

/**
 * @dev Represents a reference to a slice of bytecode in a contract
 */
struct BytecodeSlice {
    address pointer;
    uint32 start;
    uint32 end;
}

/**
 * @dev Represents a file composed of one or more bytecode slices
 */
struct File {
    // Total length of file contents (sum of all slice sizes). Useful when you want to use DynamicBuffer to build the file contents from the slices.
    uint256 size;
    BytecodeSlice[] slices;
}
// extend File struct with read functions
using {read} for File global;
using {readUnchecked} for File global;

/**
 * @dev Error thrown when a slice is out of the bounds of the contract's bytecode
 */
error SliceOutOfBounds(
    address pointer,
    uint32 codeSize,
    uint32 sliceStart,
    uint32 sliceEnd
);

/**
 * @notice Reads the contents of a file by concatenating its slices
 * @param file The file to read
 * @return contents The concatenated contents of the file
 */
function read(File memory file) view returns (string memory contents) {
    BytecodeSlice[] memory slices = file.slices;
    bytes4 sliceOutOfBoundsSelector = SliceOutOfBounds.selector;

    assembly {
        let len := mload(slices)
        let size := 0x20
        contents := mload(0x40)
        let slice
        let pointer
        let start
        let end
        let codeSize

        for {
            let i := 0
        } lt(i, len) {
            i := add(i, 1)
        } {
            slice := mload(add(slices, add(0x20, mul(i, 0x20))))
            pointer := mload(slice)
            start := mload(add(slice, 0x20))
            end := mload(add(slice, 0x40))

            codeSize := extcodesize(pointer)
            if gt(end, codeSize) {
                mstore(0x00, sliceOutOfBoundsSelector)
                mstore(0x04, pointer)
                mstore(0x24, codeSize)
                mstore(0x44, start)
                mstore(0x64, end)
                revert(0x00, 0x84)
            }

            extcodecopy(pointer, add(contents, size), start, sub(end, start))
            size := add(size, sub(end, start))
        }

        // update contents size
        mstore(contents, sub(size, 0x20))
        // store contents
        mstore(0x40, add(contents, and(add(size, 0x1f), not(0x1f))))
    }
}

/**
 * @notice Reads the contents of a file without reverting on unreadable/invalid slices. Skips any slices that are out of bounds or invalid. Useful if you are composing contract bytecode where a contract can still selfdestruct (which would result in an invalid slice) and want to avoid reverts but still output potentially "corrupted" file contents (due to missing data).
 * @param file The file to read
 * @return contents The concatenated contents of the file, skipping invalid slices
 */
function readUnchecked(File memory file) view returns (string memory contents) {
    BytecodeSlice[] memory slices = file.slices;

    assembly {
        let len := mload(slices)
        let size := 0x20
        contents := mload(0x40)
        let slice
        let pointer
        let start
        let end
        let codeSize

        for {
            let i := 0
        } lt(i, len) {
            i := add(i, 1)
        } {
            slice := mload(add(slices, add(0x20, mul(i, 0x20))))
            pointer := mload(slice)
            start := mload(add(slice, 0x20))
            end := mload(add(slice, 0x40))

            codeSize := extcodesize(pointer)
            if lt(end, codeSize) {
                extcodecopy(
                    pointer,
                    add(contents, size),
                    start,
                    sub(end, start)
                )
                size := add(size, sub(end, start))
            }
        }

        // update contents size
        mstore(contents, sub(size, 0x20))
        // store contents
        mstore(0x40, add(contents, and(add(size, 0x1f), not(0x1f))))
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EAI721Intelligence, ERC721Upgradeable, Initializable} from "../extensions/EAI721Intelligence.sol";
import {EAI721Identity, IOnchainArtData} from "../extensions/EAI721Identity.sol";
import {EAI721Monetization} from "../extensions/EAI721Monetization.sol";
import {EAI721Tokenization} from "../extensions/EAI721Tokenization.sol";
import {Rating} from "../utils/Rating.sol";
import {Errors} from "../libs/helpers/Errors.sol";
import {LibString} from "solady/src/utils/LibString.sol";

contract CryptoAgents is
    Initializable,
    OwnableUpgradeable,
    EAI721Intelligence,
    EAI721Identity,
    EAI721Monetization,
    EAI721Tokenization,
    ERC2981Upgradeable,
    Rating
{
    // --- Constants ---
    uint256 private constant TOKEN_SUPPLY_LIMIT = 10000;

    // -- errors --
    error Unauthenticated();
    error InvalidTokenId();
    error InvalidFactoryAddress();

    // -- modifiers --
    modifier onlyAgentOwner(uint256 agentId)
        override(EAI721Intelligence, EAI721Tokenization, EAI721Monetization) {
        address agentOwner = ownerOf(agentId);

        if (
            msg.sender != agentOwner &&
            !checkAgentDelegate(msg.sender, agentOwner, agentId)
        ) revert Unauthenticated();

        _;
    }

    // -- events --
    event AdminAllowed(address indexed admin, bool allowed);
    event AgentDataAddressChanged(address indexed newAddr);

    // -- state variables --
    // admins
    mapping(address => bool) private _admins;

    modifier onlyAdmin() {
        require(_admins[msg.sender], Errors.ONLY_ADMIN_ALLOWED);
        _;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address defaultRoyaltyReceiver_
    ) public initializer {
        __Ownable_init();
        __ERC721_init(name_, symbol_);
        __EAI721Intelligence_init();
        __EAI721Identity_init();
        __Rating_init(100);
        __EAI721Monetization_init();
        __EAI721Tokenization_init();
        __ERC2981_init();

        _setDefaultRoyalty(defaultRoyaltyReceiver_, 500);
    }

    function allowAdmin(address newAdm, bool allow) external onlyOwner {
        require(newAdm != address(0), Errors.INV_ADD);
        _admins[newAdm] = allow;
        emit AdminAllowed(newAdm, allow);
    }

    function isAdmin(address admin) external view returns (bool) {
        return _admins[admin];
    }

    function changeAgentDataAddress(address newAddr) external onlyOwner {
        require(newAddr != address(0), Errors.INV_ADD);

        _setAgentDataAddr(newAddr);
        emit AgentDataAddressChanged(newAddr);
    }

    //@EAI721Identity
    function mint(
        uint256 tokenId,
        address to,
        uint256 dna,
        uint256[6] memory traits
    ) external virtual onlyAdmin {
        if (tokenId == 0 || tokenId > TOKEN_SUPPLY_LIMIT)
            revert InvalidTokenId();

        _mint(tokenId, to, dna, traits);
    }

    function tokenURI(
        uint256 agentId
    )
        public
        view
        override(ERC721Upgradeable, EAI721Identity)
        returns (string memory)
    {
        return EAI721Identity.tokenURI(agentId);
    }

    function agentAttributes(
        uint256 agentId
    ) external view returns (string memory) {
        return IOnchainArtData(agentDataAddr()).agentAttributes(agentId);
    }

    function agentImageSvg(
        uint256 agentId
    ) public view returns (string memory) {
        // Get the base SVG from the agent data contract
        string memory baseSvg = IOnchainArtData(agentDataAddr()).agentImageSvg(
            agentId
        );

        // Remove the data URI prefix if present
        string memory cleanSvg = LibString.replace(
            baseSvg,
            "data:image/svg+xml;utf8,",
            ""
        );

        // Add background rectangle and improve rendering
        string memory svgWithBackground = LibString.replace(
            cleanSvg,
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>",
            "<svg xmlns='http://www.w3.org/2000/svg' shape-rendering='crispEdges' viewBox='0 0 24 24'><rect width='24' height='24' fill='#636B96' />"
        );

        // Convert URL-encoded color codes to standard hex format
        return LibString.replace(svgWithBackground, "%23", "#");
    }

    function agentImage(uint256 agentId) external view returns (bytes memory) {
        return IOnchainArtData(agentDataAddr()).agentImage(agentId);
    }

    function setDefaultRoyalty(
        address newRoyaltyReceiver,
        uint96 feeNumerator
    ) external onlyAdmin {
        _setDefaultRoyalty(newRoyaltyReceiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyAdmin {
        _deleteDefaultRoyalty();
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address newRoyaltyReceiver,
        uint96 feeNumerator
    ) external onlyAdmin {
        _setTokenRoyalty(tokenId, newRoyaltyReceiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyAdmin {
        _resetTokenRoyalty(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            ERC2981Upgradeable.supportsInterface(interfaceId);
    }

    function setAgentFactory(address factory) public virtual onlyOwner {
        if (factory == address(0)) revert InvalidFactoryAddress();

        agentFactory = factory;
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721Upgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IOnchainArtData} from "../interfaces/IOnchainArtData.sol";

abstract contract EAI721Identity is Initializable, ERC721Upgradeable {
    // --- State Variables ---
    address private _agentDataAddr;

    // --- Errors ---
    error InvalidAddr();
    error NotExist();
    error Existed();

    // initialization
    function __EAI721Identity_init() internal onlyInitializing {
        __EAI721Identity_init_unchained();
    }
    function __EAI721Identity_init_unchained() internal onlyInitializing {}

    function _setAgentDataAddr(address newAgentDataAddr) internal virtual {
        _agentDataAddr = newAgentDataAddr;
    }

    function agentDataAddr() public view virtual returns (address) {
        return _agentDataAddr;
    }

    function _mint(
        uint256 tokenId,
        address to,
        uint256 dna,
        uint256[6] memory traits
    ) internal virtual {
        if (to == address(0) || _agentDataAddr == address(0))
            revert InvalidAddr();
        if (_exists(tokenId)) revert Existed();

        _safeMint(to, tokenId);
        IOnchainArtData agentDataContract = IOnchainArtData(_agentDataAddr);
        agentDataContract.mintAgent(tokenId);
        agentDataContract.unlockRenderAgent(tokenId, dna, traits);
    }

    // {IEAI721-tokenURI}
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory result) {
        if (!_exists(tokenId)) revert NotExist();
        IOnchainArtData agentDataContract = IOnchainArtData(_agentDataAddr);
        result = agentDataContract.tokenURI(tokenId);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     */
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721Upgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IAgentFactory} from "../agent-platform/interfaces/IAgentFactory.sol";
import {IAgent} from "../agent-platform/interfaces/IAgent.sol";
import {IEAI721Intelligence} from "../interfaces/IEAI721Intelligence.sol";
import {IDelegateRegistry} from "../interfaces/IDelegateRegistry.sol";

import "../libs/helpers/File.sol";

abstract contract EAI721Intelligence is
    Initializable,
    ERC721Upgradeable,
    IEAI721Intelligence
{
    using {read} for IFileStore.File;

    // --- Constants ---
    uint256 private constant TOKEN_LIMIT = 10000;
    bytes32 private constant IPFS_SIG = keccak256(bytes("ipfs"));
    address constant delegateRegistry =
        0x00000000000000447e69651d841bD8D104Bed493;
    bytes32 constant DELEGATE_RIGHT_ERC721 =
        0x0000000000000000000000000000000000000000000000000000000000000000;

    // --- Storage ---
    mapping(uint256 agentId => string) private _codeLanguage; // e.g., "python", "javascript"...
    mapping(uint256 agentId => uint16) private _currentVersion;

    mapping(uint256 agentId => string) private _name;

    mapping(bytes32 digest => bool) private _usedDigests;
    mapping(uint256 agentId => mapping(uint256 version => uint256))
        private _pointersNum;
    mapping(uint256 agentId => mapping(uint256 version => mapping(uint256 => CodePointer)))
        private _codePointers;
    mapping(uint256 agentId => mapping(uint256 version => uint256[]))
        private _depsAgents;

    address public agentFactory;

    modifier onlyAgentOwner(uint256 agentId) virtual {
        address agentOwner = ownerOf(agentId);

        if (
            msg.sender != agentOwner &&
            !checkAgentDelegate(msg.sender, agentOwner, agentId)
        ) revert EAI721IntelligenceAuth();

        _;
    }

    function checkAgentDelegate(
        address to,
        address from,
        uint256 agentId
    ) public view returns (bool) {
        return
            IDelegateRegistry(delegateRegistry).checkDelegateForERC721(
                to,
                from,
                address(this),
                agentId,
                DELEGATE_RIGHT_ERC721
            );
    }

    // --- Initialization ---
    function __EAI721Intelligence_init() internal onlyInitializing {}

    function __EAI721Intelligence_init_unchained() internal onlyInitializing {}

    // --- Functions ---

    // {IEAI721AgentAbility-setAgentName}
    function setAgentName(
        uint256 agentId,
        string calldata name
    ) public virtual onlyAgentOwner(agentId) {
        bytes32 agentIdBytes = _collectionIdToAgentId(agentId);

        if (agentIdBytes == bytes32(0)) {
            _name[agentId] = name;
        } else {
            IAgentFactory(agentFactory).setAgentName(agentIdBytes, name);
        }

        emit AgentNameSet(agentId, name);
    }

    // {IEAI721AgentAbility-agentName}
    function agentName(
        uint256 agentId
    ) public view virtual returns (string memory) {
        address agent = _collectionIdToAgentAddress(agentId);

        if (agent == address(0)) {
            return _name[agentId];
        } else {
            return IAgent(agent).getAgentName();
        }
    }

    // {IEAI721AgentAbility-publishAgentCode}
    function publishAgentCode(
        uint256 agentId,
        string calldata codeLanguageIn,
        CodePointer[] calldata pointersIn,
        address[] calldata depsAgentsIn
    ) public virtual onlyAgentOwner(agentId) returns (uint16) {
        bytes32 agentIdBytes = _collectionIdToAgentId(agentId);
        return
            IAgentFactory(agentFactory).publishAgentCode(
                agentIdBytes,
                codeLanguageIn,
                pointersIn,
                depsAgentsIn
            );
    }

    function _collectionIdToAgentId(
        uint256 collectionId
    ) internal view returns (bytes32) {
        return IAgentFactory(agentFactory).collectionIdToAgentId(collectionId);
    }

    function _collectionIdToAgentAddress(
        uint256 collectionId
    ) internal view returns (address) {
        return
            IAgentFactory(agentFactory).agents(
                _collectionIdToAgentId(collectionId)
            );
    }

    // {IEAI721AgentAbility-depsAgents}
    function depsAgents(
        uint256 agentId,
        uint16 version
    ) public view virtual returns (address[] memory) {
        return
            IAgent(_collectionIdToAgentAddress(agentId)).getDepsAgents(version);
    }

    // {IEAI721AgentAbility-agentCode}
    function agentCode(
        uint256 agentId,
        uint16 version
    ) public view virtual returns (string memory code) {
        return
            IAgent(_collectionIdToAgentAddress(agentId)).getAgentCode(version);
    }

    // {IEAI721AgentAbility-currentVersion}
    function currentVersion(
        uint256 agentId
    ) public view virtual returns (uint16) {
        address agent = _collectionIdToAgentAddress(agentId);

        if (agent == address(0)) {
            return 0;
        } else {
            return IAgent(agent).getCurrentVersion();
        }
    }

    // {IEAI721AgentAbility-codeLanguage}
    function codeLanguage(
        uint256 agentId
    ) public view virtual returns (string memory) {
        // return _codeLanguage[agentId];
        return IAgent(_collectionIdToAgentAddress(agentId)).getCodeLanguage();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     */
    uint256[43] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IEAI721Monetization} from "../interfaces/IEAI721Monetization.sol";

abstract contract EAI721Monetization is ERC721Upgradeable, IEAI721Monetization {
    // --- Modifiers ---
    modifier onlyAgentOwner(uint256 agentId) virtual {
        if (msg.sender != ownerOf(agentId)) revert EAI721MonetizationAuth();
        _;
    }

    // --- State Variables ---
    // agentId => subscription fee
    mapping(uint256 => uint256) private _subscriptionFees;

    // initialization
    function __EAI721Monetization_init() internal onlyInitializing {}

    function __EAI721Monetization_init_unchained() internal onlyInitializing {}

    // {IEAI721Monetization-subscriptionFee}
    function subscriptionFee(uint256 agentId) public virtual view returns (uint256) {
        return _subscriptionFees[agentId];
    }

    // {IEAI721Monetization-setSubscriptionFee}
    function setSubscriptionFee(uint256 agentId, uint256 fee) public virtual onlyAgentOwner(agentId) {
        _subscriptionFees[agentId] = fee;
        emit SubscriptionFeeUpdated(agentId, fee);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     */
    uint256[44] private __gap;
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721Upgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IEAI721Tokenization} from "../interfaces/IEAI721Tokenization.sol";

abstract contract EAI721Tokenization is Initializable, ERC721Upgradeable, IEAI721Tokenization  {
    // agentId => AI token address
    mapping(uint256 => address) private _aiTokens;

    modifier onlyAgentOwner(uint256 agentId) virtual {
        if (msg.sender != ownerOf(agentId)) revert EAI721TokenizationAuth();
        _;
    }

    // --- Initialization ---
    function __EAI721Tokenization_init() internal onlyInitializing {
    }

    function __EAI721Tokenization_init_unchained() internal onlyInitializing {
    }

    // {IEAI721Tokenization-setAITokenAddress}
    function setAITokenAddress(uint256 agentId, address newAIToken) public virtual onlyAgentOwner(agentId) {
        if (newAIToken == address(0)) revert InvalidAddress();
        _aiTokens[agentId] = newAIToken;

        emit AITokenAddressUpdated(agentId, newAIToken);
    }

    // {IEAI721Tokenization-aiToken}
    function aiToken(uint256 agentId) public virtual view returns (address) {
        return _aiTokens[agentId];
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     */
    uint256[44] private __gap;
}
// SPDX-License-Identifier: CC0-1.0
pragma solidity >=0.8.13;

/**
 * @title IDelegateRegistry
 * @custom:version 2.0
 * @custom:author foobar (0xfoobar)
 * @notice A standalone immutable registry storing delegated permissions from one address to another
 */
interface IDelegateRegistry {
    /// @notice Delegation type, NONE is used when a delegation does not exist or is revoked
    enum DelegationType {
        NONE,
        ALL,
        CONTRACT,
        ERC721,
        ERC20,
        ERC1155
    }

    /// @notice Struct for returning delegations
    struct Delegation {
        DelegationType type_;
        address to;
        address from;
        bytes32 rights;
        address contract_;
        uint256 tokenId;
        uint256 amount;
    }

    /// @notice Emitted when an address delegates or revokes rights for their entire wallet
    event DelegateAll(
        address indexed from,
        address indexed to,
        bytes32 rights,
        bool enable
    );

    /// @notice Emitted when an address delegates or revokes rights for a contract address
    event DelegateContract(
        address indexed from,
        address indexed to,
        address indexed contract_,
        bytes32 rights,
        bool enable
    );

    /// @notice Emitted when an address delegates or revokes rights for an ERC721 tokenId
    event DelegateERC721(
        address indexed from,
        address indexed to,
        address indexed contract_,
        uint256 tokenId,
        bytes32 rights,
        bool enable
    );

    /// @notice Emitted when an address delegates or revokes rights for an amount of ERC20 tokens
    event DelegateERC20(
        address indexed from,
        address indexed to,
        address indexed contract_,
        bytes32 rights,
        uint256 amount
    );

    /// @notice Emitted when an address delegates or revokes rights for an amount of an ERC1155 tokenId
    event DelegateERC1155(
        address indexed from,
        address indexed to,
        address indexed contract_,
        uint256 tokenId,
        bytes32 rights,
        uint256 amount
    );

    /// @notice Thrown if multicall calldata is malformed
    error MulticallFailed();

    /**
     * -----------  WRITE -----------
     */

    /**
     * @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
     * @param data The encoded function data for each of the calls to make to this contract
     * @return results The results from each of the calls passed in via data
     */
    function multicall(
        bytes[] calldata data
    ) external payable returns (bytes[] memory results);

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for all contracts
     * @param to The address to act as delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateAll(
        address to,
        bytes32 rights,
        bool enable
    ) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for a specific contract
     * @param to The address to act as delegate
     * @param contract_ The contract whose rights are being delegated
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateContract(
        address to,
        address contract_,
        bytes32 rights,
        bool enable
    ) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for a specific ERC721 token
     * @param to The address to act as delegate
     * @param contract_ The contract whose rights are being delegated
     * @param tokenId The token id to delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param enable Whether to enable or disable this delegation, true delegates and false revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC721(
        address to,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        bool enable
    ) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for a specific amount of ERC20 tokens
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     * @param to The address to act as delegate
     * @param contract_ The address for the fungible token contract
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param amount The amount to delegate, > 0 delegates and 0 revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC20(
        address to,
        address contract_,
        bytes32 rights,
        uint256 amount
    ) external payable returns (bytes32 delegationHash);

    /**
     * @notice Allow the delegate to act on behalf of `msg.sender` for a specific amount of ERC1155 tokens
     * @dev The actual amount is not encoded in the hash, just the existence of a amount (since it is an upper bound)
     * @param to The address to act as delegate
     * @param contract_ The address of the contract that holds the token
     * @param tokenId The token id to delegate
     * @param rights Specific subdelegation rights granted to the delegate, pass an empty bytestring to encompass all rights
     * @param amount The amount of that token id to delegate, > 0 delegates and 0 revokes
     * @return delegationHash The unique identifier of the delegation
     */
    function delegateERC1155(
        address to,
        address contract_,
        uint256 tokenId,
        bytes32 rights,
        uint256 amount
    ) external payable returns (bytes32 delegationHash);

    /**
     * ----------- CHECKS -----------
     */

    /**
     * @notice Check if `to` is a delegate of `from` for the entire wallet
     * @param to The potential delegate address
     * @param from The potential address who delegated rights
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return valid Whether delegate is granted to act on the from's behalf
     */
    function checkDelegateForAll(
        address to,
        address from,
        bytes32 rights
    ) external view returns (bool);

    /**
     * @notice Check if `to` is a delegate of `from` for the specified `contract_` or the entire wallet
     * @param to The delegated address to check
     * @param contract_ The specific contract address being checked
     * @param from The cold wallet who issued the delegation
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return valid Whether delegate is granted to act on from's behalf for entire wallet or that specific contract
     */
    function checkDelegateForContract(
        address to,
        address from,
        address contract_,
        bytes32 rights
    ) external view returns (bool);

    /**
     * @notice Check if `to` is a delegate of `from` for the specific `contract` and `tokenId`, the entire `contract_`, or the entire wallet
     * @param to The delegated address to check
     * @param contract_ The specific contract address being checked
     * @param tokenId The token id for the token to delegating
     * @param from The wallet that issued the delegation
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return valid Whether delegate is granted to act on from's behalf for entire wallet, that contract, or that specific tokenId
     */
    function checkDelegateForERC721(
        address to,
        address from,
        address contract_,
        uint256 tokenId,
        bytes32 rights
    ) external view returns (bool);

    /**
     * @notice Returns the amount of ERC20 tokens the delegate is granted rights to act on the behalf of
     * @param to The delegated address to check
     * @param contract_ The address of the token contract
     * @param from The cold wallet who issued the delegation
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return balance The delegated balance, which will be 0 if the delegation does not exist
     */
    function checkDelegateForERC20(
        address to,
        address from,
        address contract_,
        bytes32 rights
    ) external view returns (uint256);

    /**
     * @notice Returns the amount of a ERC1155 tokens the delegate is granted rights to act on the behalf of
     * @param to The delegated address to check
     * @param contract_ The address of the token contract
     * @param tokenId The token id to check the delegated amount of
     * @param from The cold wallet who issued the delegation
     * @param rights Specific rights to check for, pass the zero value to ignore subdelegations and check full delegations only
     * @return balance The delegated balance, which will be 0 if the delegation does not exist
     */
    function checkDelegateForERC1155(
        address to,
        address from,
        address contract_,
        uint256 tokenId,
        bytes32 rights
    ) external view returns (uint256);

    /**
     * ----------- ENUMERATIONS -----------
     */

    /**
     * @notice Returns all enabled delegations a given delegate has received
     * @param to The address to retrieve delegations for
     * @return delegations Array of Delegation structs
     */
    function getIncomingDelegations(
        address to
    ) external view returns (Delegation[] memory delegations);

    /**
     * @notice Returns all enabled delegations an address has given out
     * @param from The address to retrieve delegations for
     * @return delegations Array of Delegation structs
     */
    function getOutgoingDelegations(
        address from
    ) external view returns (Delegation[] memory delegations);

    /**
     * @notice Returns all hashes associated with enabled delegations an address has received
     * @param to The address to retrieve incoming delegation hashes for
     * @return delegationHashes Array of delegation hashes
     */
    function getIncomingDelegationHashes(
        address to
    ) external view returns (bytes32[] memory delegationHashes);

    /**
     * @notice Returns all hashes associated with enabled delegations an address has given out
     * @param from The address to retrieve outgoing delegation hashes for
     * @return delegationHashes Array of delegation hashes
     */
    function getOutgoingDelegationHashes(
        address from
    ) external view returns (bytes32[] memory delegationHashes);

    /**
     * @notice Returns the delegations for a given array of delegation hashes
     * @param delegationHashes is an array of hashes that correspond to delegations
     * @return delegations Array of Delegation structs, return empty structs for nonexistent or revoked delegations
     */
    function getDelegationsFromHashes(
        bytes32[] calldata delegationHashes
    ) external view returns (Delegation[] memory delegations);

    /**
     * ----------- STORAGE ACCESS -----------
     */

    /**
     * @notice Allows external contracts to read arbitrary storage slots
     */
    function readSlot(bytes32 location) external view returns (bytes32);

    /**
     * @notice Allows external contracts to read an arbitrary array of storage slots
     */
    function readSlots(
        bytes32[] calldata locations
    ) external view returns (bytes32[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEAI721Intelligence {
    // --- Enums ---
    enum FileType {
        LIBRARY,
        MAIN_SCRIPT
    }

    // --- Structs ---
    struct CodePointer {
        address retrieveAddress;
        FileType fileType;
        string fileName;
    }

    // --- Events ---
    event CodePointerCreated(
        uint256 indexed agentId,
        uint256 indexed version,
        uint256 indexed pIndex,
        CodePointer newPointer
    );

    event AgentNameSet(uint256 indexed agentId, string name);

    // --- Errors ---
    error EAI721IntelligenceAuth();
    error DigestAlreadyUsed();
    error InvalidData();
    error InvalidDependency();
    error InvalidVersion();

    /**
     * @dev Updates the name of a specific agent.
     * @param agentId The unique identifier of the agent.
     * @param name The new name to assign to the agent.
     */
    function setAgentName(uint256 agentId, string calldata name) external;

    /**
     * @dev Retrieves the name of a specific agent.
     * @param agentId The unique identifier of the agent.
     * @return The name of the agent.
     */
    function agentName(uint256 agentId) external view returns (string memory);

    /**
     * @dev Publishes the code for a specific agent.
     * @param agentId The unique identifier of the agent.
     * @param codeLanguage The programming language of the code.
     * @param pointers An array of code pointers for the agent.
     * @param depsAgents An array of dependent agent IDs.
     * @return The version number of the published code.
     */
    function publishAgentCode(
        uint256 agentId,
        string calldata codeLanguage,
        CodePointer[] calldata pointers,
        address[] calldata depsAgents
    ) external returns (uint16);

    /**
     * @dev Retrieves the dependent agent IDs for a specific agent and version.
     * @param agentId The unique identifier of the agent.
     * @param version The version number of the agent's code.
     * @return An array of dependent agent addresses.
     */
    function depsAgents(
        uint256 agentId,
        uint16 version
    ) external view returns (address[] memory);

    /**
     * @dev Retrieves the code of a specific agent for a given version.
     * @param agentId The unique identifier of the agent.
     * @param version The version number of the agent's code.
     * @return code The code of the agent.
     */
    function agentCode(
        uint256 agentId,
        uint16 version
    ) external view returns (string memory code);

    /**
     * @dev Retrieves the current version of a specific agent's code.
     * @param agentId The unique identifier of the agent.
     * @return The current version number of the agent's code.
     */
    function currentVersion(uint256 agentId) external view returns (uint16);

    /**
     * @dev Retrieves the programming language of a specific agent's code.
     * @param agentId The unique identifier of the agent.
     * @return The programming language of the agent's code.
     */
    function codeLanguage(
        uint256 agentId
    ) external view returns (string memory);

    /**
     * @dev Checks if a delegate has a specific right for an agent.
     * @param to The address to check the delegate for.
     * @param from The address of the owner of the agent.
     * @param agentId The unique identifier of the agent.
     */
    function checkAgentDelegate(
        address to,
        address from,
        uint256 agentId
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEAI721Monetization {

    // --- Errors ---
    error EAI721MonetizationAuth();

    // --- Events ---
    event SubscriptionFeeUpdated(uint256 indexed agentId, uint256 fee);

    /**
     * @dev Retrieves the subscription fee for a specific agent.
     * @param agentId The ID of the agent.
     * @return The subscription fee associated with the given agent.
     */
    function subscriptionFee(uint256 agentId) external view returns (uint256);

    /**
     * @dev Sets the subscription fee for a specific agent.
     * @param agentId The ID of the agent.
     * @param fee The subscription fee to be set for the agent.
     */
    function setSubscriptionFee(uint256 agentId, uint256 fee) external;
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IEAI721Tokenization {
    // --- Errors ---
    error EAI721TokenizationAuth();
    error InvalidAddress();

    // --- Events ---
    event AITokenAddressUpdated(uint256 indexed agentId, address indexed newAIToken);

    /**
     * @dev The AI token associated with a specific agent.
     * @param agentId The ID of the agent.
     * @return The address of the AI token for the given agent.
     */
    function aiToken(uint256 agentId) external view returns (address);

    /**
     * @dev Updates the AI token address for a specific agent.
     * @param agentId The ID of the agent.
     * @param newAIToken The new AI token address to be set for the agent.
     */
    function setAITokenAddress(uint256 agentId, address newAIToken) external;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title EthFS FileStore interface
/// @notice Specifies a content-addressable onchain file store
interface IFileStore {

    /**
     * @title EthFS File
     * @notice A representation of an onchain file, composed of slices of contract bytecode and utilities to construct the file contents from those slices.
     * @dev For best gas efficiency, it's recommended using `File.read()` as close to the output returned by the contract call as possible. Lots of gas is consumed every time a large data blob is passed between functions.
     */

    /**
     * @dev Represents a reference to a slice of bytecode in a contract
     */
    struct BytecodeSlice {
        address pointer;
        uint32 start;
        uint32 end;
    }

    /**
     * @dev Represents a file composed of one or more bytecode slices
     */
    struct File {
        // Total length of file contents (sum of all slice sizes). Useful when you want to use DynamicBuffer to build the file contents from the slices.
        uint256 size;
        BytecodeSlice[] slices;
    }

    event Deployed();

    /**
     * @dev Emitted when a new file is created
     * @param indexedFilename The indexed filename for easier finding by filename in logs
     * @param pointer The pointer address of the file
     * @param filename The name of the file
     * @param size The total size of the file
     * @param metadata Additional metadata of the file, only emitted for use in offchain indexers
     */
    event FileCreated(
        string indexed indexedFilename,
        address indexed pointer,
        string filename,
        uint256 size,
        bytes metadata
    );

    /**
     * @dev Error thrown when a requested file is not found
     * @param filename The name of the file requested
     */
    error FileNotFound(string filename);

    /**
     * @dev Error thrown when a filename already exists
     * @param filename The name of the file attempted to be created
     */
    error FilenameExists(string filename);

    /**
     * @dev Error thrown when attempting to create an empty file
     */
    error FileEmpty();

    /**
     * @dev Error thrown when a provided slice for a file is empty
     * @param pointer The contract address where the bytecode lives
     * @param start The byte offset to start the slice (inclusive)
     * @param end The byte offset to end the slice (exclusive)
     */
    error SliceEmpty(address pointer, uint32 start, uint32 end);

    /**
     * @dev Error thrown when the provided pointer's bytecode does not have the expected STOP opcode prefix from SSTORE2
     * @param pointer The SSTORE2 pointer address
     */
    error InvalidPointer(address pointer);

    /**
     * @notice Returns the address of the CREATE2 deterministic deployer used by this FileStore
     * @return The address of the CREATE2 deterministic deployer
     */
    function deployer() external view returns (address);

    /**
     * @notice Retrieves the pointer address of a file by its filename
     * @param filename The name of the file
     * @return pointer The pointer address of the file
     */
    function files(
        string memory filename
    ) external view returns (address pointer);

    /**
     * @notice Checks if a file exists for a given filename
     * @param filename The name of the file to check
     * @return True if the file exists, false otherwise
     */
    function fileExists(string memory filename) external view returns (bool);

    /**
     * @notice Retrieves the pointer address for a given filename
     * @param filename The name of the file
     * @return pointer The pointer address of the file
     */
    function getPointer(
        string memory filename
    ) external view returns (address pointer);

    /**
     * @notice Retrieves a file by its filename
     * @param filename The name of the file
     * @return file The file associated with the filename
     */
    function getFile(
        string memory filename
    ) external view returns (File memory file);

    /**
     * @notice Creates a new file with the provided file contents
     * @dev This is a convenience method to simplify small file uploads. It's recommended to use `createFileFromPointers` or `createFileFromSlices` for larger files. This particular method splits `contents` into 24575-byte chunks before storing them via SSTORE2.
     * @param filename The name of the new file
     * @param contents The contents of the file
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFile(
        string memory filename,
        string memory contents
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file with the provided file contents and file metadata
     * @dev This is a convenience method to simplify small file uploads. It's recommended to use `createFileFromPointers` or `createFileFromSlices` for larger files. This particular method splits `contents` into 24575-byte chunks before storing them via SSTORE2.
     * @param filename The name of the new file
     * @param contents The contents of the file
     * @param metadata Additional file metadata, usually a JSON-encoded string, for offchain indexers
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFile(
        string memory filename,
        string memory contents,
        bytes memory metadata
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file where its content is composed of the provided string chunks
     * @dev This is a convenience method to simplify small and nuanced file uploads. It's recommended to use `createFileFromPointers` or `createFileFromSlices` for larger files. This particular will store each chunk separately via SSTORE2. For best gas efficiency, each chunk should be as large as possible (up to the contract size limit) and at least 32 bytes.
     * @param filename The name of the new file
     * @param chunks The string chunks composing the file
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromChunks(
        string memory filename,
        string[] memory chunks
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file with the provided string chunks and file metadata
     * @dev This is a convenience method to simplify small and nuanced file uploads. It's recommended to use `createFileFromPointers` or `createFileFromSlices` for larger files. This particular will store each chunk separately via SSTORE2. For best gas efficiency, each chunk should be as large as possible (up to the contract size limit) and at least 32 bytes.
     * @param filename The name of the new file
     * @param chunks The string chunks composing the file
     * @param metadata Additional file metadata, usually a JSON-encoded string, for offchain indexers
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromChunks(
        string memory filename,
        string[] memory chunks,
        bytes memory metadata
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file where its content is composed of the provided SSTORE2 pointers
     * @param filename The name of the new file
     * @param pointers The SSTORE2 pointers composing the file
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromPointers(
        string memory filename,
        address[] memory pointers
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file with the provided SSTORE2 pointers and file metadata
     * @param filename The name of the new file
     * @param pointers The SSTORE2 pointers composing the file
     * @param metadata Additional file metadata, usually a JSON-encoded string, for offchain indexers
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromPointers(
        string memory filename,
        address[] memory pointers,
        bytes memory metadata
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file where its content is composed of the provided bytecode slices
     * @param filename The name of the new file
     * @param slices The bytecode slices composing the file
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromSlices(
        string memory filename,
        BytecodeSlice[] memory slices
    ) external returns (address pointer, File memory file);

    /**
     * @notice Creates a new file with the provided bytecode slices and file metadata
     * @param filename The name of the new file
     * @param slices The bytecode slices composing the file
     * @param metadata Additional file metadata, usually a JSON-encoded string, for offchain indexers
     * @return pointer The pointer address of the new file
     * @return file The newly created file
     */
    function createFileFromSlices(
        string memory filename,
        BytecodeSlice[] memory slices,
        bytes memory metadata
    ) external returns (address pointer, File memory file);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IOnchainArtData {
    /**
     * @notice Returns the metadata URI for a given token ID.
     * @param tokenId The ID of the token to query.
     * @return result The metadata URI as a string.
     */
    function tokenURI(
        uint256 tokenId
    ) external view returns (string memory result);

    /**
     * @notice Mints a new agent with the specified token ID.
     * @param tokenId The ID of the token to mint.
     */
    function mintAgent(uint256 tokenId) external;

    /**
     * @notice Unlocks the render agent for a given token, setting its DNA and traits.
     * @param tokenId The ID of the token to unlock.
     * @param dna The DNA value to assign to the agent.
     * @param traits An array of 5 trait values to assign to the agent.
     */
    function unlockRenderAgent(
        uint256 tokenId,
        uint256 dna,
        uint256[6] memory traits
    ) external;

    /**
     * @notice Returns the attributes of an agent.
     * @param agentId The ID of the agent to query.
     * @return result The attributes of the agent as a string.
     */
    function agentAttributes(
        uint256 agentId
    ) external view returns (string memory result);

    /**
     * @notice Returns the SVG image of an agent in svg format.
     * @param agentId The ID of the agent to query.
     * @return result The SVG image of the agent as a string.
     */
    function agentImageSvg(
        uint256 agentId
    ) external view returns (string memory result);

    /**
     * @notice Returns the image of an agent in bytes format.
     * @param agentId The ID of the agent to query.
     * @return result The image of the agent as a bytes.
     */
    function agentImage(
        uint256 agentId
    ) external view returns (bytes memory result);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRating {
    // --- Events ---
    event Rated(
        address indexed user,
        uint256 indexed agentId,
        uint8 indexed stars,
        uint256 newTotalStarsSum,
        uint256 newTotalRatingCount
    );

    // --- Custom Errors ---
    error RatingOutOfRange(uint8 stars);

    // --- State-Changing Functions ---
    function rateStar(uint256 agentId, uint8 stars) external;

    // --- View functions ---
    function ratingScore(uint256 agentId) external view returns (uint256);
    function ratingCount(uint256 agentId) external view returns (uint256);
    function ratingMultiplier() external view returns (uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.12;

library Errors {
    enum ReturnCode {
        SUCCESS,
        FAILED
    }

    string public constant SUCCESS = "0";


    // common errors
    string public constant INV_ADD = "100";
    string public constant ONLY_ADMIN_ALLOWED = "101";
    string public constant ONLY_CREATOR = "102";
    string public constant ONLY_DEPLOYER = "103";
    string public constant ONLY_AGENT_CONTRACT = "104";
    string public constant INVALID_ITEM_TYPE = "105";
    string public constant ITEM_NOT_EXIST = "106";

    // validation error
    string public constant MISSING_NAME = "200";
    string public constant INV_FEE_PROJECT = "201";
    string public constant INV_PROJECT = "202";
    string public constant REACH_MAX = "203";
    string public constant INV_PARAMS = "204";
    string public constant TOO_HIGH = "205";
    string public constant TOKEN_HAS_SEED = "206";
    string public constant ZERO_SEED = "207";
    string public constant OPENING_SCHEDULE = "208";
    string public constant INV_TOKEN = "209";
    string public constant FORBIDDEN_TRANSFER_PROJECT = "210";
    string public constant ONLY_GENERATIVE_PROJECT = "211";

    // validator market error
    string public constant INVALID_ERC721_OWNER = "300";
    string public constant ERC_721_NOT_APPROVED = "301";
    string public constant OFFERING_CLOSED = "302";
    string public constant VALUE_INVALID = "303";
    string public constant ERC20_BALANCE_INVALID = "304";
    string public constant ERC20_NOT_APPROVED = "305";
    string public constant TRANSFER_FAIL = "306";
    string public constant ERC_20_NOT_ALLOW = "307";
    string public constant ZERO_PRICE = "308";
    string public constant ZERO_DURATION = "309";

    // GEN Token
    string public constant POA_INVALID_TOKEN = "400";
    string public constant TEAM_VESTING_ERROR_ADDR = "401";
    string public constant DAO_VESTING_ERROR_ADDR = "402";
    string public constant VESTING_TIME_LOCK = "403";
    string public constant VESTING_REMAIN = "404";

    string public constant CONTRACT_SEALED = "500";
    string public constant TOKEN_ID_NOT_UNLOCKED = "501"; // agent not really minted on AI agent contract -> still in queue because not reach threadhold
    string public constant TOKEN_ID_UNLOCKED = "502";
    string public constant USED_PAIRs = "503";
    string public constant TOKEN_ID_NOT_EXISTED = "504";
    string public constant WEIGHT_OUT = "505";
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IFileStore} from "../../interfaces/IFileStore.sol";

/**
 * @dev Error thrown when a slice is out of the bounds of the contract's bytecode
 */
error SliceOutOfBounds(
    address pointer,
    uint32 codeSize,
    uint32 sliceStart,
    uint32 sliceEnd
);

/**
 * @notice Reads the contents of a file by concatenating its slices
 * @param file The file to read
 * @return contents The concatenated contents of the file
 */
function read(IFileStore.File memory file) view returns (string memory contents) {
    IFileStore.BytecodeSlice[] memory slices = file.slices;
    bytes4 sliceOutOfBoundsSelector = SliceOutOfBounds.selector;

    assembly {
        let len := mload(slices)
        let size := 0x20
        contents := mload(0x40)
        let slice
        let pointer
        let start
        let end
        let codeSize

        for {
            let i := 0
        } lt(i, len) {
            i := add(i, 1)
        } {
            slice := mload(add(slices, add(0x20, mul(i, 0x20))))
            pointer := mload(slice)
            start := mload(add(slice, 0x20))
            end := mload(add(slice, 0x40))

            codeSize := extcodesize(pointer)
            if gt(end, codeSize) {
                mstore(0x00, sliceOutOfBoundsSelector)
                mstore(0x04, pointer)
                mstore(0x24, codeSize)
                mstore(0x44, start)
                mstore(0x64, end)
                revert(0x00, 0x84)
            }

            extcodecopy(pointer, add(contents, size), start, sub(end, start))
            size := add(size, sub(end, start))
        }

        // update contents size
        mstore(contents, sub(size, 0x20))
        // store contents
        mstore(0x40, add(contents, and(add(size, 0x1f), not(0x1f))))
    }
}

/**
 * @notice Reads the contents of a file without reverting on unreadable/invalid slices. Skips any slices that are out of bounds or invalid. Useful if you are composing contract bytecode where a contract can still selfdestruct (which would result in an invalid slice) and want to avoid reverts but still output potentially "corrupted" file contents (due to missing data).
 * @param file The file to read
 * @return contents The concatenated contents of the file, skipping invalid slices
 */
function readUnchecked(IFileStore.File memory file) view returns (string memory contents) {
    IFileStore.BytecodeSlice[] memory slices = file.slices;

    assembly {
        let len := mload(slices)
        let size := 0x20
        contents := mload(0x40)
        let slice
        let pointer
        let start
        let end
        let codeSize

        for {
            let i := 0
        } lt(i, len) {
            i := add(i, 1)
        } {
            slice := mload(add(slices, add(0x20, mul(i, 0x20))))
            pointer := mload(slice)
            start := mload(add(slice, 0x20))
            end := mload(add(slice, 0x40))

            codeSize := extcodesize(pointer)
            if lt(end, codeSize) {
                extcodecopy(
                    pointer,
                    add(contents, size),
                    start,
                    sub(end, start)
                )
                size := add(size, sub(end, start))
            }
        }

        // update contents size
        mstore(contents, sub(size, 0x20))
        // store contents
        mstore(0x40, add(contents, and(add(size, 0x1f), not(0x1f))))
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IRating} from "../interfaces/IRating.sol";

abstract contract Rating is Initializable, IRating {
    // --- Constants ---
    uint8 private constant MAX_RATING = 5;
    uint8 private constant MIN_RATING = 1;

    // --- Storage ---
    uint256 private _ratingMultiplier;
    mapping(uint256 agentId => uint256) private _totalStars;
    mapping(uint256 agentId => uint256) private _totalRatingCount;

    // --- Initialization ---
    function __Rating_init(
        uint256 ratingMultiplier_
    ) internal onlyInitializing {
        __Rating_init_unchained(ratingMultiplier_);
    }

    function __Rating_init_unchained(
        uint256 ratingMultiplier_
    ) internal onlyInitializing {
        _ratingMultiplier = ratingMultiplier_;
    }

    // --- Functions ---
    function rateStar(uint256 agentId, uint8 stars) external virtual {
        if (stars < MIN_RATING || stars > MAX_RATING) {
            revert RatingOutOfRange(stars);
        }
        // Add new rating
        _totalStars[agentId] += stars;
        _totalRatingCount[agentId]++;

        emit Rated(
            msg.sender,
            agentId,
            stars,
            _totalStars[agentId],
            _totalRatingCount[agentId]
        );
    }

    function ratingScore(
        uint256 agentId
    ) external view virtual returns (uint256) {
        if (_totalRatingCount[agentId] == 0) {
            return 0;
        }
        // Multiply by 100 for 2 decimal places
        // 451 means 4.51
        return
            (_totalStars[agentId] * _ratingMultiplier) /
            _totalRatingCount[agentId];
    }

    function ratingMultiplier() external view virtual returns (uint256) {
        return _ratingMultiplier;
    }

    function ratingCount(
        uint256 agentId
    ) external view virtual returns (uint256) {
        return _totalRatingCount[agentId];
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     */
    uint256[10] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for byte related operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibBytes.sol)
library LibBytes {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Goated bytes storage struct that totally MOGs, no cap, fr.
    /// Uses less gas and bytecode than Solidity's native bytes storage. It's meta af.
    /// Packs length with the first 31 bytes if <255 bytes, so it’s mad tight.
    struct BytesStorage {
        bytes32 _spacer;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when the `search` is not found in the bytes.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  BYTE STORAGE OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sets the value of the bytes storage `$` to `s`.
    function set(BytesStorage storage $, bytes memory s) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(s)
            let packed := or(0xff, shl(8, n))
            for { let i := 0 } 1 {} {
                if iszero(gt(n, 0xfe)) {
                    i := 0x1f
                    packed := or(n, shl(8, mload(add(s, i))))
                    if iszero(gt(n, i)) { break }
                }
                let o := add(s, 0x20)
                mstore(0x00, $.slot)
                for { let p := keccak256(0x00, 0x20) } 1 {} {
                    sstore(add(p, shr(5, i)), mload(add(o, i)))
                    i := add(i, 0x20)
                    if iszero(lt(i, n)) { break }
                }
                break
            }
            sstore($.slot, packed)
        }
    }

    /// @dev Sets the value of the bytes storage `$` to `s`.
    function setCalldata(BytesStorage storage $, bytes calldata s) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let packed := or(0xff, shl(8, s.length))
            for { let i := 0 } 1 {} {
                if iszero(gt(s.length, 0xfe)) {
                    i := 0x1f
                    packed := or(s.length, shl(8, shr(8, calldataload(s.offset))))
                    if iszero(gt(s.length, i)) { break }
                }
                mstore(0x00, $.slot)
                for { let p := keccak256(0x00, 0x20) } 1 {} {
                    sstore(add(p, shr(5, i)), calldataload(add(s.offset, i)))
                    i := add(i, 0x20)
                    if iszero(lt(i, s.length)) { break }
                }
                break
            }
            sstore($.slot, packed)
        }
    }

    /// @dev Sets the value of the bytes storage `$` to the empty bytes.
    function clear(BytesStorage storage $) internal {
        delete $._spacer;
    }

    /// @dev Returns whether the value stored is `$` is the empty bytes "".
    function isEmpty(BytesStorage storage $) internal view returns (bool) {
        return uint256($._spacer) & 0xff == uint256(0);
    }

    /// @dev Returns the length of the value stored in `$`.
    function length(BytesStorage storage $) internal view returns (uint256 result) {
        result = uint256($._spacer);
        /// @solidity memory-safe-assembly
        assembly {
            let n := and(0xff, result)
            result := or(mul(shr(8, result), eq(0xff, n)), mul(n, iszero(eq(0xff, n))))
        }
    }

    /// @dev Returns the value stored in `$`.
    function get(BytesStorage storage $) internal view returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let o := add(result, 0x20)
            let packed := sload($.slot)
            let n := shr(8, packed)
            for { let i := 0 } 1 {} {
                if iszero(eq(or(packed, 0xff), packed)) {
                    mstore(o, packed)
                    n := and(0xff, packed)
                    i := 0x1f
                    if iszero(gt(n, i)) { break }
                }
                mstore(0x00, $.slot)
                for { let p := keccak256(0x00, 0x20) } 1 {} {
                    mstore(add(o, i), sload(add(p, shr(5, i))))
                    i := add(i, 0x20)
                    if iszero(lt(i, n)) { break }
                }
                break
            }
            mstore(result, n) // Store the length of the memory.
            mstore(add(o, n), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(o, n), 0x20)) // Allocate memory.
        }
    }

    /// @dev Returns the uint8 at index `i`. If out-of-bounds, returns 0.
    function uint8At(BytesStorage storage $, uint256 i) internal view returns (uint8 result) {
        /// @solidity memory-safe-assembly
        assembly {
            for { let packed := sload($.slot) } 1 {} {
                if iszero(eq(or(packed, 0xff), packed)) {
                    if iszero(gt(i, 0x1e)) {
                        result := byte(i, packed)
                        break
                    }
                    if iszero(gt(i, and(0xff, packed))) {
                        mstore(0x00, $.slot)
                        let j := sub(i, 0x1f)
                        result := byte(and(j, 0x1f), sload(add(keccak256(0x00, 0x20), shr(5, j))))
                    }
                    break
                }
                if iszero(gt(i, shr(8, packed))) {
                    mstore(0x00, $.slot)
                    result := byte(and(i, 0x1f), sload(add(keccak256(0x00, 0x20), shr(5, i))))
                }
                break
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      BYTES OPERATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `subject` all occurrences of `needle` replaced with `replacement`.
    function replace(bytes memory subject, bytes memory needle, bytes memory replacement)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let needleLen := mload(needle)
            let replacementLen := mload(replacement)
            let d := sub(result, subject) // Memory difference.
            let i := add(subject, 0x20) // Subject bytes pointer.
            mstore(0x00, add(i, mload(subject))) // End of subject.
            if iszero(gt(needleLen, mload(subject))) {
                let subjectSearchEnd := add(sub(mload(0x00), needleLen), 1)
                let h := 0 // The hash of `needle`.
                if iszero(lt(needleLen, 0x20)) { h := keccak256(add(needle, 0x20), needleLen) }
                let s := mload(add(needle, 0x20))
                for { let m := shl(3, sub(0x20, and(needleLen, 0x1f))) } 1 {} {
                    let t := mload(i)
                    // Whether the first `needleLen % 32` bytes of `subject` and `needle` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(i, needleLen), h)) {
                                mstore(add(i, d), t)
                                i := add(i, 1)
                                if iszero(lt(i, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Copy the `replacement` one word at a time.
                        for { let j := 0 } 1 {} {
                            mstore(add(add(i, d), j), mload(add(add(replacement, 0x20), j)))
                            j := add(j, 0x20)
                            if iszero(lt(j, replacementLen)) { break }
                        }
                        d := sub(add(d, replacementLen), needleLen)
                        if needleLen {
                            i := add(i, needleLen)
                            if iszero(lt(i, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    mstore(add(i, d), t)
                    i := add(i, 1)
                    if iszero(lt(i, subjectSearchEnd)) { break }
                }
            }
            let end := mload(0x00)
            let n := add(sub(d, add(result, 0x20)), end)
            // Copy the rest of the bytes one word at a time.
            for {} lt(i, end) { i := add(i, 0x20) } { mstore(add(i, d), mload(i)) }
            let o := add(i, d)
            mstore(o, 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from left to right, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function indexOf(bytes memory subject, bytes memory needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := not(0) // Initialize to `NOT_FOUND`.
            for { let subjectLen := mload(subject) } 1 {} {
                if iszero(mload(needle)) {
                    result := from
                    if iszero(gt(from, subjectLen)) { break }
                    result := subjectLen
                    break
                }
                let needleLen := mload(needle)
                let subjectStart := add(subject, 0x20)

                subject := add(subjectStart, from)
                let end := add(sub(add(subjectStart, subjectLen), needleLen), 1)
                let m := shl(3, sub(0x20, and(needleLen, 0x1f)))
                let s := mload(add(needle, 0x20))

                if iszero(and(lt(subject, end), lt(from, subjectLen))) { break }

                if iszero(lt(needleLen, 0x20)) {
                    for { let h := keccak256(add(needle, 0x20), needleLen) } 1 {} {
                        if iszero(shr(m, xor(mload(subject), s))) {
                            if eq(keccak256(subject, needleLen), h) {
                                result := sub(subject, subjectStart)
                                break
                            }
                        }
                        subject := add(subject, 1)
                        if iszero(lt(subject, end)) { break }
                    }
                    break
                }
                for {} 1 {} {
                    if iszero(shr(m, xor(mload(subject), s))) {
                        result := sub(subject, subjectStart)
                        break
                    }
                    subject := add(subject, 1)
                    if iszero(lt(subject, end)) { break }
                }
                break
            }
        }
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from left to right.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function indexOf(bytes memory subject, bytes memory needle) internal pure returns (uint256) {
        return indexOf(subject, needle, 0);
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from right to left, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function lastIndexOf(bytes memory subject, bytes memory needle, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            for {} 1 {} {
                result := not(0) // Initialize to `NOT_FOUND`.
                let needleLen := mload(needle)
                if gt(needleLen, mload(subject)) { break }
                let w := result

                let fromMax := sub(mload(subject), needleLen)
                if iszero(gt(fromMax, from)) { from := fromMax }

                let end := add(add(subject, 0x20), w)
                subject := add(add(subject, 0x20), from)
                if iszero(gt(subject, end)) { break }
                // As this function is not too often used,
                // we shall simply use keccak256 for smaller bytecode size.
                for { let h := keccak256(add(needle, 0x20), needleLen) } 1 {} {
                    if eq(keccak256(subject, needleLen), h) {
                        result := sub(subject, add(end, 1))
                        break
                    }
                    subject := add(subject, w) // `sub(subject, 1)`.
                    if iszero(gt(subject, end)) { break }
                }
                break
            }
        }
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from right to left.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function lastIndexOf(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (uint256)
    {
        return lastIndexOf(subject, needle, type(uint256).max);
    }

    /// @dev Returns true if `needle` is found in `subject`, false otherwise.
    function contains(bytes memory subject, bytes memory needle) internal pure returns (bool) {
        return indexOf(subject, needle) != NOT_FOUND;
    }

    /// @dev Returns whether `subject` starts with `needle`.
    function startsWith(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(needle)
            // Just using keccak256 directly is actually cheaper.
            let t := eq(keccak256(add(subject, 0x20), n), keccak256(add(needle, 0x20), n))
            result := lt(gt(n, mload(subject)), t)
        }
    }

    /// @dev Returns whether `subject` ends with `needle`.
    function endsWith(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(needle)
            let notInRange := gt(n, mload(subject))
            // `subject + 0x20 + max(subject.length - needle.length, 0)`.
            let t := add(add(subject, 0x20), mul(iszero(notInRange), sub(mload(subject), n)))
            // Just using keccak256 directly is actually cheaper.
            result := gt(eq(keccak256(t, n), keccak256(add(needle, 0x20), n)), notInRange)
        }
    }

    /// @dev Returns `subject` repeated `times`.
    function repeat(bytes memory subject, uint256 times)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let l := mload(subject) // Subject length.
            if iszero(or(iszero(times), iszero(l))) {
                result := mload(0x40)
                subject := add(subject, 0x20)
                let o := add(result, 0x20)
                for {} 1 {} {
                    // Copy the `subject` one word at a time.
                    for { let j := 0 } 1 {} {
                        mstore(add(o, j), mload(add(subject, j)))
                        j := add(j, 0x20)
                        if iszero(lt(j, l)) { break }
                    }
                    o := add(o, l)
                    times := sub(times, 1)
                    if iszero(times) { break }
                }
                mstore(o, 0) // Zeroize the slot after the bytes.
                mstore(0x40, add(o, 0x20)) // Allocate memory.
                mstore(result, sub(o, add(result, 0x20))) // Store the length.
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function slice(bytes memory subject, uint256 start, uint256 end)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let l := mload(subject) // Subject length.
            if iszero(gt(l, end)) { end := l }
            if iszero(gt(l, start)) { start := l }
            if lt(start, end) {
                result := mload(0x40)
                let n := sub(end, start)
                let i := add(subject, start)
                let w := not(0x1f)
                // Copy the `subject` one word at a time, backwards.
                for { let j := and(add(n, 0x1f), w) } 1 {} {
                    mstore(add(result, j), mload(add(i, j)))
                    j := add(j, w) // `sub(j, 0x20)`.
                    if iszero(j) { break }
                }
                let o := add(add(result, 0x20), n)
                mstore(o, 0) // Zeroize the slot after the bytes.
                mstore(0x40, add(o, 0x20)) // Allocate memory.
                mstore(result, n) // Store the length.
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the bytes.
    /// `start` is a byte offset.
    function slice(bytes memory subject, uint256 start)
        internal
        pure
        returns (bytes memory result)
    {
        result = slice(subject, start, type(uint256).max);
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets. Faster than Solidity's native slicing.
    function sliceCalldata(bytes calldata subject, uint256 start, uint256 end)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            end := xor(end, mul(xor(end, subject.length), lt(subject.length, end)))
            start := xor(start, mul(xor(start, subject.length), lt(subject.length, start)))
            result.offset := add(subject.offset, start)
            result.length := mul(lt(start, end), sub(end, start))
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the bytes.
    /// `start` is a byte offset. Faster than Solidity's native slicing.
    function sliceCalldata(bytes calldata subject, uint256 start)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            start := xor(start, mul(xor(start, subject.length), lt(subject.length, start)))
            result.offset := add(subject.offset, start)
            result.length := mul(lt(start, subject.length), sub(subject.length, start))
        }
    }

    /// @dev Reduces the size of `subject` to `n`.
    /// If `n` is greater than the size of `subject`, this will be a no-op.
    function truncate(bytes memory subject, uint256 n)
        internal
        pure
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := subject
            mstore(mul(lt(n, mload(result)), result), n)
        }
    }

    /// @dev Returns a copy of `subject`, with the length reduced to `n`.
    /// If `n` is greater than the size of `subject`, this will be a no-op.
    function truncatedCalldata(bytes calldata subject, uint256 n)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result.offset := subject.offset
            result.length := xor(n, mul(xor(n, subject.length), lt(subject.length, n)))
        }
    }

    /// @dev Returns all the indices of `needle` in `subject`.
    /// The indices are byte offsets.
    function indicesOf(bytes memory subject, bytes memory needle)
        internal
        pure
        returns (uint256[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let searchLen := mload(needle)
            if iszero(gt(searchLen, mload(subject))) {
                result := mload(0x40)
                let i := add(subject, 0x20)
                let o := add(result, 0x20)
                let subjectSearchEnd := add(sub(add(i, mload(subject)), searchLen), 1)
                let h := 0 // The hash of `needle`.
                if iszero(lt(searchLen, 0x20)) { h := keccak256(add(needle, 0x20), searchLen) }
                let s := mload(add(needle, 0x20))
                for { let m := shl(3, sub(0x20, and(searchLen, 0x1f))) } 1 {} {
                    let t := mload(i)
                    // Whether the first `searchLen % 32` bytes of `subject` and `needle` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(i, searchLen), h)) {
                                i := add(i, 1)
                                if iszero(lt(i, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        mstore(o, sub(i, add(subject, 0x20))) // Append to `result`.
                        o := add(o, 0x20)
                        i := add(i, searchLen) // Advance `i` by `searchLen`.
                        if searchLen {
                            if iszero(lt(i, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    i := add(i, 1)
                    if iszero(lt(i, subjectSearchEnd)) { break }
                }
                mstore(result, shr(5, sub(o, add(result, 0x20)))) // Store the length of `result`.
                // Allocate memory for result.
                // We allocate one more word, so this array can be recycled for {split}.
                mstore(0x40, add(o, 0x20))
            }
        }
    }

    /// @dev Returns an arrays of bytess based on the `delimiter` inside of the `subject` bytes.
    function split(bytes memory subject, bytes memory delimiter)
        internal
        pure
        returns (bytes[] memory result)
    {
        uint256[] memory indices = indicesOf(subject, delimiter);
        /// @solidity memory-safe-assembly
        assembly {
            let w := not(0x1f)
            let indexPtr := add(indices, 0x20)
            let indicesEnd := add(indexPtr, shl(5, add(mload(indices), 1)))
            mstore(add(indicesEnd, w), mload(subject))
            mstore(indices, add(mload(indices), 1))
            for { let prevIndex := 0 } 1 {} {
                let index := mload(indexPtr)
                mstore(indexPtr, 0x60)
                if iszero(eq(index, prevIndex)) {
                    let element := mload(0x40)
                    let l := sub(index, prevIndex)
                    mstore(element, l) // Store the length of the element.
                    // Copy the `subject` one word at a time, backwards.
                    for { let o := and(add(l, 0x1f), w) } 1 {} {
                        mstore(add(element, o), mload(add(add(subject, prevIndex), o)))
                        o := add(o, w) // `sub(o, 0x20)`.
                        if iszero(o) { break }
                    }
                    mstore(add(add(element, 0x20), l), 0) // Zeroize the slot after the bytes.
                    // Allocate memory for the length and the bytes, rounded up to a multiple of 32.
                    mstore(0x40, add(element, and(add(l, 0x3f), w)))
                    mstore(indexPtr, element) // Store the `element` into the array.
                }
                prevIndex := add(index, mload(delimiter))
                indexPtr := add(indexPtr, 0x20)
                if iszero(lt(indexPtr, indicesEnd)) { break }
            }
            result := indices
            if iszero(mload(delimiter)) {
                result := add(indices, 0x20)
                mstore(result, sub(mload(indices), 2))
            }
        }
    }

    /// @dev Returns a concatenated bytes of `a` and `b`.
    /// Cheaper than `bytes.concat()` and does not de-align the free memory pointer.
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let w := not(0x1f)
            let aLen := mload(a)
            // Copy `a` one word at a time, backwards.
            for { let o := and(add(aLen, 0x20), w) } 1 {} {
                mstore(add(result, o), mload(add(a, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) { break }
            }
            let bLen := mload(b)
            let output := add(result, aLen)
            // Copy `b` one word at a time, backwards.
            for { let o := and(add(bLen, 0x20), w) } 1 {} {
                mstore(add(output, o), mload(add(b, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) { break }
            }
            let totalLen := add(aLen, bLen)
            let last := add(add(result, 0x20), totalLen)
            mstore(last, 0) // Zeroize the slot after the bytes.
            mstore(result, totalLen) // Store the length.
            mstore(0x40, add(last, 0x20)) // Allocate memory.
        }
    }

    /// @dev Returns whether `a` equals `b`.
    function eq(bytes memory a, bytes memory b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }

    /// @dev Returns whether `a` equals `b`, where `b` is a null-terminated small bytes.
    function eqs(bytes memory a, bytes32 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            // These should be evaluated on compile time, as far as possible.
            let m := not(shl(7, div(not(iszero(b)), 255))) // `0x7f7f ...`.
            let x := not(or(m, or(b, add(m, and(b, m)))))
            let r := shl(7, iszero(iszero(shr(128, x))))
            r := or(r, shl(6, iszero(iszero(shr(64, shr(r, x))))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            result := gt(eq(mload(a), add(iszero(x), xor(31, shr(3, r)))),
                xor(shr(add(8, r), b), shr(add(8, r), mload(add(a, 0x20)))))
        }
    }

    /// @dev Returns 0 if `a == b`, -1 if `a < b`, +1 if `a > b`.
    /// If `a` == b[:a.length]`, and `a.length < b.length`, returns -1.
    function cmp(bytes memory a, bytes memory b) internal pure returns (int256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let aLen := mload(a)
            let bLen := mload(b)
            let n := and(xor(aLen, mul(xor(aLen, bLen), lt(bLen, aLen))), not(0x1f))
            if n {
                for { let i := 0x20 } 1 {} {
                    let x := mload(add(a, i))
                    let y := mload(add(b, i))
                    if iszero(or(xor(x, y), eq(i, n))) {
                        i := add(i, 0x20)
                        continue
                    }
                    result := sub(gt(x, y), lt(x, y))
                    break
                }
            }
            // forgefmt: disable-next-item
            if iszero(result) {
                let l := 0x201f1e1d1c1b1a191817161514131211100f0e0d0c0b0a090807060504030201
                let x := and(mload(add(add(a, 0x20), n)), shl(shl(3, byte(sub(aLen, n), l)), not(0)))
                let y := and(mload(add(add(b, 0x20), n)), shl(shl(3, byte(sub(bLen, n), l)), not(0)))
                result := sub(gt(x, y), lt(x, y))
                if iszero(result) { result := sub(gt(aLen, bLen), lt(aLen, bLen)) }
            }
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(bytes memory a) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            // Assumes that the bytes does not start from the scratch space.
            let retStart := sub(a, 0x20)
            let retUnpaddedSize := add(mload(a), 0x40)
            // Right pad with zeroes. Just in case the bytes is produced
            // by a method that doesn't zero right pad.
            mstore(add(retStart, retUnpaddedSize), 0)
            mstore(retStart, 0x20) // Store the return offset.
            // End the transaction, returning the bytes.
            return(retStart, and(not(0x1f), add(0x1f, retUnpaddedSize)))
        }
    }

    /// @dev Directly returns `a` with minimal copying.
    function directReturn(bytes[] memory a) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(a) // `a.length`.
            let o := add(a, 0x20) // Start of elements in `a`.
            let u := a // Highest memory slot.
            let w := not(0x1f)
            for { let i := 0 } iszero(eq(i, n)) { i := add(i, 1) } {
                let c := add(o, shl(5, i)) // Location of pointer to `a[i]`.
                let s := mload(c) // `a[i]`.
                let l := mload(s) // `a[i].length`.
                let r := and(l, 0x1f) // `a[i].length % 32`.
                let z := add(0x20, and(l, w)) // Offset of last word in `a[i]` from `s`.
                // If `s` comes before `o`, or `s` is not zero right padded.
                if iszero(lt(lt(s, o), or(iszero(r), iszero(shl(shl(3, r), mload(add(s, z))))))) {
                    let m := mload(0x40)
                    mstore(m, l) // Copy `a[i].length`.
                    for {} 1 {} {
                        mstore(add(m, z), mload(add(s, z))) // Copy `a[i]`, backwards.
                        z := add(z, w) // `sub(z, 0x20)`.
                        if iszero(z) { break }
                    }
                    let e := add(add(m, 0x20), l)
                    mstore(e, 0) // Zeroize the slot after the copied bytes.
                    mstore(0x40, add(e, 0x20)) // Allocate memory.
                    s := m
                }
                mstore(c, sub(s, o)) // Convert to calldata offset.
                let t := add(l, add(s, 0x20))
                if iszero(lt(t, u)) { u := t }
            }
            let retStart := add(a, w) // Assumes `a` doesn't start from scratch space.
            mstore(retStart, 0x20) // Store the return offset.
            return(retStart, add(0x40, sub(u, retStart))) // End the transaction.
        }
    }

    /// @dev Returns the word at `offset`, without any bounds checks.
    function load(bytes memory a, uint256 offset) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(add(add(a, 0x20), offset))
        }
    }

    /// @dev Returns the word at `offset`, without any bounds checks.
    function loadCalldata(bytes calldata a, uint256 offset)
        internal
        pure
        returns (bytes32 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := calldataload(add(a.offset, offset))
        }
    }

    /// @dev Returns a slice representing a static struct in the calldata. Performs bounds checks.
    function staticStructInCalldata(bytes calldata a, uint256 offset)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let l := sub(a.length, 0x20)
            result.offset := add(a.offset, offset)
            result.length := sub(a.length, offset)
            if or(shr(64, or(l, a.offset)), gt(offset, l)) { revert(l, 0x00) }
        }
    }

    /// @dev Returns a slice representing a dynamic struct in the calldata. Performs bounds checks.
    function dynamicStructInCalldata(bytes calldata a, uint256 offset)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let l := sub(a.length, 0x20)
            let s := calldataload(add(a.offset, offset)) // Relative offset of `result` from `a.offset`.
            result.offset := add(a.offset, s)
            result.length := sub(a.length, s)
            if or(shr(64, or(s, or(l, a.offset))), gt(offset, l)) { revert(l, 0x00) }
        }
    }

    /// @dev Returns bytes in calldata. Performs bounds checks.
    function bytesInCalldata(bytes calldata a, uint256 offset)
        internal
        pure
        returns (bytes calldata result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let l := sub(a.length, 0x20)
            let s := calldataload(add(a.offset, offset)) // Relative offset of `result` from `a.offset`.
            result.offset := add(add(a.offset, s), 0x20)
            result.length := calldataload(add(a.offset, s))
            // forgefmt: disable-next-item
            if or(shr(64, or(result.length, or(s, or(l, a.offset)))),
                or(gt(add(s, result.length), l), gt(offset, l))) { revert(l, 0x00) }
        }
    }

    /// @dev Returns empty calldata bytes. For silencing the compiler.
    function emptyCalldata() internal pure returns (bytes calldata result) {
        /// @solidity memory-safe-assembly
        assembly {
            result.length := 0
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LibBytes} from "./LibBytes.sol";

/// @notice Library for converting numbers into strings and other string operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol)
///
/// @dev Note:
/// For performance and bytecode compactness, most of the string operations are restricted to
/// byte strings (7-bit ASCII), except where otherwise specified.
/// Usage of byte string operations on charsets with runes spanning two or more bytes
/// can lead to undefined behavior.
library LibString {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Goated string storage struct that totally MOGs, no cap, fr.
    /// Uses less gas and bytecode than Solidity's native string storage. It's meta af.
    /// Packs length with the first 31 bytes if <255 bytes, so it’s mad tight.
    struct StringStorage {
        bytes32 _spacer;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The length of the output is too small to contain all the hex digits.
    error HexLengthInsufficient();

    /// @dev The length of the string is more than 32 bytes.
    error TooBigForSmallString();

    /// @dev The input string must be a 7-bit ASCII.
    error StringNot7BitASCII();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when the `search` is not found in the string.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /// @dev Lookup for '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant ALPHANUMERIC_7_BIT_ASCII = 0x7fffffe07fffffe03ff000000000000;

    /// @dev Lookup for 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant LETTERS_7_BIT_ASCII = 0x7fffffe07fffffe0000000000000000;

    /// @dev Lookup for 'abcdefghijklmnopqrstuvwxyz'.
    uint128 internal constant LOWERCASE_7_BIT_ASCII = 0x7fffffe000000000000000000000000;

    /// @dev Lookup for 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant UPPERCASE_7_BIT_ASCII = 0x7fffffe0000000000000000;

    /// @dev Lookup for '0123456789'.
    uint128 internal constant DIGITS_7_BIT_ASCII = 0x3ff000000000000;

    /// @dev Lookup for '0123456789abcdefABCDEF'.
    uint128 internal constant HEXDIGITS_7_BIT_ASCII = 0x7e0000007e03ff000000000000;

    /// @dev Lookup for '01234567'.
    uint128 internal constant OCTDIGITS_7_BIT_ASCII = 0xff000000000000;

    /// @dev Lookup for '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r\x0b\x0c'.
    uint128 internal constant PRINTABLE_7_BIT_ASCII = 0x7fffffffffffffffffffffff00003e00;

    /// @dev Lookup for '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~'.
    uint128 internal constant PUNCTUATION_7_BIT_ASCII = 0x78000001f8000001fc00fffe00000000;

    /// @dev Lookup for ' \t\n\r\x0b\x0c'.
    uint128 internal constant WHITESPACE_7_BIT_ASCII = 0x100003e00;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 STRING STORAGE OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Sets the value of the string storage `$` to `s`.
    function set(StringStorage storage $, string memory s) internal {
        LibBytes.set(bytesStorage($), bytes(s));
    }

    /// @dev Sets the value of the string storage `$` to `s`.
    function setCalldata(StringStorage storage $, string calldata s) internal {
        LibBytes.setCalldata(bytesStorage($), bytes(s));
    }

    /// @dev Sets the value of the string storage `$` to the empty string.
    function clear(StringStorage storage $) internal {
        delete $._spacer;
    }

    /// @dev Returns whether the value stored is `$` is the empty string "".
    function isEmpty(StringStorage storage $) internal view returns (bool) {
        return uint256($._spacer) & 0xff == uint256(0);
    }

    /// @dev Returns the length of the value stored in `$`.
    function length(StringStorage storage $) internal view returns (uint256) {
        return LibBytes.length(bytesStorage($));
    }

    /// @dev Returns the value stored in `$`.
    function get(StringStorage storage $) internal view returns (string memory) {
        return string(LibBytes.get(bytesStorage($)));
    }

    /// @dev Returns the uint8 at index `i`. If out-of-bounds, returns 0.
    function uint8At(StringStorage storage $, uint256 i) internal view returns (uint8) {
        return LibBytes.uint8At(bytesStorage($), i);
    }

    /// @dev Helper to cast `$` to a `BytesStorage`.
    function bytesStorage(StringStorage storage $)
        internal
        pure
        returns (LibBytes.BytesStorage storage casted)
    {
        /// @solidity memory-safe-assembly
        assembly {
            casted.slot := $.slot
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     DECIMAL OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(uint256 value) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits.
            result := add(mload(0x40), 0x80)
            mstore(0x40, add(result, 0x20)) // Allocate memory.
            mstore(result, 0) // Zeroize the slot after the string.

            let end := result // Cache the end of the memory to calculate the length later.
            let w := not(0) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                result := add(result, w) // `sub(result, 1)`.
                // Store the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(result, add(48, mod(temp, 10)))
                temp := div(temp, 10) // Keep dividing `temp` until zero.
                if iszero(temp) { break }
            }
            let n := sub(end, result)
            result := sub(result, 0x20) // Move the pointer 32 bytes back to make room for the length.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(int256 value) internal pure returns (string memory result) {
        if (value >= 0) return toString(uint256(value));
        unchecked {
            result = toString(~uint256(value) + 1);
        }
        /// @solidity memory-safe-assembly
        assembly {
            // We still have some spare memory space on the left,
            // as we have allocated 3 words (96 bytes) for up to 78 digits.
            let n := mload(result) // Load the string length.
            mstore(result, 0x2d) // Store the '-' character.
            result := sub(result, 1) // Move back the string pointer by a byte.
            mstore(result, add(n, 1)) // Update the string length.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   HEXADECIMAL OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `byteCount` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `byteCount * 2 + 2` bytes.
    /// Reverts if `byteCount` is too small for the output to contain all the digits.
    function toHexString(uint256 value, uint256 byteCount)
        internal
        pure
        returns (string memory result)
    {
        result = toHexStringNoPrefix(value, byteCount);
        /// @solidity memory-safe-assembly
        assembly {
            let n := add(mload(result), 2) // Compute the length.
            mstore(result, 0x3078) // Store the "0x" prefix.
            result := sub(result, 2) // Move the pointer.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `byteCount` bytes.
    /// The output is not prefixed with "0x" and is encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `byteCount * 2` bytes.
    /// Reverts if `byteCount` is too small for the output to contain all the digits.
    function toHexStringNoPrefix(uint256 value, uint256 byteCount)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // We need 0x20 bytes for the trailing zeros padding, `byteCount * 2` bytes
            // for the digits, 0x02 bytes for the prefix, and 0x20 bytes for the length.
            // We add 0x20 to the total and round down to a multiple of 0x20.
            // (0x20 + 0x20 + 0x02 + 0x20) = 0x62.
            result := add(mload(0x40), and(add(shl(1, byteCount), 0x42), not(0x1f)))
            mstore(0x40, add(result, 0x20)) // Allocate memory.
            mstore(result, 0) // Zeroize the slot after the string.

            let end := result // Cache the end to calculate the length later.
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let start := sub(result, add(byteCount, byteCount))
            let w := not(1) // Tsk.
            let temp := value
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for {} 1 {} {
                result := add(result, w) // `sub(result, 2)`.
                mstore8(add(result, 1), mload(and(temp, 15)))
                mstore8(result, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(xor(result, start)) { break }
            }
            if temp {
                mstore(0x00, 0x2194895a) // `HexLengthInsufficient()`.
                revert(0x1c, 0x04)
            }
            let n := sub(end, result)
            result := sub(result, 0x20)
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2 + 2` bytes.
    function toHexString(uint256 value) internal pure returns (string memory result) {
        result = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let n := add(mload(result), 2) // Compute the length.
            mstore(result, 0x3078) // Store the "0x" prefix.
            result := sub(result, 2) // Move the pointer.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x".
    /// The output excludes leading "0" from the `toHexString` output.
    /// `0x00: "0x0", 0x01: "0x1", 0x12: "0x12", 0x123: "0x123"`.
    function toMinimalHexString(uint256 value) internal pure returns (string memory result) {
        result = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let o := eq(byte(0, mload(add(result, 0x20))), 0x30) // Whether leading zero is present.
            let n := add(mload(result), 2) // Compute the length.
            mstore(add(result, o), 0x3078) // Store the "0x" prefix, accounting for leading zero.
            result := sub(add(result, o), 2) // Move the pointer, accounting for leading zero.
            mstore(result, sub(n, o)) // Store the length, accounting for leading zero.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output excludes leading "0" from the `toHexStringNoPrefix` output.
    /// `0x00: "0", 0x01: "1", 0x12: "12", 0x123: "123"`.
    function toMinimalHexStringNoPrefix(uint256 value)
        internal
        pure
        returns (string memory result)
    {
        result = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let o := eq(byte(0, mload(add(result, 0x20))), 0x30) // Whether leading zero is present.
            let n := mload(result) // Get the length.
            result := add(result, o) // Move the pointer, accounting for leading zero.
            mstore(result, sub(n, o)) // Store the length, accounting for leading zero.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2` bytes.
    function toHexStringNoPrefix(uint256 value) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x40 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x40) is 0xa0.
            result := add(mload(0x40), 0x80)
            mstore(0x40, add(result, 0x20)) // Allocate memory.
            mstore(result, 0) // Zeroize the slot after the string.

            let end := result // Cache the end to calculate the length later.
            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.

            let w := not(1) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                result := add(result, w) // `sub(result, 2)`.
                mstore8(add(result, 1), mload(and(temp, 15)))
                mstore8(result, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(temp) { break }
            }
            let n := sub(end, result)
            result := sub(result, 0x20)
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x", encoded using 2 hexadecimal digits per byte,
    /// and the alphabets are capitalized conditionally according to
    /// https://eips.ethereum.org/EIPS/eip-55
    function toHexStringChecksummed(address value) internal pure returns (string memory result) {
        result = toHexString(value);
        /// @solidity memory-safe-assembly
        assembly {
            let mask := shl(6, div(not(0), 255)) // `0b010000000100000000 ...`
            let o := add(result, 0x22)
            let hashed := and(keccak256(o, 40), mul(34, mask)) // `0b10001000 ... `
            let t := shl(240, 136) // `0b10001000 << 240`
            for { let i := 0 } 1 {} {
                mstore(add(i, i), mul(t, byte(i, hashed)))
                i := add(i, 1)
                if eq(i, 20) { break }
            }
            mstore(o, xor(mload(o), shr(1, and(mload(0x00), and(mload(o), mask)))))
            o := add(o, 0x20)
            mstore(o, xor(mload(o), shr(1, and(mload(0x20), and(mload(o), mask)))))
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    function toHexString(address value) internal pure returns (string memory result) {
        result = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let n := add(mload(result), 2) // Compute the length.
            mstore(result, 0x3078) // Store the "0x" prefix.
            result := sub(result, 2) // Move the pointer.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(address value) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            // Allocate memory.
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x28 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x28) is 0x80.
            mstore(0x40, add(result, 0x80))
            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.

            result := add(result, 2)
            mstore(result, 40) // Store the length.
            let o := add(result, 0x20)
            mstore(add(o, 40), 0) // Zeroize the slot after the string.
            value := shl(96, value)
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let i := 0 } 1 {} {
                let p := add(o, add(i, i))
                let temp := byte(i, value)
                mstore8(add(p, 1), mload(and(temp, 15)))
                mstore8(p, mload(shr(4, temp)))
                i := add(i, 1)
                if eq(i, 20) { break }
            }
        }
    }

    /// @dev Returns the hex encoded string from the raw bytes.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexString(bytes memory raw) internal pure returns (string memory result) {
        result = toHexStringNoPrefix(raw);
        /// @solidity memory-safe-assembly
        assembly {
            let n := add(mload(result), 2) // Compute the length.
            mstore(result, 0x3078) // Store the "0x" prefix.
            result := sub(result, 2) // Move the pointer.
            mstore(result, n) // Store the length.
        }
    }

    /// @dev Returns the hex encoded string from the raw bytes.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(bytes memory raw) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(raw)
            result := add(mload(0x40), 2) // Skip 2 bytes for the optional prefix.
            mstore(result, add(n, n)) // Store the length of the output.

            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.
            let o := add(result, 0x20)
            let end := add(raw, n)
            for {} iszero(eq(raw, end)) {} {
                raw := add(raw, 1)
                mstore8(add(o, 1), mload(and(mload(raw), 15)))
                mstore8(o, mload(and(shr(4, mload(raw)), 15)))
                o := add(o, 2)
            }
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   RUNE STRING OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of UTF characters in the string.
    function runeCount(string memory s) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            if mload(s) {
                mstore(0x00, div(not(0), 255))
                mstore(0x20, 0x0202020202020202020202020202020202020202020202020303030304040506)
                let o := add(s, 0x20)
                let end := add(o, mload(s))
                for { result := 1 } 1 { result := add(result, 1) } {
                    o := add(o, byte(0, mload(shr(250, mload(o)))))
                    if iszero(lt(o, end)) { break }
                }
            }
        }
    }

    /// @dev Returns if this string is a 7-bit ASCII string.
    /// (i.e. all characters codes are in [0..127])
    function is7BitASCII(string memory s) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := 1
            let mask := shl(7, div(not(0), 255))
            let n := mload(s)
            if n {
                let o := add(s, 0x20)
                let end := add(o, n)
                let last := mload(end)
                mstore(end, 0)
                for {} 1 {} {
                    if and(mask, mload(o)) {
                        result := 0
                        break
                    }
                    o := add(o, 0x20)
                    if iszero(lt(o, end)) { break }
                }
                mstore(end, last)
            }
        }
    }

    /// @dev Returns if this string is a 7-bit ASCII string,
    /// AND all characters are in the `allowed` lookup.
    /// Note: If `s` is empty, returns true regardless of `allowed`.
    function is7BitASCII(string memory s, uint128 allowed) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := 1
            if mload(s) {
                let allowed_ := shr(128, shl(128, allowed))
                let o := add(s, 0x20)
                for { let end := add(o, mload(s)) } 1 {} {
                    result := and(result, shr(byte(0, mload(o)), allowed_))
                    o := add(o, 1)
                    if iszero(and(result, lt(o, end))) { break }
                }
            }
        }
    }

    /// @dev Converts the bytes in the 7-bit ASCII string `s` to
    /// an allowed lookup for use in `is7BitASCII(s, allowed)`.
    /// To save runtime gas, you can cache the result in an immutable variable.
    function to7BitASCIIAllowedLookup(string memory s) internal pure returns (uint128 result) {
        /// @solidity memory-safe-assembly
        assembly {
            if mload(s) {
                let o := add(s, 0x20)
                for { let end := add(o, mload(s)) } 1 {} {
                    result := or(result, shl(byte(0, mload(o)), 1))
                    o := add(o, 1)
                    if iszero(lt(o, end)) { break }
                }
                if shr(128, result) {
                    mstore(0x00, 0xc9807e0d) // `StringNot7BitASCII()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   BYTE STRING OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // For performance and bytecode compactness, byte string operations are restricted
    // to 7-bit ASCII strings. All offsets are byte offsets, not UTF character offsets.
    // Usage of byte string operations on charsets with runes spanning two or more bytes
    // can lead to undefined behavior.

    /// @dev Returns `subject` all occurrences of `needle` replaced with `replacement`.
    function replace(string memory subject, string memory needle, string memory replacement)
        internal
        pure
        returns (string memory)
    {
        return string(LibBytes.replace(bytes(subject), bytes(needle), bytes(replacement)));
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from left to right, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function indexOf(string memory subject, string memory needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return LibBytes.indexOf(bytes(subject), bytes(needle), from);
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from left to right.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function indexOf(string memory subject, string memory needle) internal pure returns (uint256) {
        return LibBytes.indexOf(bytes(subject), bytes(needle), 0);
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from right to left, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function lastIndexOf(string memory subject, string memory needle, uint256 from)
        internal
        pure
        returns (uint256)
    {
        return LibBytes.lastIndexOf(bytes(subject), bytes(needle), from);
    }

    /// @dev Returns the byte index of the first location of `needle` in `subject`,
    /// needleing from right to left.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `needle` is not found.
    function lastIndexOf(string memory subject, string memory needle)
        internal
        pure
        returns (uint256)
    {
        return LibBytes.lastIndexOf(bytes(subject), bytes(needle), type(uint256).max);
    }

    /// @dev Returns true if `needle` is found in `subject`, false otherwise.
    function contains(string memory subject, string memory needle) internal pure returns (bool) {
        return LibBytes.contains(bytes(subject), bytes(needle));
    }

    /// @dev Returns whether `subject` starts with `needle`.
    function startsWith(string memory subject, string memory needle) internal pure returns (bool) {
        return LibBytes.startsWith(bytes(subject), bytes(needle));
    }

    /// @dev Returns whether `subject` ends with `needle`.
    function endsWith(string memory subject, string memory needle) internal pure returns (bool) {
        return LibBytes.endsWith(bytes(subject), bytes(needle));
    }

    /// @dev Returns `subject` repeated `times`.
    function repeat(string memory subject, uint256 times) internal pure returns (string memory) {
        return string(LibBytes.repeat(bytes(subject), times));
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function slice(string memory subject, uint256 start, uint256 end)
        internal
        pure
        returns (string memory)
    {
        return string(LibBytes.slice(bytes(subject), start, end));
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the string.
    /// `start` is a byte offset.
    function slice(string memory subject, uint256 start) internal pure returns (string memory) {
        return string(LibBytes.slice(bytes(subject), start, type(uint256).max));
    }

    /// @dev Returns all the indices of `needle` in `subject`.
    /// The indices are byte offsets.
    function indicesOf(string memory subject, string memory needle)
        internal
        pure
        returns (uint256[] memory)
    {
        return LibBytes.indicesOf(bytes(subject), bytes(needle));
    }

    /// @dev Returns an arrays of strings based on the `delimiter` inside of the `subject` string.
    function split(string memory subject, string memory delimiter)
        internal
        pure
        returns (string[] memory result)
    {
        bytes[] memory a = LibBytes.split(bytes(subject), bytes(delimiter));
        /// @solidity memory-safe-assembly
        assembly {
            result := a
        }
    }

    /// @dev Returns a concatenated string of `a` and `b`.
    /// Cheaper than `string.concat()` and does not de-align the free memory pointer.
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(LibBytes.concat(bytes(a), bytes(b)));
    }

    /// @dev Returns a copy of the string in either lowercase or UPPERCASE.
    /// WARNING! This function is only compatible with 7-bit ASCII strings.
    function toCase(string memory subject, bool toUpper)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(subject)
            if n {
                result := mload(0x40)
                let o := add(result, 0x20)
                let d := sub(subject, result)
                let flags := shl(add(70, shl(5, toUpper)), 0x3ffffff)
                for { let end := add(o, n) } 1 {} {
                    let b := byte(0, mload(add(d, o)))
                    mstore8(o, xor(and(shr(b, flags), 0x20), b))
                    o := add(o, 1)
                    if eq(o, end) { break }
                }
                mstore(result, n) // Store the length.
                mstore(o, 0) // Zeroize the slot after the string.
                mstore(0x40, add(o, 0x20)) // Allocate memory.
            }
        }
    }

    /// @dev Returns a string from a small bytes32 string.
    /// `s` must be null-terminated, or behavior will be undefined.
    function fromSmallString(bytes32 s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let n := 0
            for {} byte(n, s) { n := add(n, 1) } {} // Scan for '\0'.
            mstore(result, n) // Store the length.
            let o := add(result, 0x20)
            mstore(o, s) // Store the bytes of the string.
            mstore(add(o, n), 0) // Zeroize the slot after the string.
            mstore(0x40, add(result, 0x40)) // Allocate memory.
        }
    }

    /// @dev Returns the small string, with all bytes after the first null byte zeroized.
    function normalizeSmallString(bytes32 s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            for {} byte(result, s) { result := add(result, 1) } {} // Scan for '\0'.
            mstore(0x00, s)
            mstore(result, 0x00)
            result := mload(0x00)
        }
    }

    /// @dev Returns the string as a normalized null-terminated small string.
    function toSmallString(string memory s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(s)
            if iszero(lt(result, 33)) {
                mstore(0x00, 0xec92f9a3) // `TooBigForSmallString()`.
                revert(0x1c, 0x04)
            }
            result := shl(shl(3, sub(32, result)), mload(add(s, result)))
        }
    }

    /// @dev Returns a lowercased copy of the string.
    /// WARNING! This function is only compatible with 7-bit ASCII strings.
    function lower(string memory subject) internal pure returns (string memory result) {
        result = toCase(subject, false);
    }

    /// @dev Returns an UPPERCASED copy of the string.
    /// WARNING! This function is only compatible with 7-bit ASCII strings.
    function upper(string memory subject) internal pure returns (string memory result) {
        result = toCase(subject, true);
    }

    /// @dev Escapes the string to be used within HTML tags.
    function escapeHTML(string memory s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let end := add(s, mload(s))
            let o := add(result, 0x20)
            // Store the bytes of the packed offsets and strides into the scratch space.
            // `packed = (stride << 5) | offset`. Max offset is 20. Max stride is 6.
            mstore(0x1f, 0x900094)
            mstore(0x08, 0xc0000000a6ab)
            // Store "&quot;&amp;&#39;&lt;&gt;" into the scratch space.
            mstore(0x00, shl(64, 0x2671756f743b26616d703b262333393b266c743b2667743b))
            for {} iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                // Not in `["\"","'","&","<",">"]`.
                if iszero(and(shl(c, 1), 0x500000c400000000)) {
                    mstore8(o, c)
                    o := add(o, 1)
                    continue
                }
                let t := shr(248, mload(c))
                mstore(o, mload(and(t, 0x1f)))
                o := add(o, shr(5, t))
            }
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(result, sub(o, add(result, 0x20))) // Store the length.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
        }
    }

    /// @dev Escapes the string to be used within double-quotes in a JSON.
    /// If `addDoubleQuotes` is true, the result will be enclosed in double-quotes.
    function escapeJSON(string memory s, bool addDoubleQuotes)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let o := add(result, 0x20)
            if addDoubleQuotes {
                mstore8(o, 34)
                o := add(1, o)
            }
            // Store "\\u0000" in scratch space.
            // Store "0123456789abcdef" in scratch space.
            // Also, store `{0x08:"b", 0x09:"t", 0x0a:"n", 0x0c:"f", 0x0d:"r"}`.
            // into the scratch space.
            mstore(0x15, 0x5c75303030303031323334353637383961626364656662746e006672)
            // Bitmask for detecting `["\"","\\"]`.
            let e := or(shl(0x22, 1), shl(0x5c, 1))
            for { let end := add(s, mload(s)) } iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                if iszero(lt(c, 0x20)) {
                    if iszero(and(shl(c, 1), e)) {
                        // Not in `["\"","\\"]`.
                        mstore8(o, c)
                        o := add(o, 1)
                        continue
                    }
                    mstore8(o, 0x5c) // "\\".
                    mstore8(add(o, 1), c)
                    o := add(o, 2)
                    continue
                }
                if iszero(and(shl(c, 1), 0x3700)) {
                    // Not in `["\b","\t","\n","\f","\d"]`.
                    mstore8(0x1d, mload(shr(4, c))) // Hex value.
                    mstore8(0x1e, mload(and(c, 15))) // Hex value.
                    mstore(o, mload(0x19)) // "\\u00XX".
                    o := add(o, 6)
                    continue
                }
                mstore8(o, 0x5c) // "\\".
                mstore8(add(o, 1), mload(add(c, 8)))
                o := add(o, 2)
            }
            if addDoubleQuotes {
                mstore8(o, 34)
                o := add(1, o)
            }
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(result, sub(o, add(result, 0x20))) // Store the length.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
        }
    }

    /// @dev Escapes the string to be used within double-quotes in a JSON.
    function escapeJSON(string memory s) internal pure returns (string memory result) {
        result = escapeJSON(s, false);
    }

    /// @dev Encodes `s` so that it can be safely used in a URI,
    /// just like `encodeURIComponent` in JavaScript.
    /// See: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent
    /// See: https://datatracker.ietf.org/doc/html/rfc2396
    /// See: https://datatracker.ietf.org/doc/html/rfc3986
    function encodeURIComponent(string memory s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            // Store "0123456789ABCDEF" in scratch space.
            // Uppercased to be consistent with JavaScript's implementation.
            mstore(0x0f, 0x30313233343536373839414243444546)
            let o := add(result, 0x20)
            for { let end := add(s, mload(s)) } iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                // If not in `[0-9A-Z-a-z-_.!~*'()]`.
                if iszero(and(1, shr(c, 0x47fffffe87fffffe03ff678200000000))) {
                    mstore8(o, 0x25) // '%'.
                    mstore8(add(o, 1), mload(and(shr(4, c), 15)))
                    mstore8(add(o, 2), mload(and(c, 15)))
                    o := add(o, 3)
                    continue
                }
                mstore8(o, c)
                o := add(o, 1)
            }
            mstore(result, sub(o, add(result, 0x20))) // Store the length.
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(0x40, add(o, 0x20)) // Allocate memory.
        }
    }

    /// @dev Returns whether `a` equals `b`.
    function eq(string memory a, string memory b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }

    /// @dev Returns whether `a` equals `b`, where `b` is a null-terminated small string.
    function eqs(string memory a, bytes32 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            // These should be evaluated on compile time, as far as possible.
            let m := not(shl(7, div(not(iszero(b)), 255))) // `0x7f7f ...`.
            let x := not(or(m, or(b, add(m, and(b, m)))))
            let r := shl(7, iszero(iszero(shr(128, x))))
            r := or(r, shl(6, iszero(iszero(shr(64, shr(r, x))))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            result := gt(eq(mload(a), add(iszero(x), xor(31, shr(3, r)))),
                xor(shr(add(8, r), b), shr(add(8, r), mload(add(a, 0x20)))))
        }
    }

    /// @dev Returns 0 if `a == b`, -1 if `a < b`, +1 if `a > b`.
    /// If `a` == b[:a.length]`, and `a.length < b.length`, returns -1.
    function cmp(string memory a, string memory b) internal pure returns (int256) {
        return LibBytes.cmp(bytes(a), bytes(b));
    }

    /// @dev Packs a single string with its length into a single word.
    /// Returns `bytes32(0)` if the length is zero or greater than 31.
    function packOne(string memory a) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // We don't need to zero right pad the string,
            // since this is our own custom non-standard packing scheme.
            result :=
                mul(
                    // Load the length and the bytes.
                    mload(add(a, 0x1f)),
                    // `length != 0 && length < 32`. Abuses underflow.
                    // Assumes that the length is valid and within the block gas limit.
                    lt(sub(mload(a), 1), 0x1f)
                )
        }
    }

    /// @dev Unpacks a string packed using {packOne}.
    /// Returns the empty string if `packed` is `bytes32(0)`.
    /// If `packed` is not an output of {packOne}, the output behavior is undefined.
    function unpackOne(bytes32 packed) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40) // Grab the free memory pointer.
            mstore(0x40, add(result, 0x40)) // Allocate 2 words (1 for the length, 1 for the bytes).
            mstore(result, 0) // Zeroize the length slot.
            mstore(add(result, 0x1f), packed) // Store the length and bytes.
            mstore(add(add(result, 0x20), mload(result)), 0) // Right pad with zeroes.
        }
    }

    /// @dev Packs two strings with their lengths into a single word.
    /// Returns `bytes32(0)` if combined length is zero or greater than 30.
    function packTwo(string memory a, string memory b) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let aLen := mload(a)
            // We don't need to zero right pad the strings,
            // since this is our own custom non-standard packing scheme.
            result :=
                mul(
                    or( // Load the length and the bytes of `a` and `b`.
                    shl(shl(3, sub(0x1f, aLen)), mload(add(a, aLen))), mload(sub(add(b, 0x1e), aLen))),
                    // `totalLen != 0 && totalLen < 31`. Abuses underflow.
                    // Assumes that the lengths are valid and within the block gas limit.
                    lt(sub(add(aLen, mload(b)), 1), 0x1e)
                )
        }
    }

    /// @dev Unpacks strings packed using {packTwo}.
    /// Returns the empty strings if `packed` is `bytes32(0)`.
    /// If `packed` is not an output of {packTwo}, the output behavior is undefined.
    function unpackTwo(bytes32 packed)
        internal
        pure
        returns (string memory resultA, string memory resultB)
    {
        /// @solidity memory-safe-assembly
        assembly {
            resultA := mload(0x40) // Grab the free memory pointer.
            resultB := add(resultA, 0x40)
            // Allocate 2 words for each string (1 for the length, 1 for the byte). Total 4 words.
            mstore(0x40, add(resultB, 0x40))
            // Zeroize the length slots.
            mstore(resultA, 0)
            mstore(resultB, 0)
            // Store the lengths and bytes.
            mstore(add(resultA, 0x1f), packed)
            mstore(add(resultB, 0x1f), mload(add(add(resultA, 0x20), mload(resultA))))
            // Right pad with zeroes.
            mstore(add(add(resultA, 0x20), mload(resultA)), 0)
            mstore(add(add(resultB, 0x20), mload(resultB)), 0)
        }
    }

    /// @dev Directly returns `a` without copying.
    function directReturn(string memory a) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            // Assumes that the string does not start from the scratch space.
            let retStart := sub(a, 0x20)
            let retUnpaddedSize := add(mload(a), 0x40)
            // Right pad with zeroes. Just in case the string is produced
            // by a method that doesn't zero right pad.
            mstore(add(retStart, retUnpaddedSize), 0)
            mstore(retStart, 0x20) // Store the return offset.
            // End the transaction, returning the string.
            return(retStart, and(not(0x1f), add(0x1f, retUnpaddedSize)))
        }
    }
}
