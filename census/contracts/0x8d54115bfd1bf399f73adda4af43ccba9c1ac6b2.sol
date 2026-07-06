// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {CapsEngine} from './libraries/CapsEngine.sol';
import {BorrowEngine} from './libraries/BorrowEngine.sol';
import {CollateralEngine} from './libraries/CollateralEngine.sol';
import {RateEngine} from './libraries/RateEngine.sol';
import {PriceFeedEngine} from './libraries/PriceFeedEngine.sol';
import {EModeEngine} from './libraries/EModeEngine.sol';
import {ListingEngine} from './libraries/ListingEngine.sol';
import './IAaveV3ConfigEngine.sol';

/**
 * @dev Helper smart contract abstracting the complexity of changing configurations on Aave v3, simplifying
 * - !!!IMPORTANT!!! This engine MUST BE STATELESS always, as in practise is a library to be used via DELEGATECALL
 * listing flow and parameters updates.
 * - It is planned to be used via delegatecall, by any contract having appropriate permissions to
 * do a listing, or any other granular config
 * Assumptions:
 * - Only one RewardsController for all assets
 * - Only one Collector for all assets
 * @author BGD Labs
 */
contract AaveV3ConfigEngine is IAaveV3ConfigEngine {
  using Address for address;

  IPool public immutable POOL;
  IPoolConfigurator public immutable POOL_CONFIGURATOR;
  IAaveOracle public immutable ORACLE;
  address public immutable ATOKEN_IMPL;
  address public immutable VTOKEN_IMPL;
  address public immutable REWARDS_CONTROLLER;
  address public immutable COLLECTOR;
  address public immutable DEFAULT_INTEREST_RATE_STRATEGY;

  address public immutable BORROW_ENGINE;
  address public immutable CAPS_ENGINE;
  address public immutable COLLATERAL_ENGINE;
  address public immutable EMODE_ENGINE;
  address public immutable LISTING_ENGINE;
  address public immutable PRICE_FEED_ENGINE;
  address public immutable RATE_ENGINE;

  /**
   * @dev Constructor.
   * @param aTokenImpl The address of default aToken implementation.
   * @param vTokenImpl The address of default variable debt token implementation.
   * @param engineConstants The struct containing all the engine constants.
   * @param engineLibraries The struct containing the addresses of stateless libraries containing the engine logic.
   */
  constructor(
    address aTokenImpl,
    address vTokenImpl,
    EngineConstants memory engineConstants,
    EngineLibraries memory engineLibraries
  ) {
    require(
      address(engineConstants.pool) != address(0) &&
        address(engineConstants.poolConfigurator) != address(0) &&
        address(engineConstants.oracle) != address(0) &&
        engineConstants.rewardsController != address(0) &&
        engineConstants.collector != address(0) &&
        engineConstants.defaultInterestRateStrategy != address(0),
      'ONLY_NONZERO_ENGINE_CONSTANTS'
    );

    require(aTokenImpl != address(0) && vTokenImpl != address(0), 'ONLY_NONZERO_TOKEN_IMPLS');

    require(
      engineLibraries.borrowEngine != address(0) &&
        engineLibraries.capsEngine != address(0) &&
        engineLibraries.listingEngine != address(0) &&
        engineLibraries.priceFeedEngine != address(0) &&
        engineLibraries.rateEngine != address(0),
      'ONLY_NONZERO_ENGINE_LIBRARIES'
    );

    ATOKEN_IMPL = aTokenImpl;
    VTOKEN_IMPL = vTokenImpl;
    POOL = engineConstants.pool;
    POOL_CONFIGURATOR = engineConstants.poolConfigurator;
    ORACLE = engineConstants.oracle;
    REWARDS_CONTROLLER = engineConstants.rewardsController;
    COLLECTOR = engineConstants.collector;
    DEFAULT_INTEREST_RATE_STRATEGY = engineConstants.defaultInterestRateStrategy;
    BORROW_ENGINE = engineLibraries.borrowEngine;
    CAPS_ENGINE = engineLibraries.capsEngine;
    COLLATERAL_ENGINE = engineLibraries.collateralEngine;
    EMODE_ENGINE = engineLibraries.eModeEngine;
    LISTING_ENGINE = engineLibraries.listingEngine;
    PRICE_FEED_ENGINE = engineLibraries.priceFeedEngine;
    RATE_ENGINE = engineLibraries.rateEngine;
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function listAssets(PoolContext calldata context, Listing[] calldata listings) external {
    require(listings.length != 0, 'AT_LEAST_ONE_ASSET_REQUIRED');

    ListingWithCustomImpl[] memory customListings = new ListingWithCustomImpl[](listings.length);
    for (uint256 i = 0; i < listings.length; i++) {
      customListings[i] = ListingWithCustomImpl({
        base: listings[i],
        implementations: TokenImplementations({aToken: ATOKEN_IMPL, vToken: VTOKEN_IMPL})
      });
    }

    listAssetsCustom(context, customListings);
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function listAssetsCustom(
    PoolContext calldata context,
    ListingWithCustomImpl[] memory listings
  ) public {
    LISTING_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        ListingEngine.executeCustomAssetListing.selector,
        context,
        _getEngineConstants(),
        _getEngineLibraries(),
        listings
      )
    );
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function updateCaps(CapsUpdate[] calldata updates) external {
    CAPS_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(CapsEngine.executeCapsUpdate.selector, _getEngineConstants(), updates)
    );
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function updatePriceFeeds(PriceFeedUpdate[] calldata updates) external {
    PRICE_FEED_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        PriceFeedEngine.executePriceFeedsUpdate.selector,
        _getEngineConstants(),
        updates
      )
    );
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function updateCollateralSide(CollateralUpdate[] calldata updates) external {
    COLLATERAL_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        CollateralEngine.executeCollateralSide.selector,
        _getEngineConstants(),
        updates
      )
    );
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function updateBorrowSide(BorrowUpdate[] calldata updates) external {
    BORROW_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        BorrowEngine.executeBorrowSide.selector,
        _getEngineConstants(),
        updates
      )
    );
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function updateRateStrategies(RateStrategyUpdate[] calldata updates) external {
    RATE_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        RateEngine.executeRateStrategiesUpdate.selector,
        _getEngineConstants(),
        updates
      )
    );
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function createEModeCategories(EModeCategoryCreation[] calldata creations) external {
    EMODE_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        EModeEngine.executeEModeCategoriesCreate.selector,
        _getEngineConstants(),
        creations
      )
    );
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function updateEModeCategories(EModeCategoryUpdate[] calldata updates) external {
    EMODE_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        EModeEngine.executeEModeCategoriesUpdate.selector,
        _getEngineConstants(),
        updates
      )
    );
  }

  /// @inheritdoc IAaveV3ConfigEngine
  function updateAssetsEMode(AssetEModeUpdate[] calldata updates) external {
    EMODE_ENGINE.functionDelegateCall(
      abi.encodeWithSelector(
        EModeEngine.executeAssetsEModeUpdate.selector,
        _getEngineConstants(),
        updates
      )
    );
  }

  function _getEngineLibraries() internal view returns (EngineLibraries memory) {
    return
      EngineLibraries({
        listingEngine: LISTING_ENGINE,
        eModeEngine: EMODE_ENGINE,
        borrowEngine: BORROW_ENGINE,
        collateralEngine: COLLATERAL_ENGINE,
        priceFeedEngine: PRICE_FEED_ENGINE,
        rateEngine: RATE_ENGINE,
        capsEngine: CAPS_ENGINE
      });
  }

  function _getEngineConstants() internal view returns (EngineConstants memory) {
    return
      EngineConstants({
        pool: POOL,
        poolConfigurator: POOL_CONFIGURATOR,
        defaultInterestRateStrategy: DEFAULT_INTEREST_RATE_STRATEGY,
        oracle: ORACLE,
        rewardsController: REWARDS_CONTROLLER,
        collector: COLLECTOR
      });
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Address.sol)

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

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert Errors.FailedCall();
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {EngineFlags} from '../EngineFlags.sol';
import {IAaveV3ConfigEngine as IEngine, IPoolConfigurator} from '../IAaveV3ConfigEngine.sol';

library CapsEngine {
  function executeCapsUpdate(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.CapsUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    _configureCaps(engineConstants.poolConfigurator, updates);
  }

  function _configureCaps(
    IPoolConfigurator poolConfigurator,
    IEngine.CapsUpdate[] memory caps
  ) internal {
    for (uint256 i = 0; i < caps.length; i++) {
      if (caps[i].supplyCap != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setSupplyCap(caps[i].asset, caps[i].supplyCap);
      }

      if (caps[i].borrowCap != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setBorrowCap(caps[i].asset, caps[i].borrowCap);
      }
    }
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {EngineFlags} from '../EngineFlags.sol';
import {DataTypes} from '../../../protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '../../../protocol/libraries/configuration/ReserveConfiguration.sol';
import {IAaveV3ConfigEngine as IEngine, IPoolConfigurator, IPool} from '../IAaveV3ConfigEngine.sol';

library BorrowEngine {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function executeBorrowSide(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.BorrowUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    _configBorrowSide(engineConstants.poolConfigurator, engineConstants.pool, updates);
  }

  function _configBorrowSide(
    IPoolConfigurator poolConfigurator,
    IPool pool,
    IEngine.BorrowUpdate[] memory updates
  ) internal {
    for (uint256 i = 0; i < updates.length; i++) {
      if (updates[i].enabledToBorrow != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setReserveBorrowing(
          updates[i].asset,
          EngineFlags.toBool(updates[i].enabledToBorrow)
        );
      } else {
        (, , bool borrowingEnabled, ) = pool.getConfiguration(updates[i].asset).getFlags();
        updates[i].enabledToBorrow = EngineFlags.fromBool(borrowingEnabled);
      }

      if (updates[i].borrowableInIsolation != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setBorrowableInIsolation(
          updates[i].asset,
          EngineFlags.toBool(updates[i].borrowableInIsolation)
        );
      }

      if (updates[i].withSiloedBorrowing != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setSiloedBorrowing(
          updates[i].asset,
          EngineFlags.toBool(updates[i].withSiloedBorrowing)
        );
      }

      // The reserve factor should always be > 0
      require(
        (updates[i].reserveFactor > 0 && updates[i].reserveFactor <= 100_00) ||
          updates[i].reserveFactor == EngineFlags.KEEP_CURRENT,
        'INVALID_RESERVE_FACTOR'
      );

      if (updates[i].reserveFactor != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setReserveFactor(updates[i].asset, updates[i].reserveFactor);
      }

      if (updates[i].flashloanable != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setReserveFlashLoaning(
          updates[i].asset,
          EngineFlags.toBool(updates[i].flashloanable)
        );
      }
    }
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {DataTypes} from '../../../protocol/libraries/types/DataTypes.sol';
import {ReserveConfiguration} from '../../../protocol/libraries/configuration/ReserveConfiguration.sol';
import {IAaveV3ConfigEngine as IEngine, IPoolConfigurator, IPool} from '../IAaveV3ConfigEngine.sol';
import {PercentageMath} from '../../../protocol/libraries/math/PercentageMath.sol';
import {EngineFlags} from '../EngineFlags.sol';

library CollateralEngine {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using PercentageMath for uint256;

  function executeCollateralSide(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.CollateralUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    _configCollateralSide(engineConstants.poolConfigurator, engineConstants.pool, updates);
  }

  function _configCollateralSide(
    IPoolConfigurator poolConfigurator,
    IPool pool,
    IEngine.CollateralUpdate[] memory updates
  ) internal {
    for (uint256 i = 0; i < updates.length; i++) {
      if (updates[i].liqThreshold != 0) {
        bool notAllKeepCurrent = updates[i].ltv != EngineFlags.KEEP_CURRENT ||
          updates[i].liqThreshold != EngineFlags.KEEP_CURRENT ||
          updates[i].liqBonus != EngineFlags.KEEP_CURRENT;

        bool atLeastOneKeepCurrent = updates[i].ltv == EngineFlags.KEEP_CURRENT ||
          updates[i].liqThreshold == EngineFlags.KEEP_CURRENT ||
          updates[i].liqBonus == EngineFlags.KEEP_CURRENT;

        if (notAllKeepCurrent && atLeastOneKeepCurrent) {
          DataTypes.ReserveConfigurationMap memory configuration = pool.getConfiguration(
            updates[i].asset
          );
          (
            uint256 currentLtv,
            uint256 currentLiqThreshold,
            uint256 currentLiqBonus,
            ,

          ) = configuration.getParams();

          if (updates[i].ltv == EngineFlags.KEEP_CURRENT) {
            updates[i].ltv = currentLtv;
          }

          if (updates[i].liqThreshold == EngineFlags.KEEP_CURRENT) {
            updates[i].liqThreshold = currentLiqThreshold;
          }

          if (updates[i].liqBonus == EngineFlags.KEEP_CURRENT) {
            // Subtracting 100_00 to be consistent with the engine as 100_00 gets added while setting the liqBonus
            updates[i].liqBonus = currentLiqBonus - 100_00;
          }
        }

        if (notAllKeepCurrent) {
          // LT*LB (in %) should never be above 100%, because it means instant undercollateralization
          require(
            updates[i].liqThreshold.percentMul(100_00 + updates[i].liqBonus) <= 100_00,
            'INVALID_LT_LB_RATIO'
          );

          poolConfigurator.configureReserveAsCollateral(
            updates[i].asset,
            updates[i].ltv,
            updates[i].liqThreshold,
            // For reference, this is to simplify the interaction with the Aave protocol,
            // as there the definition is as e.g. 105% (5% bonus for liquidators)
            100_00 + updates[i].liqBonus
          );
        }

        if (updates[i].liqProtocolFee != EngineFlags.KEEP_CURRENT) {
          require(updates[i].liqProtocolFee < 100_00, 'INVALID_LIQ_PROTOCOL_FEE');
          poolConfigurator.setLiquidationProtocolFee(updates[i].asset, updates[i].liqProtocolFee);
        }

        if (updates[i].debtCeiling != EngineFlags.KEEP_CURRENT) {
          // For reference, this is to simplify the interactions with the Aave protocol,
          // as there the definition is with 2 decimals. We don't see any reason to set
          // a debt ceiling involving .something USD, so we simply don't allow to do it
          poolConfigurator.setDebtCeiling(updates[i].asset, updates[i].debtCeiling * 100);
        }
      }
    }
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IDefaultInterestRateStrategyV2} from '../../../interfaces/IDefaultInterestRateStrategyV2.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {EngineFlags} from '../EngineFlags.sol';
import {IAaveV3ConfigEngine as IEngine, IPoolConfigurator} from '../IAaveV3ConfigEngine.sol';

library RateEngine {
  using SafeCast for uint256;

  function executeRateStrategiesUpdate(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.RateStrategyUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    (address[] memory ids, IEngine.InterestRateInputData[] memory rates) = _unpackRatesUpdate(
      updates
    );

    _configRateStrategies(
      IDefaultInterestRateStrategyV2(engineConstants.defaultInterestRateStrategy),
      engineConstants.poolConfigurator,
      ids,
      rates
    );
  }

  function _configRateStrategies(
    IDefaultInterestRateStrategyV2 rateStrategy,
    IPoolConfigurator poolConfigurator,
    address[] memory ids,
    IEngine.InterestRateInputData[] memory strategiesParams
  ) internal {
    for (uint256 i = 0; i < strategiesParams.length; i++) {
      address asset = ids[i];
      IEngine.InterestRateInputData memory strategyParams = strategiesParams[i];

      bool atLeastOneKeepCurrent = strategyParams.optimalUsageRatio == EngineFlags.KEEP_CURRENT ||
        strategyParams.baseVariableBorrowRate == EngineFlags.KEEP_CURRENT ||
        strategyParams.variableRateSlope1 == EngineFlags.KEEP_CURRENT ||
        strategyParams.variableRateSlope2 == EngineFlags.KEEP_CURRENT;

      if (atLeastOneKeepCurrent) {
        IDefaultInterestRateStrategyV2.InterestRateData
          memory currentStrategyData = IDefaultInterestRateStrategyV2(rateStrategy)
            .getInterestRateDataBps(asset);

        if (strategyParams.variableRateSlope1 == EngineFlags.KEEP_CURRENT) {
          strategyParams.variableRateSlope1 = currentStrategyData.variableRateSlope1;
        }

        if (strategyParams.variableRateSlope2 == EngineFlags.KEEP_CURRENT) {
          strategyParams.variableRateSlope2 = currentStrategyData.variableRateSlope2;
        }

        if (strategyParams.optimalUsageRatio == EngineFlags.KEEP_CURRENT) {
          strategyParams.optimalUsageRatio = currentStrategyData.optimalUsageRatio;
        }

        if (strategyParams.baseVariableBorrowRate == EngineFlags.KEEP_CURRENT) {
          strategyParams.baseVariableBorrowRate = currentStrategyData.baseVariableBorrowRate;
        }
      }

      poolConfigurator.setReserveInterestRateData(
        asset,
        abi.encode(
          IDefaultInterestRateStrategyV2.InterestRateData({
            optimalUsageRatio: strategyParams.optimalUsageRatio.toUint16(),
            baseVariableBorrowRate: strategyParams.baseVariableBorrowRate.toUint32(),
            variableRateSlope1: strategyParams.variableRateSlope1.toUint32(),
            variableRateSlope2: strategyParams.variableRateSlope2.toUint32()
          })
        )
      );
    }
  }

  function _unpackRatesUpdate(
    IEngine.RateStrategyUpdate[] memory updates
  ) internal pure returns (address[] memory, IEngine.InterestRateInputData[] memory) {
    address[] memory ids = new address[](updates.length);
    IEngine.InterestRateInputData[] memory rates = new IEngine.InterestRateInputData[](
      updates.length
    );

    for (uint256 i = 0; i < updates.length; i++) {
      ids[i] = updates[i].asset;
      rates[i] = updates[i].params;
    }
    return (ids, rates);
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IAaveV3ConfigEngine as IEngine, IAaveOracle} from '../IAaveV3ConfigEngine.sol';
import {AggregatorInterface} from '../../../dependencies/chainlink/AggregatorInterface.sol';

library PriceFeedEngine {
  function executePriceFeedsUpdate(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.PriceFeedUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    _setPriceFeeds(engineConstants.oracle, updates);
  }

  function _setPriceFeeds(IAaveOracle oracle, IEngine.PriceFeedUpdate[] memory updates) internal {
    address[] memory assets = new address[](updates.length);
    address[] memory sources = new address[](updates.length);

    for (uint256 i = 0; i < updates.length; i++) {
      require(updates[i].priceFeed != address(0), 'PRICE_FEED_ALWAYS_REQUIRED');
      require(
        AggregatorInterface(updates[i].priceFeed).latestAnswer() > 0,
        'FEED_SHOULD_RETURN_POSITIVE_PRICE'
      );
      assets[i] = updates[i].asset;
      sources[i] = updates[i].priceFeed;
    }

    oracle.setAssetSources(assets, sources);
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';
import {EngineFlags} from '../EngineFlags.sol';
import {DataTypes} from '../../../protocol/libraries/types/DataTypes.sol';
import {PercentageMath} from '../../../protocol/libraries/math/PercentageMath.sol';
import {IAaveV3ConfigEngine as IEngine, IPoolConfigurator, IPool} from '../IAaveV3ConfigEngine.sol';

library EModeEngine {
  using PercentageMath for uint256;
  using SafeCast for uint256;

  error NoAvailableEmodeCategory();

  function executeAssetsEModeUpdate(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.AssetEModeUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    _configAssetsEMode(engineConstants.poolConfigurator, engineConstants.pool, updates);
  }

  function executeEModeCategoriesCreate(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.EModeCategoryCreation[] memory creations
  ) external {
    for (uint256 i; i < creations.length; i++) {
      require(
        keccak256(abi.encode(creations[i].label)) !=
          keccak256(abi.encode(EngineFlags.KEEP_CURRENT_STRING)),
        'INVALID_LABEL'
      );
      uint8 categoryId = _findFirstUnusedEmodeCategory(engineConstants.pool);
      engineConstants.poolConfigurator.setEModeCategory(
        categoryId,
        creations[i].ltv.toUint16(),
        creations[i].liqThreshold.toUint16(),
        // For reference, this is to simplify the interaction with the Aave protocol,
        // as there the definition is as e.g. 105% (5% bonus for liquidators)
        (100_00 + creations[i].liqBonus).toUint16(),
        creations[i].label
      );
      for (uint256 j; j < creations[i].collaterals.length; j++) {
        engineConstants.poolConfigurator.setAssetCollateralInEMode(
          creations[i].collaterals[j],
          categoryId,
          true
        );
      }
      for (uint256 k; k < creations[i].borrowables.length; k++) {
        engineConstants.poolConfigurator.setAssetBorrowableInEMode(
          creations[i].borrowables[k],
          categoryId,
          true
        );
      }
    }
  }

  function executeEModeCategoriesUpdate(
    IEngine.EngineConstants calldata engineConstants,
    IEngine.EModeCategoryUpdate[] memory updates
  ) external {
    require(updates.length != 0, 'AT_LEAST_ONE_UPDATE_REQUIRED');

    _configEModeCategories(engineConstants.poolConfigurator, engineConstants.pool, updates);
  }

  function _configAssetsEMode(
    IPoolConfigurator poolConfigurator,
    IPool pool,
    IEngine.AssetEModeUpdate[] memory updates
  ) internal {
    for (uint256 i = 0; i < updates.length; i++) {
      DataTypes.CollateralConfig memory cfg = pool.getEModeCategoryCollateralConfig(
        updates[i].eModeCategory
      );
      require(cfg.liquidationThreshold != 0, 'INVALID_UPDATE');
      if (updates[i].collateral != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setAssetCollateralInEMode(
          updates[i].asset,
          updates[i].eModeCategory,
          EngineFlags.toBool(updates[i].collateral)
        );
      }
      if (updates[i].borrowable != EngineFlags.KEEP_CURRENT) {
        poolConfigurator.setAssetBorrowableInEMode(
          updates[i].asset,
          updates[i].eModeCategory,
          EngineFlags.toBool(updates[i].borrowable)
        );
      }
    }
  }

  function _configEModeCategories(
    IPoolConfigurator poolConfigurator,
    IPool pool,
    IEngine.EModeCategoryUpdate[] memory updates
  ) internal {
    for (uint256 i = 0; i < updates.length; i++) {
      bool atLeastOneKeepCurrent = updates[i].ltv == EngineFlags.KEEP_CURRENT ||
        updates[i].liqThreshold == EngineFlags.KEEP_CURRENT ||
        updates[i].liqBonus == EngineFlags.KEEP_CURRENT ||
        keccak256(abi.encode(updates[i].label)) ==
        keccak256(abi.encode(EngineFlags.KEEP_CURRENT_STRING));

      bool notAllKeepCurrent = updates[i].ltv != EngineFlags.KEEP_CURRENT ||
        updates[i].liqThreshold != EngineFlags.KEEP_CURRENT ||
        updates[i].liqBonus != EngineFlags.KEEP_CURRENT ||
        keccak256(abi.encode(updates[i].label)) !=
        keccak256(abi.encode(EngineFlags.KEEP_CURRENT_STRING));

      DataTypes.CollateralConfig memory cfg = pool.getEModeCategoryCollateralConfig(
        updates[i].eModeCategory
      );
      // should only be able to update existing eModes, not create new ones
      require(cfg.liquidationThreshold != 0, 'INVALID_UPDATE');

      if (notAllKeepCurrent && atLeastOneKeepCurrent) {
        if (updates[i].ltv == EngineFlags.KEEP_CURRENT) {
          updates[i].ltv = cfg.ltv;
        }

        if (updates[i].liqThreshold == EngineFlags.KEEP_CURRENT) {
          updates[i].liqThreshold = cfg.liquidationThreshold;
        }

        if (updates[i].liqBonus == EngineFlags.KEEP_CURRENT) {
          // Subtracting 100_00 to be consistent with the engine as 100_00 gets added while setting the liqBonus
          updates[i].liqBonus = cfg.liquidationBonus - 100_00;
        }

        if (
          keccak256(abi.encode(updates[i].label)) ==
          keccak256(abi.encode(EngineFlags.KEEP_CURRENT_STRING))
        ) {
          updates[i].label = pool.getEModeCategoryLabel(updates[i].eModeCategory);
        }
      }

      if (notAllKeepCurrent) {
        // LT*LB (in %) should never be above 100%, because it means instant undercollateralization
        require(
          updates[i].liqThreshold.percentMul(100_00 + updates[i].liqBonus) <= 100_00,
          'INVALID_LT_LB_RATIO'
        );

        poolConfigurator.setEModeCategory(
          updates[i].eModeCategory,
          updates[i].ltv.toUint16(),
          updates[i].liqThreshold.toUint16(),
          // For reference, this is to simplify the interaction with the Aave protocol,
          // as there the definition is as e.g. 105% (5% bonus for liquidators)
          (100_00 + updates[i].liqBonus).toUint16(),
          updates[i].label
        );
      }
    }
  }

  /**
   * @dev eModes must have a non-zero lt so we select the first that has a zero lt.
   */
  function _findFirstUnusedEmodeCategory(IPool pool) private view returns (uint8) {
    // eMode id 0 is skipped intentially as it is the reserved default
    for (uint8 i = 1; i < 256; i++) {
      if (pool.getEModeCategoryCollateralConfig(i).liquidationThreshold == 0) return i;
    }
    revert NoAvailableEmodeCategory();
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {Address} from 'openzeppelin-contracts/contracts/utils/Address.sol';
import {IAaveV3ConfigEngine as IEngine, IPoolConfigurator, IPool, IDefaultInterestRateStrategyV2} from '../IAaveV3ConfigEngine.sol';
import {PriceFeedEngine} from './PriceFeedEngine.sol';
import {CapsEngine} from './CapsEngine.sol';
import {BorrowEngine} from './BorrowEngine.sol';
import {CollateralEngine} from './CollateralEngine.sol';
import {EModeEngine} from './EModeEngine.sol';
import {ConfiguratorInputTypes} from '../../../protocol/libraries/types/ConfiguratorInputTypes.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';

library ListingEngine {
  using Address for address;
  using SafeCast for uint256;

  function executeCustomAssetListing(
    IEngine.PoolContext calldata context,
    IEngine.EngineConstants calldata engineConstants,
    IEngine.EngineLibraries calldata engineLibraries,
    IEngine.ListingWithCustomImpl[] calldata listings
  ) external {
    require(listings.length != 0, 'AT_LEAST_ONE_ASSET_REQUIRED');

    IEngine.RepackedListings memory repacked = _repackListing(listings);

    engineLibraries.priceFeedEngine.functionDelegateCall(
      abi.encodeWithSelector(
        PriceFeedEngine.executePriceFeedsUpdate.selector,
        engineConstants,
        repacked.priceFeedsUpdates
      )
    );

    _initAssets(
      context,
      engineConstants.poolConfigurator,
      repacked.ids,
      repacked.basics,
      repacked.rates
    );

    engineLibraries.capsEngine.functionDelegateCall(
      abi.encodeWithSelector(
        CapsEngine.executeCapsUpdate.selector,
        engineConstants,
        repacked.capsUpdates
      )
    );

    engineLibraries.borrowEngine.functionDelegateCall(
      abi.encodeWithSelector(
        BorrowEngine.executeBorrowSide.selector,
        engineConstants,
        repacked.borrowsUpdates
      )
    );

    engineLibraries.collateralEngine.functionDelegateCall(
      abi.encodeWithSelector(
        CollateralEngine.executeCollateralSide.selector,
        engineConstants,
        repacked.collateralsUpdates
      )
    );
  }

  function _repackListing(
    IEngine.ListingWithCustomImpl[] calldata listings
  ) internal pure returns (IEngine.RepackedListings memory) {
    address[] memory ids = new address[](listings.length);
    IEngine.BorrowUpdate[] memory borrowsUpdates = new IEngine.BorrowUpdate[](listings.length);
    IEngine.CollateralUpdate[] memory collateralsUpdates = new IEngine.CollateralUpdate[](
      listings.length
    );
    IEngine.PriceFeedUpdate[] memory priceFeedsUpdates = new IEngine.PriceFeedUpdate[](
      listings.length
    );
    IEngine.CapsUpdate[] memory capsUpdates = new IEngine.CapsUpdate[](listings.length);

    IEngine.Basic[] memory basics = new IEngine.Basic[](listings.length);
    IDefaultInterestRateStrategyV2.InterestRateData[]
      memory rates = new IDefaultInterestRateStrategyV2.InterestRateData[](listings.length);

    for (uint256 i = 0; i < listings.length; i++) {
      require(listings[i].base.asset != address(0), 'INVALID_ASSET');
      ids[i] = listings[i].base.asset;
      basics[i] = IEngine.Basic({
        assetSymbol: listings[i].base.assetSymbol,
        implementations: listings[i].implementations
      });
      priceFeedsUpdates[i] = IEngine.PriceFeedUpdate({
        asset: listings[i].base.asset,
        priceFeed: listings[i].base.priceFeed
      });
      borrowsUpdates[i] = IEngine.BorrowUpdate({
        asset: listings[i].base.asset,
        enabledToBorrow: listings[i].base.enabledToBorrow,
        flashloanable: listings[i].base.flashloanable,
        borrowableInIsolation: listings[i].base.borrowableInIsolation,
        withSiloedBorrowing: listings[i].base.withSiloedBorrowing,
        reserveFactor: listings[i].base.reserveFactor
      });
      collateralsUpdates[i] = IEngine.CollateralUpdate({
        asset: listings[i].base.asset,
        ltv: listings[i].base.ltv,
        liqThreshold: listings[i].base.liqThreshold,
        liqBonus: listings[i].base.liqBonus,
        debtCeiling: listings[i].base.debtCeiling,
        liqProtocolFee: listings[i].base.liqProtocolFee
      });
      capsUpdates[i] = IEngine.CapsUpdate({
        asset: listings[i].base.asset,
        supplyCap: listings[i].base.supplyCap,
        borrowCap: listings[i].base.borrowCap
      });
      rates[i] = IDefaultInterestRateStrategyV2.InterestRateData({
        optimalUsageRatio: listings[i].base.rateStrategyParams.optimalUsageRatio.toUint16(),
        baseVariableBorrowRate: listings[i]
          .base
          .rateStrategyParams
          .baseVariableBorrowRate
          .toUint32(),
        variableRateSlope1: listings[i].base.rateStrategyParams.variableRateSlope1.toUint32(),
        variableRateSlope2: listings[i].base.rateStrategyParams.variableRateSlope2.toUint32()
      });
    }

    return
      IEngine.RepackedListings(
        ids,
        basics,
        borrowsUpdates,
        collateralsUpdates,
        priceFeedsUpdates,
        capsUpdates,
        rates
      );
  }

  /// @dev mandatory configurations for any asset getting listed, including oracle config and basic init
  function _initAssets(
    IEngine.PoolContext calldata context,
    IPoolConfigurator poolConfigurator,
    address[] memory ids,
    IEngine.Basic[] memory basics,
    IDefaultInterestRateStrategyV2.InterestRateData[] memory rates
  ) internal {
    ConfiguratorInputTypes.InitReserveInput[]
      memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](ids.length);

    for (uint256 i = 0; i < ids.length; i++) {
      initReserveInputs[i] = ConfiguratorInputTypes.InitReserveInput({
        aTokenImpl: basics[i].implementations.aToken,
        variableDebtTokenImpl: basics[i].implementations.vToken,
        interestRateData: abi.encode(rates[i]),
        underlyingAsset: ids[i],
        aTokenName: string.concat('Aave ', context.networkName, ' ', basics[i].assetSymbol),
        aTokenSymbol: string.concat('a', context.networkAbbreviation, basics[i].assetSymbol),
        variableDebtTokenName: string.concat(
          'Aave ',
          context.networkName,
          ' Variable Debt ',
          basics[i].assetSymbol
        ),
        variableDebtTokenSymbol: string.concat(
          'variableDebt',
          context.networkAbbreviation,
          basics[i].assetSymbol
        ),
        params: bytes('')
      });
    }
    poolConfigurator.initReserves(initReserveInputs);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IPool} from '../../interfaces/IPool.sol';
import {IPoolConfigurator} from '../../interfaces/IPoolConfigurator.sol';
import {IAaveOracle} from '../../interfaces/IAaveOracle.sol';
import {IDefaultInterestRateStrategyV2} from '../../interfaces/IDefaultInterestRateStrategyV2.sol';

/// @dev Examples here assume the usage of the `AaveV3Payload` base contracts
/// contained in this same repository
interface IAaveV3ConfigEngine {
  struct Basic {
    string assetSymbol;
    TokenImplementations implementations;
  }

  struct EngineLibraries {
    address listingEngine;
    address eModeEngine;
    address borrowEngine;
    address collateralEngine;
    address priceFeedEngine;
    address rateEngine;
    address capsEngine;
  }

  struct EngineConstants {
    IPool pool;
    IPoolConfigurator poolConfigurator;
    IAaveOracle oracle;
    address rewardsController;
    address collector;
    address defaultInterestRateStrategy;
  }

  struct InterestRateInputData {
    uint256 optimalUsageRatio;
    uint256 baseVariableBorrowRate;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
  }

  /**
   * @dev Required for naming of a/v/s tokens
   * Example (mock):
   * PoolContext({
   *   networkName: 'Polygon',
   *   networkAbbreviation: 'Pol'
   * })
   */
  struct PoolContext {
    string networkName;
    string networkAbbreviation;
  }

  /**
   * @dev Example (mock):
   * Listing({
   *   asset: 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
   *   assetSymbol: 'AAVE',
   *   priceFeed: 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9,
   *   rateStrategyParams: InterestRateInputData({
   *     optimalUsageRatio: 80_00,
   *     baseVariableBorrowRate: 25, // 0.25%
   *     variableRateSlope1: 3_00,
   *     variableRateSlope2: 75_00
   *   }),
   *   enabledToBorrow: EngineFlags.ENABLED,
   *   flashloanable: EngineFlags.ENABLED,
   *   borrowableInIsolation: EngineFlags.ENABLED,
   *   withSiloedBorrowing:, EngineFlags.DISABLED,
   *   ltv: 70_50, // 70.5%
   *   liqThreshold: 76_00, // 76%
   *   liqBonus: 5_00, // 5%
   *   reserveFactor: 10_00, // 10%
   *   supplyCap: 100_000, // 100k AAVE
   *   borrowCap: 60_000, // 60k AAVE
   *   debtCeiling: 100_000, // 100k USD
   *   liqProtocolFee: 10_00, // 10%
   *   eModeCategory: 0, // No category
   * }
   */
  struct Listing {
    address asset;
    string assetSymbol;
    address priceFeed;
    InterestRateInputData rateStrategyParams; // Mandatory, no matter if enabled for borrowing or not
    uint256 enabledToBorrow;
    uint256 borrowableInIsolation; // Only considered is enabledToBorrow == EngineFlags.ENABLED (true)
    uint256 withSiloedBorrowing; // Only considered if enabledToBorrow == EngineFlags.ENABLED (true)
    uint256 flashloanable; // Independent from enabled to borrow: an asset can be flashloanble and not enabled to borrow
    uint256 ltv; // Only considered if liqThreshold > 0
    uint256 liqThreshold; // If `0`, the asset will not be enabled as collateral
    uint256 liqBonus; // Only considered if liqThreshold > 0
    uint256 reserveFactor; // Only considered if enabledToBorrow == EngineFlags.ENABLED (true)
    uint256 supplyCap; // If passing any value distinct to EngineFlags.KEEP_CURRENT, always configured
    uint256 borrowCap; // If passing any value distinct to EngineFlags.KEEP_CURRENT, always configured
    uint256 debtCeiling; // Only considered if liqThreshold > 0
    uint256 liqProtocolFee; // Only considered if liqThreshold > 0
  }

  struct RepackedListings {
    address[] ids;
    Basic[] basics;
    BorrowUpdate[] borrowsUpdates;
    CollateralUpdate[] collateralsUpdates;
    PriceFeedUpdate[] priceFeedsUpdates;
    CapsUpdate[] capsUpdates;
    IDefaultInterestRateStrategyV2.InterestRateData[] rates;
  }

  struct TokenImplementations {
    address aToken;
    address vToken;
  }

  struct ListingWithCustomImpl {
    Listing base;
    TokenImplementations implementations;
  }

  /**
   * @dev Example (mock):
   * CapsUpdate({
   *   asset: AaveV3EthereumAssets.AAVE_UNDERLYING,
   *   supplyCap: 1_000_000,
   *   borrowCap: EngineFlags.KEEP_CURRENT
   * }
   */
  struct CapsUpdate {
    address asset;
    uint256 supplyCap; // Pass any value, of EngineFlags.KEEP_CURRENT to keep it as it is
    uint256 borrowCap; // Pass any value, of EngineFlags.KEEP_CURRENT to keep it as it is
  }

  /**
   * @dev Example (mock):
   * PriceFeedUpdate({
   *   asset: AaveV3EthereumAssets.AAVE_UNDERLYING,
   *   priceFeed: 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9
   * })
   */
  struct PriceFeedUpdate {
    address asset;
    address priceFeed;
  }

  /**
   * @dev Example (mock):
   * CollateralUpdate({
   *   asset: AaveV3EthereumAssets.AAVE_UNDERLYING,
   *   ltv: 60_00,
   *   liqThreshold: 70_00,
   *   liqBonus: EngineFlags.KEEP_CURRENT,
   *   debtCeiling: EngineFlags.KEEP_CURRENT,
   *   liqProtocolFee: 7_00
   * })
   */
  struct CollateralUpdate {
    address asset;
    uint256 ltv;
    uint256 liqThreshold;
    uint256 liqBonus;
    uint256 debtCeiling;
    uint256 liqProtocolFee;
  }

  /**
   * @dev Example (mock):
   * BorrowUpdate({
   *   asset: AaveV3EthereumAssets.AAVE_UNDERLYING,
   *   enabledToBorrow: EngineFlags.ENABLED,
   *   flashloanable: EngineFlags.KEEP_CURRENT,
   *   borrowableInIsolation: EngineFlags.KEEP_CURRENT,
   *   withSiloedBorrowing: EngineFlags.KEEP_CURRENT,
   *   reserveFactor: 15_00, // 15%
   * })
   */
  struct BorrowUpdate {
    address asset;
    uint256 enabledToBorrow;
    uint256 flashloanable;
    uint256 borrowableInIsolation;
    uint256 withSiloedBorrowing;
    uint256 reserveFactor;
  }

  /**
   * @dev Example (mock):
   * AssetEModeUpdate({
   *   asset: AaveV3EthereumAssets.rETH_UNDERLYING,
   *   eModeCategory: 1, // ETH correlated
   *   borrowable: EngineFlags.ENABLED,
   *   collateral: EngineFlags.KEEP_CURRENT,
   * })
   */
  struct AssetEModeUpdate {
    address asset;
    uint8 eModeCategory;
    uint256 borrowable;
    uint256 collateral;
  }

  /**
   * @dev Example (mock):
   * EModeCategoryUpdate({
   *   eModeCategory: 1, // ETH correlated
   *   ltv: 60_00,
   *   liqThreshold: 70_00,
   *   liqBonus: EngineFlags.KEEP_CURRENT,
   *   label: EngineFlags.KEEP_CURRENT_STRING
   * })
   */
  struct EModeCategoryUpdate {
    uint8 eModeCategory;
    uint256 ltv;
    uint256 liqThreshold;
    uint256 liqBonus;
    string label;
  }

  /**
   * @dev Example (mock):
   * EModeCategoryUpdate({
   *   ltv: 60_00,
   *   liqThreshold: 70_00,
   *   liqBonus: 3_00,
   *   label: 'WETH USDC',
   *   borrowables:[USDC],
   *   collaterals:[ETH]
   * })
   */
  struct EModeCategoryCreation {
    uint256 ltv;
    uint256 liqThreshold;
    uint256 liqBonus;
    string label;
    address[] borrowables;
    address[] collaterals;
  }

  /**
   * @dev Example (mock):
   * RateStrategyUpdate({
   *   asset: AaveV3OptimismAssets.USDT_UNDERLYING,
   *   params: InterestRateInputData({
   *     optimalUsageRatio: _bpsToRay(80_00),
   *     baseVariableBorrowRate: EngineFlags.KEEP_CURRENT,
   *     variableRateSlope1: EngineFlags.KEEP_CURRENT,
   *     variableRateSlope2: _bpsToRay(75_00)
   *   })
   * })
   */
  struct RateStrategyUpdate {
    address asset;
    InterestRateInputData params;
  }

  /**
   * @notice Performs full listing of the assets, in the Aave pool configured in this engine instance
   * @param context `PoolContext` struct, effectively meta-data for naming of a/v/s tokens.
   *   More information on the documentation of the struct.
   * @param listings `Listing[]` list of declarative configs for every aspect of the asset listings.
   *   More information on the documentation of the struct.
   */
  function listAssets(PoolContext memory context, Listing[] memory listings) external;

  /**
   * @notice Performs full listings of assets, in the Aave pool configured in this engine instance
   * @dev This function allows more customization, especifically enables to set custom implementations
   *   for a/v/s tokens.
   *   IMPORTANT. Use it only if understanding the internals of the Aave v3 protocol
   * @param context `PoolContext` struct, effectively meta-data for naming of a/v/s tokens.
   *   More information on the documentation of the struct.
   * @param listings `ListingWithCustomImpl[]` list of declarative configs for every aspect of the asset listings.
   */
  function listAssetsCustom(
    PoolContext memory context,
    ListingWithCustomImpl[] memory listings
  ) external;

  /**
   * @notice Performs an update of the caps (supply, borrow) of the assets, in the Aave pool configured in this engine instance
   * @param updates `CapsUpdate[]` list of declarative updates containing the new caps
   *   More information on the documentation of the struct.
   */
  function updateCaps(CapsUpdate[] memory updates) external;

  /**
   * @notice Performs an update on the rate strategy params of the assets, in the Aave pool configured in this engine instance
   * @dev The engine itself manages if a new rate strategy needs to be deployed or if an existing one can be re-used
   * @param updates `RateStrategyUpdate[]` list of declarative updates containing the new rate strategy params
   *   More information on the documentation of the struct.
   */
  function updateRateStrategies(RateStrategyUpdate[] memory updates) external;

  /**
   * @notice Performs an update of the collateral-related params of the assets, in the Aave pool configured in this engine instance
   * @param updates `CollateralUpdate[]` list of declarative updates containing the new parameters
   *   More information on the documentation of the struct.
   */
  function updateCollateralSide(CollateralUpdate[] memory updates) external;

  /**
   * @notice Performs an update of the price feed of the assets, in the Aave pool configured in this engine instance
   * @param updates `PriceFeedUpdate[]` list of declarative updates containing the new parameters
   *   More information on the documentation of the struct.
   */
  function updatePriceFeeds(PriceFeedUpdate[] memory updates) external;

  /**
   * @notice Performs an update of the borrow-related params of the assets, in the Aave pool configured in this engine instance
   * @param updates `BorrowUpdate[]` list of declarative updates containing the new parameters
   *   More information on the documentation of the struct.
   */
  function updateBorrowSide(BorrowUpdate[] memory updates) external;

  /**
   * @notice Performs creation of new e-mode categories, in the Aave pool configured in this engine instance
   * @param creations `EModeCategoryCreation[]` list of declarative creations containing the new parameters
   *   More information on the documentation of the struct.
   */
  function createEModeCategories(EModeCategoryCreation[] memory creations) external;

  /**
   * @notice Performs an update of the e-mode categories, in the Aave pool configured in this engine instance
   * @param updates `EModeCategoryUpdate[]` list of declarative updates containing the new parameters
   *   More information on the documentation of the struct.
   */
  function updateEModeCategories(EModeCategoryUpdate[] memory updates) external;

  /**
   * @notice Performs an update of the e-mode category.
   * Sets a specified asset collateral and/or borrowable, in the Aave pool configured in this engine instance
   * @param updates `EModeCollateralUpdate[]` list of declarative updates containing the new parameters
   *   More information on the documentation of the struct.
   */
  function updateAssetsEMode(AssetEModeUpdate[] calldata updates) external;

  function DEFAULT_INTEREST_RATE_STRATEGY() external view returns (address);

  function POOL() external view returns (IPool);

  function POOL_CONFIGURATOR() external view returns (IPoolConfigurator);

  function ORACLE() external view returns (IAaveOracle);

  function ATOKEN_IMPL() external view returns (address);

  function VTOKEN_IMPL() external view returns (address);

  function REWARDS_CONTROLLER() external view returns (address);

  function COLLECTOR() external view returns (address);

  function BORROW_ENGINE() external view returns (address);

  function CAPS_ENGINE() external view returns (address);

  function COLLATERAL_ENGINE() external view returns (address);

  function EMODE_ENGINE() external view returns (address);

  function LISTING_ENGINE() external view returns (address);

  function PRICE_FEED_ENGINE() external view returns (address);

  function RATE_ENGINE() external view returns (address);
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

library EngineFlags {
  /// @dev magic value to be used as flag to keep unchanged any current configuration
  /// Strongly assumes that the value `type(uint256).max - 42` will never be used, which seems reasonable
  uint256 internal constant KEEP_CURRENT = type(uint256).max - 42;

  /// @dev magic value to be used as flag to keep unchanged any current configuration
  /// Strongly assumes that the value `KEEP_CURRENT_STRING` will never be used, which seems reasonable
  string internal constant KEEP_CURRENT_STRING = 'KEEP_CURRENT_STRING';

  /// @dev magic value to be used as flag to keep unchanged any current configuration
  /// Strongly assumes that the value `0x0000000000000000000000000000000000000050` will never be used, which seems reasonable
  address internal constant KEEP_CURRENT_ADDRESS =
    address(0x0000000000000000000000000000000000000050);

  /// @dev value to be used as flag for bool value true
  uint256 internal constant ENABLED = 1;

  /// @dev value to be used as flag for bool value false
  uint256 internal constant DISABLED = 0;

  /// @dev converts flag ENABLED DISABLED to bool
  function toBool(uint256 flag) internal pure returns (bool) {
    require(flag == 0 || flag == 1, 'INVALID_CONVERSION_TO_BOOL');
    return flag == 1;
  }

  /// @dev converts bool to ENABLED DISABLED flags
  function fromBool(bool isTrue) internal pure returns (uint256) {
    return isTrue ? ENABLED : DISABLED;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DataTypes {
  /**
   * This exists specifically to maintain the `getReserveData()` interface, since the new, internal
   * `ReserveData` struct includes the reserve's `virtualUnderlyingBalance`.
   */
  struct ReserveDataLegacy {
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
    // DEPRECATED on v3.2.0
    uint128 currentStableBorrowRate;
    //timestamp of last update
    uint40 lastUpdateTimestamp;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint16 id;
    //aToken address
    address aTokenAddress;
    // DEPRECATED on v3.2.0
    address stableDebtTokenAddress;
    //variableDebtToken address
    address variableDebtTokenAddress;
    // DEPRECATED on v3.4.0, should use the `RESERVE_INTEREST_RATE_STRATEGY` variable from the Pool contract
    address interestRateStrategyAddress;
    //the current treasury balance, scaled
    uint128 accruedToTreasury;
    // DEPRECATED on v3.4.0
    uint128 unbacked;
    //the outstanding debt borrowed against this asset in isolation mode
    uint128 isolationModeTotalDebt;
  }

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
    /// @notice reused `__deprecatedStableBorrowRate` storage from pre 3.2
    // the current accumulate deficit in underlying tokens
    uint128 deficit;
    //timestamp of last update
    uint40 lastUpdateTimestamp;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint16 id;
    //timestamp until when liquidations are not allowed on the reserve, if set to past liquidations will be allowed
    uint40 liquidationGracePeriodUntil;
    //aToken address
    address aTokenAddress;
    // DEPRECATED on v3.2.0
    address __deprecatedStableDebtTokenAddress;
    //variableDebtToken address
    address variableDebtTokenAddress;
    // DEPRECATED on v3.4.0, should use the `RESERVE_INTEREST_RATE_STRATEGY` variable from the Pool contract
    address __deprecatedInterestRateStrategyAddress;
    //the current treasury balance, scaled
    uint128 accruedToTreasury;
    // In aave 3.3.0 this storage slot contained the `unbacked`
    uint128 virtualUnderlyingBalance;
    //the outstanding debt borrowed against this asset in isolation mode
    uint128 isolationModeTotalDebt;
    //the amount of underlying accounted for by the protocol
    // DEPRECATED on v3.4.0. Moved into the same slot as accruedToTreasury for optimized storage access.
    uint128 __deprecatedVirtualUnderlyingBalance;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: DEPRECATED: stable rate borrowing enabled
    //bit 60: asset is paused
    //bit 61: borrowing in isolation mode is enabled
    //bit 62: siloed borrowing enabled
    //bit 63: flashloaning enabled
    //bit 64-79: reserve factor
    //bit 80-115: borrow cap in whole tokens, borrowCap == 0 => no cap
    //bit 116-151: supply cap in whole tokens, supplyCap == 0 => no cap
    //bit 152-167: liquidation protocol fee
    //bit 168-175: DEPRECATED: eMode category
    //bit 176-211: DEPRECATED: unbacked mint cap
    //bit 212-251: debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
    //bit 252: DEPRECATED: virtual accounting is enabled for the reserve
    //bit 253-255 unused

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

  // DEPRECATED: kept for backwards compatibility, might be removed in a future version
  struct EModeCategoryLegacy {
    // each eMode category has a custom ltv and liquidation threshold
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    // DEPRECATED
    address priceSource;
    string label;
  }

  struct CollateralConfig {
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
  }

  struct EModeCategoryBaseConfiguration {
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    string label;
  }

  struct EModeCategory {
    // each eMode category has a custom ltv and liquidation threshold
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    uint128 collateralBitmap;
    string label;
    uint128 borrowableBitmap;
  }

  enum InterestRateMode {
    NONE,
    __DEPRECATED,
    VARIABLE
  }

  struct ReserveCache {
    uint256 currScaledVariableDebt;
    uint256 nextScaledVariableDebt;
    uint256 currLiquidityIndex;
    uint256 nextLiquidityIndex;
    uint256 currVariableBorrowIndex;
    uint256 nextVariableBorrowIndex;
    uint256 currLiquidityRate;
    uint256 currVariableBorrowRate;
    uint256 reserveFactor;
    ReserveConfigurationMap reserveConfiguration;
    address aTokenAddress;
    address variableDebtTokenAddress;
    uint40 reserveLastUpdateTimestamp;
  }

  struct ExecuteLiquidationCallParams {
    address liquidator;
    uint256 debtToCover;
    address collateralAsset;
    address debtAsset;
    address borrower;
    bool receiveAToken;
    address priceOracle;
    uint8 borrowerEModeCategory;
    address priceOracleSentinel;
    address interestRateStrategyAddress;
  }

  struct ExecuteSupplyParams {
    address user;
    address asset;
    address interestRateStrategyAddress;
    uint256 amount;
    address onBehalfOf;
    uint16 referralCode;
  }

  struct ExecuteBorrowParams {
    address asset;
    address user;
    address onBehalfOf;
    address interestRateStrategyAddress;
    uint256 amount;
    InterestRateMode interestRateMode;
    uint16 referralCode;
    bool releaseUnderlying;
    address oracle;
    uint8 userEModeCategory;
    address priceOracleSentinel;
  }

  struct ExecuteRepayParams {
    address asset;
    address user;
    address interestRateStrategyAddress;
    uint256 amount;
    InterestRateMode interestRateMode;
    address onBehalfOf;
    bool useATokens;
  }

  struct ExecuteWithdrawParams {
    address user;
    address asset;
    address interestRateStrategyAddress;
    uint256 amount;
    address to;
    address oracle;
    uint8 userEModeCategory;
  }

  struct ExecuteEliminateDeficitParams {
    address user;
    address asset;
    address interestRateStrategyAddress;
    uint256 amount;
  }

  struct FinalizeTransferParams {
    address asset;
    address from;
    address to;
    uint256 amount;
    uint256 balanceFromBefore;
    uint256 balanceToBefore;
    address oracle;
    uint8 fromEModeCategory;
  }

  struct FlashloanParams {
    address user;
    address receiverAddress;
    address[] assets;
    uint256[] amounts;
    uint256[] interestRateModes;
    address interestRateStrategyAddress;
    address onBehalfOf;
    bytes params;
    uint16 referralCode;
    uint256 flashLoanPremium;
    address addressesProvider;
    address pool;
    uint8 userEModeCategory;
    bool isAuthorizedFlashBorrower;
  }

  struct FlashloanSimpleParams {
    address user;
    address receiverAddress;
    address asset;
    address interestRateStrategyAddress;
    uint256 amount;
    bytes params;
    uint16 referralCode;
    uint256 flashLoanPremium;
  }

  struct FlashLoanRepaymentParams {
    address user;
    uint256 amount;
    uint256 totalPremium;
    address asset;
    address interestRateStrategyAddress;
    address receiverAddress;
    uint16 referralCode;
  }

  struct CalculateUserAccountDataParams {
    UserConfigurationMap userConfig;
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
    address oracle;
    uint8 userEModeCategory;
    address priceOracleSentinel;
  }

  struct ValidateLiquidationCallParams {
    ReserveCache debtReserveCache;
    uint256 totalDebt;
    uint256 healthFactor;
    address priceOracleSentinel;
    address borrower;
    address liquidator;
  }

  struct CalculateInterestRatesParams {
    uint256 unbacked;
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalDebt;
    uint256 reserveFactor;
    address reserve;
    // @notice DEPRECATED in 3.4, but kept for backwards compatibility
    bool usingVirtualBalance;
    uint256 virtualUnderlyingBalance;
  }

  struct InitReserveParams {
    address asset;
    address aTokenAddress;
    address variableDebtAddress;
    uint16 reservesCount;
    uint16 maxNumberReserves;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Errors} from '../helpers/Errors.sol';
import {DataTypes} from '../types/DataTypes.sol';

/**
 * @title ReserveConfiguration library
 * @author Aave
 * @notice Implements the bitmap logic to handle the reserve configuration
 */
library ReserveConfiguration {
  uint256 internal constant LTV_MASK =                       0x000000000000000000000000000000000000000000000000000000000000FFFF; // prettier-ignore
  uint256 internal constant LIQUIDATION_THRESHOLD_MASK =     0x00000000000000000000000000000000000000000000000000000000FFFF0000; // prettier-ignore
  uint256 internal constant LIQUIDATION_BONUS_MASK =         0x0000000000000000000000000000000000000000000000000000FFFF00000000; // prettier-ignore
  uint256 internal constant DECIMALS_MASK =                  0x00000000000000000000000000000000000000000000000000FF000000000000; // prettier-ignore
  uint256 internal constant ACTIVE_MASK =                    0x0000000000000000000000000000000000000000000000000100000000000000; // prettier-ignore
  uint256 internal constant FROZEN_MASK =                    0x0000000000000000000000000000000000000000000000000200000000000000; // prettier-ignore
  uint256 internal constant BORROWING_MASK =                 0x0000000000000000000000000000000000000000000000000400000000000000; // prettier-ignore
  // @notice there is an unoccupied hole of 1 bit at position 59 from pre 3.2 stableBorrowRateEnabled
  uint256 internal constant PAUSED_MASK =                    0x0000000000000000000000000000000000000000000000001000000000000000; // prettier-ignore
  uint256 internal constant BORROWABLE_IN_ISOLATION_MASK =   0x0000000000000000000000000000000000000000000000002000000000000000; // prettier-ignore
  uint256 internal constant SILOED_BORROWING_MASK =          0x0000000000000000000000000000000000000000000000004000000000000000; // prettier-ignore
  uint256 internal constant FLASHLOAN_ENABLED_MASK =         0x0000000000000000000000000000000000000000000000008000000000000000; // prettier-ignore
  uint256 internal constant RESERVE_FACTOR_MASK =            0x00000000000000000000000000000000000000000000FFFF0000000000000000; // prettier-ignore
  uint256 internal constant BORROW_CAP_MASK =                0x00000000000000000000000000000000000FFFFFFFFF00000000000000000000; // prettier-ignore
  uint256 internal constant SUPPLY_CAP_MASK =                0x00000000000000000000000000FFFFFFFFF00000000000000000000000000000; // prettier-ignore
  uint256 internal constant LIQUIDATION_PROTOCOL_FEE_MASK =  0x0000000000000000000000FFFF00000000000000000000000000000000000000; // prettier-ignore
  //@notice there is an unoccupied hole of 8 bits from 168 to 175 left from pre 3.2 eModeCategory
  //@notice there is an unoccupied hole of 34 bits from 176 to 211 left from pre 3.4 unbackedMintCap
  uint256 internal constant DEBT_CEILING_MASK =              0x0FFFFFFFFFF00000000000000000000000000000000000000000000000000000; // prettier-ignore
  //@notice DEPRECATED: in v3.4 all reserves have virtual accounting enabled
  uint256 internal constant VIRTUAL_ACC_ACTIVE_MASK =        0x1000000000000000000000000000000000000000000000000000000000000000; // prettier-ignore

  /// @dev For the LTV, the start bit is 0 (up to 15), hence no bitshifting is needed
  uint256 internal constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
  uint256 internal constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
  uint256 internal constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
  uint256 internal constant IS_ACTIVE_START_BIT_POSITION = 56;
  uint256 internal constant IS_FROZEN_START_BIT_POSITION = 57;
  uint256 internal constant BORROWING_ENABLED_START_BIT_POSITION = 58;
  uint256 internal constant IS_PAUSED_START_BIT_POSITION = 60;
  uint256 internal constant BORROWABLE_IN_ISOLATION_START_BIT_POSITION = 61;
  uint256 internal constant SILOED_BORROWING_START_BIT_POSITION = 62;
  uint256 internal constant FLASHLOAN_ENABLED_START_BIT_POSITION = 63;
  uint256 internal constant RESERVE_FACTOR_START_BIT_POSITION = 64;
  uint256 internal constant BORROW_CAP_START_BIT_POSITION = 80;
  uint256 internal constant SUPPLY_CAP_START_BIT_POSITION = 116;
  uint256 internal constant LIQUIDATION_PROTOCOL_FEE_START_BIT_POSITION = 152;
  //@notice there is an unoccupied hole of 8 bits from 168 to 175 left from pre 3.2 eModeCategory
  //@notice there is an unoccupied hole of 34 bits from 176 to 211 left from pre 3.4 unbackedMintCap
  uint256 internal constant DEBT_CEILING_START_BIT_POSITION = 212;
  //@notice DEPRECATED: in v3.4 all reserves have virtual accounting enabled
  uint256 internal constant VIRTUAL_ACC_START_BIT_POSITION = 252;

  uint256 internal constant MAX_VALID_LTV = 65535;
  uint256 internal constant MAX_VALID_LIQUIDATION_THRESHOLD = 65535;
  uint256 internal constant MAX_VALID_LIQUIDATION_BONUS = 65535;
  uint256 internal constant MAX_VALID_DECIMALS = 255;
  uint256 internal constant MAX_VALID_RESERVE_FACTOR = 65535;
  uint256 internal constant MAX_VALID_BORROW_CAP = 68719476735;
  uint256 internal constant MAX_VALID_SUPPLY_CAP = 68719476735;
  uint256 internal constant MAX_VALID_LIQUIDATION_PROTOCOL_FEE = 65535;
  uint256 internal constant MAX_VALID_DEBT_CEILING = 1099511627775;

  uint256 public constant DEBT_CEILING_DECIMALS = 2;
  uint16 public constant MAX_RESERVES_COUNT = 128;

  /**
   * @notice Sets the Loan to Value of the reserve
   * @param self The reserve configuration
   * @param ltv The new ltv
   */
  function setLtv(DataTypes.ReserveConfigurationMap memory self, uint256 ltv) internal pure {
    require(ltv <= MAX_VALID_LTV, Errors.InvalidLtv());

    self.data = (self.data & ~LTV_MASK) | ltv;
  }

  /**
   * @notice Gets the Loan to Value of the reserve
   * @param self The reserve configuration
   * @return The loan to value
   */
  function getLtv(DataTypes.ReserveConfigurationMap memory self) internal pure returns (uint256) {
    return self.data & LTV_MASK;
  }

  /**
   * @notice Sets the liquidation threshold of the reserve
   * @param self The reserve configuration
   * @param threshold The new liquidation threshold
   */
  function setLiquidationThreshold(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 threshold
  ) internal pure {
    require(threshold <= MAX_VALID_LIQUIDATION_THRESHOLD, Errors.InvalidLiquidationThreshold());

    self.data =
      (self.data & ~LIQUIDATION_THRESHOLD_MASK) |
      (threshold << LIQUIDATION_THRESHOLD_START_BIT_POSITION);
  }

  /**
   * @notice Gets the liquidation threshold of the reserve
   * @param self The reserve configuration
   * @return The liquidation threshold
   */
  function getLiquidationThreshold(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION;
  }

  /**
   * @notice Sets the liquidation bonus of the reserve
   * @param self The reserve configuration
   * @param bonus The new liquidation bonus
   */
  function setLiquidationBonus(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 bonus
  ) internal pure {
    require(bonus <= MAX_VALID_LIQUIDATION_BONUS, Errors.InvalidLiquidationBonus());

    self.data =
      (self.data & ~LIQUIDATION_BONUS_MASK) |
      (bonus << LIQUIDATION_BONUS_START_BIT_POSITION);
  }

  /**
   * @notice Gets the liquidation bonus of the reserve
   * @param self The reserve configuration
   * @return The liquidation bonus
   */
  function getLiquidationBonus(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION;
  }

  /**
   * @notice Sets the decimals of the underlying asset of the reserve
   * @param self The reserve configuration
   * @param decimals The decimals
   */
  function setDecimals(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 decimals
  ) internal pure {
    require(decimals <= MAX_VALID_DECIMALS, Errors.InvalidDecimals());

    self.data = (self.data & ~DECIMALS_MASK) | (decimals << RESERVE_DECIMALS_START_BIT_POSITION);
  }

  /**
   * @notice Gets the decimals of the underlying asset of the reserve
   * @param self The reserve configuration
   * @return The decimals of the asset
   */
  function getDecimals(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
  }

  /**
   * @notice Sets the active state of the reserve
   * @param self The reserve configuration
   * @param active The active state
   */
  function setActive(DataTypes.ReserveConfigurationMap memory self, bool active) internal pure {
    self.data =
      (self.data & ~ACTIVE_MASK) |
      (uint256(active ? 1 : 0) << IS_ACTIVE_START_BIT_POSITION);
  }

  /**
   * @notice Gets the active state of the reserve
   * @param self The reserve configuration
   * @return The active state
   */
  function getActive(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
    return (self.data & ACTIVE_MASK) != 0;
  }

  /**
   * @notice Sets the frozen state of the reserve
   * @param self The reserve configuration
   * @param frozen The frozen state
   */
  function setFrozen(DataTypes.ReserveConfigurationMap memory self, bool frozen) internal pure {
    self.data =
      (self.data & ~FROZEN_MASK) |
      (uint256(frozen ? 1 : 0) << IS_FROZEN_START_BIT_POSITION);
  }

  /**
   * @notice Gets the frozen state of the reserve
   * @param self The reserve configuration
   * @return The frozen state
   */
  function getFrozen(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
    return (self.data & FROZEN_MASK) != 0;
  }

  /**
   * @notice Sets the paused state of the reserve
   * @param self The reserve configuration
   * @param paused The paused state
   */
  function setPaused(DataTypes.ReserveConfigurationMap memory self, bool paused) internal pure {
    self.data =
      (self.data & ~PAUSED_MASK) |
      (uint256(paused ? 1 : 0) << IS_PAUSED_START_BIT_POSITION);
  }

  /**
   * @notice Gets the paused state of the reserve
   * @param self The reserve configuration
   * @return The paused state
   */
  function getPaused(DataTypes.ReserveConfigurationMap memory self) internal pure returns (bool) {
    return (self.data & PAUSED_MASK) != 0;
  }

  /**
   * @notice Sets the borrowable in isolation flag for the reserve.
   * @dev When this flag is set to true, the asset will be borrowable against isolated collaterals and the borrowed
   * amount will be accumulated in the isolated collateral's total debt exposure.
   * @dev Only assets of the same family (eg USD stablecoins) should be borrowable in isolation mode to keep
   * consistency in the debt ceiling calculations.
   * @param self The reserve configuration
   * @param borrowable True if the asset is borrowable
   */
  function setBorrowableInIsolation(
    DataTypes.ReserveConfigurationMap memory self,
    bool borrowable
  ) internal pure {
    self.data =
      (self.data & ~BORROWABLE_IN_ISOLATION_MASK) |
      (uint256(borrowable ? 1 : 0) << BORROWABLE_IN_ISOLATION_START_BIT_POSITION);
  }

  /**
   * @notice Gets the borrowable in isolation flag for the reserve.
   * @dev If the returned flag is true, the asset is borrowable against isolated collateral. Assets borrowed with
   * isolated collateral is accounted for in the isolated collateral's total debt exposure.
   * @dev Only assets of the same family (eg USD stablecoins) should be borrowable in isolation mode to keep
   * consistency in the debt ceiling calculations.
   * @param self The reserve configuration
   * @return The borrowable in isolation flag
   */
  function getBorrowableInIsolation(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (bool) {
    return (self.data & BORROWABLE_IN_ISOLATION_MASK) != 0;
  }

  /**
   * @notice Sets the siloed borrowing flag for the reserve.
   * @dev When this flag is set to true, users borrowing this asset will not be allowed to borrow any other asset.
   * @param self The reserve configuration
   * @param siloed True if the asset is siloed
   */
  function setSiloedBorrowing(
    DataTypes.ReserveConfigurationMap memory self,
    bool siloed
  ) internal pure {
    self.data =
      (self.data & ~SILOED_BORROWING_MASK) |
      (uint256(siloed ? 1 : 0) << SILOED_BORROWING_START_BIT_POSITION);
  }

  /**
   * @notice Gets the siloed borrowing flag for the reserve.
   * @dev When this flag is set to true, users borrowing this asset will not be allowed to borrow any other asset.
   * @param self The reserve configuration
   * @return The siloed borrowing flag
   */
  function getSiloedBorrowing(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (bool) {
    return (self.data & SILOED_BORROWING_MASK) != 0;
  }

  /**
   * @notice Enables or disables borrowing on the reserve
   * @param self The reserve configuration
   * @param enabled True if the borrowing needs to be enabled, false otherwise
   */
  function setBorrowingEnabled(
    DataTypes.ReserveConfigurationMap memory self,
    bool enabled
  ) internal pure {
    self.data =
      (self.data & ~BORROWING_MASK) |
      (uint256(enabled ? 1 : 0) << BORROWING_ENABLED_START_BIT_POSITION);
  }

  /**
   * @notice Gets the borrowing state of the reserve
   * @param self The reserve configuration
   * @return The borrowing state
   */
  function getBorrowingEnabled(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (bool) {
    return (self.data & BORROWING_MASK) != 0;
  }

  /**
   * @notice Sets the reserve factor of the reserve
   * @param self The reserve configuration
   * @param reserveFactor The reserve factor
   */
  function setReserveFactor(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 reserveFactor
  ) internal pure {
    require(reserveFactor <= MAX_VALID_RESERVE_FACTOR, Errors.InvalidReserveFactor());

    self.data =
      (self.data & ~RESERVE_FACTOR_MASK) |
      (reserveFactor << RESERVE_FACTOR_START_BIT_POSITION);
  }

  /**
   * @notice Gets the reserve factor of the reserve
   * @param self The reserve configuration
   * @return The reserve factor
   */
  function getReserveFactor(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION;
  }

  /**
   * @notice Sets the borrow cap of the reserve
   * @param self The reserve configuration
   * @param borrowCap The borrow cap
   */
  function setBorrowCap(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 borrowCap
  ) internal pure {
    require(borrowCap <= MAX_VALID_BORROW_CAP, Errors.InvalidBorrowCap());

    self.data = (self.data & ~BORROW_CAP_MASK) | (borrowCap << BORROW_CAP_START_BIT_POSITION);
  }

  /**
   * @notice Gets the borrow cap of the reserve
   * @param self The reserve configuration
   * @return The borrow cap
   */
  function getBorrowCap(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & BORROW_CAP_MASK) >> BORROW_CAP_START_BIT_POSITION;
  }

  /**
   * @notice Sets the supply cap of the reserve
   * @param self The reserve configuration
   * @param supplyCap The supply cap
   */
  function setSupplyCap(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 supplyCap
  ) internal pure {
    require(supplyCap <= MAX_VALID_SUPPLY_CAP, Errors.InvalidSupplyCap());

    self.data = (self.data & ~SUPPLY_CAP_MASK) | (supplyCap << SUPPLY_CAP_START_BIT_POSITION);
  }

  /**
   * @notice Gets the supply cap of the reserve
   * @param self The reserve configuration
   * @return The supply cap
   */
  function getSupplyCap(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION;
  }

  /**
   * @notice Sets the debt ceiling in isolation mode for the asset
   * @param self The reserve configuration
   * @param ceiling The maximum debt ceiling for the asset
   */
  function setDebtCeiling(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 ceiling
  ) internal pure {
    require(ceiling <= MAX_VALID_DEBT_CEILING, Errors.InvalidDebtCeiling());

    self.data = (self.data & ~DEBT_CEILING_MASK) | (ceiling << DEBT_CEILING_START_BIT_POSITION);
  }

  /**
   * @notice Gets the debt ceiling for the asset if the asset is in isolation mode
   * @param self The reserve configuration
   * @return The debt ceiling (0 = isolation mode disabled)
   */
  function getDebtCeiling(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return (self.data & DEBT_CEILING_MASK) >> DEBT_CEILING_START_BIT_POSITION;
  }

  /**
   * @notice Sets the liquidation protocol fee of the reserve
   * @param self The reserve configuration
   * @param liquidationProtocolFee The liquidation protocol fee
   */
  function setLiquidationProtocolFee(
    DataTypes.ReserveConfigurationMap memory self,
    uint256 liquidationProtocolFee
  ) internal pure {
    require(
      liquidationProtocolFee <= MAX_VALID_LIQUIDATION_PROTOCOL_FEE,
      Errors.InvalidLiquidationProtocolFee()
    );

    self.data =
      (self.data & ~LIQUIDATION_PROTOCOL_FEE_MASK) |
      (liquidationProtocolFee << LIQUIDATION_PROTOCOL_FEE_START_BIT_POSITION);
  }

  /**
   * @dev Gets the liquidation protocol fee
   * @param self The reserve configuration
   * @return The liquidation protocol fee
   */
  function getLiquidationProtocolFee(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256) {
    return
      (self.data & LIQUIDATION_PROTOCOL_FEE_MASK) >> LIQUIDATION_PROTOCOL_FEE_START_BIT_POSITION;
  }

  /**
   * @notice Sets the flashloanable flag for the reserve
   * @param self The reserve configuration
   * @param flashLoanEnabled True if the asset is flashloanable, false otherwise
   */
  function setFlashLoanEnabled(
    DataTypes.ReserveConfigurationMap memory self,
    bool flashLoanEnabled
  ) internal pure {
    self.data =
      (self.data & ~FLASHLOAN_ENABLED_MASK) |
      (uint256(flashLoanEnabled ? 1 : 0) << FLASHLOAN_ENABLED_START_BIT_POSITION);
  }

  /**
   * @notice Gets the flashloanable flag for the reserve
   * @param self The reserve configuration
   * @return The flashloanable flag
   */
  function getFlashLoanEnabled(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (bool) {
    return (self.data & FLASHLOAN_ENABLED_MASK) != 0;
  }

  /**
   * @notice Forcefully set the virtual account active state of the reserve to `true`
   * @dev DEPRECATED: in v3.4 all reserves have virtual accounting enabled.
   * The flag is carried along for backward compatibility with integrations directly querying the configuration.
   * @param self The reserve configuration
   */
  function setVirtualAccActive(DataTypes.ReserveConfigurationMap memory self) internal pure {
    self.data =
      (self.data & ~VIRTUAL_ACC_ACTIVE_MASK) |
      (uint256(1) << VIRTUAL_ACC_START_BIT_POSITION);
  }

  /**
   * @notice Gets the configuration flags of the reserve
   * @param self The reserve configuration
   * @return The state flag representing active
   * @return The state flag representing frozen
   * @return The state flag representing borrowing enabled
   * @return The state flag representing paused
   */
  function getFlags(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (bool, bool, bool, bool) {
    uint256 dataLocal = self.data;

    return (
      (dataLocal & ACTIVE_MASK) != 0,
      (dataLocal & FROZEN_MASK) != 0,
      (dataLocal & BORROWING_MASK) != 0,
      (dataLocal & PAUSED_MASK) != 0
    );
  }

  /**
   * @notice Gets the configuration parameters of the reserve from storage
   * @param self The reserve configuration
   * @return The state param representing ltv
   * @return The state param representing liquidation threshold
   * @return The state param representing liquidation bonus
   * @return The state param representing reserve decimals
   * @return The state param representing reserve factor
   */
  function getParams(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256, uint256, uint256, uint256, uint256) {
    uint256 dataLocal = self.data;

    return (
      dataLocal & LTV_MASK,
      (dataLocal & LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION,
      (dataLocal & LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
      (dataLocal & DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
      (dataLocal & RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION
    );
  }

  /**
   * @notice Gets the caps parameters of the reserve from storage
   * @param self The reserve configuration
   * @return The state param representing borrow cap
   * @return The state param representing supply cap.
   */
  function getCaps(
    DataTypes.ReserveConfigurationMap memory self
  ) internal pure returns (uint256, uint256) {
    uint256 dataLocal = self.data;

    return (
      (dataLocal & BORROW_CAP_MASK) >> BORROW_CAP_START_BIT_POSITION,
      (dataLocal & SUPPLY_CAP_MASK) >> SUPPLY_CAP_START_BIT_POSITION
    );
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title PercentageMath library
 * @author Aave
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library PercentageMath {
  // Maximum percentage factor (100.00%)
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  // Half percentage factor (50.00%)
  uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

  /**
   * @notice Executes a percentage multiplication
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentmul percentage
   */
  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
    assembly {
      if iszero(
        or(
          iszero(percentage),
          iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)))
        )
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
    }
  }

  /**
   * @notice Executes a percentage division
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentdiv percentage
   */
  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR
    assembly {
      if or(
        iszero(percentage),
        iszero(iszero(gt(value, div(sub(not(0), div(percentage, 2)), PERCENTAGE_FACTOR))))
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)), percentage)
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IReserveInterestRateStrategy} from './IReserveInterestRateStrategy.sol';
import {IPoolAddressesProvider} from './IPoolAddressesProvider.sol';

/**
 * @title IDefaultInterestRateStrategyV2
 * @author BGD Labs
 * @notice Interface of the default interest rate strategy used by the Aave protocol
 */
interface IDefaultInterestRateStrategyV2 is IReserveInterestRateStrategy {
  /**
   * @notice Holds the interest rate data for a given reserve
   *
   * @dev Since values are in bps, they are multiplied by 1e23 in order to become rays with 27 decimals. This
   * in turn means that the maximum supported interest rate is 4294967295 (2**32-1) bps or 42949672.95%.
   *
   * @param optimalUsageRatio The optimal usage ratio, in bps
   * @param baseVariableBorrowRate The base variable borrow rate, in bps
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal ratio, in bps
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal ratio, in bps
   */
  struct InterestRateData {
    uint16 optimalUsageRatio;
    uint32 baseVariableBorrowRate;
    uint32 variableRateSlope1;
    uint32 variableRateSlope2;
  }

  /**
   * @notice The interest rate data, where all values are in ray (fixed-point 27 decimal numbers) for a given reserve,
   * used in in-memory calculations.
   *
   * @param optimalUsageRatio The optimal usage ratio
   * @param baseVariableBorrowRate The base variable borrow rate
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal ratio
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal ratio
   */
  struct InterestRateDataRay {
    uint256 optimalUsageRatio;
    uint256 baseVariableBorrowRate;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
  }

  /**
   * @notice emitted when new interest rate data is set in a reserve
   *
   * @param reserve address of the reserve that has new interest rate data set
   * @param optimalUsageRatio The optimal usage ratio, in bps
   * @param baseVariableBorrowRate The base variable borrow rate, in bps
   * @param variableRateSlope1 The slope of the variable interest curve, before hitting the optimal ratio, in bps
   * @param variableRateSlope2 The slope of the variable interest curve, after hitting the optimal ratio, in bps
   */
  event RateDataUpdate(
    address indexed reserve,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  /**
   * @notice Returns the address of the PoolAddressesProvider
   * @return The address of the PoolAddressesProvider contract
   */
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Returns the maximum value achievable for variable borrow rate, in bps
   * @return The maximum rate
   */
  function MAX_BORROW_RATE() external view returns (uint256);

  /**
   * @notice Returns the minimum optimal point, in bps
   * @return The optimal point
   */
  function MIN_OPTIMAL_POINT() external view returns (uint256);

  /**
   * @notice Returns the maximum optimal point, in bps
   * @return The optimal point
   */
  function MAX_OPTIMAL_POINT() external view returns (uint256);

  /**
   * notice Returns the full InterestRateData object for the given reserve, in ray
   *
   * @param reserve The reserve to get the data of
   *
   * @return The InterestRateDataRay object for the given reserve
   */
  function getInterestRateData(address reserve) external view returns (InterestRateDataRay memory);

  /**
   * notice Returns the full InterestRateDataRay object for the given reserve, in bps
   *
   * @param reserve The reserve to get the data of
   *
   * @return The InterestRateData object for the given reserve
   */
  function getInterestRateDataBps(address reserve) external view returns (InterestRateData memory);

  /**
   * @notice Returns the optimal usage rate for the given reserve in ray
   *
   * @param reserve The reserve to get the optimal usage rate of
   *
   * @return The optimal usage rate is the level of borrow / collateral at which the borrow rate
   */
  function getOptimalUsageRatio(address reserve) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope below optimal usage ratio in ray
   * @dev It's the variable rate when usage ratio > 0 and <= OPTIMAL_USAGE_RATIO
   *
   * @param reserve The reserve to get the variable rate slope 1 of
   *
   * @return The variable rate slope
   */
  function getVariableRateSlope1(address reserve) external view returns (uint256);

  /**
   * @notice Returns the variable rate slope above optimal usage ratio in ray
   * @dev It's the variable rate when usage ratio > OPTIMAL_USAGE_RATIO
   *
   * @param reserve The reserve to get the variable rate slope 2 of
   *
   * @return The variable rate slope
   */
  function getVariableRateSlope2(address reserve) external view returns (uint256);

  /**
   * @notice Returns the base variable borrow rate, in ray
   *
   * @param reserve The reserve to get the base variable borrow rate of
   *
   * @return The base variable borrow rate
   */
  function getBaseVariableBorrowRate(address reserve) external view returns (uint256);

  /**
   * @notice Returns the maximum variable borrow rate, in ray
   *
   * @param reserve The reserve to get the maximum variable borrow rate of
   *
   * @return The maximum variable borrow rate
   */
  function getMaxVariableBorrowRate(address reserve) external view returns (uint256);

  /**
   * @notice Sets interest rate data for an Aave rate strategy
   * @param reserve The reserve to update
   * @param rateData The reserve interest rate data to apply to the given reserve
   *   Being specific to this custom implementation, with custom struct type,
   *   overloading the function on the generic interface
   */
  function setInterestRateParams(address reserve, InterestRateData calldata rateData) external;
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
// Chainlink Contracts v0.8
pragma solidity ^0.8.0;

interface AggregatorInterface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function getRoundData(
    uint80 _roundId
  )
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

library ConfiguratorInputTypes {
  struct InitReserveInput {
    address aTokenImpl;
    address variableDebtTokenImpl;
    address underlyingAsset;
    string aTokenName;
    string aTokenSymbol;
    string variableDebtTokenName;
    string variableDebtTokenSymbol;
    bytes params;
    bytes interestRateData;
  }

  struct UpdateATokenInput {
    address asset;
    string name;
    string symbol;
    address implementation;
    bytes params;
  }

  struct UpdateDebtTokenInput {
    address asset;
    string name;
    string symbol;
    address implementation;
    bytes params;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolAddressesProvider} from './IPoolAddressesProvider.sol';
import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';

/**
 * @title IPool
 * @author Aave
 * @notice Defines the basic interface for an Aave Pool.
 */
interface IPool {
  /**
   * @dev Emitted on supply()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address initiating the supply
   * @param onBehalfOf The beneficiary of the supply, receiving the aTokens
   * @param amount The amount supplied
   * @param referralCode The referral code used
   */
  event Supply(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referralCode
  );

  /**
   * @dev Emitted on withdraw()
   * @param reserve The address of the underlying asset being withdrawn
   * @param user The address initiating the withdrawal, owner of aTokens
   * @param to The address that will receive the underlying
   * @param amount The amount to be withdrawn
   */
  event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

  /**
   * @dev Emitted on borrow() and flashLoan() when debt needs to be opened
   * @param reserve The address of the underlying asset being borrowed
   * @param user The address of the user initiating the borrow(), receiving the funds on borrow() or just
   * initiator of the transaction on flashLoan()
   * @param onBehalfOf The address that will be getting the debt
   * @param amount The amount borrowed out
   * @param interestRateMode The rate mode: 2 for Variable, 1 is deprecated (changed on v3.2.0)
   * @param borrowRate The numeric rate at which the user has borrowed, expressed in ray
   * @param referralCode The referral code used
   */
  event Borrow(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    DataTypes.InterestRateMode interestRateMode,
    uint256 borrowRate,
    uint16 indexed referralCode
  );

  /**
   * @dev Emitted on repay()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The beneficiary of the repayment, getting his debt reduced
   * @param repayer The address of the user initiating the repay(), providing the funds
   * @param amount The amount repaid
   * @param useATokens True if the repayment is done using aTokens, `false` if done with underlying asset directly
   */
  event Repay(
    address indexed reserve,
    address indexed user,
    address indexed repayer,
    uint256 amount,
    bool useATokens
  );

  /**
   * @dev Emitted on borrow(), repay() and liquidationCall() when using isolated assets
   * @param asset The address of the underlying asset of the reserve
   * @param totalDebt The total isolation mode debt for the reserve
   */
  event IsolationModeTotalDebtUpdated(address indexed asset, uint256 totalDebt);

  /**
   * @dev Emitted when the user selects a certain asset category for eMode
   * @param user The address of the user
   * @param categoryId The category id
   */
  event UserEModeSet(address indexed user, uint8 categoryId);

  /**
   * @dev Emitted on setUserUseReserveAsCollateral()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user enabling the usage as collateral
   */
  event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on setUserUseReserveAsCollateral()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user enabling the usage as collateral
   */
  event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on flashLoan()
   * @param target The address of the flash loan receiver contract
   * @param initiator The address initiating the flash loan
   * @param asset The address of the asset being flash borrowed
   * @param amount The amount flash borrowed
   * @param interestRateMode The flashloan mode: 0 for regular flashloan,
   *        1 for Stable (Deprecated on v3.2.0), 2 for Variable
   * @param premium The fee flash borrowed
   * @param referralCode The referral code used
   */
  event FlashLoan(
    address indexed target,
    address initiator,
    address indexed asset,
    uint256 amount,
    DataTypes.InterestRateMode interestRateMode,
    uint256 premium,
    uint16 indexed referralCode
  );

  /**
   * @dev Emitted when a borrower is liquidated.
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param user The address of the borrower getting liquidated
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param liquidatedCollateralAmount The amount of collateral received by the liquidator
   * @param liquidator The address of the liquidator
   * @param receiveAToken True if the liquidators wants to receive the collateral aTokens, `false` if he wants
   * to receive the underlying collateral asset directly
   */
  event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 debtToCover,
    uint256 liquidatedCollateralAmount,
    address liquidator,
    bool receiveAToken
  );

  /**
   * @dev Emitted when the state of a reserve is updated.
   * @param reserve The address of the underlying asset of the reserve
   * @param liquidityRate The next liquidity rate
   * @param stableBorrowRate The next stable borrow rate @note deprecated on v3.2.0
   * @param variableBorrowRate The next variable borrow rate
   * @param liquidityIndex The next liquidity index
   * @param variableBorrowIndex The next variable borrow index
   */
  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 stableBorrowRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  /**
   * @dev Emitted when the deficit of a reserve is covered.
   * @param reserve The address of the underlying asset of the reserve
   * @param caller The caller that triggered the DeficitCovered event
   * @param amountCovered The amount of deficit covered
   */
  event DeficitCovered(address indexed reserve, address caller, uint256 amountCovered);

  /**
   * @dev Emitted when the protocol treasury receives minted aTokens from the accrued interest.
   * @param reserve The address of the reserve
   * @param amountMinted The amount minted to the treasury
   */
  event MintedToTreasury(address indexed reserve, uint256 amountMinted);

  /**
   * @dev Emitted when deficit is realized on a liquidation.
   * @param user The user address where the bad debt will be burned
   * @param debtAsset The address of the underlying borrowed asset to be burned
   * @param amountCreated The amount of deficit created
   */
  event DeficitCreated(address indexed user, address indexed debtAsset, uint256 amountCreated);

  /**
   * @dev Emitted when a position manager is approved by the user.
   * @param user The user address
   * @param positionManager The address of the position manager
   */
  event PositionManagerApproved(address indexed user, address indexed positionManager);

  /**
   * @dev Emitted when a position manager is revoked by the user.
   * @param user The user address
   * @param positionManager The address of the position manager
   */
  event PositionManagerRevoked(address indexed user, address indexed positionManager);

  /**
   * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to be supplied
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   */
  function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

  /**
   * @notice Supply with transfer approval of asset to be supplied done via permit function
   * see: https://eips.ethereum.org/EIPS/eip-2612 and https://eips.ethereum.org/EIPS/eip-713
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to be supplied
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param deadline The deadline timestamp that the permit is valid
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param permitV The V parameter of ERC712 permit sig
   * @param permitR The R parameter of ERC712 permit sig
   * @param permitS The S parameter of ERC712 permit sig
   */
  function supplyWithPermit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;

  /**
   * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
   * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
   * @param asset The address of the underlying asset to withdraw
   * @param amount The underlying amount to be withdrawn
   *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
   * @param to The address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   * @return The final amount withdrawn
   */
  function withdraw(address asset, uint256 amount, address to) external returns (uint256);

  /**
   * @notice Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
   * already supplied enough collateral, or he was given enough allowance by a credit delegator on the VariableDebtToken
   * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
   *   and 100 variable debt tokens
   * @param asset The address of the underlying asset to borrow
   * @param amount The amount to be borrowed
   * @param interestRateMode 2 for Variable, 1 is deprecated on v3.2.0
   * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param onBehalfOf The address of the user who will receive the debt. Should be the address of the borrower itself
   * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
   * if he has been given credit delegation allowance
   */
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;

  /**
   * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
   * - E.g. User repays 100 USDC, burning 100 variable debt tokens of the `onBehalfOf` address
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param interestRateMode 2 for Variable, 1 is deprecated on v3.2.0
   * @param onBehalfOf The address of the user who will get his debt reduced/removed. Should be the address of the
   * user calling the function if he wants to reduce/remove his own debt, or the address of any other
   * other borrower whose debt should be removed
   * @return The final amount repaid
   */
  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) external returns (uint256);

  /**
   * @notice Repay with transfer approval of asset to be repaid done via permit function
   * see: https://eips.ethereum.org/EIPS/eip-2612 and https://eips.ethereum.org/EIPS/eip-713
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param interestRateMode 2 for Variable, 1 is deprecated on v3.2.0
   * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
   * user calling the function if he wants to reduce/remove his own debt, or the address of any other
   * other borrower whose debt should be removed
   * @param deadline The deadline timestamp that the permit is valid
   * @param permitV The V parameter of ERC712 permit sig
   * @param permitR The R parameter of ERC712 permit sig
   * @param permitS The S parameter of ERC712 permit sig
   * @return The final amount repaid
   */
  function repayWithPermit(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external returns (uint256);

  /**
   * @notice Repays a borrowed `amount` on a specific reserve using the reserve aTokens, burning the
   * equivalent debt tokens
   * - E.g. User repays 100 USDC using 100 aUSDC, burning 100 variable debt tokens
   * @dev  Passing uint256.max as amount will clean up any residual aToken dust balance, if the user aToken
   * balance is not enough to cover the whole debt
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param interestRateMode DEPRECATED in v3.2.0
   * @return The final amount repaid
   */
  function repayWithATokens(
    address asset,
    uint256 amount,
    uint256 interestRateMode
  ) external returns (uint256);

  /**
   * @notice Allows suppliers to enable/disable a specific supplied asset as collateral
   * @param asset The address of the underlying asset supplied
   * @param useAsCollateral True if the user wants to use the supply as collateral, false otherwise
   */
  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

  /**
   * @notice Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
   * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
   *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param borrower The address of the borrower getting liquidated
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param receiveAToken True if the liquidators wants to receive the collateral aTokens, `false` if he wants
   * to receive the underlying collateral asset directly
   */
  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address borrower,
    uint256 debtToCover,
    bool receiveAToken
  ) external;

  /**
   * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
   * as long as the amount taken plus a fee is returned.
   * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
   * into consideration. For further details please visit https://docs.aave.com/developers/
   * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanReceiver interface
   * @param assets The addresses of the assets being flash-borrowed
   * @param amounts The amounts of the assets being flash-borrowed
   * @param interestRateModes Types of the debt to open if the flash loan is not returned:
   *   0 -> Don't open any debt, just revert if funds can't be transferred from the receiver
   *   1 -> Deprecated on v3.2.0
   *   2 -> Open debt at variable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
   * @param onBehalfOf The address  that will receive the debt in the case of using 2 on `modes`
   * @param params Variadic packed params to pass to the receiver as extra information
   * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   */
  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata interestRateModes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;

  /**
   * @notice Allows smartcontracts to access the liquidity of the pool within one transaction,
   * as long as the amount taken plus a fee is returned.
   * @dev IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept
   * into consideration. For further details please visit https://docs.aave.com/developers/
   * @param receiverAddress The address of the contract receiving the funds, implementing IFlashLoanSimpleReceiver interface
   * @param asset The address of the asset being flash-borrowed
   * @param amount The amount of the asset being flash-borrowed
   * @param params Variadic packed params to pass to the receiver as extra information
   * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   */
  function flashLoanSimple(
    address receiverAddress,
    address asset,
    uint256 amount,
    bytes calldata params,
    uint16 referralCode
  ) external;

  /**
   * @notice Returns the user account data across all the reserves
   * @param user The address of the user
   * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
   * @return totalDebtBase The total debt of the user in the base currency used by the price feed
   * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
   * @return currentLiquidationThreshold The liquidation threshold of the user
   * @return ltv The loan to value of The user
   * @return healthFactor The current health factor of the user
   */
  function getUserAccountData(
    address user
  )
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

  /**
   * @notice Initializes a reserve, activating it, assigning an aToken and debt tokens
   * @dev Only callable by the PoolConfigurator contract
   * @param asset The address of the underlying asset of the reserve
   * @param aTokenAddress The address of the aToken that will be assigned to the reserve
   * @param variableDebtAddress The address of the VariableDebtToken that will be assigned to the reserve
   */
  function initReserve(address asset, address aTokenAddress, address variableDebtAddress) external;

  /**
   * @notice Drop a reserve
   * @dev Only callable by the PoolConfigurator contract
   * @dev Does not reset eMode flags, which must be considered when reusing the same reserve id for a different reserve.
   * @param asset The address of the underlying asset of the reserve
   */
  function dropReserve(address asset) external;

  /**
   * @notice Accumulates interest to all indexes of the reserve
   * @dev Only callable by the PoolConfigurator contract
   * @dev To be used when required by the configurator, for example when updating interest rates strategy data
   * @param asset The address of the underlying asset of the reserve
   */
  function syncIndexesState(address asset) external;

  /**
   * @notice Updates interest rates on the reserve data
   * @dev Only callable by the PoolConfigurator contract
   * @dev To be used when required by the configurator, for example when updating interest rates strategy data
   * @param asset The address of the underlying asset of the reserve
   */
  function syncRatesState(address asset) external;

  /**
   * @notice Sets the configuration bitmap of the reserve as a whole
   * @dev Only callable by the PoolConfigurator contract
   * @param asset The address of the underlying asset of the reserve
   * @param configuration The new configuration bitmap
   */
  function setConfiguration(
    address asset,
    DataTypes.ReserveConfigurationMap calldata configuration
  ) external;

  /**
   * @notice Returns the configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The configuration of the reserve
   */
  function getConfiguration(
    address asset
  ) external view returns (DataTypes.ReserveConfigurationMap memory);

  /**
   * @notice Returns the configuration of the user across all the reserves
   * @param user The user address
   * @return The configuration of the user
   */
  function getUserConfiguration(
    address user
  ) external view returns (DataTypes.UserConfigurationMap memory);

  /**
   * @notice Returns the normalized income of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome(address asset) external view returns (uint256);

  /**
   * @notice Returns the normalized variable debt per unit of asset
   * @dev WARNING: This function is intended to be used primarily by the protocol itself to get a
   * "dynamic" variable index based on time, current stored index and virtual rate at the current
   * moment (approx. a borrower would get if opening a position). This means that is always used in
   * combination with variable debt supply/balances.
   * If using this function externally, consider that is possible to have an increasing normalized
   * variable debt that is not equivalent to how the variable debt index would be updated in storage
   * (e.g. only updates with non-zero variable debt supply)
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve normalized variable debt
   */
  function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);

  /**
   * @notice Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state and configuration data of the reserve
   */
  function getReserveData(address asset) external view returns (DataTypes.ReserveDataLegacy memory);

  /**
   * @notice Returns the virtual underlying balance of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve virtual underlying balance
   */
  function getVirtualUnderlyingBalance(address asset) external view returns (uint128);

  /**
   * @notice Validates and finalizes an aToken transfer
   * @dev Only callable by the overlying aToken of the `asset`
   * @param asset The address of the underlying asset of the aToken
   * @param from The user from which the aTokens are transferred
   * @param to The user receiving the aTokens
   * @param amount The amount being transferred/withdrawn
   * @param balanceFromBefore The aToken balance of the `from` user before the transfer
   * @param balanceToBefore The aToken balance of the `to` user before the transfer
   */
  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromBefore,
    uint256 balanceToBefore
  ) external;

  /**
   * @notice Returns the list of the underlying assets of all the initialized reserves
   * @dev It does not include dropped reserves
   * @return The addresses of the underlying assets of the initialized reserves
   */
  function getReservesList() external view returns (address[] memory);

  /**
   * @notice Returns the number of initialized reserves
   * @dev It includes dropped reserves
   * @return The count
   */
  function getReservesCount() external view returns (uint256);

  /**
   * @notice Returns the address of the underlying asset of a reserve by the reserve id as stored in the DataTypes.ReserveData struct
   * @param id The id of the reserve as stored in the DataTypes.ReserveData struct
   * @return The address of the reserve associated with id
   */
  function getReserveAddressById(uint16 id) external view returns (address);

  /**
   * @notice Returns the PoolAddressesProvider connected to this contract
   * @return The address of the PoolAddressesProvider
   */
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Returns the ReserveInterestRateStrategy connected to all the reserves
   * @return The address of the ReserveInterestRateStrategy contract
   */
  function RESERVE_INTEREST_RATE_STRATEGY() external view returns (address);

  /**
   * @notice Updates flash loan premium. All this premium is collected by the protocol treasury.
   * @dev The premium is calculated on the total borrowed amount
   * @dev Only callable by the PoolConfigurator contract
   * @param flashLoanPremium The flash loan premium, expressed in bps
   */
  function updateFlashloanPremium(uint128 flashLoanPremium) external;

  /**
   * @notice Configures a new or alters an existing collateral configuration of an eMode.
   * @dev In eMode, the protocol allows very high borrowing power to borrow assets of the same category.
   * The category 0 is reserved as it's the default for volatile assets
   * @param id The id of the category
   * @param config The configuration of the category
   */
  function configureEModeCategory(
    uint8 id,
    DataTypes.EModeCategoryBaseConfiguration memory config
  ) external;

  /**
   * @notice Replaces the current eMode collateralBitmap.
   * @param id The id of the category
   * @param collateralBitmap The collateralBitmap of the category
   */
  function configureEModeCategoryCollateralBitmap(uint8 id, uint128 collateralBitmap) external;

  /**
   * @notice Replaces the current eMode borrowableBitmap.
   * @param id The id of the category
   * @param borrowableBitmap The borrowableBitmap of the category
   */
  function configureEModeCategoryBorrowableBitmap(uint8 id, uint128 borrowableBitmap) external;

  /**
   * @notice Returns the data of an eMode category
   * @dev DEPRECATED use independent getters instead
   * @param id The id of the category
   * @return The configuration data of the category
   */
  function getEModeCategoryData(
    uint8 id
  ) external view returns (DataTypes.EModeCategoryLegacy memory);

  /**
   * @notice Returns the label of an eMode category
   * @param id The id of the category
   * @return The label of the category
   */
  function getEModeCategoryLabel(uint8 id) external view returns (string memory);

  /**
   * @notice Returns the collateral config of an eMode category
   * @param id The id of the category
   * @return The ltv,lt,lb of the category
   */
  function getEModeCategoryCollateralConfig(
    uint8 id
  ) external view returns (DataTypes.CollateralConfig memory);

  /**
   * @notice Returns the collateralBitmap of an eMode category
   * @param id The id of the category
   * @return The collateralBitmap of the category
   */
  function getEModeCategoryCollateralBitmap(uint8 id) external view returns (uint128);

  /**
   * @notice Returns the borrowableBitmap of an eMode category
   * @param id The id of the category
   * @return The borrowableBitmap of the category
   */
  function getEModeCategoryBorrowableBitmap(uint8 id) external view returns (uint128);

  /**
   * @notice Allows a user to use the protocol in eMode
   * @param categoryId The id of the category
   */
  function setUserEMode(uint8 categoryId) external;

  /**
   * @notice Returns the eMode the user is using
   * @param user The address of the user
   * @return The eMode id
   */
  function getUserEMode(address user) external view returns (uint256);

  /**
   * @notice Resets the isolation mode total debt of the given asset to zero
   * @dev It requires the given asset has zero debt ceiling
   * @param asset The address of the underlying asset to reset the isolationModeTotalDebt
   */
  function resetIsolationModeTotalDebt(address asset) external;

  /**
   * @notice Sets the liquidation grace period of the given asset
   * @dev To enable a liquidation grace period, a timestamp in the future should be set,
   *      To disable a liquidation grace period, any timestamp in the past works, like 0
   * @param asset The address of the underlying asset to set the liquidationGracePeriod
   * @param until Timestamp when the liquidation grace period will end
   **/
  function setLiquidationGracePeriod(address asset, uint40 until) external;

  /**
   * @notice Returns the liquidation grace period of the given asset
   * @param asset The address of the underlying asset
   * @return Timestamp when the liquidation grace period will end
   **/
  function getLiquidationGracePeriod(address asset) external view returns (uint40);

  /**
   * @notice Returns the total fee on flash loans.
   * @dev From v3.4 all flashloan fees will be send to the treasury.
   * @return The total fee on flashloans
   */
  function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);

  /**
   * @notice Returns the part of the flashloan fees sent to protocol
   * @dev From v3.4 all flashloan fees will be send to the treasury and this value
   *      is always 100_00.
   * @return The flashloan fee sent to the protocol treasury
   */
  function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128);

  /**
   * @notice Returns the maximum number of reserves supported to be listed in this Pool
   * @return The maximum number of reserves supported
   */
  function MAX_NUMBER_RESERVES() external view returns (uint16);

  /**
   * @notice Mints the assets accrued through the reserve factor to the treasury in the form of aTokens
   * @param assets The list of reserves for which the minting needs to be executed
   */
  function mintToTreasury(address[] calldata assets) external;

  /**
   * @notice Rescue and transfer tokens locked in this contract
   * @param token The address of the token
   * @param to The address of the recipient
   * @param amount The amount of token to transfer
   */
  function rescueTokens(address token, address to, uint256 amount) external;

  /**
   * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
   * @dev Deprecated: Use the `supply` function instead
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to be supplied
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   */
  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

  /**
   * @notice It covers the deficit of a specified reserve by burning the equivalent aToken `amount` for assets
   * @dev The deficit of a reserve can occur due to situations where borrowed assets are not repaid, leading to bad debt.
   * @param asset The address of the underlying asset to cover the deficit.
   * @param amount The amount to be covered, in aToken
   */
  function eliminateReserveDeficit(address asset, uint256 amount) external;

  /**
   * @notice Approves or disapproves a position manager. This position manager will be able
   * to call the `setUserUseReserveAsCollateralOnBehalfOf` and the
   * `setUserEModeOnBehalfOf` function on behalf of the user.
   * @param positionManager The address of the position manager
   * @param approve True if the position manager should be approved, false otherwise
   */
  function approvePositionManager(address positionManager, bool approve) external;

  /**
   * @notice Renounces a position manager role for a given user.
   * @param user The address of the user
   */
  function renouncePositionManagerRole(address user) external;

  /**
   * @notice Sets the use as collateral flag for the user on the specific reserve on behalf of the user.
   * @param asset The address of the underlying asset of the reserve
   * @param useAsCollateral True if the user wants to use the reserve as collateral, false otherwise
   * @param onBehalfOf The address of the user
   */
  function setUserUseReserveAsCollateralOnBehalfOf(
    address asset,
    bool useAsCollateral,
    address onBehalfOf
  ) external;

  /**
   * @notice Sets the eMode category for the user on the specific reserve on behalf of the user.
   * @param categoryId The id of the category
   * @param onBehalfOf The address of the user
   */
  function setUserEModeOnBehalfOf(uint8 categoryId, address onBehalfOf) external;

  /*
   * @notice Returns true if the `positionManager` address is approved to use the position manager role on behalf of the user.
   * @param user The address of the user
   * @param positionManager The address of the position manager
   * @return True if the user is approved to use the position manager, false otherwise
   */
  function isApprovedPositionManager(
    address user,
    address positionManager
  ) external view returns (bool);

  /**
   * @notice Returns the current deficit of a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @return The current deficit of the reserve
   */
  function getReserveDeficit(address asset) external view returns (uint256);

  /**
   * @notice Returns the aToken address of a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @return The address of the aToken
   */
  function getReserveAToken(address asset) external view returns (address);

  /**
   * @notice Returns the variableDebtToken address of a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @return The address of the variableDebtToken
   */
  function getReserveVariableDebtToken(address asset) external view returns (address);

  /**
   * @notice Gets the address of the external FlashLoanLogic
   */
  function getFlashLoanLogic() external view returns (address);

  /**
   * @notice Gets the address of the external BorrowLogic
   */
  function getBorrowLogic() external view returns (address);

  /**
   * @notice Gets the address of the external EModeLogic
   */
  function getEModeLogic() external view returns (address);

  /**
   * @notice Gets the address of the external LiquidationLogic
   */
  function getLiquidationLogic() external view returns (address);

  /**
   * @notice Gets the address of the external PoolLogic
   */
  function getPoolLogic() external view returns (address);

  /**
   * @notice Gets the address of the external SupplyLogic
   */
  function getSupplyLogic() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ConfiguratorInputTypes} from '../protocol/libraries/types/ConfiguratorInputTypes.sol';
import {IDefaultInterestRateStrategyV2} from './IDefaultInterestRateStrategyV2.sol';

/**
 * @title IPoolConfigurator
 * @author Aave
 * @notice Defines the basic interface for a Pool configurator.
 */
interface IPoolConfigurator {
  /**
   * @dev Emitted when a reserve is initialized.
   * @param asset The address of the underlying asset of the reserve
   * @param aToken The address of the associated aToken contract
   * @param stableDebtToken, DEPRECATED in v3.2.0
   * @param variableDebtToken The address of the associated variable rate debt token
   * @param interestRateStrategyAddress The address of the interest rate strategy for the reserve
   */
  event ReserveInitialized(
    address indexed asset,
    address indexed aToken,
    address stableDebtToken,
    address variableDebtToken,
    address interestRateStrategyAddress
  );

  /**
   * @dev Emitted when borrowing is enabled or disabled on a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param enabled True if borrowing is enabled, false otherwise
   */
  event ReserveBorrowing(address indexed asset, bool enabled);

  /**
   * @dev Emitted when flashloans are enabled or disabled on a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param enabled True if flashloans are enabled, false otherwise
   */
  event ReserveFlashLoaning(address indexed asset, bool enabled);

  /**
   * @dev Emitted when the ltv is set for the frozen asset.
   * @param asset The address of the underlying asset of the reserve
   * @param ltv The loan to value of the asset when used as collateral
   */
  event PendingLtvChanged(address indexed asset, uint256 ltv);

  /**
   * @dev Emitted when the collateralization risk parameters for the specified asset are updated.
   * @param asset The address of the underlying asset of the reserve
   * @param ltv The loan to value of the asset when used as collateral
   * @param liquidationThreshold The threshold at which loans using this asset as collateral will be considered undercollateralized
   * @param liquidationBonus The bonus liquidators receive to liquidate this asset
   */
  event CollateralConfigurationChanged(
    address indexed asset,
    uint256 ltv,
    uint256 liquidationThreshold,
    uint256 liquidationBonus
  );

  /**
   * @dev Emitted when a reserve is activated or deactivated
   * @param asset The address of the underlying asset of the reserve
   * @param active True if reserve is active, false otherwise
   */
  event ReserveActive(address indexed asset, bool active);

  /**
   * @dev Emitted when a reserve is frozen or unfrozen
   * @param asset The address of the underlying asset of the reserve
   * @param frozen True if reserve is frozen, false otherwise
   */
  event ReserveFrozen(address indexed asset, bool frozen);

  /**
   * @dev Emitted when a reserve is paused or unpaused
   * @param asset The address of the underlying asset of the reserve
   * @param paused True if reserve is paused, false otherwise
   */
  event ReservePaused(address indexed asset, bool paused);

  /**
   * @dev Emitted when a reserve is dropped.
   * @param asset The address of the underlying asset of the reserve
   */
  event ReserveDropped(address indexed asset);

  /**
   * @dev Emitted when a reserve factor is updated.
   * @param asset The address of the underlying asset of the reserve
   * @param oldReserveFactor The old reserve factor, expressed in bps
   * @param newReserveFactor The new reserve factor, expressed in bps
   */
  event ReserveFactorChanged(
    address indexed asset,
    uint256 oldReserveFactor,
    uint256 newReserveFactor
  );

  /**
   * @dev Emitted when the borrow cap of a reserve is updated.
   * @param asset The address of the underlying asset of the reserve
   * @param oldBorrowCap The old borrow cap
   * @param newBorrowCap The new borrow cap
   */
  event BorrowCapChanged(address indexed asset, uint256 oldBorrowCap, uint256 newBorrowCap);

  /**
   * @dev Emitted when the supply cap of a reserve is updated.
   * @param asset The address of the underlying asset of the reserve
   * @param oldSupplyCap The old supply cap
   * @param newSupplyCap The new supply cap
   */
  event SupplyCapChanged(address indexed asset, uint256 oldSupplyCap, uint256 newSupplyCap);

  /**
   * @dev Emitted when the liquidation protocol fee of a reserve is updated.
   * @param asset The address of the underlying asset of the reserve
   * @param oldFee The old liquidation protocol fee, expressed in bps
   * @param newFee The new liquidation protocol fee, expressed in bps
   */
  event LiquidationProtocolFeeChanged(address indexed asset, uint256 oldFee, uint256 newFee);

  /**
   * @dev Emitted when the liquidation grace period is updated.
   * @param asset The address of the underlying asset of the reserve
   * @param gracePeriodUntil Timestamp until when liquidations will not be allowed post-unpause
   */
  event LiquidationGracePeriodChanged(address indexed asset, uint40 gracePeriodUntil);

  /**
   * @dev Emitted when the liquidation grace period is disabled.
   * @param asset The address of the underlying asset of the reserve
   */
  event LiquidationGracePeriodDisabled(address indexed asset);

  /**
   * @dev Emitted when an collateral configuration of an asset in an eMode is changed.
   * @param asset The address of the underlying asset of the reserve
   * @param categoryId The eMode category
   * @param collateral True if the asset is enabled as collateral in the eMode, false otherwise.
   */
  event AssetCollateralInEModeChanged(address indexed asset, uint8 categoryId, bool collateral);

  /**
   * @dev Emitted when the borrowable configuration of an asset in an eMode changed.
   * @param asset The address of the underlying asset of the reserve
   * @param categoryId The eMode category
   * @param borrowable True if the asset is enabled as borrowable in the eMode, false otherwise.
   */
  event AssetBorrowableInEModeChanged(address indexed asset, uint8 categoryId, bool borrowable);

  /**
   * @dev Emitted when a new eMode category is added or an existing category is altered.
   * @param categoryId The new eMode category id
   * @param ltv The ltv for the asset category in eMode
   * @param liquidationThreshold The liquidationThreshold for the asset category in eMode
   * @param liquidationBonus The liquidationBonus for the asset category in eMode
   * @param oracle DEPRECATED in v3.2.0
   * @param label A human readable identifier for the category
   */
  event EModeCategoryAdded(
    uint8 indexed categoryId,
    uint256 ltv,
    uint256 liquidationThreshold,
    uint256 liquidationBonus,
    address oracle,
    string label
  );

  /**
   * @dev Emitted when a reserve interest strategy contract is updated.
   * @param asset The address of the underlying asset of the reserve
   * @param oldStrategy The address of the old interest strategy contract
   * @param newStrategy The address of the new interest strategy contract
   */
  event ReserveInterestRateStrategyChanged(
    address indexed asset,
    address oldStrategy,
    address newStrategy
  );

  /**
   * @dev Emitted when the data of a reserve interest strategy contract is updated.
   * @param asset The address of the underlying asset of the reserve
   * @param data abi encoded data
   */
  event ReserveInterestRateDataChanged(address indexed asset, address indexed strategy, bytes data);

  /**
   * @dev Emitted when an aToken implementation is upgraded.
   * @param asset The address of the underlying asset of the reserve
   * @param proxy The aToken proxy address
   * @param implementation The new aToken implementation
   */
  event ATokenUpgraded(
    address indexed asset,
    address indexed proxy,
    address indexed implementation
  );

  /**
   * @dev Emitted when the implementation of a variable debt token is upgraded.
   * @param asset The address of the underlying asset of the reserve
   * @param proxy The variable debt token proxy address
   * @param implementation The new aToken implementation
   */
  event VariableDebtTokenUpgraded(
    address indexed asset,
    address indexed proxy,
    address indexed implementation
  );

  /**
   * @dev Emitted when the debt ceiling of an asset is set.
   * @param asset The address of the underlying asset of the reserve
   * @param oldDebtCeiling The old debt ceiling
   * @param newDebtCeiling The new debt ceiling
   */
  event DebtCeilingChanged(address indexed asset, uint256 oldDebtCeiling, uint256 newDebtCeiling);

  /**
   * @dev Emitted when the the siloed borrowing state for an asset is changed.
   * @param asset The address of the underlying asset of the reserve
   * @param oldState The old siloed borrowing state
   * @param newState The new siloed borrowing state
   */
  event SiloedBorrowingChanged(address indexed asset, bool oldState, bool newState);

  /**
   * @dev Emitted when the bridge protocol fee is updated.
   * @param oldBridgeProtocolFee The old protocol fee, expressed in bps
   * @param newBridgeProtocolFee The new protocol fee, expressed in bps
   */
  event BridgeProtocolFeeUpdated(uint256 oldBridgeProtocolFee, uint256 newBridgeProtocolFee);

  /**
   * @dev Emitted when the total premium on flashloans is updated.
   * @param oldFlashloanPremiumTotal The old premium, expressed in bps
   * @param newFlashloanPremiumTotal The new premium, expressed in bps
   */
  event FlashloanPremiumTotalUpdated(
    uint128 oldFlashloanPremiumTotal,
    uint128 newFlashloanPremiumTotal
  );

  /**
   * @dev Emitted when the part of the premium that goes to protocol is updated.
          Deprecated, from the v3.4 version the `flashloanPremiumToProtocol` value
          is always 100%.
   * @param oldFlashloanPremiumToProtocol The old premium, expressed in bps
   * @param newFlashloanPremiumToProtocol The new premium, expressed in bps
   */
  event FlashloanPremiumToProtocolUpdated(
    uint128 oldFlashloanPremiumToProtocol,
    uint128 newFlashloanPremiumToProtocol
  );

  /**
   * @dev Emitted when the reserve is set as borrowable/non borrowable in isolation mode.
   * @param asset The address of the underlying asset of the reserve
   * @param borrowable True if the reserve is borrowable in isolation, false otherwise
   */
  event BorrowableInIsolationChanged(address asset, bool borrowable);

  /**
   * @notice Initializes multiple reserves.
   * @param input The array of initialization parameters
   */
  function initReserves(ConfiguratorInputTypes.InitReserveInput[] calldata input) external;

  /**
   * @dev Updates the aToken implementation for the reserve.
   * @param input The aToken update parameters
   */
  function updateAToken(ConfiguratorInputTypes.UpdateATokenInput calldata input) external;

  /**
   * @notice Updates the variable debt token implementation for the asset.
   * @param input The variableDebtToken update parameters
   */
  function updateVariableDebtToken(
    ConfiguratorInputTypes.UpdateDebtTokenInput calldata input
  ) external;

  /**
   * @notice Configures borrowing on a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param enabled True if borrowing needs to be enabled, false otherwise
   */
  function setReserveBorrowing(address asset, bool enabled) external;

  /**
   * @notice Configures the reserve collateralization parameters.
   * @dev All the values are expressed in bps. A value of 10000, results in 100.00%
   * @dev The `liquidationBonus` is always above 100%. A value of 105% means the liquidator will receive a 5% bonus
   * @param asset The address of the underlying asset of the reserve
   * @param ltv The loan to value of the asset when used as collateral
   * @param liquidationThreshold The threshold at which loans using this asset as collateral will be considered undercollateralized
   * @param liquidationBonus The bonus liquidators receive to liquidate this asset
   */
  function configureReserveAsCollateral(
    address asset,
    uint256 ltv,
    uint256 liquidationThreshold,
    uint256 liquidationBonus
  ) external;

  /**
   * @notice Enable or disable flashloans on a reserve
   * @param asset The address of the underlying asset of the reserve
   * @param enabled True if flashloans need to be enabled, false otherwise
   */
  function setReserveFlashLoaning(address asset, bool enabled) external;

  /**
   * @notice Activate or deactivate a reserve
   * @param asset The address of the underlying asset of the reserve
   * @param active True if the reserve needs to be active, false otherwise
   */
  function setReserveActive(address asset, bool active) external;

  /**
   * @notice Freeze or unfreeze a reserve. A frozen reserve doesn't allow any new supply, borrow
   * or rate swap but allows repayments, liquidations, rate rebalances and withdrawals.
   * @param asset The address of the underlying asset of the reserve
   * @param freeze True if the reserve needs to be frozen, false otherwise
   */
  function setReserveFreeze(address asset, bool freeze) external;

  /**
   * @notice Sets the borrowable in isolation flag for the reserve.
   * @dev When this flag is set to true, the asset will be borrowable against isolated collaterals and the
   * borrowed amount will be accumulated in the isolated collateral's total debt exposure
   * @dev Only assets of the same family (e.g. USD stablecoins) should be borrowable in isolation mode to keep
   * consistency in the debt ceiling calculations
   * @param asset The address of the underlying asset of the reserve
   * @param borrowable True if the asset should be borrowable in isolation, false otherwise
   */
  function setBorrowableInIsolation(address asset, bool borrowable) external;

  /**
   * @notice Pauses a reserve. A paused reserve does not allow any interaction (supply, borrow, repay,
   * swap interest rate, liquidate, atoken transfers).
   * @param asset The address of the underlying asset of the reserve
   * @param paused True if pausing the reserve, false if unpausing
   * @param gracePeriod Count of seconds after unpause during which liquidations will not be available
   *   - Only applicable whenever unpausing (`paused` as false)
   *   - Passing 0 means no grace period
   *   - Capped to maximum MAX_GRACE_PERIOD
   */
  function setReservePause(address asset, bool paused, uint40 gracePeriod) external;

  /**
   * @notice Pauses a reserve. A paused reserve does not allow any interaction (supply, borrow, repay,
   * swap interest rate, liquidate, atoken transfers).
   * @dev Version with no grace period
   * @param asset The address of the underlying asset of the reserve
   * @param paused True if pausing the reserve, false if unpausing
   */
  function setReservePause(address asset, bool paused) external;

  /**
   * @notice Disables liquidation grace period for the asset. The liquidation grace period is set in the past
   * so that liquidations are allowed for the asset.
   * @param asset The address of the underlying asset of the reserve
   */
  function disableLiquidationGracePeriod(address asset) external;

  /**
   * @notice Updates the reserve factor of a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param newReserveFactor The new reserve factor of the reserve
   */
  function setReserveFactor(address asset, uint256 newReserveFactor) external;

  /**
   * @notice Sets interest rate data for a reserve
   * @param asset The address of the underlying asset of the reserve
   * @param rateData bytes-encoded rate data. In this format in order to allow the rate strategy contract
   *  to de-structure custom data
   */
  function setReserveInterestRateData(address asset, bytes calldata rateData) external;

  /**
   * @notice Pauses or unpauses all the protocol reserves. In the paused state all the protocol interactions
   * are suspended.
   * @param paused True if protocol needs to be paused, false otherwise
   * @param gracePeriod Count of seconds after unpause during which liquidations will not be available
   *   - Only applicable whenever unpausing (`paused` as false)
   *   - Passing 0 means no grace period
   *   - Capped to maximum MAX_GRACE_PERIOD
   */
  function setPoolPause(bool paused, uint40 gracePeriod) external;

  /**
   * @notice Pauses or unpauses all the protocol reserves. In the paused state all the protocol interactions
   * are suspended.
   * @dev Version with no grace period
   * @param paused True if protocol needs to be paused, false otherwise
   */
  function setPoolPause(bool paused) external;

  /**
   * @notice Updates the borrow cap of a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param newBorrowCap The new borrow cap of the reserve
   */
  function setBorrowCap(address asset, uint256 newBorrowCap) external;

  /**
   * @notice Updates the supply cap of a reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param newSupplyCap The new supply cap of the reserve
   */
  function setSupplyCap(address asset, uint256 newSupplyCap) external;

  /**
   * @notice Updates the liquidation protocol fee of reserve.
   * @param asset The address of the underlying asset of the reserve
   * @param newFee The new liquidation protocol fee of the reserve, expressed in bps
   */
  function setLiquidationProtocolFee(address asset, uint256 newFee) external;

  /**
   * @notice Enables/disables an asset to be borrowable in a selected eMode.
   * - eMode.borrowable always has less priority then reserve.borrowable
   * @param asset The address of the underlying asset of the reserve
   * @param categoryId The eMode categoryId
   * @param borrowable True if the asset should be borrowable in the given eMode category, false otherwise.
   */
  function setAssetBorrowableInEMode(address asset, uint8 categoryId, bool borrowable) external;

  /**
   * @notice Enables/disables an asset to be collateral in a selected eMode.
   * @param asset The address of the underlying asset of the reserve
   * @param categoryId The eMode categoryId
   * @param collateral True if the asset should be collateral in the given eMode category, false otherwise.
   */
  function setAssetCollateralInEMode(address asset, uint8 categoryId, bool collateral) external;

  /**
   * @notice Adds a new efficiency mode (eMode) category or alters a existing one.
   * @param categoryId The id of the category to be configured
   * @param ltv The ltv associated with the category
   * @param liquidationThreshold The liquidation threshold associated with the category
   * @param liquidationBonus The liquidation bonus associated with the category
   * @param label A label identifying the category
   */
  function setEModeCategory(
    uint8 categoryId,
    uint16 ltv,
    uint16 liquidationThreshold,
    uint16 liquidationBonus,
    string calldata label
  ) external;

  /**
   * @notice Drops a reserve entirely.
   * @param asset The address of the reserve to drop
   */
  function dropReserve(address asset) external;

  /**
   * @notice Updates the flash loan premium. All this premium
   *         will be collected by the treasury.
   * @dev Expressed in bps
   * @dev The premium is calculated on the total amount borrowed
   * @param newFlashloanPremium The flashloan premium
   */
  function updateFlashloanPremium(uint128 newFlashloanPremium) external;

  /**
   * @notice Sets the debt ceiling for an asset.
   * @param newDebtCeiling The new debt ceiling
   */
  function setDebtCeiling(address asset, uint256 newDebtCeiling) external;

  /**
   * @notice Sets siloed borrowing for an asset
   * @param siloed The new siloed borrowing state
   */
  function setSiloedBorrowing(address asset, bool siloed) external;

  /**
   * @notice Gets pending ltv value
   * @param asset The new siloed borrowing state
   */
  function getPendingLtv(address asset) external view returns (uint256);

  /**
   * @notice Gets the address of the external ConfiguratorLogic
   */
  function getConfiguratorLogic() external view returns (address);

  /**
   * @notice Gets the maximum liquidations grace period allowed, in seconds
   */
  function MAX_GRACE_PERIOD() external view returns (uint40);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPriceOracleGetter} from './IPriceOracleGetter.sol';
import {IPoolAddressesProvider} from './IPoolAddressesProvider.sol';

/**
 * @title IAaveOracle
 * @author Aave
 * @notice Defines the basic interface for the Aave Oracle
 */
interface IAaveOracle is IPriceOracleGetter {
  /**
   * @dev Emitted after the base currency is set
   * @param baseCurrency The base currency of used for price quotes
   * @param baseCurrencyUnit The unit of the base currency
   */
  event BaseCurrencySet(address indexed baseCurrency, uint256 baseCurrencyUnit);

  /**
   * @dev Emitted after the price source of an asset is updated
   * @param asset The address of the asset
   * @param source The price source of the asset
   */
  event AssetSourceUpdated(address indexed asset, address indexed source);

  /**
   * @dev Emitted after the address of fallback oracle is updated
   * @param fallbackOracle The address of the fallback oracle
   */
  event FallbackOracleUpdated(address indexed fallbackOracle);

  /**
   * @notice Returns the PoolAddressesProvider
   * @return The address of the PoolAddressesProvider contract
   */
  function ADDRESSES_PROVIDER() external view returns (IPoolAddressesProvider);

  /**
   * @notice Sets or replaces price sources of assets
   * @param assets The addresses of the assets
   * @param sources The addresses of the price sources
   */
  function setAssetSources(address[] calldata assets, address[] calldata sources) external;

  /**
   * @notice Sets the fallback oracle
   * @param fallbackOracle The address of the fallback oracle
   */
  function setFallbackOracle(address fallbackOracle) external;

  /**
   * @notice Returns a list of prices from a list of assets addresses
   * @param assets The list of assets addresses
   * @return The prices of the given assets
   */
  function getAssetsPrices(address[] calldata assets) external view returns (uint256[] memory);

  /**
   * @notice Returns the address of the source for an asset address
   * @param asset The address of the asset
   * @return The address of the source
   */
  function getSourceOfAsset(address asset) external view returns (address);

  /**
   * @notice Returns the address of the fallback oracle
   * @return The address of the fallback oracle
   */
  function getFallbackOracle() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author Aave
 * @notice Defines the error messages emitted by the different contracts of the Aave protocol
 */
library Errors {
  error CallerNotPoolAdmin(); // 'The caller of the function is not a pool admin'
  error CallerNotPoolOrEmergencyAdmin(); // 'The caller of the function is not a pool or emergency admin'
  error CallerNotRiskOrPoolAdmin(); // 'The caller of the function is not a risk or pool admin'
  error CallerNotAssetListingOrPoolAdmin(); // 'The caller of the function is not an asset listing or pool admin'
  error AddressesProviderNotRegistered(); // 'Pool addresses provider is not registered'
  error InvalidAddressesProviderId(); // 'Invalid id for the pool addresses provider'
  error NotContract(); // 'Address is not a contract'
  error CallerNotPoolConfigurator(); // 'The caller of the function is not the pool configurator'
  error CallerNotAToken(); // 'The caller of the function is not an AToken'
  error InvalidAddressesProvider(); // 'The address of the pool addresses provider is invalid'
  error InvalidFlashloanExecutorReturn(); // 'Invalid return value of the flashloan executor function'
  error ReserveAlreadyAdded(); // 'Reserve has already been added to reserve list'
  error NoMoreReservesAllowed(); // 'Maximum amount of reserves in the pool reached'
  error EModeCategoryReserved(); // 'Zero eMode category is reserved for volatile heterogeneous assets'
  error ReserveLiquidityNotZero(); // 'The liquidity of the reserve needs to be 0'
  error FlashloanPremiumInvalid(); // 'Invalid flashloan premium'
  error InvalidReserveParams(); // 'Invalid risk parameters for the reserve'
  error InvalidEmodeCategoryParams(); // 'Invalid risk parameters for the eMode category'
  error CallerMustBePool(); // 'The caller of this function must be a pool'
  error InvalidMintAmount(); // 'Invalid amount to mint'
  error InvalidBurnAmount(); // 'Invalid amount to burn'
  error InvalidAmount(); // 'Amount must be greater than 0'
  error ReserveInactive(); // 'Action requires an active reserve'
  error ReserveFrozen(); // 'Action cannot be performed because the reserve is frozen'
  error ReservePaused(); // 'Action cannot be performed because the reserve is paused'
  error BorrowingNotEnabled(); // 'Borrowing is not enabled'
  error NotEnoughAvailableUserBalance(); // 'User cannot withdraw more than the available balance'
  error InvalidInterestRateModeSelected(); // 'Invalid interest rate mode selected'
  error CollateralBalanceIsZero(); // 'The collateral balance is 0'
  error HealthFactorLowerThanLiquidationThreshold(); // 'Health factor is below the liquidation threshold'
  error CollateralCannotCoverNewBorrow(); // 'There is not enough collateral to cover a new borrow'
  error NoDebtOfSelectedType(); // 'For repayment of a specific type of debt, the user needs to have debt that type'
  error NoExplicitAmountToRepayOnBehalf(); // 'To repay on behalf of a user an explicit amount to repay is needed'
  error UnderlyingBalanceZero(); // 'The underlying balance needs to be greater than 0'
  error HealthFactorNotBelowThreshold(); // 'Health factor is not below the threshold'
  error CollateralCannotBeLiquidated(); // 'The collateral chosen cannot be liquidated'
  error SpecifiedCurrencyNotBorrowedByUser(); // 'User did not borrow the specified currency'
  error InconsistentFlashloanParams(); // 'Inconsistent flashloan parameters'
  error BorrowCapExceeded(); // 'Borrow cap is exceeded'
  error SupplyCapExceeded(); // 'Supply cap is exceeded'
  error DebtCeilingExceeded(); // 'Debt ceiling is exceeded'
  error UnderlyingClaimableRightsNotZero(); // 'Claimable rights over underlying not zero (aToken supply or accruedToTreasury)'
  error VariableDebtSupplyNotZero(); // 'Variable debt supply is not zero'
  error LtvValidationFailed(); // 'Ltv validation failed'
  error InconsistentEModeCategory(); // 'Inconsistent eMode category'
  error PriceOracleSentinelCheckFailed(); // 'Price oracle sentinel validation failed'
  error AssetNotBorrowableInIsolation(); // 'Asset is not borrowable in isolation mode'
  error ReserveAlreadyInitialized(); // 'Reserve has already been initialized'
  error UserInIsolationModeOrLtvZero(); // 'User is in isolation mode or ltv is zero'
  error InvalidLtv(); // 'Invalid ltv parameter for the reserve'
  error InvalidLiquidationThreshold(); // 'Invalid liquidity threshold parameter for the reserve'
  error InvalidLiquidationBonus(); // 'Invalid liquidity bonus parameter for the reserve'
  error InvalidDecimals(); // 'Invalid decimals parameter of the underlying asset of the reserve'
  error InvalidReserveFactor(); // 'Invalid reserve factor parameter for the reserve'
  error InvalidBorrowCap(); // 'Invalid borrow cap for the reserve'
  error InvalidSupplyCap(); // 'Invalid supply cap for the reserve'
  error InvalidLiquidationProtocolFee(); // 'Invalid liquidation protocol fee for the reserve'
  error InvalidDebtCeiling(); // 'Invalid debt ceiling for the reserve'
  error InvalidReserveIndex(); // 'Invalid reserve index'
  error AclAdminCannotBeZero(); // 'ACL admin cannot be set to the zero address'
  error InconsistentParamsLength(); // 'Array parameters that should be equal length are not'
  error ZeroAddressNotValid(); // 'Zero address not valid'
  error InvalidExpiration(); // 'Invalid expiration'
  error InvalidSignature(); // 'Invalid signature'
  error OperationNotSupported(); // 'Operation not supported'
  error DebtCeilingNotZero(); // 'Debt ceiling is not zero'
  error AssetNotListed(); // 'Asset is not listed'
  error InvalidOptimalUsageRatio(); // 'Invalid optimal usage ratio'
  error UnderlyingCannotBeRescued(); // 'The underlying asset cannot be rescued'
  error AddressesProviderAlreadyAdded(); // 'Reserve has already been added to reserve list'
  error PoolAddressesDoNotMatch(); // 'The token implementation pool address and the pool address provided by the initializing pool do not match'
  error SiloedBorrowingViolation(); // 'User is trying to borrow multiple assets including a siloed one'
  error ReserveDebtNotZero(); // the total debt of the reserve needs to be 0
  error FlashloanDisabled(); // FlashLoaning for this asset is disabled
  error InvalidMaxRate(); // The expect maximum borrow rate is invalid
  error WithdrawToAToken(); // Withdrawing to the aToken is not allowed
  error SupplyToAToken(); // Supplying to the aToken is not allowed
  error Slope2MustBeGteSlope1(); // Variable interest rate slope 2 can not be lower than slope 1
  error CallerNotRiskOrPoolOrEmergencyAdmin(); // 'The caller of the function is not a risk, pool or emergency admin'
  error LiquidationGraceSentinelCheckFailed(); // 'Liquidation grace sentinel validation failed'
  error InvalidGracePeriod(); // Grace period above a valid range
  error InvalidFreezeState(); // Reserve is already in the passed freeze state
  error NotBorrowableInEMode(); // Asset not borrowable in eMode
  error CallerNotUmbrella(); // The caller of the function is not the umbrella contract
  error ReserveNotInDeficit(); // The reserve is not in deficit
  error MustNotLeaveDust(); // Below a certain threshold liquidators need to take the full position
  error UserCannotHaveDebt(); // Thrown when a user tries to interact with a method that requires a position without debt
  error SelfLiquidation(); // Thrown when a user tries to liquidate themselves
  error CallerNotPositionManager(); // Thrown when the caller has not been enabled as a position manager of the on-behalf-of user
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from '../protocol/libraries/types/DataTypes.sol';

/**
 * @title IReserveInterestRateStrategy
 * @author BGD Labs
 * @notice Basic interface for any rate strategy used by the Aave protocol
 */
interface IReserveInterestRateStrategy {
  /**
   * @notice Sets interest rate data for an Aave rate strategy
   * @param reserve The reserve to update
   * @param rateData The abi encoded reserve interest rate data to apply to the given reserve
   *   Abstracted this way as rate strategies can be custom
   */
  function setInterestRateParams(address reserve, bytes calldata rateData) external;

  /**
   * @notice Calculates the interest rates depending on the reserve's state and configurations
   * @param params The parameters needed to calculate interest rates
   * @return liquidityRate The liquidity rate expressed in ray
   * @return variableBorrowRate The variable borrow rate expressed in ray
   */
  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) external view returns (uint256, uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IPoolAddressesProvider
 * @author Aave
 * @notice Defines the basic interface for a Pool Addresses Provider.
 */
interface IPoolAddressesProvider {
  /**
   * @dev Emitted when the market identifier is updated.
   * @param oldMarketId The old id of the market
   * @param newMarketId The new id of the market
   */
  event MarketIdSet(string indexed oldMarketId, string indexed newMarketId);

  /**
   * @dev Emitted when the pool is updated.
   * @param oldAddress The old address of the Pool
   * @param newAddress The new address of the Pool
   */
  event PoolUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the pool configurator is updated.
   * @param oldAddress The old address of the PoolConfigurator
   * @param newAddress The new address of the PoolConfigurator
   */
  event PoolConfiguratorUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the price oracle is updated.
   * @param oldAddress The old address of the PriceOracle
   * @param newAddress The new address of the PriceOracle
   */
  event PriceOracleUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the ACL manager is updated.
   * @param oldAddress The old address of the ACLManager
   * @param newAddress The new address of the ACLManager
   */
  event ACLManagerUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the ACL admin is updated.
   * @param oldAddress The old address of the ACLAdmin
   * @param newAddress The new address of the ACLAdmin
   */
  event ACLAdminUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the price oracle sentinel is updated.
   * @param oldAddress The old address of the PriceOracleSentinel
   * @param newAddress The new address of the PriceOracleSentinel
   */
  event PriceOracleSentinelUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the pool data provider is updated.
   * @param oldAddress The old address of the PoolDataProvider
   * @param newAddress The new address of the PoolDataProvider
   */
  event PoolDataProviderUpdated(address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when a new proxy is created.
   * @param id The identifier of the proxy
   * @param proxyAddress The address of the created proxy contract
   * @param implementationAddress The address of the implementation contract
   */
  event ProxyCreated(
    bytes32 indexed id,
    address indexed proxyAddress,
    address indexed implementationAddress
  );

  /**
   * @dev Emitted when a new non-proxied contract address is registered.
   * @param id The identifier of the contract
   * @param oldAddress The address of the old contract
   * @param newAddress The address of the new contract
   */
  event AddressSet(bytes32 indexed id, address indexed oldAddress, address indexed newAddress);

  /**
   * @dev Emitted when the implementation of the proxy registered with id is updated
   * @param id The identifier of the contract
   * @param proxyAddress The address of the proxy contract
   * @param oldImplementationAddress The address of the old implementation contract
   * @param newImplementationAddress The address of the new implementation contract
   */
  event AddressSetAsProxy(
    bytes32 indexed id,
    address indexed proxyAddress,
    address oldImplementationAddress,
    address indexed newImplementationAddress
  );

  /**
   * @notice Returns the id of the Aave market to which this contract points to.
   * @return The market id
   */
  function getMarketId() external view returns (string memory);

  /**
   * @notice Associates an id with a specific PoolAddressesProvider.
   * @dev This can be used to create an onchain registry of PoolAddressesProviders to
   * identify and validate multiple Aave markets.
   * @param newMarketId The market id
   */
  function setMarketId(string calldata newMarketId) external;

  /**
   * @notice Returns an address by its identifier.
   * @dev The returned address might be an EOA or a contract, potentially proxied
   * @dev It returns ZERO if there is no registered address with the given id
   * @param id The id
   * @return The address of the registered for the specified id
   */
  function getAddress(bytes32 id) external view returns (address);

  /**
   * @notice General function to update the implementation of a proxy registered with
   * certain `id`. If there is no proxy registered, it will instantiate one and
   * set as implementation the `newImplementationAddress`.
   * @dev IMPORTANT Use this function carefully, only for ids that don't have an explicit
   * setter function, in order to avoid unexpected consequences
   * @param id The id
   * @param newImplementationAddress The address of the new implementation
   */
  function setAddressAsProxy(bytes32 id, address newImplementationAddress) external;

  /**
   * @notice Sets an address for an id replacing the address saved in the addresses map.
   * @dev IMPORTANT Use this function carefully, as it will do a hard replacement
   * @param id The id
   * @param newAddress The address to set
   */
  function setAddress(bytes32 id, address newAddress) external;

  /**
   * @notice Returns the address of the Pool proxy.
   * @return The Pool proxy address
   */
  function getPool() external view returns (address);

  /**
   * @notice Updates the implementation of the Pool, or creates a proxy
   * setting the new `pool` implementation when the function is called for the first time.
   * @param newPoolImpl The new Pool implementation
   */
  function setPoolImpl(address newPoolImpl) external;

  /**
   * @notice Returns the address of the PoolConfigurator proxy.
   * @return The PoolConfigurator proxy address
   */
  function getPoolConfigurator() external view returns (address);

  /**
   * @notice Updates the implementation of the PoolConfigurator, or creates a proxy
   * setting the new `PoolConfigurator` implementation when the function is called for the first time.
   * @param newPoolConfiguratorImpl The new PoolConfigurator implementation
   */
  function setPoolConfiguratorImpl(address newPoolConfiguratorImpl) external;

  /**
   * @notice Returns the address of the price oracle.
   * @return The address of the PriceOracle
   */
  function getPriceOracle() external view returns (address);

  /**
   * @notice Updates the address of the price oracle.
   * @param newPriceOracle The address of the new PriceOracle
   */
  function setPriceOracle(address newPriceOracle) external;

  /**
   * @notice Returns the address of the ACL manager.
   * @return The address of the ACLManager
   */
  function getACLManager() external view returns (address);

  /**
   * @notice Updates the address of the ACL manager.
   * @param newAclManager The address of the new ACLManager
   */
  function setACLManager(address newAclManager) external;

  /**
   * @notice Returns the address of the ACL admin.
   * @return The address of the ACL admin
   */
  function getACLAdmin() external view returns (address);

  /**
   * @notice Updates the address of the ACL admin.
   * @param newAclAdmin The address of the new ACL admin
   */
  function setACLAdmin(address newAclAdmin) external;

  /**
   * @notice Returns the address of the price oracle sentinel.
   * @return The address of the PriceOracleSentinel
   */
  function getPriceOracleSentinel() external view returns (address);

  /**
   * @notice Updates the address of the price oracle sentinel.
   * @param newPriceOracleSentinel The address of the new PriceOracleSentinel
   */
  function setPriceOracleSentinel(address newPriceOracleSentinel) external;

  /**
   * @notice Returns the address of the data provider.
   * @return The address of the DataProvider
   */
  function getPoolDataProvider() external view returns (address);

  /**
   * @notice Updates the address of the data provider.
   * @param newDataProvider The address of the new DataProvider
   */
  function setPoolDataProvider(address newDataProvider) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IPriceOracleGetter
 * @author Aave
 * @notice Interface for the Aave price oracle.
 */
interface IPriceOracleGetter {
  /**
   * @notice Returns the base currency address
   * @dev Address 0x0 is reserved for USD as base currency.
   * @return Returns the base currency address.
   */
  function BASE_CURRENCY() external view returns (address);

  /**
   * @notice Returns the base currency unit
   * @dev 1 ether for ETH, 1e8 for USD.
   * @return Returns the base currency unit.
   */
  function BASE_CURRENCY_UNIT() external view returns (uint256);

  /**
   * @notice Returns the asset price in the base currency
   * @param asset The address of the asset
   * @return The price of the asset
   */
  function getAssetPrice(address asset) external view returns (uint256);
}
