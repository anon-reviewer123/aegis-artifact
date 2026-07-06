// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IDiamondCut } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondCut.sol";
import { Modifiers } from "../shared/Modifiers.sol";
import { AppStorage, LibAppStorage } from "../shared/AppStorage.sol";
import { LibGovernance } from "src/libs/LibGovernance.sol";
import { LibAdmin } from "src/libs/LibAdmin.sol";
import { LibConstants as LC } from "src/libs/LibConstants.sol";

contract GovernanceFacet is Modifiers {
    event CreateUpgrade(bytes32 id, address indexed who);
    event UpdateUpgradeExpiration(uint256 duration);
    event UpgradeCancelled(bytes32 id, address indexed who);

    /**
     * @notice Check if the diamond has been initialized.
     * @dev This will get the value from AppStorage.diamondInitialized.
     */
    function isDiamondInitialized() external view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.diamondInitialized;
    }

    /**
     * @notice Calcuate upgrade hash: `id`
     * @dev calucate the upgrade hash by hashing all the inputs
     * @param _diamondCut the array of FacetCut struct, IDiamondCut.FacetCut[] to be used for upgrade
     * @param _init address of the init diamond to be used for upgrade
     * @param _calldata bytes to be passed as call data for upgrade
     */
    function calculateUpgradeId(IDiamondCut.FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external pure returns (bytes32) {
        return LibGovernance._calculateUpgradeId(_diamondCut, _init, _calldata);
    }

    /**
     * @notice Approve the following upgrade hash: `id`
     * @dev The diamondCut() has been modified to check if the upgrade has been scheduled. This method needs to be called in order
     *      for an upgrade to be executed.
     * @param id This is the keccak256(abi.encode(cut)), where cut is the array of FacetCut struct, IDiamondCut.FacetCut[].
     */
    function createUpgrade(bytes32 id) external assertPrivilege(LibAdmin._getSystemId(), LC.GROUP_SYSTEM_ADMINS) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (s.upgradeScheduled[id] > block.timestamp) {
            revert("Upgrade has already been scheduled");
        }
        // 0 == upgrade is not scheduled / has been cancelled
        // block.timestamp + upgradeExpiration == upgrade is scheduled and expires at this time
        // Set back to 0 when an upgrade is complete
        s.upgradeScheduled[id] = block.timestamp + s.upgradeExpiration;
        emit CreateUpgrade(id, msg.sender);
    }

    /**
     * @notice Update the diamond cut upgrade expiration period.
     * @dev When createUpgrade() is called, it allows a diamondCut() upgrade to be executed. This upgrade must be executed before the
     *      upgrade expires. The upgrade expires based on when the upgrade was scheduled (when createUpgrade() was called) + AppStorage.upgradeExpiration.
     * @param duration The duration until the upgrade expires.
     */
    function updateUpgradeExpiration(uint256 duration) external assertPrivilege(LibAdmin._getSystemId(), LC.GROUP_SYSTEM_ADMINS) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(1 minutes < duration && duration < 1 weeks, "invalid upgrade expiration period");

        s.upgradeExpiration = duration;
        emit UpdateUpgradeExpiration(duration);
    }

    /**
     * @notice Cancel the following upgrade hash: `id`
     * @dev This will set the mapping AppStorage.upgradeScheduled back to 0.
     * @param id This is the keccak256(abi.encode(cut)), where cut is the array of FacetCut struct, IDiamondCut.FacetCut[].
     */
    function cancelUpgrade(bytes32 id) external assertPrivilege(LibAdmin._getSystemId(), LC.GROUP_SYSTEM_ADMINS) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(s.upgradeScheduled[id] > 0, "invalid upgrade ID");

        s.upgradeScheduled[id] = 0;

        emit UpgradeCancelled(id, msg.sender);
    }

    /**
     * @notice Get the expiry date for provided upgrade hash.
     * @dev This will get the value from AppStorage.upgradeScheduled  mapping.
     * @param id This is the keccak256(abi.encode(cut)), where cut is the array of FacetCut struct, IDiamondCut.FacetCut[].
     */
    function getUpgrade(bytes32 id) external view returns (uint256 expiry) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        expiry = s.upgradeScheduled[id];
    }

    /**
     * @notice Get the upgrade expiration period.
     * @dev This will get the value from AppStorage.upgradeExpiration. AppStorage.upgradeExpiration is added to the block.timestamp to create the upgrade expiration date.
     */
    function getUpgradeExpiration() external view returns (uint256 upgradeExpiration) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        upgradeExpiration = s.upgradeExpiration;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

interface IDiamondCut {
    enum FacetCutAction {Add, Replace, Remove}
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice modifiers

import { LibAdmin } from "../libs/LibAdmin.sol";
import { LibACL } from "../libs/LibACL.sol";
import { LibObject } from "../libs/LibObject.sol";

/**
 * @title Modifiers
 * @notice Function modifiers to control access
 * @dev Function modifiers to control access
 */
contract Modifiers {
    modifier notLocked() {
        require(!LibAdmin._isFunctionLocked(msg.sig), "function is locked");
        _;
    }

    modifier assertPrivilege(bytes32 _context, string memory _group) {
        LibACL._assertPriviledge(_context, _group);
        _;
    }

    modifier assertERC20Wrapper(bytes32 _tokenId) {
        (, , , , address erc20Wrapper) = LibObject._getObjectMeta(_tokenId);
        require(msg.sender == erc20Wrapper, "only wrapper calls allowed");
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice storage for nayms v3 decentralized insurance platform

// solhint-disable no-global-import
import "./FreeStructs.sol";

struct AppStorage {
    // Has this diamond been initialized?
    bool diamondInitialized;
    //// EIP712 domain separator ////
    uint256 initialChainId;
    bytes32 initialDomainSeparator;
    //// Reentrancy guard ////
    uint256 reentrancyStatus;
    //// NAYMS ERC20 TOKEN ////
    string name;
    mapping(address account => mapping(address spender => uint256)) allowance;
    uint256 totalSupply;
    mapping(bytes32 objectId => bool isInternalToken) internalToken;
    mapping(address account => uint256) balances;
    //// Object ////
    mapping(bytes32 objectId => bool isObject) existingObjects; // objectId => is an object?
    mapping(bytes32 objectId => bytes32 objectsParent) objectParent; // objectId => parentId
    mapping(bytes32 objectId => bytes32 objectsDataHash) objectDataHashes;
    mapping(bytes32 objectId => string tokenSymbol) objectTokenSymbol;
    mapping(bytes32 objectId => string tokenName) objectTokenName;
    mapping(bytes32 objectId => address tokenWrapperAddress) objectTokenWrapper;
    mapping(bytes32 entityId => bool isEntity) existingEntities; // entityId => is an entity?
    mapping(bytes32 policyId => bool isPolicy) existingSimplePolicies; // simplePolicyId => is a simple policy?
    //// ENTITY ////
    mapping(bytes32 entityId => Entity) entities; // objectId => Entity struct
    //// SIMPLE POLICY ////
    mapping(bytes32 policyId => SimplePolicy) simplePolicies; // objectId => SimplePolicy struct
    //// External Tokens ////
    mapping(address externalTokenAddress => bool isSupportedExternalToken) externalTokenSupported;
    address[] supportedExternalTokens;
    //// TokenizedObject ////
    mapping(bytes32 tokenId => mapping(bytes32 ownerId => uint256)) tokenBalances; // tokenId => (ownerId => balance)
    mapping(bytes32 tokenId => uint256) tokenSupply; // tokenId => Total Token Supply
    //// Dividends ////
    uint8 maxDividendDenominations;
    mapping(bytes32 objectId => bytes32[]) dividendDenominations; // object => tokenId of the dividend it allows
    mapping(bytes32 entityId => mapping(bytes32 tokenId => uint8 index)) dividendDenominationIndex; // entity ID => (token ID => index of dividend denomination)
    mapping(bytes32 entityId => mapping(uint8 index => bytes32 tokenId)) dividendDenominationAtIndex; // entity ID => (index of dividend denomination => token id)
    mapping(bytes32 tokenId => mapping(bytes32 dividendDenominationId => uint256)) totalDividends; // token ID => (denomination ID => total dividend)
    mapping(bytes32 entityId => mapping(bytes32 tokenId => mapping(bytes32 ownerId => uint256))) withdrawnDividendPerOwner; // entity => (tokenId => (owner => total withdrawn dividend)) NOT per share!!! this is TOTAL
    //// ACL Configuration////
    mapping(bytes32 roleId => mapping(bytes32 groupId => bool isRoleInGroup)) groups; //role => (group => isRoleInGroup)
    mapping(bytes32 roleId => bytes32 assignerGroupId) canAssign; //role => Group that can assign/unassign that role
    //// User Data ////
    mapping(bytes32 objectId => mapping(bytes32 contextId => bytes32 roleId)) roles; // userId => (contextId => role)
    //// MARKET ////
    uint256 lastOfferId;
    mapping(uint256 offerId => MarketInfo) offers; // offer Id => MarketInfo struct
    mapping(bytes32 sellTokenId => mapping(bytes32 buyTokenId => uint256)) bestOfferId; // sell token => buy token => best offer Id
    mapping(bytes32 sellTokenId => mapping(bytes32 buyTokenId => uint256)) span; // sell token => buy token => span
    address naymsToken; // represents the address key for this NAYMS token in AppStorage
    bytes32 naymsTokenId; // represents the bytes32 key for this NAYMS token in AppStorage
    /// Trading Commissions (all in basis points) ///
    uint16 tradingCommissionTotalBP; // note DEPRECATED // the total amount that is deducted for trading commissions (BP)
    // The total commission above is further divided as follows:
    uint16 tradingCommissionNaymsLtdBP; // note DEPRECATED
    uint16 tradingCommissionNDFBP; // note DEPRECATED
    uint16 tradingCommissionSTMBP; // note DEPRECATED
    uint16 tradingCommissionMakerBP;
    // Premium Commissions
    uint16 premiumCommissionNaymsLtdBP; // note DEPRECATED
    uint16 premiumCommissionNDFBP; // note DEPRECATED
    uint16 premiumCommissionSTMBP; // note DEPRECATED
    // A policy can pay out additional commissions on premiums to entities having a variety of roles on the policy
    mapping(bytes32 ownerId => mapping(bytes32 tokenId => uint256)) lockedBalances; // keep track of token balance that is locked, ownerId => tokenId => lockedAmount
    /// Simple two phase upgrade scheme
    mapping(bytes32 upgradeId => uint256 timestamp) upgradeScheduled; // id of the upgrade => the time that the upgrade is valid until.
    uint256 upgradeExpiration; // the period of time that an upgrade is valid until.
    uint256 sysAdmins; // counter for the number of sys admin accounts currently assigned
    mapping(address tokenWrapperAddress => bytes32 tokenId) objectTokenWrapperId; // reverse mapping token wrapper address => object ID
    mapping(string tokenSymbol => bytes32 objectId) tokenSymbolObjectId; // reverse mapping token symbol => object ID, to ensure symbol uniqueness
    mapping(bytes32 entityId => mapping(uint256 feeScheduleTypeId => FeeSchedule)) feeSchedules; // map entity ID to a fee schedule type and then to array of FeeReceivers (feeScheduleType (1-premium, 2-trading, n-others))
    mapping(bytes32 objectId => uint256 minimumSell) objectMinimumSell; // map object ID to minimum sell amount
    mapping(bytes32 objectId => uint256) depositTotal; // note: DEPRECATED: total amount deposited into contract, for rebasing tokens support
    mapping(address userAddress => EntityApproval) selfOnboarding; // note: DEPRECATED
    /// Staking
    mapping(bytes32 entityId => StakingConfig) stakingConfigs; // StakingConfig for an entity
    mapping(bytes32 vTokenId => mapping(bytes32 stakerId => uint256 balance)) stakeBalance; // [vTokenId][ownerId] balance at interval
    mapping(bytes32 vTokenId => mapping(bytes32 stakerId => uint256 boost)) stakeBoost; // [vTokenId][ownerId] boost at interval
    mapping(bytes32 entityId => mapping(bytes32 stakerId => uint64 interval)) stakeCollected; // last interval reward was collected or pain for a staker in staking entity
    mapping(bytes32 vTokenId => uint256 amount) stakingDistributionAmount; // [vTokenId] Reward at interval
    mapping(bytes32 vTokenId => bytes32 denomination) stakingDistributionDenomination; // [vTokenId] Reward currency
    mapping(bytes32 entityId => mapping(bytes32 stakerId => uint64 interval)) stakingSynced; // last interval when data was synced into storage for staker
    mapping(bytes32 vTokenId => mapping(bytes32 stakerId => uint256 balance)) stakeBalanceAdded; // raw balance staked at an interval, withouth any boost included, only for reading future intervals (to calculate the total boosted balance)
    // mapping(uint256 => bool) initComplete; // think about adding this in the future
}

/// Staking-Related Mappings

/// | Mapping Name                      | Key Structure                          | Value Type | Description                                                                                                 |
/// |-----------------------------------|----------------------------------------|------------|-------------------------------------------------------------------------------------------------------------|
/// | `stakeCollected`                  | `[Entity ID][Staker ID]`               | `uint64`   | Records the last timestamp a staker collected their stake.                                                  |
/// | `stakeCollected`                  | `[Entity ID][Entity ID]`               | `uint64`   | Records the last timestamp an entity paid out rewards.                                                      |
/// | `stakeBalance`                    | `[vTokenId][Account ID]`               | `uint256`  | Tracks staked balances for accounts across different intervals.                                             |
/// | `stakeBoost`                      | `[vTokenId][Account ID]`               | `uint256`  | Tracks boosted staked balances for accounts.                                                                |
/// | `stakeBalanceAdded`               | `[vTokenId][Staker ID]`                | `uint256`  | Raw balance staked at an interval without any boost, used for future interval calculations.                 |
/// | `stakingDistributionAmount`       | `[vTokenId]`                           | `uint256`  | Stores the reward amount for each `vTokenId` at each interval.                                              |
/// | `stakingDistributionDenomination` | `[vTokenId]`                           | `bytes32`  | Stores the reward currency (`denomination`) for each `vTokenId` at each interval.                           |
/// | `stakingSynced`                   | `[Entity ID][Staker ID]`               | `uint64`   | Records the last interval when data was synced into storage for a staker.                                   |
/// | `objectMinimumSell`               | `[Token ID][Entity ID]`                | `uint256`  | Sets minimum staking and reward amounts for tokens per entity.                                              |

struct FunctionLockedStorage {
    mapping(bytes4 => bool) locked; // function selector => is locked?
}

library LibAppStorage {
    bytes32 internal constant NAYMS_DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.nayms.storage");
    bytes32 internal constant FUNCTION_LOCK_STORAGE_POSITION = keccak256("diamond.function.lock.storage");

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = NAYMS_DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function functionLockStorage() internal pure returns (FunctionLockedStorage storage ds) {
        bytes32 position = FUNCTION_LOCK_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IDiamondCut } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondCut.sol";

/// @notice Contains internal methods for upgrade functionality
library LibGovernance {
    function _calculateUpgradeId(IDiamondCut.FacetCut[] memory _diamondCut, address _init, bytes memory _calldata) internal pure returns (bytes32) {
        return keccak256(abi.encode(_diamondCut, _init, _calldata));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { AppStorage, FunctionLockedStorage, LibAppStorage } from "../shared/AppStorage.sol";
import { Entity, OnboardingApproval } from "../shared/FreeStructs.sol";
import { LibConstants as LC } from "./LibConstants.sol";
import { LibHelpers } from "./LibHelpers.sol";
import { LibObject } from "./LibObject.sol";
import { LibERC20 } from "./LibERC20.sol";
import { LibEntity } from "./LibEntity.sol";
import { LibACL } from "./LibACL.sol";
import { LibEIP712 } from "./LibEIP712.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// prettier-ignore
import {
    CannotSupportExternalTokenWithMoreThan18Decimals,
    ObjectTokenSymbolAlreadyInUse,
    MinimumSellCannotBeZero,
    EntityOnboardingNotApproved,
    InvalidSelfOnboardRoleApproval,
    InvalidSignatureError,
    InvalidSignatureSError,
    InvalidSignatureLength
} from "../shared/CustomErrors.sol";

import { IDiamondProxy } from "src/generated/IDiamondProxy.sol";

library LibAdmin {
    using ECDSA for bytes32;

    event MaxDividendDenominationsUpdated(uint8 oldMax, uint8 newMax);
    event SupportedTokenAdded(address indexed tokenAddress);
    event FunctionsLocked(bytes4[] functionSelectors);
    event FunctionsUnlocked(bytes4[] functionSelectors);
    event SelfOnboardingCompleted(address indexed userAddress);

    /// @notice The minimum amount of an object (par token, external token) that can be sold on the market
    event MinimumSellUpdated(bytes32 objectId, uint256 minimumSell);

    function _getSystemId() internal pure returns (bytes32) {
        return LibHelpers._stringToBytes32(LC.SYSTEM_IDENTIFIER);
    }

    function _updateMaxDividendDenominations(uint8 _newMaxDividendDenominations) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint8 old = s.maxDividendDenominations;
        require(_newMaxDividendDenominations > old, "_updateMaxDividendDenominations: cannot reduce");
        s.maxDividendDenominations = _newMaxDividendDenominations;

        emit MaxDividendDenominationsUpdated(old, _newMaxDividendDenominations);
    }

    function _getMaxDividendDenominations() internal view returns (uint8) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.maxDividendDenominations;
    }

    function _isSupportedExternalTokenAddress(address _tokenId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.externalTokenSupported[_tokenId];
    }

    function _isSupportedExternalToken(bytes32 _tokenId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return LibHelpers._isAddress(_tokenId) && s.externalTokenSupported[LibHelpers._getAddressFromId(_tokenId)];
    }

    function _addSupportedExternalToken(address _tokenAddress, uint256 _minimumSell) internal {
        if (LibERC20.decimals(_tokenAddress) > 18) {
            revert CannotSupportExternalTokenWithMoreThan18Decimals();
        }
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(!s.externalTokenSupported[_tokenAddress], "external token already added");
        require(s.objectTokenWrapperId[_tokenAddress] == bytes32(0), "cannot add participation token wrapper as external");

        if (_minimumSell == 0) revert MinimumSellCannotBeZero();

        string memory symbol = LibERC20.symbol(_tokenAddress);
        if (s.tokenSymbolObjectId[symbol] != bytes32(0)) {
            revert ObjectTokenSymbolAlreadyInUse(LibHelpers._getIdForAddress(_tokenAddress), symbol);
        }

        s.externalTokenSupported[_tokenAddress] = true;
        bytes32 tokenId = LibHelpers._getIdForAddress(_tokenAddress);
        LibObject._createObject(tokenId, LC.OBJECT_TYPE_ADDRESS);
        s.supportedExternalTokens.push(_tokenAddress);
        s.tokenSymbolObjectId[symbol] = tokenId;
        s.objectMinimumSell[tokenId] = _minimumSell;

        emit SupportedTokenAdded(_tokenAddress);
        emit MinimumSellUpdated(tokenId, _minimumSell);
    }

    function _getSupportedExternalTokens() internal view returns (address[] memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Supported tokens cannot be removed because they may exist in the system!
        return s.supportedExternalTokens;
    }

    function _lockFunction(bytes4 functionSelector) internal {
        FunctionLockedStorage storage s = LibAppStorage.functionLockStorage();
        s.locked[functionSelector] = true;

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = functionSelector;
        emit FunctionsLocked(functionSelectors);
    }

    function _unlockFunction(bytes4 functionSelector) internal {
        FunctionLockedStorage storage s = LibAppStorage.functionLockStorage();
        s.locked[functionSelector] = false;

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = functionSelector;
        emit FunctionsUnlocked(functionSelectors);
    }

    function _isFunctionLocked(bytes4 functionSelector) internal view returns (bool) {
        FunctionLockedStorage storage s = LibAppStorage.functionLockStorage();
        return s.locked[functionSelector];
    }

    function _lockAllFundTransferFunctions() internal {
        FunctionLockedStorage storage s = LibAppStorage.functionLockStorage();
        s.locked[IDiamondProxy.startTokenSale.selector] = true;
        s.locked[IDiamondProxy.paySimpleClaim.selector] = true;
        s.locked[IDiamondProxy.paySimplePremium.selector] = true;
        s.locked[IDiamondProxy.checkAndUpdateSimplePolicyState.selector] = true;
        s.locked[IDiamondProxy.cancelOffer.selector] = true;
        s.locked[IDiamondProxy.executeLimitOffer.selector] = true;
        s.locked[IDiamondProxy.internalTransferFromEntity.selector] = true;
        s.locked[IDiamondProxy.payDividendFromEntity.selector] = true;
        s.locked[IDiamondProxy.internalBurn.selector] = true;
        s.locked[IDiamondProxy.wrapperInternalTransferFrom.selector] = true;
        s.locked[IDiamondProxy.withdrawDividend.selector] = true;
        s.locked[IDiamondProxy.withdrawAllDividends.selector] = true;
        s.locked[IDiamondProxy.externalWithdrawFromEntity.selector] = true;
        s.locked[IDiamondProxy.externalDeposit.selector] = true;
        s.locked[IDiamondProxy.stake.selector] = true;
        s.locked[IDiamondProxy.unstake.selector] = true;
        s.locked[IDiamondProxy.collectRewards.selector] = true;
        s.locked[IDiamondProxy.collectRewardsToInterval.selector] = true;
        s.locked[IDiamondProxy.payReward.selector] = true;
        s.locked[IDiamondProxy.cancelSimplePolicy.selector] = true;
        s.locked[IDiamondProxy.createSimplePolicy.selector] = true;
        s.locked[IDiamondProxy.createEntity.selector] = true;
        s.locked[IDiamondProxy.compoundRewards.selector] = true;
        s.locked[IDiamondProxy.zapStake.selector] = true;
        s.locked[IDiamondProxy.zapOrder.selector] = true;

        bytes4[] memory lockedFunctions = new bytes4[](25);
        lockedFunctions[0] = IDiamondProxy.startTokenSale.selector;
        lockedFunctions[1] = IDiamondProxy.paySimpleClaim.selector;
        lockedFunctions[2] = IDiamondProxy.paySimplePremium.selector;
        lockedFunctions[3] = IDiamondProxy.checkAndUpdateSimplePolicyState.selector;
        lockedFunctions[4] = IDiamondProxy.cancelOffer.selector;
        lockedFunctions[5] = IDiamondProxy.executeLimitOffer.selector;
        lockedFunctions[6] = IDiamondProxy.internalTransferFromEntity.selector;
        lockedFunctions[7] = IDiamondProxy.payDividendFromEntity.selector;
        lockedFunctions[8] = IDiamondProxy.internalBurn.selector;
        lockedFunctions[9] = IDiamondProxy.wrapperInternalTransferFrom.selector;
        lockedFunctions[10] = IDiamondProxy.withdrawDividend.selector;
        lockedFunctions[11] = IDiamondProxy.withdrawAllDividends.selector;
        lockedFunctions[12] = IDiamondProxy.externalWithdrawFromEntity.selector;
        lockedFunctions[13] = IDiamondProxy.externalDeposit.selector;
        lockedFunctions[14] = IDiamondProxy.stake.selector;
        lockedFunctions[15] = IDiamondProxy.unstake.selector;
        lockedFunctions[16] = IDiamondProxy.collectRewards.selector;
        lockedFunctions[17] = IDiamondProxy.payReward.selector;
        lockedFunctions[18] = IDiamondProxy.cancelSimplePolicy.selector;
        lockedFunctions[19] = IDiamondProxy.createSimplePolicy.selector;
        lockedFunctions[20] = IDiamondProxy.createEntity.selector;
        lockedFunctions[21] = IDiamondProxy.collectRewardsToInterval.selector;
        lockedFunctions[22] = IDiamondProxy.compoundRewards.selector;
        lockedFunctions[23] = IDiamondProxy.zapStake.selector;
        lockedFunctions[24] = IDiamondProxy.zapOrder.selector;

        emit FunctionsLocked(lockedFunctions);
    }

    function _unlockAllFundTransferFunctions() internal {
        FunctionLockedStorage storage s = LibAppStorage.functionLockStorage();
        s.locked[IDiamondProxy.startTokenSale.selector] = false;
        s.locked[IDiamondProxy.paySimpleClaim.selector] = false;
        s.locked[IDiamondProxy.paySimplePremium.selector] = false;
        s.locked[IDiamondProxy.checkAndUpdateSimplePolicyState.selector] = false;
        s.locked[IDiamondProxy.cancelOffer.selector] = false;
        s.locked[IDiamondProxy.executeLimitOffer.selector] = false;
        s.locked[IDiamondProxy.internalTransferFromEntity.selector] = false;
        s.locked[IDiamondProxy.payDividendFromEntity.selector] = false;
        s.locked[IDiamondProxy.internalBurn.selector] = false;
        s.locked[IDiamondProxy.wrapperInternalTransferFrom.selector] = false;
        s.locked[IDiamondProxy.withdrawDividend.selector] = false;
        s.locked[IDiamondProxy.withdrawAllDividends.selector] = false;
        s.locked[IDiamondProxy.externalWithdrawFromEntity.selector] = false;
        s.locked[IDiamondProxy.externalDeposit.selector] = false;
        s.locked[IDiamondProxy.stake.selector] = false;
        s.locked[IDiamondProxy.unstake.selector] = false;
        s.locked[IDiamondProxy.collectRewards.selector] = false;
        s.locked[IDiamondProxy.payReward.selector] = false;
        s.locked[IDiamondProxy.cancelSimplePolicy.selector] = false;
        s.locked[IDiamondProxy.createSimplePolicy.selector] = false;
        s.locked[IDiamondProxy.createEntity.selector] = false;
        s.locked[IDiamondProxy.collectRewardsToInterval.selector] = false;
        s.locked[IDiamondProxy.compoundRewards.selector] = false;
        s.locked[IDiamondProxy.zapStake.selector] = false;
        s.locked[IDiamondProxy.zapOrder.selector] = false;

        bytes4[] memory lockedFunctions = new bytes4[](25);
        lockedFunctions[0] = IDiamondProxy.startTokenSale.selector;
        lockedFunctions[1] = IDiamondProxy.paySimpleClaim.selector;
        lockedFunctions[2] = IDiamondProxy.paySimplePremium.selector;
        lockedFunctions[3] = IDiamondProxy.checkAndUpdateSimplePolicyState.selector;
        lockedFunctions[4] = IDiamondProxy.cancelOffer.selector;
        lockedFunctions[5] = IDiamondProxy.executeLimitOffer.selector;
        lockedFunctions[6] = IDiamondProxy.internalTransferFromEntity.selector;
        lockedFunctions[7] = IDiamondProxy.payDividendFromEntity.selector;
        lockedFunctions[8] = IDiamondProxy.internalBurn.selector;
        lockedFunctions[9] = IDiamondProxy.wrapperInternalTransferFrom.selector;
        lockedFunctions[10] = IDiamondProxy.withdrawDividend.selector;
        lockedFunctions[11] = IDiamondProxy.withdrawAllDividends.selector;
        lockedFunctions[12] = IDiamondProxy.externalWithdrawFromEntity.selector;
        lockedFunctions[13] = IDiamondProxy.externalDeposit.selector;
        lockedFunctions[14] = IDiamondProxy.stake.selector;
        lockedFunctions[15] = IDiamondProxy.unstake.selector;
        lockedFunctions[16] = IDiamondProxy.collectRewards.selector;
        lockedFunctions[17] = IDiamondProxy.payReward.selector;
        lockedFunctions[18] = IDiamondProxy.cancelSimplePolicy.selector;
        lockedFunctions[19] = IDiamondProxy.createSimplePolicy.selector;
        lockedFunctions[20] = IDiamondProxy.createEntity.selector;
        lockedFunctions[21] = IDiamondProxy.collectRewardsToInterval.selector;
        lockedFunctions[22] = IDiamondProxy.compoundRewards.selector;
        lockedFunctions[23] = IDiamondProxy.zapStake.selector;
        lockedFunctions[24] = IDiamondProxy.zapOrder.selector;

        emit FunctionsUnlocked(lockedFunctions);
    }

    function _onboardUserViaSignature(OnboardingApproval memory _approval) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address userAddress = msg.sender;

        bytes32 entityId = _approval.entityId;
        bytes32 roleId = _approval.roleId;
        bytes memory sig = _approval.signature;

        if (entityId == 0 || roleId == 0 || sig.length == 0) revert EntityOnboardingNotApproved(userAddress);

        bool isTokenHolder = roleId == LibHelpers._stringToBytes32(LC.ROLE_ENTITY_TOKEN_HOLDER);
        bool isCapitalProvider = roleId == LibHelpers._stringToBytes32(LC.ROLE_ENTITY_CP);
        if (!isTokenHolder && !isCapitalProvider) {
            revert InvalidSelfOnboardRoleApproval(roleId);
        }

        bytes32 signingHash = _getOnboardingHash(userAddress, entityId, roleId);
        bytes32 signerId = LibHelpers._getIdForAddress(_getSigner(signingHash, sig));

        if (!LibACL._isInGroup(signerId, LibAdmin._getSystemId(), LibHelpers._stringToBytes32(LC.GROUP_ONBOARDING_APPROVERS))) {
            revert EntityOnboardingNotApproved(userAddress);
        }

        if (!s.existingEntities[entityId]) {
            Entity memory entity;
            bytes32 userId = LibHelpers._getIdForAddress(userAddress);
            LibEntity._createEntity(entityId, userId, entity, 0);
        }

        if (s.roles[entityId][LibAdmin._getSystemId()] != 0) {
            LibACL._unassignRole(entityId, LibAdmin._getSystemId());
        }
        LibACL._assignRole(entityId, LibAdmin._getSystemId(), roleId);

        emit SelfOnboardingCompleted(userAddress);
    }

    function _setMinimumSell(bytes32 _objectId, uint256 _minimumSell) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (_minimumSell == 0) revert MinimumSellCannotBeZero();

        s.objectMinimumSell[_objectId] = _minimumSell;

        emit MinimumSellUpdated(_objectId, _minimumSell);
    }

    function _getOnboardingHash(address _userAddress, bytes32 _entityId, bytes32 _roleId) internal view returns (bytes32) {
        return
            LibEIP712._hashTypedDataV4(
                keccak256(abi.encode(keccak256("OnboardingApproval(address _userAddress,bytes32 _entityId,bytes32 _roleId)"), _userAddress, _entityId, _roleId))
            );
    }

    function _getSigner(bytes32 signingHash, bytes memory signature) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // ecrecover takes the signature parameters, and the only way to get them
        if (signature.length != 65) {
            revert InvalidSignatureLength();
        }

        // currently is to use assembly.
        /// @solidity memory-safe-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))

            switch v
            // if v == 0, then v = 27
            case 0 {
                v := 27
            }
            // if v == 1, then v = 28
            case 1 {
                v := 28
            }
        }

        (address signer, ECDSA.RecoverError err, ) = ECDSA.tryRecover(MessageHashUtils.toEthSignedMessageHash(signingHash), v, r, s);

        if (err == ECDSA.RecoverError.InvalidSignature) revert InvalidSignatureError(signingHash);
        else if (err == ECDSA.RecoverError.InvalidSignatureS) revert InvalidSignatureSError(s);

        return signer;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @dev Settings keys.
 */
library LibConstants {
    /// Object Types

    bytes12 internal constant OBJECT_TYPE_ADDRESS = "ADDRESS";
    bytes12 internal constant OBJECT_TYPE_ENTITY = "ENTITY";
    bytes12 internal constant OBJECT_TYPE_POLICY = "POLICY";
    bytes12 internal constant OBJECT_TYPE_FEE = "FEE";
    bytes12 internal constant OBJECT_TYPE_CLAIM = "CLAIM";
    bytes12 internal constant OBJECT_TYPE_DIVIDEND = "DIVIDEND";
    bytes12 internal constant OBJECT_TYPE_PREMIUM = "PREMIUM";
    bytes12 internal constant OBJECT_TYPE_ROLE = "ROLE";
    bytes12 internal constant OBJECT_TYPE_GROUP = "GROUP";
    bytes12 internal constant OBJECT_TYPE_STAKED = "VTOK";
    bytes12 internal constant OBJECT_TYPE_STAKING_REWARD = "SREWARD";

    /// Reserved IDs

    string internal constant EMPTY_IDENTIFIER = "";
    string internal constant SYSTEM_IDENTIFIER = "System";
    string internal constant NDF_IDENTIFIER = "NDF";
    string internal constant NLF_IDENTIFIER = "NLF";
    string internal constant STM_IDENTIFIER = "Staking Mechanism";
    string internal constant SSF_IDENTIFIER = "SSF";
    string internal constant NAYM_TOKEN_IDENTIFIER = "NAYM"; //This is the ID in the system as well as the token ID
    string internal constant DIVIDEND_BANK_IDENTIFIER = "Dividend Bank"; //This will hold all the dividends
    string internal constant NAYMS_LTD_IDENTIFIER = "Nayms Ltd";

    /// Roles

    string internal constant ROLE_SYSTEM_ADMIN = "System Admin";
    string internal constant ROLE_SYSTEM_MANAGER = "System Manager";
    string internal constant ROLE_SYSTEM_UNDERWRITER = "System Underwriter";

    string internal constant ROLE_ENTITY_ADMIN = "Entity Admin";
    string internal constant ROLE_ENTITY_MANAGER = "Entity Manager";
    string internal constant ROLE_ENTITY_BROKER = "Broker";
    string internal constant ROLE_ENTITY_INSURED = "Insured";
    string internal constant ROLE_ENTITY_CP = "Capital Provider";
    string internal constant ROLE_ENTITY_CONSULTANT = "Consultant"; // note NEW name for ROLE_SERVICE_PROVIDER
    string internal constant ROLE_ENTITY_TOKEN_HOLDER = "Token Holder";

    string internal constant ROLE_ENTITY_COMPTROLLER_COMBINED = "Comptroller Combined";
    string internal constant ROLE_ENTITY_COMPTROLLER_WITHDRAW = "Comptroller Withdraw";
    string internal constant ROLE_ENTITY_COMPTROLLER_CLAIM = "Comptroller Claim";
    string internal constant ROLE_ENTITY_COMPTROLLER_DIVIDEND = "Comptroller Dividend";

    string internal constant ROLE_ONBOARDING_APPROVER = "Onboarding Approver";

    /// old roles
    string internal constant ROLE_SPONSOR = "Sponsor";
    string internal constant ROLE_CAPITAL_PROVIDER = "Capital Provider";
    string internal constant ROLE_INSURED_PARTY = "Insured";
    string internal constant ROLE_BROKER = "Broker";
    string internal constant ROLE_SERVICE_PROVIDER = "Service Provider";
    string internal constant ROLE_UNDERWRITER = "Underwriter";
    string internal constant ROLE_CLAIMS_ADMIN = "Claims Admin";
    string internal constant ROLE_TRADER = "Trader";
    string internal constant ROLE_SEGREGATED_ACCOUNT = "Segregated Account";

    /// Groups

    string internal constant GROUP_SYSTEM_ADMINS = "System Admins";
    string internal constant GROUP_SYSTEM_MANAGERS = "System Managers";
    string internal constant GROUP_SYSTEM_UNDERWRITERS = "System Underwriters";

    string internal constant GROUP_TENANTS = "Tenants";
    string internal constant GROUP_MANAGERS = "Managers"; // a group of roles that can be assigned by both system and entity managers

    string internal constant GROUP_START_TOKEN_SALE = "Start Token Sale";
    string internal constant GROUP_EXECUTE_LIMIT_OFFER = "Execute Limit Offer";
    string internal constant GROUP_CANCEL_OFFER = "Cancel Offer";
    string internal constant GROUP_INTERNAL_TRANSFER_FROM_ENTITY = "Internal Transfer From Entity";
    string internal constant GROUP_EXTERNAL_WITHDRAW_FROM_ENTITY = "External Withdraw From Entity";
    string internal constant GROUP_EXTERNAL_DEPOSIT = "External Deposit";
    string internal constant GROUP_PAY_SIMPLE_CLAIM = "Pay Simple Claim";
    string internal constant GROUP_PAY_SIMPLE_PREMIUM = "Pay Simple Premium";
    string internal constant GROUP_PAY_DIVIDEND_FROM_ENTITY = "Pay Dividend From Entity";

    string internal constant GROUP_POLICY_HANDLERS = "Policy Handlers"; // note replaced with GROUP_PAY_SIMPLE_PREMIUM

    string internal constant GROUP_ENTITY_ADMINS = "Entity Admins";
    string internal constant GROUP_ENTITY_MANAGERS = "Entity Managers";
    string internal constant GROUP_APPROVED_USERS = "Approved Users";
    string internal constant GROUP_BROKERS = "Brokers";
    string internal constant GROUP_INSURED_PARTIES = "Insured Parties";
    string internal constant GROUP_UNDERWRITERS = "Underwriters";
    string internal constant GROUP_CAPITAL_PROVIDERS = "Capital Providers";
    string internal constant GROUP_CLAIMS_ADMINS = "Claims Admins";
    string internal constant GROUP_TRADERS = "Traders";
    string internal constant GROUP_SEGREGATED_ACCOUNTS = "Segregated Accounts";
    string internal constant GROUP_SERVICE_PROVIDERS = "Service Providers";
    string internal constant GROUP_ONBOARDING_APPROVERS = "Onboarding Approvers";
    string internal constant GROUP_TOKEN_HOLDERS = "Token Holders";

    /*///////////////////////////////////////////////////////////////////////////
                        Market and Premium Fee Schedules
    ///////////////////////////////////////////////////////////////////////////*/

    uint256 internal constant FEE_TYPE_PREMIUM = 1;
    uint256 internal constant FEE_TYPE_TRADING = 2;
    uint256 internal constant FEE_TYPE_INITIAL_SALE = 3;

    bytes32 internal constant DEFAULT_FEE_SCHEDULE = 0;

    /*///////////////////////////////////////////////////////////////////////////
                        Market Offer States
    ///////////////////////////////////////////////////////////////////////////*/

    uint256 internal constant OFFER_STATE_ACTIVE = 1;
    uint256 internal constant OFFER_STATE_CANCELLED = 2;
    uint256 internal constant OFFER_STATE_FULFILLED = 3;

    uint256 internal constant DUST = 1;
    uint256 internal constant BP_FACTOR = 10000;

    /*///////////////////////////////////////////////////////////////////////////
                        Simple Policy States
    ///////////////////////////////////////////////////////////////////////////*/

    uint256 internal constant SIMPLE_POLICY_STATE_CREATED = 0;
    uint256 internal constant SIMPLE_POLICY_STATE_APPROVED = 1;
    uint256 internal constant SIMPLE_POLICY_STATE_ACTIVE = 2;
    uint256 internal constant SIMPLE_POLICY_STATE_MATURED = 3;
    uint256 internal constant SIMPLE_POLICY_STATE_CANCELLED = 4;
    uint256 internal constant STAKING_WEEK = 7 days;
    uint256 internal constant STAKING_MINTIME = 60 days; // 60 days min lock
    uint256 internal constant STAKING_MAXTIME = 4 * 365 days; // 4 years max lock
    uint256 internal constant SCALE = 1e18; //10 ^ 18
    uint256 internal constant MAX_MATURATION_PERIOD = 3650 days; // ~ 10 years
    uint256 internal constant MAX_POLICY_COMMISSION_RECEIVERS = 10;

    /// _depositFor Types for events
    int128 internal constant STAKING_DEPOSIT_FOR_TYPE = 0;
    int128 internal constant STAKING_CREATE_LOCK_TYPE = 1;
    int128 internal constant STAKING_INCREASE_LOCK_AMOUNT = 2;
    int128 internal constant STAKING_INCREASE_UNLOCK_TIME = 3;

    /// @dev The maximum period of time the staking initDate can be from the current time.
    uint256 internal constant MAX_INIT_DATE_PERIOD = 120 days;
    uint256 internal constant MIN_STAKING_INTERVAL = 5 minutes;
    uint256 internal constant MAX_STAKING_INTERVAL = 90 days;

    uint8 internal constant INTERNAL_TOKEN_DECIMALS = 18;
    address internal constant DAI_CONSTANT = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { AppStorage, LibAppStorage } from "../shared/AppStorage.sol";
import { LibDiamond } from "lib/diamond-2-hardhat/contracts/libraries/LibDiamond.sol";
import { LibHelpers } from "./LibHelpers.sol";
import { LibAdmin } from "./LibAdmin.sol";
import { LibObject } from "./LibObject.sol";
import { LibConstants } from "./LibConstants.sol";

import { CannotUnassignRoleFromSelf, OwnerCannotBeSystemAdmin, RoleIsMissing, AssignerGroupIsMissing, InvalidGroupPrivilege } from "../shared/CustomErrors.sol";

import { LibString } from "solady/utils/LibString.sol";

library LibACL {
    using LibString for *;
    using LibHelpers for *;

    /**
     * @dev Emitted when a role gets updated. Empty roleId is assigned upon role removal
     * @param objectId The user or object that was assigned the role.
     * @param contextId The context where the role was assigned to.
     * @param assignedRoleId The ID of the role which got (un)assigned. (empty ID when unassigned)
     * @param functionName The function performing the action
     */
    event RoleUpdated(bytes32 indexed objectId, bytes32 contextId, bytes32 assignedRoleId, string functionName);
    /**
     * @dev Emitted when a role group gets updated.
     * @param role The role name.
     * @param group the group name.
     * @param roleInGroup whether the role is now in the group or not.
     */
    event RoleGroupUpdated(string role, string group, bool roleInGroup);
    /**
     * @dev Emitted when a role assigners get updated.
     * @param role The role name.
     * @param group the name of the group that can now assign this role.
     */
    event RoleCanAssignUpdated(string role, string group);

    function _assignRole(bytes32 _objectId, bytes32 _contextId, bytes32 _roleId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(_objectId != "", "invalid object ID");
        require(_contextId != "", "invalid context ID");
        require(_roleId != "", "invalid role ID");

        bytes32 oldRole = s.roles[_objectId][_contextId];
        if (_contextId == LibAdmin._getSystemId() && oldRole == LibHelpers._stringToBytes32(LibConstants.ROLE_SYSTEM_ADMIN) && oldRole != _roleId) {
            require(s.sysAdmins > 1, "must have at least one system admin");
            unchecked {
                s.sysAdmins -= 1;
            }
        }

        if (_contextId == LibAdmin._getSystemId() && _roleId == LibHelpers._stringToBytes32(LibConstants.ROLE_SYSTEM_ADMIN)) {
            if (LibHelpers._isAddress(_objectId) && LibDiamond.contractOwner() == LibHelpers._getAddressFromId(_objectId)) {
                revert OwnerCannotBeSystemAdmin();
            } else {
                unchecked {
                    s.sysAdmins += 1;
                }
            }
        }

        s.roles[_objectId][_contextId] = _roleId;

        emit RoleUpdated(_objectId, _contextId, _roleId, "_assignRole");
    }

    function _unassignRole(bytes32 _objectId, bytes32 _contextId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        bytes32 roleId = s.roles[_objectId][_contextId];
        if (_contextId == LibAdmin._getSystemId() && roleId == LibHelpers._stringToBytes32(LibConstants.ROLE_SYSTEM_ADMIN)) {
            if (msg.sender == _objectId._getAddressFromId()) revert CannotUnassignRoleFromSelf(LibConstants.ROLE_SYSTEM_ADMIN);

            require(s.sysAdmins > 1, "must have at least one system admin");
            unchecked {
                s.sysAdmins -= 1;
            }
        }

        emit RoleUpdated(_objectId, _contextId, s.roles[_objectId][_contextId], "_unassignRole");
        delete s.roles[_objectId][_contextId];
    }

    /// @dev _isInGroup no longer falls back to check the _objectId's role in the system context
    function _isInGroup(bytes32 _objectId, bytes32 _contextId, bytes32 _groupId) internal view returns (bool ret) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Check for the role in the context
        bytes32 objectRoleInContext = s.roles[_objectId][_contextId];

        if (objectRoleInContext != 0 && s.groups[objectRoleInContext][_groupId]) return true;
        return false;
    }

    function _isParentInGroup(bytes32 _objectId, bytes32 _contextId, bytes32 _groupId) internal view returns (bool) {
        bytes32 parentId = LibObject._getParent(_objectId);
        return _isInGroup(parentId, _contextId, _groupId);
    }

    /**
     * @notice Checks if assigner has the authority to assign object to a role in given context
     * @dev Any object ID can be a context, system is a special context with highest priority
     * @param _assignerId ID of an account wanting to assign a role to an object
     * @param _objectId ID of an object that is being assigned a role
     * @param _contextId ID of the context in which a role is being assigned
     * @param _roleId ID of a role being assigned
     * @return  true if allowed false otherwise
     */
    function _canAssign(bytes32 _assignerId, bytes32 _objectId, bytes32 _contextId, bytes32 _roleId) internal view returns (bool) {
        // we might impose additional restrictions on _objectId in the future
        require(_objectId != "", "invalid object ID");

        AppStorage storage s = LibAppStorage.diamondStorage();

        bytes32 assignerGroup = s.canAssign[_roleId];

        // Check for assigner's group membership in given context
        if (_isInGroup(_assignerId, _contextId, assignerGroup)) return true;
        // Otherwise, check his membership in system context
        // if account itself does not have the membership in given context, then having membership
        // in the system context grants him the privilege needed
        if (_isInGroup(_assignerId, LibAdmin._getSystemId(), assignerGroup)) return true;
        return false;
    }

    function _hasGroupPrivilege(bytes32 _userId, bytes32 _contextId, bytes32 _groupId) internal view returns (bool) {
        if (_isParentInGroup(_userId, _contextId, _groupId)) return true;
        if (_isInGroup(_userId, _contextId, _groupId)) return true;
        if (_isInGroup(_userId, LibAdmin._getSystemId(), _groupId)) return true;
        return false;
    }

    function _assertPriviledge(bytes32 _context, string memory _group) internal view {
        if (!_hasGroupPrivilege(LibHelpers._getIdForAddress(msg.sender), _context, LibHelpers._stringToBytes32(_group)))
            /// Note: If the role returned by `_getRoleInContext` is empty (represented by bytes32(0)), we explicitly return an empty string.
            /// This ensures the user doesn't receive a string that could potentially include unwanted data (like pointer and length) without any meaningful content.
            revert InvalidGroupPrivilege(
                msg.sender._getIdForAddress(),
                _context,
                (_getRoleInContext(msg.sender._getIdForAddress(), _context) == bytes32(0)) ? "" : _getRoleInContext(msg.sender._getIdForAddress(), _context).fromSmallString(),
                _group
            );
    }

    function _getRoleInContext(bytes32 _objectId, bytes32 _contextId) internal view returns (bytes32) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.roles[_objectId][_contextId];
    }

    function _isRoleInGroup(string memory role, string memory group) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.groups[LibHelpers._stringToBytes32(role)][LibHelpers._stringToBytes32(group)];
    }

    function _canGroupAssignRole(string memory role, string memory group) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.canAssign[LibHelpers._stringToBytes32(role)] == LibHelpers._stringToBytes32(group);
    }

    function _updateRoleAssigner(string memory _role, string memory _assignerGroup) internal {
        if (bytes32(bytes(_role)) == "") {
            revert RoleIsMissing();
        }
        if (bytes32(bytes(_assignerGroup)) == "") {
            revert AssignerGroupIsMissing();
        }
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.canAssign[LibHelpers._stringToBytes32(_role)] = LibHelpers._stringToBytes32(_assignerGroup);
        emit RoleCanAssignUpdated(_role, _assignerGroup);
    }

    function _updateRoleGroup(string memory _role, string memory _group, bool _roleInGroup) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (bytes32(bytes(_role)) == "") {
            revert RoleIsMissing();
        }
        if (bytes32(bytes(_group)) == "") {
            revert AssignerGroupIsMissing();
        }

        s.groups[LibHelpers._stringToBytes32(_role)][LibHelpers._stringToBytes32(_group)] = _roleInGroup;
        emit RoleGroupUpdated(_role, _group, _roleInGroup);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { AppStorage, LibAppStorage } from "../shared/AppStorage.sol";
import { LibHelpers } from "./LibHelpers.sol";
import { LibConstants as LC } from "./LibConstants.sol";
import { ObjectExistsAlready, EntityDoesNotExist, ObjectCannotBeTokenized, ObjectTokenSymbolInvalid, ObjectTokenSymbolAlreadyInUse, ObjectTokenNameInvalid, InvalidObjectType, InvalidObjectIdForAddress, MinimumSellCannotBeZero } from "../shared/CustomErrors.sol";

import { ERC20Wrapper } from "../utils/ERC20Wrapper.sol";

/// @notice Contains internal methods for core Nayms system functionality
library LibObject {
    event TokenizationEnabled(bytes32 objectId, string tokenSymbol, string tokenName);
    event TokenWrapped(bytes32 indexed entityId, address tokenWrapper);
    event TokenInfoUpdated(bytes32 indexed objectId, string symbol, string name);
    event ObjectCreated(bytes32 objectId, bytes32 parentId, bytes32 dataHash);
    event ObjectUpdated(bytes32 objectId, bytes32 parentId, bytes32 dataHash);

    function _createObject(bytes32 _objectId, bytes12 _objectType, bytes32 _parentId, bytes32 _dataHash) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        _validateObjectTypeAndNonExistance(_objectId, _objectType);

        s.existingObjects[_objectId] = true;
        s.objectParent[_objectId] = _parentId;
        s.objectDataHashes[_objectId] = _dataHash;

        emit ObjectCreated(_objectId, _parentId, _dataHash);
    }

    function _createObject(bytes32 _objectId, bytes12 _objectType, bytes32 _dataHash) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        _validateObjectTypeAndNonExistance(_objectId, _objectType);

        s.existingObjects[_objectId] = true;
        s.objectDataHashes[_objectId] = _dataHash;

        emit ObjectCreated(_objectId, 0, _dataHash);
    }

    function _createObject(bytes32 _objectId, bytes12 _objectType) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        _validateObjectTypeAndNonExistance(_objectId, _objectType);

        s.existingObjects[_objectId] = true;

        emit ObjectCreated(_objectId, 0, 0);
    }

    function _validateObjectTypeAndNonExistance(bytes32 _objectId, bytes12 _objectType) internal view {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (s.existingObjects[_objectId]) revert ObjectExistsAlready(_objectId);
        if (_objectType == LC.OBJECT_TYPE_ADDRESS && !LibHelpers._isAddress(_objectId)) revert InvalidObjectIdForAddress(_objectId);
        if (_objectType != LC.OBJECT_TYPE_ADDRESS && LibHelpers._isAddress(_objectId)) revert InvalidObjectType(_objectId, _objectType);
        if (_objectType != LC.OBJECT_TYPE_ADDRESS && !_isObjectType(_objectId, _objectType)) revert InvalidObjectType(_objectId, _objectType);
    }

    function _setDataHash(bytes32 _objectId, bytes32 _dataHash) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(s.existingObjects[_objectId], "setDataHash: object doesn't exist");
        s.objectDataHashes[_objectId] = _dataHash;

        emit ObjectUpdated(_objectId, 0, _dataHash);
    }

    function _getDataHash(bytes32 _objectId) internal view returns (bytes32 objectDataHash) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.objectDataHashes[_objectId];
    }

    function _getParent(bytes32 _objectId) internal view returns (bytes32) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.objectParent[_objectId];
    }

    function _getParentFromAddress(address addr) internal view returns (bytes32) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bytes32 objectId = LibHelpers._getIdForAddress(addr);
        return s.objectParent[objectId];
    }

    function _setParent(bytes32 _objectId, bytes32 _parentId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.objectParent[_objectId] = _parentId;

        emit ObjectUpdated(_objectId, _parentId, 0);
    }

    function _isObjectTokenizable(bytes32 _objectId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return (bytes(s.objectTokenSymbol[_objectId]).length != 0);
    }

    function _validateTokenNameAndSymbol(bytes32 _objectId, string memory _symbol, string memory _name) private view {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (bytes(_symbol).length == 0 || bytes(_symbol).length > 16) {
            revert ObjectTokenSymbolInvalid(_objectId, _symbol);
        }

        if (bytes(_name).length == 0 || bytes(_name).length > 64) {
            revert ObjectTokenNameInvalid(_objectId, _name);
        }

        if (s.tokenSymbolObjectId[_symbol] != bytes32(0)) {
            revert ObjectTokenSymbolAlreadyInUse(_objectId, _symbol);
        }
    }

    function _enableObjectTokenization(bytes32 _objectId, string memory _symbol, string memory _name, uint256 _minimumSell) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        _validateTokenNameAndSymbol(_objectId, _symbol, _name);

        if (_minimumSell == 0) revert MinimumSellCannotBeZero();

        // Ensure the entity exists before tokenizing the entity, otherwise revert.
        if (!s.existingEntities[_objectId]) {
            revert EntityDoesNotExist(_objectId);
        }

        require(!_isObjectTokenizable(_objectId), "object already tokenized");

        s.objectTokenSymbol[_objectId] = _symbol;
        s.objectTokenName[_objectId] = _name;
        s.tokenSymbolObjectId[_symbol] = _objectId;
        s.objectMinimumSell[_objectId] = _minimumSell;

        emit TokenizationEnabled(_objectId, _symbol, _name);
    }

    function _updateTokenInfo(bytes32 _objectId, string memory _symbol, string memory _name) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        _validateTokenNameAndSymbol(_objectId, _symbol, _name);

        require(_isObjectTokenizable(_objectId), "object not tokenized");

        string memory oldSymbol = s.objectTokenSymbol[_objectId];
        delete s.tokenSymbolObjectId[oldSymbol];

        s.objectTokenSymbol[_objectId] = _symbol;
        s.objectTokenName[_objectId] = _name;
        s.tokenSymbolObjectId[_symbol] = _objectId;

        emit TokenInfoUpdated(_objectId, _symbol, _name);
    }

    function _isObjectTokenWrapped(bytes32 _objectId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return (s.objectTokenWrapper[_objectId] != address(0));
    }

    function _wrapToken(bytes32 _entityId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(_isObjectTokenizable(_entityId), "must be tokenizable");
        require(!_isObjectTokenWrapped(_entityId), "must not be wrapped already");

        ERC20Wrapper tokenWrapper = new ERC20Wrapper(_entityId);
        address wrapperAddress = address(tokenWrapper);

        s.objectTokenWrapper[_entityId] = wrapperAddress;
        s.objectTokenWrapperId[wrapperAddress] = _entityId;

        emit TokenWrapped(_entityId, wrapperAddress);
    }

    function _isObject(bytes32 _id) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.existingObjects[_id];
    }

    function _setExistingObjects(bytes32[] calldata _id, bool _isExisting) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(_id.length <= 10, "too many ids");
        for (uint i = 0; i < _id.length; i++) {
            s.existingObjects[_id[i]] = _isExisting;
        }
    }

    function _getObjectType(bytes32 _objectId) internal pure returns (bytes12 objectType) {
        bytes32 shifted = _objectId >> 160;
        assembly {
            objectType := shl(160, shifted)
        }
        return objectType;
    }

    function _isObjectType(bytes32 _objectId, bytes12 _objectType) internal pure returns (bool) {
        return (_getObjectType(_objectId) == _objectType);
    }

    function _getObjectMeta(bytes32 _id) internal view returns (bytes32 parent, bytes32 dataHash, string memory tokenSymbol, string memory tokenName, address tokenWrapper) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        parent = s.objectParent[_id];
        dataHash = s.objectDataHashes[_id];
        tokenSymbol = s.objectTokenSymbol[_id];
        tokenName = s.objectTokenName[_id];
        tokenWrapper = s.objectTokenWrapper[_id];
    }

    function _objectTokenSymbol(bytes32 _objectId) internal view returns (string memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.objectTokenSymbol[_objectId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

struct MarketInfo {
    bytes32 creator; // entity ID
    bytes32 sellToken;
    uint256 sellAmount;
    uint256 sellAmountInitial;
    bytes32 buyToken;
    uint256 buyAmount;
    uint256 buyAmountInitial;
    uint256 feeSchedule;
    uint256 state;
    uint256 rankNext;
    uint256 rankPrev;
}

struct TokenAmount {
    bytes32 token;
    uint256 amount;
}

/// @dev Used in the order matching algorithm.
struct OrderMatchingCalcs {
    uint256 currentSellAmount;
    uint256 currentBuyAmount;
    uint256 normalizedBuyAmount;
    uint256 normalizedSellAmount;
}

/**
 * @param maxCapacity Maximum allowable amount of capacity that an entity is given. Denominated by assetId.
 * @param utilizedCapacity The utilized capacity of the entity. Denominated by assetId.
 */
struct Entity {
    bytes32 assetId;
    uint256 collateralRatio;
    uint256 maxCapacity;
    uint256 utilizedCapacity;
    bool simplePolicyEnabled;
}

// DEPRECATED, but don't remove, referenced in appstorage
struct EntityApproval {
    bytes32 entityId;
    bytes32 roleId;
}

/// @dev Only pass in the fields that are allowed to be updated.
/// @dev These are the variables of an entity that are allowed to be updated by the method updateEntity()
struct UpdateEntityTypeCell {
    uint256 collateralRatio;
    uint256 maxCapacity;
    bool simplePolicyEnabled;
}

struct SimplePolicy {
    uint256 startDate;
    uint256 maturationDate;
    bytes32 asset;
    uint256 limit;
    bool fundsLocked;
    bool cancelled;
    uint256 claimsPaid;
    uint256 premiumsPaid;
    bytes32[] commissionReceivers;
    uint256[] commissionBasisPoints;
}

struct SimplePolicyInfo {
    uint256 startDate;
    uint256 maturationDate;
    bytes32 asset;
    uint256 limit;
    bool fundsLocked;
    bool cancelled;
    uint256 claimsPaid;
    uint256 premiumsPaid;
}

struct Stakeholders {
    bytes32[] roles;
    bytes32[] entityIds;
    bytes[] signatures;
}

// Used in StakingFacet
struct LockedBalance {
    uint256 amount;
    uint256 endTime;
}

struct FeeSchedule {
    bytes32[] receiver;
    uint16[] basisPoints;
}

struct FeeAllocation {
    bytes32 to; // The ID of the entity that receives the fee
    uint256 fee; // The amount of fees paid to the receiver
    uint256 basisPoints; // The basis points taken from the amount transacted
}

struct CalculatedFees {
    uint256 totalFees; // total amount of fees paid
    uint256 totalBP; // total basis points of fees paid
    FeeAllocation[] feeAllocations; // The list of entities that receive a portion of the fees.
}

struct StakingConfig {
    bytes32 tokenId;
    uint256 initDate;
    uint64 a; // Amplification factor
    uint64 r;
    uint64 divider;
    uint64 interval; // Amount of time per interval in seconds
}

struct StakingState {
    uint256 balance;
    uint256 boost;
    uint64 lastCollectedInterval;
}

struct RewardsBalances {
    bytes32[] currencies;
    uint256[] amounts;
    uint64 lastPaidInterval;
}

struct PermitSignature {
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct OnboardingApproval {
    bytes32 entityId;
    bytes32 roleId;
    bytes signature;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Pure functions
library LibHelpers {
    function _getIdForAddress(address _addr) internal pure returns (bytes32) {
        return bytes32(bytes20(_addr));
    }

    function _getSenderId() internal view returns (bytes32) {
        return _getIdForAddress(msg.sender);
    }

    function _getAddressFromId(bytes32 _id) internal pure returns (address) {
        if (!_isAddress(_id)) {
            revert("Invalid address based ID");
        }
        // returns the bottom 20 bytes of the id
        return address(bytes20(_id));
    }

    function _isAddress(bytes32 _id) internal pure returns (bool) {
        return _id & 0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF == 0;
    }

    // Conversion Utilities

    /**
     * @dev Converts a string to a bytes32 representation.
     *      No length check for the input string is performed in this function, as it is only
     *      used with predefined string constants from LibConstants related to role names,
     *      role group names, and special platform identifiers.
     *      These critical string constants are verified to be 32 bytes or less off-chain
     *      before being used, and can only be set by platform admins.
     * @param strIn The input string to be converted
     * @return The bytes32 representation of the input string
     */
    function _stringToBytes32(string memory strIn) internal pure returns (bytes32) {
        return _bytesToBytes32(bytes(strIn));
    }

    function _bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
        if (source.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }

    function _bytes32ToBytes(bytes32 input) internal pure returns (bytes memory) {
        bytes memory b = new bytes(32);
        assembly {
            mstore(add(b, 32), input)
        }
        return b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/******************************************************************************\
* Author: Nick Mudge
*
/******************************************************************************/

import { IERC20 } from "../interfaces/IERC20.sol";

library LibERC20 {
    function decimals(address _token) internal view returns (uint8) {
        _assertNotEmptyContract(_token);
        IERC20 tokenContract = IERC20(_token);
        try tokenContract.decimals() returns (uint8 decimals_) {
            return decimals_;
        } catch {
            revert("LibERC20: call to decimals() failed");
        }
    }

    function symbol(address _token) internal view returns (string memory) {
        _assertNotEmptyContract(_token);
        IERC20 tokenContract = IERC20(_token);
        try tokenContract.symbol() returns (string memory symbol_) {
            return symbol_;
        } catch {
            revert("LibERC20: call to symbol() failed");
        }
    }

    function balanceOf(address _token, address _who) internal view returns (uint256) {
        _assertNotEmptyContract(_token);
        IERC20 tokenContract = IERC20(_token);
        try tokenContract.balanceOf(_who) returns (uint256 balance) {
            return balance;
        } catch {
            // Handle the error (e.g., return a default value or rethrow a custom error)
            revert("LibERC20: call to balanceOf() failed");
        }
    }

    function transferFrom(address _token, address _from, address _to, uint256 _value) internal {
        _assertNotEmptyContract(_token);
        (bool success, bytes memory result) = _token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, _from, _to, _value));
        handleReturn(success, result);
    }

    function transfer(address _token, address _to, uint256 _value) internal {
        _assertNotEmptyContract(_token);
        (bool success, bytes memory result) = _token.call(abi.encodeWithSelector(IERC20.transfer.selector, _to, _value));
        handleReturn(success, result);
    }

    function handleReturn(bool _success, bytes memory _result) internal pure {
        if (_success) {
            if (_result.length > 0) {
                require(abi.decode(_result, (bool)), "LibERC20: transfer or transferFrom returned false");
            }
        } else {
            if (_result.length > 0) {
                // bubble up any reason for revert
                // see https://github.com/OpenZeppelin/openzeppelin-contracts/blob/c239e1af8d1a1296577108dd6989a17b57434f8e/contracts/utils/Address.sol#L201
                assembly {
                    revert(add(32, _result), mload(_result))
                }
            } else {
                revert("LibERC20: transfer or transferFrom reverted");
            }
        }
    }

    function _assertNotEmptyContract(address _token) internal view {
        uint256 size;
        assembly {
            size := extcodesize(_token)
        }
        require(size > 0, "LibERC20: ERC20 token address has no code");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { LibAppStorage, AppStorage } from "../shared/AppStorage.sol";
import { Entity } from "../shared/AppStorage.sol";
import { LibConstants as LC } from "./LibConstants.sol";
import { LibAdmin } from "./LibAdmin.sol";
import { LibHelpers } from "./LibHelpers.sol";
import { LibObject } from "./LibObject.sol";
import { LibACL } from "./LibACL.sol";
import { LibTokenizedVault } from "./LibTokenizedVault.sol";
import { LibMarket } from "./LibMarket.sol";

// prettier-ignore
import { 
    EntityDoesNotExist, 
    ObjectCannotBeTokenized, 
    EntityExistsAlready, 
    UtilizedCapacityGreaterThanMaxCapacity 
} from "../shared/CustomErrors.sol";

library LibEntity {
    /**
     * @notice New entity has been created
     * @dev Emitted when entity is created
     * @param entityId Unique ID for the entity
     * @param entityAdmin Unique ID of the entity administrator
     */
    event EntityCreated(bytes32 indexed entityId, bytes32 entityAdmin);
    /**
     * @notice An entity has been updated
     * @dev Emitted when entity is updated
     * @param entityId Unique ID for the entity
     */
    event EntityUpdated(bytes32 indexed entityId);
    /**
     * @notice New token sale has been started
     * @dev Emitted when token sale is started
     * @param entityId Unique ID for the entity
     * @param offerId ID of the sale offer
     * @param tokenSymbol symbol of the token
     * @param tokenName name of the token
     */
    event TokenSaleStarted(bytes32 indexed entityId, uint256 offerId, string tokenSymbol, string tokenName);
    /**
     * @notice Collateral ratio has been updated
     * @dev Emitted when collateral ratio is updated
     * @param entityId ID of the entity
     * @param collateralRatio required collateral ratio
     * @param utilizedCapacity capacity utilization according to the new ratio
     */
    event CollateralRatioUpdated(bytes32 indexed entityId, uint256 collateralRatio, uint256 utilizedCapacity);

    /// @param _amount the amount of entity token that is minted and put on sale
    /// @param _totalPrice the buy amount
    function _startTokenSale(bytes32 _entityId, uint256 _amount, uint256 _totalPrice) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(_amount > 0, "mint amount must be > 0");
        require(_totalPrice > 0, "total price must be > 0");

        bytes32 assetId = s.entities[_entityId].assetId;
        require(_totalPrice > s.objectMinimumSell[assetId], "total price must be greater than asset minimum sell amount");

        if (!s.existingEntities[_entityId]) {
            revert EntityDoesNotExist(_entityId);
        }

        if (!LibObject._isObjectTokenizable(_entityId)) {
            revert ObjectCannotBeTokenized(_entityId);
        }

        Entity memory entity = s.entities[_entityId];

        // note: The participation tokens of the entity are minted to the entity. The participation tokens minted have the same ID as the entity.
        LibTokenizedVault._internalMint(_entityId, _entityId, _amount);

        (uint256 offerId, , ) = LibMarket._executeLimitOffer(_entityId, _entityId, _amount, entity.assetId, _totalPrice, LC.FEE_TYPE_INITIAL_SALE);

        emit TokenSaleStarted(_entityId, offerId, s.objectTokenSymbol[_entityId], s.objectTokenName[_entityId]);
    }

    function _createEntity(bytes32 _entityId, bytes32 _accountAdmin, Entity memory _entity, bytes32 _dataHash) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (s.existingEntities[_entityId]) {
            revert EntityExistsAlready(_entityId);
        }
        validateEntity(_entity);

        LibObject._createObject(_entityId, LC.OBJECT_TYPE_ENTITY, _dataHash);
        LibObject._setParent(_accountAdmin, _entityId);
        s.existingEntities[_entityId] = true;

        LibACL._assignRole(_accountAdmin, _entityId, LibHelpers._stringToBytes32(LC.ROLE_ENTITY_ADMIN));

        // An entity starts without any capacity being utilized
        require(_entity.utilizedCapacity == 0, "utilized capacity starts at 0");

        s.entities[_entityId] = _entity;

        emit EntityCreated(_entityId, _accountAdmin);
    }

    /// @dev This currently updates a non cell type entity and a cell type entity, but
    /// we should consider splitting the functionality
    function _updateEntity(bytes32 _entityId, Entity calldata _updateEntityStruct) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Cannot update a non-existing entity's metadata.
        if (!s.existingEntities[_entityId]) {
            revert EntityDoesNotExist(_entityId);
        }

        validateEntity(_updateEntityStruct);

        uint256 oldCollateralRatio = s.entities[_entityId].collateralRatio;
        uint256 oldUtilizedCapacity = s.entities[_entityId].utilizedCapacity;
        bytes32 entityAssetId = s.entities[_entityId].assetId;

        if (entityAssetId != _updateEntityStruct.assetId) {
            revert("assetId change not allowed");
        }

        // can update max capacity and simplePolicyEnabled toggle first since it's not used in collateral ratio calculation below
        s.entities[_entityId].maxCapacity = _updateEntityStruct.maxCapacity;
        s.entities[_entityId].simplePolicyEnabled = _updateEntityStruct.simplePolicyEnabled;

        // if it's a cell, and collateral ratio changed
        if (entityAssetId != 0 && _updateEntityStruct.collateralRatio != oldCollateralRatio) {
            uint256 newUtilizedCapacity = (oldUtilizedCapacity * _updateEntityStruct.collateralRatio) / oldCollateralRatio;
            uint256 newLockedBalance = s.lockedBalances[_entityId][entityAssetId] - oldUtilizedCapacity + newUtilizedCapacity;

            require(LibTokenizedVault._internalBalanceOf(_entityId, entityAssetId) >= newLockedBalance, "collateral ratio invalid, not enough balance");
            require(newUtilizedCapacity <= _updateEntityStruct.maxCapacity, "max capacity must be >= utilized capacity");

            s.entities[_entityId].collateralRatio = _updateEntityStruct.collateralRatio;
            s.entities[_entityId].utilizedCapacity = newUtilizedCapacity;
            s.lockedBalances[_entityId][entityAssetId] = newLockedBalance;

            emit CollateralRatioUpdated(_entityId, _updateEntityStruct.collateralRatio, newUtilizedCapacity);
        }

        emit EntityUpdated(_entityId);
    }

    function validateEntity(Entity memory _entity) internal view {
        // If a non cell type entity is converted into a cell type entity, then the following checks must be performed.
        if (_entity.assetId != 0) {
            // entity has an underlying asset, which means it's a cell

            // External token must be whitelisted by the platform
            require(LibAdmin._isSupportedExternalToken(_entity.assetId), "external token is not supported");

            // Collateral ratio must be in acceptable range of 1 to 10000 basis points (0.01% to 100% collateralized).
            // Cannot ever be completely uncollateralized (0 basis points), if entity is a cell.
            require(1 <= _entity.collateralRatio && _entity.collateralRatio <= LC.BP_FACTOR, "collateral ratio should be 1 to 10000");

            // Max capacity is the capital amount that an entity can write across all of their policies.
            // note: We do not directly use the value maxCapacity to determine if the entity can or cannot write a policy.
            //       First, we use the bool simplePolicyEnabled to toggle (enable / disable) whether an entity can or cannot write a policy.
            //       If an entity has this set to true, then we check if an entity has enough capacity to write a policy.
            require(!_entity.simplePolicyEnabled || (_entity.maxCapacity > 0), "max capacity should be greater than 0 for policy creation");

            if (_entity.utilizedCapacity > _entity.maxCapacity) {
                revert UtilizedCapacityGreaterThanMaxCapacity(_entity.utilizedCapacity, _entity.maxCapacity);
            }
        } else {
            // non-cell entity
            require(_entity.collateralRatio == 0, "only cell has collateral ratio");
            require(!_entity.simplePolicyEnabled, "only cell can issue policies");
            require(_entity.maxCapacity == 0, "only cells have max capacity");
        }
    }

    function _getEntityInfo(bytes32 _entityId) internal view returns (Entity memory entity) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        entity = s.entities[_entityId];
    }

    function _isEntity(bytes32 _entityId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.existingEntities[_entityId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { AppStorage, LibAppStorage } from "../shared/AppStorage.sol";

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

library LibEIP712 {
    function _domainSeparatorV4() internal view returns (bytes32) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return block.chainid == s.initialChainId ? s.initialDomainSeparator : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view returns (bytes32) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(s.name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.20;

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
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/MessageHashUtils.sol)

pragma solidity ^0.8.20;

import {Strings} from "../Strings.sol";

/**
 * @dev Signature message hash utilities for producing digests to be consumed by {ECDSA} recovery or signing.
 *
 * The library provides methods for generating a hash of a message that conforms to the
 * https://eips.ethereum.org/EIPS/eip-191[EIP 191] and https://eips.ethereum.org/EIPS/eip-712[EIP 712]
 * specifications.
 */
library MessageHashUtils {
    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing a bytes32 `messageHash` with
     * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
     * keccak256, although any bytes32 value can be safely used because the final digest will
     * be re-hashed.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing an arbitrary `message` with
     * `"\x19Ethereum Signed Message:\n" + len(message)` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32) {
        return
            keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x00` (data with intended validator).
     *
     * The digest is calculated by prefixing an arbitrary `data` with `"\x19\x00"` and the intended
     * `validator` address. Then hashing the result.
     *
     * See {ECDSA-recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data (EIP-191 version `0x01`).
     *
     * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
     * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
     *
     * See {ECDSA-recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @dev The Nayms Diamond (proxy contract) owner (address) must be mutually exclusive with the system admin role.
error OwnerCannotBeSystemAdmin();

/// @dev Passing in a missing role when trying to assign a role.
error RoleIsMissing();

/// @dev Passing in a missing group when trying to assign a role to a group.
error AssignerGroupIsMissing();

/// @dev Role assigner (msg.sender) must be in the assigners group to unassign a role.
/// @param assigner Id of the role assigner, LibHelpers._getIdForAddress(msg sender)
/// @param assignee ObjectId that the role is being assigned to
/// @param context Context that the role is being assigned in
/// @param roleInContext Role that is being assigned
error AssignerCannotUnassignRole(bytes32 assigner, bytes32 assignee, bytes32 context, string roleInContext);

/// @notice Error message for when a sender is not authorized to perform an action with their assigned role in a given context of a group
/// @dev In the assertPrivilege modifier, this error message returns the context and the role in the context, not the user's role in the system context.
/// @param msgSenderId Id of the sender
/// @param context Context in which the sender is trying to perform an action
/// @param roleInContext Role of the sender in the context
/// @param group Group to check the sender's role in
error InvalidGroupPrivilege(bytes32 msgSenderId, bytes32 context, string roleInContext, string group);

/// @notice only Token Holder or Capital Provider should be approved for self-onboarding
/// @param role The name of the rle which should not be approaved for self-onboarding
error InvalidSelfOnboardRoleApproval(bytes32 role);

/// @dev Cannot add a ERC20 token to the supported external token list that has more than 18 decimal places.
error CannotSupportExternalTokenWithMoreThan18Decimals();

/// @dev Object exsists when it should not.
error ObjectExistsAlready(bytes32 objectId);

/// @dev Object does not exsit when it should.
error ObjectDoesNotExist(bytes32 objectId);

/// @dev The entity does not exist when it should.
error EntityDoesNotExist(bytes32 objectId);

/// @dev The entity self onboarding not approved
error EntityOnboardingNotApproved(address userAddress);

/// @dev Cannot create an entity that already exists.
error EntityExistsAlready(bytes32 entityId);

/// @dev The object type is not supported in this function call.
error InvalidObjectType(bytes32 objectId, bytes12 objectType);

/// @dev The object ID being passed in is expected to be an address type, but the bottom (least significant) 12 bytes are not empty.
error InvalidObjectIdForAddress(bytes32 objectId);

/// @dev (non specific) the object is not enabled to be tokenized.
error ObjectCannotBeTokenized(bytes32 objectId);

/// @dev Provided token symbol is not valid.
error ObjectTokenSymbolInvalid(bytes32 objectId, string symbol);

/// @dev Provided token symbol is already being used.
error ObjectTokenSymbolAlreadyInUse(bytes32 objectId, string symbol);

/// @dev Provided token name is not valid.
error ObjectTokenNameInvalid(bytes32 objectId, string symbol);

/// @dev Passing in 0 amount for deposits is not allowed.
error ExternalDepositAmountCannotBeZero();

/// @dev Passing in 0 amount for withdraws is not allowed.
error ExternalWithdrawAmountCannotBeZero();

/// @dev The receiver of the withdraw must haveGroupPriviledge with the roles entity admin, comptroller combined, or comptroller withdraw.
error ExternalWithdrawInvalidReceiver(address receiver);

/// @dev Cannot create a simple policy with policyId of 0
error PolicyIdCannotBeZero();

/// @dev Policy commissions among commission receivers cannot sum to be greater than 10_000 basis points.
error PolicyCommissionsBasisPointsCannotBeGreaterThan10000(uint256 calculatedTotalBp);

/// @dev The total basis points for a fee schedule, policy fee receivers at policy creation, or maker bp cannot be greater than half of LibConstants.BP_FACTOR.
///     This is to prevent the total basis points of a fee schedule with additional fee receivers (policy fee receivers for fee payments on premiums) from being greater than 100%.
error FeeBasisPointsExceedHalfMax(uint256 actual, uint256 expected);

/// @dev The total fees can never exceed the premium payment or the marketplace trade.
error FeeBasisPointsExceedMax(uint256 actual, uint256 expected);

/// @dev When validating an entity, the utilized capacity cannot be greater than the max capacity.
error UtilizedCapacityGreaterThanMaxCapacity(uint256 utilizedCapacity, uint256 maxCapacity);

/// @dev Policy stakeholder signature validation failed
error SimplePolicyStakeholderSignatureInvalid(bytes32 signingHash, bytes signature, bytes32 signerId, bytes32 signersParent, bytes32 entityId);

/// @dev When creating a simple policy, the total claims paid should start at 0.
error SimplePolicyClaimsPaidShouldStartAtZero();

/// @dev When creating a simple policy, the total premiums paid should start at 0.
error SimplePolicyPremiumsPaidShouldStartAtZero();

/// @dev The cancel bool should not be set to true when creating a new simple policy.
error CancelCannotBeTrueWhenCreatingSimplePolicy();

/// @dev (non specific) The policyId must exist.
error PolicyDoesNotExist(bytes32 policyId);

/// @dev It is not possible to cancel policyId after maturation date has passed
error PolicyCannotCancelAfterMaturation(bytes32 policyId);

/// @dev There is a duplicate address in the list of signers (the previous signer in the list is not < the next signer in the list).
error DuplicateSignerCreatingSimplePolicy(address previousSigner, address nextSigner);

/// @dev The minimum sell amount on the marketplace cannot be zero.
error MinimumSellCannotBeZero();

/// @dev Rebasing interest tracking data has not been initialized yet.
error RebasingInterestNotInitialized(bytes32 tokenId);

/// @dev Insufficient amount of interest acrrued so far
error RebasingInterestInsufficient(bytes32 tokenId, uint256 amount, uint256 accruedAmount);

/// @dev Staking can be initialized only once
error StakingAlreadyStarted(bytes32 entityId, bytes32 tokenId);

/// @dev Staking must be started
error StakingNotStarted(bytes32 entityId, bytes32 tokenId);

/// @dev Staking must be enabled
error StakingConfigDoesNotExist(bytes32 entityId);

/// @dev Invalid A parameter value provided
error InvalidAValue();

/// @dev Invalid R parameter value provided
error InvalidRValue();

/// @dev Invalid divider parameter value provided
error InvalidDividerValue();

/// @dev Invalid interval value provided
error InvalidIntervalSecondsValue();

/// @dev Invalid staking start date provided
error InvalidStakingInitDate();

/// @dev staking entity itself should not be allowed to stake
error InvalidStaker(bytes32 entityId);

/// @dev Only one reward payment is allowed per interval
error IntervalRewardPayedOutAlready(uint64 interval);

/// @dev Token reward must be greater than minimum sell amount for the reward token
error InvalidTokenRewardAmount(bytes32 guid, bytes32 entityId, bytes32 rewardTokenId, uint256 rewardAmount);

/// @dev Insuficient balance available to perform the transfer of funds
error InsufficientBalance(bytes32 tokenId, bytes32 from, uint256 balance, uint256 amount);

/// @dev Cannot unassign the role from the sender
error CannotUnassignRoleFromSelf(string role);

/// @dev The account of rebasing tokens held by Nayms is greater than the account of rebasing tokens held by the rebasing contract
error RebasingSupplyDecreased(bytes32 tokenId, uint256 accountInNayms, uint256 accountInRebasingContract);

/// @dev This error is used to indicate that the signature could not be verified.
/// @param hash The hash of the message that was signed.
/// @notice This error suggests that the signature itself is malformed or does not correspond to the hash provided.
error InvalidSignatureError(bytes32 hash);

/// @dev This error indicates that the signatures is not 65 bytes.
/// @notice This error indicates invalid signature length.
error InvalidSignatureLength();

/// @dev This error is used to indicate that the signature has an invalid 's' value.
/// @param sValue The 's' value of the ECDSA signature that was deemed invalid.
/// @notice This error is triggered when the 's' value of the signature is not within the lower half of the secp256k1 curve's order, which can lead to malleability issues.
error InvalidSignatureSError(bytes32 sValue);

/// @dev Thrown when the number of receivers specified in a transaction is not within the acceptable range.
error InvalidReceiverCount(uint256 numberOfReceivers);

/// @dev Thrown when the maturation date of a policy is set beyond the allowable future date limit.
/// This prevents setting unrealistic maturation dates that could affect the contract's operability or the enforceability of the policy.
error MaturationDateTooFar(uint256 maturationDate);

/// @dev Thrown when the number of commission receivers for a policy exceeds the system's maximum limit.
/// This limit is enforced to prevent out-of-gas errors during commission payouts, ensuring the system remains functional and efficient.
error ExcessiveCommissionReceivers(uint256 numberOfReceivers, uint256 maxReceivers);

/// @dev Thrown when the initialization date for staking is set too far in the future, beyond the system-defined maximum limit.
error InitDateTooFar(uint256 initDate);

/// @dev Thrown when the staking interval is set outside the allowed range, either too short or too long, as defined by system limits.
error IntervalOutOfRange(uint256 interval);

/// @dev Thrown when the sum of parameters 'a' and 'r' does not equal the 'divider', which is necessary for the boost multiplier to asymptotically converge to 2.
error BoostDividerNotEqualError(uint256 a, uint256 r, uint256 divider);

/// @dev This internal token ID is invalid for the given context.
error InvalidTokenId();

/// @dev Cannot stake an amount lower than objectMinimumSell[tokenId].
error InvalidStakingAmount();

/// @dev Not a supported external ERC 20 token
/// @param tokenAddress Address of the ERC20 token
/// @param method Name of the method that threw the error
error InvalidERC20Token(address tokenAddress, string method);

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/// ------------------------------------------------------------------------------------------------------------
///
/// NOTE: This file is auto-generated by Gemforge.
///
/// ------------------------------------------------------------------------------------------------------------

import { IDiamondCut } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondLoupe.sol";
import { IERC173 } from "lib/diamond-2-hardhat/contracts/interfaces/IERC173.sol";
import { IERC165 } from "lib/diamond-2-hardhat/contracts/interfaces/IERC165.sol";
import "../shared/FreeStructs.sol";


interface IDiamondProxy is
    IERC173,
    IERC165,
    IDiamondCut,
    IDiamondLoupe
{
function assignRole(bytes32 _objectId, bytes32 _contextId, string memory _role) external;
function unassignRole(bytes32 _objectId, bytes32 _contextId) external;
function isInGroup(bytes32 _objectId, bytes32 _contextId, string memory _group) external view returns (bool);
function isParentInGroup(bytes32 _objectId, bytes32 _contextId, string memory _group) external view returns (bool);
function canAssign(bytes32 _assignerId, bytes32 _objectId, bytes32 _contextId, string memory _role) external view returns (bool);
function hasGroupPrivilege(bytes32 _userId, bytes32 _contextId, bytes32 _groupId) external view returns (bool);
function getRoleInContext(bytes32 objectId, bytes32 contextId) external view returns (bytes32);
function isRoleInGroup(string memory role, string memory group) external view returns (bool);
function canGroupAssignRole(string memory role, string memory group) external view returns (bool);
function updateRoleAssigner(string memory _role, string memory _assignerGroup) external;
function updateRoleGroup(string memory _role, string memory _group, bool _roleInGroup) external;
function setMaxDividendDenominations(uint8 _newMax) external;
function getMaxDividendDenominations() external view returns (uint8);
function isSupportedExternalToken(bytes32 _tokenId) external view returns (bool);
function addSupportedExternalToken(address _tokenAddress, uint256 _minimumSell) external;
function getSupportedExternalTokens() external view returns (address[] memory);
function getSystemId() external pure returns (bytes32);
function isObjectTokenizable(bytes32 _objectId) external view returns (bool);
function lockFunction(bytes4 functionSelector) external;
function unlockFunction(bytes4 functionSelector) external;
function isFunctionLocked(bytes4 functionSelector) external view returns (bool);
function lockAllFundTransferFunctions() external;
function unlockAllFundTransferFunctions() external;
function replaceMakerBP(uint16 _newMakerBP) external;
function addFeeSchedule(bytes32 _entityId, uint256 _feeScheduleType, bytes32[] calldata _receiver, uint16[] calldata _basisPoints) external;
function removeFeeSchedule(bytes32 _entityId, uint256 _feeScheduleType) external;
function onboardViaSignature(OnboardingApproval calldata _onboardingApproval) external;
function getOnboardingHash(address _userAddress, bytes32 _entityId, bytes32 _roleId) external view returns (bytes32);
function domainSeparatorV4() external view returns (bytes32);
function hashTypedDataV4(bytes32 structHash) external view returns (bytes32);
function enableEntityTokenization(bytes32 _objectId, string memory _symbol, string memory _name, uint256 _minimumSell) external;
function updateEntityTokenInfo(bytes32 _entityId, string memory _symbol, string memory _name) external;
function startTokenSale(bytes32 _entityId, uint256 _amount, uint256 _totalPrice) external;
function isTokenWrapped(bytes32 _entityId) external view returns (bool);
function updateEntity(bytes32 _entityId, Entity calldata _updateEntity) external;
function getEntityInfo(bytes32 _entityId) external view returns (Entity memory);
function getFeeSchedule(bytes32 _entityId, uint256 _feeScheduleType) external view returns (bytes32[] memory receiver_, uint16[] memory basisPoints_);
function getObjectTokenSymbol(bytes32 _objectId) external view returns (string memory);
function isDiamondInitialized() external view returns (bool);
function calculateUpgradeId(IDiamondCut.FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external pure returns (bytes32);
function createUpgrade(bytes32 id) external;
function updateUpgradeExpiration(uint256 duration) external;
function cancelUpgrade(bytes32 id) external;
function getUpgrade(bytes32 id) external view returns (uint256 expiry);
function getUpgradeExpiration() external view returns (uint256 upgradeExpiration);
function cancelOffer(uint256 _offerId) external;
function executeLimitOffer(bytes32 _sellToken, uint256 _sellAmount, bytes32 _buyToken, uint256 _buyAmount) external returns (uint256 offerId_, uint256 buyTokenCommissionsPaid_, uint256 sellTokenCommissionsPaid_);
function getLastOfferId() external view returns (uint256);
function getBestOfferId(bytes32 _sellToken, bytes32 _buyToken) external view returns (uint256);
function getOffer(uint256 _offerId) external view returns (MarketInfo memory _offerState);
function isActiveOffer(uint256 _offerId) external view returns (bool);
function calculateTradingFees(bytes32 _buyerId, bytes32 _sellToken, bytes32 _buyToken, uint256 _buyAmount) external view returns (uint256 totalFees_, uint256 totalBP_);
function getMakerBP() external view returns (uint16);
function objectMinimumSell(bytes32 _objectId) external view returns (uint256);
function setMinimumSell(bytes32 _objectId, uint256 _minimumSell) external;
function transferOwnership(address _newOwner) external;
function owner() external view returns (address owner_);
function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external;
function createSimplePolicy(bytes32 _policyId, bytes32 _entityId, Stakeholders calldata _stakeholders, SimplePolicy calldata _simplePolicy, bytes32 _dataHash) external;
function paySimplePremium(bytes32 _policyId, uint256 _amount) external;
function paySimpleClaim(bytes32 _claimId, bytes32 _policyId, bytes32 _insuredId, uint256 _amount) external;
function getSimplePolicyInfo(bytes32 _policyId) external view returns (SimplePolicyInfo memory);
function getPolicyCommissionReceivers(bytes32 _id) external view returns (bytes32[] memory commissionReceivers);
function checkAndUpdateSimplePolicyState(bytes32 _policyId) external;
function cancelSimplePolicy(bytes32 _policyId) external;
function getSigningHash(uint256 _startDate, uint256 _maturationDate, bytes32 _asset, uint256 _limit, bytes32 _offchainDataHash) external view returns (bytes32 signingHash_);
function calculatePremiumFees(bytes32 _policyId, uint256 _premiumPaid) external view returns (CalculatedFees memory cf);
function vTokenId(bytes32 _entityId, bytes32 _tokenId, uint64 _interval) external pure returns (bytes32);
function currentInterval(bytes32 _entityId) external view returns (uint64);
function getStakingConfig(bytes32 _entityId) external view returns (StakingConfig memory);
function initStaking(bytes32 _entityId, StakingConfig calldata _config) external;
function stake(bytes32 _entityId, uint256 _amount) external;
function unstake(bytes32 _entityId) external;
function lastCollectedInterval(bytes32 _entityId, bytes32 _stakerId) external view returns (uint64);
function lastPaidInterval(bytes32 _entityId) external view returns (uint64);
function calculateStartTimeOfInterval(bytes32 _entityId, uint64 _interval) external view returns (uint256);
function calculateStartTimeOfCurrentInterval(bytes32 _entityId) external view returns (uint256);
function getRewardsBalance(bytes32 _stakerId, bytes32 _entityId) external view returns (bytes32[] memory rewardCurrencies_, uint256[] memory rewardAmounts_);
function collectRewards(bytes32 _entityId) external;
function compoundRewards(bytes32 _entityId) external;
function collectRewardsToInterval(bytes32 _entityId, uint64 _interval) external;
function payReward(bytes32 _stakingRewardId, bytes32 _entityId, bytes32 _rewardTokenId, uint256 _amount) external;
function getStakingAmounts(bytes32 _stakerId, bytes32 _entityId) external view returns (uint256 stakedAmount_, uint256 boostedAmount_);
function createEntity(bytes32 _entityId, bytes32 _entityAdmin, Entity calldata _entityData, bytes32 _dataHash) external;
function stringToBytes32(string memory _strIn) external pure returns (bytes32 result);
function isObject(bytes32 _id) external view returns (bool);
function setExistingObjects(bytes32[] calldata _id, bool _isExisting) external;
function getObjectMeta(bytes32 _id) external view returns (bytes32 parent, bytes32 dataHash, string memory tokenSymbol, string memory tokenName, address tokenWrapper);
function wrapToken(bytes32 _objectId) external;
function getObjectType(bytes32 _objectId) external pure returns (bytes12);
function isObjectType(bytes32 _objectId, bytes12 _objectType) external pure returns (bool);
function internalBalanceOf(bytes32 ownerId, bytes32 tokenId) external view returns (uint256);
function internalTokenSupply(bytes32 tokenId) external view returns (uint256);
function internalTransferFromEntity(bytes32 to, bytes32 tokenId, uint256 amount) external;
function wrapperInternalTransferFrom(bytes32 from, bytes32 to, bytes32 tokenId, uint256 amount) external;
function internalBurn(bytes32 from, bytes32 tokenId, uint256 amount) external;
function getWithdrawableDividend(bytes32 ownerId, bytes32 tokenId, bytes32 dividendTokenId) external view returns (uint256);
function withdrawDividend(bytes32 ownerId, bytes32 tokenId, bytes32 dividendTokenId) external;
function withdrawAllDividends(bytes32 ownerId, bytes32 tokenId) external;
function payDividendFromEntity(bytes32 guid, uint256 amount) external;
function getLockedBalance(bytes32 _entityId, bytes32 _tokenId) external view returns (uint256 amount);
function getAvailableBalance(bytes32 _entityId, bytes32 _tokenId) external view returns (uint256);
function internalTransferBySystemAdmin(bytes32 _fromId, bytes32 _toId, bytes32 _tokenId, uint256 _amount) external;
function totalDividends(bytes32 _tokenId, bytes32 _dividendDenominationId) external view returns (uint256);
function accruedInterest(bytes32 _tokenId) external view returns (uint256);
function distributeAccruedInterest(bytes32 _tokenId, uint256 _amount, bytes32 _guid) external;
function externalDeposit(address _externalTokenAddress, uint256 _amount) external;
function externalWithdrawFromEntity(bytes32 _entityId, address _receiver, address _externalTokenAddress, uint256 _amount) external;
function getUserIdFromAddress(address addr) external pure returns (bytes32 userId);
function getAddressFromExternalTokenId(bytes32 _externalTokenId) external pure returns (address tokenAddress);
function setEntity(bytes32 _userId, bytes32 _entityId) external;
function getEntity(bytes32 _userId) external view returns (bytes32 entityId);
function zapStake(address _externalTokenAddress, bytes32 _stakingEntityId, uint256 _amountToDeposit, uint256 _amountToStake, PermitSignature calldata _permitSignature, OnboardingApproval calldata _onboardingApproval) external;
function zapOrder(address _externalTokenAddress, uint256 _depositAmount, bytes32 _sellToken, uint256 _sellAmount, bytes32 _buyToken, uint256 _buyAmount, PermitSignature calldata _permitSignature, OnboardingApproval calldata _onboardingApproval) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct DiamondStorage {
        // maps function selectors to the facets that execute the functions.
        // and maps the selectors to their position in the selectorSlots array.
        // func selector => address facet, selector position
        mapping(bytes4 => bytes32) facets;
        // array of slots of function selectors.
        // each slot holds 8 function selectors.
        mapping(uint256 => bytes32) selectorSlots;
        // The number of function selectors in selectorSlots
        uint16 selectorCount;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // owner of the contract
        address contractOwner;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == diamondStorage().contractOwner, "LibDiamond: Must be contract owner");
    }

    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    bytes32 constant CLEAR_ADDRESS_MASK = bytes32(uint256(0xffffffffffffffffffffffff));
    bytes32 constant CLEAR_SELECTOR_MASK = bytes32(uint256(0xffffffff << 224));

    // Internal function version of diamondCut
    // This code is almost the same as the external diamondCut,
    // except it is using 'Facet[] memory _diamondCut' instead of
    // 'Facet[] calldata _diamondCut'.
    // The code is duplicated to prevent copying calldata to memory which
    // causes an error for a two dimensional array.
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        DiamondStorage storage ds = diamondStorage();
        uint256 originalSelectorCount = ds.selectorCount;
        uint256 selectorCount = originalSelectorCount;
        bytes32 selectorSlot;
        // Check if last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8" 
        if (selectorCount & 7 > 0) {
            // get last selectorSlot
            // "selectorSlot >> 3" is a gas efficient division by 8 "selectorSlot / 8"
            selectorSlot = ds.selectorSlots[selectorCount >> 3];
        }
        // loop through diamond cut
        for (uint256 facetIndex; facetIndex < _diamondCut.length; ) {
            (selectorCount, selectorSlot) = addReplaceRemoveFacetSelectors(
                selectorCount,
                selectorSlot,
                _diamondCut[facetIndex].facetAddress,
                _diamondCut[facetIndex].action,
                _diamondCut[facetIndex].functionSelectors
            );

            unchecked {
                facetIndex++;
            }
        }
        if (selectorCount != originalSelectorCount) {
            ds.selectorCount = uint16(selectorCount);
        }
        // If last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8" 
        if (selectorCount & 7 > 0) {
            // "selectorSlot >> 3" is a gas efficient division by 8 "selectorSlot / 8"
            ds.selectorSlots[selectorCount >> 3] = selectorSlot;
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addReplaceRemoveFacetSelectors(
        uint256 _selectorCount,
        bytes32 _selectorSlot,
        address _newFacetAddress,
        IDiamondCut.FacetCutAction _action,
        bytes4[] memory _selectors
    ) internal returns (uint256, bytes32) {
        DiamondStorage storage ds = diamondStorage();
        require(_selectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        if (_action == IDiamondCut.FacetCutAction.Add) {
            enforceHasContractCode(_newFacetAddress, "LibDiamondCut: Add facet has no code");
            for (uint256 selectorIndex; selectorIndex < _selectors.length; ) {
                bytes4 selector = _selectors[selectorIndex];
                bytes32 oldFacet = ds.facets[selector];
                require(address(bytes20(oldFacet)) == address(0), "LibDiamondCut: Can't add function that already exists");
                // add facet for selector
                ds.facets[selector] = bytes20(_newFacetAddress) | bytes32(_selectorCount);
                // "_selectorCount & 7" is a gas efficient modulo by eight "_selectorCount % 8" 
                // " << 5 is the same as multiplying by 32 ( * 32)
                uint256 selectorInSlotPosition = (_selectorCount & 7) << 5;
                // clear selector position in slot and add selector
                _selectorSlot = (_selectorSlot & ~(CLEAR_SELECTOR_MASK >> selectorInSlotPosition)) | (bytes32(selector) >> selectorInSlotPosition);
                // if slot is full then write it to storage
                if (selectorInSlotPosition == 224) {
                    // "_selectorSlot >> 3" is a gas efficient division by 8 "_selectorSlot / 8"
                    ds.selectorSlots[_selectorCount >> 3] = _selectorSlot;
                    _selectorSlot = 0;
                }
                _selectorCount++;

                unchecked {
                    selectorIndex++;
                }
            }
        } else if (_action == IDiamondCut.FacetCutAction.Replace) {
            enforceHasContractCode(_newFacetAddress, "LibDiamondCut: Replace facet has no code");
            for (uint256 selectorIndex; selectorIndex < _selectors.length; ) {
                bytes4 selector = _selectors[selectorIndex];
                bytes32 oldFacet = ds.facets[selector];
                address oldFacetAddress = address(bytes20(oldFacet));
                // only useful if immutable functions exist
                require(oldFacetAddress != address(this), "LibDiamondCut: Can't replace immutable function");
                require(oldFacetAddress != _newFacetAddress, "LibDiamondCut: Can't replace function with same function");
                require(oldFacetAddress != address(0), "LibDiamondCut: Can't replace function that doesn't exist");
                // replace old facet address
                ds.facets[selector] = (oldFacet & CLEAR_ADDRESS_MASK) | bytes20(_newFacetAddress);

                unchecked {
                    selectorIndex++;
                }
            }
        } else if (_action == IDiamondCut.FacetCutAction.Remove) {
            require(_newFacetAddress == address(0), "LibDiamondCut: Remove facet address must be address(0)");
            // "_selectorCount >> 3" is a gas efficient division by 8 "_selectorCount / 8"
            uint256 selectorSlotCount = _selectorCount >> 3;
            // "_selectorCount & 7" is a gas efficient modulo by eight "_selectorCount % 8" 
            uint256 selectorInSlotIndex = _selectorCount & 7;
            for (uint256 selectorIndex; selectorIndex < _selectors.length; ) {
                if (selectorInSlotIndex == 0) {
                    // get last selectorSlot
                    selectorSlotCount--;
                    _selectorSlot = ds.selectorSlots[selectorSlotCount];
                    selectorInSlotIndex = 7;
                } else {
                    selectorInSlotIndex--;
                }
                bytes4 lastSelector;
                uint256 oldSelectorsSlotCount;
                uint256 oldSelectorInSlotPosition;
                // adding a block here prevents stack too deep error
                {
                    bytes4 selector = _selectors[selectorIndex];
                    bytes32 oldFacet = ds.facets[selector];
                    require(address(bytes20(oldFacet)) != address(0), "LibDiamondCut: Can't remove function that doesn't exist");
                    // only useful if immutable functions exist
                    require(address(bytes20(oldFacet)) != address(this), "LibDiamondCut: Can't remove immutable function");
                    // replace selector with last selector in ds.facets
                    // gets the last selector
                    // " << 5 is the same as multiplying by 32 ( * 32)
                    lastSelector = bytes4(_selectorSlot << (selectorInSlotIndex << 5));
                    if (lastSelector != selector) {
                        // update last selector slot position info
                        ds.facets[lastSelector] = (oldFacet & CLEAR_ADDRESS_MASK) | bytes20(ds.facets[lastSelector]);
                    }
                    delete ds.facets[selector];
                    uint256 oldSelectorCount = uint16(uint256(oldFacet));
                    // "oldSelectorCount >> 3" is a gas efficient division by 8 "oldSelectorCount / 8"
                    oldSelectorsSlotCount = oldSelectorCount >> 3;
                    // "oldSelectorCount & 7" is a gas efficient modulo by eight "oldSelectorCount % 8" 
                    // " << 5 is the same as multiplying by 32 ( * 32)
                    oldSelectorInSlotPosition = (oldSelectorCount & 7) << 5;
                }
                if (oldSelectorsSlotCount != selectorSlotCount) {
                    bytes32 oldSelectorSlot = ds.selectorSlots[oldSelectorsSlotCount];
                    // clears the selector we are deleting and puts the last selector in its place.
                    oldSelectorSlot =
                        (oldSelectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition)) |
                        (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                    // update storage with the modified slot
                    ds.selectorSlots[oldSelectorsSlotCount] = oldSelectorSlot;
                } else {
                    // clears the selector we are deleting and puts the last selector in its place.
                    _selectorSlot =
                        (_selectorSlot & ~(CLEAR_SELECTOR_MASK >> oldSelectorInSlotPosition)) |
                        (bytes32(lastSelector) >> oldSelectorInSlotPosition);
                }
                if (selectorInSlotIndex == 0) {
                    delete ds.selectorSlots[selectorSlotCount];
                    _selectorSlot = 0;
                }

                unchecked {
                    selectorIndex++;
                }
            }
            _selectorCount = selectorSlotCount * 8 + selectorInSlotIndex;
        } else {
            revert("LibDiamondCut: Incorrect FacetCutAction");
        }
        return (_selectorCount, _selectorSlot);
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibDiamondCut: _init address has no code");        
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for converting numbers into strings and other string operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol)
library LibString {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The `length` of the output is too small to contain all the hex digits.
    error HexLengthInsufficient();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when the `search` is not found in the string.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     DECIMAL OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(uint256 value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits.
            str := add(mload(0x40), 0x80)
            // Update the free memory pointer to allocate.
            mstore(0x40, add(str, 0x20))
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            let w := not(0) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                str := add(str, w) // `sub(str, 1)`.
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(int256 value) internal pure returns (string memory str) {
        if (value >= 0) {
            return toString(uint256(value));
        }
        unchecked {
            str = toString(uint256(-value));
        }
        /// @solidity memory-safe-assembly
        assembly {
            // We still have some spare memory space on the left,
            // as we have allocated 3 words (96 bytes) for up to 78 digits.
            let length := mload(str) // Load the string length.
            mstore(str, 0x2d) // Store the '-' character.
            str := sub(str, 1) // Move back the string pointer by a byte.
            mstore(str, add(length, 1)) // Update the string length.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   HEXADECIMAL OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `length` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `length * 2 + 2` bytes.
    /// Reverts if `length` is too small for the output to contain all the digits.
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value, length);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`,
    /// left-padded to an input length of `length` bytes.
    /// The output is prefixed with "0x" encoded using 2 hexadecimal digits per byte,
    /// giving a total length of `length * 2` bytes.
    /// Reverts if `length` is too small for the output to contain all the digits.
    function toHexStringNoPrefix(uint256 value, uint256 length)
        internal
        pure
        returns (string memory str)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // We need 0x20 bytes for the trailing zeros padding, `length * 2` bytes
            // for the digits, 0x02 bytes for the prefix, and 0x20 bytes for the length.
            // We add 0x20 to the total and round down to a multiple of 0x20.
            // (0x20 + 0x20 + 0x02 + 0x20) = 0x62.
            str := add(mload(0x40), and(add(shl(1, length), 0x42), not(0x1f)))
            // Allocate the memory.
            mstore(0x40, add(str, 0x20))
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let start := sub(str, add(length, length))
            let w := not(1) // Tsk.
            let temp := value
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for {} 1 {} {
                str := add(str, w) // `sub(str, 2)`.
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(xor(str, start)) { break }
            }

            if temp {
                // Store the function selector of `HexLengthInsufficient()`.
                mstore(0x00, 0x2194895a)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Compute the string's length.
            let strLength := sub(end, str)
            // Move the pointer and write the length.
            str := sub(str, 0x20)
            mstore(str, strLength)
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x" and encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2 + 2` bytes.
    function toHexString(uint256 value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x".
    /// The output excludes leading "0" from the `toHexString` output.
    /// `0x00: "0x0", 0x01: "0x1", 0x12: "0x12", 0x123: "0x123"`.
    function toMinimalHexString(uint256 value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let o := eq(byte(0, mload(add(str, 0x20))), 0x30) // Whether leading zero is present.
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(add(str, o), 0x3078) // Write the "0x" prefix, accounting for leading zero.
            str := sub(add(str, o), 2) // Move the pointer, accounting for leading zero.
            mstore(str, sub(strLength, o)) // Write the length, accounting for leading zero.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output excludes leading "0" from the `toHexStringNoPrefix` output.
    /// `0x00: "0", 0x01: "1", 0x12: "12", 0x123: "123"`.
    function toMinimalHexStringNoPrefix(uint256 value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let o := eq(byte(0, mload(add(str, 0x20))), 0x30) // Whether leading zero is present.
            let strLength := mload(str) // Get the length.
            str := add(str, o) // Move the pointer, accounting for leading zero.
            mstore(str, sub(strLength, o)) // Write the length, accounting for leading zero.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    /// As address are 20 bytes long, the output will left-padded to have
    /// a length of `20 * 2` bytes.
    function toHexStringNoPrefix(uint256 value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x40 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x40) is 0xa0.
            str := add(mload(0x40), 0x80)
            // Allocate the memory.
            mstore(0x40, add(str, 0x20))
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let w := not(1) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                str := add(str, w) // `sub(str, 2)`.
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(temp) { break }
            }

            // Compute the string's length.
            let strLength := sub(end, str)
            // Move the pointer and write the length.
            str := sub(str, 0x20)
            mstore(str, strLength)
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is prefixed with "0x", encoded using 2 hexadecimal digits per byte,
    /// and the alphabets are capitalized conditionally according to
    /// https://eips.ethereum.org/EIPS/eip-55
    function toHexStringChecksummed(address value) internal pure returns (string memory str) {
        str = toHexString(value);
        /// @solidity memory-safe-assembly
        assembly {
            let mask := shl(6, div(not(0), 255)) // `0b010000000100000000 ...`
            let o := add(str, 0x22)
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
    function toHexString(address value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hexadecimal representation of `value`.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(address value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            str := mload(0x40)

            // Allocate the memory.
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x28 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x28) is 0x80.
            mstore(0x40, add(str, 0x80))

            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            str := add(str, 2)
            mstore(str, 40)

            let o := add(str, 0x20)
            mstore(add(o, 40), 0)

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
    function toHexString(bytes memory raw) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(raw);
        /// @solidity memory-safe-assembly
        assembly {
            let strLength := add(mload(str), 2) // Compute the length.
            mstore(str, 0x3078) // Write the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Write the length.
        }
    }

    /// @dev Returns the hex encoded string from the raw bytes.
    /// The output is encoded using 2 hexadecimal digits per byte.
    function toHexStringNoPrefix(bytes memory raw) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            let length := mload(raw)
            str := add(mload(0x40), 2) // Skip 2 bytes for the optional prefix.
            mstore(str, add(length, length)) // Store the length of the output.

            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let o := add(str, 0x20)
            let end := add(raw, length)

            for {} iszero(eq(raw, end)) {} {
                raw := add(raw, 1)
                mstore8(add(o, 1), mload(and(mload(raw), 15)))
                mstore8(o, mload(and(shr(4, mload(raw)), 15)))
                o := add(o, 2)
            }
            mstore(o, 0) // Zeroize the slot after the string.
            mstore(0x40, add(o, 0x20)) // Allocate the memory.
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
            let mask := shl(7, div(not(0), 255))
            result := 1
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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   BYTE STRING OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // For performance and bytecode compactness, all indices of the following operations
    // are byte (ASCII) offsets, not UTF character offsets.

    /// @dev Returns `subject` all occurrences of `search` replaced with `replacement`.
    function replace(string memory subject, string memory search, string memory replacement)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)
            let replacementLength := mload(replacement)

            subject := add(subject, 0x20)
            search := add(search, 0x20)
            replacement := add(replacement, 0x20)
            result := add(mload(0x40), 0x20)

            let subjectEnd := add(subject, subjectLength)
            if iszero(gt(searchLength, subjectLength)) {
                let subjectSearchEnd := add(sub(subjectEnd, searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 0x20)) { h := keccak256(search, searchLength) }
                let m := shl(3, sub(0x20, and(searchLength, 0x1f)))
                let s := mload(search)
                for {} 1 {} {
                    let t := mload(subject)
                    // Whether the first `searchLength % 32` bytes of
                    // `subject` and `search` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                mstore(result, t)
                                result := add(result, 1)
                                subject := add(subject, 1)
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Copy the `replacement` one word at a time.
                        for { let o := 0 } 1 {} {
                            mstore(add(result, o), mload(add(replacement, o)))
                            o := add(o, 0x20)
                            if iszero(lt(o, replacementLength)) { break }
                        }
                        result := add(result, replacementLength)
                        subject := add(subject, searchLength)
                        if searchLength {
                            if iszero(lt(subject, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    mstore(result, t)
                    result := add(result, 1)
                    subject := add(subject, 1)
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
            }

            let resultRemainder := result
            result := add(mload(0x40), 0x20)
            let k := add(sub(resultRemainder, result), sub(subjectEnd, subject))
            // Copy the rest of the string one word at a time.
            for {} lt(subject, subjectEnd) {} {
                mstore(resultRemainder, mload(subject))
                resultRemainder := add(resultRemainder, 0x20)
                subject := add(subject, 0x20)
            }
            result := sub(result, 0x20)
            let last := add(add(result, 0x20), k) // Zeroize the slot after the string.
            mstore(last, 0)
            mstore(0x40, add(last, 0x20)) // Allocate the memory.
            mstore(result, k) // Store the length.
        }
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from left to right, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function indexOf(string memory subject, string memory search, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            for { let subjectLength := mload(subject) } 1 {} {
                if iszero(mload(search)) {
                    if iszero(gt(from, subjectLength)) {
                        result := from
                        break
                    }
                    result := subjectLength
                    break
                }
                let searchLength := mload(search)
                let subjectStart := add(subject, 0x20)

                result := not(0) // Initialize to `NOT_FOUND`.

                subject := add(subjectStart, from)
                let end := add(sub(add(subjectStart, subjectLength), searchLength), 1)

                let m := shl(3, sub(0x20, and(searchLength, 0x1f)))
                let s := mload(add(search, 0x20))

                if iszero(and(lt(subject, end), lt(from, subjectLength))) { break }

                if iszero(lt(searchLength, 0x20)) {
                    for { let h := keccak256(add(search, 0x20), searchLength) } 1 {} {
                        if iszero(shr(m, xor(mload(subject), s))) {
                            if eq(keccak256(subject, searchLength), h) {
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

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from left to right.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function indexOf(string memory subject, string memory search)
        internal
        pure
        returns (uint256 result)
    {
        result = indexOf(subject, search, 0);
    }

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from right to left, starting from `from`.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function lastIndexOf(string memory subject, string memory search, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            for {} 1 {} {
                result := not(0) // Initialize to `NOT_FOUND`.
                let searchLength := mload(search)
                if gt(searchLength, mload(subject)) { break }
                let w := result

                let fromMax := sub(mload(subject), searchLength)
                if iszero(gt(fromMax, from)) { from := fromMax }

                let end := add(add(subject, 0x20), w)
                subject := add(add(subject, 0x20), from)
                if iszero(gt(subject, end)) { break }
                // As this function is not too often used,
                // we shall simply use keccak256 for smaller bytecode size.
                for { let h := keccak256(add(search, 0x20), searchLength) } 1 {} {
                    if eq(keccak256(subject, searchLength), h) {
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

    /// @dev Returns the byte index of the first location of `search` in `subject`,
    /// searching from right to left.
    /// Returns `NOT_FOUND` (i.e. `type(uint256).max`) if the `search` is not found.
    function lastIndexOf(string memory subject, string memory search)
        internal
        pure
        returns (uint256 result)
    {
        result = lastIndexOf(subject, search, uint256(int256(-1)));
    }

    /// @dev Returns whether `subject` starts with `search`.
    function startsWith(string memory subject, string memory search)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let searchLength := mload(search)
            // Just using keccak256 directly is actually cheaper.
            // forgefmt: disable-next-item
            result := and(
                iszero(gt(searchLength, mload(subject))),
                eq(
                    keccak256(add(subject, 0x20), searchLength),
                    keccak256(add(search, 0x20), searchLength)
                )
            )
        }
    }

    /// @dev Returns whether `subject` ends with `search`.
    function endsWith(string memory subject, string memory search)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let searchLength := mload(search)
            let subjectLength := mload(subject)
            // Whether `search` is not longer than `subject`.
            let withinRange := iszero(gt(searchLength, subjectLength))
            // Just using keccak256 directly is actually cheaper.
            // forgefmt: disable-next-item
            result := and(
                withinRange,
                eq(
                    keccak256(
                        // `subject + 0x20 + max(subjectLength - searchLength, 0)`.
                        add(add(subject, 0x20), mul(withinRange, sub(subjectLength, searchLength))),
                        searchLength
                    ),
                    keccak256(add(search, 0x20), searchLength)
                )
            )
        }
    }

    /// @dev Returns `subject` repeated `times`.
    function repeat(string memory subject, uint256 times)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLength := mload(subject)
            if iszero(or(iszero(times), iszero(subjectLength))) {
                subject := add(subject, 0x20)
                result := mload(0x40)
                let output := add(result, 0x20)
                for {} 1 {} {
                    // Copy the `subject` one word at a time.
                    for { let o := 0 } 1 {} {
                        mstore(add(output, o), mload(add(subject, o)))
                        o := add(o, 0x20)
                        if iszero(lt(o, subjectLength)) { break }
                    }
                    output := add(output, subjectLength)
                    times := sub(times, 1)
                    if iszero(times) { break }
                }
                mstore(output, 0) // Zeroize the slot after the string.
                let resultLength := sub(output, add(result, 0x20))
                mstore(result, resultLength) // Store the length.
                // Allocate the memory.
                mstore(0x40, add(result, add(resultLength, 0x20)))
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to `end` (exclusive).
    /// `start` and `end` are byte offsets.
    function slice(string memory subject, uint256 start, uint256 end)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLength := mload(subject)
            if iszero(gt(subjectLength, end)) { end := subjectLength }
            if iszero(gt(subjectLength, start)) { start := subjectLength }
            if lt(start, end) {
                result := mload(0x40)
                let resultLength := sub(end, start)
                mstore(result, resultLength)
                subject := add(subject, start)
                let w := not(0x1f)
                // Copy the `subject` one word at a time, backwards.
                for { let o := and(add(resultLength, 0x1f), w) } 1 {} {
                    mstore(add(result, o), mload(add(subject, o)))
                    o := add(o, w) // `sub(o, 0x20)`.
                    if iszero(o) { break }
                }
                // Zeroize the slot after the string.
                mstore(add(add(result, 0x20), resultLength), 0)
                // Allocate memory for the length and the bytes,
                // rounded up to a multiple of 32.
                mstore(0x40, add(result, and(add(resultLength, 0x3f), w)))
            }
        }
    }

    /// @dev Returns a copy of `subject` sliced from `start` to the end of the string.
    /// `start` is a byte offset.
    function slice(string memory subject, uint256 start)
        internal
        pure
        returns (string memory result)
    {
        result = slice(subject, start, uint256(int256(-1)));
    }

    /// @dev Returns all the indices of `search` in `subject`.
    /// The indices are byte offsets.
    function indicesOf(string memory subject, string memory search)
        internal
        pure
        returns (uint256[] memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)

            if iszero(gt(searchLength, subjectLength)) {
                subject := add(subject, 0x20)
                search := add(search, 0x20)
                result := add(mload(0x40), 0x20)

                let subjectStart := subject
                let subjectSearchEnd := add(sub(add(subject, subjectLength), searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 0x20)) { h := keccak256(search, searchLength) }
                let m := shl(3, sub(0x20, and(searchLength, 0x1f)))
                let s := mload(search)
                for {} 1 {} {
                    let t := mload(subject)
                    // Whether the first `searchLength % 32` bytes of
                    // `subject` and `search` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                subject := add(subject, 1)
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Append to `result`.
                        mstore(result, sub(subject, subjectStart))
                        result := add(result, 0x20)
                        // Advance `subject` by `searchLength`.
                        subject := add(subject, searchLength)
                        if searchLength {
                            if iszero(lt(subject, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    subject := add(subject, 1)
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
                let resultEnd := result
                // Assign `result` to the free memory pointer.
                result := mload(0x40)
                // Store the length of `result`.
                mstore(result, shr(5, sub(resultEnd, add(result, 0x20))))
                // Allocate memory for result.
                // We allocate one more word, so this array can be recycled for {split}.
                mstore(0x40, add(resultEnd, 0x20))
            }
        }
    }

    /// @dev Returns a arrays of strings based on the `delimiter` inside of the `subject` string.
    function split(string memory subject, string memory delimiter)
        internal
        pure
        returns (string[] memory result)
    {
        uint256[] memory indices = indicesOf(subject, delimiter);
        /// @solidity memory-safe-assembly
        assembly {
            let w := not(0x1f)
            let indexPtr := add(indices, 0x20)
            let indicesEnd := add(indexPtr, shl(5, add(mload(indices), 1)))
            mstore(add(indicesEnd, w), mload(subject))
            mstore(indices, add(mload(indices), 1))
            let prevIndex := 0
            for {} 1 {} {
                let index := mload(indexPtr)
                mstore(indexPtr, 0x60)
                if iszero(eq(index, prevIndex)) {
                    let element := mload(0x40)
                    let elementLength := sub(index, prevIndex)
                    mstore(element, elementLength)
                    // Copy the `subject` one word at a time, backwards.
                    for { let o := and(add(elementLength, 0x1f), w) } 1 {} {
                        mstore(add(element, o), mload(add(add(subject, prevIndex), o)))
                        o := add(o, w) // `sub(o, 0x20)`.
                        if iszero(o) { break }
                    }
                    // Zeroize the slot after the string.
                    mstore(add(add(element, 0x20), elementLength), 0)
                    // Allocate memory for the length and the bytes,
                    // rounded up to a multiple of 32.
                    mstore(0x40, add(element, and(add(elementLength, 0x3f), w)))
                    // Store the `element` into the array.
                    mstore(indexPtr, element)
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

    /// @dev Returns a concatenated string of `a` and `b`.
    /// Cheaper than `string.concat()` and does not de-align the free memory pointer.
    function concat(string memory a, string memory b)
        internal
        pure
        returns (string memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let w := not(0x1f)
            result := mload(0x40)
            let aLength := mload(a)
            // Copy `a` one word at a time, backwards.
            for { let o := and(add(aLength, 0x20), w) } 1 {} {
                mstore(add(result, o), mload(add(a, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) { break }
            }
            let bLength := mload(b)
            let output := add(result, aLength)
            // Copy `b` one word at a time, backwards.
            for { let o := and(add(bLength, 0x20), w) } 1 {} {
                mstore(add(output, o), mload(add(b, o)))
                o := add(o, w) // `sub(o, 0x20)`.
                if iszero(o) { break }
            }
            let totalLength := add(aLength, bLength)
            let last := add(add(result, 0x20), totalLength)
            // Zeroize the slot after the string.
            mstore(last, 0)
            // Stores the length.
            mstore(result, totalLength)
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, and(add(last, 0x1f), w))
        }
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
            let length := mload(subject)
            if length {
                result := add(mload(0x40), 0x20)
                subject := add(subject, 1)
                let flags := shl(add(70, shl(5, toUpper)), 0x3ffffff)
                let w := not(0)
                for { let o := length } 1 {} {
                    o := add(o, w)
                    let b := and(0xff, mload(add(subject, o)))
                    mstore8(add(result, o), xor(b, and(shr(b, flags), 0x20)))
                    if iszero(o) { break }
                }
                result := mload(0x40)
                mstore(result, length) // Store the length.
                let last := add(add(result, 0x20), length)
                mstore(last, 0) // Zeroize the slot after the string.
                mstore(0x40, add(last, 0x20)) // Allocate the memory.
            }
        }
    }

    /// @dev Returns a string from a small bytes32 string.
    /// `smallString` must be null terminated, or behavior will be undefined.
    function fromSmallString(bytes32 smallString) internal pure returns (string memory result) {
        if (smallString == bytes32(0)) return result;
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let n := 0
            for {} 1 {} {
                n := add(n, 1)
                if iszero(byte(n, smallString)) { break } // Scan for '\0'.
            }
            mstore(result, n)
            let o := add(result, 0x20)
            mstore(o, smallString)
            mstore(add(o, n), 0)
            mstore(0x40, add(result, 0x40))
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
            let end := add(s, mload(s))
            result := add(mload(0x40), 0x20)
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
                    mstore8(result, c)
                    result := add(result, 1)
                    continue
                }
                let t := shr(248, mload(c))
                mstore(result, mload(and(t, 0x1f)))
                result := add(result, shr(5, t))
            }
            let last := result
            mstore(last, 0) // Zeroize the slot after the string.
            result := mload(0x40)
            mstore(result, sub(last, add(result, 0x20))) // Store the length.
            mstore(0x40, add(last, 0x20)) // Allocate the memory.
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
            let end := add(s, mload(s))
            result := add(mload(0x40), 0x20)
            if addDoubleQuotes {
                mstore8(result, 34)
                result := add(1, result)
            }
            // Store "\\u0000" in scratch space.
            // Store "0123456789abcdef" in scratch space.
            // Also, store `{0x08:"b", 0x09:"t", 0x0a:"n", 0x0c:"f", 0x0d:"r"}`.
            // into the scratch space.
            mstore(0x15, 0x5c75303030303031323334353637383961626364656662746e006672)
            // Bitmask for detecting `["\"","\\"]`.
            let e := or(shl(0x22, 1), shl(0x5c, 1))
            for {} iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                if iszero(lt(c, 0x20)) {
                    if iszero(and(shl(c, 1), e)) {
                        // Not in `["\"","\\"]`.
                        mstore8(result, c)
                        result := add(result, 1)
                        continue
                    }
                    mstore8(result, 0x5c) // "\\".
                    mstore8(add(result, 1), c)
                    result := add(result, 2)
                    continue
                }
                if iszero(and(shl(c, 1), 0x3700)) {
                    // Not in `["\b","\t","\n","\f","\d"]`.
                    mstore8(0x1d, mload(shr(4, c))) // Hex value.
                    mstore8(0x1e, mload(and(c, 15))) // Hex value.
                    mstore(result, mload(0x19)) // "\\u00XX".
                    result := add(result, 6)
                    continue
                }
                mstore8(result, 0x5c) // "\\".
                mstore8(add(result, 1), mload(add(c, 8)))
                result := add(result, 2)
            }
            if addDoubleQuotes {
                mstore8(result, 34)
                result := add(1, result)
            }
            let last := result
            mstore(last, 0) // Zeroize the slot after the string.
            result := mload(0x40)
            mstore(result, sub(last, add(result, 0x20))) // Store the length.
            mstore(0x40, add(last, 0x20)) // Allocate the memory.
        }
    }

    /// @dev Escapes the string to be used within double-quotes in a JSON.
    function escapeJSON(string memory s) internal pure returns (string memory result) {
        result = escapeJSON(s, false);
    }

    /// @dev Returns whether `a` equals `b`.
    function eq(string memory a, string memory b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }

    /// @dev Returns whether `a` equals `b`. For small strings up to 32 bytes.
    /// `b` must be null terminated, or behavior will be undefined.
    function eqs(string memory a, bytes32 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            // These should be evaluated on compile time, as far as possible.
            let x := and(b, add(not(b), 1))
            let r := or(shl(8, iszero(b)), shl(7, iszero(iszero(shr(128, x)))))
            r := or(r, shl(6, iszero(iszero(shr(64, shr(r, x))))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            result := gt(eq(mload(a), sub(32, shr(3, r))), shr(r, xor(b, mload(add(a, 0x20)))))
        }
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
            // Grab the free memory pointer.
            result := mload(0x40)
            // Allocate 2 words (1 for the length, 1 for the bytes).
            mstore(0x40, add(result, 0x40))
            // Zeroize the length slot.
            mstore(result, 0)
            // Store the length and bytes.
            mstore(add(result, 0x1f), packed)
            // Right pad with zeroes.
            mstore(add(add(result, 0x20), mload(result)), 0)
        }
    }

    /// @dev Packs two strings with their lengths into a single word.
    /// Returns `bytes32(0)` if combined length is zero or greater than 30.
    function packTwo(string memory a, string memory b) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let aLength := mload(a)
            // We don't need to zero right pad the strings,
            // since this is our own custom non-standard packing scheme.
            result :=
                mul(
                    // Load the length and the bytes of `a` and `b`.
                    or(
                        shl(shl(3, sub(0x1f, aLength)), mload(add(a, aLength))),
                        mload(sub(add(b, 0x1e), aLength))
                    ),
                    // `totalLength != 0 && totalLength < 31`. Abuses underflow.
                    // Assumes that the lengths are valid and within the block gas limit.
                    lt(sub(add(aLength, mload(b)), 1), 0x1e)
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
            // Grab the free memory pointer.
            resultA := mload(0x40)
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
        assembly {
            // Assumes that the string does not start from the scratch space.
            let retStart := sub(a, 0x20)
            let retSize := add(mload(a), 0x40)
            // Right pad with zeroes. Just in case the string is produced
            // by a method that doesn't zero right pad.
            mstore(add(retStart, retSize), 0)
            // Store the return offset.
            mstore(retStart, 0x20)
            // End the transaction, returning the string.
            return(retStart, retSize)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "../interfaces/IERC20.sol";
import { IDiamondProxy } from "../generated/IDiamondProxy.sol";
import { LibHelpers } from "../libs/LibHelpers.sol";
import { ReentrancyGuard } from "../utils/ReentrancyGuard.sol";

contract ERC20Wrapper is IERC20, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/
    bytes32 internal immutable tokenId;
    IDiamondProxy internal immutable nayms;
    mapping(address => mapping(address => uint256)) public allowances;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/
    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    constructor(bytes32 _tokenId) {
        // ensure only diamond can instantiate this
        nayms = IDiamondProxy(msg.sender);

        require(nayms.isObjectTokenizable(_tokenId), "must be tokenizable");
        require(!nayms.isTokenWrapped(_tokenId), "must not be wrapped already");

        tokenId = _tokenId;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    function name() external view returns (string memory) {
        (, , , string memory tokenName, ) = nayms.getObjectMeta(tokenId);
        return tokenName;
    }

    function symbol() external view returns (string memory) {
        (, , string memory tokenSymbol, , ) = nayms.getObjectMeta(tokenId);
        return tokenSymbol;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return nayms.internalTokenSupply(tokenId);
    }

    function balanceOf(address who) external view returns (uint256) {
        return nayms.internalBalanceOf(LibHelpers._getIdForAddress(who), tokenId);
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }

    function transfer(address to, uint256 value) external nonReentrant returns (bool) {
        bytes32 fromId = LibHelpers._getSenderId();
        bytes32 toId = LibHelpers._getIdForAddress(to);

        emit Transfer(msg.sender, to, value);

        nayms.wrapperInternalTransferFrom(fromId, toId, tokenId, value);

        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowances[msg.sender][spender] = value;
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        require(type(uint256).max - allowances[msg.sender][spender] >= addedValue, "ERC20: allowance overflow");
        unchecked {
            allowances[msg.sender][spender] += addedValue;
        }
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            allowances[msg.sender][spender] -= subtractedValue;
        }
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external nonReentrant returns (bool) {
        if (value == 0) {
            revert();
        }
        uint256 allowed = allowances[from][msg.sender]; // Saves gas for limited approvals.
        require(allowed >= value, "not enough allowance");

        if (allowed != type(uint256).max) allowances[from][msg.sender] = allowed - value;

        bytes32 fromId = LibHelpers._getIdForAddress(from);
        bytes32 toId = LibHelpers._getIdForAddress(to);

        emit Transfer(from, to, value);

        nayms.wrapperInternalTransferFrom(fromId, toId, tokenId, value);

        return true;
    }

    // refer to https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol#L116
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowances[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(LibHelpers._bytes32ToBytes(tokenId)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * See https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/token/ERC20
 */
interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { AppStorage, LibAppStorage } from "../shared/AppStorage.sol";
import { LibAdmin } from "./LibAdmin.sol";
import { LibConstants as LC } from "./LibConstants.sol";
import { LibHelpers } from "./LibHelpers.sol";
import { LibObject } from "./LibObject.sol";
import { LibERC20 } from "./LibERC20.sol";
import { RebasingInterestNotInitialized, RebasingInterestInsufficient, RebasingSupplyDecreased } from "../shared/CustomErrors.sol";

import { InsufficientBalance } from "../shared/CustomErrors.sol";

library LibTokenizedVault {
    /**
     * @dev Emitted when a token balance gets updated.
     * @param ownerId Id of owner
     * @param tokenId ID of token
     * @param newAmountOwned new amount owned
     * @param functionName Function name
     * @param msgSender msg.sender
     */
    event InternalTokenBalanceUpdate(bytes32 indexed ownerId, bytes32 tokenId, uint256 newAmountOwned, string functionName, address indexed msgSender);

    /**
     * @dev Emitted when a token supply gets updated.
     * @param tokenId ID of token
     * @param newTokenSupply New token supply
     * @param functionName Function name
     * @param msgSender msg.sender
     */
    event InternalTokenSupplyUpdate(bytes32 indexed tokenId, uint256 newTokenSupply, string functionName, address indexed msgSender);

    /**
     * @dev Emitted when a dividend gets paid out.
     * @param guid dividend distribution ID
     * @param from distribution initiator
     * @param to distribution receiver
     * @param amount distributed amount
     */
    event DividendDistribution(bytes32 indexed guid, bytes32 from, bytes32 to, bytes32 dividendTokenId, uint256 amount);

    /**
     * @dev Emitted when a dividend gets paid out.
     * @param accountId ID of the account withdrawing the dividend
     * @param tokenId ID of the participation token that is paying out the dividends to holders
     * @param amountOwned owned amount of the participation tokens
     * @param dividendTokenId ID of the dividend denomination token
     * @param dividendAmountWithdrawn amount withdrawn
     */
    event DividendWithdrawn(bytes32 indexed accountId, bytes32 tokenId, uint256 amountOwned, bytes32 dividendTokenId, uint256 dividendAmountWithdrawn);

    function _internalBalanceOf(bytes32 _ownerId, bytes32 _tokenId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.tokenBalances[_tokenId][_ownerId];
    }

    function _internalTokenSupply(bytes32 _objectId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.tokenSupply[_objectId];
    }

    function _internalTransfer(bytes32 _from, bytes32 _to, bytes32 _tokenId, uint256 _amount) internal returns (bool success) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (s.tokenBalances[_tokenId][_from] < _amount) revert InsufficientBalance(_tokenId, _from, s.tokenBalances[_tokenId][_from], _amount);
        require(s.tokenBalances[_tokenId][_from] - s.lockedBalances[_from][_tokenId] >= _amount, "_internalTransfer: insufficient balance available, funds locked");

        _withdrawAllDividends(_from, _tokenId);

        s.tokenBalances[_tokenId][_from] -= _amount;
        s.tokenBalances[_tokenId][_to] += _amount;

        _normalizeDividends(_from, _to, _tokenId, _amount, false);

        emit InternalTokenBalanceUpdate(_from, _tokenId, s.tokenBalances[_tokenId][_from], "_internalTransfer", msg.sender);
        emit InternalTokenBalanceUpdate(_to, _tokenId, s.tokenBalances[_tokenId][_to], "_internalTransfer", msg.sender);

        success = true;
    }

    function _internalMint(bytes32 _to, bytes32 _tokenId, uint256 _amount) internal {
        require(_to != "", "_internalMint: mint to zero address");
        require(_amount > 0, "_internalMint: mint zero tokens");

        AppStorage storage s = LibAppStorage.diamondStorage();

        _normalizeDividends(bytes32(0), _to, _tokenId, _amount, true);

        s.tokenSupply[_tokenId] += _amount;
        s.tokenBalances[_tokenId][_to] += _amount;

        emit InternalTokenSupplyUpdate(_tokenId, s.tokenSupply[_tokenId], "_internalMint", msg.sender);
        emit InternalTokenBalanceUpdate(_to, _tokenId, s.tokenBalances[_tokenId][_to], "_internalMint", msg.sender);
    }

    function _normalizeDividends(bytes32 _from, bytes32 _to, bytes32 _tokenId, uint256 _amount, bool _updateTotals) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 supply = _internalTokenSupply(_tokenId);

        // This must be done BEFORE the supply increases!!!
        // This will calculate the hypothetical dividends that would correspond to this number of shares.
        // It must be added to the withdrawn dividend for every denomination for the user who receives the minted tokens
        bytes32[] memory dividendDenominations = s.dividendDenominations[_tokenId];

        for (uint256 i = 0; i < dividendDenominations.length; ++i) {
            bytes32 dividendDenominationId = dividendDenominations[i];
            uint256 totalDividend = s.totalDividends[_tokenId][dividendDenominationId];

            // Dividend deduction for newly issued shares
            uint256 dividendDeductionIssued = _getWithdrawableDividendAndDeductionMath(_amount, supply, totalDividend, 0);

            // Scale total dividends and withdrawn dividend for new owner
            s.withdrawnDividendPerOwner[_tokenId][dividendDenominationId][_to] += dividendDeductionIssued;

            // Scale total dividends for the previous owner, if applicable
            if (_from != bytes32(0)) {
                s.withdrawnDividendPerOwner[_tokenId][dividendDenominationId][_from] -= dividendDeductionIssued;
            }

            if (_updateTotals) {
                s.totalDividends[_tokenId][dividendDenominationId] += (s.totalDividends[_tokenId][dividendDenominationId] * _amount) / supply;
            }
        }
    }

    /// @dev Recalculate totalDividends for all denominations when tokens are burned
    function _normalizeDividendsBurn(bytes32 _tokenId, uint256 _amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 supply = _internalTokenSupply(_tokenId);

        bytes32[] memory dividendDenominations = s.dividendDenominations[_tokenId];

        for (uint256 i; i < dividendDenominations.length; ++i) {
            bytes32 dividendDenominationId = dividendDenominations[i];

            // new total dividends = old total dividends * new total supply of p token / old total supply of p token
            s.totalDividends[_tokenId][dividendDenominationId] = (s.totalDividends[_tokenId][dividendDenominationId] * (supply - _amount)) / supply;
        }
    }

    function _internalBurn(bytes32 _from, bytes32 _tokenId, uint256 _amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(s.tokenBalances[_tokenId][_from] >= _amount, "_internalBurn: insufficient balance");
        require(s.tokenBalances[_tokenId][_from] - s.lockedBalances[_from][_tokenId] >= _amount, "_internalBurn: insufficient balance available, funds locked");

        _withdrawAllDividends(_from, _tokenId);
        _normalizeDividendsBurn(_tokenId, _amount);

        s.tokenSupply[_tokenId] -= _amount;
        s.tokenBalances[_tokenId][_from] -= _amount;

        emit InternalTokenSupplyUpdate(_tokenId, s.tokenSupply[_tokenId], "_internalBurn", msg.sender);
        emit InternalTokenBalanceUpdate(_from, _tokenId, s.tokenBalances[_tokenId][_from], "_internalBurn", msg.sender);
    }

    //   DIVIDEND PAYOUT LOGIC
    //
    // When a dividend is paid, you divide by the total supply and add it to the totalDividendPerToken
    // Dividends are held by the diamond contract at: LibHelpers._stringToBytes32(LibConstants.DIVIDEND_BANK_IDENTIFIER)
    // When dividends are paid, they are transferred OUT of that same diamond contract ID.
    //
    // To calculate withdrawableDividend = ownedTokens * totalDividendPerToken - totalWithdrawnDividendPerOwner
    //
    // When a dividend is collected you set the totalWithdrawnDividendPerOwner to the total amount the owner withdrew
    //
    // When you transfer, you pay out all dividends to previous owner first, then transfer ownership
    // !!!YOU ALSO TRANSFER totalWithdrawnDividendPerOwner for those shares!!!
    // totalWithdrawnDividendPerOwner(for new owner) += numberOfSharesTransferred * totalDividendPerToken
    // totalWithdrawnDividendPerOwner(for previous owner) -= numberOfSharesTransferred * totalDividendPerToken (can be optimized)
    //
    // When minting
    // Add the token balance to the new owner
    // totalWithdrawnDividendPerOwner(for new owner) += numberOfSharesMinted * totalDividendPerToken
    //
    // When doing the division these will be dust. Leave the dust in the diamond!!!
    function _withdrawDividend(bytes32 _ownerId, bytes32 _tokenId, bytes32 _dividendTokenId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bytes32 dividendBankId = LibHelpers._stringToBytes32(LC.DIVIDEND_BANK_IDENTIFIER);

        uint256 amountOwned = s.tokenBalances[_tokenId][_ownerId];
        uint256 supply = _internalTokenSupply(_tokenId);
        uint256 totalDividend = s.totalDividends[_tokenId][_dividendTokenId];
        uint256 withdrawnSoFar = s.withdrawnDividendPerOwner[_tokenId][_dividendTokenId][_ownerId];

        uint256 withdrawableDividend = _getWithdrawableDividendAndDeductionMath(amountOwned, supply, totalDividend, withdrawnSoFar);

        if (withdrawableDividend > 0) {
            // Bump the withdrawn dividends for the owner
            /// Special Case: (_tokenId == _dividendTokenId), i.e distributing accrued interest for rebasing coins like USDM
            /// withdrawnDividendPerOwner should be adjusted before the update, so that the user cannot claim additional dividend based on the amount he just received as dividend
            /// dividend is calculated based on a ratio between users balance and the total, but in this case claiming the dividend his balance increases and
            /// thus his share of the total increases as well, which entitles him to claim more of the dividend, potentially draining out the entirety of it if repeated infinitely
            if (_tokenId == _dividendTokenId) {
                uint256 withdrawableDividendAdjusted = _getWithdrawableDividendAndDeductionMath(amountOwned + withdrawableDividend, supply, totalDividend, withdrawnSoFar);
                s.withdrawnDividendPerOwner[_tokenId][_dividendTokenId][_ownerId] += withdrawableDividendAdjusted;
            } else {
                s.withdrawnDividendPerOwner[_tokenId][_dividendTokenId][_ownerId] += withdrawableDividend;
            }

            // Move the dividend
            s.tokenBalances[_dividendTokenId][dividendBankId] -= withdrawableDividend;
            s.tokenBalances[_dividendTokenId][_ownerId] += withdrawableDividend;

            emit InternalTokenBalanceUpdate(dividendBankId, _dividendTokenId, s.tokenBalances[_dividendTokenId][dividendBankId], "_withdrawDividend", msg.sender);
            emit InternalTokenBalanceUpdate(_ownerId, _dividendTokenId, s.tokenBalances[_dividendTokenId][_ownerId], "_withdrawDividend", msg.sender);
            emit DividendWithdrawn(_ownerId, _tokenId, amountOwned, _dividendTokenId, withdrawableDividend);
        }
    }

    function _getWithdrawableDividend(bytes32 _ownerId, bytes32 _tokenId, bytes32 _dividendTokenId) internal view returns (uint256 withdrawableDividend_) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 amount = s.tokenBalances[_tokenId][_ownerId];
        uint256 supply = _internalTokenSupply(_tokenId);
        uint256 totalDividend = s.totalDividends[_tokenId][_dividendTokenId];
        uint256 withdrawnSoFar = s.withdrawnDividendPerOwner[_tokenId][_dividendTokenId][_ownerId];

        withdrawableDividend_ = _getWithdrawableDividendAndDeductionMath(amount, supply, totalDividend, withdrawnSoFar);
    }

    function _withdrawAllDividends(bytes32 _ownerId, bytes32 _tokenId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bytes32[] memory dividendDenominations = s.dividendDenominations[_tokenId];

        for (uint256 i = 0; i < dividendDenominations.length; ++i) {
            _withdrawDividend(_ownerId, _tokenId, dividendDenominations[i]);
        }
    }

    function _payDividend(bytes32 _guid, bytes32 _from, bytes32 _to, bytes32 _dividendTokenId, uint256 _amount) internal {
        require(_amount > 0, "dividend amount must be > 0");
        require(LibAdmin._isSupportedExternalToken(_dividendTokenId), "must be supported dividend token");
        require(!LibObject._isObject(_guid), "nonunique dividend distribution identifier");

        AppStorage storage s = LibAppStorage.diamondStorage();
        bytes32 dividendBankId = LibHelpers._stringToBytes32(LC.DIVIDEND_BANK_IDENTIFIER);

        // If no tokens are issued, then deposit directly.
        // note: This functionality is for the business case where we want to distribute dividends directly to entities.
        // How this functionality is implemented may be changed in the future.
        if (_internalTokenSupply(_to) == 0) {
            _internalTransfer(_from, _to, _dividendTokenId, _amount);
        }
        // Otherwise pay as dividend
        else {
            // issue dividend. if you are owed dividends on the _dividendTokenId, they will be collected
            // Check for possible infinite loop, but probably not
            _internalTransfer(_from, dividendBankId, _dividendTokenId, _amount);
            uint256 tokenSupply = _internalTokenSupply(_dividendTokenId);
            uint256 adjustedDividendAmount = _amount;
            if (_to == _dividendTokenId) {
                // withdrawn dividend was adjusted for the previous holder in this case,
                // therefore dividend amount should be increased in order to give existing token holders the correct amount
                adjustedDividendAmount = (_amount * (tokenSupply)) / (tokenSupply - _amount);
            }

            s.totalDividends[_to][_dividendTokenId] += adjustedDividendAmount;

            // keep track of the dividend denominations
            // if dividend has not yet been issued in this token, add it to the list and update mappings
            if (s.dividendDenominationIndex[_to][_dividendTokenId] == 0 && s.dividendDenominationAtIndex[_to][0] != _dividendTokenId) {
                // We must limit the number of different tokens dividends are paid in
                if (s.dividendDenominations[_to].length >= LibAdmin._getMaxDividendDenominations()) {
                    revert("exceeds max div denominations");
                }

                s.dividendDenominationIndex[_to][_dividendTokenId] = uint8(s.dividendDenominations[_to].length);
                s.dividendDenominationAtIndex[_to][uint8(s.dividendDenominations[_to].length)] = _dividendTokenId;
                s.dividendDenominations[_to].push(_dividendTokenId);
            }
        }

        // prevent guid reuse/collision
        LibObject._createObject(_guid, LC.OBJECT_TYPE_DIVIDEND);

        // Events are emitted from the _internalTransfer()
        emit DividendDistribution(_guid, _from, _to, _dividendTokenId, _amount);
    }

    function _getWithdrawableDividendAndDeductionMath(
        uint256 _amount,
        uint256 _supply,
        uint256 _totalDividend,
        uint256 _withdrawnSoFar
    ) internal pure returns (uint256 _withdrawableDividend) {
        // The holder dividend is: holderDividend = (totalDividend/tokenSupply) * _amount. The remainder (dust) is lost.
        uint256 totalDividendTimesAmount = _totalDividend * _amount;
        uint256 holderDividend = _supply == 0 ? 0 : (totalDividendTimesAmount / _supply);

        _withdrawableDividend = (_withdrawnSoFar >= holderDividend) ? 0 : holderDividend - _withdrawnSoFar;
    }

    function _getLockedBalance(bytes32 _accountId, bytes32 _tokenId) internal view returns (uint256 amount) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.lockedBalances[_accountId][_tokenId];
    }

    function _getAvailableBalance(bytes32 _accountId, bytes32 _tokenId) internal view returns (uint256 amount) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 lockedBalance = s.lockedBalances[_accountId][_tokenId];
        uint256 internalBalance = s.tokenBalances[_tokenId][_accountId];
        return internalBalance - lockedBalance;
    }

    function _totalDividends(bytes32 _tokenId, bytes32 _dividendDenominationId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return s.totalDividends[_tokenId][_dividendDenominationId];
    }

    function _accruedInterest(bytes32 _tokenId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address tokenAddress = LibHelpers._getAddressFromId(_tokenId);

        uint256 depositTotal = s.tokenSupply[_tokenId];
        uint256 total = LibERC20.balanceOf(tokenAddress, address(this));

        // If the Nayms balance of the rebasing token has decreased and is lower than the deposit total, revert
        if (total < depositTotal) {
            revert RebasingSupplyDecreased(_tokenId, depositTotal, total);
        }
        return total - depositTotal;
    }

    function _claimRebasingInterest(bytes32 _tokenId, uint256 _amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (s.tokenSupply[_tokenId] == 0) {
            revert RebasingInterestNotInitialized(_tokenId);
        }

        uint256 accruedAmount = _accruedInterest(_tokenId);
        if (_amount > accruedAmount) {
            revert RebasingInterestInsufficient(_tokenId, _amount, accruedAmount);
        }

        _internalMint(LibAdmin._getSystemId(), _tokenId, _amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { AppStorage, LibAppStorage, MarketInfo, TokenAmount, OrderMatchingCalcs } from "../shared/AppStorage.sol";
import { LibTokenizedVault } from "./LibTokenizedVault.sol";
import { LibConstants } from "./LibConstants.sol";
import { LibFeeRouter } from "./LibFeeRouter.sol";
import { LibAdmin } from "./LibAdmin.sol";

import { MinimumSellCannotBeZero, ObjectDoesNotExist } from "../shared/CustomErrors.sol";

library LibMarket {
    struct MatchingOfferResult {
        uint256 remainingBuyAmount;
        uint256 remainingSellAmount;
        uint256 buyTokenCommissionsPaid;
        uint256 sellTokenCommissionsPaid;
    }

    /// @notice order has been added
    event OrderAdded(
        uint256 indexed orderId,
        bytes32 indexed maker,
        bytes32 indexed sellToken,
        uint256 sellAmount,
        uint256 sellAmountInitial,
        bytes32 buyToken,
        uint256 buyAmount,
        uint256 buyAmountInitial,
        uint256 state
    );

    /// @notice order has been executed
    event OrderExecuted(uint256 indexed orderId, bytes32 indexed taker, bytes32 indexed sellToken, uint256 sellAmount, bytes32 buyToken, uint256 buyAmount, uint256 state);

    /// @notice order has been matched
    /// new event has been added not to change the existing ones, for preserving the backward compatibility
    event OrderMatched(uint256 indexed orderId, uint256 matchedWithId, uint256 sellAmountMatched, uint256 buyAmountMatched);

    /// @notice order has been cancelled
    event OrderCancelled(uint256 indexed orderId, bytes32 indexed taker, bytes32 sellToken);

    function _getBestOfferId(bytes32 _sellToken, bytes32 _buyToken) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.bestOfferId[_sellToken][_buyToken];
    }

    function _insertOfferIntoSortedList(uint256 _offerId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // check that offer is NOT in the sorted list
        require(!_isOfferInSortedList(_offerId), "offer already in sorted list");

        bytes32 sellToken = s.offers[_offerId].sellToken;
        bytes32 buyToken = s.offers[_offerId].buyToken;

        uint256 prevId;

        // find position of next highest offer
        uint256 top = s.bestOfferId[sellToken][buyToken];
        uint256 oldTop;

        while (top != 0 && _isOfferPricedLtOrEq(_offerId, top)) {
            oldTop = top;
            top = s.offers[top].rankPrev;
        }

        uint256 pos = oldTop;

        // insert offer at position
        if (pos != 0) {
            prevId = s.offers[pos].rankPrev;
            s.offers[pos].rankPrev = _offerId;
            s.offers[_offerId].rankNext = pos;
        }
        // else this is the new best offer, so insert at top
        else {
            prevId = s.bestOfferId[sellToken][buyToken];
            s.bestOfferId[sellToken][buyToken] = _offerId;
        }

        if (prevId != 0) {
            // requirement below is satisfied by statements above
            // require(!_isOfferPricedLtOrEq(_offerId, prevId));
            s.offers[prevId].rankNext = _offerId;
            s.offers[_offerId].rankPrev = prevId;
        }

        s.span[sellToken][buyToken]++;
    }

    function _removeOfferFromSortedList(uint256 _offerId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // check that offer is in the sorted list
        require(_isOfferInSortedList(_offerId), "offer not in sorted list");

        bytes32 sellToken = s.offers[_offerId].sellToken;
        bytes32 buyToken = s.offers[_offerId].buyToken;

        require(s.span[sellToken][buyToken] > 0, "token pair list does not exist");

        // if offer is not the highest offer
        if (_offerId != s.bestOfferId[sellToken][buyToken]) {
            uint256 nextId = s.offers[_offerId].rankNext;
            require(s.offers[nextId].rankPrev == _offerId, "sort check failed");
            s.offers[nextId].rankPrev = s.offers[_offerId].rankPrev;
        }
        // if offer is the highest offer
        else {
            s.bestOfferId[sellToken][buyToken] = s.offers[_offerId].rankPrev;
        }

        // if offer is not the lowest offer
        if (s.offers[_offerId].rankPrev != 0) {
            uint256 prevId = s.offers[_offerId].rankPrev;
            require(s.offers[prevId].rankNext == _offerId, "sort check failed");
            s.offers[prevId].rankNext = s.offers[_offerId].rankNext;
        }

        // nullify
        delete s.offers[_offerId].rankNext;
        delete s.offers[_offerId].rankPrev;

        s.span[sellToken][buyToken]--;
    }

    /**
     * @dev If the relative price of the sell token for offer1 ("low offer") is more expensive than the relative price of of the sell token for offer2 ("high offer"), then this returns true.
     *      If the sell token for offer1 is "more expensive", this means that one will need more sell token to buy the same amount of buy token when comparing relative prices of offer1 to offer2.
     */
    function _isOfferPricedLtOrEq(uint256 _lowOfferId, uint256 _highOfferId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 lowSellAmount = s.offers[_lowOfferId].sellAmountInitial;
        uint256 lowBuyAmount = s.offers[_lowOfferId].buyAmountInitial;

        uint256 highSellAmount = s.offers[_highOfferId].sellAmountInitial;
        uint256 highBuyAmount = s.offers[_highOfferId].buyAmountInitial;

        return lowBuyAmount * highSellAmount >= highBuyAmount * lowSellAmount;
    }

    function _isOfferInSortedList(uint256 _offerId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        bytes32 sellToken = s.offers[_offerId].sellToken;
        bytes32 buyToken = s.offers[_offerId].buyToken;

        return _offerId != 0 && (s.offers[_offerId].rankNext != 0 || s.offers[_offerId].rankPrev != 0 || s.bestOfferId[sellToken][buyToken] == _offerId);
    }

    function _matchToExistingOffers(
        uint256 _offerId,
        bytes32 _takerId,
        bytes32 _sellToken,
        uint256 _sellAmount,
        bytes32 _buyToken,
        uint256 _buyAmount,
        uint256 _feeScheduleType
    ) internal returns (MatchingOfferResult memory result) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        result.remainingBuyAmount = _buyAmount;
        result.remainingSellAmount = _sellAmount;

        // sell: p100 buy: $100 =>  YES! buy more
        // sell: $100 buy: p100 =>  NO! DON'T buy more

        // If the buyToken is entity(p-token)   => limit both buy and sell amounts
        // If the buyToken is external          => limit only sell amount

        bool buyExternalToken = LibAdmin._isSupportedExternalToken(_buyToken);
        while (result.remainingSellAmount != 0 && (buyExternalToken || result.remainingBuyAmount != 0)) {
            // there is at least one offer stored for token pair
            uint256 bestOfferId = s.bestOfferId[_buyToken][_sellToken];
            if (bestOfferId == 0) {
                break; // no market liquidity, bail out
            }

            {
                uint256 makerBuyAmount = s.offers[bestOfferId].buyAmount;
                uint256 makerSellAmount = s.offers[bestOfferId].sellAmount;

                // Check if best available price on the market is better or same,
                // as the one taker is willing to pay, within error margin of ±1.
                // This ugly hack is to work around rounding errors. Based on the idea that
                // the furthest the amounts can stray from their "true" values is 1.
                // Ergo the worst case has `sellAmount` and `makerSellAmount` at +1 away from
                // their "correct" values and `makerBuyAmount` and `buyAmount` at -1.
                // Since (c - 1) * (d - 1) > (a + 1) * (b + 1) is equivalent to
                // c * d > a * b + a + b + c + d
                // (For detailed breakdown see https://hiddentao.com/archives/2019/09/08/maker-otc-on-chain-orderbook-deep-dive)
                if (
                    makerBuyAmount * result.remainingBuyAmount >
                    result.remainingSellAmount * makerSellAmount + makerBuyAmount + result.remainingBuyAmount + result.remainingSellAmount + makerSellAmount
                ) {
                    break; // no matching price, bail out
                }
                // ^ The `rounding` parameter is a compromise borne of a couple days of discussion.
            }

            OrderMatchingCalcs memory calcs;

            // take the offer
            if (buyExternalToken) {
                // if the maker's buy amount is less than the remaining sell amount, then we sell only the maker's buy amount. Else, we sell the remaining sell amount
                calcs.currentSellAmount = s.offers[bestOfferId].buyAmount < result.remainingSellAmount ? s.offers[bestOfferId].buyAmount : result.remainingSellAmount;
                calcs.currentBuyAmount = (calcs.currentSellAmount * s.offers[bestOfferId].sellAmount) / s.offers[bestOfferId].buyAmount; // (a / b) * c = c * a / b  -> multiply first, avoid underflow

                // note: _takeOffer returns commissions paid
                result.buyTokenCommissionsPaid += _takeOffer(_feeScheduleType, bestOfferId, _takerId, calcs.currentBuyAmount, calcs.currentSellAmount, buyExternalToken);
            } else {
                // Similar operations, but for the non-external token case (the fee is always paid in external tokens)
                calcs.currentBuyAmount = s.offers[bestOfferId].sellAmount < result.remainingBuyAmount ? s.offers[bestOfferId].sellAmount : result.remainingBuyAmount;
                calcs.currentSellAmount = (calcs.currentBuyAmount * s.offers[bestOfferId].buyAmount) / s.offers[bestOfferId].sellAmount; // (a / b) * c = c * a / b  -> multiply first, avoid underflow

                result.sellTokenCommissionsPaid += _takeOffer(_feeScheduleType, bestOfferId, _takerId, calcs.currentBuyAmount, calcs.currentSellAmount, buyExternalToken);
            }

            // Update how much is left to buy/sell:
            // if the maker's price is more favourable to the taker, to prevent underflow we need to:
            //  - normalize current **external token** amount
            //  - and reduce remaining amount by that normalized value
            //
            //   taker price = initial buy amount / initial sell amount
            //   maker price = current buy amount / current sell amount
            //
            // if taker price < maker price => normalize currentAmount before reducing remainingAmount
            if (_buyAmount * calcs.currentSellAmount < calcs.currentBuyAmount * _sellAmount) {
                if (buyExternalToken) {
                    // Normalize the sell amount when taker is buying external tokens

                    // if the taker is buying an external token, we need to normalize current buy amount value
                    // normalization factor = taker price / maker price:
                    //   = (initial buy amount/initial sell amount) / (current buy amount / current sell amount)
                    //   = initial buy amount * current sell amount / initial sell amount / current buy amount
                    // that means that normalized buy amount:
                    //   = current buy amount * normalization factor
                    // normalized buy amount = current buy amount * (initial buy amount * current sell amount / initial sell amount / current buy amount)
                    // which equals to below:
                    calcs.normalizedBuyAmount = (_buyAmount * calcs.currentSellAmount) / _sellAmount;
                    calcs.normalizedSellAmount = calcs.currentSellAmount;
                } else {
                    // Normalize the sell amount when taker is buying participation tokens

                    // if the taker is buying participation tokens we need to normalize current sell amount value
                    calcs.normalizedBuyAmount = calcs.currentBuyAmount;
                    calcs.normalizedSellAmount = (_sellAmount * calcs.currentBuyAmount) / _buyAmount;
                }
                result.remainingBuyAmount -= calcs.normalizedBuyAmount;
                result.remainingSellAmount -= calcs.normalizedSellAmount;
            } else {
                result.remainingBuyAmount -= calcs.currentBuyAmount;
                result.remainingSellAmount -= calcs.currentSellAmount;
            }

            // note: events are emmited to keep track of average price actually paid,
            // in case matched is done with more preferable offers, otherwise this information is be lost
            emit OrderMatched(_offerId, bestOfferId, calcs.currentSellAmount, calcs.currentBuyAmount); // taker offer
            emit OrderMatched(bestOfferId, _offerId, calcs.currentBuyAmount, calcs.currentSellAmount); // maker offer
        }
    }

    function _createOffer(
        uint256 _offerId,
        bytes32 _creator,
        bytes32 _sellToken,
        uint256 _sellAmount,
        uint256 _sellAmountInitial,
        bytes32 _buyToken,
        uint256 _buyAmount,
        uint256 _buyAmountInitial,
        uint256 _feeScheduleType
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        require(_offerId == ++s.lastOfferId, "Invalid Offer ID");

        MarketInfo memory marketInfo;
        marketInfo.creator = _creator;
        marketInfo.sellToken = _sellToken;
        marketInfo.sellAmount = _sellAmount;
        marketInfo.sellAmountInitial = _sellAmountInitial;
        marketInfo.buyToken = _buyToken;
        marketInfo.buyAmount = _buyAmount;
        marketInfo.buyAmountInitial = _buyAmountInitial;
        marketInfo.feeSchedule = _feeScheduleType;

        uint256 btMin = s.objectMinimumSell[_buyToken];
        uint256 stMin = s.objectMinimumSell[_sellToken];

        if (_buyAmount < (btMin == 0 ? 1 : btMin) || _sellAmount < (stMin == 0 ? 1 : stMin)) {
            marketInfo.state = LibConstants.OFFER_STATE_FULFILLED;
        } else {
            marketInfo.state = LibConstants.OFFER_STATE_ACTIVE;
        }

        s.offers[_offerId] = marketInfo;
        emit OrderAdded(_offerId, marketInfo.creator, _sellToken, _sellAmount, _sellAmountInitial, _buyToken, _buyAmount, _buyAmountInitial, marketInfo.state);
    }

    function _takeOffer(
        uint256 _feeScheduleType,
        uint256 _offerId,
        bytes32 _takerId,
        uint256 _buyAmount,
        uint256 _sellAmount,
        bool _takeExternalToken
    ) internal returns (uint256 commissionsPaid_) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // check bounds and update balances
        _checkBoundsAndUpdateBalances(_offerId, _buyAmount, _sellAmount);

        /// Check to see if the fee schedule from the new order (`startTokenSale()`) is the initial offer fee schedule or not
        /// Use the initial offer fee schedule if it is, otherwise use the fee schedule from the original order placed

        {
            uint256 feeScheduleType;
            if (s.offers[_offerId].feeSchedule == LibConstants.FEE_TYPE_INITIAL_SALE || _feeScheduleType == LibConstants.FEE_TYPE_INITIAL_SALE) {
                feeScheduleType = LibConstants.FEE_TYPE_INITIAL_SALE;
            } else {
                feeScheduleType = LibConstants.FEE_TYPE_TRADING;
            }

            bytes32 buyer;
            if (feeScheduleType == LibConstants.FEE_TYPE_INITIAL_SALE && s.offers[_offerId].creator != s.offers[_offerId].sellToken) {
                buyer = s.offers[_offerId].creator;
            } else {
                buyer = _takerId;
            }

            // _takeExternalToken == true means the creator is selling an external token
            if (_takeExternalToken) {
                // sellToken is external supported token, commissions are paid on top of _buyAmount in sellToken
                commissionsPaid_ = LibFeeRouter._payTradingFees(feeScheduleType, buyer, s.offers[_offerId].creator, _takerId, s.offers[_offerId].sellToken, _buyAmount);
            } else {
                // sellToken is internal/participation token, commissions are paid from _sellAmount in buyToken
                commissionsPaid_ = LibFeeRouter._payTradingFees(feeScheduleType, buyer, s.offers[_offerId].creator, _takerId, s.offers[_offerId].buyToken, _sellAmount);
            }
            s.lockedBalances[s.offers[_offerId].creator][s.offers[_offerId].sellToken] -= _buyAmount;

            LibTokenizedVault._internalTransfer(s.offers[_offerId].creator, _takerId, s.offers[_offerId].sellToken, _buyAmount);
            LibTokenizedVault._internalTransfer(_takerId, s.offers[_offerId].creator, s.offers[_offerId].buyToken, _sellAmount);

            // close offer if it has become dust
            uint256 stMin = s.objectMinimumSell[s.offers[_offerId].sellToken];
            if (s.offers[_offerId].sellAmount < (stMin == 0 ? 1 : stMin)) {
                s.offers[_offerId].state = LibConstants.OFFER_STATE_FULFILLED;
                _cancelOffer(_offerId);
            }
        }

        emit OrderExecuted(
            _offerId,
            _takerId,
            s.offers[_offerId].sellToken,
            s.offers[_offerId].sellAmount,
            s.offers[_offerId].buyToken,
            s.offers[_offerId].buyAmount,
            s.offers[_offerId].state
        );
    }

    function _checkBoundsAndUpdateBalances(uint256 _offerId, uint256 _sellAmount, uint256 _buyAmount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        (TokenAmount memory offerSell, TokenAmount memory offerBuy) = _getOfferTokenAmounts(_offerId);

        _validateAmounts(_sellAmount, _buyAmount);

        require(_buyAmount <= offerBuy.amount, "requested buy amount too large");
        require(_sellAmount <= offerSell.amount, "calculated sell amount too large");

        // update balances
        s.offers[_offerId].sellAmount = offerSell.amount - _sellAmount;
        s.offers[_offerId].buyAmount = offerBuy.amount - _buyAmount;
    }

    function _cancelOffer(uint256 _offerId) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (_isOfferInSortedList(_offerId)) {
            _removeOfferFromSortedList(_offerId);
        }

        MarketInfo memory marketInfo = s.offers[_offerId];

        // unlock the remaining sell amount back to creator
        if (marketInfo.sellAmount > 0) {
            // note nothing is transferred since tokens for sale are UN-escrowed. Just unlock!
            s.lockedBalances[s.offers[_offerId].creator][s.offers[_offerId].sellToken] -= marketInfo.sellAmount;
        }

        // don't emit event stating market order is cancelled if the market order was executed and fulfilled
        if (marketInfo.state != LibConstants.OFFER_STATE_FULFILLED) {
            s.offers[_offerId].state = LibConstants.OFFER_STATE_CANCELLED;
            emit OrderCancelled(_offerId, marketInfo.creator, marketInfo.sellToken);
        }

        /// @dev Burn the par tokens if this was an initial token sale (selling par tokens through startTokenSale())
        if (marketInfo.feeSchedule == LibConstants.FEE_TYPE_INITIAL_SALE) {
            LibTokenizedVault._internalBurn(s.offers[_offerId].sellToken, s.offers[_offerId].sellToken, marketInfo.sellAmount);
        }
    }

    function _validateAmounts(uint256 _sellAmount, uint256 _buyAmount) internal pure {
        require(_sellAmount <= type(uint128).max, "sell amount exceeds uint128 limit");
        require(_buyAmount <= type(uint128).max, "buy amount exceeds uint128 limit");
        require(_sellAmount > 0, "sell amount must be >0");
        require(_buyAmount > 0, "buy amount must be >0");
    }

    function _validateOffer(bytes32 _entityId, bytes32 _sellToken, uint256 _sellAmount, bytes32 _buyToken, uint256 _buyAmount, uint256 _feeScheduleType) internal view {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // A valid offer can only be made by an existing entity.
        require(_entityId != 0 && s.existingEntities[_entityId], "offer must be made by an existing entity");

        // note: Clarification on terminology:
        // A participation token (a.k.a par token or p token or entity token) is an entity tokenized.
        // An external token is an ERC20 token approved to be used on the Nayms platform.

        bool isSellExternalToken = LibAdmin._isSupportedExternalToken(_sellToken);
        bool isBuyExternalToken = LibAdmin._isSupportedExternalToken(_buyToken);

        _validateAmounts(_sellAmount, _buyAmount);

        require(_sellToken != "", "sell token must be valid");
        require(_buyToken != "", "buy token must be valid");

        require(isBuyExternalToken || isSellExternalToken, "must trade external token");
        require(_sellToken != _buyToken, "cannot sell and buy same token");

        // note: add restriction to not be able to sell tokens that are already for sale
        // maker must own sell amount and it must not be locked
        require(s.tokenBalances[_sellToken][_entityId] >= _sellAmount, "insufficient balance");
        require(s.tokenBalances[_sellToken][_entityId] - s.lockedBalances[_entityId][_sellToken] >= _sellAmount, "insufficient balance available, funds locked");

        // must have a valid fee schedule
        require(_feeScheduleType == LibConstants.FEE_TYPE_TRADING || _feeScheduleType == LibConstants.FEE_TYPE_INITIAL_SALE, "fee type invalid");
    }

    function _getOfferTokenAmounts(uint256 _offerId) internal view returns (TokenAmount memory sell_, TokenAmount memory buy_) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        sell_.token = s.offers[_offerId].sellToken;
        sell_.amount = s.offers[_offerId].sellAmount;
        buy_.token = s.offers[_offerId].buyToken;
        buy_.amount = s.offers[_offerId].buyAmount;
    }

    function _executeLimitOffer(
        bytes32 _creator,
        bytes32 _sellToken,
        uint256 _sellAmount,
        bytes32 _buyToken,
        uint256 _buyAmount,
        uint256 _feeScheduleType
    ) internal returns (uint256 offerId_, uint256 buyTokenCommissionsPaid_, uint256 sellTokenCommissionsPaid_) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        _validateOffer(_creator, _sellToken, _sellAmount, _buyToken, _buyAmount, _feeScheduleType);

        offerId_ = s.lastOfferId + 1;
        _createOffer(offerId_, _creator, _sellToken, _sellAmount, _sellAmount, _buyToken, _buyAmount, _buyAmount, _feeScheduleType);

        MatchingOfferResult memory result = _matchToExistingOffers(offerId_, _creator, _sellToken, _sellAmount, _buyToken, _buyAmount, _feeScheduleType);
        buyTokenCommissionsPaid_ = result.buyTokenCommissionsPaid;
        sellTokenCommissionsPaid_ = result.sellTokenCommissionsPaid;

        s.offers[offerId_].sellAmount = result.remainingSellAmount;
        s.offers[offerId_].buyAmount = result.remainingBuyAmount;

        // lock tokens!
        s.lockedBalances[_creator][_sellToken] += result.remainingSellAmount;

        if (result.remainingSellAmount < s.objectMinimumSell[_sellToken] || result.remainingBuyAmount < s.objectMinimumSell[_buyToken]) {
            s.offers[offerId_].state = LibConstants.OFFER_STATE_FULFILLED;
        }

        // if still some left
        if (s.offers[offerId_].state == LibConstants.OFFER_STATE_ACTIVE) {
            // ensure it's in the right position in the list
            _insertOfferIntoSortedList(offerId_);
        }
    }

    function _getOffer(uint256 _offerId) internal view returns (MarketInfo memory _offerState) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.offers[_offerId];
    }

    function _getLastOfferId() internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.lastOfferId;
    }

    function _isActiveOffer(uint256 _offerId) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.offers[_offerId].state == LibConstants.OFFER_STATE_ACTIVE;
    }

    function _objectMinimumSell(bytes32 _objectId) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.objectMinimumSell[_objectId];
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity ^0.8.20;

import {Math} from "./math/Math.sol";
import {SignedMath} from "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

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
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
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
    function toStringSigned(int256 value) internal pure returns (string memory) {
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
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

// A loupe is a small magnifying glass used to look at diamonds.
// These functions look at diamonds
interface IDiamondLoupe {
    /// These functions are expected to be called frequently
    /// by tools.

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ERC-173 Contract Ownership Standard
///  Note: the ERC-165 identifier for this interface is 0x7f5828d0
/* is ERC165 */
interface IERC173 {
    /// @dev This emits when ownership of a contract changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Get the address of the owner
    /// @return owner_ The address of the owner.
    function owner() external view returns (address owner_);

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { LibAppStorage } from "../shared/AppStorage.sol";

// From OpenZeppelin: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol

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
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, reentrancyStatus will be _NOT_ENTERED
        require(LibAppStorage.diamondStorage().reentrancyStatus != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        LibAppStorage.diamondStorage().reentrancyStatus = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        LibAppStorage.diamondStorage().reentrancyStatus = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { AppStorage, LibAppStorage, CalculatedFees, FeeAllocation, FeeSchedule } from "../shared/AppStorage.sol";
import { LibObject } from "./LibObject.sol";
import { LibConstants } from "./LibConstants.sol";
import { LibTokenizedVault } from "./LibTokenizedVault.sol";
import { FeeBasisPointsExceedHalfMax, EntityDoesNotExist, InvalidReceiverCount } from "../shared/CustomErrors.sol";

library LibFeeRouter {
    event FeePaid(bytes32 indexed fromId, bytes32 indexed toId, bytes32 tokenId, uint256 amount, uint256 feeType);

    event MakerBasisPointsUpdated(uint16 tradingCommissionMakerBP);
    event FeeScheduleAdded(bytes32 entityId, uint256 feeType, FeeSchedule feeSchedule);
    event FeeScheduleRemoved(bytes32 entityId, uint256 feeType);

    function _calculatePremiumFees(bytes32 _policyId, uint256 _premiumPaid) internal view returns (CalculatedFees memory cf) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        bytes32[] memory commissionReceivers = s.simplePolicies[_policyId].commissionReceivers;
        uint256[] memory commissionBasisPoints = s.simplePolicies[_policyId].commissionBasisPoints;
        uint256 commissionsCount = commissionReceivers.length;

        bytes32 parentEntityId = LibObject._getParent(_policyId);
        FeeSchedule memory feeSchedule = _getFeeSchedule(parentEntityId, LibConstants.FEE_TYPE_PREMIUM);
        uint256 feeScheduleReceiversCount = feeSchedule.receiver.length;

        uint256 totalReceiverCount = feeScheduleReceiversCount + commissionsCount;

        cf.feeAllocations = new FeeAllocation[](totalReceiverCount);

        uint256 fee;
        for (uint256 i; i < commissionsCount; ++i) {
            fee = (_premiumPaid * commissionBasisPoints[i]) / LibConstants.BP_FACTOR;

            cf.feeAllocations[i].to = commissionReceivers[i];
            cf.feeAllocations[i].basisPoints = commissionBasisPoints[i];
            cf.feeAllocations[i].fee = fee;

            cf.totalBP += commissionBasisPoints[i];
            cf.totalFees += fee;
        }

        for (uint256 i; i < feeScheduleReceiversCount; ++i) {
            fee = (_premiumPaid * feeSchedule.basisPoints[i]) / LibConstants.BP_FACTOR;

            cf.feeAllocations[commissionsCount + i].to = feeSchedule.receiver[i];
            cf.feeAllocations[commissionsCount + i].basisPoints = feeSchedule.basisPoints[i];
            cf.feeAllocations[commissionsCount + i].fee = fee;

            cf.totalBP += feeSchedule.basisPoints[i];
            cf.totalFees += fee;
        }
    }

    /// @dev The total bp for a policy premium fee schedule cannot exceed LibConstants.BP_FACTOR since the policy's additional fee receivers and fee schedule are each checked to be less than LibConstants.BP_FACTOR / 2 when they are being set.
    function _payPremiumFees(bytes32 _policyId, uint256 _premiumPaid) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        bytes32[] memory commissionReceivers = s.simplePolicies[_policyId].commissionReceivers;
        uint256[] memory commissionBasisPoints = s.simplePolicies[_policyId].commissionBasisPoints;
        uint256 commissionsCount = commissionReceivers.length;

        bytes32 parentEntityId = LibObject._getParent(_policyId);

        bytes32 asset = s.simplePolicies[_policyId].asset;
        uint256 fee;
        for (uint256 i; i < commissionsCount; ++i) {
            fee = (_premiumPaid * commissionBasisPoints[i]) / LibConstants.BP_FACTOR;

            if (fee > 0) {
                emit FeePaid(parentEntityId, commissionReceivers[i], asset, fee, LibConstants.FEE_TYPE_PREMIUM);
                LibTokenizedVault._internalTransfer(parentEntityId, commissionReceivers[i], asset, fee);
            }
        }

        FeeSchedule memory feeSchedule = _getFeeSchedule(parentEntityId, LibConstants.FEE_TYPE_PREMIUM);

        uint256 feeScheduleReceiversCount = feeSchedule.receiver.length;
        for (uint256 i; i < feeScheduleReceiversCount; ++i) {
            fee = (_premiumPaid * feeSchedule.basisPoints[i]) / LibConstants.BP_FACTOR;

            if (fee > 0) {
                emit FeePaid(parentEntityId, feeSchedule.receiver[i], asset, fee, LibConstants.FEE_TYPE_PREMIUM);
                LibTokenizedVault._internalTransfer(parentEntityId, feeSchedule.receiver[i], asset, fee);
            }
        }
    }

    function _calculateTradingFees(bytes32 _buyerId, bytes32 _sellToken, bytes32 _buyToken, uint256 _buyAmount) internal view returns (uint256 totalFees_, uint256 totalBP_) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 offerId = s.bestOfferId[_buyToken][_sellToken];
        uint256 remainingBuyAmount = _buyAmount;
        uint256 offerCounter;

        while (remainingBuyAmount > 0) {
            // if no liquidity, apply default fees
            uint256 feeType = s.offers[offerId].sellAmount == 0 ? LibConstants.FEE_TYPE_INITIAL_SALE : s.offers[offerId].feeSchedule;
            FeeSchedule memory feeSchedule = _getFeeSchedule(_buyerId, feeType);

            uint256 amount = s.offers[offerId].sellAmount == 0 || remainingBuyAmount < s.offers[offerId].sellAmount ? remainingBuyAmount : s.offers[offerId].sellAmount;

            remainingBuyAmount -= amount;

            for (uint256 i; i < feeSchedule.basisPoints.length; i++) {
                totalFees_ += (amount * feeSchedule.basisPoints[i]) / LibConstants.BP_FACTOR;
                totalBP_ += feeSchedule.basisPoints[i];
            }

            if (s.tradingCommissionMakerBP > 0) {
                totalFees_ += (amount * s.tradingCommissionMakerBP) / LibConstants.BP_FACTOR;
                totalBP_ += s.tradingCommissionMakerBP;
            }

            offerCounter++;
            offerId = s.offers[offerId].rankPrev;
        }
        totalBP_ = offerCounter > 0 ? totalBP_ / offerCounter : totalBP_; // normalize total BP
    }

    /// @dev The total bp for a marketplace fee schedule cannot exceed LibConstants.BP_FACTOR since the maker BP and fee schedules are each checked to be less than LibConstants.BP_FACTOR / 2 when they are being set.
    function _payTradingFees(
        uint256 _feeScheduleType,
        bytes32 _buyer,
        bytes32 _makerId,
        bytes32 _takerId,
        bytes32 _tokenId,
        uint256 _buyAmount
    ) internal returns (uint256 totalFees_) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Get the fee receivers for this _feeScheduleType
        FeeSchedule memory feeSchedule = _getFeeSchedule(_buyer, _feeScheduleType);

        uint256 fee;
        // Calculate fees for the market maker
        if (s.tradingCommissionMakerBP > 0) {
            fee = (_buyAmount * s.tradingCommissionMakerBP) / LibConstants.BP_FACTOR;
            totalFees_ += fee;

            emit FeePaid(_takerId, _makerId, _tokenId, fee, LibConstants.FEE_TYPE_TRADING);
            LibTokenizedVault._internalTransfer(_takerId, _makerId, _tokenId, fee);
        }

        uint256 feeScheduleReceiversCount = feeSchedule.receiver.length;
        for (uint256 i; i < feeScheduleReceiversCount; i++) {
            fee = (_buyAmount * feeSchedule.basisPoints[i]) / LibConstants.BP_FACTOR;

            if (fee > 0) {
                LibTokenizedVault._internalTransfer(_buyer, feeSchedule.receiver[i], _tokenId, fee);
                totalFees_ += fee;
                emit FeePaid(_buyer, feeSchedule.receiver[i], _tokenId, fee, LibConstants.FEE_TYPE_TRADING);
            }
        }
    }

    function _replaceMakerBP(uint16 tradingCommissionMakerBP) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (tradingCommissionMakerBP > LibConstants.BP_FACTOR / 2) {
            revert FeeBasisPointsExceedHalfMax(tradingCommissionMakerBP, LibConstants.BP_FACTOR / 2);
        }

        s.tradingCommissionMakerBP = tradingCommissionMakerBP;

        emit MakerBasisPointsUpdated(tradingCommissionMakerBP);
    }

    function _addFeeSchedule(bytes32 _entityId, uint256 _feeScheduleType, bytes32[] calldata _receiver, uint16[] calldata _basisPoints) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // The entity must exist or it must be the default fee schedule
        if (!(s.existingEntities[_entityId] || _entityId == LibConstants.DEFAULT_FEE_SCHEDULE)) {
            revert EntityDoesNotExist(_entityId);
        }

        require(_receiver.length == _basisPoints.length, "receivers and basis points mismatch");

        if (_receiver.length < 1 || _receiver.length > 10) revert InvalidReceiverCount(_receiver.length);

        // Remove the fee schedule for this _entityId/_feeScheduleType if it already exists
        delete s.feeSchedules[_entityId][_feeScheduleType];

        FeeSchedule memory feeSchedule = FeeSchedule({ receiver: _receiver, basisPoints: _basisPoints });

        // Check to see that the total basis points does not exceed LibConstants.BP_FACTOR / 2 basis points
        uint256 receiverCount = feeSchedule.receiver.length;
        uint256 totalBp;
        for (uint256 i; i < receiverCount; ++i) {
            totalBp += feeSchedule.basisPoints[i];
        }
        if (totalBp > LibConstants.BP_FACTOR / 2) {
            revert FeeBasisPointsExceedHalfMax(totalBp, LibConstants.BP_FACTOR / 2);
        }

        s.feeSchedules[_entityId][_feeScheduleType] = feeSchedule;

        emit FeeScheduleAdded(_entityId, _feeScheduleType, feeSchedule);
    }

    /// @dev VERY IMPORTANT: always use this method to fetch the fee schedule because of fallback to default one!
    function _getFeeSchedule(bytes32 _entityId, uint256 _feeScheduleType) internal view returns (FeeSchedule memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        FeeSchedule memory feeSchedule = s.feeSchedules[_entityId][_feeScheduleType];

        if (feeSchedule.receiver.length == 0 || feeSchedule.receiver.length != feeSchedule.basisPoints.length) {
            // return default fee schedule
            feeSchedule = s.feeSchedules[LibConstants.DEFAULT_FEE_SCHEDULE][_feeScheduleType];
        }
        return feeSchedule;
    }

    function _removeFeeSchedule(bytes32 _entityId, uint256 _feeScheduleType) internal {
        // note: default fee schedule is stored at s.feeSchedules[LibConstants.DEFAULT_FEE_SCHEDULE][_feeScheduleType]
        // cannot remove this default fee schedule.
        require(_entityId != LibConstants.DEFAULT_FEE_SCHEDULE, "cannot remove default fees");
        AppStorage storage s = LibAppStorage.diamondStorage();
        delete s.feeSchedules[_entityId][_feeScheduleType];
        emit FeeScheduleRemoved(_entityId, _feeScheduleType);
    }

    function _getMakerBP() internal view returns (uint16) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.tradingCommissionMakerBP;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
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
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
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
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
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
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
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
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
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

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
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

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
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
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
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
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
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
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

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
