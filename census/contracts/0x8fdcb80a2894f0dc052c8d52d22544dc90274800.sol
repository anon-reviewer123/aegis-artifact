// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {
    FlowCaps,
    FlowCapsConfig,
    Withdrawal,
    MAX_SETTABLE_FLOW_CAP,
    IPublicAllocatorStaticTyping,
    IPublicAllocatorBase
} from "./interfaces/IPublicAllocator.sol";
import {IEulerEarn, MarketAllocation} from "./interfaces/IEulerEarn.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

import {IERC4626} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {EVCUtil} from "../lib/ethereum-vault-connector/src/utils/EVCUtil.sol";

/// @title PublicAllocator
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @notice Publicly callable allocator for EulerEarn vaults.
contract PublicAllocator is EVCUtil, IPublicAllocatorStaticTyping {
    /* STORAGE */

    /// @inheritdoc IPublicAllocatorBase
    mapping(address => address) public admin;
    /// @inheritdoc IPublicAllocatorBase
    mapping(address => uint256) public fee;
    /// @inheritdoc IPublicAllocatorBase
    mapping(address => uint256) public accruedFee;
    /// @inheritdoc IPublicAllocatorStaticTyping
    mapping(address => mapping(IERC4626 => FlowCaps)) public flowCaps;

    /* MODIFIER */

    /// @dev Reverts if the caller is not the admin nor the owner of this vault.
    modifier onlyAdminOrVaultOwner(address vault) {
        address msgSender = _authenticateCallerWithStandardContextState(true);
        if (msgSender != admin[vault] && msgSender != IEulerEarn(vault).owner()) {
            revert ErrorsLib.NotAdminNorVaultOwner();
        }
        _;
    }

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    constructor(address evc) EVCUtil(evc) {}

    /* ADMIN OR VAULT OWNER ONLY */

    /// @inheritdoc IPublicAllocatorBase
    function setAdmin(address vault, address newAdmin) external onlyAdminOrVaultOwner(vault) {
        if (admin[vault] == newAdmin) revert ErrorsLib.AlreadySet();
        admin[vault] = newAdmin;
        emit EventsLib.SetAdmin(_msgSender(), vault, newAdmin);
    }

    /// @inheritdoc IPublicAllocatorBase
    function setFee(address vault, uint256 newFee) external onlyAdminOrVaultOwner(vault) {
        if (fee[vault] == newFee) revert ErrorsLib.AlreadySet();
        fee[vault] = newFee;
        emit EventsLib.SetAllocationFee(_msgSender(), vault, newFee);
    }

    /// @inheritdoc IPublicAllocatorBase
    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external onlyAdminOrVaultOwner(vault) {
        for (uint256 i = 0; i < config.length; i++) {
            IERC4626 id = config[i].id;
            if (!IEulerEarn(vault).config(id).enabled && (config[i].caps.maxIn > 0 || config[i].caps.maxOut > 0)) {
                revert ErrorsLib.MarketNotEnabled(id);
            }
            if (config[i].caps.maxIn > MAX_SETTABLE_FLOW_CAP || config[i].caps.maxOut > MAX_SETTABLE_FLOW_CAP) {
                revert ErrorsLib.MaxSettableFlowCapExceeded();
            }
            flowCaps[vault][id] = config[i].caps;
        }

        emit EventsLib.SetFlowCaps(_msgSender(), vault, config);
    }

    /// @inheritdoc IPublicAllocatorBase
    function transferFee(address vault, address payable feeRecipient) external onlyAdminOrVaultOwner(vault) {
        uint256 claimed = accruedFee[vault];
        accruedFee[vault] = 0;
        (bool success,) = feeRecipient.call{value: claimed}("");
        if (!success) revert ErrorsLib.FeeTransferFailed(feeRecipient);
        emit EventsLib.TransferAllocationFee(_msgSender(), vault, claimed, feeRecipient);
    }

    /* PUBLIC */

    /// @inheritdoc IPublicAllocatorBase
    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, IERC4626 supplyId) external payable {
        if (msg.value != fee[vault]) revert ErrorsLib.IncorrectFee();
        if (msg.value > 0) accruedFee[vault] += msg.value;

        if (withdrawals.length == 0) revert ErrorsLib.EmptyWithdrawals();

        if (!IEulerEarn(vault).config(supplyId).enabled) revert ErrorsLib.MarketNotEnabled(supplyId);

        MarketAllocation[] memory allocations = new MarketAllocation[](withdrawals.length + 1);
        uint128 totalWithdrawn;

        IERC4626 id;
        IERC4626 prevId;
        for (uint256 i = 0; i < withdrawals.length; i++) {
            prevId = id;
            id = withdrawals[i].id;
            if (!IEulerEarn(vault).config(id).enabled) revert ErrorsLib.MarketNotEnabled(id);
            uint128 withdrawnAssets = withdrawals[i].amount;
            if (withdrawnAssets == 0) revert ErrorsLib.WithdrawZero(id);

            if (address(id) <= address(prevId)) revert ErrorsLib.InconsistentWithdrawals();
            if (address(id) == address(supplyId)) revert ErrorsLib.DepositMarketInWithdrawals();

            uint256 assets = IEulerEarn(vault).expectedSupplyAssets(id);

            if (flowCaps[vault][id].maxOut < withdrawnAssets) revert ErrorsLib.MaxOutflowExceeded(id);
            if (assets < withdrawnAssets) revert ErrorsLib.NotEnoughSupply(id);

            flowCaps[vault][id].maxIn += withdrawnAssets;
            flowCaps[vault][id].maxOut -= withdrawnAssets;
            allocations[i].id = withdrawals[i].id;
            allocations[i].assets = assets - withdrawnAssets;

            totalWithdrawn += withdrawnAssets;

            emit EventsLib.PublicWithdrawal(_msgSender(), vault, id, withdrawnAssets);
        }

        if (flowCaps[vault][supplyId].maxIn < totalWithdrawn) revert ErrorsLib.MaxInflowExceeded(supplyId);

        flowCaps[vault][supplyId].maxIn -= totalWithdrawn;
        flowCaps[vault][supplyId].maxOut += totalWithdrawn;
        allocations[withdrawals.length].id = supplyId;
        allocations[withdrawals.length].assets = type(uint256).max;

        IEulerEarn(vault).reallocate(allocations);

        emit EventsLib.PublicReallocateTo(_msgSender(), vault, supplyId, totalWithdrawn);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {MarketAllocation} from "./IEulerEarn.sol";

import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

/// @dev Max settable flow cap, such that caps can always be stored on 128 bits.
/// @dev The actual max possible flow cap is type(uint128).max-1.
/// @dev Equals to 170141183460469231731687303715884105727;
uint128 constant MAX_SETTABLE_FLOW_CAP = type(uint128).max / 2;

struct FlowCaps {
    /// @notice The maximum allowed inflow in a vault.
    uint128 maxIn;
    /// @notice The maximum allowed outflow in a vault.
    uint128 maxOut;
}

struct FlowCapsConfig {
    /// @notice Vault for which to change flow caps.
    IERC4626 id;
    /// @notice New flow caps for this vault.
    FlowCaps caps;
}

struct Withdrawal {
    /// @notice The vault from which to withdraw.
    IERC4626 id;
    /// @notice The amount to withdraw.
    uint128 amount;
}

/// @dev This interface is used for factorizing IPublicAllocatorStaticTyping and IPublicAllocator.
/// @dev Consider using the IPublicAllocator interface instead of this one.
interface IPublicAllocatorBase {
    /// @notice The admin for a given vault.
    function admin(address vault) external view returns (address);

    /// @notice The current ETH fee for a given vault.
    function fee(address vault) external view returns (uint256);

    /// @notice The accrued ETH fee for a given vault.
    function accruedFee(address vault) external view returns (uint256);

    /// @notice Reallocates from a list of vaults to one vault.
    /// @param vault The EulerEarn vault to reallocate.
    /// @param withdrawals The vaults to withdraw from, and the amounts to withdraw.
    /// @param supplyId The vault receiving total withdrawn to.
    /// @dev Will call EulerEarn's `reallocate`.
    /// @dev Checks that the flow caps are respected.
    /// @dev Will revert when `withdrawals` contains a duplicate or is not sorted.
    /// @dev Will revert if `withdrawals` contains the supply vault.
    /// @dev Will revert if a withdrawal amount is larger than available liquidity.
    function reallocateTo(address vault, Withdrawal[] calldata withdrawals, IERC4626 supplyId) external payable;

    /// @notice Sets the admin for a given vault.
    function setAdmin(address vault, address newAdmin) external;

    /// @notice Sets the fee for a given vault.
    function setFee(address vault, uint256 newFee) external;

    /// @notice Transfers the current balance to `feeRecipient` for a given vault.
    function transferFee(address vault, address payable feeRecipient) external;

    /// @notice Sets the maximum inflow and outflow through public allocation for some vaults for a given Earn vault.
    /// @dev Max allowed inflow/outflow is MAX_SETTABLE_FLOW_CAP.
    /// @dev Doesn't revert if it doesn't change the storage at all.
    function setFlowCaps(address vault, FlowCapsConfig[] calldata config) external;
}

/// @dev This interface is inherited by PublicAllocator so that function signatures are checked by the compiler.
/// @dev Consider using the IPublicAllocator interface instead of this one.
interface IPublicAllocatorStaticTyping is IPublicAllocatorBase {
    /// @notice Returns (maximum inflow, maximum outflow) through public allocation of a given vault for a given Earn vault.
    function flowCaps(address vault, IERC4626) external view returns (uint128, uint128);
}

/// @title IPublicAllocator
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @dev Use this interface for PublicAllocator to have access to all the functions with the appropriate function
/// signatures.
interface IPublicAllocator is IPublicAllocatorBase {
    /// @notice Returns the maximum inflow and maximum outflow through public allocation of a given vault for a given
    /// Earn vault.
    function flowCaps(address vault, IERC4626) external view returns (FlowCaps memory);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IEulerEarnFactory} from "./IEulerEarnFactory.sol";

import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

import {MarketConfig, PendingUint136, PendingAddress} from "../libraries/PendingLib.sol";

struct MarketAllocation {
    /// @notice The vault to allocate.
    IERC4626 id;
    /// @notice The amount of assets to allocate.
    uint256 assets;
}

interface IOwnable {
    function owner() external view returns (address);
    function transferOwnership(address) external;
    function renounceOwnership() external;
    function acceptOwnership() external;
    function pendingOwner() external view returns (address);
}

/// @dev This interface is used for factorizing IEulerEarnStaticTyping and IEulerEarn.
/// @dev Consider using the IEulerEarn interface instead of this one.
interface IEulerEarnBase {
    /// @notice The address of the Permit2 contract.
    function permit2Address() external view returns (address);

    /// @notice The address of the creator.
    function creator() external view returns (address);

    /// @notice The address of the curator.
    function curator() external view returns (address);

    /// @notice Stores whether an address is an allocator or not.
    function isAllocator(address target) external view returns (bool);

    /// @notice The current guardian. Can be set even without the timelock set.
    function guardian() external view returns (address);

    /// @notice The current fee.
    function fee() external view returns (uint96);

    /// @notice The fee recipient.
    function feeRecipient() external view returns (address);

    /// @notice The current timelock.
    function timelock() external view returns (uint256);

    /// @dev Stores the order of vaults in which liquidity is supplied upon deposit.
    /// @dev Can contain any vault. A vault is skipped as soon as its supply cap is reached.
    function supplyQueue(uint256) external view returns (IERC4626);

    /// @notice Returns the length of the supply queue.
    function supplyQueueLength() external view returns (uint256);

    /// @dev Stores the order of vault from which liquidity is withdrawn upon withdrawal.
    /// @dev Always contain all non-zero cap vault as well as all vault on which the Earn vault supplies liquidity,
    /// without duplicate.
    function withdrawQueue(uint256) external view returns (IERC4626);

    /// @notice Returns the length of the withdraw queue.
    function withdrawQueueLength() external view returns (uint256);

    /// @notice Returns the amount of assets that can be withdrawn from given strategy vault.
    /// @dev Accounts for internally tracked balance, ignoring direct shares transfer and for assets available in the strategy.
    function maxWithdrawFromStrategy(IERC4626 id) external view returns (uint256);

    /// @notice Returns the amount of assets expected to be supplied to the strategy vault.
    /// @dev Accounts for internally tracked balance, ignoring direct shares transfer.
    function expectedSupplyAssets(IERC4626 id) external view returns (uint256);

    /// @notice Stores the total assets managed by this vault when the fee was last accrued.
    function lastTotalAssets() external view returns (uint256);

    /// @notice Stores the missing assets due to realized bad debt or forced vault removal.
    /// @dev In order to cover those lost assets, it is advised to supply on behalf of address(1) on the vault
    /// (canonical method).
    function lostAssets() external view returns (uint256);

    /// @notice Submits a `newTimelock`.
    /// @dev Warning: Reverts if a timelock is already pending. Revoke the pending timelock to overwrite it.
    /// @dev In case the new timelock is higher than the current one, the timelock is set immediately.
    function submitTimelock(uint256 newTimelock) external;

    /// @notice Accepts the pending timelock.
    function acceptTimelock() external;

    /// @notice Revokes the pending timelock.
    /// @dev Does not revert if there is no pending timelock.
    function revokePendingTimelock() external;

    /// @notice Submits a `newSupplyCap` for the vault.
    /// @dev Warning: Reverts if a cap is already pending. Revoke the pending cap to overwrite it.
    /// @dev Warning: Reverts if a vault removal is pending.
    /// @dev In case the new cap is lower than the current one, the cap is set immediately.
    /// @dev For the sake of backwards compatibility, the max allowed cap can either be set to type(uint184).max or type(uint136).max.
    function submitCap(IERC4626 id, uint256 newSupplyCap) external;

    /// @notice Accepts the pending cap of the vault.
    function acceptCap(IERC4626 id) external;

    /// @notice Revokes the pending cap of the vault.
    /// @dev Does not revert if there is no pending cap.
    function revokePendingCap(IERC4626 id) external;

    /// @notice Submits a forced vault removal from the Earn vault, eventually losing all funds supplied to the vault.
    /// @notice This forced removal is expected to be used as an emergency process in case a vault constantly reverts.
    /// To softly remove a sane vault, the curator role is expected to bundle a reallocation that empties the vault
    /// first (using `reallocate`), followed by the removal of the vault (using `updateWithdrawQueue`).
    /// @dev Warning: Reverts for non-zero cap or if there is a pending cap. Successfully submitting a zero cap will
    /// prevent such reverts.
    function submitMarketRemoval(IERC4626 id) external;

    /// @notice Revokes the pending removal of the vault.
    /// @dev Does not revert if there is no pending vault removal.
    function revokePendingMarketRemoval(IERC4626 id) external;

    /// @notice Sets the name of the Earn vault.
    function setName(string memory newName) external;

    /// @notice Sets the symbol of the Earn vault.
    function setSymbol(string memory newSymbol) external;

    /// @notice Submits a `newGuardian`.
    /// @notice Warning: a malicious guardian could disrupt the Earn vault's operation, and would have the power to revoke
    /// any pending guardian.
    /// @dev In case there is no guardian, the guardian is set immediately.
    /// @dev Warning: Submitting a guardian will overwrite the current pending guardian.
    function submitGuardian(address newGuardian) external;

    /// @notice Accepts the pending guardian.
    function acceptGuardian() external;

    /// @notice Revokes the pending guardian.
    function revokePendingGuardian() external;

    /// @notice Sets `newAllocator` as an allocator or not (`newIsAllocator`).
    function setIsAllocator(address newAllocator, bool newIsAllocator) external;

    /// @notice Sets `curator` to `newCurator`.
    function setCurator(address newCurator) external;

    /// @notice Sets the `fee` to `newFee`.
    function setFee(uint256 newFee) external;

    /// @notice Sets `feeRecipient` to `newFeeRecipient`.
    function setFeeRecipient(address newFeeRecipient) external;

    /// @notice Sets `supplyQueue` to `newSupplyQueue`.
    /// @param newSupplyQueue is an array of enabled vaults, and can contain duplicate vaults, but it would only
    /// increase the cost of depositing to the vault.
    function setSupplyQueue(IERC4626[] calldata newSupplyQueue) external;

    /// @notice Updates the withdraw queue. Some vaults can be removed, but no vault can be added.
    /// @notice Removing a vault requires the vault to have 0 supply on it, or to have previously submitted a removal
    /// for this vault (with the function `submitMarketRemoval`).
    /// @notice Warning: Anyone can supply on behalf of the vault so the call to `updateWithdrawQueue` that expects a
    /// vault to be empty can be griefed by a front-run. To circumvent this, the allocator can simply bundle a
    /// reallocation that withdraws max from this vault with a call to `updateWithdrawQueue`.
    /// @dev Warning: Removing a vault with supply will decrease the fee accrued until one of the functions updating
    /// `lastTotalAssets` is triggered (deposit/mint/withdraw/redeem/setFee/setFeeRecipient).
    /// @dev Warning: `updateWithdrawQueue` is not idempotent. Submitting twice the same tx will change the queue twice.
    /// @param indexes The indexes of each vault in the previous withdraw queue, in the new withdraw queue's order.
    function updateWithdrawQueue(uint256[] calldata indexes) external;

    /// @notice Reallocates the vault's liquidity so as to reach a given allocation of assets on each given vault.
    /// @dev The behavior of the reallocation can be altered by state changes, including:
    /// - Deposits on the Earn vault that supplies to vaults that are expected to be supplied to during reallocation.
    /// - Withdrawals from the Earn vault that withdraws from vaults that are expected to be withdrawn from during
    /// reallocation.
    /// - Donations to the vault on vaults that are expected to be supplied to during reallocation.
    /// - Withdrawals from vaults that are expected to be withdrawn from during reallocation.
    /// @dev Sender is expected to pass `assets = type(uint256).max` with the last MarketAllocation of `allocations` to
    /// supply all the remaining withdrawn liquidity, which would ensure that `totalWithdrawn` = `totalSupplied`.
    /// @dev A supply in a reallocation step will make the reallocation revert if the amount is greater than the net
    /// amount from previous steps (i.e. total withdrawn minus total supplied).
    function reallocate(MarketAllocation[] calldata allocations) external;
}

/// @dev This interface is inherited by IEulerEarn so that function signatures are checked by the compiler.
/// @dev Consider using the IEulerEarn interface instead of this one.
interface IEulerEarnStaticTyping is IEulerEarnBase {
    /// @notice Returns the current configuration of each vault.
    function config(IERC4626) external view returns (uint112 balance, uint136 cap, bool enabled, uint64 removableAt);

    /// @notice Returns the pending guardian.
    function pendingGuardian() external view returns (address guardian, uint64 validAt);

    /// @notice Returns the pending cap for each vault.
    function pendingCap(IERC4626) external view returns (uint136 value, uint64 validAt);

    /// @notice Returns the pending timelock.
    function pendingTimelock() external view returns (uint136 value, uint64 validAt);
}

/// @title IEulerEarn
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @dev Use this interface for IEulerEarn to have access to all the functions with the appropriate function
/// signatures.
interface IEulerEarn is IEulerEarnBase, IERC4626, IERC20Permit, IOwnable {
    /// @notice Returns the address of the Ethereum Vault Connector (EVC) used by this contract.
    function EVC() external view returns (address);

    /// @notice Returns the current configuration of each vault.
    function config(IERC4626) external view returns (MarketConfig memory);

    /// @notice Returns the pending guardian.
    function pendingGuardian() external view returns (PendingAddress memory);

    /// @notice Returns the pending cap for each vault.
    function pendingCap(IERC4626) external view returns (PendingUint136 memory);

    /// @notice Returns the pending timelock.
    function pendingTimelock() external view returns (PendingUint136 memory);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

/// @title ErrorsLib
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when the query is invalid.
    error BadQuery();

    /// @notice Thrown when the address passed is the zero address.
    error ZeroAddress();

    /// @notice Thrown when the caller doesn't have the curator role.
    error NotCuratorRole();

    /// @notice Thrown when the caller doesn't have the allocator role.
    error NotAllocatorRole();

    /// @notice Thrown when the caller doesn't have the guardian role.
    error NotGuardianRole();

    /// @notice Thrown when the caller doesn't have the curator nor the guardian role.
    error NotCuratorNorGuardianRole();

    /// @notice Thrown when the vault cannot be set in the supply queue.
    error UnauthorizedMarket(IERC4626 id);

    /// @notice Thrown when submitting a cap for a vault whose underlying asset does not correspond to the underlying
    /// asset of the Earn vault.
    error InconsistentAsset(IERC4626 id);

    /// @notice Thrown when the supply cap has been exceeded on vault during a reallocation of funds.
    error SupplyCapExceeded(IERC4626 id);

    /// @notice Thrown when the fee to set exceeds the maximum fee.
    error MaxFeeExceeded();

    /// @notice Thrown when the value is already set.
    error AlreadySet();

    /// @notice Thrown when a value is already pending.
    error AlreadyPending();

    /// @notice Thrown when submitting the removal of a vault when there is a cap already pending on that vault.
    error PendingCap(IERC4626 id);

    /// @notice Thrown when submitting a cap for a vault with a pending removal.
    error PendingRemoval();

    /// @notice Thrown when submitting a vault removal for a vault with a non zero cap.
    error NonZeroCap();

    /// @notice Thrown when vault is a duplicate in the new withdraw queue to set.
    error DuplicateMarket(IERC4626 id);

    /// @notice Thrown when vault is missing in the updated withdraw queue and the vault has a non-zero cap set.
    error InvalidMarketRemovalNonZeroCap(IERC4626 id);

    /// @notice Thrown when vault is missing in the updated withdraw queue and the vault has a non-zero supply.
    error InvalidMarketRemovalNonZeroSupply(IERC4626 id);

    /// @notice Thrown when vault is missing in the updated withdraw queue and the vault is not yet disabled.
    error InvalidMarketRemovalTimelockNotElapsed(IERC4626 id);

    /// @notice Thrown when there's no pending value to set.
    error NoPendingValue();

    /// @notice Thrown when the requested liquidity cannot be withdrawn from EulerEarn.
    error NotEnoughLiquidity();

    /// @notice Thrown when interacting with a non previously enabled vault.
    error MarketNotEnabled(IERC4626 id);

    /// @notice Thrown when the submitted timelock is above the max timelock.
    error AboveMaxTimelock();

    /// @notice Thrown when the submitted timelock is below the min timelock.
    error BelowMinTimelock();

    /// @notice Thrown when the timelock is not elapsed.
    error TimelockNotElapsed();

    /// @notice Thrown when too many vaults are in the withdraw queue.
    error MaxQueueLengthExceeded();

    /// @notice Thrown when setting the fee to a non zero value while the fee recipient is the zero address.
    error ZeroFeeRecipient();

    /// @notice Thrown when the amount withdrawn is not exactly the amount supplied.
    error InconsistentReallocation();

    /// @notice Thrown when all caps have been reached.
    error AllCapsReached();

    /// @notice Thrown when the `msg.sender` is not the admin nor the owner of the vault.
    error NotAdminNorVaultOwner();

    /// @notice Thrown when the reallocation fee given is wrong.
    error IncorrectFee();

    /// @notice Thrown when `withdrawals` is empty.
    error EmptyWithdrawals();

    /// @notice Thrown when `withdrawals` contains a duplicate or is not sorted.
    error InconsistentWithdrawals();

    /// @notice Thrown when the deposit vault is in `withdrawals`.
    error DepositMarketInWithdrawals();

    /// @notice Thrown when attempting to deposit amount of assets corresponding to zero shares.
    error ZeroShares();

    /// @notice Thrown when attempting to withdraw zero from a vault.
    error WithdrawZero(IERC4626 id);

    /// @notice Thrown when attempting to set max inflow/outflow above the MAX_SETTABLE_FLOW_CAP.
    error MaxSettableFlowCapExceeded();

    /// @notice Thrown when the fee transfer fails.
    error FeeTransferFailed(address feeRecipient);

    /// @notice Thrown when attempting to withdraw more than the available supply of a vault.
    error NotEnoughSupply(IERC4626 id);

    /// @notice Thrown when attempting to withdraw more than the max outflow of a vault.
    error MaxOutflowExceeded(IERC4626 id);

    /// @notice Thrown when attempting to supply more than the max inflow of a vault.
    error MaxInflowExceeded(IERC4626 id);

    /// @notice Thrown when the maximum uint128 is exceeded.
    error MaxUint128Exceeded();

    /// @notice Thrown when withdrawal is attempted to an address known to be an EVC sub-account
    error BadAssetReceiver();
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {FlowCapsConfig} from "../interfaces/IPublicAllocator.sol";

import {IERC4626} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

import {PendingAddress} from "./PendingLib.sol";

/// @title EventsLib
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted when the perspective is set.
    event SetPerspective(address);

    /// @notice Emitted when the name of the Earn vault is set.
    event SetName(string name);

    /// @notice Emitted when the symbol of the Earn vault is set.
    event SetSymbol(string symbol);

    /// @notice Emitted when a pending `newTimelock` is submitted.
    event SubmitTimelock(uint256 newTimelock);

    /// @notice Emitted when `timelock` is set to `newTimelock`.
    event SetTimelock(address indexed caller, uint256 newTimelock);

    /// @notice Emitted `fee` is set to `newFee`.
    event SetFee(address indexed caller, uint256 newFee);

    /// @notice Emitted when a new `newFeeRecipient` is set.
    event SetFeeRecipient(address indexed newFeeRecipient);

    /// @notice Emitted when a pending `newGuardian` is submitted.
    event SubmitGuardian(address indexed newGuardian);

    /// @notice Emitted when `guardian` is set to `newGuardian`.
    event SetGuardian(address indexed caller, address indexed guardian);

    /// @notice Emitted when a pending `cap` is submitted for a vault.
    event SubmitCap(address indexed caller, IERC4626 indexed id, uint256 cap);

    /// @notice Emitted when a new `cap` is set for a vault.
    event SetCap(address indexed caller, IERC4626 indexed id, uint256 cap);

    /// @notice Emitted when the vault's last total assets is updated to `updatedTotalAssets`.
    event UpdateLastTotalAssets(uint256 updatedTotalAssets);

    /// @notice Emitted when the vault's lostAssets is updated to `newLostAssets`.
    event UpdateLostAssets(uint256 newLostAssets);

    /// @notice Emitted when the vault is submitted for removal.
    event SubmitMarketRemoval(address indexed caller, IERC4626 indexed id);

    /// @notice Emitted when `curator` is set to `newCurator`.
    event SetCurator(address indexed newCurator);

    /// @notice Emitted when an `allocator` is set to `isAllocator`.
    event SetIsAllocator(address indexed allocator, bool isAllocator);

    /// @notice Emitted when a `pendingTimelock` is revoked.
    event RevokePendingTimelock(address indexed caller);

    /// @notice Emitted when a `pendingCap` for the vault is revoked.
    event RevokePendingCap(address indexed caller, IERC4626 indexed id);

    /// @notice Emitted when a `pendingGuardian` is revoked.
    event RevokePendingGuardian(address indexed caller);

    /// @notice Emitted when a pending vault removal is revoked.
    event RevokePendingMarketRemoval(address indexed caller, IERC4626 indexed id);

    /// @notice Emitted when the `supplyQueue` is set to `newSupplyQueue`.
    event SetSupplyQueue(address indexed caller, IERC4626[] newSupplyQueue);

    /// @notice Emitted when the `withdrawQueue` is set to `newWithdrawQueue`.
    event SetWithdrawQueue(address indexed caller, IERC4626[] newWithdrawQueue);

    /// @notice Emitted when a reallocation supplies assets to the vault.
    /// @param id The address of the vault.
    /// @param suppliedAssets The amount of assets supplied to the vault.
    /// @param suppliedShares The amount of shares minted.
    event ReallocateSupply(address indexed caller, IERC4626 indexed id, uint256 suppliedAssets, uint256 suppliedShares);

    /// @notice Emitted when a reallocation withdraws assets from the vault.
    /// @param id The address of the vault.
    /// @param withdrawnAssets The amount of assets withdrawn from the vault.
    /// @param withdrawnShares The amount of shares burned.
    event ReallocateWithdraw(
        address indexed caller, IERC4626 indexed id, uint256 withdrawnAssets, uint256 withdrawnShares
    );

    /// @notice Emitted when interest are accrued.
    /// @param newTotalAssets The assets of the vault after accruing the interest but before the interaction.
    /// @param feeShares The shares minted to the fee recipient.
    event AccrueInterest(uint256 newTotalAssets, uint256 feeShares);

    /// @notice Emitted when a new EulerEarn vault is created.
    /// @param eulerEarn The address of the EulerEarn vault.
    /// @param caller The caller of the function.
    /// @param initialOwner The initial owner of the EulerEarn vault.
    /// @param initialTimelock The initial timelock of the EulerEarn vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the EulerEarn vault.
    /// @param symbol The symbol of the EulerEarn vault.
    /// @param salt The salt used for the EulerEarn vault's CREATE2 address.
    event CreateEulerEarn(
        address indexed eulerEarn,
        address indexed caller,
        address initialOwner,
        uint256 initialTimelock,
        address indexed asset,
        string name,
        string symbol,
        bytes32 salt
    );

    /// @notice Emitted during a public reallocation for each withdrawn-from vault.
    event PublicWithdrawal(address indexed sender, address indexed vault, IERC4626 indexed id, uint256 withdrawnAssets);

    /// @notice Emitted at the end of a public reallocation.
    event PublicReallocateTo(
        address indexed sender, address indexed vault, IERC4626 indexed supplyId, uint256 suppliedAssets
    );

    /// @notice Emitted when the admin is set for a vault.
    event SetAdmin(address indexed sender, address indexed vault, address admin);

    /// @notice Emitted when the fee is set for a vault.
    event SetAllocationFee(address indexed sender, address indexed vault, uint256 fee);

    /// @notice Emitted when the fee is transfered for a vault.
    event TransferAllocationFee(
        address indexed sender, address indexed vault, uint256 amount, address indexed feeRecipient
    );

    /// @notice Emitted when the flow caps are set for a vault.
    event SetFlowCaps(address indexed sender, address indexed vault, FlowCapsConfig[] config);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {IERC20Metadata} from "../token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface of the ERC-4626 "Tokenized Vault Standard", as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 */
interface IERC4626 is IERC20, IERC20Metadata {
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @dev Returns the address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     *
     * - MUST be an ERC-20 token contract.
     * - MUST NOT revert.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @dev Returns the total amount of the underlying asset that is “managed” by Vault.
     *
     * - SHOULD include any compounding that occurs from yield.
     * - MUST be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT revert.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @dev Returns the amount of shares that the Vault would exchange for the amount of assets provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
     * scenario where all the conditions are met.
     *
     * - MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     * - MUST NOT show any variations depending on the caller.
     * - MUST NOT reflect slippage or other on-chain conditions, when performing the actual exchange.
     * - MUST NOT revert.
     *
     * NOTE: This calculation MAY NOT reflect the “per-user” price-per-share, and instead should reflect the
     * “average-user’s” price-per-share, meaning what the average user should expect to see when exchanging to and
     * from.
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be deposited into the Vault for the receiver,
     * through a deposit call.
     *
     * - MUST return a limited value if receiver is subject to some deposit limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     * - MUST NOT revert.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of Vault shares that would be minted in a deposit
     *   call in the same transaction. I.e. deposit should return the same or more shares as previewDeposit if called
     *   in the same transaction.
     * - MUST NOT account for deposit limits like those returned from maxDeposit and should always act as though the
     *   deposit would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   deposit execution, and are accounted for during deposit.
     * - MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of the Vault shares that can be minted for the receiver, through a mint call.
     * - MUST return a limited value if receiver is subject to some mint limit.
     * - MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     * - MUST NOT revert.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given
     * current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call
     *   in the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the
     *   same transaction.
     * - MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint
     *   would be accepted, regardless if the user has enough tokens approved, etc.
     * - MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * - MUST emit the Deposit event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the mint
     *   execution, and are accounted for during mint.
     * - MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     *   approving enough underlying tokens to the Vault contract, etc).
     *
     * NOTE: most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * @dev Returns the maximum amount of the underlying asset that can be withdrawn from the owner balance in the
     * Vault, through a withdraw call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     *   call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if
     *   called
     *   in the same transaction.
     * - MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though
     *   the withdrawal would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * @dev Burns shares from owner and sends exactly assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   withdraw execution, and are accounted for during withdraw.
     * - MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * @dev Returns the maximum amount of Vault shares that can be redeemed from the owner balance in the Vault,
     * through a redeem call.
     *
     * - MUST return a limited value if owner is subject to some withdrawal limit or timelock.
     * - MUST return balanceOf(owner) if owner is not subject to any withdrawal limit or timelock.
     * - MUST NOT revert.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares);

    /**
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redemption at the current block,
     * given current on-chain conditions.
     *
     * - MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call
     *   in the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the
     *   same transaction.
     * - MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     *   redemption would be accepted, regardless if the user has enough shares, etc.
     * - MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     * - MUST NOT revert.
     *
     * NOTE: any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * @dev Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * - MUST emit the Withdraw event.
     * - MAY support an additional flow in which the underlying tokens are owned by the Vault contract before the
     *   redeem execution, and are accounted for during redeem.
     * - MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner
     *   not having enough shares, etc).
     *
     * NOTE: some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IEVC} from "../interfaces/IEthereumVaultConnector.sol";
import {ExecutionContext, EC} from "../ExecutionContext.sol";

/// @title EVCUtil
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice This contract is an abstract base contract for interacting with the Ethereum Vault Connector (EVC).
/// It provides utility functions for authenticating the callers in the context of the EVC, a pattern for enforcing the
/// contracts to be called through the EVC.
abstract contract EVCUtil {
    using ExecutionContext for EC;

    uint160 internal constant ACCOUNT_ID_OFFSET = 8;
    IEVC internal immutable evc;

    error EVC_InvalidAddress();
    error NotAuthorized();
    error ControllerDisabled();

    constructor(address _evc) {
        if (_evc == address(0)) revert EVC_InvalidAddress();

        evc = IEVC(_evc);
    }

    /// @notice Returns the address of the Ethereum Vault Connector (EVC) used by this contract.
    /// @return The address of the EVC contract.
    function EVC() external view virtual returns (address) {
        return address(evc);
    }

    /// @notice Ensures that the msg.sender is the EVC by using the EVC callback functionality if necessary.
    /// @dev Optional to use for functions requiring account and vault status checks to enforce predictable behavior.
    /// @dev If this modifier used in conjuction with any other modifier, it must appear as the first (outermost)
    /// modifier of the function.
    modifier callThroughEVC() virtual {
        _callThroughEVC();
        _;
    }

    /// @notice Ensures that the caller is the EVC in the appropriate context.
    /// @dev Should be used for checkAccountStatus and checkVaultStatus functions.
    modifier onlyEVCWithChecksInProgress() virtual {
        _onlyEVCWithChecksInProgress();
        _;
    }

    /// @notice Ensures a standard authentication path on the EVC allowing the account owner or any of its EVC accounts.
    /// @dev This modifier checks if the caller is the EVC and if so, verifies the execution context.
    /// It reverts if the operator is authenticated, control collateral is in progress, or checks are in progress.
    /// @dev This modifier must not be used on functions utilized by liquidation flows, i.e. transfer or withdraw.
    /// @dev This modifier must not be used on checkAccountStatus and checkVaultStatus functions.
    /// @dev This modifier can be used on access controlled functions to prevent non-standard authentication paths on
    /// the EVC.
    modifier onlyEVCAccount() virtual {
        _authenticateCallerWithStandardContextState(false);
        _;
    }

    /// @notice Ensures a standard authentication path on the EVC.
    /// @dev This modifier checks if the caller is the EVC and if so, verifies the execution context.
    /// It reverts if the operator is authenticated, control collateral is in progress, or checks are in progress.
    /// It reverts if the authenticated account owner is known and it is not the account owner.
    /// @dev It assumes that if the caller is not the EVC, the caller is the account owner.
    /// @dev This modifier must not be used on functions utilized by liquidation flows, i.e. transfer or withdraw.
    /// @dev This modifier must not be used on checkAccountStatus and checkVaultStatus functions.
    /// @dev This modifier can be used on access controlled functions to prevent non-standard authentication paths on
    /// the EVC.
    modifier onlyEVCAccountOwner() virtual {
        _authenticateCallerWithStandardContextState(true);
        _;
    }

    /// @notice Checks whether the specified account and the other account have the same owner.
    /// @dev The function is used to check whether one account is authorized to perform operations on behalf of the
    /// other. Accounts are considered to have a common owner if they share the first 19 bytes of their address.
    /// @param account The address of the account that is being checked.
    /// @param otherAccount The address of the other account that is being checked.
    /// @return A boolean flag that indicates whether the accounts have the same owner.
    function _haveCommonOwner(address account, address otherAccount) internal pure returns (bool) {
        bool result;
        assembly {
            result := lt(xor(account, otherAccount), 0x100)
        }
        return result;
    }

    /// @notice Returns the address prefix of the specified account.
    /// @dev The address prefix is the first 19 bytes of the account address.
    /// @param account The address of the account whose address prefix is being retrieved.
    /// @return A bytes19 value that represents the address prefix of the account.
    function _getAddressPrefix(address account) internal pure returns (bytes19) {
        return bytes19(uint152(uint160(account) >> ACCOUNT_ID_OFFSET));
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual returns (address) {
        address sender = msg.sender;

        if (sender == address(evc)) {
            (sender,) = evc.getCurrentOnBehalfOfAccount(address(0));
        }

        return sender;
    }

    /// @notice Retrieves the message sender in the context of the EVC for a borrow operation.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC. This function reverts if this contract is not enabled
    /// as a controller for the account on behalf of which the operation is being executed.
    /// @return The address of the message sender.
    function _msgSenderForBorrow() internal view virtual returns (address) {
        address sender = msg.sender;
        bool controllerEnabled;

        if (sender == address(evc)) {
            (sender, controllerEnabled) = evc.getCurrentOnBehalfOfAccount(address(this));
        } else {
            controllerEnabled = evc.isControllerEnabled(sender, address(this));
        }

        if (!controllerEnabled) {
            revert ControllerDisabled();
        }

        return sender;
    }

    /// @notice Retrieves the message sender, ensuring it's any EVC account meaning that the execution context is in a
    /// standard state (not operator authenticated, not control collateral in progress, not checks in progress).
    /// @dev This function must not be used on functions utilized by liquidation flows, i.e. transfer or withdraw.
    /// @dev This function must not be used on checkAccountStatus and checkVaultStatus functions.
    /// @dev This function can be used on access controlled functions to prevent non-standard authentication paths on
    /// the EVC.
    /// @return The address of the message sender.
    function _msgSenderOnlyEVCAccount() internal view returns (address) {
        return _authenticateCallerWithStandardContextState(false);
    }

    /// @notice Retrieves the message sender, ensuring it's the EVC account owner and that the execution context is in a
    /// standard state (not operator authenticated, not control collateral in progress, not checks in progress).
    /// @dev It assumes that if the caller is not the EVC, the caller is the account owner.
    /// @dev This function must not be used on functions utilized by liquidation flows, i.e. transfer or withdraw.
    /// @dev This function must not be used on checkAccountStatus and checkVaultStatus functions.
    /// @dev This function can be used on access controlled functions to prevent non-standard authentication paths on
    /// the EVC.
    /// @return The address of the message sender.
    function _msgSenderOnlyEVCAccountOwner() internal view returns (address) {
        return _authenticateCallerWithStandardContextState(true);
    }

    /// @notice Calls the current external function through the EVC.
    /// @dev This function is used to route the current call through the EVC if it's not already coming from the EVC. It
    /// makes the EVC set the execution context and call back this contract with unchanged calldata. msg.sender is used
    /// as the onBehalfOfAccount.
    /// @dev This function shall only be used by the callThroughEVC modifier.
    function _callThroughEVC() internal {
        address _evc = address(evc);
        if (msg.sender == _evc) return;

        assembly {
            mstore(0, 0x1f8b521500000000000000000000000000000000000000000000000000000000) // EVC.call selector
            mstore(4, address()) // EVC.call 1st argument - address(this)
            mstore(36, caller()) // EVC.call 2nd argument - msg.sender
            mstore(68, callvalue()) // EVC.call 3rd argument - msg.value
            mstore(100, 128) // EVC.call 4th argument - msg.data, offset to the start of encoding - 128 bytes
            mstore(132, calldatasize()) // msg.data length
            calldatacopy(164, 0, calldatasize()) // original calldata

            // abi encoded bytes array should be zero padded so its length is a multiple of 32
            // store zero word after msg.data bytes and round up calldatasize to nearest multiple of 32
            mstore(add(164, calldatasize()), 0)
            let result := call(gas(), _evc, callvalue(), 0, add(164, and(add(calldatasize(), 31), not(31))), 0, 0)

            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(64, sub(returndatasize(), 64)) } // strip bytes encoding from call return
        }
    }

    /// @notice Ensures that the function is called only by the EVC during the checks phase
    /// @dev Reverts if the caller is not the EVC or if checks are not in progress.
    function _onlyEVCWithChecksInProgress() internal view {
        if (msg.sender != address(evc) || !evc.areChecksInProgress()) {
            revert NotAuthorized();
        }
    }

    /// @notice Ensures that the function is called only by the EVC account owner or any of its EVC accounts
    /// @dev This function checks if the caller is the EVC and if so, verifies that the execution context is not in a
    /// special state (operator authenticated, collateral control in progress, or checks in progress). If
    /// onlyAccountOwner is true and the owner was already registered on the EVC, it verifies that the onBehalfOfAccount
    /// is the owner. If onlyAccountOwner is false, it allows any EVC account of the owner to call the function.
    /// @param onlyAccountOwner If true, only allows the account owner; if false, allows any EVC account of the owner
    /// @return The address of the message sender.
    function _authenticateCallerWithStandardContextState(bool onlyAccountOwner) internal view returns (address) {
        if (msg.sender == address(evc)) {
            EC ec = EC.wrap(evc.getRawExecutionContext());

            if (ec.isOperatorAuthenticated() || ec.isControlCollateralInProgress() || ec.areChecksInProgress()) {
                revert NotAuthorized();
            }

            address onBehalfOfAccount = ec.getOnBehalfOfAccount();

            if (onlyAccountOwner) {
                address owner = evc.getAccountOwner(onBehalfOfAccount);

                if (owner != address(0) && owner != onBehalfOfAccount) {
                    revert NotAuthorized();
                }
            }

            return onBehalfOfAccount;
        }

        return msg.sender;
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IEulerEarn} from "./IEulerEarn.sol";

/// @title IEulerEarnFactory
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @notice Interface of EulerEarn's factory.
interface IEulerEarnFactory {
    /// @notice The address of the Permit2 contract.
    function permit2Address() external view returns (address);

    /// @notice The address of the supported perspective contract.
    function supportedPerspective() external view returns (address);

    /// @notice Whether a vault was created with the factory.
    function isVault(address target) external view returns (bool);

    /// @notice Fetch the length of the deployed proxies list
    /// @return The length of the proxy list array
    function getVaultListLength() external view returns (uint256);

    /// @notice Get a slice of the deployed proxies array
    /// @param start Start index of the slice
    /// @param end End index of the slice
    /// @return list An array containing the slice of the proxy list
    function getVaultListSlice(uint256 start, uint256 end) external view returns (address[] memory list);

    /// @notice Sets the perspective contract.
    /// @param _perspective The address of the new perspective contract.
    function setPerspective(address _perspective) external;

    /// @notice Whether a strategy is allowed to be used by the Earn vault.
    /// @dev Warning: Only allow trusted, correctly implemented ERC4626 strategies to be used by the Earn vault.
    /// @dev Warning: Allowed strategies must not be prone to the first-depositor attack.
    /// @dev Warning: To prevent exchange rate manipulation, it is recommended that the allowed strategies are not empty or have sufficient protection.
    function isStrategyAllowed(address id) external view returns (bool);

    /// @notice Creates a new EulerEarn vault.
    /// @param initialOwner The owner of the vault.
    /// @param initialTimelock The initial timelock of the vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param salt The salt to use for the EulerEarn vault's CREATE2 address.
    function createEulerEarn(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IEulerEarn eulerEarn);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[ERC-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC-20 allowance (see {IERC20-allowance}) by
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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

struct MarketConfig {
    /// @notice The current balance of vault shares.
    uint112 balance;
    /// @notice The maximum amount of assets that can be allocated to the vault.
    uint136 cap;
    /// @notice Whether the vault is in the withdraw queue.
    bool enabled;
    /// @notice The timestamp at which the vault can be instantly removed from the withdraw queue.
    uint64 removableAt;
}

struct PendingUint136 {
    /// @notice The pending value to set.
    uint136 value;
    /// @notice The timestamp at which the pending value becomes valid.
    uint64 validAt;
}

struct PendingAddress {
    /// @notice The pending value to set.
    address value;
    /// @notice The timestamp at which the pending value becomes valid.
    uint64 validAt;
}

/// @title PendingLib
/// @author Forked with gratitude from Morpho Labs. Inspired by Silo Labs.
/// @custom:contact security@morpho.org
/// @custom:contact security@euler.xyz
/// @notice Library to manage pending values and their validity timestamp.
library PendingLib {
    /// @dev Updates `pending`'s value to `newValue` and its corresponding `validAt` timestamp.
    /// @dev Assumes `timelock` <= `MAX_TIMELOCK`.
    function update(PendingUint136 storage pending, uint136 newValue, uint256 timelock) internal {
        pending.value = newValue;
        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        pending.validAt = uint64(block.timestamp + timelock);
    }

    /// @dev Updates `pending`'s value to `newValue` and its corresponding `validAt` timestamp.
    /// @dev Assumes `timelock` <= `MAX_TIMELOCK`.
    function update(PendingAddress storage pending, address newValue, uint256 timelock) internal {
        pending.value = newValue;
        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        pending.validAt = uint64(block.timestamp + timelock);
    }
}

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";

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

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

/// @title IEVC
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice This interface defines the methods for the Ethereum Vault Connector.
interface IEVC {
    /// @notice A struct representing a batch item.
    /// @dev Each batch item represents a single operation to be performed within a checks deferred context.
    struct BatchItem {
        /// @notice The target contract to be called.
        address targetContract;
        /// @notice The account on behalf of which the operation is to be performed. msg.sender must be authorized to
        /// act on behalf of this account. Must be address(0) if the target contract is the EVC itself.
        address onBehalfOfAccount;
        /// @notice The amount of value to be forwarded with the call. If the value is type(uint256).max, the whole
        /// balance of the EVC contract will be forwarded. Must be 0 if the target contract is the EVC itself.
        uint256 value;
        /// @notice The encoded data which is called on the target contract.
        bytes data;
    }

    /// @notice A struct representing the result of a batch item operation.
    /// @dev Used only for simulation purposes.
    struct BatchItemResult {
        /// @notice A boolean indicating whether the operation was successful.
        bool success;
        /// @notice The result of the operation.
        bytes result;
    }

    /// @notice A struct representing the result of the account or vault status check.
    /// @dev Used only for simulation purposes.
    struct StatusCheckResult {
        /// @notice The address of the account or vault for which the check was performed.
        address checkedAddress;
        /// @notice A boolean indicating whether the status of the account or vault is valid.
        bool isValid;
        /// @notice The result of the check.
        bytes result;
    }

    /// @notice Returns current raw execution context.
    /// @dev When checks in progress, on behalf of account is always address(0).
    /// @return context Current raw execution context.
    function getRawExecutionContext() external view returns (uint256 context);

    /// @notice Returns an account on behalf of which the operation is being executed at the moment and whether the
    /// controllerToCheck is an enabled controller for that account.
    /// @dev This function should only be used by external smart contracts if msg.sender is the EVC. Otherwise, the
    /// account address returned must not be trusted.
    /// @dev When checks in progress, on behalf of account is always address(0). When address is zero, the function
    /// reverts to protect the consumer from ever relying on the on behalf of account address which is in its default
    /// state.
    /// @param controllerToCheck The address of the controller for which it is checked whether it is an enabled
    /// controller for the account on behalf of which the operation is being executed at the moment.
    /// @return onBehalfOfAccount An account that has been authenticated and on behalf of which the operation is being
    /// executed at the moment.
    /// @return controllerEnabled A boolean value that indicates whether controllerToCheck is an enabled controller for
    /// the account on behalf of which the operation is being executed at the moment. Always false if controllerToCheck
    /// is address(0).
    function getCurrentOnBehalfOfAccount(address controllerToCheck)
        external
        view
        returns (address onBehalfOfAccount, bool controllerEnabled);

    /// @notice Checks if checks are deferred.
    /// @return A boolean indicating whether checks are deferred.
    function areChecksDeferred() external view returns (bool);

    /// @notice Checks if checks are in progress.
    /// @return A boolean indicating whether checks are in progress.
    function areChecksInProgress() external view returns (bool);

    /// @notice Checks if control collateral is in progress.
    /// @return A boolean indicating whether control collateral is in progress.
    function isControlCollateralInProgress() external view returns (bool);

    /// @notice Checks if an operator is authenticated.
    /// @return A boolean indicating whether an operator is authenticated.
    function isOperatorAuthenticated() external view returns (bool);

    /// @notice Checks if a simulation is in progress.
    /// @return A boolean indicating whether a simulation is in progress.
    function isSimulationInProgress() external view returns (bool);

    /// @notice Checks whether the specified account and the other account have the same owner.
    /// @dev The function is used to check whether one account is authorized to perform operations on behalf of the
    /// other. Accounts are considered to have a common owner if they share the first 19 bytes of their address.
    /// @param account The address of the account that is being checked.
    /// @param otherAccount The address of the other account that is being checked.
    /// @return A boolean flag that indicates whether the accounts have the same owner.
    function haveCommonOwner(address account, address otherAccount) external pure returns (bool);

    /// @notice Returns the address prefix of the specified account.
    /// @dev The address prefix is the first 19 bytes of the account address.
    /// @param account The address of the account whose address prefix is being retrieved.
    /// @return A bytes19 value that represents the address prefix of the account.
    function getAddressPrefix(address account) external pure returns (bytes19);

    /// @notice Returns the owner for the specified account.
    /// @dev The function returns address(0) if the owner is not registered. Registration of the owner happens on the
    /// initial
    /// interaction with the EVC that requires authentication of an owner.
    /// @param account The address of the account whose owner is being retrieved.
    /// @return owner The address of the account owner. An account owner is an EOA/smart contract which address matches
    /// the first 19 bytes of the account address.
    function getAccountOwner(address account) external view returns (address);

    /// @notice Checks if lockdown mode is enabled for a given address prefix.
    /// @param addressPrefix The address prefix to check for lockdown mode status.
    /// @return A boolean indicating whether lockdown mode is enabled.
    function isLockdownMode(bytes19 addressPrefix) external view returns (bool);

    /// @notice Checks if permit functionality is disabled for a given address prefix.
    /// @param addressPrefix The address prefix to check for permit functionality status.
    /// @return A boolean indicating whether permit functionality is disabled.
    function isPermitDisabledMode(bytes19 addressPrefix) external view returns (bool);

    /// @notice Returns the current nonce for a given address prefix and nonce namespace.
    /// @dev Each nonce namespace provides 256 bit nonce that has to be used sequentially. There's no requirement to use
    /// all the nonces for a given nonce namespace before moving to the next one which allows to use permit messages in
    /// a non-sequential manner.
    /// @param addressPrefix The address prefix for which the nonce is being retrieved.
    /// @param nonceNamespace The nonce namespace for which the nonce is being retrieved.
    /// @return nonce The current nonce for the given address prefix and nonce namespace.
    function getNonce(bytes19 addressPrefix, uint256 nonceNamespace) external view returns (uint256 nonce);

    /// @notice Returns the bit field for a given address prefix and operator.
    /// @dev The bit field is used to store information about authorized operators for a given address prefix. Each bit
    /// in the bit field corresponds to one account belonging to the same owner. If the bit is set, the operator is
    /// authorized for the account.
    /// @param addressPrefix The address prefix for which the bit field is being retrieved.
    /// @param operator The address of the operator for which the bit field is being retrieved.
    /// @return operatorBitField The bit field for the given address prefix and operator. The bit field defines which
    /// accounts the operator is authorized for. It is a 256-position binary array like 0...010...0, marking the account
    /// positionally in a uint256. The position in the bit field corresponds to the account ID (0-255), where 0 is the
    /// owner account's ID.
    function getOperator(bytes19 addressPrefix, address operator) external view returns (uint256 operatorBitField);

    /// @notice Returns whether a given operator has been authorized for a given account.
    /// @param account The address of the account whose operator is being checked.
    /// @param operator The address of the operator that is being checked.
    /// @return authorized A boolean value that indicates whether the operator is authorized for the account.
    function isAccountOperatorAuthorized(address account, address operator) external view returns (bool authorized);

    /// @notice Enables or disables lockdown mode for a given address prefix.
    /// @dev This function can only be called by the owner of the address prefix. To disable this mode, the EVC
    /// must be called directly. It is not possible to disable this mode by using checks-deferrable call or
    /// permit message.
    /// @param addressPrefix The address prefix for which the lockdown mode is being set.
    /// @param enabled A boolean indicating whether to enable or disable lockdown mode.
    function setLockdownMode(bytes19 addressPrefix, bool enabled) external payable;

    /// @notice Enables or disables permit functionality for a given address prefix.
    /// @dev This function can only be called by the owner of the address prefix. To disable this mode, the EVC
    /// must be called directly. It is not possible to disable this mode by using checks-deferrable call or (by
    /// definition) permit message. To support permit functionality by default, note that the logic was inverted here. To
    /// disable  the permit functionality, one must pass true as the second argument. To enable the permit
    /// functionality, one must pass false as the second argument.
    /// @param addressPrefix The address prefix for which the permit functionality is being set.
    /// @param enabled A boolean indicating whether to enable or disable the disable-permit mode.
    function setPermitDisabledMode(bytes19 addressPrefix, bool enabled) external payable;

    /// @notice Sets the nonce for a given address prefix and nonce namespace.
    /// @dev This function can only be called by the owner of the address prefix. Each nonce namespace provides a 256
    /// bit nonce that has to be used sequentially. There's no requirement to use all the nonces for a given nonce
    /// namespace before moving to the next one which allows the use of permit messages in a non-sequential manner. To
    /// invalidate signed permit messages, set the nonce for a given nonce namespace accordingly. To invalidate all the
    /// permit messages for a given nonce namespace, set the nonce to type(uint).max.
    /// @param addressPrefix The address prefix for which the nonce is being set.
    /// @param nonceNamespace The nonce namespace for which the nonce is being set.
    /// @param nonce The new nonce for the given address prefix and nonce namespace.
    function setNonce(bytes19 addressPrefix, uint256 nonceNamespace, uint256 nonce) external payable;

    /// @notice Sets the bit field for a given address prefix and operator.
    /// @dev This function can only be called by the owner of the address prefix. Each bit in the bit field corresponds
    /// to one account belonging to the same owner. If the bit is set, the operator is authorized for the account.
    /// @param addressPrefix The address prefix for which the bit field is being set.
    /// @param operator The address of the operator for which the bit field is being set. Can neither be the EVC address
    /// nor an address belonging to the same address prefix.
    /// @param operatorBitField The new bit field for the given address prefix and operator. Reverts if the provided
    /// value is equal to the currently stored value.
    function setOperator(bytes19 addressPrefix, address operator, uint256 operatorBitField) external payable;

    /// @notice Authorizes or deauthorizes an operator for the account.
    /// @dev Only the owner or authorized operator of the account can call this function. An operator is an address that
    /// can perform actions for an account on behalf of the owner. If it's an operator calling this function, it can
    /// only deauthorize itself.
    /// @param account The address of the account whose operator is being set or unset.
    /// @param operator The address of the operator that is being installed or uninstalled. Can neither be the EVC
    /// address nor an address belonging to the same owner as the account.
    /// @param authorized A boolean value that indicates whether the operator is being authorized or deauthorized.
    /// Reverts if the provided value is equal to the currently stored value.
    function setAccountOperator(address account, address operator, bool authorized) external payable;

    /// @notice Returns an array of collaterals enabled for an account.
    /// @dev A collateral is a vault for which an account's balances are under the control of the currently enabled
    /// controller vault.
    /// @param account The address of the account whose collaterals are being queried.
    /// @return An array of addresses that are enabled collaterals for the account.
    function getCollaterals(address account) external view returns (address[] memory);

    /// @notice Returns whether a collateral is enabled for an account.
    /// @dev A collateral is a vault for which account's balances are under the control of the currently enabled
    /// controller vault.
    /// @param account The address of the account that is being checked.
    /// @param vault The address of the collateral that is being checked.
    /// @return A boolean value that indicates whether the vault is an enabled collateral for the account or not.
    function isCollateralEnabled(address account, address vault) external view returns (bool);

    /// @notice Enables a collateral for an account.
    /// @dev A collaterals is a vault for which account's balances are under the control of the currently enabled
    /// controller vault. Only the owner or an operator of the account can call this function. Unless it's a duplicate,
    /// the collateral is added to the end of the array. There can be at most 10 unique collaterals enabled at a time.
    /// Account status checks are performed.
    /// @param account The account address for which the collateral is being enabled.
    /// @param vault The address being enabled as a collateral.
    function enableCollateral(address account, address vault) external payable;

    /// @notice Disables a collateral for an account.
    /// @dev This function does not preserve the order of collaterals in the array obtained using the getCollaterals
    /// function; the order may change. A collateral is a vault for which account’s balances are under the control of
    /// the currently enabled controller vault. Only the owner or an operator of the account can call this function.
    /// Disabling a collateral might change the order of collaterals in the array obtained using getCollaterals
    /// function. Account status checks are performed.
    /// @param account The account address for which the collateral is being disabled.
    /// @param vault The address of a collateral being disabled.
    function disableCollateral(address account, address vault) external payable;

    /// @notice Swaps the position of two collaterals so that they appear switched in the array of collaterals for a
    /// given account obtained by calling getCollaterals function.
    /// @dev A collateral is a vault for which account’s balances are under the control of the currently enabled
    /// controller vault. Only the owner or an operator of the account can call this function. The order of collaterals
    /// can be changed by specifying the indices of the two collaterals to be swapped. Indices are zero-based and must
    /// be in the range of 0 to the number of collaterals minus 1. index1 must be lower than index2. Account status
    /// checks are performed.
    /// @param account The address of the account for which the collaterals are being reordered.
    /// @param index1 The index of the first collateral to be swapped.
    /// @param index2 The index of the second collateral to be swapped.
    function reorderCollaterals(address account, uint8 index1, uint8 index2) external payable;

    /// @notice Returns an array of enabled controllers for an account.
    /// @dev A controller is a vault that has been chosen for an account to have special control over the account's
    /// balances in enabled collaterals vaults. A user can have multiple controllers during a call execution, but at
    /// most one can be selected when the account status check is performed.
    /// @param account The address of the account whose controllers are being queried.
    /// @return An array of addresses that are the enabled controllers for the account.
    function getControllers(address account) external view returns (address[] memory);

    /// @notice Returns whether a controller is enabled for an account.
    /// @dev A controller is a vault that has been chosen for an account to have special control over account’s
    /// balances in the enabled collaterals vaults.
    /// @param account The address of the account that is being checked.
    /// @param vault The address of the controller that is being checked.
    /// @return A boolean value that indicates whether the vault is enabled controller for the account or not.
    function isControllerEnabled(address account, address vault) external view returns (bool);

    /// @notice Enables a controller for an account.
    /// @dev A controller is a vault that has been chosen for an account to have special control over account’s
    /// balances in the enabled collaterals vaults. Only the owner or an operator of the account can call this function.
    /// Unless it's a duplicate, the controller is added to the end of the array. Transiently, there can be at most 10
    /// unique controllers enabled at a time, but at most one can be enabled after the outermost checks-deferrable
    /// call concludes. Account status checks are performed.
    /// @param account The address for which the controller is being enabled.
    /// @param vault The address of the controller being enabled.
    function enableController(address account, address vault) external payable;

    /// @notice Disables a controller for an account.
    /// @dev A controller is a vault that has been chosen for an account to have special control over account’s
    /// balances in the enabled collaterals vaults. Only the vault itself can call this function. Disabling a controller
    /// might change the order of controllers in the array obtained using getControllers function. Account status checks
    /// are performed.
    /// @param account The address for which the calling controller is being disabled.
    function disableController(address account) external payable;

    /// @notice Executes signed arbitrary data by self-calling into the EVC.
    /// @dev Low-level call function is used to execute the arbitrary data signed by the owner or the operator on the
    /// EVC contract. During that call, EVC becomes msg.sender.
    /// @param signer The address signing the permit message (ECDSA) or verifying the permit message signature
    /// (ERC-1271). It's also the owner or the operator of all the accounts for which authentication will be needed
    /// during the execution of the arbitrary data call.
    /// @param sender The address of the msg.sender which is expected to execute the data signed by the signer. If
    /// address(0) is passed, the msg.sender is ignored.
    /// @param nonceNamespace The nonce namespace for which the nonce is being used.
    /// @param nonce The nonce for the given account and nonce namespace. A valid nonce value is considered to be the
    /// value currently stored and can take any value between 0 and type(uint256).max - 1.
    /// @param deadline The timestamp after which the permit is considered expired.
    /// @param value The amount of value to be forwarded with the call. If the value is type(uint256).max, the whole
    /// balance of the EVC contract will be forwarded.
    /// @param data The encoded data which is self-called on the EVC contract.
    /// @param signature The signature of the data signed by the signer.
    function permit(
        address signer,
        address sender,
        uint256 nonceNamespace,
        uint256 nonce,
        uint256 deadline,
        uint256 value,
        bytes calldata data,
        bytes calldata signature
    ) external payable;

    /// @notice Calls into a target contract as per data encoded.
    /// @dev This function defers the account and vault status checks (it's a checks-deferrable call). If the outermost
    /// call ends, the account and vault status checks are performed.
    /// @dev This function can be used to interact with any contract while checks are deferred. If the target contract
    /// is msg.sender, msg.sender is called back with the calldata provided and the context set up according to the
    /// account provided. If the target contract is not msg.sender, only the owner or the operator of the account
    /// provided can call this function.
    /// @dev This function can be used to recover the remaining value from the EVC contract.
    /// @param targetContract The address of the contract to be called.
    /// @param onBehalfOfAccount  If the target contract is msg.sender, the address of the account which will be set
    /// in the context. It assumes msg.sender has authenticated the account themselves. If the target contract is
    /// not msg.sender, the address of the account for which it is checked whether msg.sender is authorized to act
    /// on behalf of.
    /// @param value The amount of value to be forwarded with the call. If the value is type(uint256).max, the whole
    /// balance of the EVC contract will be forwarded.
    /// @param data The encoded data which is called on the target contract.
    /// @return result The result of the call.
    function call(
        address targetContract,
        address onBehalfOfAccount,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result);

    /// @notice For a given account, calls into one of the enabled collateral vaults from the currently enabled
    /// controller vault as per data encoded.
    /// @dev This function defers the account and vault status checks (it's a checks-deferrable call). If the outermost
    /// call ends, the account and vault status checks are performed.
    /// @dev This function can be used to interact with any contract while checks are deferred as long as the contract
    /// is enabled as a collateral of the account and the msg.sender is the only enabled controller of the account.
    /// @param targetCollateral The collateral address to be called.
    /// @param onBehalfOfAccount The address of the account for which it is checked whether msg.sender is authorized to
    /// act on behalf.
    /// @param value The amount of value to be forwarded with the call. If the value is type(uint256).max, the whole
    /// balance of the EVC contract will be forwarded.
    /// @param data The encoded data which is called on the target collateral.
    /// @return result The result of the call.
    function controlCollateral(
        address targetCollateral,
        address onBehalfOfAccount,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result);

    /// @notice Executes multiple calls into the target contracts while checks deferred as per batch items provided.
    /// @dev This function defers the account and vault status checks (it's a checks-deferrable call). If the outermost
    /// call ends, the account and vault status checks are performed.
    /// @dev The authentication rules for each batch item are the same as for the call function.
    /// @param items An array of batch items to be executed.
    function batch(BatchItem[] calldata items) external payable;

    /// @notice Executes multiple calls into the target contracts while checks deferred as per batch items provided.
    /// @dev This function always reverts as it's only used for simulation purposes. This function cannot be called
    /// within a checks-deferrable call.
    /// @param items An array of batch items to be executed.
    function batchRevert(BatchItem[] calldata items) external payable;

    /// @notice Executes multiple calls into the target contracts while checks deferred as per batch items provided.
    /// @dev This function does not modify state and should only be used for simulation purposes. This function cannot
    /// be called within a checks-deferrable call.
    /// @param items An array of batch items to be executed.
    /// @return batchItemsResult An array of batch item results for each item.
    /// @return accountsStatusCheckResult An array of account status check results for each account.
    /// @return vaultsStatusCheckResult An array of vault status check results for each vault.
    function batchSimulation(BatchItem[] calldata items)
        external
        payable
        returns (
            BatchItemResult[] memory batchItemsResult,
            StatusCheckResult[] memory accountsStatusCheckResult,
            StatusCheckResult[] memory vaultsStatusCheckResult
        );

    /// @notice Retrieves the timestamp of the last successful account status check performed for a specific account.
    /// @dev This function reverts if the checks are in progress.
    /// @dev The account status check is considered to be successful if it calls into the selected controller vault and
    /// obtains expected magic value. This timestamp does not change if the account status is considered valid when no
    /// controller enabled. When consuming, one might need to ensure that the account status check is not deferred at
    /// the moment.
    /// @param account The address of the account for which the last status check timestamp is being queried.
    /// @return The timestamp of the last status check as a uint256.
    function getLastAccountStatusCheckTimestamp(address account) external view returns (uint256);

    /// @notice Checks whether the status check is deferred for a given account.
    /// @dev This function reverts if the checks are in progress.
    /// @param account The address of the account for which it is checked whether the status check is deferred.
    /// @return A boolean flag that indicates whether the status check is deferred or not.
    function isAccountStatusCheckDeferred(address account) external view returns (bool);

    /// @notice Checks the status of an account and reverts if it is not valid.
    /// @dev If checks deferred, the account is added to the set of accounts to be checked at the end of the outermost
    /// checks-deferrable call. There can be at most 10 unique accounts added to the set at a time. Account status
    /// check is performed by calling into the selected controller vault and passing the array of currently enabled
    /// collaterals. If controller is not selected, the account is always considered valid.
    /// @param account The address of the account to be checked.
    function requireAccountStatusCheck(address account) external payable;

    /// @notice Forgives previously deferred account status check.
    /// @dev Account address is removed from the set of addresses for which status checks are deferred. This function
    /// can only be called by the currently enabled controller of a given account. Depending on the vault
    /// implementation, may be needed in the liquidation flow.
    /// @param account The address of the account for which the status check is forgiven.
    function forgiveAccountStatusCheck(address account) external payable;

    /// @notice Checks whether the status check is deferred for a given vault.
    /// @dev This function reverts if the checks are in progress.
    /// @param vault The address of the vault for which it is checked whether the status check is deferred.
    /// @return A boolean flag that indicates whether the status check is deferred or not.
    function isVaultStatusCheckDeferred(address vault) external view returns (bool);

    /// @notice Checks the status of a vault and reverts if it is not valid.
    /// @dev If checks deferred, the vault is added to the set of vaults to be checked at the end of the outermost
    /// checks-deferrable call. There can be at most 10 unique vaults added to the set at a time. This function can
    /// only be called by the vault itself.
    function requireVaultStatusCheck() external payable;

    /// @notice Forgives previously deferred vault status check.
    /// @dev Vault address is removed from the set of addresses for which status checks are deferred. This function can
    /// only be called by the vault itself.
    function forgiveVaultStatusCheck() external payable;

    /// @notice Checks the status of an account and a vault and reverts if it is not valid.
    /// @dev If checks deferred, the account and the vault are added to the respective sets of accounts and vaults to be
    /// checked at the end of the outermost checks-deferrable call. Account status check is performed by calling into
    /// selected controller vault and passing the array of currently enabled collaterals. If controller is not selected,
    /// the account is always considered valid. This function can only be called by the vault itself.
    /// @param account The address of the account to be checked.
    function requireAccountAndVaultStatusCheck(address account) external payable;
}

// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

type EC is uint256;

/// @title ExecutionContext
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice This library provides functions for managing the execution context in the Ethereum Vault Connector.
/// @dev The execution context is a bit field that stores the following information:
/// @dev - on behalf of account - an account on behalf of which the currently executed operation is being performed
/// @dev - checks deferred flag - used to indicate whether checks are deferred
/// @dev - checks in progress flag - used to indicate that the account/vault status checks are in progress. This flag is
/// used to prevent re-entrancy.
/// @dev - control collateral in progress flag - used to indicate that the control collateral is in progress. This flag
/// is used to prevent re-entrancy.
/// @dev - operator authenticated flag - used to indicate that the currently executed operation is being performed by
/// the account operator
/// @dev - simulation flag - used to indicate that the currently executed batch call is a simulation
/// @dev - stamp - dummy value for optimization purposes
library ExecutionContext {
    uint256 internal constant ON_BEHALF_OF_ACCOUNT_MASK =
        0x000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 internal constant CHECKS_DEFERRED_MASK = 0x0000000000000000000000FF0000000000000000000000000000000000000000;
    uint256 internal constant CHECKS_IN_PROGRESS_MASK =
        0x00000000000000000000FF000000000000000000000000000000000000000000;
    uint256 internal constant CONTROL_COLLATERAL_IN_PROGRESS_LOCK_MASK =
        0x000000000000000000FF00000000000000000000000000000000000000000000;
    uint256 internal constant OPERATOR_AUTHENTICATED_MASK =
        0x0000000000000000FF0000000000000000000000000000000000000000000000;
    uint256 internal constant SIMULATION_MASK = 0x00000000000000FF000000000000000000000000000000000000000000000000;
    uint256 internal constant STAMP_OFFSET = 200;

    // None of the functions below modifies the state. All the functions operate on the copy
    // of the execution context and return its modified value as a result. In order to update
    // one should use the result of the function call as a new execution context value.

    function getOnBehalfOfAccount(EC self) internal pure returns (address result) {
        result = address(uint160(EC.unwrap(self) & ON_BEHALF_OF_ACCOUNT_MASK));
    }

    function setOnBehalfOfAccount(EC self, address account) internal pure returns (EC result) {
        result = EC.wrap((EC.unwrap(self) & ~ON_BEHALF_OF_ACCOUNT_MASK) | uint160(account));
    }

    function areChecksDeferred(EC self) internal pure returns (bool result) {
        result = EC.unwrap(self) & CHECKS_DEFERRED_MASK != 0;
    }

    function setChecksDeferred(EC self) internal pure returns (EC result) {
        result = EC.wrap(EC.unwrap(self) | CHECKS_DEFERRED_MASK);
    }

    function areChecksInProgress(EC self) internal pure returns (bool result) {
        result = EC.unwrap(self) & CHECKS_IN_PROGRESS_MASK != 0;
    }

    function setChecksInProgress(EC self) internal pure returns (EC result) {
        result = EC.wrap(EC.unwrap(self) | CHECKS_IN_PROGRESS_MASK);
    }

    function isControlCollateralInProgress(EC self) internal pure returns (bool result) {
        result = EC.unwrap(self) & CONTROL_COLLATERAL_IN_PROGRESS_LOCK_MASK != 0;
    }

    function setControlCollateralInProgress(EC self) internal pure returns (EC result) {
        result = EC.wrap(EC.unwrap(self) | CONTROL_COLLATERAL_IN_PROGRESS_LOCK_MASK);
    }

    function isOperatorAuthenticated(EC self) internal pure returns (bool result) {
        result = EC.unwrap(self) & OPERATOR_AUTHENTICATED_MASK != 0;
    }

    function setOperatorAuthenticated(EC self) internal pure returns (EC result) {
        result = EC.wrap(EC.unwrap(self) | OPERATOR_AUTHENTICATED_MASK);
    }

    function clearOperatorAuthenticated(EC self) internal pure returns (EC result) {
        result = EC.wrap(EC.unwrap(self) & ~OPERATOR_AUTHENTICATED_MASK);
    }

    function isSimulationInProgress(EC self) internal pure returns (bool result) {
        result = EC.unwrap(self) & SIMULATION_MASK != 0;
    }

    function setSimulationInProgress(EC self) internal pure returns (EC result) {
        result = EC.wrap(EC.unwrap(self) | SIMULATION_MASK);
    }
}
