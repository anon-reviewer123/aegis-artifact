// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import {Attestation} from "eas-contracts/IEAS.sol";
import {ILibreCoreGateway, TokenTransfer, ChainInvestorAddresses} from "src/interfaces/ILibreCoreGateway.sol";
import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IGatewayManager} from "src/interfaces/IGatewayManager.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {ISecurityToken} from "src/interfaces/ISecurityToken.sol";
import {LibreUUPSUpgradeable} from "src/utils/LibreUUPSUpgradeable.sol";
import {GatewayUtils} from "src/utils/GatewayUtils.sol";
import {OperationId, UidOp} from "src/lib/OperationId.sol";
import "src/utils/Constant.sol";

/**
 * @title Libre Core Gateway
 * @notice Main gateway contract for cross-chain token transfers and credential bridging
 * @dev Implements lock-and-mint mechanism for cross-chain token transfers and provides credential bridging mechanism
 */
contract LibreCoreGateway is ILibreCoreGateway, LibreUUPSUpgradeable, PausableUpgradeable {
    /// @custom:storage-location erc7201:CoreGateway.storage
    struct CoreGatewayStorage {
        IInstrumentRegistry instrumentRegistry;
        IInvestorRegistry investorRegistry;
        IGatewayManager gatewayManager;
        uint16 UNUSED_VAR_1; //  Reserved for storage layout alignment. Do not remove to ensure upgrade safety.
        uint16[] supportedChainSelectors;
        mapping(uint16 chainSelector => bool isSupported) supportedChains;
        mapping(uint16 chainSelector => bool isVariableLengthAddress) variableLengthAddressChains;
        uint128 nonce;
        // Mapping to track canonical message IDs and their last operation
        mapping(bytes32 => UidOp) usedUids;
    }

    // keccak256(abi.encode(uint256(keccak256("CoreGateway.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CORE_GATEWAY_STORAGE_SLOT =
        0xd3c6fea86d6cb76ec7f4c7a1353ebe90781bbd85c20123a20cc0e122f08d3000;

    modifier nonEmptyChainSelectors(uint16[] calldata chainSelectors) {
        if (chainSelectors.length == 0) {
            revert CoreGateway_InvalidInput();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ILibreCoreGateway
    function initialize(
        IInstrumentRegistry _instrumentRegistry,
        IInvestorRegistry _investorRegistry,
        IGatewayManager _gatewayManager,
        IRoleRegistry _roleRegistry,
        uint16[] calldata _supportedChains
    ) external initializer {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        cgs.instrumentRegistry = _instrumentRegistry;
        cgs.investorRegistry = _investorRegistry;
        cgs.gatewayManager = _gatewayManager;

        _initializeSupportedChains(_supportedChains);

        PermissionedContractStorage storage pcs = _getPermissionedContractStorage();
        pcs.roleRegistry = _roleRegistry;

        __Pausable_init();
    }

    /// @inheritdoc ILibreCoreGateway
    function lockAndBridge(TokenTransfer calldata transferDetails) external whenNotPaused {
        if (transferDetails.amount == 0) revert CoreGateway_ZeroAmount();

        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();

        // check if chain is supported
        _validateSupportedChain(transferDetails.chainSelector);

        // Cache investor registry to save storage read
        IInvestorRegistry investorRegistry = cgs.investorRegistry;

        // Validate investor
        bytes32 investorId = investorRegistry.getIdFromWallet(msg.sender);
        if (investorId != transferDetails.investorId) {
            revert CoreGateway_InvalidInvestor();
        }

        // Verify credential for instrument with cross-chain expiry threshold
        investorRegistry.checkCredentialInstrumentForCrossChain(
            transferDetails.investorId, transferDetails.instrumentId
        );

        // Get security token address from instrument registry
        address tokenAddress = cgs.instrumentRegistry.getAddress(transferDetails.instrumentId, INSTRUMENT_TOKEN);
        if (tokenAddress == address(0)) revert CoreGateway_TokenAddressNotFound(tokenAddress);

        // Validate destination chain receiver address is valid
        if (
            !cgs.gatewayManager.isValidCrossChainAddress(
                transferDetails.investorId, transferDetails.chainSelector, transferDetails.receiver
            )
        ) {
            revert CoreGateway_InvalidTransfer();
        }

        // Transfer tokens to this contract
        ISecurityToken token = ISecurityToken(tokenAddress);
        token.transferFrom(msg.sender, address(this), transferDetails.amount);

        // Generate UID for this operation
        bytes32 uid = OperationId.generate(
            cgs.nonce, NATIVE_CHAIN_SELECTOR, transferDetails.chainSelector, transferDetails.investorId
        );

        // Process burn/lock operation - track UID to prevent replay attacks
        _processBurnLock(uid);

        // Encode transfer details for the event
        bytes memory encodedTransferDetails = abi.encode(transferDetails);

        // Increment nonce after generating UID and before emitting event
        cgs.nonce++;
        emit TokenLockedAndBridged(uid, encodedTransferDetails);
    }

    /// @inheritdoc ILibreCoreGateway
    function unlock(bytes32 _senderRole, bytes calldata encodedTransferDetails, bytes32 uid) external whenNotPaused {
        _checkRoleHasAccess(_senderRole);

        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();

        TokenTransfer memory transferDetails = abi.decode(encodedTransferDetails, (TokenTransfer));
        if (transferDetails.amount == 0) revert CoreGateway_ZeroAmount();

        if (NATIVE_CHAIN_SELECTOR != transferDetails.chainSelector) {
            revert CoreGateway_InvalidNativeChainSelector();
        }

        // Convert bytes receiver to address for EVM
        address receiver = address(bytes20(transferDetails.receiver));

        // Validate investor
        bytes32 investorId = cgs.investorRegistry.getIdFromWallet(receiver);
        if (investorId != transferDetails.investorId) {
            revert CoreGateway_InvalidInvestor();
        }

        // Get security token address from instrument registry
        address tokenAddress = cgs.instrumentRegistry.getAddress(transferDetails.instrumentId, INSTRUMENT_TOKEN);
        if (tokenAddress == address(0)) revert CoreGateway_TokenAddressNotFound(tokenAddress);

        // Process mint/unlock operation - validate UID state transition
        _processMintUnlock(uid);

        if (_senderRole != DEFAULT_ADMIN_ROLE) {
            // Transfer tokens from this contract
            ISecurityToken(tokenAddress).transfer(receiver, transferDetails.amount);
        } else {
            // Force unlock or transfer tokens from this contract
            ISecurityToken(tokenAddress).forceTransfer(address(this), receiver, transferDetails.amount, bytes32(0));
        }

        emit TokenUnlocked(uid, encodedTransferDetails);
    }

    /// @inheritdoc ILibreCoreGateway
    function bridgeCredential(
        bytes32 _senderRole,
        Attestation calldata attestation,
        uint16[] calldata destinationChainSelectors
    ) external nonEmptyChainSelectors(destinationChainSelectors) whenNotPaused {
        _checkRoleHasAccess(_senderRole);
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();

        for (uint256 i; i < destinationChainSelectors.length; ++i) {
            // check if chain is supported
            _validateSupportedChain(destinationChainSelectors[i]);
        }

        // Decode investor ID and verify credential matches from registry
        (bytes32 investorId,,) = abi.decode(attestation.data, (bytes32, bytes32[], uint64[]));
        bytes32 credentialId = cgs.investorRegistry.getBytes(investorId, CREDENTIAL_ID);
        if (credentialId != attestation.uid) {
            revert CoreGateway_InvalidCredential();
        }

        // Process credential sync operation - track UID to prevent replay attacks
        _processCredentialSync(attestation.uid);

        emit CredentialBridged(investorId, destinationChainSelectors, attestation.uid);
    }

    /// @inheritdoc ILibreCoreGateway
    function bridgeInvestorAddresses(
        bytes32 _senderRole,
        bytes32 _investorId,
        bytes[] calldata _addressChanges,
        uint16[] calldata investorDestChainSelectors
    ) external whenNotPaused {
        _checkRoleHasAccess(_senderRole);
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();

        // Validate investor exists
        if (!cgs.investorRegistry.getBool(_investorId, IS_INVESTOR)) {
            revert CoreGateway_InvalidInvestor();
        }

        // Validate input
        if (_addressChanges.length == 0) {
            revert CoreGateway_InvalidInput();
        }

        // Validate all chain selectors are supported
        for (uint256 i; i < investorDestChainSelectors.length; ++i) {
            _validateSupportedChain(investorDestChainSelectors[i]);
        }

        // Group addresses by chain with validation for supported chains
        ChainInvestorAddresses[] memory chainAddresses = _groupAddressesByChain(cgs, _investorId, _addressChanges);

        // Cache current nonce and native chain selector
        uint128 nonceCache = cgs.nonce;

        // Emit events for each chain's address changes
        for (uint256 i; i < chainAddresses.length; ++i) {
            bytes memory encodedChainData = abi.encode(chainAddresses[i]);

            // Generate UID for the entire operation (use first chain's selector)
            bytes32 uid =
                OperationId.generate(nonceCache, NATIVE_CHAIN_SELECTOR, chainAddresses[i].chainSelector, _investorId);

            // Process address sync operation - track UID to prevent replay attacks
            _processAddressSync(uid);

            nonceCache++;

            emit ChainInvestorAddressesBridged(uid, _investorId, investorDestChainSelectors, encodedChainData);
        }

        // Update nonce storage slot once
        cgs.nonce = nonceCache;
    }

    /// @inheritdoc ILibreCoreGateway
    function setChainSupport(bytes32 _senderRole, uint16 chainSelector, bool isSupported) external {
        _checkRoleHasAccess(_senderRole);

        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        bool wasSupported = cgs.supportedChains[chainSelector];

        if (wasSupported == isSupported) {
            revert CoreGateway_NoStatusChanged();
        }
        cgs.supportedChains[chainSelector] = isSupported;

        // Add to supported chains array if newly supported
        if (isSupported && !wasSupported) {
            cgs.supportedChainSelectors.push(chainSelector);
        }
        // Remove from supported chains array if no longer supported
        else if (!isSupported && wasSupported) {
            _removeChainSelector(chainSelector);
        }

        emit ChainSupportUpdated(chainSelector, isSupported);
    }

    /// @inheritdoc ILibreCoreGateway
    function setChainVariableLengthAddressSupport(
        bytes32 _senderRole,
        uint16 _chainSelector,
        bool _isVariableLengthAddress
    ) external {
        _checkRoleHasAccess(_senderRole);

        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        bool wasVariableLengthAddress = cgs.variableLengthAddressChains[_chainSelector];

        if (wasVariableLengthAddress == _isVariableLengthAddress) {
            revert CoreGateway_NoStatusChanged();
        }
        cgs.variableLengthAddressChains[_chainSelector] = _isVariableLengthAddress;

        emit ChainVariableLengthAddressSupportUpdated(_chainSelector, _isVariableLengthAddress);
    }

    /// @inheritdoc ILibreCoreGateway
    function pause(bytes32 _senderRole) external {
        _checkRoleHasAccess(_senderRole);
        _pause();
    }

    /// @inheritdoc ILibreCoreGateway
    function unpause(bytes32 _senderRole) external {
        _checkRoleHasAccess(_senderRole);
        _unpause();
    }

    /// @inheritdoc ILibreCoreGateway
    function getLockedBalance(bytes32 instrumentId) external view returns (uint256 totalLocked) {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        address tokenAddress = cgs.instrumentRegistry.getAddress(instrumentId, INSTRUMENT_TOKEN);
        if (tokenAddress == address(0)) revert CoreGateway_TokenAddressNotFound(tokenAddress);

        totalLocked = ISecurityToken(tokenAddress).balanceOf(address(this));
    }

    /// @inheritdoc ILibreCoreGateway
    function getSupportedChains() external view returns (uint16[] memory) {
        return _getCoreGatewayStorage().supportedChainSelectors;
    }

    /// @inheritdoc ILibreCoreGateway
    function isSupportedChain(uint16 chainSelector) external view returns (bool) {
        return _getCoreGatewayStorage().supportedChains[chainSelector];
    }

    /**
     * @notice Gets the address of the instrument registry
     * @return The address of the instrument registry contract
     */
    function getInstrumentRegistry() external view returns (address) {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        return address(cgs.instrumentRegistry);
    }

    /**
     * @notice Gets the address of the investor registry
     * @return The address of the investor registry contract
     */
    function getInvestorRegistry() external view returns (address) {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        return address(cgs.investorRegistry);
    }

    /**
     * @notice Gets the address of the gateway manager
     * @return The address of the gateway manager contract
     */
    function getGatewayManager() external view returns (address) {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        return address(cgs.gatewayManager);
    }

    /**
     * @notice Get the current nonce value
     * @return Current nonce
     */
    function getNonce() external view returns (uint128) {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        return cgs.nonce;
    }

    /**
     * @notice Get the native chain selector
     * @return Native chain selector
     */
    function getNativeChainSelector() external view returns (uint16) {
        return NATIVE_CHAIN_SELECTOR;
    }

    /**
     * @notice Gets the last operation performed with a specific UID.
     * @param uid The unique identifier to query.
     * @return The last operation performed with the given UID.
     */
    function getUidLastOp(bytes32 uid) public view returns (UidOp) {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        return cgs.usedUids[uid];
    }

    /**
     * @notice Initializes supported chains IDs
     * @param _supportedChains Array of custom chain IDs
     */
    function _initializeSupportedChains(uint16[] calldata _supportedChains) internal {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        cgs.supportedChainSelectors = _supportedChains;

        for (uint256 i; i < _supportedChains.length; ++i) {
            cgs.supportedChains[_supportedChains[i]] = true;
        }
    }

    /**
     * @notice Removes a chain ID from the list of supported chains
     * @param chainSelector The chain ID to remove from supported chains array
     */
    function _removeChainSelector(uint16 chainSelector) internal {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();

        uint256 length = cgs.supportedChainSelectors.length;
        for (uint256 i; i < length; ++i) {
            if (cgs.supportedChainSelectors[i] == chainSelector) {
                cgs.supportedChainSelectors[i] = cgs.supportedChainSelectors[length - 1];
                cgs.supportedChainSelectors.pop();
                break;
            }
        }
    }

    /**
     * @notice Validates if a chain ID is supported by the gateway
     * @dev Reverts with CoreGateway_ChainNotSupported if chain is not supported
     * @param _chainSelector The chain ID to validate
     */
    function _validateSupportedChain(uint16 _chainSelector) internal view {
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();

        if (!cgs.supportedChains[_chainSelector]) {
            revert CoreGateway_ChainNotSupported(_chainSelector);
        }
    }

    /**
     * @notice Group address changes by chain ID and validate chains
     * @param _cgs storage reference for CoreGateway variables
     * @param investorId Unique investor ID
     * @param addressChanges Array of address changes bytes
     * @return result Array of ChainInvestorAddresses structures per chain
     */
    function _groupAddressesByChain(
        CoreGatewayStorage storage _cgs,
        bytes32 investorId,
        bytes[] calldata addressChanges
    ) internal view returns (ChainInvestorAddresses[] memory) {
        // First pass: count unique chains and changes per chain
        uint16[] memory uniqueChainSelectors = new uint16[](addressChanges.length);
        uint8[] memory changesPerChain = new uint8[](addressChanges.length);
        uint8 uniqueChainCount;

        for (uint256 i; i < addressChanges.length; ++i) {
            (, uint16 chainSelector,) = GatewayUtils.decodeAddressChange(addressChanges[i]);

            // Find or add chain ID
            bool found;
            for (uint8 j; j < uniqueChainCount; ++j) {
                if (uniqueChainSelectors[j] == chainSelector) {
                    changesPerChain[j]++;
                    found = true;
                    break;
                }
            }

            if (!found) {
                // Only validate chain support when encountering it for the first time
                if (chainSelector != NATIVE_CHAIN_SELECTOR && !_cgs.supportedChains[chainSelector]) {
                    revert CoreGateway_ChainNotSupported(chainSelector);
                }

                uniqueChainSelectors[uniqueChainCount] = chainSelector;
                changesPerChain[uniqueChainCount] = 1;
                uniqueChainCount++;
            }
        }

        // Initialize result array and address arrays for each chain
        ChainInvestorAddresses[] memory result = new ChainInvestorAddresses[](uniqueChainCount);
        for (uint8 i; i < uniqueChainCount; ++i) {
            result[i].investorId = investorId;
            result[i].chainSelector = uniqueChainSelectors[i];
            result[i].addressChanges = new bytes[](changesPerChain[i]);
        }

        // Second pass: fill the address arrays
        uint8[] memory currentIndex = new uint8[](uniqueChainCount);
        for (uint256 i; i < addressChanges.length; ++i) {
            (bool isAdd, uint16 chainSelector, bytes memory walletAddress) =
                GatewayUtils.decodeAddressChange(addressChanges[i]);

            // Find chain index
            for (uint8 j; j < uniqueChainCount; ++j) {
                if (uniqueChainSelectors[j] == chainSelector) {
                    // Set address size
                    if (_cgs.variableLengthAddressChains[chainSelector]) {
                        // addressSize should stay as 0 if the chain has variable length addresses
                    } else if (currentIndex[j] == 0) {
                        result[j].addressSize = uint8(walletAddress.length);
                    } else if (result[j].addressSize != walletAddress.length) {
                        revert CoreGateway_InvalidInput();
                    }

                    // Create formatted change: action byte + wallet address
                    bytes memory formattedChange = new bytes(1 + walletAddress.length);
                    formattedChange[0] = isAdd ? bytes1(0x00) : bytes1(0x01);

                    for (uint256 k; k < walletAddress.length; ++k) {
                        formattedChange[k + 1] = walletAddress[k];
                    }

                    result[j].addressChanges[currentIndex[j]] = formattedChange;
                    currentIndex[j]++;
                    break;
                }
            }
        }

        return result;
    }

    /**
     * @notice Sets the operation for a specific UID.
     * @param uid The unique identifier to set the operation for.
     * @param operation The operation to associate with the UID.
     * @dev Internal function to update UID operations. Cannot set operation to Unset.
     */
    function _setUidOperation(bytes32 uid, UidOp operation) internal {
        if (operation == UidOp.Unset) {
            revert CoreGateway_CannotSetUnsetOperation();
        }
        CoreGatewayStorage storage cgs = _getCoreGatewayStorage();
        cgs.usedUids[uid] = operation;
    }

    /**
     * @notice Processes a burn/lock operation with validation.
     * @param uid The unique identifier for the burn/lock operation.
     * @dev Used when tokens are burned or locked on the source chain.
     *      Reverts if the UID has already been used.
     */
    function _processBurnLock(bytes32 uid) internal {
        // Check if UID has already been used
        if (getUidLastOp(uid) != UidOp.Unset) {
            revert CoreGateway_UidAlreadyUsed();
        }
        _setUidOperation(uid, UidOp.BurnLock);
    }

    /**
     * @notice Processes a mint/unlock operation with validation.
     * @param uid The unique identifier for the mint/unlock operation.
     * @dev Used when tokens are minted or unlocked on the destination chain.
     *      Validates that either the UID doesn't exist or has BurnLock status.
     *      Reverts if the UID operation state is invalid.
     */
    function _processMintUnlock(bytes32 uid) internal {
        UidOp currentOp = getUidLastOp(uid);

        if (currentOp == UidOp.Unset || currentOp == UidOp.BurnLock) {
            // UID doesn't exist, or from BurnLock to MintUnlock
            _setUidOperation(uid, UidOp.MintUnlock);
        } else {
            // Invalid state, reject the operation
            revert CoreGateway_InvalidUidOperation();
        }
    }

    /**
     * @notice Processes a credential sync operation with validation.
     * @param uid The unique identifier for the credential sync operation.
     * @dev Used when credential attestations are bridged across chains.
     *      Reverts if the UID has already been used.
     */
    function _processCredentialSync(bytes32 uid) internal {
        // Check if UID has already been used
        if (getUidLastOp(uid) != UidOp.Unset) {
            revert CoreGateway_UidAlreadyUsed();
        }
        _setUidOperation(uid, UidOp.CredentialSync);
    }

    /**
     * @notice Processes an address sync operation with validation.
     * @param uid The unique identifier for the address sync operation.
     * @dev Used when investor addresses are bridged across chains.
     *      Reverts if the UID has already been used.
     */
    function _processAddressSync(bytes32 uid) internal {
        // Check if UID has already been used
        if (getUidLastOp(uid) != UidOp.Unset) {
            revert CoreGateway_UidAlreadyUsed();
        }
        _setUidOperation(uid, UidOp.AddressSync);
    }

    /**
     * @notice Retrieves the storage slot for the `CoreGatewayStorage` structure.
     * @return cgs A reference to the `CoreGatewayStorage` located at the predefined storage slot.
     */
    function _getCoreGatewayStorage() private pure returns (CoreGatewayStorage storage cgs) {
        assembly {
            cgs.slot := CORE_GATEWAY_STORAGE_SLOT
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.19;

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ISchemaRegistry } from "./ISchemaRegistry.sol";
import { ISemver } from "./ISemver.sol";
import { Attestation, Signature } from "./Common.sol";

/// @notice A struct representing the arguments of the attestation request.
struct AttestationRequestData {
    address recipient; // The recipient of the attestation.
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    bool revocable; // Whether the attestation is revocable.
    bytes32 refUID; // The UID of the related attestation.
    bytes data; // Custom attestation data.
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @notice A struct representing the full arguments of the attestation request.
struct AttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData data; // The arguments of the attestation request.
}

/// @notice A struct representing the full arguments of the full delegated attestation request.
struct DelegatedAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData data; // The arguments of the attestation request.
    Signature signature; // The ECDSA signature data.
    address attester; // The attesting account.
    uint64 deadline; // The deadline of the signature/request.
}

/// @notice A struct representing the full arguments of the multi attestation request.
struct MultiAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData[] data; // The arguments of the attestation request.
}

/// @notice A struct representing the full arguments of the delegated multi attestation request.
struct MultiDelegatedAttestationRequest {
    bytes32 schema; // The unique identifier of the schema.
    AttestationRequestData[] data; // The arguments of the attestation requests.
    Signature[] signatures; // The ECDSA signatures data. Please note that the signatures are assumed to be signed with increasing nonces.
    address attester; // The attesting account.
    uint64 deadline; // The deadline of the signature/request.
}

/// @notice A struct representing the arguments of the revocation request.
struct RevocationRequestData {
    bytes32 uid; // The UID of the attestation to revoke.
    uint256 value; // An explicit ETH amount to send to the resolver. This is important to prevent accidental user errors.
}

/// @notice A struct representing the full arguments of the revocation request.
struct RevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData data; // The arguments of the revocation request.
}

/// @notice A struct representing the arguments of the full delegated revocation request.
struct DelegatedRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData data; // The arguments of the revocation request.
    Signature signature; // The ECDSA signature data.
    address revoker; // The revoking account.
    uint64 deadline; // The deadline of the signature/request.
}

/// @notice A struct representing the full arguments of the multi revocation request.
struct MultiRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData[] data; // The arguments of the revocation request.
}

/// @notice A struct representing the full arguments of the delegated multi revocation request.
struct MultiDelegatedRevocationRequest {
    bytes32 schema; // The unique identifier of the schema.
    RevocationRequestData[] data; // The arguments of the revocation requests.
    Signature[] signatures; // The ECDSA signatures data. Please note that the signatures are assumed to be signed with increasing nonces.
    address revoker; // The revoking account.
    uint64 deadline; // The deadline of the signature/request.
}

/// @title IEAS
/// @notice EAS - Ethereum Attestation Service interface.
interface IEAS is ISemver {
    /// @notice Emitted when an attestation has been made.
    /// @param recipient The recipient of the attestation.
    /// @param attester The attesting account.
    /// @param uid The UID of the new attestation.
    /// @param schemaUID The UID of the schema.
    event Attested(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schemaUID);

    /// @notice Emitted when an attestation has been revoked.
    /// @param recipient The recipient of the attestation.
    /// @param attester The attesting account.
    /// @param schemaUID The UID of the schema.
    /// @param uid The UID the revoked attestation.
    event Revoked(address indexed recipient, address indexed attester, bytes32 uid, bytes32 indexed schemaUID);

    /// @notice Emitted when a data has been timestamped.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event Timestamped(bytes32 indexed data, uint64 indexed timestamp);

    /// @notice Emitted when a data has been revoked.
    /// @param revoker The address of the revoker.
    /// @param data The data.
    /// @param timestamp The timestamp.
    event RevokedOffchain(address indexed revoker, bytes32 indexed data, uint64 indexed timestamp);

    /// @notice Returns the address of the global schema registry.
    /// @return The address of the global schema registry.
    function getSchemaRegistry() external view returns (ISchemaRegistry);

    /// @notice Attests to a specific schema.
    /// @param request The arguments of the attestation request.
    /// @return The UID of the new attestation.
    ///
    /// Example:
    ///     attest({
    ///         schema: "0facc36681cbe2456019c1b0d1e7bedd6d1d40f6f324bf3dd3a4cef2999200a0",
    ///         data: {
    ///             recipient: "0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf",
    ///             expirationTime: 0,
    ///             revocable: true,
    ///             refUID: "0x0000000000000000000000000000000000000000000000000000000000000000",
    ///             data: "0xF00D",
    ///             value: 0
    ///         }
    ///     })
    function attest(AttestationRequest calldata request) external payable returns (bytes32);

    /// @notice Attests to a specific schema via the provided ECDSA signature.
    /// @param delegatedRequest The arguments of the delegated attestation request.
    /// @return The UID of the new attestation.
    ///
    /// Example:
    ///     attestByDelegation({
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: {
    ///             recipient: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    ///             expirationTime: 1673891048,
    ///             revocable: true,
    ///             refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
    ///             data: '0x1234',
    ///             value: 0
    ///         },
    ///         signature: {
    ///             v: 28,
    ///             r: '0x148c...b25b',
    ///             s: '0x5a72...be22'
    ///         },
    ///         attester: '0xc5E8740aD971409492b1A63Db8d83025e0Fc427e',
    ///         deadline: 1673891048
    ///     })
    function attestByDelegation(
        DelegatedAttestationRequest calldata delegatedRequest
    ) external payable returns (bytes32);

    /// @notice Attests to multiple schemas.
    /// @param multiRequests The arguments of the multi attestation requests. The requests should be grouped by distinct
    ///     schema ids to benefit from the best batching optimization.
    /// @return The UIDs of the new attestations.
    ///
    /// Example:
    ///     multiAttest([{
    ///         schema: '0x33e9094830a5cba5554d1954310e4fbed2ef5f859ec1404619adea4207f391fd',
    ///         data: [{
    ///             recipient: '0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf',
    ///             expirationTime: 1673891048,
    ///             revocable: true,
    ///             refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
    ///             data: '0x1234',
    ///             value: 1000
    ///         },
    ///         {
    ///             recipient: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    ///             expirationTime: 0,
    ///             revocable: false,
    ///             refUID: '0x480df4a039efc31b11bfdf491b383ca138b6bde160988222a2a3509c02cee174',
    ///             data: '0x00',
    ///             value: 0
    ///         }],
    ///     },
    ///     {
    ///         schema: '0x5ac273ce41e3c8bfa383efe7c03e54c5f0bff29c9f11ef6ffa930fc84ca32425',
    ///         data: [{
    ///             recipient: '0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf',
    ///             expirationTime: 0,
    ///             revocable: true,
    ///             refUID: '0x75bf2ed8dca25a8190c50c52db136664de25b2449535839008ccfdab469b214f',
    ///             data: '0x12345678',
    ///             value: 0
    ///         },
    ///     }])
    function multiAttest(MultiAttestationRequest[] calldata multiRequests) external payable returns (bytes32[] memory);

    /// @notice Attests to multiple schemas using via provided ECDSA signatures.
    /// @param multiDelegatedRequests The arguments of the delegated multi attestation requests. The requests should be
    ///     grouped by distinct schema ids to benefit from the best batching optimization.
    /// @return The UIDs of the new attestations.
    ///
    /// Example:
    ///     multiAttestByDelegation([{
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: [{
    ///             recipient: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    ///             expirationTime: 1673891048,
    ///             revocable: true,
    ///             refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
    ///             data: '0x1234',
    ///             value: 0
    ///         },
    ///         {
    ///             recipient: '0xdEADBeAFdeAdbEafdeadbeafDeAdbEAFdeadbeaf',
    ///             expirationTime: 0,
    ///             revocable: false,
    ///             refUID: '0x0000000000000000000000000000000000000000000000000000000000000000',
    ///             data: '0x00',
    ///             value: 0
    ///         }],
    ///         signatures: [{
    ///             v: 28,
    ///             r: '0x148c...b25b',
    ///             s: '0x5a72...be22'
    ///         },
    ///         {
    ///             v: 28,
    ///             r: '0x487s...67bb',
    ///             s: '0x12ad...2366'
    ///         }],
    ///         attester: '0x1D86495b2A7B524D747d2839b3C645Bed32e8CF4',
    ///         deadline: 1673891048
    ///     }])
    function multiAttestByDelegation(
        MultiDelegatedAttestationRequest[] calldata multiDelegatedRequests
    ) external payable returns (bytes32[] memory);

    /// @notice Revokes an existing attestation to a specific schema.
    /// @param request The arguments of the revocation request.
    ///
    /// Example:
    ///     revoke({
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: {
    ///             uid: '0x101032e487642ee04ee17049f99a70590c735b8614079fc9275f9dd57c00966d',
    ///             value: 0
    ///         }
    ///     })
    function revoke(RevocationRequest calldata request) external payable;

    /// @notice Revokes an existing attestation to a specific schema via the provided ECDSA signature.
    /// @param delegatedRequest The arguments of the delegated revocation request.
    ///
    /// Example:
    ///     revokeByDelegation({
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: {
    ///             uid: '0xcbbc12102578c642a0f7b34fe7111e41afa25683b6cd7b5a14caf90fa14d24ba',
    ///             value: 0
    ///         },
    ///         signature: {
    ///             v: 27,
    ///             r: '0xb593...7142',
    ///             s: '0x0f5b...2cce'
    ///         },
    ///         revoker: '0x244934dd3e31bE2c81f84ECf0b3E6329F5381992',
    ///         deadline: 1673891048
    ///     })
    function revokeByDelegation(DelegatedRevocationRequest calldata delegatedRequest) external payable;

    /// @notice Revokes existing attestations to multiple schemas.
    /// @param multiRequests The arguments of the multi revocation requests. The requests should be grouped by distinct
    ///     schema ids to benefit from the best batching optimization.
    ///
    /// Example:
    ///     multiRevoke([{
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: [{
    ///             uid: '0x211296a1ca0d7f9f2cfebf0daaa575bea9b20e968d81aef4e743d699c6ac4b25',
    ///             value: 1000
    ///         },
    ///         {
    ///             uid: '0xe160ac1bd3606a287b4d53d5d1d6da5895f65b4b4bab6d93aaf5046e48167ade',
    ///             value: 0
    ///         }],
    ///     },
    ///     {
    ///         schema: '0x5ac273ce41e3c8bfa383efe7c03e54c5f0bff29c9f11ef6ffa930fc84ca32425',
    ///         data: [{
    ///             uid: '0x053d42abce1fd7c8fcddfae21845ad34dae287b2c326220b03ba241bc5a8f019',
    ///             value: 0
    ///         },
    ///     }])
    function multiRevoke(MultiRevocationRequest[] calldata multiRequests) external payable;

    /// @notice Revokes existing attestations to multiple schemas via provided ECDSA signatures.
    /// @param multiDelegatedRequests The arguments of the delegated multi revocation attestation requests. The requests
    ///     should be grouped by distinct schema ids to benefit from the best batching optimization.
    ///
    /// Example:
    ///     multiRevokeByDelegation([{
    ///         schema: '0x8e72f5bc0a8d4be6aa98360baa889040c50a0e51f32dbf0baa5199bd93472ebc',
    ///         data: [{
    ///             uid: '0x211296a1ca0d7f9f2cfebf0daaa575bea9b20e968d81aef4e743d699c6ac4b25',
    ///             value: 1000
    ///         },
    ///         {
    ///             uid: '0xe160ac1bd3606a287b4d53d5d1d6da5895f65b4b4bab6d93aaf5046e48167ade',
    ///             value: 0
    ///         }],
    ///         signatures: [{
    ///             v: 28,
    ///             r: '0x148c...b25b',
    ///             s: '0x5a72...be22'
    ///         },
    ///         {
    ///             v: 28,
    ///             r: '0x487s...67bb',
    ///             s: '0x12ad...2366'
    ///         }],
    ///         revoker: '0x244934dd3e31bE2c81f84ECf0b3E6329F5381992',
    ///         deadline: 1673891048
    ///     }])
    function multiRevokeByDelegation(
        MultiDelegatedRevocationRequest[] calldata multiDelegatedRequests
    ) external payable;

    /// @notice Timestamps the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was timestamped with.
    function timestamp(bytes32 data) external returns (uint64);

    /// @notice Timestamps the specified multiple bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was timestamped with.
    function multiTimestamp(bytes32[] calldata data) external returns (uint64);

    /// @notice Revokes the specified bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was revoked with.
    function revokeOffchain(bytes32 data) external returns (uint64);

    /// @notice Revokes the specified multiple bytes32 data.
    /// @param data The data to timestamp.
    /// @return The timestamp the data was revoked with.
    function multiRevokeOffchain(bytes32[] calldata data) external returns (uint64);

    /// @notice Returns an existing attestation by UID.
    /// @param uid The UID of the attestation to retrieve.
    /// @return The attestation data members.
    function getAttestation(bytes32 uid) external view returns (Attestation memory);

    /// @notice Checks whether an attestation exists.
    /// @param uid The UID of the attestation to retrieve.
    /// @return Whether an attestation exists.
    function isAttestationValid(bytes32 uid) external view returns (bool);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return The timestamp the data was timestamped with.
    function getTimestamp(bytes32 data) external view returns (uint64);

    /// @notice Returns the timestamp that the specified data was timestamped with.
    /// @param data The data to query.
    /// @return The timestamp the data was timestamped with.
    function getRevokeOffchain(address revoker, bytes32 data) external view returns (uint64);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {IGatewayManager} from "src/interfaces/IGatewayManager.sol";
import {Attestation} from "eas-contracts/IEAS.sol";
import {UidOp} from "src/lib/OperationId.sol";

/**
 * @notice Structure representing token transfer details across chains
 * @dev Used for both locking and unlocking operations
 */
struct TokenTransfer {
    uint16 chainSelector; // Unique 16-bit Custom Chain ID where the Token is transfered
    bytes32 instrumentId; // Instrument ID associated with the security token
    bytes32 investorId; // Investor ID associated with the sender
    bytes receiver; // Recipient's address for minting/unlocking
    uint256 amount; // Amount of the asset to transfer
}

/**
 * @notice Structure for managing investor addresses across specific chain
 * @dev Each address change is encoded as: [1 byte action][n bytes address]
 */
struct ChainInvestorAddresses {
    // Unique investor ID
    bytes32 investorId;
    // Unique chain ID
    uint16 chainSelector;
    // Address size for that chain
    uint8 addressSize;
    // A list of concatenated bytes describing a change in addresses
    // Format `addressChanges`` := bytes1 action ++ bytes accountAddress
    // where `action`: 0b0 -> Add, 0b1 -> Remove
    bytes[] addressChanges;
}

/// @notice Interface for the Libre Core Gateway.
interface ILibreCoreGateway {
    // Events
    /**
     * @notice Emitted when tokens are locked on source chain
     * @param uid Unique identifier of the originating bridge operation
     * @param encodedTransferDetails ABI-encoded TokenTransfer struct
     */
    event TokenLockedAndBridged(bytes32 indexed uid, bytes encodedTransferDetails);

    /**
     * @notice Emitted when tokens are unlocked on destination chain
     * @param uid Unique identifier of the originating bridge operation
     * @param encodedTransferDetails ABI-encoded TokenTransfer struct
     */
    event TokenUnlocked(bytes32 indexed uid, bytes encodedTransferDetails);

    /**
     * @notice Emitted when a credential is bridged to other chains
     * @param investorId Investor ID of the investor
     * @param chainSelectors Array of destination chains where credential is bridged
     * @param uid Unique identifier of the originating bridge operation
     */
    event CredentialBridged(bytes32 indexed investorId, uint16[] chainSelectors, bytes32 indexed uid);

    /**
     * @notice Emitted when investor chain-specific addresses are bridged
     * @param uid Unique identifier of the originating bridge operation
     * @param investorId Investor ID of the investor
     * @param investorDestChainSelectors Array of destination chain selectors that investor has addresses on
     * @param encodedChainInvestorAddresses ABI-encoded ChainInvestorAddresses struct
     */
    event ChainInvestorAddressesBridged(
        bytes32 indexed uid,
        bytes32 investorId,
        uint16[] investorDestChainSelectors,
        bytes encodedChainInvestorAddresses
    );

    /**
     * @notice Emitted when chain support status is updated
     * @param chainSelector Chain ID whose support status changed
     * @param isSupported New support status
     */
    event ChainSupportUpdated(uint16 chainSelector, bool isSupported);

    /**
     * @notice Emitted when chain variable length address support status is updated
     * @param _chainSelector Chain ID whose support status changed
     * @param _isVariableLengthAddress New support status
     */
    event ChainVariableLengthAddressSupportUpdated(uint16 _chainSelector, bool _isVariableLengthAddress);

    // Custom Errors
    /// @notice Thrown when operation is attempted on an unsupported chain
    /// @param chainSelector The unsupported chain ID
    error CoreGateway_ChainNotSupported(uint16 chainSelector);

    /// @notice Thrown when the chain selector (chain ID) not matches with Native chain ID for unlock requests
    error CoreGateway_InvalidNativeChainSelector();

    /// @notice Thrown when token address is not found or invalid
    /// @param token The invalid token address
    error CoreGateway_TokenAddressNotFound(address token);

    /// @notice Thrown when attempting transfer with zero amount
    error CoreGateway_ZeroAmount();

    /// @notice Thrown when transfer validation fails
    error CoreGateway_InvalidTransfer();

    /// @notice Thrown when provided investor id is not found
    error CoreGateway_InvalidInvestor();

    /// @notice Thrown when wrong inputs are provided
    error CoreGateway_InvalidInput();

    /// @notice Thrown when credential to be bridged are not stored or mismatches with registry
    error CoreGateway_InvalidCredential();

    /// @notice Thrown when an attempted status update results in no actual change.
    error CoreGateway_NoStatusChanged();

    /// @notice Thrown when trying to use a UID that has already been used for a different operation
    error CoreGateway_UidAlreadyUsed();

    /// @notice Thrown when the UID operation state is invalid for the current operation
    error CoreGateway_InvalidUidOperation();

    /// @notice Thrown when trying to set operation to Unset
    error CoreGateway_CannotSetUnsetOperation();

    /**
     * @notice Initializes the gateway contract
     * @param _instrumentRegistry Address of the Instrument Registry
     * @param _investorRegistry Address of the Investor Registry
     * @param _gatewayManager Address of the Gateway Manager
     * @param _roleRegistry Address of the Role Registry
     * @param _supportedChains Array of supported custom chain Ids
     */
    function initialize(
        IInstrumentRegistry _instrumentRegistry,
        IInvestorRegistry _investorRegistry,
        IGatewayManager _gatewayManager,
        IRoleRegistry _roleRegistry,
        uint16[] memory _supportedChains
    ) external;

    /**
     * @notice Locks tokens for cross-chain transfer and emits event for minting
     * @dev Validates investor credentials and cross-chain addresses before locking
     * @param transferDetails The details of the token transfer.
     */
    function lockAndBridge(TokenTransfer calldata transferDetails) external;

    /**
     * @notice Unlocks tokens on the source chain
     * @dev Called by bridge operators to release tokens to the recipient
     * @param _senderRole The role of the caller
     * @param encodedTransferDetails ABI-encoded transfer details
     * @param uid Unique identifier of the originating bridge operation
     */
    function unlock(bytes32 _senderRole, bytes calldata encodedTransferDetails, bytes32 uid) external;

    /**
     * @notice Bridges a credential to one or more destination chains.
     * @dev Perform below steps:
     *      1. Verifies all destination chains are supported
     *      2. Validates the attestation matches the stored credential for the investor
     *      3. Emits CredentialBridged event for cross-chain communication
     * @param _senderRole The role of the caller
     * @param attestation The attestation details to bridge.
     * @param destinationChainSelectors Array of destination chain IDs.
     */
    function bridgeCredential(
        bytes32 _senderRole,
        Attestation calldata attestation,
        uint16[] calldata destinationChainSelectors
    ) external;

    /**
     * @notice Bridges investor addresses updates.
     * @dev Processes and broadcasts chain specific address changes across destination chains
     * Destination chains are extracted from _addressChanges to avoid parameter redundancy
     * UID is generated internally and nonce is incremented for operation tracking
     * Emits `ChainInvestorAddressesBridged` event for each chain's address updates.
     *
     * @param _senderRole The role of the caller for authorization
     * @param _investorId The unique identifier of the investor whose addresses are being updated
     * @param _addressChanges Array of encoded address changes containing chain and address information
     * @param investorDestChainSelectors Array of destination chain selectors that investor has addresses on
     */
    function bridgeInvestorAddresses(
        bytes32 _senderRole,
        bytes32 _investorId,
        bytes[] calldata _addressChanges,
        uint16[] calldata investorDestChainSelectors
    ) external;

    /**
     * @notice Pauses all gateway operations
     * @param _senderRole The role of the caller
     */
    function pause(bytes32 _senderRole) external;

    /**
     * @notice Unpauses gateway operations
     * @param _senderRole The role of the caller
     */
    function unpause(bytes32 _senderRole) external;

    /**
     * @notice Enables or disables support for a specific chain.
     * @param _senderRole The role of the caller
     * @param chainSelector The Custom chain ID.
     * @param isSupported Whether the chain is supported.
     */
    function setChainSupport(bytes32 _senderRole, uint16 chainSelector, bool isSupported) external;

    /**
     * @notice Enables or disables support for variable length addresses for a specific chain.
     * @param _senderRole The role of the caller
     * @param _chainSelector The Custom chain ID.
     * @param _isVariableLengthAddress Whether variable length addresses for the chain are supported.
     */
    function setChainVariableLengthAddressSupport(
        bytes32 _senderRole,
        uint16 _chainSelector,
        bool _isVariableLengthAddress
    ) external;

    /**
     * @notice Retrieves the total amount of a specific instrument/token locked in the gateway.
     * @param instrumentId The Instrument ID associated with the security token
     * @return The total amount of the token locked in the gateway
     */
    function getLockedBalance(bytes32 instrumentId) external view returns (uint256);

    /**
     * @notice Checks if a chain is supported.
     * @param chainSelector The ID of the chain to check.
     * @return True if the chain is supported, false otherwise.
     */
    function isSupportedChain(uint16 chainSelector) external view returns (bool);

    /**
     * @notice Gets the list of supported chains
     * @return uint16[] Array of supported chain IDs
     */
    function getSupportedChains() external view returns (uint16[] memory);

    /**
     * @notice Gets the last operation performed with a specific UID.
     * @param uid The unique identifier to query.
     * @return The last operation performed with the given UID.
     */
    function getUidLastOp(bytes32 uid) external view returns (UidOp);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20MetadataUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {IEAS, AttestationRequestData} from "eas-contracts/IEAS.sol";
import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

import {IBaseRegistry} from "src/interfaces/IBaseRegistry.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {IDealerRegistry} from "src/interfaces/IDealerRegistry.sol";
import {IOperationsEngine} from "src/interfaces/IOperationsEngine.sol";
import {IUserRegistry} from "src/interfaces/IUserRegistry.sol";
import {IGatewayManager} from "src/interfaces/IGatewayManager.sol";
import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";
import {OrderProofData, SteelProofData, CredentialProofData} from "src/utils/Types.sol";
import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

/**
 * @title IInvestorRegistry
 * @author Libre
 * @notice Interface for managing investors, including adding new investors, managing credentials, and verifying subscriptions.
 * It integrates with Ethereum Attestation Service (EAS) and zk-verifiers to ensure security and compliance.
 */
interface IInvestorRegistry is IBaseRegistry, IUserRegistry {
    /// @notice Thrown when an operation is not permitted due to insufficient privileges.
    error IInvestorRegistry_OperationNotPermitted();

    /// @notice Thrown when the sender is not the dealer associated with the specified investor.
    error IInvestorRegistry_NotInvestorsDealer();

    /// @notice Thrown when the caller is not the Operations Engine.
    error IInvestorRegistry_NotOperationsEngine();

    /// @notice Thrown when the caller is not the Jurisdiction Registry.
    error IInvestorRegistry_NotJurisdictionRegistry();

    /// @notice Thrown when attempting to add an investor who is already registered.
    error IInvestorRegistry_AlreadyAnInvestor();

    /// @notice Thrown when the sender does not have the Contract Manager role.
    error IInvestorRegistry_NoContractManagerRole();

    /// @notice Thrown when the Resolver Verifier address is empty or invalid.
    error IInvestorRegistry_EmptyResolverVerifier();

    /// @notice Thrown when the provided zk program image IDs are empty.
    error IInvestorRegistry_EmptyImageIDs();

    /// @notice Thrown when the sender does not have the Attester role.
    error IInvestorRegistry_NoAttesterRole();

    /// @notice Thrown when attempting to access a schema that has not been set.
    error IInvestorRegistry_SchemaNotSet();

    /// @notice Thrown when attempting to access a credential that does not exist.
    error IInvestorRegistry_NonExistingCredential();

    /// @notice Thrown when the credential is found to be invalid or revoked.
    error IInvestorRegistry_CredentialInvalid();

    /// @notice Thrown when the Investor Id doesn't match with the attestation's investor Id.
    error IInvestorRegistry_MismatchInvestorId();

    /// @notice Thrown when a credential does not grant access to the specified instrument.
    error IInvestorRegistry_InstrumentCredentialInvalid();

    /// @notice Thrown when attempting to revoke access to instruments that are not part of the credential.
    error IInvestorRegistry_InstrumentsToRevokeNotInCredential();

    /// @notice Thrown when there is a mismatch in the policy viewer proof.
    error IInvestorRegistry_PolicyViewerProofMismatch();

    /// @notice Thrown when an invalid dealer ID is provided.
    error IInvestorRegistry_InvalidDealerId();

    // Events
    /**
     * @notice Emitted when a new investor is added to the registry.
     * @param investorId The unique identifier of the new investor.
     * @param wallet The initial wallet address associated with the investor.
     */
    event NewInvestorAdded(bytes32 investorId, address wallet);

    /**
     * @notice Emitted when a credential is set for an investor.
     * @param investorId The unique identifier of the investor.
     * @param instrumentIds The list of instrument IDs included in the credential.
     */
    event InvestorRegistryCredentialSet(bytes32 investorId, bytes32[] instrumentIds);

    /**
     * @notice Emitted when a credential is revoked for an investor.
     * @param investorId The unique identifier of the investor.
     * @param instrumentIds The list of instrument IDs that have been revoked.
     */
    event InvestorRegistryCredentialRevoked(bytes32 investorId, bytes32[] instrumentIds);

    /**
     * @notice Emitted when the Resolver Verifier is updated.
     * @param resolverVerifierAddress The address of the new Resolver Verifier.
     */
    event InvestorRegistryResolverVerifierChanged(address resolverVerifierAddress);

    /**
     * @notice Emitted when the zk program image IDs are updated.
     * @param credentialImageID The new image ID for the credential zk program.
     * @param subscriptionImageID The new image ID for the subscription zk program.
     */
    event InvestorRegistryImageIDsChanged(bytes32 credentialImageID, bytes32 subscriptionImageID);

    /**
     * @notice Initialize the registry
     * @param _roleRegistry Address of the Role Registry
     * @param _instrumentRegistry Address of the Instrument Registry
     * @param _dealerRegistry Address of the Dealer Registry
     * @param _jurisdictionRegistry Address of the Jurisdiction Registry
     * @param _operationsEngine Address of the Operations Engine
     * @param _eas Address of the Ethereum Attestation Service contract
     * @param _gatewayManager Address of the gateway manager contract
     * @param _resolverVerifier Address of the Resolver Verifier
     * @param _policyViewer Address of the Policy Viewer
     */
    function initialize(
        IRoleRegistry _roleRegistry,
        IInstrumentRegistry _instrumentRegistry,
        IDealerRegistry _dealerRegistry,
        IEternalRegistryStorage _jurisdictionRegistry,
        IOperationsEngine _operationsEngine,
        IEAS _eas,
        IGatewayManager _gatewayManager,
        address _resolverVerifier,
        address _policyViewer
    ) external;

    /**
     * @notice Adds a new investor to the registry
     * @param _senderRole Role the sender claims to have
     * @param _investorId ID of the investor
     * @param _wallet Default address of the investor
     * @param _dealerId ID of the dealer
     */
    function addInvestor(bytes32 _senderRole, bytes32 _investorId, address _wallet, bytes32 _dealerId) external;

    /**
     * @notice Checks a subscription is allowed into the instrument
     * @param _proof proof data for zk verifier
     */
    function checkSubscription(OrderProofData calldata _proof) external view;

    /**
     * @notice Replaces the ResolverVerifier contract with a new version, renewing the schema in the process
     * @param _resolverVerifier address of new resolverVerifier
     */
    function configureResolverVerifier(address _resolverVerifier) external;

    /**
     * @notice Changes the zk program image IDs to use with the verifier
     * @param _credentialImageID new image ID for the credential zk program
     * @param _subscriptionImageID new image ID for the subscription zk program
     */
    function configureImageIDs(bytes32 _credentialImageID, bytes32 _subscriptionImageID) external;

    /**
     * @notice Creates a new investor credential or updates an existing/revoked one
     * @param _proof contains data for setting the credential, including the zk-proof to verify
     * @dev When updating credential, seal should contain the proof for new instruments, while
     * the journal should include existing ones to be kept, bridge new credential via gateway manager
     */
    function setCredential(CredentialProofData calldata _proof) external;

    /**
     * @notice Revokes an investor credential, or access to certain instruments, bridge revoked credential via gateway manager
     * @param _investorId Id of the investor
     * @param _instrumentIds Instruments to revoke access from (entire credential revoked if left empty)
     */
    function revokeCredential(bytes32 _investorId, bytes32[] calldata _instrumentIds) external;

    /**
     * @notice Checks if the investor has a valid credential
     * @param _investorId Id of the investor
     */
    function checkCredential(bytes32 _investorId) external view;

    /**
     * @notice Checks if the investor has a valid credential granting access to the instrument
     * @param _investorId Id of the investor
     * @param _instrumentId Id of the instrument
     */
    function checkCredentialInstrument(bytes32 _investorId, bytes32 _instrumentId) external view;

    /**
     * @notice Checks if the investor has a valid credential granting access to the instrument for cross-chain operations
     * @param _investorId Id of the investor
     * @param _instrumentId Id of the instrument
     * @dev Includes 1 day threshold validation for cross-chain operations
     */
    function checkCredentialInstrumentForCrossChain(bytes32 _investorId, bytes32 _instrumentId) external view;

    /**
     * @notice Get dealer id of an investor
     * @param _investorId The ID of the investor
     * @return dealerId_ Id of the dealer associated to the investor
     */
    function getDealer(bytes32 _investorId) external view returns (bytes32 dealerId_);

    /**
     * Used by the ResolverVerifier to fetch the proof data for the current attestation
     * @return Proof Data
     */
    function getTempSteelProofData() external view returns (SteelProofData memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {ILibreCoreGateway} from "src/interfaces/ILibreCoreGateway.sol";
import {IEAS} from "eas-contracts/IEAS.sol";

/**
 * @title IGatewayManager Interface
 * @notice Interface for managing cross-chain addresses and investor chain preferences
 * @dev Coordinates with LibreCoreGateway for cross-chain operations
 */
interface IGatewayManager {
    /**
     * @notice Emitted when an investor's preferred chains are updated or set
     * @param investorId The unique identifier of the investor
     * @param chains Array of custom chain IDs that the investor prefers
     * @param oldChains Previous array of chain IDs for the investor
     */
    event InvestorChainsUpdated(bytes32 investorId, uint16[] chains, uint16[] oldChains);

    /**
     * @notice Emitted when cross-chain addresses are updated for an investor
     * @dev Each address change is encoded as: [1 byte action][2 bytes chainSelector][n bytes address]
     * @param investorId The unique identifier of the investor
     * @param addressChanges A list of concatenated bytes describing a change in multi-chain address
     */
    event InvestorAddressesUpdated(bytes32 investorId, bytes[] addressChanges);

    /// @notice Thrown when an unsupported or invalid chain ID is provided
    error GatewayManager_InvalidChain();

    /// @notice Thrown when the investor ID doesn't exist or is invalid
    error GatewayManager_InvalidInvestor();

    /// @notice Thrown when input parameters are invalid or missing
    error GatewayManager_InvalidInput();

    /// @notice Thrown when a cross-chain address is already associated with another investor
    error GatewayManager_AddressAlreadyUsed();

    /**
     * @notice Initializes the gateway manager
     * @param _coreGateway Address of the LibreCoreGateway contract
     * @param _eas Address of the Ethereum Attestation Service
     * @param _investorRegistry Address of the InvestorRegistry contract
     * @param _roleRegistry Address of the RoleRegistry contract
     */
    function initialize(
        ILibreCoreGateway _coreGateway,
        IEAS _eas,
        IInvestorRegistry _investorRegistry,
        IRoleRegistry _roleRegistry
    ) external;

    /**
     * @notice Sets the preferred chains for an investor
     * @param _senderRole Role of the transaction sender
     * @param _investorId Unique identifier of the investor
     * @param _chains Array of chain IDs to set as preferred
     */
    function setInvestorChains(bytes32 _senderRole, bytes32 _investorId, uint16[] calldata _chains) external;

    /**
     * @notice Updates investor's cross-chain addresses and propagates changes to other chains
     * @dev Adds or removes addresses and bridges the updates to other chains
     * @param _senderRole Role of the transaction sender
     * @param _investorId Unique identifier of the investor
     * @param _addressChanges A list of concatenated bytes describing a change in multi-chain address
     */
    function manageCrossChainAddresses(bytes32 _senderRole, bytes32 _investorId, bytes[] calldata _addressChanges)
        external;

    /**
     * @notice Bridges a credential to all investor's preferred chains via core gateway.
     * @param _attestationId The unique ID of the attestation to be bridged.
     * @param _senderRole Role of the transaction sender.
     * @param _chains Chains to bridge credential to (all investor chains if empty)
     */
    function bridgeCredential(bytes32 _attestationId, bytes32 _senderRole, uint16[] memory _chains) external;

    /**
     * @notice Validates if an address is a valid cross-chain address for an investor
     * @param _investorId The investor ID to check
     * @param _chainSelector The chain ID to check
     * @param _address The address to validate
     * @return bool True if the address is valid for the investor on the chain
     */
    function isValidCrossChainAddress(bytes32 _investorId, uint16 _chainSelector, bytes calldata _address)
        external
        view
        returns (bool);

    /**
     * @notice Gets an investor's preferred chains
     * @param _investorId The investor's unique identifier
     * @return uint16[] Array of preferred chain IDs
     */
    function getInvestorChains(bytes32 _investorId) external view returns (uint16[] memory);

    /**
     * @notice Gets the owner of a cross-chain address
     * @param _chainSelector The chain ID of the address
     * @param _address The address to get the owner of
     * @return bytes32 The owner of the address
     */
    function getAddressOwner(uint16 _chainSelector, bytes calldata _address) external view returns (bytes32);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IAccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/IAccessControlUpgradeable.sol";

/**
 * @title Roles Registry
 * @author Libre
 * @notice Store all the roles of the system as well as the permissions a user get by having each role.
 * @dev It is meant to be used for roles access validation in all the components of the system.
 */
interface IRoleRegistry is IAccessControlUpgradeable {
    /**
     * @notice Thrown when attempting to create a role that already exists.
     */
    error IRoleRegistry_RoleAlreadyExists();

    /**
     * @notice Thrown when attempting to grant a role that does not exist.
     */
    error IRoleRegistry_RoleDoesNotExist();

    /**
     * @notice Thrown when attempting to use a blacklisted wallet.
     */
    error IRoleRegistry_WalletBlacklisted();

    /**
     * @notice Used when a new role is created
     * @param _role Parent role
     * @param _subRole Newly created Role
     */
    event RoleCreated(bytes32 _role, bytes32 _subRole);

    /**
     * @notice Used when a contract manager is set
     * @param _contract Contract managed
     * @param _roleManager New contract manager role
     */
    event ContractManagerAdded(address _contract, bytes32 _roleManager);

    /**
     * @notice Used when a wallet is blacklisted
     * @param _wallet Wallet blacklisted
     */
    event WalletBlacklisted(address _wallet);

    /**
     * @notice Used when a contract function access is granted
     * @param _contract Contract managed
     * @param _selector Selector of the funtion which access is modified
     * @param _role Role getting access gratend
     */
    event AccessGranted(address _contract, bytes4 _selector, bytes32 _role);

    /**
     * @notice Used when a contract function access is revoked
     * @param _contract Contract managed
     * @param _selector Selector of the funtion which access is modified
     * @param _role Role which access is revoked
     */
    event RevokedAccess(address _contract, bytes4 _selector, bytes32 _role);

    /**
     * @notice Used when a contract access is reset
     * @param _contract Contract managed
     * @param _timestamp Time when the reset is executed
     */
    event ResetedAccess(address _contract, uint256 _timestamp);

    /**
     * @notice Function to create subroles
     * @param _role New role to create
     * @param _adminRole Parent role of the newly created role
     * @dev Caller needs to has role _adminRole
     */
    function createRole(bytes32 _role, bytes32 _adminRole) external;

    /**
     * @notice Set the role going to manage permissions in a specific contract
     * @param _contract Address of the contract to where permissions are needed to be managed
     * @param _roleManager Role in charge of managing the permissions
     */
    function setContractManager(address _contract, bytes32 _roleManager) external;

    /**
     * @notice Get the role that manages permissions in a specific contract
     * @param _contract Address of the contract
     */
    function getContractManager(address _contract) external view returns (bytes32);

    /**
     * @notice Grant a role the right access a functionality of a contract
     * @param _contract Contract where the access is granted
     * @param _selector Functionality granted access for
     * @param _role Role getting the access
     */
    function grantAccess(address _contract, bytes4 _selector, bytes32 _role) external;

    /**
     * @notice Prevent a role for having access to a functionality of a contract
     * @param _contract Contract where the access is revoked
     * @param _selector Functionality revoked access for
     * @param _role Role losing the access
     */
    function revokeAccess(address _contract, bytes4 _selector, bytes32 _role) external;

    /**
     * @notice Revoke access to a functionality of a contract for all roles
     * @param _contract Contract where the access is reset
     * @param _selector Functionality reset access for
     * @dev Cleans all the previously granted roles
     */
    function resetAccess(address _contract, bytes4 _selector) external;

    /**
     * @notice Blacklists a wallet.
     * @param _wallet The wallet to blacklist.
     */
    function blacklistWallet(address _wallet) external;

    /**
     * @notice Check access of a role to a contract functionality
     * @param _contract Contract where accessed
     * @param _selector Functionality accessed
     * @param _requestor Address attempting to access
     * @param _role Role of the address attempting to access
     */
    function hasAccess(address _contract, bytes4 _selector, address _requestor, bytes32 _role)
        external
        view
        returns (bool);

    /**
     * @notice Checks if a wallet is blacklisted.
     * @param _wallet The wallet to check.
     * @return Boolean indicating whether the wallet is blacklisted.
     */
    function isBlacklisted(address _wallet) external view returns (bool);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IBaseRegistry} from "src/interfaces/IBaseRegistry.sol";
import {IDealerRegistry} from "src/interfaces/IDealerRegistry.sol";
import {IFundRegistry} from "src/interfaces/IFundRegistry.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IOperationsEngine} from "src/interfaces/IOperationsEngine.sol";
import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";

/**
 * @title IInstrumentRegistry
 * @author Libre
 * @notice Interface for managing instruments within a fund registry system.
 * Provides functionalities to initialize, add, and manage instruments, track their subscription and redemption periods,
 * update Net Asset Value (NAV) per share, and manage investor access.
 */
interface IInstrumentRegistry is IBaseRegistry {
    /**
     * @notice Thrown when attempting to add an instrument that already exists in the registry.
     */
    error IInstrumentRegistry_InstrumentAlreadyExists();

    /**
     * @notice Thrown when the specified instrument does not exist in the registry.
     */
    error IInstrumentRegistry_InstrumentDoesNotExist();

    /**
     * @notice Thrown when attempting to initialize an instrument that has already been initialized.
     */
    error IInstrumentRegistry_InstrumentAlreadyInitialized();

    /**
     * @notice Emited when a new instrument is added
     * @param fundId Id of the fund where the instrument is added
     * @param instrumentId Id of the new instrument
     */
    event NewFundInstrumentAdded(bytes32 indexed fundId, bytes32 indexed instrumentId);

    /**
     * @notice Emited when an instrument is initialized
     * @param instrumentId Id of the new instrument
     * @param settlementToken Address of the settlement token of the instrument
     * @param securityToken Address of the deployed security token
     * @param subscriptionBook Address of the deployed subscription book
     * @param redemptionBook Address of the deployed redemption book
     */
    event FundInstrumentInitialized(
        bytes32 indexed instrumentId,
        address settlementToken,
        address securityToken,
        address subscriptionBook,
        address redemptionBook
    );

    /**
     * @notice Emited when an instrument is closed
     * @param instrumentId Id of the instrument
     */
    event InstrumentClosed(bytes32 indexed instrumentId);

    /**
     * @notice Emited when an instrument is paused
     * @param instrumentId Id of the instrument
     * @param paused Y/N value indicating if the instrument is paused or not
     */
    event InstrumentPaused(bytes32 indexed instrumentId, bool paused);

    /**
     * @notice Emited when an investor's allowlist status is updated for an instrument
     * @param instrumentId Id of the instrument
     * @param investorId Id of the investor
     * @param allowed Y/N value indicating if the investor is allowed or not
     */
    event InvestorAllowedUpdated(bytes32 indexed instrumentId, bytes32 indexed investorId, bool allowed);

    /**
     * @notice Initialize the registry
     * @param _roleRegistry Address of the Role Registry
     * @param _investorRegistry Address of the Investor Registry
     * @param _dealerRegistry Address of the Dealer Registry
     * @param _fundRegistry Address of the Fund Registry
     * @param _jurisdictionRegistry Address of the Jurisdiction Registry
     * @param _operationsEngine Address of the Rules Engine
     */
    function initialize(
        IRoleRegistry _roleRegistry,
        IInvestorRegistry _investorRegistry,
        IDealerRegistry _dealerRegistry,
        IFundRegistry _fundRegistry,
        IEternalRegistryStorage _jurisdictionRegistry,
        IOperationsEngine _operationsEngine
    ) external;

    /**
     * @notice Adds a new fund instrument to the registry
     * @dev _senderRole is ignored if the caller if the Fund Admin of the instrument
     * @param _senderRole Role of the sender which allow the operation execution
     * @param _instrumentId the instrument ID
     * @param _fundId the fund ID
     */
    function addFundInstrument(bytes32 _senderRole, bytes32 _instrumentId, bytes32 _fundId) external;

    /**
     * @notice Adds a new instrument to the registry
     * @dev _senderRole is ignored if the caller if the Fund Admin of the instrument
     * @param _senderRole Role of the sender which allow the operation execution
     * @param _instrumentId the instrument ID
     * @param _settlementToken settlement token address
     * @param _name the instrument token name
     * @param _symbol the instrument token symbol
     * @param _subscriptionBookImp The implementation of subscription book to be cloned
     * @param _redemptionBookImp The implementation of redemption book to be cloned
     * @param _stTokenImpl The implementation of security token implementation to be cloned
     * @param _treasury The address of instrument treasury
     * @param _policyViewerAddress The address of instrument policy viewer
     */
    function initializeFundInstrument(
        bytes32 _senderRole,
        bytes32 _fundId,
        bytes32 _instrumentId,
        address _settlementToken,
        string memory _name,
        string memory _symbol,
        address _subscriptionBookImp,
        address _redemptionBookImp,
        address _stTokenImpl,
        address _treasury,
        address _policyViewerAddress
    ) external;

    /**
     * @notice Close a fund instrument
     * @param _senderRole Role of the sender which allow the operation execution
     * @param _instrumentId The ID of the instrument
     */
    function closeFundInstrument(bytes32 _senderRole, bytes32 _instrumentId) external;

    /**
     * @notice Return the number of the current subscription period or
     * 0 in case subscription is not started or infinite if subscriptions are done
     * @dev Infinite is represented by type(uint256).max;
     * @param _instrumentId Id of the instrument
     * @return The current period of the subscription, the start & the end of it
     */
    function currentSubscriptionPeriod(bytes32 _instrumentId) external view returns (uint256, uint256, uint256);

    /**
     * @notice Return the number of the current redemption period or
     * 0 in case redemption is not started or infinite if redemptions are done
     * @param _instrumentId Id of the instrument
     * @return The current period of the redemption, the start & the end of it
     */
    function currentRedemptionPeriod(bytes32 _instrumentId) external view returns (uint256, uint256, uint256);

    /**
     * @notice Sets a new value for the audited NAV per share of a fund
     * @param _senderRole Role of the sender which allow the operation execution
     * @param _instrumentId ID of the fund
     * @param _newNavPerShare new value of the nav
     * @dev Expressed with 6 decimals as it is in settlement tokens units
     */
    function updateAuditedNavPerShare(bytes32 _senderRole, bytes32 _instrumentId, uint256 _newNavPerShare) external;

    /**
     * @notice Allow investor for a specific instrument
     * @param _instrumentId The ID of the instrument
     * @param _investorId Id of the investor
     * @param _allowed Y/N value indicating if the investor is allowed or not
     * @param _senderRole Role of the sender
     */
    function allowInvestor(bytes32 _instrumentId, bytes32 _investorId, bool _allowed, bytes32 _senderRole) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20MetadataUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IOperationsEngine} from "src/interfaces/IOperationsEngine.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";

/**
 * @title ISecurityToken
 * @author Libre
 * @notice Interface for managing a security token associated with an instrument.
 * Provides functions for issuing, burning, and transferring tokens, as well as retrieving investor and holder information.
 * @dev This interface extends the `IERC20MetadataUpgradeable` for ERC20 token standard compliance.
 */
interface ISecurityToken is IERC20MetadataUpgradeable {
    /**
     * @notice Thrown when a non-subscription book contract attempts to issue tokens.
     */
    error ISecurityToken_OnlySubscriptionBookCanIssueTokens();

    /**
     * @notice Thrown when a non-redemption book contract attempts to burn tokens.
     */
    error ISecurityToken_OnlyRedemptionBookCanBurnTokens();

    /**
     * @notice Thrown when a non-redemption book or core gateway contract attempts to perform a forced transfer.
     */
    error ISecurityToken_OnlyRedemptionBookOrGatewayCanForceTransfer();

    /**
     * @notice Thrown when attempting to transfer zero tokens, which is not allowed.
     */
    error ISecurityToken_ZeroValueTransfersNotAllowed();

    /**
     * @notice Thrown when the instrument is paused.
     */
    error ISecurityToken_InstrumentPaused();

    /**
     * @notice Thrown when from address for transfer is zero
     */
    error ISecurityToken_InvalidSender();

    /**
     * @notice Thrown when to address for transfer is zero
     */
    error ISecurityToken_InvalidReceiver();

    /**
     * @notice Emitted when the name and symbol of the security token are updated.
     * @param _name The new name of the token.
     * @param _symbol The new symbol of the token.
     */
    event NameAndSymbolChanged(string _name, string _symbol);

    /**
     * @notice Issue tokens to an address
     * @param _holder Address of the receiver
     * @param _amount Amount issued
     */
    function issue(address _holder, uint256 _amount) external;

    /**
     * @notice Burn tokens from the caller
     * @param _amount Amount burned
     */
    function burn(uint256 _amount) external;

    /**
     * @notice Initializes the security token
     * @param _instrumentId Id of the instrument the security token is associated to
     * @param _name Name of the token
     * @param _symbol Symbol of the token
     * @param _operationsEngine Address of the instrument's operations engine
     * @param _subscriptionBook Address of the instrument's subscription book
     * @param _redemptionBook Address of the instrument's redemption book
     * @param _instrumentRegistry Address of the instrument registry
     * @param _investorRegistry Address of the investor registry
     * @param _roleRegistry Address of the role registry
     */
    function initialize(
        bytes32 _instrumentId,
        string memory _name,
        string memory _symbol,
        IOperationsEngine _operationsEngine,
        address _subscriptionBook,
        address _redemptionBook,
        IInstrumentRegistry _instrumentRegistry,
        IInvestorRegistry _investorRegistry,
        IRoleRegistry _roleRegistry
    ) external;

    /**
     * @notice Forced transfer execution
     * @dev Only callable by redemption book or by Libre Admin in case of blacklisted wallets
     * @param _from Address from where assets are transferred
     * @param _to Address where tokens were sent
     * @param _amount Amount of tokens sent
     * @param _role Role required to make the transfer
     */
    function forceTransfer(address _from, address _to, uint256 _amount, bytes32 _role) external;

    /**
     * @notice Changes the name and symbol of the token
     * @param _name New name
     * @param _symbol New symbol
     * @param _role Role required to make the change
     */
    function changeNameAndSymbol(string calldata _name, string calldata _symbol, bytes32 _role) external;

    /**
     * @notice Gets the aggregate balance of an investor
     * @param _investorId Investor to get the balance of
     * @return Balance value
     */
    function getInvestorBalance(bytes32 _investorId) external view returns (uint256);

    /**
     * @notice Gets the ID of the Instrument this token is associated to
     * @return Instrument ID
     */
    function getInstrumentId() external view returns (bytes32);

    /**
     * @notice Get the number of holders of the token
     * @return Amount of holders
     * @dev Only valid investors are counted
     */
    function getHolders() external view returns (uint256);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ERC1967UtilsUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/proxy/ERC1967/ERC1967UtilsUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import {PermissionedContract} from "src/PermissionedContract.sol";

/**
 * @title LibreUUPSUpgradeable
 * @author Libre
 * @notice An extension of UUPSUpgradeable with role-based access control for upgrades.
 * @dev Integrates UUPSUpgradeable and PermissionedContract to provide secured upgrade functionalities.
 */
contract LibreUUPSUpgradeable is UUPSUpgradeable, PermissionedContract {
    /// @dev Error thrown when a restricted function is called directly.
    error LibreUUPSUpgradeable_WrongUpgradeToFunction();

    /**
     * @notice Retrieve the address of the current implementation.
     * @return The address of the current implementation.
     */
    function getImplementation() external view returns (address) {
        return ERC1967UtilsUpgradeable.getImplementation();
    }

    /**
     * @notice Upgrade the contract to a new implementation with a specific role and optionally execute a call.
     * @param _newImplementation The address of the new implementation contract.
     * @param _role The role required to perform the upgrade.
     * @param _data The data for the function call to execute after the upgrade.
     */
    function upgradeToWithRoleAndCall(address _newImplementation, bytes32 _role, bytes memory _data)
        public
        payable
        virtual
        onlyProxy
    {
        _checkRoleHasAccess(_role);
        ERC1967UtilsUpgradeable.upgradeToAndCallUUPS(_newImplementation, _data, true);
    }

    /**
     * @notice Override to prevent direct usage of the `upgradeToAndCall` function.
     * @dev Always reverts with a custom error.
     */
    function upgradeToAndCall(address, bytes memory) public payable virtual override onlyProxy {
        revert LibreUUPSUpgradeable_WrongUpgradeToFunction();
    }

    /**
     * @notice Upgrade the contract to a new implementation with a specific role.
     * @param _newImplementation The address of the new implementation contract.
     * @param _role The role required to perform the upgrade.
     */
    function upgradeToWithRole(address _newImplementation, bytes32 _role) public virtual onlyProxy {
        _checkRoleHasAccess(_role);
        ERC1967UtilsUpgradeable.upgradeToAndCallUUPS(_newImplementation, new bytes(0), false);
    }

    /**
     * @notice Override to prevent direct usage of the `upgradeTo` function.
     * @dev Always reverts with a custom error.
     */
    function upgradeTo(address) public virtual override onlyProxy {
        revert LibreUUPSUpgradeable_WrongUpgradeToFunction();
    }

    /**
     * @notice Internal function to authorize an upgrade.
     * @dev Can be overridden by derived contracts to implement custom logic.
     * @notice param _newImplementation The address of the new implementation contract (not used).
     */
    function _authorizeUpgrade(address) internal view virtual override {}
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IGatewayManager} from "src/interfaces/IGatewayManager.sol";

/**
 * @title GatewayUtils
 * @author Libre
 * @notice Utility functions for gateway contracts
 * @dev Shared utilities used by LibreCoreGateway and GatewayManager
 */
library GatewayUtils {
    /**
     * @notice Error thrown when input data is invalid
     */
    error GatewayUtils_InvalidInput();

    /**
     * @notice Bridges wallet address changes to other chains
     * @param _gatewayManager The gateway manager contract
     * @param _userId The ID of the user
     * @param _wallet The wallet address being added or removed
     * @param _isAdd True if adding a wallet, false if removing
     * @param _nativeChainSelector The chain selector for the native chain
     * @param _gatewayManagerRole The role required for cross-chain operations
     */
    function bridgeAddressChange(
        IGatewayManager _gatewayManager,
        bytes32 _userId,
        address _wallet,
        bool _isAdd,
        uint16 _nativeChainSelector,
        bytes32 _gatewayManagerRole
    ) public {
        if (address(_gatewayManager) == address(0)) {
            return;
        }

        bytes memory addressChange = encodeAddressChange(_wallet, _isAdd, _nativeChainSelector);

        bytes[] memory addressChanges = new bytes[](1);
        addressChanges[0] = addressChange;

        // Bridge the address change to other chains
        _gatewayManager.manageCrossChainAddresses(_gatewayManagerRole, _userId, addressChanges);
    }

    /**
     * @notice Decodes an address change byte array
     * @param addressChange The encoded address change
     * @return isAdd True if adding an address, false if removing
     * @return chainId The chain ID for the address
     * @return walletAddress The wallet address being added or removed
     */
    function decodeAddressChange(bytes calldata addressChange)
        public
        pure
        returns (bool isAdd, uint16 chainId, bytes memory walletAddress)
    {
        // excluding the action and chainId, the address has to be of at least one byte
        if (addressChange.length < 4) {
            revert GatewayUtils_InvalidInput();
        }

        // Extract isAdd, first byte (0 -> Add, 1 -> Remove)
        isAdd = addressChange[0] == 0x00;

        // Extract chainId (bytes 1-2)
        chainId = uint16(uint8(addressChange[1])) << 8 | uint16(uint8(addressChange[2]));

        // Remaining bytes are the wallet address
        uint256 walletLength = addressChange.length - 3;
        walletAddress = new bytes(walletLength);
        for (uint256 i; i < walletLength; ++i) {
            walletAddress[i] = addressChange[i + 3];
        }
    }

    /**
     * @notice Creates an encoded address change
     * @param _wallet The wallet address being added or removed
     * @param _isAdd True if adding a wallet, false if removing
     * @param _chainSelector The chain selector for the chain
     * @return The encoded address change
     */
    function encodeAddressChange(address _wallet, bool _isAdd, uint16 _chainSelector)
        public
        pure
        returns (bytes memory)
    {
        // Create the address change encoding: [action byte][2 bytes chainSelector][n bytes address]
        bytes memory addressChange = new bytes(23); // 1 byte action + 2 bytes chainSelector + 20 bytes address
        addressChange[0] = _isAdd ? bytes1(0x00) : bytes1(0x01); // 0x00 for add, 0x01 for remove

        // Set the chainSelector
        addressChange[1] = bytes1(uint8(_chainSelector >> 8));
        addressChange[2] = bytes1(uint8(_chainSelector));

        // Copy the wallet address bytes
        bytes memory walletBytes = abi.encodePacked(_wallet);
        for (uint256 i = 0; i < 20; i++) {
            addressChange[i + 3] = walletBytes[i];
        }

        return addressChange;
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// Enum representing last operation with UID
enum UidOp {
    Unset, // default value for unset entries
    MintUnlock,
    BurnLock,
    CredentialSync,
    AddressSync
}

/**
 * @title OperationId
 * @notice Library for generating unique identifiers for cross-chain operations
 * @dev Used to create consistent UIDs across source and destination chains
 */
library OperationId {
    /**
     * @notice Generate a new unique id for the bridge operation
     * @param _nonce Current operation nonce
     * @param _sourceChainSelector Chain selector of the source chain
     * @param _destChainSelector Chain selector of the destination chain
     * @param _investorId Investor ID bytes
     * @return bytes32 Unique operation identifier
     */
    function generate(uint128 _nonce, uint16 _sourceChainSelector, uint16 _destChainSelector, bytes32 _investorId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_nonce, _sourceChainSelector, _destChainSelector, _investorId));
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "src/utils/JurisdictionEncodings.sol";
import "src/utils/Types.sol";

// General Config
bytes32 constant TIMEZONE = keccak256("TIMEZONE");
bytes32 constant MAX_TIMEZONE = keccak256("MAX_TIMEZONE");

// Chain/Gateway Config
uint16 constant NATIVE_CHAIN_SELECTOR = 101;

// NAV
bytes32 constant AUDITED_NAV_PER_SHARE = keccak256("AUDITED_NAV_PER_SHARE");
bytes32 constant INSTRUMENT_ALLOWED_ADDRESSES = keccak256("INSTRUMENT_ALLOWED_ADDRESSES");

// Volatility
bytes32 constant ANNUALIZED_VOLATILITY = keccak256("ANNUALIZED_VOLATILITY");

// Subscription Config
bytes32 constant SUBSCRIPTION_PHASES = keccak256("SUBSCRIPTION_PHASES");
bytes32 constant SUBSCRIPTION_START = keccak256("SUBSCRIPTION_START");
bytes32 constant SUBSCRIPTION_END = keccak256("SUBSCRIPTION_END");
bytes32 constant SUBSCRIPTION_FREQUENCY = keccak256("SUBSCRIPTION_FREQUENCY");
bytes32 constant SUBSCRIPTION_FREQUENCY_TIME_UNIT = keccak256("SUBSCRIPTION_FREQUENCY_TIME_UNIT");

// Redemption Config
bytes32 constant REDEMPTION_START = keccak256("REDEMPTION_START");
bytes32 constant REDEMPTION_END = keccak256("REDEMPTION_END");
bytes32 constant REDEMPTION_FREQUENCY = keccak256("REDEMPTION_FREQUENCY");
bytes32 constant REDEMPTION_FREQUENCY_TIME_UNIT = keccak256("REDEMPTION_FREQUENCY_TIME_UNIT");

// Fund data
bytes32 constant FUND_ID = keccak256("FUND_ID");
bytes32 constant DISCLOSURE_DOCUMENTS = keccak256("DISCLOSURE_DOCUMENTS");
bytes32 constant LISTED_ON_REGULATED_VENUE = keccak256("LISTED_ON_REGULATED_VENUE");
bytes32 constant LOCAL_AIFM = keccak256("LOCAL_AIFM");
bytes32 constant NON_EU_AIFM = keccak256("NON_EU_AIFM");

// Fund Instruments data
bytes32 constant INSTRUMENT_TOKEN = keccak256("INSTRUMENT_TOKEN");
bytes32 constant LOCAL_INVESTOR_MINIMUM_HOLDING = keccak256("LOCAL_INVESTOR_MINIMUM_HOLDING");
bytes32 constant AGGREGATED_MINIMUM_REDEMPTION_VALUE = keccak256("AGGREGATED_MINIMUM_REDEMPTION_VALUE");
bytes32 constant AGGREGATED_MINIMUM_SUBSEQUENT_SUBSCRIPTION = keccak256("AGGREGATED_MINIMUM_SUBSEQUENT_SUBSCRIPTION");
bytes32 constant INVESTOR_MINIMUM_INITIAL_SUBSCRIPTION = keccak256("INVESTOR_MINIMUM_INITIAL_SUBSCRIPTION");
bytes32 constant INVESTOR_MINIMUM_SUBSEQUENT_SUBSCRIPTION = keccak256("INVESTOR_MINIMUM_SUBSEQUENT_SUBSCRIPTION");
bytes32 constant REDEMPTION_BOOK = keccak256("REDEMPTION_BOOK");
bytes32 constant SUBSCRIPTION_BOOK = keccak256("SUBSCRIPTION_BOOK");

// Subscription Cutoff
bytes32 constant SUBSCRIPTION_CUT_OFF_CALENDAR_DAYS = keccak256("SUBSCRIPTION_CUT_OFF_CALENDAR_DAYS");
bytes32 constant SUBSCRIPTION_CUT_OFF_BUSINESS_DAYS = keccak256("SUBSCRIPTION_CUT_OFF_BUSINESS_DAYS");
bytes32 constant SUBSCRIPTION_CUT_OFF_TIME = keccak256("SUBSCRIPTION_CUT_OFF_TIME");
bytes32 constant SUBSCRIPTION_CUT_OFF_PERIOD = keccak256("SUBSCRIPTION_CUT_OFF_PERIOD");

bytes32 constant LOCAL_AGGREGATE_MINIMUM_HOLDING = keccak256("LOCAL_AGGREGATE_MINIMUM_HOLDING");
bytes32 constant SUBSCRIPTION_SIZE_MULTIPLE = keccak256("SUBSCRIPTION_SIZE_MULTIPLE");
bytes32 constant GLOBAL_AGGREGATE_MINIMUM_BREACH = keccak256("GLOBAL_AGGREGATE_MINIMUM_BREACH");
bytes32 constant FORCED_REDEMPTION_TOP_UP_PERIOD = keccak256("FORCED_REDEMPTION_TOP_UP_PERIOD");
bytes32 constant FORCED_REDEMPTION_TOP_UP_PERIOD_UNIT = keccak256("FORCED_REDEMPTION_TOP_UP_PERIOD_UNIT");
bytes32 constant REDEMPTION_VOLUME_LIMIT = keccak256("REDEMPTION_VOLUME_LIMIT");
bytes32 constant REDEMPTION_VOLUME_LIMIT_PER_INVESTOR = keccak256("REDEMPTION_VOLUME_LIMIT_PER_INVESTOR");
bytes32 constant REDEMPTION_VOLUME_LIMIT_PER_INVESTOR_FEE = keccak256("REDEMPTION_VOLUME_LIMIT_PER_INVESTOR_FEE");
bytes32 constant REDEMPTION_LOOKBACK_PERIOD = keccak256("REDEMPTION_LOOKBACK_PERIOD");
bytes32 constant REDEMPTION_LOOKBACK_PERIOD_UNIT = keccak256("REDEMPTION_LOOKBACK_PERIOD_UNIT");
bytes32 constant GATE_CRITERIA_1 = keccak256("GATE_CRITERIA_1");
bytes32 constant REDEMPTION_NOTICE_PERIOD = keccak256("REDEMPTION_NOTICE_PERIOD");
bytes32 constant REDEMPTION_NOTICE_PERIOD_UNIT = keccak256("REDEMPTION_NOTICE_PERIOD_UNIT");
bytes32 constant REDEMPTION_CUT_OFF_PERIOD = keccak256("REDEMPTION_CUT_OFF_PERIOD");
// Calendar
bytes32 constant BUSINESS_DAY_BITMAP_PART_1 = keccak256("BUSINESS_DAY_BITMAP_PART_1");
bytes32 constant BUSINESS_DAY_BITMAP_PART_2 = keccak256("BUSINESS_DAY_BITMAP_PART_2");

// Redemption Cutoff
bytes32 constant REDEMPTION_CUT_OFF_CALENDAR_DAYS = keccak256("REDEMPTION_CUT_OFF_CALENDAR_DAYS");
bytes32 constant REDEMPTION_CUT_OFF_BUSINESS_DAYS = keccak256("REDEMPTION_CUT_OFF_BUSINESS_DAYS");
bytes32 constant REDEMPTION_CUT_OFF_TIME = keccak256("REDEMPTION_CUT_OFF_TIME");

// Execution Date
bytes32 constant SUBSCRIPTION_NOTICE_PERIOD_CALENDAR_MONTHS = keccak256("SUBSCRIPTION_NOTICE_PERIOD_CALENDAR_MONTHS");
bytes32 constant SUBSCRIPTION_NOTICE_PERIOD_CALENDAR_DAYS = keccak256("SUBSCRIPTION_NOTICE_PERIOD_CALENDAR_DAYS");
bytes32 constant SUBSCRIPTION_NOTICE_PERIOD_BUSINESS_DAYS = keccak256("SUBSCRIPTION_NOTICE_PERIOD_BUSINESS_DAYS");
bytes32 constant SUBSCRIPTION_CUTOFF_TIME = keccak256("SUBSCRIPTION_CUTOFF_TIME");
bytes32 constant WAIVE_SUBSCRIPTION_NOTICE_PERIOD = keccak256("WAIVE_SUBSCRIPTION_NOTICE_PERIOD");
bytes32 constant SUBSCRIPTION_PREADJUSTMENT_DEALING_DAY_OF_MONTH =
    keccak256("SUBSCRIPTION_PREADJUSTMENT_DEALING_DAY_OF_MONTH");
bytes32 constant REDEMPTION_NOTICE_PERIOD_CALENDAR_MONTHS = keccak256("REDEMPTION_NOTICE_PERIOD_CALENDAR_MONTHS");
bytes32 constant REDEMPTION_NOTICE_PERIOD_CALENDAR_DAYS = keccak256("REDEMPTION_NOTICE_PERIOD_CALENDAR_DAYS");
bytes32 constant REDEMPTION_NOTICE_PERIOD_BUSINESS_DAYS = keccak256("REDEMPTION_NOTICE_PERIOD_BUSINESS_DAYS");
bytes32 constant REDEMPTION_CUTOFF_TIME = keccak256("REDEMPTION_CUTOFF_TIME");
bytes32 constant WAIVE_REDEMPTION_NOTICE_PERIOD = keccak256("WAIVE_REDEMPTION_NOTICE_PERIOD");
bytes32 constant REDEMPTION_PREADJUSTMENT_DEALING_DAY_OF_MONTH =
    keccak256("REDEMPTION_PREADJUSTMENT_DEALING_DAY_OF_MONTH");

// Redemption Holding Intervals
bytes32 constant REDEMPTION_FIRST_UNLOCK_PERIOD = keccak256("REDEMPTION_FIRST_UNLOCK_PERIOD");
bytes32 constant REDEMPTION_SECOND_UNLOCK_PERIOD = keccak256("REDEMPTION_SECOND_UNLOCK_PERIOD");

bytes32 constant CUMULATIVE_REDEMPTION_PERIOD = keccak256("CUMULATIVE_REDEMPTION_PERIOD");
bytes32 constant CUMULATIVE_REDEMPTION_PERIOD_UNIT = keccak256("CUMULATIVE_REDEMPTION_PERIOD_UNIT");
bytes32 constant CUMULATIVE_REDEMPTION_LIMIT_FEE = keccak256("CUMULATIVE_REDEMPTION_LIMIT_FEE");
bytes32 constant CUMULATIVE_REDEMPTION_LIMIT_ALLOWANCE = keccak256("CUMULATIVE_REDEMPTION_LIMIT_ALLOWANCE");
bytes32 constant CUMULATIVE_REDEMPTION_LIMIT_PER_INVESTOR_ALLOWANCE =
    keccak256("CUMULATIVE_REDEMPTION_LIMIT_PER_INVESTOR_ALLOWANCE");
bytes32 constant CUMULATIVE_REDEMPTION_LIMIT_PER_INVESTOR_FEE =
    keccak256("CUMULATIVE_REDEMPTION_LIMIT_PER_INVESTOR_FEE");
bytes32 constant INITIAL_REDEMPTION_RESTRICTED_PERIOD = keccak256("INITIAL_REDEMPTION_RESTRICTED_PERIOD");
bytes32 constant INITIAL_SUBSCRIPTION_RESTRICTED_PERIOD = keccak256("INITIAL_SUBSCRIPTION_RESTRICTED_PERIOD");
bytes32 constant INITIAL_SUBSCRIPTION_RESTRICTED_PERIOD_UNIT = keccak256("INITIAL_SUBSCRIPTION_RESTRICTED_PERIOD_UNIT");
bytes32 constant INITIAL_SUBSCRIPTION_RESTRICTED_PERIOD_ALLOWANCE =
    keccak256("INITIAL_SUBSCRIPTION_RESTRICTED_PERIOD_ALLOWANCE");
bytes32 constant INITIAL_SUBSCRIPTION_RESTRICTED_PERIOD_FEE = keccak256("INITIAL_SUBSCRIPTION_RESTRICTED_PERIOD_FEE");
bytes32 constant INITIAL_REDEMPTION_RESTRICTED_PERIOD_ALLOWANCE =
    keccak256("INITIAL_REDEMPTION_RESTRICTED_PERIOD_ALLOWANCE");
bytes32 constant POST_SUBSCRIPTION_RESTRICTED_PERIOD_ALLOWANCE =
    keccak256("POST_SUBSCRIPTION_RESTRICTED_PERIOD_ALLOWANCE");
bytes32 constant POST_SUBSCRIPTION_RESTRICTED_PERIOD_FEE = keccak256("POST_SUBSCRIPTION_RESTRICTED_PERIOD_FEE");
bytes32 constant INITIAL_REDEMPTION_RESTRICTED_PERIOD_FEE = keccak256("INITIAL_REDEMPTION_RESTRICTED_PERIOD_FEE");
bytes32 constant POST_REDEMPTION_RESTRICTED_PERIOD_ALLOWANCE = keccak256("POST_REDEMPTION_RESTRICTED_PERIOD_ALLOWANCE");
bytes32 constant POST_REDEMPTION_RESTRICTED_PERIOD_FEE = keccak256("POST_REDEMPTION_RESTRICTED_PERIOD_FEE");
bytes32 constant GLOBAL_AGGREGATE_MINIMUM_HOLDING = keccak256("GLOBAL_AGGREGATE_MINIMUM_HOLDING");
bytes32 constant BLOCKED = keccak256("BLOCKED");
bytes32 constant RESIDENCES_ALLOWED = keccak256("RESIDENCES_ALLOWED");
bytes32 constant NATIONALITIES_ALLOWED = keccak256("NATIONALITIES_ALLOWED");
bytes32 constant INVESTOR_TYPES_ALLOWED = keccak256("INVESTOR_TYPES_ALLOWED");
bytes32 constant ESTIMATED_REDEMPTION_FEE = keccak256("ESTIMATED_REDEMPTION_FEE");
bytes32 constant IS_INVESTOR_ALLOWED = keccak256("IS_INVESTOR_ALLOWED");
bytes32 constant HOLDING_FEE = keccak256("HOLDING_FEE");
bytes32 constant HOLDING_FEE_PERIOD = keccak256("HOLDING_FEE_PERIOD");
bytes32 constant HOLDING_FEE_PERIOD_UNIT = keccak256("HOLDING_FEE_PERIOD_UNIT");

// Investors data
bytes32 constant INVESTOR_TYPE = keccak256("INVESTOR_TYPE");
bytes32 constant MAX_INVESTOR_TYPE = keccak256("MAX_INVESTOR_TYPE");
bytes32 constant NATIONALITIES = keccak256("NATIONALITIES");
bytes32 constant REVIEW_DATE = keccak256("REVIEW_DATE");
bytes32 constant KYC_PASSED = keccak256("KYC_PASSED");
bytes32 constant AML_PASSED = keccak256("AML_PASSED");
bytes32 constant SANCTIONS_PASSED = keccak256("SANCTIONS_PASSED");
bytes32 constant SELF_CERTIFICATION = keccak256("SELF_CERTIFICATION");
bytes32 constant FITNESS_TEST = keccak256("FITNESS_TEST");
bytes32 constant FROZEN = keccak256("FROZEN");
bytes32 constant USA_STATE = keccak256("USA_STATE");
bytes32 constant ALLOWED_TO_INTERACT_DAY = keccak256("ALLOWED_TO_INTERACT_DAY");
bytes32 constant DEALER = keccak256("DEALER");
bytes32 constant REVERSE_ENQUIRY = keccak256("REVERSE_ENQUIRY");

// Jurisdictions data
bytes32 constant JURISDICTION_ALLOWED = keccak256("JURISDICTION_ALLOWED");
bytes32 constant INVESTOR_ALLOWLISTED_REQUIRED = keccak256("INVESTOR_ALLOWLISTED_REQUIRED");
bytes32 constant SELF_CERTIFICATION_REQUIRED = keccak256("SELF_CERTIFICATION_REQUIRED");
bytes32 constant FITNESS_TEST_REQUIRED = keccak256("FITNESS_TEST_REQUIRED");
bytes32 constant DISCLOSURE_DOCUMENTS_REQUIRED = keccak256("DISCLOSURE_DOCUMENTS_REQUIRED");
bytes32 constant LISTED_ON_REGULATED_VENUE_REQUIRED = keccak256("LISTED_ON_REGULATED_VENUE_REQUIRED");
bytes32 constant LOCAL_AIFM_REQUIRED = keccak256("LOCAL_AIFM_REQUIRED");
bytes32 constant NON_EU_AIFM_REQUIRED = keccak256("NON_EU_AIFM_REQUIRED");
bytes32 constant MINIMUM_INVESTMENT_REQUIRED = keccak256("MINIMUM_INVESTMENT_REQUIRED");
bytes32 constant MINIMUM_INVESTMENT = keccak256("MINIMUM_INVESTMENT");
bytes32 constant NO_MINIMUM_INVESTMENT_HOLDER_NUMBER = keccak256("NO_MINIMUM_INVESTMENT_HOLDER_NUMBER");

// Registries
bytes32 constant GENERAL_DATA_ID = bytes32(0);
bytes32 constant ETERNAL_STORAGE_SLOT = keccak256("ETERNAL_STORAGE_SLOT");
bytes32 constant BLACKLISTED_WALLET = keccak256("BLACKLISTED_WALLET");

// Tracking
bytes32 constant CURRENT_SUBSCRIPTIONS_AMOUNT = keccak256("CURRENT_SUBSCRIPTIONS_AMOUNT");
bytes32 constant INVESTOR_SUBSCRIPTION_AMOUNT = keccak256("INVESTOR_SUBSCRIPTION_AMOUNT");
bytes32 constant CURRENT_REDEMPTIONS_AMOUNT = keccak256("CURRENT_REDEMPTIONS_AMOUNT");
bytes32 constant INVESTOR_REDEMPTION_AMOUNT = keccak256("INVESTOR_REDEMPTION_AMOUNT");
bytes32 constant REDEMPTION_RECORDS = keccak256("REDEMPTION_RECORDS");
bytes32 constant REDEMPTION_RECORDS_COUNT = keccak256("REDEMPTION_RECORDS_COUNT");
bytes32 constant REDEMPTION_RECORDS_AGGREGATE = keccak256("REDEMPTION_RECORDS_AGGREGATE");
bytes32 constant REDEMPTION_RECORDS_TIMESTAMP = keccak256("REDEMPTION_RECORDS_TIMESTAMP");
bytes32 constant HOLDING_FEE_EXEMPTION_CREDITS = keccak256("HOLDING_FEE_EXEMPTION_CREDITS");
bytes32 constant HOLDING_FEE_EXEMPTION_CREDITS_START = keccak256("HOLDING_FEE_EXEMPTION_CREDITS_START");
bytes32 constant HOLDING_FEE_EXEMPTION_CREDITS_COUNT = keccak256("HOLDING_FEE_EXEMPTION_CREDITS_COUNT");
bytes32 constant HOLDING_FEE_EXEMPTION_CREDITS_AMOUNT = keccak256("HOLDING_FEE_EXEMPTION_CREDITS_AMOUNT");
bytes32 constant HOLDING_FEE_EXEMPTION_CREDITS_TIMESTAMP = keccak256("HOLDING_FEE_EXEMPTION_CREDITS_TIMESTAMP");

// Tracking (Holding Intervals)
bytes32 constant HOLDING_TIME_CREDITS = keccak256("HOLDING_TIME_CREDITS");
bytes32 constant HOLDING_TIME_CREDITS_START = keccak256("HOLDING_TIME_CREDITS_START");
bytes32 constant HOLDING_TIME_CREDITS_COUNT = keccak256("HOLDING_TIME_CREDITS_COUNT");
bytes32 constant HOLDING_TIME_CREDITS_TIMESTAMP = keccak256("HOLDING_TIME_CREDITS_TIMESTAMP");

bytes32 constant HOLDING_CREDITS_FIRST_PERIOD = keccak256("HOLDING_CREDITS_FIRST_PERIOD"); // related to REDEMPTION_FIRST_UNLOCK_PERIOD
bytes32 constant HOLDING_CREDITS_SECOND_PERIOD = keccak256("HOLDING_CREDITS_SECOND_PERIOD"); // related to REDEMPTION_SECOND_UNLOCK_PERIOD

bytes32 constant HOLDING_PERCENTAGE_FIRST_PERIOD = keccak256("HOLDING_PERCENTAGE_FIRST_PERIOD");
bytes32 constant HOLDING_PERCENTAGE_SECOND_PERIOD = keccak256("HOLDING_PERCENTAGE_SECOND_PERIOD");

// Tracking (NAV Track Module)
bytes32 constant NAV_NUM_CHECKPOINTS = keccak256("NAV_NUM_CHECKPOINTS");
bytes32 constant NAV_CHECKPOINT = keccak256("NAV_CHECKPOINT");
bytes32 constant NAV_CHECKPOINT_TIMESTAMP = keccak256("NAV_CHECKPOINT_TIMESTAMP");

// Security Token Track (Per investor)
bytes32 constant SECURITY_TOKEN_NUM_CHECKPOINTS = keccak256("SECURITY_TOKEN_NUM_CHECKPOINTS");
bytes32 constant SECURITY_TOKEN_CHECKPOINT_TIMESTAMP = keccak256("SECURITY_TOKEN_CHECKPOINT_TIMESTAMP");
bytes32 constant SECURITY_TOKEN_CHECKPOINTS = keccak256("SECURITY_TOKEN_CHECKPOINTS");

// Investor Registry
bytes32 constant IS_INVESTOR = keccak256("IS_INVESTOR");
bytes32 constant LAST_OPERATION_TIMESTAMP = keccak256("LAST_OPERATION_TIMESTAMP");
bytes32 constant CREDENTIAL_ID = keccak256("CREDENTIAL_ID");
bytes32 constant INVESTOR_CROSS_CHAIN_ADDRESSES = keccak256("INVESTOR_CROSS_CHAIN_ADDRESSES");

// Instrument Registry
bytes32 constant IS_INSTRUMENT = keccak256("IS_INSTRUMENT");
bytes32 constant TRADING_DAYS_IN_YEAR = keccak256("TRADING_DAYS_IN_YEAR");
bytes32 constant INSTRUMENT_INITIALIZED = keccak256("INSTRUMENT_INITIALIZED");
bytes32 constant INSTRUMENT_CLOSED = keccak256("INSTRUMENT_CLOSED");
bytes32 constant INSTANT_SETTLEMENT = keccak256("INSTANT_SETTLEMENT");
bytes32 constant CAN_TRANSFER_SETTLEMENT_TOKEN = keccak256("CAN_TRANSFER_SETTLEMENT_TOKEN");
bytes32 constant CAN_TRANSFER_SECURITY_TOKEN = keccak256("CAN_TRANSFER_SECURITY_TOKEN");
bytes32 constant INSTRUMENT_PAUSED = keccak256("INSTRUMENT_PAUSED");

// Dealer Registry
bytes32 constant IS_DEALER = keccak256("IS_DEALER");

// Fund Registry
bytes32 constant IS_FUND = keccak256("IS_FUND");
bytes32 constant DEFAULT_FUND_MODULES = keccak256("DEFAULT_FUND_MODULES");

// Roles
bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);
bytes32 constant DEALER_MANAGER_ROLE = keccak256("DEALER_MANAGER_ROLE");
bytes32 constant LIBRE_DEALER_ROLE = keccak256("LIBRE_DEALER_ROLE");
bytes32 constant INSTRUMENT_MANAGER_ROLE = keccak256("INSTRUMENT_MANAGER_ROLE");
bytes32 constant SETTLEMENT_TOKEN_MINTER_ROLE = keccak256("SETTLEMENT_TOKEN_MINTER_ROLE");
bytes32 constant SETTLEMENT_TOKEN_BURNER_ROLE = keccak256("SETTLEMENT_TOKEN_BURNER_ROLE");
bytes32 constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
bytes32 constant CONTRACT_MANAGER_ROLE = keccak256("CONTRACT_MANAGER_ROLE");
bytes32 constant REGISTRY_WRITER_ROLE_ADMIN = keccak256("REGISTRY_WRITER_ROLE_ADMIN");
bytes32 constant REGISTRY_WRITER_ROLE = keccak256("REGISTRY_WRITER_ROLE");
bytes32 constant ATTESTER_ROLE = keccak256("ATTESTER_ROLE");
bytes32 constant GATEWAY_MANAGER_ROLE = keccak256("GATEWAY_MANAGER_ROLE");
bytes32 constant CORE_GATEWAY_ROLE = keccak256("CORE_GATEWAY_ROLE");
bytes32 constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

// Hash of module names
bytes32 constant TRANSFER_MODULE = keccak256("TransferModule");
bytes32 constant DAILY_EXECUTION_CALCULATOR_MODULE = keccak256("DailyExecutionCalculatorModule");
bytes32 constant EXECUTION_DATE_ENFORCEMENT_MODULE = keccak256("ExecutionDateEnforcementModule");
bytes32 constant HALT_MODULE = keccak256("HaltModule");
bytes32 constant HOLDINGS_MODULE = keccak256("HoldingsModule");
bytes32 constant MONTHLY_EXECUTION_CALCULATOR_MODULE = keccak256("MonthlyExecutionCalculatorModule");
bytes32 constant FORCED_REDEMPTION_MODULE = keccak256("ForcedRedemptionModule");
bytes32 constant GATE_1_MODULE = keccak256("Gate1Module");
bytes32 constant HOLDING_INTERVALS_MODULE = keccak256("HoldingIntervalsModule");
bytes32 constant REDEMPTIONS_AGGREGATION_LIMIT_MODULE = keccak256("RedemptionsAggregationLimitModule");
bytes32 constant SUBSCRIPTIONS_AGGREGATION_LIMIT_MODULE = keccak256("SubscriptionsAggregationLimitModule");
bytes32 constant HOLDING_FEE_MODULE = keccak256("HoldingFeeModule");
bytes32 constant REDEMPTION_VOLUME_LIMIT_PER_INVESTOR_FEE_MODULE =
    keccak256("RedemptionVolumeLimitPerInvestorFeeModule");
bytes32 constant INVESTOR_LAST_OPERATION_TRACKING_MODULE = keccak256("InvestorLastOperationTrackingModule");
bytes32 constant NAV_TRACKING_MODULE = keccak256("NAVTrackingModule");
bytes32 constant REDEMPTIONS_RECORDS_MODULE = keccak256("RedemptionsRecordsModule");
bytes32 constant REDEMPTIONS_TOTAL_AMOUNT_MODULE = keccak256("RedemptionsTotalAmountModule");
bytes32 constant SECURITY_TOKEN_TRACKING_MODULE = keccak256("SecurityTokenTrackingModule");
bytes32 constant SUBSCRIPTIONS_TOTAL_AMOUNT_MODULE = keccak256("SubscriptionsTotalAmountModule");
bytes32 constant HOLDING_FEE_EXEMPTION_MODULE = keccak256("HoldingFeeExemptionModule");
bytes32 constant HOLDING_INTERVALS_TRACKING_MODULE = keccak256("HoldingIntervalsTrackingModule");

// Percentage calculations
uint256 constant PERCENTAGE_BASE = 100_00;

// Cross-chain threshold time (1 day) for credential expiry validation
uint256 constant CROSS_CHAIN_THRESHOLD_TIME = 1 days;

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.19;
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
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.19;

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
     * @dev The contract is already initialized.
     */
    error AlreadyInitialized();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

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
        if (!(isTopLevelCall && _initialized < 1) && !(address(this).code.length == 0 && _initialized == 1)) {
            revert AlreadyInitialized();
        }
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
        if (_initializing || _initialized >= version) {
            revert AlreadyInitialized();
        }
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
        if (!_initializing) {
            revert NotInitializing();
        }
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
        if (_initializing) {
            revert AlreadyInitialized();
        }
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

pragma solidity ^0.8.0;

import { ISemver } from "./ISemver.sol";

import { ISchemaResolver } from "./resolver/ISchemaResolver.sol";

/// @notice A struct representing a record for a submitted schema.
struct SchemaRecord {
    bytes32 uid; // The unique identifier of the schema.
    ISchemaResolver resolver; // Optional schema resolver.
    bool revocable; // Whether the schema allows revocations explicitly.
    string schema; // Custom specification of the schema (e.g., an ABI).
}

/// @title ISchemaRegistry
/// @notice The interface of global attestation schemas for the Ethereum Attestation Service protocol.
interface ISchemaRegistry is ISemver {
    /// @notice Emitted when a new schema has been registered
    /// @param uid The schema UID.
    /// @param registerer The address of the account used to register the schema.
    /// @param schema The schema data.
    event Registered(bytes32 indexed uid, address indexed registerer, SchemaRecord schema);

    /// @notice Submits and reserves a new schema
    /// @param schema The schema data schema.
    /// @param resolver An optional schema resolver.
    /// @param revocable Whether the schema allows revocations explicitly.
    /// @return The UID of the new schema.
    function register(string calldata schema, ISchemaResolver resolver, bool revocable) external returns (bytes32);

    /// @notice Returns an existing schema by UID
    /// @param uid The UID of the schema to retrieve.
    /// @return The schema data members.
    function getSchema(bytes32 uid) external view returns (SchemaRecord memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title ISemver
/// @notice A semver interface.
interface ISemver {
    /// @notice Returns the full semver contract version.
    /// @return Semver contract version as a string.
    function version() external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// A representation of an empty/uninitialized UID.
bytes32 constant EMPTY_UID = 0;

// A zero expiration represents an non-expiring attestation.
uint64 constant NO_EXPIRATION_TIME = 0;

error AccessDenied();
error DeadlineExpired();
error InvalidEAS();
error InvalidLength();
error InvalidSignature();
error NotFound();

/// @notice A struct representing ECDSA signature data.
struct Signature {
    uint8 v; // The recovery ID.
    bytes32 r; // The x-coordinate of the nonce R.
    bytes32 s; // The signature data.
}

/// @notice A struct representing a single attestation.
struct Attestation {
    bytes32 uid; // A unique identifier of the attestation.
    bytes32 schema; // The unique identifier of the schema.
    uint64 time; // The time when the attestation was created (Unix timestamp).
    uint64 expirationTime; // The time when the attestation expires (Unix timestamp).
    uint64 revocationTime; // The time when the attestation was revoked (Unix timestamp).
    bytes32 refUID; // The UID of the related attestation.
    address recipient; // The recipient of the attestation.
    address attester; // The attester/sender of the attestation.
    bool revocable; // Whether the attestation is revocable.
    bytes data; // Custom attestation data.
}

/// @notice A helper function to work with unchecked iterators in loops.
function uncheckedInc(uint256 i) pure returns (uint256 j) {
    unchecked {
        j = i + 1;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.19;

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

// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

import {reverseByteOrderUint32} from "./Util.sol";

/// @notice A receipt attesting to the execution of a guest program.
/// @dev A receipt contains two parts: a seal and a claim. The seal is a zero-knowledge proof
/// attesting to knowledge of a zkVM execution resulting in the claim. The claim is a set of public
/// outputs for the execution. Crucially, the claim includes the journal and the image ID. The
/// image ID identifies the program that was executed, and the journal is the public data written
/// by the program. Note that this struct only contains the claim digest, as can be obtained with
/// the `digest()` function on `ReceiptClaimLib`.
struct Receipt {
    bytes seal;
    bytes32 claimDigest;
}

/// @notice Public claims about a zkVM guest execution, such as the journal committed to by the guest.
/// @dev Also includes important information such as the exit code and the starting and ending system
/// state (i.e. the state of memory). `ReceiptClaim` is a "Merkle-ized struct" supporting
/// partial openings of the underlying fields from a hash commitment to the full structure.
struct ReceiptClaim {
    /// @notice Digest of the SystemState just before execution has begun.
    bytes32 preStateDigest;
    /// @notice Digest of the SystemState just after execution has completed.
    bytes32 postStateDigest;
    /// @notice The exit code for the execution.
    ExitCode exitCode;
    /// @notice A digest of the input to the guest.
    /// @dev This field is currently unused and must be set to the zero digest.
    bytes32 input;
    /// @notice Digest of the Output of the guest, including the journal
    /// and assumptions set during execution.
    bytes32 output;
}

library ReceiptClaimLib {
    using OutputLib for Output;
    using SystemStateLib for SystemState;

    bytes32 constant TAG_DIGEST = sha256("risc0.ReceiptClaim");

    // Define a constant to ensure hashing is done at compile time. Can't use the
    // SystemStateLib.digest method here because the Solidity compiler complains.
    bytes32 constant SYSTEM_STATE_ZERO_DIGEST = 0xa3acc27117418996340b84e5a90f3ef4c49d22c79e44aad822ec9c313e1eb8e2;

    /// @notice Construct a ReceiptClaim from the given imageId and journalDigest.
    ///         Returned ReceiptClaim will represent a successful execution of the zkVM, running
    ///         the program committed by imageId and resulting in the journal specified by
    ///         journalDigest.
    /// @param imageId The identifier for the guest program.
    /// @param journalDigest The SHA-256 digest of the journal bytes.
    /// @dev Input hash and postStateDigest are set to all-zeros (i.e. no committed input, or
    ///      final memory state), the exit code is (Halted, 0), and there are no assumptions
    ///      (i.e. the receipt is unconditional).
    function ok(bytes32 imageId, bytes32 journalDigest) internal pure returns (ReceiptClaim memory) {
        return ReceiptClaim(
            imageId,
            SYSTEM_STATE_ZERO_DIGEST,
            ExitCode(SystemExitCode.Halted, 0),
            bytes32(0),
            Output(journalDigest, bytes32(0)).digest()
        );
    }

    function digest(ReceiptClaim memory claim) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                claim.input,
                claim.preStateDigest,
                claim.postStateDigest,
                claim.output,
                // data
                uint32(claim.exitCode.system) << 24,
                uint32(claim.exitCode.user) << 24,
                // down.length
                uint16(4) << 8
            )
        );
    }
}

/// @notice Commitment to the memory state and program counter (pc) of the zkVM.
/// @dev The "pre" and "post" fields of the ReceiptClaim are digests of the system state at the
///      start are stop of execution. Programs are loaded into the zkVM by creating a memory image
///      of the loaded program, and creating a system state for initializing the zkVM. This is
///      known as the "image ID".
struct SystemState {
    /// @notice Program counter.
    uint32 pc;
    /// @notice Root hash of a merkle tree which confirms the integrity of the memory image.
    bytes32 merkle_root;
}

library SystemStateLib {
    bytes32 constant TAG_DIGEST = sha256("risc0.SystemState");

    function digest(SystemState memory state) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                state.merkle_root,
                // data
                reverseByteOrderUint32(state.pc),
                // down.length
                uint16(1) << 8
            )
        );
    }
}

/// @notice Exit condition indicated by the zkVM at the end of the guest execution.
/// @dev Exit codes have a "system" part and a "user" part. Semantically, the system part is set to
/// indicate the type of exit (e.g. halt, pause, or system split) and is directly controlled by the
/// zkVM. The user part is an exit code, similar to exit codes used in Linux, chosen by the guest
/// program to indicate additional information (e.g. 0 to indicate success or 1 to indicate an
/// error).
struct ExitCode {
    SystemExitCode system;
    uint8 user;
}

/// @notice Exit condition indicated by the zkVM at the end of the execution covered by this proof.
/// @dev
/// `Halted` indicates normal termination of a program with an interior exit code returned from the
/// guest program. A halted program cannot be resumed.
///
/// `Paused` indicates the execution ended in a paused state with an interior exit code set by the
/// guest program. A paused program can be resumed such that execution picks up where it left
/// of, with the same memory state.
///
/// `SystemSplit` indicates the execution ended on a host-initiated system split. System split is
/// mechanism by which the host can temporarily stop execution of the execution ended in a system
/// split has no output and no conclusions can be drawn about whether the program will eventually
/// halt. System split is used in continuations to split execution into individually provable segments.
enum SystemExitCode {
    Halted,
    Paused,
    SystemSplit
}

/// @notice Output field in the `ReceiptClaim`, committing to a claimed journal and assumptions list.
struct Output {
    /// @notice Digest of the journal committed to by the guest execution.
    bytes32 journalDigest;
    /// @notice Digest of the ordered list of `ReceiptClaim` digests corresponding to the
    /// calls to `env::verify` and `env::verify_integrity`.
    /// @dev Verifying the integrity of a `Receipt` corresponding to a `ReceiptClaim` with a
    /// non-empty assumptions list does not guarantee unconditionally any of the claims over the
    /// guest execution (i.e. if the assumptions list is non-empty, then the journal digest cannot
    /// be trusted to correspond to a genuine execution). The claims can be checked by additional
    /// verifying a `Receipt` for every digest in the assumptions list.
    bytes32 assumptionsDigest;
}

library OutputLib {
    bytes32 constant TAG_DIGEST = sha256("risc0.Output");

    function digest(Output memory output) internal pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                TAG_DIGEST,
                // down
                output.journalDigest,
                output.assumptionsDigest,
                // down.length
                uint16(2) << 8
            )
        );
    }
}

/// @notice Error raised when cryptographic verification of the zero-knowledge proof fails.
error VerificationFailed();

/// @notice Verifier interface for RISC Zero receipts of execution.
interface IRiscZeroVerifier {
    /// @notice Verify that the given seal is a valid RISC Zero proof of execution with the
    ///     given image ID and journal digest. Reverts on failure.
    /// @dev This method additionally ensures that the input hash is all-zeros (i.e. no
    /// committed input), the exit code is (Halted, 0), and there are no assumptions (i.e. the
    /// receipt is unconditional).
    /// @param seal The encoded cryptographic proof (i.e. SNARK).
    /// @param imageId The identifier for the guest program.
    /// @param journalDigest The SHA-256 digest of the journal bytes.
    function verify(bytes calldata seal, bytes32 imageId, bytes32 journalDigest) external view;

    /// @notice Verify that the given receipt is a valid RISC Zero receipt, ensuring the `seal` is
    /// valid a cryptographic proof of the execution with the given `claim`. Reverts on failure.
    /// @param receipt The receipt to be verified.
    function verifyIntegrity(Receipt calldata receipt) external view;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";

/**
 * @title IBaseRegistry
 * @notice Interface for the base registry, which provides functionality for tracking and retrieving data
 * specific to modules that interact with the registry.
 * @dev The tracked data can be queried via a delegatecall callback to the relevant module,
 * which implements the query logic.
 */
interface IBaseRegistry is IEternalRegistryStorage {
    /**
     * @notice Thrown when an unauthorized caller tries to access a restricted function or resource.
     */
    error IBaseRegistry_AccessDenied();

    /**
     * @notice Thrown when an action is attempted on a module that is not registered in the registry.
     */
    error IBaseRegistry_NotRegisteredModule();

    /**
     * @notice Thrown when an invalid or non-existent ID is provided for an operation.
     */
    error IBaseRegistry_NotAValidId();

    /**
     * @notice Thrown when the system fails to retrieve the tracked data for a specific operation or ID.
     */
    error IBaseRegistry_FailedToGetTrackedData();

    /**
     * @notice Get the tracked data of the registry
     * @param _data Data to be used by the module to get the tracked data
     * @return bytes memory of the tracked data
     * @dev This function is used to get the tracked data from the registry
     * by doing a delegatecall callback to the module requesting the data
     * which can implement the query logic
     */
    function getTrackedData(bytes memory _data) external returns (bytes memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBaseRegistry} from "src/interfaces/IBaseRegistry.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IUserRegistry} from "src/interfaces/IUserRegistry.sol";
import {IOperationsEngine} from "src/interfaces/IOperationsEngine.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";

/**
 * @title IDealerRegistry
 * @notice Interface for managing dealers within the registry, including adding new dealers,
 * allowing dealers for specific instruments, and checking dealer permissions.
 * @dev Extends both `IBaseRegistry` and `IUserRegistry` for core registry and user management functionality.
 */
interface IDealerRegistry is IBaseRegistry, IUserRegistry {
    /**
     * @notice Thrown when attempting to add a dealer who is already registered.
     */
    error IDealerRegistry_AlreadyADealer();

    /**
     * @notice Thrown when invalid input parameters are provided.
     */
    error IDealerRegistry_InvalidInput();

    /**
     * @notice Thrown when the specified instrument does not exist in the registry.
     */
    error IDealerRegistry_NonExistingInstrument();

    /**
     * @notice Thrown when the dealer is not allowed for the specified instrument.
     */
    error IDealerRegistry_DealerNotAllowed();

    /**
     * @notice Emited when a new dealer is added
     * @param dealerId Id of the new dealer
     * @param wallet Initial wallet of the dealer
     */
    event NewDealerAdded(bytes32 dealerId, address wallet);

    /**
     * @notice Emited when an dealer's allowed status is updated
     * @param dealerId Id of the dealer updated
     * @param allowed Y/N if dealer is allowed for the instrument
     */
    event dealerAllowedUpdated(bytes32 dealerId, bytes32 instrumentId, bool allowed);

    /**
     * @notice Initialize the registry
     * @param _roleRegistry Address of the role registry
     */
    function initialize(
        IRoleRegistry _roleRegistry,
        IOperationsEngine _operationsEngine,
        IInvestorRegistry _investorRegistry,
        IInstrumentRegistry _instrumentRegistry
    ) external;

    /**
     * @notice Adds a new dealer to the registry
     * @param _senderRole Role of the sender which allows the operation execution
     * @param _dealerId ID of the dealer
     * @param _wallet Wallet of the dealer
     */
    function addDealer(bytes32 _senderRole, bytes32 _dealerId, address _wallet) external;

    /**
     * @notice Allows a dealer for a specific instrument
     * @param _senderRole Role of the sender which allows the operation execution
     * @param _dealerId ID of the dealer
     * @param _instrumentId ID of the instrument
     * @param _allowed Y/N if dealer is allowed for the instrument
     */
    function allowDealer(bytes32 _senderRole, bytes32 _dealerId, bytes32 _instrumentId, bool _allowed) external;

    /**
     * @notice Returns if the dealer is allowed for a specific instrument
     * @param _dealerId ID of the dealer
     * @param _instrumentId ID of the instrument
     * @return Bool indicating if dealer if allowed
     */
    function isDealerAllowed(bytes32 _dealerId, bytes32 _instrumentId) external view returns (bool);

    /**
     * @notice Reverts if the dealer is not allowed for a specific instrument
     * @param _dealerId ID of the dealer
     * @param _instrumentId ID of the instrument
     */
    function checkDealerAllowed(bytes32 _dealerId, bytes32 _instrumentId) external view;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IFundRegistry} from "src/interfaces/IFundRegistry.sol";
import {IDealerRegistry} from "src/interfaces/IDealerRegistry.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";
import {OPERATIONS} from "./operations/IOperationModule.sol";

/**
 * @title Operations Engine Interface
 * @author Libre
 * @notice Defines the interface for managing modules, operations, and dependencies in the system.
 * @dev Includes error definitions, events, and function signatures for interacting with the operations engine.
 */
interface IOperationsEngine {
    // Enums
    /**
     * @notice Defines the type of ID for the module check, modules are either tracking ones or check ones.
     */
    enum IdType {
        NULL,
        INSTRUMENT_CHECK,
        FEE,
        TRACKING
    }

    /**
     * @notice Defines the type of check a module performs.
     */
    enum CHECK_TYPE {
        BOOLEAN,
        NUMERIC_MIN,
        NUMERIC_MAX
    }

    // Errors
    /**
     * @dev Revert when the tracking module reverts for any reason
     */
    error IOperationsEngine_TrackingModuleFailure();

    /**
     * @dev Revert when the fee module reverts for any reason
     */
    error IOperationsEngine_FeeModuleFailure();

    /**
     * @dev Revert when the module address provided is invalid.
     */
    error IOperationsEngine_InvalidModuleAddress();

    /**
     * @dev Revert when the module is not of the Libre type.
     */
    error IOperationsEngine_ModuleIsNotLibreType();

    /**
     * @dev Revert when a lending module cannot be disabled.
     */
    error IOperationsEngine_LendingModuleDisable();

    /**
     * @dev Revert when dependencies required for an operation are missing.
     */
    error IOperationsEngine_MissingDependencies();

    /**
     * @dev Revert when an invalid check type is used.
     */
    error IOperationsEngine_InvalidCheckType();

    /**
     * @dev Revert when the caller is not authorized to perform the action.
     */
    error IOperationsEngine_CallerNotAuthorized();

    /**
     * @dev Revert when adding a module that is already been added.
     */
    error IOperationsEngine_ModuleAlreadyAdded();

    /**
     * @dev Revert when module already enabled for the same instrument.
     */
    error IOperationsEngine_ModuleAlreadyEnabled();

    /**
     * @dev Revert when a module to be disabled for an instrument is not enabled
     */
    error IOperationsEngine_ModuleNotEnabled();

    // Events
    /**
     * @notice Emitted when a module is added to the available modules library.
     * @param moduleAddress Address of the module that was added.
     */
    event ModuleAdded(address indexed moduleAddress);

    /**
     * @notice Emitted when a module is removed from the available modules library.
     * @param moduleAddress Address of the module that was removed.
     */
    event ModuleRemoved(address indexed moduleAddress);

    /**
     * @notice Emitted when a module is enabled for a specific instrument.
     * @param moduleAddress Address of the module that was enabled.
     * @param instrumentId Id of the instrument for which the module was enabled.
     */
    event ModuleEnabled(address indexed moduleAddress, bytes32 instrumentId);

    /**
     * @notice Emitted when a module is disabled for a specific instrument.
     * @param moduleAddress Address of the module that was disabled.
     * @param instrumentId Id of the instrument for which the module was disabled.
     */
    event ModuleDisabled(address indexed moduleAddress, bytes32 instrumentId);

    /**
     * @dev Event emitted when a fee is applied.
     * @param instrumentId The ID of the instrument.
     * @param orderId The ID of the order.
     * @param feeModule The address of the fee module.
     * @param feeAmount The amount of the fee applied.
     */
    event FeeApplied(bytes32 indexed instrumentId, uint256 orderId, address feeModule, uint256 feeAmount);

    //functions

    /**
     * @notice Initializes the Rules Engine with necessary registries.
     * @param _investorRegistry Address of the Investor Registry.
     * @param _dealerRegistry Address of the Dealer Registry.
     * @param _fundRegistry Address of the Fund Registry.
     * @param _instrumentRegistry Address of the Instrument Registry.
     * @param _roleRegistry Address of the Role Registry.
     * @param _jurisdictionRegistry Address of the Jurisdiction Registry.
     */
    function initialize(
        IInvestorRegistry _investorRegistry,
        IDealerRegistry _dealerRegistry,
        IFundRegistry _fundRegistry,
        IInstrumentRegistry _instrumentRegistry,
        IRoleRegistry _roleRegistry,
        IEternalRegistryStorage _jurisdictionRegistry
    ) external;

    /**
     * @notice Gets the addresses for registered check modules implementing the given operation.
     * @param _id Id of the dealer or instrument the modules belong to.
     * @param _operation Operation implemented in modules.
     * @return An array of addresses of modules implementing the given operation.
     */
    function getCheckModules(bytes32 _id, OPERATIONS _operation) external view returns (address[] memory);

    /**
     * @notice Gets the addresses for registered fee modules implementing the given operation.
     * @param _id Id of the dealer or instrument the modules belong to.
     * @param _operation Operation implemented in modules.
     * @return An array of addresses of modules implementing the given operation.
     */
    function getFeeModules(bytes32 _id, OPERATIONS _operation) external view returns (address[] memory);

    /**
     * @notice Gets the addresses for registered tracking modules implementing the given operation.
     * @param _id Id of the dealer or instrument the modules belong to.
     * @param _operation Operation implemented in modules.
     * @return An array of addresses of modules implementing the given operation.
     */
    function getTrackingModules(bytes32 _id, OPERATIONS _operation) external view returns (address[] memory);

    /**
     * @notice Adds a module to the available modules library.
     * @param _moduleAddress Address of the module to add.
     * @param _role Role required to add the module.
     * @param _idType Type of the module.
     */
    function addModule(address _moduleAddress, bytes32 _role, IdType _idType) external;

    /**
     * @notice Removes a module from the available modules library.
     * @param _moduleAddress Address of the module to remove.
     * @param _role Role required to remove the module.
     */
    function removeModule(address _moduleAddress, bytes32 _role) external;

    /**
     * @notice Enables a module for a specific instrument.
     * @param _moduleAddress Address of the module to enable.
     * @param _instrumentId Id of the instrument.
     * @param _role Role required to enable the module.
     */
    function enableModule(address _moduleAddress, bytes32 _instrumentId, bytes32 _role) external;

    /**
     * @notice Disables a module for a specific instrument.
     * @param _moduleAddress Address of the module to disable.
     * @param _instrumentId Id of the instrument.
     * @param _role Role required to disable the module.
     * @dev Lending modules cannot be disabled, because at least one module must be enabled at all times.
     * Instead, the lending module can be replaced with another lending module by enabling the new module.
     */
    function disableModule(address _moduleAddress, bytes32 _instrumentId, bytes32 _role) external;

    /**
     * @notice Checks if a module is available in the available modules library.
     * @param _moduleAddress Address of the module to check.
     * @return True if the module is available, false otherwise.
     */
    function isAvailableModule(address _moduleAddress) external view returns (bool);

    /**
     * @notice Checks if a module is enabled for a specific instrument.
     * @param _id Id of the instrument.
     * @param _moduleName Hash of the abi.encodePacked of the module name
     * @return True if the module is enabled, false otherwise.
     */
    function hasModuleEnabled(bytes32 _id, bytes32 _moduleName) external view returns (bool);

    /**
     * @notice Function to be delegatecalled by the registry to perform the check
     * @param _operation The operation to be checked
     * @param _id The id of the operation
     * @param _data Arbitrary data that can be used by the module to perform the check
     * @return result memory Result of the check
     */
    function check(OPERATIONS _operation, bytes32 _id, bytes calldata _data) external returns (bytes memory result);

    /**
     * @notice Tracks the operation
     * @param _operation The operation to track
     * @param _id The id of the instrument or investor
     * @param _data The data to track
     * @return True if the tracking was successful, false otherwise
     */
    function track(OPERATIONS _operation, bytes32 _id, bytes memory _data) external returns (bool);

    /**
     * @notice Calculates the total fee amount to be deducted for a given operation and instrument.
     * @dev Loops through all enabled fee modules for the given operation and instrument, calls them with the input data,
     *      and sums up the returned fee amounts. Also emits `FeeApplied` events for each individual module fee.
     *
     * @param _operation The operation type (e.g., SETTLE_SUBSCRIPTION_PER_ORDER).
     * @param _id The instrument ID for which the fees are being calculated.
     * @param _data ABI-encoded parameters required for fee calculation. Must encode the following values in order:
     *        - `uint256 _orderId`: Unique identifier of the order
     *        - `bytes32 _investorId`: The ID of the investor associated with the order
     *        - `uint256 _amountToSettle`: The current amount to be settled
     *
     * @return totalFee The total fee amount to be deducted across all enabled fee modules.
     */
    function calculateFees(OPERATIONS _operation, bytes32 _id, bytes memory _data)
        external
        returns (uint256 totalFee);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IUserRegistry
 * @author Libre
 * @notice Interface for managing user wallets and their association with investor/dealer IDs.
 * @dev Provides functions for adding wallets, retrieving wallets, and mapping wallets to user IDs.
 */
interface IUserRegistry {
    /**
     * @notice Thrown when the wallet address being added is already associated with another user ID.
     */
    error IUserRegistry_WalletAlreadyClaimed();

    /**
     * @notice Thrown when the provided signature fails to verify ownership of the wallet address.
     */
    error IUserRegistry_WalletOwnershipVerificationFailure();

    /**
     * @notice Thrown when the provided wallet signature has expired.
     */
    error IUserRegistry_WalletSignatureExpired();

    /**
     * @notice Thrown when the provided wallet address to add is blacklisted.
     */
    error IUserRegistry_WalletBlacklisted();

    /**
     * @notice Emited when secondary wallet is removed
     * @param wallet User wallet address
     */
    event WalletAdded(address indexed wallet);

    /**
     * @notice Emited when secondary wallet is removed
     * @param wallet User wallet address
     */
    event WalletRemoved(address indexed wallet);

    /**
     * @notice Adds a new investor to the registry
     * @param _userId The ID of the user.
     * @param _wallet The wallet address to associate with the user ID.
     * @param _role The role used by the caller.
     */
    function addWallet(bytes32 _userId, address _wallet, bytes32 _role) external;

    /**
     * @notice Removes a wallet from the registry
     * @param _wallet The wallet address to remove.
     * @param _role The role used by the caller.
     * @return The user ID that the wallet was removed from
     */
    function removeWallet(address _wallet, bytes32 _role) external returns (bytes32);

    /**
     * @notice Get Investor/Dealer array of wallets
     * @param _userId Investor/Dealer ID
     */
    function getWallets(bytes32 _userId) external view returns (address[] memory);

    /**
     * @notice Get Investor/Dealer ID
     * @param _wallet Investor/Dealer address
     */
    function getIdFromWallet(address _wallet) external view returns (bytes32);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IEternalRegistryStorage
 * @notice Interface for managing a flexible and extensible storage system, allowing various types of values to be
 * stored and retrieved for specific registry entries. Provides a robust and modular way to interact with registry data.
 * @dev Enables storage and retrieval of multiple data types (e.g., uint256, address, string, bool, bytes32) and
 * supports operations like batch updates, array manipulations, and role-based access control for data modifications.
 */
interface IEternalRegistryStorage {
    /**
     * @notice Thrown when attempting to modify a key that has been restricted.
     */
    error IEternalRegistryStorage_AttemptToSetARestrictedKey();

    /**
     * @notice Thrown when the length of the provided input arrays does not match.
     */
    error IEternalRegistryStorage_BatchLengthMismatch();

    /**
     * @notice Thrown when attempting to access an array index that is out of bounds.
     */
    error IEternalRegistryStorage_IndexShouldBeLessThanLengthOfTheArray();

    /**
     * @notice Emitted when a boolean value is added to the registry.
     * @param id The identifier of the registry entry.
     * @param key The key associated with the boolean value.
     * @param value The boolean value added to the registry.
     */
    event AddedBool(bytes32 indexed id, bytes32 indexed key, bool value);

    /**
     * @notice Emitted when a uint256 value is added to the registry.
     * @param id The identifier of the registry entry.
     * @param key The key associated with the uint256 value.
     * @param value The uint256 value added to the registry.
     */
    event AddedUint(bytes32 indexed id, bytes32 indexed key, uint256 value);

    /**
     * @notice Emitted when an address value is added to the registry.
     * @param id The identifier of the registry entry.
     * @param key The key associated with the address value.
     * @param value The address value added to the registry.
     */
    event AddedAddress(bytes32 indexed id, bytes32 indexed key, address value);

    /**
     * @notice Emitted when a string value is added to the registry.
     * @param id The identifier of the registry entry.
     * @param key The key associated with the string value.
     * @param value The string value added to the registry.
     */
    event AddedString(bytes32 indexed id, bytes32 indexed key, string value);

    /**
     * @notice Emitted when a bytes32 value is added to the registry.
     * @param id The identifier of the registry entry.
     * @param key The key associated with the bytes32 value.
     * @param value The bytes32 value added to the registry.
     */
    event AddedBytes(bytes32 indexed id, bytes32 indexed key, bytes32 value);

    /**
     * @notice Emitted every time a key is restricted from being set
     * for an specific entry
     * @param _id Id of the entry where the key is restricted
     * @param _key Key being restricted
     */
    event KeyRestricted(bytes32 indexed _id, bytes32 indexed _key);

    /**
     * @notice Get a boolean value from the storage
     * @param _id Id of the registry entry to get the value from
     * @param _key Key identifying the value to get
     * @return bool value of the element associated to the key
     * in the requested registry entry
     */
    function getBool(bytes32 _id, bytes32 _key) external view returns (bool);

    /**
     * @notice Get a uint256 value from the storage
     * @param _id Id of the registry entry to get the value from
     * @param _key Key identifying the value to get
     * @return uint256 value of the element associated to the key
     * in the requested registry entry
     */
    function getUint(bytes32 _id, bytes32 _key) external view returns (uint256);

    /**
     * @notice Get an address value from the storage
     * @param _id Id of the registry entry to get the value from
     * @param _key Key identifying the value to get
     * @return address value of the element associated to the key
     * in the requested registry entry
     */
    function getAddress(bytes32 _id, bytes32 _key) external view returns (address);

    /**
     * @notice Get a string value from the storage
     * @param _id Id of the registry entry to get the value from
     * @param _key Key identifying the value to get
     * @return string value of the element associated to the key
     * in the requested registry entry
     */
    function getString(bytes32 _id, bytes32 _key) external view returns (string memory);

    /**
     * @notice Get a bytes value from the storage
     * @param _id Id of the registry entry to get the value from
     * @param _key Key identifying the value to get
     * @return bytes value of the element associated to the key
     * in the requested registry entry
     */
    function getBytes(bytes32 _id, bytes32 _key) external view returns (bytes32);

    /**
     * @notice Set a boolean value on the storage
     * @param _id Id of the registry entry to set the value on
     * @param _key Key identifying the value to set
     * @param _value Value to set
     * @param _senderRole Role of the sender allowing the operation
     */
    function setBool(bytes32 _id, bytes32 _key, bool _value, bytes32 _senderRole) external;

    /**
     * @notice Set a uint256 value on the storage
     * @param _id Id of the registry entry to set the value on
     * @param _key Key identifying the value to set
     * @param _value Value to set
     * @param _senderRole Role of the sender allowing the operation
     */
    function setUint(bytes32 _id, bytes32 _key, uint256 _value, bytes32 _senderRole) external;

    /**
     * @notice Set an address value on the storage
     * @param _id Id of the registry entry to set the value on
     * @param _key Key identifying the value to set
     * @param _value Value to set
     * @param _senderRole Role of the sender allowing the operation
     */
    function setAddress(bytes32 _id, bytes32 _key, address _value, bytes32 _senderRole) external;

    /**
     * @notice Set a string value on the storage
     * @param _id Id of the registry entry to set the value on
     * @param _key Key identifying the value to set
     * @param _value Value to set
     * @param _senderRole Role of the sender allowing the operation
     */
    function setString(bytes32 _id, bytes32 _key, string calldata _value, bytes32 _senderRole) external;

    /**
     * @notice Set a bytes value on the storage
     * @param _id Id of the registry entry to set the value on
     * @param _key Key identifying the value to set
     * @param _value Value to set
     * @param _senderRole Role of the sender allowing the operation
     */
    function setBytes(bytes32 _id, bytes32 _key, bytes32 _value, bytes32 _senderRole) external;

    /**
     * @notice Set multiple values in one transaction
     * @param _ids Ids associated to the values to set
     * @param _keys Key associated to the values to set
     * @param _boolValues Bool values to set
     * @param _uintValues Uint256 values to set
     * @param _addressValues Address values to set
     * @param _stringValues String values to set
     * @param _bytesValues Bytes32 values to set
     * @param _senderRole Role of the sender allowing the operation
     */
    function setBatch(
        bytes32[] memory _ids,
        bytes32[] memory _keys,
        bool[] memory _boolValues,
        uint256[] memory _uintValues,
        address[] memory _addressValues,
        string[] memory _stringValues,
        bytes32[] memory _bytesValues,
        bytes32 _senderRole
    ) external;

    /**
     * @notice Get multiple values in one transaction
     * @param _ids Ids associated to the values to get
     * @param _keys Keys associated to the values to get
     * @param _boolCount Number of bool values to get
     * @param _uintCount Number of uint256 values to get
     * @param _addressCount Number of address values to get
     * @param _stringCount Number of string values to get
     * @param _bytesCount Number of bytes32 values to get
     * @return _boolValues Bool values return array
     * @return _uintValues Uint256 values return array
     * @return _addressValues Address values return array
     * @return _stringValues String values return array
     * @return _bytesValues Bytes32 values return array
     */
    function getBatch(
        bytes32[] memory _ids,
        bytes32[] memory _keys,
        uint256 _boolCount,
        uint256 _uintCount,
        uint256 _addressCount,
        uint256 _stringCount,
        uint256 _bytesCount
    )
        external
        view
        returns (
            bool[] memory _boolValues,
            uint256[] memory _uintValues,
            address[] memory _addressValues,
            string[] memory _stringValues,
            bytes32[] memory _bytesValues
        );
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Steel} from "risc0/steel/Steel.sol";

struct SteelProofData {
    //Block hash commitment for Steel
    Steel.Commitment commitment;
    //Seal for Steel
    bytes seal;
}

struct CredentialProofData {
    //Journal Data for Steel
    CredentialJournal journal;
    //Seal for Steel
    bytes seal;
}

// @notice Journal that is committed to for Credentials
struct CredentialJournal {
    //Block hash commitment for Steel
    Steel.Commitment commitment;
    //Id of the investor
    bytes32 investorId;
    //Credential expiry timestamp
    uint64 expiryTimestamp;
    //Ids of instruments the investor is registered for
    bytes32[] instrumentIds;
    //Access expiry timestamps for instruments the investor is registered for
    uint64[] instrumentExpiryTimestamps;
    address policyViewer;
}

struct OrderProofData {
    //Journal Data for Steel
    OrderJournal journal;
    //Seal for Steel
    bytes seal;
}

// @notice Journal that is committed to for Orders
struct OrderJournal {
    //Block hash commitment for Steel
    Steel.Commitment commitment;
    //Id of the investor
    bytes32 investorId;
    //Id of the instrument the investor is subscribing or redeeming to
    bytes32 instrumentId;
    //Amount the investor is subscribing or redeeming with
    uint256 amount;
    address policyViewer;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.19;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

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
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.19;

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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBaseRegistry} from "src/interfaces/IBaseRegistry.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {IOperationsEngine} from "src/interfaces/IOperationsEngine.sol";

/**
 * @title IFundRegistry
 * @author Libre
 * @notice Interface for managing and storing information related to funds within a registry.
 * Provides functionality to initialize the registry, add new funds, and emit events for key actions.
 */
interface IFundRegistry is IBaseRegistry {
    /// @notice Error raised when attempting to register a fund that is already registered.
    error IFundRegistry_AlreadyRegistered();

    /**
     * @notice Emited when a new Fund is added
     * @param fundId Id of the new fund
     */
    event NewFundAdded(bytes32 indexed fundId);

    /**
     * @notice Initialize the registry
     * @param _roleRegistry Address of the role registry
     */
    function initialize(IRoleRegistry _roleRegistry, IOperationsEngine _operationsEngine) external;

    /**
     * @notice Adds a new fund to the registry
     * @param _senderRole Role of the sender which allow the operation execution
     * @param _fundId The ID of the fund
     */
    function addNewFund(bytes32 _senderRole, bytes32 _fundId) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.20;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/IERC1967Upgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 */
library ERC1967UtilsUpgradeable {
    // We re-declare ERC-1967 events here because they can't be used directly from IERC1967.
    // This will be fixed in Solidity 0.8.21. At that point we should remove these events.
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);

    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error ERC1967UnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlotUpgradeable.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
        upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            AddressUpgradeable.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCallUUPS(address newImplementation, bytes memory data, bool forceCall) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                if (slot != IMPLEMENTATION_SLOT) {
                    revert ERC1967UnsupportedProxiableUUID(slot);
                }
            } catch {
                // The implementation is not UUPS
                revert ERC1967InvalidImplementation(newImplementation);
            }
            upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlotUpgradeable.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1) and is validated in the constructor.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        address beaconImplementation = IBeaconUpgradeable(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }

        StorageSlotUpgradeable.getAddressSlot(BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            AddressUpgradeable.functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.19;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UtilsUpgradeable.sol";
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
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        if (address(this) == __self) {
            // Must be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
        if (ERC1967UtilsUpgradeable.getImplementation() != __self) {
            // Must be called through an active proxy
            revert UUPSUnauthorizedCallContext();
        }
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
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
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967UtilsUpgradeable.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeTo(address newImplementation) public virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        ERC1967UtilsUpgradeable.upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        ERC1967UtilsUpgradeable.upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal  onlyOwner {}
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";

/**
 * @title PermissionedContract
 * @author Libre
 * @notice Base contract for managing access control via roles.
 * @dev Provides shared functionality for role-based access control across contracts.
 */
abstract contract PermissionedContract {
    /// @custom:storage-location erc7201:PermissionedContract.storage
    struct PermissionedContractStorage {
        IRoleRegistry roleRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("PermissionedContract.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PERMISSIONED_CONTRACT_STORAGE_SLOT =
        0x5a84e274199d81bb7497e94f6b60cc9eba947b73ccf3412997ff6bcdecf19d00;

    error PermissionedContract_AccessDenied();

    function _roleRegistry() internal view returns (IRoleRegistry) {
        PermissionedContractStorage storage s = _getPermissionedContractStorage();
        return s.roleRegistry;
    }

    /**
     * @notice Verify that the user can execute the operation
     * using the role specified
     * @param _role Role the caller wants to use
     */
    function _roleHasAccess(bytes32 _role) internal view returns (bool) {
        return _roleRegistry().hasAccess(address(this), msg.sig, msg.sender, _role);
    }

    /**
     * @notice Check that the user can execute the operation
     * using the role specified
     * @param _role Role the caller wants to use
     */
    function _checkRoleHasAccess(bytes32 _role) internal view {
        if (!_roleHasAccess(_role)) {
            revert PermissionedContract_AccessDenied();
        }
    }

    /**
     * @notice Retrieves the storage for the Permissioned Contract.
     * @dev This function uses inline assembly to access the storage slot defined by `PERMISSIONED_CONTRACT_STORAGE_SLOT`.
     *      It allows access to the `PermissionedContractStorage` structure, enabling the management of permissioned contract data.
     * @return s The `PermissionedContractStorage` structure located at the specified storage slot.
     */
    function _getPermissionedContractStorage() internal pure returns (PermissionedContractStorage storage s) {
        assembly {
            s.slot := PERMISSIONED_CONTRACT_STORAGE_SLOT
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

//The encodings used for jurisdictions are based and ordered after the ISO 3166 standard as of 2023/11/28
//(https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes)
//Any new additions after this date will be added at the end as to not modify existing encodings
//allowed values are in the range of: 2^x, 0 ≤ x ≤ 255
uint256 constant AF = 2 ** 0;
uint256 constant AX = 2 ** 1;
uint256 constant AL = 2 ** 2;
uint256 constant DZ = 2 ** 3;
uint256 constant AS = 2 ** 4;
uint256 constant AD = 2 ** 5;
uint256 constant AO = 2 ** 6;
uint256 constant AI = 2 ** 7;
uint256 constant AQ = 2 ** 8;
uint256 constant AG = 2 ** 9;
uint256 constant AR = 2 ** 10;
uint256 constant AM = 2 ** 11;
uint256 constant AW = 2 ** 12;
uint256 constant AU = 2 ** 13;
uint256 constant AT = 2 ** 14;
uint256 constant AZ = 2 ** 15;
uint256 constant BS = 2 ** 16;
uint256 constant BH = 2 ** 17;
uint256 constant BD = 2 ** 18;
uint256 constant BB = 2 ** 19;
uint256 constant BY = 2 ** 20;
uint256 constant BE = 2 ** 21;
uint256 constant BZ = 2 ** 22;
uint256 constant BJ = 2 ** 23;
uint256 constant BM = 2 ** 24;
uint256 constant BT = 2 ** 25;
uint256 constant BO = 2 ** 26;
uint256 constant BQ = 2 ** 27;
uint256 constant BA = 2 ** 28;
uint256 constant BW = 2 ** 29;
uint256 constant BV = 2 ** 30;
uint256 constant BR = 2 ** 31;
uint256 constant IO = 2 ** 32;
uint256 constant BN = 2 ** 33;
uint256 constant BG = 2 ** 34;
uint256 constant BF = 2 ** 35;
uint256 constant BI = 2 ** 36;
uint256 constant CV = 2 ** 37;
uint256 constant KH = 2 ** 38;
uint256 constant CM = 2 ** 39;
uint256 constant CA = 2 ** 40;
uint256 constant KY = 2 ** 41;
uint256 constant CF = 2 ** 42;
uint256 constant TD = 2 ** 43;
uint256 constant CL = 2 ** 44;
uint256 constant CN = 2 ** 45;
uint256 constant CX = 2 ** 46;
uint256 constant CC = 2 ** 47;
uint256 constant CO = 2 ** 48;
uint256 constant KM = 2 ** 49;
uint256 constant CD = 2 ** 50;
uint256 constant CG = 2 ** 51;
uint256 constant CK = 2 ** 52;
uint256 constant CR = 2 ** 53;
uint256 constant CI = 2 ** 54;
uint256 constant HR = 2 ** 55;
uint256 constant CU = 2 ** 56;
uint256 constant CW = 2 ** 57;
uint256 constant CY = 2 ** 58;
uint256 constant CZ = 2 ** 59;
uint256 constant DK = 2 ** 60;
uint256 constant DJ = 2 ** 61;
uint256 constant DM = 2 ** 62;
uint256 constant DO = 2 ** 63;
uint256 constant EC = 2 ** 64;
uint256 constant EG = 2 ** 65;
uint256 constant SV = 2 ** 66;
uint256 constant GQ = 2 ** 67;
uint256 constant ER = 2 ** 68;
uint256 constant EE = 2 ** 69;
uint256 constant SZ = 2 ** 70;
uint256 constant ET = 2 ** 71;
uint256 constant FK = 2 ** 72;
uint256 constant FO = 2 ** 73;
uint256 constant FJ = 2 ** 74;
uint256 constant FI = 2 ** 75;
uint256 constant FR = 2 ** 76;
uint256 constant GF = 2 ** 77;
uint256 constant PF = 2 ** 78;
uint256 constant TF = 2 ** 79;
uint256 constant GA = 2 ** 80;
uint256 constant GM = 2 ** 81;
uint256 constant GE = 2 ** 82;
uint256 constant DE = 2 ** 83;
uint256 constant GH = 2 ** 84;
uint256 constant GI = 2 ** 85;
uint256 constant GR = 2 ** 86;
uint256 constant GL = 2 ** 87;
uint256 constant GD = 2 ** 88;
uint256 constant GP = 2 ** 89;
uint256 constant GU = 2 ** 90;
uint256 constant GT = 2 ** 91;
uint256 constant GG = 2 ** 92;
uint256 constant GN = 2 ** 93;
uint256 constant GW = 2 ** 94;
uint256 constant GY = 2 ** 95;
uint256 constant HT = 2 ** 96;
uint256 constant HM = 2 ** 97;
uint256 constant VA = 2 ** 98;
uint256 constant HN = 2 ** 99;
uint256 constant HK = 2 ** 100;
uint256 constant HU = 2 ** 101;
uint256 constant IS = 2 ** 102;
uint256 constant IN = 2 ** 103;
uint256 constant ID = 2 ** 104;
uint256 constant IR = 2 ** 105;
uint256 constant IQ = 2 ** 106;
uint256 constant IE = 2 ** 107;
uint256 constant IM = 2 ** 108;
uint256 constant IL = 2 ** 109;
uint256 constant IT = 2 ** 110;
uint256 constant JM = 2 ** 111;
uint256 constant JP = 2 ** 112;
uint256 constant JE = 2 ** 113;
uint256 constant JO = 2 ** 114;
uint256 constant KZ = 2 ** 115;
uint256 constant KE = 2 ** 116;
uint256 constant KI = 2 ** 117;
uint256 constant KP = 2 ** 118;
uint256 constant KR = 2 ** 119;
uint256 constant KW = 2 ** 120;
uint256 constant KG = 2 ** 121;
uint256 constant LA = 2 ** 122;
uint256 constant LV = 2 ** 123;
uint256 constant LB = 2 ** 124;
uint256 constant LS = 2 ** 125;
uint256 constant LR = 2 ** 126;
uint256 constant LY = 2 ** 127;
uint256 constant LI = 2 ** 128;
uint256 constant LT = 2 ** 129;
uint256 constant LU = 2 ** 130;
uint256 constant MO = 2 ** 131;
uint256 constant MK = 2 ** 132;
uint256 constant MG = 2 ** 133;
uint256 constant MW = 2 ** 134;
uint256 constant MY = 2 ** 135;
uint256 constant MV = 2 ** 136;
uint256 constant ML = 2 ** 137;
uint256 constant MT = 2 ** 138;
uint256 constant MH = 2 ** 139;
uint256 constant MQ = 2 ** 140;
uint256 constant MR = 2 ** 141;
uint256 constant MU = 2 ** 142;
uint256 constant YT = 2 ** 143;
uint256 constant MX = 2 ** 144;
uint256 constant FM = 2 ** 145;
uint256 constant MD = 2 ** 146;
uint256 constant MC = 2 ** 147;
uint256 constant MN = 2 ** 148;
uint256 constant ME = 2 ** 149;
uint256 constant MS = 2 ** 150;
uint256 constant MA = 2 ** 151;
uint256 constant MZ = 2 ** 152;
uint256 constant MM = 2 ** 153;
uint256 constant NA = 2 ** 154;
uint256 constant NR = 2 ** 155;
uint256 constant NP = 2 ** 156;
uint256 constant NL = 2 ** 157;
uint256 constant NC = 2 ** 158;
uint256 constant NZ = 2 ** 159;
uint256 constant NI = 2 ** 160;
uint256 constant NE = 2 ** 161;
uint256 constant NG = 2 ** 162;
uint256 constant NU = 2 ** 163;
uint256 constant NF = 2 ** 164;
uint256 constant MP = 2 ** 165;
uint256 constant NO = 2 ** 166;
uint256 constant OM = 2 ** 167;
uint256 constant PK = 2 ** 168;
uint256 constant PW = 2 ** 169;
uint256 constant PS = 2 ** 170;
uint256 constant PA = 2 ** 171;
uint256 constant PG = 2 ** 172;
uint256 constant PY = 2 ** 173;
uint256 constant PE = 2 ** 174;
uint256 constant PH = 2 ** 175;
uint256 constant PN = 2 ** 176;
uint256 constant PL = 2 ** 177;
uint256 constant PT = 2 ** 178;
uint256 constant PR = 2 ** 179;
uint256 constant QA = 2 ** 180;
uint256 constant RE = 2 ** 181;
uint256 constant RO = 2 ** 182;
uint256 constant RU = 2 ** 183;
uint256 constant RW = 2 ** 184;
uint256 constant BL = 2 ** 185;
uint256 constant SH = 2 ** 186;
uint256 constant KN = 2 ** 187;
uint256 constant LC = 2 ** 188;
uint256 constant MF = 2 ** 189;
uint256 constant PM = 2 ** 190;
uint256 constant VC = 2 ** 191;
uint256 constant WS = 2 ** 192;
uint256 constant SM = 2 ** 193;
uint256 constant ST = 2 ** 194;
uint256 constant SA = 2 ** 195;
uint256 constant SN = 2 ** 196;
uint256 constant RS = 2 ** 197;
uint256 constant SC = 2 ** 198;
uint256 constant SL = 2 ** 199;
uint256 constant SG = 2 ** 200;
uint256 constant SX = 2 ** 201;
uint256 constant SK = 2 ** 202;
uint256 constant SI = 2 ** 203;
uint256 constant SB = 2 ** 204;
uint256 constant SO = 2 ** 205;
uint256 constant ZA = 2 ** 206;
uint256 constant GS = 2 ** 207;
uint256 constant SS = 2 ** 208;
uint256 constant ES = 2 ** 209;
uint256 constant LK = 2 ** 210;
uint256 constant SD = 2 ** 211;
uint256 constant SR = 2 ** 212;
uint256 constant SJ = 2 ** 213;
uint256 constant SE = 2 ** 214;
uint256 constant CH = 2 ** 215;
uint256 constant SY = 2 ** 216;
uint256 constant TW = 2 ** 217;
uint256 constant TJ = 2 ** 218;
uint256 constant TZ = 2 ** 219;
uint256 constant TH = 2 ** 220;
uint256 constant TL = 2 ** 221;
uint256 constant TG = 2 ** 222;
uint256 constant TK = 2 ** 223;
uint256 constant TO = 2 ** 224;
uint256 constant TT = 2 ** 225;
uint256 constant TN = 2 ** 226;
uint256 constant TR = 2 ** 227;
uint256 constant TM = 2 ** 228;
uint256 constant TC = 2 ** 229;
uint256 constant TV = 2 ** 230;
uint256 constant UG = 2 ** 231;
uint256 constant UA = 2 ** 232;
uint256 constant AE = 2 ** 233;
uint256 constant GB = 2 ** 234;
uint256 constant UM = 2 ** 235;
uint256 constant US = 2 ** 236;
uint256 constant UY = 2 ** 237;
uint256 constant UZ = 2 ** 238;
uint256 constant VU = 2 ** 239;
uint256 constant VE = 2 ** 240;
uint256 constant VN = 2 ** 241;
uint256 constant VG = 2 ** 242;
uint256 constant VI = 2 ** 243;
uint256 constant WF = 2 ** 244;
uint256 constant EH = 2 ** 245;
uint256 constant YE = 2 ** 246;
uint256 constant ZM = 2 ** 247;
uint256 constant ZW = 2 ** 248;
//values 249-255 reserved for future additions

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.19;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
        return functionCallWithValue(target, data, 0, defaultRevert);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with a
     * `customRevert` function as a fallback when `target` reverts.
     *
     * Requirements:
     *
     * - `customRevert` must be a reverting function.
     *
     * _Available since v5.0._
     */
    function functionCall(
        address target,
        bytes memory data,
        function() internal view customRevert
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, customRevert);
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
        return functionCallWithValue(target, data, value, defaultRevert);
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with a `customRevert` function as a fallback revert reason when `target` reverts.
     *
     * Requirements:
     *
     * - `customRevert` must be a reverting function.
     *
     * _Available since v5.0._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        function() internal view customRevert
    ) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, customRevert);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, defaultRevert);
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
        function() internal view customRevert
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, customRevert);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, defaultRevert);
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
        function() internal view customRevert
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, customRevert);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided `customRevert`) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v5.0._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        function() internal view customRevert
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check if target is a contract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                if (target.code.length == 0) {
                    revert AddressEmptyCode(target);
                }
            }
            return returndata;
        } else {
            _revert(returndata, customRevert);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or with a default revert error.
     *
     * _Available since v5.0._
     */
    function verifyCallResult(bool success, bytes memory returndata) internal view returns (bytes memory) {
        return verifyCallResult(success, returndata, defaultRevert);
    }

    /**
     * @dev Same as {xref-Address-verifyCallResult-bool-bytes-}[`verifyCallResult`], but with a
     * `customRevert` function as a fallback when `success` is `false`.
     *
     * Requirements:
     *
     * - `customRevert` must be a reverting function.
     *
     * _Available since v5.0._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        function() internal view customRevert
    ) internal view returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, customRevert);
        }
    }

    /**
     * @dev Default reverting function when no `customRevert` is provided in a function call.
     */
    function defaultRevert() internal pure {
        revert FailedInnerCall();
    }

    function _revert(bytes memory returndata, function() internal view customRevert) private view {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            customRevert();
            revert FailedInnerCall();
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Attestation } from "./../Common.sol";
import { ISemver } from "./../ISemver.sol";

/// @title ISchemaResolver
/// @notice The interface of an optional schema resolver.
interface ISchemaResolver is ISemver {
    /// @notice Checks if the resolver can be sent ETH.
    /// @return Whether the resolver supports ETH transfers.
    function isPayable() external pure returns (bool);

    /// @notice Processes an attestation and verifies whether it's valid.
    /// @param attestation The new attestation.
    /// @return Whether the attestation is valid.
    function attest(Attestation calldata attestation) external payable returns (bool);

    /// @notice Processes multiple attestations and verifies whether they are valid.
    /// @param attestations The new attestations.
    /// @param values Explicit ETH amounts which were sent with each attestation.
    /// @return Whether all the attestations are valid.
    function multiAttest(
        Attestation[] calldata attestations,
        uint256[] calldata values
    ) external payable returns (bool);

    /// @notice Processes an attestation revocation and verifies if it can be revoked.
    /// @param attestation The existing attestation to be revoked.
    /// @return Whether the attestation can be revoked.
    function revoke(Attestation calldata attestation) external payable returns (bool);

    /// @notice Processes revocation of multiple attestation and verifies they can be revoked.
    /// @param attestations The existing attestations to be revoked.
    /// @param values Explicit ETH amounts which were sent with each revocation.
    /// @return Whether the attestations can be revoked.
    function multiRevoke(
        Attestation[] calldata attestations,
        uint256[] calldata values
    ) external payable returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.19;

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

// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

/// @notice reverse the byte order of the uint256 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint256(uint256 input) pure returns (uint256 v) {
    v = input;

    // swap bytes
    v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >> 8)
        | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) << 8);

    // swap 2-byte long pairs
    v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >> 16)
        | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) << 16);

    // swap 4-byte long pairs
    v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >> 32)
        | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) << 32);

    // swap 8-byte long pairs
    v = ((v & 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >> 64)
        | ((v & 0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) << 64);

    // swap 16-byte long pairs
    v = (v >> 128) | (v << 128);
}

/// @notice reverse the byte order of the uint32 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint32(uint32 input) pure returns (uint32 v) {
    v = input;

    // swap bytes
    v = ((v & 0xFF00FF00) >> 8) | ((v & 0x00FF00FF) << 8);

    // swap 2-byte long pairs
    v = (v >> 16) | (v << 16);
}

/// @notice reverse the byte order of the uint16 value.
/// @dev Solidity uses a big-endian ABI encoding. Reversing the byte order before encoding
/// ensure that the encoded value will be little-endian.
/// Written by k06a. https://ethereum.stackexchange.com/a/83627
function reverseByteOrderUint16(uint16 input) pure returns (uint16 v) {
    v = input;

    // swap bytes
    v = (v >> 8) | ((v & 0x00FF) << 8);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IFundRegistry} from "src/interfaces/IFundRegistry.sol";
import {IDealerRegistry} from "src/interfaces/IDealerRegistry.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";

enum OPERATIONS {
    // Transfer specific operations:
    TRANSFER,
    FORCED_TRANSFER,
    RECEIVE,
    SEND,
    CLAWBACK,
    // Subscription specific operations:
    ADVISED_CREATE_SUBSCRIPTION,
    CREATE_SUBSCRIPTION,
    SUBSCRIPTION_EXECUTION_DATE_CALCULATION,
    SETTLE_SUBSCRIPTIONS,
    SETTLE_SUBSCRIPTION_PER_ORDER,
    SUBSCRIPTION_CANCELLATION,
    // Redemption specific operations:
    ADVISED_CREATE_REDEMPTION,
    CREATE_REDEMPTION,
    REDEMPTION_EXECUTION_DATE_CALCULATION,
    REDEMPTION_CANCELLATION,
    SETTLE_REDEMPTIONS,
    SETTLE_REDEMPTION_PER_ORDER,
    FORCED_REDEMPTION,
    REDEMPTION_FEE,
    // Secondary Market specific operations:
    FILL,
    ORDER,
    TRADE,
    // NAV operations:
    UPDATE_AUDITED_NAV_PER_SHARE
}

interface IOperationModule {
    /**
     * @return The list of operations associated with a module
     * @dev It should contains all the Operation ids of all
     * the IOperations it implements
     */
    function getOperations() external pure returns (OPERATIONS[] memory);

    /**
     * @return Returns the name of the module
     */
    function name() external pure returns (string memory);

    /**
     * @return Returns the hash of the module name
     */
    function nameHash() external pure returns (bytes32);
}

// Copyright 2024 RISC Zero, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.9;

/// @title Steel Library
/// @notice This library provides a collection of utilities to work with Steel commitments in Solidity.
library Steel {
    /// @notice Represents a commitment to a specific block in the blockchain.
    /// @dev The `id` combines the version and the actual identifier of the claim, such as the block number.
    /// @dev The `digest` represents the data being committed to, e.g. the hash of the execution block.
    /// @dev The `configID` is the cryptographic digest of the network configuration.
    struct Commitment {
        uint256 id;
        bytes32 digest;
        bytes32 configID;
    }

    /// @notice The version of the Commitment is incorrect.
    error InvalidCommitmentVersion();

    /// @notice The Commitment is too old and can no longer be validated.
    error CommitmentTooOld();

    /// @notice Validates if the provided Commitment matches the block hash of the given block number.
    /// @param commitment The Commitment struct to validate.
    /// @return True if the commitment's block hash matches the block hash of the block number, false otherwise.
    function validateCommitment(Commitment memory commitment) internal view returns (bool) {
        (uint240 claimID, uint16 version) = Encoding.decodeVersionedID(commitment.id);
        if (version == 0) {
            return validateBlockCommitment(claimID, commitment.digest);
        } else if (version == 1) {
            return validateBeaconCommitment(claimID, commitment.digest);
        } else {
            revert InvalidCommitmentVersion();
        }
    }

    /// @notice Validates if the provided block commitment matches the block hash of the given block number.
    /// @param blockNumber The block number to compare against.
    /// @param blockHash The block hash to validate.
    /// @return True if the block's block hash matches the block hash, false otherwise.
    function validateBlockCommitment(uint256 blockNumber, bytes32 blockHash) internal view returns (bool) {
        if (block.number - blockNumber > 256) {
            revert CommitmentTooOld();
        }
        return blockHash == blockhash(blockNumber);
    }

    /// @notice Validates if the provided beacon commitment matches the block root of the given timestamp.
    /// @param timestamp The timestamp to compare against.
    /// @param blockRoot The block root to validate.
    /// @return True if the block's block root matches the block root, false otherwise.
    function validateBeaconCommitment(uint256 timestamp, bytes32 blockRoot) internal view returns (bool) {
        if (block.timestamp - timestamp > 12 * 8191) {
            revert CommitmentTooOld();
        }
        return blockRoot == Beacon.parentBlockRoot(timestamp);
    }
}

/// @title Beacon Library
library Beacon {
    /// @notice The address of the Beacon roots contract.
    /// @dev https://eips.ethereum.org/EIPS/eip-4788
    address internal constant BEACON_ROOTS_ADDRESS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @notice Find the root of the Beacon block corresponding to the parent of the execution block with the given timestamp.
    /// @return root Returns the corresponding Beacon block root or null, if no such block exists.
    function parentBlockRoot(uint256 timestamp) internal view returns (bytes32 root) {
        (bool success, bytes memory result) = BEACON_ROOTS_ADDRESS.staticcall(abi.encode(timestamp));
        if (success) {
            return abi.decode(result, (bytes32));
        }
    }
}

/// @title Encoding Library
library Encoding {
    /// @notice Encodes a version and ID into a single uint256 value.
    /// @param id The base ID to be encoded, limited by 240 bits (or the maximum value of a uint240).
    /// @param version The version number to be encoded, limited by 16 bits (or the maximum value of a uint16).
    /// @return Returns a single uint256 value that contains both the `id` and the `version` encoded into it.
    function encodeVersionedID(uint240 id, uint16 version) internal pure returns (uint256) {
        uint256 encoded;
        assembly {
            encoded := or(shl(240, version), id)
        }
        return encoded;
    }

    /// @notice Decodes a version and ID from a single uint256 value.
    /// @param id The single uint256 value to be decoded.
    /// @return Returns two values: a uint240 for the original base ID and a uint16 for the version number encoded into it.
    function decodeVersionedID(uint256 id) internal pure returns (uint240, uint16) {
        uint240 decoded;
        uint16 version;
        assembly {
            decoded := and(id, 0x0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            version := shr(240, id)
        }
        return (decoded, version);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.19;

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
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.19;

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
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.19;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 *
 * _Available since v4.8.3._
 */
interface IERC1967Upgradeable {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.19;

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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.19;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, `uint256`._
 * _Available since v4.9 for `string`, `bytes`._
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

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
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

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}
