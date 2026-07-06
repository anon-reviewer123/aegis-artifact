// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20Upgradeable as IERC20, SafeERC20Upgradeable as SafeERC20} from "@openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IConvexBooster, IConvexFeeRegistry, IConvexVault} from "@interfaces/IConvexFraxVaults.sol";
import "@interfaces/IFraxFarmERC20.sol";
import "@interfaces/IRewardsDistributor.sol";
import "@interfaces/IFeeManager.sol";
import "@interfaces/IERC1155Receipt.sol";

/**
*   @title Asset Strategy Vault - Convex & Frax staked Curve LP
*   @notice This is the implementation logic for staking Curve LP assets through Convex to a FraxFarm.
*   @author Hourglass Finance
*/

contract FraxBPVault {
    using SafeERC20 for IERC20;

    /// @notice The address of the convex booster to clone vaults from
    address internal constant CONVEX_BOOSTER = address(0x569f5B842B5006eC17Be02B8b94510BA8e79FbCa);
    /// @notice The address of the convex fee registry
    address internal constant CONVEX_FEE_REGISTRY = address(0xC9aCB83ADa68413a6Aa57007BC720EE2E2b3C46D);
    /// @notice The convex pool id for this asset/strategy
    uint256 internal constant CONVEX_PID = 9;
    /// @notice Address of FXS token
    address internal constant FXS = address(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);
    /// @notice Fee denominator for fee calculations
    uint256 internal constant FEE_DENOMINATOR = 10000;

    /// @notice The address of the fee manager contract
    address internal feeManager;
    /// @notice The asset id of this strategy
    uint256 internal assetId;
    /// @notice Address of the token that is deposited into the convex vault
    address internal depositToken;
    /// @notice Address of the 1155 receipt users receive for depositing into this vault
    address internal receiptToken;
    /// @notice The timestamp at which this vault can be withdrawn from, also, the 1155 token id
    uint256 internal maturityTimestamp;

    /// @notice Address of the cloned convex vault this contract owns
    address internal depositVault;
    /// @notice The kek id for the locked stake - as array in case this needs to be managed by a generalized contract
    bytes32[] internal depositId;

    /// @notice The address of the owner (custodian)
    address internal owner;
    /// @notice Whether this contract has been initialized yet.
    bool internal isInitialized;


    ////////// Getters for the internal vars //////////
    /// @notice Get the address of the fee manager
    function getFeeManager() external view returns (address) {
        return feeManager;
    }
    /// @notice Get the the address of the vault this owns
    function getDepositVault() external view returns (address) {
        return depositVault;
    }
    /// @notice Get the address of the token that is deposited into the convex vault
    function getDepositToken() external view returns (address) {
        return depositToken;
    }
    /// @notice Get the maturity timestamp for this vault
    function getMaturityTimestamp() external view returns (uint256) {
        return maturityTimestamp;
    }
    /// @notice returns the value of the deposit id
    function getDepositId() external view returns (bytes32) {
        return depositId[0];
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    /// @notice Initialization is called when the implementation is cloned for new maturities
    function initialize(
        address _feeManager,
        address _depositToken, // curve LP token
        uint256 initAmount,
        uint256 _maturityTimestamp,
        uint256 _assetId,
        address _receipt, 
        bytes calldata,
        bytes calldata
    ) public {
        require(!isInitialized, "!init");
        owner = msg.sender;
        isInitialized = true;

        depositVault = IConvexBooster(CONVEX_BOOSTER).createVault(CONVEX_PID);

        // just a check to make sure the assets are correct!
        require(_depositToken == IConvexVault(depositVault).curveLpToken(), "!depositToken");
        feeManager = _feeManager;
        depositToken = _depositToken;
        maturityTimestamp = _maturityTimestamp; 
        receiptToken = _receipt;
        assetId = _assetId;

        /// Set approvals - convex vault OK to pull from here & if needed reward collector to pull from here
        IERC20(_depositToken).approve(depositVault, type(uint256).max);

        /// seed stake 
        bytes32 kekId = IConvexVault(depositVault).stakeLockedCurveLp(initAmount, (_maturityTimestamp - block.timestamp));
        depositId.push(kekId);
    }
    
    /// @notice Triggers the deposit of the assets into the strategy
    /// @param _amount The amount of the deposit token to deposit
    /// @dev This contract must receive the deposit token first, and `_amount` must be <= the balance of this contract
    function deposit(uint256 _amount, bytes calldata) external onlyOwner {
        // The deposit token is sent into this vault before this function is called
        require(_amount <= IERC20(depositToken).balanceOf(address(this)), "!balance");

        // call convex vault lockAdditional
        IConvexVault(depositVault).lockAdditionalCurveLp(depositId[0], _amount);
    }

    /// @notice Withdraws unlocked assets once maturity is reached, claiming rewards
    /// @param destination The address to send the matured assets to
    /// @param toUser Whether or not this is a user triggered withdrawal
    /// @param user The user address to send the user portion to (if applicable)
    /// @param userAmount The amount of the matured assets to send to the user (if applicable)
    /// @dev sending to user prevents them from having to again withdraw from the mature vault
    function withdrawMatured(
        address destination, 
        bool toUser, 
        address user, 
        uint256 userAmount
    ) external onlyOwner returns (uint256 totalWithdrawn) {
        // claim rewards first so it sends to reward distributor
        claimRewards();

        // withdraw from convex vault to this address
        IConvexVault(depositVault).withdrawLockedAndUnwrap(depositId[0]);

        // get the balance of the deposit token now held here
        totalWithdrawn = IERC20(depositToken).balanceOf(address(this));
        require(totalWithdrawn >= userAmount, "!userAmount");
        
        // if user triggered this withdrawal, send their portion to them & the rest to the mature vault
        if (toUser) {
            // send to user
            IERC20(depositToken).safeTransfer(user, userAmount);
            // send to destination mature holding vault
            IERC20(depositToken).safeTransfer(destination, totalWithdrawn - userAmount);
        } else {
            // send to destination mature holding vault
            IERC20(depositToken).safeTransfer(destination, totalWithdrawn);
        }
    }

    /// @notice this returns the amounts accrued by the vault BEFORE Convex or our fees are deducted
    /// @return rewardTokens The reward tokens earned
    /// @return amountEarned The amount of each reward token earned
    /// @dev This does not return reliable values if the frax farm reward period has entered a new round && the farm has not claimed it's new rewards yet (checkpointed)
    function earned() public view returns (address[] memory rewardTokens, uint256[] memory amountEarned) {
        // this function will only work if the farm has been sync'd during the current reward period
        require(
            IFraxFarmERC20(IConvexVault(depositVault).stakingAddress()).periodFinish() 
            >= block.timestamp, 
            "!periodFinish"
        );

        // call vault's `earned` to obtain token addresses & amounts earned
        (rewardTokens, amountEarned) = IConvexVault(depositVault).earned();

        // loop through the tokens and apply our fee (& convex fee if it is FXS)
        uint256 numTokens = rewardTokens.length;
        for (uint256 i; i < numTokens; i++) {
            // if FXS, deduct the Convex fee
            if (rewardTokens[i] == FXS) {
                uint256 convexFee = IConvexFeeRegistry(CONVEX_FEE_REGISTRY).totalFees();
                require(convexFee <= FEE_DENOMINATOR, "!convexFee");
                amountEarned[i] -= (amountEarned[i] * convexFee / FEE_DENOMINATOR);
            }

            // calculate our fee
            uint256 fee = (amountEarned[i] * IFeeManager(feeManager).rewardsFee() / FEE_DENOMINATOR);

            // if there's a fee, deduct it before returning earned amonuts
            if (fee > 0) {
                amountEarned[i] -= fee;
            }
        }
    }

    /// @notice Allows anyone to claim this vault's rewards, regardless of whether the epoch has finished
    /// @return rewardTokens The reward tokens earned
    /// @return amountEarned The amount of each reward token earned
    /// @dev sends reward tokens to the reward distributor checkpointer for later posting/distribution
    function claimRewards() public returns (address[] memory rewardTokens, uint256[] memory amountEarned) {
        // call vault's `earned` to obtain token addresses & amounts earned
        (rewardTokens, amountEarned) = IConvexVault(depositVault).earned();

        // claim rewards from convex vault
        IConvexVault(depositVault).getReward();

        address feeAddress = IFeeManager(feeManager).feeAddress();
        // update with any other rewards in here
        uint256 numTokens = rewardTokens.length;
        for (uint256 i; i < numTokens; i++) {
            // convex doesn't return the correct amounts earned due to their fee, so build those values here
            amountEarned[i] = IERC20(rewardTokens[i]).balanceOf(address(this));

            // calculate if there's a fee
            /// @dev Note that rewardsFee MUST be less than FEE_DENOMINATOR, which is checked on setting the fee @ FeeManager
            uint256 fee = (amountEarned[i] * IFeeManager(feeManager).rewardsFee() / FEE_DENOMINATOR);
            
            // if there's a fee, send it to the fee address
            if (fee > 0) {
                amountEarned[i] -= fee;
                IERC20(rewardTokens[i]).transfer(feeAddress, fee);
                emit FeeSent(rewardTokens[i], fee);
            }

            // send the reward token with updated balances to the reward destination
            IERC20(rewardTokens[i]).transfer(IFeeManager(feeManager).rewardsAddress(), amountEarned[i]);
        }

        emit RewardsClaimed(rewardTokens, amountEarned, numTokens);

        return (rewardTokens, amountEarned);
    }

    /// @notice Allows the owner (custodian) to rescue any ERC20 tokens sent to this contract
    function rescue(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner, _amount);
        emit TokenRescued(owner, _token, _amount);
    }

    /// @notice Allows the owner (custodian) to set vault variables
    function setVars(bytes calldata _data) external onlyOwner {
        /// Do nothing
    }

    /// @notice Allows custodian to transfer ownership of this vault to a new address
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "!addr(0)");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }


    /////////// Events ///////////

    /// @dev note that most events are emitted in other contracts
    event FeeSent(address _token, uint256 _amount);
    /// @notice Emitted when rewards are claimed & allows for easy off-chain tracking of rewards
    event RewardsClaimed(address[] _rewardTokens, uint256[] _amounts, uint256 indexed _numberOfRewardTkns);
    event TokenRescued(address indexed _receiver, address indexed _token, uint256 indexed _amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20Upgradeable token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && AddressUpgradeable.isContract(address(token));
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/** solhint-disable */

/**
*  NOTE - this is the non-transferrable vault version!
*/

interface IConvexBooster {
    function createVault(uint256 _pid) external returns (address);
}

interface IConvexFeeRegistry {
    function totalFees() external view returns (uint256);
}

interface IConvexVault {
    function stakeLockedCurveLp(uint256 _liquidity, uint256 _secs) external returns (bytes32 kek_id);
    function stakeLockedConvexToken(uint256 _liquidity, uint256 _secs) external returns (bytes32 kek_id);
    function stakeLocked(uint256 _liquidity, uint256 _secs) external returns (bytes32 kek_id);
    function lockAdditional(bytes32 _kek_id, uint256 _addl_liq) external;
    function lockAdditionalCurveLp(bytes32 _kek_id, uint256 _addl_liq) external;
    function lockAdditionalConvexToken(bytes32 _kek_id, uint256 _addl_liq) external;
    function withdrawLocked(bytes32 _kek_id) external;
    function withdrawLockedAndUnwrap(bytes32 _kek_id) external;

    function earned() external view  returns (address[] memory token_addresses, uint256[] memory total_earned);
    function getReward() external;
    function getReward(bool _claim) external;
    function getReward(bool _claim, address[] calldata _rewardTokenList) external;

    function stakingAddress() external view returns (address);
    function stakingToken() external view returns (address);
    function curveLpToken() external view returns (address);
    function convexDepositToken() external view returns (address);
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/** solhint-disable */

/// NOTE - setting this up with the non-transferrable version for now!
interface IFraxFarmERC20 {
    
    struct LockedStake {
        bytes32 kek_id;
        uint256 start_timestamp;
        uint256 liquidity;
        uint256 ending_timestamp;
        uint256 lock_multiplier; 
    }

    function owner() external view returns (address);
    function stakingToken() external view returns (address);
    function fraxPerLPToken() external view returns (uint256);
    function calcCurCombinedWeight(address account) external view
        returns (
            uint256 old_combined_weight,
            uint256 new_vefxs_multiplier,
            uint256 new_combined_weight
        );
    function lockedStakesOf(address account) external view returns (LockedStake[] memory);
    function lockedStakesOfLength(address account) external view returns (uint256);
    function lockAdditional(bytes32 kek_id, uint256 addl_liq) external;
    function lockLonger(bytes32 kek_id, uint256 new_ending_ts) external;
    function stakeLocked(uint256 liquidity, uint256 secs) external returns (bytes32);
    function withdrawLocked(bytes32 kek_id, address destination_address) external returns (uint256);

    function unlockStakes() external;

    function periodFinish() external view returns (uint256);
    function rewardsDuration() external view returns (uint256);
    function getAllRewardTokens() external view returns (address[] memory);
    function earned(address account) external view returns (uint256[] memory new_earned);
    function totalLiquidityLocked() external view returns (uint256);
    function lockedLiquidityOf(address account) external view returns (uint256);
    function totalCombinedWeight() external view returns (uint256);
    function combinedWeightOf(address account) external view returns (uint256);
    function lockMultiplier(uint256 secs) external view returns (uint256);
    function rewardRates(uint256 token_idx) external view returns (uint256 rwd_rate);

    function userStakedFrax(address account) external view returns (uint256);
    function proxyStakedFrax(address proxy_address) external view returns (uint256);
    function maxLPForMaxBoost(address account) external view returns (uint256);
    function minVeFXSForMaxBoost(address account) external view returns (uint256);
    function minVeFXSForMaxBoostProxy(address proxy_address) external view returns (uint256);
    function veFXSMultiplier(address account) external view returns (uint256 vefxs_multiplier);

    function toggleValidVeFXSProxy(address proxy_address) external;
    function proxyToggleStaker(address staker_address) external;
    function stakerSetVeFXSProxy(address proxy_address) external;
    function getReward(address destination_address) external returns (uint256[] memory);
    function vefxs_max_multiplier() external view returns(uint256);
    function vefxs_boost_scale_factor() external view returns(uint256);
    function vefxs_per_frax_for_max_boost() external view returns(uint256);
    function getProxyFor(address addr) external view returns (address);

    function sync() external;
    function setRewardVars(address reward_token_address, uint256 _new_rate, address _gauge_controller_address, address _rewards_distributor_address) external;
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IRewardsDistributor {
    function register1155(address receipt) external;
    function receiptCheckpoint(
        address receipt,
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;
    
    function feeManager() external view returns (address);
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IFeeManager {
    function feeAddress() external view returns (address);
    function platformFee() external view returns (uint256);
    function rewardsFee() external view returns (uint256);
    function tradeFee() external view returns (uint256);
    function matureFee() external view returns (uint256);

    function rewardsAddress() external view returns (address);
    function rewardDistributor() external view returns (address);
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Receipt {
    function earned(uint256[] calldata tokenIds) external view returns (address[][] memory rewardTokens, uint256[][] memory amounts);

    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external;
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
    function burn(address account, uint256 id, uint256 amount) external;
    function burnBatch(address account, uint256[] calldata ids, uint256[] calldata amounts) external;

    function burnFrom(address account, uint256 id, uint256 amount) external;
    function burnBatchFrom(address account, uint256[] calldata ids, uint256[] calldata amounts) external;

    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);

    function MINTER_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function initializeReceiptContract(
        uint256 assetId, 
        address custodian,
        address depositStrategy, 
        address matureHoldingsVault,
        uint256 rewardEpochDuration,
        bytes calldata data
    ) external;

    function initializeTokenId(
        uint256 assetId, 
        address depositVault, 
        uint256 maturity, 
        bytes calldata tokenData
    ) external;
    
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
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
