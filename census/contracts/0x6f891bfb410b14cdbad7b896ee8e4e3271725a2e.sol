// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISchemaRegistry, SchemaRecord} from "eas-contracts/ISchemaRegistry.sol";
import {ISchemaResolver} from "eas-contracts/resolver/ISchemaResolver.sol";
import {
    IEAS,
    AttestationRequestData,
    AttestationRequest,
    Attestation,
    RevocationRequestData,
    RevocationRequest
} from "eas-contracts/IEAS.sol";

import {IUserRegistry} from "src/interfaces/IUserRegistry.sol";
import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IOperationsEngine} from "src/interfaces/IOperationsEngine.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {IDealerRegistry} from "src/interfaces/IDealerRegistry.sol";
import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";
import {IGatewayManager} from "src/interfaces/IGatewayManager.sol";

import "src/utils/Constant.sol";

import {BaseRegistry} from "src/registries/BaseRegistry.sol";
import {BaseUserRegistry} from "src/registries/BaseUserRegistry.sol";
import {ResolverVerifier, IAccessVerifier} from "src/credentials/ResolverVerifier.sol";
import {GatewayUtils} from "src/utils/GatewayUtils.sol";

/**
 * @title Investor Registry
 * @author Libre
 * @notice Keeps all the information relative to the investors
 * accreditation and compliance checks
 */
contract InvestorRegistry is BaseUserRegistry, IInvestorRegistry {
    /// @custom:storage-location erc7201:InvestorRegistry.storage
    struct InvestorRegistryStorage {
        address resolverVerifier;
        address policyViewer;
        IEAS eas;
        IGatewayManager gatewayManager;
        bytes32 schemaId;
        //TODO: Hopefully can use transient storage for this in solidity 0.8.29
        SteelProofData tempSteelProofData;
    }

    // keccak256(abi.encode(uint256(keccak256("InvestorRegistry.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INVESTOR_REGISTRY_STORAGE_SLOT =
        0x6038d02812ffb3cdd1975655e8b1ac798e35a8c7b30389858eb87a41fc030b00;

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
    ) external initializer {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        BaseRegistry.initialize(IS_INVESTOR);

        brs.instrumentRegistry = _instrumentRegistry;
        brs.dealerRegistry = _dealerRegistry;
        brs.jurisdictionRegistry = _jurisdictionRegistry;
        brs.operationsEngine = _operationsEngine;
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        ivrs.eas = _eas;
        ivrs.gatewayManager = _gatewayManager;
        ivrs.resolverVerifier = _resolverVerifier;
        ivrs.policyViewer = _policyViewer;
        ISchemaRegistry easSchemaRegistry = _eas.getSchemaRegistry();
        ivrs.schemaId = easSchemaRegistry.register(
            "bytes32 investorId, bytes32[] instrumentIds, uint64[] instrumentExpiryTimestamps",
            ISchemaResolver(_resolverVerifier),
            true
        );

        PermissionedContractStorage storage pcs = _getPermissionedContractStorage();
        pcs.roleRegistry = _roleRegistry;
    }

    /**
     * @notice Adds a new investor to the registry.
     * @param _senderRole Role of the sender performing the operation.
     * @param _investorId The unique ID of the investor.
     * @param _wallet The default wallet address of the investor.
     * @param _dealerId The ID of the associated dealer.
     */
    function addInvestor(bytes32 _senderRole, bytes32 _investorId, address _wallet, bytes32 _dealerId) external {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();

        _nonZeroId(_investorId);
        _nonZeroId(_dealerId);
        _checkRoleHasAccess(_senderRole);
        if (_isValidId(_investorId)) {
            revert IInvestorRegistry_AlreadyAnInvestor();
        }
        _setDefaultReservedKeys(_investorId);

        bytes32 dealerId = brs.dealerRegistry.getIdFromWallet(msg.sender);
        //if msg.sender is a dealer, they must be the investor's dealer
        if (dealerId != bytes32(0)) {
            if (dealerId != _dealerId) {
                revert IInvestorRegistry_NotInvestorsDealer();
            }
        }

        // Validate that _dealerId exists and is a valid dealer
        if (!brs.dealerRegistry.getBool(_dealerId, IS_DEALER)) {
            revert IInvestorRegistry_InvalidDealerId();
        }

        _setBool(_investorId, IS_INVESTOR, true);
        _setBytes(_investorId, DEALER, _dealerId);
        _addWallet(_investorId, _wallet);

        _setReservedKey(_investorId, CREDENTIAL_ID);
        _setReservedKey(_investorId, DEALER);

        emit NewInvestorAdded(_investorId, _wallet);
    }

    function configureResolverVerifier(address _resolverVerifier) external {
        IRoleRegistry roleRegistry = _roleRegistry();

        bytes32 contractManagerRole = roleRegistry.getContractManager(address(this));

        if (!roleRegistry.hasRole(contractManagerRole, msg.sender)) {
            revert IInvestorRegistry_NoContractManagerRole();
        }
        if (_resolverVerifier == address((0))) {
            revert IInvestorRegistry_EmptyResolverVerifier();
        }
        //update schema with new resolverVerifier
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        ISchemaRegistry easSchemaRegistry = ivrs.eas.getSchemaRegistry();
        ivrs.schemaId = easSchemaRegistry.register(
            "bytes32 investorId, bytes32[] instrumentIds, uint64[] instrumentExpiryTimestamps",
            ISchemaResolver(_resolverVerifier),
            true
        );
        //update stored resolverVerifier
        ivrs.resolverVerifier = _resolverVerifier;
        emit InvestorRegistryResolverVerifierChanged(_resolverVerifier);
    }

    /**
     * @notice Updates zk program image IDs for credential and subscription verification.
     * @param _credentialImageID New zk program image ID for credentials.
     * @param _subscriptionImageID New zk program image ID for subscriptions.
     */
    function configureImageIDs(bytes32 _credentialImageID, bytes32 _subscriptionImageID) external {
        IRoleRegistry roleRegistry = _roleRegistry();

        bytes32 contractManagerRole = roleRegistry.getContractManager(address(this));
        if (!roleRegistry.hasRole(contractManagerRole, msg.sender)) {
            revert IInvestorRegistry_NoContractManagerRole();
        }
        if (_credentialImageID == bytes32(0) || _subscriptionImageID == bytes32(0)) {
            revert IInvestorRegistry_EmptyImageIDs();
        }
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        ResolverVerifier(payable(ivrs.resolverVerifier)).updateImageIDs(_credentialImageID, _subscriptionImageID);
        emit InvestorRegistryImageIDsChanged(_credentialImageID, _subscriptionImageID);
    }

    //@dev If a credential does not exist or the previous one is revoked, it creates a new one with all new values.
    // Otherwise it creates a new credential adding the new instruments and/or updating expiry timestamps.
    // In this second case the seal should only contain the proof for the updated instruments, but the journal
    //should have existing instruments added to be kept in the new credential
    function setCredential(CredentialProofData calldata _proof) external {
        if (!_roleRegistry().hasRole(ATTESTER_ROLE, msg.sender)) {
            revert IInvestorRegistry_NoAttesterRole();
        }
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        bytes32 schemaId = ivrs.schemaId;
        if (schemaId == bytes32(0)) {
            revert IInvestorRegistry_SchemaNotSet();
        }

        if (_proof.journal.policyViewer != ivrs.policyViewer) {
            revert IInvestorRegistry_PolicyViewerProofMismatch();
        }

        bytes32 previousCredentialUid = getBytes(_proof.journal.investorId, CREDENTIAL_ID);

        bytes memory encodedData = abi.encode(
            _proof.journal.investorId, _proof.journal.instrumentIds, _proof.journal.instrumentExpiryTimestamps
        );
        AttestationRequestData memory attestation = AttestationRequestData({
            recipient: address(0), //We are using investorId in the data rather than their address
            expirationTime: _proof.journal.expiryTimestamp,
            revocable: true,
            refUID: bytes32(0), //Not referencing other attestations
            data: encodedData,
            value: 0
        });

        AttestationRequest memory attestationRequest = AttestationRequest({schema: schemaId, data: attestation});
        ivrs.tempSteelProofData = SteelProofData({commitment: _proof.journal.commitment, seal: _proof.seal});
        bytes32 credentialId = ivrs.eas.attest(attestationRequest);
        _setBytes(_proof.journal.investorId, CREDENTIAL_ID, credentialId);

        // Bridge the new credential
        uint16[] memory chains;
        ivrs.gatewayManager.bridgeCredential(credentialId, GATEWAY_MANAGER_ROLE, chains);

        //revoke previous attestation
        if (previousCredentialUid != bytes32(0) && ivrs.eas.getAttestation(previousCredentialUid).revocationTime == 0) {
            _revokeAttestation(previousCredentialUid);
        }

        emit InvestorRegistryCredentialSet(_proof.journal.investorId, _proof.journal.instrumentIds);
    }

    //@dev If no instrument Ids sent as input, it revokes the entire credential.
    // Otherwise it reissues the credential eliminating the instruments sent as input
    function revokeCredential(bytes32 _investorId, bytes32[] calldata _instrumentIds) external {
        if (!_roleRegistry().hasRole(ATTESTER_ROLE, msg.sender)) {
            revert IInvestorRegistry_NoAttesterRole();
        }
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();

        bytes32 schemaId = ivrs.schemaId;
        if (schemaId == bytes32(0)) {
            revert IInvestorRegistry_SchemaNotSet();
        }
        bytes32 previousCredentialUid = getBytes(_investorId, CREDENTIAL_ID);
        _revokeAttestation(previousCredentialUid);

        if (_instrumentIds.length != 0) {
            //Compare instruments to revoke with previous attestation
            AttestationRequestData memory replacementAttestation;
            {
                Attestation memory oldAttestation = ivrs.eas.getAttestation(previousCredentialUid);
                (, bytes32[] memory oldInstrumentIds, uint64[] memory oldInstrumentExpiryTimestamps) =
                    abi.decode(oldAttestation.data, (bytes32, bytes32[], uint64[]));

                //only keeping instruments that are not being revoked
                bytes32[] memory keptInstrumentIds;
                uint64[] memory keptInstrumentExpiryTimestamps;
                {
                    uint256 keptCount = oldInstrumentIds.length - _instrumentIds.length;
                    keptInstrumentIds = new bytes32[](keptCount);
                    keptInstrumentExpiryTimestamps = new uint64[](keptCount);
                }

                uint256 currentIndex;
                for (uint256 i; i < oldInstrumentIds.length; ++i) {
                    bool toRevoke;
                    for (uint256 j; j < _instrumentIds.length; ++j) {
                        if (oldInstrumentIds[i] == _instrumentIds[j]) {
                            toRevoke = true;
                            break;
                        }
                    }
                    if (!toRevoke) {
                        if (currentIndex >= keptInstrumentIds.length) {
                            revert IInvestorRegistry_InstrumentsToRevokeNotInCredential();
                        }
                        keptInstrumentIds[currentIndex] = (oldInstrumentIds[i]);
                        keptInstrumentExpiryTimestamps[currentIndex] = (oldInstrumentExpiryTimestamps[i]);
                        ++currentIndex;
                    }
                }

                bytes memory encodedData = abi.encode(_investorId, keptInstrumentIds, keptInstrumentExpiryTimestamps);
                replacementAttestation = AttestationRequestData({
                    recipient: address(0), //We are using investorId in the data rather than their address
                    expirationTime: oldAttestation.expirationTime,
                    revocable: true,
                    refUID: bytes32(0), //Not referencing other attestations
                    data: encodedData,
                    value: 0
                });
            }

            //replace attestation only with kept instruments
            AttestationRequest memory attestationRequest =
                AttestationRequest({schema: schemaId, data: replacementAttestation});
            bytes32 credentialId = ivrs.eas.attest(attestationRequest);
            _setBytes(_investorId, CREDENTIAL_ID, credentialId);

            // Bridge the updated credential
            uint16[] memory chains;
            ivrs.gatewayManager.bridgeCredential(credentialId, GATEWAY_MANAGER_ROLE, chains);
        } else {
            // Bridge the revkoed credential
            uint16[] memory chains;
            ivrs.gatewayManager.bridgeCredential(previousCredentialUid, GATEWAY_MANAGER_ROLE, chains);
        }
        emit InvestorRegistryCredentialRevoked(_investorId, _instrumentIds);
    }

    /**
     * @notice Overrides the addWallet method to bridge wallet changes across chains
     * @param _userId The ID of the user.
     * @param _wallet The wallet address to associate with the user ID.
     * @param _role The role used by the caller.
     */
    function addWallet(bytes32 _userId, address _wallet, bytes32 _role)
        public
        override(BaseUserRegistry, IUserRegistry)
    {
        super.addWallet(_userId, _wallet, _role);
        // Bridge wallet change
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        GatewayUtils.bridgeAddressChange(
            ivrs.gatewayManager, _userId, _wallet, true, NATIVE_CHAIN_SELECTOR, GATEWAY_MANAGER_ROLE
        );
    }

    /**
     * @notice Overrides the removeWallet method to bridge wallet changes across chains
     * @param _wallet The wallet address to remove.
     * @param _role The role used by the caller.
     * @return _userId The user ID that the wallet was removed from
     */
    function removeWallet(address _wallet, bytes32 _role)
        public
        override(BaseUserRegistry, IUserRegistry)
        returns (bytes32)
    {
        bytes32 _userId = super.removeWallet(_wallet, _role);
        // Bridge wallet change
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        GatewayUtils.bridgeAddressChange(
            ivrs.gatewayManager,
            _userId,
            _wallet,
            false, // Remove wallet
            NATIVE_CHAIN_SELECTOR,
            GATEWAY_MANAGER_ROLE
        );
        return _userId;
    }

    /**
     * @notice Retrieves the address of the Resolver Verifier.
     * @dev This function provides access to the Resolver Verifier, which is used for investor credential verification.
     * @return The address of the Resolver Verifier.
     */
    function getResolverVerifier() external view returns (address) {
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        return ivrs.resolverVerifier;
    }

    /**
     * @notice Retrieves the schema ID used for investor credential management.
     * @dev This function provides access to the schema ID, which represents the structure of attestation data.
     * @return The schema ID as a `bytes32` value.
     */
    function getSchemaId() external view returns (bytes32) {
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        return ivrs.schemaId;
    }

    /**
     * @notice Verifies a subscription order against a zk-based proof.
     * @param _proof The proof data for the subscription.
     * @dev This uses the Resolver Verifier to validate the subscription.
     */
    function checkSubscription(OrderProofData calldata _proof) external view {
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        IAccessVerifier(ivrs.resolverVerifier).verifySubscription(_proof);
    }

    /**
     * @notice Retrieves the temporary proof data for the current attestation.
     * @return The temporary `SteelProofData` structure.
     */
    function getTempSteelProofData() external view returns (SteelProofData memory) {
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        return ivrs.tempSteelProofData;
    }

    /**
     * @notice Gets the dealer ID associated with an investor.
     * @param _investorId The unique ID of the investor.
     * @return dealerId The ID of the associated dealer.
     */
    function getDealer(bytes32 _investorId) public view returns (bytes32 dealerId) {
        return getBytes(_investorId, DEALER);
    }

    /**
     * @notice Verifies the validity of an investor's credential.
     * @param _investorId The unique ID of the investor.
     * @dev Reverts if the credential is invalid, expired, or revoked.
     */
    function checkCredential(bytes32 _investorId) public view {
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        bytes32 credentialUid = getBytes(_investorId, CREDENTIAL_ID);

        IEAS eas = ivrs.eas;
        if (!eas.isAttestationValid(credentialUid)) {
            revert IInvestorRegistry_NonExistingCredential();
        }

        Attestation memory attestation = eas.getAttestation(credentialUid);
        if (
            attestation.revocationTime != 0 || attestation.expirationTime < block.timestamp
                || attestation.attester != address(this)
        ) {
            revert IInvestorRegistry_CredentialInvalid();
        }

        (bytes32 returnedInvestorId,,) = abi.decode(attestation.data, (bytes32, bytes32[], uint64[]));

        if (returnedInvestorId != _investorId) {
            revert IInvestorRegistry_MismatchInvestorId();
        }
    }

    /**
     * @notice Verifies that an investor has a valid credential for a specific instrument.
     * @param _investorId The unique ID of the investor.
     * @param _instrumentId The ID of the instrument to check against.
     * @dev Reverts if the credential for the instrument is invalid or expired.
     */
    function checkCredentialInstrument(bytes32 _investorId, bytes32 _instrumentId) public view {
        _verifyCredentialForInstrument(_investorId, _instrumentId, false);
    }

    /**
     * @notice Verifies that an investor has a valid credential for a specific instrument for cross-chain operations.
     * @param _investorId The unique ID of the investor.
     * @param _instrumentId The ID of the instrument to check against.
     * @dev Reverts if the credential for the instrument is invalid or about to expire within 1 day.
     */
    function checkCredentialInstrumentForCrossChain(bytes32 _investorId, bytes32 _instrumentId) external view {
        _verifyCredentialForInstrument(_investorId, _instrumentId, true);
    }

    /**
     * @notice Verifies that an investor has a valid credential for a specific instrument with cross-chain threshold.
     * @param _investorId The unique ID of the investor.
     * @param _instrumentId The ID of the instrument to check against.
     * @param _isCrossChainOperation Whether this is a cross-chain operation requiring threshold buffer.
     * @dev Reverts if the credential for the instrument is invalid or expired.
     *      For cross-chain operations, both attestation and instrument expiry must be > current time + 1 day.
     */
    function _verifyCredentialForInstrument(bytes32 _investorId, bytes32 _instrumentId, bool _isCrossChainOperation)
        internal
        view
    {
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        bytes32 credentialUid = getBytes(_investorId, CREDENTIAL_ID);

        IEAS eas = ivrs.eas;
        if (!eas.isAttestationValid(credentialUid)) {
            revert IInvestorRegistry_NonExistingCredential();
        }

        Attestation memory attestation = eas.getAttestation(credentialUid);

        uint256 currentTimestamp = block.timestamp;
        uint256 thresholdTime = _isCrossChainOperation ? CROSS_CHAIN_THRESHOLD_TIME : 0;

        // Check if attestation is not revoked and is within threshold
        if (
            attestation.revocationTime != 0 || attestation.expirationTime < currentTimestamp + thresholdTime
                || attestation.attester != address(this)
        ) {
            revert IInvestorRegistry_CredentialInvalid();
        }

        (bytes32 returnedInvestorId, bytes32[] memory instrumentIds, uint64[] memory instrumentExpiryTimestamps) =
            abi.decode(attestation.data, (bytes32, bytes32[], uint64[]));

        if (returnedInvestorId != _investorId) {
            revert IInvestorRegistry_MismatchInvestorId();
        }

        for (uint256 i; i < instrumentIds.length; ++i) {
            if (_instrumentId == instrumentIds[i]) {
                // Check if instrument expiry is within threshold
                if (instrumentExpiryTimestamps[i] > currentTimestamp + thresholdTime) return;
                else break;
            }
        }
        revert IInvestorRegistry_InstrumentCredentialInvalid();
    }

    /**
     * @notice Revokes an attestation.
     * @param _attestationId The unique ID of the attestation to be revoked.
     */
    function _revokeAttestation(bytes32 _attestationId) internal {
        RevocationRequestData memory revocationData = RevocationRequestData({
            uid: _attestationId,
            value: 0 //No eth
        });
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();

        RevocationRequest memory revocation =
            RevocationRequest({schema: ivrs.eas.getAttestation(_attestationId).schema, data: revocationData});
        ivrs.eas.revoke(revocation);
    }

    /**
     * @notice Checks if the sender has extra access to the specified ID.
     * @param _id The unique ID being checked.
     * @return Boolean indicating if extra access is granted.
     */
    function _hasExtraAccess(bytes32 _id) internal view override returns (bool) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        InvestorRegistryStorage storage ivrs = _getInvestorRegistryStorage();
        if (_id == GENERAL_DATA_ID) {
            return false;
        }

        // If this is a cross-chain address operation and sender is the Gateway Manager
        if (msg.sender == address(ivrs.gatewayManager)) {
            return true;
        }

        return getBytes(_id, DEALER) == brs.dealerRegistry.getIdFromWallet(msg.sender);
    }

    /**
     * @notice Checks if the sender has extra access to a batch of IDs.
     * @param _ids An array of IDs being checked.
     * @return Boolean indicating if extra access is granted for all IDs.
     */
    function _hasExtraAccess(bytes32[] memory _ids) internal view override returns (bool) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();

        bytes32 dealerId = brs.dealerRegistry.getIdFromWallet(msg.sender);
        for (uint256 i; i < _ids.length; ++i) {
            if (_ids[i] == GENERAL_DATA_ID) {
                return false;
            }
            if (getBytes(_ids[i], DEALER) != dealerId) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Retrieves the storage slot for the `InvestorRegistryStorage` structure.
     * @dev Uses inline assembly to map the predefined storage slot to the `InvestorRegistryStorage` structure.
     * This method is used internally to access the investor registry's storage layout.
     * @return ivrs A reference to the `InvestorRegistryStorage` located at the predefined storage slot.
     */
    function _getInvestorRegistryStorage() private pure returns (InvestorRegistryStorage storage ivrs) {
        assembly {
            ivrs.slot := INVESTOR_REGISTRY_STORAGE_SLOT
        }
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {IDealerRegistry} from "src/interfaces/IDealerRegistry.sol";
import {IFundRegistry} from "src/interfaces/IFundRegistry.sol";
import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";
import {IOperationsEngine} from "src/interfaces/IOperationsEngine.sol";
import {IBaseRegistry} from "src/interfaces/IBaseRegistry.sol";
import {ICheckModule} from "src/interfaces/operations/ICheckModule.sol";

import {LibreUUPSUpgradeable} from "src/utils/LibreUUPSUpgradeable.sol";

import {EternalRegistryStorage} from "src/registries/EternalRegistryStorage.sol";

import "src/utils/Constant.sol";

/**
 * @title Base contract for Registies implementations
 * @author Libre
 * @notice Shared functionalities for registries
 * @dev RoleRegistry not included as it is a special type of registry
 */
abstract contract BaseRegistry is IBaseRegistry, LibreUUPSUpgradeable, EternalRegistryStorage {
    // keccak256(abi.encode(uint256(keccak256("BaseRegistry.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant BASE_REGISTRY_STORAGE_SLOT =
        0xb2c66b460d9aa93b78f84537d8b5e3f1eafaad44c253f0046a48cca1de146000;

    /// @custom:storage-location erc7201:BaseRegistry.storage
    struct BaseRegistryStorage {
        bytes32 IS_VALID_ID;
        IInvestorRegistry investorRegistry;
        IInstrumentRegistry instrumentRegistry;
        IDealerRegistry dealerRegistry;
        IFundRegistry fundRegistry;
        IEternalRegistryStorage jurisdictionRegistry;
        IOperationsEngine operationsEngine;
    }

    constructor() {
        _disableInitializers();
    }

    function getTrackedData(bytes memory _data) external returns (bytes memory) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();

        if (!brs.operationsEngine.isAvailableModule(msg.sender)) {
            revert IBaseRegistry_NotRegisteredModule();
        }

        (bool success, bytes memory returnData) =
            msg.sender.delegatecall(abi.encodeWithSelector(ICheckModule.getTrackedData.selector, _data));
        if (!success) {
            revert IBaseRegistry_FailedToGetTrackedData();
        }

        return abi.decode(returnData, (bytes));
    }

    function setBool(bytes32 _id, bytes32 _key, bool _value, bytes32 _senderRole) external {
        _checkHasRegistryWriteAccess(_id, _senderRole);
        _onlyConfigurableKey(_id, _key);
        _setBool(_id, _key, _value);
        _afterEntryUpdate(_id);
    }

    function setUint(bytes32 _id, bytes32 _key, uint256 _value, bytes32 _senderRole) external {
        _checkHasRegistryWriteAccess(_id, _senderRole);
        _onlyConfigurableKey(_id, _key);
        _setUint(_id, _key, _value);
        _afterEntryUpdate(_id);
    }

    function setAddress(bytes32 _id, bytes32 _key, address _value, bytes32 _senderRole) external {
        _checkHasRegistryWriteAccess(_id, _senderRole);
        _onlyConfigurableKey(_id, _key);
        _setAddress(_id, _key, _value);
        _afterEntryUpdate(_id);
    }

    function setString(bytes32 _id, bytes32 _key, string calldata _value, bytes32 _senderRole) external {
        _checkHasRegistryWriteAccess(_id, _senderRole);
        _onlyConfigurableKey(_id, _key);
        _setString(_id, _key, _value);
        _afterEntryUpdate(_id);
    }

    function setBytes(bytes32 _id, bytes32 _key, bytes32 _value, bytes32 _senderRole) external {
        _checkHasRegistryWriteAccess(_id, _senderRole);
        _onlyConfigurableKey(_id, _key);
        _setBytes(_id, _key, _value);
        _afterEntryUpdate(_id);
    }

    function setBatch(
        bytes32[] memory _ids,
        bytes32[] memory _keys,
        bool[] memory _boolValues,
        uint256[] memory _uintValues,
        address[] memory _addressValues,
        string[] memory _stringValues,
        bytes32[] memory _bytesValues,
        bytes32 _senderRole
    ) external {
        _checkHasRegistryWriteAccess(_ids, _senderRole);
        _onlyConfigurableKeys(_ids, _keys);
        _setBatch(_ids, _keys, _boolValues, _uintValues, _addressValues, _stringValues, _bytesValues);
        _afterEntryUpdate(_ids);
    }

    /**
     * @notice Retrieves the address of the Investor Registry contract.
     * @return The `IInvestorRegistry` interface instance representing the Investor Registry contract.
     */
    function getInvestorRegistry() external view returns (IInvestorRegistry) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        return brs.investorRegistry;
    }

    /**
     * @notice Retrieves the address of the Instrument Registry contract.
     * @return The `IInstrumentRegistry` interface instance representing the Instrument Registry contract.
     */
    function getInstrumentRegistry() external view returns (IInstrumentRegistry) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        return brs.instrumentRegistry;
    }

    /**
     * @notice Retrieves the address of the Dealer Registry contract.
     * @return The `IDealerRegistry` interface instance representing the Dealer Registry contract.
     */
    function getDealerRegistry() external view returns (IDealerRegistry) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        return brs.dealerRegistry;
    }

    /**
     * @notice Retrieves the address of the Fund Registry contract.
     * @return The `IFundRegistry` interface instance representing the Fund Registry contract.
     */
    function getFundRegistry() external view returns (IFundRegistry) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        return brs.fundRegistry;
    }

    /**
     * @notice Retrieves the address of the Jurisdiction Registry contract.
     * @return The `IEternalRegistryStorage` interface instance representing the Jurisdiction Registry contract.
     */
    function getJurisdictionRegistry() external view returns (IEternalRegistryStorage) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        return brs.jurisdictionRegistry;
    }

    /**
     * @notice Retrieves the address of the Operations Engine contract.
     * @return The `IOperationsEngine` interface instance representing the Operations Engine contract.
     */
    function getOperationsEngine() external view returns (IOperationsEngine) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        return brs.operationsEngine;
    }

    function initialize(bytes32 _validIdHash) public onlyInitializing {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        brs.IS_VALID_ID = _validIdHash;
        _setReservedKey(GENERAL_DATA_ID, _validIdHash);
        _setBool(GENERAL_DATA_ID, _validIdHash, true);
        __UUPSUpgradeable_init();
    }

    // internals for single calls

    /**
     * @notice Set the basic reserved keys for new entries
     * @param _id Id of the entry
     */
    function _setDefaultReservedKeys(bytes32 _id) internal virtual {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        _setReservedKey(_id, brs.IS_VALID_ID);
    }

    /**
     * @notice Trigger updates to be done after entry updates
     * @param _id Id of the updated entry
     * @dev Override for different logic
     */
    function _afterEntryUpdate(bytes32 _id) internal virtual {}

    /**
     * @notice Trigger updates to be done after entry updates
     * @param _ids Id of the entries updated
     * @dev Override for different logic
     * @dev Empty to avoid iterating the array when no logic is needed
     */
    function _afterEntryUpdate(bytes32[] memory _ids) internal virtual {}

    /**
     * @notice Checks if the caller can set values for a specific entry
     * @param _id The id of the entry being accessed
     * @param _senderRole The role sender claims to have
     * @dev Tracking engine has special access and can call with empty args
     */
    function _checkHasRegistryWriteAccess(bytes32 _id, bytes32 _senderRole) internal view {
        if (_roleRegistry().hasRole(REGISTRY_WRITER_ROLE, msg.sender)) return;
        _checkHasAccess(_id, _senderRole);
    }

    /**
     * @notice Checks if the caller can set values for a list of entries
     * @param _ids The ids of the entries being accessed
     * @param _senderRole The role sender claims to have
     * @dev Tracking engine has special access and can call with empty args
     */
    function _checkHasRegistryWriteAccess(bytes32[] memory _ids, bytes32 _senderRole) internal view {
        if (_roleRegistry().hasRole(REGISTRY_WRITER_ROLE, msg.sender)) return;
        _checkHasAccess(_ids, _senderRole);
    }

    /**
     * @notice Checks if the caller can set values for a specific entry
     * @param _id Id of the entry being accessed
     * @param _senderRole Role sender claims to have
     * @dev Entry id needs to be valid
     * @dev Override for different logic
     */
    function _checkHasAccess(bytes32 _id, bytes32 _senderRole) internal view virtual {
        if (!(_isValidId(_id) && _hasAccess(_id, _senderRole))) {
            revert IBaseRegistry_AccessDenied();
        }
    }

    /**
     * @notice Verify if the caller can access a specific entry
     * @param _id Id of the entry being accessed
     * @param _senderRole Role sender claims to have
     * @return Y/N
     * @dev Override for different logic
     */
    function _hasAccess(bytes32 _id, bytes32 _senderRole) internal view virtual returns (bool) {
        return _roleHasAccess(_senderRole) || _hasExtraAccess(_id);
    }

    /**
     * @notice Verify if the caller has special access to an entry
     * @param _id Id of the entry being accessed
     * @return Y/N
     * @dev Override for different logic
     */
    function _hasExtraAccess(bytes32 _id) internal view virtual returns (bool) {}

    /**
     * @notice Verify if an entry is valid
     * @param _id Id to verify
     * @return Y/N
     * @dev Override for different logic
     */
    function _isValidId(bytes32 _id) internal view virtual returns (bool) {
        BaseRegistryStorage storage brs = _getBaseRegistryStorage();
        return getBool(_id, brs.IS_VALID_ID);
    }

    /**
     * @notice Check if an entry is valid
     * @param _id Id to verify
     */
    function _checkIsValidId(bytes32 _id) internal view {
        if (!_isValidId(_id)) {
            revert IBaseRegistry_NotAValidId();
        }
    }

    // internals for batch calls

    /**
     * @notice Checks if the caller can set values for a list of entries
     * @param _ids Ids of the entries being accessed
     * @param _senderRole Role sender claims to have
     * @dev Each entry id needs to be valid
     * @dev Override for different logic
     */
    function _checkHasAccess(bytes32[] memory _ids, bytes32 _senderRole) internal view virtual {
        if (!_areValidIds(_ids) || !_hasAccess(_ids, _senderRole)) {
            revert IBaseRegistry_AccessDenied();
        }
    }

    /**
     * @notice Verify if the caller can access a list of entries
     * @param _ids Ids of the entries being accessed
     * @param _senderRole Role sender claims to have
     * @return Y/N
     * @dev Override for different logic
     */
    function _hasAccess(bytes32[] memory _ids, bytes32 _senderRole) internal view virtual returns (bool) {
        return _roleHasAccess(_senderRole) || _hasExtraAccess(_ids);
    }

    /**
     * @notice Verify if the caller has special access to a list of entries
     * @param _ids Ids of the entries being accessed
     * @return Y/N
     * @dev Override for different logic
     */
    function _hasExtraAccess(bytes32[] memory _ids) internal view virtual returns (bool) {
        for (uint256 i; i < _ids.length; ++i) {
            if (!_hasExtraAccess(_ids[i])) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Verify if a list of entries are valid
     * @param _ids Ids to verify
     * @return Y/N
     * @dev Override for different logic
     * @dev Override if entries validation is not needed to avoid iterating the list
     */
    function _areValidIds(bytes32[] memory _ids) internal view virtual returns (bool) {
        for (uint256 i; i < _ids.length; ++i) {
            if (!_isValidId(_ids[i])) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Retrieves the storage structure for the contract.
     * @return store The storage object for the base registry.
     */
    function _getBaseRegistryStorage() internal pure returns (BaseRegistryStorage storage store) {
        assembly {
            store.slot := BASE_REGISTRY_STORAGE_SLOT
        }
    }

    /**
     * @notice Ensures that the provided ID is not a zero value.
     * @dev Reverts with `IBaseRegistry_NotAValidId` if the ID is zero.
     * @param _id The ID to validate.
     */
    function _nonZeroId(bytes32 _id) internal pure {
        if (_id == 0) {
            revert IBaseRegistry_NotAValidId();
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import {BaseRegistry} from "src/registries/BaseRegistry.sol";
import {IUserRegistry} from "src/interfaces/IUserRegistry.sol";

/**
 * @title BaseUserRegistry
 * @author Libre
 * @notice Provides functionality for managing wallets and associating them with user IDs.
 * @dev This contract verifies wallet ownership using ECDSA signatures and ensures that wallets are uniquely linked to user IDs.
 *
 * Features:
 * - Add a wallet to a user ID after verifying ownership with a signed message.
 * - Retrieve all wallets linked to a specific user ID.
 * - Get the user ID associated with a specific wallet.
 */
abstract contract BaseUserRegistry is BaseRegistry, IUserRegistry {
    using ECDSA for bytes32;

    // keccak256(abi.encode(uint256(keccak256("BaseUserRegistry.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant BASE_USER_REGISTRY_STORAGE_SLOT =
        0x6f933317f0ef3f5c481822d7bb2f0d5186d0b51ef77db971f6da83b7e837e000;

    /// @custom:storage-location erc7201:BaseUserRegistry.storage
    struct BaseUserRegistryStorage {
        // Mapping of wallet addresses (param1) to user IDs (param2)
        mapping(address wallet => bytes32 userId) ownedBy;
        // Mapping of user IDs (param1) to an array of wallet addresses (param2)
        mapping(bytes32 userId => address[] wallets) ownedWallets;
    }

    function getWallets(bytes32 _userId) external view override returns (address[] memory) {
        BaseUserRegistryStorage storage burs = _getBaseUserRegistryStorage();
        return burs.ownedWallets[_userId];
    }

    /**
     * @notice Adds a wallet to a user ID after verifying correct role
     * @param _userId The ID of the user.
     * @param _wallet The wallet address to associate with the user ID.
     * @param _role The role used by the caller.
     */
    function addWallet(bytes32 _userId, address _wallet, bytes32 _role) public virtual override {
        _checkRoleHasAccess(_role);
        _checkIsValidId(_userId);
        _addWallet(_userId, _wallet);
    }

    /**
     * @notice Removes a wallet from a user ID.
     * @param _wallet The wallet address to remove from the user ID.
     * @param _role The role used by the caller.
     * @return _userId The user ID that the wallet was removed from.
     *
     * Requirements:
     * - The `_wallet` must be associated with a user ID.
     */
    function removeWallet(address _wallet, bytes32 _role) public virtual returns (bytes32) {
        _checkRoleHasAccess(_role);
        BaseUserRegistryStorage storage burs = _getBaseUserRegistryStorage();
        bytes32 _userId = burs.ownedBy[_wallet];
        _checkIsValidId(_userId);

        uint256 ownedWalletsLength = burs.ownedWallets[_userId].length;

        for (uint256 i; i < ownedWalletsLength; i++) {
            if (burs.ownedWallets[_userId][i] == _wallet) {
                burs.ownedWallets[_userId][i] = burs.ownedWallets[_userId][ownedWalletsLength - 1];
                burs.ownedWallets[_userId].pop();
                break;
            }
        }
        burs.ownedBy[_wallet] = 0x0;

        emit WalletRemoved(_wallet);

        return _userId;
    }

    function getIdFromWallet(address wallet) public view override returns (bytes32) {
        BaseUserRegistryStorage storage burs = _getBaseUserRegistryStorage();
        return burs.ownedBy[wallet];
    }

    /**
     * @notice Internally adds a wallet to a user ID.
     * @param _id The user ID to associate with the wallet.
     * @param _wallet The wallet address to associate with the user ID.
     *
     * Requirements:
     * - The `_wallet` must not already be associated with another user ID.
     */
    function _addWallet(bytes32 _id, address _wallet) internal {
        BaseUserRegistryStorage storage burs = _getBaseUserRegistryStorage();

        if (_roleRegistry().isBlacklisted(_wallet)) {
            revert IUserRegistry_WalletBlacklisted();
        }

        if (burs.ownedBy[_wallet] != 0x0) {
            revert IUserRegistry_WalletAlreadyClaimed();
        }

        burs.ownedWallets[_id].push(_wallet);
        burs.ownedBy[_wallet] = _id;
        emit WalletAdded(_wallet);
    }

    /**
     * @dev Retrieves the storage structure for the contract.
     * @return store The storage object for the base user registry.
     */
    function _getBaseUserRegistryStorage() internal pure returns (BaseUserRegistryStorage storage store) {
        assembly {
            store.slot := BASE_USER_REGISTRY_STORAGE_SLOT
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";
import {Steel} from "risc0/steel/Steel.sol";
import {IAccessVerifier, CredentialProofData} from "src/interfaces/IAccessVerifier.sol";
import {SchemaResolver} from "eas-contracts/resolver/SchemaResolver.sol";
import {IEAS, Attestation} from "eas-contracts/IEAS.sol";
import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import "src/utils/Constant.sol";

/**
 * @title ResolverVerifier
 * @notice This contract handles the verification of credentials and subscriptions using zkVM proofs.
 *         It integrates with RISC Zero Verifier and manages attestation schemas for investor compliance.
 * @dev The contract utilizes SchemaResolver for EAS-based attestation validation and implements IAccessVerifier.
 * @author Libre
 */
contract ResolverVerifier is SchemaResolver, IAccessVerifier {
    /// @notice Image IDs of the zkVM binaries to accept verification from.
    bytes32 public credentialImageID;
    bytes32 public subscriptionImageID;

    /// @notice RISC Zero verifier contract address.
    IRiscZeroVerifier public immutable verifier;

    /// @notice Investor registry to manage investor-related data and credentials.
    IInvestorRegistry public immutable investorRegistry;

    /// @notice Address of the policy viewer used to generate the proofs
    address public immutable policyViewer;

    /// @dev Error thrown when a non-investor registry address tries to update image IDs.
    error ResolverVerifier_NotInvestorRegistry();

    /// @dev Error thrown when a journal commitment fails validation.
    error ResolverVerifier_InvalidCommitment();

    constructor(
        IEAS eas,
        IInvestorRegistry _investorRegistry,
        IRiscZeroVerifier _verifier,
        bytes32 _credentialImageID,
        bytes32 _subscriptionImageID,
        address _policyViewer
    ) SchemaResolver(eas) {
        investorRegistry = _investorRegistry;
        verifier = _verifier;
        credentialImageID = _credentialImageID;
        subscriptionImageID = _subscriptionImageID;
        policyViewer = _policyViewer;
    }

    function updateImageIDs(bytes32 _credentialImageID, bytes32 _subscriptionImageID) external {
        if (msg.sender != address(investorRegistry)) {
            revert ResolverVerifier_NotInvestorRegistry();
        }
        credentialImageID = _credentialImageID;
        subscriptionImageID = _subscriptionImageID;
    }

    function verifyCredential(CredentialProofData memory _proof) public view {
        if (!Steel.validateCommitment(_proof.journal.commitment)) {
            revert ResolverVerifier_InvalidCommitment();
        }
        bytes32 journalHash = sha256(abi.encode(_proof.journal));
        verifier.verify(_proof.seal, credentialImageID, journalHash);
    }

    function verifySubscription(OrderProofData calldata _proof) public view {
        if (!Steel.validateCommitment(_proof.journal.commitment)) {
            revert ResolverVerifier_InvalidCommitment();
        }
        bytes32 journalHash = sha256(abi.encode(_proof.journal));
        verifier.verify(_proof.seal, subscriptionImageID, journalHash);
    }

    /**
     * @notice Handles logic for attestation verification.
     * @param _attestation The attestation data.
     * @return Whether the attestation passes verification.
     * @dev Includes credential validation and instrument-specific compliance checks.
     */
    function onAttest(Attestation calldata _attestation, uint256 /*value*/ ) internal view override returns (bool) {
        if (_attestation.attester != address(investorRegistry)) {
            return false;
        }
        SteelProofData memory steelProofData = investorRegistry.getTempSteelProofData();
        //Decode attestation schema
        (bytes32 investorId, bytes32[] memory instrumentIds, uint64[] memory instrumentExpiryTimestamps) =
            abi.decode(_attestation.data, (bytes32, bytes32[], uint64[]));

        if (instrumentIds.length != instrumentExpiryTimestamps.length) {
            return false;
        }

        bytes32 currentCredentialId = investorRegistry.getBytes(investorId, CREDENTIAL_ID);
        if (currentCredentialId != bytes32(0)) {
            Attestation memory oldAttestation = _eas.getAttestation(currentCredentialId);
            if (oldAttestation.revocationTime == block.timestamp) {
                return true;
            }
        }

        CredentialProofData memory proof;
        proof.journal.commitment = steelProofData.commitment;
        proof.journal.expiryTimestamp = _attestation.expirationTime;
        proof.journal.investorId = investorId;
        proof.journal.policyViewer = policyViewer;
        proof.seal = steelProofData.seal;

        {
            //Decode old attestation schema
            bytes32 oldAttestationId = investorRegistry.getBytes(investorId, CREDENTIAL_ID);
            if (oldAttestationId == bytes32(0)) {
                proof.journal.instrumentIds = instrumentIds;
                proof.journal.instrumentExpiryTimestamps = instrumentExpiryTimestamps;
            } else {
                Attestation memory oldAttestation = _eas.getAttestation(oldAttestationId);
                (, bytes32[] memory oldInstrumentIds, uint64[] memory oldInstrumentExpiryTimestamps) =
                    abi.decode(oldAttestation.data, (bytes32, bytes32[], uint64[]));

                //only keeping instruments that are new or updated for proof checking
                bytes32[] memory newInstrumentIds = new bytes32[](instrumentIds.length);
                uint64[] memory newInstrumentExpiryTimestamps = new uint64[](instrumentExpiryTimestamps.length);
                uint256 newOrUpdatedCount;
                for (uint256 i; i < instrumentIds.length; ++i) {
                    bool newOrUpdated = true;
                    for (uint256 j; j < oldInstrumentIds.length; ++j) {
                        if (instrumentIds[i] == oldInstrumentIds[j]) {
                            if (instrumentExpiryTimestamps[i] == oldInstrumentExpiryTimestamps[j]) {
                                newOrUpdated = false;
                            }
                            break;
                        }
                    }
                    if (newOrUpdated) {
                        newInstrumentIds[newOrUpdatedCount] = (instrumentIds[i]);
                        newInstrumentExpiryTimestamps[newOrUpdatedCount] = (instrumentExpiryTimestamps[i]);
                        ++newOrUpdatedCount;
                    }
                }

                //Resize Arrays to have length of newOrUpdatedCount
                assembly {
                    mstore(newInstrumentIds, newOrUpdatedCount)
                    mstore(newInstrumentExpiryTimestamps, newOrUpdatedCount)
                }

                proof.journal.instrumentIds = newInstrumentIds;
                proof.journal.instrumentExpiryTimestamps = newInstrumentExpiryTimestamps;
            }
        }

        //reverts if proof is invalid
        verifyCredential(proof);

        return true;
    }

    /**
     * @notice Handles logic for attestation revocation.
     * @return Always returns true as all revocation requests are allowed.
     */
    function onRevoke(Attestation calldata, /*attestation*/ uint256 /*value*/ ) internal pure override returns (bool) {
        return true;
    }
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IInvestorRegistry} from "src/interfaces/IInvestorRegistry.sol";
import {IFundRegistry} from "src/interfaces/IFundRegistry.sol";
import {IDealerRegistry} from "src/interfaces/IDealerRegistry.sol";
import {IInstrumentRegistry} from "src/interfaces/IInstrumentRegistry.sol";
import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";
import {IRoleRegistry} from "src/interfaces/IRoleRegistry.sol";

import {IOperationModule, OPERATIONS} from "src/interfaces/operations/IOperationModule.sol";

/**
 * @title ICheckModule
 * @author Libre
 * @notice Interface for modules that perform validation checks on operations for instruments.
 * @dev This interface extends the IOperationModule interface and adds functionality for checking dependencies,
 *      querying tracked data, and performing operation-specific checks.
 */
interface ICheckModule is IOperationModule {
    /**
     * @notice Checks if the dependencies of the module are respected
     * @param _id The id of the instrument the module is enabled for
     * @return true if the dependencies are respected, false otherwise
     */
    function getDependenciesRespected(bytes32 _id) external view returns (bool);

    /**
     * @notice Function to be delegatecalled by the registry to query the tracked data
     * @param _data Arbitrary data that can be used by the module to get the tracked data
     * @return Tracked data needed to perform the check
     */
    function getTrackedData(bytes memory _data) external view returns (bytes memory);

    /**
     * @notice Function to be delegatecalled by the registry to perform the check
     * @param _operation The operation to be checked
     * @param _id The id of the operation
     * @param _data Arbitrary data that can be used by the module to perform the check
     * @return result memory Result of the check
     */
    function check(OPERATIONS _operation, bytes32 _id, bytes calldata _data) external returns (bytes memory result);
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

import {IEternalRegistryStorage} from "src/interfaces/IEternalRegistryStorage.sol";

import "src/utils/Constant.sol";

/**
 * @title EternalRegistryStorage
 * @author Libre
 * @notice A flexible storage system for managing different types of data (booleans, numbers, addresses, strings, and arrays).
 *
 * Features:
 * - Store and retrieve various data types using IDs and keys.
 * - Batch operations to handle multiple updates at once.
 * - Protect certain keys from being changed in the future.
 * - Keep logs of changes through events.
 *
 * How to use:
 * - Use `get` methods to retrieve stored data.
 * - Use `set` methods to save or update data.
 * - Use `_setReservedKey` to lock a key so it can't be changed.
 */
abstract contract EternalRegistryStorage is IEternalRegistryStorage {
    struct EternalStorage {
        // Mapping of entry ID (`id`) to a mapping of key (`key`) to a boolean value.
        mapping(bytes32 id => mapping(bytes32 key => bool value)) booleans;
        // Mapping of entry ID (`id`) to a mapping of key (`key`) to a uint256 value.
        mapping(bytes32 id => mapping(bytes32 key => uint256 value)) uints;
        // Mapping of entry ID (`id`) to a mapping of key (`key`) to an address value.
        mapping(bytes32 id => mapping(bytes32 key => address value)) addresses;
        // Mapping of entry ID (`id`) to a mapping of key (`key`) to a string value.
        mapping(bytes32 id => mapping(bytes32 key => string value)) strings;
        // Mapping of entry ID (`id`) to a mapping of key (`key`) to a bytes32 value.
        mapping(bytes32 id => mapping(bytes32 key => bytes32 value)) bytesStorage;
        // Mapping of entry ID (`id`) to a mapping of restricted key (`key`) to a boolean indicating restriction status.
        // set of key identifiers that cannot be edited per each entry
        mapping(bytes32 id => mapping(bytes32 key => bool isRestricted)) internalKeys;
    }

    function getBool(bytes32 _id, bytes32 _key) public view returns (bool) {
        EternalStorage storage es = _getEternalStorage();
        return es.booleans[_id][_key];
    }

    function getUint(bytes32 _id, bytes32 _key) public view returns (uint256) {
        EternalStorage storage es = _getEternalStorage();
        return es.uints[_id][_key];
    }

    function getAddress(bytes32 _id, bytes32 _key) public view returns (address) {
        EternalStorage storage es = _getEternalStorage();
        return es.addresses[_id][_key];
    }

    function getString(bytes32 _id, bytes32 _key) public view returns (string memory) {
        EternalStorage storage es = _getEternalStorage();
        return es.strings[_id][_key];
    }

    function getBatch(
        bytes32[] memory _ids,
        bytes32[] memory _keys,
        uint256 _boolCount,
        uint256 _uintCount,
        uint256 _addressCount,
        uint256 _stringCount,
        uint256 _bytesCount
    )
        public
        view
        returns (
            bool[] memory _boolValues,
            uint256[] memory _uintValues,
            address[] memory _addressValues,
            string[] memory _stringValues,
            bytes32[] memory _bytesValues
        )
    {
        {
            if (
                _ids.length != _keys.length
                    || _ids.length != _boolCount + _uintCount + _addressCount + _stringCount + _bytesCount
            ) {
                revert IEternalRegistryStorage_BatchLengthMismatch();
            }
        }
        _boolValues = new bool[](_boolCount);
        _uintValues = new uint256[](_uintCount);
        _addressValues = new address[](_addressCount);
        _stringValues = new string[](_stringCount);
        _bytesValues = new bytes32[](_bytesCount);

        uint256 batchElement;
        for (uint256 i; i < _boolCount; ++i) {
            _boolValues[i] = getBool(_ids[batchElement], _keys[batchElement]);
            ++batchElement;
        }
        for (uint256 i; i < _uintCount; ++i) {
            _uintValues[i] = getUint(_ids[batchElement], _keys[batchElement]);
            ++batchElement;
        }
        for (uint256 i; i < _addressCount; ++i) {
            _addressValues[i] = getAddress(_ids[batchElement], _keys[batchElement]);
            ++batchElement;
        }
        for (uint256 i; i < _stringCount; ++i) {
            _stringValues[i] = getString(_ids[batchElement], _keys[batchElement]);
            ++batchElement;
        }
        for (uint256 i; i < _bytesCount; ++i) {
            _bytesValues[i] = getBytes(_ids[batchElement], _keys[batchElement]);
            ++batchElement;
        }
        return (_boolValues, _uintValues, _addressValues, _stringValues, _bytesValues);
    }

    function getBytes(bytes32 _id, bytes32 _key) public view returns (bytes32) {
        EternalStorage storage es = _getEternalStorage();
        return es.bytesStorage[_id][_key];
    }

    /**
     * @notice Prevent future modifications of a specific key in a given entry
     * @param _id Id of the entry where the key is restricted
     * @param _key Key to restrict
     * @dev use `onlyConfigurableKey` modifier to ensure
     * only non restricted keys are modified
     */
    function _setReservedKey(bytes32 _id, bytes32 _key) internal {
        EternalStorage storage es = _getEternalStorage();
        es.internalKeys[_id][_key] = true;
        emit KeyRestricted(_id, _key);
    }

    function _setBool(bytes32 _id, bytes32 _key, bool _value) internal {
        EternalStorage storage es = _getEternalStorage();
        es.booleans[_id][_key] = _value;
        emit AddedBool(_id, _key, _value);
    }

    function _setUint(bytes32 _id, bytes32 _key, uint256 _value) internal {
        EternalStorage storage es = _getEternalStorage();
        es.uints[_id][_key] = _value;
        emit AddedUint(_id, _key, _value);
    }

    function _setAddress(bytes32 _id, bytes32 _key, address _value) internal {
        EternalStorage storage es = _getEternalStorage();
        es.addresses[_id][_key] = _value;
        emit AddedAddress(_id, _key, _value);
    }

    function _setString(bytes32 _id, bytes32 _key, string calldata _value) internal {
        EternalStorage storage es = _getEternalStorage();
        es.strings[_id][_key] = _value;
        emit AddedString(_id, _key, _value);
    }

    function _setBytes(bytes32 _id, bytes32 _key, bytes32 _value) internal {
        EternalStorage storage es = _getEternalStorage();
        es.bytesStorage[_id][_key] = _value;
        emit AddedBytes(_id, _key, _value);
    }

    function _setBatch(
        bytes32[] memory _ids,
        bytes32[] memory _keys,
        bool[] memory _boolValues,
        uint256[] memory _uintValues,
        address[] memory _addressValues,
        string[] memory _stringValues,
        bytes32[] memory _bytesValues
    ) internal {
        if (
            _ids.length != _keys.length
                || _ids.length
                    != _boolValues.length + _uintValues.length + _addressValues.length + _stringValues.length
                        + _bytesValues.length
        ) {
            revert IEternalRegistryStorage_BatchLengthMismatch();
        }
        uint256 batchElement;
        for (uint256 i; i < _boolValues.length; ++i) {
            _setBool(_ids[batchElement], _keys[batchElement], _boolValues[i]);
            ++batchElement;
        }
        for (uint256 i; i < _uintValues.length; ++i) {
            _setUint(_ids[batchElement], _keys[batchElement], _uintValues[i]);
            ++batchElement;
        }
        for (uint256 i; i < _addressValues.length; ++i) {
            _setAddress(_ids[batchElement], _keys[batchElement], _addressValues[i]);
            ++batchElement;
        }
        for (uint256 i; i < _stringValues.length; ++i) {
            EternalStorage storage es = _getEternalStorage();
            // no conversion from memory to calldata
            es.strings[_ids[batchElement]][_keys[batchElement]] = _stringValues[i];
            emit AddedString(_ids[batchElement], _keys[batchElement], _stringValues[i]);
            ++batchElement;
        }
        for (uint256 i; i < _bytesValues.length; ++i) {
            _setBytes(_ids[batchElement], _keys[batchElement], _bytesValues[i]);
            ++batchElement;
        }
    }

    function _getEternalStorage() internal view returns (EternalStorage storage) {
        EternalStorage storage es;
        bytes32 slot = ETERNAL_STORAGE_SLOT;
        assembly {
            es.slot := slot
        }
        return es;
    }

    function _onlyConfigurableKey(bytes32 _id, bytes32 _key) internal view {
        EternalStorage storage es = _getEternalStorage();
        if (es.internalKeys[_id][_key]) {
            revert IEternalRegistryStorage_AttemptToSetARestrictedKey();
        }
    }

    function _onlyConfigurableKeys(bytes32[] memory _ids, bytes32[] memory _keys) internal view {
        for (uint256 i; i < _keys.length; ++i) {
            _onlyConfigurableKey(_ids[i], _keys[i]);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.19;

import "../Strings.sol";

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

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError, bytes32) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
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
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError, bytes32) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError, bytes32) {
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
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 message) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            message := keccak256(0x00, 0x3c)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Data with intended validator, created from a
     * `validator` and `data` according to the version 0 of EIP-191.
     *
     * See {recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {CredentialProofData, OrderProofData} from "src/utils/Types.sol";

/**
 * @title IAccessVerifier
 * @notice Interface for verifying access credentials and subscription orders using off-chain generated proofs.
 * This interface utilizes cryptographic proofs (e.g., Steel proofs) to ensure secure verification of investor credentials
 * and subscription orders in compliance with the defined rules and regulations.
 *
 * @dev The Steel proofs must be generated off-chain using RISC0-zkVM and then submitted on-chain for verification.
 * These proofs ensure privacy and correctness while validating investor actions and subscriptions.
 */
interface IAccessVerifier {
    /// @notice Verifies the Credential for an investor, if the Steel proof verifies that they are allowed to interact with an instrument
    /// @dev The Steel proof must be generated off-chain using RISC0-zkVM and submitted here.
    function verifyCredential(CredentialProofData calldata _proof) external;

    /// @notice Verifies a subscription order for an investor, if the Steel proof verifies that their subscription to an instrument is valid
    /// @dev The Steel proof must be generated off-chain using RISC0-zkVM and submitted here.
    function verifySubscription(OrderProofData calldata _proof) external view;

    /// @notice Returns the image ID used for credential verification.
    function credentialImageID() external view returns (bytes32);

    /// @notice Returns the image ID used for subscription verification.
    function subscriptionImageID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import { AccessDenied, InvalidEAS, InvalidLength, uncheckedInc } from "./../Common.sol";
import { IEAS, Attestation } from "./../IEAS.sol";
import { Semver } from "./../Semver.sol";
import { ISchemaResolver } from "./ISchemaResolver.sol";

/// @title SchemaResolver
/// @notice The base schema resolver contract.
abstract contract SchemaResolver is ISchemaResolver, Semver {
    error InsufficientValue();
    error NotPayable();

    // The global EAS contract.
    IEAS internal immutable _eas;

    /// @dev Creates a new resolver.
    /// @param eas The address of the global EAS contract.
    constructor(IEAS eas) Semver(1, 3, 0) {
        if (address(eas) == address(0)) {
            revert InvalidEAS();
        }

        _eas = eas;
    }

    /// @dev Ensures that only the EAS contract can make this call.
    modifier onlyEAS() {
        _onlyEAS();

        _;
    }

    /// @inheritdoc ISchemaResolver
    function isPayable() public pure virtual returns (bool) {
        return false;
    }

    /// @dev ETH callback.
    receive() external payable virtual {
        if (!isPayable()) {
            revert NotPayable();
        }
    }

    /// @inheritdoc ISchemaResolver
    function attest(Attestation calldata attestation) external payable onlyEAS returns (bool) {
        return onAttest(attestation, msg.value);
    }

    /// @inheritdoc ISchemaResolver
    function multiAttest(
        Attestation[] calldata attestations,
        uint256[] calldata values
    ) external payable onlyEAS returns (bool) {
        uint256 length = attestations.length;
        if (length != values.length) {
            revert InvalidLength();
        }

        // We are keeping track of the remaining ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 remainingValue = msg.value;

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            // Ensure that the attester/revoker doesn't try to spend more than available.
            uint256 value = values[i];
            if (value > remainingValue) {
                revert InsufficientValue();
            }

            // Forward the attestation to the underlying resolver and return false in case it isn't approved.
            if (!onAttest(attestations[i], value)) {
                return false;
            }

            unchecked {
                // Subtract the ETH amount, that was provided to this attestation, from the global remaining ETH amount.
                remainingValue -= value;
            }
        }

        return true;
    }

    /// @inheritdoc ISchemaResolver
    function revoke(Attestation calldata attestation) external payable onlyEAS returns (bool) {
        return onRevoke(attestation, msg.value);
    }

    /// @inheritdoc ISchemaResolver
    function multiRevoke(
        Attestation[] calldata attestations,
        uint256[] calldata values
    ) external payable onlyEAS returns (bool) {
        uint256 length = attestations.length;
        if (length != values.length) {
            revert InvalidLength();
        }

        // We are keeping track of the remaining ETH amount that can be sent to resolvers and will keep deducting
        // from it to verify that there isn't any attempt to send too much ETH to resolvers. Please note that unless
        // some ETH was stuck in the contract by accident (which shouldn't happen in normal conditions), it won't be
        // possible to send too much ETH anyway.
        uint256 remainingValue = msg.value;

        for (uint256 i = 0; i < length; i = uncheckedInc(i)) {
            // Ensure that the attester/revoker doesn't try to spend more than available.
            uint256 value = values[i];
            if (value > remainingValue) {
                revert InsufficientValue();
            }

            // Forward the revocation to the underlying resolver and return false in case it isn't approved.
            if (!onRevoke(attestations[i], value)) {
                return false;
            }

            unchecked {
                // Subtract the ETH amount, that was provided to this attestation, from the global remaining ETH amount.
                remainingValue -= value;
            }
        }

        return true;
    }

    /// @notice A resolver callback that should be implemented by child contracts.
    /// @param attestation The new attestation.
    /// @param value An explicit ETH amount that was sent to the resolver. Please note that this value is verified in
    ///     both attest() and multiAttest() callbacks EAS-only callbacks and that in case of multi attestations, it'll
    ///     usually hold that msg.value != value, since msg.value aggregated the sent ETH amounts for all the
    ///     attestations in the batch.
    /// @return Whether the attestation is valid.
    function onAttest(Attestation calldata attestation, uint256 value) internal virtual returns (bool);

    /// @notice Processes an attestation revocation and verifies if it can be revoked.
    /// @param attestation The existing attestation to be revoked.
    /// @param value An explicit ETH amount that was sent to the resolver. Please note that this value is verified in
    ///     both revoke() and multiRevoke() callbacks EAS-only callbacks and that in case of multi attestations, it'll
    ///     usually hold that msg.value != value, since msg.value aggregated the sent ETH amounts for all the
    ///     attestations in the batch.
    /// @return Whether the attestation can be revoked.
    function onRevoke(Attestation calldata attestation, uint256 value) internal virtual returns (bool);

    /// @dev Ensures that only the EAS contract can make this call.
    function _onlyEAS() private view {
        if (msg.sender != address(_eas)) {
            revert AccessDenied();
        }
    }
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.19;

import "./math/Math.sol";
import "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
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
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
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
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ISemver } from "./ISemver.sol";

/// @title Semver
/// @notice A simple contract for managing contract versions.
contract Semver is ISemver {
    // Contract's major version number.
    uint256 private immutable _major;

    // Contract's minor version number.
    uint256 private immutable _minor;

    // Contract's patch version number.
    uint256 private immutable _patch;

    /// @dev Create a new Semver instance.
    /// @param major Major version number.
    /// @param minor Minor version number.
    /// @param patch Patch version number.
    constructor(uint256 major, uint256 minor, uint256 patch) {
        _major = major;
        _minor = minor;
        _patch = patch;
    }

    /// @notice Returns the full semver contract version.
    /// @return Semver contract version as a string.
    function version() external view returns (string memory) {
        return
            string(
                abi.encodePacked(Strings.toString(_major), ".", Strings.toString(_minor), ".", Strings.toString(_patch))
            );
    }
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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.19;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v5.0._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v5.0._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v5.0._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v5.0._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v5.0._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
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
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

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
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

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

pragma solidity ^0.8.19;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
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
