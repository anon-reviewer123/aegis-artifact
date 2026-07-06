// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IAuthorizer } from "../vault/IAuthorizer.sol";

interface IBasicAuthorizer is IAuthorizer {
    // solhint-disable-next-line func-name-mixedcase
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/// @notice Simple interface for permissioned calling of external functions.
interface IAuthentication {
    /// @notice The sender does not have permission to call a function.
    error SenderNotAllowed();

    /**
     * @notice Returns the action identifier associated with the external function described by `selector`.
     * @param selector The 4-byte selector of the permissioned function
     * @return actionId The computed actionId
     */
    function getActionId(bytes4 selector) external view returns (bytes32 actionId);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/// @notice General interface for token exchange rates.
interface IRateProvider {
    /**
     * @notice An 18 decimal fixed point number representing the exchange rate of one token to another related token.
     * @dev The meaning of this rate depends on the context. Note that there may be an error associated with a token
     * rate, and the caller might require a certain rounding direction to ensure correctness. This (legacy) interface
     * does not take a rounding direction or return an error, so great care must be taken when interpreting and using
     * rates in downstream computations.
     *
     * @return rate The current token rate
     */
    function getRate() external view returns (uint256 rate);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

/// @notice Interface to the Vault's permission system.
interface IAuthorizer {
    /**
     * @notice Returns true if `account` can perform the action described by `actionId` in the contract `where`.
     * @param actionId Identifier for the action to be performed
     * @param account Account trying to perform the action
     * @param where Target contract for the action
     * @return success True if the action is permitted
     */
    function canPerform(bytes32 actionId, address account, address where) external view returns (bool success);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

// Explicitly import VaultTypes structs because we expect this interface to be heavily used by external developers.
// Internally, when this list gets too long, we usually just do a simple import to keep things tidy.
import {
    TokenConfig,
    LiquidityManagement,
    PoolSwapParams,
    AfterSwapParams,
    HookFlags,
    AddLiquidityKind,
    RemoveLiquidityKind,
    SwapKind
} from "./VaultTypes.sol";

/**
 * @notice Interface for pool hooks.
 * @dev Hooks are functions invoked by the Vault at specific points in the flow of each operation. This guarantees that
 * they are called in the correct order, and with the correct arguments. To maintain this security, these functions
 * should only be called by the Vault. The recommended way to do this is to derive the hook contract from `BaseHooks`,
 * then use the `onlyVault` modifier from `VaultGuard`. (See the examples in /pool-hooks.)
 */
interface IHooks {
    /***************************************************************************
                                   Register
    ***************************************************************************/

    /**
     * @notice Hook executed when a pool is registered with a non-zero hooks contract.
     * @dev Returns true if registration was successful, and false to revert the pool registration.
     * Make sure this function is properly implemented (e.g. check the factory, and check that the
     * given pool is from the factory). The Vault address will be msg.sender.
     *
     * @param factory Address of the pool factory (contract deploying the pool)
     * @param pool Address of the pool
     * @param tokenConfig An array of descriptors for the tokens the pool will manage
     * @param liquidityManagement Liquidity management flags indicating which functions are enabled
     * @return success True if the hook allowed the registration, false otherwise
     */
    function onRegister(
        address factory,
        address pool,
        TokenConfig[] memory tokenConfig,
        LiquidityManagement calldata liquidityManagement
    ) external returns (bool success);

    /**
     * @notice Return the set of hooks implemented by the contract.
     * @dev The Vault will only call hooks the pool says it supports, and of course only if a hooks contract is defined
     * (i.e., the `poolHooksContract` in `PoolRegistrationParams` is non-zero).
     * `onRegister` is the only "mandatory" hook.
     *
     * @return hookFlags Flags indicating which hooks the contract supports
     */
    function getHookFlags() external view returns (HookFlags memory hookFlags);

    /***************************************************************************
                                   Initialize
    ***************************************************************************/

    /**
     * @notice Hook executed before pool initialization.
     * @dev Called if the `shouldCallBeforeInitialize` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param exactAmountsIn Exact amounts of input tokens
     * @param userData Optional, arbitrary data sent with the encoded request
     * @return success True if the pool wishes to proceed with initialization
     */
    function onBeforeInitialize(uint256[] memory exactAmountsIn, bytes memory userData) external returns (bool success);

    /**
     * @notice Hook to be executed after pool initialization.
     * @dev Called if the `shouldCallAfterInitialize` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param exactAmountsIn Exact amounts of input tokens
     * @param bptAmountOut Amount of pool tokens minted during initialization
     * @param userData Optional, arbitrary data sent with the encoded request
     * @return success True if the pool accepts the initialization results
     */
    function onAfterInitialize(
        uint256[] memory exactAmountsIn,
        uint256 bptAmountOut,
        bytes memory userData
    ) external returns (bool success);

    /***************************************************************************
                                   Add Liquidity
    ***************************************************************************/

    /**
     * @notice Hook to be executed before adding liquidity.
     * @dev Called if the `shouldCallBeforeAddLiquidity` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param router The address (usually a router contract) that initiated an add liquidity operation on the Vault
     * @param pool Pool address, used to fetch pool information from the Vault (pool config, tokens, etc.)
     * @param kind The add liquidity operation type (e.g., proportional, custom)
     * @param maxAmountsInScaled18 Maximum amounts of input tokens
     * @param minBptAmountOut Minimum amount of output pool tokens
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Optional, arbitrary data sent with the encoded request
     * @return success True if the pool wishes to proceed with settlement
     */
    function onBeforeAddLiquidity(
        address router,
        address pool,
        AddLiquidityKind kind,
        uint256[] memory maxAmountsInScaled18,
        uint256 minBptAmountOut,
        uint256[] memory balancesScaled18,
        bytes memory userData
    ) external returns (bool success);

    /**
     * @notice Hook to be executed after adding liquidity.
     * @dev Called if the `shouldCallAfterAddLiquidity` flag is set in the configuration. The Vault will ignore
     * `hookAdjustedAmountsInRaw` unless `enableHookAdjustedAmounts` is true. Hook contracts should use the
     * `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param router The address (usually a router contract) that initiated an add liquidity operation on the Vault
     * @param pool Pool address, used to fetch pool information from the Vault (pool config, tokens, etc.)
     * @param kind The add liquidity operation type (e.g., proportional, custom)
     * @param amountsInScaled18 Actual amounts of tokens added, sorted in token registration order
     * @param amountsInRaw Actual amounts of tokens added, sorted in token registration order
     * @param bptAmountOut Amount of pool tokens minted
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Additional (optional) data provided by the user
     * @return success True if the pool wishes to proceed with settlement
     * @return hookAdjustedAmountsInRaw New amountsInRaw, potentially modified by the hook
     */
    function onAfterAddLiquidity(
        address router,
        address pool,
        AddLiquidityKind kind,
        uint256[] memory amountsInScaled18,
        uint256[] memory amountsInRaw,
        uint256 bptAmountOut,
        uint256[] memory balancesScaled18,
        bytes memory userData
    ) external returns (bool success, uint256[] memory hookAdjustedAmountsInRaw);

    /***************************************************************************
                                 Remove Liquidity
    ***************************************************************************/

    /**
     * @notice Hook to be executed before removing liquidity.
     * @dev Called if the `shouldCallBeforeRemoveLiquidity` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param router The address (usually a router contract) that initiated a remove liquidity operation on the Vault
     * @param pool Pool address, used to fetch pool information from the Vault (pool config, tokens, etc.)
     * @param kind The type of remove liquidity operation (e.g., proportional, custom)
     * @param maxBptAmountIn Maximum amount of input pool tokens
     * @param minAmountsOutScaled18 Minimum output amounts, sorted in token registration order
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Optional, arbitrary data sent with the encoded request
     * @return success True if the pool wishes to proceed with settlement
     */
    function onBeforeRemoveLiquidity(
        address router,
        address pool,
        RemoveLiquidityKind kind,
        uint256 maxBptAmountIn,
        uint256[] memory minAmountsOutScaled18,
        uint256[] memory balancesScaled18,
        bytes memory userData
    ) external returns (bool success);

    /**
     * @notice Hook to be executed after removing liquidity.
     * @dev Called if the `shouldCallAfterRemoveLiquidity` flag is set in the configuration. The Vault will ignore
     * `hookAdjustedAmountsOutRaw` unless `enableHookAdjustedAmounts` is true. Hook contracts should use the
     * `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param router The address (usually a router contract) that initiated a remove liquidity operation on the Vault
     * @param pool Pool address, used to fetch pool information from the Vault (pool config, tokens, etc.)
     * @param kind The type of remove liquidity operation (e.g., proportional, custom)
     * @param bptAmountIn Amount of pool tokens to burn
     * @param amountsOutScaled18 Scaled amount of tokens to receive, sorted in token registration order
     * @param amountsOutRaw Actual amount of tokens to receive, sorted in token registration order
     * @param balancesScaled18 Current pool balances, sorted in token registration order
     * @param userData Additional (optional) data provided by the user
     * @return success True if the pool wishes to proceed with settlement
     * @return hookAdjustedAmountsOutRaw New amountsOutRaw, potentially modified by the hook
     */
    function onAfterRemoveLiquidity(
        address router,
        address pool,
        RemoveLiquidityKind kind,
        uint256 bptAmountIn,
        uint256[] memory amountsOutScaled18,
        uint256[] memory amountsOutRaw,
        uint256[] memory balancesScaled18,
        bytes memory userData
    ) external returns (bool success, uint256[] memory hookAdjustedAmountsOutRaw);

    /***************************************************************************
                                    Swap
    ***************************************************************************/

    /**
     * @notice Called before a swap to give the Pool an opportunity to perform actions.
     * @dev Called if the `shouldCallBeforeSwap` flag is set in the configuration. Hook contracts should use the
     * `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param params Swap parameters (see PoolSwapParams for struct definition)
     * @param pool Pool address, used to get pool information from the Vault (poolData, token config, etc.)
     * @return success True if the pool wishes to proceed with settlement
     */
    function onBeforeSwap(PoolSwapParams calldata params, address pool) external returns (bool success);

    /**
     * @notice Called after a swap to perform further actions once the balances have been updated by the swap.
     * @dev Called if the `shouldCallAfterSwap` flag is set in the configuration. The Vault will ignore
     * `hookAdjustedAmountCalculatedRaw` unless `enableHookAdjustedAmounts` is true. Hook contracts should
     * use the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param params Swap parameters (see above for struct definition)
     * @return success True if the pool wishes to proceed with settlement
     * @return hookAdjustedAmountCalculatedRaw New amount calculated, potentially modified by the hook
     */
    function onAfterSwap(
        AfterSwapParams calldata params
    ) external returns (bool success, uint256 hookAdjustedAmountCalculatedRaw);

    /**
     * @notice Called after `onBeforeSwap` and before the main swap operation, if the pool has dynamic fees.
     * @dev Called if the `shouldCallComputeDynamicSwapFee` flag is set in the configuration. Hook contracts should use
     * the `onlyVault` modifier to guarantee this is only called by the Vault.
     *
     * @param params Swap parameters (see PoolSwapParams for struct definition)
     * @param pool Pool address, used to get pool information from the Vault (poolData, token config, etc.)
     * @param staticSwapFeePercentage 18-decimal FP value of the static swap fee percentage, for reference
     * @return success True if the pool wishes to proceed with settlement
     * @return dynamicSwapFeePercentage Value of the swap fee percentage, as an 18-decimal FP value
     */
    function onComputeDynamicSwapFeePercentage(
        PoolSwapParams calldata params,
        address pool,
        uint256 staticSwapFeePercentage
    ) external view returns (bool success, uint256 dynamicSwapFeePercentage);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IVault } from "./IVault.sol";

/// @notice Contract that handles protocol and pool creator fees for the Vault.
interface IProtocolFeeController {
    /**
     * @notice Emitted when the protocol swap fee percentage is updated.
     * @param swapFeePercentage The updated protocol swap fee percentage
     */
    event GlobalProtocolSwapFeePercentageChanged(uint256 swapFeePercentage);

    /**
     * @notice Emitted when the protocol yield fee percentage is updated.
     * @param yieldFeePercentage The updated protocol yield fee percentage
     */
    event GlobalProtocolYieldFeePercentageChanged(uint256 yieldFeePercentage);

    /**
     * @notice Emitted when the protocol swap fee percentage is updated for a specific pool.
     * @param pool The pool whose protocol swap fee will be changed
     * @param swapFeePercentage The updated protocol swap fee percentage
     */
    event ProtocolSwapFeePercentageChanged(address indexed pool, uint256 swapFeePercentage);

    /**
     * @notice Emitted when the protocol yield fee percentage is updated for a specific pool.
     * @param pool The pool whose protocol yield fee will be changed
     * @param yieldFeePercentage The updated protocol yield fee percentage
     */
    event ProtocolYieldFeePercentageChanged(address indexed pool, uint256 yieldFeePercentage);

    /**
     * @notice Emitted when the pool creator swap fee percentage of a pool is updated.
     * @param pool The pool whose pool creator swap fee will be changed
     * @param poolCreatorSwapFeePercentage The new pool creator swap fee percentage for the pool
     */
    event PoolCreatorSwapFeePercentageChanged(address indexed pool, uint256 poolCreatorSwapFeePercentage);

    /**
     * @notice Emitted when the pool creator yield fee percentage of a pool is updated.
     * @param pool The pool whose pool creator yield fee will be changed
     * @param poolCreatorYieldFeePercentage The new pool creator yield fee percentage for the pool
     */
    event PoolCreatorYieldFeePercentageChanged(address indexed pool, uint256 poolCreatorYieldFeePercentage);

    /**
     * @notice Logs the collection of protocol swap fees in a specific token and amount.
     * @dev Note that since charging protocol fees (i.e., distributing tokens between pool and fee balances) occurs
     * in the Vault, but fee collection happens in the ProtocolFeeController, the swap fees reported here may encompass
     * multiple operations.
     *
     * @param pool The pool on which the swap fee was charged
     * @param token The token in which the swap fee was charged
     * @param amount The amount of the token collected in fees
     */
    event ProtocolSwapFeeCollected(address indexed pool, IERC20 indexed token, uint256 amount);

    /**
     * @notice Logs the collection of protocol yield fees in a specific token and amount.
     * @dev Note that since charging protocol fees (i.e., distributing tokens between pool and fee balances) occurs
     * in the Vault, but fee collection happens in the ProtocolFeeController, the yield fees reported here may encompass
     * multiple operations.
     *
     * @param pool The pool on which the yield fee was charged
     * @param token The token in which the yield fee was charged
     * @param amount The amount of the token collected in fees
     */
    event ProtocolYieldFeeCollected(address indexed pool, IERC20 indexed token, uint256 amount);

    /**
     * @notice Logs the withdrawal of protocol fees in a specific token and amount.
     * @param pool The pool from which protocol fees are being withdrawn
     * @param token The token being withdrawn
     * @param recipient The recipient of the funds
     * @param amount The amount of the fee token that was withdrawn
     */
    event ProtocolFeesWithdrawn(address indexed pool, IERC20 indexed token, address indexed recipient, uint256 amount);

    /**
     * @notice Logs the withdrawal of pool creator fees in a specific token and amount.
     * @param pool The pool from which pool creator fees are being withdrawn
     * @param token The token being withdrawn
     * @param recipient The recipient of the funds (the pool creator if permissionless, or another account)
     * @param amount The amount of the fee token that was withdrawn
     */
    event PoolCreatorFeesWithdrawn(
        address indexed pool,
        IERC20 indexed token,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @notice Emitted on pool registration with the initial aggregate swap fee percentage, for off-chain processes.
     * @dev If the pool is registered as protocol fee exempt, this will be zero (until changed). Otherwise, it will
     * equal the current global swap fee percentage.
     *
     * @param pool The pool being registered
     * @param aggregateSwapFeePercentage The initial aggregate swap fee percentage
     * @param isProtocolFeeExempt True if the pool is exempt from taking protocol fees initially
     */
    event InitialPoolAggregateSwapFeePercentage(
        address indexed pool,
        uint256 aggregateSwapFeePercentage,
        bool isProtocolFeeExempt
    );

    /**
     * @notice Emitted on pool registration with the initial aggregate yield fee percentage, for off-chain processes.
     * @dev If the pool is registered as protocol fee exempt, this will be zero (until changed). Otherwise, it will
     * equal the current global yield fee percentage.
     *
     * @param pool The pool being registered
     * @param aggregateYieldFeePercentage The initial aggregate yield fee percentage
     * @param isProtocolFeeExempt True if the pool is exempt from taking protocol fees initially
     */
    event InitialPoolAggregateYieldFeePercentage(
        address indexed pool,
        uint256 aggregateYieldFeePercentage,
        bool isProtocolFeeExempt
    );

    /**
     * @notice Emitted as a convenience during pool registration, more focused than the Vault's `PoolRegistered` event.
     * @dev The `PoolRegistered` event includes the `roleAccounts` field, which also records the pool creator, but this
     * simpler event is also provided for convenience. Though `InitialPoolAggregateSwapFeePercentage` and its yield fee
     * counterpart also include the protocol fee exemption flag, we might as well include it here as well.
     *
     * @param pool The address of the pool being registered
     * @param poolCreator The address of the pool creator (non-zero, or the event would not be emitted)
     * @param  protocolFeeExempt True if the pool is initially exempt from protocol fees
     */
    event PoolRegisteredWithFeeController(address indexed pool, address indexed poolCreator, bool protocolFeeExempt);

    /**
     * @notice Error raised when the protocol swap fee percentage exceeds the maximum allowed value.
     * @dev Note that this is checked for both the global and pool-specific protocol swap fee percentages.
     */
    error ProtocolSwapFeePercentageTooHigh();

    /**
     * @notice Error raised when the protocol yield fee percentage exceeds the maximum allowed value.
     * @dev Note that this is checked for both the global and pool-specific protocol yield fee percentages.
     */
    error ProtocolYieldFeePercentageTooHigh();

    /**
     * @notice Error raised if there is no pool creator on a withdrawal attempt from the given pool.
     * @param pool The pool with no creator
     */
    error PoolCreatorNotRegistered(address pool);

    /**
     * @notice Error raised if the wrong account attempts to withdraw pool creator fees.
     * @param caller The account attempting to withdraw pool creator fees
     * @param pool The pool the caller tried to withdraw from
     */
    error CallerIsNotPoolCreator(address caller, address pool);

    /// @notice Error raised when the pool creator swap or yield fee percentage exceeds the maximum allowed value.
    error PoolCreatorFeePercentageTooHigh();

    /**
     * @notice Get the address of the main Vault contract.
     * @return vault The Vault address
     */
    function vault() external view returns (IVault);

    /**
     * @notice Collects aggregate fees from the Vault for a given pool.
     * @param pool The pool with aggregate fees
     */
    function collectAggregateFees(address pool) external;

    /**
     * @notice Getter for the current global protocol swap fee.
     * @return protocolSwapFeePercentage The global protocol swap fee percentage
     */
    function getGlobalProtocolSwapFeePercentage() external view returns (uint256 protocolSwapFeePercentage);

    /**
     * @notice Getter for the current global protocol yield fee.
     * @return protocolYieldFeePercentage The global protocol yield fee percentage
     */
    function getGlobalProtocolYieldFeePercentage() external view returns (uint256 protocolYieldFeePercentage);

    /**
     * @notice Getter for pool registration flag.
     * @param pool The address of the pool
     * @return isRegistered True if the pool configuration has been set (e.g., through `registerPool`)
     */
    function isPoolRegistered(address pool) external view returns (bool);

    /**
     * @notice Getter for the current protocol swap fee for a given pool.
     * @param pool The address of the pool
     * @return protocolSwapFeePercentage The protocol swap fee percentage for the given pool
     * @return isOverride True if the protocol fee has been overridden
     */
    function getPoolProtocolSwapFeeInfo(
        address pool
    ) external view returns (uint256 protocolSwapFeePercentage, bool isOverride);

    /**
     * @notice Getter for the current protocol yield fee for a given pool.
     * @param pool The address of the pool
     * @return protocolYieldFeePercentage The protocol yield fee percentage for the given pool
     * @return isOverride True if the protocol fee has been overridden
     */
    function getPoolProtocolYieldFeeInfo(
        address pool
    ) external view returns (uint256 protocolYieldFeePercentage, bool isOverride);

    /**
     * @notice Getter for the current pool creator swap fee percentage for a given pool.
     * @param pool The address of the pool
     * @return poolCreatorSwapFeePercentage The pool creator swap fee component of the aggregate swap fee
     */
    function getPoolCreatorSwapFeePercentage(address pool) external view returns (uint256);

    /**
     * @notice Getter for the current pool creator yield fee percentage for a given pool.
     * @param pool The address of the pool
     * @return poolCreatorSwapFeePercentage The pool creator yield fee component of the aggregate yield fee
     */
    function getPoolCreatorYieldFeePercentage(address pool) external view returns (uint256);

    /**
     * @notice Returns the amount of each pool token allocated to the protocol for withdrawal.
     * @dev Includes both swap and yield fees.
     * @param pool The address of the pool on which fees were collected
     * @return feeAmounts The total amounts of each token available for withdrawal, sorted in token registration order
     */
    function getProtocolFeeAmounts(address pool) external view returns (uint256[] memory feeAmounts);

    /**
     * @notice Returns the amount of each pool token allocated to the pool creator for withdrawal.
     * @dev Includes both swap and yield fees.
     * @param pool The address of the pool on which fees were collected
     * @return feeAmounts The total amounts of each token available for withdrawal, sorted in token registration order
     */
    function getPoolCreatorFeeAmounts(address pool) external view returns (uint256[] memory feeAmounts);

    /**
     * @notice Returns a calculated aggregate percentage from protocol and pool creator fee percentages.
     * @dev Not tied to any particular pool; this just performs the low-level "additive fee" calculation. Note that
     * pool creator fees are calculated based on creatorAndLpFees, and not in totalFees. Since aggregate fees are
     * stored in the Vault with 24-bit precision, this will truncate any values that require greater precision.
     * It is expected that pool creators will negotiate with the DAO and agree on reasonable values for these fee
     * components, but the truncation ensures it will not revert for any valid set of fee percentages.
     *
     * See example below:
     *
     * tokenOutAmount = 10000; poolSwapFeePct = 10%; protocolFeePct = 40%; creatorFeePct = 60%
     * totalFees = tokenOutAmount * poolSwapFeePct = 10000 * 10% = 1000
     * protocolFees = totalFees * protocolFeePct = 1000 * 40% = 400
     * creatorAndLpFees = totalFees - protocolFees = 1000 - 400 = 600
     * creatorFees = creatorAndLpFees * creatorFeePct = 600 * 60% = 360
     * lpFees (will stay in the pool) = creatorAndLpFees - creatorFees = 600 - 360 = 240
     *
     * @param protocolFeePercentage The protocol portion of the aggregate fee percentage
     * @param poolCreatorFeePercentage The pool creator portion of the aggregate fee percentage
     * @return aggregateFeePercentage The computed aggregate percentage
     */
    function computeAggregateFeePercentage(
        uint256 protocolFeePercentage,
        uint256 poolCreatorFeePercentage
    ) external pure returns (uint256 aggregateFeePercentage);

    /**
     * @notice Override the protocol swap fee percentage for a specific pool.
     * @dev This is a permissionless call, and will set the pool's fee to the current global fee, if it is different
     * from the current value, and the fee is not controlled by governance (i.e., has never been overridden).
     *
     * @param pool The pool for which we are setting the protocol swap fee
     */
    function updateProtocolSwapFeePercentage(address pool) external;

    /**
     * @notice Override the protocol yield fee percentage for a specific pool.
     * @dev This is a permissionless call, and will set the pool's fee to the current global fee, if it is different
     * from the current value, and the fee is not controlled by governance (i.e., has never been overridden).
     *
     * @param pool The pool for which we are setting the protocol yield fee
     */
    function updateProtocolYieldFeePercentage(address pool) external;

    /***************************************************************************
                                Permissioned Functions
    ***************************************************************************/

    /**
     * @notice Add pool-specific entries to the protocol swap and yield percentages.
     * @dev This must be called from the Vault during pool registration. It will initialize the pool to the global
     * protocol fee percentage values (or 0, if the `protocolFeeExempt` flags is set), and return the initial aggregate
     * fee percentages, based on an initial pool creator fee of 0.
     *
     * @param pool The address of the pool being registered
     * @param poolCreator The address of the pool creator (or 0 if there won't be a pool creator fee)
     * @param protocolFeeExempt If true, the pool is initially exempt from protocol fees
     * @return aggregateSwapFeePercentage The initial aggregate swap fee percentage
     * @return aggregateYieldFeePercentage The initial aggregate yield fee percentage
     */
    function registerPool(
        address pool,
        address poolCreator,
        bool protocolFeeExempt
    ) external returns (uint256 aggregateSwapFeePercentage, uint256 aggregateYieldFeePercentage);

    /**
     * @notice Set the global protocol swap fee percentage, used by standard pools.
     * @param newProtocolSwapFeePercentage The new protocol swap fee percentage
     */
    function setGlobalProtocolSwapFeePercentage(uint256 newProtocolSwapFeePercentage) external;

    /**
     * @notice Set the global protocol yield fee percentage, used by standard pools.
     * @param newProtocolYieldFeePercentage The new protocol yield fee percentage
     */
    function setGlobalProtocolYieldFeePercentage(uint256 newProtocolYieldFeePercentage) external;

    /**
     * @notice Override the protocol swap fee percentage for a specific pool.
     * @param pool The address of the pool for which we are setting the protocol swap fee
     * @param newProtocolSwapFeePercentage The new protocol swap fee percentage for the pool
     */
    function setProtocolSwapFeePercentage(address pool, uint256 newProtocolSwapFeePercentage) external;

    /**
     * @notice Override the protocol yield fee percentage for a specific pool.
     * @param pool The address of the pool for which we are setting the protocol yield fee
     * @param newProtocolYieldFeePercentage The new protocol yield fee percentage for the pool
     */
    function setProtocolYieldFeePercentage(address pool, uint256 newProtocolYieldFeePercentage) external;

    /**
     * @notice Assigns a new pool creator swap fee percentage to the specified pool.
     * @dev Fees are divided between the protocol, pool creator, and LPs. The pool creator percentage is applied to
     * the "net" amount after protocol fees, and divides the remainder between the pool creator and LPs. If the
     * pool creator fee is near 100%, almost none of the fee amount remains in the pool for LPs.
     *
     * @param pool The address of the pool for which the pool creator fee will be changed
     * @param poolCreatorSwapFeePercentage The new pool creator swap fee percentage to apply to the pool
     */
    function setPoolCreatorSwapFeePercentage(address pool, uint256 poolCreatorSwapFeePercentage) external;

    /**
     * @notice Assigns a new pool creator yield fee percentage to the specified pool.
     * @dev Fees are divided between the protocol, pool creator, and LPs. The pool creator percentage is applied to
     * the "net" amount after protocol fees, and divides the remainder between the pool creator and LPs. If the
     * pool creator fee is near 100%, almost none of the fee amount remains in the pool for LPs.
     *
     * @param pool The address of the pool for which the pool creator fee will be changed
     * @param poolCreatorYieldFeePercentage The new pool creator yield fee percentage to apply to the pool
     */
    function setPoolCreatorYieldFeePercentage(address pool, uint256 poolCreatorYieldFeePercentage) external;

    /**
     * @notice Withdraw collected protocol fees for a given pool (all tokens). This is a permissioned function.
     * @dev Sends swap and yield protocol fees to the recipient.
     * @param pool The pool on which fees were collected
     * @param recipient Address to send the tokens
     */
    function withdrawProtocolFees(address pool, address recipient) external;

    /**
     * @notice Withdraw collected protocol fees for a given pool and a given token. This is a permissioned function.
     * @dev Sends swap and yield protocol fees to the recipient.
     * @param pool The pool on which fees were collected
     * @param recipient Address to send the tokens
     * @param token Token to withdraw
     */
    function withdrawProtocolFeesForToken(address pool, address recipient, IERC20 token) external;

    /**
     * @notice Withdraw collected pool creator fees for a given pool. This is a permissioned function.
     * @dev Sends swap and yield pool creator fees to the recipient.
     * @param pool The pool on which fees were collected
     * @param recipient Address to send the tokens
     */
    function withdrawPoolCreatorFees(address pool, address recipient) external;

    /**
     * @notice Withdraw collected pool creator fees for a given pool.
     * @dev Sends swap and yield pool creator fees to the registered poolCreator. Since this is a known and immutable
     * value, this function is permissionless.
     *
     * @param pool The pool on which fees were collected
     */
    function withdrawPoolCreatorFees(address pool) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IAuthentication } from "../solidity-utils/helpers/IAuthentication.sol";
import { IVaultExtension } from "./IVaultExtension.sol";
import { IVaultErrors } from "./IVaultErrors.sol";
import { IVaultEvents } from "./IVaultEvents.sol";
import { IVaultAdmin } from "./IVaultAdmin.sol";
import { IVaultMain } from "./IVaultMain.sol";

/// @notice Composite interface for all Vault operations: swap, add/remove liquidity, and associated queries.
interface IVault is IVaultMain, IVaultExtension, IVaultAdmin, IVaultErrors, IVaultEvents, IAuthentication {
    /// @return vault The main Vault address.
    function vault() external view override(IVaultAdmin, IVaultExtension) returns (IVault);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { IProtocolFeeController } from "./IProtocolFeeController.sol";
import { IAuthorizer } from "./IAuthorizer.sol";
import { IVault } from "./IVault.sol";

/**
 * @notice Interface for functions defined on the `VaultAdmin` contract.
 * @dev `VaultAdmin` is the Proxy extension of `VaultExtension`, and handles the least critical operations,
 * as two delegate calls add gas to each call. Most of the permissioned calls are here.
 */
interface IVaultAdmin {
    /*******************************************************************************
                               Constants and immutables
    *******************************************************************************/

    /**
     * @notice Returns the main Vault address.
     * @dev The main Vault contains the entrypoint and main liquidity operation implementations.
     * @return vault The address of the main Vault
     */
    function vault() external view returns (IVault);

    /**
     * @notice Returns the Vault's pause window end time.
     * @dev This value is immutable, and represents the timestamp after which the Vault can no longer be paused
     * by governance. Balancer timestamps are 32 bits.
     *
     * @return pauseWindowEndTime The timestamp when the Vault's pause window ends
     */
    function getPauseWindowEndTime() external view returns (uint32 pauseWindowEndTime);

    /**
     * @notice Returns the Vault's buffer period duration.
     * @dev This value is immutable. It represents the period during which, if paused, the Vault will remain paused.
     * This ensures there is time available to address whatever issue caused the Vault to be paused. Balancer
     * timestamps are 32 bits.
     *
     * @return bufferPeriodDuration The length of the buffer period in seconds
     */
    function getBufferPeriodDuration() external view returns (uint32 bufferPeriodDuration);

    /**
     * @notice Returns the Vault's buffer period end time.
     * @dev This value is immutable. If already paused, the Vault can be unpaused until this timestamp. Balancer
     * timestamps are 32 bits.
     *
     * @return bufferPeriodEndTime The timestamp after which the Vault remains permanently unpaused
     */
    function getBufferPeriodEndTime() external view returns (uint32 bufferPeriodEndTime);

    /**
     * @notice Get the minimum number of tokens in a pool.
     * @dev We expect the vast majority of pools to be 2-token.
     * @return minTokens The minimum token count of a pool
     */
    function getMinimumPoolTokens() external pure returns (uint256 minTokens);

    /**
     * @notice Get the maximum number of tokens in a pool.
     * @return maxTokens The maximum token count of a pool
     */
    function getMaximumPoolTokens() external pure returns (uint256 maxTokens);

    /**
     * @notice Get the minimum total supply of pool tokens (BPT) for an initialized pool.
     * @dev This prevents pools from being completely drained. When the pool is initialized, this minimum amount of BPT
     * is minted to the zero address. This is an 18-decimal floating point number; BPT are always 18 decimals.
     *
     * @return poolMinimumTotalSupply The minimum total supply a pool can have after initialization
     */
    function getPoolMinimumTotalSupply() external pure returns (uint256 poolMinimumTotalSupply);

    /**
     * @notice Get the minimum total supply of an ERC4626 wrapped token buffer in the Vault.
     * @dev This prevents buffers from being completely drained. When the buffer is initialized, this minimum number
     * of shares is added to the shares resulting from the initial deposit. Buffer total supply accounting is internal
     * to the Vault, as buffers are not tokenized.
     *
     * @return bufferMinimumTotalSupply The minimum total supply a buffer can have after initialization
     */
    function getBufferMinimumTotalSupply() external pure returns (uint256 bufferMinimumTotalSupply);

    /**
     * @notice Get the minimum trade amount in a pool operation.
     * @dev This limit is applied to the 18-decimal "upscaled" amount in any operation (swap, add/remove liquidity).
     * @return minimumTradeAmount The minimum trade amount as an 18-decimal floating point number
     */
    function getMinimumTradeAmount() external view returns (uint256 minimumTradeAmount);

    /**
     * @notice Get the minimum wrap amount in a buffer operation.
     * @dev This limit is applied to the wrap operation amount, in native underlying token decimals.
     * @return minimumWrapAmount The minimum wrap amount in native underlying token decimals
     */
    function getMinimumWrapAmount() external view returns (uint256 minimumWrapAmount);

    /*******************************************************************************
                                    Vault Pausing
    *******************************************************************************/

    /**
     * @notice Indicates whether the Vault is paused.
     * @dev If the Vault is paused, all non-Recovery Mode state-changing operations on pools will revert. Note that
     * ERC4626 buffers and the Vault have separate and independent pausing mechanisms. Pausing the Vault does not
     * also pause buffers (though we anticipate they would likely be paused and unpaused together). Call
     * `areBuffersPaused` to check the pause state of the buffers.
     *
     * @return vaultPaused True if the Vault is paused
     */
    function isVaultPaused() external view returns (bool vaultPaused);

    /**
     * @notice Returns the paused status, and end times of the Vault's pause window and buffer period.
     * @dev Balancer timestamps are 32 bits.
     * @return vaultPaused True if the Vault is paused
     * @return vaultPauseWindowEndTime The timestamp of the end of the Vault's pause window
     * @return vaultBufferPeriodEndTime The timestamp of the end of the Vault's buffer period
     */
    function getVaultPausedState()
        external
        view
        returns (bool vaultPaused, uint32 vaultPauseWindowEndTime, uint32 vaultBufferPeriodEndTime);

    /**
     * @notice Pause the Vault: an emergency action which disables all operational state-changing functions on pools.
     * @dev This is a permissioned function that will only work during the Pause Window set during deployment.
     * Note that ERC4626 buffer operations have an independent pause mechanism, which is not affected by pausing
     * the Vault. Custom routers could still wrap/unwrap using buffers while the Vault is paused, unless buffers
     * are also paused (with `pauseVaultBuffers`).
     */
    function pauseVault() external;

    /**
     * @notice Reverse a `pause` operation, and restore Vault pool operations to normal functionality.
     * @dev This is a permissioned function that will only work on a paused Vault within the Buffer Period set during
     * deployment. Note that the Vault will automatically unpause after the Buffer Period expires. As noted above,
     * ERC4626 buffers and Vault operations on pools are independent. Unpausing the Vault does not reverse
     * `pauseVaultBuffers`. If buffers were also paused, they will remain in that state until explicitly unpaused.
     */
    function unpauseVault() external;

    /*******************************************************************************
                                    Pool Pausing
    *******************************************************************************/

    /**
     * @notice Pause the Pool: an emergency action which disables all pool functions.
     * @dev This is a permissioned function that will only work during the Pause Window set during pool factory
     * deployment.
     *
     * @param pool The pool being paused
     */
    function pausePool(address pool) external;

    /**
     * @notice Reverse a `pause` operation, and restore the Pool to normal functionality.
     * @dev This is a permissioned function that will only work on a paused Pool within the Buffer Period set during
     * deployment. Note that the Pool will automatically unpause after the Buffer Period expires.
     *
     * @param pool The pool being unpaused
     */
    function unpausePool(address pool) external;

    /*******************************************************************************
                                         Fees
    *******************************************************************************/

    /**
     * @notice Assigns a new static swap fee percentage to the specified pool.
     * @dev This is a permissioned function, disabled if the pool is paused. The swap fee percentage must be within
     * the bounds specified by the pool's implementation of `ISwapFeePercentageBounds`.
     * Emits the SwapFeePercentageChanged event.
     *
     * @param pool The address of the pool for which the static swap fee will be changed
     * @param swapFeePercentage The new swap fee percentage to apply to the pool
     */
    function setStaticSwapFeePercentage(address pool, uint256 swapFeePercentage) external;

    /**
     * @notice Collects accumulated aggregate swap and yield fees for the specified pool.
     * @dev Fees are sent to the ProtocolFeeController address.
     * @param pool The pool on which all aggregate fees should be collected
     * @return swapFeeAmounts An array with the total swap fees collected, sorted in token registration order
     * @return yieldFeeAmounts An array with the total yield fees collected, sorted in token registration order
     */
    function collectAggregateFees(
        address pool
    ) external returns (uint256[] memory swapFeeAmounts, uint256[] memory yieldFeeAmounts);

    /**
     * @notice Update an aggregate swap fee percentage.
     * @dev Can only be called by the current protocol fee controller. Called when governance overrides a protocol fee
     * for a specific pool, or to permissionlessly update a pool to a changed global protocol fee value (if the pool's
     * fee has not previously been set by governance). Ensures the aggregate percentage <= FixedPoint.ONE, and also
     * that the final value does not lose precision when stored in 24 bits (see `FEE_BITLENGTH` in VaultTypes.sol).
     * Emits an `AggregateSwapFeePercentageChanged` event.
     *
     * @param pool The pool whose swap fee percentage will be updated
     * @param newAggregateSwapFeePercentage The new aggregate swap fee percentage
     */
    function updateAggregateSwapFeePercentage(address pool, uint256 newAggregateSwapFeePercentage) external;

    /**
     * @notice Update an aggregate yield fee percentage.
     * @dev Can only be called by the current protocol fee controller. Called when governance overrides a protocol fee
     * for a specific pool, or to permissionlessly update a pool to a changed global protocol fee value (if the pool's
     * fee has not previously been set by governance). Ensures the aggregate percentage <= FixedPoint.ONE, and also
     * that the final value does not lose precision when stored in 24 bits (see `FEE_BITLENGTH` in VaultTypes.sol).
     * Emits an `AggregateYieldFeePercentageChanged` event.
     *
     * @param pool The pool whose yield fee percentage will be updated
     * @param newAggregateYieldFeePercentage The new aggregate yield fee percentage
     */
    function updateAggregateYieldFeePercentage(address pool, uint256 newAggregateYieldFeePercentage) external;

    /**
     * @notice Sets a new Protocol Fee Controller for the Vault.
     * @dev This is a permissioned call. Emits a `ProtocolFeeControllerChanged` event.
     * @param newProtocolFeeController The address of the new Protocol Fee Controller
     */
    function setProtocolFeeController(IProtocolFeeController newProtocolFeeController) external;

    /*******************************************************************************
                                    Recovery Mode
    *******************************************************************************/

    /**
     * @notice Enable recovery mode for a pool.
     * @dev This is a permissioned function. It enables a safe proportional withdrawal, with no external calls.
     * Since there are no external calls, ensuring that entering Recovery Mode cannot fail, we cannot compute and so
     * must forfeit any yield fees between the last operation and enabling Recovery Mode. For the same reason, live
     * balances cannot be updated while in Recovery Mode, as doing so might cause withdrawals to fail.
     *
     * @param pool The address of the pool
     */
    function enableRecoveryMode(address pool) external;

    /**
     * @notice Disable recovery mode for a pool.
     * @dev This is a permissioned function. It re-syncs live balances (which could not be updated during
     * Recovery Mode), forfeiting any yield fees that accrued while enabled. It makes external calls, and could
     * potentially fail if there is an issue with any associated Rate Providers.
     *
     * @param pool The address of the pool
     */
    function disableRecoveryMode(address pool) external;

    /*******************************************************************************
                                  Query Functionality
    *******************************************************************************/

    /**
     * @notice Disables query functionality on the Vault. Can only be called by governance.
     * @dev The query functions rely on a specific EVM feature to detect static calls. Query operations are exempt from
     * settlement constraints, so it's critical that no state changes can occur. We retain the ability to disable
     * queries in the unlikely event that EVM changes violate its assumptions (perhaps on an L2).
     * This function can be acted upon as an emergency measure in ambiguous contexts where it's not 100% clear whether
     * disabling queries is completely necessary; queries can still be re-enabled after this call.
     */
    function disableQuery() external;

    /**
     * @notice Disables query functionality permanently on the Vault. Can only be called by governance.
     * @dev Shall only be used when there is no doubt that queries pose a fundamental threat to the system.
     */
    function disableQueryPermanently() external;

    /**
     * @notice Enables query functionality on the Vault. Can only be called by governance.
     * @dev Only works if queries are not permanently disabled.
     */
    function enableQuery() external;

    /*******************************************************************************
                                  ERC4626 Buffers
    *******************************************************************************/

    /**
     * @notice Indicates whether the Vault buffers are paused.
     * @dev When buffers are paused, all buffer operations (i.e., calls on the Router with `isBuffer` true)
     * will revert. Pausing buffers is reversible. Note that ERC4626 buffers and the Vault have separate and
     * independent pausing mechanisms. Pausing the Vault does not also pause buffers (though we anticipate they
     * would likely be paused and unpaused together). Call `isVaultPaused` to check the pause state of the Vault.
     *
     * @return buffersPaused True if the Vault buffers are paused
     */
    function areBuffersPaused() external view returns (bool buffersPaused);

    /**
     * @notice Pauses native vault buffers globally.
     * @dev When buffers are paused, it's not possible to add liquidity or wrap/unwrap tokens using the Vault's
     * `erc4626BufferWrapOrUnwrap` primitive. However, it's still possible to remove liquidity. Currently it's not
     * possible to pause vault buffers individually.
     *
     * This is a permissioned call, and is reversible (see `unpauseVaultBuffers`). Note that the Vault has a separate
     * and independent pausing mechanism. It is possible to pause the Vault (i.e. pool operations), without affecting
     * buffers, and vice versa.
     */
    function pauseVaultBuffers() external;

    /**
     * @notice Unpauses native vault buffers globally.
     * @dev When buffers are paused, it's not possible to add liquidity or wrap/unwrap tokens using the Vault's
     * `erc4626BufferWrapOrUnwrap` primitive. However, it's still possible to remove liquidity. As noted above,
     * ERC4626 buffers and Vault operations on pools are independent. Unpausing buffers does not reverse `pauseVault`.
     * If the Vault was also paused, it will remain in that state until explicitly unpaused.
     *
     * This is a permissioned call.
     */
    function unpauseVaultBuffers() external;

    /**
     * @notice Initializes buffer for the given wrapped token.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @param amountUnderlyingRaw Amount of underlying tokens that will be deposited into the buffer
     * @param amountWrappedRaw Amount of wrapped tokens that will be deposited into the buffer
     * @param minIssuedShares Minimum amount of shares to receive from the buffer, expressed in underlying token
     * native decimals
     * @param sharesOwner Address that will own the deposited liquidity. Only this address will be able to remove
     * liquidity from the buffer
     * @return issuedShares the amount of tokens sharesOwner has in the buffer, expressed in underlying token amounts.
     * (it is the BPT of an internal ERC4626 buffer). It is expressed in underlying token native decimals.
     */
    function initializeBuffer(
        IERC4626 wrappedToken,
        uint256 amountUnderlyingRaw,
        uint256 amountWrappedRaw,
        uint256 minIssuedShares,
        address sharesOwner
    ) external returns (uint256 issuedShares);

    /**
     * @notice Adds liquidity to an internal ERC4626 buffer in the Vault, proportionally.
     * @dev The buffer needs to be initialized beforehand.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @param maxAmountUnderlyingInRaw Maximum amount of underlying tokens to add to the buffer. It is expressed in
     * underlying token native decimals
     * @param maxAmountWrappedInRaw Maximum amount of wrapped tokens to add to the buffer. It is expressed in wrapped
     * token native decimals
     * @param exactSharesToIssue The value in underlying tokens that `sharesOwner` wants to add to the buffer,
     * in underlying token decimals
     * @param sharesOwner Address that will own the deposited liquidity. Only this address will be able to remove
     * liquidity from the buffer
     * @return amountUnderlyingRaw Amount of underlying tokens deposited into the buffer
     * @return amountWrappedRaw Amount of wrapped tokens deposited into the buffer
     */
    function addLiquidityToBuffer(
        IERC4626 wrappedToken,
        uint256 maxAmountUnderlyingInRaw,
        uint256 maxAmountWrappedInRaw,
        uint256 exactSharesToIssue,
        address sharesOwner
    ) external returns (uint256 amountUnderlyingRaw, uint256 amountWrappedRaw);

    /**
     * @notice Removes liquidity from an internal ERC4626 buffer in the Vault.
     * @dev Only proportional exits are supported, and the sender has to be the owner of the shares.
     * This function unlocks the Vault just for this operation; it does not work with a Router as an entrypoint.
     *
     * Pre-conditions:
     * - The buffer needs to be initialized.
     * - sharesOwner is the original msg.sender, it needs to be checked in the Router. That's why
     *   this call is authenticated; only routers approved by the DAO can remove the liquidity of a buffer.
     * - The buffer needs to have some liquidity and have its asset registered in `_bufferAssets` storage.
     *
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @param sharesToRemove Amount of shares to remove from the buffer. Cannot be greater than sharesOwner's
     * total shares. It is expressed in underlying token native decimals
     * @param minAmountUnderlyingOutRaw Minimum amount of underlying tokens to receive from the buffer. It is expressed
     * in underlying token native decimals
     * @param minAmountWrappedOutRaw Minimum amount of wrapped tokens to receive from the buffer. It is expressed in
     * wrapped token native decimals
     * @return removedUnderlyingBalanceRaw Amount of underlying tokens returned to the user
     * @return removedWrappedBalanceRaw Amount of wrapped tokens returned to the user
     */
    function removeLiquidityFromBuffer(
        IERC4626 wrappedToken,
        uint256 sharesToRemove,
        uint256 minAmountUnderlyingOutRaw,
        uint256 minAmountWrappedOutRaw
    ) external returns (uint256 removedUnderlyingBalanceRaw, uint256 removedWrappedBalanceRaw);

    /**
     * @notice Returns the asset registered for a given wrapped token.
     * @dev The asset can never change after buffer initialization.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @return underlyingToken Address of the underlying token registered for the wrapper; `address(0)` if the buffer
     * has not been initialized.
     */
    function getBufferAsset(IERC4626 wrappedToken) external view returns (address underlyingToken);

    /**
     * @notice Returns the shares (internal buffer BPT) of a liquidity owner: a user that deposited assets
     * in the buffer.
     *
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @param liquidityOwner Address of the user that owns liquidity in the wrapped token's buffer
     * @return ownerShares Amount of shares allocated to the liquidity owner, in native underlying token decimals
     */
    function getBufferOwnerShares(
        IERC4626 wrappedToken,
        address liquidityOwner
    ) external view returns (uint256 ownerShares);

    /**
     * @notice Returns the supply shares (internal buffer BPT) of the ERC4626 buffer.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @return bufferShares Amount of supply shares of the buffer, in native underlying token decimals
     */
    function getBufferTotalShares(IERC4626 wrappedToken) external view returns (uint256 bufferShares);

    /**
     * @notice Returns the amount of underlying and wrapped tokens deposited in the internal buffer of the Vault.
     * @dev All values are in native token decimals of the wrapped or underlying tokens.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @return underlyingBalanceRaw Amount of underlying tokens deposited into the buffer, in native token decimals
     * @return wrappedBalanceRaw Amount of wrapped tokens deposited into the buffer, in native token decimals
     */
    function getBufferBalance(
        IERC4626 wrappedToken
    ) external view returns (uint256 underlyingBalanceRaw, uint256 wrappedBalanceRaw);

    /*******************************************************************************
                                Authentication
    *******************************************************************************/

    /**
     * @notice Sets a new Authorizer for the Vault.
     * @dev This is a permissioned call. Emits an `AuthorizerChanged` event.
     * @param newAuthorizer The address of the new authorizer
     */
    function setAuthorizer(IAuthorizer newAuthorizer) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Errors are declared inside an interface (namespace) to improve DX with Typechain.
interface IVaultErrors {
    /*******************************************************************************
                            Registration and Initialization
    *******************************************************************************/

    /**
     * @notice A pool has already been registered. `registerPool` may only be called once.
     * @param pool The already registered pool
     */
    error PoolAlreadyRegistered(address pool);

    /**
     * @notice A pool has already been initialized. `initialize` may only be called once.
     * @param pool The already initialized pool
     */
    error PoolAlreadyInitialized(address pool);

    /**
     * @notice A pool has not been registered.
     * @param pool The unregistered pool
     */
    error PoolNotRegistered(address pool);

    /**
     * @notice A referenced pool has not been initialized.
     * @param pool The uninitialized pool
     */
    error PoolNotInitialized(address pool);

    /**
     * @notice A hook contract rejected a pool on registration.
     * @param poolHooksContract Address of the hook contract that rejected the pool registration
     * @param pool Address of the rejected pool
     * @param poolFactory Address of the pool factory
     */
    error HookRegistrationFailed(address poolHooksContract, address pool, address poolFactory);

    /**
     * @notice A token was already registered (i.e., it is a duplicate in the pool).
     * @param token The duplicate token
     */
    error TokenAlreadyRegistered(IERC20 token);

    /// @notice The token count is below the minimum allowed.
    error MinTokens();

    /// @notice The token count is above the maximum allowed.
    error MaxTokens();

    /// @notice Invalid tokens (e.g., zero) cannot be registered.
    error InvalidToken();

    /// @notice The token type given in a TokenConfig during pool registration is invalid.
    error InvalidTokenType();

    /// @notice The data in a TokenConfig struct is inconsistent or unsupported.
    error InvalidTokenConfiguration();

    /// @notice Tokens with more than 18 decimals are not supported.
    error InvalidTokenDecimals();

    /**
     * @notice The token list passed into an operation does not match the pool tokens in the pool.
     * @param pool Address of the pool
     * @param expectedToken The correct token at a given index in the pool
     * @param actualToken The actual token found at that index
     */
    error TokensMismatch(address pool, address expectedToken, address actualToken);

    /*******************************************************************************
                                 Transient Accounting
    *******************************************************************************/

    /// @notice A transient accounting operation completed with outstanding token deltas.
    error BalanceNotSettled();

    /// @notice A user called a Vault function (swap, add/remove liquidity) outside the lock context.
    error VaultIsNotUnlocked();

    /// @notice The pool has returned false to the beforeSwap hook, indicating the transaction should revert.
    error DynamicSwapFeeHookFailed();

    /// @notice The pool has returned false to the beforeSwap hook, indicating the transaction should revert.
    error BeforeSwapHookFailed();

    /// @notice The pool has returned false to the afterSwap hook, indicating the transaction should revert.
    error AfterSwapHookFailed();

    /// @notice The pool has returned false to the beforeInitialize hook, indicating the transaction should revert.
    error BeforeInitializeHookFailed();

    /// @notice The pool has returned false to the afterInitialize hook, indicating the transaction should revert.
    error AfterInitializeHookFailed();

    /// @notice The pool has returned false to the beforeAddLiquidity hook, indicating the transaction should revert.
    error BeforeAddLiquidityHookFailed();

    /// @notice The pool has returned false to the afterAddLiquidity hook, indicating the transaction should revert.
    error AfterAddLiquidityHookFailed();

    /// @notice The pool has returned false to the beforeRemoveLiquidity hook, indicating the transaction should revert.
    error BeforeRemoveLiquidityHookFailed();

    /// @notice The pool has returned false to the afterRemoveLiquidity hook, indicating the transaction should revert.
    error AfterRemoveLiquidityHookFailed();

    /// @notice An unauthorized Router tried to call a permissioned function (i.e., using the Vault's token allowance).
    error RouterNotTrusted();

    /*******************************************************************************
                                        Swaps
    *******************************************************************************/

    /// @notice The user tried to swap zero tokens.
    error AmountGivenZero();

    /// @notice The user attempted to swap a token for itself.
    error CannotSwapSameToken();

    /**
     * @notice The user attempted to operate with a token that is not in the pool.
     * @param token The unregistered token
     */
    error TokenNotRegistered(IERC20 token);

    /**
     * @notice An amount in or out has exceeded the limit specified in the swap request.
     * @param amount The total amount in or out
     * @param limit The amount of the limit that has been exceeded
     */
    error SwapLimit(uint256 amount, uint256 limit);

    /**
     * @notice A hook adjusted amount in or out has exceeded the limit specified in the swap request.
     * @param amount The total amount in or out
     * @param limit The amount of the limit that has been exceeded
     */
    error HookAdjustedSwapLimit(uint256 amount, uint256 limit);

    /// @notice The amount given or calculated for an operation is below the minimum limit.
    error TradeAmountTooSmall();

    /*******************************************************************************
                                    Add Liquidity
    *******************************************************************************/

    /// @notice Add liquidity kind not supported.
    error InvalidAddLiquidityKind();

    /**
     * @notice A required amountIn exceeds the maximum limit specified for the operation.
     * @param tokenIn The incoming token
     * @param amountIn The total token amount in
     * @param maxAmountIn The amount of the limit that has been exceeded
     */
    error AmountInAboveMax(IERC20 tokenIn, uint256 amountIn, uint256 maxAmountIn);

    /**
     * @notice A hook adjusted amountIn exceeds the maximum limit specified for the operation.
     * @param tokenIn The incoming token
     * @param amountIn The total token amount in
     * @param maxAmountIn The amount of the limit that has been exceeded
     */
    error HookAdjustedAmountInAboveMax(IERC20 tokenIn, uint256 amountIn, uint256 maxAmountIn);

    /**
     * @notice The BPT amount received from adding liquidity is below the minimum specified for the operation.
     * @param amountOut The total BPT amount out
     * @param minAmountOut The amount of the limit that has been exceeded
     */
    error BptAmountOutBelowMin(uint256 amountOut, uint256 minAmountOut);

    /// @notice Pool does not support adding liquidity with a customized input.
    error DoesNotSupportAddLiquidityCustom();

    /// @notice Pool does not support adding liquidity through donation.
    error DoesNotSupportDonation();

    /*******************************************************************************
                                    Remove Liquidity
    *******************************************************************************/

    /// @notice Remove liquidity kind not supported.
    error InvalidRemoveLiquidityKind();

    /**
     * @notice The actual amount out is below the minimum limit specified for the operation.
     * @param tokenOut The outgoing token
     * @param amountOut The total BPT amount out
     * @param minAmountOut The amount of the limit that has been exceeded
     */
    error AmountOutBelowMin(IERC20 tokenOut, uint256 amountOut, uint256 minAmountOut);

    /**
     * @notice The hook adjusted amount out is below the minimum limit specified for the operation.
     * @param tokenOut The outgoing token
     * @param amountOut The total BPT amount out
     * @param minAmountOut The amount of the limit that has been exceeded
     */
    error HookAdjustedAmountOutBelowMin(IERC20 tokenOut, uint256 amountOut, uint256 minAmountOut);

    /**
     * @notice The required BPT amount in exceeds the maximum limit specified for the operation.
     * @param amountIn The total BPT amount in
     * @param maxAmountIn The amount of the limit that has been exceeded
     */
    error BptAmountInAboveMax(uint256 amountIn, uint256 maxAmountIn);

    /// @notice Pool does not support removing liquidity with a customized input.
    error DoesNotSupportRemoveLiquidityCustom();

    /*******************************************************************************
                                     Fees
    *******************************************************************************/

    /**
     * @notice Error raised when there is an overflow in the fee calculation.
     * @dev This occurs when the sum of the parts (aggregate swap or yield fee) is greater than the whole
     * (total swap or yield fee). Also validated when the protocol fee controller updates aggregate fee
     * percentages in the Vault.
     */
    error ProtocolFeesExceedTotalCollected();

    /**
     * @notice Error raised when the swap fee percentage is less than the minimum allowed value.
     * @dev The Vault itself does not impose a universal minimum. Rather, it validates against the
     * range specified by the `ISwapFeePercentageBounds` interface. and reverts with this error
     * if it is below the minimum value returned by the pool.
     *
     * Pools with dynamic fees do not check these limits.
     */
    error SwapFeePercentageTooLow();

    /**
     * @notice Error raised when the swap fee percentage is greater than the maximum allowed value.
     * @dev The Vault itself does not impose a universal minimum. Rather, it validates against the
     * range specified by the `ISwapFeePercentageBounds` interface. and reverts with this error
     * if it is above the maximum value returned by the pool.
     *
     * Pools with dynamic fees do not check these limits.
     */
    error SwapFeePercentageTooHigh();

    /**
     * @notice Primary fee percentages result in an aggregate fee that cannot be stored with the required precision.
     * @dev Primary fee percentages are 18-decimal values, stored here in 64 bits, and calculated with full 256-bit
     * precision. However, the resulting aggregate fees are stored in the Vault with 24-bit precision, which
     * corresponds to 0.00001% resolution (i.e., a fee can be 1%, 1.00001%, 1.00002%, but not 1.000005%).
     * Disallow setting fees such that there would be precision loss in the Vault, leading to a discrepancy between
     * the aggregate fee calculated here and that stored in the Vault.
     */
    error FeePrecisionTooHigh();

    /// @notice A given percentage is above the maximum (usually a value close to FixedPoint.ONE, or 1e18 wei).
    error PercentageAboveMax();

    /*******************************************************************************
                                    Queries
    *******************************************************************************/

    /// @notice A user tried to execute a query operation when they were disabled.
    error QueriesDisabled();

    /// @notice An admin tried to re-enable queries, but they were disabled permanently.
    error QueriesDisabledPermanently();

    /*******************************************************************************
                                Recovery Mode
    *******************************************************************************/

    /**
     * @notice Cannot enable recovery mode when already enabled.
     * @param pool The pool
     */
    error PoolInRecoveryMode(address pool);

    /**
     * @notice Cannot disable recovery mode when not enabled.
     * @param pool The pool
     */
    error PoolNotInRecoveryMode(address pool);

    /*******************************************************************************
                                Authentication
    *******************************************************************************/

    /**
     * @notice Error indicating the sender is not the Vault (e.g., someone is trying to call a permissioned function).
     * @param sender The account attempting to call a permissioned function
     */
    error SenderIsNotVault(address sender);

    /*******************************************************************************
                                        Pausing
    *******************************************************************************/

    /// @notice The caller specified a pause window period longer than the maximum.
    error VaultPauseWindowDurationTooLarge();

    /// @notice The caller specified a buffer period longer than the maximum.
    error PauseBufferPeriodDurationTooLarge();

    /// @notice A user tried to perform an operation while the Vault was paused.
    error VaultPaused();

    /// @notice Governance tried to unpause the Vault when it was not paused.
    error VaultNotPaused();

    /// @notice Governance tried to pause the Vault after the pause period expired.
    error VaultPauseWindowExpired();

    /**
     * @notice A user tried to perform an operation involving a paused Pool.
     * @param pool The paused pool
     */
    error PoolPaused(address pool);

    /**
     * @notice Governance tried to unpause the Pool when it was not paused.
     * @param pool The unpaused pool
     */
    error PoolNotPaused(address pool);

    /**
     * @notice Governance tried to pause a Pool after the pause period expired.
     * @param pool The pool
     */
    error PoolPauseWindowExpired(address pool);

    /*******************************************************************************
                                ERC4626 token buffers
    *******************************************************************************/

    /**
     * @notice The buffer for the given wrapped token was already initialized.
     * @param wrappedToken The wrapped token corresponding to the buffer
     */
    error BufferAlreadyInitialized(IERC4626 wrappedToken);

    /**
     * @notice The buffer for the given wrapped token was not initialized.
     * @param wrappedToken The wrapped token corresponding to the buffer
     */
    error BufferNotInitialized(IERC4626 wrappedToken);

    /// @notice The user is trying to remove more than their allocated shares from the buffer.
    error NotEnoughBufferShares();

    /**
     * @notice The wrapped token asset does not match the underlying token.
     * @dev This should never happen, but a malicious wrapper contract might not return the correct address.
     * Legitimate wrapper contracts should make the asset a constant or immutable value.
     *
     * @param wrappedToken The wrapped token corresponding to the buffer
     * @param underlyingToken The underlying token returned by `asset`
     */
    error WrongUnderlyingToken(IERC4626 wrappedToken, address underlyingToken);

    /**
     * @notice A wrapped token reported the zero address as its underlying token asset.
     * @dev This should never happen, but a malicious wrapper contract might do this (e.g., in an attempt to
     * re-initialize the buffer).
     *
     * @param wrappedToken The wrapped token corresponding to the buffer
     */
    error InvalidUnderlyingToken(IERC4626 wrappedToken);

    /**
     * @notice The amount given to wrap/unwrap was too small, which can introduce rounding issues.
     * @param wrappedToken The wrapped token corresponding to the buffer
     */
    error WrapAmountTooSmall(IERC4626 wrappedToken);

    /// @notice Buffer operation attempted while vault buffers are paused.
    error VaultBuffersArePaused();

    /// @notice Buffer shares were minted to the zero address.
    error BufferSharesInvalidReceiver();

    /// @notice Buffer shares were burned from the zero address.
    error BufferSharesInvalidOwner();

    /**
     * @notice The total supply of a buffer can't be lower than the absolute minimum.
     * @param totalSupply The total supply value that was below the minimum
     */
    error BufferTotalSupplyTooLow(uint256 totalSupply);

    /// @dev A wrap/unwrap operation consumed more or returned less underlying tokens than it should.
    error NotEnoughUnderlying(IERC4626 wrappedToken, uint256 expectedUnderlyingAmount, uint256 actualUnderlyingAmount);

    /// @dev A wrap/unwrap operation consumed more or returned less wrapped tokens than it should.
    error NotEnoughWrapped(IERC4626 wrappedToken, uint256 expectedWrappedAmount, uint256 actualWrappedAmount);

    /// @dev Shares issued during initialization are below the requested amount.
    error IssuedSharesBelowMin(uint256 issuedShares, uint256 minIssuedShares);

    /*******************************************************************************
                                    Miscellaneous
    *******************************************************************************/

    /// @notice Pool does not support adding / removing liquidity with an unbalanced input.
    error DoesNotSupportUnbalancedLiquidity();

    /// @notice The contract should not receive ETH.
    error CannotReceiveEth();

    /**
     * @notice The `VaultExtension` contract was called by an account directly.
     * @dev It can only be called by the Vault via delegatecall.
     */
    error NotVaultDelegateCall();

    /// @notice The `VaultExtension` contract was configured with an incorrect Vault address.
    error WrongVaultExtensionDeployment();

    /// @notice The `ProtocolFeeController` contract was configured with an incorrect Vault address.
    error WrongProtocolFeeControllerDeployment();

    /// @notice The `VaultAdmin` contract was configured with an incorrect Vault address.
    error WrongVaultAdminDeployment();

    /// @notice Quote reverted with a reserved error code.
    error QuoteResultSpoofed();
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IProtocolFeeController } from "./IProtocolFeeController.sol";
import { IAuthorizer } from "./IAuthorizer.sol";
import { IHooks } from "./IHooks.sol";
import "./VaultTypes.sol";

/// @dev Events are declared inside an interface (namespace) to improve DX with Typechain.
interface IVaultEvents {
    /**
     * @notice A Pool was registered by calling `registerPool`.
     * @param pool The pool being registered
     * @param factory The factory creating the pool
     * @param tokenConfig An array of descriptors for the tokens the pool will manage
     * @param swapFeePercentage The static swap fee of the pool
     * @param pauseWindowEndTime The pool's pause window end time
     * @param roleAccounts Addresses the Vault will allow to change certain pool settings
     * @param hooksConfig Flags indicating which hooks the pool supports and address of hooks contract
     * @param liquidityManagement Supported liquidity management hook flags
     */
    event PoolRegistered(
        address indexed pool,
        address indexed factory,
        TokenConfig[] tokenConfig,
        uint256 swapFeePercentage,
        uint32 pauseWindowEndTime,
        PoolRoleAccounts roleAccounts,
        HooksConfig hooksConfig,
        LiquidityManagement liquidityManagement
    );

    /**
     * @notice A Pool was initialized by calling `initialize`.
     * @param pool The pool being initialized
     */
    event PoolInitialized(address indexed pool);

    /**
     * @notice A swap has occurred.
     * @param pool The pool with the tokens being swapped
     * @param tokenIn The token entering the Vault (balance increases)
     * @param tokenOut The token leaving the Vault (balance decreases)
     * @param amountIn Number of tokenIn tokens
     * @param amountOut Number of tokenOut tokens
     * @param swapFeePercentage Swap fee percentage applied (can differ if dynamic)
     * @param swapFeeAmount Swap fee amount paid
     */
    event Swap(
        address indexed pool,
        IERC20 indexed tokenIn,
        IERC20 indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 swapFeePercentage,
        uint256 swapFeeAmount
    );

    /**
     * @notice A wrap operation has occurred.
     * @param wrappedToken The wrapped token address
     * @param depositedUnderlying Number of underlying tokens deposited
     * @param mintedShares Number of shares (wrapped tokens) minted
     * @param bufferBalances The final buffer balances, packed in 128-bit words (underlying, wrapped)
     */
    event Wrap(
        IERC4626 indexed wrappedToken,
        uint256 depositedUnderlying,
        uint256 mintedShares,
        bytes32 bufferBalances
    );

    /**
     * @notice An unwrap operation has occurred.
     * @param wrappedToken The wrapped token address
     * @param burnedShares Number of shares (wrapped tokens) burned
     * @param withdrawnUnderlying Number of underlying tokens withdrawn
     * @param bufferBalances The final buffer balances, packed in 128-bit words (underlying, wrapped)
     */
    event Unwrap(
        IERC4626 indexed wrappedToken,
        uint256 burnedShares,
        uint256 withdrawnUnderlying,
        bytes32 bufferBalances
    );

    /**
     * @notice Liquidity has been added to a pool (including initialization).
     * @param pool The pool with liquidity added
     * @param liquidityProvider The user performing the operation
     * @param kind The add liquidity operation type (e.g., proportional, custom)
     * @param totalSupply The total supply of the pool after the operation
     * @param amountsAddedRaw The amount of each token that was added, sorted in token registration order
     * @param swapFeeAmountsRaw The total swap fees charged, sorted in token registration order
     */
    event LiquidityAdded(
        address indexed pool,
        address indexed liquidityProvider,
        AddLiquidityKind indexed kind,
        uint256 totalSupply,
        uint256[] amountsAddedRaw,
        uint256[] swapFeeAmountsRaw
    );

    /**
     * @notice Liquidity has been removed from a pool.
     * @param pool The pool with liquidity removed
     * @param liquidityProvider The user performing the operation
     * @param kind The remove liquidity operation type (e.g., proportional, custom)
     * @param totalSupply The total supply of the pool after the operation
     * @param amountsRemovedRaw The amount of each token that was removed, sorted in token registration order
     * @param swapFeeAmountsRaw The total swap fees charged, sorted in token registration order
     */
    event LiquidityRemoved(
        address indexed pool,
        address indexed liquidityProvider,
        RemoveLiquidityKind indexed kind,
        uint256 totalSupply,
        uint256[] amountsRemovedRaw,
        uint256[] swapFeeAmountsRaw
    );

    /**
     * @notice The Vault's pause status has changed.
     * @param paused True if the Vault was paused
     */
    event VaultPausedStateChanged(bool paused);

    /// @notice `disableQuery` has been called on the Vault, disabling query functionality.
    event VaultQueriesDisabled();

    /// @notice `enableQuery` has been called on the Vault, enabling query functionality.
    event VaultQueriesEnabled();

    /**
     * @notice A Pool's pause status has changed.
     * @param pool The pool that was just paused or unpaused
     * @param paused True if the pool was paused
     */
    event PoolPausedStateChanged(address indexed pool, bool paused);

    /**
     * @notice Emitted when the swap fee percentage of a pool is updated.
     * @param swapFeePercentage The new swap fee percentage for the pool
     */
    event SwapFeePercentageChanged(address indexed pool, uint256 swapFeePercentage);

    /**
     * @notice Recovery mode has been enabled or disabled for a pool.
     * @param pool The pool
     * @param recoveryMode True if recovery mode was enabled
     */
    event PoolRecoveryModeStateChanged(address indexed pool, bool recoveryMode);

    /**
     * @notice A protocol or pool creator fee has changed, causing an update to the aggregate swap fee.
     * @dev The `ProtocolFeeController` will emit an event with the underlying change.
     * @param pool The pool whose aggregate swap fee percentage changed
     * @param aggregateSwapFeePercentage The new aggregate swap fee percentage
     */
    event AggregateSwapFeePercentageChanged(address indexed pool, uint256 aggregateSwapFeePercentage);

    /**
     * @notice A protocol or pool creator fee has changed, causing an update to the aggregate yield fee.
     * @dev The `ProtocolFeeController` will emit an event with the underlying change.
     * @param pool The pool whose aggregate yield fee percentage changed
     * @param aggregateYieldFeePercentage The new aggregate yield fee percentage
     */
    event AggregateYieldFeePercentageChanged(address indexed pool, uint256 aggregateYieldFeePercentage);

    /**
     * @notice A new authorizer is set by `setAuthorizer`.
     * @param newAuthorizer The address of the new authorizer
     */
    event AuthorizerChanged(IAuthorizer indexed newAuthorizer);

    /**
     * @notice A new protocol fee controller is set by `setProtocolFeeController`.
     * @param newProtocolFeeController The address of the new protocol fee controller
     */
    event ProtocolFeeControllerChanged(IProtocolFeeController indexed newProtocolFeeController);

    /**
     * @notice Liquidity was added to an ERC4626 buffer corresponding to the given wrapped token.
     * @dev The underlying token can be derived from the wrapped token, so it's not included here.
     *
     * @param wrappedToken The wrapped token that identifies the buffer
     * @param amountUnderlying The amount of the underlying token that was deposited
     * @param amountWrapped The amount of the wrapped token that was deposited
     * @param bufferBalances The final buffer balances, packed in 128-bit words (underlying, wrapped)
     */
    event LiquidityAddedToBuffer(
        IERC4626 indexed wrappedToken,
        uint256 amountUnderlying,
        uint256 amountWrapped,
        bytes32 bufferBalances
    );

    /**
     * @notice Buffer shares were minted for an ERC4626 buffer corresponding to a given wrapped token.
     * @dev The shares are not tokenized like pool BPT, but accounted for in the Vault. `getBufferOwnerShares`
     * retrieves the current total shares for a given buffer and address, and `getBufferTotalShares` returns the
     * "totalSupply" of a buffer.
     *
     * @param wrappedToken The wrapped token that identifies the buffer
     * @param to The owner of the minted shares
     * @param issuedShares The amount of "internal BPT" shares created
     */
    event BufferSharesMinted(IERC4626 indexed wrappedToken, address indexed to, uint256 issuedShares);

    /**
     * @notice Buffer shares were burned for an ERC4626 buffer corresponding to a given wrapped token.
     * @dev The shares are not tokenized like pool BPT, but accounted for in the Vault. `getBufferOwnerShares`
     * retrieves the current total shares for a given buffer and address, and `getBufferTotalShares` returns the
     * "totalSupply" of a buffer.
     *
     * @param wrappedToken The wrapped token that identifies the buffer
     * @param from The owner of the burned shares
     * @param burnedShares The amount of "internal BPT" shares burned
     */
    event BufferSharesBurned(IERC4626 indexed wrappedToken, address indexed from, uint256 burnedShares);

    /**
     * @notice Liquidity was removed from an ERC4626 buffer.
     * @dev The underlying token can be derived from the wrapped token, so it's not included here.
     * @param wrappedToken The wrapped token that identifies the buffer
     * @param amountUnderlying The amount of the underlying token that was withdrawn
     * @param amountWrapped The amount of the wrapped token that was withdrawn
     * @param bufferBalances The final buffer balances, packed in 128-bit words (underlying, wrapped)
     */
    event LiquidityRemovedFromBuffer(
        IERC4626 indexed wrappedToken,
        uint256 amountUnderlying,
        uint256 amountWrapped,
        bytes32 bufferBalances
    );

    /**
     * @notice The Vault buffers pause status has changed.
     * @dev If buffers all paused, all buffer operations (i.e., all calls through the Router with `isBuffer`
     * set to true) will revert.
     *
     * @param paused True if the Vault buffers were paused
     */
    event VaultBuffersPausedStateChanged(bool paused);

    /**
     * @notice Pools can use this event to emit event data from the Vault.
     * @param pool Pool address
     * @param eventKey Event key
     * @param eventData Encoded event data
     */
    event VaultAuxiliary(address indexed pool, bytes32 indexed eventKey, bytes eventData);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IAuthorizer } from "./IAuthorizer.sol";
import { IProtocolFeeController } from "./IProtocolFeeController.sol";
import { IVault } from "./IVault.sol";
import { IHooks } from "./IHooks.sol";
import "./VaultTypes.sol";

/**
 * @notice Interface for functions defined on the `VaultExtension` contract.
 * @dev `VaultExtension` handles less critical or frequently used functions, since delegate calls through
 * the Vault are more expensive than direct calls. The main Vault contains the core code for swaps and
 * liquidity operations.
 */
interface IVaultExtension {
    /*******************************************************************************
                              Constants and immutables
    *******************************************************************************/

    /**
     * @notice Returns the main Vault address.
     * @dev The main Vault contains the entrypoint and main liquidity operation implementations.
     * @return vault The address of the main Vault
     */
    function vault() external view returns (IVault);

    /**
     * @notice Returns the VaultAdmin contract address.
     * @dev The VaultAdmin contract mostly implements permissioned functions.
     * @return vaultAdmin The address of the Vault admin
     */
    function getVaultAdmin() external view returns (address vaultAdmin);

    /*******************************************************************************
                              Transient Accounting
    *******************************************************************************/

    /**
     * @notice Returns whether the Vault is unlocked (i.e., executing an operation).
     * @dev The Vault must be unlocked to perform state-changing liquidity operations.
     * @return unlocked True if the Vault is unlocked, false otherwise
     */
    function isUnlocked() external view returns (bool unlocked);

    /**
     *  @notice Returns the count of non-zero deltas.
     *  @return nonzeroDeltaCount The current value of `_nonzeroDeltaCount`
     */
    function getNonzeroDeltaCount() external view returns (uint256 nonzeroDeltaCount);

    /**
     * @notice Retrieves the token delta for a specific token.
     * @dev This function allows reading the value from the `_tokenDeltas` mapping.
     * @param token The token for which the delta is being fetched
     * @return tokenDelta The delta of the specified token
     */
    function getTokenDelta(IERC20 token) external view returns (int256 tokenDelta);

    /**
     * @notice Retrieves the reserve (i.e., total Vault balance) of a given token.
     * @param token The token for which to retrieve the reserve
     * @return reserveAmount The amount of reserves for the given token
     */
    function getReservesOf(IERC20 token) external view returns (uint256 reserveAmount);

    /**
     * @notice This flag is used to detect and tax "round-trip" interactions (adding and removing liquidity in the
     * same pool).
     * @dev Taxing remove liquidity proportional whenever liquidity was added in the same `unlock` call adds an extra
     * layer of security, discouraging operations that try to undo others for profit. Remove liquidity proportional
     * is the only standard way to exit a position without fees, and this flag is used to enable fees in that case.
     * It also discourages indirect swaps via unbalanced add and remove proportional, as they are expected to be worse
     * than a simple swap for every pool type.
     *
     * @param pool Address of the pool to check
     * @return liquidityAdded True if liquidity has been added to this pool in the current transaction
     
     * Note that there is no `sessionId` argument; it always returns the value for the current (i.e., latest) session.
     */
    function getAddLiquidityCalledFlag(address pool) external view returns (bool liquidityAdded);

    /*******************************************************************************
                                    Pool Registration
    *******************************************************************************/

    /**
     * @notice Registers a pool, associating it with its factory and the tokens it manages.
     * @dev A pool can opt-out of pausing by providing a zero value for the pause window, or allow pausing indefinitely
     * by providing a large value. (Pool pause windows are not limited by the Vault maximums.) The vault defines an
     * additional buffer period during which a paused pool will stay paused. After the buffer period passes, a paused
     * pool will automatically unpause. Balancer timestamps are 32 bits.
     *
     * A pool can opt out of Balancer governance pausing by providing a custom `pauseManager`. This might be a
     * multi-sig contract or an arbitrary smart contract with its own access controls, that forwards calls to
     * the Vault.
     *
     * If the zero address is provided for the `pauseManager`, permissions for pausing the pool will default to the
     * authorizer.
     *
     * @param pool The address of the pool being registered
     * @param tokenConfig An array of descriptors for the tokens the pool will manage
     * @param swapFeePercentage The initial static swap fee percentage of the pool
     * @param pauseWindowEndTime The timestamp after which it is no longer possible to pause the pool
     * @param protocolFeeExempt If true, the pool's initial aggregate fees will be set to 0
     * @param roleAccounts Addresses the Vault will allow to change certain pool settings
     * @param poolHooksContract Contract that implements the hooks for the pool
     * @param liquidityManagement Liquidity management flags with implemented methods
     */
    function registerPool(
        address pool,
        TokenConfig[] memory tokenConfig,
        uint256 swapFeePercentage,
        uint32 pauseWindowEndTime,
        bool protocolFeeExempt,
        PoolRoleAccounts calldata roleAccounts,
        address poolHooksContract,
        LiquidityManagement calldata liquidityManagement
    ) external;

    /**
     * @notice Checks whether a pool is registered.
     * @param pool Address of the pool to check
     * @return registered True if the pool is registered, false otherwise
     */
    function isPoolRegistered(address pool) external view returns (bool registered);

    /**
     * @notice Initializes a registered pool by adding liquidity; mints BPT tokens for the first time in exchange.
     * @param pool Address of the pool to initialize
     * @param to Address that will receive the output BPT
     * @param tokens Tokens used to seed the pool (must match the registered tokens)
     * @param exactAmountsIn Exact amounts of input tokens
     * @param minBptAmountOut Minimum amount of output pool tokens
     * @param userData Additional (optional) data required for adding initial liquidity
     * @return bptAmountOut Output pool token amount
     */
    function initialize(
        address pool,
        address to,
        IERC20[] memory tokens,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        bytes memory userData
    ) external returns (uint256 bptAmountOut);

    /*******************************************************************************
                                    Pool Information
    *******************************************************************************/

    /**
     * @notice Checks whether a pool is initialized.
     * @dev An initialized pool can be considered registered as well.
     * @param pool Address of the pool to check
     * @return initialized True if the pool is initialized, false otherwise
     */
    function isPoolInitialized(address pool) external view returns (bool initialized);

    /**
     * @notice Gets the tokens registered to a pool.
     * @param pool Address of the pool
     * @return tokens List of tokens in the pool
     */
    function getPoolTokens(address pool) external view returns (IERC20[] memory tokens);

    /**
     * @notice Gets pool token rates.
     * @dev This function performs external calls if tokens are yield-bearing. All returned arrays are in token
     * registration order.
     *
     * @param pool Address of the pool
     * @return decimalScalingFactors Conversion factor used to adjust for token decimals for uniform precision in
     * calculations. FP(1) for 18-decimal tokens
     * @return tokenRates 18-decimal FP values for rate tokens (e.g., yield-bearing), or FP(1) for standard tokens
     */
    function getPoolTokenRates(
        address pool
    ) external view returns (uint256[] memory decimalScalingFactors, uint256[] memory tokenRates);

    /**
     * @notice Returns comprehensive pool data for the given pool.
     * @dev This contains the pool configuration (flags), tokens and token types, rates, scaling factors, and balances.
     * @param pool The address of the pool
     * @return poolData The `PoolData` result
     */
    function getPoolData(address pool) external view returns (PoolData memory poolData);

    /**
     * @notice Gets the raw data for a pool: tokens, raw balances, scaling factors.
     * @param pool Address of the pool
     * @return tokens The pool tokens, sorted in registration order
     * @return tokenInfo Token info structs (type, rate provider, yield flag), sorted in token registration order
     * @return balancesRaw Current native decimal balances of the pool tokens, sorted in token registration order
     * @return lastBalancesLiveScaled18 Last saved live balances, sorted in token registration order
     */
    function getPoolTokenInfo(
        address pool
    )
        external
        view
        returns (
            IERC20[] memory tokens,
            TokenInfo[] memory tokenInfo,
            uint256[] memory balancesRaw,
            uint256[] memory lastBalancesLiveScaled18
        );

    /**
     * @notice Gets current live balances of a given pool (fixed-point, 18 decimals), corresponding to its tokens in
     * registration order.
     *
     * @param pool Address of the pool
     * @return balancesLiveScaled18 Token balances after paying yield fees, applying decimal scaling and rates
     */
    function getCurrentLiveBalances(address pool) external view returns (uint256[] memory balancesLiveScaled18);

    /**
     * @notice Gets the configuration parameters of a pool.
     * @dev The `PoolConfig` contains liquidity management and other state flags, fee percentages, the pause window.
     * @param pool Address of the pool
     * @return poolConfig The pool configuration as a `PoolConfig` struct
     */
    function getPoolConfig(address pool) external view returns (PoolConfig memory poolConfig);

    /**
     * @notice Gets the hooks configuration parameters of a pool.
     * @dev The `HooksConfig` contains flags indicating which pool hooks are implemented.
     * @param pool Address of the pool
     * @return hooksConfig The hooks configuration as a `HooksConfig` struct
     */
    function getHooksConfig(address pool) external view returns (HooksConfig memory hooksConfig);

    /**
     * @notice The current rate of a pool token (BPT) = invariant / totalSupply.
     * @param pool Address of the pool
     * @return rate BPT rate
     */
    function getBptRate(address pool) external view returns (uint256 rate);

    /*******************************************************************************
                                 Balancer Pool Tokens
    *******************************************************************************/

    /**
     * @notice Gets the total supply of a given ERC20 token.
     * @param token The token address
     * @return tokenTotalSupply Total supply of the token
     */
    function totalSupply(address token) external view returns (uint256 tokenTotalSupply);

    /**
     * @notice Gets the balance of an account for a given ERC20 token.
     * @param token Address of the token
     * @param account Address of the account
     * @return tokenBalance Token balance of the account
     */
    function balanceOf(address token, address account) external view returns (uint256 tokenBalance);

    /**
     * @notice Gets the allowance of a spender for a given ERC20 token and owner.
     * @param token Address of the token
     * @param owner Address of the owner
     * @param spender Address of the spender
     * @return tokenAllowance Amount of tokens the spender is allowed to spend
     */
    function allowance(address token, address owner, address spender) external view returns (uint256 tokenAllowance);

    /**
     * @notice Approves a spender to spend pool tokens on behalf of sender.
     * @dev Notice that the pool token address is not included in the params. This function is exclusively called by
     * the pool contract, so msg.sender is used as the token address.
     *
     * @param owner Address of the owner
     * @param spender Address of the spender
     * @param amount Amount of tokens to approve
     * @return success True if successful, false otherwise
     */
    function approve(address owner, address spender, uint256 amount) external returns (bool success);

    /*******************************************************************************
                                     Pool Pausing
    *******************************************************************************/

    /**
     * @notice Indicates whether a pool is paused.
     * @dev If a pool is paused, all non-Recovery Mode state-changing operations will revert.
     * @param pool The pool to be checked
     * @return poolPaused True if the pool is paused
     */
    function isPoolPaused(address pool) external view returns (bool poolPaused);

    /**
     * @notice Returns the paused status, and end times of the Pool's pause window and buffer period.
     * @dev Note that even when set to a paused state, the pool will automatically unpause at the end of
     * the buffer period. Balancer timestamps are 32 bits.
     *
     * @param pool The pool whose data is requested
     * @return poolPaused True if the Pool is paused
     * @return poolPauseWindowEndTime The timestamp of the end of the Pool's pause window
     * @return poolBufferPeriodEndTime The timestamp after which the Pool unpauses itself (if paused)
     * @return pauseManager The pause manager, or the zero address
     */
    function getPoolPausedState(
        address pool
    )
        external
        view
        returns (bool poolPaused, uint32 poolPauseWindowEndTime, uint32 poolBufferPeriodEndTime, address pauseManager);

    /*******************************************************************************
                                   ERC4626 Buffers
    *******************************************************************************/

    /**
     * @notice Checks if the wrapped token has an initialized buffer in the Vault.
     * @dev An initialized buffer should have an asset registered in the Vault.
     * @param wrappedToken Address of the wrapped token that implements IERC4626
     * @return isBufferInitialized True if the ERC4626 buffer is initialized
     */
    function isERC4626BufferInitialized(IERC4626 wrappedToken) external view returns (bool isBufferInitialized);

    /**
     * @notice Gets the registered asset for a given buffer.
     * @dev To avoid malicious wrappers (e.g., that might potentially change their asset after deployment), routers
     * should never call `wrapper.asset()` directly, at least without checking it against the asset registered with
     * the Vault on initialization.
     *
     * @param wrappedToken The wrapped token specifying the buffer
     * @return asset The underlying asset of the wrapped token
     */
    function getERC4626BufferAsset(IERC4626 wrappedToken) external view returns (address asset);

    /*******************************************************************************
                                          Fees
    *******************************************************************************/

    /**
     * @notice Returns the accumulated swap fees (including aggregate fees) in `token` collected by the pool.
     * @param pool The address of the pool for which aggregate fees have been collected
     * @param token The address of the token in which fees have been accumulated
     * @return swapFeeAmount The total amount of fees accumulated in the specified token
     */
    function getAggregateSwapFeeAmount(address pool, IERC20 token) external view returns (uint256 swapFeeAmount);

    /**
     * @notice Returns the accumulated yield fees (including aggregate fees) in `token` collected by the pool.
     * @param pool The address of the pool for which aggregate fees have been collected
     * @param token The address of the token in which fees have been accumulated
     * @return yieldFeeAmount The total amount of fees accumulated in the specified token
     */
    function getAggregateYieldFeeAmount(address pool, IERC20 token) external view returns (uint256 yieldFeeAmount);

    /**
     * @notice Fetches the static swap fee percentage for a given pool.
     * @param pool The address of the pool whose static swap fee percentage is being queried
     * @return swapFeePercentage The current static swap fee percentage for the specified pool
     */
    function getStaticSwapFeePercentage(address pool) external view returns (uint256 swapFeePercentage);

    /**
     * @notice Fetches the role accounts for a given pool (pause manager, swap manager, pool creator)
     * @param pool The address of the pool whose roles are being queried
     * @return roleAccounts A struct containing the role accounts for the pool (or 0 if unassigned)
     */
    function getPoolRoleAccounts(address pool) external view returns (PoolRoleAccounts memory roleAccounts);

    /**
     * @notice Query the current dynamic swap fee percentage of a pool, given a set of swap parameters.
     * @dev Reverts if the hook doesn't return the success flag set to `true`.
     * @param pool The pool
     * @param swapParams The swap parameters used to compute the fee
     * @return dynamicSwapFeePercentage The dynamic swap fee percentage
     */
    function computeDynamicSwapFeePercentage(
        address pool,
        PoolSwapParams memory swapParams
    ) external view returns (uint256 dynamicSwapFeePercentage);

    /**
     * @notice Returns the Protocol Fee Controller address.
     * @return protocolFeeController Address of the ProtocolFeeController
     */
    function getProtocolFeeController() external view returns (IProtocolFeeController protocolFeeController);

    /*******************************************************************************
                                     Recovery Mode
    *******************************************************************************/

    /**
     * @notice Checks whether a pool is in Recovery Mode.
     * @dev Recovery Mode enables a safe proportional withdrawal path, with no external calls.
     * @param pool Address of the pool to check
     * @return inRecoveryMode True if the pool is in Recovery Mode, false otherwise
     */
    function isPoolInRecoveryMode(address pool) external view returns (bool inRecoveryMode);

    /**
     * @notice Remove liquidity from a pool specifying exact pool tokens in, with proportional token amounts out.
     * The request is implemented by the Vault without any interaction with the pool, ensuring that
     * it works the same for all pools, and cannot be disabled by a new pool type.
     *
     * @param pool Address of the pool
     * @param from Address of user to burn pool tokens from
     * @param exactBptAmountIn Input pool token amount
     * @param minAmountsOut Minimum amounts of tokens to be received, sorted in token registration order
     * @return amountsOut Actual calculated amounts of output tokens, sorted in token registration order
     */
    function removeLiquidityRecovery(
        address pool,
        address from,
        uint256 exactBptAmountIn,
        uint256[] memory minAmountsOut
    ) external returns (uint256[] memory amountsOut);

    /*******************************************************************************
                                    Queries
    *******************************************************************************/

    /**
     * @notice Performs a callback on msg.sender with arguments provided in `data`.
     * @dev Used to query a set of operations on the Vault. Only off-chain eth_call are allowed,
     * anything else will revert.
     *
     * Allows querying any operation on the Vault that has the `onlyWhenUnlocked` modifier.
     *
     * Allows the external calling of a function via the Vault contract to
     * access Vault's functions guarded by `onlyWhenUnlocked`.
     * `transient` modifier ensuring balances changes within the Vault are settled.
     *
     * @param data Contains function signature and args to be passed to the msg.sender
     * @return result Resulting data from the call
     */
    function quote(bytes calldata data) external returns (bytes memory result);

    /**
     * @notice Performs a callback on msg.sender with arguments provided in `data`.
     * @dev Used to query a set of operations on the Vault. Only off-chain eth_call are allowed,
     * anything else will revert.
     *
     * Allows querying any operation on the Vault that has the `onlyWhenUnlocked` modifier.
     *
     * Allows the external calling of a function via the Vault contract to
     * access Vault's functions guarded by `onlyWhenUnlocked`.
     * `transient` modifier ensuring balances changes within the Vault are settled.
     *
     * This call always reverts, returning the result in the revert reason.
     *
     * @param data Contains function signature and args to be passed to the msg.sender
     */
    function quoteAndRevert(bytes calldata data) external;

    /**
     * @notice Returns true if queries are disabled on the Vault.
     * @dev If true, queries might either be disabled temporarily or permanently.
     * @return queryDisabled True if query functionality is reversibly disabled
     */
    function isQueryDisabled() external view returns (bool queryDisabled);

    /**
     * @notice Returns true if queries are disabled permanently; false if they are enabled.
     * @dev This is a one-way switch. Once queries are disabled permanently, they can never be re-enabled.
     * @return queryDisabledPermanently True if query functionality is permanently disabled
     */
    function isQueryDisabledPermanently() external view returns (bool queryDisabledPermanently);

    /**
     * @notice Pools can use this event to emit event data from the Vault.
     * @param eventKey Event key
     * @param eventData Encoded event data
     */
    function emitAuxiliaryEvent(bytes32 eventKey, bytes calldata eventData) external;

    /*******************************************************************************
                                Authentication
    *******************************************************************************/

    /**
     * @notice Returns the Authorizer address.
     * @dev The authorizer holds the permissions granted by governance. It is set on Vault deployment,
     * and can be changed through a permissioned call.
     *
     * @return authorizer Address of the authorizer contract
     */
    function getAuthorizer() external view returns (IAuthorizer authorizer);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./VaultTypes.sol";

/**
 * @notice Interface for functions defined on the main Vault contract.
 * @dev These are generally "critical path" functions (swap, add/remove liquidity) that are in the main contract
 * for technical or performance reasons.
 */
interface IVaultMain {
    /*******************************************************************************
                              Transient Accounting
    *******************************************************************************/

    /**
     * @notice Creates a context for a sequence of operations (i.e., "unlocks" the Vault).
     * @dev Performs a callback on msg.sender with arguments provided in `data`. The Callback is `transient`,
     * meaning all balances for the caller have to be settled at the end.
     *
     * @param data Contains function signature and args to be passed to the msg.sender
     * @return result Resulting data from the call
     */
    function unlock(bytes calldata data) external returns (bytes memory result);

    /**
     * @notice Settles deltas for a token; must be successful for the current lock to be released.
     * @dev Protects the caller against leftover dust in the Vault for the token being settled. The caller
     * should know in advance how many tokens were paid to the Vault, so it can provide it as a hint to discard any
     * excess in the Vault balance.
     *
     * If the given hint is equal to or higher than the difference in reserves, the difference in reserves is given as
     * credit to the caller. If it's higher, the caller sent fewer tokens than expected, so settlement would fail.
     *
     * If the given hint is lower than the difference in reserves, the hint is given as credit to the caller.
     * In this case, the excess would be absorbed by the Vault (and reflected correctly in the reserves), but would
     * not affect settlement.
     *
     * The credit supplied by the Vault can be calculated as `min(reserveDifference, amountHint)`, where the reserve
     * difference equals current balance of the token minus existing reserves of the token when the function is called.
     *
     * @param token Address of the token
     * @param amountHint Amount paid as reported by the caller
     * @return credit Credit received in return of the payment
     */
    function settle(IERC20 token, uint256 amountHint) external returns (uint256 credit);

    /**
     * @notice Sends tokens to a recipient.
     * @dev There is no inverse operation for this function. Transfer funds to the Vault and call `settle` to cancel
     * debts.
     *
     * @param token Address of the token
     * @param to Recipient address
     * @param amount Amount of tokens to send
     */
    function sendTo(IERC20 token, address to, uint256 amount) external;

    /***************************************************************************
                                       Swaps
    ***************************************************************************/

    /**
     * @notice Swaps tokens based on provided parameters.
     * @dev All parameters are given in raw token decimal encoding.
     * @param vaultSwapParams Parameters for the swap (see above for struct definition)
     * @return amountCalculatedRaw Calculated swap amount
     * @return amountInRaw Amount of input tokens for the swap
     * @return amountOutRaw Amount of output tokens from the swap
     */
    function swap(
        VaultSwapParams memory vaultSwapParams
    ) external returns (uint256 amountCalculatedRaw, uint256 amountInRaw, uint256 amountOutRaw);

    /***************************************************************************
                                   Add Liquidity
    ***************************************************************************/

    /**
     * @notice Adds liquidity to a pool.
     * @dev Caution should be exercised when adding liquidity because the Vault has the capability
     * to transfer tokens from any user, given that it holds all allowances.
     *
     * @param params Parameters for the add liquidity (see above for struct definition)
     * @return amountsIn Actual amounts of input tokens
     * @return bptAmountOut Output pool token amount
     * @return returnData Arbitrary (optional) data with an encoded response from the pool
     */
    function addLiquidity(
        AddLiquidityParams memory params
    ) external returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData);

    /***************************************************************************
                                 Remove Liquidity
    ***************************************************************************/

    /**
     * @notice Removes liquidity from a pool.
     * @dev Trusted routers can burn pool tokens belonging to any user and require no prior approval from the user.
     * Untrusted routers require prior approval from the user. This is the only function allowed to call
     * _queryModeBalanceIncrease (and only in a query context).
     *
     * @param params Parameters for the remove liquidity (see above for struct definition)
     * @return bptAmountIn Actual amount of BPT burned
     * @return amountsOut Actual amounts of output tokens
     * @return returnData Arbitrary (optional) data with an encoded response from the pool
     */
    function removeLiquidity(
        RemoveLiquidityParams memory params
    ) external returns (uint256 bptAmountIn, uint256[] memory amountsOut, bytes memory returnData);

    /*******************************************************************************
                                    Pool Information
    *******************************************************************************/

    /**
     * @notice Gets the index of a token in a given pool.
     * @dev Reverts if the pool is not registered, or if the token does not belong to the pool.
     * @param pool Address of the pool
     * @param token Address of the token
     * @return tokenCount Number of tokens in the pool
     * @return index Index corresponding to the given token in the pool's token list
     */
    function getPoolTokenCountAndIndexOfToken(
        address pool,
        IERC20 token
    ) external view returns (uint256 tokenCount, uint256 index);

    /*******************************************************************************
                                 Balancer Pool Tokens
    *******************************************************************************/

    /**
     * @notice Transfers pool token from owner to a recipient.
     * @dev Notice that the pool token address is not included in the params. This function is exclusively called by
     * the pool contract, so msg.sender is used as the token address.
     *
     * @param owner Address of the owner
     * @param to Address of the recipient
     * @param amount Amount of tokens to transfer
     * @return success True if successful, false otherwise
     */
    function transfer(address owner, address to, uint256 amount) external returns (bool);

    /**
     * @notice Transfers pool token from a sender to a recipient using an allowance.
     * @dev Notice that the pool token address is not included in the params. This function is exclusively called by
     * the pool contract, so msg.sender is used as the token address.
     *
     * @param spender Address allowed to perform the transfer
     * @param from Address of the sender
     * @param to Address of the recipient
     * @param amount Amount of tokens to transfer
     * @return success True if successful, false otherwise
     */
    function transferFrom(address spender, address from, address to, uint256 amount) external returns (bool success);

    /*******************************************************************************
                                  ERC4626 Buffers
    *******************************************************************************/

    /**
     * @notice Wraps/unwraps tokens based on the parameters provided.
     * @dev All parameters are given in raw token decimal encoding. It requires the buffer to be initialized,
     * and uses the internal wrapped token buffer when it has enough liquidity to avoid external calls.
     *
     * @param params Parameters for the wrap/unwrap operation (see struct definition)
     * @return amountCalculatedRaw Calculated swap amount
     * @return amountInRaw Amount of input tokens for the swap
     * @return amountOutRaw Amount of output tokens from the swap
     */
    function erc4626BufferWrapOrUnwrap(
        BufferWrapOrUnwrapParams memory params
    ) external returns (uint256 amountCalculatedRaw, uint256 amountInRaw, uint256 amountOutRaw);

    /*******************************************************************************
                                     Miscellaneous
    *******************************************************************************/

    /**
     * @notice Returns the VaultExtension contract address.
     * @dev Function is in the main Vault contract. The VaultExtension handles less critical or frequently used
     * functions, since delegate calls through the Vault are more expensive than direct calls.
     *
     * @return vaultExtension Address of the VaultExtension
     */
    function getVaultExtension() external view returns (address vaultExtension);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { IRateProvider } from "../solidity-utils/helpers/IRateProvider.sol";

/**
 * @notice Represents a pool's liquidity management configuration.
 * @param disableUnbalancedLiquidity If set, liquidity can only be added or removed proportionally
 * @param enableAddLiquidityCustom If set, the pool has implemented `onAddLiquidityCustom`
 * @param enableRemoveLiquidityCustom If set, the pool has implemented `onRemoveLiquidityCustom`
 * @param enableDonation If set, the pool will not revert if liquidity is added with AddLiquidityKind.DONATION
 */
struct LiquidityManagement {
    bool disableUnbalancedLiquidity;
    bool enableAddLiquidityCustom;
    bool enableRemoveLiquidityCustom;
    bool enableDonation;
}

// @notice Custom type to store the entire configuration of the pool.
type PoolConfigBits is bytes32;

/**
 * @notice Represents a pool's configuration (hooks configuration are separated in another struct).
 * @param liquidityManagement Flags related to adding/removing liquidity
 * @param staticSwapFeePercentage The pool's native swap fee
 * @param aggregateSwapFeePercentage The total swap fee charged, including protocol and pool creator components
 * @param aggregateYieldFeePercentage The total swap fee charged, including protocol and pool creator components
 * @param tokenDecimalDiffs Compressed storage of the token decimals of each pool token
 * @param pauseWindowEndTime Timestamp after which the pool cannot be paused
 * @param isPoolRegistered If true, the pool has been registered with the Vault
 * @param isPoolInitialized If true, the pool has been initialized with liquidity, and is available for trading
 * @param isPoolPaused If true, the pool has been paused (by governance or the pauseManager)
 * @param isPoolInRecoveryMode If true, the pool has been placed in recovery mode, enabling recovery mode withdrawals
 */
struct PoolConfig {
    LiquidityManagement liquidityManagement;
    uint256 staticSwapFeePercentage;
    uint256 aggregateSwapFeePercentage;
    uint256 aggregateYieldFeePercentage;
    uint40 tokenDecimalDiffs;
    uint32 pauseWindowEndTime;
    bool isPoolRegistered;
    bool isPoolInitialized;
    bool isPoolPaused;
    bool isPoolInRecoveryMode;
}

/**
 * @notice The flag portion of the `HooksConfig`.
 * @dev `enableHookAdjustedAmounts` must be true for all contracts that modify the `amountCalculated`
 * in after hooks. Otherwise, the Vault will ignore any "hookAdjusted" amounts. Setting any "shouldCall"
 * flags to true will cause the Vault to call the corresponding hook during operations.
 */
struct HookFlags {
    bool enableHookAdjustedAmounts;
    bool shouldCallBeforeInitialize;
    bool shouldCallAfterInitialize;
    bool shouldCallComputeDynamicSwapFee;
    bool shouldCallBeforeSwap;
    bool shouldCallAfterSwap;
    bool shouldCallBeforeAddLiquidity;
    bool shouldCallAfterAddLiquidity;
    bool shouldCallBeforeRemoveLiquidity;
    bool shouldCallAfterRemoveLiquidity;
}

/// @notice Represents a hook contract configuration for a pool (HookFlags + hooksContract address).
struct HooksConfig {
    bool enableHookAdjustedAmounts;
    bool shouldCallBeforeInitialize;
    bool shouldCallAfterInitialize;
    bool shouldCallComputeDynamicSwapFee;
    bool shouldCallBeforeSwap;
    bool shouldCallAfterSwap;
    bool shouldCallBeforeAddLiquidity;
    bool shouldCallAfterAddLiquidity;
    bool shouldCallBeforeRemoveLiquidity;
    bool shouldCallAfterRemoveLiquidity;
    address hooksContract;
}

/**
 * @notice Represents temporary state used during a swap operation.
 * @param indexIn The zero-based index of tokenIn
 * @param indexOut The zero-based index of tokenOut
 * @param amountGivenScaled18 The amountGiven (i.e., tokenIn for ExactIn), adjusted for token decimals
 * @param swapFeePercentage The swap fee to be applied (might be static or dynamic)
 */
struct SwapState {
    uint256 indexIn;
    uint256 indexOut;
    uint256 amountGivenScaled18;
    uint256 swapFeePercentage;
}

/**
 * @notice Represents the Vault's configuration.
 * @param isQueryDisabled If set to true, disables query functionality of the Vault. Can be modified by governance
 * @param isVaultPaused If set to true, swaps and add/remove liquidity operations are halted
 * @param areBuffersPaused If set to true, the Vault wrap/unwrap primitives associated with buffers will be disabled
 */
struct VaultState {
    bool isQueryDisabled;
    bool isVaultPaused;
    bool areBuffersPaused;
}

/**
 * @notice Represents the accounts holding certain roles for a given pool. This is passed in on pool registration.
 * @param pauseManager Account empowered to pause/unpause the pool (note that governance can always pause a pool)
 * @param swapFeeManager Account empowered to set static swap fees for a pool (or 0 to delegate to governance)
 * @param poolCreator Account empowered to set the pool creator fee (or 0 if all fees go to the protocol and LPs)
 */
struct PoolRoleAccounts {
    address pauseManager;
    address swapFeeManager;
    address poolCreator;
}

/*******************************************************************************
                                   Tokens
*******************************************************************************/

// Note that the following tokens are unsupported by the Vault. This list is not meant to be exhaustive, but covers
// many common types of tokens that will not work with the Vault architecture. (See https://github.com/d-xo/weird-erc20
// for examples of token features that are problematic for many protocols.)
//
// * Rebasing tokens (e.g., aDAI). The Vault keeps track of token balances in its internal accounting; any token whose
//   balance changes asynchronously (i.e., outside a swap or liquidity operation), would get out-of-sync with this
//   internal accounting. This category would also include "airdrop" tokens, whose balances can change unexpectedly.
//
// * Double entrypoint (e.g., old Synthetix tokens, now fixed). These could likewise bypass internal accounting by
//   registering the token under one address, then accessing it through another. This is especially troublesome
//   in v3, with the introduction of ERC4626 buffers.
//
// * Fee on transfer (e.g., PAXG). The Vault issues credits and debits according to given and calculated token amounts,
//   and settlement assumes that the send/receive transfer functions transfer exactly the given number of tokens.
//   If this is not the case, transactions will not settle. Unlike with the other types, which are fundamentally
//   incompatible, it would be possible to design a Router to handle this - but we didn't try it. In any case, it's
//   not supported in the current Routers.
//
// * Tokens with more than 18 decimals (e.g., YAM-V2). The Vault handles token scaling: i.e., handling I/O for
//   amounts in native token decimals, but doing calculations with full 18-decimal precision. This requires reading
//   and storing the decimals for each token. Since virtually all tokens are 18 or fewer decimals, and we have limited
//   storage space, 18 was a reasonable maximum. Unlike the other types, this is enforceable by the Vault. Attempting
//   to register such tokens will revert with `InvalidTokenDecimals`. Of course, we must also be able to read the token
//   decimals, so the Vault only supports tokens that implement `IERC20Metadata.decimals`, and return a value less than
//   or equal to 18.
//
//  * Token decimals are checked and stored only once, on registration. Valid tokens store their decimals as immutable
//    variables or constants. Malicious tokens that don't respect this basic property would not work anywhere in DeFi.
//
// These types of tokens are supported but discouraged, as they don't tend to play well with AMMs generally.
//
// * Very low-decimal tokens (e.g., GUSD). The Vault has been extensively tested with 6-decimal tokens (e.g., USDC),
//   but going much below that may lead to unanticipated effects due to precision loss, especially with smaller trade
//   values.
//
// * Revert on zero value approval/transfer. The Vault has been tested against these, but peripheral contracts, such
//   as hooks, might not have been designed with this in mind.
//
// * Other types from "weird-erc20," such as upgradeable, pausable, or tokens with blocklists. We have seen cases
//   where a token upgrade fails, "bricking" the token - and many operations on pools containing that token. Any
//   sort of "permissioned" token that can make transfers fail can cause operations on pools containing them to
//   revert. Even Recovery Mode cannot help then, as it does a proportional withdrawal of all tokens. If one of
//   them is bricked, the whole operation will revert. Since v3 does not have "internal balances" like v2, there
//   is no recourse.
//
//   Of course, many tokens in common use have some of these "features" (especially centralized stable coins), so
//   we have to support them anyway. Working with common centralized tokens is a risk common to all of DeFi.

/**
 * @notice Token types supported by the Vault.
 * @dev In general, pools may contain any combination of these tokens.
 *
 * STANDARD tokens (e.g., BAL, WETH) have no rate provider.
 * WITH_RATE tokens (e.g., wstETH) require a rate provider. These may be tokens like wstETH, which need to be wrapped
 * because the underlying stETH token is rebasing, and such tokens are unsupported by the Vault. They may also be
 * tokens like sEUR, which track an underlying asset, but are not yield-bearing. Finally, this encompasses
 * yield-bearing ERC4626 tokens, which can be used to facilitate swaps without requiring wrapping or unwrapping
 * in most cases. The `paysYieldFees` flag can be used to indicate whether a token is yield-bearing (e.g., waDAI),
 * not yield-bearing (e.g., sEUR), or yield-bearing but exempt from fees (e.g., in certain nested pools, where
 * yield fees are charged elsewhere).
 *
 * NB: STANDARD must always be the first enum element, so that newly initialized data structures default to Standard.
 */
enum TokenType {
    STANDARD,
    WITH_RATE
}

/**
 * @notice Encapsulate the data required for the Vault to support a token of the given type.
 * @dev For STANDARD tokens, the rate provider address must be 0, and paysYieldFees must be false. All WITH_RATE tokens
 * need a rate provider, and may or may not be yield-bearing.
 *
 * At registration time, it is useful to include the token address along with the token parameters in the structure
 * passed to `registerPool`, as the alternative would be parallel arrays, which would be error prone and require
 * validation checks. `TokenConfig` is only used for registration, and is never put into storage (see `TokenInfo`).
 *
 * @param token The token address
 * @param tokenType The token type (see the enum for supported types)
 * @param rateProvider The rate provider for a token (see further documentation above)
 * @param paysYieldFees Flag indicating whether yield fees should be charged on this token
 */
struct TokenConfig {
    IERC20 token;
    TokenType tokenType;
    IRateProvider rateProvider;
    bool paysYieldFees;
}

/**
 * @notice This data structure is stored in `_poolTokenInfo`, a nested mapping from pool -> (token -> TokenInfo).
 * @dev Since the token is already the key of the nested mapping, it would be redundant (and an extra SLOAD) to store
 * it again in the struct. When we construct PoolData, the tokens are separated into their own array.
 *
 * @param tokenType The token type (see the enum for supported types)
 * @param rateProvider The rate provider for a token (see further documentation above)
 * @param paysYieldFees Flag indicating whether yield fees should be charged on this token
 */
struct TokenInfo {
    TokenType tokenType;
    IRateProvider rateProvider;
    bool paysYieldFees;
}

/**
 * @notice Data structure used to represent the current pool state in memory
 * @param poolConfigBits Custom type to store the entire configuration of the pool.
 * @param tokens Pool tokens, sorted in token registration order
 * @param tokenInfo Configuration data for each token, sorted in token registration order
 * @param balancesRaw Token balances in native decimals
 * @param balancesLiveScaled18 Token balances after paying yield fees, applying decimal scaling and rates
 * @param tokenRates 18-decimal FP values for rate tokens (e.g., yield-bearing), or FP(1) for standard tokens
 * @param decimalScalingFactors Conversion factor used to adjust for token decimals for uniform precision in
 * calculations. It is 1e18 (FP 1) for 18-decimal tokens
 */
struct PoolData {
    PoolConfigBits poolConfigBits;
    IERC20[] tokens;
    TokenInfo[] tokenInfo;
    uint256[] balancesRaw;
    uint256[] balancesLiveScaled18;
    uint256[] tokenRates;
    uint256[] decimalScalingFactors;
}

enum Rounding {
    ROUND_UP,
    ROUND_DOWN
}

/*******************************************************************************
                                    Swaps
*******************************************************************************/

enum SwapKind {
    EXACT_IN,
    EXACT_OUT
}

// There are two "SwapParams" structs defined below. `VaultSwapParams` corresponds to the external swap API defined
// in the Router contracts, which uses explicit token addresses, the amount given and limit on the calculated amount
// expressed in native token decimals, and optional user data passed in from the caller.
//
// `PoolSwapParams` passes some of this information through (kind, userData), but "translates" the parameters to fit
// the internal swap API used by `IBasePool`. It scales amounts to full 18-decimal precision, adds the token balances,
// converts the raw token addresses to indices, and adds the address of the Router originating the request. It does
// not need the limit, since this is checked at the Router level.

/**
 * @notice Data passed into primary Vault `swap` operations.
 * @param kind Type of swap (Exact In or Exact Out)
 * @param pool The pool with the tokens being swapped
 * @param tokenIn The token entering the Vault (balance increases)
 * @param tokenOut The token leaving the Vault (balance decreases)
 * @param amountGivenRaw Amount specified for tokenIn or tokenOut (depending on the type of swap)
 * @param limitRaw Minimum or maximum value of the calculated amount (depending on the type of swap)
 * @param userData Additional (optional) user data
 */
struct VaultSwapParams {
    SwapKind kind;
    address pool;
    IERC20 tokenIn;
    IERC20 tokenOut;
    uint256 amountGivenRaw;
    uint256 limitRaw;
    bytes userData;
}

/**
 * @notice Data for a swap operation, used by contracts implementing `IBasePool`.
 * @param kind Type of swap (exact in or exact out)
 * @param amountGivenScaled18 Amount given based on kind of the swap (e.g., tokenIn for EXACT_IN)
 * @param balancesScaled18 Current pool balances
 * @param indexIn Index of tokenIn
 * @param indexOut Index of tokenOut
 * @param router The address (usually a router contract) that initiated a swap operation on the Vault
 * @param userData Additional (optional) data required for the swap
 */
struct PoolSwapParams {
    SwapKind kind;
    uint256 amountGivenScaled18;
    uint256[] balancesScaled18;
    uint256 indexIn;
    uint256 indexOut;
    address router;
    bytes userData;
}

/**
 * @notice Data for the hook after a swap operation.
 * @param kind Type of swap (exact in or exact out)
 * @param tokenIn Token to be swapped from
 * @param tokenOut Token to be swapped to
 * @param amountInScaled18 Amount of tokenIn (entering the Vault)
 * @param amountOutScaled18 Amount of tokenOut (leaving the Vault)
 * @param tokenInBalanceScaled18 Updated (after swap) balance of tokenIn
 * @param tokenOutBalanceScaled18 Updated (after swap) balance of tokenOut
 * @param amountCalculatedScaled18 Token amount calculated by the swap
 * @param amountCalculatedRaw Token amount calculated by the swap
 * @param router The address (usually a router contract) that initiated a swap operation on the Vault
 * @param pool Pool address
 * @param userData Additional (optional) data required for the swap
 */
struct AfterSwapParams {
    SwapKind kind;
    IERC20 tokenIn;
    IERC20 tokenOut;
    uint256 amountInScaled18;
    uint256 amountOutScaled18;
    uint256 tokenInBalanceScaled18;
    uint256 tokenOutBalanceScaled18;
    uint256 amountCalculatedScaled18;
    uint256 amountCalculatedRaw;
    address router;
    address pool;
    bytes userData;
}

/*******************************************************************************
                                Add liquidity
*******************************************************************************/

enum AddLiquidityKind {
    PROPORTIONAL,
    UNBALANCED,
    SINGLE_TOKEN_EXACT_OUT,
    DONATION,
    CUSTOM
}

/**
 * @notice Data for an add liquidity operation.
 * @param pool Address of the pool
 * @param to Address of user to mint to
 * @param maxAmountsIn Maximum amounts of input tokens
 * @param minBptAmountOut Minimum amount of output pool tokens
 * @param kind Add liquidity kind
 * @param userData Optional user data
 */
struct AddLiquidityParams {
    address pool;
    address to;
    uint256[] maxAmountsIn;
    uint256 minBptAmountOut;
    AddLiquidityKind kind;
    bytes userData;
}

/*******************************************************************************
                                Remove liquidity
*******************************************************************************/

enum RemoveLiquidityKind {
    PROPORTIONAL,
    SINGLE_TOKEN_EXACT_IN,
    SINGLE_TOKEN_EXACT_OUT,
    CUSTOM
}

/**
 * @notice Data for an remove liquidity operation.
 * @param pool Address of the pool
 * @param from Address of user to burn from
 * @param maxBptAmountIn Maximum amount of input pool tokens
 * @param minAmountsOut Minimum amounts of output tokens
 * @param kind Remove liquidity kind
 * @param userData Optional user data
 */
struct RemoveLiquidityParams {
    address pool;
    address from;
    uint256 maxBptAmountIn;
    uint256[] minAmountsOut;
    RemoveLiquidityKind kind;
    bytes userData;
}

/*******************************************************************************
                                Remove liquidity
*******************************************************************************/

enum WrappingDirection {
    WRAP,
    UNWRAP
}

/**
 * @notice Data for a wrap/unwrap operation.
 * @param kind Type of swap (Exact In or Exact Out)
 * @param direction Direction of the wrapping operation (Wrap or Unwrap)
 * @param wrappedToken Wrapped token, compatible with interface ERC4626
 * @param amountGivenRaw Amount specified for tokenIn or tokenOut (depends on the type of swap and wrapping direction)
 * @param limitRaw Minimum or maximum amount specified for the other token (depends on the type of swap and wrapping
 * direction)
 */
struct BufferWrapOrUnwrapParams {
    SwapKind kind;
    WrappingDirection direction;
    IERC4626 wrappedToken;
    uint256 amountGivenRaw;
    uint256 limitRaw;
}

// Protocol Fees are 24-bit values. We transform them by multiplying by 1e11, so that they can be set to any value
// between 0% and 100% (step 0.00001%). Protocol and pool creator fees are set in the `ProtocolFeeController`, and
// ensure both constituent and aggregate fees do not exceed this precision.
uint256 constant FEE_BITLENGTH = 24;
uint256 constant FEE_SCALING_FACTOR = 1e11;
// Used to ensure the safety of fee-related math (e.g., pools or hooks don't set it greater than 100%).
// This value should work for practical purposes and is well within the max precision requirements.
uint256 constant MAX_FEE_PERCENTAGE = 99.9999e16; // 99.9999%

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IAuthentication } from "@balancer-labs/v3-interfaces/contracts/solidity-utils/helpers/IAuthentication.sol";

/**
 * @notice Building block for performing access control on external functions.
 * @dev This contract is used via the `authenticate` modifier (or the `_authenticateCaller` function), which can be
 * applied to external functions to make them only callable by authorized accounts.
 *
 * Derived contracts must implement the `_canPerform` function, which holds the actual access control logic.
 */
abstract contract Authentication is IAuthentication {
    bytes32 private immutable _actionIdDisambiguator;

    /**
     * @dev The main purpose of the `actionIdDisambiguator` is to prevent accidental function selector collisions in
     * multi-contract systems.
     *
     * There are two main uses for it:
     *  - if the contract is a singleton, any unique identifier can be used to make the associated action identifiers
     *    unique. The contract's own address is a good option.
     *  - if the contract belongs to a family that shares action identifiers for the same functions, an identifier
     *    shared by the entire family (and no other contract) should be used instead.
     */
    constructor(bytes32 actionIdDisambiguator) {
        _actionIdDisambiguator = actionIdDisambiguator;
    }

    /// @dev Reverts unless the caller is allowed to call this function. Should only be applied to external functions.
    modifier authenticate() {
        _authenticateCaller();
        _;
    }

    /// @dev Reverts unless the caller is allowed to call the entry point function.
    function _authenticateCaller() internal view {
        bytes32 actionId = getActionId(msg.sig);

        if (!_canPerform(actionId, msg.sender)) {
            revert SenderNotAllowed();
        }
    }

    /// @inheritdoc IAuthentication
    function getActionId(bytes4 selector) public view override returns (bytes32) {
        // Each external function is dynamically assigned an action identifier as the hash of the disambiguator and the
        // function selector. Disambiguation is necessary to avoid potential collisions in the function selectors of
        // multiple contracts.
        return keccak256(abi.encodePacked(_actionIdDisambiguator, selector));
    }

    /**
     * @dev Derived contracts must implement this function to perform the actual access control logic.
     * @param actionId The action identifier associated with an external function
     * @param user The account performing the action
     * @return success True if the action is permitted
     */
    function _canPerform(bytes32 actionId, address user) internal view virtual returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { LogExpMath } from "./LogExpMath.sol";

/// @notice Support 18-decimal fixed point arithmetic. All Vault calculations use this for high and uniform precision.
library FixedPoint {
    /// @notice Attempted division by zero.
    error ZeroDivision();

    // solhint-disable no-inline-assembly
    // solhint-disable private-vars-leading-underscore

    uint256 internal constant ONE = 1e18; // 18 decimal places
    uint256 internal constant TWO = 2 * ONE;
    uint256 internal constant FOUR = 4 * ONE;
    uint256 internal constant MAX_POW_RELATIVE_ERROR = 10000; // 10^(-14)

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        // Multiplication overflow protection is provided by Solidity 0.8.x.
        uint256 product = a * b;

        return product / ONE;
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
        // Multiplication overflow protection is provided by Solidity 0.8.x.
        uint256 product = a * b;

        // Equivalent to:
        // result = product == 0 ? 0 : ((product - 1) / FixedPoint.ONE) + 1
        assembly ("memory-safe") {
            result := mul(iszero(iszero(product)), add(div(sub(product, 1), ONE), 1))
        }
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity 0.8 reverts with a Panic code (0x11) if the multiplication overflows.
        uint256 aInflated = a * ONE;

        // Solidity 0.8 reverts with a "Division by Zero" Panic code (0x12) if b is zero
        return aInflated / b;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
        return mulDivUp(a, ONE, b);
    }

    /// @dev Return (a * b) / c, rounding up.
    function mulDivUp(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 result) {
        // This check is required because Yul's `div` doesn't revert on c==0.
        if (c == 0) {
            revert ZeroDivision();
        }

        // Multiple overflow protection is done by Solidity 0.8.x.
        uint256 product = a * b;

        // The traditional divUp formula is:
        // divUp(x, y) := (x + y - 1) / y
        // To avoid intermediate overflow in the addition, we distribute the division and get:
        // divUp(x, y) := (x - 1) / y + 1
        // Note that this requires x != 0, if x == 0 then the result is zero
        //
        // Equivalent to:
        // result = a == 0 ? 0 : (a * b - 1) / c + 1
        assembly ("memory-safe") {
            result := mul(iszero(iszero(product)), add(div(sub(product, 1), c), 1))
        }
    }

    /**
     * @dev Version of divUp when the input is raw (i.e., already "inflated"). For instance,
     * invariant * invariant (36 decimals) vs. invariant.mulDown(invariant) (18 decimal FP).
     * This can occur in calculations with many successive multiplications and divisions, and
     * we want to minimize the number of operations by avoiding unnecessary scaling by ONE.
     */
    function divUpRaw(uint256 a, uint256 b) internal pure returns (uint256 result) {
        // This check is required because Yul's `div` doesn't revert on b==0.
        if (b == 0) {
            revert ZeroDivision();
        }

        // Equivalent to:
        // result = a == 0 ? 0 : 1 + (a - 1) / b
        assembly ("memory-safe") {
            result := mul(iszero(iszero(a)), add(1, div(sub(a, 1), b)))
        }
    }

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding down. The result is guaranteed to not be above
     * the true value (that is, the error function expected - actual is always positive).
     */
    function powDown(uint256 x, uint256 y) internal pure returns (uint256) {
        // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
        // and 80/20 Weighted Pools
        if (y == ONE) {
            return x;
        } else if (y == TWO) {
            return mulDown(x, x);
        } else if (y == FOUR) {
            uint256 square = mulDown(x, x);
            return mulDown(square, square);
        } else {
            uint256 raw = LogExpMath.pow(x, y);
            uint256 maxError = mulUp(raw, MAX_POW_RELATIVE_ERROR) + 1;

            if (raw < maxError) {
                return 0;
            } else {
                unchecked {
                    return raw - maxError;
                }
            }
        }
    }

    /**
     * @dev Returns x^y, assuming both are fixed point numbers, rounding up. The result is guaranteed to not be below
     * the true value (that is, the error function expected - actual is always negative).
     */
    function powUp(uint256 x, uint256 y) internal pure returns (uint256) {
        // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
        // and 80/20 Weighted Pools
        if (y == ONE) {
            return x;
        } else if (y == TWO) {
            return mulUp(x, x);
        } else if (y == FOUR) {
            uint256 square = mulUp(x, x);
            return mulUp(square, square);
        } else {
            uint256 raw = LogExpMath.pow(x, y);
            uint256 maxError = mulUp(raw, MAX_POW_RELATIVE_ERROR) + 1;

            return raw + maxError;
        }
    }

    /**
     * @dev Returns the complement of a value (1 - x), capped to 0 if x is larger than 1.
     *
     * Useful when computing the complement for values with some level of relative error, as it strips this error and
     * prevents intermediate negative values.
     */
    function complement(uint256 x) internal pure returns (uint256 result) {
        // Equivalent to:
        // result = (x < ONE) ? (ONE - x) : 0
        assembly ("memory-safe") {
            result := mul(lt(x, ONE), sub(ONE, x))
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

// solhint-disable

/**
 * @dev Exponentiation and logarithm functions for 18 decimal fixed point numbers (both base and exponent/argument).
 *
 * Exponentiation and logarithm with arbitrary bases (x^y and log_x(y)) are implemented by conversion to natural
 * exponentiation and logarithm (where the base is Euler's number).
 *
 * All math operations are unchecked in order to save gas.
 *
 * @author Fernando Martinelli - @fernandomartinelli
 * @author Sergio Yuhjtman     - @sergioyuhjtman
 * @author Daniel Fernandez    - @dmf7z
 */
library LogExpMath {
    /// @notice This error is thrown when a base is not within an acceptable range.
    error BaseOutOfBounds();

    /// @notice This error is thrown when a exponent is not within an acceptable range.
    error ExponentOutOfBounds();

    /// @notice This error is thrown when the exponent * ln(base) is not within an acceptable range.
    error ProductOutOfBounds();

    /// @notice This error is thrown when an exponent used in the exp function is not within an acceptable range.
    error InvalidExponent();

    /// @notice This error is thrown when a variable or result is not within the acceptable bounds defined in the function.
    error OutOfBounds();

    // All fixed point multiplications and divisions are inlined. This means we need to divide by ONE when multiplying
    // two numbers, and multiply by ONE when dividing them.

    // All arguments and return values are 18 decimal fixed point numbers.
    int256 constant ONE_18 = 1e18;

    // Internally, intermediate values are computed with higher precision as 20 decimal fixed point numbers, and in the
    // case of ln36, 36 decimals.
    int256 constant ONE_20 = 1e20;
    int256 constant ONE_36 = 1e36;

    // The domain of natural exponentiation is bound by the word size and number of decimals used.
    //
    // Because internally the result will be stored using 20 decimals, the largest possible result is
    // (2^255 - 1) / 10^20, which makes the largest exponent ln((2^255 - 1) / 10^20) = 130.700829182905140221.
    // The smallest possible result is 10^(-18), which makes largest negative argument
    // ln(10^(-18)) = -41.446531673892822312.
    // We use 130.0 and -41.0 to have some safety margin.
    int256 constant MAX_NATURAL_EXPONENT = 130e18;
    int256 constant MIN_NATURAL_EXPONENT = -41e18;

    // Bounds for ln_36's argument. Both ln(0.9) and ln(1.1) can be represented with 36 decimal places in a fixed point
    // 256 bit integer.
    int256 constant LN_36_LOWER_BOUND = ONE_18 - 1e17;
    int256 constant LN_36_UPPER_BOUND = ONE_18 + 1e17;

    uint256 constant MILD_EXPONENT_BOUND = 2 ** 254 / uint256(ONE_20);

    // 18 decimal constants
    int256 constant x0 = 128000000000000000000; // 2ˆ7
    int256 constant a0 = 38877084059945950922200000000000000000000000000000000000; // eˆ(x0) (no decimals)
    int256 constant x1 = 64000000000000000000; // 2ˆ6
    int256 constant a1 = 6235149080811616882910000000; // eˆ(x1) (no decimals)

    // 20 decimal constants
    int256 constant x2 = 3200000000000000000000; // 2ˆ5
    int256 constant a2 = 7896296018268069516100000000000000; // eˆ(x2)
    int256 constant x3 = 1600000000000000000000; // 2ˆ4
    int256 constant a3 = 888611052050787263676000000; // eˆ(x3)
    int256 constant x4 = 800000000000000000000; // 2ˆ3
    int256 constant a4 = 298095798704172827474000; // eˆ(x4)
    int256 constant x5 = 400000000000000000000; // 2ˆ2
    int256 constant a5 = 5459815003314423907810; // eˆ(x5)
    int256 constant x6 = 200000000000000000000; // 2ˆ1
    int256 constant a6 = 738905609893065022723; // eˆ(x6)
    int256 constant x7 = 100000000000000000000; // 2ˆ0
    int256 constant a7 = 271828182845904523536; // eˆ(x7)
    int256 constant x8 = 50000000000000000000; // 2ˆ-1
    int256 constant a8 = 164872127070012814685; // eˆ(x8)
    int256 constant x9 = 25000000000000000000; // 2ˆ-2
    int256 constant a9 = 128402541668774148407; // eˆ(x9)
    int256 constant x10 = 12500000000000000000; // 2ˆ-3
    int256 constant a10 = 113314845306682631683; // eˆ(x10)
    int256 constant x11 = 6250000000000000000; // 2ˆ-4
    int256 constant a11 = 106449445891785942956; // eˆ(x11)

    /**
     * @dev Exponentiation (x^y) with unsigned 18 decimal fixed point base and exponent.
     *
     * Reverts if ln(x) * y is smaller than `MIN_NATURAL_EXPONENT`, or larger than `MAX_NATURAL_EXPONENT`.
     */
    function pow(uint256 x, uint256 y) internal pure returns (uint256) {
        if (y == 0) {
            // We solve the 0^0 indetermination by making it equal one.
            return uint256(ONE_18);
        }

        if (x == 0) {
            return 0;
        }

        // Instead of computing x^y directly, we instead rely on the properties of logarithms and exponentiation to
        // arrive at that result. In particular, exp(ln(x)) = x, and ln(x^y) = y * ln(x). This means
        // x^y = exp(y * ln(x)).

        // The ln function takes a signed value, so we need to make sure x fits in the signed 256 bit range.
        if (x >> 255 != 0) {
            revert BaseOutOfBounds();
        }
        int256 x_int256 = int256(x);

        // We will compute y * ln(x) in a single step. Depending on the value of x, we can either use ln or ln_36. In
        // both cases, we leave the division by ONE_18 (due to fixed point multiplication) to the end.

        // This prevents y * ln(x) from overflowing, and at the same time guarantees y fits in the signed 256 bit range.
        if (y >= MILD_EXPONENT_BOUND) {
            revert ExponentOutOfBounds();
        }
        int256 y_int256 = int256(y);

        int256 logx_times_y;
        unchecked {
            if (LN_36_LOWER_BOUND < x_int256 && x_int256 < LN_36_UPPER_BOUND) {
                int256 ln_36_x = _ln_36(x_int256);

                // ln_36_x has 36 decimal places, so multiplying by y_int256 isn't as straightforward, since we can't just
                // bring y_int256 to 36 decimal places, as it might overflow. Instead, we perform two 18 decimal
                // multiplications and add the results: one with the first 18 decimals of ln_36_x, and one with the
                // (downscaled) last 18 decimals.
                logx_times_y = ((ln_36_x / ONE_18) * y_int256 + ((ln_36_x % ONE_18) * y_int256) / ONE_18);
            } else {
                logx_times_y = _ln(x_int256) * y_int256;
            }
            logx_times_y /= ONE_18;
        }

        // Finally, we compute exp(y * ln(x)) to arrive at x^y
        if (!(MIN_NATURAL_EXPONENT <= logx_times_y && logx_times_y <= MAX_NATURAL_EXPONENT)) {
            revert ProductOutOfBounds();
        }

        return uint256(exp(logx_times_y));
    }

    /**
     * @dev Natural exponentiation (e^x) with signed 18 decimal fixed point exponent.
     *
     * Reverts if `x` is smaller than MIN_NATURAL_EXPONENT, or larger than `MAX_NATURAL_EXPONENT`.
     */
    function exp(int256 x) internal pure returns (int256) {
        if (!(x >= MIN_NATURAL_EXPONENT && x <= MAX_NATURAL_EXPONENT)) {
            revert InvalidExponent();
        }

        // We avoid using recursion here because zkSync doesn't support it.
        bool negativeExponent = false;

        if (x < 0) {
            // We only handle positive exponents: e^(-x) is computed as 1 / e^x. We can safely make x positive since it
            // fits in the signed 256 bit range (as it is larger than MIN_NATURAL_EXPONENT). In the negative
            // exponent case, compute e^x, then return 1 / result.
            unchecked {
                x = -x;
            }
            negativeExponent = true;
        }

        // First, we use the fact that e^(x+y) = e^x * e^y to decompose x into a sum of powers of two, which we call x_n,
        // where x_n == 2^(7 - n), and e^x_n = a_n has been precomputed. We choose the first x_n, x0, to equal 2^7
        // because all larger powers are larger than MAX_NATURAL_EXPONENT, and therefore not present in the
        // decomposition.
        // At the end of this process we will have the product of all e^x_n = a_n that apply, and the remainder of this
        // decomposition, which will be lower than the smallest x_n.
        // exp(x) = k_0 * a_0 * k_1 * a_1 * ... + k_n * a_n * exp(remainder), where each k_n equals either 0 or 1.
        // We mutate x by subtracting x_n, making it the remainder of the decomposition.

        // The first two a_n (e^(2^7) and e^(2^6)) are too large if stored as 18 decimal numbers, and could cause
        // intermediate overflows. Instead we store them as plain integers, with 0 decimals.
        // Additionally, x0 + x1 is larger than MAX_NATURAL_EXPONENT, which means they will not both be present in the
        // decomposition.

        // For each x_n, we test if that term is present in the decomposition (if x is larger than it), and if so deduct
        // it and compute the accumulated product.

        int256 firstAN;
        unchecked {
            if (x >= x0) {
                x -= x0;
                firstAN = a0;
            } else if (x >= x1) {
                x -= x1;
                firstAN = a1;
            } else {
                firstAN = 1; // One with no decimal places
            }

            // We now transform x into a 20 decimal fixed point number, to have enhanced precision when computing the
            // smaller terms.
            x *= 100;
        }

        // `product` is the accumulated product of all a_n (except a0 and a1), which starts at 20 decimal fixed point
        // one. Recall that fixed point multiplication requires dividing by ONE_20.
        int256 product = ONE_20;

        unchecked {
            if (x >= x2) {
                x -= x2;
                product = (product * a2) / ONE_20;
            }
            if (x >= x3) {
                x -= x3;
                product = (product * a3) / ONE_20;
            }
            if (x >= x4) {
                x -= x4;
                product = (product * a4) / ONE_20;
            }
            if (x >= x5) {
                x -= x5;
                product = (product * a5) / ONE_20;
            }
            if (x >= x6) {
                x -= x6;
                product = (product * a6) / ONE_20;
            }
            if (x >= x7) {
                x -= x7;
                product = (product * a7) / ONE_20;
            }
            if (x >= x8) {
                x -= x8;
                product = (product * a8) / ONE_20;
            }
            if (x >= x9) {
                x -= x9;
                product = (product * a9) / ONE_20;
            }
        }

        // x10 and x11 are unnecessary here since we have high enough precision already.

        // Now we need to compute e^x, where x is small (in particular, it is smaller than x9). We use the Taylor series
        // expansion for e^x: 1 + x + (x^2 / 2!) + (x^3 / 3!) + ... + (x^n / n!).

        int256 seriesSum = ONE_20; // The initial one in the sum, with 20 decimal places.
        int256 term; // Each term in the sum, where the nth term is (x^n / n!).

        // The first term is simply x.
        term = x;
        unchecked {
            seriesSum += term;

            // Each term (x^n / n!) equals the previous one times x, divided by n. Since x is a fixed point number,
            // multiplying by it requires dividing by ONE_20, but dividing by the non-fixed point n values does not.

            term = ((term * x) / ONE_20) / 2;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 3;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 4;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 5;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 6;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 7;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 8;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 9;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 10;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 11;
            seriesSum += term;

            term = ((term * x) / ONE_20) / 12;
            seriesSum += term;

            // 12 Taylor terms are sufficient for 18 decimal precision.

            // We now have the first a_n (with no decimals), and the product of all other a_n present, and the Taylor
            // approximation of the exponentiation of the remainder (both with 20 decimals). All that remains is to multiply
            // all three (one 20 decimal fixed point multiplication, dividing by ONE_20, and one integer multiplication),
            // and then drop two digits to return an 18 decimal value.

            int256 result = (((product * seriesSum) / ONE_20) * firstAN) / 100;

            // We avoid using recursion here because zkSync doesn't support it.
            return negativeExponent ? (ONE_18 * ONE_18) / result : result;
        }
    }

    /// @dev Logarithm (log(arg, base), with signed 18 decimal fixed point base and argument.
    function log(int256 arg, int256 base) internal pure returns (int256) {
        // This performs a simple base change: log(arg, base) = ln(arg) / ln(base).

        // Both logBase and logArg are computed as 36 decimal fixed point numbers, either by using ln_36, or by
        // upscaling.

        int256 logBase;
        unchecked {
            if (LN_36_LOWER_BOUND < base && base < LN_36_UPPER_BOUND) {
                logBase = _ln_36(base);
            } else {
                logBase = _ln(base) * ONE_18;
            }
        }

        int256 logArg;
        unchecked {
            if (LN_36_LOWER_BOUND < arg && arg < LN_36_UPPER_BOUND) {
                logArg = _ln_36(arg);
            } else {
                logArg = _ln(arg) * ONE_18;
            }

            // When dividing, we multiply by ONE_18 to arrive at a result with 18 decimal places
            return (logArg * ONE_18) / logBase;
        }
    }

    /// @dev Natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
    function ln(int256 a) internal pure returns (int256) {
        // The real natural logarithm is not defined for negative numbers or zero.
        if (a <= 0) {
            revert OutOfBounds();
        }
        if (LN_36_LOWER_BOUND < a && a < LN_36_UPPER_BOUND) {
            unchecked {
                return _ln_36(a) / ONE_18;
            }
        } else {
            return _ln(a);
        }
    }

    /// @dev Internal natural logarithm (ln(a)) with signed 18 decimal fixed point argument.
    function _ln(int256 a) private pure returns (int256) {
        // We avoid using recursion here because zkSync doesn't support it.
        bool negativeExponent = false;

        if (a < ONE_18) {
            // Since ln(a^k) = k * ln(a), we can compute ln(a) as ln(a) = ln((1/a)^(-1)) = - ln((1/a)). If a is less
            // than one, 1/a will be greater than one, so in this case we compute ln(1/a) and negate the final result.
            unchecked {
                a = (ONE_18 * ONE_18) / a;
            }
            negativeExponent = true;
        }

        // First, we use the fact that ln^(a * b) = ln(a) + ln(b) to decompose ln(a) into a sum of powers of two, which
        // we call x_n, where x_n == 2^(7 - n), which are the natural logarithm of precomputed quantities a_n (that is,
        // ln(a_n) = x_n). We choose the first x_n, x0, to equal 2^7 because the exponential of all larger powers cannot
        // be represented as 18 fixed point decimal numbers in 256 bits, and are therefore larger than a.
        // At the end of this process we will have the sum of all x_n = ln(a_n) that apply, and the remainder of this
        // decomposition, which will be lower than the smallest a_n.
        // ln(a) = k_0 * x_0 + k_1 * x_1 + ... + k_n * x_n + ln(remainder), where each k_n equals either 0 or 1.
        // We mutate a by subtracting a_n, making it the remainder of the decomposition.

        // For reasons related to how `exp` works, the first two a_n (e^(2^7) and e^(2^6)) are not stored as fixed point
        // numbers with 18 decimals, but instead as plain integers with 0 decimals, so we need to multiply them by
        // ONE_18 to convert them to fixed point.
        // For each a_n, we test if that term is present in the decomposition (if a is larger than it), and if so divide
        // by it and compute the accumulated sum.

        int256 sum = 0;
        unchecked {
            if (a >= a0 * ONE_18) {
                a /= a0; // Integer, not fixed point division
                sum += x0;
            }

            if (a >= a1 * ONE_18) {
                a /= a1; // Integer, not fixed point division
                sum += x1;
            }

            // All other a_n and x_n are stored as 20 digit fixed point numbers, so we convert the sum and a to this format.
            sum *= 100;
            a *= 100;

            // Because further a_n are  20 digit fixed point numbers, we multiply by ONE_20 when dividing by them.

            if (a >= a2) {
                a = (a * ONE_20) / a2;
                sum += x2;
            }

            if (a >= a3) {
                a = (a * ONE_20) / a3;
                sum += x3;
            }

            if (a >= a4) {
                a = (a * ONE_20) / a4;
                sum += x4;
            }

            if (a >= a5) {
                a = (a * ONE_20) / a5;
                sum += x5;
            }

            if (a >= a6) {
                a = (a * ONE_20) / a6;
                sum += x6;
            }

            if (a >= a7) {
                a = (a * ONE_20) / a7;
                sum += x7;
            }

            if (a >= a8) {
                a = (a * ONE_20) / a8;
                sum += x8;
            }

            if (a >= a9) {
                a = (a * ONE_20) / a9;
                sum += x9;
            }

            if (a >= a10) {
                a = (a * ONE_20) / a10;
                sum += x10;
            }

            if (a >= a11) {
                a = (a * ONE_20) / a11;
                sum += x11;
            }
        }

        // a is now a small number (smaller than a_11, which roughly equals 1.06). This means we can use a Taylor series
        // that converges rapidly for values of `a` close to one - the same one used in ln_36.
        // Let z = (a - 1) / (a + 1).
        // ln(a) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

        // Recall that 20 digit fixed point division requires multiplying by ONE_20, and multiplication requires
        // division by ONE_20.
        unchecked {
            int256 z = ((a - ONE_20) * ONE_20) / (a + ONE_20);
            int256 z_squared = (z * z) / ONE_20;

            // num is the numerator of the series: the z^(2 * n + 1) term
            int256 num = z;

            // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
            int256 seriesSum = num;

            // In each step, the numerator is multiplied by z^2
            num = (num * z_squared) / ONE_20;
            seriesSum += num / 3;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 5;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 7;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 9;

            num = (num * z_squared) / ONE_20;
            seriesSum += num / 11;

            // 6 Taylor terms are sufficient for 36 decimal precision.

            // Finally, we multiply by 2 (non fixed point) to compute ln(remainder)
            seriesSum *= 2;

            // We now have the sum of all x_n present, and the Taylor approximation of the logarithm of the remainder (both
            // with 20 decimals). All that remains is to sum these two, and then drop two digits to return a 18 decimal
            // value.

            int256 result = (sum + seriesSum) / 100;

            // We avoid using recursion here because zkSync doesn't support it.
            return negativeExponent ? -result : result;
        }
    }

    /**
     * @dev Internal high precision (36 decimal places) natural logarithm (ln(x)) with signed 18 decimal fixed point argument,
     * for x close to one.
     *
     * Should only be used if x is between LN_36_LOWER_BOUND and LN_36_UPPER_BOUND.
     */
    function _ln_36(int256 x) private pure returns (int256) {
        // Since ln(1) = 0, a value of x close to one will yield a very small result, which makes using 36 digits
        // worthwhile.

        // First, we transform x to a 36 digit fixed point value.
        unchecked {
            x *= ONE_18;

            // We will use the following Taylor expansion, which converges very rapidly. Let z = (x - 1) / (x + 1).
            // ln(x) = 2 * (z + z^3 / 3 + z^5 / 5 + z^7 / 7 + ... + z^(2 * n + 1) / (2 * n + 1))

            // Recall that 36 digit fixed point division requires multiplying by ONE_36, and multiplication requires
            // division by ONE_36.
            int256 z = ((x - ONE_36) * ONE_36) / (x + ONE_36);
            int256 z_squared = (z * z) / ONE_36;

            // num is the numerator of the series: the z^(2 * n + 1) term
            int256 num = z;

            // seriesSum holds the accumulated sum of each term in the series, starting with the initial z
            int256 seriesSum = num;

            // In each step, the numerator is multiplied by z^2
            num = (num * z_squared) / ONE_36;
            seriesSum += num / 3;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 5;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 7;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 9;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 11;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 13;

            num = (num * z_squared) / ONE_36;
            seriesSum += num / 15;

            // 8 Taylor terms are sufficient for 36 decimal precision.

            // All that remains is multiplying by 2 (non fixed point).
            return seriesSum * 2;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { StorageSlotExtension } from "./StorageSlotExtension.sol";

/**
 * @notice Variant of {ReentrancyGuard} that uses transient storage.
 * @dev NOTE: This variant only works on networks where EIP-1153 is available.
 */
abstract contract ReentrancyGuardTransient {
    using StorageSlotExtension for *;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    /// @notice Unauthorized reentrant call.
    error ReentrancyGuardReentrantCall();

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
        // On the first call to nonReentrant, _status will be NOT_ENTERED.
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail.
        _REENTRANCY_GUARD_STORAGE.asBoolean().tstore(true);
    }

    function _nonReentrantAfter() private {
        _REENTRANCY_GUARD_STORAGE.asBoolean().tstore(false);
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _REENTRANCY_GUARD_STORAGE.asBoolean().tload();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/**
 * @notice Library for reading and writing primitive types to specific storage slots. Based on OpenZeppelin; just adding support for int256.
 * @dev TIP: Consider using this library along with {SlotDerivation}.
 */
library StorageSlotExtension {
    struct Int256Slot {
        int256 value;
    }

    /// @dev Returns an `Int256Slot` with member `value` located at `slot`.
    function getInt256Slot(bytes32 slot) internal pure returns (Int256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /// @dev Custom type that represents a slot holding an address.
    type AddressSlotType is bytes32;

    /// @dev Cast an arbitrary slot to a AddressSlotType.
    function asAddress(bytes32 slot) internal pure returns (AddressSlotType) {
        return AddressSlotType.wrap(slot);
    }

    /// @dev Custom type that represents a slot holding a boolean.
    type BooleanSlotType is bytes32;

    /// @dev Cast an arbitrary slot to a BooleanSlotType.
    function asBoolean(bytes32 slot) internal pure returns (BooleanSlotType) {
        return BooleanSlotType.wrap(slot);
    }

    /// @dev Custom type that represents a slot holding a bytes32.
    type Bytes32SlotType is bytes32;

    /// @dev Cast an arbitrary slot to a Bytes32SlotType.
    function asBytes32(bytes32 slot) internal pure returns (Bytes32SlotType) {
        return Bytes32SlotType.wrap(slot);
    }

    /// @dev Custom type that represents a slot holding a uint256.
    type Uint256SlotType is bytes32;

    /// @dev Cast an arbitrary slot to a Uint256SlotType.
    function asUint256(bytes32 slot) internal pure returns (Uint256SlotType) {
        return Uint256SlotType.wrap(slot);
    }

    /// @dev Custom type that represents a slot holding an int256.
    type Int256SlotType is bytes32;

    /// @dev Cast an arbitrary slot to an Int256SlotType.
    function asInt256(bytes32 slot) internal pure returns (Int256SlotType) {
        return Int256SlotType.wrap(slot);
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(AddressSlotType slot) internal view returns (address value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(AddressSlotType slot, address value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(BooleanSlotType slot) internal view returns (bool value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(BooleanSlotType slot, bool value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(Bytes32SlotType slot) internal view returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(Bytes32SlotType slot, bytes32 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(Uint256SlotType slot) internal view returns (uint256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(Uint256SlotType slot, uint256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }

    /// @dev Load the value held at location `slot` in transient storage.
    function tload(Int256SlotType slot) internal view returns (int256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(slot)
        }
    }

    /// @dev Store `value` at location `slot` in transient storage.
    function tstore(Int256SlotType slot, int256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(slot, value)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";
import { Authentication } from "@balancer-labs/v3-solidity-utils/contracts/helpers/Authentication.sol";

/// @dev Base contract for performing access control on external functions within pools.
abstract contract CommonAuthentication is Authentication {
    IVault private immutable _vault;

    /// @notice Caller must be the swapFeeManager, if defined. Otherwise, default to governance.
    modifier onlySwapFeeManagerOrGovernance(address pool) {
        address roleAddress = _vault.getPoolRoleAccounts(pool).swapFeeManager;
        _ensureAuthenticatedByExclusiveRole(pool, roleAddress);
        _;
    }

    constructor(IVault vault, bytes32 actionIdDisambiguator) Authentication(actionIdDisambiguator) {
        _vault = vault;
    }

    function _getVault() internal view returns (IVault) {
        return _vault;
    }

    // Access control is delegated to the Authorizer in the `_canPerform` functions.
    function _canPerform(bytes32 actionId, address user) internal view override returns (bool) {
        return _vault.getAuthorizer().canPerform(actionId, user, address(this));
    }

    function _canPerform(bytes32 actionId, address account, address where) internal view returns (bool) {
        return _vault.getAuthorizer().canPerform(actionId, account, where);
    }

    /// @dev Ensure the sender is the roleAccount, or default to governance if roleAccount is address(0).
    function _ensureAuthenticatedByExclusiveRole(address where, address roleAccount) internal view {
        if (roleAccount == address(0)) {
            // Defer to governance if no role assigned.
            if (_canPerform(getActionId(msg.sig), msg.sender, where) == false) {
                revert SenderNotAllowed();
            }
        } else if (msg.sender != roleAccount) {
            revert SenderNotAllowed();
        }
    }

    /// @dev Ensure the sender is either the role manager, or is authorized by governance (non-exclusive).
    function _ensureAuthenticatedByRole(address where, address roleAccount) internal view {
        // If the sender is not the delegated manager for the role, defer to governance.
        if (msg.sender != roleAccount) {
            if (_canPerform(getActionId(msg.sig), msg.sender, where) == false) {
                revert SenderNotAllowed();
            }
        }
        // (else) if the sender is the delegated manager, proceed.
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IProtocolFeeController } from "@balancer-labs/v3-interfaces/contracts/vault/IProtocolFeeController.sol";
import { IVaultErrors } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultErrors.sol";
import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";
import {
    FEE_SCALING_FACTOR,
    MAX_FEE_PERCENTAGE,
    PoolRoleAccounts
} from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

import {
    ReentrancyGuardTransient
} from "@balancer-labs/v3-solidity-utils/contracts/openzeppelin/ReentrancyGuardTransient.sol";
import { FixedPoint } from "@balancer-labs/v3-solidity-utils/contracts/math/FixedPoint.sol";

import { SingletonAuthentication } from "./SingletonAuthentication.sol";
import { VaultGuard } from "./VaultGuard.sol";

/**
 * @notice Helper contract to manage protocol and creator fees outside the Vault.
 * @dev This contract stores global default protocol swap and yield fees, and also tracks the values of those fees
 * for each pool (the `PoolFeeConfig` described below). Protocol fees can always be overwritten by governance, but
 * pool creator fees are controlled by the registered poolCreator (see `PoolRoleAccounts`).
 *
 * The Vault stores a single aggregate percentage for swap and yield fees; only this `ProtocolFeeController` knows
 * the component fee percentages, and how to compute the aggregate from the components. This is done for performance
 * reasons, to minimize gas on the critical path, as this way the Vault simply applies a single "cut", and stores the
 * fee amounts separately from the pool balances.
 *
 * The pool creator fees are "net" protocol fees, meaning the protocol fee is taken first, and the pool creator fee
 * percentage is applied to the remainder. Essentially, the protocol is paid first, then the remainder is divided
 * between the pool creator and the LPs.
 *
 * There is a permissionless function (`collectAggregateFees`) that transfers these tokens from the Vault to this
 * contract, and distributes them between the protocol and pool creator, after which they can be withdrawn at any
 * time by governance and the pool creator, respectively.
 *
 * Protocol fees can be zero in some cases (e.g., the token is registered as exempt), and pool creator fees are zero
 * if there is no creator role address defined. Protocol fees are capped at a maximum percentage (50%); pool creator
 * fees are computed "net" protocol fees, so they can be any value from 0 to 100%. Any combination is possible.
 * A protocol-fee-exempt pool with a 100% pool creator fee would send all fees to the creator. If there is no pool
 * creator, a pool with a 50% protocol fee would divide the fees evenly between the protocol and LPs.
 *
 * This contract is deployed with the Vault, but can be changed by governance.
 */
contract ProtocolFeeController is
    IProtocolFeeController,
    SingletonAuthentication,
    ReentrancyGuardTransient,
    VaultGuard
{
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;
    using SafeCast for *;

    enum ProtocolFeeType {
        SWAP,
        YIELD
    }

    /**
     * @notice Fee configuration stored in the swap and yield fee mappings.
     * @dev Instead of storing only the fee in the mapping, also store a flag to indicate whether the fee has been
     * set by governance through a permissioned call. (The fee is stored in 64-bits, so that the struct fits
     * within a single slot.)
     *
     * We know the percentage is an 18-decimal FP value, which only takes 60 bits, so it's guaranteed to fit,
     * and we can do simple casts to truncate the high bits without needed SafeCast.
     *
     * We want to enable permissionless updates for pools, so that it is less onerous to update potentially
     * hundreds of pools if the global protocol fees change. However, we don't want to overwrite pools that
     * have had their fee percentages manually set by the DAO (i.e., after off-chain negotiation and agreement).
     *
     * @param feePercentage The raw swap or yield fee percentage
     * @param isOverride When set, this fee is controlled by governance, and cannot be changed permissionlessly
     */
    struct PoolFeeConfig {
        uint64 feePercentage;
        bool isOverride;
    }

    // Maximum protocol swap fee percentage. FixedPoint.ONE corresponds to a 100% fee.
    uint256 public constant MAX_PROTOCOL_SWAP_FEE_PERCENTAGE = 50e16; // 50%

    // Maximum protocol yield fee percentage.
    uint256 public constant MAX_PROTOCOL_YIELD_FEE_PERCENTAGE = 50e16; // 50%

    // Maximum pool creator (swap, yield) fee percentage.
    uint256 public constant MAX_CREATOR_FEE_PERCENTAGE = 99.999e16; // 99.999%

    // Global protocol swap fee.
    uint256 private _globalProtocolSwapFeePercentage;

    // Global protocol yield fee.
    uint256 private _globalProtocolYieldFeePercentage;

    // Store the pool-specific swap fee percentages (the Vault's poolConfigBits stores the aggregate percentage).
    mapping(address pool => PoolFeeConfig swapFeeConfig) internal _poolProtocolSwapFeePercentages;

    // Store the pool-specific yield fee percentages (the Vault's poolConfigBits stores the aggregate percentage).
    mapping(address pool => PoolFeeConfig yieldFeeConfig) internal _poolProtocolYieldFeePercentages;

    // Explicitly mark a pool as registered. This will enable future migrations to safely update protected state.
    mapping(address pool => bool isRegistered) internal _registeredPools;

    // Pool creator swap fee percentages for each pool.
    mapping(address pool => uint256 poolCreatorSwapFee) internal _poolCreatorSwapFeePercentages;

    // Pool creator yield fee percentages for each pool.
    mapping(address pool => uint256 poolCreatorYieldFee) internal _poolCreatorYieldFeePercentages;

    // Disaggregated protocol fees (from swap and yield), available for withdrawal by governance.
    mapping(address pool => mapping(IERC20 poolToken => uint256 feeAmount)) internal _protocolFeeAmounts;

    // Disaggregated pool creator fees (from swap and yield), available for withdrawal by the pool creator.
    mapping(address pool => mapping(IERC20 poolToken => uint256 feeAmount)) internal _poolCreatorFeeAmounts;

    /**
     * @notice Prevent pool data from being registered more than once.
     * @dev This can happen if there is an error in the migration, or if governance somehow grants permission to
     * `migratePool`, which should never happen.
     *
     * @param pool The pool
     */
    error PoolAlreadyRegistered(address pool);

    /// @notice Migration source cannot be this contract.
    error InvalidMigrationSource();

    // Ensure that the caller is the pool creator.
    modifier onlyPoolCreator(address pool) {
        _ensureCallerIsPoolCreator(pool);
        _;
    }

    // Validate the swap fee percentage against the maximum.
    modifier withValidSwapFee(uint256 newSwapFeePercentage) {
        if (newSwapFeePercentage > MAX_PROTOCOL_SWAP_FEE_PERCENTAGE) {
            revert ProtocolSwapFeePercentageTooHigh();
        }
        _ensureValidPrecision(newSwapFeePercentage);
        _;
    }

    // Validate the yield fee percentage against the maximum.
    modifier withValidYieldFee(uint256 newYieldFeePercentage) {
        if (newYieldFeePercentage > MAX_PROTOCOL_YIELD_FEE_PERCENTAGE) {
            revert ProtocolYieldFeePercentageTooHigh();
        }
        _ensureValidPrecision(newYieldFeePercentage);
        _;
    }

    modifier withValidPoolCreatorFee(uint256 newPoolCreatorFeePercentage) {
        if (newPoolCreatorFeePercentage > MAX_CREATOR_FEE_PERCENTAGE) {
            revert PoolCreatorFeePercentageTooHigh();
        }
        _;
    }

    // Force collection and disaggregation (e.g., before changing protocol fee percentages).
    modifier withLatestFees(address pool) {
        collectAggregateFees(pool);
        _;
    }

    constructor(
        IVault vault_,
        uint256 initialGlobalSwapFeePercentage,
        uint256 initialGlobalYieldFeePercentage
    ) SingletonAuthentication(vault_) VaultGuard(vault_) {
        _setGlobalProtocolSwapFeePercentage(initialGlobalSwapFeePercentage);
        _setGlobalProtocolYieldFeePercentage(initialGlobalYieldFeePercentage);
    }

    /// @inheritdoc IProtocolFeeController
    function vault() external view returns (IVault) {
        return _vault;
    }

    /// @inheritdoc IProtocolFeeController
    function collectAggregateFees(address pool) public {
        _vault.unlock(abi.encodeCall(ProtocolFeeController.collectAggregateFeesHook, pool));
    }

    /**
     * @dev Copy and zero out the `aggregateFeeAmounts` collected in the Vault accounting, supplying credit
     * for each token. Then have the Vault transfer tokens to this contract, debiting each token for the amount
     * transferred so that the transaction settles when the hook returns.
     */
    function collectAggregateFeesHook(address pool) external onlyVault {
        (uint256[] memory totalSwapFees, uint256[] memory totalYieldFees) = _vault.collectAggregateFees(pool);
        _receiveAggregateFees(pool, totalSwapFees, totalYieldFees);
    }

    /**
     * @notice Settle fee credits from the Vault.
     * @dev This must be called after calling `collectAggregateFees` in the Vault. Note that since charging protocol
     * fees (i.e., distributing tokens between pool and fee balances) occurs in the Vault, but fee collection
     * happens in the ProtocolFeeController, the swap fees reported here may encompass multiple operations. The Vault
     * differentiates between swap and yield fees (since they can have different percentage values); the Controller
     * combines swap and yield fees, then allocates the total between the protocol and pool creator.
     *
     * @param pool The address of the pool on which the swap fees were charged
     * @param swapFeeAmounts An array with the total swap fees collected, sorted in token registration order
     * @param yieldFeeAmounts An array with the total yield fees collected, sorted in token registration order
     */
    function _receiveAggregateFees(
        address pool,
        uint256[] memory swapFeeAmounts,
        uint256[] memory yieldFeeAmounts
    ) internal {
        _receiveAggregateFees(pool, ProtocolFeeType.SWAP, swapFeeAmounts);
        _receiveAggregateFees(pool, ProtocolFeeType.YIELD, yieldFeeAmounts);
    }

    function _receiveAggregateFees(address pool, ProtocolFeeType feeType, uint256[] memory feeAmounts) private {
        // There are two cases when we don't need to split fees (in which case we can save gas and avoid rounding
        // errors by skipping calculations) if either the protocol or pool creator fee percentage is zero.

        uint256 protocolFeePercentage = feeType == ProtocolFeeType.SWAP
            ? _poolProtocolSwapFeePercentages[pool].feePercentage
            : _poolProtocolYieldFeePercentages[pool].feePercentage;

        uint256 poolCreatorFeePercentage = feeType == ProtocolFeeType.SWAP
            ? _poolCreatorSwapFeePercentages[pool]
            : _poolCreatorYieldFeePercentages[pool];

        uint256 aggregateFeePercentage;

        bool needToSplitFees = poolCreatorFeePercentage > 0 && protocolFeePercentage > 0;
        if (needToSplitFees) {
            // Calculate once, outside the loop.
            aggregateFeePercentage = _computeAggregateFeePercentage(protocolFeePercentage, poolCreatorFeePercentage);
        }

        (IERC20[] memory poolTokens, uint256 numTokens) = _getPoolTokensAndCount(pool);
        for (uint256 i = 0; i < numTokens; ++i) {
            if (feeAmounts[i] > 0) {
                IERC20 token = poolTokens[i];

                _vault.sendTo(token, address(this), feeAmounts[i]);

                // It should be easier for off-chain processes to handle two events, rather than parsing the type
                // out of a single event.
                if (feeType == ProtocolFeeType.SWAP) {
                    emit ProtocolSwapFeeCollected(pool, token, feeAmounts[i]);
                } else {
                    emit ProtocolYieldFeeCollected(pool, token, feeAmounts[i]);
                }

                if (needToSplitFees) {
                    // The Vault took a single "cut" for the aggregate total percentage (protocol + pool creator) for
                    // this fee type (swap or yield). The first step is to reconstruct this total fee amount. Then we
                    // need to "disaggregate" this total, dividing it between the protocol and pool creator according
                    // to their individual percentages. We do this by computing the protocol portion first, then
                    // assigning the remainder to the pool creator.
                    uint256 totalFeeAmountRaw = feeAmounts[i].divUp(aggregateFeePercentage);
                    uint256 protocolPortion = totalFeeAmountRaw.mulUp(protocolFeePercentage);

                    _protocolFeeAmounts[pool][token] += protocolPortion;
                    _poolCreatorFeeAmounts[pool][token] += feeAmounts[i] - protocolPortion;
                } else {
                    // If we don't need to split, one of them must be zero.
                    if (poolCreatorFeePercentage == 0) {
                        _protocolFeeAmounts[pool][token] += feeAmounts[i];
                    } else {
                        _poolCreatorFeeAmounts[pool][token] += feeAmounts[i];
                    }
                }
            }
        }
    }

    /// @inheritdoc IProtocolFeeController
    function getGlobalProtocolSwapFeePercentage() external view returns (uint256) {
        return _globalProtocolSwapFeePercentage;
    }

    /// @inheritdoc IProtocolFeeController
    function getGlobalProtocolYieldFeePercentage() external view returns (uint256) {
        return _globalProtocolYieldFeePercentage;
    }

    /// @inheritdoc IProtocolFeeController
    function isPoolRegistered(address pool) external view returns (bool) {
        return _registeredPools[pool];
    }

    /// @inheritdoc IProtocolFeeController
    function getPoolProtocolSwapFeeInfo(address pool) external view returns (uint256, bool) {
        PoolFeeConfig memory config = _poolProtocolSwapFeePercentages[pool];

        return (config.feePercentage, config.isOverride);
    }

    /// @inheritdoc IProtocolFeeController
    function getPoolProtocolYieldFeeInfo(address pool) external view returns (uint256, bool) {
        PoolFeeConfig memory config = _poolProtocolYieldFeePercentages[pool];

        return (config.feePercentage, config.isOverride);
    }

    /// @inheritdoc IProtocolFeeController
    function getPoolCreatorSwapFeePercentage(address pool) external view returns (uint256) {
        return _poolCreatorSwapFeePercentages[pool];
    }

    /// @inheritdoc IProtocolFeeController
    function getPoolCreatorYieldFeePercentage(address pool) external view returns (uint256) {
        return _poolCreatorYieldFeePercentages[pool];
    }

    /// @inheritdoc IProtocolFeeController
    function getProtocolFeeAmounts(address pool) external view returns (uint256[] memory feeAmounts) {
        (IERC20[] memory poolTokens, uint256 numTokens) = _getPoolTokensAndCount(pool);

        feeAmounts = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; ++i) {
            feeAmounts[i] = _protocolFeeAmounts[pool][poolTokens[i]];
        }
    }

    /// @inheritdoc IProtocolFeeController
    function getPoolCreatorFeeAmounts(address pool) external view returns (uint256[] memory feeAmounts) {
        (IERC20[] memory poolTokens, uint256 numTokens) = _getPoolTokensAndCount(pool);

        feeAmounts = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; ++i) {
            feeAmounts[i] = _poolCreatorFeeAmounts[pool][poolTokens[i]];
        }
    }

    /// @inheritdoc IProtocolFeeController
    function computeAggregateFeePercentage(
        uint256 protocolFeePercentage,
        uint256 poolCreatorFeePercentage
    ) external pure returns (uint256) {
        return _computeAggregateFeePercentage(protocolFeePercentage, poolCreatorFeePercentage);
    }

    /// @inheritdoc IProtocolFeeController
    function updateProtocolSwapFeePercentage(address pool) external withLatestFees(pool) {
        PoolFeeConfig memory feeConfig = _poolProtocolSwapFeePercentages[pool];
        uint256 globalProtocolSwapFee = _globalProtocolSwapFeePercentage;

        if (feeConfig.isOverride == false && globalProtocolSwapFee != feeConfig.feePercentage) {
            _updatePoolSwapFeePercentage(pool, globalProtocolSwapFee, false);
        }
    }

    /// @inheritdoc IProtocolFeeController
    function updateProtocolYieldFeePercentage(address pool) external withLatestFees(pool) {
        PoolFeeConfig memory feeConfig = _poolProtocolYieldFeePercentages[pool];
        uint256 globalProtocolYieldFee = _globalProtocolYieldFeePercentage;

        if (feeConfig.isOverride == false && globalProtocolYieldFee != feeConfig.feePercentage) {
            _updatePoolYieldFeePercentage(pool, globalProtocolYieldFee, false);
        }
    }

    function _getAggregateFeePercentage(address pool, ProtocolFeeType feeType) internal view returns (uint256) {
        uint256 protocolFeePercentage;
        uint256 poolCreatorFeePercentage;

        if (feeType == ProtocolFeeType.SWAP) {
            protocolFeePercentage = _poolProtocolSwapFeePercentages[pool].feePercentage;
            poolCreatorFeePercentage = _poolCreatorSwapFeePercentages[pool];
        } else {
            protocolFeePercentage = _poolProtocolYieldFeePercentages[pool].feePercentage;
            poolCreatorFeePercentage = _poolCreatorYieldFeePercentages[pool];
        }

        return _computeAggregateFeePercentage(protocolFeePercentage, poolCreatorFeePercentage);
    }

    function _computeAggregateFeePercentage(
        uint256 protocolFeePercentage,
        uint256 poolCreatorFeePercentage
    ) internal pure returns (uint256 aggregateFeePercentage) {
        aggregateFeePercentage =
            protocolFeePercentage +
            protocolFeePercentage.complement().mulDown(poolCreatorFeePercentage);

        // Protocol fee percentages are limited to 24-bit precision for performance reasons (i.e., to fit all the fees
        // in a single slot), and because high precision is not needed. Generally we expect protocol fees set by
        // governance to be simple integers.
        //
        // However, the pool creator fee is entirely controlled by the pool creator, and it is possible to craft a
        // valid pool creator fee percentage that would cause the aggregate fee percentage to fail the precision check.
        // This case should be rare, so we ensure this can't happen by truncating the final value.
        aggregateFeePercentage = (aggregateFeePercentage / FEE_SCALING_FACTOR) * FEE_SCALING_FACTOR;
    }

    function _ensureCallerIsPoolCreator(address pool) internal view {
        address poolCreator = _getPoolCreator(pool);

        if (poolCreator == address(0)) {
            revert PoolCreatorNotRegistered(pool);
        }

        if (poolCreator != msg.sender) {
            revert CallerIsNotPoolCreator(msg.sender, pool);
        }
    }

    function _getPoolTokensAndCount(address pool) internal view returns (IERC20[] memory tokens, uint256 numTokens) {
        tokens = _vault.getPoolTokens(pool);
        numTokens = tokens.length;
    }

    // Retrieve the pool creator for a pool from the Vault.
    function _getPoolCreator(address pool) internal view returns (address) {
        PoolRoleAccounts memory roleAccounts = _vault.getPoolRoleAccounts(pool);

        return roleAccounts.poolCreator;
    }

    /***************************************************************************
                                 Pool Migration
    ***************************************************************************/

    /**
     * @notice Not exposed in the interface, this enables migration of hidden pool state.
     * @dev Permission should NEVER be granted to this function outside of a migration contract. It is necessary to
     * permit migration of the `ProtocolFeeController` with all state (in particular, protocol fee overrides and pool
     * creator fees) that cannot be written outside of the `registerPool` function called by the Vault during pool
     * deployment.
     *
     * Even if governance were to grant permission to call this function, the `_registeredPools` latch keeps it safe,
     * guaranteeing that it is impossible to use this function to change anything after registration. A pool can only
     * be registered / configured once - either copied to a new controller in the migration context, or added normally
     * through the Vault calling `registerPool`.
     *
     * @param pool The address of the pool to be migrated
     */
    function migratePool(address pool) external {
        IProtocolFeeController oldFeeController = _vault.getProtocolFeeController();

        if (address(oldFeeController) == address(this)) {
            revert InvalidMigrationSource();
        }

        if (_registeredPools[pool]) {
            revert PoolAlreadyRegistered(pool);
        }

        _registeredPools[pool] = true;

        (uint256 protocolSwapFeePercentage, bool swapFeeIsOverride) = oldFeeController.getPoolProtocolSwapFeeInfo(pool);
        _poolProtocolSwapFeePercentages[pool] = PoolFeeConfig({
            feePercentage: protocolSwapFeePercentage.toUint64(),
            isOverride: swapFeeIsOverride
        });

        (uint256 protocolYieldFeePercentage, bool yieldFeeIsOverride) = oldFeeController.getPoolProtocolYieldFeeInfo(
            pool
        );
        _poolProtocolYieldFeePercentages[pool] = PoolFeeConfig({
            feePercentage: protocolYieldFeePercentage.toUint64(),
            isOverride: yieldFeeIsOverride
        });

        // On the first migration, these functions won't exist, as they were not included in the originally deployed
        // contract. This is ok, as the first time the contract will be migrated, there will be no pool creators.
        // In the event a pool that did have a pool creator was missed, the pool creator can simply set the fee
        // percentage again on the new controller. The fact that a pool has a pool creator cannot be lost, as this
        // is stored in the Vault on initial registration.
        try oldFeeController.getPoolCreatorSwapFeePercentage(pool) returns (uint256 poolCreatorSwapFeePercentage) {
            _poolCreatorSwapFeePercentages[pool] = poolCreatorSwapFeePercentage;
        } catch {
            // solhint-disable-previous-line no-empty-blocks
        }

        try oldFeeController.getPoolCreatorYieldFeePercentage(pool) returns (uint256 poolCreatorYieldFeePercentage) {
            _poolCreatorYieldFeePercentages[pool] = poolCreatorYieldFeePercentage;
        } catch {
            // solhint-disable-previous-line no-empty-blocks
        }
    }

    /***************************************************************************
                                Permissioned Functions
    ***************************************************************************/

    /// @inheritdoc IProtocolFeeController
    function registerPool(
        address pool,
        address poolCreator,
        bool protocolFeeExempt
    ) external onlyVault returns (uint256 aggregateSwapFeePercentage, uint256 aggregateYieldFeePercentage) {
        _registeredPools[pool] = true;

        // Set local storage of the actual percentages for the pool (default to global).
        aggregateSwapFeePercentage = protocolFeeExempt ? 0 : _globalProtocolSwapFeePercentage;
        aggregateYieldFeePercentage = protocolFeeExempt ? 0 : _globalProtocolYieldFeePercentage;

        // `isOverride` is true if the pool is protocol fee exempt; otherwise, default to false.
        // If exempt, this pool cannot be updated to the current global percentage permissionlessly.
        // The percentages are 18 decimal floating point numbers, bound between 0 and the max fee (<= FixedPoint.ONE).
        // Since this fits in 64 bits, the SafeCast shouldn't be necessary, and is done out of an abundance of caution.
        _poolProtocolSwapFeePercentages[pool] = PoolFeeConfig({
            feePercentage: aggregateSwapFeePercentage.toUint64(),
            isOverride: protocolFeeExempt
        });
        _poolProtocolYieldFeePercentages[pool] = PoolFeeConfig({
            feePercentage: aggregateYieldFeePercentage.toUint64(),
            isOverride: protocolFeeExempt
        });

        // Allow tracking pool fee percentages in all cases (e.g., when the pool is protocol-fee exempt).
        emit InitialPoolAggregateSwapFeePercentage(pool, aggregateSwapFeePercentage, protocolFeeExempt);
        emit InitialPoolAggregateYieldFeePercentage(pool, aggregateYieldFeePercentage, protocolFeeExempt);

        emit PoolRegisteredWithFeeController(pool, poolCreator, protocolFeeExempt);
    }

    /// @inheritdoc IProtocolFeeController
    function setGlobalProtocolSwapFeePercentage(uint256 newProtocolSwapFeePercentage) external authenticate {
        _setGlobalProtocolSwapFeePercentage(newProtocolSwapFeePercentage);
    }

    function _setGlobalProtocolSwapFeePercentage(
        uint256 newProtocolSwapFeePercentage
    ) internal withValidSwapFee(newProtocolSwapFeePercentage) {
        _globalProtocolSwapFeePercentage = newProtocolSwapFeePercentage;

        emit GlobalProtocolSwapFeePercentageChanged(newProtocolSwapFeePercentage);
    }

    /// @inheritdoc IProtocolFeeController
    function setGlobalProtocolYieldFeePercentage(uint256 newProtocolYieldFeePercentage) external authenticate {
        _setGlobalProtocolYieldFeePercentage(newProtocolYieldFeePercentage);
    }

    function _setGlobalProtocolYieldFeePercentage(
        uint256 newProtocolYieldFeePercentage
    ) internal withValidYieldFee(newProtocolYieldFeePercentage) {
        _globalProtocolYieldFeePercentage = newProtocolYieldFeePercentage;

        emit GlobalProtocolYieldFeePercentageChanged(newProtocolYieldFeePercentage);
    }

    /// @inheritdoc IProtocolFeeController
    function setProtocolSwapFeePercentage(
        address pool,
        uint256 newProtocolSwapFeePercentage
    ) external authenticate withValidSwapFee(newProtocolSwapFeePercentage) withLatestFees(pool) {
        _updatePoolSwapFeePercentage(pool, newProtocolSwapFeePercentage, true);
    }

    /// @inheritdoc IProtocolFeeController
    function setProtocolYieldFeePercentage(
        address pool,
        uint256 newProtocolYieldFeePercentage
    ) external authenticate withValidYieldFee(newProtocolYieldFeePercentage) withLatestFees(pool) {
        _updatePoolYieldFeePercentage(pool, newProtocolYieldFeePercentage, true);
    }

    /// @inheritdoc IProtocolFeeController
    function setPoolCreatorSwapFeePercentage(
        address pool,
        uint256 poolCreatorSwapFeePercentage
    ) external onlyPoolCreator(pool) withValidPoolCreatorFee(poolCreatorSwapFeePercentage) withLatestFees(pool) {
        _setPoolCreatorFeePercentage(pool, poolCreatorSwapFeePercentage, ProtocolFeeType.SWAP);
    }

    /// @inheritdoc IProtocolFeeController
    function setPoolCreatorYieldFeePercentage(
        address pool,
        uint256 poolCreatorYieldFeePercentage
    ) external onlyPoolCreator(pool) withValidPoolCreatorFee(poolCreatorYieldFeePercentage) withLatestFees(pool) {
        _setPoolCreatorFeePercentage(pool, poolCreatorYieldFeePercentage, ProtocolFeeType.YIELD);
    }

    function _setPoolCreatorFeePercentage(
        address pool,
        uint256 poolCreatorFeePercentage,
        ProtocolFeeType feeType
    ) internal {
        // Need to set locally, and update the aggregate percentage in the Vault.
        if (feeType == ProtocolFeeType.SWAP) {
            _poolCreatorSwapFeePercentages[pool] = poolCreatorFeePercentage;

            // The Vault will also emit an `AggregateSwapFeePercentageChanged` event.
            _vault.updateAggregateSwapFeePercentage(pool, _getAggregateFeePercentage(pool, ProtocolFeeType.SWAP));

            emit PoolCreatorSwapFeePercentageChanged(pool, poolCreatorFeePercentage);
        } else {
            _poolCreatorYieldFeePercentages[pool] = poolCreatorFeePercentage;

            // The Vault will also emit an `AggregateYieldFeePercentageChanged` event.
            _vault.updateAggregateYieldFeePercentage(pool, _getAggregateFeePercentage(pool, ProtocolFeeType.YIELD));

            emit PoolCreatorYieldFeePercentageChanged(pool, poolCreatorFeePercentage);
        }
    }

    /// @inheritdoc IProtocolFeeController
    function withdrawProtocolFees(address pool, address recipient) external authenticate {
        (IERC20[] memory poolTokens, uint256 numTokens) = _getPoolTokensAndCount(pool);

        for (uint256 i = 0; i < numTokens; ++i) {
            IERC20 token = poolTokens[i];

            _withdrawProtocolFees(pool, recipient, token);
        }
    }

    /// @inheritdoc IProtocolFeeController
    function withdrawProtocolFeesForToken(address pool, address recipient, IERC20 token) external authenticate {
        // Revert if the pool is not registered or if the token does not belong to the pool.
        _vault.getPoolTokenCountAndIndexOfToken(pool, token);
        _withdrawProtocolFees(pool, recipient, token);
    }

    function _withdrawProtocolFees(address pool, address recipient, IERC20 token) internal {
        uint256 amountToWithdraw = _protocolFeeAmounts[pool][token];
        if (amountToWithdraw > 0) {
            _protocolFeeAmounts[pool][token] = 0;
            token.safeTransfer(recipient, amountToWithdraw);

            emit ProtocolFeesWithdrawn(pool, token, recipient, amountToWithdraw);
        }
    }

    /// @inheritdoc IProtocolFeeController
    function withdrawPoolCreatorFees(address pool, address recipient) external onlyPoolCreator(pool) {
        _withdrawPoolCreatorFees(pool, recipient);
    }

    /// @inheritdoc IProtocolFeeController
    function withdrawPoolCreatorFees(address pool) external {
        _withdrawPoolCreatorFees(pool, _getPoolCreator(pool));
    }

    function _withdrawPoolCreatorFees(address pool, address recipient) private {
        (IERC20[] memory poolTokens, uint256 numTokens) = _getPoolTokensAndCount(pool);

        for (uint256 i = 0; i < numTokens; ++i) {
            IERC20 token = poolTokens[i];

            uint256 amountToWithdraw = _poolCreatorFeeAmounts[pool][token];
            if (amountToWithdraw > 0) {
                _poolCreatorFeeAmounts[pool][token] = 0;
                token.safeTransfer(recipient, amountToWithdraw);

                emit PoolCreatorFeesWithdrawn(pool, token, recipient, amountToWithdraw);
            }
        }
    }

    /// @dev Common code shared between set/update. `isOverride` will be true if governance is setting the percentage.
    function _updatePoolSwapFeePercentage(address pool, uint256 newProtocolSwapFeePercentage, bool isOverride) private {
        // Update local storage of the raw percentage.
        //
        // The percentages are 18 decimal floating point numbers, bound between 0 and the max fee (<= FixedPoint.ONE).
        // Since this fits in 64 bits, the SafeCast shouldn't be necessary, and is done out of an abundance of caution.
        _poolProtocolSwapFeePercentages[pool] = PoolFeeConfig({
            feePercentage: newProtocolSwapFeePercentage.toUint64(),
            isOverride: isOverride
        });

        // Update the resulting aggregate swap fee value in the Vault (PoolConfig).
        _vault.updateAggregateSwapFeePercentage(pool, _getAggregateFeePercentage(pool, ProtocolFeeType.SWAP));

        emit ProtocolSwapFeePercentageChanged(pool, newProtocolSwapFeePercentage);
    }

    /// @dev Common code shared between set/update. `isOverride` will be true if governance is setting the percentage.
    function _updatePoolYieldFeePercentage(
        address pool,
        uint256 newProtocolYieldFeePercentage,
        bool isOverride
    ) private {
        // Update local storage of the raw percentage.
        // The percentages are 18 decimal floating point numbers, bound between 0 and the max fee (<= FixedPoint.ONE).
        // Since this fits in 64 bits, the SafeCast shouldn't be necessary, and is done out of an abundance of caution.
        _poolProtocolYieldFeePercentages[pool] = PoolFeeConfig({
            feePercentage: newProtocolYieldFeePercentage.toUint64(),
            isOverride: isOverride
        });

        // Update the resulting aggregate yield fee value in the Vault (PoolConfig).
        _vault.updateAggregateYieldFeePercentage(pool, _getAggregateFeePercentage(pool, ProtocolFeeType.YIELD));

        emit ProtocolYieldFeePercentageChanged(pool, newProtocolYieldFeePercentage);
    }

    function _ensureValidPrecision(uint256 feePercentage) private pure {
        // Primary fee percentages are 18-decimal values, stored here in 64 bits, and calculated with full 256-bit
        // precision. However, the resulting aggregate fees are stored in the Vault with 24-bit precision, which
        // corresponds to 0.00001% resolution (i.e., a fee can be 1%, 1.00001%, 1.00002%, but not 1.000005%).
        // Ensure there will be no precision loss in the Vault - which would lead to a discrepancy between the
        // aggregate fee calculated here and that stored in the Vault.
        if ((feePercentage / FEE_SCALING_FACTOR) * FEE_SCALING_FACTOR != feePercentage) {
            revert IVaultErrors.FeePrecisionTooHigh();
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IAuthorizer } from "@balancer-labs/v3-interfaces/contracts/vault/IAuthorizer.sol";
import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";

import { CommonAuthentication } from "./CommonAuthentication.sol";

/**
 * @notice Base contract suitable for Singleton contracts (e.g., pool factories) that have permissioned functions.
 * @dev The disambiguator is the contract's own address. This is used in the construction of actionIds for permissioned
 * functions, to avoid conflicts when multiple contracts (or multiple versions of the same contract) use the same
 * function name.
 */
abstract contract SingletonAuthentication is CommonAuthentication {
    // Use the contract's own address to disambiguate action identifiers.
    constructor(IVault vault) CommonAuthentication(vault, bytes32(uint256(uint160(address(this))))) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @notice Get the address of the Balancer Vault.
     * @return vault An interface pointer to the Vault
     */
    function getVault() public view returns (IVault) {
        return _getVault();
    }

    /**
     * @notice Get the address of the Authorizer.
     * @return authorizer An interface pointer to the Authorizer
     */
    function getAuthorizer() public view returns (IAuthorizer) {
        return getVault().getAuthorizer();
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IVaultErrors } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultErrors.sol";
import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";

/// @notice Contract that shares the modifier `onlyVault`.
contract VaultGuard {
    IVault internal immutable _vault;

    constructor(IVault vault) {
        _vault = vault;
    }

    modifier onlyVault() {
        _ensureOnlyVault();
        _;
    }

    function _ensureOnlyVault() private view {
        if (msg.sender != address(_vault)) {
            revert IVaultErrors.SenderIsNotVault(msg.sender);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {IERC20Metadata} from "../token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface of the ERC4626 "Tokenized Vault Standard", as defined in
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
     * @dev Allows an on-chain or off-chain user to simulate the effects of their redeemption at the current block,
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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../IERC20.sol";
import {IERC20Permit} from "../extensions/IERC20Permit.sol";
import {Address} from "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
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
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
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
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
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
            revert AddressInsufficientBalance(address(this));
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
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
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
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.20;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
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
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IAuthentication } from "@balancer-labs/v3-interfaces/contracts/solidity-utils/helpers/IAuthentication.sol";
import { IBasicAuthorizer } from "@balancer-labs/v3-interfaces/contracts/governance-scripts/IBasicAuthorizer.sol";
import { IProtocolFeeController } from "@balancer-labs/v3-interfaces/contracts/vault/IProtocolFeeController.sol";
import { PoolRoleAccounts, PoolConfig } from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import { IVaultAdmin } from "@balancer-labs/v3-interfaces/contracts/vault/IVaultAdmin.sol";
import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";

import { SingletonAuthentication } from "@balancer-labs/v3-vault/contracts/SingletonAuthentication.sol";
import { ProtocolFeeController } from "@balancer-labs/v3-vault/contracts/ProtocolFeeController.sol";
import {
    ReentrancyGuardTransient
} from "@balancer-labs/v3-solidity-utils/contracts/openzeppelin/ReentrancyGuardTransient.sol";

/**
 * @notice Migrate to a ProtocolFeeController with extra events and infrastructure for future migrations.
 * @dev These events enable tracking pool protocol fees under all circumstances (in particular, when protocol fees are
 * initially turned off).
 *
 * After deployment, call `migratePools` as many times as necessary. The list must be generated externally, as pools
 * are not iterable on-chain. The batch interface allows an unlimited number of pools to be migrated; it's possible
 * there might be too many to migrate in a single call.
 *
 * The first time `migratePools` is called, the contract will first copy the global (pool-independent data). This could
 * be done in a separate stage, but we're trying to keep the contract simple, vs. duplicating the staging coordinator
 * system of v2 just yet.
 *
 * When all pools have been migrated, call `finalizeMigration` to disable further migration, update the address in the
 * Vault, and renounce all permissions. While `migratePools` is permissionless, this call must be permissioned to
 * prevent premature termination in case multiple transactions are required to migrate all the pools.
 *
 * Associated with `20250221-protocol-fee-controller-migration` (fork test only).
 */
contract ProtocolFeeControllerMigration is ReentrancyGuardTransient, SingletonAuthentication {
    IProtocolFeeController public immutable oldFeeController;
    IProtocolFeeController public newFeeController;

    IVault public immutable vault;

    // IAuthorizer with interface for granting/revoking roles.
    IBasicAuthorizer internal immutable _authorizer;

    // Set when the operation is complete and all permissions have been renounced.
    bool internal _finalized;

    // Set after the global percentages have been transferred (on the first call to `migratePools`).
    bool internal _globalPercentagesMigrated;

    /**
     * @notice Attempt to deploy this contract with invalid parameters.
     * @dev ProtocolFeeController contracts return the address of the Vault they were deployed with. Ensure that both
     * the old and new controllers reference the same vault.
     */
    error InvalidFeeController();

    /// @notice Migration can only be performed once.
    error AlreadyMigrated();

    constructor(IVault _vault, IProtocolFeeController _newFeeController) SingletonAuthentication(_vault) {
        oldFeeController = _vault.getProtocolFeeController();

        // Ensure valid fee controllers. Also ensure that we are not trying to operate on the current fee controller.
        if (_newFeeController.vault() != _vault || _newFeeController == oldFeeController) {
            revert InvalidFeeController();
        }

        vault = _vault;
        newFeeController = _newFeeController;

        _authorizer = IBasicAuthorizer(address(vault.getAuthorizer()));
    }

    /**
     * @notice Check whether migration has been completed.
     * @dev It can only be done once.
     * @return isComplete True if `finalizeMigration` has been called.
     */
    function isMigrationComplete() public view returns (bool) {
        return _finalized;
    }

    /**
     * @notice Migrate pools from the old fee controller to the new one.
     * @dev This can be called multiple times, if there are too many pools for a single transaction. Note that the
     * first time this is called, it will migrate the global fee percentages, then proceed with the first set of pools.
     *
     * @param pools The set of pools to be migrated in this call
     */
    function migratePools(address[] memory pools) external virtual nonReentrant {
        if (isMigrationComplete()) {
            revert AlreadyMigrated();
        }

        // Migrate the global percentages only once, before the first set of pools.
        if (_globalPercentagesMigrated == false) {
            _globalPercentagesMigrated = true;

            _migrateGlobalPercentages();
        }

        // This more complex migration allows for pool creators and overrides, and uses the new features in the second
        // deployment of the `ProtocolFeeController`.
        //
        // At the end of this process, governance must still withdraw any leftover protocol fees from the old
        // controller (i.e., that have been collected but not withdrawn). Pool creators likewise would still need to
        // withdraw any leftover pool creator fees from the old controller.
        for (uint256 i = 0; i < pools.length; ++i) {
            // This function is not in the public interface.
            ProtocolFeeController(address(newFeeController)).migratePool(pools[i]);
        }
    }

    function finalizeMigration() external virtual authenticate {
        if (isMigrationComplete()) {
            revert AlreadyMigrated();
        }

        _finalized = true;

        // Update the fee controller in the Vault.
        _migrateFeeController();

        // Revoke all permissions.
        _authorizer.renounceRole(_authorizer.DEFAULT_ADMIN_ROLE(), address(this));
    }

    function _migrateGlobalPercentages() internal {
        // Grant global fee percentage permissions to set on new controller.
        bytes32 swapFeeRole = IAuthentication(address(newFeeController)).getActionId(
            IProtocolFeeController.setGlobalProtocolSwapFeePercentage.selector
        );

        bytes32 yieldFeeRole = IAuthentication(address(newFeeController)).getActionId(
            IProtocolFeeController.setGlobalProtocolYieldFeePercentage.selector
        );

        _authorizer.grantRole(swapFeeRole, address(this));
        _authorizer.grantRole(yieldFeeRole, address(this));

        // Copy percentages to new controller.
        uint256 globalSwapFeePercentage = oldFeeController.getGlobalProtocolSwapFeePercentage();
        uint256 globalYieldFeePercentage = oldFeeController.getGlobalProtocolYieldFeePercentage();

        newFeeController.setGlobalProtocolSwapFeePercentage(globalSwapFeePercentage);
        newFeeController.setGlobalProtocolYieldFeePercentage(globalYieldFeePercentage);

        // Revoke permissions.
        _authorizer.renounceRole(swapFeeRole, address(this));
        _authorizer.renounceRole(yieldFeeRole, address(this));
    }

    function _migrateFeeController() internal {
        bytes32 setFeeControllerRole = IAuthentication(address(vault)).getActionId(
            IVaultAdmin.setProtocolFeeController.selector
        );

        _authorizer.grantRole(setFeeControllerRole, address(this));

        vault.setProtocolFeeController(newFeeController);

        _authorizer.renounceRole(setFeeControllerRole, address(this));
    }
}
