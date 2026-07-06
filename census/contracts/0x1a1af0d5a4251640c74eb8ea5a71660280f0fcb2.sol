// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

library DataTypes {
  // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
  struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
  }

  struct UserConfigurationMap {
    uint256 data;
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
}
// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface IAaveIncentivesController {
  
  event RewardsAccrued(address indexed user, uint256 amount);

  event RewardsClaimed(
    address indexed user,
    address indexed to,
    uint256 amount
  );

  event RewardsClaimed(
    address indexed user,
    address indexed to,
    address indexed claimer,
    uint256 amount
  );

  event ClaimerSet(address indexed user, address indexed claimer);

  /**
   * @dev Whitelists an address to claim the rewards on behalf of another address
   * @param user The address of the user
   * @param claimer The address of the claimer
   */
  function setClaimer(address user, address claimer) external;

  /**
   * @dev Returns the whitelisted claimer for a certain address (0x0 if not set)
   * @param user The address of the user
   * @return The claimer address
   */
  function getClaimer(address user) external view returns (address);

  /**
   * @dev Configure assets for a certain rewards emission
   * @param assets The assets to incentivize
   * @param emissionsPerSecond The emission for each asset
   */
  function configureAssets(address[] calldata assets, uint256[] calldata emissionsPerSecond)
    external;


  /**
   * @dev Called by the corresponding asset on any update that affects the rewards distribution
   * @param asset The address of the user
   * @param userBalance The balance of the user of the asset in the lending pool
   * @param totalSupply The total supply of the asset in the lending pool
   **/
  function handleAction(
    address asset,
    uint256 userBalance,
    uint256 totalSupply
  ) external;

  /**
   * @dev Returns the total of rewards of an user, already accrued + not yet accrued
   * @param user The address of the user
   * @return The rewards
   **/
  function getRewardsBalance(address[] calldata assets, address user)
    external
    view
    returns (uint256);

  /**
   * @dev Claims reward for an user, on all the assets of the lending pool, accumulating the pending rewards
   * @param amount Amount of rewards to claim
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/
  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending rewards. The caller must
   * be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
   * @param amount Amount of rewards to claim
   * @param user Address to check and claim rewards
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/
  function claimRewardsOnBehalf(
    address[] calldata assets,
    uint256 amount,
    address user,
    address to
  ) external returns (uint256);

  /**
   * @dev returns the unclaimed rewards of the user
   * @param user the address of the user
   * @return the unclaimed user rewards
   */
  function getUserUnclaimedRewards(address user) external view returns (uint256);

  /**
  * @dev for backward compatibility with previous implementation of the Incentives controller
  */
  function REWARD_TOKEN() external view returns (address);

  function assets(address asset) external view returns (uint104, uint104, uint40);

  function claimAllRewards(address[] calldata assets, address to) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}
// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {DataTypes} from './DataTypes.sol';

interface ILendingPool {
  /**
   * @dev Emitted on deposit()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address initiating the deposit
   * @param onBehalfOf The beneficiary of the deposit, receiving the aTokens
   * @param amount The amount deposited
   * @param referral The referral code used
   **/
  event Deposit(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on withdraw()
   * @param reserve The address of the underlyng asset being withdrawn
   * @param user The address initiating the withdrawal, owner of aTokens
   * @param to Address that will receive the underlying
   * @param amount The amount to be withdrawn
   **/
  event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

  /**
   * @dev Emitted on borrow() and flashLoan() when debt needs to be opened
   * @param reserve The address of the underlying asset being borrowed
   * @param user The address of the user initiating the borrow(), receiving the funds on borrow() or just
   * initiator of the transaction on flashLoan()
   * @param onBehalfOf The address that will be getting the debt
   * @param amount The amount borrowed out
   * @param borrowRateMode The rate mode: 1 for Stable, 2 for Variable
   * @param borrowRate The numeric rate at which the user has borrowed
   * @param referral The referral code used
   **/
  event Borrow(
    address indexed reserve,
    address user,
    address indexed onBehalfOf,
    uint256 amount,
    uint256 borrowRateMode,
    uint256 borrowRate,
    uint16 indexed referral
  );

  /**
   * @dev Emitted on repay()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The beneficiary of the repayment, getting his debt reduced
   * @param repayer The address of the user initiating the repay(), providing the funds
   * @param amount The amount repaid
   **/
  event Repay(
    address indexed reserve,
    address indexed user,
    address indexed repayer,
    uint256 amount
  );

  /**
   * @dev Emitted on swapBorrowRateMode()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user swapping his rate mode
   * @param rateMode The rate mode that the user wants to swap to
   **/
  event Swap(address indexed reserve, address indexed user, uint256 rateMode);

  /**
   * @dev Emitted on setUserUseReserveAsCollateral()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user enabling the usage as collateral
   **/
  event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on setUserUseReserveAsCollateral()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user enabling the usage as collateral
   **/
  event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on rebalanceStableBorrowRate()
   * @param reserve The address of the underlying asset of the reserve
   * @param user The address of the user for which the rebalance has been executed
   **/
  event RebalanceStableBorrowRate(address indexed reserve, address indexed user);

  /**
   * @dev Emitted on flashLoan()
   * @param target The address of the flash loan receiver contract
   * @param initiator The address initiating the flash loan
   * @param asset The address of the asset being flash borrowed
   * @param amount The amount flash borrowed
   * @param premium The fee flash borrowed
   * @param referralCode The referral code used
   **/
  event FlashLoan(
    address indexed target,
    address indexed initiator,
    address indexed asset,
    uint256 amount,
    uint256 premium,
    uint16 referralCode
  );

  /**
   * @dev Emitted when the pause is triggered.
   */
  event Paused();

  /**
   * @dev Emitted when the pause is lifted.
   */
  event Unpaused();

  /**
   * @dev Emitted when a borrower is liquidated. This event is emitted by the LendingPool via
   * LendingPoolCollateral manager using a DELEGATECALL
   * This allows to have the events in the generated ABI for LendingPool.
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param user The address of the borrower getting liquidated
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param liquidatedCollateralAmount The amount of collateral received by the liiquidator
   * @param liquidator The address of the liquidator
   * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
   * to receive the underlying collateral asset directly
   **/
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
   * @dev Emitted when the state of a reserve is updated. NOTE: This event is actually declared
   * in the ReserveLogic library and emitted in the updateInterestRates() function. Since the function is internal,
   * the event will actually be fired by the LendingPool contract. The event is therefore replicated here so it
   * gets added to the LendingPool ABI
   * @param reserve The address of the underlying asset of the reserve
   * @param liquidityRate The new liquidity rate
   * @param stableBorrowRate The new stable borrow rate
   * @param variableBorrowRate The new variable borrow rate
   * @param liquidityIndex The new liquidity index
   * @param variableBorrowIndex The new variable borrow index
   **/
  event ReserveDataUpdated(
    address indexed reserve,
    uint256 liquidityRate,
    uint256 stableBorrowRate,
    uint256 variableBorrowRate,
    uint256 liquidityIndex,
    uint256 variableBorrowIndex
  );

  /**
   * @dev Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User deposits 100 USDC and gets in return 100 aUSDC
   * @param asset The address of the underlying asset to deposit
   * @param amount The amount to be deposited
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function deposit(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
  ) external;

  /**
   * @dev Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
   * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
   * @param asset The address of the underlying asset to withdraw
   * @param amount The underlying amount to be withdrawn
   *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
   * @param to Address that will receive the underlying, same as msg.sender if the user
   *   wants to receive it on his own wallet, or a different address if the beneficiary is a
   *   different wallet
   * @return The final amount withdrawn
   **/
  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @dev Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
   * already deposited enough collateral, or he was given enough allowance by a credit delegator on the
   * corresponding debt token (StableDebtToken or VariableDebtToken)
   * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
   *   and 100 stable/variable debt tokens, depending on the `interestRateMode`
   * @param asset The address of the underlying asset to borrow
   * @param amount The amount to be borrowed
   * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param onBehalfOf Address of the user who will receive the debt. Should be the address of the borrower itself
   * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
   * if he has been given credit delegation allowance
   **/
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;

  /**
   * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
   * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param rateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
   * @param onBehalfOf Address of the user who will get his debt reduced/removed. Should be the address of the
   * user calling the function if he wants to reduce/remove his own debt, or the address of any other
   * other borrower whose debt should be removed
   * @return The final amount repaid
   **/
  function repay(
    address asset,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external returns (uint256);

  /**
   * @dev Allows a borrower to swap his debt between stable and variable mode, or viceversa
   * @param asset The address of the underlying asset borrowed
   * @param rateMode The rate mode that the user wants to swap to
   **/
  function swapBorrowRateMode(address asset, uint256 rateMode) external;

  /**
   * @dev Rebalances the stable interest rate of a user to the current stable rate defined on the reserve.
   * - Users can be rebalanced if the following conditions are satisfied:
   *     1. Usage ratio is above 95%
   *     2. the current deposit APY is below REBALANCE_UP_THRESHOLD * maxVariableBorrowRate, which means that too much has been
   *        borrowed at a stable rate and depositors are not earning enough
   * @param asset The address of the underlying asset borrowed
   * @param user The address of the user to be rebalanced
   **/
  function rebalanceStableBorrowRate(address asset, address user) external;

  /**
   * @dev Allows depositors to enable/disable a specific deposited asset as collateral
   * @param asset The address of the underlying asset deposited
   * @param useAsCollateral `true` if the user wants to use the deposit as collateral, `false` otherwise
   **/
  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

  /**
   * @dev Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
   * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
   *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
   * @param user The address of the borrower getting liquidated
   * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
   * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
   * to receive the underlying collateral asset directly
   **/
  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) external;

  /**
   * @dev Allows smartcontracts to access the liquidity of the pool within one transaction,
   * as long as the amount taken plus a fee is returned.
   * IMPORTANT There are security concerns for developers of flashloan receiver contracts that must be kept into consideration.
   * For further details please visit https://developers.aave.com
   * @param receiverAddress The address of the contract receiving the funds, implementing the IFlashLoanReceiver interface
   * @param assets The addresses of the assets being flash-borrowed
   * @param amounts The amounts amounts being flash-borrowed
   * @param modes Types of the debt to open if the flash loan is not returned:
   *   0 -> Don't open any debt, just revert if funds can't be transferred from the receiver
   *   1 -> Open debt at stable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
   *   2 -> Open debt at variable rate for the value of the amount flash-borrowed to the `onBehalfOf` address
   * @param onBehalfOf The address  that will receive the debt in the case of using on `modes` 1 or 2
   * @param params Variadic packed params to pass to the receiver as extra information
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;

  /**
   * @dev Returns the user account data across all the reserves
   * @param user The address of the user
   * @return totalCollateralETH the total collateral in ETH of the user
   * @return totalDebtETH the total debt in ETH of the user
   * @return availableBorrowsETH the borrowing power left of the user
   * @return currentLiquidationThreshold the liquidation threshold of the user
   * @return ltv the loan to value of the user
   * @return healthFactor the current health factor of the user
   **/
  function getUserAccountData(address user)
    external
    view
    returns (
      uint256 totalCollateralETH,
      uint256 totalDebtETH,
      uint256 availableBorrowsETH,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );

  function initReserve(
    address reserve,
    address aTokenAddress,
    address stableDebtAddress,
    address variableDebtAddress,
    address interestRateStrategyAddress
  ) external;

  function setReserveInterestRateStrategyAddress(address reserve, address rateStrategyAddress)
    external;

  function setConfiguration(address reserve, uint256 configuration) external;

  /**
   * @dev Returns the configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The configuration of the reserve
   **/
  function getConfiguration(address asset)
    external
    view
    returns (uint);

  /**
   * @dev Returns the configuration of the user across all the reserves
   * @param user The user address
   * @return The configuration of the user
   **/
  function getUserConfiguration(address user)
    external
    view
    returns (DataTypes.UserConfigurationMap memory);

  /**
   * @dev Returns the normalized income normalized income of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve's normalized income
   */
  function getReserveNormalizedIncome(address asset) external view returns (uint256);

  /**
   * @dev Returns the normalized variable debt per unit of asset
   * @param asset The address of the underlying asset of the reserve
   * @return The reserve normalized variable debt
   */
  function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);

  /**
   * @dev Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state of the reserve
   **/
  function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromAfter,
    uint256 balanceToBefore
  ) external;

  function getReservesList() external view returns (address[] memory);

  function setPause(bool val) external;

  function paused() external view returns (bool);
}
// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface IPriceOracleGetter {
    function getAssetPrice(address _asset) external view returns (uint256);
    function getAssetsPrices(address[] calldata _assets) external view returns(uint256[] memory);
    function getSourceOfAsset(address _asset) external view returns(address);
    function getFallbackOracle() external view returns(address);
}
// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface IProtocolDataProviderV2 {
  function getUserReserveData(address asset, address user) external view returns (uint256 currentATokenBalance, uint256 currentStableDebt, uint256 currentVariableDebt, uint256 principalStableDebt, uint256 scaledVariableDebt, uint256 stableBorrowRate, uint256 liquidityRate, uint40 stableRateLastUpdated, bool usageAsCollateralEnabled);

  function getReserveConfigurationData(address asset) external view returns (uint256 decimals, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus, uint256 reserveFactor, bool usageAsCollateralEnabled, bool borrowingEnabled, bool stableBorrowRateEnabled, bool isActive, bool isFrozen);

  function getReserveData(address asset) external view returns (uint256 availableLiquidity, uint256 totalStableDebt, uint256 totalVariableDebt, uint256 liquidityRate, uint256 variableBorrowRate, uint256 stableBorrowRate, uint256 averageStableBorrowRate, uint256 liquidityIndex, uint256 variableBorrowIndex, uint40 lastUpdateTimestamp);
  
  function getReserveTokensAddresses(address asset) external view returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress);
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

library DataTypesV3 {
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
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    //timestamp of last update
    uint40 lastUpdateTimestamp;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint16 id;
    //aToken address
    address aTokenAddress;
    //stableDebtToken address
    address stableDebtTokenAddress;
    //variableDebtToken address
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the current treasury balance, scaled
    uint128 accruedToTreasury;
    //the outstanding unbacked aTokens minted through the bridging feature
    uint128 unbacked;
    //the outstanding debt borrowed against this asset in isolation mode
    uint128 isolationModeTotalDebt;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60: asset is paused
    //bit 61: borrowing in isolation mode is enabled
    //bit 62-63: reserved
    //bit 64-79: reserve factor
    //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
    //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
    //bit 152-167 liquidation protocol fee
    //bit 168-175 eMode category
    //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
    //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
    //bit 252-255 unused

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

  struct EModeCategory {
    // each eMode category has a custom ltv and liquidation threshold
    uint16 ltv;
    uint16 liquidationThreshold;
    uint16 liquidationBonus;
    // each eMode category may or may not have a custom oracle to override the individual assets price oracles
    address priceSource;
    string label;
  }

  enum InterestRateMode {
    NONE,
    STABLE,
    VARIABLE
  }

  struct ReserveCache {
    uint256 currScaledVariableDebt;
    uint256 nextScaledVariableDebt;
    uint256 currPrincipalStableDebt;
    uint256 currAvgStableBorrowRate;
    uint256 currTotalStableDebt;
    uint256 nextAvgStableBorrowRate;
    uint256 nextTotalStableDebt;
    uint256 currLiquidityIndex;
    uint256 nextLiquidityIndex;
    uint256 currVariableBorrowIndex;
    uint256 nextVariableBorrowIndex;
    uint256 currLiquidityRate;
    uint256 currVariableBorrowRate;
    uint256 reserveFactor;
    ReserveConfigurationMap reserveConfiguration;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    uint40 reserveLastUpdateTimestamp;
    uint40 stableDebtLastUpdateTimestamp;
  }

  struct ExecuteLiquidationCallParams {
    uint256 reservesCount;
    uint256 debtToCover;
    address collateralAsset;
    address debtAsset;
    address user;
    bool receiveAToken;
    address priceOracle;
    uint8 userEModeCategory;
    address priceOracleSentinel;
  }

  struct ExecuteSupplyParams {
    address asset;
    uint256 amount;
    address onBehalfOf;
    uint16 referralCode;
  }

  struct ExecuteBorrowParams {
    address asset;
    address user;
    address onBehalfOf;
    uint256 amount;
    InterestRateMode interestRateMode;
    uint16 referralCode;
    bool releaseUnderlying;
    uint256 maxStableRateBorrowSizePercent;
    uint256 reservesCount;
    address oracle;
    uint8 userEModeCategory;
    address priceOracleSentinel;
  }

  struct ExecuteRepayParams {
    address asset;
    uint256 amount;
    InterestRateMode interestRateMode;
    address onBehalfOf;
    bool useATokens;
  }

  struct ExecuteWithdrawParams {
    address asset;
    uint256 amount;
    address to;
    uint256 reservesCount;
    address oracle;
    uint8 userEModeCategory;
  }

  struct ExecuteSetUserEModeParams {
    uint256 reservesCount;
    address oracle;
    uint8 categoryId;
  }

  struct FinalizeTransferParams {
    address asset;
    address from;
    address to;
    uint256 amount;
    uint256 balanceFromBefore;
    uint256 balanceToBefore;
    uint256 reservesCount;
    address oracle;
    uint8 fromEModeCategory;
  }

  struct FlashloanParams {
    address receiverAddress;
    address[] assets;
    uint256[] amounts;
    uint256[] interestRateModes;
    address onBehalfOf;
    bytes params;
    uint16 referralCode;
    uint256 flashLoanPremiumToProtocol;
    uint256 flashLoanPremiumTotal;
    uint256 maxStableRateBorrowSizePercent;
    uint256 reservesCount;
    address addressesProvider;
    uint8 userEModeCategory;
    bool isAuthorizedFlashBorrower;
  }

  struct FlashloanSimpleParams {
    address receiverAddress;
    address asset;
    uint256 amount;
    bytes params;
    uint16 referralCode;
    uint256 flashLoanPremiumToProtocol;
    uint256 flashLoanPremiumTotal;
  }

  struct FlashLoanRepaymentParams {
    uint256 amount;
    uint256 totalPremium;
    uint256 flashLoanPremiumToProtocol;
    address asset;
    address receiverAddress;
    uint16 referralCode;
  }

  struct CalculateUserAccountDataParams {
    UserConfigurationMap userConfig;
    uint256 reservesCount;
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
    uint256 maxStableLoanPercent;
    uint256 reservesCount;
    address oracle;
    uint8 userEModeCategory;
    address priceOracleSentinel;
    bool isolationModeActive;
    address isolationModeCollateralAddress;
    uint256 isolationModeDebtCeiling;
  }

  struct ValidateLiquidationCallParams {
    ReserveCache debtReserveCache;
    uint256 totalDebt;
    uint256 healthFactor;
    address priceOracleSentinel;
  }

  struct CalculateInterestRatesParams {
    uint256 unbacked;
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalStableDebt;
    uint256 totalVariableDebt;
    uint256 averageStableBorrowRate;
    uint256 reserveFactor;
    address reserve;
    address aToken;
  }

  struct InitReserveParams {
    address asset;
    address aTokenAddress;
    address stableDebtAddress;
    address variableDebtAddress;
    address interestRateStrategyAddress;
    uint16 reservesCount;
    uint16 maxNumberReserves;
  }
}
/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import {DataTypesV3} from './DataTypesV3.sol';

struct EModeCategory {
  // each eMode category has a custom ltv and liquidation threshold
  uint16 ltv;
  uint16 liquidationThreshold;
  uint16 liquidationBonus;
  // each eMode category may or may not have a custom oracle to override the individual assets price oracles
  address priceSource;
  string label;
}

interface IPool {

  /**
   * @dev Emitted on withdraw()
   * @param reserve The address of the underlying asset being withdrawn
   * @param user The address initiating the withdrawal, owner of aTokens
   * @param to The address that will receive the underlying
   * @param amount The amount to be withdrawn
   */
  event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

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
   * @notice Repays a borrowed `amount` on a specific reserve using the reserve aTokens, burning the
   * equivalent debt tokens
   * - E.g. User repays 100 USDC using 100 aUSDC, burning 100 variable/stable debt tokens
   * @dev  Passing uint256.max as amount will clean up any residual aToken dust balance, if the user aToken
   * balance is not enough to cover the whole debt
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
   * @return The final amount repaid
   **/
  function repayWithATokens(
    address asset,
    uint256 amount,
    uint256 interestRateMode
  ) external returns (uint256);

  /**
   * @notice Returns the data of an eMode category
   * @param id The id of the category
   * @return The configuration data of the category
   */
  function getEModeCategoryData(uint8 id) external view returns (EModeCategory memory);

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
   * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
   * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
   * @param asset The address of the underlying asset to supply
   * @param amount The amount to be supplied
   * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
   *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
   *   is a different wallet
   * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   **/
  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
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
   **/
  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @notice Allows users to borrow a specific `amount` of the reserve underlying asset, provided that the borrower
   * already supplied enough collateral, or he was given enough allowance by a credit delegator on the
   * corresponding debt token (StableDebtToken or VariableDebtToken)
   * - E.g. User borrows 100 USDC passing as `onBehalfOf` his own address, receiving the 100 USDC in his wallet
   *   and 100 stable/variable debt tokens, depending on the `interestRateMode`
   * @param asset The address of the underlying asset to borrow
   * @param amount The amount to be borrowed
   * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable
   * @param referralCode The code used to register the integrator originating the operation, for potential rewards.
   *   0 if the action is executed directly by the user, without any middle-man
   * @param onBehalfOf The address of the user who will receive the debt. Should be the address of the borrower itself
   * calling the function if he wants to borrow against his own collateral, or the address of the credit delegator
   * if he has been given credit delegation allowance
   **/
  function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
  ) external;

  /**
   * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
   * - E.g. User repays 100 USDC, burning 100 variable/stable debt tokens of the `onBehalfOf` address
   * @param asset The address of the borrowed underlying asset previously borrowed
   * @param amount The amount to repay
   * - Send the value type(uint256).max in order to repay the whole debt for `asset` on the specific `debtMode`
   * @param interestRateMode The interest rate mode at of the debt the user wants to repay: 1 for Stable, 2 for Variable
   * @param onBehalfOf The address of the user who will get his debt reduced/removed. Should be the address of the
   * user calling the function if he wants to reduce/remove his own debt, or the address of any other
   * other borrower whose debt should be removed
   * @return The final amount repaid
   **/
  function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
  ) external returns (uint256);

  /**
   * @notice Allows suppliers to enable/disable a specific supplied asset as collateral
   * @param asset The address of the underlying asset supplied
   * @param useAsCollateral True if the user wants to use the supply as collateral, false otherwise
   **/
  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

  /**
   * @notice Returns the user account data across all the reserves
   * @param user The address of the user
   * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
   * @return totalDebtBase The total debt of the user in the base currency used by the price feed
   * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
   * @return currentLiquidationThreshold The liquidation threshold of the user
   * @return ltv The loan to value of The user
   * @return healthFactor The current health factor of the user
   **/
  function getUserAccountData(address user)
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
   * @notice Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state and configuration data of the reserve
   **/
  function getReserveData(address asset) external view returns (DataTypesV3.ReserveData memory);
}
// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

interface IProtocolDataProviderV3 {
  function getReserveTokensAddresses(address asset) external view returns (address aTokenAddress, address stableDebtTokenAddress, address variableDebtTokenAddress);

  function getReserveConfigurationData(address asset) external view returns (uint256 decimals, uint256 ltv, uint256 liquidationThreshold, uint256 liquidationBonus, uint256 reserveFactor, bool collateralEnabled, bool borrowingEnabled, bool stableRateBorrowingEnabled, bool isActive, bool isFrozen);

  function getReserveData(address asset) external view returns (uint256 unbacked, uint256 accruedToTreasuryScaled, uint256 totalAToken, uint256 totalStableDebt, uint256 totalVariableDebt, uint256 liquidityRate, uint256 variableBorrowRate, uint256 stableBorrowRate, uint256 averageStableBorrowRate, uint256 liquidityIndex, uint256 variableBorrowIndex, uint40 lastUpdateTimestamp);
  
  function getReserveCaps(address asset) external view returns (uint256 borrowCap, uint256 supplyCap);

  function getUserReserveData(address asset, address user) external view returns (uint256 aTokenBalance, uint256 stableDebt, uint256 variableDebt, uint256 principalStableDebt, uint256 scaledVariableDebt, uint256 stableBorrowRate, uint256 reserveLiquidityRate, uint40 stableRateLastUpdate, bool usedAsCollateral);
}
// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IRewardsDistributorV3} from './IRewardsDistributorV3.sol';

/**
 * @title IRewardsController
 * @author Aave
 * @notice Defines the basic interface for a Rewards Controller.
 */
interface IRewardsControllerV3 is IRewardsDistributorV3 {
  /**
   * @dev Emitted when a new address is whitelisted as claimer of rewards on behalf of a user
   * @param user The address of the user
   * @param claimer The address of the claimer
   */
  event ClaimerSet(address indexed user, address indexed claimer);

  /**
   * @dev Emitted when rewards are claimed
   * @param user The address of the user rewards has been claimed on behalf of
   * @param reward The address of the token reward is claimed
   * @param to The address of the receiver of the rewards
   * @param claimer The address of the claimer
   * @param amount The amount of rewards claimed
   */
  event RewardsClaimed(
    address indexed user,
    address indexed reward,
    address indexed to,
    address claimer,
    uint256 amount
  );

  /**
   * @dev Emitted when a transfer strategy is installed for the reward distribution
   * @param reward The address of the token reward
   * @param transferStrategy The address of TransferStrategy contract
   */
  event TransferStrategyInstalled(address indexed reward, address indexed transferStrategy);

  /**
   * @dev Emitted when the reward oracle is updated
   * @param reward The address of the token reward
   * @param rewardOracle The address of oracle
   */
  event RewardOracleUpdated(address indexed reward, address indexed rewardOracle);

  /**
   * @dev Whitelists an address to claim the rewards on behalf of another address
   * @param user The address of the user
   * @param claimer The address of the claimer
   */
  function setClaimer(address user, address claimer) external;

  /**
   * @dev Get the price aggregator oracle address
   * @param reward The address of the reward
   * @return The price oracle of the reward
   */
  function getRewardOracle(address reward) external view returns (address);

  /**
   * @dev Returns the whitelisted claimer for a certain address (0x0 if not set)
   * @param user The address of the user
   * @return The claimer address
   */
  function getClaimer(address user) external view returns (address);

  /**
   * @dev Returns the Transfer Strategy implementation contract address being used for a reward address
   * @param reward The address of the reward
   * @return The address of the TransferStrategy contract
   */
  function getTransferStrategy(address reward) external view returns (address);

  /**
   * @dev Called by the corresponding asset on any update that affects the rewards distribution
   * @param user The address of the user
   * @param userBalance The user balance of the asset
   * @param totalSupply The total supply of the asset
   **/
  function handleAction(
    address user,
    uint256 userBalance,
    uint256 totalSupply
  ) external;

  /**
   * @dev Claims reward for a user to the desired address, on all the assets of the pool, accumulating the pending rewards
   * @param assets List of assets to check eligible distributions before claiming rewards
   * @param amount The amount of rewards to claim
   * @param to The address that will be receiving the rewards
   * @param reward The address of the reward token
   * @return The amount of rewards claimed
   **/
  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to,
    address reward
  ) external returns (uint256);

  /**
   * @dev Claims reward for a user on behalf, on all the assets of the pool, accumulating the pending rewards. The
   * caller must be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param amount The amount of rewards to claim
   * @param user The address to check and claim rewards
   * @param to The address that will be receiving the rewards
   * @param reward The address of the reward token
   * @return The amount of rewards claimed
   **/
  function claimRewardsOnBehalf(
    address[] calldata assets,
    uint256 amount,
    address user,
    address to,
    address reward
  ) external returns (uint256);

  /**
   * @dev Claims reward for msg.sender, on all the assets of the pool, accumulating the pending rewards
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param amount The amount of rewards to claim
   * @param reward The address of the reward token
   * @return The amount of rewards claimed
   **/
  function claimRewardsToSelf(
    address[] calldata assets,
    uint256 amount,
    address reward
  ) external returns (uint256);

  /**
   * @dev Claims all rewards for a user to the desired address, on all the assets of the pool, accumulating the pending rewards
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param to The address that will be receiving the rewards
   * @return rewardsList List of addresses of the reward tokens
   * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardList"
   **/
  function claimAllRewards(address[] calldata assets, address to)
    external
    returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

  /**
   * @dev Claims all rewards for a user on behalf, on all the assets of the pool, accumulating the pending rewards. The caller must
   * be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param user The address to check and claim rewards
   * @param to The address that will be receiving the rewards
   * @return rewardsList List of addresses of the reward tokens
   * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardsList"
   **/
  function claimAllRewardsOnBehalf(
    address[] calldata assets,
    address user,
    address to
  ) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

  /**
   * @dev Claims all reward for msg.sender, on all the assets of the pool, accumulating the pending rewards
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @return rewardsList List of addresses of the reward tokens
   * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardsList"
   **/
  function claimAllRewardsToSelf(address[] calldata assets)
    external
    returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

/**
 * @title IRewardsDistributor
 * @author Aave
 * @notice Defines the basic interface for a Rewards Distributor.
 */
interface IRewardsDistributorV3 {
  /**
   * @dev Emitted when the configuration of the rewards of an asset is updated.
   * @param asset The address of the incentivized asset
   * @param reward The address of the reward token
   * @param oldEmission The old emissions per second value of the reward distribution
   * @param newEmission The new emissions per second value of the reward distribution
   * @param oldDistributionEnd The old end timestamp of the reward distribution
   * @param newDistributionEnd The new end timestamp of the reward distribution
   * @param assetIndex The index of the asset distribution
   */
  event AssetConfigUpdated(
    address indexed asset,
    address indexed reward,
    uint256 oldEmission,
    uint256 newEmission,
    uint256 oldDistributionEnd,
    uint256 newDistributionEnd,
    uint256 assetIndex
  );

  /**
   * @dev Emitted when rewards of an asset are accrued on behalf of a user.
   * @param asset The address of the incentivized asset
   * @param reward The address of the reward token
   * @param user The address of the user that rewards are accrued on behalf of
   * @param assetIndex The index of the asset distribution
   * @param userIndex The index of the asset distribution on behalf of the user
   * @param rewardsAccrued The amount of rewards accrued
   */
  event Accrued(
    address indexed asset,
    address indexed reward,
    address indexed user,
    uint256 assetIndex,
    uint256 userIndex,
    uint256 rewardsAccrued
  );

  /**
   * @dev Emitted when the emission manager address is updated.
   * @param oldEmissionManager The address of the old emission manager
   * @param newEmissionManager The address of the new emission manager
   */
  event EmissionManagerUpdated(
    address indexed oldEmissionManager,
    address indexed newEmissionManager
  );

  /**
   * @dev Sets the end date for the distribution
   * @param asset The asset to incentivize
   * @param reward The reward token that incentives the asset
   * @param newDistributionEnd The end date of the incentivization, in unix time format
   **/
  function setDistributionEnd(
    address asset,
    address reward,
    uint32 newDistributionEnd
  ) external;

  /**
   * @dev Sets the emission per second of a set of reward distributions
   * @param asset The asset is being incentivized
   * @param rewards List of reward addresses are being distributed
   * @param newEmissionsPerSecond List of new reward emissions per second
   */
  function setEmissionPerSecond(
    address asset,
    address[] calldata rewards,
    uint88[] calldata newEmissionsPerSecond
  ) external;

  /**
   * @dev Gets the end date for the distribution
   * @param asset The incentivized asset
   * @param reward The reward token of the incentivized asset
   * @return The timestamp with the end of the distribution, in unix time format
   **/
  function getDistributionEnd(address asset, address reward) external view returns (uint256);

  /**
   * @dev Returns the index of a user on a reward distribution
   * @param user Address of the user
   * @param asset The incentivized asset
   * @param reward The reward token of the incentivized asset
   * @return The current user asset index, not including new distributions
   **/
  function getUserAssetIndex(
    address user,
    address asset,
    address reward
  ) external view returns (uint256);

  /**
   * @dev Returns the configuration of the distribution reward for a certain asset
   * @param asset The incentivized asset
   * @param reward The reward token of the incentivized asset
   * @return The index of the asset distribution
   * @return The emission per second of the reward distribution
   * @return The timestamp of the last update of the index
   * @return The timestamp of the distribution end
   **/
  function getRewardsData(address asset, address reward)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );

  /**
   * @dev Returns the list of available reward token addresses of an incentivized asset
   * @param asset The incentivized asset
   * @return List of rewards addresses of the input asset
   **/
  function getRewardsByAsset(address asset) external view returns (address[] memory);

  /**
   * @dev Returns the list of available reward addresses
   * @return List of rewards supported in this contract
   **/
  function getRewardsList() external view returns (address[] memory);

  /**
   * @dev Returns the accrued rewards balance of a user, not including virtually accrued rewards since last distribution.
   * @param user The address of the user
   * @param reward The address of the reward token
   * @return Unclaimed rewards, not including new distributions
   **/
  function getUserAccruedRewards(address user, address reward) external view returns (uint256);

  /**
   * @dev Returns a single rewards balance of a user, including virtually accrued and unrealized claimable rewards.
   * @param assets List of incentivized assets to check eligible distributions
   * @param user The address of the user
   * @param reward The address of the reward token
   * @return The rewards amount
   **/
  function getUserRewards(
    address[] calldata assets,
    address user,
    address reward
  ) external view returns (uint256);

  /**
   * @dev Returns a list all rewards of a user, including already accrued and unrealized claimable rewards
   * @param assets List of incentivized assets to check eligible distributions
   * @param user The address of the user
   * @return The list of reward addresses
   * @return The list of unclaimed amount of rewards
   **/
  function getAllUserRewards(address[] calldata assets, address user)
    external
    view
    returns (address[] memory, uint256[] memory);

  /**
   * @dev Returns the decimals of an asset to calculate the distribution delta
   * @param asset The address to retrieve decimals
   * @return The decimals of an underlying asset
   */
  function getAssetDecimals(address asset) external view returns (uint8);

  /**
   * @dev Returns the address of the emission manager
   * @return The address of the EmissionManager
   */
  function getEmissionManager() external view returns (address);

  /**
   * @dev Updates the address of the emission manager
   * @param emissionManager The address of the new EmissionManager
   */
  function setEmissionManager(address emissionManager) external;
}

/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@itb/quant-common/contracts/solidity8/ITBContract.sol';
import '@itb/quant-common/contracts/solidity8/ILoanManager.sol';
import './aave/IPriceOracle.sol';
import './aave/ILendingPool.sol';
import './aave/IProtocolDataProviderV2.sol';
import './aave/IAaveIncentivesController.sol';

/// @title LoanManager that targets Aave V2 markets.
/// @author IntoTheBlock Corp
contract LoanManager is ITBContract, ILoanManager {
    enum SnapshotUpdateAction { SUPPLY, BORROW, REPAY, WITHDRAW }
    event SnapshotUpdate(SnapshotUpdateAction indexed action, uint256 amount, address executor, address supplyToken, address borrowToken, uint256 totalSupplied, uint256 totalDebt);
    event ClaimRewards(address[] claimedTokens, uint256[] claimedAmounts);
    event UpdateLoanConfig(LoanConfig oldConfig, LoanConfig newConfig);
    event EnableCollateral(address supplyToken);
    event DisableCollateral(address supplyToken);
    event UpdateLendingPool(ILendingPool oldPool, ILendingPool newPool);
    event UpdatePriceOracle(IPriceOracleGetter oldOracle, IPriceOracleGetter newOracle);
    event UpdateProtocolDataProvider(IProtocolDataProviderV2 oldProvider, IProtocolDataProviderV2 newProvider);
    event UpdateRewardsController(IAaveIncentivesController oldController, IAaveIncentivesController newController);

    IPriceOracleGetter priceOracle;
    ILendingPool lendingPool;
    IProtocolDataProviderV2 protocolDataProvider;
    IAaveIncentivesController rewardsController;
    LoanConfig public loanConfig;

    /// @param _executors Array of executors addresses.
    /// @param _wnative Native token address.
    /// @param _supplyAddress Supplied token address.
    /// @param _borrowAddress Borrowed token address.
    /// @param _minHealthFactor Minimum health factor. 1e18 is equivalent to 1.00.
    /// @param _lendingPool Address of the Aave V3 lending pool.
    /// @param _priceOracle Address of the Aave V3 price oracle.
    /// @param _protocolDataProvider Address of the Aave V3 protocol data provider.
    /// @param _rewardsController Address of the Aave V3 protocol rewards controller.
    constructor(
        address[] memory _executors,
        address payable _wnative,
        address _supplyAddress,
        address _borrowAddress,
        uint _minHealthFactor,
        ILendingPool _lendingPool,
        IPriceOracleGetter _priceOracle,
        IProtocolDataProviderV2 _protocolDataProvider,
        IAaveIncentivesController _rewardsController
    ) ITBContract (_executors, _wnative) {
        setConfig(_supplyAddress, _borrowAddress, _minHealthFactor);
        updateLendingPool(_lendingPool);
        updatePriceOracle(_priceOracle);
        updateProtocolDataProvider(_protocolDataProvider);
        updateRewardsController(_rewardsController);
    }

    /* Helpers */

    /// @notice Compares after execution health factor vs min health factor and reverts if below min health factor
    modifier healthFactorCheck() {
        _;
        require(getHealthFactor() >= loanConfig.minHealthFactor, "Dangerous Health Factor reached");
    }

    /// @notice Converts a given amount from base to asset using the oracle and returns the result.
    /// @param asset Address of the asset to convert to.
    /// @param baseAmount Amount in base token to be converted.
    /// @return convertedAmount amount converted.
    function _baseToAsset(address asset, uint baseAmount) internal view returns (uint convertedAmount) {
        return baseAmount * (10 ** _decimals(asset)) / priceOracle.getAssetPrice(asset);
    }

    /// @notice Fetches the number of decimals of a given asset.
    /// @param asset Address of the asset to fetch the decimals from.
    /// @return decimals decimals of the asset.
    function _decimals(address asset) internal view returns (uint decimals) {
        decimals = ERC20(asset).decimals();
    }

    /// @notice Atoken addresses for a given market.
    /// @param _token Underlying market.
    /// @return aToken aToken address.
    /// @return stableDebtToken Stable debt token address.
    /// @return variableDebtToken Variable debt token address.
    function _getAaveTokens(address _token) internal view returns (address aToken, address stableDebtToken, address variableDebtToken) {
        (aToken, stableDebtToken, variableDebtToken) = protocolDataProvider.getReserveTokensAddresses(_token);
    }

    /// @notice Checks if the supplied asset is enabled as collateral
    /// @return isCollateral true if the asset is enabled as collateral, false otherwise
    function _isCollateral() internal view returns (bool isCollateral){
        (, , , , , , , , isCollateral) = protocolDataProvider.getUserReserveData(loanConfig.supplyAddress, address(this));
    }

    function _logSnapshot(SnapshotUpdateAction _action, uint256 _amount) internal {
        emit SnapshotUpdate(_action, _amount, msg.sender, loanConfig.supplyAddress, loanConfig.borrowAddress, getSupply(), getBorrow());
    }
    
    /* Internal */

    /// @notice Fetches the current supply rate of the configured supply market (internal implementation).
    /// @return supplyRate Supply rate.
    function _getSupplyRate() internal virtual view returns (uint256 supplyRate){
        (, , , supplyRate, , , , , ,) = protocolDataProvider.getReserveData(loanConfig.supplyAddress);
    }

    /// @notice Fetches the current borrow rate of the configured borrow market (internal implementation).
    /// @return borrowRate Borrow rate.
    function _getBorrowRate() internal virtual view returns (uint256 borrowRate){
        (, , , , borrowRate, , , , ,) = protocolDataProvider.getReserveData(loanConfig.borrowAddress);
    }
    
    /// @notice Fetches total supply and debt of the configured markets (internal implementation).
    /// @return supplyMarketDeposits Total supply of the configured supply market.
    /// @return supplyMarketDebt Total debt of the configured supply market.
    /// @return borrowMarketDeposits Total supply of the configured borrow market.
    /// @return borrowMarketDebt Total debt of the configured borrow market.
    function _getMarketsData() internal virtual view returns (uint256 supplyMarketDeposits, uint256 supplyMarketDebt, uint256 borrowMarketDeposits, uint256 borrowMarketDebt){
        (address supplyAToken, ,) = _getAaveTokens(loanConfig.supplyAddress);
        (address borrowAToken, ,) = _getAaveTokens(loanConfig.borrowAddress);
        supplyMarketDeposits = IERC20(supplyAToken).totalSupply();
        borrowMarketDeposits = IERC20(borrowAToken).totalSupply();
        (, uint256 supplyMarketStableDebt, uint256 supplyMarketVariableDebt, , , , , , , ) = protocolDataProvider.getReserveData(loanConfig.supplyAddress);
        (, uint256 borrowMarketStableDebt, uint256 borrowMarketVariableDebt, , , , , , , ) = protocolDataProvider.getReserveData(loanConfig.borrowAddress);
        supplyMarketDebt = supplyMarketStableDebt + supplyMarketVariableDebt;
        borrowMarketDebt = borrowMarketStableDebt + borrowMarketVariableDebt;
    }
    
    /// @notice Supplies the given amount of supply token to pool (internal implementation).
    /// @param _amount Amount of token to supply.
    function _supply(uint256 _amount) internal virtual {
        lendingPool.deposit(loanConfig.supplyAddress, _amount, address(this), 0);
    }
    
    /// @notice Borrows the given amount of borrow token from pool (internal implementation).
    /// @param _amount Amount of token to borrow.
    function _borrow(uint256 _amount) internal virtual {
        lendingPool.borrow(loanConfig.borrowAddress, _amount, 2, 0, address(this));
    }

    /// @notice Repays the given amount of borrow token debt to lending pool (internal implementation).
    /// @param _amount Amount of debt to repay.
    function _repay(uint256 _amount) internal virtual {
        _checkAllowanceAndApprove(loanConfig.borrowAddress, address(lendingPool), _amount);
        lendingPool.repay(loanConfig.borrowAddress, _amount, 2, address(this));
    }

    /// @notice Withdraw supplied tokens from a given market (internal implementation).
    /// @param _amount Amount to withdraw.
    function _withdrawSupply(uint256 _amount) internal virtual {
        lendingPool.withdraw(loanConfig.supplyAddress, _amount, address(this));
    }
    
    /// @notice Claims pending rewards for the configured markets (internal implementation).
    /// @param tokens Array of token addresses to claim.
    /// @return claimedTokens Array of claimed tokens addresses.
    /// @return claimedAmounts Array of claimed amounts.
    function _claimRewards(address[] memory tokens) internal virtual returns (address[] memory claimedTokens, uint256 [] memory claimedAmounts){
        claimedTokens = new address[](1);
        claimedAmounts = new uint256[](1);
        claimedTokens[0] = rewardsController.REWARD_TOKEN();
        claimedAmounts[0] = rewardsController.claimRewards(tokens, rewardsController.getRewardsBalance(tokens, address(this)), address(this));
    }
    
    /* Infra */

    /// @notice Only owner. Sets config parameters.
    /// @param _supplyAddress Address of the token to supply to pool.
    /// @param _borrowAddress Address of the token to borrow from pool.
    /// @param _minHealthFactor Minimum acceptable health factor.
    function setConfig(address _supplyAddress, address _borrowAddress, uint _minHealthFactor) public onlyOwner {
        LoanConfig memory new_config = LoanConfig(_supplyAddress, _borrowAddress, _minHealthFactor);
        emit UpdateLoanConfig(loanConfig, new_config);
        loanConfig = new_config;
    }

    /// @notice Only owner. Enables supplied token to be used as collateral.
    function enableCollateral() external onlyOwner {
        lendingPool.setUserUseReserveAsCollateral(loanConfig.supplyAddress, true);
        emit EnableCollateral(loanConfig.supplyAddress);
    }

    /// @notice Only owner. Disables supplied token to be used as collateral.
    function disableCollateral() external onlyOwner healthFactorCheck {
        lendingPool.setUserUseReserveAsCollateral(loanConfig.supplyAddress, false);
        emit DisableCollateral(loanConfig.supplyAddress);
    }

    /// @notice Only owner. Update LendingPool address
    /// @param _address New address
    function updateLendingPool(ILendingPool _address) public onlyOwner {
        emit UpdateLendingPool(lendingPool, _address);
        lendingPool = _address;
    }

    /// @notice Only owner. Update PriceOracle address
    /// @param _address New address
    function updatePriceOracle(IPriceOracleGetter _address) public onlyOwner {
        emit UpdatePriceOracle(priceOracle, _address);
        priceOracle = _address;
    }

    /// @notice Only owner. Update ProtocolDataProvider address
    /// @param _address New address
    function updateProtocolDataProvider(IProtocolDataProviderV2 _address) public onlyOwner {
        emit UpdateProtocolDataProvider(protocolDataProvider, _address);
        protocolDataProvider = _address;
    }

    /// @notice Only owner. Update RewardsController address
    /// @param _address New address
    function updateRewardsController(IAaveIncentivesController _address) public onlyOwner {
        emit UpdateRewardsController(rewardsController, _address);
        rewardsController = _address;
    }

    /* View */

    /// @notice Fetches config parameters.
    /// @return config config parameters.
    function getConfig() public view returns (LoanConfig memory config) {
        config = loanConfig;
    }

    /// @notice Fetches prices from Aave Price Oracle.
    /// @return supplyTokenPrice supply token price.
    /// @return borrowTokenPrice borrow token price.
    function getPrices() public view returns (uint256 supplyTokenPrice, uint256 borrowTokenPrice){
        address[] memory tokens = new address[](2);
        uint256[] memory prices = new uint256[](2);
        tokens[0] = loanConfig.supplyAddress;
        tokens[1] = loanConfig.borrowAddress;
        prices = priceOracle.getAssetsPrices(tokens);
        return (prices[0], prices[1]);
    }

    /// @notice Fetches health factor from pool.
    /// @return healthFactor health factor.
    function getHealthFactor() public view returns (uint256 healthFactor){
        (, , , , , healthFactor) = lendingPool.getUserAccountData(address(this));
    }

    /// @notice Fetches liquidity and shortfall from pool.
    /// @return liquidity Liquidity (or 0 if undercollateralized).
    /// @return shortfall Shortfall (or 0 if overcollateralized).
    function getLiquidityAndShortFall() public view returns (uint256 liquidity, uint256 shortfall){
        (liquidity, shortfall) = getLiquidityAndShortFallAsBase();
        liquidity = _baseToAsset(loanConfig.supplyAddress, liquidity);
        shortfall = _baseToAsset(loanConfig.borrowAddress, shortfall);
    }

    /// @notice Fetches amount of token supplied to pool.
    /// @return supplied Amount of token supplied to pool.
    function getSupply() public view returns (uint256 supplied){
        (address atoken, ,) = _getAaveTokens(loanConfig.supplyAddress);
        supplied = _erc20Balance(atoken);
    }

    /// @notice Fetches amount of token borrowed from pool.
    /// @return borrowed Amount of token borrowed from pool.
    function getBorrow() public view returns (uint256 borrowed){
        (, , address variableDebtToken) = _getAaveTokens(loanConfig.borrowAddress);
        borrowed = _erc20Balance(variableDebtToken);
    }

    /// @notice Fetches the current supply rate of the configured supply market.
    /// @return supplyRate Supply rate.
    function getSupplyRate() public view returns (uint256 supplyRate){
        supplyRate = _getSupplyRate();
    }

    /// @notice Fetches the current borrow rate of the configured borrow market.
    /// @return borrowRate Borrow rate.
    function getBorrowRate() public view returns (uint256 borrowRate){
        borrowRate = _getBorrowRate();
    }

    /// @notice Aggregates and returns position data.
    /// @return healthFactor Health factor.
    /// @return liquidity Liquidity (or 0 if undercollateralized).
    /// @return shortfall Shortfall (or 0 if overcollateralized).
    /// @return supplied Amount of tokens supplied to pool.
    /// @return borrowed Amount of tokens borrowed from pool.
    /// @return supplyRate Supply rate of the configured supply market.
    /// @return borrowRate Borrow rate of the configured borrow market.
    function getPositionDataSnapshot() public view returns (uint256 healthFactor, uint256 liquidity, uint256 shortfall, uint256 supplied, uint256 borrowed, uint256 supplyRate, uint256 borrowRate){
        healthFactor = getHealthFactor();
        (liquidity, shortfall) = getLiquidityAndShortFall();
        supplied = getSupply();
        borrowed = getBorrow();
        supplyRate = getSupplyRate();
        borrowRate = getBorrowRate();
    }

    /// @notice Fetches total supply, debt and current price of the configured markets.
    /// @return supplyMarketDeposits Total supply of the configured supply market.
    /// @return supplyMarketDebt Total debt of the configured supply market.
    /// @return supplyMarketAssetPrice Price of the configured supply market underlying.
    /// @return borrowMarketDeposits Total supply of the configured borrow market.
    /// @return borrowMarketDebt Total debt of the configured borrow market.
    /// @return borrowMarketAssetPrice Price of the configured borrow market underlying.
    function getMarketsData() public view returns (uint256 supplyMarketDeposits, uint256 supplyMarketDebt, uint256 supplyMarketAssetPrice, uint256 borrowMarketDeposits, uint256 borrowMarketDebt, uint256 borrowMarketAssetPrice){
        (supplyMarketDeposits, supplyMarketDebt, borrowMarketDeposits, borrowMarketDebt) = _getMarketsData();
        (supplyMarketAssetPrice, borrowMarketAssetPrice ) = getPrices();
    }

    /// @notice Fetches amount of token supplied to pool as base.
    /// @return supplyAsBase Amount of token supplied to pool as base.
    function getSupplyAsBase() public view returns (uint256 supplyAsBase){
        (supplyAsBase, , , , ,) = lendingPool.getUserAccountData(address(this));
    }

    /// @notice Fetches amount of token borrowed from pool as base.
    /// @return borrowAsBase Amount of token borrowed from pool as base.
    function getBorrowAsBase() public view returns (uint256 borrowAsBase){
        (, borrowAsBase, , , ,) = lendingPool.getUserAccountData(address(this));
    }

    /// @notice Fetches liquidity and shortfall from pool as base.
    /// @return liquidity Liquidity (or 0 if undercollateralized) as base.
    /// @return shortfall Shortfall (or 0 if overcollateralized) as base.
    function getLiquidityAndShortFallAsBase() public view returns (uint256 liquidity, uint256 shortfall){
        (uint256 supplied, uint256 borrowed, , , uint256 ltv, ) = lendingPool.getUserAccountData(address(this));
        uint256 borrow_power = supplied * ltv / 1e4;
        liquidity = borrow_power > borrowed ? borrow_power - borrowed : 0;
        shortfall = borrow_power < borrowed ? borrowed - borrow_power : 0;
    }

    /// @notice Fetches collateral factor for the given collateral.
    /// @param _collateral Address of the collateral.
    /// @return Collateral factor.
    function getLiquidationThreshold(address _collateral) public view returns (uint256){
        (, , uint256 liquidationThreshold, , , , , , ,) = protocolDataProvider.getReserveConfigurationData(_collateral);
        return liquidationThreshold * 1e18 / 1e4;
    }

    /* Primitives */

    /// @notice Only executor. Supplies the given amount of supply token to pool.
    /// @param _amount Amount of token to supply.
    function supply(uint256 _amount) public onlyExecutor {
        _checkAllowanceAndApprove(loanConfig.supplyAddress, address(lendingPool), _amount);
        _supply(_amount);
        _logSnapshot(SnapshotUpdateAction.SUPPLY, _amount);
    }

    /// @notice Only executor. Borrows the given amount of borrow token from pool.
    /// @param _amount Amount of token to borrow.
    function borrow(uint256 _amount) public onlyExecutor healthFactorCheck {
        _borrow(_amount);
        _logSnapshot(SnapshotUpdateAction.BORROW, _amount);
    }

    /// @notice Only executor. Repays the given amount of borrow token debt to pool.
    /// @param _amount Amount of token debt to repay.
    function repay(uint256 _amount) public onlyExecutor {
        _repay(_amount);
        _logSnapshot(SnapshotUpdateAction.REPAY, _amount);
    }

    /// @notice Only executor. Repays all borrow token debt.
    function repayAll() public onlyExecutor {
        uint256 totalBorrow = getBorrow();
        if (totalBorrow == 0)
            return;
        _repay(type(uint).max);
        _approveToken(loanConfig.borrowAddress, address(lendingPool), 0);
        _logSnapshot(SnapshotUpdateAction.REPAY, totalBorrow);
    }

    /// @notice Only executor. Withdraws the given amount of underlying from pool.
    /// @param _amount Amount of underlying to withdraw.
    function withdrawSupply(uint256 _amount) public onlyExecutor healthFactorCheck {
        _withdrawSupply(_amount);
        _logSnapshot(SnapshotUpdateAction.WITHDRAW, _amount);
    }

    /// @notice Only executor. Withdraws all underlying from pool.
    function withdrawSupplyAll() public onlyExecutor healthFactorCheck {
        uint256 totalSupply = getSupply();
        _withdrawSupply(type(uint).max);
        _logSnapshot(SnapshotUpdateAction.WITHDRAW, totalSupply);
    }

    /// @notice Only executor. Repays all borrow token debt and withdraws all underlying from pool.
    /// @return amountWithdrawn Amount of tokens withdrawn.
    function repayAllAndWithdrawSupplyAll() public onlyExecutor healthFactorCheck returns (uint256 amountWithdrawn){
        repayAll();
        uint256 previousBalance = _erc20Balance(loanConfig.supplyAddress);
        withdrawSupplyAll();
        amountWithdrawn = _erc20Balance(loanConfig.supplyAddress) - previousBalance;
    }

    /// @notice Only executor. Claims pending rewards for the configured markets.
    /// @return claimedTokens Array of claimed tokens addresses.
    /// @return claimedAmounts Array of claimed amounts.
    function claimRewards() public onlyExecutor returns (address[] memory claimedTokens, uint256[] memory claimedAmounts){
        address[] memory tokens = new address[](4);
        (address aToken, , address variableDebtToken) = _getAaveTokens(loanConfig.supplyAddress);
        tokens[0] = aToken;
        tokens[1] = variableDebtToken;
        (address aTokenB, , address variableDebtTokenB) = _getAaveTokens(loanConfig.borrowAddress);
        tokens[2] = aTokenB;
        tokens[3] = variableDebtTokenB;
        (claimedTokens, claimedAmounts) = _claimRewards(tokens);
        emit ClaimRewards(claimedTokens, claimedAmounts);
    }

    /* Interfaces for Harvester */
    
    /// @notice Only executor. Supply tokens to the configured market.
    /// @param _amount Amount to supply.
    /// @dev For Harvester compatibility.
    function deposit(address, uint _amount) external virtual onlyExecutor {
        supply(_amount);
    }

    /// @notice Only executor. Claim rewards across all markets.
    /// @dev For Harvester compatibility.
    function claimRewards(address, uint) external virtual onlyExecutor returns (uint){
        (, uint[] memory claimedAmounts) = claimRewards();
        return claimedAmounts[0];
    }
}
/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import './LoanManager.sol';
import './aaveV3/IPool.sol';
import './aaveV3/IProtocolDataProviderV3.sol';
import './aaveV3/IRewardsControllerV3.sol';

/// @title LoanManager that targets Aave V3 markets.
/// @author IntoTheBlock Corp
contract LoanManagerV3 is LoanManager {
    uint8 public emodeCategory;

    event UpdateEModeCategory(uint8 emode_category);
    event SetEMode(uint8 emode_category);

    /// @param _executors Array of executors addresses.
    /// @param _wnative Native token address.
    /// @param _supplyAddress Supplied token address.
    /// @param _borrowAddress Borrowed token address.
    /// @param _minHealthFactor Minimum health factor. 1e18 is equivalent to 1.00.
    /// @param _lendingPool Address of the Aave V3 lending pool.
    /// @param _priceOracle Address of the Aave V3 price oracle.
    /// @param _protocolDataProvider Address of the Aave V3 protocol data provider.
    /// @param _rewardsController Address of the Aave V3 protocol rewards controller.
    constructor(
        address[] memory _executors,
        address payable _wnative,
        address _supplyAddress,
        address _borrowAddress,
        uint _minHealthFactor,
        ILendingPool _lendingPool,
        IPriceOracleGetter _priceOracle,
        IProtocolDataProviderV2 _protocolDataProvider,
        IAaveIncentivesController _rewardsController
    ) LoanManager (_executors, _wnative, _supplyAddress, _borrowAddress, _minHealthFactor, _lendingPool, _priceOracle, _protocolDataProvider, _rewardsController) {}

    /* Helpers */

    /// Cast inherited Aave V2 lendingPool to V3
    function _v3_pool() internal view returns (IPool) {
        return IPool(address(lendingPool));
    }

    /// Cast inherited Aave V2 incentives controller to RewardsControllerV3
    function _rewards_controller() internal view returns (IRewardsControllerV3) {
        return IRewardsControllerV3(address(rewardsController));
    }

    /// Cast inherited Aave V2 protocolDataProvider to IProtocolDataProviderV3
    function _protocol_data_provider() internal view returns (IProtocolDataProviderV3) {
        return IProtocolDataProviderV3(address(protocolDataProvider));
    }

    /* Internal */

    /// @notice Fetches the current supply rate of the configured supply market (internal implementation).
    /// @return supplyRate Supply rate.
    function _getSupplyRate() internal override view returns (uint256 supplyRate){
        (, , , , , supplyRate, , , , , ,) = _protocol_data_provider().getReserveData(loanConfig.supplyAddress);
    }

    /// @notice Fetches the current borrow rate of the configured borrow market (internal implementation).
    /// @return borrowRate Borrow rate.
    function _getBorrowRate() internal override view returns (uint256 borrowRate){
        (, , , , , , borrowRate, , , , ,) = _protocol_data_provider().getReserveData(loanConfig.borrowAddress);
    }

    /// @notice Fetches total supply and debt of the configured markets (internal implementation).
    /// @return supplyMarketDeposits Total supply of the configured supply market.
    /// @return supplyMarketDebt Total debt of the configured supply market.
    /// @return borrowMarketDeposits Total supply of the configured borrow market.
    /// @return borrowMarketDebt Total debt of the configured borrow market.
    function _getMarketsData() internal override view returns (uint256 supplyMarketDeposits, uint256 supplyMarketDebt, uint256 borrowMarketDeposits, uint256 borrowMarketDebt){
        (, , uint256 supplyMarketTotalSupply, uint256 supplyMarketStableDebt, uint256 supplyMarketVariableDebt, , , , , , , ) = _protocol_data_provider().getReserveData(loanConfig.supplyAddress);
        (, , uint256 borrowMarketTotalSupply, uint256 borrowMarketStableDebt, uint256 borrowMarketVariableDebt, , , , , , , ) = _protocol_data_provider().getReserveData(loanConfig.borrowAddress);
        supplyMarketDeposits = supplyMarketTotalSupply;
        supplyMarketDebt = supplyMarketStableDebt + supplyMarketVariableDebt;
        borrowMarketDeposits = borrowMarketTotalSupply;
        borrowMarketDebt = borrowMarketStableDebt + borrowMarketVariableDebt;
    }

    /// @notice Supplies the given amount of supply token to pool (internal implementation).
    /// @param _amount Amount of token to supply.
    function _supply(uint256 _amount) internal override {
        _v3_pool().supply(loanConfig.supplyAddress, _amount, address(this), 0);
    }

    /// @notice Borrows the given amount of borrow token from pool (internal implementation).
    /// @param _amount Amount of token to borrow.
    function _borrow(uint256 _amount) internal override {
        _v3_pool().borrow(loanConfig.borrowAddress, _amount, 2, 0, address(this));
    }

    /// @notice Repays the given amount of borrow token debt to lending pool (internal implementation).
    /// @param _amount Amount of debt to repay.
    function _repay(uint256 _amount) internal override {
        _checkAllowanceAndApprove(loanConfig.borrowAddress, address(lendingPool), _amount);
        _v3_pool().repay(loanConfig.borrowAddress, _amount, 2, address(this));
    }

    /// @notice Withdraw supplied tokens from a given market
    /// @param _amount Amount to withdraw
    function _withdrawSupply(uint256 _amount) internal override {
        _v3_pool().withdraw(loanConfig.supplyAddress, _amount, address(this));
    }

    /// @notice Claims pending rewards for the configured markets (internal implementation).
    /// @param tokens Array of token addresses to claim.
    /// @return claimedTokens Array of claimed tokens addresses.
    /// @return claimedAmounts Array of claimed amounts.
    function _claimRewards(address[] memory tokens) internal override returns (address[] memory claimedTokens, uint256 [] memory claimedAmounts){
        (claimedTokens, claimedAmounts) = _rewards_controller().claimAllRewards(tokens, address(this));
    }

    /* Infra */

    /// @notice Only owner. Sets V3 config parameters.
    /// @param _supplyAddress Address of the token to supply to pool.
    /// @param _borrowAddress Address of the token to borrow from pool.
    /// @param _minHealthFactor Minimum acceptable health factor.
    /// @param _emode_category Emode category to use
    function setConfig(address _supplyAddress, address _borrowAddress, uint _minHealthFactor, uint8 _emode_category) public onlyOwner {
        setConfig(_supplyAddress, _borrowAddress, _minHealthFactor);
        emodeCategory = _emode_category;
        emit UpdateEModeCategory(_emode_category);
    }

    /// @notice Only executor. Sets EMode category to the one set by config
    function setEMode() external onlyOwner {
        _v3_pool().setUserEMode(emodeCategory);
        emit SetEMode(emodeCategory);
    }
}
/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.20;

import './ITBContract.sol';

interface ILoanManager {
    struct LoanConfig {
        address supplyAddress;
        address borrowAddress;
        uint minHealthFactor;
    }

    function getConfig() external view returns (LoanConfig memory);

    function setConfig(address supplyAddress, address borrowAddress, uint minHealthFactor) external;

    function supply(uint amount) external;

    function borrow(uint amount) external;

    function repay(uint256 _amount) external;

    function repayAll() external;

    function withdrawSupply(uint256 _amount) external;

    function withdrawSupplyAll() external;

    function repayAllAndWithdrawSupplyAll() external returns (uint256);

    function getPrices() external view returns (uint256, uint256);

    function getHealthFactor() external view returns (uint256);

    function getLiquidityAndShortFall() external view returns (uint256, uint256);

    function getSupply() external view returns (uint256);

    function getBorrow() external view returns (uint256);

    function getSupplyRate() external view returns (uint256);

    function getBorrowRate() external view returns (uint256);

    function getPositionDataSnapshot() external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256);

    function claimRewards() external returns (address[] memory, uint256[] memory);

    function getMarketsData() external returns (uint256, uint256, uint256, uint256, uint256, uint256);

    function getLiquidationThreshold(address _collateral) external view returns (uint256);
}
/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.20;

import './utils/Withdrawable.sol';
import './utils/IWETH.sol';


/// @title ITBContract contract that implements common owner only functions accross all strategies
/// @author IntoTheBlock Corp
/// @dev Abstract
abstract contract ITBContract is Withdrawable {
    using SafeERC20 for IERC20;
    event ApproveToken(address indexed token, address guy, uint256 wad);
    address payable immutable public WNATIVE;

    uint constant ONE = 1e18;

    /// @param _executors Executor addresses
    constructor(address[] memory _executors, address payable _wnative) Executable(_executors) {
        WNATIVE = _wnative;
    }

    function _percentageAmount(uint _amount, uint _percentage) internal pure returns (uint) {
        return _amount * _percentage / ONE;
    }

    /// @notice Set allowance for a given token, amount and spender
    /// @param _token Token to spend
    /// @param _guy Spender
    /// @param _wad Max amount to spend
    function _approveToken(address _token, address _guy, uint256 _wad) internal {
        if (_wad != 0)
            IERC20(_token).forceApprove(_guy, _wad);
        else
            IERC20(_token).approve(_guy, _wad);
        emit ApproveToken(_token, _guy, _wad);
    }

    /// @notice For a given token, amount and spender, check if contract can spend amount and, if necessary, set the allowance to amount
    /// @param _token Token to spend
    /// @param _guy Spender
    /// @param _amount Amount to spend
    function _checkAllowanceAndApprove(address _token, address _guy, uint256 _amount) internal {
        _checkAllowanceAndApprove(_token, _guy, _amount, _amount);
    }

    /// @notice For a given token, amount and spender, check if contract can spend amount and, if necessary, set the allowance to approval amount
    /// @param _token Token to spend
    /// @param _guy Spender
    /// @param _amount Amount to spend
    /// @param _approval_amount Amount to approve
    function _checkAllowanceAndApprove(address _token, address _guy, uint256 _amount, uint256 _approval_amount) internal {
        if (IERC20(_token).allowance(address(this), _guy) < _amount)
            _approveToken(_token, _guy, _approval_amount);
    }

    /// @notice Only owner. Set allowance for a given token, amount and spender
    /// @param _token Token to spend
    /// @param _guy Spender
    /// @param _wad Max amount to spend
    function approveToken(address _token, address _guy, uint256 _wad) external onlyOwner {
        _approveToken(_token, _guy, _wad);
    }

    /// @notice Only owner. Revoke allowance for a given token and spender
    /// @param _token Token to spend
    /// @param _guy Spender
    function revokeToken(address _token, address _guy) external onlyOwner {
        _approveToken(_token, _guy, 0);
    }

    /// @notice Only owner. Execute an arbitrary call
    /// @param _to Target address
    /// @param _value Value (i. e. msg.value)
    /// @param _data Invocation data
    function execute(address _to, uint256 _value, bytes calldata _data) external payable onlyOwner {
        (bool success, bytes memory returnData) = _to.call{ value: _value }(_data);
        require(success, string(returnData));
    }

    /// @notice Only owner. Execute multiple arbitrary calls in order
    /// @param _tos Target address for each call
    /// @param _values Value for each call (i. e. msg.value)
    /// @param _datas Invocation data for each call
    function batchExecute(address[] calldata _tos, uint256[] calldata _values, bytes[] calldata _datas) external payable onlyOwner {
        require(_tos.length == _values.length && _tos.length == _datas.length, "Arguments length mismatch");
        for (uint256 i = 0; i < _tos.length; i++) {
            (bool success, bytes memory returnData) = _tos[i].call{ value: _values[i] }(_datas[i]);
            require(success, string(returnData));
        }
    }

    function wrapNative(uint256 _amount) public onlyExecutor {
        IWETH(WNATIVE).deposit{ value: _amount }();
    }

    function unwrapNative(uint256 _amount) public onlyExecutor {
        IWETH(WNATIVE).withdraw(_amount);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title Base contract that implements executor related functions
/// @author IntoTheBlock Corp
/// @dev Abstract
abstract contract Executable is Ownable2Step {
    mapping(address => bool) public executors;

    event ExecutorUpdated(address indexed executor, bool enabled);

    /// @param _executors Initial whitelisted executor addresses
    constructor(address[] memory _executors) Ownable(msg.sender) {
        for (uint256 i = 0; i < _executors.length; i++) {
            addExecutor(_executors[i]);
        }
    }

    /// @notice Revert if call is not being made from the owner or an executor
    modifier onlyExecutor() {
        require(owner() == msg.sender || executors[msg.sender], "Executable: caller is not the executor");
        _;
    }

    /// @notice Only owner. Add an executor
    /// @param _executor New executor address
    function addExecutor(address _executor) public onlyOwner {
        emit ExecutorUpdated(_executor, true);
        executors[_executor] = true;
    }

    /// @notice Only owner. Remove an executor
    /// @param _executor Executor address to remove
    function removeExecutor(address _executor) external onlyOwner {
        emit ExecutorUpdated(_executor, false);
        executors[_executor] = false;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IWETH {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);

    fallback() external payable;
    receive() external payable;
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function totalSupply() external view returns (uint256);
    function approve(address guy, uint256 wad) external returns (bool);
    function transfer(address dst, uint256 wad) external returns (bool);
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import './Executable.sol';

/**
    Ensures that any contract that inherits from this contract is able to
    withdraw funds that are accidentally received or stuck.
 */

/// @title Base contract that implements withdrawal related functions
/// @author IntoTheBlock Corp
/// @dev Abstract
abstract contract Withdrawable is Executable {
    using SafeERC20 for IERC20;
    address constant ETHER = address(0);

    event LogWithdraw(
        address indexed _to,
        address indexed _asset_address,
        uint256 amount
    );

    receive() external payable {}

    /// @notice ERC20 or ETH balance of this contract given a token address
    /// @param _asset_address Token address or address(0) for ETH
    /// @return Balance    
    function _balance(address _asset_address) internal view returns (uint256) {
        return _asset_address == ETHER ? address(this).balance : _erc20Balance(_asset_address);
    }

    function _erc20Balance(address _asset_address) internal view returns (uint256) {
        return IERC20(_asset_address).balanceOf(address(this));
    }
    
    /// @notice ERC20 balance of given account
    /// @param _asset_address Token address 
    /// @param _account Account address 
    /// @return Balance  
    function balanceOf(address _asset_address, address _account) public view returns (uint256) {
        return IERC20(_asset_address).balanceOf(_account);
    }

    /// @notice Send the given amount of the given token or ETH to the given receiver
    /// @param _asset_address Token address or address(0) for ETH
    /// @param _amount Amount to send
    /// @param _to Receiver address
    function _withdraw_to(address _asset_address, uint256 _amount, address payable _to) internal {
        require(_to != address(0), 'Invalid address');
        uint256 balance = _balance(_asset_address);
        require(balance >= _amount, 'Insufficient funds');
        if (_asset_address == ETHER) {
            (bool success, ) = _to.call{value: _amount}(''); /* carry gas over so it works with contracts with custom fallback, we dont care about reentrancy on onlyOwner */
            require(success, 'Native transfer failed.');
        } else
            IERC20(_asset_address).safeTransfer(_to, _amount);
        emit LogWithdraw(_to, _asset_address, _amount);
    }

    /// @notice Only owner. Send the given amount of the given token or ETH to the caller
    /// @param _asset_address Token address or address(0) for ETH
    /// @param _amount Amount to send
    function withdraw(address _asset_address, uint256 _amount) external onlyOwner {
        _withdraw_to(_asset_address, _amount, payable(msg.sender));
    }

    /// @notice Only owner. Send the given amount of the given token or ETH to the given receiver
    /// @param _asset_address Token address or address(0) for ETH
    /// @param _amount Amount to send
    /// @param _to Receiver address
    function withdrawTo(address _asset_address, uint256 _amount, address payable _to) external onlyOwner {
        _withdraw_to(_asset_address, _amount, _to);
    }

    /// @notice Only owner. Send its entire balance of the given token or ETH to the caller
    /// @param _asset_address Token address or address(0) for ETH
    function withdrawAll(address _asset_address) external onlyOwner {
        uint256 balance = _balance(_asset_address);
        _withdraw_to(_asset_address, balance, payable(msg.sender));
    }

    /// @notice Only owner. Send its entire balance of the given token or ETH to the given receiver
    /// @param _asset_address Token address or address(0) for ETH
    /// @param _to Receiver address
    function withdrawAllTo(address _asset_address, address payable _to) external onlyOwner {
        uint256 balance = _balance(_asset_address);
        _withdraw_to(_asset_address, balance, _to);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.20;

import {Ownable} from "./Ownable.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)

pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IERC165} from "./IERC165.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "./IERC20.sol";
import {IERC20Metadata} from "./extensions/IERC20Metadata.sol";
import {Context} from "../../utils/Context.sol";
import {IERC20Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
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
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * Both values are immutable: they can only be set once during construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
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
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner`'s tokens.
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
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner`'s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
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
// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC1363} from "../../../interfaces/IERC1363.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

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
