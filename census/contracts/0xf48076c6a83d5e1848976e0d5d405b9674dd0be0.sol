//SPDX-License-Identifier: GPL-3.0-or-later

// Copyright (C) Moondance Labs Ltd.
// This file is part of Tanssi.
// Tanssi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Tanssi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Tanssi.  If not, see <http://www.gnu.org/licenses/>
pragma solidity 0.8.25;

//**************************************************************************************************
//                                      CHAINLINK
//**************************************************************************************************
import {AutomationCompatibleInterface} from "@chainlink/automation/interfaces/AutomationCompatibleInterface.sol";
import {AggregatorV3Interface} from "@chainlink/shared/interfaces/AggregatorV2V3Interface.sol";

//**************************************************************************************************
//                                      OPENZEPPELIN
//**************************************************************************************************
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

//**************************************************************************************************
//                                      SYMBIOTIC
//**************************************************************************************************
import {IEntity} from "@symbiotic/interfaces/common/IEntity.sol";
import {IVault} from "@symbiotic/interfaces/vault/IVault.sol";
import {IBaseDelegator} from "@symbiotic/interfaces/delegator/IBaseDelegator.sol";
import {ISlasher} from "@symbiotic/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "@symbiotic/interfaces/slasher/IVetoSlasher.sol";
import {Subnetwork} from "@symbiotic/contracts/libraries/Subnetwork.sol";
import {Operators} from "@symbiotic-middleware/extensions/operators/Operators.sol";
import {BaseOperators} from "@symbiotic-middleware/extensions/operators/BaseOperators.sol";
import {KeyManager256} from "@symbiotic-middleware/extensions/managers/keys/KeyManager256.sol";
import {OzAccessControl} from "@symbiotic-middleware/extensions/managers/access/OzAccessControl.sol";
import {EpochCapture} from "@symbiotic-middleware/extensions/managers/capture-timestamps/EpochCapture.sol";
import {VaultManager} from "@symbiotic-middleware/managers/VaultManager.sol";
import {PauseableEnumerableSet} from "@symbiotic-middleware/libraries/PauseableEnumerableSet.sol";

//**************************************************************************************************
//                                      SNOWBRIDGE
//**************************************************************************************************
import {IOGateway} from "@tanssi-bridge-relayer/snowbridge/contracts/src/interfaces/IOGateway.sol";
import {IODefaultStakerRewards} from "src/interfaces/rewarder/IODefaultStakerRewards.sol";
import {IODefaultOperatorRewards} from "src/interfaces/rewarder/IODefaultOperatorRewards.sol";
import {IODefaultStakerRewardsFactory} from "src/interfaces/rewarder/IODefaultStakerRewardsFactory.sol";
import {IMiddleware} from "src/interfaces/middleware/IMiddleware.sol";
import {OSharedVaults} from "src/contracts/extensions/OSharedVaults.sol";
import {MiddlewareStorage} from "src/contracts/middleware/MiddlewareStorage.sol";

import {IOBaseMiddlewareReader} from "src/interfaces/middleware/IOBaseMiddlewareReader.sol";

contract Middleware is
    UUPSUpgradeable,
    OSharedVaults,
    Operators,
    KeyManager256,
    OzAccessControl,
    EpochCapture,
    AutomationCompatibleInterface,
    MiddlewareStorage,
    IMiddleware
{
    using PauseableEnumerableSet for PauseableEnumerableSet.AddressSet;
    using PauseableEnumerableSet for PauseableEnumerableSet.Status;
    using Subnetwork for address;
    using Math for uint256;

    modifier notZeroAddress(
        address address_
    ) {
        _checkNotZeroAddress(address_);
        _;
    }

    /*
     * @notice Constructor for the middleware
     * @param operatorRewards The operator rewards address
     * @param stakerRewardsFactory The staker rewards factory address
     */
    constructor(
        address operatorRewards,
        address stakerRewardsFactory
    ) notZeroAddress(operatorRewards) notZeroAddress(stakerRewardsFactory) {
        _disableInitializers();

        i_operatorRewards = operatorRewards;
        i_stakerRewardsFactory = stakerRewardsFactory;
    }

    /*
     * @notice Initialize the middleware
     * @param network The network address
     * @param operatorRegistry The operator registry address
     * @param vaultRegistry The vault registry address
     * @param operatorNetOptin The operator network optin address
     * @param owner The owner address
     * @param epochDuration The epoch duration
     * @param slashingWindow The slashing window
     * @param reader The reader address
     */
    function initialize(
        InitParams memory params
    ) external initializer {
        _validateInitParams(params);

        {
            StorageMiddleware storage $ = _getMiddlewareStorage();
            $.lastTimestamp = Time.timestamp();
            $.interval = params.epochDuration;
        }

        __BaseMiddleware_init(
            params.network,
            params.slashingWindow,
            params.vaultRegistry,
            params.operatorRegistry,
            params.operatorNetworkOptIn,
            params.reader
        );
        __OzAccessControl_init(params.owner);
        __EpochCapture_init(params.epochDuration);
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, params.owner);
        _setSelectorRole(this.distributeRewards.selector, GATEWAY_ROLE);
        _setSelectorRole(this.slash.selector, GATEWAY_ROLE);
        _setSelectorRole(this.performUpkeep.selector, FORWARDER_ROLE);
    }

    function _validateInitParams(
        InitParams memory params
    )
        private
        pure
        notZeroAddress(params.network)
        notZeroAddress(params.operatorRegistry)
        notZeroAddress(params.vaultRegistry)
        notZeroAddress(params.operatorNetworkOptIn)
        notZeroAddress(params.owner)
        notZeroAddress(params.reader)
    {
        if (params.epochDuration == 0 || params.slashingWindow == 0) {
            revert Middleware__InvalidEpochDuration();
        }

        if (params.slashingWindow < params.epochDuration) {
            revert Middleware__SlashingWindowTooShort();
        }
    }

    function stakeToPower(address vault, uint256 stake) public view override returns (uint256 power) {
        address collateral = vaultToCollateral(vault);
        address oracle = collateralToOracle(collateral);

        if (oracle == address(0)) {
            revert Middleware__NotSupportedCollateral(collateral);
        }
        (, int256 price,,,) = AggregatorV3Interface(oracle).latestRoundData();
        uint8 priceDecimals = AggregatorV3Interface(oracle).decimals();
        power = stake.mulDiv(uint256(price), 10 ** priceDecimals);
        // Normalize power to 18 decimals
        uint8 collateralDecimals = IERC20Metadata(collateral).decimals();
        if (collateralDecimals != DEFAULT_DECIMALS) {
            power = power.mulDiv(10 ** DEFAULT_DECIMALS, 10 ** collateralDecimals);
        }
    }

    /**
     * @inheritdoc IMiddleware
     */
    function setGateway(
        address newGateway
    ) external checkAccess notZeroAddress(newGateway) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        address oldGateway = $.gateway;

        if (newGateway == oldGateway) {
            revert Middleware__AlreadySet();
        }

        $.gateway = newGateway;
        _revokeRole(GATEWAY_ROLE, oldGateway);
        _grantRole(GATEWAY_ROLE, newGateway);

        emit GatewaySet(newGateway);
    }

    /**
     * @inheritdoc IMiddleware
     */
    function setInterval(
        uint256 interval
    ) external checkAccess {
        if (interval == 0) {
            revert Middleware__InvalidInterval();
        }
        StorageMiddleware storage $ = _getMiddlewareStorage();

        if (interval == $.interval) {
            revert Middleware__AlreadySet();
        }

        $.interval = interval;
        emit IntervalSet(interval);
    }

    /**
     * @inheritdoc IMiddleware
     */
    function setForwarder(
        address forwarder
    ) external checkAccess notZeroAddress(forwarder) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        address currentForwarderAddress = $.forwarderAddress;
        if (forwarder == currentForwarderAddress) {
            revert Middleware__AlreadySet();
        }

        $.forwarderAddress = forwarder;
        _revokeRole(FORWARDER_ROLE, currentForwarderAddress);
        _grantRole(FORWARDER_ROLE, forwarder);

        emit ForwarderSet(forwarder);
    }

    function setCollateralToOracle(
        address collateral,
        address oracle
    ) external checkAccess notZeroAddress(collateral) {
        StorageMiddleware storage $ = _getMiddlewareStorage();

        // Oracle is not checked against zero so this can be used to remove the oracle from a collateral

        $.collateralToOracle[collateral] = oracle;
        emit CollateralToOracleSet(collateral, oracle);
    }

    /**
     * @inheritdoc IMiddleware
     */
    function setOperatorShareOnOperatorRewards(
        uint48 operatorShare
    ) external checkAccess {
        IODefaultOperatorRewards(i_operatorRewards).setOperatorShare(operatorShare);
    }

    /**
     * @inheritdoc IMiddleware
     */
    function distributeRewards(
        uint256 epoch,
        uint256 eraIndex,
        uint256 totalPoints,
        uint256 tokenAmount,
        bytes32 rewardsRoot,
        address tokenAddress
    ) external checkAccess {
        if (IERC20(tokenAddress).balanceOf(address(this)) < tokenAmount) {
            revert Middleware__InsufficientBalance();
        }

        IERC20(tokenAddress).approve(i_operatorRewards, tokenAmount);

        IODefaultOperatorRewards(i_operatorRewards).distributeRewards(
            uint48(epoch), uint48(eraIndex), tokenAmount, totalPoints, rewardsRoot, tokenAddress
        );
    }

    /**
     * @inheritdoc IMiddleware
     */
    function sendCurrentOperatorsKeys() external returns (bytes32[] memory sortedKeys) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        if (block.number < $.lastExecutionBlock + MIN_INTERVAL_TO_SEND_OPERATOR_KEYS) {
            return sortedKeys;
        }

        address gateway = getGateway();
        if (gateway == address(0)) {
            revert Middleware__GatewayNotSet();
        }

        $.lastExecutionBlock = block.number;
        uint48 epoch = getCurrentEpoch();
        sortedKeys = IOBaseMiddlewareReader(address(this)).sortOperatorsByPower(epoch);
        IOGateway(gateway).sendOperatorsData(sortedKeys, epoch);
    }

    /**
     * @inheritdoc AutomationCompatibleInterface
     * @dev Called by chainlink nodes off-chain to check if the upkeep is needed
     * @return upkeepNeeded boolean to indicate whether the keeper should call performUpkeep or not.
     * @return performData bytes of the sorted (by power) operators' keys and the epoch that will be used by the keeper when calling performUpkeep, if upkeep is needed.
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        uint48 epoch = getCurrentEpoch();
        bytes32[] memory sortedKeys = IOBaseMiddlewareReader(address(this)).sortOperatorsByPower(epoch);
        StorageMiddleware storage $ = _getMiddlewareStorage();

        //Should be at least once per epoch
        upkeepNeeded = (Time.timestamp() - $.lastTimestamp) > $.interval;

        performData = abi.encode(sortedKeys, epoch);
    }

    /**
     * @inheritdoc AutomationCompatibleInterface
     * @dev Called by chainlink nodes off-chain to perform the upkeep. It will send the sorted keys to the gateway
     */
    function performUpkeep(
        bytes calldata performData
    ) external override checkAccess {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        address gateway = $.gateway;
        if (gateway == address(0)) {
            revert Middleware__GatewayNotSet();
        }

        uint48 currentTimestamp = Time.timestamp();
        if ((currentTimestamp - $.lastTimestamp) > $.interval) {
            $.lastTimestamp = currentTimestamp;

            // Decode the sorted keys and the epoch from performData
            (bytes32[] memory sortedKeys, uint48 epoch) = abi.decode(performData, (bytes32[], uint48));

            IOGateway(gateway).sendOperatorsData(sortedKeys, epoch);
        }
    }

    /**
     * @inheritdoc IMiddleware
     */
    function slash(uint48 epoch, bytes32 operatorKey, uint256 percentage) external checkAccess {
        uint48 epochStartTs = IOBaseMiddlewareReader(address(this)).getEpochStart(epoch);
        address operator = operatorByKey(abi.encode(operatorKey));

        if (epochStartTs + _SLASHING_WINDOW() < Time.timestamp()) {
            revert Middleware__TooOldEpoch();
        }

        if (epochStartTs > Time.timestamp()) {
            revert Middleware__InvalidEpoch();
        }

        // If address is 0, then we should return
        if (operator == address(0)) {
            revert Middleware__OperatorNotFound(operatorKey, epoch);
        }

        // Sanitization: check percentage is below 100% (or 1 billion in other words)
        if (percentage > PARTS_PER_BILLION) {
            revert Middleware__SlashPercentageTooBig(epoch, operator, percentage);
        }
        SlashParams memory params;
        params.epochStartTs = epochStartTs;
        params.operator = operator;
        params.slashPercentage = percentage;

        address[] memory vaults = _activeVaultsAt(epochStartTs, operator);
        // simple pro-rata slasher
        uint256 vaultsLength = vaults.length;
        for (uint256 i; i < vaultsLength;) {
            _processVaultSlashing(vaults[i], params);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Execute a slash with a given slash index using hints.
     * @param vault The vault address, must have a veto slasher
     * @param slashIndex index of the slash request
     * @param hints hints for checkpoints' indexes
     * @return slashedAmount virtual amount of the collateral slashed
     */
    function executeSlash(
        address vault,
        uint256 slashIndex,
        bytes calldata hints
    ) external returns (uint256 slashedAmount) {
        slashedAmount = _executeSlash(vault, slashIndex, hints);
    }

    /**
     * @dev Set the reader address.
     * @param reader The MiddlewareReader address
     */
    function setReader(
        address reader
    ) external checkAccess notZeroAddress(reader) {
        // From BaseMiddleware.sol
        bytes32 ReaderStorageLocation = 0xfd87879bc98f37af7578af722aecfbe5843e5ad354da2d1e70cb5157c4ec8800;
        assembly {
            sstore(ReaderStorageLocation, reader)
        }
    }

    /**
     * @dev Get vault stake and calculate slashing amount.
     * @param vault The vault address to calculate its stake
     * @param params Struct containing slashing parameters
     */
    function _processVaultSlashing(address vault, SlashParams memory params) private {
        // Tanssi will use only one subnetwork so we only check the first
        bytes32 subnetwork = _NETWORK().subnetwork(0);

        uint256 vaultStake = IBaseDelegator(IVault(vault).delegator()).stakeAt(
            subnetwork, params.operator, params.epochStartTs, new bytes(0)
        );
        // Slash percentage is already in parts per billion
        // so we need to divide by a billion
        uint256 slashAmount = params.slashPercentage.mulDiv(vaultStake, PARTS_PER_BILLION);

        _slashVault(params.epochStartTs, vault, subnetwork, params.operator, slashAmount);
    }

    /**
     * @dev Slashes a vault's stake for a specific operator. Middleware SDK already provides _slashVault function but  custom version is needed to avoid revert in specific scenarios for the gateway message passing.
     * @param timestamp Time at which the epoch started
     * @param vault Address of the vault to slash
     * @param subnetwork Subnetwork identifier
     * @param operator Address of the operator being slashed
     * @param amount Amount to slash
     */
    function _slashVault(
        uint48 timestamp,
        address vault,
        bytes32 subnetwork,
        address operator,
        uint256 amount
    ) private {
        address slasher = IVault(vault).slasher();

        if (slasher == address(0) || amount == 0) {
            return;
        }
        uint256 slasherType = IEntity(slasher).TYPE();

        uint256 response;
        if (slasherType == uint256(SlasherType.INSTANT)) {
            response = ISlasher(slasher).slash(subnetwork, operator, amount, timestamp, new bytes(0));
            emit VaultManager.InstantSlash(vault, subnetwork, response);
        } else if (slasherType == uint256(SlasherType.VETO)) {
            response = IVetoSlasher(slasher).requestSlash(subnetwork, operator, amount, timestamp, new bytes(0));
            emit VaultManager.VetoSlash(vault, subnetwork, response);
        } else {
            revert VaultManager.UnknownSlasherType();
        }
    }

    /**
     * @inheritdoc OSharedVaults
     */
    function _afterRegisterSharedVault(
        address sharedVault,
        IODefaultStakerRewards.InitParams memory stakerRewardsParams
    ) internal override {
        address stakerRewards =
            IODefaultStakerRewardsFactory(i_stakerRewardsFactory).create(sharedVault, stakerRewardsParams);

        IODefaultOperatorRewards(i_operatorRewards).setStakerRewardContract(stakerRewards, sharedVault);

        address collateral = IVault(sharedVault).collateral();
        _setVaultToCollateral(sharedVault, collateral);
    }

    /**
     * @inheritdoc BaseOperators
     */
    function _beforeRegisterOperatorVault(address, /* operator */ address vault) internal override {
        address collateral = IVault(vault).collateral();
        _setVaultToCollateral(vault, collateral);
    }

    /**
     * @inheritdoc BaseOperators
     */
    function _beforeRegisterOperator(
        address operator,
        bytes memory key,
        address
    ) internal pure override notZeroAddress(operator) {
        if (abi.decode(key, (bytes32)) == bytes32(0)) {
            revert Middleware__InvalidKey();
        }
    }

    /**
     * @inheritdoc BaseOperators
     */
    function _beforeUnregisterOperator(
        address operator
    ) internal override {
        _updateKey(operator, abi.encode(bytes32(0)));
    }

    function _setVaultToCollateral(address vault, address collateral) private notZeroAddress(collateral) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        $.vaultToCollateral[vault] = collateral;
    }

    function _checkNotZeroAddress(
        address address_
    ) private pure {
        if (address_ == address(0)) {
            revert Middleware__InvalidAddress();
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override checkAccess {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorInterface} from "./AggregatorInterface.sol";
import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

// solhint-disable-next-line interface-starts-with-i
interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/types/Time.sol)

pragma solidity ^0.8.20;

import {Math} from "../math/Math.sol";
import {SafeCast} from "../math/SafeCast.sol";

/**
 * @dev This library provides helpers for manipulating time-related objects.
 *
 * It uses the following types:
 * - `uint48` for timepoints
 * - `uint32` for durations
 *
 * While the library doesn't provide specific types for timepoints and duration, it does provide:
 * - a `Delay` type to represent duration that can be programmed to change value automatically at a given point
 * - additional helper functions
 */
library Time {
    using Time for *;

    /**
     * @dev Get the block timestamp as a Timepoint.
     */
    function timestamp() internal view returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    /**
     * @dev Get the block number as a Timepoint.
     */
    function blockNumber() internal view returns (uint48) {
        return SafeCast.toUint48(block.number);
    }

    // ==================================================== Delay =====================================================
    /**
     * @dev A `Delay` is a uint32 duration that can be programmed to change value automatically at a given point in the
     * future. The "effect" timepoint describes when the transitions happens from the "old" value to the "new" value.
     * This allows updating the delay applied to some operation while keeping some guarantees.
     *
     * In particular, the {update} function guarantees that if the delay is reduced, the old delay still applies for
     * some time. For example if the delay is currently 7 days to do an upgrade, the admin should not be able to set
     * the delay to 0 and upgrade immediately. If the admin wants to reduce the delay, the old delay (7 days) should
     * still apply for some time.
     *
     *
     * The `Delay` type is 112 bits long, and packs the following:
     *
     * ```
     *   | [uint48]: effect date (timepoint)
     *   |           | [uint32]: value before (duration)
     *   ↓           ↓       ↓ [uint32]: value after (duration)
     * 0xAAAAAAAAAAAABBBBBBBBCCCCCCCC
     * ```
     *
     * NOTE: The {get} and {withUpdate} functions operate using timestamps. Block number based delays are not currently
     * supported.
     */
    type Delay is uint112;

    /**
     * @dev Wrap a duration into a Delay to add the one-step "update in the future" feature
     */
    function toDelay(uint32 duration) internal pure returns (Delay) {
        return Delay.wrap(duration);
    }

    /**
     * @dev Get the value at a given timepoint plus the pending value and effect timepoint if there is a scheduled
     * change after this timepoint. If the effect timepoint is 0, then the pending value should not be considered.
     */
    function _getFullAt(
        Delay self,
        uint48 timepoint
    ) private pure returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        (valueBefore, valueAfter, effect) = self.unpack();
        return effect <= timepoint ? (valueAfter, 0, 0) : (valueBefore, valueAfter, effect);
    }

    /**
     * @dev Get the current value plus the pending value and effect timepoint if there is a scheduled change. If the
     * effect timepoint is 0, then the pending value should not be considered.
     */
    function getFull(Delay self) internal view returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        return _getFullAt(self, timestamp());
    }

    /**
     * @dev Get the current value.
     */
    function get(Delay self) internal view returns (uint32) {
        (uint32 delay, , ) = self.getFull();
        return delay;
    }

    /**
     * @dev Update a Delay object so that it takes a new duration after a timepoint that is automatically computed to
     * enforce the old delay at the moment of the update. Returns the updated Delay object and the timestamp when the
     * new delay becomes effective.
     */
    function withUpdate(
        Delay self,
        uint32 newValue,
        uint32 minSetback
    ) internal view returns (Delay updatedDelay, uint48 effect) {
        uint32 value = self.get();
        uint32 setback = uint32(Math.max(minSetback, value > newValue ? value - newValue : 0));
        effect = timestamp() + setback;
        return (pack(value, newValue, effect), effect);
    }

    /**
     * @dev Split a delay into its components: valueBefore, valueAfter and effect (transition timepoint).
     */
    function unpack(Delay self) internal pure returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        uint112 raw = Delay.unwrap(self);

        valueAfter = uint32(raw);
        valueBefore = uint32(raw >> 32);
        effect = uint48(raw >> 64);

        return (valueBefore, valueAfter, effect);
    }

    /**
     * @dev pack the components into a Delay object.
     */
    function pack(uint32 valueBefore, uint32 valueAfter, uint48 effect) internal pure returns (Delay) {
        return Delay.wrap((uint112(effect) << 64) | (uint112(valueBefore) << 32) | uint112(valueAfter));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.22;

import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Initializable} from "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC-1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC-1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC-1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
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
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC-1967 compliant implementation pointing to self.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC-1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

import {Panic} from "../Panic.sol";
import {SafeCast} from "./SafeCast.sol";

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an success flag (no overflow).
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an success flag (no overflow).
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an success flag (no overflow).
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
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
     * @dev Returns the division of two unsigned integers, with a success flag (no division by zero).
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a success flag (no division by zero).
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool success, uint256 result) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Branchless ternary evaluation for `a ? b : c`. Gas costs are constant.
     *
     * IMPORTANT: This function may reduce bytecode size and consume less gas when used standalone.
     * However, the compiler may optimize Solidity ternary operations (i.e. `a ? b : c`) to only compute
     * one branch when needed, making this function more expensive.
     */
    function ternary(bool condition, uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            // branchless ternary works because:
            // b ^ (a ^ b) == a
            // b ^ 0 == b
            return b ^ ((a ^ b) * SafeCast.toUint(condition));
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a > b, a, b);
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return ternary(a < b, a, b);
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
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }

        // The following calculation ensures accurate ceiling division without overflow.
        // Since a is non-zero, (a - 1) / b will not overflow.
        // The largest possible result occurs when (a - 1) / b is type(uint256).max,
        // but the largest value we can obtain is type(uint256).max - 1, which happens
        // when a = type(uint256).max and b = 1.
        unchecked {
            return SafeCast.toUint(a > 0) * ((a - 1) / b + 1);
        }
    }

    /**
     * @dev Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     *
     * Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2²⁵⁶ and mod 2²⁵⁶ - 1, then use
            // the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2²⁵⁶ + prod0.
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

            // Make sure the result is less than 2²⁵⁶. Also prevents denominator == 0.
            if (denominator <= prod1) {
                Panic.panic(ternary(denominator == 0, Panic.DIVISION_BY_ZERO, Panic.UNDER_OVERFLOW));
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

                // Flip twos such that it is 2²⁵⁶ / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2²⁵⁶. Now that denominator is an odd number, it has an inverse modulo 2²⁵⁶ such
            // that denominator * inv ≡ 1 mod 2²⁵⁶. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv ≡ 1 mod 2⁴.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2¹⁶
            inverse *= 2 - denominator * inverse; // inverse mod 2³²
            inverse *= 2 - denominator * inverse; // inverse mod 2⁶⁴
            inverse *= 2 - denominator * inverse; // inverse mod 2¹²⁸
            inverse *= 2 - denominator * inverse; // inverse mod 2²⁵⁶

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2²⁵⁶. Since the preconditions guarantee that the outcome is
            // less than 2²⁵⁶, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @dev Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        return mulDiv(x, y, denominator) + SafeCast.toUint(unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0);
    }

    /**
     * @dev Calculate the modular multiplicative inverse of a number in Z/nZ.
     *
     * If n is a prime, then Z/nZ is a field. In that case all elements are inversible, except 0.
     * If n is not a prime, then Z/nZ is not a field, and some elements might not be inversible.
     *
     * If the input value is not inversible, 0 is returned.
     *
     * NOTE: If you know for sure that n is (big) a prime, it may be cheaper to use Fermat's little theorem and get the
     * inverse using `Math.modExp(a, n - 2, n)`. See {invModPrime}.
     */
    function invMod(uint256 a, uint256 n) internal pure returns (uint256) {
        unchecked {
            if (n == 0) return 0;

            // The inverse modulo is calculated using the Extended Euclidean Algorithm (iterative version)
            // Used to compute integers x and y such that: ax + ny = gcd(a, n).
            // When the gcd is 1, then the inverse of a modulo n exists and it's x.
            // ax + ny = 1
            // ax = 1 + (-y)n
            // ax ≡ 1 (mod n) # x is the inverse of a modulo n

            // If the remainder is 0 the gcd is n right away.
            uint256 remainder = a % n;
            uint256 gcd = n;

            // Therefore the initial coefficients are:
            // ax + ny = gcd(a, n) = n
            // 0a + 1n = n
            int256 x = 0;
            int256 y = 1;

            while (remainder != 0) {
                uint256 quotient = gcd / remainder;

                (gcd, remainder) = (
                    // The old remainder is the next gcd to try.
                    remainder,
                    // Compute the next remainder.
                    // Can't overflow given that (a % gcd) * (gcd // (a % gcd)) <= gcd
                    // where gcd is at most n (capped to type(uint256).max)
                    gcd - remainder * quotient
                );

                (x, y) = (
                    // Increment the coefficient of a.
                    y,
                    // Decrement the coefficient of n.
                    // Can overflow, but the result is casted to uint256 so that the
                    // next value of y is "wrapped around" to a value between 0 and n - 1.
                    x - y * int256(quotient)
                );
            }

            if (gcd != 1) return 0; // No inverse exists.
            return ternary(x < 0, n - uint256(-x), uint256(x)); // Wrap the result if it's negative.
        }
    }

    /**
     * @dev Variant of {invMod}. More efficient, but only works if `p` is known to be a prime greater than `2`.
     *
     * From https://en.wikipedia.org/wiki/Fermat%27s_little_theorem[Fermat's little theorem], we know that if p is
     * prime, then `a**(p-1) ≡ 1 mod p`. As a consequence, we have `a * a**(p-2) ≡ 1 mod p`, which means that
     * `a**(p-2)` is the modular multiplicative inverse of a in Fp.
     *
     * NOTE: this function does NOT check that `p` is a prime greater than `2`.
     */
    function invModPrime(uint256 a, uint256 p) internal view returns (uint256) {
        unchecked {
            return Math.modExp(a, p - 2, p);
        }
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m)
     *
     * Requirements:
     * - modulus can't be zero
     * - underlying staticcall to precompile must succeed
     *
     * IMPORTANT: The result is only valid if the underlying call succeeds. When using this function, make
     * sure the chain you're using it on supports the precompiled contract for modular exponentiation
     * at address 0x05 as specified in https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise,
     * the underlying function will succeed given the lack of a revert, but the result may be incorrectly
     * interpreted as 0.
     */
    function modExp(uint256 b, uint256 e, uint256 m) internal view returns (uint256) {
        (bool success, uint256 result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Returns the modular exponentiation of the specified base, exponent and modulus (b ** e % m).
     * It includes a success flag indicating if the operation succeeded. Operation will be marked as failed if trying
     * to operate modulo 0 or if the underlying precompile reverted.
     *
     * IMPORTANT: The result is only valid if the success flag is true. When using this function, make sure the chain
     * you're using it on supports the precompiled contract for modular exponentiation at address 0x05 as specified in
     * https://eips.ethereum.org/EIPS/eip-198[EIP-198]. Otherwise, the underlying function will succeed given the lack
     * of a revert, but the result may be incorrectly interpreted as 0.
     */
    function tryModExp(uint256 b, uint256 e, uint256 m) internal view returns (bool success, uint256 result) {
        if (m == 0) return (false, 0);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            // | Offset    | Content    | Content (Hex)                                                      |
            // |-----------|------------|--------------------------------------------------------------------|
            // | 0x00:0x1f | size of b  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x20:0x3f | size of e  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x40:0x5f | size of m  | 0x0000000000000000000000000000000000000000000000000000000000000020 |
            // | 0x60:0x7f | value of b | 0x<.............................................................b> |
            // | 0x80:0x9f | value of e | 0x<.............................................................e> |
            // | 0xa0:0xbf | value of m | 0x<.............................................................m> |
            mstore(ptr, 0x20)
            mstore(add(ptr, 0x20), 0x20)
            mstore(add(ptr, 0x40), 0x20)
            mstore(add(ptr, 0x60), b)
            mstore(add(ptr, 0x80), e)
            mstore(add(ptr, 0xa0), m)

            // Given the result < m, it's guaranteed to fit in 32 bytes,
            // so we can use the memory scratch space located at offset 0.
            success := staticcall(gas(), 0x05, ptr, 0xc0, 0x00, 0x20)
            result := mload(0x00)
        }
    }

    /**
     * @dev Variant of {modExp} that supports inputs of arbitrary length.
     */
    function modExp(bytes memory b, bytes memory e, bytes memory m) internal view returns (bytes memory) {
        (bool success, bytes memory result) = tryModExp(b, e, m);
        if (!success) {
            Panic.panic(Panic.DIVISION_BY_ZERO);
        }
        return result;
    }

    /**
     * @dev Variant of {tryModExp} that supports inputs of arbitrary length.
     */
    function tryModExp(
        bytes memory b,
        bytes memory e,
        bytes memory m
    ) internal view returns (bool success, bytes memory result) {
        if (_zeroBytes(m)) return (false, new bytes(0));

        uint256 mLen = m.length;

        // Encode call args in result and move the free memory pointer
        result = abi.encodePacked(b.length, e.length, mLen, b, e, m);

        assembly ("memory-safe") {
            let dataPtr := add(result, 0x20)
            // Write result on top of args to avoid allocating extra memory.
            success := staticcall(gas(), 0x05, dataPtr, mload(result), dataPtr, mLen)
            // Overwrite the length.
            // result.length > returndatasize() is guaranteed because returndatasize() == m.length
            mstore(result, mLen)
            // Set the memory pointer after the returned data.
            mstore(0x40, add(dataPtr, mLen))
        }
    }

    /**
     * @dev Returns whether the provided byte array is zero.
     */
    function _zeroBytes(bytes memory byteArray) private pure returns (bool) {
        for (uint256 i = 0; i < byteArray.length; ++i) {
            if (byteArray[i] != 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * This method is based on Newton's method for computing square roots; the algorithm is restricted to only
     * using integer operations.
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        unchecked {
            // Take care of easy edge cases when a == 0 or a == 1
            if (a <= 1) {
                return a;
            }

            // In this function, we use Newton's method to get a root of `f(x) := x² - a`. It involves building a
            // sequence x_n that converges toward sqrt(a). For each iteration x_n, we also define the error between
            // the current value as `ε_n = | x_n - sqrt(a) |`.
            //
            // For our first estimation, we consider `e` the smallest power of 2 which is bigger than the square root
            // of the target. (i.e. `2**(e-1) ≤ sqrt(a) < 2**e`). We know that `e ≤ 128` because `(2¹²⁸)² = 2²⁵⁶` is
            // bigger than any uint256.
            //
            // By noticing that
            // `2**(e-1) ≤ sqrt(a) < 2**e → (2**(e-1))² ≤ a < (2**e)² → 2**(2*e-2) ≤ a < 2**(2*e)`
            // we can deduce that `e - 1` is `log2(a) / 2`. We can thus compute `x_n = 2**(e-1)` using a method similar
            // to the msb function.
            uint256 aa = a;
            uint256 xn = 1;

            if (aa >= (1 << 128)) {
                aa >>= 128;
                xn <<= 64;
            }
            if (aa >= (1 << 64)) {
                aa >>= 64;
                xn <<= 32;
            }
            if (aa >= (1 << 32)) {
                aa >>= 32;
                xn <<= 16;
            }
            if (aa >= (1 << 16)) {
                aa >>= 16;
                xn <<= 8;
            }
            if (aa >= (1 << 8)) {
                aa >>= 8;
                xn <<= 4;
            }
            if (aa >= (1 << 4)) {
                aa >>= 4;
                xn <<= 2;
            }
            if (aa >= (1 << 2)) {
                xn <<= 1;
            }

            // We now have x_n such that `x_n = 2**(e-1) ≤ sqrt(a) < 2**e = 2 * x_n`. This implies ε_n ≤ 2**(e-1).
            //
            // We can refine our estimation by noticing that the middle of that interval minimizes the error.
            // If we move x_n to equal 2**(e-1) + 2**(e-2), then we reduce the error to ε_n ≤ 2**(e-2).
            // This is going to be our x_0 (and ε_0)
            xn = (3 * xn) >> 1; // ε_0 := | x_0 - sqrt(a) | ≤ 2**(e-2)

            // From here, Newton's method give us:
            // x_{n+1} = (x_n + a / x_n) / 2
            //
            // One should note that:
            // x_{n+1}² - a = ((x_n + a / x_n) / 2)² - a
            //              = ((x_n² + a) / (2 * x_n))² - a
            //              = (x_n⁴ + 2 * a * x_n² + a²) / (4 * x_n²) - a
            //              = (x_n⁴ + 2 * a * x_n² + a² - 4 * a * x_n²) / (4 * x_n²)
            //              = (x_n⁴ - 2 * a * x_n² + a²) / (4 * x_n²)
            //              = (x_n² - a)² / (2 * x_n)²
            //              = ((x_n² - a) / (2 * x_n))²
            //              ≥ 0
            // Which proves that for all n ≥ 1, sqrt(a) ≤ x_n
            //
            // This gives us the proof of quadratic convergence of the sequence:
            // ε_{n+1} = | x_{n+1} - sqrt(a) |
            //         = | (x_n + a / x_n) / 2 - sqrt(a) |
            //         = | (x_n² + a - 2*x_n*sqrt(a)) / (2 * x_n) |
            //         = | (x_n - sqrt(a))² / (2 * x_n) |
            //         = | ε_n² / (2 * x_n) |
            //         = ε_n² / | (2 * x_n) |
            //
            // For the first iteration, we have a special case where x_0 is known:
            // ε_1 = ε_0² / | (2 * x_0) |
            //     ≤ (2**(e-2))² / (2 * (2**(e-1) + 2**(e-2)))
            //     ≤ 2**(2*e-4) / (3 * 2**(e-1))
            //     ≤ 2**(e-3) / 3
            //     ≤ 2**(e-3-log2(3))
            //     ≤ 2**(e-4.5)
            //
            // For the following iterations, we use the fact that, 2**(e-1) ≤ sqrt(a) ≤ x_n:
            // ε_{n+1} = ε_n² / | (2 * x_n) |
            //         ≤ (2**(e-k))² / (2 * 2**(e-1))
            //         ≤ 2**(2*e-2*k) / 2**e
            //         ≤ 2**(e-2*k)
            xn = (xn + a / xn) >> 1; // ε_1 := | x_1 - sqrt(a) | ≤ 2**(e-4.5)  -- special case, see above
            xn = (xn + a / xn) >> 1; // ε_2 := | x_2 - sqrt(a) | ≤ 2**(e-9)    -- general case with k = 4.5
            xn = (xn + a / xn) >> 1; // ε_3 := | x_3 - sqrt(a) | ≤ 2**(e-18)   -- general case with k = 9
            xn = (xn + a / xn) >> 1; // ε_4 := | x_4 - sqrt(a) | ≤ 2**(e-36)   -- general case with k = 18
            xn = (xn + a / xn) >> 1; // ε_5 := | x_5 - sqrt(a) | ≤ 2**(e-72)   -- general case with k = 36
            xn = (xn + a / xn) >> 1; // ε_6 := | x_6 - sqrt(a) | ≤ 2**(e-144)  -- general case with k = 72

            // Because e ≤ 128 (as discussed during the first estimation phase), we know have reached a precision
            // ε_6 ≤ 2**(e-144) < 1. Given we're operating on integers, then we can ensure that xn is now either
            // sqrt(a) or sqrt(a) + 1.
            return xn - SafeCast.toUint(xn > a / xn);
        }
    }

    /**
     * @dev Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && result * result < a);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 x) internal pure returns (uint256 r) {
        // If value has upper 128 bits set, log2 result is at least 128
        r = SafeCast.toUint(x > 0xffffffffffffffffffffffffffffffff) << 7;
        // If upper 64 bits of 128-bit half set, add 64 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffffffffffff) << 6;
        // If upper 32 bits of 64-bit half set, add 32 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffff) << 5;
        // If upper 16 bits of 32-bit half set, add 16 to result
        r |= SafeCast.toUint((x >> r) > 0xffff) << 4;
        // If upper 8 bits of 16-bit half set, add 8 to result
        r |= SafeCast.toUint((x >> r) > 0xff) << 3;
        // If upper 4 bits of 8-bit half set, add 4 to result
        r |= SafeCast.toUint((x >> r) > 0xf) << 2;

        // Shifts value right by the current result and use it as an index into this lookup table:
        //
        // | x (4 bits) |  index  | table[index] = MSB position |
        // |------------|---------|-----------------------------|
        // |    0000    |    0    |        table[0] = 0         |
        // |    0001    |    1    |        table[1] = 0         |
        // |    0010    |    2    |        table[2] = 1         |
        // |    0011    |    3    |        table[3] = 1         |
        // |    0100    |    4    |        table[4] = 2         |
        // |    0101    |    5    |        table[5] = 2         |
        // |    0110    |    6    |        table[6] = 2         |
        // |    0111    |    7    |        table[7] = 2         |
        // |    1000    |    8    |        table[8] = 3         |
        // |    1001    |    9    |        table[9] = 3         |
        // |    1010    |   10    |        table[10] = 3        |
        // |    1011    |   11    |        table[11] = 3        |
        // |    1100    |   12    |        table[12] = 3        |
        // |    1101    |   13    |        table[13] = 3        |
        // |    1110    |   14    |        table[14] = 3        |
        // |    1111    |   15    |        table[15] = 3        |
        //
        // The lookup table is represented as a 32-byte value with the MSB positions for 0-15 in the last 16 bytes.
        assembly ("memory-safe") {
            r := or(r, byte(shr(r, x), 0x0000010102020202030303030303030300000000000000000000000000000000))
        }
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 1 << result < value);
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
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 10 ** result < value);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 x) internal pure returns (uint256 r) {
        // If value has upper 128 bits set, log2 result is at least 128
        r = SafeCast.toUint(x > 0xffffffffffffffffffffffffffffffff) << 7;
        // If upper 64 bits of 128-bit half set, add 64 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffffffffffff) << 6;
        // If upper 32 bits of 64-bit half set, add 32 to result
        r |= SafeCast.toUint((x >> r) > 0xffffffff) << 5;
        // If upper 16 bits of 32-bit half set, add 16 to result
        r |= SafeCast.toUint((x >> r) > 0xffff) << 4;
        // Add 1 if upper 8 bits of 16-bit half set, and divide accumulated result by 8
        return (r >> 3) | SafeCast.toUint((x >> r) > 0xff);
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + SafeCast.toUint(unsignedRoundsUp(rounding) && 1 << (result << 3) < value);
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
pragma solidity ^0.8.0;

interface IEntity {
    error NotInitialized();

    /**
     * @notice Get the factory's address.
     * @return address of the factory
     */
    function FACTORY() external view returns (address);

    /**
     * @notice Get the entity's type.
     * @return type of the entity
     */
    function TYPE() external view returns (uint64);

    /**
     * @notice Initialize this entity contract by using a given data.
     * @param data some data to use
     */
    function initialize(
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMigratableEntity} from "../common/IMigratableEntity.sol";
import {IVaultStorage} from "./IVaultStorage.sol";

interface IVault is IMigratableEntity, IVaultStorage {
    error AlreadyClaimed();
    error AlreadySet();
    error DelegatorAlreadyInitialized();
    error DepositLimitReached();
    error InsufficientClaim();
    error InsufficientDeposit();
    error InsufficientRedemption();
    error InsufficientWithdrawal();
    error InvalidAccount();
    error InvalidCaptureEpoch();
    error InvalidClaimer();
    error InvalidCollateral();
    error InvalidDelegator();
    error InvalidEpoch();
    error InvalidEpochDuration();
    error InvalidLengthEpochs();
    error InvalidOnBehalfOf();
    error InvalidRecipient();
    error InvalidSlasher();
    error MissingRoles();
    error NotDelegator();
    error NotSlasher();
    error NotWhitelistedDepositor();
    error SlasherAlreadyInitialized();
    error TooMuchRedeem();
    error TooMuchWithdraw();

    /**
     * @notice Initial parameters needed for a vault deployment.
     * @param collateral vault's underlying collateral
     * @param burner vault's burner to issue debt to (e.g., 0xdEaD or some unwrapper contract)
     * @param epochDuration duration of the vault epoch (it determines sync points for withdrawals)
     * @param depositWhitelist if enabling deposit whitelist
     * @param isDepositLimit if enabling deposit limit
     * @param depositLimit deposit limit (maximum amount of the collateral that can be in the vault simultaneously)
     * @param defaultAdminRoleHolder address of the initial DEFAULT_ADMIN_ROLE holder
     * @param depositWhitelistSetRoleHolder address of the initial DEPOSIT_WHITELIST_SET_ROLE holder
     * @param depositorWhitelistRoleHolder address of the initial DEPOSITOR_WHITELIST_ROLE holder
     * @param isDepositLimitSetRoleHolder address of the initial IS_DEPOSIT_LIMIT_SET_ROLE holder
     * @param depositLimitSetRoleHolder address of the initial DEPOSIT_LIMIT_SET_ROLE holder
     */
    struct InitParams {
        address collateral;
        address burner;
        uint48 epochDuration;
        bool depositWhitelist;
        bool isDepositLimit;
        uint256 depositLimit;
        address defaultAdminRoleHolder;
        address depositWhitelistSetRoleHolder;
        address depositorWhitelistRoleHolder;
        address isDepositLimitSetRoleHolder;
        address depositLimitSetRoleHolder;
    }

    /**
     * @notice Hints for an active balance.
     * @param activeSharesOfHint hint for the active shares of checkpoint
     * @param activeStakeHint hint for the active stake checkpoint
     * @param activeSharesHint hint for the active shares checkpoint
     */
    struct ActiveBalanceOfHints {
        bytes activeSharesOfHint;
        bytes activeStakeHint;
        bytes activeSharesHint;
    }

    /**
     * @notice Emitted when a deposit is made.
     * @param depositor account that made the deposit
     * @param onBehalfOf account the deposit was made on behalf of
     * @param amount amount of the collateral deposited
     * @param shares amount of the active shares minted
     */
    event Deposit(address indexed depositor, address indexed onBehalfOf, uint256 amount, uint256 shares);

    /**
     * @notice Emitted when a withdrawal is made.
     * @param withdrawer account that made the withdrawal
     * @param claimer account that needs to claim the withdrawal
     * @param amount amount of the collateral withdrawn
     * @param burnedShares amount of the active shares burned
     * @param mintedShares amount of the epoch withdrawal shares minted
     */
    event Withdraw(
        address indexed withdrawer, address indexed claimer, uint256 amount, uint256 burnedShares, uint256 mintedShares
    );

    /**
     * @notice Emitted when a claim is made.
     * @param claimer account that claimed
     * @param recipient account that received the collateral
     * @param epoch epoch the collateral was claimed for
     * @param amount amount of the collateral claimed
     */
    event Claim(address indexed claimer, address indexed recipient, uint256 epoch, uint256 amount);

    /**
     * @notice Emitted when a batch claim is made.
     * @param claimer account that claimed
     * @param recipient account that received the collateral
     * @param epochs epochs the collateral was claimed for
     * @param amount amount of the collateral claimed
     */
    event ClaimBatch(address indexed claimer, address indexed recipient, uint256[] epochs, uint256 amount);

    /**
     * @notice Emitted when a slash happens.
     * @param amount amount of the collateral to slash
     * @param captureTimestamp time point when the stake was captured
     * @param slashedAmount real amount of the collateral slashed
     */
    event OnSlash(uint256 amount, uint48 captureTimestamp, uint256 slashedAmount);

    /**
     * @notice Emitted when a deposit whitelist status is enabled/disabled.
     * @param status if enabled deposit whitelist
     */
    event SetDepositWhitelist(bool status);

    /**
     * @notice Emitted when a depositor whitelist status is set.
     * @param account account for which the whitelist status is set
     * @param status if whitelisted the account
     */
    event SetDepositorWhitelistStatus(address indexed account, bool status);

    /**
     * @notice Emitted when a deposit limit status is enabled/disabled.
     * @param status if enabled deposit limit
     */
    event SetIsDepositLimit(bool status);

    /**
     * @notice Emitted when a deposit limit is set.
     * @param limit deposit limit (maximum amount of the collateral that can be in the vault simultaneously)
     */
    event SetDepositLimit(uint256 limit);

    /**
     * @notice Emitted when a delegator is set.
     * @param delegator vault's delegator to delegate the stake to networks and operators
     * @dev Can be set only once.
     */
    event SetDelegator(address indexed delegator);

    /**
     * @notice Emitted when a slasher is set.
     * @param slasher vault's slasher to provide a slashing mechanism to networks
     * @dev Can be set only once.
     */
    event SetSlasher(address indexed slasher);

    /**
     * @notice Check if the vault is fully initialized (a delegator and a slasher are set).
     * @return if the vault is fully initialized
     */
    function isInitialized() external view returns (bool);

    /**
     * @notice Get a total amount of the collateral that can be slashed.
     * @return total amount of the slashable collateral
     */
    function totalStake() external view returns (uint256);

    /**
     * @notice Get an active balance for a particular account at a given timestamp using hints.
     * @param account account to get the active balance for
     * @param timestamp time point to get the active balance for the account at
     * @param hints hints for checkpoints' indexes
     * @return active balance for the account at the timestamp
     */
    function activeBalanceOfAt(
        address account,
        uint48 timestamp,
        bytes calldata hints
    ) external view returns (uint256);

    /**
     * @notice Get an active balance for a particular account.
     * @param account account to get the active balance for
     * @return active balance for the account
     */
    function activeBalanceOf(
        address account
    ) external view returns (uint256);

    /**
     * @notice Get withdrawals for a particular account at a given epoch (zero if claimed).
     * @param epoch epoch to get the withdrawals for the account at
     * @param account account to get the withdrawals for
     * @return withdrawals for the account at the epoch
     */
    function withdrawalsOf(uint256 epoch, address account) external view returns (uint256);

    /**
     * @notice Get a total amount of the collateral that can be slashed for a given account.
     * @param account account to get the slashable collateral for
     * @return total amount of the account's slashable collateral
     */
    function slashableBalanceOf(
        address account
    ) external view returns (uint256);

    /**
     * @notice Deposit collateral into the vault.
     * @param onBehalfOf account the deposit is made on behalf of
     * @param amount amount of the collateral to deposit
     * @return depositedAmount real amount of the collateral deposited
     * @return mintedShares amount of the active shares minted
     */
    function deposit(
        address onBehalfOf,
        uint256 amount
    ) external returns (uint256 depositedAmount, uint256 mintedShares);

    /**
     * @notice Withdraw collateral from the vault (it will be claimable after the next epoch).
     * @param claimer account that needs to claim the withdrawal
     * @param amount amount of the collateral to withdraw
     * @return burnedShares amount of the active shares burned
     * @return mintedShares amount of the epoch withdrawal shares minted
     */
    function withdraw(address claimer, uint256 amount) external returns (uint256 burnedShares, uint256 mintedShares);

    /**
     * @notice Redeem collateral from the vault (it will be claimable after the next epoch).
     * @param claimer account that needs to claim the withdrawal
     * @param shares amount of the active shares to redeem
     * @return withdrawnAssets amount of the collateral withdrawn
     * @return mintedShares amount of the epoch withdrawal shares minted
     */
    function redeem(address claimer, uint256 shares) external returns (uint256 withdrawnAssets, uint256 mintedShares);

    /**
     * @notice Claim collateral from the vault.
     * @param recipient account that receives the collateral
     * @param epoch epoch to claim the collateral for
     * @return amount amount of the collateral claimed
     */
    function claim(address recipient, uint256 epoch) external returns (uint256 amount);

    /**
     * @notice Claim collateral from the vault for multiple epochs.
     * @param recipient account that receives the collateral
     * @param epochs epochs to claim the collateral for
     * @return amount amount of the collateral claimed
     */
    function claimBatch(address recipient, uint256[] calldata epochs) external returns (uint256 amount);

    /**
     * @notice Slash callback for burning collateral.
     * @param amount amount to slash
     * @param captureTimestamp time point when the stake was captured
     * @return slashedAmount real amount of the collateral slashed
     * @dev Only the slasher can call this function.
     */
    function onSlash(uint256 amount, uint48 captureTimestamp) external returns (uint256 slashedAmount);

    /**
     * @notice Enable/disable deposit whitelist.
     * @param status if enabling deposit whitelist
     * @dev Only a DEPOSIT_WHITELIST_SET_ROLE holder can call this function.
     */
    function setDepositWhitelist(
        bool status
    ) external;

    /**
     * @notice Set a depositor whitelist status.
     * @param account account for which the whitelist status is set
     * @param status if whitelisting the account
     * @dev Only a DEPOSITOR_WHITELIST_ROLE holder can call this function.
     */
    function setDepositorWhitelistStatus(address account, bool status) external;

    /**
     * @notice Enable/disable deposit limit.
     * @param status if enabling deposit limit
     * @dev Only a IS_DEPOSIT_LIMIT_SET_ROLE holder can call this function.
     */
    function setIsDepositLimit(
        bool status
    ) external;

    /**
     * @notice Set a deposit limit.
     * @param limit deposit limit (maximum amount of the collateral that can be in the vault simultaneously)
     * @dev Only a DEPOSIT_LIMIT_SET_ROLE holder can call this function.
     */
    function setDepositLimit(
        uint256 limit
    ) external;

    /**
     * @notice Set a delegator.
     * @param delegator vault's delegator to delegate the stake to networks and operators
     * @dev Can be set only once.
     */
    function setDelegator(
        address delegator
    ) external;

    /**
     * @notice Set a slasher.
     * @param slasher vault's slasher to provide a slashing mechanism to networks
     * @dev Can be set only once.
     */
    function setSlasher(
        address slasher
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntity} from "../common/IEntity.sol";

interface IBaseDelegator is IEntity {
    error AlreadySet();
    error InsufficientHookGas();
    error NotNetwork();
    error NotSlasher();
    error NotVault();

    /**
     * @notice Base parameters needed for delegators' deployment.
     * @param defaultAdminRoleHolder address of the initial DEFAULT_ADMIN_ROLE holder
     * @param hook address of the hook contract
     * @param hookSetRoleHolder address of the initial HOOK_SET_ROLE holder
     */
    struct BaseParams {
        address defaultAdminRoleHolder;
        address hook;
        address hookSetRoleHolder;
    }

    /**
     * @notice Base hints for a stake.
     * @param operatorVaultOptInHint hint for the operator-vault opt-in
     * @param operatorNetworkOptInHint hint for the operator-network opt-in
     */
    struct StakeBaseHints {
        bytes operatorVaultOptInHint;
        bytes operatorNetworkOptInHint;
    }

    /**
     * @notice Emitted when a subnetwork's maximum limit is set.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param amount new maximum subnetwork's limit (how much stake the subnetwork is ready to get)
     */
    event SetMaxNetworkLimit(bytes32 indexed subnetwork, uint256 amount);

    /**
     * @notice Emitted when a slash happens.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @param amount amount of the collateral to be slashed
     * @param captureTimestamp time point when the stake was captured
     */
    event OnSlash(bytes32 indexed subnetwork, address indexed operator, uint256 amount, uint48 captureTimestamp);

    /**
     * @notice Emitted when a hook is set.
     * @param hook address of the hook
     */
    event SetHook(address indexed hook);

    /**
     * @notice Get a version of the delegator (different versions mean different interfaces).
     * @return version of the delegator
     * @dev Must return 1 for this one.
     */
    function VERSION() external view returns (uint64);

    /**
     * @notice Get the network registry's address.
     * @return address of the network registry
     */
    function NETWORK_REGISTRY() external view returns (address);

    /**
     * @notice Get the vault factory's address.
     * @return address of the vault factory
     */
    function VAULT_FACTORY() external view returns (address);

    /**
     * @notice Get the operator-vault opt-in service's address.
     * @return address of the operator-vault opt-in service
     */
    function OPERATOR_VAULT_OPT_IN_SERVICE() external view returns (address);

    /**
     * @notice Get the operator-network opt-in service's address.
     * @return address of the operator-network opt-in service
     */
    function OPERATOR_NETWORK_OPT_IN_SERVICE() external view returns (address);

    /**
     * @notice Get a gas limit for the hook.
     * @return value of the hook gas limit
     */
    function HOOK_GAS_LIMIT() external view returns (uint256);

    /**
     * @notice Get a reserve gas between the gas limit check and the hook's execution.
     * @return value of the reserve gas
     */
    function HOOK_RESERVE() external view returns (uint256);

    /**
     * @notice Get a hook setter's role.
     * @return identifier of the hook setter role
     */
    function HOOK_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get the vault's address.
     * @return address of the vault
     */
    function vault() external view returns (address);

    /**
     * @notice Get the hook's address.
     * @return address of the hook
     * @dev The hook can have arbitrary logic under certain functions, however, it doesn't affect the stake guarantees.
     */
    function hook() external view returns (address);

    /**
     * @notice Get a particular subnetwork's maximum limit
     *         (meaning the subnetwork is not ready to get more as a stake).
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @return maximum limit of the subnetwork
     */
    function maxNetworkLimit(
        bytes32 subnetwork
    ) external view returns (uint256);

    /**
     * @notice Get a stake that a given subnetwork could be able to slash for a certain operator at a given timestamp
     *         until the end of the consequent epoch using hints (if no cross-slashing and no slashings by the subnetwork).
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @param timestamp time point to capture the stake at
     * @param hints hints for the checkpoints' indexes
     * @return slashable stake at the given timestamp until the end of the consequent epoch
     * @dev Warning: it is not safe to use timestamp >= current one for the stake capturing, as it can change later.
     */
    function stakeAt(
        bytes32 subnetwork,
        address operator,
        uint48 timestamp,
        bytes memory hints
    ) external view returns (uint256);

    /**
     * @notice Get a stake that a given subnetwork will be able to slash
     *         for a certain operator until the end of the next epoch (if no cross-slashing and no slashings by the subnetwork).
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @return slashable stake until the end of the next epoch
     * @dev Warning: this function is not safe to use for stake capturing, as it can change by the end of the block.
     */
    function stake(bytes32 subnetwork, address operator) external view returns (uint256);

    /**
     * @notice Set a maximum limit for a subnetwork (how much stake the subnetwork is ready to get).
     * identifier identifier of the subnetwork
     * @param amount new maximum subnetwork's limit
     * @dev Only a network can call this function.
     */
    function setMaxNetworkLimit(uint96 identifier, uint256 amount) external;

    /**
     * @notice Set a new hook.
     * @param hook address of the hook
     * @dev Only a HOOK_SET_ROLE holder can call this function.
     *      The hook can have arbitrary logic under certain functions, however, it doesn't affect the stake guarantees.
     */
    function setHook(
        address hook
    ) external;

    /**
     * @notice Called when a slash happens.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @param amount amount of the collateral slashed
     * @param captureTimestamp time point when the stake was captured
     * @param data some additional data
     * @dev Only the vault's slasher can call this function.
     */
    function onSlash(
        bytes32 subnetwork,
        address operator,
        uint256 amount,
        uint48 captureTimestamp,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBaseSlasher} from "./IBaseSlasher.sol";

interface ISlasher is IBaseSlasher {
    error InsufficientSlash();
    error InvalidCaptureTimestamp();

    /**
     * @notice Initial parameters needed for a slasher deployment.
     * @param baseParams base parameters for slashers' deployment
     */
    struct InitParams {
        IBaseSlasher.BaseParams baseParams;
    }

    /**
     * @notice Hints for a slash.
     * @param slashableStakeHints hints for the slashable stake checkpoints
     */
    struct SlashHints {
        bytes slashableStakeHints;
    }

    /**
     * @notice Extra data for the delegator.
     * @param slashableStake amount of the slashable stake before the slash (cache)
     * @param stakeAt amount of the stake at the capture time (cache)
     */
    struct DelegatorData {
        uint256 slashableStake;
        uint256 stakeAt;
    }

    /**
     * @notice Emitted when a slash is performed.
     * @param subnetwork subnetwork that requested the slash
     * @param operator operator that is slashed
     * @param slashedAmount virtual amount of the collateral slashed
     * @param captureTimestamp time point when the stake was captured
     */
    event Slash(bytes32 indexed subnetwork, address indexed operator, uint256 slashedAmount, uint48 captureTimestamp);

    /**
     * @notice Perform a slash using a subnetwork for a particular operator by a given amount using hints.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @param amount maximum amount of the collateral to be slashed
     * @param captureTimestamp time point when the stake was captured
     * @param hints hints for checkpoints' indexes
     * @return slashedAmount virtual amount of the collateral slashed
     * @dev Only a network middleware can call this function.
     */
    function slash(
        bytes32 subnetwork,
        address operator,
        uint256 amount,
        uint48 captureTimestamp,
        bytes calldata hints
    ) external returns (uint256 slashedAmount);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBaseSlasher} from "./IBaseSlasher.sol";

interface IVetoSlasher is IBaseSlasher {
    error AlreadySet();
    error InsufficientSlash();
    error InvalidCaptureTimestamp();
    error InvalidResolverSetEpochsDelay();
    error InvalidVetoDuration();
    error NoResolver();
    error NotNetwork();
    error NotResolver();
    error SlashPeriodEnded();
    error SlashRequestCompleted();
    error SlashRequestNotExist();
    error VetoPeriodEnded();
    error VetoPeriodNotEnded();

    /**
     * @notice Initial parameters needed for a slasher deployment.
     * @param baseParams base parameters for slashers' deployment
     * @param vetoDuration duration of the veto period for a slash request
     * @param resolverSetEpochsDelay delay in epochs for a network to update a resolver
     */
    struct InitParams {
        IBaseSlasher.BaseParams baseParams;
        uint48 vetoDuration;
        uint256 resolverSetEpochsDelay;
    }

    /**
     * @notice Structure for a slash request.
     * @param subnetwork subnetwork that requested the slash
     * @param operator operator that could be slashed (if the request is not vetoed)
     * @param amount maximum amount of the collateral to be slashed
     * @param captureTimestamp time point when the stake was captured
     * @param vetoDeadline deadline for the resolver to veto the slash (exclusively)
     * @param completed if the slash was vetoed/executed
     */
    struct SlashRequest {
        bytes32 subnetwork;
        address operator;
        uint256 amount;
        uint48 captureTimestamp;
        uint48 vetoDeadline;
        bool completed;
    }

    /**
     * @notice Hints for a slash request.
     * @param slashableStakeHints hints for the slashable stake checkpoints
     */
    struct RequestSlashHints {
        bytes slashableStakeHints;
    }

    /**
     * @notice Hints for a slash execute.
     * @param captureResolverHint hint for the resolver checkpoint at the capture time
     * @param currentResolverHint hint for the resolver checkpoint at the current time
     * @param slashableStakeHints hints for the slashable stake checkpoints
     */
    struct ExecuteSlashHints {
        bytes captureResolverHint;
        bytes currentResolverHint;
        bytes slashableStakeHints;
    }

    /**
     * @notice Hints for a slash veto.
     * @param captureResolverHint hint for the resolver checkpoint at the capture time
     * @param currentResolverHint hint for the resolver checkpoint at the current time
     */
    struct VetoSlashHints {
        bytes captureResolverHint;
        bytes currentResolverHint;
    }

    /**
     * @notice Hints for a resolver set.
     * @param resolverHint hint for the resolver checkpoint
     */
    struct SetResolverHints {
        bytes resolverHint;
    }

    /**
     * @notice Extra data for the delegator.
     * @param slashableStake amount of the slashable stake before the slash (cache)
     * @param stakeAt amount of the stake at the capture time (cache)
     * @param slashIndex index of the slash request
     */
    struct DelegatorData {
        uint256 slashableStake;
        uint256 stakeAt;
        uint256 slashIndex;
    }

    /**
     * @notice Emitted when a slash request is created.
     * @param slashIndex index of the slash request
     * @param subnetwork subnetwork that requested the slash
     * @param operator operator that could be slashed (if the request is not vetoed)
     * @param slashAmount maximum amount of the collateral to be slashed
     * @param captureTimestamp time point when the stake was captured
     * @param vetoDeadline deadline for the resolver to veto the slash (exclusively)
     */
    event RequestSlash(
        uint256 indexed slashIndex,
        bytes32 indexed subnetwork,
        address indexed operator,
        uint256 slashAmount,
        uint48 captureTimestamp,
        uint48 vetoDeadline
    );

    /**
     * @notice Emitted when a slash request is executed.
     * @param slashIndex index of the slash request
     * @param slashedAmount virtual amount of the collateral slashed
     */
    event ExecuteSlash(uint256 indexed slashIndex, uint256 slashedAmount);

    /**
     * @notice Emitted when a slash request is vetoed.
     * @param slashIndex index of the slash request
     * @param resolver address of the resolver that vetoed the slash
     */
    event VetoSlash(uint256 indexed slashIndex, address indexed resolver);

    /**
     * @notice Emitted when a resolver is set.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param resolver address of the resolver
     */
    event SetResolver(bytes32 indexed subnetwork, address resolver);

    /**
     * @notice Get the network registry's address.
     * @return address of the network registry
     */
    function NETWORK_REGISTRY() external view returns (address);

    /**
     * @notice Get a duration during which resolvers can veto slash requests.
     * @return duration of the veto period
     */
    function vetoDuration() external view returns (uint48);

    /**
     * @notice Get a total number of slash requests.
     * @return total number of slash requests
     */
    function slashRequestsLength() external view returns (uint256);

    /**
     * @notice Get a particular slash request.
     * @param slashIndex index of the slash request
     * @return subnetwork subnetwork that requested the slash
     * @return operator operator that could be slashed (if the request is not vetoed)
     * @return amount maximum amount of the collateral to be slashed
     * @return captureTimestamp time point when the stake was captured
     * @return vetoDeadline deadline for the resolver to veto the slash (exclusively)
     * @return completed if the slash was vetoed/executed
     */
    function slashRequests(
        uint256 slashIndex
    )
        external
        view
        returns (
            bytes32 subnetwork,
            address operator,
            uint256 amount,
            uint48 captureTimestamp,
            uint48 vetoDeadline,
            bool completed
        );

    /**
     * @notice Get a delay for networks in epochs to update a resolver.
     * @return updating resolver delay in epochs
     */
    function resolverSetEpochsDelay() external view returns (uint256);

    /**
     * @notice Get a resolver for a given subnetwork at a particular timestamp using a hint.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param timestamp timestamp to get the resolver at
     * @param hint hint for the checkpoint index
     * @return address of the resolver
     */
    function resolverAt(bytes32 subnetwork, uint48 timestamp, bytes memory hint) external view returns (address);

    /**
     * @notice Get a resolver for a given subnetwork using a hint.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param hint hint for the checkpoint index
     * @return address of the resolver
     */
    function resolver(bytes32 subnetwork, bytes memory hint) external view returns (address);

    /**
     * @notice Request a slash using a subnetwork for a particular operator by a given amount using hints.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @param amount maximum amount of the collateral to be slashed
     * @param captureTimestamp time point when the stake was captured
     * @param hints hints for checkpoints' indexes
     * @return slashIndex index of the slash request
     * @dev Only a network middleware can call this function.
     */
    function requestSlash(
        bytes32 subnetwork,
        address operator,
        uint256 amount,
        uint48 captureTimestamp,
        bytes calldata hints
    ) external returns (uint256 slashIndex);

    /**
     * @notice Execute a slash with a given slash index using hints.
     * @param slashIndex index of the slash request
     * @param hints hints for checkpoints' indexes
     * @return slashedAmount virtual amount of the collateral slashed
     * @dev Only a network middleware can call this function.
     */
    function executeSlash(uint256 slashIndex, bytes calldata hints) external returns (uint256 slashedAmount);

    /**
     * @notice Veto a slash with a given slash index using hints.
     * @param slashIndex index of the slash request
     * @param hints hints for checkpoints' indexes
     * @dev Only a resolver can call this function.
     */
    function vetoSlash(uint256 slashIndex, bytes calldata hints) external;

    /**
     * @notice Set a resolver for a subnetwork using hints.
     * identifier identifier of the subnetwork
     * @param resolver address of the resolver
     * @param hints hints for checkpoints' indexes
     * @dev Only a network can call this function.
     */
    function setResolver(uint96 identifier, address resolver, bytes calldata hints) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev This library adds functions to work with subnetworks.
 */
library Subnetwork {
    function subnetwork(address network_, uint96 identifier_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(network_)) << 96 | identifier_);
    }

    function network(
        bytes32 subnetwork_
    ) internal pure returns (address) {
        return address(uint160(uint256(subnetwork_ >> 96)));
    }

    function identifier(
        bytes32 subnetwork_
    ) internal pure returns (uint96) {
        return uint96(uint256(subnetwork_));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseOperators} from "./BaseOperators.sol";
import {IOperators} from "../../interfaces/extensions/operators/IOperators.sol";

/**
 * @title Operators
 * @notice Base contract for managing operator registration, keys, and vault relationships
 * @dev Provides core operator management functionality with hooks for customization
 */
abstract contract Operators is BaseOperators, IOperators {
    uint64 public constant Operators_VERSION = 1;

    /**
     * @inheritdoc IOperators
     */
    function registerOperator(address operator, bytes memory key, address vault) external checkAccess {
        _registerOperatorImpl(operator, key, vault);
    }

    /**
     * @inheritdoc IOperators
     */
    function unregisterOperator(
        address operator
    ) external checkAccess {
        _unregisterOperatorImpl(operator);
    }

    /**
     * @inheritdoc IOperators
     */
    function pauseOperator(
        address operator
    ) external virtual checkAccess {
        _pauseOperatorImpl(operator);
    }

    /**
     * @inheritdoc IOperators
     */
    function unpauseOperator(
        address operator
    ) external virtual checkAccess {
        _unpauseOperatorImpl(operator);
    }

    /**
     * @inheritdoc IOperators
     */
    function updateOperatorKey(address operator, bytes memory key) external virtual checkAccess {
        _updateOperatorKeyImpl(operator, key);
    }
    /**
     * @inheritdoc IOperators
     */

    function registerOperatorVault(address operator, address vault) external virtual checkAccess {
        _registerOperatorVaultImpl(operator, vault);
    }

    /**
     * @inheritdoc IOperators
     */
    function unregisterOperatorVault(address operator, address vault) external virtual checkAccess {
        _unregisterOperatorVaultImpl(operator, vault);
    }

    /**
     * @inheritdoc IOperators
     */
    function pauseOperatorVault(address operator, address vault) external virtual checkAccess {
        _pauseOperatorVaultImpl(operator, vault);
    }

    /**
     * @inheritdoc IOperators
     */
    function unpauseOperatorVault(address operator, address vault) external virtual checkAccess {
        _unpauseOperatorVaultImpl(operator, vault);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseMiddleware} from "../../middleware/BaseMiddleware.sol";

/**
 * @title BaseOperators
 * @notice Base contract for managing operator registration, keys, and vault relationships
 * @dev Provides core operator management functionality with hooks for customization
 */
abstract contract BaseOperators is BaseMiddleware {
    error OperatorNotRegistered();

    /**
     * @notice Internal implementation for registering an operator
     * @param operator The operator address to register
     * @param key The operator's public key
     * @param vault Optional vault address to associate with operator
     */
    function _registerOperatorImpl(address operator, bytes memory key, address vault) internal virtual {
        _beforeRegisterOperator(operator, key, vault);
        _registerOperator(operator);
        _updateOperatorKeyImpl(operator, key);
        if (vault != address(0)) {
            _beforeRegisterOperatorVault(operator, vault);
            _registerOperatorVault(operator, vault);
        }
    }

    /**
     * @notice Internal implementation for unregistering an operator
     * @param operator The operator address to unregister
     */
    function _unregisterOperatorImpl(
        address operator
    ) internal virtual {
        _beforeUnregisterOperator(operator);
        _unregisterOperator(operator);
    }

    /**
     * @notice Internal implementation for pausing an operator
     * @param operator The operator address to pause
     */
    function _pauseOperatorImpl(
        address operator
    ) internal virtual {
        _beforePauseOperator(operator);
        _pauseOperator(operator);
    }

    /**
     * @notice Internal implementation for unpausing an operator
     * @param operator The operator address to unpause
     */
    function _unpauseOperatorImpl(
        address operator
    ) internal virtual {
        _beforeUnpauseOperator(operator);
        _unpauseOperator(operator);
    }

    /**
     * @notice Internal implementation for updating an operator's key
     * @param operator The operator address
     * @param key The new public key
     */
    function _updateOperatorKeyImpl(address operator, bytes memory key) internal virtual {
        _beforeUpdateOperatorKey(operator, key);
        _updateKey(operator, key);
    }

    /**
     * @notice Internal implementation for registering an operator-vault pair
     * @param operator The operator address
     * @param vault The vault address to associate
     * @dev Reverts if operator is not registered
     */
    function _registerOperatorVaultImpl(address operator, address vault) internal virtual {
        if (!_isOperatorRegistered(operator)) {
            revert OperatorNotRegistered();
        }
        _beforeRegisterOperatorVault(operator, vault);
        _registerOperatorVault(operator, vault);
    }

    /**
     * @notice Internal implementation for unregistering an operator-vault pair
     * @param operator The operator address
     * @param vault The vault address to unregister
     */
    function _unregisterOperatorVaultImpl(address operator, address vault) internal virtual {
        _beforeUnregisterOperatorVault(operator, vault);
        _unregisterOperatorVault(operator, vault);
    }

    /**
     * @notice Internal implementation for pausing an operator-vault pair
     * @param operator The operator address
     * @param vault The vault address to pause
     */
    function _pauseOperatorVaultImpl(address operator, address vault) internal virtual {
        _beforePauseOperatorVault(operator, vault);
        _pauseOperatorVault(operator, vault);
    }

    /**
     * @notice Internal implementation for unpausing an operator-vault pair
     * @param operator The operator address
     * @param vault The vault address to unpause
     */
    function _unpauseOperatorVaultImpl(address operator, address vault) internal virtual {
        _beforeUnpauseOperatorVault(operator, vault);
        _unpauseOperatorVault(operator, vault);
    }

    /**
     * @notice Hook called before updating an operator's key
     * @param operator The operator address
     * @param key The new key
     */
    function _beforeUpdateOperatorKey(address operator, bytes memory key) internal virtual {}

    /**
     * @notice Hook called before registering an operator
     * @param operator The operator address
     * @param key The operator's key
     * @param vault Optional vault address
     */
    function _beforeRegisterOperator(address operator, bytes memory key, address vault) internal virtual {}

    /**
     * @notice Hook called before unregistering an operator
     * @param operator The operator address
     */
    function _beforeUnregisterOperator(
        address operator
    ) internal virtual {}

    /**
     * @notice Hook called before pausing an operator
     * @param operator The operator address
     */
    function _beforePauseOperator(
        address operator
    ) internal virtual {}

    /**
     * @notice Hook called before unpausing an operator
     * @param operator The operator address
     */
    function _beforeUnpauseOperator(
        address operator
    ) internal virtual {}

    /**
     * @notice Hook called before registering an operator-vault pair
     * @param operator The operator address
     * @param vault The vault address
     */
    function _beforeRegisterOperatorVault(address operator, address vault) internal virtual {}

    /**
     * @notice Hook called before unregistering an operator-vault pair
     * @param operator The operator address
     * @param vault The vault address
     */
    function _beforeUnregisterOperatorVault(address operator, address vault) internal virtual {}

    /**
     * @notice Hook called before pausing an operator-vault pair
     * @param operator The operator address
     * @param vault The vault address
     */
    function _beforePauseOperatorVault(address operator, address vault) internal virtual {}

    /**
     * @notice Hook called before unpausing an operator-vault pair
     * @param operator The operator address
     * @param vault The vault address
     */
    function _beforeUnpauseOperatorVault(address operator, address vault) internal virtual {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {KeyManager} from "../../../managers/extendable/KeyManager.sol";
import {PauseableEnumerableSet} from "../../../libraries/PauseableEnumerableSet.sol";

/**
 * @title KeyManager256
 * @notice Manages storage and validation of operator keys using bytes32 values
 * @dev Extends KeyManager to provide key management functionality
 */
abstract contract KeyManager256 is KeyManager {
    uint64 public constant KeyManager256_VERSION = 1;

    using PauseableEnumerableSet for PauseableEnumerableSet.Status;

    error DuplicateKey();
    error PreviousKeySlashable();

    struct KeyManager256Storage {
        mapping(address => bytes32) _key;
        mapping(address => bytes32) _prevKey;
        mapping(bytes32 => PauseableEnumerableSet.InnerAddress) _keyData;
    }

    // keccak256(abi.encode(uint256(keccak256("symbiotic.storage.KeyManager256")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KeyManager256StorageLocation =
        0x3da47716e6090d5a5545e03387f4dac112d37cd069a5573bb81de8579bd9dc00;

    function _getKeyManager256Storage() internal pure returns (KeyManager256Storage storage s) {
        bytes32 location = KeyManager256StorageLocation;
        assembly {
            s.slot := location
        }
    }

    /**
     * @notice Gets the operator address associated with a key
     * @param key The key to lookup
     * @return The operator address that owns the key, or zero address if none
     */
    function operatorByKey(
        bytes memory key
    ) public view override returns (address) {
        KeyManager256Storage storage $ = _getKeyManager256Storage();
        return $._keyData[abi.decode(key, (bytes32))].value;
    }

    /**
     * @notice Gets an operator's active key at the current capture timestamp
     * @param operator The operator address to lookup
     * @return The operator's active key encoded as bytes, or encoded zero bytes if none
     */
    function operatorKey(
        address operator
    ) public view override returns (bytes memory) {
        KeyManager256Storage storage $ = _getKeyManager256Storage();
        uint48 timestamp = getCaptureTimestamp();
        bytes32 key = $._key[operator];
        if (key != bytes32(0) && $._keyData[key].status.wasActiveAt(timestamp)) {
            return abi.encode(key);
        }
        key = $._prevKey[operator];
        if (key != bytes32(0) && $._keyData[key].status.wasActiveAt(timestamp)) {
            return abi.encode(key);
        }
        return abi.encode(bytes32(0));
    }

    /**
     * @notice Checks if a key was active at a specific timestamp
     * @param timestamp The timestamp to check
     * @param key_ The key to check
     * @return True if the key was active at the timestamp, false otherwise
     */
    function keyWasActiveAt(uint48 timestamp, bytes memory key_) public view override returns (bool) {
        KeyManager256Storage storage $ = _getKeyManager256Storage();
        bytes32 key = abi.decode(key_, (bytes32));
        return $._keyData[key].status.wasActiveAt(timestamp);
    }

    /**
     * @notice Updates an operator's key
     * @dev Handles key rotation by disabling old key and registering new one
     * @param operator The operator address to update
     * @param key_ The new key to register, encoded as bytes
     */
    function _updateKey(address operator, bytes memory key_) internal override {
        KeyManager256Storage storage $ = _getKeyManager256Storage();
        bytes32 key = abi.decode(key_, (bytes32));
        uint48 timestamp = _now();

        if ($._keyData[key].value != address(0)) {
            revert DuplicateKey();
        }

        bytes32 prevKey = $._prevKey[operator];
        if (prevKey != bytes32(0)) {
            if (!$._keyData[prevKey].status.checkUnregister(timestamp, _SLASHING_WINDOW())) {
                revert PreviousKeySlashable();
            }
            delete $._keyData[prevKey];
        }

        bytes32 currentKey = $._key[operator];
        if (currentKey != bytes32(0)) {
            $._keyData[currentKey].status.disable(timestamp);
        }

        $._prevKey[operator] = currentKey;
        $._key[operator] = key;

        if (key != bytes32(0)) {
            $._keyData[key].value = operator;
            $._keyData[key].status.set(timestamp);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {AccessManager} from "../../../managers/extendable/AccessManager.sol";
import {IOzAccessControl} from "../../../interfaces/extensions/managers/access/IOzAccessControl.sol";

/**
 * @title OzAccessControl
 * @notice A middleware extension that implements role-based access control
 * @dev Implements AccessManager with role-based access control functionality
 */
abstract contract OzAccessControl is AccessManager, IOzAccessControl {
    uint64 public constant OzAccessControl_VERSION = 1;

    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @custom:storage-location erc7201:symbiotic.storage.OzAccessControl
    struct OzAccessControlStorage {
        mapping(bytes32 role => RoleData) _roles;
        mapping(bytes4 selector => bytes32 role) _selectorRoles;
    }

    // keccak256(abi.encode(uint256(keccak256("symbiotic.storage.OzAccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OzAccessControlStorageLocation =
        0xbe09a78a256419d2b885312b60a13e8082d8ab3c36c463fff4fbb086f1e96f00;

    function _getOzAccessControlStorage() internal pure returns (OzAccessControlStorage storage $) {
        assembly {
            $.slot := OzAccessControlStorageLocation
        }
    }

    /**
     * @notice Initializes the contract with a default admin
     * @param defaultAdmin The address to set as the default admin
     */
    function __OzAccessControl_init(
        address defaultAdmin
    ) internal onlyInitializing {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    /**
     * @inheritdoc IOzAccessControl
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        OzAccessControlStorage storage $ = _getOzAccessControlStorage();
        return $._roles[role].hasRole[account];
    }

    /**
     * @inheritdoc IOzAccessControl
     */
    function getRoleAdmin(
        bytes32 role
    ) public view virtual returns (bytes32) {
        OzAccessControlStorage storage $ = _getOzAccessControlStorage();
        return $._roles[role].adminRole;
    }

    /**
     * @inheritdoc IOzAccessControl
     */
    function getRole(
        bytes4 selector
    ) public view virtual returns (bytes32) {
        OzAccessControlStorage storage $ = _getOzAccessControlStorage();
        return $._selectorRoles[selector];
    }

    /**
     * @inheritdoc IOzAccessControl
     */
    function grantRole(bytes32 role, address account) public virtual {
        bytes32 adminRole = getRoleAdmin(role);
        if (!hasRole(adminRole, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
        }
        _grantRole(role, account);
    }

    /**
     * @inheritdoc IOzAccessControl
     */
    function revokeRole(bytes32 role, address account) public virtual {
        bytes32 adminRole = getRoleAdmin(role);
        if (!hasRole(adminRole, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
        }
        _revokeRole(role, account);
    }

    /**
     * @inheritdoc IOzAccessControl
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != msg.sender) {
            revert AccessControlBadConfirmation();
        }
        _revokeRole(role, callerConfirmation);
    }

    /**
     * @notice Sets the role required for a function selector
     * @param selector The function selector
     * @param role The required role
     */
    function _setSelectorRole(bytes4 selector, bytes32 role) internal virtual {
        OzAccessControlStorage storage $ = _getOzAccessControlStorage();
        $._selectorRoles[selector] = role;
        emit SelectorRoleSet(selector, role);
    }

    /**
     * @notice Sets the admin role for a role
     * @param role The role to set admin for
     * @param adminRole The new admin role
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        OzAccessControlStorage storage $ = _getOzAccessControlStorage();
        bytes32 previousAdminRole = getRoleAdmin(role);
        $._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @notice Grants a role
     * @param role The role to grant
     * @param account The account to grant the role to
     * @return bool True if role was granted
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            OzAccessControlStorage storage $ = _getOzAccessControlStorage();
            $._roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, msg.sender);
            return true;
        }
        return false;
    }

    /**
     * @notice Revokes a role
     * @param role The role to revoke
     * @param account The account to revoke the role from
     * @return bool True if role was revoked
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            OzAccessControlStorage storage $ = _getOzAccessControlStorage();
            $._roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, msg.sender);
            return true;
        }
        return false;
    }

    /**
     * @notice Checks access based on role required for the function selector
     * @dev Implements BaseMiddleware's _checkAccess function
     */
    function _checkAccess() internal view virtual override {
        if (!hasRole(getRole(msg.sig), msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, getRole(msg.sig));
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {CaptureTimestampManager} from "../../../managers/extendable/CaptureTimestampManager.sol";
import {IEpochCapture} from "../../../interfaces/extensions/managers/capture-timestamps/IEpochCapture.sol";

/**
 * @title EpochCapture
 * @notice A middleware extension that captures timestamps based on epochs
 * @dev Implements CaptureTimestampManager with epoch-based timestamp capture
 * @dev Epochs are fixed time periods starting from a base timestamp
 */
abstract contract EpochCapture is CaptureTimestampManager, IEpochCapture {
    uint64 public constant EpochCapture_VERSION = 1;

    struct EpochCaptureStorage {
        uint48 startTimestamp;
        uint48 epochDuration;
    }

    // keccak256(abi.encode(uint256(keccak256("symbiotic.storage.EpochCapture")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant EpochCaptureStorageLocation =
        0x4e241e104e7ef4df0fc8eb6aad7b0f201c6126c722652f1bd1305b6b75c86d00;

    function _getEpochCaptureStorage() internal pure returns (EpochCaptureStorage storage $) {
        bytes32 location = EpochCaptureStorageLocation;
        assembly {
            $.slot := location
        }
    }

    /* 
     * @notice initializer of the Epochs contract.
     * @param epochDuration The duration of each epoch.
     */
    function __EpochCapture_init(
        uint48 epochDuration
    ) internal onlyInitializing {
        EpochCaptureStorage storage $ = _getEpochCaptureStorage();
        $.epochDuration = epochDuration;
        $.startTimestamp = _now();
    }

    /**
     * @inheritdoc IEpochCapture
     */
    function getEpochStart(
        uint48 epoch
    ) public view returns (uint48) {
        EpochCaptureStorage storage $ = _getEpochCaptureStorage();
        return $.startTimestamp + epoch * $.epochDuration;
    }

    /**
     * @inheritdoc IEpochCapture
     */
    function getCurrentEpoch() public view returns (uint48) {
        EpochCaptureStorage storage $ = _getEpochCaptureStorage();
        if (_now() == $.startTimestamp) {
            return 0;
        }

        return (_now() - $.startTimestamp - 1) / $.epochDuration;
    }

    /* 
     * @notice Returns the capture timestamp for the current epoch.
     * @return The capture timestamp.
     */
    function getCaptureTimestamp() public view override returns (uint48 timestamp) {
        return getEpochStart(getCurrentEpoch());
    }

    /**
     * @inheritdoc IEpochCapture
     */
    function getEpochDuration() public view returns (uint48) {
        EpochCaptureStorage storage $ = _getEpochCaptureStorage();
        return $.epochDuration;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IVault} from "@symbiotic/interfaces/vault/IVault.sol";
import {IBaseDelegator} from "@symbiotic/interfaces/delegator/IBaseDelegator.sol";
import {IRegistry} from "@symbiotic/interfaces/common/IRegistry.sol";
import {IEntity} from "@symbiotic/interfaces/common/IEntity.sol";
import {IVetoSlasher} from "@symbiotic/interfaces/slasher/IVetoSlasher.sol";
import {Subnetwork} from "@symbiotic/contracts/libraries/Subnetwork.sol";
import {ISlasher} from "@symbiotic/interfaces/slasher/ISlasher.sol";
import {IOperatorSpecificDelegator} from "@symbiotic/interfaces/delegator/IOperatorSpecificDelegator.sol";

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {StakePowerManager} from "./extendable/StakePowerManager.sol";
import {CaptureTimestampManager} from "./extendable/CaptureTimestampManager.sol";

import {NetworkStorage} from "./storages/NetworkStorage.sol";
import {SlashingWindowStorage} from "./storages/SlashingWindowStorage.sol";

import {PauseableEnumerableSet} from "../libraries/PauseableEnumerableSet.sol";

/**
 * @title VaultManager
 * @notice Abstract contract for managing vaults and their relationships with operators and subnetworks
 * @dev Extends BaseManager and provides functionality for registering, pausing, and managing vaults
 */
abstract contract VaultManager is NetworkStorage, SlashingWindowStorage, CaptureTimestampManager, StakePowerManager {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableMap for EnumerableMap.AddressToAddressMap;
    using PauseableEnumerableSet for PauseableEnumerableSet.AddressSet;
    using PauseableEnumerableSet for PauseableEnumerableSet.Uint160Set;
    using Subnetwork for address;

    error NotVault();
    error NotOperatorVault();
    error VaultNotInitialized();
    error VaultAlreadyRegistered();
    error VaultEpochTooShort();
    error InactiveVaultSlash();
    error UnknownSlasherType();
    error NonVetoSlasher();
    error NoSlasher();
    error TooOldTimestampSlash();
    error NotOperatorSpecificVault();

    /// @custom:storage-location erc7201:symbiotic.storage.VaultManager
    struct VaultManagerStorage {
        address _vaultRegistry;
        PauseableEnumerableSet.Uint160Set _subnetworks;
        PauseableEnumerableSet.AddressSet _sharedVaults;
        mapping(address => PauseableEnumerableSet.AddressSet) _operatorVaults;
        EnumerableMap.AddressToAddressMap _vaultOperator;
    }

    event InstantSlash(address vault, bytes32 subnetwork, uint256 amount);
    event VetoSlash(address vault, bytes32 subnetwork, uint256 index);

    enum SlasherType {
        INSTANT, // Instant slasher type
        VETO // Veto slasher type

    }

    enum DelegatorType {
        NETWORK_RESTAKE,
        FULL_RESTAKE,
        OPERATOR_SPECIFIC,
        OPERATOR_NETWORK_SPECIFIC
    }

    // keccak256(abi.encode(uint256(keccak256("symbiotic.storage.VaultManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VaultManagerStorageLocation =
        0x485f0695561726d087d0cb5cf546efed37ef61dfced21455f1ba7eb5e5b3db00;

    /**
     * @notice Internal helper to access the VaultManager storage struct
     * @dev Uses assembly to load storage location from a constant slot
     * @return $ Storage pointer to the VaultManagerStorage struct
     */
    function _getVaultManagerStorage() internal pure returns (VaultManagerStorage storage $) {
        assembly {
            $.slot := VaultManagerStorageLocation
        }
    }

    uint96 internal constant DEFAULT_SUBNETWORK = 0;

    /**
     * @notice Initializes the VaultManager with required parameters
     * @param vaultRegistry The address of the vault registry contract
     */
    function __VaultManager_init_private(
        address vaultRegistry
    ) internal onlyInitializing {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._vaultRegistry = vaultRegistry;
        _registerSubnetwork(DEFAULT_SUBNETWORK);
    }

    /**
     * @notice Gets the address of the vault registry contract
     * @return The vault registry contract address
     */
    function _VAULT_REGISTRY() internal view returns (address) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._vaultRegistry;
    }

    /**
     * @notice Gets the total number of registered subnetworks
     * @return uint256 The count of registered subnetworks
     */
    function _subnetworksLength() internal view returns (uint256) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._subnetworks.length();
    }

    /**
     * @notice Gets the subnetwork information at a specific index
     * @param pos The index position to query
     * @return uint160 The subnetwork address
     * @return uint48 The time when the subnetwork was enabled
     * @return uint48 The time when the subnetwork was disabled
     */
    function _subnetworkWithTimesAt(
        uint256 pos
    ) internal view returns (uint160, uint48, uint48) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._subnetworks.at(pos);
    }

    /**
     * @notice Gets all currently active subnetworks
     * @return uint160[] Array of active subnetwork addresses
     */
    function _activeSubnetworks() internal view returns (uint160[] memory) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._subnetworks.getActive(getCaptureTimestamp());
    }

    /**
     * @notice Gets all subnetworks that were active at a specific timestamp
     * @param timestamp The timestamp to check
     * @return uint160[] Array of subnetwork addresses that were active at the timestamp
     */
    function _activeSubnetworksAt(
        uint48 timestamp
    ) internal view returns (uint160[] memory) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._subnetworks.getActive(timestamp);
    }

    /**
     * @notice Checks if a subnetwork was active at a specific timestamp
     * @param timestamp The timestamp to check
     * @param subnetwork The subnetwork identifier
     * @return bool True if the subnetwork was active at the timestamp
     */
    function _subnetworkWasActiveAt(uint48 timestamp, uint96 subnetwork) internal view returns (bool) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._subnetworks.wasActiveAt(timestamp, uint160(subnetwork));
    }

    /**
     * @notice Gets the total number of shared vaults
     * @return uint256 The count of shared vaults
     */
    function _sharedVaultsLength() internal view returns (uint256) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._sharedVaults.length();
    }

    /**
     * @notice Gets the vault information at a specific index
     * @param pos The index position to query
     * @return address The vault address
     * @return uint48 The time when the vault was enabled
     * @return uint48 The time when the vault was disabled
     */
    function _sharedVaultWithTimesAt(
        uint256 pos
    ) internal view returns (address, uint48, uint48) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._sharedVaults.at(pos);
    }

    /**
     * @notice Gets all currently active shared vaults
     * @return address[] Array of active shared vault addresses
     */
    function _activeSharedVaults() internal view returns (address[] memory) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._sharedVaults.getActive(getCaptureTimestamp());
    }

    /**
     * @notice Gets all shared vaults that were active at a specific timestamp
     * @param timestamp The timestamp to check
     * @return address[] Array of shared vault addresses that were active at the timestamp
     */
    function _activeSharedVaultsAt(
        uint48 timestamp
    ) internal view returns (address[] memory) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._sharedVaults.getActive(timestamp);
    }

    /**
     * @notice Gets the number of vaults associated with an operator
     * @param operator The operator address to query
     * @return uint256 The count of vaults for the operator
     */
    function _operatorVaultsLength(
        address operator
    ) internal view returns (uint256) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._operatorVaults[operator].length();
    }

    /**
     * @notice Gets the vault information at a specific index for an operator
     * @param operator The operator address
     * @param pos The index position to query
     * @return address The vault address
     * @return uint48 The time when the vault was enabled
     * @return uint48 The time when the vault was disabled
     */
    function _operatorVaultWithTimesAt(address operator, uint256 pos) internal view returns (address, uint48, uint48) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._operatorVaults[operator].at(pos);
    }

    /**
     * @notice Gets all currently active vaults for a specific operator
     * @param operator The operator address
     * @return address[] Array of active vault addresses
     */
    function _activeOperatorVaults(
        address operator
    ) internal view returns (address[] memory) {
        return _activeOperatorVaultsAt(getCaptureTimestamp(), operator);
    }

    /**
     * @notice Gets all currently active vaults for a specific operator at a specific timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address
     * @return address[] Array of active vault addresses
     */
    function _activeOperatorVaultsAt(uint48 timestamp, address operator) internal view returns (address[] memory) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._operatorVaults[operator].getActive(timestamp);
    }

    /**
     * @notice Gets all currently active vaults across all operators
     * @return address[] Array of all active vault addresses
     */
    function _activeVaults() internal view returns (address[] memory) {
        return _activeVaultsAt(getCaptureTimestamp());
    }

    /**
     * @notice Gets all vaults that were active at a specific timestamp
     * @param timestamp The timestamp to check
     * @return address[] Array of vault addresses that were active at the timestamp
     */
    function _activeVaultsAt(
        uint48 timestamp
    ) internal view returns (address[] memory) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        address[] memory activeSharedVaults_ = $._sharedVaults.getActive(timestamp);
        uint256 len = activeSharedVaults_.length;
        uint256 operatorVaultsLen = $._vaultOperator.length();
        address[] memory vaults = new address[](len + operatorVaultsLen);

        for (uint256 i; i < len; ++i) {
            vaults[i] = activeSharedVaults_[i];
        }

        for (uint256 i; i < operatorVaultsLen; ++i) {
            (address vault, address operator) = $._vaultOperator.at(i);
            if ($._operatorVaults[operator].wasActiveAt(timestamp, vault)) {
                vaults[len++] = vault;
            }
        }

        assembly {
            mstore(vaults, len)
        }

        return vaults;
    }

    /**
     * @notice Gets all currently active vaults for a specific operator
     * @param operator The operator address
     * @return address[] Array of active vault addresses for the operator
     */
    function _activeVaults(
        address operator
    ) internal view returns (address[] memory) {
        return _activeVaultsAt(getCaptureTimestamp(), operator);
    }

    /**
     * @notice Gets all vaults that were active for an operator at a specific timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address
     * @return address[] Array of vault addresses that were active at the timestamp
     */
    function _activeVaultsAt(uint48 timestamp, address operator) internal view returns (address[] memory) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        address[] memory activeSharedVaults_ = $._sharedVaults.getActive(timestamp);
        address[] memory activeOperatorVaults_ = $._operatorVaults[operator].getActive(timestamp);

        uint256 activeSharedVaultsLen = activeSharedVaults_.length;
        uint256 activeOperatorVaultsLen = activeOperatorVaults_.length;
        address[] memory vaults = new address[](activeSharedVaultsLen + activeOperatorVaultsLen);
        for (uint256 i; i < activeSharedVaultsLen; ++i) {
            vaults[i] = activeSharedVaults_[i];
        }
        for (uint256 i; i < activeOperatorVaultsLen; ++i) {
            vaults[activeSharedVaultsLen + i] = activeOperatorVaults_[i];
        }

        return vaults;
    }

    /**
     * @notice Checks if a vault was active at a specific timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address
     * @param vault The vault address
     * @return bool True if the vault was active at the timestamp
     */
    function _vaultWasActiveAt(uint48 timestamp, address operator, address vault) internal view returns (bool) {
        return _sharedVaultWasActiveAt(timestamp, vault) || _operatorVaultWasActiveAt(timestamp, operator, vault);
    }

    /**
     * @notice Checks if a shared vault was active at a specific timestamp
     * @param timestamp The timestamp to check
     * @param vault The vault address
     * @return bool True if the shared vault was active at the timestamp
     */
    function _sharedVaultWasActiveAt(uint48 timestamp, address vault) internal view returns (bool) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._sharedVaults.wasActiveAt(timestamp, vault);
    }

    /**
     * @notice Checks if an operator vault was active at a specific timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address
     * @param vault The vault address
     * @return bool True if the operator vault was active at the timestamp
     */
    function _operatorVaultWasActiveAt(
        uint48 timestamp,
        address operator,
        address vault
    ) internal view returns (bool) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        return $._operatorVaults[operator].wasActiveAt(timestamp, vault);
    }

    /**
     * @notice Gets the stake amount for an operator in a vault and subnetwork at a specific timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address
     * @param vault The vault address
     * @param subnetwork The subnetwork identifier
     * @return uint256 The stake amount at the timestamp
     */
    function _getOperatorStakeAt(
        uint48 timestamp,
        address operator,
        address vault,
        uint96 subnetwork
    ) private view returns (uint256) {
        bytes32 subnetworkId = _NETWORK().subnetwork(subnetwork);
        return IBaseDelegator(IVault(vault).delegator()).stakeAt(subnetworkId, operator, timestamp, "");
    }

    /**
     * @notice Gets the power amount for an operator in a vault and subnetwork
     * @param operator The operator address
     * @param vault The vault address
     * @param subnetwork The subnetwork identifier
     * @return uint256 The power amount
     */
    function _getOperatorPower(address operator, address vault, uint96 subnetwork) internal view returns (uint256) {
        return _getOperatorPowerAt(getCaptureTimestamp(), operator, vault, subnetwork);
    }

    /**
     * @notice Gets the power amount for an operator in a vault and subnetwork at a specific timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address
     * @param vault The vault address
     * @param subnetwork The subnetwork identifier
     * @return uint256 The power amount at the timestamp
     */
    function _getOperatorPowerAt(
        uint48 timestamp,
        address operator,
        address vault,
        uint96 subnetwork
    ) internal view returns (uint256) {
        uint256 stake = _getOperatorStakeAt(timestamp, operator, vault, subnetwork);
        return stakeToPower(vault, stake);
    }

    /**
     * @notice Gets the total power amount for an operator across all vaults and subnetworks
     * @param operator The operator address
     * @return power The total power amount
     */
    function _getOperatorPower(
        address operator
    ) internal view returns (uint256 power) {
        return _getOperatorPowerAt(getCaptureTimestamp(), operator);
    }

    /**
     * @notice Gets the total power amount for an operator across all vaults and subnetworks at a specific timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address
     * @return power The total power amount at the timestamp
     */
    function _getOperatorPowerAt(uint48 timestamp, address operator) internal view returns (uint256 power) {
        address[] memory vaults = _activeVaultsAt(timestamp, operator);
        uint160[] memory subnetworks = _activeSubnetworksAt(timestamp);

        return _getOperatorPowerAt(timestamp, operator, vaults, subnetworks);
    }

    /**
     * @notice Gets the total power amount for an operator across all vaults and subnetworks
     * @param operator The operator address
     * @param vaults The list of vault addresses
     * @param subnetworks The list of subnetwork identifiers
     * @return power The total power amount
     */
    function _getOperatorPower(
        address operator,
        address[] memory vaults,
        uint160[] memory subnetworks
    ) internal view returns (uint256 power) {
        return _getOperatorPowerAt(getCaptureTimestamp(), operator, vaults, subnetworks);
    }

    /**
     * @notice Gets the total power amount for an operator across all vaults and subnetworks at a specific timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address
     * @param vaults The list of vault addresses
     * @param subnetworks The list of subnetwork identifiers
     * @return power The total power amount at the timestamp
     */
    function _getOperatorPowerAt(
        uint48 timestamp,
        address operator,
        address[] memory vaults,
        uint160[] memory subnetworks
    ) internal view returns (uint256 power) {
        for (uint256 i; i < vaults.length; ++i) {
            address vault = vaults[i];
            for (uint256 j; j < subnetworks.length; ++j) {
                power += _getOperatorPowerAt(timestamp, operator, vault, uint96(subnetworks[j]));
            }
        }

        return power;
    }

    /**
     * @notice Calculates the total power for a list of operators
     * @param operators Array of operator addresses
     * @return power The total power amount
     */
    function _totalPower(
        address[] memory operators
    ) internal view returns (uint256 power) {
        for (uint256 i; i < operators.length; ++i) {
            power += _getOperatorPower(operators[i]);
        }

        return power;
    }

    /**
     * @notice Registers a new subnetwork
     * @param subnetwork The subnetwork identifier to register
     */
    function _registerSubnetwork(
        uint96 subnetwork
    ) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._subnetworks.register(_now(), uint160(subnetwork));
    }

    /**
     * @notice Pauses a subnetwork
     * @param subnetwork The subnetwork identifier to pause
     */
    function _pauseSubnetwork(
        uint96 subnetwork
    ) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._subnetworks.pause(_now(), uint160(subnetwork));
    }

    /**
     * @notice Unpauses a subnetwork
     * @param subnetwork The subnetwork identifier to unpause
     */
    function _unpauseSubnetwork(
        uint96 subnetwork
    ) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._subnetworks.unpause(_now(), _SLASHING_WINDOW(), uint160(subnetwork));
    }

    /**
     * @notice Unregisters a subnetwork
     * @param subnetwork The subnetwork identifier to unregister
     */
    function _unregisterSubnetwork(
        uint96 subnetwork
    ) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._subnetworks.unregister(_now(), _SLASHING_WINDOW(), uint160(subnetwork));
    }

    /**
     * @notice Registers a new shared vault
     * @param vault The vault address to register
     */
    function _registerSharedVault(
        address vault
    ) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        _validateVault(vault);
        $._sharedVaults.register(_now(), vault);
    }

    /**
     * @notice Registers a new operator vault
     * @param operator The operator address
     * @param vault The vault address to register
     */
    function _registerOperatorVault(address operator, address vault) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        _validateVault(vault);
        _validateOperatorVault(operator, vault);

        $._operatorVaults[operator].register(_now(), vault);
        $._vaultOperator.set(vault, operator);
    }

    /**
     * @notice Pauses a shared vault
     * @param vault The vault address to pause
     */
    function _pauseSharedVault(
        address vault
    ) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._sharedVaults.pause(_now(), vault);
    }

    /**
     * @notice Unpauses a shared vault
     * @param vault The vault address to unpause
     */
    function _unpauseSharedVault(
        address vault
    ) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._sharedVaults.unpause(_now(), _SLASHING_WINDOW(), vault);
    }

    /**
     * @notice Pauses an operator vault
     * @param operator The operator address
     * @param vault The vault address to pause
     */
    function _pauseOperatorVault(address operator, address vault) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._operatorVaults[operator].pause(_now(), vault);
    }

    /**
     * @notice Unpauses an operator vault
     * @param operator The operator address
     * @param vault The vault address to unpause
     */
    function _unpauseOperatorVault(address operator, address vault) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._operatorVaults[operator].unpause(_now(), _SLASHING_WINDOW(), vault);
    }

    /**
     * @notice Unregisters a shared vault
     * @param vault The vault address to unregister
     */
    function _unregisterSharedVault(
        address vault
    ) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._sharedVaults.unregister(_now(), _SLASHING_WINDOW(), vault);
    }

    /**
     * @notice Unregisters an operator vault
     * @param operator The operator address
     * @param vault The vault address to unregister
     */
    function _unregisterOperatorVault(address operator, address vault) internal {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        $._operatorVaults[operator].unregister(_now(), _SLASHING_WINDOW(), vault);
        $._vaultOperator.remove(vault);
    }

    /**
     * @notice Slashes a vault based on provided conditions
     * @param timestamp The timestamp when the slash occurs
     * @param vault The vault address
     * @param subnetwork The subnetwork identifier
     * @param operator The operator to slash
     * @param amount The amount to slash
     * @param hints Additional data for the slasher
     * @return response index for veto slashing or amount for instant slashing
     */
    function _slashVault(
        uint48 timestamp,
        address vault,
        bytes32 subnetwork,
        address operator,
        uint256 amount,
        bytes memory hints
    ) internal returns (uint256 response) {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        if (!($._sharedVaults.contains(vault) || $._operatorVaults[operator].contains(vault))) {
            revert NotOperatorVault();
        }

        if (!_vaultWasActiveAt(timestamp, operator, vault)) {
            revert InactiveVaultSlash();
        }

        if (timestamp + _SLASHING_WINDOW() < _now()) {
            revert TooOldTimestampSlash();
        }

        address slasher = IVault(vault).slasher();
        if (slasher == address(0)) {
            revert NoSlasher();
        }

        uint64 slasherType = IEntity(slasher).TYPE();
        if (slasherType == uint64(SlasherType.INSTANT)) {
            response = ISlasher(slasher).slash(subnetwork, operator, amount, timestamp, hints);
            emit InstantSlash(vault, subnetwork, response);
        } else if (slasherType == uint64(SlasherType.VETO)) {
            response = IVetoSlasher(slasher).requestSlash(subnetwork, operator, amount, timestamp, hints);
            emit VetoSlash(vault, subnetwork, response);
        } else {
            revert UnknownSlasherType();
        }
    }

    /**
     * @notice Executes a veto-based slash for a vault
     * @param vault The vault address
     * @param slashIndex The index of the slash to execute
     * @param hints Additional data for the veto slasher
     * @return slashedAmount The amount that was slashed
     */
    function _executeSlash(
        address vault,
        uint256 slashIndex,
        bytes memory hints
    ) internal returns (uint256 slashedAmount) {
        address slasher = IVault(vault).slasher();
        uint64 slasherType = IEntity(slasher).TYPE();
        if (slasherType != uint64(SlasherType.VETO)) {
            revert NonVetoSlasher();
        }

        return IVetoSlasher(slasher).executeSlash(slashIndex, hints);
    }

    /**
     * @notice Validates if a vault is properly initialized and registered
     * @param vault The vault address to validate
     */
    function _validateVault(
        address vault
    ) private view {
        VaultManagerStorage storage $ = _getVaultManagerStorage();
        if (!IRegistry(_VAULT_REGISTRY()).isEntity(vault)) {
            revert NotVault();
        }

        if (!IVault(vault).isInitialized()) {
            revert VaultNotInitialized();
        }

        if ($._vaultOperator.contains(vault) || $._sharedVaults.contains(vault)) {
            revert VaultAlreadyRegistered();
        }

        uint48 vaultEpoch = IVault(vault).epochDuration();

        address slasher = IVault(vault).slasher();
        if (slasher != address(0)) {
            uint64 slasherType = IEntity(slasher).TYPE();
            if (slasherType == uint64(SlasherType.VETO)) {
                vaultEpoch -= IVetoSlasher(slasher).vetoDuration();
            } else if (slasherType > uint64(SlasherType.VETO)) {
                revert UnknownSlasherType();
            }
        }

        if (vaultEpoch < _SLASHING_WINDOW()) {
            revert VaultEpochTooShort();
        }
    }

    function _validateOperatorVault(address operator, address vault) internal view {
        address delegator = IVault(vault).delegator();
        uint64 delegatorType = IEntity(delegator).TYPE();
        if (
            (
                delegatorType != uint64(DelegatorType.OPERATOR_SPECIFIC)
                    && delegatorType != uint64(DelegatorType.OPERATOR_NETWORK_SPECIFIC)
            ) || IOperatorSpecificDelegator(delegator).operator() != operator
        ) {
            revert NotOperatorSpecificVault();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title PauseableEnumerableSet
 * @notice Library for managing sets of values that can be paused and unpaused
 * @dev Provides functionality for managing sets of addresses, uint160s, bytes32s and bytes values
 *      Each value in a set has an associated status that tracks when it was enabled/disabled
 */
library PauseableEnumerableSet {
    using PauseableEnumerableSet for AddressSet;
    using PauseableEnumerableSet for Status;

    error AlreadyRegistered();
    error NotRegistered();
    error AlreadyEnabled();
    error NotEnabled();
    error Enabled();
    error ImmutablePeriodNotPassed();

    /**
     * @dev Stores the enabled and disabled timestamps for a value
     */
    struct Status {
        uint48 enabled;
        uint48 disabled;
    }

    /**
     * @dev Stores an address value and its status
     */
    struct InnerAddress {
        address value;
        Status status;
    }

    /**
     * @dev Set of address values with their statuses
     */
    struct AddressSet {
        InnerAddress[] array;
        mapping(address => uint256) positions;
    }

    /**
     * @dev Set of uint160 values, implemented using AddressSet
     */
    struct Uint160Set {
        AddressSet set;
    }

    /**
     * @notice Sets the initial status of a value
     * @param self The status to modify
     * @param timestamp The timestamp to set as enabled
     */
    function set(Status storage self, uint48 timestamp) internal {
        self.enabled = timestamp;
        self.disabled = 0;
    }

    /**
     * @notice Enables a previously disabled value
     * @param self The status to modify
     * @param timestamp The timestamp to set as enabled
     * @param immutablePeriod The required waiting period after disabling
     */
    function enable(Status storage self, uint48 timestamp, uint48 immutablePeriod) internal {
        if (self.enabled != 0) revert AlreadyEnabled();
        if (self.disabled + immutablePeriod > timestamp) revert ImmutablePeriodNotPassed();

        self.enabled = timestamp;
        self.disabled = 0;
    }

    /**
     * @notice Disables an enabled value
     * @param self The status to modify
     * @param timestamp The timestamp to set as disabled
     */
    function disable(Status storage self, uint48 timestamp) internal {
        if (self.disabled != 0) revert NotEnabled();
        self.enabled = 0;
        self.disabled = timestamp;
    }

    /**
     * @notice Validates if a value can be unregistered
     * @param self The status to check
     * @param timestamp The current timestamp
     * @param immutablePeriod The required waiting period after disabling
     */
    function validateUnregister(Status storage self, uint48 timestamp, uint48 immutablePeriod) internal view {
        if (self.enabled != 0 || self.disabled == 0) revert Enabled();
        if (self.disabled + immutablePeriod > timestamp) revert ImmutablePeriodNotPassed();
    }

    /**
     * @notice Checks if a value can be unregistered
     * @param self The status to check
     * @param timestamp The current timestamp
     * @param immutablePeriod The required waiting period after disabling
     * @return bool Whether the value can be unregistered
     */
    function checkUnregister(
        Status storage self,
        uint48 timestamp,
        uint48 immutablePeriod
    ) internal view returns (bool) {
        return self.enabled == 0 && self.disabled != 0 && self.disabled + immutablePeriod <= timestamp;
    }

    /**
     * @notice Checks if a value was active at a given timestamp
     * @param self The status to check
     * @param timestamp The timestamp to check
     * @return bool Whether the value was active
     */
    function wasActiveAt(Status storage self, uint48 timestamp) internal view returns (bool) {
        return self.enabled < timestamp && (self.disabled == 0 || self.disabled >= timestamp);
    }

    // AddressSet functions

    /**
     * @notice Gets the number of addresses in the set
     * @param self The AddressSet to query
     * @return uint256 The number of addresses
     */
    function length(
        AddressSet storage self
    ) internal view returns (uint256) {
        return self.array.length;
    }

    /**
     * @notice Gets the address and status at a given position
     * @param self The AddressSet to query
     * @param pos The position to query
     * @return The address, enabled timestamp, and disabled timestamp
     */
    function at(AddressSet storage self, uint256 pos) internal view returns (address, uint48, uint48) {
        InnerAddress storage element = self.array[pos];
        return (element.value, element.status.enabled, element.status.disabled);
    }

    /**
     * @notice Gets all active addresses at a given timestamp
     * @param self The AddressSet to query
     * @param timestamp The timestamp to check
     * @return array Array of active addresses
     */
    function getActive(AddressSet storage self, uint48 timestamp) internal view returns (address[] memory array) {
        uint256 arrayLen = self.array.length;
        array = new address[](arrayLen);
        uint256 len;
        for (uint256 i; i < arrayLen; ++i) {
            if (self.array[i].status.wasActiveAt(timestamp)) {
                array[len++] = self.array[i].value;
            }
        }

        assembly {
            mstore(array, len)
        }
        return array;
    }

    /**
     * @notice Checks if an address was active at a given timestamp
     * @param self The AddressSet to query
     * @param timestamp The timestamp to check
     * @param value The address to check
     * @return bool Whether the address was active
     */
    function wasActiveAt(AddressSet storage self, uint48 timestamp, address value) internal view returns (bool) {
        uint256 pos = self.positions[value];
        return pos != 0 && self.array[pos - 1].status.wasActiveAt(timestamp);
    }

    /**
     * @notice Registers a new address
     * @param self The AddressSet to modify
     * @param timestamp The timestamp to set as enabled
     * @param value The address to register
     */
    function register(AddressSet storage self, uint48 timestamp, address value) internal {
        if (self.positions[value] != 0) revert AlreadyRegistered();

        InnerAddress storage element = self.array.push();
        element.value = value;
        element.status.set(timestamp);
        self.positions[value] = self.array.length;
    }

    /**
     * @notice Pauses an address
     * @param self The AddressSet to modify
     * @param timestamp The timestamp to set as disabled
     * @param value The address to pause
     */
    function pause(AddressSet storage self, uint48 timestamp, address value) internal {
        if (self.positions[value] == 0) revert NotRegistered();
        self.array[self.positions[value] - 1].status.disable(timestamp);
    }

    /**
     * @notice Unpauses an address
     * @param self The AddressSet to modify
     * @param timestamp The timestamp to set as enabled
     * @param immutablePeriod The required waiting period after disabling
     * @param value The address to unpause
     */
    function unpause(AddressSet storage self, uint48 timestamp, uint48 immutablePeriod, address value) internal {
        if (self.positions[value] == 0) revert NotRegistered();
        self.array[self.positions[value] - 1].status.enable(timestamp, immutablePeriod);
    }

    /**
     * @notice Unregisters an address
     * @param self The AddressSet to modify
     * @param timestamp The current timestamp
     * @param immutablePeriod The required waiting period after disabling
     * @param value The address to unregister
     */
    function unregister(AddressSet storage self, uint48 timestamp, uint48 immutablePeriod, address value) internal {
        uint256 pos = self.positions[value];
        if (pos == 0) revert NotRegistered();
        pos--;

        self.array[pos].status.validateUnregister(timestamp, immutablePeriod);

        if (self.array.length <= pos + 1) {
            delete self.positions[value];
            self.array.pop();
            return;
        }

        self.array[pos] = self.array[self.array.length - 1];
        self.array.pop();

        delete self.positions[value];
        self.positions[self.array[pos].value] = pos + 1;
    }

    /**
     * @notice Checks if an address is registered
     * @param self The AddressSet to query
     * @param value The address to check
     * @return bool Whether the address is registered
     */
    function contains(AddressSet storage self, address value) internal view returns (bool) {
        return self.positions[value] != 0;
    }

    /**
     * @notice Checks if an address can be unregistered
     * @param self The AddressSet to query
     * @param timestamp The current timestamp
     * @param immutablePeriod The required waiting period after disabling
     * @param value The address to check
     * @return bool Whether the address can be unregistered
     */
    function checkUnregister(
        AddressSet storage self,
        uint48 timestamp,
        uint48 immutablePeriod,
        address value
    ) internal view returns (bool) {
        uint256 pos = self.positions[value];
        if (pos == 0) revert NotRegistered();
        pos--;
        return self.array[pos].status.checkUnregister(timestamp, immutablePeriod);
    }

    // Uint160Set functions

    /**
     * @notice Gets the number of uint160s in the set
     * @param self The Uint160Set to query
     * @return uint256 The number of uint160s
     */
    function length(
        Uint160Set storage self
    ) internal view returns (uint256) {
        return self.set.length();
    }

    /**
     * @notice Gets the uint160 and status at a given position
     * @param self The Uint160Set to query
     * @param pos The position to query
     * @return The uint160, enabled timestamp, and disabled timestamp
     */
    function at(Uint160Set storage self, uint256 pos) internal view returns (uint160, uint48, uint48) {
        (address value, uint48 enabled, uint48 disabled) = self.set.at(pos);
        return (uint160(value), enabled, disabled);
    }

    /**
     * @notice Gets all active uint160s at a given timestamp
     * @param self The Uint160Set to query
     * @param timestamp The timestamp to check
     * @return array Array of active uint160s
     */
    function getActive(Uint160Set storage self, uint48 timestamp) internal view returns (uint160[] memory array) {
        address[] memory addressArray = self.set.getActive(timestamp);
        assembly {
            array := addressArray
        }
        return array;
    }

    /**
     * @notice Checks if a uint160 was active at a given timestamp
     * @param self The Uint160Set to query
     * @param timestamp The timestamp to check
     * @param value The uint160 to check
     * @return bool Whether the uint160 was active
     */
    function wasActiveAt(Uint160Set storage self, uint48 timestamp, uint160 value) internal view returns (bool) {
        return self.set.wasActiveAt(timestamp, address(value));
    }

    /**
     * @notice Registers a new uint160
     * @param self The Uint160Set to modify
     * @param timestamp The timestamp to set as enabled
     * @param value The uint160 to register
     */
    function register(Uint160Set storage self, uint48 timestamp, uint160 value) internal {
        self.set.register(timestamp, address(value));
    }

    /**
     * @notice Pauses a uint160
     * @param self The Uint160Set to modify
     * @param timestamp The timestamp to set as disabled
     * @param value The uint160 to pause
     */
    function pause(Uint160Set storage self, uint48 timestamp, uint160 value) internal {
        self.set.pause(timestamp, address(value));
    }

    /**
     * @notice Unpauses a uint160
     * @param self The Uint160Set to modify
     * @param timestamp The timestamp to set as enabled
     * @param immutablePeriod The required waiting period after disabling
     * @param value The uint160 to unpause
     */
    function unpause(Uint160Set storage self, uint48 timestamp, uint48 immutablePeriod, uint160 value) internal {
        self.set.unpause(timestamp, immutablePeriod, address(value));
    }

    /**
     * @notice Unregisters a uint160
     * @param self The Uint160Set to modify
     * @param timestamp The current timestamp
     * @param immutablePeriod The required waiting period after disabling
     * @param value The uint160 to unregister
     */
    function unregister(Uint160Set storage self, uint48 timestamp, uint48 immutablePeriod, uint160 value) internal {
        self.set.unregister(timestamp, immutablePeriod, address(value));
    }

    /**
     * @notice Checks if a uint160 is registered
     * @param self The Uint160Set to query
     * @param value The uint160 to check
     * @return bool Whether the uint160 is registered
     */
    function contains(Uint160Set storage self, uint160 value) internal view returns (bool) {
        return self.set.contains(address(value));
    }
}

//SPDX-License-Identifier: GPL-3.0-or-later

// Copyright (C) Moondance Labs Ltd.
// This file is part of Tanssi.
// Tanssi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Tanssi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Tanssi.  If not, see <http://www.gnu.org/licenses/>
pragma solidity ^0.8.0;

import {ParaID} from "../Types.sol";
import {IGateway} from "./IGateway.sol";

interface IOGateway is IGateway {
    // Emitted when operators data has been created
    event OperatorsDataCreated(uint256 indexed validatorsCount, bytes payload);

    // Emitted when owner of the gateway is changed.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Emitted when the middleware contract address is changed by the owner.
    event MiddlewareChanged(address indexed previousMiddleware, address indexed newMiddleware);

    // Emitted when the middleware fails to apply an individual slash
    event UnableToProcessIndividualSlashB(
        bytes32 indexed operatorKey, uint256 slashFranction, uint256 indexed epoch, bytes error
    );

    // Emitted when the middleware fails to apply an individual slash
    event UnableToProcessIndividualSlashS(
        bytes32 indexed operatorKey, uint256 slashFranction, uint256 indexed epoch, string error
    );

    // Emitted when the middleware fails to apply the slash message
    event UnableToProcessSlashMessageB(bytes error);

    // Emitted when the middleware fails to apply the slash message
    event UnableToProcessSlashMessageS(string error);

    // Emitted when the middleware fails to apply the slash message
    event UnableToProcessRewardsMessageB(bytes error);

    // Emitted when the middleware fails to apply the slash message
    event UnableToProcessRewardsMessageS(string error);

    // Slash struct, used to decode slashes, which are identified by
    // operatorKey to be slashed
    // slashFraction to be applied as parts per billion
    // epoch identifying when the slash happened
    struct Slash {
        bytes32 operatorKey;
        uint256 slashFraction;
        uint256 epoch;
    }

    struct SlashParams {
        uint256 eraIndex;
        Slash[] slashes;
    }

    function s_middleware() external view returns (address);

    function reportSlashes(bytes calldata data) external;

    function sendRewards(bytes calldata data) external;

    function sendOperatorsData(bytes32[] calldata data, uint48 epoch) external;

    function setMiddleware(address middleware) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Moondance Labs Ltd.
// This file is part of Tanssi.
// Tanssi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Tanssi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Tanssi.  If not, see <http://www.gnu.org/licenses/>

pragma solidity ^0.8.0;

interface IODefaultStakerRewards {
    error ODefaultStakerRewards__AlreadySet();
    error ODefaultStakerRewards__HighAdminFee();
    error ODefaultStakerRewards__InsufficientAdminFee();
    error ODefaultStakerRewards__InsufficientReward();
    error ODefaultStakerRewards__InvalidAddress();
    error ODefaultStakerRewards__InvalidAdminFee();
    error ODefaultStakerRewards__InvalidRecipient();
    error ODefaultStakerRewards__InvalidRewardTimestamp();
    error ODefaultStakerRewards__MissingRoles();
    error ODefaultStakerRewards__NoRewardsToClaim();

    /**
     * @notice Emitted when a reward is distributed.
     * @param network network on behalf of which the reward is distributed
     * @param tokenAddress address of the reward token
     * @param eraIndex era index of Starlight's rewards distribution
     * @param epoch epoch of the reward distribution
     * @param amount amount of tokens
     * @param data some used data
     */
    event DistributeRewards(
        address network,
        address indexed tokenAddress,
        uint48 indexed eraIndex,
        uint48 indexed epoch,
        uint256 amount,
        bytes data
    );

    /**
     * @notice Emitted when rewards are claimed.
     * @param network address of the network
     * @param tokenAddress address of the reward token
     * @param claimer account that claimed the reward
     * @param epoch epoch of the reward
     * @param recipient account that received the reward
     * @param amount amount of tokens claimed
     */
    event ClaimRewards(
        address network,
        address indexed tokenAddress,
        address indexed claimer,
        uint48 indexed epoch,
        address recipient,
        uint256 amount
    );

    /**
     * @notice Emitted when an admin fee is claimed.
     * @param recipient account that received the fee
     * @param tokenAddress address of the reward token
     * @param epoch epoch of the claimed fee
     * @param amount amount of the fee claimed
     */
    event ClaimAdminFee(address indexed recipient, address indexed tokenAddress, uint48 indexed epoch, uint256 amount);

    /**
     * @notice Emitted when an admin fee is set.
     * @param adminFee admin fee
     */
    event SetAdminFee(uint256 adminFee);

    /**
     * @notice Initial parameters needed for a staker rewards contract deployment.
     * @param adminFee admin fee (up to ADMIN_FEE_BASE inclusively)
     * @param defaultAdminRoleHolder address of the initial DEFAULT_ADMIN_ROLE holder
     * @param adminFeeClaimRoleHolder address of the initial ADMIN_FEE_CLAIM_ROLE holder
     * @param adminFeeSetRoleHolder address of the initial ADMIN_FEE_SET_ROLE holder
     */
    struct InitParams {
        uint256 adminFee;
        address defaultAdminRoleHolder;
        address adminFeeClaimRoleHolder;
        address adminFeeSetRoleHolder;
    }

    /**
     * @notice Get a version of the staker rewards contract (different versions mean different interfaces).
     * @return version of the staker rewards contract
     * @dev Must return 1 for this one.
     */
    function VERSION() external view returns (uint64);

    /**
     * @notice Get the maximum admin fee (= 100%).
     * @return maximum admin fee
     */
    function ADMIN_FEE_BASE() external view returns (uint256);

    /**
     * @notice Get the admin fee claimer's role.
     * @return identifier of the admin fee claimer role
     */
    function ADMIN_FEE_CLAIM_ROLE() external view returns (bytes32);

    /**
     * @notice Get the admin fee setter's role.
     * @return identifier of the admin fee setter role
     */
    function ADMIN_FEE_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get the operator rewards role.
     * @return identifier of the operator rewards role
     */
    function OPERATOR_REWARDS_ROLE() external view returns (bytes32);

    /**
     * @notice Get the network middleware service's address.
     * @return address of the network middleware service
     */
    function i_networkMiddlewareService() external view returns (address);

    /**
     * @notice Get the network's address.
     * @return address of the network
     * @dev set during initalization, so it's immutable
     */
    function i_network() external view returns (address);

    /**
     * @notice Get the vault's address.
     * @return address of the vault
     * @dev set during initalization, so it's immutable
     */
    function i_vault() external view returns (address);

    /**
     * @notice Get an admin fee.
     * @return admin fee
     */
    function adminFee() external view returns (uint256);

    /**
     * @notice Get a specific reward for a given epoch.
     * @param epoch The epoch of the reward.
     * @param tokenAddress The address of the token for the specified reward.
     * @return amount The amount of tokens for the specified reward.
     */
    function rewards(uint48 epoch, address tokenAddress) external view returns (uint256 amount);

    /**
     * @notice Get the amount already claimed by the staker
     * @param account address of the account
     * @param epoch epoch to check for unclaimed rewards
     * @param tokenAddress address of the token for the rewards
     * @return claimed amount that has been already claimed
     */
    function stakerClaimedRewardPerEpoch(
        address account,
        uint48 epoch,
        address tokenAddress
    ) external view returns (uint256 claimed);

    /**
     * @notice Get a claimable admin fee amount for a given epoch.
     * @param epoch epoch for which the admin fee can be claimed
     * @param tokenAddress address of the token for the admin fee
     * @return amount claimable admin fee
     */
    function claimableAdminFee(uint48 epoch, address tokenAddress) external view returns (uint256 amount);

    /**
     * @notice Get an amount of rewards claimable by a particular account for a given epoch.
     * @param epoch epoch for which the rewards can be claimed
     * @param account address of the claimer
     * @param tokenAddress address of the reward token
     * @return amount of claimable tokens
     */
    function claimable(uint48 epoch, address account, address tokenAddress) external view returns (uint256);

    /**
     * @notice Distribute rewards for a particular epoch
     * @param epoch epoch of the reward distribution
     * @param eraIndex era index of Starlight's rewards distribution
     * @param amount amount of tokens
     * @param tokenAddress address of the reward token
     * @param data some data to use
     */
    function distributeRewards(
        uint48 epoch,
        uint48 eraIndex,
        uint256 amount,
        address tokenAddress,
        bytes calldata data
    ) external;

    /**
     * @notice Claim rewards for a given epoch.
     * @param recipient address of the tokens' recipient
     * @param epoch epoch for which the rewards are being claimed.
     * @param tokenAddress address of the reward token
     * @param activeSharesOfHints hint indexes to optimize `activeSharesOf()` processing
     */
    function claimRewards(
        address recipient,
        uint48 epoch,
        address tokenAddress,
        bytes calldata activeSharesOfHints
    ) external;

    /**
     * @notice Claim an admin fee.
     * @param recipient account that will receive the fee
     * @param epoch epoch for which the fee is being claimed
     * @param tokenAddress address of the token for the admin fee
     * @dev Only the vault owner can call this function.
     */
    function claimAdminFee(address recipient, uint48 epoch, address tokenAddress) external;

    /**
     * @notice Set an admin fee.
     * @param adminFee_ admin fee (up to ADMIN_FEE_BASE inclusively)
     * @dev Only the ADMIN_FEE_SET_ROLE holder can call this function.
     */
    function setAdminFee(
        uint256 adminFee_
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Moondance Labs Ltd.
// This file is part of Tanssi.
// Tanssi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Tanssi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Tanssi.  If not, see <http://www.gnu.org/licenses/>

pragma solidity ^0.8.0;

interface IODefaultOperatorRewards {
    error ODefaultOperatorRewards__AlreadyClaimed();
    error ODefaultOperatorRewards__InsufficientTransfer();
    error ODefaultOperatorRewards__RootNotSet();
    error ODefaultOperatorRewards__InvalidProof();
    error ODefaultOperatorRewards__InvalidValues();
    error ODefaultOperatorRewards__InvalidOperatorShare();
    error ODefaultOperatorRewards__InvalidAddress();
    error ODefaultOperatorRewards__AlreadySet();
    error ODefaultOperatorRewards__NoVaults();

    /**
     * @notice Emitted when rewards are distributed by providing a Merkle root.
     * @param epoch epoch of the rewards distribution
     * @param eraIndex era index of Starlight's rewards distribution
     * @param root Merkle root of the rewards distribution
     * @dev The Merkle tree's leaves must represent an account and a claimable amount (the total amount of the reward tokens for the whole time).
     */
    event DistributeRewards(
        uint48 indexed epoch,
        uint48 indexed eraIndex,
        address indexed tokenAddress,
        uint256 points,
        uint256 amount,
        bytes32 root
    );

    /**
     * @notice Emitted when rewards are claimed by a particular account.
     * @param recipient address of the rewards' recipient
     * @param tokenAddress address of the reward token
     * @param eraIndex era index of Starlight's rewards distribution
     * @param epoch network epoch of the middleware
     * @param claimer address of the rewards' claimer
     * @param amount amount of tokens claimed
     */
    event ClaimRewards(
        address indexed recipient,
        address indexed tokenAddress,
        uint48 indexed eraIndex,
        uint48 epoch,
        address claimer,
        uint256 amount
    );

    /**
     * @notice Emitted when the staker rewards contract's address is set for a particular vault.
     * @param stakerRewards address of the staker rewards contract
     * @param vault address of the vault
     */
    event SetStakerRewardContract(address indexed stakerRewards, address indexed vault);

    /**
     * @notice Emitted when the operator share of the rewards is set.
     * @param operatorShare operator share of the rewards
     */
    event SetOperatorShare(uint48 indexed operatorShare);

    /**
     * @notice Struct to store the data related to rewards distribution per Starlight's era.
     * @param epoch network epoch of the middleware
     * @param amount amount of tokens received per eraIndex
     * @param tokensPerPoint amount of tokens per point
     * @param root Merkle root of the rewards distribution
     * @param tokenAddress address of the reward token
     */
    struct OldEraRoot {
        uint48 epoch;
        uint256 amount;
        uint256 tokensPerPoint;
        bytes32 root;
        address tokenAddress;
    }

    /**
     * @notice Struct to store the data related to rewards distribution per Starlight's era.
     * @param epoch network epoch of the middleware
     * @param amount amount of tokens received per eraIndex
     * @param totalPoints total amount of points for the reward distribution
     * @param totalAmount total amount of tokens for the reward distribution
     * @param root Merkle root of the rewards distribution
     * @param tokenAddress address of the reward token
     */
    struct EraRoot {
        uint48 epoch;
        uint256 amount;
        uint256 totalPoints;
        bytes32 root;
        address tokenAddress;
    }

    /**
     * @notice Struct to store the data related to claim the rewards distribution per Starlight's era.
     * @param operatorKey operator key of the rewards' recipient
     * @param epoch network epoch of the middleware
     * @param eraIndex era index of Starlight's rewards distribution
     * @param totalPointsClaimable total amount of points that can be claimed
     * @param proof Merkle proof of the rewards distribution
     * @param data additional data to use to distribute rewards to stakers
     */
    struct ClaimRewardsInput {
        bytes32 operatorKey;
        uint48 eraIndex;
        uint32 totalPointsClaimable; //! Are we sure this won't be bigger than a uint32?
        bytes32[] proof;
        bytes data;
    }

    /**
     * @notice Get the network middleware service's address.
     * @return address of the network middleware service
     */
    function i_networkMiddlewareService() external view returns (address);

    /**
     * @notice Get the network identifier.
     * @return network identifier
     */
    function i_network() external view returns (address);

    /**
     * @notice Get the operator share.
     * @return operator share
     */
    function operatorShare() external view returns (uint48);

    /**
     * @notice Get an information of a particular era rewards data distribution
     * @param eraIndex era index of Starlight's rewards distribution
     * @return eraRoot_ information of a particular era rewards data distribution
     */
    function eraRoot(
        uint48 eraIndex
    ) external view returns (EraRoot memory eraRoot_);

    /**
     * @notice Get an array of era indexes for a particular epoch.
     * @param epoch network epoch of the middleware
     * @param index in the array of era indexes
     * @return eraIndex era index of Starlight's rewards distribution
     */
    function eraIndexesPerEpoch(uint48 epoch, uint256 index) external view returns (uint48 eraIndex);

    /**
     * @notice Get a claimed amount of rewards for a particular account and epoch
     * @param eraIndex era index of Starlight's rewards distribution
     * @param account operator key of the rewards' recipient
     * @return amount claimed amount of tokens
     */
    function claimed(uint48 eraIndex, bytes32 account) external view returns (uint256 amount);

    /**
     * @notice Get the staker rewards contract's address for a particular vault
     * @param vault address of the vault
     * @return stakerRewardsAddress address of the staker rewards contract
     */
    function vaultToStakerRewardsContract(
        address vault
    ) external view returns (address stakerRewardsAddress);

    /**
     * @notice Distribute rewards for a specific era contained in an epoch by providing a Merkle root, total points, and total amount of tokens.
     * @param epoch network epoch of the middleware
     * @param eraIndex era index of Starlight's rewards distribution
     * @param amount amount of tokens to distribute
     * @param totalPoints total amount of points for the reward distribution
     * @param root Merkle root of the reward distribution
     * @param tokenAddress address of the reward token
     * @dev Emit DistributeRewards event.
     */
    function distributeRewards(
        uint48 epoch,
        uint48 eraIndex,
        uint256 amount,
        uint256 totalPoints,
        bytes32 root,
        address tokenAddress
    ) external;

    /**
     * @notice Claim rewards for a particular epoch by providing a Merkle proof.
     * @param input data to claim rewards
     * @return amount amount of tokens claimed
     * @dev Emit ClaimRewards event.
     * @dev The input data must contain:
     * @dev - operatorKey operator key of the rewards' recipient
     * @dev - epoch network epoch of the middleware
     * @dev - eraIndex era index of Starlight's rewards distribution
     * @dev - totalPointsClaimable total amount of tokens that can be claimed
     * @dev - proof Merkle proof of the reward distribution
     * @dev - data additional data to use to distribute rewards to stakers
     */
    function claimRewards(
        ClaimRewardsInput calldata input
    ) external returns (uint256 amount);

    /**
     * @notice Set the staker rewards contract's address for a particular vault.
     * @param stakerRewards The address of the staker rewards contract
     * @param vault The address of the vault
     */
    function setStakerRewardContract(address stakerRewards, address vault) external;

    /**
     * @notice Set the operator share of the rewards.
     * @param operatorShare_ operator share of the rewards
     */
    function setOperatorShare(
        uint48 operatorShare_
    ) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) Moondance Labs Ltd.
// This file is part of Tanssi.
// Tanssi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Tanssi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Tanssi.  If not, see <http://www.gnu.org/licenses/>

pragma solidity ^0.8.0;

import {IODefaultStakerRewards} from "./IODefaultStakerRewards.sol";
import {IRegistry} from "@symbioticfi/core/src/interfaces/common/IRegistry.sol";

interface IODefaultStakerRewardsFactory is IRegistry {
    error ODefaultStakerRewardsFactory__InvalidAddress();
    error ODefaultStakerRewardsFactory__NotVault();

    /**
     * @notice Create a default staker rewards contract for a given vault.
     * @param sharedVault address of the shared vault
     * @param params initial parameters needed for a staker rewards contract deployment
     * @return address of the created staker rewards contract
     */
    function create(
        address sharedVault,
        IODefaultStakerRewards.InitParams calldata params
    ) external returns (address);
}

//SPDX-License-Identifier: GPL-3.0-or-later

// Copyright (C) Moondance Labs Ltd.
// This file is part of Tanssi.
// Tanssi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Tanssi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Tanssi.  If not, see <http://www.gnu.org/licenses/>
pragma solidity ^0.8.0;

interface IMiddleware {
    /**
     * @notice Emitted when an oracle is set for a collateral.
     * @dev If the oracle is set to address(0), the collateral will no longer be supported.
     * @param collateral The collateral address
     * @param oracle The oracle address
     */
    event CollateralToOracleSet(address indexed collateral, address indexed oracle);

    /**
     * @notice Emitted when the interval for which the `performUpkeep` should be performed is set.
     * @param interval The interval in seconds
     */
    event IntervalSet(uint256 indexed interval);

    /**
     * @notice Emitted when the forwarder is set.
     * @param forwarder The forwarder address
     */
    event ForwarderSet(address indexed forwarder);

    /**
     * @notice Emitted when a new gateway address is set.
     * @param gateway The new gateway address
     */
    event GatewaySet(address indexed gateway);

    // Errors
    error Middleware__GatewayNotSet();
    error Middleware__AlreadySet();
    error Middleware__TooOldEpoch();
    error Middleware__InvalidEpoch();
    error Middleware__InvalidEpochDuration();
    error Middleware__InvalidAddress();
    error Middleware__InvalidKey();
    error Middleware__InvalidInterval();
    error Middleware__InsufficientBalance();
    error Middleware__NotSupportedCollateral(address collateral);
    error Middleware__SlashingWindowTooShort();
    error Middleware__OperatorNotFound(bytes32 operatorKey, uint48 epoch);
    error Middleware__SlashPercentageTooBig(uint48 epoch, address operator, uint256 percentage);

    /**
     * @notice Validator data structure containing stake and key
     * @param power The validator's power, based on staked tokens and their price
     * @param key The validator's key
     */
    struct ValidatorData {
        uint256 power;
        bytes32 key;
    }

    /**
     * @notice Structure to store slashing parameters
     * @param epochStartTs The epoch start timestamp
     * @param vault The vault address
     * @param operator The operator address
     * @param slashAmount The amount to slash
     */
    struct SlashParams {
        uint48 epochStartTs;
        address vault;
        address operator;
        uint256 slashPercentage;
    }

    /**
     * @notice Structure to pair an operator with their associated vaults
     * @param operator The operator's address
     * @param vaults Array of vault addresses associated with the operator
     */
    struct OperatorVaultPair {
        address operator;
        address[] vaults;
    }

    /**
     * @param network The network address
     * @param operatorRegistry The operator registry address
     * @param vaultRegistry The vault registry address
     * @param operatorNetOptin The operator network optin address
     * @param owner The owner address
     * @param epochDuration The epoch duration
     * @param slashingWindow The slashing window
     * @param reader The reader address
     */
    struct InitParams {
        address network;
        address operatorRegistry;
        address vaultRegistry;
        address operatorNetworkOptIn;
        address owner;
        uint48 epochDuration;
        uint48 slashingWindow;
        address reader;
    }

    /**
     * @notice Sets the gateway contract
     * @dev Only the owner can call this function
     * @param gateway The gateway contract address
     */
    function setGateway(
        address gateway
    ) external;

    /**
     * @notice Sets the interval on which to let Chainlink forwarder to call `performUpkeep`
     * @dev Only the owner can call this function
     * @param interval The interval
     */
    function setInterval(
        uint256 interval
    ) external;

    /**
     * @notice Sets the forwarder address
     * @param forwarder The forwarder address
     */
    function setForwarder(
        address forwarder
    ) external;

    /**
     * @notice Sets the operator share on operator rewards contract
     * @param operatorShare The operator share
     */
    function setOperatorShareOnOperatorRewards(
        uint48 operatorShare
    ) external;

    /**
     * @notice Distribute rewards for a specific era contained in an epoch by providing a Merkle root, total points, total amount of tokens and the token address of the rewards.
     * @param epoch network epoch of the middleware
     * @param eraIndex era index of Starlight's rewards distribution
     * @param totalPoints total amount of points for the reward distribution
     * @param tokenAmount amount of tokens to distribute
     * @param rewardsRoot Merkle root of the reward distribution
     * @param tokenAddress The token address of the rewards
     * @dev This function is called by the gateway only
     * @dev Emit DistributeRewards event.
     */
    function distributeRewards(
        uint256 epoch,
        uint256 eraIndex,
        uint256 totalPoints,
        uint256 tokenAmount,
        bytes32 rewardsRoot,
        address tokenAddress
    ) external;

    /**
     * @notice Gets the operators' keys for latest epoch
     * @return keys Array of operator keys
     */
    function sendCurrentOperatorsKeys() external returns (bytes32[] memory keys);

    /**
     * @notice Slashes an operator's stake
     * @dev Only the owner can call this function
     * @dev This function first updates the stake cache for the target epoch
     * @param epoch The epoch number
     * @param operatorKey The operator key to slash
     * @param percentage Percentage to slash, represented as parts per billion.
     */
    function slash(uint48 epoch, bytes32 operatorKey, uint256 percentage) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseMiddleware} from "@symbiotic-middleware/middleware/BaseMiddleware.sol";
import {IOSharedVaults} from "src/interfaces/extensions/IOSharedVaults.sol";
import {IODefaultStakerRewards} from "src/interfaces/rewarder/IODefaultStakerRewards.sol";

/**
 * @title OSharedVaults
 * @notice Contract for managing shared vaults that can be used by multiple operators
 * @dev Extends BaseMiddleware to provide access control for vault management functions
 */
abstract contract OSharedVaults is BaseMiddleware, IOSharedVaults {
    uint64 public constant SharedVaults_VERSION = 1;

    /**
     * @inheritdoc IOSharedVaults
     */
    function registerSharedVault(
        address sharedVault,
        IODefaultStakerRewards.InitParams memory stakerRewardsParams
    ) public checkAccess {
        _beforeRegisterSharedVault(sharedVault);
        _registerSharedVault(sharedVault);
        _afterRegisterSharedVault(sharedVault, stakerRewardsParams);
    }

    /**
     * @inheritdoc IOSharedVaults
     */
    function pauseSharedVault(
        address sharedVault
    ) public checkAccess {
        _beforePauseSharedVault(sharedVault);
        _pauseSharedVault(sharedVault);
    }

    /**
     * @inheritdoc IOSharedVaults
     */
    function unpauseSharedVault(
        address sharedVault
    ) public checkAccess {
        _beforeUnpauseSharedVault(sharedVault);
        _unpauseSharedVault(sharedVault);
    }

    /**
     * @inheritdoc IOSharedVaults
     */
    function unregisterSharedVault(
        address sharedVault
    ) public checkAccess {
        _beforeUnregisterSharedVault(sharedVault);
        _unregisterSharedVault(sharedVault);
    }

    /**
     * @notice Hook called before registering a shared vault
     * @param sharedVault The vault address
     */
    function _beforeRegisterSharedVault(
        address sharedVault
    ) internal virtual {}

    /**
     * @notice Hook called after registering a shared vault
     * @param sharedVault The vault address
     * @param stakerRewardsParams Init params to create a staker rewards contract associated with the shared vault
     */
    function _afterRegisterSharedVault(
        address sharedVault,
        IODefaultStakerRewards.InitParams memory stakerRewardsParams
    ) internal virtual {}

    /**
     * @notice Hook called before pausing a shared vault
     * @param sharedVault The vault address
     */
    function _beforePauseSharedVault(
        address sharedVault
    ) internal virtual {}

    /**
     * @notice Hook called before unpausing a shared vault
     * @param sharedVault The vault address
     */
    function _beforeUnpauseSharedVault(
        address sharedVault
    ) internal virtual {}

    /**
     * @notice Hook called before unregistering a shared vault
     * @param sharedVault The vault address
     */
    function _beforeUnregisterSharedVault(
        address sharedVault
    ) internal virtual {}
}

//SPDX-License-Identifier: GPL-3.0-or-later

// Copyright (C) Moondance Labs Ltd.
// This file is part of Tanssi.
// Tanssi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Tanssi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Tanssi.  If not, see <http://www.gnu.org/licenses/>
pragma solidity 0.8.25;

abstract contract MiddlewareStorage {
    /// @custom:storage-location erc7201:tanssi.middleware.MiddlewareStorage.v1.1
    struct StorageMiddleware {
        address gateway;
        uint256 lastTimestamp;
        uint256 interval;
        address forwarderAddress;
        mapping(address collateral => address oracle) collateralToOracle;
        mapping(address vault => address collateral) vaultToCollateral;
        uint256 lastExecutionBlock;
    }

    // keccak256(abi.encode(uint256(keccak256("tanssi.middleware.MiddlewareStorage.v1.1")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant MIDDLEWARE_STORAGE_LOCATION =
        0xca64b196a0d05040904d062f739ed1d1e1d3cc5de78f7001fb9039595fce9100;

    uint8 public constant DEFAULT_DECIMALS = 18;
    uint256 public constant VERSION = 1;
    uint256 public constant PARTS_PER_BILLION = 1_000_000_000;
    uint256 public constant MIN_INTERVAL_TO_SEND_OPERATOR_KEYS = 50; // 600 seconds ≈ 10 minutes
    bytes32 internal constant GATEWAY_ROLE = keccak256("GATEWAY_ROLE");
    bytes32 internal constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");

    /**
     * @notice Get the operator rewards contract address
     * @return operator rewards contract address
     */
    address public immutable i_operatorRewards;

    /**
     * @notice Get the staker rewards factory contract address
     * @return staker rewards factory contract address
     */
    address public immutable i_stakerRewardsFactory;

    function _getMiddlewareStorage() internal pure returns (StorageMiddleware storage $v1) {
        assembly {
            $v1.slot := MIDDLEWARE_STORAGE_LOCATION
        }
    }

    /**
     * @notice Get the gateway contract
     * @return gateway contract
     */
    function getGateway() public view returns (address) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        return $.gateway;
    }

    /**
     * @notice Get the last timestamp
     * @return last timestamp
     */
    function getLastTimestamp() public view returns (uint256) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        return $.lastTimestamp;
    }

    /**
     * @notice Get the forwarder address
     * @return forwarder address
     */
    function getForwarderAddress() public view returns (address) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        return $.forwarderAddress;
    }

    /**
     * @notice Get the interval
     * @return interval
     */
    function getInterval() public view returns (uint256) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        return $.interval;
    }

    /**
     * @notice Get the oracle address for a collateral
     * @return oracle address
     */
    function collateralToOracle(
        address collateral
    ) public view returns (address) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        return $.collateralToOracle[collateral];
    }

    /**
     * @notice Get the collateral address for a vault
     * @return collateral address
     */
    function vaultToCollateral(
        address vault
    ) public view returns (address) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        return $.vaultToCollateral[vault];
    }

    /**
     * @notice Get the oracle address for a vault
     * @return oracle address
     */
    function vaultToOracle(
        address vault
    ) public view returns (address) {
        StorageMiddleware storage $ = _getMiddlewareStorage();
        return $.collateralToOracle[$.vaultToCollateral[vault]];
    }
}

//SPDX-License-Identifier: GPL-3.0-or-later

// Copyright (C) Moondance Labs Ltd.
// This file is part of Tanssi.
// Tanssi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Tanssi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Tanssi.  If not, see <http://www.gnu.org/licenses/>
pragma solidity ^0.8.0;

import {IMiddleware} from "src/interfaces/middleware/IMiddleware.sol";

interface IOBaseMiddlewareReader {
    function getCaptureTimestamp() external view returns (uint48 timestamp);

    function stakeToPower(address vault, uint256 stake) external view returns (uint256 power);

    function keyWasActiveAt(uint48 timestamp, bytes memory key) external view returns (bool);

    function operatorKey(
        address operator
    ) external view returns (bytes memory);

    function operatorByKey(
        bytes memory key
    ) external view returns (address);

    function getEpochStart(
        uint48 epoch
    ) external view returns (uint48);

    function getCurrentEpoch() external view returns (uint48);

    function getEpochDuration() external view returns (uint48);

    function NETWORK() external view returns (address);

    function SLASHING_WINDOW() external view returns (uint48);

    function VAULT_REGISTRY() external view returns (address);

    function OPERATOR_REGISTRY() external view returns (address);

    function OPERATOR_NET_OPTIN() external view returns (address);

    function operatorsLength() external view returns (uint256);

    function operatorWithTimesAt(
        uint256 pos
    ) external view returns (address, uint48, uint48);

    function activeOperators() external view returns (address[] memory);

    function activeOperatorsAt(
        uint48 timestamp
    ) external view returns (address[] memory);

    function operatorWasActiveAt(uint48 timestamp, address operator) external view returns (bool);

    function isOperatorRegistered(
        address operator
    ) external view returns (bool);

    function subnetworksLength() external view returns (uint256);

    function subnetworkWithTimesAt(
        uint256 pos
    ) external view returns (uint160, uint48, uint48);

    function activeSubnetworks() external view returns (uint160[] memory);

    function activeSubnetworksAt(
        uint48 timestamp
    ) external view returns (uint160[] memory);

    function subnetworkWasActiveAt(uint48 timestamp, uint96 subnetwork) external view returns (bool);

    function sharedVaultsLength() external view returns (uint256);

    function sharedVaultWithTimesAt(
        uint256 pos
    ) external view returns (address, uint48, uint48);

    function activeSharedVaults() external view returns (address[] memory);

    function activeSharedVaultsAt(
        uint48 timestamp
    ) external view returns (address[] memory);

    function operatorVaultsLength(
        address operator
    ) external view returns (uint256);

    function operatorVaultWithTimesAt(address operator, uint256 pos) external view returns (address, uint48, uint48);

    function activeOperatorVaults(
        address operator
    ) external view returns (address[] memory);

    function activeOperatorVaultsAt(uint48 timestamp, address operator) external view returns (address[] memory);

    function activeVaults() external view returns (address[] memory);

    function activeVaultsAt(
        uint48 timestamp
    ) external view returns (address[] memory);

    function activeVaults(
        address operator
    ) external view returns (address[] memory);

    function activeVaultsAt(uint48 timestamp, address operator) external view returns (address[] memory);

    function vaultWasActiveAt(uint48 timestamp, address operator, address vault) external view returns (bool);

    function sharedVaultWasActiveAt(uint48 timestamp, address vault) external view returns (bool);

    function operatorVaultWasActiveAt(uint48 timestamp, address operator, address vault) external view returns (bool);

    function getOperatorPower(address operator, address vault, uint96 subnetwork) external view returns (uint256);

    function getOperatorPowerAt(
        uint48 timestamp,
        address operator,
        address vault,
        uint96 subnetwork
    ) external view returns (uint256);

    function getOperatorPower(
        address operator
    ) external view returns (uint256);

    function getOperatorPowerAt(uint48 timestamp, address operator) external view returns (uint256);

    function getOperatorPower(
        address operator,
        address[] memory vaults,
        uint160[] memory subnetworks
    ) external view returns (uint256);

    function getOperatorPowerAt(
        uint48 timestamp,
        address operator,
        address[] memory vaults,
        uint160[] memory subnetworks
    ) external view returns (uint256);

    function totalPower(
        address[] memory operators
    ) external view returns (uint256);

    function getOperatorsByEpoch(
        uint48 epoch
    ) external view returns (address[] memory activeOperators_);

    function getOperatorVaultPairs(
        uint48 epoch
    ) external view returns (IMiddleware.OperatorVaultPair[] memory operatorVaultPairs);

    function isVaultRegistered(
        address vault
    ) external view returns (bool);

    function sortOperatorsByPower(
        uint48 epoch
    ) external view returns (bytes32[] memory sortedKeys);

    function getOperatorVaults(
        address operator,
        uint48 epochStartTs
    ) external view returns (uint256 vaultIdx, address[] memory _vaults);

    function getTotalStake(
        uint48 epoch
    ) external view returns (uint256);

    function getOperatorKeyAt(address operator, uint48 timestamp) external view returns (bytes memory);

    function getValidatorSet(
        uint48 epoch
    ) external view returns (IMiddleware.ValidatorData[] memory validatorsData);

    function getEpochAtTs(
        uint48 timestamp
    ) external view returns (uint48 epoch);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface AggregatorInterface {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.20;

/**
 * @dev Wrappers over Solidity's uintXX/intXX/bool casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast {
    /**
     * @dev Value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev An uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }

    /**
     * @dev Cast a boolean (false or true) to a uint256 (0 or 1) with no jump.
     */
    function toUint(bool b) internal pure returns (uint256 u) {
        assembly ("memory-safe") {
            u := iszero(iszero(b))
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC-1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
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
// OpenZeppelin Contracts (last updated v5.2.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.22;

import {IBeacon} from "../beacon/IBeacon.sol";
import {IERC1967} from "../../interfaces/IERC1967.sol";
import {Address} from "../../utils/Address.sol";
import {StorageSlot} from "../../utils/StorageSlot.sol";

/**
 * @dev This library provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[ERC-1967] slots.
 */
library ERC1967Utils {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
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
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit IERC1967.Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by ERC-1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the ERC-1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit IERC1967.AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the ERC-1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit IERC1967.BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
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
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Panic.sol)

pragma solidity ^0.8.20;

/**
 * @dev Helper library for emitting standardized panic codes.
 *
 * ```solidity
 * contract Example {
 *      using Panic for uint256;
 *
 *      // Use any of the declared internal constants
 *      function foo() { Panic.GENERIC.panic(); }
 *
 *      // Alternatively
 *      function foo() { Panic.panic(Panic.GENERIC); }
 * }
 * ```
 *
 * Follows the list from https://github.com/ethereum/solidity/blob/v0.8.24/libsolutil/ErrorCodes.h[libsolutil].
 *
 * _Available since v5.1._
 */
// slither-disable-next-line unused-state
library Panic {
    /// @dev generic / unspecified error
    uint256 internal constant GENERIC = 0x00;
    /// @dev used by the assert() builtin
    uint256 internal constant ASSERT = 0x01;
    /// @dev arithmetic underflow or overflow
    uint256 internal constant UNDER_OVERFLOW = 0x11;
    /// @dev division or modulo by zero
    uint256 internal constant DIVISION_BY_ZERO = 0x12;
    /// @dev enum conversion error
    uint256 internal constant ENUM_CONVERSION_ERROR = 0x21;
    /// @dev invalid encoding in storage
    uint256 internal constant STORAGE_ENCODING_ERROR = 0x22;
    /// @dev empty array pop
    uint256 internal constant EMPTY_ARRAY_POP = 0x31;
    /// @dev array out of bounds access
    uint256 internal constant ARRAY_OUT_OF_BOUNDS = 0x32;
    /// @dev resource error (too large allocation or too large array)
    uint256 internal constant RESOURCE_ERROR = 0x41;
    /// @dev calling invalid internal function
    uint256 internal constant INVALID_INTERNAL_FUNCTION = 0x51;

    /// @dev Reverts with a panic code. Recommended to use with
    /// the internal constants with predefined codes.
    function panic(uint256 code) internal pure {
        assembly ("memory-safe") {
            mstore(0x00, 0x4e487b71)
            mstore(0x20, code)
            revert(0x1c, 0x24)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMigratableEntity {
    error AlreadyInitialized();
    error NotFactory();
    error NotInitialized();

    /**
     * @notice Get the factory's address.
     * @return address of the factory
     */
    function FACTORY() external view returns (address);

    /**
     * @notice Get the entity's version.
     * @return version of the entity
     * @dev Starts from 1.
     */
    function version() external view returns (uint64);

    /**
     * @notice Initialize this entity contract by using a given data and setting a particular version and owner.
     * @param initialVersion initial version of the entity
     * @param owner initial owner of the entity
     * @param data some data to use
     */
    function initialize(uint64 initialVersion, address owner, bytes calldata data) external;

    /**
     * @notice Migrate this entity to a particular newer version using a given data.
     * @param newVersion new version of the entity
     * @param data some data to use
     */
    function migrate(uint64 newVersion, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultStorage {
    error InvalidTimestamp();
    error NoPreviousEpoch();

    /**
     * @notice Get a deposit whitelist enabler/disabler's role.
     * @return identifier of the whitelist enabler/disabler role
     */
    function DEPOSIT_WHITELIST_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get a depositor whitelist status setter's role.
     * @return identifier of the depositor whitelist status setter role
     */
    function DEPOSITOR_WHITELIST_ROLE() external view returns (bytes32);

    /**
     * @notice Get a deposit limit enabler/disabler's role.
     * @return identifier of the deposit limit enabler/disabler role
     */
    function IS_DEPOSIT_LIMIT_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get a deposit limit setter's role.
     * @return identifier of the deposit limit setter role
     */
    function DEPOSIT_LIMIT_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get the delegator factory's address.
     * @return address of the delegator factory
     */
    function DELEGATOR_FACTORY() external view returns (address);

    /**
     * @notice Get the slasher factory's address.
     * @return address of the slasher factory
     */
    function SLASHER_FACTORY() external view returns (address);

    /**
     * @notice Get a vault collateral.
     * @return address of the underlying collateral
     */
    function collateral() external view returns (address);

    /**
     * @notice Get a burner to issue debt to (e.g., 0xdEaD or some unwrapper contract).
     * @return address of the burner
     */
    function burner() external view returns (address);

    /**
     * @notice Get a delegator (it delegates the vault's stake to networks and operators).
     * @return address of the delegator
     */
    function delegator() external view returns (address);

    /**
     * @notice Get if the delegator is initialized.
     * @return if the delegator is initialized
     */
    function isDelegatorInitialized() external view returns (bool);

    /**
     * @notice Get a slasher (it provides networks a slashing mechanism).
     * @return address of the slasher
     */
    function slasher() external view returns (address);

    /**
     * @notice Get if the slasher is initialized.
     * @return if the slasher is initialized
     */
    function isSlasherInitialized() external view returns (bool);

    /**
     * @notice Get a time point of the epoch duration set.
     * @return time point of the epoch duration set
     */
    function epochDurationInit() external view returns (uint48);

    /**
     * @notice Get a duration of the vault epoch.
     * @return duration of the epoch
     */
    function epochDuration() external view returns (uint48);

    /**
     * @notice Get an epoch at a given timestamp.
     * @param timestamp time point to get the epoch at
     * @return epoch at the timestamp
     * @dev Reverts if the timestamp is less than the start of the epoch 0.
     */
    function epochAt(
        uint48 timestamp
    ) external view returns (uint256);

    /**
     * @notice Get a current vault epoch.
     * @return current epoch
     */
    function currentEpoch() external view returns (uint256);

    /**
     * @notice Get a start of the current vault epoch.
     * @return start of the current epoch
     */
    function currentEpochStart() external view returns (uint48);

    /**
     * @notice Get a start of the previous vault epoch.
     * @return start of the previous epoch
     * @dev Reverts if the current epoch is 0.
     */
    function previousEpochStart() external view returns (uint48);

    /**
     * @notice Get a start of the next vault epoch.
     * @return start of the next epoch
     */
    function nextEpochStart() external view returns (uint48);

    /**
     * @notice Get if the deposit whitelist is enabled.
     * @return if the deposit whitelist is enabled
     */
    function depositWhitelist() external view returns (bool);

    /**
     * @notice Get if a given account is whitelisted as a depositor.
     * @param account address to check
     * @return if the account is whitelisted as a depositor
     */
    function isDepositorWhitelisted(
        address account
    ) external view returns (bool);

    /**
     * @notice Get if the deposit limit is set.
     * @return if the deposit limit is set
     */
    function isDepositLimit() external view returns (bool);

    /**
     * @notice Get a deposit limit (maximum amount of the active stake that can be in the vault simultaneously).
     * @return deposit limit
     */
    function depositLimit() external view returns (uint256);

    /**
     * @notice Get a total number of active shares in the vault at a given timestamp using a hint.
     * @param timestamp time point to get the total number of active shares at
     * @param hint hint for the checkpoint index
     * @return total number of active shares at the timestamp
     */
    function activeSharesAt(uint48 timestamp, bytes memory hint) external view returns (uint256);

    /**
     * @notice Get a total number of active shares in the vault.
     * @return total number of active shares
     */
    function activeShares() external view returns (uint256);

    /**
     * @notice Get a total amount of active stake in the vault at a given timestamp using a hint.
     * @param timestamp time point to get the total active stake at
     * @param hint hint for the checkpoint index
     * @return total amount of active stake at the timestamp
     */
    function activeStakeAt(uint48 timestamp, bytes memory hint) external view returns (uint256);

    /**
     * @notice Get a total amount of active stake in the vault.
     * @return total amount of active stake
     */
    function activeStake() external view returns (uint256);

    /**
     * @notice Get a total number of active shares for a particular account at a given timestamp using a hint.
     * @param account account to get the number of active shares for
     * @param timestamp time point to get the number of active shares for the account at
     * @param hint hint for the checkpoint index
     * @return number of active shares for the account at the timestamp
     */
    function activeSharesOfAt(address account, uint48 timestamp, bytes memory hint) external view returns (uint256);

    /**
     * @notice Get a number of active shares for a particular account.
     * @param account account to get the number of active shares for
     * @return number of active shares for the account
     */
    function activeSharesOf(
        address account
    ) external view returns (uint256);

    /**
     * @notice Get a total amount of the withdrawals at a given epoch.
     * @param epoch epoch to get the total amount of the withdrawals at
     * @return total amount of the withdrawals at the epoch
     */
    function withdrawals(
        uint256 epoch
    ) external view returns (uint256);

    /**
     * @notice Get a total number of withdrawal shares at a given epoch.
     * @param epoch epoch to get the total number of withdrawal shares at
     * @return total number of withdrawal shares at the epoch
     */
    function withdrawalShares(
        uint256 epoch
    ) external view returns (uint256);

    /**
     * @notice Get a number of withdrawal shares for a particular account at a given epoch (zero if claimed).
     * @param epoch epoch to get the number of withdrawal shares for the account at
     * @param account account to get the number of withdrawal shares for
     * @return number of withdrawal shares for the account at the epoch
     */
    function withdrawalSharesOf(uint256 epoch, address account) external view returns (uint256);

    /**
     * @notice Get if the withdrawals are claimed for a particular account at a given epoch.
     * @param epoch epoch to check the withdrawals for the account at
     * @param account account to check the withdrawals for
     * @return if the withdrawals are claimed for the account at the epoch
     */
    function isWithdrawalsClaimed(uint256 epoch, address account) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntity} from "../common/IEntity.sol";

interface IBaseSlasher is IEntity {
    error NoBurner();
    error InsufficientBurnerGas();
    error NotNetworkMiddleware();
    error NotVault();

    /**
     * @notice Base parameters needed for slashers' deployment.
     * @param isBurnerHook if the burner is needed to be called on a slashing
     */
    struct BaseParams {
        bool isBurnerHook;
    }

    /**
     * @notice Hints for a slashable stake.
     * @param stakeHints hints for the stake checkpoints
     * @param cumulativeSlashFromHint hint for the cumulative slash amount at a capture timestamp
     */
    struct SlashableStakeHints {
        bytes stakeHints;
        bytes cumulativeSlashFromHint;
    }

    /**
     * @notice General data for the delegator.
     * @param slasherType type of the slasher
     * @param data slasher-dependent data for the delegator
     */
    struct GeneralDelegatorData {
        uint64 slasherType;
        bytes data;
    }

    /**
     * @notice Get a gas limit for the burner.
     * @return value of the burner gas limit
     */
    function BURNER_GAS_LIMIT() external view returns (uint256);

    /**
     * @notice Get a reserve gas between the gas limit check and the burner's execution.
     * @return value of the reserve gas
     */
    function BURNER_RESERVE() external view returns (uint256);

    /**
     * @notice Get the vault factory's address.
     * @return address of the vault factory
     */
    function VAULT_FACTORY() external view returns (address);

    /**
     * @notice Get the network middleware service's address.
     * @return address of the network middleware service
     */
    function NETWORK_MIDDLEWARE_SERVICE() external view returns (address);

    /**
     * @notice Get the vault's address.
     * @return address of the vault to perform slashings on
     */
    function vault() external view returns (address);

    /**
     * @notice Get if the burner is needed to be called on a slashing.
     * @return if the burner is a hook
     */
    function isBurnerHook() external view returns (bool);

    /**
     * @notice Get the latest capture timestamp that was slashed on a subnetwork.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @return latest capture timestamp that was slashed
     */
    function latestSlashedCaptureTimestamp(bytes32 subnetwork, address operator) external view returns (uint48);

    /**
     * @notice Get a cumulative slash amount for an operator on a subnetwork until a given timestamp (inclusively) using a hint.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @param timestamp time point to get the cumulative slash amount until (inclusively)
     * @param hint hint for the checkpoint index
     * @return cumulative slash amount until the given timestamp (inclusively)
     */
    function cumulativeSlashAt(
        bytes32 subnetwork,
        address operator,
        uint48 timestamp,
        bytes memory hint
    ) external view returns (uint256);

    /**
     * @notice Get a cumulative slash amount for an operator on a subnetwork.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @return cumulative slash amount
     */
    function cumulativeSlash(bytes32 subnetwork, address operator) external view returns (uint256);

    /**
     * @notice Get a slashable amount of a stake got at a given capture timestamp using hints.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param operator address of the operator
     * @param captureTimestamp time point to get the stake amount at
     * @param hints hints for the checkpoints' indexes
     * @return slashable amount of the stake
     */
    function slashableStake(
        bytes32 subnetwork,
        address operator,
        uint48 captureTimestamp,
        bytes memory hints
    ) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IOperators
 * @notice Interface for managing operator registration, keys, and vault relationships
 */
interface IOperators {
    /**
     * @notice Registers a new operator with an optional vault association
     * @param operator The address of the operator to register
     * @param key The operator's public key
     * @param vault Optional vault address to associate with the operator
     */
    function registerOperator(address operator, bytes memory key, address vault) external;

    /**
     * @notice Unregisters an operator
     * @param operator The address of the operator to unregister
     */
    function unregisterOperator(
        address operator
    ) external;

    /**
     * @notice Pauses an operator
     * @param operator The address of the operator to pause
     */
    function pauseOperator(
        address operator
    ) external;

    /**
     * @notice Unpauses an operator
     * @param operator The address of the operator to unpause
     */
    function unpauseOperator(
        address operator
    ) external;

    /**
     * @notice Updates an operator's public key
     * @param operator The address of the operator
     * @param key The new public key
     */
    function updateOperatorKey(address operator, bytes memory key) external;

    /**
     * @notice Associates an operator with a vault
     * @param operator The address of the operator
     * @param vault The address of the vault
     */
    function registerOperatorVault(address operator, address vault) external;

    /**
     * @notice Removes an operator's association with a vault
     * @param operator The address of the operator
     * @param vault The address of the vault
     */
    function unregisterOperatorVault(address operator, address vault) external;

    /**
     * @notice Pauses an operator's association with a specific vault
     * @param operator The address of the operator
     * @param vault The address of the vault
     */
    function pauseOperatorVault(address operator, address vault) external;

    /**
     * @notice Unpauses an operator's association with a specific vault
     * @param operator The address of the operator
     * @param vault The address of the vault
     */
    function unpauseOperatorVault(address operator, address vault) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {VaultManager} from "../managers/VaultManager.sol";
import {OperatorManager} from "../managers/OperatorManager.sol";
import {AccessManager} from "../managers/extendable/AccessManager.sol";
import {KeyManager} from "../managers/extendable/KeyManager.sol";

/**
 * @title BaseMiddleware
 * @notice Abstract base contract that combines core manager functionality for building middleware
 * @dev Inherits from VaultManager, OperatorManager, AccessManager, and KeyManager to provide:
 *      - Vault management and registration
 *      - Operator management and registration
 *      - Access management
 *      - Key management
 *
 * This contract serves as a foundation for building custom middleware by providing essential
 * management capabilities that can be extended with additional functionality.
 */
abstract contract BaseMiddleware is VaultManager, OperatorManager, AccessManager, KeyManager {
    // This constant aggregates changes of all not extendable managers
    uint64 public constant BaseMiddleware_VERSION = 1;

    // keccak256(abi.encode(uint256(keccak256("symbiotic.storage.BaseMiddleware")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReaderStorageLocation = 0xfd87879bc98f37af7578af722aecfbe5843e5ad354da2d1e70cb5157c4ec8800;

    /**
     * @notice Initializes the BaseMiddleware contract with required dependencies and parameters
     * @dev This internal initialization function sets up core storage and manager components
     * @param network The address of the network contract
     * @param slashingWindow The duration of the slashing window in blocks
     * @param vaultRegistry The address of the vault registry contract
     * @param operatorRegistry The address of the operator registry contract
     * @param operatorNetOptin The address of the operator network opt-in contract
     * @param reader The address of the reader contract used for delegatecall
     */
    function __BaseMiddleware_init(
        address network,
        uint48 slashingWindow,
        address vaultRegistry,
        address operatorRegistry,
        address operatorNetOptin,
        address reader
    ) internal onlyInitializing {
        __NetworkStorage_init_private(network);
        __SlashingWindowStorage_init_private(slashingWindow);
        __VaultManager_init_private(vaultRegistry);
        __OperatorManager_init_private(operatorRegistry, operatorNetOptin);
        assembly {
            sstore(ReaderStorageLocation, reader)
        }
    }

    /**
     * @notice The fallback function is used to implement getter functions by delegating calls to the BasemiddlewareReader contract
     * @dev This allows the BaseMiddleware to expose view functions defined in the BasemiddlewareReader without explicitly implementing them,
     *      reducing code duplication and maintaining a single source of truth for read operations
     */
    fallback() external {
        address reader_;
        assembly {
            reader_ := sload(ReaderStorageLocation)
        }
        (bool success, bytes memory returndata) = reader_.delegatecall(abi.encodePacked(msg.data, address(this)));
        if (!success) {
            assembly {
                revert(add(returndata, 0x20), mload(returndata))
            }
        }
        assembly {
            return(add(returndata, 0x20), mload(returndata))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SlashingWindowStorage} from "../storages/SlashingWindowStorage.sol";
import {CaptureTimestampManager} from "./CaptureTimestampManager.sol";

/**
 * @title KeyManager
 * @notice Abstract contract for managing keys
 */
abstract contract KeyManager is SlashingWindowStorage, CaptureTimestampManager {
    /**
     * @notice Updates the key associated with an operator
     * @param operator The address of the operator
     * @param key The key to update, or empty bytes to delete the key
     */
    function _updateKey(address operator, bytes memory key) internal virtual;

    /**
     * @notice Returns the operator address associated with a given key
     * @param key The key for which to find the associated operator
     * @return The address of the operator linked to the specified key
     */
    function operatorByKey(
        bytes memory key
    ) public view virtual returns (address);

    /**
     * @notice Returns the current or previous key for a given operator
     * @dev Returns the previous key if the key was updated in the current epoch
     * @param operator The address of the operator
     * @return The key associated with the specified operator
     */
    function operatorKey(
        address operator
    ) public view virtual returns (bytes memory);

    /**
     * @notice Checks if a key was active at a specific timestamp
     * @param timestamp The timestamp to check
     * @param key The key to check
     * @return True if the key was active at the timestamp, false otherwise
     */
    function keyWasActiveAt(uint48 timestamp, bytes memory key) public view virtual returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AccessManager
 * @notice Abstract contract for managing access control
 * @dev Provides a modifier and internal function for checking access permissions
 */
abstract contract AccessManager is Initializable {
    /**
     * @notice Modifier that checks access before executing a function
     * @dev Calls internal _checkAccess function and continues if allowed
     */
    modifier checkAccess() {
        _checkAccess();
        _;
    }

    /**
     * @notice Internal function to check if caller has required access
     * @dev Must be implemented by inheriting contracts
     */
    function _checkAccess() internal virtual;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IOzAccessControl
 * @notice Interface for a middleware extension that implements role-based access control
 */
interface IOzAccessControl {
    error AccessControlUnauthorizedAccount(address account, bytes32 role);
    error AccessControlBadConfirmation();

    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event SelectorRoleSet(bytes4 indexed selector, bytes32 indexed role);

    /**
     * @notice Returns true if account has been granted role
     * @param role The role to check
     * @param account The account to check
     * @return bool True if account has role
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @notice Returns the admin role that controls the specified role
     * @param role The role to get the admin for
     * @return bytes32 The admin role
     */
    function getRoleAdmin(
        bytes32 role
    ) external view returns (bytes32);

    /**
     * @notice Returns the role required for a function selector
     * @param selector The function selector
     * @return bytes32 The required role
     */
    function getRole(
        bytes4 selector
    ) external view returns (bytes32);

    /**
     * @notice Grants role to account if caller has admin role
     * @param role The role to grant
     * @param account The account to grant the role to
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @notice Revokes role from account if caller has admin role
     * @param role The role to revoke
     * @param account The account to revoke the role from
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @notice Allows an account to renounce a role they have
     * @param role The role to renounce
     * @param callerConfirmation Address of the caller for confirmation
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
/**
 * @title CaptureTimestampManager
 * @notice Abstract contract for managing capture timestamps
 */

abstract contract CaptureTimestampManager is Initializable {
    /**
     * @notice Returns the current capture timestamp
     * @return timestamp The current capture timestamp
     */
    function getCaptureTimestamp() public view virtual returns (uint48 timestamp);

    /**
     * @notice Returns the current timestamp
     * @return timestamp The current timestamp
     */
    function _now() internal view returns (uint48) {
        return Time.timestamp();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IEpochCapture
 * @notice Interface for a middleware extension that captures timestamps based on epochs
 * @dev Implements timestamp capture using fixed time periods (epochs) from a base timestamp
 */
interface IEpochCapture {
    /**
     * @notice Returns the start timestamp for a given epoch
     * @param epoch The epoch number
     * @return The start timestamp
     */
    function getEpochStart(
        uint48 epoch
    ) external view returns (uint48);

    /**
     * @notice Returns the current epoch number
     * @return The current epoch
     */
    function getCurrentEpoch() external view returns (uint48);

    /**
     * @notice Returns the duration of each epoch
     * @return The duration of each epoch
     */
    function getEpochDuration() external view returns (uint48);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegistry {
    error EntityNotExist();

    /**
     * @notice Emitted when an entity is added.
     * @param entity address of the added entity
     */
    event AddEntity(address indexed entity);

    /**
     * @notice Get if a given address is an entity.
     * @param account address to check
     * @return if the given address is an entity
     */
    function isEntity(
        address account
    ) external view returns (bool);

    /**
     * @notice Get a total number of entities.
     * @return total number of entities added
     */
    function totalEntities() external view returns (uint256);

    /**
     * @notice Get an entity given its index.
     * @param index index of the entity to get
     * @return address of the entity
     */
    function entity(
        uint256 index
    ) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBaseDelegator} from "./IBaseDelegator.sol";

interface IOperatorSpecificDelegator is IBaseDelegator {
    error DuplicateRoleHolder();
    error ExceedsMaxNetworkLimit();
    error MissingRoleHolders();
    error NotOperator();
    error ZeroAddressRoleHolder();

    /**
     * @notice Hints for a stake.
     * @param baseHints base hints
     * @param activeStakeHint hint for the active stake checkpoint
     * @param networkLimitHint hint for the subnetwork limit checkpoint
     */
    struct StakeHints {
        bytes baseHints;
        bytes activeStakeHint;
        bytes networkLimitHint;
    }

    /**
     * @notice Initial parameters needed for an operator-specific delegator deployment.
     * @param baseParams base parameters for delegators' deployment
     * @param networkLimitSetRoleHolders array of addresses of the initial NETWORK_LIMIT_SET_ROLE holders
     * @param operator address of the single operator
     */
    struct InitParams {
        IBaseDelegator.BaseParams baseParams;
        address[] networkLimitSetRoleHolders;
        address operator;
    }

    /**
     * @notice Emitted when a subnetwork's limit is set.
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param amount new subnetwork's limit (how much stake the vault curator is ready to give to the subnetwork)
     */
    event SetNetworkLimit(bytes32 indexed subnetwork, uint256 amount);

    /**
     * @notice Get a subnetwork limit setter's role.
     * @return identifier of the subnetwork limit setter role
     */
    function NETWORK_LIMIT_SET_ROLE() external view returns (bytes32);

    /**
     * @notice Get the operator registry's address.
     * @return address of the operator registry
     */
    function OPERATOR_REGISTRY() external view returns (address);

    /**
     * @notice Get an operator managing the vault's funds.
     * @return address of the operator
     */
    function operator() external view returns (address);

    /**
     * @notice Get a subnetwork's limit at a given timestamp using a hint
     *         (how much stake the vault curator is ready to give to the subnetwork).
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param timestamp time point to get the subnetwork limit at
     * @param hint hint for checkpoint index
     * @return limit of the subnetwork at the given timestamp
     */
    function networkLimitAt(bytes32 subnetwork, uint48 timestamp, bytes memory hint) external view returns (uint256);

    /**
     * @notice Get a subnetwork's limit (how much stake the vault curator is ready to give to the subnetwork).
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @return limit of the subnetwork
     */
    function networkLimit(
        bytes32 subnetwork
    ) external view returns (uint256);

    /**
     * @notice Set a subnetwork's limit (how much stake the vault curator is ready to give to the subnetwork).
     * @param subnetwork full identifier of the subnetwork (address of the network concatenated with the uint96 identifier)
     * @param amount new limit of the subnetwork
     * @dev Only a NETWORK_LIMIT_SET_ROLE holder can call this function.
     */
    function setNetworkLimit(bytes32 subnetwork, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/structs/EnumerableMap.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableMap.js.

pragma solidity ^0.8.20;

import {EnumerableSet} from "./EnumerableSet.sol";

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableMap for EnumerableMap.UintToAddressMap;
 *
 *     // Declare a set state variable
 *     EnumerableMap.UintToAddressMap private myMap;
 * }
 * ```
 *
 * The following map types are supported:
 *
 * - `uint256 -> address` (`UintToAddressMap`) since v3.0.0
 * - `address -> uint256` (`AddressToUintMap`) since v4.6.0
 * - `bytes32 -> bytes32` (`Bytes32ToBytes32Map`) since v4.6.0
 * - `uint256 -> uint256` (`UintToUintMap`) since v4.7.0
 * - `bytes32 -> uint256` (`Bytes32ToUintMap`) since v4.7.0
 * - `uint256 -> bytes32` (`UintToBytes32Map`) since v5.1.0
 * - `address -> address` (`AddressToAddressMap`) since v5.1.0
 * - `address -> bytes32` (`AddressToBytes32Map`) since v5.1.0
 * - `bytes32 -> address` (`Bytes32ToAddressMap`) since v5.1.0
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableMap, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableMap.
 * ====
 */
library EnumerableMap {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // To implement this library for multiple types with as little code repetition as possible, we write it in
    // terms of a generic Map type with bytes32 keys and values. The Map implementation uses private functions,
    // and user-facing implementations such as `UintToAddressMap` are just wrappers around the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit in bytes32.

    /**
     * @dev Query for a nonexistent map key.
     */
    error EnumerableMapNonexistentKey(bytes32 key);

    struct Bytes32ToBytes32Map {
        // Storage of keys
        EnumerableSet.Bytes32Set _keys;
        mapping(bytes32 key => bytes32) _values;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(Bytes32ToBytes32Map storage map, bytes32 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function length(Bytes32ToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @dev Returns the key-value pair stored at position `index` in the map. O(1).
     *
     * Note that there are no guarantees on the ordering of entries inside the
     * array, and it may change when more entries are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToBytes32Map storage map, uint256 index) internal view returns (bytes32 key, bytes32 value) {
        bytes32 atKey = map._keys.at(index);
        return (atKey, map._values[atKey]);
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool exists, bytes32 value) {
        bytes32 val = map._values[key];
        if (val == bytes32(0)) {
            return (contains(map, key), bytes32(0));
        } else {
            return (true, val);
        }
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32) {
        bytes32 value = map._values[key];
        if (value == 0 && !contains(map, key)) {
            revert EnumerableMapNonexistentKey(key);
        }
        return value;
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(Bytes32ToBytes32Map storage map) internal view returns (bytes32[] memory) {
        return map._keys.values();
    }

    // UintToUintMap

    struct UintToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(UintToUintMap storage map, uint256 key, uint256 value) internal returns (bool) {
        return set(map._inner, bytes32(key), bytes32(value));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToUintMap storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToUintMap storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToUintMap storage map, uint256 index) internal view returns (uint256 key, uint256 value) {
        (bytes32 atKey, bytes32 val) = at(map._inner, index);
        return (uint256(atKey), uint256(val));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToUintMap storage map, uint256 key) internal view returns (bool exists, uint256 value) {
        (bool success, bytes32 val) = tryGet(map._inner, bytes32(key));
        return (success, uint256(val));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToUintMap storage map, uint256 key) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(key)));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(UintToUintMap storage map) internal view returns (uint256[] memory) {
        bytes32[] memory store = keys(map._inner);
        uint256[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // UintToAddressMap

    struct UintToAddressMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(UintToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        return set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToAddressMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256 key, address value) {
        (bytes32 atKey, bytes32 val) = at(map._inner, index);
        return (uint256(atKey), address(uint160(uint256(val))));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToAddressMap storage map, uint256 key) internal view returns (bool exists, address value) {
        (bool success, bytes32 val) = tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint256(val))));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, bytes32(key)))));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(UintToAddressMap storage map) internal view returns (uint256[] memory) {
        bytes32[] memory store = keys(map._inner);
        uint256[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // UintToBytes32Map

    struct UintToBytes32Map {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(UintToBytes32Map storage map, uint256 key, bytes32 value) internal returns (bool) {
        return set(map._inner, bytes32(key), value);
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToBytes32Map storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToBytes32Map storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToBytes32Map storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToBytes32Map storage map, uint256 index) internal view returns (uint256 key, bytes32 value) {
        (bytes32 atKey, bytes32 val) = at(map._inner, index);
        return (uint256(atKey), val);
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToBytes32Map storage map, uint256 key) internal view returns (bool exists, bytes32 value) {
        (bool success, bytes32 val) = tryGet(map._inner, bytes32(key));
        return (success, val);
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToBytes32Map storage map, uint256 key) internal view returns (bytes32) {
        return get(map._inner, bytes32(key));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(UintToBytes32Map storage map) internal view returns (uint256[] memory) {
        bytes32[] memory store = keys(map._inner);
        uint256[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // AddressToUintMap

    struct AddressToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(AddressToUintMap storage map, address key, uint256 value) internal returns (bool) {
        return set(map._inner, bytes32(uint256(uint160(key))), bytes32(value));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(AddressToUintMap storage map, address key) internal returns (bool) {
        return remove(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(AddressToUintMap storage map, address key) internal view returns (bool) {
        return contains(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(AddressToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressToUintMap storage map, uint256 index) internal view returns (address key, uint256 value) {
        (bytes32 atKey, bytes32 val) = at(map._inner, index);
        return (address(uint160(uint256(atKey))), uint256(val));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(AddressToUintMap storage map, address key) internal view returns (bool exists, uint256 value) {
        (bool success, bytes32 val) = tryGet(map._inner, bytes32(uint256(uint160(key))));
        return (success, uint256(val));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(AddressToUintMap storage map, address key) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(uint256(uint160(key)))));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(AddressToUintMap storage map) internal view returns (address[] memory) {
        bytes32[] memory store = keys(map._inner);
        address[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // AddressToAddressMap

    struct AddressToAddressMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(AddressToAddressMap storage map, address key, address value) internal returns (bool) {
        return set(map._inner, bytes32(uint256(uint160(key))), bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(AddressToAddressMap storage map, address key) internal returns (bool) {
        return remove(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(AddressToAddressMap storage map, address key) internal view returns (bool) {
        return contains(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(AddressToAddressMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressToAddressMap storage map, uint256 index) internal view returns (address key, address value) {
        (bytes32 atKey, bytes32 val) = at(map._inner, index);
        return (address(uint160(uint256(atKey))), address(uint160(uint256(val))));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(AddressToAddressMap storage map, address key) internal view returns (bool exists, address value) {
        (bool success, bytes32 val) = tryGet(map._inner, bytes32(uint256(uint160(key))));
        return (success, address(uint160(uint256(val))));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(AddressToAddressMap storage map, address key) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, bytes32(uint256(uint160(key)))))));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(AddressToAddressMap storage map) internal view returns (address[] memory) {
        bytes32[] memory store = keys(map._inner);
        address[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // AddressToBytes32Map

    struct AddressToBytes32Map {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(AddressToBytes32Map storage map, address key, bytes32 value) internal returns (bool) {
        return set(map._inner, bytes32(uint256(uint160(key))), value);
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(AddressToBytes32Map storage map, address key) internal returns (bool) {
        return remove(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(AddressToBytes32Map storage map, address key) internal view returns (bool) {
        return contains(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(AddressToBytes32Map storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressToBytes32Map storage map, uint256 index) internal view returns (address key, bytes32 value) {
        (bytes32 atKey, bytes32 val) = at(map._inner, index);
        return (address(uint160(uint256(atKey))), val);
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(AddressToBytes32Map storage map, address key) internal view returns (bool exists, bytes32 value) {
        (bool success, bytes32 val) = tryGet(map._inner, bytes32(uint256(uint160(key))));
        return (success, val);
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(AddressToBytes32Map storage map, address key) internal view returns (bytes32) {
        return get(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(AddressToBytes32Map storage map) internal view returns (address[] memory) {
        bytes32[] memory store = keys(map._inner);
        address[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // Bytes32ToUintMap

    struct Bytes32ToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(Bytes32ToUintMap storage map, bytes32 key, uint256 value) internal returns (bool) {
        return set(map._inner, key, bytes32(value));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToUintMap storage map, bytes32 key) internal returns (bool) {
        return remove(map._inner, key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToUintMap storage map, bytes32 key) internal view returns (bool) {
        return contains(map._inner, key);
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(Bytes32ToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToUintMap storage map, uint256 index) internal view returns (bytes32 key, uint256 value) {
        (bytes32 atKey, bytes32 val) = at(map._inner, index);
        return (atKey, uint256(val));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToUintMap storage map, bytes32 key) internal view returns (bool exists, uint256 value) {
        (bool success, bytes32 val) = tryGet(map._inner, key);
        return (success, uint256(val));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToUintMap storage map, bytes32 key) internal view returns (uint256) {
        return uint256(get(map._inner, key));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(Bytes32ToUintMap storage map) internal view returns (bytes32[] memory) {
        bytes32[] memory store = keys(map._inner);
        bytes32[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // Bytes32ToAddressMap

    struct Bytes32ToAddressMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(Bytes32ToAddressMap storage map, bytes32 key, address value) internal returns (bool) {
        return set(map._inner, key, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToAddressMap storage map, bytes32 key) internal returns (bool) {
        return remove(map._inner, key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (bool) {
        return contains(map._inner, key);
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(Bytes32ToAddressMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToAddressMap storage map, uint256 index) internal view returns (bytes32 key, address value) {
        (bytes32 atKey, bytes32 val) = at(map._inner, index);
        return (atKey, address(uint160(uint256(val))));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (bool exists, address value) {
        (bool success, bytes32 val) = tryGet(map._inner, key);
        return (success, address(uint160(uint256(val))));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToAddressMap storage map, bytes32 key) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, key))));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(Bytes32ToAddressMap storage map) internal view returns (bytes32[] memory) {
        bytes32[] memory store = keys(map._inner);
        bytes32[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title StakePowerManager
 * @notice Abstract contract for managing stake power conversion
 */
abstract contract StakePowerManager is Initializable {
    /**
     * @notice Converts stake amount to voting power
     * @param vault The vault address
     * @param stake The stake amount
     * @return power The calculated voting power
     */
    function stakeToPower(address vault, uint256 stake) public view virtual returns (uint256 power);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title NetworkStorage
 * @notice Storage contract for managing the network address
 * @dev Uses a single storage slot to store the network address value
 */
abstract contract NetworkStorage is Initializable {
    // keccak256(abi.encode(uint256(keccak256("symbiotic.storage.NetworkStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NetworkStorageLocation = 0x933223a21808ea6583da836861e2265bfa3c7e3b9070740cd75dc9ff6fb41700;

    /**
     * @notice Initializes the NetworkManager contract
     * @param network The address of the network
     */
    function __NetworkStorage_init_private(
        address network
    ) internal onlyInitializing {
        assembly {
            sstore(NetworkStorageLocation, network)
        }
    }

    /**
     * @notice Returns the address of the network
     * @return network The address of the network
     */
    function _NETWORK() internal view returns (address) {
        address network;
        assembly {
            network := sload(NetworkStorageLocation)
        }
        return network;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title SlashingWindowStorage
 * @notice Storage contract for managing the slashing window duration
 * @dev Uses a single storage slot to store the slashing window duration value
 */
abstract contract SlashingWindowStorage is Initializable {
    // keccak256(abi.encode(uint256(keccak256("symbiotic.storage.SlashingWindowStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SlashingWindowStorageLocation =
        0x937e0d2984afc3afaa413d74098ba180cc0c6aae6527cc2713827ed6bc72f200;

    /**
     * @notice Initializes the SlashingWindowStorage contract
     * @param _slashingWindow The duration of the slashing window in seconds
     */
    function __SlashingWindowStorage_init_private(
        uint48 _slashingWindow
    ) internal onlyInitializing {
        assembly {
            sstore(SlashingWindowStorageLocation, _slashingWindow)
        }
    }

    /**
     * @notice Returns the slashing window duration
     * @return slashingWindow The duration of the slashing window in seconds
     */
    function _SLASHING_WINDOW() internal view returns (uint48) {
        uint48 slashingWindow;
        assembly {
            slashingWindow := sload(SlashingWindowStorageLocation)
        }
        return slashingWindow;
    }
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

import {
    MultiAddress, multiAddressFromUint32, multiAddressFromBytes32, multiAddressFromBytes20
} from "./MultiAddress.sol";

import {UD60x18} from "prb/math/src/UD60x18.sol";

type ParaID is uint32;

using {ParaIDEq as ==, ParaIDNe as !=, into} for ParaID global;

function ParaIDEq(ParaID a, ParaID b) pure returns (bool) {
    return ParaID.unwrap(a) == ParaID.unwrap(b);
}

function ParaIDNe(ParaID a, ParaID b) pure returns (bool) {
    return !ParaIDEq(a, b);
}

function into(ParaID paraID) pure returns (ChannelID) {
    return ChannelID.wrap(keccak256(abi.encodePacked("para", ParaID.unwrap(paraID))));
}

type ChannelID is bytes32;

using {ChannelIDEq as ==, ChannelIDNe as !=} for ChannelID global;

function ChannelIDEq(ChannelID a, ChannelID b) pure returns (bool) {
    return ChannelID.unwrap(a) == ChannelID.unwrap(b);
}

function ChannelIDNe(ChannelID a, ChannelID b) pure returns (bool) {
    return !ChannelIDEq(a, b);
}

/// @dev A messaging channel for a Polkadot parachain
struct Channel {
    /// @dev The operating mode for this channel. Can be used to
    /// disable messaging on a per-channel basis.
    OperatingMode mode;
    /// @dev The current nonce for the inbound lane
    uint64 inboundNonce;
    /// @dev The current node for the outbound lane
    uint64 outboundNonce;
    /// @dev The address of the agent of the parachain owning this channel
    address agent;
}

/// @dev Inbound message from a Polkadot parachain (via BridgeHub)
struct InboundMessage {
    /// @dev The parachain from which this message originated
    ChannelID channelID;
    /// @dev The channel nonce
    uint64 nonce;
    /// @dev The command to execute
    Command command;
    /// @dev The Parameters for the command
    bytes params;
    /// @dev The maximum gas allowed for message dispatch
    uint64 maxDispatchGas;
    /// @dev The maximum fee per gas
    uint256 maxFeePerGas;
    /// @dev The reward for message submission
    uint256 reward;
    /// @dev ID for this message
    bytes32 id;
}

enum OperatingMode {
    Normal,
    RejectingOutboundMessages
}

/// @dev Messages from Polkadot take the form of these commands.
enum Command {
    AgentExecute,
    Upgrade,
    CreateAgent,
    CreateChannel,
    UpdateChannel,
    SetOperatingMode,
    TransferNativeFromAgent,
    SetTokenTransferFees,
    SetPricingParameters,
    TransferNativeToken,
    RegisterForeignToken,
    MintForeignToken,
    /// @dev Below enums are reserved in case upstream snowbridge adds more commands
    Reserved12,
    Reserved13,
    Reserved14,
    Reserved15,
    Reserved16,
    Reserved17,
    Reserved18,
    Reserved19,
    Reserved20,
    Reserved21,
    Reserved22,
    Reserved23,
    Reserved24,
    Reserved25,
    Reserved26,
    Reserved27,
    Reserved28,
    Reserved29,
    Reserved30,
    Reserved31,
    Test,
    ReportRewards,
    ReportSlashes
}

/// @dev DEPRECATED
enum AgentExecuteCommand {
    TransferToken
}

/// @dev Application-level costs for a message
struct Costs {
    /// @dev Costs in foreign currency
    uint256 foreign;
    /// @dev Costs in native currency
    uint256 native;
}

struct Ticket {
    ParaID dest;
    Costs costs;
    bytes payload;
}

struct TokenInfo {
    bool isRegistered;
    bytes32 foreignID;
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

import {OperatingMode, InboundMessage, ParaID, ChannelID, MultiAddress} from "../Types.sol";
import {Verification} from "../Verification.sol";
import {UD60x18} from "prb/math/src/UD60x18.sol";

interface IGateway {
    /**
     * Events
     */

    // Emitted when inbound message has been dispatched
    event InboundMessageDispatched(ChannelID indexed channelID, uint64 nonce, bytes32 indexed messageID, bool success);

    // Emitted when an outbound message has been accepted for delivery to a Polkadot parachain
    event OutboundMessageAccepted(ChannelID indexed channelID, uint64 nonce, bytes32 indexed messageID, bytes payload);

    // Emitted when an agent has been created for a consensus system on Polkadot
    event AgentCreated(bytes32 agentID, address agent);

    // Emitted when a channel has been created
    event ChannelCreated(ChannelID indexed channelID);

    // Emitted when a channel has been updated
    event ChannelUpdated(ChannelID indexed channelID);

    // Emitted when the operating mode is changed
    event OperatingModeChanged(OperatingMode mode);

    // Emitted when pricing params updated
    event PricingParametersChanged();

    // Emitted when funds are withdrawn from an agent
    event AgentFundsWithdrawn(bytes32 indexed agentID, address indexed recipient, uint256 amount);

    // Emitted when foreign token from polkadot registed
    event ForeignTokenRegistered(bytes32 indexed tokenID, address token);

    /**
     * Getters
     */
    function operatingMode() external view returns (OperatingMode);

    function channelOperatingModeOf(ChannelID channelID) external view returns (OperatingMode);

    function channelNoncesOf(ChannelID channelID) external view returns (uint64, uint64);

    function agentOf(bytes32 agentID) external view returns (address);

    function pricingParameters() external view returns (UD60x18, uint128);

    function implementation() external view returns (address);

    /**
     * Messaging
     */

    // Submit a message from a Polkadot network
    function submitV1(
        InboundMessage calldata message,
        bytes32[] calldata leafProof,
        Verification.Proof calldata headerProof
    ) external;

    /**
     * Token Transfers
     */

    // @dev Emitted when the fees updated
    event TokenTransferFeesChanged();

    /// @dev Emitted once the funds are locked and an outbound message is successfully queued.
    event TokenSent(
        address indexed token,
        address indexed sender,
        ParaID indexed destinationChain,
        MultiAddress destinationAddress,
        uint128 amount
    );

    /// @dev Emitted when a command is sent to register a new wrapped token on AssetHub
    event TokenRegistrationSent(address token);

    /// @dev Check whether a token is registered
    function isTokenRegistered(address token) external view returns (bool);

    /// @dev Get token id of an ERC20 contract address.
    function queryForeignTokenID(address token) external view returns (bytes32);

    /// @dev Quote a fee in Ether for registering a token, covering
    /// 1. Delivery costs to BridgeHub
    /// 2. XCM Execution costs on AssetHub
    function quoteRegisterTokenFee() external view returns (uint256);

    /// @dev Register an ERC20 token and create a wrapped derivative on AssetHub in the `ForeignAssets` pallet.
    function registerToken(address token) external payable;

    /// @dev Quote a fee in Ether for sending a token
    /// 1. Delivery costs to BridgeHub
    /// 2. XCM execution costs on destinationChain
    function quoteSendTokenFee(address token, ParaID destinationChain, uint128 destinationFee)
        external
        view
        returns (uint256);

    /// @dev Send ERC20 tokens to parachain `destinationChain` and deposit into account `destinationAddress`
    function sendToken(
        address token,
        ParaID destinationChain,
        MultiAddress calldata destinationAddress,
        uint128 destinationFee,
        uint128 amount
    ) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegistry {
    error EntityNotExist();

    /**
     * @notice Emitted when an entity is added.
     * @param entity address of the added entity
     */
    event AddEntity(address indexed entity);

    /**
     * @notice Get if a given address is an entity.
     * @param account address to check
     * @return if the given address is an entity
     */
    function isEntity(
        address account
    ) external view returns (bool);

    /**
     * @notice Get a total number of entities.
     * @return total number of entities added
     */
    function totalEntities() external view returns (uint256);

    /**
     * @notice Get an entity given its index.
     * @param index index of the entity to get
     * @return address of the entity
     */
    function entity(
        uint256 index
    ) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IODefaultStakerRewards} from "../rewarder/IODefaultStakerRewards.sol";
/**
 * @title IOSharedVaults
 * @notice Interface for managing shared vaults that can be used by multiple operators
 */

interface IOSharedVaults {
    /**
     * @notice Registers a new shared vault
     * @param sharedVault The address of the vault to register
     * @param stakerRewardsParams Init params to create a staker rewards contract associated with the shared vault
     */
    function registerSharedVault(
        address sharedVault,
        IODefaultStakerRewards.InitParams memory stakerRewardsParams
    ) external;

    /**
     * @notice Pauses a shared vault
     * @param sharedVault The address of the vault to pause
     */
    function pauseSharedVault(
        address sharedVault
    ) external;

    /**
     * @notice Unpauses a shared vault
     * @param sharedVault The address of the vault to unpause
     */
    function unpauseSharedVault(
        address sharedVault
    ) external;

    /**
     * @notice Unregisters a shared vault
     * @param sharedVault The address of the vault to unregister
     */
    function unregisterSharedVault(
        address sharedVault
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 */
interface IERC1967 {
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
// OpenZeppelin Contracts (last updated v5.2.0) (utils/Address.sol)

pragma solidity ^0.8.20;

import {Errors} from "./Errors.sol";

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

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
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, bytes memory returndata) = recipient.call{value: amount}("");
        if (!success) {
            _revert(returndata);
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
     * {Errors.FailedCall} error.
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
            revert Errors.InsufficientBalance(address(this).balance, value);
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
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
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
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC-1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
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
 * TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlot {
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

    struct Int256Slot {
        int256 value;
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
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `Int256Slot` with member `value` located at `slot`.
     */
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns a `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns a `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        assembly ("memory-safe") {
            r.slot := store.slot
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IRegistry} from "@symbiotic/interfaces/common/IRegistry.sol";
import {IOptInService} from "@symbiotic/interfaces/service/IOptInService.sol";

import {NetworkStorage} from "./storages/NetworkStorage.sol";
import {SlashingWindowStorage} from "./storages/SlashingWindowStorage.sol";

import {CaptureTimestampManager} from "./extendable/CaptureTimestampManager.sol";

import {PauseableEnumerableSet} from "../libraries/PauseableEnumerableSet.sol";

/**
 * @title OperatorManager
 * @notice Manages operator registration and validation for the protocol
 * @dev Inherits from NetworkStorage, SlashingWindowStorage, and CaptureTimestampManager
 * to provide operator management functionality with network awareness and time-based features
 */
abstract contract OperatorManager is NetworkStorage, SlashingWindowStorage, CaptureTimestampManager {
    using PauseableEnumerableSet for PauseableEnumerableSet.AddressSet;

    error NotOperator();
    error OperatorNotOptedIn();

    /// @custom:storage-location erc7201:symbiotic.storage.OperatorManager
    struct OperatorManagerStorage {
        address _operatorRegistry; // Address of the operator registry
        address _operatorNetOptin; // Address of the operator network opt-in service
        PauseableEnumerableSet.AddressSet _operators;
    }

    // keccak256(abi.encode(uint256(keccak256("symbiotic.storage.OperatorManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OperatorManagerStorageLocation =
        0x3b2b549db680c436ebf9aa3c8eeee850852f16da5cdb5137dbc0299ebb219e00;

    /**
     * @notice Gets the storage pointer for OperatorManager state
     * @return $ Storage pointer to OperatorManagerStorage struct
     */
    function _getOperatorManagerStorage() internal pure returns (OperatorManagerStorage storage $) {
        assembly {
            $.slot := OperatorManagerStorageLocation
        }
    }

    /**
     * @notice Initializes the OperatorManager with required parameters
     * @param operatorRegistry The address of the operator registry contract
     * @param operatorNetOptin The address of the operator network opt-in service
     */
    function __OperatorManager_init_private(
        address operatorRegistry,
        address operatorNetOptin
    ) internal onlyInitializing {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        $._operatorRegistry = operatorRegistry;
        $._operatorNetOptin = operatorNetOptin;
    }

    /**
     * @notice Gets the address of the operator registry contract
     * @return The operator registry contract address
     */
    function _OPERATOR_REGISTRY() internal view returns (address) {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        return $._operatorRegistry;
    }

    /**
     * @notice Gets the address of the operator network opt-in service contract
     * @return The operator network opt-in service contract address
     */
    function _OPERATOR_NET_OPTIN() internal view returns (address) {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        return $._operatorNetOptin;
    }

    /**
     * @notice Returns the total number of registered operators, including both active and inactive
     * @return The number of registered operators
     */
    function _operatorsLength() internal view returns (uint256) {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        return $._operators.length();
    }
    /**
     * @notice Returns the operator and their associated enabled and disabled times at a specific position
     * @param pos The index position in the operators array
     * @return The operator address
     * @return The enabled timestamp
     * @return The disabled timestamp
     */

    function _operatorWithTimesAt(
        uint256 pos
    ) internal view returns (address, uint48, uint48) {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        return $._operators.at(pos);
    }

    /**
     * @notice Returns a list of active operators
     * @return Array of addresses representing the active operators
     */
    function _activeOperators() internal view returns (address[] memory) {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        return $._operators.getActive(getCaptureTimestamp());
    }

    /**
     * @notice Returns a list of active operators at a specific timestamp
     * @param timestamp The timestamp to check
     * @return Array of addresses representing the active operators at the timestamp
     */
    function _activeOperatorsAt(
        uint48 timestamp
    ) internal view returns (address[] memory) {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        return $._operators.getActive(timestamp);
    }

    /**
     * @notice Checks if a given operator was active at a specified timestamp
     * @param timestamp The timestamp to check
     * @param operator The operator address to check
     * @return True if the operator was active at the timestamp, false otherwise
     */
    function _operatorWasActiveAt(uint48 timestamp, address operator) internal view returns (bool) {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        return $._operators.wasActiveAt(timestamp, operator);
    }

    /**
     * @notice Checks if an operator is registered
     * @param operator The address of the operator to check
     * @return True if the operator is registered, false otherwise
     */
    function _isOperatorRegistered(
        address operator
    ) internal view returns (bool) {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        return $._operators.contains(operator);
    }

    /**
     * @notice Registers a new operator
     * @param operator The address of the operator to register
     */
    function _registerOperator(
        address operator
    ) internal {
        if (!IRegistry(_OPERATOR_REGISTRY()).isEntity(operator)) {
            revert NotOperator();
        }

        if (!IOptInService(_OPERATOR_NET_OPTIN()).isOptedIn(operator, _NETWORK())) {
            revert OperatorNotOptedIn();
        }

        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        $._operators.register(_now(), operator);
    }

    /**
     * @notice Pauses a registered operator
     * @param operator The address of the operator to pause
     */
    function _pauseOperator(
        address operator
    ) internal {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        $._operators.pause(_now(), operator);
    }

    /**
     * @notice Unpauses a paused operator
     * @param operator The address of the operator to unpause
     */
    function _unpauseOperator(
        address operator
    ) internal {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        $._operators.unpause(_now(), _SLASHING_WINDOW(), operator);
    }

    /**
     * @notice Unregisters an operator
     * @param operator The address of the operator to unregister
     */
    function _unregisterOperator(
        address operator
    ) internal {
        OperatorManagerStorage storage $ = _getOperatorManagerStorage();
        $._operators.unregister(_now(), _SLASHING_WINDOW(), operator);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes32 value => uint256) _positions;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly ("memory-safe") {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

using {isIndex, asIndex, isAddress32, asAddress32, isAddress20, asAddress20} for MultiAddress global;

/// @dev An address for an on-chain account
struct MultiAddress {
    Kind kind;
    bytes data;
}

enum Kind {
    Index,
    Address32,
    Address20
}

function isIndex(MultiAddress calldata multiAddress) pure returns (bool) {
    return multiAddress.kind == Kind.Index;
}

function asIndex(MultiAddress calldata multiAddress) pure returns (uint32) {
    return abi.decode(multiAddress.data, (uint32));
}

function isAddress32(MultiAddress calldata multiAddress) pure returns (bool) {
    return multiAddress.kind == Kind.Address32;
}

function asAddress32(MultiAddress calldata multiAddress) pure returns (bytes32) {
    return bytes32(multiAddress.data);
}

function isAddress20(MultiAddress calldata multiAddress) pure returns (bool) {
    return multiAddress.kind == Kind.Address20;
}

function asAddress20(MultiAddress calldata multiAddress) pure returns (bytes20) {
    return bytes20(multiAddress.data);
}

function multiAddressFromUint32(uint32 id) pure returns (MultiAddress memory) {
    return MultiAddress({kind: Kind.Index, data: abi.encode(id)});
}

function multiAddressFromBytes32(bytes32 id) pure returns (MultiAddress memory) {
    return MultiAddress({kind: Kind.Address32, data: bytes.concat(id)});
}

function multiAddressFromBytes20(bytes20 id) pure returns (MultiAddress memory) {
    return MultiAddress({kind: Kind.Address20, data: bytes.concat(id)});
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

/*

██████╗ ██████╗ ██████╗ ███╗   ███╗ █████╗ ████████╗██╗  ██╗
██╔══██╗██╔══██╗██╔══██╗████╗ ████║██╔══██╗╚══██╔══╝██║  ██║
██████╔╝██████╔╝██████╔╝██╔████╔██║███████║   ██║   ███████║
██╔═══╝ ██╔══██╗██╔══██╗██║╚██╔╝██║██╔══██║   ██║   ██╔══██║
██║     ██║  ██║██████╔╝██║ ╚═╝ ██║██║  ██║   ██║   ██║  ██║
╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝

██╗   ██╗██████╗  ██████╗  ██████╗ ██╗  ██╗ ██╗ █████╗
██║   ██║██╔══██╗██╔════╝ ██╔═████╗╚██╗██╔╝███║██╔══██╗
██║   ██║██║  ██║███████╗ ██║██╔██║ ╚███╔╝ ╚██║╚█████╔╝
██║   ██║██║  ██║██╔═══██╗████╔╝██║ ██╔██╗  ██║██╔══██╗
╚██████╔╝██████╔╝╚██████╔╝╚██████╔╝██╔╝ ██╗ ██║╚█████╔╝
 ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═╝ ╚════╝

*/

import "./ud60x18/Casting.sol";
import "./ud60x18/Constants.sol";
import "./ud60x18/Conversions.sol";
import "./ud60x18/Errors.sol";
import "./ud60x18/Helpers.sol";
import "./ud60x18/Math.sol";
import "./ud60x18/ValueType.sol";

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

import {SubstrateMerkleProof} from "./utils/SubstrateMerkleProof.sol";
import {BeefyClient} from "./BeefyClient.sol";
import {ScaleCodec} from "./utils/ScaleCodec.sol";
import {SubstrateTypes} from "./SubstrateTypes.sol";

library Verification {
    /// @dev Merkle proof for parachain header finalized by BEEFY
    /// Reference: https://github.com/paritytech/polkadot/blob/09b61286da11921a3dda0a8e4015ceb9ef9cffca/runtime/rococo/src/lib.rs#L1312
    struct HeadProof {
        // The leaf index of the parachain being proven
        uint256 pos;
        // The number of leaves in the merkle tree
        uint256 width;
        // The proof items
        bytes32[] proof;
    }

    /// @dev An MMRLeaf without the `leaf_extra` field.
    /// Reference: https://github.com/paritytech/substrate/blob/14e0a0b628f9154c5a2c870062c3aac7df8983ed/primitives/consensus/beefy/src/mmr.rs#L52
    struct MMRLeafPartial {
        uint8 version;
        uint32 parentNumber;
        bytes32 parentHash;
        uint64 nextAuthoritySetID;
        uint32 nextAuthoritySetLen;
        bytes32 nextAuthoritySetRoot;
    }

    /// @dev Parachain header
    /// References:
    /// * https://paritytech.github.io/substrate/master/sp_runtime/generic/struct.Header.html
    /// * https://github.com/paritytech/substrate/blob/14e0a0b628f9154c5a2c870062c3aac7df8983ed/primitives/runtime/src/generic/header.rs#L41
    struct ParachainHeader {
        bytes32 parentHash;
        uint256 number;
        bytes32 stateRoot;
        bytes32 extrinsicsRoot;
        DigestItem[] digestItems;
    }

    /// @dev Represents a digest item within a parachain header.
    /// References:
    /// * https://paritytech.github.io/substrate/master/sp_runtime/generic/enum.DigestItem.html
    /// * https://github.com/paritytech/substrate/blob/14e0a0b628f9154c5a2c870062c3aac7df8983ed/primitives/runtime/src/generic/digest.rs#L75
    struct DigestItem {
        uint256 kind;
        bytes4 consensusEngineID;
        bytes data;
    }

    /// @dev A chain of proofs
    struct Proof {
        // The MMR leaf to be proven
        MMRLeafPartial leafPartial;
        // The MMR leaf prove
        bytes32[] leafProof;
        // Parachain heads root
        bytes32 parachainHeadsRoot;
        // The order in which proof items should be combined
        uint256 leafProofOrder;
    }

    error InvalidParachainHeader();

    /// @dev IDs of enum variants of DigestItem
    /// Reference: https://github.com/paritytech/substrate/blob/14e0a0b628f9154c5a2c870062c3aac7df8983ed/primitives/runtime/src/generic/digest.rs#L201
    uint256 public constant DIGEST_ITEM_OTHER = 0;
    uint256 public constant DIGEST_ITEM_CONSENSUS = 4;
    uint256 public constant DIGEST_ITEM_SEAL = 5;
    uint256 public constant DIGEST_ITEM_PRERUNTIME = 6;
    uint256 public constant DIGEST_ITEM_RUNTIME_ENVIRONMENT_UPDATED = 8;

    /// @dev Enum variant ID for CustomDigestItem::Snowbridge
    bytes1 public constant DIGEST_ITEM_OTHER_SNOWBRIDGE = 0x00;

    /// @dev Verify the message commitment by applying several proofs
    ///
    /// 1. First check that the commitment is included in the digest items of the parachain header
    /// 2. Generate the root of the parachain heads merkle tree
    /// 3. Construct an MMR leaf containing the parachain heads root.
    /// 4. Verify that the MMR leaf is included in the MMR maintained by the BEEFY light client.
    ///
    /// Background info:
    ///
    /// In the Polkadot relay chain, for every block:
    /// 1. A merkle root of finalized parachain headers is constructed:
    ///    https://github.com/paritytech/polkadot/blob/09b61286da11921a3dda0a8e4015ceb9ef9cffca/runtime/rococo/src/lib.rs#L1312.
    /// 2. An MMR leaf is produced, containing this parachain headers root, and is then inserted into the
    ///    MMR maintained by the `merkle-mountain-range` pallet:
    ///    https://github.com/paritytech/substrate/tree/master/frame/merkle-mountain-range
    ///
    /// @param beefyClient The address of the BEEFY light client
    /// @param encodedParaID The SCALE-encoded parachain ID of BridgeHub
    /// @param messageCommitment The message commitment root expected to be contained within the
    ///                   digest of BridgeHub parachain header.
    /// @param proof The chain of proofs described above
    function verifyCommitment(
        address beefyClient,
        bytes4 encodedParaID,
        bytes32 messageCommitment,
        Proof calldata proof
    ) external view returns (bool) {
        bytes32 leafHash = createMMRLeaf(proof.leafPartial, proof.parachainHeadsRoot, messageCommitment);

        // Verify that the MMR leaf is part of the MMR maintained by the BEEFY light client
        return BeefyClient(beefyClient).verifyMMRLeafProof(leafHash, proof.leafProof, proof.leafProofOrder);
    }

    // Verify that a message commitment is in the header digest
    function isCommitmentInHeaderDigest(bytes32 messageCommitment, ParachainHeader calldata header)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < header.digestItems.length; i++) {
            if (
                header.digestItems[i].kind == DIGEST_ITEM_OTHER && header.digestItems[i].data.length == 33
                    && header.digestItems[i].data[0] == DIGEST_ITEM_OTHER_SNOWBRIDGE
                    && messageCommitment == bytes32(header.digestItems[i].data[1:])
            ) {
                return true;
            }
        }
        return false;
    }

    // SCALE-Encodes: Vec<DigestItem>
    // Reference: https://github.com/paritytech/substrate/blob/14e0a0b628f9154c5a2c870062c3aac7df8983ed/primitives/runtime/src/generic/digest.rs#L40
    function encodeDigestItems(DigestItem[] calldata digestItems) internal pure returns (bytes memory) {
        // encode all digest items into a buffer
        bytes memory accum = hex"";
        for (uint256 i = 0; i < digestItems.length; i++) {
            accum = bytes.concat(accum, encodeDigestItem(digestItems[i]));
        }
        // Encode number of digest items, followed by encoded digest items
        return bytes.concat(ScaleCodec.checkedEncodeCompactU32(digestItems.length), accum);
    }

    function encodeDigestItem(DigestItem calldata digestItem) internal pure returns (bytes memory) {
        if (
            digestItem.kind == DIGEST_ITEM_PRERUNTIME || digestItem.kind == DIGEST_ITEM_CONSENSUS
                || digestItem.kind == DIGEST_ITEM_SEAL
        ) {
            return bytes.concat(
                bytes1(uint8(digestItem.kind)),
                digestItem.consensusEngineID,
                ScaleCodec.checkedEncodeCompactU32(digestItem.data.length),
                digestItem.data
            );
        } else if (digestItem.kind == DIGEST_ITEM_OTHER) {
            return bytes.concat(
                bytes1(uint8(DIGEST_ITEM_OTHER)),
                ScaleCodec.checkedEncodeCompactU32(digestItem.data.length),
                digestItem.data
            );
        } else if (digestItem.kind == DIGEST_ITEM_RUNTIME_ENVIRONMENT_UPDATED) {
            return bytes.concat(bytes1(uint8(DIGEST_ITEM_RUNTIME_ENVIRONMENT_UPDATED)));
        } else {
            revert InvalidParachainHeader();
        }
    }

    // Creates a keccak hash of a SCALE-encoded parachain header
    function createParachainHeaderMerkleLeaf(bytes4 encodedParaID, ParachainHeader calldata header)
        internal
        pure
        returns (bytes32)
    {
        // Hash of encoded parachain header merkle leaf
        return keccak256(createParachainHeader(encodedParaID, header));
    }

    function createParachainHeader(bytes4 encodedParaID, ParachainHeader calldata header)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory encodedHeader = bytes.concat(
            // H256
            header.parentHash,
            // Compact unsigned int
            ScaleCodec.checkedEncodeCompactU32(header.number),
            // H256
            header.stateRoot,
            // H256
            header.extrinsicsRoot,
            // Vec<DigestItem>
            encodeDigestItems(header.digestItems)
        );

        return bytes.concat(
            // u32
            encodedParaID,
            // length of encoded header
            ScaleCodec.checkedEncodeCompactU32(encodedHeader.length),
            encodedHeader
        );
    }

    // SCALE-encode: MMRLeaf
    // Reference: https://github.com/paritytech/substrate/blob/14e0a0b628f9154c5a2c870062c3aac7df8983ed/primitives/consensus/beefy/src/mmr.rs#L52
    function createMMRLeaf(MMRLeafPartial memory leaf, bytes32 parachainHeadsRoot, bytes32 messageCommitment)
        internal
        pure
        returns (bytes32)
    {
        bytes memory encodedLeaf = bytes.concat(
            ScaleCodec.encodeU8(leaf.version),
            ScaleCodec.encodeU32(leaf.parentNumber),
            leaf.parentHash,
            ScaleCodec.encodeU64(leaf.nextAuthoritySetID),
            ScaleCodec.encodeU32(leaf.nextAuthoritySetLen),
            leaf.nextAuthoritySetRoot,
            parachainHeadsRoot,
            messageCommitment
        );
        return keccak256(encodedLeaf);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOptInService {
    error AlreadyOptedIn();
    error ExpiredSignature();
    error InvalidSignature();
    error NotOptedIn();
    error NotWhereEntity();
    error NotWho();
    error OptOutCooldown();

    /**
     * @notice Emitted when a "who" opts into a "where" entity.
     * @param who address of the "who"
     * @param where address of the "where" entity
     */
    event OptIn(address indexed who, address indexed where);

    /**
     * @notice Emitted when a "who" opts out from a "where" entity.
     * @param who address of the "who"
     * @param where address of the "where" entity
     */
    event OptOut(address indexed who, address indexed where);

    /**
     * @notice Emitted when the nonce of a "who" to a "where" entity is increased.
     * @param who address of the "who"
     * @param where address of the "where" entity
     */
    event IncreaseNonce(address indexed who, address indexed where);

    /**
     * @notice Get the "who" registry's address.
     * @return address of the "who" registry
     */
    function WHO_REGISTRY() external view returns (address);

    /**
     * @notice Get the address of the registry where to opt-in.
     * @return address of the "where" registry
     */
    function WHERE_REGISTRY() external view returns (address);

    /**
     * @notice Get if a given "who" is opted-in to a particular "where" entity at a given timestamp using a hint.
     * @param who address of the "who"
     * @param where address of the "where" entity
     * @param timestamp time point to get if the "who" is opted-in at
     * @param hint hint for the checkpoint index
     * @return if the "who" is opted-in at the given timestamp
     */
    function isOptedInAt(
        address who,
        address where,
        uint48 timestamp,
        bytes calldata hint
    ) external view returns (bool);

    /**
     * @notice Check if a given "who" is opted-in to a particular "where" entity.
     * @param who address of the "who"
     * @param where address of the "where" entity
     * @return if the "who" is opted-in
     */
    function isOptedIn(address who, address where) external view returns (bool);

    /**
     * @notice Get the nonce of a given "who" to a particular "where" entity.
     * @param who address of the "who"
     * @param where address of the "where" entity
     * @return nonce
     */
    function nonces(address who, address where) external view returns (uint256);

    /**
     * @notice Opt-in a calling "who" to a particular "where" entity.
     * @param where address of the "where" entity
     */
    function optIn(
        address where
    ) external;

    /**
     * @notice Opt-in a "who" to a particular "where" entity with a signature.
     * @param who address of the "who"
     * @param where address of the "where" entity
     * @param deadline time point until the signature is valid (inclusively)
     * @param signature signature of the "who"
     */
    function optIn(address who, address where, uint48 deadline, bytes calldata signature) external;

    /**
     * @notice Opt-out a calling "who" from a particular "where" entity.
     * @param where address of the "where" entity
     */
    function optOut(
        address where
    ) external;

    /**
     * @notice Opt-out a "who" from a particular "where" entity with a signature.
     * @param who address of the "who"
     * @param where address of the "where" entity
     * @param deadline time point until the signature is valid (inclusively)
     * @param signature signature of the "who"
     */
    function optOut(address who, address where, uint48 deadline, bytes calldata signature) external;

    /**
     * @notice Increase the nonce of a given "who" to a particular "where" entity.
     * @param where address of the "where" entity
     * @dev It can be used to invalidate a given signature.
     */
    function increaseNonce(
        address where
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./Errors.sol" as CastingErrors;
import { MAX_UINT128, MAX_UINT40 } from "../Common.sol";
import { uMAX_SD1x18 } from "../sd1x18/Constants.sol";
import { SD1x18 } from "../sd1x18/ValueType.sol";
import { uMAX_SD59x18 } from "../sd59x18/Constants.sol";
import { SD59x18 } from "../sd59x18/ValueType.sol";
import { uMAX_UD2x18 } from "../ud2x18/Constants.sol";
import { UD2x18 } from "../ud2x18/ValueType.sol";
import { UD60x18 } from "./ValueType.sol";

/// @notice Casts a UD60x18 number into SD1x18.
/// @dev Requirements:
/// - x must be less than or equal to `uMAX_SD1x18`.
function intoSD1x18(UD60x18 x) pure returns (SD1x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(int256(uMAX_SD1x18))) {
        revert CastingErrors.PRBMath_UD60x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(uint64(xUint)));
}

/// @notice Casts a UD60x18 number into UD2x18.
/// @dev Requirements:
/// - x must be less than or equal to `uMAX_UD2x18`.
function intoUD2x18(UD60x18 x) pure returns (UD2x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uMAX_UD2x18) {
        revert CastingErrors.PRBMath_UD60x18_IntoUD2x18_Overflow(x);
    }
    result = UD2x18.wrap(uint64(xUint));
}

/// @notice Casts a UD60x18 number into SD59x18.
/// @dev Requirements:
/// - x must be less than or equal to `uMAX_SD59x18`.
function intoSD59x18(UD60x18 x) pure returns (SD59x18 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > uint256(uMAX_SD59x18)) {
        revert CastingErrors.PRBMath_UD60x18_IntoSD59x18_Overflow(x);
    }
    result = SD59x18.wrap(int256(xUint));
}

/// @notice Casts a UD60x18 number into uint128.
/// @dev This is basically an alias for {unwrap}.
function intoUint256(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

/// @notice Casts a UD60x18 number into uint128.
/// @dev Requirements:
/// - x must be less than or equal to `MAX_UINT128`.
function intoUint128(UD60x18 x) pure returns (uint128 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > MAX_UINT128) {
        revert CastingErrors.PRBMath_UD60x18_IntoUint128_Overflow(x);
    }
    result = uint128(xUint);
}

/// @notice Casts a UD60x18 number into uint40.
/// @dev Requirements:
/// - x must be less than or equal to `MAX_UINT40`.
function intoUint40(UD60x18 x) pure returns (uint40 result) {
    uint256 xUint = UD60x18.unwrap(x);
    if (xUint > MAX_UINT40) {
        revert CastingErrors.PRBMath_UD60x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

/// @notice Alias for {wrap}.
function ud(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

/// @notice Alias for {wrap}.
function ud60x18(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

/// @notice Unwraps a UD60x18 number into uint256.
function unwrap(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x);
}

/// @notice Wraps a uint256 number into the UD60x18 value type.
function wrap(uint256 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(x);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { UD60x18 } from "./ValueType.sol";

// NOTICE: the "u" prefix stands for "unwrapped".

/// @dev Euler's number as a UD60x18 number.
UD60x18 constant E = UD60x18.wrap(2_718281828459045235);

/// @dev The maximum input permitted in {exp}.
uint256 constant uEXP_MAX_INPUT = 133_084258667509499440;
UD60x18 constant EXP_MAX_INPUT = UD60x18.wrap(uEXP_MAX_INPUT);

/// @dev The maximum input permitted in {exp2}.
uint256 constant uEXP2_MAX_INPUT = 192e18 - 1;
UD60x18 constant EXP2_MAX_INPUT = UD60x18.wrap(uEXP2_MAX_INPUT);

/// @dev Half the UNIT number.
uint256 constant uHALF_UNIT = 0.5e18;
UD60x18 constant HALF_UNIT = UD60x18.wrap(uHALF_UNIT);

/// @dev $log_2(10)$ as a UD60x18 number.
uint256 constant uLOG2_10 = 3_321928094887362347;
UD60x18 constant LOG2_10 = UD60x18.wrap(uLOG2_10);

/// @dev $log_2(e)$ as a UD60x18 number.
uint256 constant uLOG2_E = 1_442695040888963407;
UD60x18 constant LOG2_E = UD60x18.wrap(uLOG2_E);

/// @dev The maximum value a UD60x18 number can have.
uint256 constant uMAX_UD60x18 = 115792089237316195423570985008687907853269984665640564039457_584007913129639935;
UD60x18 constant MAX_UD60x18 = UD60x18.wrap(uMAX_UD60x18);

/// @dev The maximum whole value a UD60x18 number can have.
uint256 constant uMAX_WHOLE_UD60x18 = 115792089237316195423570985008687907853269984665640564039457_000000000000000000;
UD60x18 constant MAX_WHOLE_UD60x18 = UD60x18.wrap(uMAX_WHOLE_UD60x18);

/// @dev PI as a UD60x18 number.
UD60x18 constant PI = UD60x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of UD60x18.
uint256 constant uUNIT = 1e18;
UD60x18 constant UNIT = UD60x18.wrap(uUNIT);

/// @dev The unit number squared.
uint256 constant uUNIT_SQUARED = 1e36;
UD60x18 constant UNIT_SQUARED = UD60x18.wrap(uUNIT_SQUARED);

/// @dev Zero as a UD60x18 number.
UD60x18 constant ZERO = UD60x18.wrap(0);

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { uMAX_UD60x18, uUNIT } from "./Constants.sol";
import { PRBMath_UD60x18_Convert_Overflow } from "./Errors.sol";
import { UD60x18 } from "./ValueType.sol";

/// @notice Converts a UD60x18 number to a simple integer by dividing it by `UNIT`.
/// @dev The result is rounded toward zero.
/// @param x The UD60x18 number to convert.
/// @return result The same number in basic integer form.
function convert(UD60x18 x) pure returns (uint256 result) {
    result = UD60x18.unwrap(x) / uUNIT;
}

/// @notice Converts a simple integer to UD60x18 by multiplying it by `UNIT`.
///
/// @dev Requirements:
/// - x must be less than or equal to `MAX_UD60x18 / UNIT`.
///
/// @param x The basic integer to convert.
/// @param result The same number converted to UD60x18.
function convert(uint256 x) pure returns (UD60x18 result) {
    if (x > uMAX_UD60x18 / uUNIT) {
        revert PRBMath_UD60x18_Convert_Overflow(x);
    }
    unchecked {
        result = UD60x18.wrap(x * uUNIT);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { UD60x18 } from "./ValueType.sol";

/// @notice Thrown when ceiling a number overflows UD60x18.
error PRBMath_UD60x18_Ceil_Overflow(UD60x18 x);

/// @notice Thrown when converting a basic integer to the fixed-point format overflows UD60x18.
error PRBMath_UD60x18_Convert_Overflow(uint256 x);

/// @notice Thrown when taking the natural exponent of a base greater than 133_084258667509499441.
error PRBMath_UD60x18_Exp_InputTooBig(UD60x18 x);

/// @notice Thrown when taking the binary exponent of a base greater than 192e18.
error PRBMath_UD60x18_Exp2_InputTooBig(UD60x18 x);

/// @notice Thrown when taking the geometric mean of two numbers and multiplying them overflows UD60x18.
error PRBMath_UD60x18_Gm_Overflow(UD60x18 x, UD60x18 y);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD1x18.
error PRBMath_UD60x18_IntoSD1x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD59x18.
error PRBMath_UD60x18_IntoSD59x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in UD2x18.
error PRBMath_UD60x18_IntoUD2x18_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint128.
error PRBMath_UD60x18_IntoUint128_Overflow(UD60x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint40.
error PRBMath_UD60x18_IntoUint40_Overflow(UD60x18 x);

/// @notice Thrown when taking the logarithm of a number less than 1.
error PRBMath_UD60x18_Log_InputTooSmall(UD60x18 x);

/// @notice Thrown when calculating the square root overflows UD60x18.
error PRBMath_UD60x18_Sqrt_Overflow(UD60x18 x);

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { wrap } from "./Casting.sol";
import { UD60x18 } from "./ValueType.sol";

/// @notice Implements the checked addition operation (+) in the UD60x18 type.
function add(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() + y.unwrap());
}

/// @notice Implements the AND (&) bitwise operation in the UD60x18 type.
function and(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() & bits);
}

/// @notice Implements the AND (&) bitwise operation in the UD60x18 type.
function and2(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() & y.unwrap());
}

/// @notice Implements the equal operation (==) in the UD60x18 type.
function eq(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() == y.unwrap();
}

/// @notice Implements the greater than operation (>) in the UD60x18 type.
function gt(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() > y.unwrap();
}

/// @notice Implements the greater than or equal to operation (>=) in the UD60x18 type.
function gte(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() >= y.unwrap();
}

/// @notice Implements a zero comparison check function in the UD60x18 type.
function isZero(UD60x18 x) pure returns (bool result) {
    // This wouldn't work if x could be negative.
    result = x.unwrap() == 0;
}

/// @notice Implements the left shift operation (<<) in the UD60x18 type.
function lshift(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() << bits);
}

/// @notice Implements the lower than operation (<) in the UD60x18 type.
function lt(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() < y.unwrap();
}

/// @notice Implements the lower than or equal to operation (<=) in the UD60x18 type.
function lte(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() <= y.unwrap();
}

/// @notice Implements the checked modulo operation (%) in the UD60x18 type.
function mod(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() % y.unwrap());
}

/// @notice Implements the not equal operation (!=) in the UD60x18 type.
function neq(UD60x18 x, UD60x18 y) pure returns (bool result) {
    result = x.unwrap() != y.unwrap();
}

/// @notice Implements the NOT (~) bitwise operation in the UD60x18 type.
function not(UD60x18 x) pure returns (UD60x18 result) {
    result = wrap(~x.unwrap());
}

/// @notice Implements the OR (|) bitwise operation in the UD60x18 type.
function or(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() | y.unwrap());
}

/// @notice Implements the right shift operation (>>) in the UD60x18 type.
function rshift(UD60x18 x, uint256 bits) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() >> bits);
}

/// @notice Implements the checked subtraction operation (-) in the UD60x18 type.
function sub(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() - y.unwrap());
}

/// @notice Implements the unchecked addition operation (+) in the UD60x18 type.
function uncheckedAdd(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    unchecked {
        result = wrap(x.unwrap() + y.unwrap());
    }
}

/// @notice Implements the unchecked subtraction operation (-) in the UD60x18 type.
function uncheckedSub(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    unchecked {
        result = wrap(x.unwrap() - y.unwrap());
    }
}

/// @notice Implements the XOR (^) bitwise operation in the UD60x18 type.
function xor(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(x.unwrap() ^ y.unwrap());
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../Common.sol" as Common;
import "./Errors.sol" as Errors;
import { wrap } from "./Casting.sol";
import {
    uEXP_MAX_INPUT,
    uEXP2_MAX_INPUT,
    uHALF_UNIT,
    uLOG2_10,
    uLOG2_E,
    uMAX_UD60x18,
    uMAX_WHOLE_UD60x18,
    UNIT,
    uUNIT,
    uUNIT_SQUARED,
    ZERO
} from "./Constants.sol";
import { UD60x18 } from "./ValueType.sol";

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Calculates the arithmetic average of x and y using the following formula:
///
/// $$
/// avg(x, y) = (x & y) + ((xUint ^ yUint) / 2)
/// $$
///
/// In English, this is what this formula does:
///
/// 1. AND x and y.
/// 2. Calculate half of XOR x and y.
/// 3. Add the two results together.
///
/// This technique is known as SWAR, which stands for "SIMD within a register". You can read more about it here:
/// https://devblogs.microsoft.com/oldnewthing/20220207-00/?p=106223
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// @param x The first operand as a UD60x18 number.
/// @param y The second operand as a UD60x18 number.
/// @return result The arithmetic average as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function avg(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();
    uint256 yUint = y.unwrap();
    unchecked {
        result = wrap((xUint & yUint) + ((xUint ^ yUint) >> 1));
    }
}

/// @notice Yields the smallest whole number greater than or equal to x.
///
/// @dev This is optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional
/// counterparts. See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x must be less than or equal to `MAX_WHOLE_UD60x18`.
///
/// @param x The UD60x18 number to ceil.
/// @param result The smallest whole number greater than or equal to x, as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function ceil(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();
    if (xUint > uMAX_WHOLE_UD60x18) {
        revert Errors.PRBMath_UD60x18_Ceil_Overflow(x);
    }

    assembly ("memory-safe") {
        // Equivalent to `x % UNIT`.
        let remainder := mod(x, uUNIT)

        // Equivalent to `UNIT - remainder`.
        let delta := sub(uUNIT, remainder)

        // Equivalent to `x + remainder > 0 ? delta : 0`.
        result := add(x, mul(delta, gt(remainder, 0)))
    }
}

/// @notice Divides two UD60x18 numbers, returning a new UD60x18 number.
///
/// @dev Uses {Common.mulDiv} to enable overflow-safe multiplication and division.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
///
/// @param x The numerator as a UD60x18 number.
/// @param y The denominator as a UD60x18 number.
/// @param result The quotient as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function div(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(Common.mulDiv(x.unwrap(), uUNIT, y.unwrap()));
}

/// @notice Calculates the natural exponent of x using the following formula:
///
/// $$
/// e^x = 2^{x * log_2{e}}
/// $$
///
/// @dev Requirements:
/// - x must be less than 133_084258667509499441.
///
/// @param x The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();

    // This check prevents values greater than 192e18 from being passed to {exp2}.
    if (xUint > uEXP_MAX_INPUT) {
        revert Errors.PRBMath_UD60x18_Exp_InputTooBig(x);
    }

    unchecked {
        // Inline the fixed-point multiplication to save gas.
        uint256 doubleUnitProduct = xUint * uLOG2_E;
        result = exp2(wrap(doubleUnitProduct / uUNIT));
    }
}

/// @notice Calculates the binary exponent of x using the binary fraction method.
///
/// @dev See https://ethereum.stackexchange.com/q/79903/24693
///
/// Requirements:
/// - x must be less than 192e18.
/// - The result must fit in UD60x18.
///
/// @param x The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp2(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();

    // Numbers greater than or equal to 192e18 don't fit in the 192.64-bit format.
    if (xUint > uEXP2_MAX_INPUT) {
        revert Errors.PRBMath_UD60x18_Exp2_InputTooBig(x);
    }

    // Convert x to the 192.64-bit fixed-point format.
    uint256 x_192x64 = (xUint << 64) / uUNIT;

    // Pass x to the {Common.exp2} function, which uses the 192.64-bit fixed-point number representation.
    result = wrap(Common.exp2(x_192x64));
}

/// @notice Yields the greatest whole number less than or equal to x.
/// @dev Optimized for fractional value inputs, because every whole value has (1e18 - 1) fractional counterparts.
/// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
/// @param x The UD60x18 number to floor.
/// @param result The greatest whole number less than or equal to x, as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function floor(UD60x18 x) pure returns (UD60x18 result) {
    assembly ("memory-safe") {
        // Equivalent to `x % UNIT`.
        let remainder := mod(x, uUNIT)

        // Equivalent to `x - remainder > 0 ? remainder : 0)`.
        result := sub(x, mul(remainder, gt(remainder, 0)))
    }
}

/// @notice Yields the excess beyond the floor of x using the odd function definition.
/// @dev See https://en.wikipedia.org/wiki/Fractional_part.
/// @param x The UD60x18 number to get the fractional part of.
/// @param result The fractional part of x as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function frac(UD60x18 x) pure returns (UD60x18 result) {
    assembly ("memory-safe") {
        result := mod(x, uUNIT)
    }
}

/// @notice Calculates the geometric mean of x and y, i.e. $\sqrt{x * y}$, rounding down.
///
/// @dev Requirements:
/// - x * y must fit in UD60x18.
///
/// @param x The first operand as a UD60x18 number.
/// @param y The second operand as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function gm(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();
    uint256 yUint = y.unwrap();
    if (xUint == 0 || yUint == 0) {
        return ZERO;
    }

    unchecked {
        // Checking for overflow this way is faster than letting Solidity do it.
        uint256 xyUint = xUint * yUint;
        if (xyUint / xUint != yUint) {
            revert Errors.PRBMath_UD60x18_Gm_Overflow(x, y);
        }

        // We don't need to multiply the result by `UNIT` here because the x*y product picked up a factor of `UNIT`
        // during multiplication. See the comments in {Common.sqrt}.
        result = wrap(Common.sqrt(xyUint));
    }
}

/// @notice Calculates the inverse of x.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x must not be zero.
///
/// @param x The UD60x18 number for which to calculate the inverse.
/// @return result The inverse as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function inv(UD60x18 x) pure returns (UD60x18 result) {
    unchecked {
        result = wrap(uUNIT_SQUARED / x.unwrap());
    }
}

/// @notice Calculates the natural logarithm of x using the following formula:
///
/// $$
/// ln{x} = log_2{x} / log_2{e}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
/// - The precision isn't sufficiently fine-grained to return exactly `UNIT` when the input is `E`.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The UD60x18 number for which to calculate the natural logarithm.
/// @return result The natural logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function ln(UD60x18 x) pure returns (UD60x18 result) {
    unchecked {
        // Inline the fixed-point multiplication to save gas. This is overflow-safe because the maximum value that
        // {log2} can return is ~196_205294292027477728.
        result = wrap(log2(x).unwrap() * uUNIT / uLOG2_E);
    }
}

/// @notice Calculates the common logarithm of x using the following formula:
///
/// $$
/// log_{10}{x} = log_2{x} / log_2{10}
/// $$
///
/// However, if x is an exact power of ten, a hard coded value is returned.
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The UD60x18 number for which to calculate the common logarithm.
/// @return result The common logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function log10(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();
    if (xUint < uUNIT) {
        revert Errors.PRBMath_UD60x18_Log_InputTooSmall(x);
    }

    // Note that the `mul` in this assembly block is the standard multiplication operation, not {UD60x18.mul}.
    // prettier-ignore
    assembly ("memory-safe") {
        switch x
        case 1 { result := mul(uUNIT, sub(0, 18)) }
        case 10 { result := mul(uUNIT, sub(1, 18)) }
        case 100 { result := mul(uUNIT, sub(2, 18)) }
        case 1000 { result := mul(uUNIT, sub(3, 18)) }
        case 10000 { result := mul(uUNIT, sub(4, 18)) }
        case 100000 { result := mul(uUNIT, sub(5, 18)) }
        case 1000000 { result := mul(uUNIT, sub(6, 18)) }
        case 10000000 { result := mul(uUNIT, sub(7, 18)) }
        case 100000000 { result := mul(uUNIT, sub(8, 18)) }
        case 1000000000 { result := mul(uUNIT, sub(9, 18)) }
        case 10000000000 { result := mul(uUNIT, sub(10, 18)) }
        case 100000000000 { result := mul(uUNIT, sub(11, 18)) }
        case 1000000000000 { result := mul(uUNIT, sub(12, 18)) }
        case 10000000000000 { result := mul(uUNIT, sub(13, 18)) }
        case 100000000000000 { result := mul(uUNIT, sub(14, 18)) }
        case 1000000000000000 { result := mul(uUNIT, sub(15, 18)) }
        case 10000000000000000 { result := mul(uUNIT, sub(16, 18)) }
        case 100000000000000000 { result := mul(uUNIT, sub(17, 18)) }
        case 1000000000000000000 { result := 0 }
        case 10000000000000000000 { result := uUNIT }
        case 100000000000000000000 { result := mul(uUNIT, 2) }
        case 1000000000000000000000 { result := mul(uUNIT, 3) }
        case 10000000000000000000000 { result := mul(uUNIT, 4) }
        case 100000000000000000000000 { result := mul(uUNIT, 5) }
        case 1000000000000000000000000 { result := mul(uUNIT, 6) }
        case 10000000000000000000000000 { result := mul(uUNIT, 7) }
        case 100000000000000000000000000 { result := mul(uUNIT, 8) }
        case 1000000000000000000000000000 { result := mul(uUNIT, 9) }
        case 10000000000000000000000000000 { result := mul(uUNIT, 10) }
        case 100000000000000000000000000000 { result := mul(uUNIT, 11) }
        case 1000000000000000000000000000000 { result := mul(uUNIT, 12) }
        case 10000000000000000000000000000000 { result := mul(uUNIT, 13) }
        case 100000000000000000000000000000000 { result := mul(uUNIT, 14) }
        case 1000000000000000000000000000000000 { result := mul(uUNIT, 15) }
        case 10000000000000000000000000000000000 { result := mul(uUNIT, 16) }
        case 100000000000000000000000000000000000 { result := mul(uUNIT, 17) }
        case 1000000000000000000000000000000000000 { result := mul(uUNIT, 18) }
        case 10000000000000000000000000000000000000 { result := mul(uUNIT, 19) }
        case 100000000000000000000000000000000000000 { result := mul(uUNIT, 20) }
        case 1000000000000000000000000000000000000000 { result := mul(uUNIT, 21) }
        case 10000000000000000000000000000000000000000 { result := mul(uUNIT, 22) }
        case 100000000000000000000000000000000000000000 { result := mul(uUNIT, 23) }
        case 1000000000000000000000000000000000000000000 { result := mul(uUNIT, 24) }
        case 10000000000000000000000000000000000000000000 { result := mul(uUNIT, 25) }
        case 100000000000000000000000000000000000000000000 { result := mul(uUNIT, 26) }
        case 1000000000000000000000000000000000000000000000 { result := mul(uUNIT, 27) }
        case 10000000000000000000000000000000000000000000000 { result := mul(uUNIT, 28) }
        case 100000000000000000000000000000000000000000000000 { result := mul(uUNIT, 29) }
        case 1000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 30) }
        case 10000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 31) }
        case 100000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 32) }
        case 1000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 33) }
        case 10000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 34) }
        case 100000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 35) }
        case 1000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 36) }
        case 10000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 37) }
        case 100000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 38) }
        case 1000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 39) }
        case 10000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 40) }
        case 100000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 41) }
        case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 42) }
        case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 43) }
        case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 44) }
        case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 45) }
        case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 46) }
        case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 47) }
        case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 48) }
        case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 49) }
        case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 50) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 51) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 52) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 53) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 54) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 55) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 56) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 57) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 58) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 59) }
        default { result := uMAX_UD60x18 }
    }

    if (result.unwrap() == uMAX_UD60x18) {
        unchecked {
            // Inline the fixed-point division to save gas.
            result = wrap(log2(x).unwrap() * uUNIT / uLOG2_10);
        }
    }
}

/// @notice Calculates the binary logarithm of x using the iterative approximation algorithm:
///
/// $$
/// log_2{x} = n + log_2{y}, \text{ where } y = x*2^{-n}, \ y \in [1, 2)
/// $$
///
/// For $0 \leq x \lt 1$, the input is inverted:
///
/// $$
/// log_2{x} = -log_2{\frac{1}{x}}
/// $$
///
/// @dev See https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
///
/// Notes:
/// - Due to the lossy precision of the iterative approximation, the results are not perfectly accurate to the last decimal.
///
/// Requirements:
/// - x must be greater than zero.
///
/// @param x The UD60x18 number for which to calculate the binary logarithm.
/// @return result The binary logarithm as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function log2(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();

    if (xUint < uUNIT) {
        revert Errors.PRBMath_UD60x18_Log_InputTooSmall(x);
    }

    unchecked {
        // Calculate the integer part of the logarithm.
        uint256 n = Common.msb(xUint / uUNIT);

        // This is the integer part of the logarithm as a UD60x18 number. The operation can't overflow because n
        // n is at most 255 and UNIT is 1e18.
        uint256 resultUint = n * uUNIT;

        // Calculate $y = x * 2^{-n}$.
        uint256 y = xUint >> n;

        // If y is the unit number, the fractional part is zero.
        if (y == uUNIT) {
            return wrap(resultUint);
        }

        // Calculate the fractional part via the iterative approximation.
        // The `delta >>= 1` part is equivalent to `delta /= 2`, but shifting bits is more gas efficient.
        uint256 DOUBLE_UNIT = 2e18;
        for (uint256 delta = uHALF_UNIT; delta > 0; delta >>= 1) {
            y = (y * y) / uUNIT;

            // Is y^2 >= 2e18 and so in the range [2e18, 4e18)?
            if (y >= DOUBLE_UNIT) {
                // Add the 2^{-m} factor to the logarithm.
                resultUint += delta;

                // Halve y, which corresponds to z/2 in the Wikipedia article.
                y >>= 1;
            }
        }
        result = wrap(resultUint);
    }
}

/// @notice Multiplies two UD60x18 numbers together, returning a new UD60x18 number.
///
/// @dev Uses {Common.mulDiv} to enable overflow-safe multiplication and division.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
///
/// @dev See the documentation in {Common.mulDiv18}.
/// @param x The multiplicand as a UD60x18 number.
/// @param y The multiplier as a UD60x18 number.
/// @return result The product as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function mul(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    result = wrap(Common.mulDiv18(x.unwrap(), y.unwrap()));
}

/// @notice Raises x to the power of y.
///
/// For $1 \leq x \leq \infty$, the following standard formula is used:
///
/// $$
/// x^y = 2^{log_2{x} * y}
/// $$
///
/// For $0 \leq x \lt 1$, since the unsigned {log2} is undefined, an equivalent formula is used:
///
/// $$
/// i = \frac{1}{x}
/// w = 2^{log_2{i} * y}
/// x^y = \frac{1}{w}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2} and {mul}.
/// - Returns `UNIT` for 0^0.
/// - It may not perform well with very small values of x. Consider using SD59x18 as an alternative.
///
/// Requirements:
/// - Refer to the requirements in {exp2}, {log2}, and {mul}.
///
/// @param x The base as a UD60x18 number.
/// @param y The exponent as a UD60x18 number.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function pow(UD60x18 x, UD60x18 y) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();
    uint256 yUint = y.unwrap();

    // If both x and y are zero, the result is `UNIT`. If just x is zero, the result is always zero.
    if (xUint == 0) {
        return yUint == 0 ? UNIT : ZERO;
    }
    // If x is `UNIT`, the result is always `UNIT`.
    else if (xUint == uUNIT) {
        return UNIT;
    }

    // If y is zero, the result is always `UNIT`.
    if (yUint == 0) {
        return UNIT;
    }
    // If y is `UNIT`, the result is always x.
    else if (yUint == uUNIT) {
        return x;
    }

    // If x is greater than `UNIT`, use the standard formula.
    if (xUint > uUNIT) {
        result = exp2(mul(log2(x), y));
    }
    // Conversely, if x is less than `UNIT`, use the equivalent formula.
    else {
        UD60x18 i = wrap(uUNIT_SQUARED / xUint);
        UD60x18 w = exp2(mul(log2(i), y));
        result = wrap(uUNIT_SQUARED / w.unwrap());
    }
}

/// @notice Raises x (a UD60x18 number) to the power y (an unsigned basic integer) using the well-known
/// algorithm "exponentiation by squaring".
///
/// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv18}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - The result must fit in UD60x18.
///
/// @param x The base as a UD60x18 number.
/// @param y The exponent as a uint256.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function powu(UD60x18 x, uint256 y) pure returns (UD60x18 result) {
    // Calculate the first iteration of the loop in advance.
    uint256 xUint = x.unwrap();
    uint256 resultUint = y & 1 > 0 ? xUint : uUNIT;

    // Equivalent to `for(y /= 2; y > 0; y /= 2)`.
    for (y >>= 1; y > 0; y >>= 1) {
        xUint = Common.mulDiv18(xUint, xUint);

        // Equivalent to `y % 2 == 1`.
        if (y & 1 > 0) {
            resultUint = Common.mulDiv18(resultUint, xUint);
        }
    }
    result = wrap(resultUint);
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x must be less than `MAX_UD60x18 / UNIT`.
///
/// @param x The UD60x18 number for which to calculate the square root.
/// @return result The result as a UD60x18 number.
/// @custom:smtchecker abstract-function-nondet
function sqrt(UD60x18 x) pure returns (UD60x18 result) {
    uint256 xUint = x.unwrap();

    unchecked {
        if (xUint > uMAX_UD60x18 / uUNIT) {
            revert Errors.PRBMath_UD60x18_Sqrt_Overflow(x);
        }
        // Multiply x by `UNIT` to account for the factor of `UNIT` picked up when multiplying two UD60x18 numbers.
        // In this case, the two numbers are both the square root.
        result = wrap(Common.sqrt(xUint * uUNIT));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./Casting.sol" as Casting;
import "./Helpers.sol" as Helpers;
import "./Math.sol" as Math;

/// @notice The unsigned 60.18-decimal fixed-point number representation, which can have up to 60 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the Solidity type uint256.
/// @dev The value type is defined here so it can be imported in all other files.
type UD60x18 is uint256;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    Casting.intoSD1x18,
    Casting.intoUD2x18,
    Casting.intoSD59x18,
    Casting.intoUint128,
    Casting.intoUint256,
    Casting.intoUint40,
    Casting.unwrap
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes the functions in this library callable on the UD60x18 type.
using {
    Math.avg,
    Math.ceil,
    Math.div,
    Math.exp,
    Math.exp2,
    Math.floor,
    Math.frac,
    Math.gm,
    Math.inv,
    Math.ln,
    Math.log10,
    Math.log2,
    Math.mul,
    Math.pow,
    Math.powu,
    Math.sqrt
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes the functions in this library callable on the UD60x18 type.
using {
    Helpers.add,
    Helpers.and,
    Helpers.eq,
    Helpers.gt,
    Helpers.gte,
    Helpers.isZero,
    Helpers.lshift,
    Helpers.lt,
    Helpers.lte,
    Helpers.mod,
    Helpers.neq,
    Helpers.not,
    Helpers.or,
    Helpers.rshift,
    Helpers.sub,
    Helpers.uncheckedAdd,
    Helpers.uncheckedSub,
    Helpers.xor
} for UD60x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                    OPERATORS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes it possible to use these operators on the UD60x18 type.
using {
    Helpers.add as +,
    Helpers.and2 as &,
    Math.div as /,
    Helpers.eq as ==,
    Helpers.gt as >,
    Helpers.gte as >=,
    Helpers.lt as <,
    Helpers.lte as <=,
    Helpers.or as |,
    Helpers.mod as %,
    Math.mul as *,
    Helpers.neq as !=,
    Helpers.not as ~,
    Helpers.sub as -,
    Helpers.xor as ^
} for UD60x18 global;

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

// Used to verify merkle proofs generated by https://github.com/paritytech/substrate/tree/master/utils/binary-merkle-tree
library SubstrateMerkleProof {
    /**
     * @notice Verify that a specific leaf element is part of the Merkle Tree at a specific position in the tree
     *
     * The tree would have been constructed using
     * https://paritytech.github.io/substrate/master/binary_merkle_tree/fn.merkle_root.html
     *
     * This implementation adapted from
     * https://paritytech.github.io/substrate/master/binary_merkle_tree/fn.verify_proof.html
     *
     * @param root the root of the merkle tree
     * @param leaf the leaf which needs to be proven
     * @param position the position of the leaf, index starting with 0
     * @param width the width or number of leaves in the tree
     * @param proof the array of proofs to help verify the leaf's membership, ordered from leaf to root
     * @return a boolean value representing the success or failure of the operation
     */
    function verify(bytes32 root, bytes32 leaf, uint256 position, uint256 width, bytes32[] calldata proof)
        internal
        pure
        returns (bool)
    {
        if (position >= width) {
            return false;
        }
        return root == computeRoot(leaf, position, width, proof);
    }

    function computeRoot(bytes32 leaf, uint256 position, uint256 width, bytes32[] calldata proof)
        internal
        pure
        returns (bytes32)
    {
        bytes32 node = leaf;
        unchecked {
            for (uint256 i = 0; i < proof.length; i++) {
                if (position & 1 == 1 || position + 1 == width) {
                    node = efficientHash(proof[i], node);
                } else {
                    node = efficientHash(node, proof[i]);
                }
                position = position >> 1;
                width = ((width - 1) >> 1) + 1;
            }
            return node;
        }
    }

    function efficientHash(bytes32 a, bytes32 b) internal pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {SubstrateMerkleProof} from "./utils/SubstrateMerkleProof.sol";
import {Bitfield} from "./utils/Bitfield.sol";
import {Uint16Array, createUint16Array} from "./utils/Uint16Array.sol";
import {Math} from "./utils/Math.sol";
import {MMRProof} from "./utils/MMRProof.sol";
import {ScaleCodec} from "./utils/ScaleCodec.sol";

/**
 * @title BeefyClient
 *
 * High-level documentation at https://docs.snowbridge.network/architecture/verification/polkadot
 *
 * To submit new commitments, relayers must call the following methods sequentially:
 * 1. submitInitial: Setup the session for the interactive submission
 * 2. commitPrevRandao: Commit to a random seed for generating a validator subsampling
 * 3. createFinalBitfield: Generate the validator subsampling
 * 4. submitFinal: Complete submission after providing the request validator signatures
 *
 */
contract BeefyClient {
    using Math for uint16;
    using Math for uint256;

    /* Events */

    /**
     * @dev Emitted when the MMR root is updated
     * @param mmrRoot the updated MMR root
     * @param blockNumber the beefy block number of the updated MMR root
     */
    event NewMMRRoot(bytes32 mmrRoot, uint64 blockNumber);

    /**
     * @dev Emitted when a new ticket has been created
     * @param relayer The relayer who created the ticket
     * @param blockNumber the parent block number of the candidate MMR root
     */
    event NewTicket(address relayer, uint64 blockNumber);

    /* Types */

    /**
     * @dev The Commitment, with its payload, is the core thing we are trying to verify with
     * this contract. It contains an MMR root that commits to the polkadot history, including
     * past blocks and parachain blocks and can be used to verify both polkadot and parachain blocks.
     */
    struct Commitment {
        // Relay chain block number
        uint32 blockNumber;
        // ID of the validator set that signed the commitment
        uint64 validatorSetID;
        // The payload of the new commitment in beefy justifications (in
        // our case, this is a new MMR root for all past polkadot blocks)
        PayloadItem[] payload;
    }

    /**
     * @dev Each PayloadItem is a piece of data signed by validators at a particular block.
     */
    struct PayloadItem {
        // An ID that references a description of the data in the payload item.
        // Known payload ids can be found [upstream](https://github.com/paritytech/substrate/blob/fe1f8ba1c4f23931ae89c1ada35efb3d908b50f5/primitives/consensus/beefy/src/payload.rs#L27).
        bytes2 payloadID;
        // The contents of the payload item
        bytes data;
    }

    /**
     * @dev The ValidatorProof is a proof used to verify a commitment signature
     */
    struct ValidatorProof {
        // The parity bit to specify the intended solution
        uint8 v;
        // The x component on the secp256k1 curve
        bytes32 r;
        // The challenge solution
        bytes32 s;
        // Leaf index of the validator address in the merkle tree
        uint256 index;
        // Validator address
        address account;
        // Merkle proof for the validator
        bytes32[] proof;
    }

    /**
     * @dev A ticket tracks working state for the interactive submission of new commitments
     */
    struct Ticket {
        // The block number this ticket was issued
        uint64 blockNumber;
        // Length of the validator set that signed the commitment
        uint32 validatorSetLen;
        // The number of signatures required
        uint32 numRequiredSignatures;
        // The PREVRANDAO seed selected for this ticket session
        uint256 prevRandao;
        // Hash of a bitfield claiming which validators have signed
        bytes32 bitfieldHash;
    }

    /// @dev The MMRLeaf describes the leaf structure of the MMR
    struct MMRLeaf {
        // Version of the leaf type
        uint8 version;
        // Parent number of the block this leaf describes
        uint32 parentNumber;
        // Parent hash of the block this leaf describes
        bytes32 parentHash;
        // Validator set id that will be part of consensus for the next block
        uint64 nextAuthoritySetID;
        // Length of that validator set
        uint32 nextAuthoritySetLen;
        // Merkle root of all public keys in that validator set
        bytes32 nextAuthoritySetRoot;
        // Merkle root of all parachain headers in this block
        bytes32 parachainHeadsRoot;
        // Message commitment
        bytes32 messageCommitment;
    }

    /**
     * @dev The ValidatorSet describes a BEEFY validator set
     */
    struct ValidatorSet {
        // Identifier for the set
        uint128 id;
        // Number of validators in the set
        uint128 length;
        // Merkle root of BEEFY validator addresses
        bytes32 root;
    }

    /**
     * @dev The ValidatorSetState describes a BEEFY validator set along with signature usage counters
     */
    struct ValidatorSetState {
        // Identifier for the set
        uint128 id;
        // Number of validators in the set
        uint128 length;
        // Merkle root of BEEFY validator addresses
        bytes32 root;
        // Number of times a validator signature has been used
        Uint16Array usageCounters;
    }

    /* State */

    /// @dev The latest verified MMR root
    bytes32 public latestMMRRoot;

    /// @dev The block number in the relay chain in which the latest MMR root was emitted
    uint64 public latestBeefyBlock;

    /// @dev State of the current validator set
    ValidatorSetState public currentValidatorSet;

    /// @dev State of the next validator set
    ValidatorSetState public nextValidatorSet;

    /// @dev Pending tickets for commitment submission
    mapping(bytes32 ticketID => Ticket) public tickets;

    /* Constants */

    /**
     * @dev Beefy payload id for MMR Root payload items:
     * https://github.com/paritytech/substrate/blob/fe1f8ba1c4f23931ae89c1ada35efb3d908b50f5/primitives/consensus/beefy/src/payload.rs#L33
     */
    bytes2 public constant MMR_ROOT_ID = bytes2("mh");

    /**
     * @dev Minimum delay in number of blocks that a relayer must wait between calling
     * submitInitial and commitPrevRandao. In production this should be set to MAX_SEED_LOOKAHEAD:
     * https://eth2book.info/altair/part3/config/preset#max_seed_lookahead
     */
    uint256 public immutable randaoCommitDelay;

    /**
     * @dev after randaoCommitDelay is reached, relayer must
     * call commitPrevRandao within this number of blocks.
     * Without this expiration, relayers can roll the dice infinitely to get the subsampling
     * they desire.
     */
    uint256 public immutable randaoCommitExpiration;

    /**
     * @dev Minimum number of signatures required to validate a new commitment. This parameter
     * is calculated based on `randaoCommitExpiration`. See ~/scripts/beefy_signature_sampling.py
     * for the calculation.
     */
    uint256 public immutable minNumRequiredSignatures;

    /* Errors */
    error InvalidBitfield();
    error InvalidBitfieldLength();
    error InvalidCommitment();
    error InvalidMMRLeaf();
    error InvalidMMRLeafProof();
    error InvalidMMRRootLength();
    error InvalidSignature();
    error InvalidTicket();
    error InvalidValidatorProof();
    error InvalidValidatorProofLength();
    error CommitmentNotRelevant();
    error NotEnoughClaims();
    error PrevRandaoAlreadyCaptured();
    error PrevRandaoNotCaptured();
    error StaleCommitment();
    error TicketExpired();
    error WaitPeriodNotOver();

    constructor(
        uint256 _randaoCommitDelay,
        uint256 _randaoCommitExpiration,
        uint256 _minNumRequiredSignatures,
        uint64 _initialBeefyBlock,
        ValidatorSet memory _initialValidatorSet,
        ValidatorSet memory _nextValidatorSet
    ) {
        if (_nextValidatorSet.id != _initialValidatorSet.id + 1) {
            revert("invalid-constructor-params");
        }
        randaoCommitDelay = _randaoCommitDelay;
        randaoCommitExpiration = _randaoCommitExpiration;
        minNumRequiredSignatures = _minNumRequiredSignatures;
        latestBeefyBlock = _initialBeefyBlock;
        currentValidatorSet.id = _initialValidatorSet.id;
        currentValidatorSet.length = _initialValidatorSet.length;
        currentValidatorSet.root = _initialValidatorSet.root;
        currentValidatorSet.usageCounters = createUint16Array(currentValidatorSet.length);
        nextValidatorSet.id = _nextValidatorSet.id;
        nextValidatorSet.length = _nextValidatorSet.length;
        nextValidatorSet.root = _nextValidatorSet.root;
        nextValidatorSet.usageCounters = createUint16Array(nextValidatorSet.length);
    }

    /* External Functions */

    /**
     * @dev Begin submission of commitment
     * @param commitment contains the commitment signed by the validators
     * @param bitfield a bitfield claiming which validators have signed the commitment
     * @param proof a proof that a single validator from currentValidatorSet has signed the commitment
     */
    function submitInitial(Commitment calldata commitment, uint256[] calldata bitfield, ValidatorProof calldata proof)
        external
    {
        if (commitment.blockNumber <= latestBeefyBlock) {
            revert StaleCommitment();
        }

        ValidatorSetState storage vset;
        uint16 signatureUsageCount;
        if (commitment.validatorSetID == currentValidatorSet.id) {
            signatureUsageCount = currentValidatorSet.usageCounters.get(proof.index);
            currentValidatorSet.usageCounters.set(proof.index, signatureUsageCount.saturatingAdd(1));
            vset = currentValidatorSet;
        } else if (commitment.validatorSetID == nextValidatorSet.id) {
            signatureUsageCount = nextValidatorSet.usageCounters.get(proof.index);
            nextValidatorSet.usageCounters.set(proof.index, signatureUsageCount.saturatingAdd(1));
            vset = nextValidatorSet;
        } else {
            revert InvalidCommitment();
        }

        // Check if merkle proof is valid based on the validatorSetRoot and if proof is included in bitfield
        if (!isValidatorInSet(vset, proof.account, proof.index, proof.proof) || !Bitfield.isSet(bitfield, proof.index))
        {
            revert InvalidValidatorProof();
        }

        // Check if validatorSignature is correct, ie. check if it matches
        // the signature of senderPublicKey on the commitmentHash
        bytes32 commitmentHash = keccak256(encodeCommitment(commitment));
        if (ECDSA.recover(commitmentHash, proof.v, proof.r, proof.s) != proof.account) {
            revert InvalidSignature();
        }

        // For the initial submission, the supplied bitfield should claim that more than
        // two thirds of the validator set have sign the commitment
        if (Bitfield.countSetBits(bitfield) < computeQuorum(vset.length)) {
            revert NotEnoughClaims();
        }

        tickets[createTicketID(msg.sender, commitmentHash)] = Ticket({
            blockNumber: uint64(block.number),
            validatorSetLen: uint32(vset.length),
            numRequiredSignatures: uint32(
                computeNumRequiredSignatures(vset.length, signatureUsageCount, minNumRequiredSignatures)
            ),
            prevRandao: 0,
            bitfieldHash: keccak256(abi.encodePacked(bitfield))
        });

        emit NewTicket(msg.sender, commitment.blockNumber);
    }

    /**
     * @dev Capture PREVRANDAO
     * @param commitmentHash contains the commitmentHash signed by the validators
     */
    function commitPrevRandao(bytes32 commitmentHash) external {
        bytes32 ticketID = createTicketID(msg.sender, commitmentHash);
        Ticket storage ticket = tickets[ticketID];

        if (ticket.blockNumber == 0) {
            revert InvalidTicket();
        }

        if (ticket.prevRandao != 0) {
            revert PrevRandaoAlreadyCaptured();
        }

        // relayer must wait `randaoCommitDelay` blocks
        if (block.number < ticket.blockNumber + randaoCommitDelay) {
            revert WaitPeriodNotOver();
        }

        // relayer can capture within `randaoCommitExpiration` blocks
        if (block.number > ticket.blockNumber + randaoCommitDelay + randaoCommitExpiration) {
            delete tickets[ticketID];
            revert TicketExpired();
        }

        // Post-merge, the difficulty opcode now returns PREVRANDAO
        ticket.prevRandao = block.prevrandao;
    }

    /**
     * @dev Submit a commitment and leaf for final verification
     * @param commitment contains the full commitment that was used for the commitmentHash
     * @param bitfield claiming which validators have signed the commitment
     * @param proofs a struct containing the data needed to verify all validator signatures
     * @param leaf an MMR leaf provable using the MMR root in the commitment payload
     * @param leafProof an MMR leaf proof
     * @param leafProofOrder a bitfield describing the order of each item (left vs right)
     */
    function submitFinal(
        Commitment calldata commitment,
        uint256[] calldata bitfield,
        ValidatorProof[] calldata proofs,
        MMRLeaf calldata leaf,
        bytes32[] calldata leafProof,
        uint256 leafProofOrder
    ) external {
        bytes32 commitmentHash = keccak256(encodeCommitment(commitment));
        bytes32 ticketID = createTicketID(msg.sender, commitmentHash);
        validateTicket(ticketID, commitment, bitfield);

        bool is_next_session = false;
        ValidatorSetState storage vset;
        if (commitment.validatorSetID == nextValidatorSet.id) {
            is_next_session = true;
            vset = nextValidatorSet;
        } else if (commitment.validatorSetID == currentValidatorSet.id) {
            vset = currentValidatorSet;
        } else {
            revert InvalidCommitment();
        }

        verifyCommitment(commitmentHash, ticketID, bitfield, vset, proofs);

        bytes32 newMMRRoot = ensureProvidesMMRRoot(commitment);

        if (is_next_session) {
            if (leaf.nextAuthoritySetID != nextValidatorSet.id + 1) {
                revert InvalidMMRLeaf();
            }
            bool leafIsValid =
                MMRProof.verifyLeafProof(newMMRRoot, keccak256(encodeMMRLeaf(leaf)), leafProof, leafProofOrder);
            if (!leafIsValid) {
                revert InvalidMMRLeafProof();
            }
            currentValidatorSet = nextValidatorSet;
            nextValidatorSet.id = leaf.nextAuthoritySetID;
            nextValidatorSet.length = leaf.nextAuthoritySetLen;
            nextValidatorSet.root = leaf.nextAuthoritySetRoot;
            nextValidatorSet.usageCounters = createUint16Array(leaf.nextAuthoritySetLen);
        }

        latestMMRRoot = newMMRRoot;
        latestBeefyBlock = commitment.blockNumber;
        delete tickets[ticketID];

        emit NewMMRRoot(newMMRRoot, commitment.blockNumber);
    }

    /**
     * @dev Verify that the supplied MMR leaf is included in the latest verified MMR root.
     * @param leafHash contains the merkle leaf to be verified
     * @param proof contains simplified mmr proof
     * @param proofOrder a bitfield describing the order of each item (left vs right)
     */
    function verifyMMRLeafProof(bytes32 leafHash, bytes32[] calldata proof, uint256 proofOrder)
        external
        view
        returns (bool)
    {
        return MMRProof.verifyLeafProof(latestMMRRoot, leafHash, proof, proofOrder);
    }

    /**
     * @dev Helper to create an initial validator bitfield.
     * @param bitsToSet contains indexes of all signed validators, should be deduplicated
     * @param length of validator set
     */
    function createInitialBitfield(uint256[] calldata bitsToSet, uint256 length)
        external
        pure
        returns (uint256[] memory)
    {
        if (length < bitsToSet.length) {
            revert InvalidBitfieldLength();
        }
        return Bitfield.createBitfield(bitsToSet, length);
    }

    /**
     * @dev Helper to create a final bitfield, with subsampled validator selections
     * @param commitmentHash contains the commitmentHash signed by the validators
     * @param bitfield claiming which validators have signed the commitment
     */
    function createFinalBitfield(bytes32 commitmentHash, uint256[] calldata bitfield)
        external
        view
        returns (uint256[] memory)
    {
        Ticket storage ticket = tickets[createTicketID(msg.sender, commitmentHash)];
        if (ticket.bitfieldHash != keccak256(abi.encodePacked(bitfield))) {
            revert InvalidBitfield();
        }
        return Bitfield.subsample(ticket.prevRandao, bitfield, ticket.numRequiredSignatures, ticket.validatorSetLen);
    }

    /* Internal Functions */

    // Creates a unique ticket ID for a new interactive prover-verifier session
    function createTicketID(address account, bytes32 commitmentHash) internal pure returns (bytes32 value) {
        assembly {
            mstore(0x00, account)
            mstore(0x20, commitmentHash)
            value := keccak256(0x0, 0x40)
        }
    }

    /**
     * @dev Calculates the number of required signatures for `submitFinal`.
     * @param validatorSetLen The length of the validator set
     * @param signatureUsageCount A counter of the number of times the validator signature was previously used in a call to `submitInitial` within the session.
     * @param minRequiredSignatures The minimum amount of signatures to verify
     */
    // For more details on the calculation, read the following:
    // 1. https://docs.snowbridge.network/architecture/verification/polkadot#signature-sampling
    // 2. https://hackmd.io/9OedC7icR5m-in_moUZ_WQ
    function computeNumRequiredSignatures(
        uint256 validatorSetLen,
        uint256 signatureUsageCount,
        uint256 minRequiredSignatures
    ) internal pure returns (uint256) {
        // Start with the minimum number of signatures.
        uint256 numRequiredSignatures = minRequiredSignatures;
        // Add signatures based on the number of validators in the validator set.
        numRequiredSignatures += Math.log2(validatorSetLen, Math.Rounding.Ceil);
        // Add signatures based on the signature usage count.
        numRequiredSignatures += 1 + (2 * Math.log2(signatureUsageCount, Math.Rounding.Ceil));
        // Never require more signatures than a 2/3 majority
        return Math.min(numRequiredSignatures, computeQuorum(validatorSetLen));
    }

    /**
     * @dev Calculates 2/3 majority required for quorum for a given number of validators.
     * @param numValidators The number of validators in the validator set.
     */
    function computeQuorum(uint256 numValidators) internal pure returns (uint256) {
        return numValidators - (numValidators - 1) / 3;
    }

    /**
     * @dev Verify commitment using the supplied signature proofs
     */
    function verifyCommitment(
        bytes32 commitmentHash,
        bytes32 ticketID,
        uint256[] calldata bitfield,
        ValidatorSetState storage vset,
        ValidatorProof[] calldata proofs
    ) internal view {
        Ticket storage ticket = tickets[ticketID];
        // Verify that enough signature proofs have been supplied
        uint256 numRequiredSignatures = ticket.numRequiredSignatures;
        if (proofs.length != numRequiredSignatures) {
            revert InvalidValidatorProofLength();
        }

        // Generate final bitfield indicating which validators need to be included in the proofs.
        uint256[] memory finalbitfield =
            Bitfield.subsample(ticket.prevRandao, bitfield, numRequiredSignatures, vset.length);

        for (uint256 i = 0; i < proofs.length; i++) {
            ValidatorProof calldata proof = proofs[i];

            // Check that validator is in bitfield
            if (!Bitfield.isSet(finalbitfield, proof.index)) {
                revert InvalidValidatorProof();
            }

            // Check that validator is actually in a validator set
            if (!isValidatorInSet(vset, proof.account, proof.index, proof.proof)) {
                revert InvalidValidatorProof();
            }

            // Check that validator signed the commitment
            if (ECDSA.recover(commitmentHash, proof.v, proof.r, proof.s) != proof.account) {
                revert InvalidSignature();
            }

            // Ensure no validator can appear more than once in bitfield
            Bitfield.unset(finalbitfield, proof.index);
        }
    }

    // Ensure that the commitment provides a new MMR root
    function ensureProvidesMMRRoot(Commitment calldata commitment) internal pure returns (bytes32) {
        for (uint256 i = 0; i < commitment.payload.length; i++) {
            if (commitment.payload[i].payloadID == MMR_ROOT_ID) {
                if (commitment.payload[i].data.length != 32) {
                    revert InvalidMMRRootLength();
                } else {
                    return bytes32(commitment.payload[i].data);
                }
            }
        }
        revert CommitmentNotRelevant();
    }

    function encodeCommitment(Commitment calldata commitment) internal pure returns (bytes memory) {
        return bytes.concat(
            encodeCommitmentPayload(commitment.payload),
            ScaleCodec.encodeU32(commitment.blockNumber),
            ScaleCodec.encodeU64(commitment.validatorSetID)
        );
    }

    function encodeCommitmentPayload(PayloadItem[] calldata items) internal pure returns (bytes memory) {
        bytes memory payload = ScaleCodec.checkedEncodeCompactU32(items.length);
        for (uint256 i = 0; i < items.length; i++) {
            payload = bytes.concat(
                payload, items[i].payloadID, ScaleCodec.checkedEncodeCompactU32(items[i].data.length), items[i].data
            );
        }

        return payload;
    }

    function encodeMMRLeaf(MMRLeaf calldata leaf) internal pure returns (bytes memory) {
        return bytes.concat(
            ScaleCodec.encodeU8(leaf.version),
            ScaleCodec.encodeU32(leaf.parentNumber),
            leaf.parentHash,
            ScaleCodec.encodeU64(leaf.nextAuthoritySetID),
            ScaleCodec.encodeU32(leaf.nextAuthoritySetLen),
            leaf.nextAuthoritySetRoot,
            leaf.parachainHeadsRoot,
            leaf.messageCommitment
        );
    }

    /**
     * @dev Checks if a validators address is a member of the merkle tree
     * @param vset The validator set
     * @param account The address of the validator to check for inclusion in `vset`.
     * @param index The leaf index of the account in the merkle tree of validator set addresses.
     * @param proof Merkle proof required for validation of the address
     * @return true if the validator is in the set
     */
    function isValidatorInSet(ValidatorSetState storage vset, address account, uint256 index, bytes32[] calldata proof)
        internal
        view
        returns (bool)
    {
        bytes32 hashedLeaf = keccak256(abi.encodePacked(account));
        return SubstrateMerkleProof.verify(vset.root, hashedLeaf, index, vset.length, proof);
    }

    /**
     * @dev Basic validation of a ticket for submitFinal
     */
    function validateTicket(bytes32 ticketID, Commitment calldata commitment, uint256[] calldata bitfield)
        internal
        view
    {
        Ticket storage ticket = tickets[ticketID];

        if (ticket.blockNumber == 0) {
            // submitInitial hasn't been called yet
            revert InvalidTicket();
        }

        if (ticket.prevRandao == 0) {
            // commitPrevRandao hasn't been called yet
            revert PrevRandaoNotCaptured();
        }

        if (commitment.blockNumber <= latestBeefyBlock) {
            // ticket is obsolete
            revert StaleCommitment();
        }

        if (ticket.bitfieldHash != keccak256(abi.encodePacked(bitfield))) {
            // The provided claims bitfield isn't the same one that was
            // passed to submitInitial
            revert InvalidBitfield();
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

library ScaleCodec {
    error UnsupportedCompactEncoding();

    uint256 internal constant MAX_COMPACT_ENCODABLE_UINT = 2 ** 30 - 1;

    // Sources:
    //   * https://ethereum.stackexchange.com/questions/15350/how-to-convert-an-bytes-to-address-in-solidity/50528
    //   * https://graphics.stanford.edu/~seander/bithacks.html#ReverseParallel

    function reverse256(uint256 input) internal pure returns (uint256 v) {
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

    function reverse128(uint128 input) internal pure returns (uint128 v) {
        v = input;

        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00FF00FF00FF00FF00) >> 8) | ((v & 0x00FF00FF00FF00FF00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000FFFF0000FFFF0000) >> 16) | ((v & 0x0000FFFF0000FFFF0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = ((v & 0xFFFFFFFF00000000FFFFFFFF00000000) >> 32) | ((v & 0x00000000FFFFFFFF00000000FFFFFFFF) << 32);

        // swap 8-byte long pairs
        v = (v >> 64) | (v << 64);
    }

    function reverse64(uint64 input) internal pure returns (uint64 v) {
        v = input;

        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00) >> 8) | ((v & 0x00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000) >> 16) | ((v & 0x0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);
    }

    function reverse32(uint32 input) internal pure returns (uint32 v) {
        v = input;

        // swap bytes
        v = ((v & 0xFF00FF00) >> 8) | ((v & 0x00FF00FF) << 8);

        // swap 2-byte long pairs
        v = (v >> 16) | (v << 16);
    }

    function reverse16(uint16 input) internal pure returns (uint16 v) {
        v = input;

        // swap bytes
        v = (v >> 8) | (v << 8);
    }

    function encodeU256(uint256 input) internal pure returns (bytes32) {
        return bytes32(reverse256(input));
    }

    function encodeU128(uint128 input) internal pure returns (bytes16) {
        return bytes16(reverse128(input));
    }

    function encodeU64(uint64 input) internal pure returns (bytes8) {
        return bytes8(reverse64(input));
    }

    function encodeU32(uint32 input) internal pure returns (bytes4) {
        return bytes4(reverse32(input));
    }

    function encodeU16(uint16 input) internal pure returns (bytes2) {
        return bytes2(reverse16(input));
    }

    function encodeU8(uint8 input) internal pure returns (bytes1) {
        return bytes1(input);
    }

    // Supports compact encoding of integers in [0, uint32.MAX]
    function encodeCompactU32(uint32 value) internal pure returns (bytes memory) {
        if (value <= 2 ** 6 - 1) {
            // add single byte flag
            return abi.encodePacked(uint8(value << 2));
        } else if (value <= 2 ** 14 - 1) {
            // add two byte flag and create little endian encoding
            return abi.encodePacked(ScaleCodec.reverse16(uint16(((value << 2) + 1))));
        } else if (value <= 2 ** 30 - 1) {
            // add four byte flag and create little endian encoding
            return abi.encodePacked(ScaleCodec.reverse32(uint32((value << 2)) + 2));
        } else {
            return abi.encodePacked(uint8(3), ScaleCodec.reverse32(value));
        }
    }

    function checkedEncodeCompactU32(uint256 value) internal pure returns (bytes memory) {
        if (value > type(uint32).max) {
            revert UnsupportedCompactEncoding();
        }
        return encodeCompactU32(uint32(value));
    }
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

import {ScaleCodec} from "./utils/ScaleCodec.sol";
import {ParaID} from "./Types.sol";

/**
 * @title SCALE encoders for common Substrate types
 */
library SubstrateTypes {
    error UnsupportedCompactEncoding();

    /**
     * @dev Encodes `MultiAddress::Id`: https://crates.parity.io/sp_runtime/enum.MultiAddress.html#variant.Id
     * @return bytes SCALE-encoded bytes
     */
    // solhint-disable-next-line func-name-mixedcase
    function MultiAddressWithID(bytes32 account) internal pure returns (bytes memory) {
        return bytes.concat(hex"00", account);
    }

    /**
     * @dev Encodes `H160`: https://crates.parity.io/sp_core/struct.H160.html
     * @return bytes SCALE-encoded bytes
     */
    // solhint-disable-next-line func-name-mixedcase
    function H160(address account) internal pure returns (bytes memory) {
        return abi.encodePacked(account);
    }

    function VecU8(bytes memory input) internal pure returns (bytes memory) {
        return bytes.concat(ScaleCodec.checkedEncodeCompactU32(input.length), input);
    }

    /**
     * @dev Encodes `Option::None`: https://doc.rust-lang.org/std/option/enum.Option.html#variant.None
     * @return bytes SCALE-encoded bytes
     */
    // solhint-disable-next-line func-name-mixedcase
    function None() internal pure returns (bytes memory) {
        return hex"00";
    }

    // solhint-disable-next-line func-name-mixedcase
    function OptionParaID(ParaID v) internal pure returns (bytes memory) {
        if (ParaID.unwrap(v) == 0) {
            return hex"00";
        } else {
            return bytes.concat(bytes1(0x01), ScaleCodec.encodeU32(uint32(ParaID.unwrap(v))));
        }
    }

    /**
     * @dev SCALE-encodes `router_primitives::inbound::VersionedMessage` containing payload
     * `NativeTokensMessage::Create`
     */
    // solhint-disable-next-line func-name-mixedcase
    function RegisterToken(address token, uint128 fee) internal view returns (bytes memory) {
        return bytes.concat(
            bytes1(0x00),
            ScaleCodec.encodeU64(uint64(block.chainid)),
            bytes1(0x00),
            SubstrateTypes.H160(token),
            ScaleCodec.encodeU128(fee)
        );
    }

    /**
     * @dev SCALE-encodes `router_primitives::inbound::VersionedMessage` containing payload
     * `NativeTokensMessage::Mint`
     */
    // destination is AccountID32 address on AssetHub
    function SendTokenToAssetHubAddress32(address token, bytes32 recipient, uint128 xcmFee, uint128 amount)
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            bytes1(0x00),
            ScaleCodec.encodeU64(uint64(block.chainid)),
            bytes1(0x01),
            SubstrateTypes.H160(token),
            bytes1(0x00),
            recipient,
            ScaleCodec.encodeU128(amount),
            ScaleCodec.encodeU128(xcmFee)
        );
    }

    // destination is AccountID32 address
    function SendTokenToAddress32(
        address token,
        ParaID paraID,
        bytes32 recipient,
        uint128 xcmFee,
        uint128 destinationXcmFee,
        uint128 amount
    ) internal view returns (bytes memory) {
        return bytes.concat(
            bytes1(0x00),
            ScaleCodec.encodeU64(uint64(block.chainid)),
            bytes1(0x01),
            SubstrateTypes.H160(token),
            bytes1(0x01),
            ScaleCodec.encodeU32(uint32(ParaID.unwrap(paraID))),
            recipient,
            ScaleCodec.encodeU128(destinationXcmFee),
            ScaleCodec.encodeU128(amount),
            ScaleCodec.encodeU128(xcmFee)
        );
    }

    // destination is AccountID20 address
    function SendTokenToAddress20(
        address token,
        ParaID paraID,
        bytes20 recipient,
        uint128 xcmFee,
        uint128 destinationXcmFee,
        uint128 amount
    ) internal view returns (bytes memory) {
        return bytes.concat(
            bytes1(0x00),
            ScaleCodec.encodeU64(uint64(block.chainid)),
            bytes1(0x01),
            SubstrateTypes.H160(token),
            bytes1(0x02),
            ScaleCodec.encodeU32(uint32(ParaID.unwrap(paraID))),
            recipient,
            ScaleCodec.encodeU128(destinationXcmFee),
            ScaleCodec.encodeU128(amount),
            ScaleCodec.encodeU128(xcmFee)
        );
    }

    function SendForeignTokenToAssetHubAddress32(bytes32 tokenID, bytes32 recipient, uint128 xcmFee, uint128 amount)
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            bytes1(0x00),
            ScaleCodec.encodeU64(uint64(block.chainid)),
            bytes1(0x02),
            tokenID,
            bytes1(0x00),
            recipient,
            ScaleCodec.encodeU128(amount),
            ScaleCodec.encodeU128(xcmFee)
        );
    }

    // destination is AccountID32 address
    function SendForeignTokenToAddress32(
        bytes32 tokenID,
        ParaID paraID,
        bytes32 recipient,
        uint128 xcmFee,
        uint128 destinationXcmFee,
        uint128 amount
    ) internal view returns (bytes memory) {
        return bytes.concat(
            bytes1(0x00),
            ScaleCodec.encodeU64(uint64(block.chainid)),
            bytes1(0x02),
            tokenID,
            bytes1(0x01),
            ScaleCodec.encodeU32(uint32(ParaID.unwrap(paraID))),
            recipient,
            ScaleCodec.encodeU128(destinationXcmFee),
            ScaleCodec.encodeU128(amount),
            ScaleCodec.encodeU128(xcmFee)
        );
    }

    // destination is AccountID20 address
    function SendForeignTokenToAddress20(
        bytes32 tokenID,
        ParaID paraID,
        bytes20 recipient,
        uint128 xcmFee,
        uint128 destinationXcmFee,
        uint128 amount
    ) internal view returns (bytes memory) {
        return bytes.concat(
            bytes1(0x00),
            ScaleCodec.encodeU64(uint64(block.chainid)),
            bytes1(0x02),
            tokenID,
            bytes1(0x02),
            ScaleCodec.encodeU32(uint32(ParaID.unwrap(paraID))),
            recipient,
            ScaleCodec.encodeU128(destinationXcmFee),
            ScaleCodec.encodeU128(amount),
            ScaleCodec.encodeU128(xcmFee)
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// Common.sol
//
// Common mathematical functions used in both SD59x18 and UD60x18. Note that these global functions do not
// always operate with SD59x18 and UD60x18 numbers.

/*//////////////////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Thrown when the resultant value in {mulDiv} overflows uint256.
error PRBMath_MulDiv_Overflow(uint256 x, uint256 y, uint256 denominator);

/// @notice Thrown when the resultant value in {mulDiv18} overflows uint256.
error PRBMath_MulDiv18_Overflow(uint256 x, uint256 y);

/// @notice Thrown when one of the inputs passed to {mulDivSigned} is `type(int256).min`.
error PRBMath_MulDivSigned_InputTooSmall();

/// @notice Thrown when the resultant value in {mulDivSigned} overflows int256.
error PRBMath_MulDivSigned_Overflow(int256 x, int256 y);

/*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
//////////////////////////////////////////////////////////////////////////*/

/// @dev The maximum value a uint128 number can have.
uint128 constant MAX_UINT128 = type(uint128).max;

/// @dev The maximum value a uint40 number can have.
uint40 constant MAX_UINT40 = type(uint40).max;

/// @dev The unit number, which the decimal precision of the fixed-point types.
uint256 constant UNIT = 1e18;

/// @dev The unit number inverted mod 2^256.
uint256 constant UNIT_INVERSE = 78156646155174841979727994598816262306175212592076161876661_508869554232690281;

/// @dev The the largest power of two that divides the decimal value of `UNIT`. The logarithm of this value is the least significant
/// bit in the binary representation of `UNIT`.
uint256 constant UNIT_LPOTD = 262144;

/*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

/// @notice Calculates the binary exponent of x using the binary fraction method.
/// @dev Has to use 192.64-bit fixed-point numbers. See https://ethereum.stackexchange.com/a/96594/24693.
/// @param x The exponent as an unsigned 192.64-bit fixed-point number.
/// @return result The result as an unsigned 60.18-decimal fixed-point number.
/// @custom:smtchecker abstract-function-nondet
function exp2(uint256 x) pure returns (uint256 result) {
    unchecked {
        // Start from 0.5 in the 192.64-bit fixed-point format.
        result = 0x800000000000000000000000000000000000000000000000;

        // The following logic multiplies the result by $\sqrt{2^{-i}}$ when the bit at position i is 1. Key points:
        //
        // 1. Intermediate results will not overflow, as the starting point is 2^191 and all magic factors are under 2^65.
        // 2. The rationale for organizing the if statements into groups of 8 is gas savings. If the result of performing
        // a bitwise AND operation between x and any value in the array [0x80; 0x40; 0x20; 0x10; 0x08; 0x04; 0x02; 0x01] is 1,
        // we know that `x & 0xFF` is also 1.
        if (x & 0xFF00000000000000 > 0) {
            if (x & 0x8000000000000000 > 0) {
                result = (result * 0x16A09E667F3BCC909) >> 64;
            }
            if (x & 0x4000000000000000 > 0) {
                result = (result * 0x1306FE0A31B7152DF) >> 64;
            }
            if (x & 0x2000000000000000 > 0) {
                result = (result * 0x1172B83C7D517ADCE) >> 64;
            }
            if (x & 0x1000000000000000 > 0) {
                result = (result * 0x10B5586CF9890F62A) >> 64;
            }
            if (x & 0x800000000000000 > 0) {
                result = (result * 0x1059B0D31585743AE) >> 64;
            }
            if (x & 0x400000000000000 > 0) {
                result = (result * 0x102C9A3E778060EE7) >> 64;
            }
            if (x & 0x200000000000000 > 0) {
                result = (result * 0x10163DA9FB33356D8) >> 64;
            }
            if (x & 0x100000000000000 > 0) {
                result = (result * 0x100B1AFA5ABCBED61) >> 64;
            }
        }

        if (x & 0xFF000000000000 > 0) {
            if (x & 0x80000000000000 > 0) {
                result = (result * 0x10058C86DA1C09EA2) >> 64;
            }
            if (x & 0x40000000000000 > 0) {
                result = (result * 0x1002C605E2E8CEC50) >> 64;
            }
            if (x & 0x20000000000000 > 0) {
                result = (result * 0x100162F3904051FA1) >> 64;
            }
            if (x & 0x10000000000000 > 0) {
                result = (result * 0x1000B175EFFDC76BA) >> 64;
            }
            if (x & 0x8000000000000 > 0) {
                result = (result * 0x100058BA01FB9F96D) >> 64;
            }
            if (x & 0x4000000000000 > 0) {
                result = (result * 0x10002C5CC37DA9492) >> 64;
            }
            if (x & 0x2000000000000 > 0) {
                result = (result * 0x1000162E525EE0547) >> 64;
            }
            if (x & 0x1000000000000 > 0) {
                result = (result * 0x10000B17255775C04) >> 64;
            }
        }

        if (x & 0xFF0000000000 > 0) {
            if (x & 0x800000000000 > 0) {
                result = (result * 0x1000058B91B5BC9AE) >> 64;
            }
            if (x & 0x400000000000 > 0) {
                result = (result * 0x100002C5C89D5EC6D) >> 64;
            }
            if (x & 0x200000000000 > 0) {
                result = (result * 0x10000162E43F4F831) >> 64;
            }
            if (x & 0x100000000000 > 0) {
                result = (result * 0x100000B1721BCFC9A) >> 64;
            }
            if (x & 0x80000000000 > 0) {
                result = (result * 0x10000058B90CF1E6E) >> 64;
            }
            if (x & 0x40000000000 > 0) {
                result = (result * 0x1000002C5C863B73F) >> 64;
            }
            if (x & 0x20000000000 > 0) {
                result = (result * 0x100000162E430E5A2) >> 64;
            }
            if (x & 0x10000000000 > 0) {
                result = (result * 0x1000000B172183551) >> 64;
            }
        }

        if (x & 0xFF00000000 > 0) {
            if (x & 0x8000000000 > 0) {
                result = (result * 0x100000058B90C0B49) >> 64;
            }
            if (x & 0x4000000000 > 0) {
                result = (result * 0x10000002C5C8601CC) >> 64;
            }
            if (x & 0x2000000000 > 0) {
                result = (result * 0x1000000162E42FFF0) >> 64;
            }
            if (x & 0x1000000000 > 0) {
                result = (result * 0x10000000B17217FBB) >> 64;
            }
            if (x & 0x800000000 > 0) {
                result = (result * 0x1000000058B90BFCE) >> 64;
            }
            if (x & 0x400000000 > 0) {
                result = (result * 0x100000002C5C85FE3) >> 64;
            }
            if (x & 0x200000000 > 0) {
                result = (result * 0x10000000162E42FF1) >> 64;
            }
            if (x & 0x100000000 > 0) {
                result = (result * 0x100000000B17217F8) >> 64;
            }
        }

        if (x & 0xFF000000 > 0) {
            if (x & 0x80000000 > 0) {
                result = (result * 0x10000000058B90BFC) >> 64;
            }
            if (x & 0x40000000 > 0) {
                result = (result * 0x1000000002C5C85FE) >> 64;
            }
            if (x & 0x20000000 > 0) {
                result = (result * 0x100000000162E42FF) >> 64;
            }
            if (x & 0x10000000 > 0) {
                result = (result * 0x1000000000B17217F) >> 64;
            }
            if (x & 0x8000000 > 0) {
                result = (result * 0x100000000058B90C0) >> 64;
            }
            if (x & 0x4000000 > 0) {
                result = (result * 0x10000000002C5C860) >> 64;
            }
            if (x & 0x2000000 > 0) {
                result = (result * 0x1000000000162E430) >> 64;
            }
            if (x & 0x1000000 > 0) {
                result = (result * 0x10000000000B17218) >> 64;
            }
        }

        if (x & 0xFF0000 > 0) {
            if (x & 0x800000 > 0) {
                result = (result * 0x1000000000058B90C) >> 64;
            }
            if (x & 0x400000 > 0) {
                result = (result * 0x100000000002C5C86) >> 64;
            }
            if (x & 0x200000 > 0) {
                result = (result * 0x10000000000162E43) >> 64;
            }
            if (x & 0x100000 > 0) {
                result = (result * 0x100000000000B1721) >> 64;
            }
            if (x & 0x80000 > 0) {
                result = (result * 0x10000000000058B91) >> 64;
            }
            if (x & 0x40000 > 0) {
                result = (result * 0x1000000000002C5C8) >> 64;
            }
            if (x & 0x20000 > 0) {
                result = (result * 0x100000000000162E4) >> 64;
            }
            if (x & 0x10000 > 0) {
                result = (result * 0x1000000000000B172) >> 64;
            }
        }

        if (x & 0xFF00 > 0) {
            if (x & 0x8000 > 0) {
                result = (result * 0x100000000000058B9) >> 64;
            }
            if (x & 0x4000 > 0) {
                result = (result * 0x10000000000002C5D) >> 64;
            }
            if (x & 0x2000 > 0) {
                result = (result * 0x1000000000000162E) >> 64;
            }
            if (x & 0x1000 > 0) {
                result = (result * 0x10000000000000B17) >> 64;
            }
            if (x & 0x800 > 0) {
                result = (result * 0x1000000000000058C) >> 64;
            }
            if (x & 0x400 > 0) {
                result = (result * 0x100000000000002C6) >> 64;
            }
            if (x & 0x200 > 0) {
                result = (result * 0x10000000000000163) >> 64;
            }
            if (x & 0x100 > 0) {
                result = (result * 0x100000000000000B1) >> 64;
            }
        }

        if (x & 0xFF > 0) {
            if (x & 0x80 > 0) {
                result = (result * 0x10000000000000059) >> 64;
            }
            if (x & 0x40 > 0) {
                result = (result * 0x1000000000000002C) >> 64;
            }
            if (x & 0x20 > 0) {
                result = (result * 0x10000000000000016) >> 64;
            }
            if (x & 0x10 > 0) {
                result = (result * 0x1000000000000000B) >> 64;
            }
            if (x & 0x8 > 0) {
                result = (result * 0x10000000000000006) >> 64;
            }
            if (x & 0x4 > 0) {
                result = (result * 0x10000000000000003) >> 64;
            }
            if (x & 0x2 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
            if (x & 0x1 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
        }

        // In the code snippet below, two operations are executed simultaneously:
        //
        // 1. The result is multiplied by $(2^n + 1)$, where $2^n$ represents the integer part, and the additional 1
        // accounts for the initial guess of 0.5. This is achieved by subtracting from 191 instead of 192.
        // 2. The result is then converted to an unsigned 60.18-decimal fixed-point format.
        //
        // The underlying logic is based on the relationship $2^{191-ip} = 2^{ip} / 2^{191}$, where $ip$ denotes the,
        // integer part, $2^n$.
        result *= UNIT;
        result >>= (191 - (x >> 64));
    }
}

/// @notice Finds the zero-based index of the first 1 in the binary representation of x.
///
/// @dev See the note on "msb" in this Wikipedia article: https://en.wikipedia.org/wiki/Find_first_set
///
/// Each step in this implementation is equivalent to this high-level code:
///
/// ```solidity
/// if (x >= 2 ** 128) {
///     x >>= 128;
///     result += 128;
/// }
/// ```
///
/// Where 128 is replaced with each respective power of two factor. See the full high-level implementation here:
/// https://gist.github.com/PaulRBerg/f932f8693f2733e30c4d479e8e980948
///
/// The Yul instructions used below are:
///
/// - "gt" is "greater than"
/// - "or" is the OR bitwise operator
/// - "shl" is "shift left"
/// - "shr" is "shift right"
///
/// @param x The uint256 number for which to find the index of the most significant bit.
/// @return result The index of the most significant bit as a uint256.
/// @custom:smtchecker abstract-function-nondet
function msb(uint256 x) pure returns (uint256 result) {
    // 2^128
    assembly ("memory-safe") {
        let factor := shl(7, gt(x, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^64
    assembly ("memory-safe") {
        let factor := shl(6, gt(x, 0xFFFFFFFFFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^32
    assembly ("memory-safe") {
        let factor := shl(5, gt(x, 0xFFFFFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^16
    assembly ("memory-safe") {
        let factor := shl(4, gt(x, 0xFFFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^8
    assembly ("memory-safe") {
        let factor := shl(3, gt(x, 0xFF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^4
    assembly ("memory-safe") {
        let factor := shl(2, gt(x, 0xF))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^2
    assembly ("memory-safe") {
        let factor := shl(1, gt(x, 0x3))
        x := shr(factor, x)
        result := or(result, factor)
    }
    // 2^1
    // No need to shift x any more.
    assembly ("memory-safe") {
        let factor := gt(x, 0x1)
        result := or(result, factor)
    }
}

/// @notice Calculates x*y÷denominator with 512-bit precision.
///
/// @dev Credits to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - The denominator must not be zero.
/// - The result must fit in uint256.
///
/// @param x The multiplicand as a uint256.
/// @param y The multiplier as a uint256.
/// @param denominator The divisor as a uint256.
/// @return result The result as a uint256.
/// @custom:smtchecker abstract-function-nondet
function mulDiv(uint256 x, uint256 y, uint256 denominator) pure returns (uint256 result) {
    // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
    // use the Chinese Remainder Theorem to reconstruct the 512-bit result. The result is stored in two 256
    // variables such that product = prod1 * 2^256 + prod0.
    uint256 prod0; // Least significant 256 bits of the product
    uint256 prod1; // Most significant 256 bits of the product
    assembly ("memory-safe") {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    // Handle non-overflow cases, 256 by 256 division.
    if (prod1 == 0) {
        unchecked {
            return prod0 / denominator;
        }
    }

    // Make sure the result is less than 2^256. Also prevents denominator == 0.
    if (prod1 >= denominator) {
        revert PRBMath_MulDiv_Overflow(x, y, denominator);
    }

    ////////////////////////////////////////////////////////////////////////////
    // 512 by 256 division
    ////////////////////////////////////////////////////////////////////////////

    // Make division exact by subtracting the remainder from [prod1 prod0].
    uint256 remainder;
    assembly ("memory-safe") {
        // Compute remainder using the mulmod Yul instruction.
        remainder := mulmod(x, y, denominator)

        // Subtract 256 bit number from 512-bit number.
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
    }

    unchecked {
        // Calculate the largest power of two divisor of the denominator using the unary operator ~. This operation cannot overflow
        // because the denominator cannot be zero at this point in the function execution. The result is always >= 1.
        // For more detail, see https://cs.stackexchange.com/q/138556/92363.
        uint256 lpotdod = denominator & (~denominator + 1);
        uint256 flippedLpotdod;

        assembly ("memory-safe") {
            // Factor powers of two out of denominator.
            denominator := div(denominator, lpotdod)

            // Divide [prod1 prod0] by lpotdod.
            prod0 := div(prod0, lpotdod)

            // Get the flipped value `2^256 / lpotdod`. If the `lpotdod` is zero, the flipped value is one.
            // `sub(0, lpotdod)` produces the two's complement version of `lpotdod`, which is equivalent to flipping all the bits.
            // However, `div` interprets this value as an unsigned value: https://ethereum.stackexchange.com/q/147168/24693
            flippedLpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
        }

        // Shift in bits from prod1 into prod0.
        prod0 |= prod1 * flippedLpotdod;

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
    }
}

/// @notice Calculates x*y÷1e18 with 512-bit precision.
///
/// @dev A variant of {mulDiv} with constant folding, i.e. in which the denominator is hard coded to 1e18.
///
/// Notes:
/// - The body is purposely left uncommented; to understand how this works, see the documentation in {mulDiv}.
/// - The result is rounded toward zero.
/// - We take as an axiom that the result cannot be `MAX_UINT256` when x and y solve the following system of equations:
///
/// $$
/// \begin{cases}
///     x * y = MAX\_UINT256 * UNIT \\
///     (x * y) \% UNIT \geq \frac{UNIT}{2}
/// \end{cases}
/// $$
///
/// Requirements:
/// - Refer to the requirements in {mulDiv}.
/// - The result must fit in uint256.
///
/// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
/// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
/// @return result The result as an unsigned 60.18-decimal fixed-point number.
/// @custom:smtchecker abstract-function-nondet
function mulDiv18(uint256 x, uint256 y) pure returns (uint256 result) {
    uint256 prod0;
    uint256 prod1;
    assembly ("memory-safe") {
        let mm := mulmod(x, y, not(0))
        prod0 := mul(x, y)
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }

    if (prod1 == 0) {
        unchecked {
            return prod0 / UNIT;
        }
    }

    if (prod1 >= UNIT) {
        revert PRBMath_MulDiv18_Overflow(x, y);
    }

    uint256 remainder;
    assembly ("memory-safe") {
        remainder := mulmod(x, y, UNIT)
        result :=
            mul(
                or(
                    div(sub(prod0, remainder), UNIT_LPOTD),
                    mul(sub(prod1, gt(remainder, prod0)), add(div(sub(0, UNIT_LPOTD), UNIT_LPOTD), 1))
                ),
                UNIT_INVERSE
            )
    }
}

/// @notice Calculates x*y÷denominator with 512-bit precision.
///
/// @dev This is an extension of {mulDiv} for signed numbers, which works by computing the signs and the absolute values separately.
///
/// Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - Refer to the requirements in {mulDiv}.
/// - None of the inputs can be `type(int256).min`.
/// - The result must fit in int256.
///
/// @param x The multiplicand as an int256.
/// @param y The multiplier as an int256.
/// @param denominator The divisor as an int256.
/// @return result The result as an int256.
/// @custom:smtchecker abstract-function-nondet
function mulDivSigned(int256 x, int256 y, int256 denominator) pure returns (int256 result) {
    if (x == type(int256).min || y == type(int256).min || denominator == type(int256).min) {
        revert PRBMath_MulDivSigned_InputTooSmall();
    }

    // Get hold of the absolute values of x, y and the denominator.
    uint256 xAbs;
    uint256 yAbs;
    uint256 dAbs;
    unchecked {
        xAbs = x < 0 ? uint256(-x) : uint256(x);
        yAbs = y < 0 ? uint256(-y) : uint256(y);
        dAbs = denominator < 0 ? uint256(-denominator) : uint256(denominator);
    }

    // Compute the absolute value of x*y÷denominator. The result must fit in int256.
    uint256 resultAbs = mulDiv(xAbs, yAbs, dAbs);
    if (resultAbs > uint256(type(int256).max)) {
        revert PRBMath_MulDivSigned_Overflow(x, y);
    }

    // Get the signs of x, y and the denominator.
    uint256 sx;
    uint256 sy;
    uint256 sd;
    assembly ("memory-safe") {
        // "sgt" is the "signed greater than" assembly instruction and "sub(0,1)" is -1 in two's complement.
        sx := sgt(x, sub(0, 1))
        sy := sgt(y, sub(0, 1))
        sd := sgt(denominator, sub(0, 1))
    }

    // XOR over sx, sy and sd. What this does is to check whether there are 1 or 3 negative signs in the inputs.
    // If there are, the result should be negative. Otherwise, it should be positive.
    unchecked {
        result = sx ^ sy ^ sd == 0 ? -int256(resultAbs) : int256(resultAbs);
    }
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - If x is not a perfect square, the result is rounded down.
/// - Credits to OpenZeppelin for the explanations in comments below.
///
/// @param x The uint256 number for which to calculate the square root.
/// @return result The result as a uint256.
/// @custom:smtchecker abstract-function-nondet
function sqrt(uint256 x) pure returns (uint256 result) {
    if (x == 0) {
        return 0;
    }

    // For our first guess, we calculate the biggest power of 2 which is smaller than the square root of x.
    //
    // We know that the "msb" (most significant bit) of x is a power of 2 such that we have:
    //
    // $$
    // msb(x) <= x <= 2*msb(x)$
    // $$
    //
    // We write $msb(x)$ as $2^k$, and we get:
    //
    // $$
    // k = log_2(x)
    // $$
    //
    // Thus, we can write the initial inequality as:
    //
    // $$
    // 2^{log_2(x)} <= x <= 2*2^{log_2(x)+1} \\
    // sqrt(2^k) <= sqrt(x) < sqrt(2^{k+1}) \\
    // 2^{k/2} <= sqrt(x) < 2^{(k+1)/2} <= 2^{(k/2)+1}
    // $$
    //
    // Consequently, $2^{log_2(x) /2} is a good first approximation of sqrt(x) with at least one correct bit.
    uint256 xAux = uint256(x);
    result = 1;
    if (xAux >= 2 ** 128) {
        xAux >>= 128;
        result <<= 64;
    }
    if (xAux >= 2 ** 64) {
        xAux >>= 64;
        result <<= 32;
    }
    if (xAux >= 2 ** 32) {
        xAux >>= 32;
        result <<= 16;
    }
    if (xAux >= 2 ** 16) {
        xAux >>= 16;
        result <<= 8;
    }
    if (xAux >= 2 ** 8) {
        xAux >>= 8;
        result <<= 4;
    }
    if (xAux >= 2 ** 4) {
        xAux >>= 4;
        result <<= 2;
    }
    if (xAux >= 2 ** 2) {
        result <<= 1;
    }

    // At this point, `result` is an estimation with at least one bit of precision. We know the true value has at
    // most 128 bits, since it is the square root of a uint256. Newton's method converges quadratically (precision
    // doubles at every iteration). We thus need at most 7 iteration to turn our partial result with one bit of
    // precision into the expected uint128 result.
    unchecked {
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;
        result = (result + x / result) >> 1;

        // If x is not a perfect square, round the result toward zero.
        uint256 roundedResult = x / result;
        if (result >= roundedResult) {
            result = roundedResult;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { SD1x18 } from "./ValueType.sol";

/// @dev Euler's number as an SD1x18 number.
SD1x18 constant E = SD1x18.wrap(2_718281828459045235);

/// @dev The maximum value an SD1x18 number can have.
int64 constant uMAX_SD1x18 = 9_223372036854775807;
SD1x18 constant MAX_SD1x18 = SD1x18.wrap(uMAX_SD1x18);

/// @dev The maximum value an SD1x18 number can have.
int64 constant uMIN_SD1x18 = -9_223372036854775808;
SD1x18 constant MIN_SD1x18 = SD1x18.wrap(uMIN_SD1x18);

/// @dev PI as an SD1x18 number.
SD1x18 constant PI = SD1x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of SD1x18.
SD1x18 constant UNIT = SD1x18.wrap(1e18);
int64 constant uUNIT = 1e18;

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./Casting.sol" as Casting;

/// @notice The signed 1.18-decimal fixed-point number representation, which can have up to 1 digit and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int64. This is useful when end users want to use int64 to save gas, e.g. with tight variable packing in contract
/// storage.
type SD1x18 is int64;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    Casting.intoSD59x18,
    Casting.intoUD2x18,
    Casting.intoUD60x18,
    Casting.intoUint256,
    Casting.intoUint128,
    Casting.intoUint40,
    Casting.unwrap
} for SD1x18 global;

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { SD59x18 } from "./ValueType.sol";

// NOTICE: the "u" prefix stands for "unwrapped".

/// @dev Euler's number as an SD59x18 number.
SD59x18 constant E = SD59x18.wrap(2_718281828459045235);

/// @dev The maximum input permitted in {exp}.
int256 constant uEXP_MAX_INPUT = 133_084258667509499440;
SD59x18 constant EXP_MAX_INPUT = SD59x18.wrap(uEXP_MAX_INPUT);

/// @dev Any value less than this returns 0 in {exp}.
int256 constant uEXP_MIN_THRESHOLD = -41_446531673892822322;
SD59x18 constant EXP_MIN_THRESHOLD = SD59x18.wrap(uEXP_MIN_THRESHOLD);

/// @dev The maximum input permitted in {exp2}.
int256 constant uEXP2_MAX_INPUT = 192e18 - 1;
SD59x18 constant EXP2_MAX_INPUT = SD59x18.wrap(uEXP2_MAX_INPUT);

/// @dev Any value less than this returns 0 in {exp2}.
int256 constant uEXP2_MIN_THRESHOLD = -59_794705707972522261;
SD59x18 constant EXP2_MIN_THRESHOLD = SD59x18.wrap(uEXP2_MIN_THRESHOLD);

/// @dev Half the UNIT number.
int256 constant uHALF_UNIT = 0.5e18;
SD59x18 constant HALF_UNIT = SD59x18.wrap(uHALF_UNIT);

/// @dev $log_2(10)$ as an SD59x18 number.
int256 constant uLOG2_10 = 3_321928094887362347;
SD59x18 constant LOG2_10 = SD59x18.wrap(uLOG2_10);

/// @dev $log_2(e)$ as an SD59x18 number.
int256 constant uLOG2_E = 1_442695040888963407;
SD59x18 constant LOG2_E = SD59x18.wrap(uLOG2_E);

/// @dev The maximum value an SD59x18 number can have.
int256 constant uMAX_SD59x18 = 57896044618658097711785492504343953926634992332820282019728_792003956564819967;
SD59x18 constant MAX_SD59x18 = SD59x18.wrap(uMAX_SD59x18);

/// @dev The maximum whole value an SD59x18 number can have.
int256 constant uMAX_WHOLE_SD59x18 = 57896044618658097711785492504343953926634992332820282019728_000000000000000000;
SD59x18 constant MAX_WHOLE_SD59x18 = SD59x18.wrap(uMAX_WHOLE_SD59x18);

/// @dev The minimum value an SD59x18 number can have.
int256 constant uMIN_SD59x18 = -57896044618658097711785492504343953926634992332820282019728_792003956564819968;
SD59x18 constant MIN_SD59x18 = SD59x18.wrap(uMIN_SD59x18);

/// @dev The minimum whole value an SD59x18 number can have.
int256 constant uMIN_WHOLE_SD59x18 = -57896044618658097711785492504343953926634992332820282019728_000000000000000000;
SD59x18 constant MIN_WHOLE_SD59x18 = SD59x18.wrap(uMIN_WHOLE_SD59x18);

/// @dev PI as an SD59x18 number.
SD59x18 constant PI = SD59x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of SD59x18.
int256 constant uUNIT = 1e18;
SD59x18 constant UNIT = SD59x18.wrap(1e18);

/// @dev The unit number squared.
int256 constant uUNIT_SQUARED = 1e36;
SD59x18 constant UNIT_SQUARED = SD59x18.wrap(uUNIT_SQUARED);

/// @dev Zero as an SD59x18 number.
SD59x18 constant ZERO = SD59x18.wrap(0);

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./Casting.sol" as Casting;
import "./Helpers.sol" as Helpers;
import "./Math.sol" as Math;

/// @notice The signed 59.18-decimal fixed-point number representation, which can have up to 59 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type int256.
type SD59x18 is int256;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    Casting.intoInt256,
    Casting.intoSD1x18,
    Casting.intoUD2x18,
    Casting.intoUD60x18,
    Casting.intoUint256,
    Casting.intoUint128,
    Casting.intoUint40,
    Casting.unwrap
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                            MATHEMATICAL FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {
    Math.abs,
    Math.avg,
    Math.ceil,
    Math.div,
    Math.exp,
    Math.exp2,
    Math.floor,
    Math.frac,
    Math.gm,
    Math.inv,
    Math.log10,
    Math.log2,
    Math.ln,
    Math.mul,
    Math.pow,
    Math.powu,
    Math.sqrt
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
//////////////////////////////////////////////////////////////////////////*/

using {
    Helpers.add,
    Helpers.and,
    Helpers.eq,
    Helpers.gt,
    Helpers.gte,
    Helpers.isZero,
    Helpers.lshift,
    Helpers.lt,
    Helpers.lte,
    Helpers.mod,
    Helpers.neq,
    Helpers.not,
    Helpers.or,
    Helpers.rshift,
    Helpers.sub,
    Helpers.uncheckedAdd,
    Helpers.uncheckedSub,
    Helpers.uncheckedUnary,
    Helpers.xor
} for SD59x18 global;

/*//////////////////////////////////////////////////////////////////////////
                                    OPERATORS
//////////////////////////////////////////////////////////////////////////*/

// The global "using for" directive makes it possible to use these operators on the SD59x18 type.
using {
    Helpers.add as +,
    Helpers.and2 as &,
    Math.div as /,
    Helpers.eq as ==,
    Helpers.gt as >,
    Helpers.gte as >=,
    Helpers.lt as <,
    Helpers.lte as <=,
    Helpers.mod as %,
    Math.mul as *,
    Helpers.neq as !=,
    Helpers.not as ~,
    Helpers.or as |,
    Helpers.sub as -,
    Helpers.unary as -,
    Helpers.xor as ^
} for SD59x18 global;

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { UD2x18 } from "./ValueType.sol";

/// @dev Euler's number as a UD2x18 number.
UD2x18 constant E = UD2x18.wrap(2_718281828459045235);

/// @dev The maximum value a UD2x18 number can have.
uint64 constant uMAX_UD2x18 = 18_446744073709551615;
UD2x18 constant MAX_UD2x18 = UD2x18.wrap(uMAX_UD2x18);

/// @dev PI as a UD2x18 number.
UD2x18 constant PI = UD2x18.wrap(3_141592653589793238);

/// @dev The unit number, which gives the decimal precision of UD2x18.
UD2x18 constant UNIT = UD2x18.wrap(1e18);
uint64 constant uUNIT = 1e18;

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./Casting.sol" as Casting;

/// @notice The unsigned 2.18-decimal fixed-point number representation, which can have up to 2 digits and up to 18
/// decimals. The values of this are bound by the minimum and the maximum values permitted by the underlying Solidity
/// type uint64. This is useful when end users want to use uint64 to save gas, e.g. with tight variable packing in contract
/// storage.
type UD2x18 is uint64;

/*//////////////////////////////////////////////////////////////////////////
                                    CASTING
//////////////////////////////////////////////////////////////////////////*/

using {
    Casting.intoSD1x18,
    Casting.intoSD59x18,
    Casting.intoUD60x18,
    Casting.intoUint256,
    Casting.intoUint128,
    Casting.intoUint40,
    Casting.unwrap
} for UD2x18 global;

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/cryptography/ECDSA.sol)

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

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

import {Bits} from "./Bits.sol";

library Bitfield {
    using Bits for uint256;

    /**
     * @dev Constants used to efficiently calculate the hamming weight of a bitfield. See
     * https://en.wikipedia.org/wiki/Hamming_weight#Efficient_implementation for an explanation of those constants.
     */
    uint256 internal constant M1 = 0x5555555555555555555555555555555555555555555555555555555555555555;
    uint256 internal constant M2 = 0x3333333333333333333333333333333333333333333333333333333333333333;
    uint256 internal constant M4 = 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
    uint256 internal constant M8 = 0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff;
    uint256 internal constant M16 = 0x0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff;
    uint256 internal constant M32 = 0x00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff;
    uint256 internal constant M64 = 0x0000000000000000ffffffffffffffff0000000000000000ffffffffffffffff;
    uint256 internal constant M128 = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;

    uint256 internal constant ONE = uint256(1);

    /**
     * @notice Core subsampling algorithm. Draws a random number, derives an index in the bitfield, and sets the bit if it is in the `prior` and not
     * yet set. Repeats that `n` times.
     * @param seed Source of randomness for selecting validator signatures.
     * @param prior Bitfield indicating which validators claim to have signed the commitment.
     * @param n Number of unique bits in prior that must be set in the result. Must be <= number of set bits in `prior`.
     * @param length Length of the bitfield prior to draw bits from. Must be <= prior.length * 256.
     */
    function subsample(uint256 seed, uint256[] memory prior, uint256 n, uint256 length)
        internal
        pure
        returns (uint256[] memory bitfield)
    {
        bitfield = new uint256[](prior.length);
        uint256 found = 0;

        for (uint256 i = 0; found < n;) {
            uint256 index = makeIndex(seed, i, length);

            // require randomly selected bit to be set in prior and not yet set in bitfield
            if (!isSet(prior, index) || isSet(bitfield, index)) {
                unchecked {
                    i++;
                }
                continue;
            }

            set(bitfield, index);

            unchecked {
                found++;
                i++;
            }
        }

        return bitfield;
    }

    /**
     * @dev Helper to create a bitfield.
     */
    function createBitfield(uint256[] calldata bitsToSet, uint256 length)
        internal
        pure
        returns (uint256[] memory bitfield)
    {
        // Calculate length of uint256 array based on rounding up to number of uint256 needed
        uint256 arrayLength = (length + 255) / 256;

        bitfield = new uint256[](arrayLength);

        for (uint256 i = 0; i < bitsToSet.length; i++) {
            set(bitfield, bitsToSet[i]);
        }

        return bitfield;
    }

    /**
     * @notice Calculates the number of set bits by using the hamming weight of the bitfield.
     * The algorithm below is implemented after https://en.wikipedia.org/wiki/Hamming_weight#Efficient_implementation.
     * Further improvements are possible, see the article above.
     */
    function countSetBits(uint256[] memory self) internal pure returns (uint256) {
        unchecked {
            uint256 count = 0;
            for (uint256 i = 0; i < self.length; i++) {
                uint256 x = self[i];
                x = (x & M1) + ((x >> 1) & M1); //put count of each  2 bits into those  2 bits
                x = (x & M2) + ((x >> 2) & M2); //put count of each  4 bits into those  4 bits
                x = (x & M4) + ((x >> 4) & M4); //put count of each  8 bits into those  8 bits
                x = (x & M8) + ((x >> 8) & M8); //put count of each 16 bits into those 16 bits
                x = (x & M16) + ((x >> 16) & M16); //put count of each 32 bits into those 32 bits
                x = (x & M32) + ((x >> 32) & M32); //put count of each 64 bits into those 64 bits
                x = (x & M64) + ((x >> 64) & M64); //put count of each 128 bits into those 128 bits
                x = (x & M128) + ((x >> 128) & M128); //put count of each 256 bits into those 256 bits
                count += x;
            }
            return count;
        }
    }

    function isSet(uint256[] memory self, uint256 index) internal pure returns (bool) {
        uint256 element = index >> 8;
        return self[element].bit(uint8(index)) == 1;
    }

    function set(uint256[] memory self, uint256 index) internal pure {
        uint256 element = index >> 8;
        self[element] = self[element].setBit(uint8(index));
    }

    function unset(uint256[] memory self, uint256 index) internal pure {
        uint256 element = index >> 8;
        self[element] = self[element].clearBit(uint8(index));
    }

    function makeIndex(uint256 seed, uint256 iteration, uint256 length) internal pure returns (uint256 index) {
        assembly {
            mstore(0x00, seed)
            mstore(0x20, iteration)
            index := mod(keccak256(0x00, 0x40), length)
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

/**
 * @title A utility library for 16 bit counters packed in 256 bit array.
 * @dev The BeefyClient needs to store a count of how many times a validators signature is used. In solidity
 * a uint16 would take up as much space as a uin256 in storage, making storing counters for 1000 validators
 * expensive in terms of gas. The BeefyClient only needs 16 bits per counter. This library allows us to pack
 * 16 uint16 into a single uint256 and save 16x storage.
 *
 * Layout of 32 counters (2 uint256)
 * We store all counts in a single large uint256 array and convert from index from the logical uint16 array
 * to the physical uint256 array.
 *
 *           0                                               1                                               2
 * uint256[] |-- -- -- -- -- -- -- -- -- -- -- -- YY -- -- --|-- -- -- -- -- -- XX -- -- -- -- -- -- -- -- --|
 * uint16[]  |--|--|--|--|--|--|--|--|--|--|--|--|YY|--|--|--|--|--|--|--|--|--|XX|--|--|--|--|--|--|--|--|--|
 *           0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32
 *
 * Logical Index Layout
 * We use the first 4
 * |-------...---------|----|
 * 256                 4    0
 *        ^index          ^bit-index
 *
 * In the above table counter YY is at logical index 12 in the uint16 array. It will convert to a physical
 * index of 0 in the physical uint256 array and then to bit-index of 192 to 207 of that uint256. In the
 * above table counter XX is at logical index 22. It will convert to a physical index of 1 in the array and
 * then to bit-index 96 to 111 of uint256[1].
 */
using {get, set} for Uint16Array global;

error IndexOutOfBounds();

/**
 * @dev stores the backing array and the length.
 */
struct Uint16Array {
    uint256[] data;
    uint256 length;
}

/**
 * @dev Creates a new counter which can store at least `length` counters.
 * @param length The amount of counters.
 */
function createUint16Array(uint256 length) pure returns (Uint16Array memory) {
    // create space for `length` elements and round up if needed.
    uint256 bufferLength = length / 16 + (length % 16 == 0 ? 0 : 1);
    return Uint16Array({data: new uint256[](bufferLength), length: length});
}

/**
 * @dev Gets the counter at the logical index
 * @param self The array.
 * @param index The logical index.
 */
function get(Uint16Array storage self, uint256 index) view returns (uint16) {
    if (index >= self.length) {
        revert IndexOutOfBounds();
    }
    // Right-shift the index by 4. This truncates the first 4 bits (bit-index) leaving us with the index
    // into the array.
    uint256 element = index >> 4;
    // Mask out the first 4 bits of the logical index to give us the bit-index.
    uint8 inside = uint8(index) & 0x0F;
    // find the element in the array, shift until its bit index and mask to only take the first 16 bits.
    return uint16((self.data[element] >> (16 * inside)) & 0xFFFF);
}

/**
 * @dev Sets the counter at the logical index.
 * @param self The array.
 * @param index The logical index of the counter in the array.
 * @param value The value to set the counter to.
 */
function set(Uint16Array storage self, uint256 index, uint16 value) {
    if (index >= self.length) {
        revert IndexOutOfBounds();
    }
    // Right-shift the index by 4. This truncates the first 4 bits (bit-index) leaving us with the index
    // into the array.
    uint256 element = index >> 4;
    // Mask out the first 4 bytes of the logical index to give us the bit-index.
    uint8 inside = uint8(index) & 0x0F;
    // Create a zero mask which will clear the existing value at the bit-index.
    uint256 zero = ~(uint256(0xFFFF) << (16 * inside));
    // Shift the value to the bit index.
    uint256 shiftedValue = uint256(value) << (16 * inside);
    // Take the element, apply the zero mask to clear the existing value, and then apply the shifted value with bitwise or.
    self.data[element] = self.data[element] & zero | shiftedValue;
}

// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2023 OpenZeppelin
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
// Code from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol
pragma solidity 0.8.25;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero

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
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }

    /**
     * @dev Safely adds two unsigned 16-bit integers, preventing overflow by saturating to max uint16.
     */
    function saturatingAdd(uint16 a, uint16 b) internal pure returns (uint16) {
        unchecked {
            uint16 c = a + b;
            if (c < a) {
                return 0xFFFF;
            }
            return c;
        }
    }

    /**
     * @dev Safely subtracts two unsigned 256-bit integers, preventing overflow by saturating to min uint256.
     */
    function saturatingSub(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (b >= a) {
                return 0;
            }
            return a - b;
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.25;

library MMRProof {
    error ProofSizeExceeded();

    uint256 internal constant MAXIMUM_PROOF_SIZE = 256;

    /**
     * @dev Verify inclusion of a leaf in an MMR
     * @param root MMR root hash
     * @param leafHash leaf hash
     * @param proof an array of hashes
     * @param proofOrder a bitfield describing the order of each item (left vs right)
     */
    function verifyLeafProof(bytes32 root, bytes32 leafHash, bytes32[] calldata proof, uint256 proofOrder)
        internal
        pure
        returns (bool)
    {
        // Size of the proof is bounded, since `proofOrder` can only contain `MAXIMUM_PROOF_SIZE` orderings.
        if (proof.length > MAXIMUM_PROOF_SIZE) {
            revert ProofSizeExceeded();
        }

        bytes32 acc = leafHash;
        for (uint256 i = 0; i < proof.length; i++) {
            acc = hashPairs(acc, proof[i], (proofOrder >> i) & 1);
        }
        return root == acc;
    }

    function hashPairs(bytes32 x, bytes32 y, uint256 order) internal pure returns (bytes32 value) {
        assembly {
            switch order
            case 0 {
                mstore(0x00, x)
                mstore(0x20, y)
            }
            default {
                mstore(0x00, y)
                mstore(0x20, x)
            }
            value := keccak256(0x0, 0x40)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../Common.sol" as Common;
import "./Errors.sol" as CastingErrors;
import { SD59x18 } from "../sd59x18/ValueType.sol";
import { UD2x18 } from "../ud2x18/ValueType.sol";
import { UD60x18 } from "../ud60x18/ValueType.sol";
import { SD1x18 } from "./ValueType.sol";

/// @notice Casts an SD1x18 number into SD59x18.
/// @dev There is no overflow check because the domain of SD1x18 is a subset of SD59x18.
function intoSD59x18(SD1x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(SD1x18.unwrap(x)));
}

/// @notice Casts an SD1x18 number into UD2x18.
/// - x must be positive.
function intoUD2x18(SD1x18 x) pure returns (UD2x18 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD1x18_ToUD2x18_Underflow(x);
    }
    result = UD2x18.wrap(uint64(xInt));
}

/// @notice Casts an SD1x18 number into UD60x18.
/// @dev Requirements:
/// - x must be positive.
function intoUD60x18(SD1x18 x) pure returns (UD60x18 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD1x18_ToUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint256.
/// @dev Requirements:
/// - x must be positive.
function intoUint256(SD1x18 x) pure returns (uint256 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD1x18_ToUint256_Underflow(x);
    }
    result = uint256(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint128.
/// @dev Requirements:
/// - x must be positive.
function intoUint128(SD1x18 x) pure returns (uint128 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD1x18_ToUint128_Underflow(x);
    }
    result = uint128(uint64(xInt));
}

/// @notice Casts an SD1x18 number into uint40.
/// @dev Requirements:
/// - x must be positive.
/// - x must be less than or equal to `MAX_UINT40`.
function intoUint40(SD1x18 x) pure returns (uint40 result) {
    int64 xInt = SD1x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD1x18_ToUint40_Underflow(x);
    }
    if (xInt > int64(uint64(Common.MAX_UINT40))) {
        revert CastingErrors.PRBMath_SD1x18_ToUint40_Overflow(x);
    }
    result = uint40(uint64(xInt));
}

/// @notice Alias for {wrap}.
function sd1x18(int64 x) pure returns (SD1x18 result) {
    result = SD1x18.wrap(x);
}

/// @notice Unwraps an SD1x18 number into int64.
function unwrap(SD1x18 x) pure returns (int64 result) {
    result = SD1x18.unwrap(x);
}

/// @notice Wraps an int64 number into SD1x18.
function wrap(int64 x) pure returns (SD1x18 result) {
    result = SD1x18.wrap(x);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "./Errors.sol" as CastingErrors;
import { MAX_UINT128, MAX_UINT40 } from "../Common.sol";
import { uMAX_SD1x18, uMIN_SD1x18 } from "../sd1x18/Constants.sol";
import { SD1x18 } from "../sd1x18/ValueType.sol";
import { uMAX_UD2x18 } from "../ud2x18/Constants.sol";
import { UD2x18 } from "../ud2x18/ValueType.sol";
import { UD60x18 } from "../ud60x18/ValueType.sol";
import { SD59x18 } from "./ValueType.sol";

/// @notice Casts an SD59x18 number into int256.
/// @dev This is basically a functional alias for {unwrap}.
function intoInt256(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x);
}

/// @notice Casts an SD59x18 number into SD1x18.
/// @dev Requirements:
/// - x must be greater than or equal to `uMIN_SD1x18`.
/// - x must be less than or equal to `uMAX_SD1x18`.
function intoSD1x18(SD59x18 x) pure returns (SD1x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < uMIN_SD1x18) {
        revert CastingErrors.PRBMath_SD59x18_IntoSD1x18_Underflow(x);
    }
    if (xInt > uMAX_SD1x18) {
        revert CastingErrors.PRBMath_SD59x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(xInt));
}

/// @notice Casts an SD59x18 number into UD2x18.
/// @dev Requirements:
/// - x must be positive.
/// - x must be less than or equal to `uMAX_UD2x18`.
function intoUD2x18(SD59x18 x) pure returns (UD2x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUD2x18_Underflow(x);
    }
    if (xInt > int256(uint256(uMAX_UD2x18))) {
        revert CastingErrors.PRBMath_SD59x18_IntoUD2x18_Overflow(x);
    }
    result = UD2x18.wrap(uint64(uint256(xInt)));
}

/// @notice Casts an SD59x18 number into UD60x18.
/// @dev Requirements:
/// - x must be positive.
function intoUD60x18(SD59x18 x) pure returns (UD60x18 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUD60x18_Underflow(x);
    }
    result = UD60x18.wrap(uint256(xInt));
}

/// @notice Casts an SD59x18 number into uint256.
/// @dev Requirements:
/// - x must be positive.
function intoUint256(SD59x18 x) pure returns (uint256 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint256_Underflow(x);
    }
    result = uint256(xInt);
}

/// @notice Casts an SD59x18 number into uint128.
/// @dev Requirements:
/// - x must be positive.
/// - x must be less than or equal to `uMAX_UINT128`.
function intoUint128(SD59x18 x) pure returns (uint128 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint128_Underflow(x);
    }
    if (xInt > int256(uint256(MAX_UINT128))) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint128_Overflow(x);
    }
    result = uint128(uint256(xInt));
}

/// @notice Casts an SD59x18 number into uint40.
/// @dev Requirements:
/// - x must be positive.
/// - x must be less than or equal to `MAX_UINT40`.
function intoUint40(SD59x18 x) pure returns (uint40 result) {
    int256 xInt = SD59x18.unwrap(x);
    if (xInt < 0) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint40_Underflow(x);
    }
    if (xInt > int256(uint256(MAX_UINT40))) {
        revert CastingErrors.PRBMath_SD59x18_IntoUint40_Overflow(x);
    }
    result = uint40(uint256(xInt));
}

/// @notice Alias for {wrap}.
function sd(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

/// @notice Alias for {wrap}.
function sd59x18(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

/// @notice Unwraps an SD59x18 number into int256.
function unwrap(SD59x18 x) pure returns (int256 result) {
    result = SD59x18.unwrap(x);
}

/// @notice Wraps an int256 number into SD59x18.
function wrap(int256 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(x);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { wrap } from "./Casting.sol";
import { SD59x18 } from "./ValueType.sol";

/// @notice Implements the checked addition operation (+) in the SD59x18 type.
function add(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    return wrap(x.unwrap() + y.unwrap());
}

/// @notice Implements the AND (&) bitwise operation in the SD59x18 type.
function and(SD59x18 x, int256 bits) pure returns (SD59x18 result) {
    return wrap(x.unwrap() & bits);
}

/// @notice Implements the AND (&) bitwise operation in the SD59x18 type.
function and2(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    return wrap(x.unwrap() & y.unwrap());
}

/// @notice Implements the equal (=) operation in the SD59x18 type.
function eq(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() == y.unwrap();
}

/// @notice Implements the greater than operation (>) in the SD59x18 type.
function gt(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() > y.unwrap();
}

/// @notice Implements the greater than or equal to operation (>=) in the SD59x18 type.
function gte(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() >= y.unwrap();
}

/// @notice Implements a zero comparison check function in the SD59x18 type.
function isZero(SD59x18 x) pure returns (bool result) {
    result = x.unwrap() == 0;
}

/// @notice Implements the left shift operation (<<) in the SD59x18 type.
function lshift(SD59x18 x, uint256 bits) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() << bits);
}

/// @notice Implements the lower than operation (<) in the SD59x18 type.
function lt(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() < y.unwrap();
}

/// @notice Implements the lower than or equal to operation (<=) in the SD59x18 type.
function lte(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() <= y.unwrap();
}

/// @notice Implements the unchecked modulo operation (%) in the SD59x18 type.
function mod(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() % y.unwrap());
}

/// @notice Implements the not equal operation (!=) in the SD59x18 type.
function neq(SD59x18 x, SD59x18 y) pure returns (bool result) {
    result = x.unwrap() != y.unwrap();
}

/// @notice Implements the NOT (~) bitwise operation in the SD59x18 type.
function not(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap(~x.unwrap());
}

/// @notice Implements the OR (|) bitwise operation in the SD59x18 type.
function or(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() | y.unwrap());
}

/// @notice Implements the right shift operation (>>) in the SD59x18 type.
function rshift(SD59x18 x, uint256 bits) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() >> bits);
}

/// @notice Implements the checked subtraction operation (-) in the SD59x18 type.
function sub(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() - y.unwrap());
}

/// @notice Implements the checked unary minus operation (-) in the SD59x18 type.
function unary(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap(-x.unwrap());
}

/// @notice Implements the unchecked addition operation (+) in the SD59x18 type.
function uncheckedAdd(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    unchecked {
        result = wrap(x.unwrap() + y.unwrap());
    }
}

/// @notice Implements the unchecked subtraction operation (-) in the SD59x18 type.
function uncheckedSub(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    unchecked {
        result = wrap(x.unwrap() - y.unwrap());
    }
}

/// @notice Implements the unchecked unary minus operation (-) in the SD59x18 type.
function uncheckedUnary(SD59x18 x) pure returns (SD59x18 result) {
    unchecked {
        result = wrap(-x.unwrap());
    }
}

/// @notice Implements the XOR (^) bitwise operation in the SD59x18 type.
function xor(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() ^ y.unwrap());
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../Common.sol" as Common;
import "./Errors.sol" as Errors;
import {
    uEXP_MAX_INPUT,
    uEXP2_MAX_INPUT,
    uEXP_MIN_THRESHOLD,
    uEXP2_MIN_THRESHOLD,
    uHALF_UNIT,
    uLOG2_10,
    uLOG2_E,
    uMAX_SD59x18,
    uMAX_WHOLE_SD59x18,
    uMIN_SD59x18,
    uMIN_WHOLE_SD59x18,
    UNIT,
    uUNIT,
    uUNIT_SQUARED,
    ZERO
} from "./Constants.sol";
import { wrap } from "./Helpers.sol";
import { SD59x18 } from "./ValueType.sol";

/// @notice Calculates the absolute value of x.
///
/// @dev Requirements:
/// - x must be greater than `MIN_SD59x18`.
///
/// @param x The SD59x18 number for which to calculate the absolute value.
/// @param result The absolute value of x as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function abs(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    if (xInt == uMIN_SD59x18) {
        revert Errors.PRBMath_SD59x18_Abs_MinSD59x18();
    }
    result = xInt < 0 ? wrap(-xInt) : x;
}

/// @notice Calculates the arithmetic average of x and y.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// @param x The first operand as an SD59x18 number.
/// @param y The second operand as an SD59x18 number.
/// @return result The arithmetic average as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function avg(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    int256 yInt = y.unwrap();

    unchecked {
        // This operation is equivalent to `x / 2 +  y / 2`, and it can never overflow.
        int256 sum = (xInt >> 1) + (yInt >> 1);

        if (sum < 0) {
            // If at least one of x and y is odd, add 1 to the result, because shifting negative numbers to the right
            // rounds toward negative infinity. The right part is equivalent to `sum + (x % 2 == 1 || y % 2 == 1)`.
            assembly ("memory-safe") {
                result := add(sum, and(or(xInt, yInt), 1))
            }
        } else {
            // Add 1 if both x and y are odd to account for the double 0.5 remainder truncated after shifting.
            result = wrap(sum + (xInt & yInt & 1));
        }
    }
}

/// @notice Yields the smallest whole number greater than or equal to x.
///
/// @dev Optimized for fractional value inputs, because every whole value has (1e18 - 1) fractional counterparts.
/// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x must be less than or equal to `MAX_WHOLE_SD59x18`.
///
/// @param x The SD59x18 number to ceil.
/// @param result The smallest whole number greater than or equal to x, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function ceil(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    if (xInt > uMAX_WHOLE_SD59x18) {
        revert Errors.PRBMath_SD59x18_Ceil_Overflow(x);
    }

    int256 remainder = xInt % uUNIT;
    if (remainder == 0) {
        result = x;
    } else {
        unchecked {
            // Solidity uses C fmod style, which returns a modulus with the same sign as x.
            int256 resultInt = xInt - remainder;
            if (xInt > 0) {
                resultInt += uUNIT;
            }
            result = wrap(resultInt);
        }
    }
}

/// @notice Divides two SD59x18 numbers, returning a new SD59x18 number.
///
/// @dev This is an extension of {Common.mulDiv} for signed numbers, which works by computing the signs and the absolute
/// values separately.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv}.
/// - The result is rounded toward zero.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv}.
/// - None of the inputs can be `MIN_SD59x18`.
/// - The denominator must not be zero.
/// - The result must fit in SD59x18.
///
/// @param x The numerator as an SD59x18 number.
/// @param y The denominator as an SD59x18 number.
/// @param result The quotient as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function div(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    int256 yInt = y.unwrap();
    if (xInt == uMIN_SD59x18 || yInt == uMIN_SD59x18) {
        revert Errors.PRBMath_SD59x18_Div_InputTooSmall();
    }

    // Get hold of the absolute values of x and y.
    uint256 xAbs;
    uint256 yAbs;
    unchecked {
        xAbs = xInt < 0 ? uint256(-xInt) : uint256(xInt);
        yAbs = yInt < 0 ? uint256(-yInt) : uint256(yInt);
    }

    // Compute the absolute value (x*UNIT÷y). The resulting value must fit in SD59x18.
    uint256 resultAbs = Common.mulDiv(xAbs, uint256(uUNIT), yAbs);
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert Errors.PRBMath_SD59x18_Div_Overflow(x, y);
    }

    // Check if x and y have the same sign using two's complement representation. The left-most bit represents the sign (1 for
    // negative, 0 for positive or zero).
    bool sameSign = (xInt ^ yInt) > -1;

    // If the inputs have the same sign, the result should be positive. Otherwise, it should be negative.
    unchecked {
        result = wrap(sameSign ? int256(resultAbs) : -int256(resultAbs));
    }
}

/// @notice Calculates the natural exponent of x using the following formula:
///
/// $$
/// e^x = 2^{x * log_2{e}}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {exp2}.
///
/// Requirements:
/// - Refer to the requirements in {exp2}.
/// - x must be less than 133_084258667509499441.
///
/// @param x The exponent as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();

    // Any input less than the threshold returns zero.
    // This check also prevents an overflow for very small numbers.
    if (xInt < uEXP_MIN_THRESHOLD) {
        return ZERO;
    }

    // This check prevents values greater than 192e18 from being passed to {exp2}.
    if (xInt > uEXP_MAX_INPUT) {
        revert Errors.PRBMath_SD59x18_Exp_InputTooBig(x);
    }

    unchecked {
        // Inline the fixed-point multiplication to save gas.
        int256 doubleUnitProduct = xInt * uLOG2_E;
        result = exp2(wrap(doubleUnitProduct / uUNIT));
    }
}

/// @notice Calculates the binary exponent of x using the binary fraction method using the following formula:
///
/// $$
/// 2^{-x} = \frac{1}{2^x}
/// $$
///
/// @dev See https://ethereum.stackexchange.com/q/79903/24693.
///
/// Notes:
/// - If x is less than -59_794705707972522261, the result is zero.
///
/// Requirements:
/// - x must be less than 192e18.
/// - The result must fit in SD59x18.
///
/// @param x The exponent as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function exp2(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    if (xInt < 0) {
        // The inverse of any number less than the threshold is truncated to zero.
        if (xInt < uEXP2_MIN_THRESHOLD) {
            return ZERO;
        }

        unchecked {
            // Inline the fixed-point inversion to save gas.
            result = wrap(uUNIT_SQUARED / exp2(wrap(-xInt)).unwrap());
        }
    } else {
        // Numbers greater than or equal to 192e18 don't fit in the 192.64-bit format.
        if (xInt > uEXP2_MAX_INPUT) {
            revert Errors.PRBMath_SD59x18_Exp2_InputTooBig(x);
        }

        unchecked {
            // Convert x to the 192.64-bit fixed-point format.
            uint256 x_192x64 = uint256((xInt << 64) / uUNIT);

            // It is safe to cast the result to int256 due to the checks above.
            result = wrap(int256(Common.exp2(x_192x64)));
        }
    }
}

/// @notice Yields the greatest whole number less than or equal to x.
///
/// @dev Optimized for fractional value inputs, because for every whole value there are (1e18 - 1) fractional
/// counterparts. See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
///
/// Requirements:
/// - x must be greater than or equal to `MIN_WHOLE_SD59x18`.
///
/// @param x The SD59x18 number to floor.
/// @param result The greatest whole number less than or equal to x, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function floor(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    if (xInt < uMIN_WHOLE_SD59x18) {
        revert Errors.PRBMath_SD59x18_Floor_Underflow(x);
    }

    int256 remainder = xInt % uUNIT;
    if (remainder == 0) {
        result = x;
    } else {
        unchecked {
            // Solidity uses C fmod style, which returns a modulus with the same sign as x.
            int256 resultInt = xInt - remainder;
            if (xInt < 0) {
                resultInt -= uUNIT;
            }
            result = wrap(resultInt);
        }
    }
}

/// @notice Yields the excess beyond the floor of x for positive numbers and the part of the number to the right.
/// of the radix point for negative numbers.
/// @dev Based on the odd function definition. https://en.wikipedia.org/wiki/Fractional_part
/// @param x The SD59x18 number to get the fractional part of.
/// @param result The fractional part of x as an SD59x18 number.
function frac(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap(x.unwrap() % uUNIT);
}

/// @notice Calculates the geometric mean of x and y, i.e. $\sqrt{x * y}$.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x * y must fit in SD59x18.
/// - x * y must not be negative, since complex numbers are not supported.
///
/// @param x The first operand as an SD59x18 number.
/// @param y The second operand as an SD59x18 number.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function gm(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    int256 yInt = y.unwrap();
    if (xInt == 0 || yInt == 0) {
        return ZERO;
    }

    unchecked {
        // Equivalent to `xy / x != y`. Checking for overflow this way is faster than letting Solidity do it.
        int256 xyInt = xInt * yInt;
        if (xyInt / xInt != yInt) {
            revert Errors.PRBMath_SD59x18_Gm_Overflow(x, y);
        }

        // The product must not be negative, since complex numbers are not supported.
        if (xyInt < 0) {
            revert Errors.PRBMath_SD59x18_Gm_NegativeProduct(x, y);
        }

        // We don't need to multiply the result by `UNIT` here because the x*y product picked up a factor of `UNIT`
        // during multiplication. See the comments in {Common.sqrt}.
        uint256 resultUint = Common.sqrt(uint256(xyInt));
        result = wrap(int256(resultUint));
    }
}

/// @notice Calculates the inverse of x.
///
/// @dev Notes:
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x must not be zero.
///
/// @param x The SD59x18 number for which to calculate the inverse.
/// @return result The inverse as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function inv(SD59x18 x) pure returns (SD59x18 result) {
    result = wrap(uUNIT_SQUARED / x.unwrap());
}

/// @notice Calculates the natural logarithm of x using the following formula:
///
/// $$
/// ln{x} = log_2{x} / log_2{e}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
/// - The precision isn't sufficiently fine-grained to return exactly `UNIT` when the input is `E`.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The SD59x18 number for which to calculate the natural logarithm.
/// @return result The natural logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function ln(SD59x18 x) pure returns (SD59x18 result) {
    // Inline the fixed-point multiplication to save gas. This is overflow-safe because the maximum value that
    // {log2} can return is ~195_205294292027477728.
    result = wrap(log2(x).unwrap() * uUNIT / uLOG2_E);
}

/// @notice Calculates the common logarithm of x using the following formula:
///
/// $$
/// log_{10}{x} = log_2{x} / log_2{10}
/// $$
///
/// However, if x is an exact power of ten, a hard coded value is returned.
///
/// @dev Notes:
/// - Refer to the notes in {log2}.
///
/// Requirements:
/// - Refer to the requirements in {log2}.
///
/// @param x The SD59x18 number for which to calculate the common logarithm.
/// @return result The common logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function log10(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    if (xInt < 0) {
        revert Errors.PRBMath_SD59x18_Log_InputTooSmall(x);
    }

    // Note that the `mul` in this block is the standard multiplication operation, not {SD59x18.mul}.
    // prettier-ignore
    assembly ("memory-safe") {
        switch x
        case 1 { result := mul(uUNIT, sub(0, 18)) }
        case 10 { result := mul(uUNIT, sub(1, 18)) }
        case 100 { result := mul(uUNIT, sub(2, 18)) }
        case 1000 { result := mul(uUNIT, sub(3, 18)) }
        case 10000 { result := mul(uUNIT, sub(4, 18)) }
        case 100000 { result := mul(uUNIT, sub(5, 18)) }
        case 1000000 { result := mul(uUNIT, sub(6, 18)) }
        case 10000000 { result := mul(uUNIT, sub(7, 18)) }
        case 100000000 { result := mul(uUNIT, sub(8, 18)) }
        case 1000000000 { result := mul(uUNIT, sub(9, 18)) }
        case 10000000000 { result := mul(uUNIT, sub(10, 18)) }
        case 100000000000 { result := mul(uUNIT, sub(11, 18)) }
        case 1000000000000 { result := mul(uUNIT, sub(12, 18)) }
        case 10000000000000 { result := mul(uUNIT, sub(13, 18)) }
        case 100000000000000 { result := mul(uUNIT, sub(14, 18)) }
        case 1000000000000000 { result := mul(uUNIT, sub(15, 18)) }
        case 10000000000000000 { result := mul(uUNIT, sub(16, 18)) }
        case 100000000000000000 { result := mul(uUNIT, sub(17, 18)) }
        case 1000000000000000000 { result := 0 }
        case 10000000000000000000 { result := uUNIT }
        case 100000000000000000000 { result := mul(uUNIT, 2) }
        case 1000000000000000000000 { result := mul(uUNIT, 3) }
        case 10000000000000000000000 { result := mul(uUNIT, 4) }
        case 100000000000000000000000 { result := mul(uUNIT, 5) }
        case 1000000000000000000000000 { result := mul(uUNIT, 6) }
        case 10000000000000000000000000 { result := mul(uUNIT, 7) }
        case 100000000000000000000000000 { result := mul(uUNIT, 8) }
        case 1000000000000000000000000000 { result := mul(uUNIT, 9) }
        case 10000000000000000000000000000 { result := mul(uUNIT, 10) }
        case 100000000000000000000000000000 { result := mul(uUNIT, 11) }
        case 1000000000000000000000000000000 { result := mul(uUNIT, 12) }
        case 10000000000000000000000000000000 { result := mul(uUNIT, 13) }
        case 100000000000000000000000000000000 { result := mul(uUNIT, 14) }
        case 1000000000000000000000000000000000 { result := mul(uUNIT, 15) }
        case 10000000000000000000000000000000000 { result := mul(uUNIT, 16) }
        case 100000000000000000000000000000000000 { result := mul(uUNIT, 17) }
        case 1000000000000000000000000000000000000 { result := mul(uUNIT, 18) }
        case 10000000000000000000000000000000000000 { result := mul(uUNIT, 19) }
        case 100000000000000000000000000000000000000 { result := mul(uUNIT, 20) }
        case 1000000000000000000000000000000000000000 { result := mul(uUNIT, 21) }
        case 10000000000000000000000000000000000000000 { result := mul(uUNIT, 22) }
        case 100000000000000000000000000000000000000000 { result := mul(uUNIT, 23) }
        case 1000000000000000000000000000000000000000000 { result := mul(uUNIT, 24) }
        case 10000000000000000000000000000000000000000000 { result := mul(uUNIT, 25) }
        case 100000000000000000000000000000000000000000000 { result := mul(uUNIT, 26) }
        case 1000000000000000000000000000000000000000000000 { result := mul(uUNIT, 27) }
        case 10000000000000000000000000000000000000000000000 { result := mul(uUNIT, 28) }
        case 100000000000000000000000000000000000000000000000 { result := mul(uUNIT, 29) }
        case 1000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 30) }
        case 10000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 31) }
        case 100000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 32) }
        case 1000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 33) }
        case 10000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 34) }
        case 100000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 35) }
        case 1000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 36) }
        case 10000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 37) }
        case 100000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 38) }
        case 1000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 39) }
        case 10000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 40) }
        case 100000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 41) }
        case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 42) }
        case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 43) }
        case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 44) }
        case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 45) }
        case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 46) }
        case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 47) }
        case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 48) }
        case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 49) }
        case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 50) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 51) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 52) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 53) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 54) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 55) }
        case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 56) }
        case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 57) }
        case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(uUNIT, 58) }
        default { result := uMAX_SD59x18 }
    }

    if (result.unwrap() == uMAX_SD59x18) {
        unchecked {
            // Inline the fixed-point division to save gas.
            result = wrap(log2(x).unwrap() * uUNIT / uLOG2_10);
        }
    }
}

/// @notice Calculates the binary logarithm of x using the iterative approximation algorithm:
///
/// $$
/// log_2{x} = n + log_2{y}, \text{ where } y = x*2^{-n}, \ y \in [1, 2)
/// $$
///
/// For $0 \leq x \lt 1$, the input is inverted:
///
/// $$
/// log_2{x} = -log_2{\frac{1}{x}}
/// $$
///
/// @dev See https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation.
///
/// Notes:
/// - Due to the lossy precision of the iterative approximation, the results are not perfectly accurate to the last decimal.
///
/// Requirements:
/// - x must be greater than zero.
///
/// @param x The SD59x18 number for which to calculate the binary logarithm.
/// @return result The binary logarithm as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function log2(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    if (xInt <= 0) {
        revert Errors.PRBMath_SD59x18_Log_InputTooSmall(x);
    }

    unchecked {
        int256 sign;
        if (xInt >= uUNIT) {
            sign = 1;
        } else {
            sign = -1;
            // Inline the fixed-point inversion to save gas.
            xInt = uUNIT_SQUARED / xInt;
        }

        // Calculate the integer part of the logarithm.
        uint256 n = Common.msb(uint256(xInt / uUNIT));

        // This is the integer part of the logarithm as an SD59x18 number. The operation can't overflow
        // because n is at most 255, `UNIT` is 1e18, and the sign is either 1 or -1.
        int256 resultInt = int256(n) * uUNIT;

        // Calculate $y = x * 2^{-n}$.
        int256 y = xInt >> n;

        // If y is the unit number, the fractional part is zero.
        if (y == uUNIT) {
            return wrap(resultInt * sign);
        }

        // Calculate the fractional part via the iterative approximation.
        // The `delta >>= 1` part is equivalent to `delta /= 2`, but shifting bits is more gas efficient.
        int256 DOUBLE_UNIT = 2e18;
        for (int256 delta = uHALF_UNIT; delta > 0; delta >>= 1) {
            y = (y * y) / uUNIT;

            // Is y^2 >= 2e18 and so in the range [2e18, 4e18)?
            if (y >= DOUBLE_UNIT) {
                // Add the 2^{-m} factor to the logarithm.
                resultInt = resultInt + delta;

                // Halve y, which corresponds to z/2 in the Wikipedia article.
                y >>= 1;
            }
        }
        resultInt *= sign;
        result = wrap(resultInt);
    }
}

/// @notice Multiplies two SD59x18 numbers together, returning a new SD59x18 number.
///
/// @dev Notes:
/// - Refer to the notes in {Common.mulDiv18}.
///
/// Requirements:
/// - Refer to the requirements in {Common.mulDiv18}.
/// - None of the inputs can be `MIN_SD59x18`.
/// - The result must fit in SD59x18.
///
/// @param x The multiplicand as an SD59x18 number.
/// @param y The multiplier as an SD59x18 number.
/// @return result The product as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function mul(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    int256 yInt = y.unwrap();
    if (xInt == uMIN_SD59x18 || yInt == uMIN_SD59x18) {
        revert Errors.PRBMath_SD59x18_Mul_InputTooSmall();
    }

    // Get hold of the absolute values of x and y.
    uint256 xAbs;
    uint256 yAbs;
    unchecked {
        xAbs = xInt < 0 ? uint256(-xInt) : uint256(xInt);
        yAbs = yInt < 0 ? uint256(-yInt) : uint256(yInt);
    }

    // Compute the absolute value (x*y÷UNIT). The resulting value must fit in SD59x18.
    uint256 resultAbs = Common.mulDiv18(xAbs, yAbs);
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert Errors.PRBMath_SD59x18_Mul_Overflow(x, y);
    }

    // Check if x and y have the same sign using two's complement representation. The left-most bit represents the sign (1 for
    // negative, 0 for positive or zero).
    bool sameSign = (xInt ^ yInt) > -1;

    // If the inputs have the same sign, the result should be positive. Otherwise, it should be negative.
    unchecked {
        result = wrap(sameSign ? int256(resultAbs) : -int256(resultAbs));
    }
}

/// @notice Raises x to the power of y using the following formula:
///
/// $$
/// x^y = 2^{log_2{x} * y}
/// $$
///
/// @dev Notes:
/// - Refer to the notes in {exp2}, {log2}, and {mul}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - Refer to the requirements in {exp2}, {log2}, and {mul}.
///
/// @param x The base as an SD59x18 number.
/// @param y Exponent to raise x to, as an SD59x18 number
/// @return result x raised to power y, as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function pow(SD59x18 x, SD59x18 y) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    int256 yInt = y.unwrap();

    // If both x and y are zero, the result is `UNIT`. If just x is zero, the result is always zero.
    if (xInt == 0) {
        return yInt == 0 ? UNIT : ZERO;
    }
    // If x is `UNIT`, the result is always `UNIT`.
    else if (xInt == uUNIT) {
        return UNIT;
    }

    // If y is zero, the result is always `UNIT`.
    if (yInt == 0) {
        return UNIT;
    }
    // If y is `UNIT`, the result is always x.
    else if (yInt == uUNIT) {
        return x;
    }

    // Calculate the result using the formula.
    result = exp2(mul(log2(x), y));
}

/// @notice Raises x (an SD59x18 number) to the power y (an unsigned basic integer) using the well-known
/// algorithm "exponentiation by squaring".
///
/// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring.
///
/// Notes:
/// - Refer to the notes in {Common.mulDiv18}.
/// - Returns `UNIT` for 0^0.
///
/// Requirements:
/// - Refer to the requirements in {abs} and {Common.mulDiv18}.
/// - The result must fit in SD59x18.
///
/// @param x The base as an SD59x18 number.
/// @param y The exponent as a uint256.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function powu(SD59x18 x, uint256 y) pure returns (SD59x18 result) {
    uint256 xAbs = uint256(abs(x).unwrap());

    // Calculate the first iteration of the loop in advance.
    uint256 resultAbs = y & 1 > 0 ? xAbs : uint256(uUNIT);

    // Equivalent to `for(y /= 2; y > 0; y /= 2)`.
    uint256 yAux = y;
    for (yAux >>= 1; yAux > 0; yAux >>= 1) {
        xAbs = Common.mulDiv18(xAbs, xAbs);

        // Equivalent to `y % 2 == 1`.
        if (yAux & 1 > 0) {
            resultAbs = Common.mulDiv18(resultAbs, xAbs);
        }
    }

    // The result must fit in SD59x18.
    if (resultAbs > uint256(uMAX_SD59x18)) {
        revert Errors.PRBMath_SD59x18_Powu_Overflow(x, y);
    }

    unchecked {
        // Is the base negative and the exponent odd? If yes, the result should be negative.
        int256 resultInt = int256(resultAbs);
        bool isNegative = x.unwrap() < 0 && y & 1 == 1;
        if (isNegative) {
            resultInt = -resultInt;
        }
        result = wrap(resultInt);
    }
}

/// @notice Calculates the square root of x using the Babylonian method.
///
/// @dev See https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
///
/// Notes:
/// - Only the positive root is returned.
/// - The result is rounded toward zero.
///
/// Requirements:
/// - x cannot be negative, since complex numbers are not supported.
/// - x must be less than `MAX_SD59x18 / UNIT`.
///
/// @param x The SD59x18 number for which to calculate the square root.
/// @return result The result as an SD59x18 number.
/// @custom:smtchecker abstract-function-nondet
function sqrt(SD59x18 x) pure returns (SD59x18 result) {
    int256 xInt = x.unwrap();
    if (xInt < 0) {
        revert Errors.PRBMath_SD59x18_Sqrt_NegativeInput(x);
    }
    if (xInt > uMAX_SD59x18 / uUNIT) {
        revert Errors.PRBMath_SD59x18_Sqrt_Overflow(x);
    }

    unchecked {
        // Multiply x by `UNIT` to account for the factor of `UNIT` picked up when multiplying two SD59x18 numbers.
        // In this case, the two numbers are both the square root.
        uint256 resultUint = Common.sqrt(uint256(xInt * uUNIT));
        result = wrap(int256(resultUint));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import "../Common.sol" as Common;
import "./Errors.sol" as Errors;
import { uMAX_SD1x18 } from "../sd1x18/Constants.sol";
import { SD1x18 } from "../sd1x18/ValueType.sol";
import { SD59x18 } from "../sd59x18/ValueType.sol";
import { UD60x18 } from "../ud60x18/ValueType.sol";
import { UD2x18 } from "./ValueType.sol";

/// @notice Casts a UD2x18 number into SD1x18.
/// - x must be less than or equal to `uMAX_SD1x18`.
function intoSD1x18(UD2x18 x) pure returns (SD1x18 result) {
    uint64 xUint = UD2x18.unwrap(x);
    if (xUint > uint64(uMAX_SD1x18)) {
        revert Errors.PRBMath_UD2x18_IntoSD1x18_Overflow(x);
    }
    result = SD1x18.wrap(int64(xUint));
}

/// @notice Casts a UD2x18 number into SD59x18.
/// @dev There is no overflow check because the domain of UD2x18 is a subset of SD59x18.
function intoSD59x18(UD2x18 x) pure returns (SD59x18 result) {
    result = SD59x18.wrap(int256(uint256(UD2x18.unwrap(x))));
}

/// @notice Casts a UD2x18 number into UD60x18.
/// @dev There is no overflow check because the domain of UD2x18 is a subset of UD60x18.
function intoUD60x18(UD2x18 x) pure returns (UD60x18 result) {
    result = UD60x18.wrap(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint128.
/// @dev There is no overflow check because the domain of UD2x18 is a subset of uint128.
function intoUint128(UD2x18 x) pure returns (uint128 result) {
    result = uint128(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint256.
/// @dev There is no overflow check because the domain of UD2x18 is a subset of uint256.
function intoUint256(UD2x18 x) pure returns (uint256 result) {
    result = uint256(UD2x18.unwrap(x));
}

/// @notice Casts a UD2x18 number into uint40.
/// @dev Requirements:
/// - x must be less than or equal to `MAX_UINT40`.
function intoUint40(UD2x18 x) pure returns (uint40 result) {
    uint64 xUint = UD2x18.unwrap(x);
    if (xUint > uint64(Common.MAX_UINT40)) {
        revert Errors.PRBMath_UD2x18_IntoUint40_Overflow(x);
    }
    result = uint40(xUint);
}

/// @notice Alias for {wrap}.
function ud2x18(uint64 x) pure returns (UD2x18 result) {
    result = UD2x18.wrap(x);
}

/// @notice Unwrap a UD2x18 number into uint64.
function unwrap(UD2x18 x) pure returns (uint64 result) {
    result = UD2x18.unwrap(x);
}

/// @notice Wraps a uint64 number into UD2x18.
function wrap(uint64 x) pure returns (UD2x18 result) {
    result = UD2x18.wrap(x);
}

// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
// Code from https://github.com/ethereum/solidity-examples
pragma solidity 0.8.25;

library Bits {
    uint256 internal constant ONE = uint256(1);
    uint256 internal constant ONES = type(uint256).max;

    // Sets the bit at the given 'index' in 'self' to '1'.
    // Returns the modified value.
    function setBit(uint256 self, uint8 index) internal pure returns (uint256) {
        return self | (ONE << index);
    }

    // Sets the bit at the given 'index' in 'self' to '0'.
    // Returns the modified value.
    function clearBit(uint256 self, uint8 index) internal pure returns (uint256) {
        return self & ~(ONE << index);
    }

    // Sets the bit at the given 'index' in 'self' to:
    //  '1' - if the bit is '0'
    //  '0' - if the bit is '1'
    // Returns the modified value.
    function toggleBit(uint256 self, uint8 index) internal pure returns (uint256) {
        return self ^ (ONE << index);
    }

    // Get the value of the bit at the given 'index' in 'self'.
    function bit(uint256 self, uint8 index) internal pure returns (uint8) {
        return uint8((self >> index) & 1);
    }

    // Check if the bit at the given 'index' in 'self' is set.
    // Returns:
    //  'true' - if the value of the bit is '1'
    //  'false' - if the value of the bit is '0'
    function bitSet(uint256 self, uint8 index) internal pure returns (bool) {
        return (self >> index) & 1 == 1;
    }

    // Checks if the bit at the given 'index' in 'self' is equal to the corresponding
    // bit in 'other'.
    // Returns:
    //  'true' - if both bits are '0' or both bits are '1'
    //  'false' - otherwise
    function bitEqual(uint256 self, uint256 other, uint8 index) internal pure returns (bool) {
        return ((self ^ other) >> index) & 1 == 0;
    }

    // Get the bitwise NOT of the bit at the given 'index' in 'self'.
    function bitNot(uint256 self, uint8 index) internal pure returns (uint8) {
        return uint8(1 - ((self >> index) & 1));
    }

    // Computes the bitwise AND of the bit at the given 'index' in 'self', and the
    // corresponding bit in 'other', and returns the value.
    function bitAnd(uint256 self, uint256 other, uint8 index) internal pure returns (uint8) {
        return uint8(((self & other) >> index) & 1);
    }

    // Computes the bitwise OR of the bit at the given 'index' in 'self', and the
    // corresponding bit in 'other', and returns the value.
    function bitOr(uint256 self, uint256 other, uint8 index) internal pure returns (uint8) {
        return uint8(((self | other) >> index) & 1);
    }

    // Computes the bitwise XOR of the bit at the given 'index' in 'self', and the
    // corresponding bit in 'other', and returns the value.
    function bitXor(uint256 self, uint256 other, uint8 index) internal pure returns (uint8) {
        return uint8(((self ^ other) >> index) & 1);
    }

    // Gets 'numBits' consecutive bits from 'self', starting from the bit at 'startIndex'.
    // Returns the bits as a 'uint'.
    // Requires that:
    //  - '0 < numBits <= 256'
    //  - 'startIndex < 256'
    //  - 'numBits + startIndex <= 256'
    function bits(uint256 self, uint8 startIndex, uint16 numBits) internal pure returns (uint256) {
        require(0 < numBits && startIndex < 256 && startIndex + numBits <= 256, "out of bounds");
        return (self >> startIndex) & (ONES >> (256 - numBits));
    }

    // Computes the index of the highest bit set in 'self'.
    // Returns the highest bit set as an 'uint8'.
    // Requires that 'self != 0'.
    function highestBitSet(uint256 self) internal pure returns (uint8 highest) {
        require(self != 0, "should not be zero");
        uint256 val = self;
        for (uint8 i = 128; i >= 1; i >>= 1) {
            if (val & (((ONE << i) - 1) << i) != 0) {
                highest += i;
                val >>= i;
            }
        }
    }

    // Computes the index of the lowest bit set in 'self'.
    // Returns the lowest bit set as an 'uint8'.
    // Requires that 'self != 0'.
    function lowestBitSet(uint256 self) internal pure returns (uint8 lowest) {
        require(self != 0, "should not be zero");
        uint256 val = self;
        for (uint8 i = 128; i >= 1; i >>= 1) {
            if (val & ((ONE << i) - 1) == 0) {
                lowest += i;
                val >>= i;
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { SD1x18 } from "./ValueType.sol";

/// @notice Thrown when trying to cast a SD1x18 number that doesn't fit in UD2x18.
error PRBMath_SD1x18_ToUD2x18_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast a SD1x18 number that doesn't fit in UD60x18.
error PRBMath_SD1x18_ToUD60x18_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast a SD1x18 number that doesn't fit in uint128.
error PRBMath_SD1x18_ToUint128_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast a SD1x18 number that doesn't fit in uint256.
error PRBMath_SD1x18_ToUint256_Underflow(SD1x18 x);

/// @notice Thrown when trying to cast a SD1x18 number that doesn't fit in uint40.
error PRBMath_SD1x18_ToUint40_Overflow(SD1x18 x);

/// @notice Thrown when trying to cast a SD1x18 number that doesn't fit in uint40.
error PRBMath_SD1x18_ToUint40_Underflow(SD1x18 x);

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { SD59x18 } from "./ValueType.sol";

/// @notice Thrown when taking the absolute value of `MIN_SD59x18`.
error PRBMath_SD59x18_Abs_MinSD59x18();

/// @notice Thrown when ceiling a number overflows SD59x18.
error PRBMath_SD59x18_Ceil_Overflow(SD59x18 x);

/// @notice Thrown when converting a basic integer to the fixed-point format overflows SD59x18.
error PRBMath_SD59x18_Convert_Overflow(int256 x);

/// @notice Thrown when converting a basic integer to the fixed-point format underflows SD59x18.
error PRBMath_SD59x18_Convert_Underflow(int256 x);

/// @notice Thrown when dividing two numbers and one of them is `MIN_SD59x18`.
error PRBMath_SD59x18_Div_InputTooSmall();

/// @notice Thrown when dividing two numbers and one of the intermediary unsigned results overflows SD59x18.
error PRBMath_SD59x18_Div_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when taking the natural exponent of a base greater than 133_084258667509499441.
error PRBMath_SD59x18_Exp_InputTooBig(SD59x18 x);

/// @notice Thrown when taking the binary exponent of a base greater than 192e18.
error PRBMath_SD59x18_Exp2_InputTooBig(SD59x18 x);

/// @notice Thrown when flooring a number underflows SD59x18.
error PRBMath_SD59x18_Floor_Underflow(SD59x18 x);

/// @notice Thrown when taking the geometric mean of two numbers and their product is negative.
error PRBMath_SD59x18_Gm_NegativeProduct(SD59x18 x, SD59x18 y);

/// @notice Thrown when taking the geometric mean of two numbers and multiplying them overflows SD59x18.
error PRBMath_SD59x18_Gm_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD1x18.
error PRBMath_SD59x18_IntoSD1x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in SD1x18.
error PRBMath_SD59x18_IntoSD1x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in UD2x18.
error PRBMath_SD59x18_IntoUD2x18_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in UD2x18.
error PRBMath_SD59x18_IntoUD2x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in UD60x18.
error PRBMath_SD59x18_IntoUD60x18_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint128.
error PRBMath_SD59x18_IntoUint128_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint128.
error PRBMath_SD59x18_IntoUint128_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint256.
error PRBMath_SD59x18_IntoUint256_Underflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint40.
error PRBMath_SD59x18_IntoUint40_Overflow(SD59x18 x);

/// @notice Thrown when trying to cast a UD60x18 number that doesn't fit in uint40.
error PRBMath_SD59x18_IntoUint40_Underflow(SD59x18 x);

/// @notice Thrown when taking the logarithm of a number less than or equal to zero.
error PRBMath_SD59x18_Log_InputTooSmall(SD59x18 x);

/// @notice Thrown when multiplying two numbers and one of the inputs is `MIN_SD59x18`.
error PRBMath_SD59x18_Mul_InputTooSmall();

/// @notice Thrown when multiplying two numbers and the intermediary absolute result overflows SD59x18.
error PRBMath_SD59x18_Mul_Overflow(SD59x18 x, SD59x18 y);

/// @notice Thrown when raising a number to a power and the intermediary absolute result overflows SD59x18.
error PRBMath_SD59x18_Powu_Overflow(SD59x18 x, uint256 y);

/// @notice Thrown when taking the square root of a negative number.
error PRBMath_SD59x18_Sqrt_NegativeInput(SD59x18 x);

/// @notice Thrown when the calculating the square root overflows SD59x18.
error PRBMath_SD59x18_Sqrt_Overflow(SD59x18 x);

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { UD2x18 } from "./ValueType.sol";

/// @notice Thrown when trying to cast a UD2x18 number that doesn't fit in SD1x18.
error PRBMath_UD2x18_IntoSD1x18_Overflow(UD2x18 x);

/// @notice Thrown when trying to cast a UD2x18 number that doesn't fit in uint40.
error PRBMath_UD2x18_IntoUint40_Overflow(UD2x18 x);
