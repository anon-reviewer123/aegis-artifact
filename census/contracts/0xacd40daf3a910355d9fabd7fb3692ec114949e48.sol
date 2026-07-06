// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../interfaces/curve/ICurveStableSwapNG.sol";
import "../interfaces/convex/IConvex.sol";
import "../interfaces/curve/ICrvMinter.sol";
import "../interfaces/curve/IRewardsGauge.sol";
import "./GiddyBaseStrategyV3.sol";

/**
 * @title StrategyConvexCurve
 * @notice Convex Curve strategy for Giddy V3 vaults
 * @dev Implements Convex Curve LP token staking with reward claiming and compounding
 *      Inherits from GiddyBaseStrategyV3 for common functionality
 *      Handles LP token deposits, withdrawals, and reward processing
 */
contract StrategyConvexCurve is GiddyBaseStrategyV3 {
  using SafeERC20 for IERC20;

  uint256 private constant BASE_PERCENT = 1e6;
  
  // Hardcoded Ethereum mainnet addresses
  IConvexBooster public constant BOOSTER = IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
  ICrvMinter public constant MINTER = ICrvMinter(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);
  address private constant CRV_TOKEN = 0xD533a949740bb3306d119CC777fa900bA034cd52;
  
  address public rewardPool;
  uint256 public poolId;
  
  // Curve gauge support
  address public gauge;
  
  // Configuration flags
  bool public isCrvMintable;
  bool public isCurveRewardsClaimable;

  function initialize(StrategyInitParams memory _params, address[] memory _rewards, address _rewardPool, uint256 _poolId) external initializer {
    __BaseStrategy_init(_params);

    // Add reward tokens using validated function
    for (uint256 i = 0; i < _rewards.length; i++) {
      addRewardToken(_rewards[i]);
    }

    rewardPool = _rewardPool;
    poolId = _poolId;
    
    // Initialize gauge as address(0) - can be set later via setGauge
    gauge = address(0);
    
    // Default configuration
    isCrvMintable = true;
    isCurveRewardsClaimable = true;

    IERC20(vaultToken).approve(address(BOOSTER), type(uint256).max);
    IERC20(vaultToken).approve(rewardPool, type(uint256).max);
  }

  function _deposit(uint256 amount) internal override {
    if (amount > 0) {
      if (rewardPool != address(0)) {
        // Use Convex
        IERC20(vaultToken).approve(address(BOOSTER), amount);
        BOOSTER.deposit(poolId, amount, true);
      } else {
        // Use Curve gauge directly
        IERC20(vaultToken).approve(gauge, amount);
        IRewardsGauge(gauge).deposit(amount);
      }
    }
  }

  function _withdraw(uint256 amount) internal override {
    if (amount > 0) {
      if (rewardPool != address(0)) {
        // Use Convex
        IConvexRewardPool(rewardPool).withdrawAndUnwrap(amount, false);
      } else {
        // Use Curve gauge directly
        IRewardsGauge(gauge).withdraw(amount);
      }
    }
  }

  function _balanceInDefiStrategy() internal view override returns (uint256 balance) {
    if (rewardPool != address(0)) {
      // Use Convex - check balance in reward pool
      return IERC20(rewardPool).balanceOf(address(this));
    } else {
      // Use Curve gauge - check balance in gauge
      return IRewardsGauge(gauge).balanceOf(address(this));
    }
  }

  function _claimAllRewards() internal override {
    if (rewardPool != address(0)) {
      // Use Convex
      IConvexRewardPool(rewardPool).getReward(address(this));
    } else {
      // Use Curve gauge
      if (isCrvMintable) MINTER.mint(gauge);
      if (isCurveRewardsClaimable) IRewardsGauge(gauge).claim_rewards(address(this));
    }
  }

  function _getClaimableBalance(address token) internal view override returns (uint256 claimable) {
    if (rewardPool != address(0)) {
      // Use Convex L1 - check main pool and extra rewards
      // Check if requesting CRV from main pool
      try IConvexRewardPool(rewardPool).rewardToken() returns (address mainRewardToken) {
        if (token == mainRewardToken) {
          // This is the main reward (CRV) - query main pool
          try IConvexRewardPool(rewardPool).earned(address(this)) returns (uint256 amount) {
            return amount;
          } catch {
            return 0;
          }
        }
      } catch {}
      // Check extra rewards (CVX, BOLD, etc.)
      try IConvexRewardPool(rewardPool).extraRewardsLength() returns (uint256 extraLen) {
        for (uint256 i = 0; i < extraLen; i++) {
          try IConvexRewardPool(rewardPool).extraRewards(i) returns (address extraRewardContract) {
            try IConvexVirtualRewardPool(extraRewardContract).rewardToken() returns (address extraToken) {
              if (extraToken == token) {
                // Found the token in extra rewards
                try IConvexVirtualRewardPool(extraRewardContract).earned(address(this)) returns (uint256 amount) {
                  return amount;
                } catch {
                  return 0;
                }
              }
            } catch {}
          } catch {}
        }
      } catch {}
      return 0;
    } else {
      // Use Curve gauge
      if (token == CRV_TOKEN) { 
        // CRV token - use claimable_tokens() as it's more reliable
        try IRewardsGauge(gauge).claimable_tokens(address(this)) returns (uint256 amount) {
          return amount;
        } catch {
          return 0;
        }
      } else {
        // For non-CRV tokens (BOLD, LUSD, etc.), use claimable_reward()
        try IRewardsGauge(gauge).claimable_reward(address(this), token) returns (uint256 amount) {
          return amount;
        } catch {
          return 0;
        }
      }
    }
  }

  function setConvexPid(uint256 _poolId) external onlyManager {
    setConvexPid(_poolId, false);
  }

  function setConvexPid(uint256 _poolId, bool claim) public onlyManager {
    if (poolId == _poolId) return;

    _withdraw(_balanceInDefiStrategy());
    if (claim) _claimAllRewards();

    // Update to new pool
    (address _lpToken,,, address _rewardPool,,) = BOOSTER.poolInfo(_poolId);
    require(vaultToken == _lpToken, "!lp");
    rewardPool = _rewardPool;
    poolId = _poolId;

    // Redeploy
    uint256 balance = IERC20(vaultToken).balanceOf(address(this));
    if (balance > 0) {
      _deposit(balance);
    }
  }

  function setGauge(address _gauge) external onlyManager {
    gauge = _gauge;
    if (_gauge != address(0)) {
      IERC20(vaultToken).approve(_gauge, type(uint256).max);
    }
  }

  function setCrvMintable(bool _isCrvMintable) external onlyManager {
    isCrvMintable = _isCrvMintable;
  }

  function setCurveRewardsClaimable(bool _isCurveRewardsClaimable) external onlyManager {
    isCurveRewardsClaimable = _isCurveRewardsClaimable;
  }

  function stratName() public pure override returns (string memory name) {
    return "StrategyConvexCurve";
  }

  function version() public pure override returns (string memory) {
    return "1.0";
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

interface ICurveStableSwapNG {
  function N_COINS() external view returns (uint256);
  function coins(uint256 i) external view returns (address);
  function get_balances() external view returns (uint256[] memory);
  function stored_rates() external view returns (uint256[] memory);

  function totalSupply() external view returns (uint256);
  function get_virtual_price() external view returns (uint256);

  function add_liquidity(
    uint256[] calldata _amounts,
    uint256 _min_mint_amount,
    address _receiver
  ) external returns (uint256);

  function remove_liquidity(
    uint256 _burn_amount,
    uint256[] calldata _min_amounts,
    address _receiver,
    bool _claim_admin_fees
  ) external returns (uint256[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IConvexBooster {
    function deposit(uint256 pid, uint256 amount, bool stake) external returns (bool);
    function earmarkRewards(uint256 _pid) external;
    function poolInfo(uint256 pid) external view returns (
        address lptoken,
        address token,
        address gauge,
        address crvRewards,
        address stash,
        bool shutdown
    );
}

interface IConvexBoosterL2 {
    function deposit(uint256 _pid, uint256 _amount) external returns (bool);
    function poolInfo(uint256 pid) external view returns (
        address lptoken, //the curve lp token
        address gauge, //the curve gauge
        address rewards, //the main reward/staking contract
        bool shutdown, //is this pool shutdown?
        address factory //a reference to the curve factory used to create this pool (needed for minting crv)
    );
}

// L1 Mainnet Reward Pool Interface
// Documentation: https://docs.convexfinance.com/convexfinanceintegration/baserewardpool
interface IConvexRewardPool {
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @notice Get earned CRV rewards for an account
     * @param account The account to check
     * @return The amount of CRV tokens earned
     * @dev This only returns CRV from the main pool. Extra rewards must be queried separately.
     */
    function earned(address account) external view returns (uint256);
    
    /**
     * @notice Get the reward token address (CRV on L1)
     * @return The address of the main reward token
     */
    function rewardToken() external view returns (address);
    
    /**
     * @notice Get the number of extra reward contracts
     * @return The count of extra reward contracts
     */
    function extraRewardsLength() external view returns (uint256);
    
    /**
     * @notice Get extra reward contract at index
     * @param index The index of the extra reward contract
     * @return The address of the VirtualBalanceRewardPool contract
     */
    function extraRewards(uint256 index) external view returns (address);
    
    function periodFinish() external view returns (uint256);
    function getReward() external;
    function getReward(address _account, bool _claimExtras) external;
    function getReward(address _account) external;
    function withdrawAndUnwrap(uint256 _amount, bool claim) external;
    function withdrawAllAndUnwrap(bool claim) external;
}

// VirtualBalanceRewardPool - used for extra rewards on L1
interface IConvexVirtualRewardPool {
    function rewardToken() external view returns (address);
    function earned(address account) external view returns (uint256);
}

// L2 Sidechain Reward Pool Interface
// CRITICAL: earned() returns array of (token, amount) tuples on L2, not single uint256!
// Documentation: https://docs.convexfinance.com/convexfinanceintegration/side-chain-implemention
interface IConvexRewardPoolL2 {
    struct EarnedData {
        address token;
        uint256 amount;
    }
    
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @notice Get all earned rewards for an account
     * @param account The account to check rewards for
     * @return Array of EarnedData structs (token address, amount)
     * @dev CRITICAL: This is a MUTATIVE function on L2 - it claims from sources first
     *      When querying, use staticcall/view to prevent state changes
     *      Returns ALL reward tokens in one call (no separate extraRewards)
     */
    function earned(address account) external returns (EarnedData[] memory);
    
    /**
     * @notice Get number of reward tokens
     * @return The count of reward tokens for this pool
     */
    function rewardLength() external view returns (uint256);
    
    /**
     * @notice Get reward token info at index
     * @param index The index of the reward token
     * @return token The reward token address
     * @return integral The reward integral value
     * @return remaining The remaining rewards
     */
    function rewards(uint256 index) external view returns (address token, uint256 integral, uint256 remaining);
    
    function getReward(address _account) external;
    function withdraw(uint256 _amount, bool _claim) external;
    function emergencyWithdraw(uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

/**
 * @title ICrvMinter
 * @notice Interface for Curve CRV token minter contract
 * @dev Used to mint CRV rewards from gauges
 * 
 * NETWORK ADDRESSES:
 * - Ethereum L1: 0xd061D61a4d941c39E5453435B6345Dc261C2fcE0 (hardcoded in StrategyConvexCurve)
 * - L2 Networks: Retrieved via IRewardsGauge(gauge).factory() (dynamic lookup)
 * 
 * USAGE:
 * - Call mint(gauge) to mint accumulated CRV rewards for a gauge
 * - Must be called before claiming rewards on some gauge types
 * - Not all gauges require minting (controlled by isCrvMintable flag)
 */
interface ICrvMinter {
    /**
     * @notice Mint CRV rewards for a specific gauge
     * @param _gauge The gauge address to mint CRV for
     * @dev Mints all accumulated CRV rewards to the gauge contract
     */
    function mint(address _gauge) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

/**
 * @title IRewardsGauge
 * @notice Interface for Curve liquidity gauge contracts (matches Beefy naming)
 * @dev Handles LP token staking and reward claiming in Curve gauges
 * 
 * TESTING NOTES:
 * 
 * Test #1 - Arbitrum (Gauge 0x7611DDC8b5029184f900a5a1Dca5C1610684F71e):
 * - Has CRV emissions
 * - claimable_tokens() ✅ WORKS - Returns CRV rewards (tested: 0.000542 CRV)
 * - claimable_reward(user, CRV) ❌ Returns 0 for CRV token
 * - balanceOf() ✅ WORKS - Returns staked LP tokens (tested: 0.0457 LP)
 * - reward_count() returns 1 (CRV only)
 * 
 * Test #2 - Polygon (Gauge 0x41CB0cb61C11039459Dc81DB76BD64d3EdE704F2):
 * - NO CRV emissions, has miMATIC + WMATIC rewards
 * - claimable_tokens() ✅ Returns 0 (no CRV as expected)
 * - claimable_reward(user, miMATIC) ✅ WORKS - Returns 0.0000695 miMATIC
 * - claimable_reward(user, WMATIC) ✅ Returns 0 (no rewards yet)
 * - balanceOf() ✅ WORKS - Returns 97.57 LP tokens staked
 * - reward_count() ✅ Returns 2 (WMATIC + miMATIC)
 * - reward_tokens(0) ✅ Returns WMATIC address
 * - reward_tokens(1) ✅ Returns miMATIC address
 * 
 * RECOMMENDATION:
 * - Use claimable_tokens() for CRV rewards (when gauge has CRV emissions)
 * - Use claimable_reward(user, token) for extra/non-CRV rewards
 * - Use reward_count() + reward_tokens(i) to enumerate all reward tokens
 */
interface IRewardsGauge {
    // ============ Staking Functions ============
    
    /**
     * @notice Deposit (stake) LP tokens into the gauge
     * @param _value The amount of LP tokens to deposit
     */
    function deposit(uint256 _value) external;
    
    /**
     * @notice Withdraw (unstake) LP tokens from the gauge
     * @param _value The amount of LP tokens to withdraw
     */
    function withdraw(uint256 _value) external;
    
    /**
     * @notice Get the staked balance of LP tokens for an account
     * @param account The address to check
     * @return The amount of LP tokens staked in the gauge
     */
    function balanceOf(address account) external view returns (uint256);
    
    // ============ Reward Query Functions ============
    
    /**
     * @notice Get the number of reward tokens for this gauge
     * @return The count of reward tokens
     * @dev TESTED: Returns 1 for CRV-only gauges, 2+ for gauges with extra rewards
     */
    function reward_count() external view returns (uint256);
    
    /**
     * @notice Get the reward token address at a specific index
     * @param index The index of the reward token (0-based)
     * @return The address of the reward token
     * @dev TESTED: Use with reward_count() to enumerate all reward tokens
     */
    function reward_tokens(uint256 index) external view returns (address);
    
    /**
     * @notice Get claimable CRV tokens for an account
     * @param _addr The address to check rewards for
     * @return The claimable amount of CRV tokens
     * @dev TESTED: This is the reliable method for querying CRV rewards (Arbitrum test)
     */
    function claimable_tokens(address _addr) external view returns (uint256);
    
    /**
     * @notice Get claimable amount of a specific reward token
     * @param _addr The address to check rewards for
     * @param _token The reward token address to query
     * @return The claimable amount of the specified token
     * @dev TESTED: Works for non-CRV rewards (Polygon miMATIC test), returns 0 for CRV on some gauges
     */
    function claimable_reward(address _addr, address _token) external view returns (uint256);
    
    // ============ Reward Claiming Functions ============
    
    /**
     * @notice Claim all available rewards for an address
     * @param _addr The address to claim rewards for
     * @dev Claims both CRV and any extra reward tokens
     */
    function claim_rewards(address _addr) external;
    
    // ============ Helper/Utility Functions ============
    
    /**
     * @notice Get the factory address that deployed this gauge
     * @return The factory contract address
     * @dev Used to get the CRV minter on L2 networks
     */
    function factory() external view returns (address);
    
    /**
     * @notice Get the reward contract address (if applicable)
     * @return The address of the reward contract
     */
    function reward_contract() external view returns (address);
    
    /**
     * @notice Get the BAL pseudo minter address (for Balancer gauges)
     * @return The address of the BAL pseudo minter
     */
    function bal_pseudo_minter() external view returns (address);
}


// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../libraries/GiddyLibraryV3.sol";
import "../infra/GiddyAdapterManager.sol";
import "../infra/GiddyStrategyFactory.sol";
import "../interfaces/IGiddyFeeConfig.sol";

/**
 * @title GiddyBaseStrategyV3
 * @notice Base strategy contract for Giddy V3 vaults
 * @dev Implements centralized strategy management pattern for efficient configuration
 *      Provides common functionality for all V3 strategies
 *      Child contracts override specific yield farming logic (_deposit, _withdraw, etc.)
 *      Designed to work with BeaconProxy pattern for upgradeability
 */
abstract contract GiddyBaseStrategyV3 is PausableUpgradeable, ReentrancyGuardUpgradeable {
  using SafeERC20 for IERC20;

  // ============ Structs ============

  struct StrategyInitParams {
    string name;
    address vaultToken;
    address factory;
    address vault;
  }

  struct RewardTokenInfo {
    address token;
    uint256 balance;      // held + claimable
  }

  // ============ Errors ============

  error UnauthorizedCaller(address caller);
  error StrategyPaused();
  error NotManager();
  error AdapterZapFailed();

  // ============ State Variables ============

  address public vault;
  address public vaultToken;
  address public factory;
  uint256 public lastProcessYield;
  string public name;

  // Yield Tracking
  address[] public rewardTokens;
  uint256 public lastVaultTokenBalance;
  uint256 public lastVaultTokenGrowthIndex;
  mapping(address => uint256) public lastBaseTokensGrowthIndexes;
  uint256 public performanceFees;
  uint256 public strategyGrowthIndex;
  uint256 public cumulativeYield;

  // ============ Modifiers ============

  modifier onlyVault() {
    if (_msgSender() != vault) {
      revert UnauthorizedCaller(msg.sender);
    }
    _;
  }

  modifier ifNotPaused() {
    if (paused()) revert StrategyPaused();
    if (GiddyStrategyFactory(factory).globalPause() || GiddyStrategyFactory(factory).strategyPause(stratName())) revert StrategyPaused();
    _;
  }

  modifier onlyManager() {
    _checkManager();
    _;
  }

  // ============ Initialization ============

  /**
   * @notice Initialize the base strategy
   * @param params Struct containing all strategy initialization parameters
   * @dev This function should be called by child contracts in their initialize function
   */
  function __BaseStrategy_init(StrategyInitParams memory params) internal onlyInitializing {
    require(params.vaultToken != address(0), "Invalid vaultToken address");
    require(params.factory != address(0), "Invalid factory address");
    require(params.vault != address(0), "Invalid vault address");

    __Pausable_init();
    __ReentrancyGuard_init();

    vaultToken = params.vaultToken;
    factory = params.factory;
    vault = params.vault;
    name = params.name;
    strategyGrowthIndex = 1e18;
    
    GiddyAdapterManager adapter = _adapterManager();
    
    // Initialize growth index tracking
    if (adapter.getTokenAdapter(vaultToken) != address(0)) {
      lastVaultTokenGrowthIndex = adapter.getGrowthIndex(vaultToken);
      
      address[] memory baseTokens = adapter.getBaseTokens(vaultToken);
      uint256 len = baseTokens.length;
      for (uint256 i = 0; i < len; ++i) {
        address baseToken = baseTokens[i];
        if (adapter.getTokenAdapter(baseToken) != address(0)) {
          try adapter.getGrowthIndex(baseToken) returns (uint256 index) {
            lastBaseTokensGrowthIndexes[baseToken] = index;
          } catch {
            lastBaseTokensGrowthIndexes[baseToken] = 1e18;
          }
        } else {
          lastBaseTokensGrowthIndexes[baseToken] = 1e18;
        }
      }
    } else {
      lastVaultTokenGrowthIndex = 1e18;
    }
  }

  // ============ Core Operations ============

  function deposit(uint256[] calldata amounts) external onlyVault ifNotPaused nonReentrant {
    address adapter = _adapterManager().getTokenAdapter(vaultToken);
    if (adapter != address(0)) {
      (bool success,) = adapter.delegatecall(
        abi.encodeWithSignature("zapIn(address,uint256[])", vaultToken, amounts)
      );
      if (!success) {
        revert AdapterZapFailed();
      }
    }
    _deposit(_balanceInContract());
    lastVaultTokenBalance = balanceOf();
  }

  function withdraw(uint256 amount) external onlyVault ifNotPaused nonReentrant {
    uint256 stakedBalance = _balanceInDefiStrategy();
    uint256 toWithdraw = amount > stakedBalance ? stakedBalance : amount;
    _withdraw(toWithdraw);

    address adapter = _adapterManager().getTokenAdapter(vaultToken);
    if (adapter == address(0)) {
      IERC20(vaultToken).safeTransfer(vault, amount);
    } else {
      (bool success, ) = adapter.delegatecall(abi.encodeWithSignature("zapOut(address,uint256,address)", vaultToken, amount, vault));
      if (!success) {
        revert AdapterZapFailed();
      }
    }
    lastVaultTokenBalance = balanceOf();
  }

  // ============ Yield Processing ============

  /**
   * @notice Record yield and accumulate performance fees
   * @dev Only callable by the vault contract
   * @return yieldRecorded Amount of yield recorded
   */
  function recordYield() external onlyVault returns (uint256 yieldRecorded) {
    
    GiddyAdapterManager adapter = _adapterManager();
    IGiddyFeeConfig feeConfig = _giddyFeeConfig();
   
    // 1) Calculate yield from vault token quantity increasing
    uint256 vaultYield1 = balanceOf() - lastVaultTokenBalance;
    
    // 2) Calculate yield from vault token value increasing via growth index
    uint256 vaultYield2 = 0;
    if (adapter.getTokenAdapter(vaultToken) != address(0)) {
      uint256 currentGrowthIndex = adapter.getGrowthIndex(vaultToken);
      if (currentGrowthIndex > lastVaultTokenGrowthIndex) {
        // Calculate yield based on growth index change: ((current - previous) / previous) * balance
        vaultYield2 = ((currentGrowthIndex - lastVaultTokenGrowthIndex) * lastVaultTokenBalance) / lastVaultTokenGrowthIndex;
        lastVaultTokenGrowthIndex = currentGrowthIndex;
      }
    }
    
    // 3) Calculate yield from component tokens
    uint256 tokenYield = _calculateTokenYield();
    
    // TOTAL YIELD since last processing (no reward yield calculation, no compounding)
    uint256 totalYield = vaultYield1 + vaultYield2 + tokenYield;
        
    // Calculate and accumulate PERFORMANCE FEES
    uint256 feeRate = feeConfig.getPerformanceFee(address(this), stratName());
    uint256 performanceFeeAmount;
    unchecked { // Safe: totalYield * feeRate < 2^256 (feeRate <= 10000)
      performanceFeeAmount = (totalYield * feeRate) / 10000; // Basis points
    }
    if (performanceFeeAmount > 0) {
      // Add fee to performanceFees instead of transferring immediately
      performanceFees += performanceFeeAmount;
      totalYield -= performanceFeeAmount; // Update total yield to reflect fee deduction
    }
    
    // Update CUMULATIVE YIELD earned and STRATEGY GROWTH INDEX (after fees)
    if (lastVaultTokenBalance > 0 && totalYield > 0) {
      cumulativeYield += totalYield;
      // Formula: newIndex = currentIndex * (1 + yield/balance)
      strategyGrowthIndex = strategyGrowthIndex + (strategyGrowthIndex * totalYield) / lastVaultTokenBalance;
    }
    
    // Update state for next processing
    lastVaultTokenBalance = balanceOf();
    lastProcessYield = block.timestamp;
    return totalYield;
  }

  /**
   * @notice Collect accumulated performance fees and send to fee recipient
   */
  function collectFees() external onlyManager {
    if (performanceFees == 0) {
      return;
    }

    uint256 amountToCollect = performanceFees;
    performanceFees = 0; // Reset before external calls

    GiddyAdapterManager adapter = _adapterManager();

    if (adapter.getTokenAdapter(vaultToken) != address(0)) {
      address[] memory baseTokens = adapter.getBaseTokens(vaultToken);
      address recipient = _giddyFeeRecipient();
      uint256 len = baseTokens.length;
      for (uint256 i = 0; i < len; ++i) {
        uint256 balance = IERC20(baseTokens[i]).balanceOf(address(this));
        if (balance > 0) {
          IERC20(baseTokens[i]).safeTransfer(recipient, balance);
        }
      }
    } else {
      IERC20(vaultToken).safeTransfer(_giddyFeeRecipient(), amountToCollect);
    }
  }

  /**
   * @notice Swap reward tokens to base tokens using provided swap data
   * @param swaps Array of swap operations to convert reward tokens to base tokens
   * @dev Called by vault to swap claimed rewards to base tokens
   *      Claims rewards, swaps to base tokens, only swaps tokens that meet threshold
   *      Swaps are structured as: for each reward token, swaps to each base token
   * @return amounts Array of base token amounts received from swaps
   */
  function swapRewardTokens(SwapInfo[] calldata swaps) external onlyVault ifNotPaused nonReentrant returns (uint256[] memory amounts) {
    _claimAllRewards();
    
    address[] memory baseTokens = _adapterManager().getBaseTokens(vaultToken);
    uint256 baseTokensLength = baseTokens.length;
    uint256 swapsLength = swaps.length;
    amounts = new uint256[](baseTokensLength);
    
    // Execute all configured reward token swaps
    for (uint256 i = 0; i < swapsLength; ++i) {
      SwapInfo calldata swap = swaps[i];
      if (swap.amount == 0) continue;

      uint256 baseTokenIndex = i % baseTokensLength;

      uint256 amountReceived = GiddyLibraryV3.executeSwap(swap, address(this), address(this));
      amounts[baseTokenIndex] += amountReceived;
    }
    
    return amounts;
  }

  // ============ View Functions (Public) ============

  function getBaseTokens() external view virtual returns (address[] memory tokens) {
    tokens = _adapterManager().getBaseTokens(vaultToken);
  }

  function getBaseRatios() external view virtual returns (uint256[] memory ratios) {
    ratios = _adapterManager().getBaseRatios(vaultToken);
  }

  function getBaseAmounts(uint256 amount) external view virtual returns (uint256[] memory amounts) {
    amounts = _adapterManager().getBaseAmounts(vaultToken, amount);
  }

  function balanceOf() public view returns (uint256) {
    return _balanceInContract() + _balanceInDefiStrategy() - performanceFees;
  }

  function getRewardTokens() public view returns (address[] memory tokens) {
    return rewardTokens;
  }

  function getRewardInfo() external view returns (RewardTokenInfo[] memory info) {
    info = new RewardTokenInfo[](rewardTokens.length);
    for (uint256 i = 0; i < rewardTokens.length; i++) {
      address token = rewardTokens[i];
      uint256 heldBalance = 0;
      uint256 claimableBalance = 0;
      // Get held balance (already claimed rewards in contract)
      try IERC20(token).balanceOf(address(this)) returns (uint256 balance) {
        heldBalance = balance;
      } catch {
        heldBalance = 0;
      }
      claimableBalance = _getClaimableBalance(token); // Get claimable balance (not yet claimed)
      info[i] = RewardTokenInfo({
        token: token,
        balance: heldBalance + claimableBalance
      });
    }
    return info;
  }

  function isAuthorizedSigner(address _signer) public view returns (bool) {
    return GiddyStrategyFactory(factory).isAuthorizedSigner(_signer);
  }

  function getAPY() external view virtual returns (uint256 apy) {
    return 0;
  }

  function getTvl() public view virtual returns (uint256 tvl) {
    if (_adapterManager().getTokenAdapter(vaultToken) != address(0)) {
      try _adapterManager().getTvl(vaultToken) returns (uint256 adapterTvl) {
        return adapterTvl;
      } catch {
        
        return balanceOf(); // Fall back to strategy balance if adapter call fails
      }
    }
    return balanceOf(); // Default implementation returns strategy balance
  }

  function getLiveApr() public view virtual returns (uint256 apr) {
    if (_adapterManager().getTokenAdapter(vaultToken) != address(0)) {
      try _adapterManager().getLiveApr(vaultToken) returns (uint256 adapterApr) {
        return adapterApr;
      } catch {
        return 0; // Fall back to 0 if adapter call fails
      }
    }
    return 0; // Default implementation returns 0 - child contracts should override
  }

  function baseVersion() external pure returns (string memory) {
    return "3.0.0";
  }

  // ============ Management Functions ============

  function panic() external onlyManager {
    pause();
    uint256 balance = _balanceInDefiStrategy();
    if (balance > 0) {
      _withdraw(balance);
    }
  }

  function pause() public onlyManager {
    _pause();
  }

  function unpause() external onlyManager {
    _unpause();
  }

  function rescueToken(
    address token,
    address to,
    uint256 amount
  ) external onlyManager {
    require(token != vaultToken, "Cannot rescue vaultToken");
    require(to != address(0), "Invalid recipient");
    
    IERC20(token).safeTransfer(to, amount);
  }

  function addRewardToken(address token) public onlyManager {
    require(token != address(0), "Invalid token");
    require(token != vaultToken, "Cannot add vault token");

    rewardTokens.push(token);
  }

  function removeRewardToken(uint256 index) external onlyManager {
    require(index < rewardTokens.length, "Index out of bounds");

    // Swap with last element and pop
    rewardTokens[index] = rewardTokens[rewardTokens.length - 1];
    rewardTokens.pop();
  }

  function resetRewardTokens() external onlyManager {
    // Clear array
    delete rewardTokens;
  }

  // ============ Internal Helper Functions ============

  function _balanceInContract() internal view returns (uint256) {
    return IERC20(vaultToken).balanceOf(address(this));
  }

  function _adapterManager() internal view returns (GiddyAdapterManager) {
    return GiddyAdapterManager(GiddyStrategyFactory(factory).adapterManager());
  }

  function _giddyFeeConfig() internal view returns (IGiddyFeeConfig) {
    return IGiddyFeeConfig(GiddyStrategyFactory(factory).feeConfig());
  }

  function _giddyFeeRecipient() internal view returns (address) {
    return _giddyFeeConfig().feeRecipient();
  }

  function _performanceFee() internal view returns (uint256 fee) {
    return _giddyFeeConfig().getPerformanceFee(address(this), stratName());
  }

  function _checkManager() internal view {
    if (!GiddyStrategyFactory(factory).isKeeper(msg.sender)) revert NotManager();
  }

  /**
   * @notice Calculate token yield from base tokens and update their tracked growth indexes
   * @return tokenYield Total yield from base tokens
   */
  function _calculateTokenYield() internal returns (uint256 tokenYield) {
    GiddyAdapterManager adapter = _adapterManager();
    address[] memory baseTokens = adapter.getBaseTokens(vaultToken);
    
    uint256 len = baseTokens.length;
    for (uint256 i = 0; i < len; ++i) {
      address baseToken = baseTokens[i];
      
      if (adapter.getTokenAdapter(baseToken) != address(0)) {
        try adapter.getGrowthIndex(baseToken) returns (uint256 currentIndex) {
          uint256 lastIndex = lastBaseTokensGrowthIndexes[baseToken];
          
          if (currentIndex > lastIndex) {
            unchecked {
              uint256 baseTokenYield = ((currentIndex - lastIndex) * lastVaultTokenBalance) / lastIndex;
              tokenYield += baseTokenYield;
            }
            lastBaseTokensGrowthIndexes[baseToken] = currentIndex;
          }
        } catch {
          // Skip this base token if growth index call fails
        }
      }
    }
    
    return tokenYield;
  }

  // ============ Abstract Functions for Child Contracts ============

  function _deposit(uint256 amount) internal virtual;
  function _withdraw(uint256 amount) internal virtual;
  function _balanceInDefiStrategy() internal view virtual returns (uint256 balance) {return IERC20(vaultToken).balanceOf(address(this));}
  function _getClaimableBalance(address /* token */) internal view virtual returns (uint256 claimable) {return 0;}
  function _claimAllRewards() internal virtual {}
  function stratName() public view virtual returns (string memory name);
  function version() public pure virtual returns (string memory);
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
// OpenZeppelin Contracts (last updated v5.3.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

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
    /// @custom:storage-location erc7201:openzeppelin.storage.Pausable
    struct PausableStorage {
        bool _paused;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Pausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PausableStorageLocation = 0xcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300;

    function _getPausableStorage() private pure returns (PausableStorage storage $) {
        assembly {
            $.slot := PausableStorageLocation
        }
    }

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

    function __Pausable_init() internal onlyInitializing {
    }

    function __Pausable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        PausableStorage storage $ = _getPausableStorage();
        return $._paused;
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
        PausableStorage storage $ = _getPausableStorage();
        $._paused = true;
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
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;
import {Initializable} from "../proxy/utils/Initializable.sol";

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
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
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
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    /// @custom:storage-location erc7201:openzeppelin.storage.ReentrancyGuard
    struct ReentrancyGuardStorage {
        uint256 _status;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ReentrancyGuardStorageLocation = 0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    function _getReentrancyGuardStorage() private pure returns (ReentrancyGuardStorage storage $) {
        assembly {
            $.slot := ReentrancyGuardStorageLocation
        }
    }

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        $._status = NOT_ENTERED;
    }

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
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if ($._status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        $._status = ENTERED;
    }

    function _nonReentrantAfter() private {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        $._status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        ReentrancyGuardStorage storage $ = _getReentrancyGuardStorage();
        return $._status == ENTERED;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct SwapInfo {
  address fromToken;
  address toToken;
  uint256 amount;
  address aggregator;
  bytes data;
}

library GiddyLibraryV3 {
  using SafeERC20 for IERC20;

  address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function executeSwap(SwapInfo calldata swap, address srcAccount, address dstAccount) internal returns (uint256 returnAmount) {
    bool isFromTokenNative = swap.fromToken == NATIVE_TOKEN || swap.fromToken == address(0);
    bool isToTokenNative = swap.toToken == NATIVE_TOKEN || swap.toToken == address(0);

    if (!isFromTokenNative) {
      SafeERC20.safeIncreaseAllowance(IERC20(swap.fromToken), swap.aggregator, swap.amount);
    }

    uint256 srcBalanceBefore = isFromTokenNative ? srcAccount.balance : IERC20(swap.fromToken).balanceOf(srcAccount);
    uint256 dstBalanceBefore = isToTokenNative ? dstAccount.balance : IERC20(swap.toToken).balanceOf(dstAccount);
    
    (bool swapSuccess, ) = isFromTokenNative ? swap.aggregator.call{value: swap.amount}(swap.data) : swap.aggregator.call(swap.data);

    if (!swapSuccess) {
      revert("SWAP_CALL_FAILED");
    }
    
    uint256 srcBalanceAfter = isFromTokenNative ? srcAccount.balance : IERC20(swap.fromToken).balanceOf(srcAccount);
    uint256 actualSrcChange = srcBalanceBefore - srcBalanceAfter;
    require(actualSrcChange > 0 && actualSrcChange <= swap.amount, "INVALID_SRC_BALANCE_CHANGE");

    uint256 dstBalanceAfter = isToTokenNative ? dstAccount.balance : IERC20(swap.toToken).balanceOf(dstAccount);
    returnAmount = dstBalanceAfter - dstBalanceBefore;
    require(returnAmount > 0, "SWAP_NO_TOKENS_RECEIVED");
  }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IGiddyDefiAdapter.sol";
import "./GiddyStrategyFactory.sol";

contract GiddyAdapterManager is Initializable, OwnableUpgradeable {
  using SafeERC20 for IERC20;

  address public strategyFactory;
  mapping(address => bytes32) public tokenMap;
  mapping(bytes32 => address) public adapterMap;

  event AdapterSet(string adapterName, address adapterAddress);
  event TokenAdapterSet(address token, string adapterName);

  error NotManager();
  error InvalidAdapter();

  function initialize(address _strategyFactory) public initializer {
    __Ownable_init(_msgSender());
    strategyFactory = _strategyFactory;
  }

  modifier onlyManager() {
    if (!GiddyStrategyFactory(strategyFactory).keepers(msg.sender)) revert NotManager();
    _;
  }

  function getBaseTokens(address defiToken) external view returns (address[] memory tokens) {
    address adapter = getTokenAdapter(defiToken);
    if (adapter == address(0)) {
      tokens = new address[](1);
      tokens[0] = defiToken;
    } else {
      tokens = IGiddyDefiAdapter(adapter).getBaseTokens(defiToken);
    }
  }

  function getBaseRatios(address defiToken) external view returns (uint256[] memory ratios) {
    address adapter = getTokenAdapter(defiToken);
    if (adapter == address(0)) {
      ratios = new uint256[](1);
      ratios[0] = 1e18; // 100% ratio
    } else {
      ratios = IGiddyDefiAdapter(adapter).getBaseRatios(defiToken);
    }
  }

  function getBaseAmounts(address defiToken, uint defiAmount) external view returns (uint256[] memory baseAmounts) {
    address adapter = getTokenAdapter(defiToken);
    if (adapter == address(0)) {
      baseAmounts = new uint256[](1);
      baseAmounts[0] = defiAmount;
    } else {
      baseAmounts = IGiddyDefiAdapter(adapter).getBaseAmounts(defiToken, defiAmount);
    }
  }

  function getBaseComposition(address defiToken) external view returns (uint256[] memory ratios) {
    address adapter = getTokenAdapter(defiToken);
    if (adapter == address(0)) {
      ratios = new uint256[](0);
    } else {
      ratios = IGiddyDefiAdapter(adapter).getBaseComposition(defiToken);
    }
  }

  function getGrowthIndex(address defiToken) external view returns (uint256 index) {
    address adapter = getTokenAdapter(defiToken);
    if (adapter == address(0)) {
      index = 1e18; // Return 1:1 ratio if no adapter
    } else {
      index = IGiddyDefiAdapter(adapter).getGrowthIndex(defiToken);
    }
  }

  function getTvl(address token) external view returns (uint256 defiAmount) {
    address adapter = getTokenAdapter(token);
    if (adapter == address(0)) {
      defiAmount = 0;
    } else {
      defiAmount = IGiddyDefiAdapter(adapter).getTvl(token);
    }
  }

  function getLiveApr(address token) external view returns (uint256 apr) {
    // Live APR in basis points (e.g., 500 = 5%)
    address adapter = getTokenAdapter(token);
    if (adapter == address(0)) {
      apr = 0;
    } else {
      apr = IGiddyDefiAdapter(adapter).getLiveApr(token);
    }
  }

  function setAdapter(string memory adapterName, address adapterAddress) public onlyManager {
    if (bytes(adapterName).length == 0) revert InvalidAdapter();
    adapterMap[keccak256(bytes(adapterName))] = adapterAddress;
    emit AdapterSet(adapterName, adapterAddress);
  }

  function getAdapter(string memory adapterName) public view returns (address adapterAddress) {
    return adapterMap[keccak256(bytes(adapterName))];
  }

  function setTokenAdapter(address token, string memory adapterName) public onlyManager {
    if (bytes(adapterName).length == 0) revert InvalidAdapter();
    tokenMap[token] = keccak256(bytes(adapterName));
    emit TokenAdapterSet(token, adapterName);
  }

  function getTokenAdapter(address token) public view returns (address adapterAddress) {
    return adapterMap[tokenMap[token]];
  }

  function hasAdapter(address token) public view returns (bool) {
    return adapterMap[tokenMap[token]] != address(0);
  }
}
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title GiddyStrategyFactory
 * @notice Factory contract for deploying Giddy strategies using BeaconProxy pattern
 * @dev Implements BeaconProxy pattern for gas-efficient strategy deployment
 *      Implements centralized strategy management with pause controls
 */
contract GiddyStrategyFactory is OwnableUpgradeable {


    // ============ State Variables ============

    /// @notice Instance mapping to strategy name with version
    mapping (string => UpgradeableBeacon) public instances;

    /// @notice Deployed strategy types
    string[] public strategyTypes;

    /// @notice Mapping of keeper addresses
    mapping(address => bool) public keepers;

    /// @notice Pause state by strategy name
    mapping(string => bool) public strategyPause;

    /// @notice The fee config address
    address public feeConfig;

    /// @notice The adapter manager address
    address public adapterManager;

    /// @notice The authorized signer address for vault operations
    address public authorizedSigner;

    /// @notice Global pause state for all strategies
    bool public globalPause;

    /// @notice Mapping of authorized signer addresses for vault operations
    mapping(address => bool) public authorizedSigners;

    // ============ Errors ============

    error NotManager();

    // ============ Modifiers ============

    /// @notice Throws if called by any account other than the owner or a keeper
    modifier onlyManager() {
        if (msg.sender != owner() && !keepers[msg.sender]) revert NotManager();
        _;
    }

    // ============ Constructor ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the factory
     * @param _owner Owner of the contract
     */
    function initialize(address _owner) external initializer {
        require(_owner != address(0), "Invalid owner address");
        __Ownable_init(_owner);
    }

        // ============ Core Functions ============

    /**
     * @notice Add a new strategy beacon to the factory
     * @param _strategyName Name of the strategy
     * @param _implementation Implementation address
     */
    function addStrategyBeacon(string calldata _strategyName, address _implementation) external onlyManager {
        require(address(instances[_strategyName]) == address(0), "Strategy type already exists");

        instances[_strategyName] = new UpgradeableBeacon(_implementation, address(this));
        strategyTypes.push(_strategyName);
    }

    /**
     * @notice Create a new strategy proxy
     * @param _strategyName Type of strategy to create
     * @return strategy Address of the created strategy proxy
     */
    function createStrategyProxy(string calldata _strategyName) external onlyManager returns (address strategy) {
        UpgradeableBeacon instance = instances[_strategyName];
        require(address(instance) != address(0), "Strategy type not found");
        
        BeaconProxy proxy = new BeaconProxy(address(instance), "");
        strategy = address(proxy);
        return strategy;
    }

    /**
     * @notice Upgrade the implementation of a strategy beacon
     * @param _strategyName Name of the strategy
     * @param _newImplementation New implementation address
     */
    function upgradeStrategyBeacon(string calldata _strategyName, address _newImplementation) external onlyOwner {
        UpgradeableBeacon instance = instances[_strategyName];
        require(address(instance) != address(0), "Strategy type not found");
        
        instance.upgradeTo(_newImplementation);
    }

    // ============ Pause Management ============

    /**
     * @notice Set global pause state
     * @param _paused Whether to pause all strategies
     */
    function setGlobalPause(bool _paused) external onlyManager {
        globalPause = _paused;
    }

    /**
     * @notice Set strategy-specific pause state
     * @param strategyName Name of the strategy
     * @param _paused Whether to pause the strategy
     */
    function setStrategyPause(string calldata strategyName, bool _paused) external onlyManager {
        strategyPause[strategyName] = _paused;
    }

    // ============ Management Functions ============

    /**
     * @notice Add a keeper address
     * @param _keeper Keeper address to add
     */
    function addKeeper(address _keeper) external onlyOwner {
        require(_keeper != address(0), "Invalid keeper address");
        require(!keepers[_keeper], "Keeper already exists");
        keepers[_keeper] = true;
    }

    /**
     * @notice Remove a keeper address
     * @param _keeper Keeper address to remove
     */
    function removeKeeper(address _keeper) external onlyOwner {
        require(keepers[_keeper], "Keeper does not exist");
        keepers[_keeper] = false;
    }

    /**
     * @notice Check if an address is a keeper
     * @param _keeper Address to check
     * @return isKeeper Whether the address is a keeper
     */
    function isKeeper(address _keeper) external view returns (bool) {
        return keepers[_keeper];
    }

    /**
     * @notice Set the fee config address
     * @param _feeConfig New fee config address
     */
    function setFeeConfig(address _feeConfig) external onlyOwner {
        require(_feeConfig != address(0), "Invalid fee config address");
        feeConfig = _feeConfig;
    }

    /**
     * @notice Set the adapter manager address
     * @param _adapterManager New adapter manager address
     */
    function setAdapterManager(address _adapterManager) external onlyOwner {
        require(_adapterManager != address(0), "Invalid adapter manager address");
        adapterManager = _adapterManager;
    }

    /**
     * @notice Set the authorized signer address
     * @param _authorizedSigner New authorized signer address
     * @param _authorized Whether the signer is authorized
     */
    function setAuthorizedSigner(address _authorizedSigner, bool _authorized) external onlyOwner {
      authorizedSigners[_authorizedSigner] = _authorized;
    }

    /**
     * @notice Check if an address is an authorized signer
     * @param _signer Address to check
     * @return Whether the address is an authorized signer
     */
    function isAuthorizedSigner(address _signer) external view returns (bool) {
      return authorizedSigners[_signer];
    }

    // ============ View Functions ============

    /**
     * @notice Get the implementation of a strategy type
     * @param _strategyName Name of the strategy
     * @return Implementation address
     */
    function getImplementation(string calldata _strategyName) external view returns (address) {
        return instances[_strategyName].implementation();
    }

    /**
     * @notice Get the array of deployed strategy types
     * @return Array of deployed strategy types
     */
    function getStrategyTypes() external view returns (string[] memory) {
        return strategyTypes;
    }
}
// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

/**
 * @title IGiddyFeeConfig
 * @notice Interface for GiddyFeeConfig contract
 * @dev Provides access to fee configuration functions for strategies
 */
interface IGiddyFeeConfig {
    // ============ Structs ============

    /**
     * @dev Struct containing fee configuration for a vault
     * @param performanceFee Performance fee in basis points (on gains)
     */
    struct FeeConfig {
        uint256 performanceFee;     // Basis points (e.g., 2000 = 20%)
    }

    // ============ View Functions ============

    /**
     * @notice Get performance fee for a vault with hierarchical logic
     * Priority: vault-specific → category-specific → default
     * @param vault Address of the vault
     * @param category Category of the vault
     * @return performanceFee Performance fee in basis points
     */
    function getPerformanceFee(
        address vault,
        string calldata category
    ) external view returns (uint256 performanceFee);

    /**
     * @notice Get the fee recipient address
     * @return recipient Address that receives all performance fees
     */
    function feeRecipient() external view returns (address recipient);

    /**
     * @notice Get the default performance fee
     * @return fee Default performance fee in basis points
     */
    function defaultPerformanceFee() external view returns (uint256 fee);

    /**
     * @notice Get vault-specific performance fee
     * @param vault Address of the vault
     * @return hasCustomFee Whether the vault has custom performance fee
     * @return performanceFee Performance fee in basis points (if custom)
     */
    function getVaultPerformanceFee(address vault) external view returns (bool hasCustomFee, uint256 performanceFee);

    /**
     * @notice Get category-specific performance fee
     * @param category Category name
     * @return hasCustomFee Whether the category has custom performance fee
     * @return performanceFee Performance fee in basis points (if custom)
     */
    function getCategoryPerformanceFee(string calldata category) external view returns (bool hasCustomFee, uint256 performanceFee);

    // ============ State Variable Getters ============

    /**
     * @notice Check if a vault has custom fee configuration
     * @param vault Address of the vault
     * @return hasCustom Whether the vault has custom fee configuration
     */
    function hasVaultCustomFee(address vault) external view returns (bool hasCustom);



    /**
     * @notice Get vault fee configuration
     * @param vault Address of the vault
     * @return config Fee configuration for the vault
     */
    function vaultFeeConfigs(address vault) external view returns (FeeConfig memory config);

    /**
     * @notice Get category fee configuration
     * @param category Category name
     * @return config Fee configuration for the category
     */
    function categoryFeeConfigs(string calldata category) external view returns (FeeConfig memory config);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

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
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

pragma solidity >=0.6.2;

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
// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (proxy/utils/Initializable.sol)

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
        // - construction: the contract is initialized at version 1 (no reinitialization) and the
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
     * @dev Pointer to storage slot. Allows integrators to override it with a custom storage location.
     *
     * NOTE: Consider following the ERC-7201 formula to derive storage locations.
     */
    function _initializableStorageSlot() internal pure virtual returns (bytes32) {
        return INITIALIZABLE_STORAGE;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;

import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Ownable
    struct OwnableStorage {
        address _owner;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Ownable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableStorageLocation = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;

    function _getOwnableStorage() private pure returns (OwnableStorage storage $) {
        assembly {
            $.slot := OwnableStorageLocation
        }
    }

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
    function __Ownable_init(address initialOwner) internal onlyInitializing {
        __Ownable_init_unchained(initialOwner);
    }

    function __Ownable_init_unchained(address initialOwner) internal onlyInitializing {
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
        OwnableStorage storage $ = _getOwnableStorage();
        return $._owner;
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
        OwnableStorage storage $ = _getOwnableStorage();
        address oldOwner = $._owner;
        $._owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

interface IGiddyDefiAdapter {
  function getBaseTokens(address defiToken) external view returns (address[] memory tokens);
  function getBaseRatios(address defiToken) external view returns (uint256[] memory ratios);
  function getBaseComposition(address defiToken) external view returns (uint256[] memory ratios);
  function getBaseAmounts(address defiToken, uint256 defiAmount) external view returns (uint256[] memory baseAmounts);
  function getGrowthIndex(address defiToken) external view returns (uint256 index);
  function getTvl(address defiToken) external view returns (uint256 defiAmount);
  function getLiveApr(address defiToken) external view returns (uint256 apr);

  function zapIn(address defiToken, uint256[] memory baseAmounts) external;
  function zapOut(address defiToken, uint256 defiAmount, address receiver) external;  
}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (proxy/beacon/BeaconProxy.sol)

pragma solidity ^0.8.22;

import {IBeacon} from "./IBeacon.sol";
import {Proxy} from "../Proxy.sol";
import {ERC1967Utils} from "../ERC1967/ERC1967Utils.sol";

/**
 * @dev This contract implements a proxy that gets the implementation address for each call from an {UpgradeableBeacon}.
 *
 * The beacon address can only be set once during construction, and cannot be changed afterwards. It is stored in an
 * immutable variable to avoid unnecessary storage reads, and also in the beacon storage slot specified by
 * https://eips.ethereum.org/EIPS/eip-1967[ERC-1967] so that it can be accessed externally.
 *
 * CAUTION: Since the beacon address can never be changed, you must ensure that you either control the beacon, or trust
 * the beacon to not upgrade the implementation maliciously.
 *
 * IMPORTANT: Do not use the implementation logic to modify the beacon storage slot. Doing so would leave the proxy in
 * an inconsistent state where the beacon storage slot does not match the beacon address.
 */
contract BeaconProxy is Proxy {
    // An immutable address for the beacon to avoid unnecessary SLOADs before each delegate call.
    address private immutable _beacon;

    /**
     * @dev Initializes the proxy with `beacon`.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon. This
     * will typically be an encoded function call, and allows initializing the storage of the proxy like a Solidity
     * constructor.
     *
     * Requirements:
     *
     * - `beacon` must be a contract with the interface {IBeacon}.
     * - If `data` is empty, `msg.value` must be zero.
     */
    constructor(address beacon, bytes memory data) payable {
        ERC1967Utils.upgradeBeaconToAndCall(beacon, data);
        _beacon = beacon;
    }

    /**
     * @dev Returns the current implementation address of the associated beacon.
     */
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }

    /**
     * @dev Returns the beacon.
     */
    function _getBeacon() internal view virtual returns (address) {
        return _beacon;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/UpgradeableBeacon.sol)

pragma solidity ^0.8.20;

import {IBeacon} from "./IBeacon.sol";
import {Ownable} from "../../access/Ownable.sol";

/**
 * @dev This contract is used in conjunction with one or more instances of {BeaconProxy} to determine their
 * implementation contract, which is where they will delegate all function calls.
 *
 * An owner is able to change the implementation the beacon points to, thus upgrading the proxies that use this beacon.
 */
contract UpgradeableBeacon is IBeacon, Ownable {
    address private _implementation;

    /**
     * @dev The `implementation` of the beacon is invalid.
     */
    error BeaconInvalidImplementation(address implementation);

    /**
     * @dev Emitted when the implementation returned by the beacon is changed.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Sets the address of the initial implementation, and the initial owner who can upgrade the beacon.
     */
    constructor(address implementation_, address initialOwner) Ownable(initialOwner) {
        _setImplementation(implementation_);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function implementation() public view virtual returns (address) {
        return _implementation;
    }

    /**
     * @dev Upgrades the beacon to a new implementation.
     *
     * Emits an {Upgraded} event.
     *
     * Requirements:
     *
     * - msg.sender must be the owner of the contract.
     * - `newImplementation` must be a contract.
     */
    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _setImplementation(newImplementation);
    }

    /**
     * @dev Sets the implementation contract address for this beacon
     *
     * Requirements:
     *
     * - `newImplementation` must be a contract.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert BeaconInvalidImplementation(newImplementation);
        }
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

pragma solidity >=0.4.16;

import {IERC20} from "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

pragma solidity >=0.4.16;

import {IERC165} from "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (proxy/beacon/IBeacon.sol)

pragma solidity >=0.4.16;

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
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/Proxy.sol)

pragma solidity ^0.8.20;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback
     * function and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.21;

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
// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

pragma solidity >=0.4.16;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1967.sol)

pragma solidity >=0.4.11;

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
// OpenZeppelin Contracts (last updated v5.4.0) (utils/Address.sol)

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
                revert(add(returndata, 0x20), mload(returndata))
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
