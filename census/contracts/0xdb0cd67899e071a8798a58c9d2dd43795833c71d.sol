// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./MainnetPriceFeedBase.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";


contract YieldBearingStablecoinPriceFeed is MainnetPriceFeedBase {
    uint256 public constant UNDERLYING_USD_DEVIATION_THRESHOLD = 2e16; // 2%
    IERC4626 public immutable yieldBearingToken;

    constructor(
        address _underlyingUsdOracleAddress, // Underlying asset/USD oracle
        address _yieldBearingToken, // ERC4626 yield-bearing token address
        uint256 _underlyingUsdStalenessThreshold,
        address _borrowerOperationsAddress
    ) MainnetPriceFeedBase(_underlyingUsdOracleAddress, _underlyingUsdStalenessThreshold, _borrowerOperationsAddress) {

        yieldBearingToken = IERC4626(_yieldBearingToken);

        _fetchPricePrimary(false);

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    function fetchPrice() public returns (uint256, bool) {
        return _fetchPricePrimary(false);
    }

    function fetchRedemptionPrice() external returns (uint256, bool) {
        return _fetchPricePrimary(true);
    }

    function _fetchPricePrimary(bool _isRedemption) internal returns (uint256, bool) {
        // If using last good price due to oracle failure, return it
        if (priceSource == PriceSource.lastGoodPrice) {
            return (lastGoodPrice, false);
        }

        // Get underlying asset/USD price (returns in 18 decimals from _getOracleAnswer)
        (uint256 underlyingUsdPrice, bool underlyingUsdOracleDown) = _getOracleAnswer(ethUsdOracle);
        if (underlyingUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(ethUsdOracle.aggregator)), true);
        }

        // Get canonical rate from ERC4626 yield-bearing token (18 decimals)
        uint256 yieldBearingRate = yieldBearingToken.convertToAssets(1e18);
        uint256 canonicalPrice = underlyingUsdPrice * yieldBearingRate / 1e18;

        uint256 price = canonicalPrice;

        lastGoodPrice = price;
        return (price, false);
    }

    function _withinDeviationThreshold(uint256 _priceToCheck, uint256 _referencePrice, uint256 _deviationThreshold)
        internal
        pure
        returns (bool)
    {
        uint256 max = _referencePrice * (DECIMAL_PRECISION + _deviationThreshold) / DECIMAL_PRECISION;
        uint256 min = _referencePrice * (DECIMAL_PRECISION - _deviationThreshold) / DECIMAL_PRECISION;
        return _priceToCheck >= min && _priceToCheck <= max;
    }
}



// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../Dependencies/Ownable.sol";
import "../Dependencies/AggregatorV3Interface.sol";
import "../Interfaces/IMainnetPriceFeed.sol";
import "../BorrowerOperations.sol";

abstract contract MainnetPriceFeedBase is IMainnetPriceFeed {
    // Determines where the PriceFeed sources data from. Possible states:
    // - primary: Uses the primary price calcuation, which depends on the specific feed
    // - ETHUSDxCanonical: Uses Chainlink's ETH-USD multiplied by the LST' canonical rate
    // - lastGoodPrice: the last good price recorded by this PriceFeed.
    PriceSource public priceSource;

    // Last good price tracker for the derived USD price
    uint256 public lastGoodPrice;

    struct Oracle {
        AggregatorV3Interface aggregator;
        uint256 stalenessThreshold;
        uint8 decimals;
    }

    struct ChainlinkResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
    }

    error InsufficientGasForExternalCall();

    event ShutDownFromOracleFailure(address _failedOracleAddr);

    Oracle public ethUsdOracle;

    IBorrowerOperations borrowerOperations;

    constructor(address _ethUsdOracleAddress, uint256 _ethUsdStalenessThreshold, address _borrowOperationsAddress) {
        // Store ETH-USD oracle
        ethUsdOracle.aggregator = AggregatorV3Interface(_ethUsdOracleAddress);
        ethUsdOracle.stalenessThreshold = _ethUsdStalenessThreshold;
        ethUsdOracle.decimals = ethUsdOracle.aggregator.decimals();

        borrowerOperations = IBorrowerOperations(_borrowOperationsAddress);

        assert(ethUsdOracle.decimals == 8);
    }

    function _getOracleAnswer(Oracle memory _oracle) internal view returns (uint256, bool) {
        ChainlinkResponse memory chainlinkResponse = _getCurrentChainlinkResponse(_oracle.aggregator);

        uint256 scaledPrice;
        bool oracleIsDown;
        // Check oracle is serving an up-to-date and sensible price. If not, shut down this collateral branch.
        if (!_isValidChainlinkPrice(chainlinkResponse, _oracle.stalenessThreshold)) {
            oracleIsDown = true;
        } else {
            scaledPrice = _scaleChainlinkPriceTo18decimals(chainlinkResponse.answer, _oracle.decimals);
        }

        return (scaledPrice, oracleIsDown);
    }

    function _shutDownAndSwitchToLastGoodPrice(address _failedOracleAddr) internal returns (uint256) {
        // Shut down the branch
        borrowerOperations.shutdownFromOracleFailure();

        priceSource = PriceSource.lastGoodPrice;

        emit ShutDownFromOracleFailure(_failedOracleAddr);
        return lastGoodPrice;
    }

    function _getCurrentChainlinkResponse(AggregatorV3Interface _aggregator)
        internal
        view
        returns (ChainlinkResponse memory chainlinkResponse)
    {
        uint256 gasBefore = gasleft();

        // Try to get latest price data:
        try _aggregator.latestRoundData() returns (
            uint80 roundId, int256 answer, uint256, /* startedAt */ uint256 updatedAt, uint80 /* answeredInRound */
        ) {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkResponse.roundId = roundId;
            chainlinkResponse.answer = answer;
            chainlinkResponse.timestamp = updatedAt;
            chainlinkResponse.success = true;

            return chainlinkResponse;
        } catch {
            // Require that enough gas was provided to prevent an OOG revert in the call to Chainlink
            // causing a shutdown. Instead, just revert. Slightly conservative, as it includes gas used
            // in the check itself.
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();

            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }
    }

    // False if:
    // - Call to Chainlink aggregator reverts
    // - price is too stale, i.e. older than the oracle's staleness threshold
    // - Price answer is 0 or negative
    function _isValidChainlinkPrice(ChainlinkResponse memory chainlinkResponse, uint256 _stalenessThreshold)
        internal
        view
        returns (bool)
    {
        return chainlinkResponse.success && block.timestamp - chainlinkResponse.timestamp < _stalenessThreshold
            && chainlinkResponse.answer > 0;
    }

    // Trust assumption: Chainlink won't change the decimal precision on any feed used in v2 after deployment
    function _scaleChainlinkPriceTo18decimals(int256 _price, uint256 _decimals) internal pure returns (uint256) {
        // Scale an int price to a uint with 18 decimals
        return uint256(_price) * 10 ** (18 - _decimals);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC4626.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";
import "../token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface of the ERC4626 "Tokenized Vault Standard", as defined in
 * https://eips.ethereum.org/EIPS/eip-4626[ERC-4626].
 *
 * _Available since v4.7._
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

pragma solidity 0.8.24;

/**
 * Based on OpenZeppelin's Ownable contract:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol
 *
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting `initialOwner` as the initial owner.
     */
    constructor(address initialOwner) {
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     *
     * NOTE: This function is not safe, as it doesn’t check owner is calling it.
     * Make sure you check it before calling it.
     */
    function _renounceOwnership() internal {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

// SPDX-License-Identifier: MIT
// Code from https://github.com/smartcontractkit/chainlink/blob/master/evm-contracts/src/v0.6/interfaces/AggregatorV3Interface.sol

pragma solidity 0.8.24;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// SPDX-License-Identifier: MIT
import "../Interfaces/IPriceFeed.sol";
import "../Dependencies/AggregatorV3Interface.sol";

pragma solidity ^0.8.0;

interface IMainnetPriceFeed is IPriceFeed {
    enum PriceSource {
        primary,
        ETHUSDxCanonical,
        lastGoodPrice
    }

    function ethUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8);
    function priceSource() external view returns (PriceSource);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "./Dependencies/LiquityBase.sol";
import "./Dependencies/AddRemoveManagers.sol";
import "./Interfaces/IBorrowerOperations.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Interfaces/IAddressesRegistry.sol";
import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IBoldToken.sol";
import "./Interfaces/ICollSurplusPool.sol";
import "./Interfaces/ISortedTroves.sol";
import "./Types/LatestTroveData.sol";
import "./Types/LatestBatchData.sol";
import {IEbisuBorrowerOperationsHelper} from "./Interfaces/IEbisuBorrowerOperationsHelper.sol";
import {IEbisuBranchManager} from "./Interfaces/IEbisuBranchManager.sol";
import "./Dependencies/EbisuUpgradeable.sol";

contract BorrowerOperations is LiquityBase, AddRemoveManagers, IBorrowerOperations, EbisuUpgradeable {
    using SafeERC20 for IERC20;

    // --- Connected contract declarations ---

    IERC20 internal collToken;
    ITroveManager internal troveManager;
    address internal gasPoolAddress;
    ICollSurplusPool internal collSurplusPool;
    IBoldToken internal boldToken;
    IEbisuBorrowerOperationsHelper public boHelper;
    IEbisuBranchManager internal branchManager;
    // A doubly linked list of Troves, sorted by their collateral ratios
    ISortedTroves internal sortedTroves;
    // Wrapped ETH for liquidation reserve (gas compensation)
    IWETH internal WETH;

    // Shutdown system collateral ratio. If the system's total collateral ratio (TCR) for a given collateral falls below the SCR,
    // the protocol triggers the shutdown of the borrow market and permanently disables all borrowing operations except for closing Troves.
    bool public hasBeenShutDown;

    // Extra buffer of collateral ratio to join a batch or adjust a trove inside a batch (on top of MCR)
    uint256 private BCR;

    uint256 private minDebt;

    /*
     * Mapping from TroveId to granted address for interest rate setting (batch manager).
     *
     * Batch managers set the interest rate for every Trove in the batch. The interest rate is the same for all Troves in the batch.
     */
    mapping(uint256 => address) public interestBatchManagerOf;

    // Reserved for future upgrades
    uint256[50] private __gap;

    /* --- Variable container structs  ---

    Used to hold, return and assign variables inside a function, in order to avoid the error:
    "CompilerError: Stack too deep". */

    struct OpenTroveVars {
        ITroveManager troveManager;
        uint256 troveId;
        TroveChange change;
        LatestBatchData batch;
    }

    struct LocalVariables_removeFromBatch {
        ITroveManager troveManager;
        ISortedTroves sortedTroves;
        address batchManager;
        LatestTroveData trove;
        LatestBatchData batch;
        uint256 batchFutureDebt;
        TroveChange batchChange;
    }

    error IsShutDown();
    error TCRNotBelowSCR();
    error TroveExists();
    error TroveNotOpen();
    error TroveNotActive();
    error TroveNotZombie();
    error TroveWithZeroDebt();
    error UpfrontFeeTooHigh();
    error ICRBelowMCR();
    error ICRBelowMCRPlusBCR();
    error TCRBelowCCR();
    error DebtBelowMin();
    error NewOracleFailureDetected();
    error TroveNotInBatch();
    error CallerNotTroveManager();
    error CallerNotPriceFeed();
    error MintingDebtPaused();
    error DebtCapReached();
    error BatchSharesRatioTooLow();
    error CallerNotBorrowerOperationsHelper();
    error CallerNotBranchManager();
    event ShutDown(uint256 _tcr);

    constructor() {
        _disableInitializers();
    }

    //TODO: remove virtual on prod
    function initialize(address _addressesRegistryAddress)
        public
        virtual
        override(AddRemoveManagers, LiquityBase, IBorrowerOperations)
        initializer
    {
        IAddressesRegistry _addressesRegistry = IAddressesRegistry(_addressesRegistryAddress);
        LiquityBase.initialize(_addressesRegistryAddress);
        AddRemoveManagers.initialize(_addressesRegistryAddress);
        _ebisuAdminRegistry = IEbisuAdminRegistry(address(_addressesRegistry.collateralRegistry()));
  
        collToken = _addressesRegistry.collToken();
        WETH = _addressesRegistry.WETH();

        troveManager = _addressesRegistry.troveManager();
        gasPoolAddress = _addressesRegistry.gasPoolAddress();
        collSurplusPool = _addressesRegistry.collSurplusPool();
        sortedTroves = _addressesRegistry.sortedTroves();
        boldToken = _addressesRegistry.boldToken();
        boHelper = IEbisuBorrowerOperationsHelper(_addressesRegistry.borrowerOperationsHelper());
        branchManager = _addressesRegistry.branchManager();
        collToken.approve(address(activePool), type(uint256).max);
        BCR = _addressesRegistry.BCR();
        minDebt = MIN_DEBT;
        // This makes impossible to open a trove with zero withdrawn Bold
        assert(minDebt > 0);
    }

    // --- Borrower Trove Operations ---

    function openTrove(
        address _owner,
        uint256 _ownerIndex,
        uint256 _collAmount,
        uint256 _boldAmount,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _annualInterestRate,
        uint256 _maxUpfrontFee,
        address _addManager,
        address _removeManager,
        address _receiver
    ) external virtual override returns (uint256) {
        branchManager.requireValidAnnualInterestRate(_annualInterestRate);

        OpenTroveVars memory vars;

        vars.troveId = _openTrove(
            _owner,
            _ownerIndex,
            _collAmount,
            _boldAmount,
            _annualInterestRate,
            address(0),
            0,
            0,
            _maxUpfrontFee,
            _addManager,
            _removeManager,
            _receiver,
            vars.change
        );

        // Set the stored Trove properties and mint the NFT
        troveManager.onOpenTrove(_owner, vars.troveId, vars.change, _annualInterestRate);

        sortedTroves.insert(vars.troveId, _annualInterestRate, _upperHint, _lowerHint);

        return vars.troveId;
    }

    function openTroveAndJoinInterestBatchManager(OpenTroveAndJoinInterestBatchManagerParams calldata _params)
        external
        virtual
        override
        returns (uint256)
    {
        boHelper.requireValidInterestBatchManager(_params.interestBatchManager);

        OpenTroveVars memory vars;
        vars.troveManager = troveManager;

        vars.batch = vars.troveManager.getLatestBatchData(_params.interestBatchManager);

        // We set old weighted values here, as it's only necessary for batches, so we don't need to pass them to _openTrove func
        vars.change.batchAccruedManagementFee = vars.batch.accruedManagementFee;
        vars.change.oldWeightedRecordedDebt = vars.batch.weightedRecordedDebt;
        vars.change.oldWeightedRecordedBatchManagementFee = vars.batch.weightedRecordedBatchManagementFee;
        vars.troveId = _openTrove(
            _params.owner,
            _params.ownerIndex,
            _params.collAmount,
            _params.boldAmount,
            vars.batch.annualInterestRate,
            _params.interestBatchManager,
            vars.batch.entireDebtWithoutRedistribution,
            vars.batch.annualManagementFee,
            _params.maxUpfrontFee,
            _params.addManager,
            _params.removeManager,
            _params.receiver,
            vars.change
        );

        interestBatchManagerOf[vars.troveId] = _params.interestBatchManager;

        // Set the stored Trove properties and mint the NFT
        vars.troveManager.onOpenTroveAndJoinBatch(
            _params.owner,
            vars.troveId,
            vars.change,
            _params.interestBatchManager,
            vars.batch.entireCollWithoutRedistribution,
            vars.batch.entireDebtWithoutRedistribution
        );

        sortedTroves.insertIntoBatch(
            vars.troveId,
            BatchId.wrap(_params.interestBatchManager),
            vars.batch.annualInterestRate,
            _params.upperHint,
            _params.lowerHint
        );

        return vars.troveId;
    }

    function _requireMintingDebtAllowed() internal view virtual {
        if (!branchManager.mintingDebtAllowed()) {
            revert MintingDebtPaused();
        }
    }

    function _openTrove(
        address _owner,
        uint256 _ownerIndex,
        uint256 _collAmount,
        uint256 _boldAmount,
        uint256 _annualInterestRate,
        address _interestBatchManager,
        uint256 _batchEntireDebt,
        uint256 _batchManagementAnnualFee,
        uint256 _maxUpfrontFee,
        address _addManager,
        address _removeManager,
        address _receiver,
        TroveChange memory _change
    ) internal virtual returns (uint256) {
        _requireIsNotShutDown();
        // verify branch is not paused
        _requireMintingDebtAllowed();
        LocalVariables_openTrove memory vars;

        // stack too deep not allowing to reuse troveManager from outer functions
        vars.troveManager = troveManager;
        vars.activePool = activePool;
        vars.boldToken = boldToken;

        vars.price = _requireOraclesLive();

        // --- Checks ---

        vars.troveId = uint256(keccak256(abi.encode(msg.sender, _owner, _ownerIndex)));
        _requireTroveDoesNotExists(vars.troveManager, vars.troveId);

        _change.collIncrease = _collAmount;
        _change.debtIncrease = _boldAmount;

        // For simplicity, we ignore the fee when calculating the approx. interest rate
        _change.newWeightedRecordedDebt = (_batchEntireDebt + _change.debtIncrease) * _annualInterestRate;

        vars.avgInterestRate = vars.activePool.getNewApproxAvgInterestRateFromTroveChange(_change);
        _change.upfrontFee = _calcUpfrontFee(_change.debtIncrease, vars.avgInterestRate);
        _requireUserAcceptsUpfrontFee(_change.upfrontFee, _maxUpfrontFee);

        vars.entireDebt = _change.debtIncrease + _change.upfrontFee;

        if (vars.entireDebt < minDebt) {
            revert DebtBelowMin();
        }

        vars.ICR = LiquityMath._computeCR(_collAmount, vars.entireDebt, vars.price);

        // Recalculate newWeightedRecordedDebt, now taking into account the upfront fee, and the batch fee if needed
        if (_interestBatchManager == address(0)) {
            _change.newWeightedRecordedDebt = vars.entireDebt * _annualInterestRate;

            // ICR is based on the requested Bold amount + upfront fee.
            _requireICRisAboveMCR(vars.ICR);
        } else {
            // old values have been set outside, before calling this function
            _change.newWeightedRecordedDebt = (_batchEntireDebt + vars.entireDebt) * _annualInterestRate;
            _change.newWeightedRecordedBatchManagementFee =
                (_batchEntireDebt + vars.entireDebt) * _batchManagementAnnualFee;
            // ICR is based on the requested Bold amount + upfront fee.
            // Troves in a batch have a stronger requirement (MCR+BCR)
            _requireICRisAboveMCRPlusBCR(vars.ICR);
        }

        vars.newTCR = _getNewTCRFromTroveChange(_change, vars.price);
        _requireNewTCRisAboveCCR(vars.newTCR);

        // --- Effects & interactions ---

        // Set add/remove managers
        _setAddManager(vars.troveId, _addManager);
        _setRemoveManagerAndReceiver(vars.troveId, _removeManager, _receiver);

        vars.activePool.mintAggInterestAndAccountForTroveChange(_change, _interestBatchManager);

        // Pull coll tokens from sender and move them to the Active Pool
        _pullCollAndSendToActivePool(vars.activePool, _collAmount);

        // Mint the requested _boldAmount to the borrower and mint the gas comp to the GasPool
        vars.boldToken.mint(msg.sender, _boldAmount);
        WETH.transferFrom(msg.sender, gasPoolAddress, ETH_GAS_COMPENSATION);

        _requireTotalDebtBelowCap();
        return vars.troveId;
    }

    // Send collateral to a trove
    function addColl(uint256 _troveId, uint256 _collAmount) external virtual override {
        ITroveManager troveManagerCached = troveManager;
        _requireTroveIsActive(troveManagerCached, _troveId);

        TroveChange memory troveChange;
        troveChange.collIncrease = _collAmount;

        _adjustTrove(
            troveManagerCached,
            _troveId,
            troveChange,
            0 // _maxUpfrontFee
        );
    }

    // Withdraw collateral from a trove
    function withdrawColl(uint256 _troveId, uint256 _collWithdrawal) external virtual override {
        ITroveManager troveManagerCached = troveManager;
        _requireTroveIsActive(troveManagerCached, _troveId);

        TroveChange memory troveChange;
        troveChange.collDecrease = _collWithdrawal;

        _adjustTrove(
            troveManagerCached,
            _troveId,
            troveChange,
            0 // _maxUpfrontFee
        );
    }

    // Withdraw Bold tokens from a trove: mint new Bold tokens to the owner, and increase the trove's debt accordingly
    function withdrawBold(uint256 _troveId, uint256 _boldAmount, uint256 _maxUpfrontFee) external virtual override {
        ITroveManager troveManagerCached = troveManager;
        _requireTroveIsActive(troveManagerCached, _troveId);

        TroveChange memory troveChange;
        troveChange.debtIncrease = _boldAmount;
        _adjustTrove(troveManagerCached, _troveId, troveChange, _maxUpfrontFee);
    }

    // Repay Bold tokens to a Trove: Burn the repaid Bold tokens, and reduce the trove's debt accordingly
    function repayBold(uint256 _troveId, uint256 _boldAmount) external virtual override {
        ITroveManager troveManagerCached = troveManager;
        _requireTroveIsActive(troveManagerCached, _troveId);

        TroveChange memory troveChange;
        troveChange.debtDecrease = _boldAmount;

        _adjustTrove(
            troveManagerCached,
            _troveId,
            troveChange,
            0 // _maxUpfrontFee
        );
    }

    function _initTroveChange(
        TroveChange memory _troveChange,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _boldChange,
        bool _isDebtIncrease
    ) internal pure virtual {
        if (_isCollIncrease) {
            _troveChange.collIncrease = _collChange;
        } else {
            _troveChange.collDecrease = _collChange;
        }

        if (_isDebtIncrease) {
            _troveChange.debtIncrease = _boldChange;
        } else {
            _troveChange.debtDecrease = _boldChange;
        }
    }

    function adjustTrove(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _boldChange,
        bool _isDebtIncrease,
        uint256 _maxUpfrontFee
    ) external virtual override {
        ITroveManager troveManagerCached = troveManager;
        _requireTroveIsActive(troveManagerCached, _troveId);

        TroveChange memory troveChange;
        _initTroveChange(troveChange, _collChange, _isCollIncrease, _boldChange, _isDebtIncrease);
        _adjustTrove(troveManagerCached, _troveId, troveChange, _maxUpfrontFee);
    }

    function adjustZombieTrove(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _boldChange,
        bool _isDebtIncrease,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external virtual override {
        ITroveManager troveManagerCached = troveManager;
        _requireTroveIsZombie(troveManagerCached, _troveId);

        TroveChange memory troveChange;
        _initTroveChange(troveChange, _collChange, _isCollIncrease, _boldChange, _isDebtIncrease);
        _adjustTrove(troveManagerCached, _troveId, troveChange, _maxUpfrontFee);

        troveManagerCached.setTroveStatusToActive(_troveId);

        address batchManager = interestBatchManagerOf[_troveId];
        uint256 batchAnnualInterestRate;
        if (batchManager != address(0)) {
            LatestBatchData memory batch = troveManagerCached.getLatestBatchData(batchManager);
            batchAnnualInterestRate = batch.annualInterestRate;
        }
        _reInsertIntoSortedTroves(
            _troveId,
            troveManagerCached.getTroveAnnualInterestRate(_troveId),
            _upperHint,
            _lowerHint,
            batchManager,
            batchAnnualInterestRate
        );
    }

    function adjustTroveInterestRate(
        uint256 _troveId,
        uint256 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external virtual {
        _requireIsNotShutDown();

        ITroveManager troveManagerCached = troveManager;

        (TroveChange memory troveChange, LatestTroveData memory trove, uint256 newDebt) = boHelper
            .initAdjustTroveInterestRate(
            msg.sender, _troveId, _newAnnualInterestRate, _maxUpfrontFee, _upperHint, _lowerHint
        );

        troveManagerCached.onAdjustTroveInterestRate(
            _troveId, trove.entireColl, newDebt, _newAnnualInterestRate, troveChange
        );
    }

    /*
    * _adjustTrove(): Alongside a debt change, this function can perform either a collateral top-up or a collateral withdrawal.
    */
    function _adjustTrove(
        ITroveManager _troveManager,
        uint256 _troveId,
        TroveChange memory _troveChange,
        uint256 _maxUpfrontFee
    ) internal virtual {
        _requireIsNotShutDown();

        LocalVariables_adjustTrove memory vars;
        vars.activePool = activePool;
        vars.boldToken = boldToken;

        vars.price = _requireOraclesLive();
        vars.isBelowCriticalThreshold = _checkBelowCriticalThreshold(vars.price, branchManager.CCR());

        // --- Checks ---

        _requireTroveIsOpen(_troveManager, _troveId);

        address owner = troveNFT.ownerOf(_troveId);
        address receiver = owner; // If it’s a withdrawal, and remove manager privilege is set, a different receiver can be defined

        if (_troveChange.collDecrease > 0 || _troveChange.debtIncrease > 0) {
            receiver = _requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, owner);
        } else {
            // RemoveManager assumes AddManager, so if the former is set, there's no need to check the latter
            _requireSenderIsOwnerOrAddManager(_troveId, owner);
            // No need to check the type of trove change for two reasons:
            // - If the check above fails, it means sender is not owner, nor AddManager, nor RemoveManager.
            //   An independent 3rd party should not be allowed here.
            // - If it's not collIncrease or debtDecrease, _requireNonZeroAdjustment would revert
        }

        (vars, _troveChange) = boHelper.initAdjustTrove(
            _troveId, msg.sender, vars, _troveChange, _maxUpfrontFee, interestBatchManagerOf[_troveId]
        );

        // --- Effects and interactions ---

        // vars.activePool.mintAggInterestAndAccountForTroveChange(_troveChange, batchManager);
        _moveTokensFromAdjustment(receiver, _troveChange, vars.boldToken, vars.activePool);
    }

    function closeTrove(uint256 _troveId) external virtual override {
        // --- Checks ---
        address receiver = _requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, troveNFT.ownerOf(_troveId));
        address batchManager = interestBatchManagerOf[_troveId];
        LatestTroveData memory trove = boHelper.initCloseTrove(msg.sender, _troveId, batchManager);

        // Return ETH gas compensation
        WETH.transferFrom(gasPoolAddress, receiver, ETH_GAS_COMPENSATION);
        // Burn the remainder of the Trove's entire debt from the user
        boldToken.burn(msg.sender, trove.entireDebt);
        // Send the collateral back to the user
        activePool.sendColl(receiver, trove.entireColl);

        _wipeTroveMappings(_troveId);
    }

    function applyPendingDebt(uint256 _troveId, uint256 _lowerHint, uint256 _upperHint) public virtual {
        _requireIsNotShutDown();

        ITroveManager troveManagerCached = troveManager;

        _requireTroveIsOpen(troveManagerCached, _troveId);

        LatestTroveData memory trove = troveManagerCached.getLatestTroveData(_troveId);
        _requireNonZeroDebt(trove.entireDebt);

        TroveChange memory change;
        change.appliedRedistBoldDebtGain = trove.redistBoldDebtGain;
        change.appliedRedistCollGain = trove.redistCollGain;

        address batchManager = interestBatchManagerOf[_troveId];
        LatestBatchData memory batch;

        if (batchManager == address(0)) {
            change.oldWeightedRecordedDebt = trove.weightedRecordedDebt;
            change.newWeightedRecordedDebt = trove.entireDebt * trove.annualInterestRate;
        } else {
            batch = troveManagerCached.getLatestBatchData(batchManager);
            change.batchAccruedManagementFee = batch.accruedManagementFee;
            change.oldWeightedRecordedDebt = batch.weightedRecordedDebt;
            change.newWeightedRecordedDebt =
                (batch.entireDebtWithoutRedistribution + trove.redistBoldDebtGain) * batch.annualInterestRate;
            change.oldWeightedRecordedBatchManagementFee = batch.weightedRecordedBatchManagementFee;
            change.newWeightedRecordedBatchManagementFee =
                (batch.entireDebtWithoutRedistribution + trove.redistBoldDebtGain) * batch.annualManagementFee;
        }

        troveManagerCached.onApplyTroveInterest(
            _troveId,
            trove.entireColl,
            trove.entireDebt,
            batchManager,
            batch.entireCollWithoutRedistribution,
            batch.entireDebtWithoutRedistribution,
            change
        );
        activePool.mintAggInterestAndAccountForTroveChange(change, batchManager);

        // If the trove was zombie, and now it's not anymore, put it back in the list
        if (_checkTroveIsZombie(troveManagerCached, _troveId) && trove.entireDebt >= minDebt) {
            troveManagerCached.setTroveStatusToActive(_troveId);
            _reInsertIntoSortedTroves(
                _troveId, trove.annualInterestRate, _upperHint, _lowerHint, batchManager, batch.annualInterestRate
            );
        }
    }

    function setInterestIndividualDelegate(
        uint256 _troveId,
        address _delegate,
        uint128 _minInterestRate,
        uint128 _maxInterestRate,
        // only needed if trove was previously in a batch:
        uint256 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee,
        uint256 _minInterestRateChangePeriod
    ) external virtual {
        _requireIsNotShutDown();

        boHelper.initSetInterestIndividualDelegate(
            msg.sender, _troveId, _delegate, _minInterestRate, _maxInterestRate, _minInterestRateChangePeriod
        );

        // Can't have both individual delegation and batch manager
        if (interestBatchManagerOf[_troveId] != address(0)) {
            // Not needed, implicitly checked in removeFromBatch
            //_requireValidAnnualInterestRate(_newAnnualInterestRate);
            removeFromBatch(_troveId, _newAnnualInterestRate, _upperHint, _lowerHint, _maxUpfrontFee);
        }
    }

    function lowerBatchManagementFee(uint256 _newAnnualManagementFee) external virtual {
        boHelper.lowerBatchManagementFee(msg.sender, _newAnnualManagementFee);
    }

    function kickFromBatch(uint256 _troveId, uint256 _upperHint, uint256 _lowerHint) external virtual override {
        _removeFromBatch({
            _troveId: _troveId,
            _newAnnualInterestRate: 0, // ignored when kicking
            _upperHint: _upperHint,
            _lowerHint: _lowerHint,
            _maxUpfrontFee: 0, // will use the batch's existing interest rate, so no fee
            _kick: true
        });
    }

    function removeFromBatch(
        uint256 _troveId,
        uint256 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) public virtual override {
        _removeFromBatch({
            _troveId: _troveId,
            _newAnnualInterestRate: _newAnnualInterestRate,
            _upperHint: _upperHint,
            _lowerHint: _lowerHint,
            _maxUpfrontFee: _maxUpfrontFee,
            _kick: false
        });
    }

    function _removeFromBatch(
        uint256 _troveId,
        uint256 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee,
        bool _kick
    ) internal virtual {
        _requireIsNotShutDown();

        LocalVariables_removeFromBatch memory vars;
        vars.troveManager = troveManager;
        vars.sortedTroves = sortedTroves;

        if (_kick) {
            _requireTroveIsOpen(vars.troveManager, _troveId);
        } else {
            _requireTroveIsActive(vars.troveManager, _troveId);
            _requireCallerIsBorrower(_troveId);
            branchManager.requireValidAnnualInterestRate(_newAnnualInterestRate);
        }

        vars.batchManager = _requireIsInBatch(_troveId);
        vars.trove = vars.troveManager.getLatestTroveData(_troveId);
        vars.batch = vars.troveManager.getLatestBatchData(vars.batchManager);

        if (_kick) {
            if (vars.batch.totalDebtShares * MAX_BATCH_SHARES_RATIO >= vars.batch.entireDebtWithoutRedistribution) {
                revert BatchSharesRatioTooLow();
            }
            _newAnnualInterestRate = vars.batch.annualInterestRate;
        }

        delete interestBatchManagerOf[_troveId];

        if (!_checkTroveIsZombie(vars.troveManager, _troveId)) {
            // Remove trove from Batch in SortedTroves
            vars.sortedTroves.removeFromBatch(_troveId);
            // Reinsert as single trove
            vars.sortedTroves.insert(_troveId, _newAnnualInterestRate, _upperHint, _lowerHint);
        }

        vars.batchFutureDebt =
            vars.batch.entireDebtWithoutRedistribution - (vars.trove.entireDebt - vars.trove.redistBoldDebtGain);

        vars.batchChange.appliedRedistBoldDebtGain = vars.trove.redistBoldDebtGain;
        vars.batchChange.appliedRedistCollGain = vars.trove.redistCollGain;
        vars.batchChange.batchAccruedManagementFee = vars.batch.accruedManagementFee;
        vars.batchChange.oldWeightedRecordedDebt = vars.batch.weightedRecordedDebt;
        vars.batchChange.newWeightedRecordedDebt =
            vars.batchFutureDebt * vars.batch.annualInterestRate + vars.trove.entireDebt * _newAnnualInterestRate;

        // Apply upfront fee on premature adjustments. It checks the resulting ICR
        if (
            vars.batch.annualInterestRate != _newAnnualInterestRate
                && block.timestamp < vars.trove.lastInterestRateAdjTime + INTEREST_RATE_ADJ_COOLDOWN
        ) {
            (vars.trove.entireDebt, vars.batchChange) = boHelper.applyUpfrontFee(
                vars.trove.entireColl, vars.trove.entireDebt, vars.batchChange, _maxUpfrontFee, false
            );
        }

        // Recalculate newWeightedRecordedDebt, now taking into account the upfront fee
        vars.batchChange.newWeightedRecordedDebt =
            vars.batchFutureDebt * vars.batch.annualInterestRate + vars.trove.entireDebt * _newAnnualInterestRate;
        // Add batch fees
        vars.batchChange.oldWeightedRecordedBatchManagementFee = vars.batch.weightedRecordedBatchManagementFee;
        vars.batchChange.newWeightedRecordedBatchManagementFee = vars.batchFutureDebt * vars.batch.annualManagementFee;

        activePool.mintAggInterestAndAccountForTroveChange(vars.batchChange, vars.batchManager);

        vars.troveManager.onRemoveFromBatch(
            _troveId,
            vars.trove.entireColl,
            vars.trove.entireDebt,
            vars.batchChange,
            vars.batchManager,
            vars.batch.entireCollWithoutRedistribution,
            vars.batch.entireDebtWithoutRedistribution,
            _newAnnualInterestRate
        );
    }

    function switchBatchManager(
        uint256 _troveId,
        uint256 _removeUpperHint,
        uint256 _removeLowerHint,
        address _newBatchManager,
        uint256 _addUpperHint,
        uint256 _addLowerHint,
        uint256 _maxUpfrontFee
    ) external virtual override {
        LatestBatchData memory oldBatch = boHelper.initSwitchBatchManager(_troveId, _newBatchManager);

        removeFromBatch(_troveId, oldBatch.annualInterestRate, _removeUpperHint, _removeLowerHint, 0);
        boHelper.setInterestBatchManager(
            msg.sender, _troveId, _newBatchManager, _addUpperHint, _addLowerHint, _maxUpfrontFee
        );
    }

    function _calcUpfrontFee(uint256 _debt, uint256 _avgInterestRate) internal pure virtual returns (uint256) {
        return _calcInterest(_debt * _avgInterestRate, UPFRONT_INTEREST_PERIOD);
    }

    // Call from TM to clean state here
    function onLiquidateTrove(uint256 _troveId) external virtual {
        _requireCallerIsTroveManager();

        _wipeTroveMappings(_troveId);
    }

    function _requireCallerIsTroveManager() internal view virtual {
        if (msg.sender != address(troveManager)) {
            revert CallerNotTroveManager();
        }
    }

    function _wipeTroveMappings(uint256 _troveId) internal virtual {
        boHelper.removeInterestIndividualDelegate(_troveId);
        delete interestBatchManagerOf[_troveId];
        _wipeAddRemoveManagers(_troveId);
    }

    /**
     * Claim remaining collateral from a liquidation with ICR exceeding the liquidation penalty
     */
    function claimCollateral() external virtual override {
        // send coll from CollSurplus Pool to owner
        collSurplusPool.claimColl(msg.sender);
    }

    function shutdown() external virtual {
        if (hasBeenShutDown) revert IsShutDown();

        uint256 totalColl = getEntireBranchColl();
        uint256 totalDebt = getEntireBranchDebt();
        (uint256 price, bool newOracleFailureDetected) = priceFeed.fetchPrice();
        // If the oracle failed, the above call to PriceFeed will have shut this branch down
        if (newOracleFailureDetected) return;

        // Otherwise, proceed with the TCR check:
        uint256 TCR = LiquityMath._computeCR(totalColl, totalDebt, price);
        if (TCR >= branchManager.SCR()) revert TCRNotBelowSCR();

        _applyShutdown();

        emit ShutDown(TCR);
    }

    // Not technically a "Borrower op", but seems best placed here given current shutdown logic.
    function shutdownFromOracleFailure() external virtual {
        _requireCallerIsPriceFeed();

        // No-op rather than revert here, so that the outer function call which fetches the price does not revert
        // if the system is already shut down.
        if (hasBeenShutDown) return;

        _applyShutdown();
    }

    function _requireCallerIsPriceFeed() internal view virtual {
        if (msg.sender != address(priceFeed)) {
            revert CallerNotPriceFeed();
        }
    }

    function _applyShutdown() internal virtual {
        activePool.mintAggInterest();
        hasBeenShutDown = true;
        branchManager.shutdown();
    }

    // --- Helper functions ---

    function _reInsertIntoSortedTroves(
        uint256 _troveId,
        uint256 _troveAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        address _batchManager,
        uint256 _batchAnnualInterestRate
    ) internal virtual {
        // If it was in a batch, we need to put it back, otherwise we insert it normally
        if (_batchManager == address(0)) {
            sortedTroves.insert(_troveId, _troveAnnualInterestRate, _upperHint, _lowerHint);
        } else {
            sortedTroves.insertIntoBatch(
                _troveId, BatchId.wrap(_batchManager), _batchAnnualInterestRate, _upperHint, _lowerHint
            );
        }
    }

    // This function mints the BOLD corresponding to the borrower's chosen debt increase
    // (it does not mint the accrued interest).
    function _moveTokensFromAdjustment(
        address withdrawalReceiver,
        TroveChange memory _troveChange,
        IBoldToken _boldToken,
        IActivePool _activePool
    ) internal virtual {
        if (_troveChange.debtIncrease > 0) {
            _requireMintingDebtAllowed();
            _boldToken.mint(withdrawalReceiver, _troveChange.debtIncrease);
            _requireTotalDebtBelowCap();
        } else if (_troveChange.debtDecrease > 0) {
            _boldToken.burn(msg.sender, _troveChange.debtDecrease);
        }

        if (_troveChange.collIncrease > 0) {
            // Pull coll tokens from sender and move them to the Active Pool
            _pullCollAndSendToActivePool(_activePool, _troveChange.collIncrease);
        } else if (_troveChange.collDecrease > 0) {
            // Pull Coll from Active Pool and decrease its recorded Coll balance
            _activePool.sendColl(withdrawalReceiver, _troveChange.collDecrease);
        }
    }

    function _pullCollAndSendToActivePool(IActivePool _activePool, uint256 _amount) internal virtual {
        // Send Coll tokens from sender to active pool
        collToken.safeTransferFrom(msg.sender, address(_activePool), _amount);
        // Make sure Active Pool accountancy is right
        _activePool.accountForReceivedColl(_amount);
    }

    // --- 'Require' wrapper functions ---

    function _requireIsNotShutDown() internal view virtual {
        if (hasBeenShutDown) {
            revert IsShutDown();
        }
    }

    function _requireTroveDoesNotExists(ITroveManager _troveManager, uint256 _troveId) internal view virtual {
        ITroveManager.Status status = _troveManager.getTroveStatus(_troveId);
        if (status != ITroveManager.Status.nonExistent) {
            revert TroveExists();
        }
    }

    function _requireIsInBatch(uint256 _troveId) internal view virtual returns (address) {
        address batchManager = interestBatchManagerOf[_troveId];
        if (batchManager == address(0)) {
            revert TroveNotInBatch();
        }

        return batchManager;
    }

    function _requireTroveIsOpen(ITroveManager _troveManager, uint256 _troveId) internal view virtual {
        ITroveManager.Status status = _troveManager.getTroveStatus(_troveId);
        if (status != ITroveManager.Status.active && status != ITroveManager.Status.zombie) {
            revert TroveNotOpen();
        }
    }

    function _requireTroveIsActive(ITroveManager _troveManager, uint256 _troveId) internal view virtual {
        ITroveManager.Status status = _troveManager.getTroveStatus(_troveId);
        if (status != ITroveManager.Status.active) {
            revert TroveNotActive();
        }
    }

    function _requireTotalDebtBelowCap() internal view virtual {
        if (activePool.totalDebtTaken() > branchManager.debtCap()) {
            if (msg.sender != _ebisuAdminRegistry.ebisuAdmin()) {
                revert DebtCapReached();
            }
        }
    }

    function _requireTroveIsZombie(ITroveManager _troveManager, uint256 _troveId) internal view virtual {
        if (!_checkTroveIsZombie(_troveManager, _troveId)) {
            revert TroveNotZombie();
        }
    }

    function _checkTroveIsZombie(ITroveManager _troveManager, uint256 _troveId) internal view virtual returns (bool) {
        ITroveManager.Status status = _troveManager.getTroveStatus(_troveId);
        return status == ITroveManager.Status.zombie;
    }

    function _requireNonZeroDebt(uint256 _troveDebt) internal pure virtual {
        if (_troveDebt == 0) {
            revert TroveWithZeroDebt();
        }
    }

    function _requireUserAcceptsUpfrontFee(uint256 _fee, uint256 _maxFee) internal pure virtual {
        if (_fee > _maxFee) {
            revert UpfrontFeeTooHigh();
        }
    }

    function _requireICRisAboveMCR(uint256 _newICR) internal view virtual {
        if (_newICR < branchManager.MCR()) {
            revert ICRBelowMCR();
        }
    }

    function _requireNewTCRisAboveCCR(uint256 _newTCR) internal view virtual {
        if (_newTCR < branchManager.CCR()) {
            revert TCRBelowCCR();
        }
    }

    function _requireOraclesLive() internal virtual returns (uint256) {
        (uint256 price, bool newOracleFailureDetected) = priceFeed.fetchPrice();
        if (newOracleFailureDetected) {
            revert NewOracleFailureDetected();
        }

        return price;
    }

    // --- ICR and TCR getters ---

    function _getNewTCRFromTroveChange(TroveChange memory _troveChange, uint256 _price)
        internal
        view
        virtual
        returns (uint256 newTCR)
    {
        uint256 totalColl = getEntireBranchColl();
        totalColl += _troveChange.collIncrease;
        totalColl -= _troveChange.collDecrease;

        uint256 totalDebt = getEntireBranchDebt();
        totalDebt += _troveChange.debtIncrease;
        totalDebt += _troveChange.upfrontFee;
        totalDebt -= _troveChange.debtDecrease;

        newTCR = LiquityMath._computeCR(totalColl, totalDebt, _price);
    }

    function setInterestBatchManagerOf(uint256 _troveId, address _batchManager) external virtual {
        if (msg.sender != address(boHelper)) {
            revert CallerNotBorrowerOperationsHelper();
        }
        interestBatchManagerOf[_troveId] = _batchManager;
    }

    function _requireICRisAboveMCRPlusBCR(uint256 _newICR) internal view virtual {
        if (_newICR < branchManager.MCR() + BCR) {
            revert ICRBelowMCRPlusBCR();
        }
    }

    function setMinDebt(uint256 _minDebt) external virtual {
        if (msg.sender != address(branchManager)) {
            revert CallerNotBranchManager();
        }
        minDebt = _minDebt;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceFeed {
    function fetchPrice() external returns (uint256, bool);
    function fetchRedemptionPrice() external returns (uint256, bool);
    function lastGoodPrice() external view returns (uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "./Constants.sol";
import "./LiquityMath.sol";
import "../Interfaces/IAddressesRegistry.sol";
import "../Interfaces/IActivePool.sol";
import "../Interfaces/IDefaultPool.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/ILiquityBase.sol";

/*
* Base contract for TroveManager, BorrowerOperations and StabilityPool. Contains global system constants and
* common functions.
*/
contract LiquityBase is ILiquityBase {
    IActivePool public activePool;
    IDefaultPool internal defaultPool;
    IPriceFeed internal priceFeed;

    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);

    function initialize(address _addressesRegistryAddress) public virtual {
        require(address(activePool) == address(0), "Already initialized");

        IAddressesRegistry _addressesRegistry = IAddressesRegistry(_addressesRegistryAddress);
        activePool = _addressesRegistry.activePool();
        defaultPool = _addressesRegistry.defaultPool();
        priceFeed = _addressesRegistry.priceFeed();

        emit ActivePoolAddressChanged(address(activePool));
        emit DefaultPoolAddressChanged(address(defaultPool));
        emit PriceFeedAddressChanged(address(priceFeed));
    }
    // --- Gas compensation functions ---

    function getEntireBranchColl() public view returns (uint256 entireSystemColl) {
        uint256 activeColl = activePool.getCollBalance();
        uint256 liquidatedColl = defaultPool.getCollBalance();

        return activeColl + liquidatedColl;
    }

    function getEntireBranchDebt() public view returns (uint256 entireSystemDebt) {
        uint256 activeDebt = activePool.getBoldDebt();
        uint256 closedDebt = defaultPool.getBoldDebt();

        return activeDebt + closedDebt;
    }

    function _getTCR(uint256 _price) internal view returns (uint256 TCR) {
        uint256 entireSystemColl = getEntireBranchColl();
        uint256 entireSystemDebt = getEntireBranchDebt();

        TCR = LiquityMath._computeCR(entireSystemColl, entireSystemDebt, _price);

        return TCR;
    }

    function _checkBelowCriticalThreshold(uint256 _price, uint256 _CCR) internal view returns (bool) {
        uint256 TCR = _getTCR(_price);

        return TCR < _CCR;
    }

    function _calcInterest(uint256 _weightedDebt, uint256 _period) internal pure returns (uint256) {
        return _weightedDebt * _period / ONE_YEAR / DECIMAL_PRECISION;
    }
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "../Interfaces/IAddRemoveManagers.sol";
import "../Interfaces/IAddressesRegistry.sol";
import "../Interfaces/ITroveNFT.sol";

contract AddRemoveManagers is IAddRemoveManagers {
    ITroveNFT internal troveNFT;

    struct RemoveManagerReceiver {
        address manager;
        address receiver;
    }

    /*
     * Mapping from TroveId to granted address for operations that "give" money to the trove (add collateral, pay debt).
     * Useful for instance for cold/hot wallet setups.
     * If its value is zero address, any address is allowed to do those operations on behalf of trove owner.
     * Otherwise, only the address in this mapping (and the trove owner) will be allowed.
     * To restrict this permission to no one, trove owner should be set in this mapping.
     */
    mapping(uint256 => address) public addManagerOf;

    /*
     * Mapping from TroveId to granted addresses for operations that "withdraw" money from the trove (withdraw collateral, borrow),
     * and for each of those addresses another address for the receiver of those withdrawn funds.
     * Useful for instance for cold/hot wallet setups or for automations.
     * Only the address in this mapping, if any, and the trove owner, will be allowed.
     * Therefore, by default this permission is restricted to no one.
     * If the receiver is zero, the owner is assumed as the receiver.
     * RemoveManager also assumes AddManager permission
     */
    mapping(uint256 => RemoveManagerReceiver) public removeManagerReceiverOf;

    error EmptyManager();
    error NotBorrower();
    error NotOwnerNorAddManager();
    error NotOwnerNorRemoveManager();

    event TroveNFTAddressChanged(address _newTroveNFTAddress);
    event AddManagerUpdated(uint256 indexed _troveId, address _newAddManager);
    event RemoveManagerAndReceiverUpdated(uint256 indexed _troveId, address _newRemoveManager, address _newReceiver);

    function initialize(address _addressesRegistryAddress) public virtual {
        require(address(troveNFT) == address(0), "Already initialized");
        IAddressesRegistry _addressesRegistry = IAddressesRegistry(_addressesRegistryAddress);
        troveNFT = _addressesRegistry.troveNFT();
        emit TroveNFTAddressChanged(address(troveNFT));
    }

    function setAddManager(uint256 _troveId, address _manager) external {
        _requireCallerIsBorrower(_troveId);
        _setAddManager(_troveId, _manager);
    }

    function _setAddManager(uint256 _troveId, address _manager) internal {
        addManagerOf[_troveId] = _manager;
        emit AddManagerUpdated(_troveId, _manager);
    }

    function setRemoveManager(uint256 _troveId, address _manager) external {
        setRemoveManagerWithReceiver(_troveId, _manager, troveNFT.ownerOf(_troveId));
    }

    function setRemoveManagerWithReceiver(uint256 _troveId, address _manager, address _receiver) public {
        _requireCallerIsBorrower(_troveId);
        _setRemoveManagerAndReceiver(_troveId, _manager, _receiver);
    }

    function _setRemoveManagerAndReceiver(uint256 _troveId, address _manager, address _receiver) internal {
        _requireNonZeroManagerUnlessWiping(_manager, _receiver);
        removeManagerReceiverOf[_troveId].manager = _manager;
        removeManagerReceiverOf[_troveId].receiver = _receiver;
        emit RemoveManagerAndReceiverUpdated(_troveId, _manager, _receiver);
    }

    function _wipeAddRemoveManagers(uint256 _troveId) internal {
        delete addManagerOf[_troveId];
        delete removeManagerReceiverOf[_troveId];
        emit AddManagerUpdated(_troveId, address(0));
        emit RemoveManagerAndReceiverUpdated(_troveId, address(0), address(0));
    }

    function _requireNonZeroManagerUnlessWiping(address _manager, address _receiver) internal pure {
        if (_manager == address(0) && _receiver != address(0)) {
            revert EmptyManager();
        }
    }

    function _requireCallerIsBorrower(uint256 _troveId) internal view {
        if (msg.sender != troveNFT.ownerOf(_troveId)) {
            revert NotBorrower();
        }
    }

    function _requireSenderIsOwnerOrAddManager(uint256 _troveId, address _owner) internal view {
        address addManager = addManagerOf[_troveId];
        if (msg.sender != _owner && addManager != address(0) && msg.sender != addManager) {
            // RemoveManager assumes AddManager permission too
            address removeManager = removeManagerReceiverOf[_troveId].manager;
            if (msg.sender != removeManager) {
                revert NotOwnerNorAddManager();
            }
        }
    }

    function _requireSenderIsOwnerOrRemoveManagerAndGetReceiver(uint256 _troveId, address _owner)
        internal
        view
        returns (address)
    {
        address manager = removeManagerReceiverOf[_troveId].manager;
        address receiver = removeManagerReceiverOf[_troveId].receiver;
        if (msg.sender != _owner && msg.sender != manager) {
            revert NotOwnerNorRemoveManager();
        }
        if (receiver == address(0) || msg.sender != manager) {
            return _owner;
        }
        return receiver;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ILiquityBase.sol";
import "./IAddRemoveManagers.sol";
import "./IBoldToken.sol";
import "./IPriceFeed.sol";
import "./ISortedTroves.sol";
import "./ITroveManager.sol";
import "./IWETH.sol";
import "../Dependencies/BoStructs.sol";
import "./IEbisuBorrowerOperationsHelper.sol";
// Common interface for the Borrower Operations.

interface IBorrowerOperations is ILiquityBase, IAddRemoveManagers {
    function initialize(address _addressesRegistryAddress) external;

    function openTrove(
        address _owner,
        uint256 _ownerIndex,
        uint256 _ETHAmount,
        uint256 _boldAmount,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _annualInterestRate,
        uint256 _maxUpfrontFee,
        address _addManager,
        address _removeManager,
        address _receiver
    ) external returns (uint256);

    struct OpenTroveAndJoinInterestBatchManagerParams {
        address owner;
        uint256 ownerIndex;
        uint256 collAmount;
        uint256 boldAmount;
        uint256 upperHint;
        uint256 lowerHint;
        address interestBatchManager;
        uint256 maxUpfrontFee;
        address addManager;
        address removeManager;
        address receiver;
    }

    function openTroveAndJoinInterestBatchManager(OpenTroveAndJoinInterestBatchManagerParams calldata _params)
        external
        returns (uint256);

    function addColl(uint256 _troveId, uint256 _ETHAmount) external;

    function withdrawColl(uint256 _troveId, uint256 _amount) external;

    function withdrawBold(uint256 _troveId, uint256 _amount, uint256 _maxUpfrontFee) external;

    function repayBold(uint256 _troveId, uint256 _amount) external;

    function closeTrove(uint256 _troveId) external;

    function adjustTrove(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool isDebtIncrease,
        uint256 _maxUpfrontFee
    ) external;

    function adjustZombieTrove(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _boldChange,
        bool _isDebtIncrease,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external;

    function adjustTroveInterestRate(
        uint256 _troveId,
        uint256 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external;

    function applyPendingDebt(uint256 _troveId, uint256 _lowerHint, uint256 _upperHint) external;

    function onLiquidateTrove(uint256 _troveId) external;

    function claimCollateral() external;

    function hasBeenShutDown() external view returns (bool);
    function shutdown() external;
    function shutdownFromOracleFailure() external;

    // -- individual delegation --
    function setInterestIndividualDelegate(
        uint256 _troveId,
        address _delegate,
        uint128 _minInterestRate,
        uint128 _maxInterestRate,
        // only needed if trove was previously in a batch:
        uint256 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee,
        uint256 _minInterestRateChangePeriod
    ) external;
    // -- batches --
    function lowerBatchManagementFee(uint256 _newAnnualFee) external;
    function interestBatchManagerOf(uint256 _troveId) external view returns (address);
    function kickFromBatch(uint256 _troveId, uint256 _upperHint, uint256 _lowerHint) external;
    function removeFromBatch(
        uint256 _troveId,
        uint256 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external;
    function switchBatchManager(
        uint256 _troveId,
        uint256 _removeUpperHint,
        uint256 _removeLowerHint,
        address _newBatchManager,
        uint256 _addUpperHint,
        uint256 _addLowerHint,
        uint256 _maxUpfrontFee
    ) external;

    function setInterestBatchManagerOf(uint256 _troveId, address _batchManager) external;
    function boHelper() external view returns (IEbisuBorrowerOperationsHelper);
    function setMinDebt(uint256 _minDebt) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
import "../../../utils/Address.sol";

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
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
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
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
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
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
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
        IERC20Permit token,
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
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
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
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IActivePool.sol";
import "./IBoldToken.sol";
import "./IBorrowerOperations.sol";
import "./ICollSurplusPool.sol";
import "./IDefaultPool.sol";
import "./IHintHelpers.sol";
import "./IMultiTroveGetter.sol";
import "./ISortedTroves.sol";
import "./IStabilityPool.sol";
import "./ITroveManager.sol";
import "./ITroveNFT.sol";
import {IMetadataNFT} from "../NFTMetadata/MetadataNFT.sol";
import {ICollateralRegistry} from "./ICollateralRegistry.sol";
import "./IInterestRouter.sol";
import "./IPriceFeed.sol";
import "./IWETH.sol";
import "./IEbisuBranchManager.sol";

interface IAddressesRegistry {
    struct AddressVars {
        IERC20Metadata collToken;
        IBorrowerOperations borrowerOperations;
        ITroveManager troveManager;
        ITroveNFT troveNFT;
        IMetadataNFT metadataNFT;
        IStabilityPool stabilityPool;
        IPriceFeed priceFeed;
        IActivePool activePool;
        IDefaultPool defaultPool;
        address gasPoolAddress;
        ICollSurplusPool collSurplusPool;
        ISortedTroves sortedTroves;
        IInterestRouter interestRouter;
        IHintHelpers hintHelpers;
        IMultiTroveGetter multiTroveGetter;
        ICollateralRegistry collateralRegistry;
        IBoldToken boldToken;
        IWETH WETH;
        address borrowerOperationsHelper;
        IEbisuBranchManager branchManager;
    }

    function CCR() external view returns (uint256);
    function SCR() external view returns (uint256);
    function MCR() external view returns (uint256);
    function BCR() external view returns (uint256);
    function LIQUIDATION_PENALTY_SP() external view returns (uint256);
    function LIQUIDATION_PENALTY_REDISTRIBUTION() external view returns (uint256);
    function branchCollGasCompensationCap() external view returns (uint256);

    function collToken() external view returns (IERC20Metadata);
    function borrowerOperations() external view returns (IBorrowerOperations);
    function troveManager() external view returns (ITroveManager);
    function troveNFT() external view returns (ITroveNFT);
    function metadataNFT() external view returns (IMetadataNFT);
    function stabilityPool() external view returns (IStabilityPool);
    function priceFeed() external view returns (IPriceFeed);
    function activePool() external view returns (IActivePool);
    function defaultPool() external view returns (IDefaultPool);
    function gasPoolAddress() external view returns (address);
    function collSurplusPool() external view returns (ICollSurplusPool);
    function sortedTroves() external view returns (ISortedTroves);
    function interestRouter() external view returns (IInterestRouter);
    function hintHelpers() external view returns (IHintHelpers);
    function multiTroveGetter() external view returns (IMultiTroveGetter);
    function collateralRegistry() external view returns (ICollateralRegistry);
    function boldToken() external view returns (IBoldToken);
    function WETH() external returns (IWETH);
    function borrowerOperationsHelper() external view returns (address);
    function branchManager() external view returns (IEbisuBranchManager);

    function setAddresses(AddressVars memory _vars) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ILiquityBase.sol";
import "./ITroveNFT.sol";
import "./IBorrowerOperations.sol";
import "./IStabilityPool.sol";
import "./IBoldToken.sol";
import "./ISortedTroves.sol";
import "../Types/LatestTroveData.sol";
import "../Types/LatestBatchData.sol";
import "./IEbisuBranchManager.sol";
import "../Dependencies/TMStructs.sol";
// Common interface for the Trove Manager.

interface ITroveManager is ILiquityBase {
    enum Status {
        nonExistent,
        active,
        closedByOwner,
        closedByLiquidation,
        zombie
    }

    function initialize(address _addressesRegistryAddress) external;

    function troveNFT() external view returns (ITroveNFT);
    function stabilityPool() external view returns (IStabilityPool);
    function sortedTroves() external view returns (ISortedTroves);
    function borrowerOperations() external view returns (IBorrowerOperations);

    function Troves(uint256 _id)
        external
        view
        returns (
            uint256 debt,
            uint256 coll,
            uint256 stake,
            Status status,
            uint64 arrayIndex,
            uint64 lastDebtUpdateTime,
            uint64 lastInterestRateAdjTime,
            uint256 annualInterestRate,
            address interestBatchManager,
            uint256 batchDebtShares
        );

    function rewardSnapshots(uint256 _id) external view returns (uint256 coll, uint256 boldDebt);

    function getTroveIdsCount() external view returns (uint256);

    function getTroveFromTroveIdsArray(uint256 _index) external view returns (uint256);

    function getCurrentICR(uint256 _troveId, uint256 _price) external view returns (uint256);

    function lastZombieTroveId() external view returns (uint256);

    function batchLiquidateTroves(uint256[] calldata _troveArray) external;
    function shutdown() external;

    function getLatestTroveData(uint256 _troveId) external view returns (LatestTroveData memory);
    function getTroveAnnualInterestRate(uint256 _troveId) external view returns (uint256);

    function getTroveStatus(uint256 _troveId) external view returns (Status);

    function getLatestBatchData(address _batchAddress) external view returns (LatestBatchData memory);

    // -- permissioned functions called by BorrowerOperations

    function onOpenTrove(address _owner, uint256 _troveId, TroveChange memory _troveChange, uint256 _annualInterestRate)
        external;
    function onOpenTroveAndJoinBatch(
        address _owner,
        uint256 _troveId,
        TroveChange memory _troveChange,
        address _batchAddress,
        uint256 _batchColl,
        uint256 _batchDebt
    ) external;

    // Called from `adjustZombieTrove()`
    function setTroveStatusToActive(uint256 _troveId) external;

    function onAdjustTroveInterestRate(
        uint256 _troveId,
        uint256 _newColl,
        uint256 _newDebt,
        uint256 _newAnnualInterestRate,
        TroveChange calldata _troveChange
    ) external;

    function onAdjustTrove(uint256 _troveId, uint256 _newColl, uint256 _newDebt, TroveChange calldata _troveChange)
        external;

    function onAdjustTroveInsideBatch(
        uint256 _troveId,
        uint256 _newTroveColl,
        uint256 _newTroveDebt,
        TroveChange memory _troveChange,
        address _batchAddress,
        uint256 _newBatchColl,
        uint256 _newBatchDebt
    ) external;

    function onApplyTroveInterest(
        uint256 _troveId,
        uint256 _newTroveColl,
        uint256 _newTroveDebt,
        address _batchAddress,
        uint256 _newBatchColl,
        uint256 _newBatchDebt,
        TroveChange calldata _troveChange
    ) external;

    function onCloseTrove(
        uint256 _troveId,
        TroveChange memory _troveChange, // decrease vars: entire, with interest, batch fee and redistribution
        address _batchAddress,
        uint256 _newBatchColl,
        uint256 _newBatchDebt // entire, with interest and batch fee
    ) external;

    // -- batches --
    function onRegisterBatchManager(address _batchAddress, uint256 _annualInterestRate, uint256 _annualFee) external;
    function onLowerBatchManagerAnnualFee(
        address _batchAddress,
        uint256 _newColl,
        uint256 _newDebt,
        uint256 _newAnnualManagementFee
    ) external;
    function onSetBatchManagerAnnualInterestRate(
        address _batchAddress,
        uint256 _newColl,
        uint256 _newDebt,
        uint256 _newAnnualInterestRate,
        uint256 _upfrontFee // needed by BatchUpdated event
    ) external;

    struct OnSetInterestBatchManagerParams {
        uint256 troveId;
        uint256 troveColl; // entire, with redistribution
        uint256 troveDebt; // entire, with interest, batch fee and redistribution
        TroveChange troveChange;
        address newBatchAddress;
        uint256 newBatchColl; // updated collateral for new batch manager
        uint256 newBatchDebt; // updated debt for new batch manager
    }

    function onSetInterestBatchManager(OnSetInterestBatchManagerParams calldata _params) external;
    function onRemoveFromBatch(
        uint256 _troveId,
        uint256 _newTroveColl, // entire, with redistribution
        uint256 _newTroveDebt, // entire, with interest, batch fee and redistribution
        TroveChange memory _troveChange,
        address _batchAddress,
        uint256 _newBatchColl,
        uint256 _newBatchDebt, // entire, with interest and batch fee
        uint256 _newAnnualInterestRate
    ) external;

    function setLastZombieTroveId(uint256 _lastZombieTroveId) external;
    function updateBatchSharesAndTroveColl(
        uint256 _troveId,
        uint256 _newColl,
        address _batchAddress,
        TroveChange memory _troveChange,
        uint256 _newTroveDebt,
        uint256 _batchColl,
        uint256 _batchDebt,
        bool _checkBatchSharesRatio
    ) external;

    function updateTroveState(uint256 _troveId, uint256 _newColl, uint256 _redistBoldDebtGain, uint256 _redistCollGain)
        external
        returns (uint256 newStake);
    function setTroveCollDebtAndLastDebtUpdateTime(uint256 _troveId, uint256 _newColl, uint256 _newDebt) external;
    function setTroveStatusToZombie(uint256 _troveId) external;

    // -- end of permissioned functions --
    function L_coll() external view returns (uint256);
    function L_boldDebt() external view returns (uint256);
    function getBatchData(address _batchAddress) external view returns (Batch memory);
    function getBatchManager(uint256 _troveId) external view returns (address);
    function updateBatchInterestPriorToRedemption(address _batchAddress) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";

interface IBoldToken is IERC20MetadataUpgradeable, IERC20PermitUpgradeable {
    function setCollateralRegistry(address _collateralRegistryAddress) external;

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function sendToPool(address _sender, address poolAddress, uint256 _amount) external;

    function returnFromPool(address poolAddress, address user, uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICollSurplusPool {
    function initialize(address _addressesRegistryAddress) external;

    function getCollBalance() external view returns (uint256);

    function getCollateral(address _account) external view returns (uint256);

    function accountSurplus(address _account, uint256 _amount) external;

    function claimColl(address _account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ITroveManager.sol";
import {BatchId, BATCH_ID_ZERO} from "../Types/BatchId.sol";

interface ISortedTroves {
    // Initialize function
    function initialize(address _addressesRegistryAddress) external;
    // -- Mutating functions (permissioned) --
    function insert(uint256 _id, uint256 _annualInterestRate, uint256 _prevId, uint256 _nextId) external;
    function insertIntoBatch(
        uint256 _troveId,
        BatchId _batchId,
        uint256 _annualInterestRate,
        uint256 _prevId,
        uint256 _nextId
    ) external;

    function remove(uint256 _id) external;
    function removeFromBatch(uint256 _id) external;

    function reInsert(uint256 _id, uint256 _newAnnualInterestRate, uint256 _prevId, uint256 _nextId) external;
    function reInsertBatch(BatchId _id, uint256 _newAnnualInterestRate, uint256 _prevId, uint256 _nextId) external;

    // -- View functions --

    function contains(uint256 _id) external view returns (bool);
    function isBatchedNode(uint256 _id) external view returns (bool);
    function isEmptyBatch(BatchId _id) external view returns (bool);

    function isEmpty() external view returns (bool);
    function getSize() external view returns (uint256);

    function getFirst() external view returns (uint256);
    function getLast() external view returns (uint256);
    function getNext(uint256 _id) external view returns (uint256);
    function getPrev(uint256 _id) external view returns (uint256);

    function validInsertPosition(uint256 _annualInterestRate, uint256 _prevId, uint256 _nextId)
        external
        view
        returns (bool);
    function findInsertPosition(uint256 _annualInterestRate, uint256 _prevId, uint256 _nextId)
        external
        view
        returns (uint256, uint256);

    // Public state variable getters
    function borrowerOperationsAddress() external view returns (address);
    function troveManager() external view returns (ITroveManager);
    function size() external view returns (uint256);
    function nodes(uint256 _id) external view returns (uint256 nextId, uint256 prevId, BatchId batchId, bool exists);
    function batches(BatchId _id) external view returns (uint256 head, uint256 tail);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

struct LatestTroveData {
    uint256 entireDebt;
    uint256 entireColl;
    uint256 redistBoldDebtGain;
    uint256 redistCollGain;
    uint256 accruedInterest;
    uint256 recordedDebt;
    uint256 annualInterestRate;
    uint256 weightedRecordedDebt;
    uint256 accruedBatchManagementFee;
    uint256 lastInterestRateAdjTime;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

struct LatestBatchData {
    uint256 totalDebtShares;
    uint256 entireDebtWithoutRedistribution;
    uint256 entireCollWithoutRedistribution;
    uint256 accruedInterest;
    uint256 recordedDebt;
    uint256 annualInterestRate;
    uint256 weightedRecordedDebt;
    uint256 annualManagementFee;
    uint256 accruedManagementFee;
    uint256 weightedRecordedBatchManagementFee;
    uint256 lastDebtUpdateTime;
    uint256 lastInterestRateAdjTime;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IBorrowerOperations.sol";
import "./IPriceFeed.sol";
import "../Dependencies/BoStructs.sol";
import "./ILiquityBase.sol";
import "../Types/LatestTroveData.sol";
import "../Types/LatestBatchData.sol";

interface IEbisuBorrowerOperationsHelper is ILiquityBase {
    function initialize(address _addressesRegistryAddress) external;

    function initSetInterestIndividualDelegate(
        address caller,
        uint256 _troveId,
        address _delegate,
        uint128 _minInterestRate,
        uint128 _maxInterestRate,
        uint256 _minInterestRateChangePeriod
    ) external;

    function getInterestBatchManager(address _account) external view returns (InterestBatchManager memory);
    function checkBatchManagerExists(address _batchManager) external view returns (bool);
    function requireValidInterestBatchManager(address _interestBatchManagerAddress) external view;

    function initCloseTrove(address caller, uint256 _troveId, address batchManager)
        external
        returns (LatestTroveData memory);

    function initAdjustTroveInterestRate(
        address caller,
        uint256 _troveId,
        uint256 _newAnnualInterestRate,
        uint256 _maxUpfrontFee,
        uint256 _upperHint,
        uint256 _lowerHint
    ) external returns (TroveChange memory troveChange, LatestTroveData memory trove, uint256 newDebt);

    function initAdjustTrove(
        uint256 _troveId,
        address caller,
        LocalVariables_adjustTrove memory vars,
        TroveChange memory _troveChange,
        uint256 _maxUpfrontFee,
        address batchManager
    ) external returns (LocalVariables_adjustTrove memory, TroveChange memory);

    function applyUpfrontFee(
        uint256 _troveEntireColl,
        uint256 _troveEntireDebt,
        TroveChange memory _troveChange,
        uint256 _maxUpfrontFee,
        bool _isTroveInBatch
    ) external returns (uint256, TroveChange memory);

    function removeInterestIndividualDelegate(uint256 _troveId) external;

    function getInterestIndividualDelegateOf(uint256 _troveId)
        external
        view
        returns (InterestIndividualDelegate memory);

    function setInterestBatchManager(
        uint256 _troveId,
        address _newBatchManager,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external;

    function setInterestBatchManager(
        address caller,
        uint256 _troveId,
        address _newBatchManager,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external;

    function initSwitchBatchManager(uint256 _troveId, address _newBatchManager)
        external
        returns (LatestBatchData memory);

    function registerBatchManager(
        uint128 minInterestRate,
        uint128 maxInterestRate,
        uint128 currentInterestRate,
        uint128 fee,
        uint128 minInterestRateChangePeriod
    ) external;

    function setBatchManagerAnnualInterestRate(
        uint128 _newAnnualInterestRate,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external;

    function lowerBatchManagementFee(address _caller, uint256 _newAnnualManagementFee) external;

    function setMinDebt(uint256 _minDebt) external;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "../Types/LatestTroveData.sol";
import "../Types/LatestBatchData.sol";
import "./ILiquityBase.sol";

enum Parameter {
    MCR,
    MIN_ANNUAL_INTEREST_RATE,
    SP_YIELD_SPLIT,
    DEBT_CAP,
    PAUSE_MINTING,
    UNPAUSE_MINTING,
    FINALIZE_PARAMETER,
    REDEMPTION_FEE_FLOOR,
    CCR,
    MIN_DEBT,
    BRANCH_COLL_GAS_COMPENSATION_CAP
}

interface IEbisuBranchManager is ILiquityBase {
    struct SingleRedemptionValues {
        uint256 troveId;
        address batchAddress;
        uint256 boldLot;
        uint256 collLot;
        uint256 collFee;
        uint256 appliedRedistBoldDebtGain;
        uint256 oldWeightedRecordedDebt;
        uint256 newWeightedRecordedDebt;
        uint256 newStake;
        bool isZombieTrove;
        LatestTroveData trove;
        LatestBatchData batch;
    }

    function initialize(address _addressesRegistryAddress) external;

    function MCR() external view returns (uint256);

    function CCR() external view returns (uint256);

    function SCR() external view returns (uint256);

    function liquidationPenaltySp() external view returns (uint256);

    function liquidationPenaltyRedistribution() external view returns (uint256);

    function mintingDebtAllowed() external view returns (bool);

    function spYieldSplit() external view returns (uint256);

    function debtCap() external view returns (uint256);

    function minDebt() external view returns (uint256);

    function branchCollGasCompensationCap() external view returns (uint256);

    function requireValidAnnualInterestRate(uint256 _annualInterestRate) external view;

    function getOffsetAndRedistributionVals(
        uint256 _entireTroveDebt,
        uint256 _collToLiquidate, // gas compensation is already subtracted
        uint256 _boldInStabPool,
        uint256 _price
    )
        external
        view
        returns (
            uint256 debtToOffset,
            uint256 collToSendToSP,
            uint256 collGasCompensation,
            uint256 debtToRedistribute,
            uint256 collToRedistribute,
            uint256 collSurplus
        );

    function pauseMintingDebt() external;

    function unpauseMintingDebt() external;

    function setParameterController(Parameter parameter, address controller, bool isAuthorized) external;

    function isAuthorizedAddress(Parameter parameter, address controller) external view returns (bool);

    function setSpYieldSplit(uint256 _spYieldSplit) external;

    function finalizeParameterChange(Parameter parameter) external;

    function setMCR(uint256 _MCR) external;

    function setCCR(uint256 _CCR) external;

    function setDebtCap(uint256 _debtCap) external;

    function setBranchRedemptionFeeFloor(uint256 _redemptionFeeFloor) external;

    function setDebtCapAndRedemptionFeeFloor(uint256 _debtCap, uint256 _redemptionFeeFloor) external;

    function getTroveMinAnnualInterestRate() external view returns (uint256);

    function setInterestRouter(address _interestRouter) external;

    function cancelParameterProposal(Parameter parameter) external;

    function setMinDebt(uint256 _minDebt) external;

    function setBranchCollGasCompensationCap(uint256 _branchCollGasCompensationCap) external;

    function redeemCollateral(
        address _redeemer,
        uint256 _boldamount,
        uint256 _price,
        uint256 _redemptionRate,
        uint256 _maxIterations
    ) external returns (uint256 _redemeedAmount);

    function urgentRedemption(uint256 _boldamount, uint256[] memory _troveIds, uint256 _totalCollRedeemed) external;

    function getUnbackedPortionPriceAndRedeemability() external returns (uint256, uint256, bool);

    function shutdown() external;

    function shutdownTime() external view returns (uint256);

    function totalDebtTaken() external view returns (uint256);
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../Interfaces/IEbisuAdminRegistry.sol";
/**
 * @title EbisuUpgradeable
 * @notice Base contract for upgradeable contracts in the Ebisu protocol
 * @dev Implements timelock mechanism for upgrades and access control
 */

abstract contract EbisuUpgradeable is UUPSUpgradeable, Initializable {
    // Upgrade timelock
    address public pendingImplementation;
    uint256 public upgradeProposalTime;
    uint256 public constant UPGRADE_TIMELOCK = 7 days;

    // Registry for admin access control
    IEbisuAdminRegistry internal _ebisuAdminRegistry;

    // Events
    event UpgradeProposed(address indexed implementation, uint256 proposalTime);

    // Errors
    error NotEbisuAdmin();
    error UpgradeTimelockNotElapsed();
    error NoPendingUpgrade();
    error InvalidUpgradeImplementation();

    /**
     * @notice Modifier to restrict access to ebisu admin
     */
    modifier onlyEbisuAdmin() {
        if (msg.sender != _ebisuAdminRegistry.ebisuAdmin()) revert NotEbisuAdmin();
        _;
    }

    /**
     * @notice Proposes a new implementation for upgrade
     * @dev Starts the timelock period for the upgrade. Setting to zero address cancels any pending upgrade.
     * @param _newImplementation Address of the new implementation
     */
    function proposeUpgrade(address _newImplementation) external onlyEbisuAdmin {
        pendingImplementation = _newImplementation;
        upgradeProposalTime = block.timestamp;

        emit UpgradeProposed(_newImplementation, upgradeProposalTime);
    }

    /**
     * @dev Required by the UUPSUpgradeable module
     * @dev Override to check if the upgrade is authorized through our timelock mechanism
     * @dev This function handles both authorization and execution of the upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyEbisuAdmin {
        // Verify upgrade is authorized
        if (pendingImplementation == address(0)) revert NoPendingUpgrade();
        if (newImplementation != pendingImplementation) revert InvalidUpgradeImplementation();
        if (block.timestamp < upgradeProposalTime + UPGRADE_TIMELOCK) revert UpgradeTimelockNotElapsed();

        // Clear state
        pendingImplementation = address(0);
        upgradeProposalTime = 0;
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

address constant ZERO_ADDRESS = address(0);

uint256 constant MAX_UINT256 = type(uint256).max;

uint256 constant DECIMAL_PRECISION = 1e18;
uint256 constant _100pct = DECIMAL_PRECISION;
uint256 constant _1pct = DECIMAL_PRECISION / 100;

// Amount of ETH to be locked in gas pool on opening troves
uint256 constant ETH_GAS_COMPENSATION = 0.0375 ether;

// Liquidation
uint256 constant MIN_LIQUIDATION_PENALTY_SP = 5e16; // 5%
uint256 constant MAX_LIQUIDATION_PENALTY_REDISTRIBUTION = 20e16; // 20%

// Collateral branch parameters (SETH = staked ETH, i.e. wstETH / rETH)
uint256 constant CCR_WETH = 150 * _1pct;
uint256 constant CCR_SETH = 160 * _1pct;

uint256 constant MCR_WETH = 110 * _1pct;
uint256 constant MCR_SETH = 120 * _1pct;

uint256 constant SCR_WETH = 110 * _1pct;
uint256 constant SCR_SETH = 120 * _1pct;

// Batch CR buffer (same for all branches for now)
// On top of MCR to join a batch, or adjust inside a batch
uint256 constant BCR_ALL = 5 * _1pct;

uint256 constant LIQUIDATION_PENALTY_SP_WETH = 5 * _1pct;
uint256 constant LIQUIDATION_PENALTY_SP_SETH = 5 * _1pct;

uint256 constant LIQUIDATION_PENALTY_REDISTRIBUTION_WETH = 10 * _1pct;
uint256 constant LIQUIDATION_PENALTY_REDISTRIBUTION_SETH = 20 * _1pct;

// Fraction of collateral awarded to liquidator
uint256 constant COLL_GAS_COMPENSATION_DIVISOR = 200; // dividing by 200 yields 0.5%
uint256 constant COLL_GAS_COMPENSATION_CAP = 2 ether; // Max coll gas compensation capped at 2 ETH

// Minimum amount of net Bold debt a trove must have
uint256 constant MIN_DEBT = 2000e18;

uint256 constant MIN_ANNUAL_INTEREST_RATE = _1pct / 2; // 0.5%
uint256 constant MAX_ANNUAL_INTEREST_RATE = 250 * _1pct;

// Batch management params
uint128 constant MAX_ANNUAL_BATCH_MANAGEMENT_FEE = uint128(_100pct / 10); // 10%
uint128 constant MIN_INTEREST_RATE_CHANGE_PERIOD = 1 hours; // only applies to batch managers / batched Troves

uint256 constant REDEMPTION_FEE_FLOOR = _1pct / 2; // 0.5%

// For the debt / shares ratio to increase by a factor 1e9
// at a average annual debt increase (compounded interest + fees) of 10%, it would take more than 217 years (log(1e9)/log(1.1))
// at a average annual debt increase (compounded interest + fees) of 50%, it would take more than 51 years (log(1e9)/log(1.5))
// The increase pace could be forced to be higher through an inflation attack,
// but precisely the fact that we have this max value now prevents the attack
uint256 constant MAX_BATCH_SHARES_RATIO = 1e9;

// Half-life of 6h. 6h = 360 min
// (1/2) = d^360 => d = (1/2)^(1/360)
uint256 constant REDEMPTION_MINUTE_DECAY_FACTOR = 998076443575628800;

// BETA: 18 digit decimal. Parameter by which to divide the redeemed fraction, in order to calc the new base rate from a redemption.
// Corresponds to (1 / ALPHA) in the white paper.
uint256 constant REDEMPTION_BETA = 1;

// To prevent redemptions unless Bold depegs below 0.95 and allow the system to take off
uint256 constant INITIAL_BASE_RATE = _100pct; // 100% initial redemption rate

// Discount to be used once the shutdown thas been triggered
uint256 constant URGENT_REDEMPTION_BONUS = 2e16; // 2%

uint256 constant ONE_MINUTE = 1 minutes;
uint256 constant ONE_YEAR = 365 days;
uint256 constant UPFRONT_INTEREST_PERIOD = 7 days;
uint256 constant INTEREST_RATE_ADJ_COOLDOWN = 7 days;

uint256 constant SP_YIELD_SPLIT = 75 * _1pct; // 75%

uint256 constant MIN_BOLD_IN_SP = 1e18;

// Maximum number of collaterals allowed in the system
// Capped at 40 to ensure redemptions stay within gas limits
uint256 constant MAX_COLLATERALS = 40;

// Dummy contract that lets legacy Hardhat tests query some of the constants
contract Constants {
    uint256 public constant _ETH_GAS_COMPENSATION = ETH_GAS_COMPENSATION;
    uint256 public constant _MIN_DEBT = MIN_DEBT;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {DECIMAL_PRECISION} from "./Constants.sol";

library LiquityMath {
    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a < _b) ? _a : _b;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a >= _b) ? _a : _b;
    }

    function _sub_min_0(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b) ? _a - _b : 0;
    }

    /* 
    * Multiply two decimal numbers and use normal rounding rules:
    * -round product up if 19'th mantissa digit >= 5
    * -round product down if 19'th mantissa digit < 5
    *
    * Used only inside the exponentiation, _decPow().
    */
    function decMul(uint256 x, uint256 y) internal pure returns (uint256 decProd) {
        uint256 prod_xy = x * y;

        decProd = (prod_xy + DECIMAL_PRECISION / 2) / DECIMAL_PRECISION;
    }

    /* 
    * _decPow: Exponentiation function for 18-digit decimal base, and integer exponent n.
    * 
    * Uses the efficient "exponentiation by squaring" algorithm. O(log(n)) complexity. 
    * 
    * Called by function CollateralRegistry._calcDecayedBaseRate, that represent time in units of minutes
    *
    * The exponent is capped to avoid reverting due to overflow. The cap 525600000 equals
    * "minutes in 1000 years": 60 * 24 * 365 * 1000
    * 
    * If a period of > 1000 years is ever used as an exponent in either of the above functions, the result will be
    * negligibly different from just passing the cap, since: 
    *
    * In function 1), the decayed base rate will be 0 for 1000 years or > 1000 years
    * In function 2), the difference in tokens issued at 1000 years and any time > 1000 years, will be negligible
    */
    function _decPow(uint256 _base, uint256 _minutes) internal pure returns (uint256) {
        if (_minutes > 525600000) _minutes = 525600000; // cap to avoid overflow

        if (_minutes == 0) return DECIMAL_PRECISION;

        uint256 y = DECIMAL_PRECISION;
        uint256 x = _base;
        uint256 n = _minutes;

        // Exponentiation-by-squaring
        while (n > 1) {
            if (n % 2 == 0) {
                x = decMul(x, x);
                n = n / 2;
            } else {
                // if (n % 2 != 0)
                y = decMul(x, y);
                x = decMul(x, x);
                n = (n - 1) / 2;
            }
        }

        return decMul(x, y);
    }

    function _getAbsoluteDifference(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a >= _b) ? _a - _b : _b - _a;
    }

    function _computeCR(uint256 _coll, uint256 _debt, uint256 _price) internal pure returns (uint256) {
        if (_debt > 0) {
            uint256 newCollRatio = _coll * _price / _debt;

            return newCollRatio;
        }
        // Return the maximal value for uint256 if the debt is 0. Represents "infinite" CR.
        else {
            // if (_debt == 0)
            return 2 ** 256 - 1;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IInterestRouter.sol";
import "./IBoldRewardsReceiver.sol";
import "../Types/TroveChange.sol";

interface IActivePool {
    function initialize(address _addressesRegistryAddress) external;

    function defaultPoolAddress() external view returns (address);
    function borrowerOperationsAddress() external view returns (address);
    function troveManagerAddress() external view returns (address);
    function interestRouter() external view returns (IInterestRouter);
    // We avoid IStabilityPool here in order to prevent creating a dependency cycle that would break flattening
    function stabilityPool() external view returns (IBoldRewardsReceiver);

    function getCollBalance() external view returns (uint256);
    function getBoldDebt() external view returns (uint256);
    function lastAggUpdateTime() external view returns (uint256);
    function aggRecordedDebt() external view returns (uint256);
    function aggWeightedDebtSum() external view returns (uint256);
    function aggBatchManagementFees() external view returns (uint256);
    function aggWeightedBatchManagementFeeSum() external view returns (uint256);
    function calcPendingAggInterest() external view returns (uint256);
    function calcPendingSPYield() external view returns (uint256);
    function calcPendingAggBatchManagementFee() external view returns (uint256);
    function getNewApproxAvgInterestRateFromTroveChange(TroveChange calldata _troveChange)
        external
        view
        returns (uint256);

    function mintAggInterest() external;
    function mintAggInterestAndAccountForTroveChange(TroveChange calldata _troveChange, address _batchManager)
        external;
    function mintBatchManagementFeeAndAccountForChange(TroveChange calldata _troveChange, address _batchAddress)
        external;

    function setShutdownFlag() external;
    function hasBeenShutDown() external view returns (bool);
    function shutdownTime() external view returns (uint256);

    function sendColl(address _account, uint256 _amount) external;
    function sendCollToDefaultPool(uint256 _amount) external;
    function receiveColl(uint256 _amount) external;
    function accountForReceivedColl(uint256 _amount) external;
    function totalDebtTaken() external view returns (uint256);
    function setInterestRouter(address _newInterestRouter) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IDefaultPool {
    function initialize(address _addressesRegistryAddress) external;

    function troveManagerAddress() external view returns (address);
    function activePoolAddress() external view returns (address);
    // --- Functions ---
    function getCollBalance() external view returns (uint256);
    function getBoldDebt() external view returns (uint256);
    function sendCollToActivePool(uint256 _amount) external;
    function receiveColl(uint256 _amount) external;

    function increaseBoldDebt(uint256 _amount) external;
    function decreaseBoldDebt(uint256 _amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IActivePool.sol";
import "./IDefaultPool.sol";
import "./IPriceFeed.sol";

interface ILiquityBase {
    function activePool() external view returns (IActivePool);
    function getEntireBranchDebt() external view returns (uint256);
    function getEntireBranchColl() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAddRemoveManagers {
    function setAddManager(uint256 _troveId, address _manager) external;
    function setRemoveManager(uint256 _troveId, address _manager) external;
    function setRemoveManagerWithReceiver(uint256 _troveId, address _manager, address _receiver) external;
    function addManagerOf(uint256 _troveId) external view returns (address);
    function removeManagerReceiverOf(uint256 _troveId) external view returns (address, address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import "./ITroveManager.sol";

interface ITroveNFT is IERC721MetadataUpgradeable {
    function mint(address _owner, uint256 _troveId) external;
    function burn(uint256 _troveId) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IWETH is IERC20Metadata {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "../Interfaces/ITroveManager.sol";
import "../Interfaces/IActivePool.sol";
import "../Interfaces/IBoldToken.sol";
import "../Types/LatestTroveData.sol";
import "../Types/LatestBatchData.sol";
import "../Interfaces/ISortedTroves.sol";

// -- individual delegation --
struct InterestIndividualDelegate {
    address account;
    uint128 minInterestRate;
    uint128 maxInterestRate;
    uint256 minInterestRateChangePeriod;
}

struct InterestBatchManager {
    uint128 minInterestRate;
    uint128 maxInterestRate;
    uint256 minInterestRateChangePeriod;
}

struct LocalVariables_openTrove {
    ITroveManager troveManager;
    IActivePool activePool;
    IBoldToken boldToken;
    uint256 troveId;
    uint256 price;
    uint256 avgInterestRate;
    uint256 entireDebt;
    uint256 ICR;
    uint256 newTCR;
    bool newOracleFailureDetected;
}

struct LocalVariables_adjustTrove {
    IActivePool activePool;
    IBoldToken boldToken;
    LatestTroveData trove;
    uint256 price;
    bool isBelowCriticalThreshold;
    uint256 newICR;
    uint256 newDebt;
    uint256 newColl;
    bool newOracleFailureDetected;
}

struct LocalVariables_setInterestBatchManager {
    ITroveManager troveManager;
    IActivePool activePool;
    ISortedTroves sortedTroves;
    address oldBatchManager;
    LatestTroveData trove;
    LatestBatchData oldBatch;
    LatestBatchData newBatch;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHintHelpers {
    function getApproxHint(uint256 _collIndex, uint256 _interestRate, uint256 _numTrials, uint256 _inputRandomSeed)
        external
        view
        returns (uint256 hintId, uint256 diff, uint256 latestRandomSeed);

    function predictOpenTroveUpfrontFee(uint256 _collIndex, uint256 _borrowedAmount, uint256 _interestRate)
        external
        view
        returns (uint256);

    function predictAdjustInterestRateUpfrontFee(uint256 _collIndex, uint256 _troveId, uint256 _newInterestRate)
        external
        view
        returns (uint256);

    function forcePredictAdjustInterestRateUpfrontFee(uint256 _collIndex, uint256 _troveId, uint256 _newInterestRate)
        external
        view
        returns (uint256);

    function predictAdjustTroveUpfrontFee(uint256 _collIndex, uint256 _troveId, uint256 _debtIncrease)
        external
        view
        returns (uint256);

    function predictAdjustBatchInterestRateUpfrontFee(
        uint256 _collIndex,
        address _batchAddress,
        uint256 _newInterestRate
    ) external view returns (uint256);

    function predictJoinBatchInterestRateUpfrontFee(uint256 _collIndex, uint256 _troveId, address _batchAddress)
        external
        view
        returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMultiTroveGetter {
    struct CombinedTroveData {
        uint256 id;
        uint256 entireDebt;
        uint256 entireColl;
        uint256 redistBoldDebtGain;
        uint256 redistCollGain;
        uint256 accruedInterest;
        uint256 recordedDebt;
        uint256 annualInterestRate;
        uint256 accruedBatchManagementFee;
        uint256 lastInterestRateAdjTime;
        uint256 stake;
        uint256 lastDebtUpdateTime;
        address interestBatchManager;
        uint256 batchDebtShares;
        uint256 snapshotETH;
        uint256 snapshotBoldDebt;
    }

    struct DebtPerInterestRate {
        address interestBatchManager;
        uint256 interestRate;
        uint256 debt;
    }

    function getMultipleSortedTroves(uint256 _collIndex, int256 _startIdx, uint256 _count)
        external
        view
        returns (CombinedTroveData[] memory _troves);

    function getDebtPerInterestRateAscending(uint256 _collIndex, uint256 _startId, uint256 _maxIterations)
        external
        view
        returns (DebtPerInterestRate[] memory, uint256 currId);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ILiquityBase.sol";
import "./IBoldToken.sol";
import "./ITroveManager.sol";
import "./IBoldRewardsReceiver.sol";

/*
 * The Stability Pool holds Bold tokens deposited by Stability Pool depositors.
 *
 * When a trove is liquidated, then depending on system conditions, some of its Bold debt gets offset with
 * Bold in the Stability Pool:  that is, the offset debt evaporates, and an equal amount of Bold tokens in the Stability Pool is burned.
 *
 * Thus, a liquidation causes each depositor to receive a Bold loss, in proportion to their deposit as a share of total deposits.
 * They also receive an Coll gain, as the collateral of the liquidated trove is distributed among Stability depositors,
 * in the same proportion.
 *
 * When a liquidation occurs, it depletes every deposit by the same fraction: for example, a liquidation that depletes 40%
 * of the total Bold in the Stability Pool, depletes 40% of each deposit.
 *
 * A deposit that has experienced a series of liquidations is termed a "compounded deposit": each liquidation depletes the deposit,
 * multiplying it by some factor in range ]0,1[
 *
 * Please see the implementation spec in the proof document, which closely follows on from the compounded deposit / Coll gain derivations:
 * https://github.com/liquity/liquity/blob/master/papers/Scalable_Reward_Distribution_with_Compounding_Stakes.pdf
 *
*/
interface IStabilityPool is ILiquityBase, IBoldRewardsReceiver {
    function initialize(address _addressesRegistryAddress) external;
    function boldToken() external view returns (IBoldToken);
    function troveManager() external view returns (ITroveManager);

    /*  provideToSP():
    * - Calculates depositor's Coll gain
    * - Calculates the compounded deposit
    * - Increases deposit, and takes new snapshots of accumulators P and S
    * - Sends depositor's accumulated Coll gains to depositor
    */
    function provideToSP(uint256 _amount, bool _doClaim) external;

    /*  withdrawFromSP():
    * - Calculates depositor's Coll gain
    * - Calculates the compounded deposit
    * - Sends the requested BOLD withdrawal to depositor
    * - (If _amount > userDeposit, the user withdraws all of their compounded deposit)
    * - Decreases deposit by withdrawn amount and takes new snapshots of accumulators P and S
    */
    function withdrawFromSP(uint256 _amount, bool doClaim) external;

    function claimAllCollGains() external;

    /*
     * Initial checks:
     * - Caller is TroveManager
     * ---
     * Cancels out the specified debt against the Bold contained in the Stability Pool (as far as possible)
     * and transfers the Trove's collateral from ActivePool to StabilityPool.
     * Only called by liquidation functions in the TroveManager.
     */
    function offset(uint256 _debt, uint256 _coll) external;

    function deposits(address _depositor) external view returns (uint256 initialValue);
    function stashedColl(address _depositor) external view returns (uint256);

    /*
     * Returns the total amount of Coll held by the pool, accounted in an internal variable instead of `balance`,
     * to exclude edge cases like Coll received from a self-destruct.
     */
    function getCollBalance() external view returns (uint256);

    /*
     * Returns Bold held in the pool. Changes when users deposit/withdraw, and when Trove debt is offset.
     */
    function getTotalBoldDeposits() external view returns (uint256);

    function getYieldGainsOwed() external view returns (uint256);
    function getYieldGainsPending() external view returns (uint256);

    /*
     * Calculates the Coll gain earned by the deposit since its last snapshots were taken.
     */
    function getDepositorCollGain(address _depositor) external view returns (uint256);

    /*
     * Calculates the BOLD yield gain earned by the deposit since its last snapshots were taken.
     */
    function getDepositorYieldGain(address _depositor) external view returns (uint256);

    /*
     * Calculates what `getDepositorYieldGain` will be if interest is minted now.
     */
    function getDepositorYieldGainWithPending(address _depositor) external view returns (uint256);

    /*
     * Return the user's compounded deposit.
     */
    function getCompoundedBoldDeposit(address _depositor) external view returns (uint256);

    function scaleToS(uint256 _scale) external view returns (uint256);

    function scaleToB(uint256 _scale) external view returns (uint256);

    function P() external view returns (uint256);
    function currentScale() external view returns (uint256);

    function P_PRECISION() external view returns (uint256);
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "Solady/utils/SSTORE2.sol";
import "./utils/JSON.sol";

import "./utils/baseSVG.sol";
import "./utils/ebisu.sol";

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ITroveManager} from "../Interfaces/ITroveManager.sol";

interface IMetadataNFT {
    struct TroveData {
        uint256 _tokenId;
        address _owner;
        address _collToken;
        address _boldToken;
        uint256 _collAmount;
        uint256 _debtAmount;
        uint256 _interestRate;
        ITroveManager.Status _status;
    }

    function uri(TroveData memory _troveData) external view returns (string memory);
}

contract MetadataNFT is IMetadataNFT {
    FixedAssetReader public immutable mainAssetReader;
    FixedAssetReader public immutable heroAssetReader;

    constructor(FixedAssetReader _mainAssetReader, FixedAssetReader _heroAssetReader) {
        mainAssetReader = _mainAssetReader;
        heroAssetReader = _heroAssetReader;
    }

    function uri(TroveData memory _troveData) public view returns (string memory) {
        string memory attr = attributes(_troveData);
        return json.formattedMetadata(
            string.concat("Ebisu Money - ", IERC20Metadata(_troveData._collToken).name()),
            string.concat(
                "Ebisu Money is a collateralized debt platform. Users can lock up ",
                IERC20Metadata(_troveData._collToken).symbol(),
                " to issue stablecoin tokens (ebUSD) to their own Ethereum address. The individual collateralized debt positions are called Troves, and are represented as NFTs."
            ),
            renderSVGImage(_troveData),
            attr
        );
    }

    function renderSVGImage(TroveData memory _troveData) internal view returns (string memory) {
        return svg._svg(
            baseSVG._svgProps(),
            string.concat(
                baseSVG._baseElements(mainAssetReader),
                ebisuSVG._hero(_troveData._tokenId, heroAssetReader),
                dynamicTextComponents(_troveData)
            )
        );
    }

    function attributes(TroveData memory _troveData) public pure returns (string memory) {
        //include: collateral token address, collateral amount, debt token address, debt amount, interest rate, status
        return string.concat(
            '[{"trait_type": "Collateral Token", "value": "',
            LibString.toHexString(_troveData._collToken),
            '"}, {"trait_type": "Collateral Amount", "value": "',
            LibString.toString(_troveData._collAmount),
            '"}, {"trait_type": "Debt Token", "value": "',
            LibString.toHexString(_troveData._boldToken),
            '"}, {"trait_type": "Debt Amount", "value": "',
            LibString.toString(_troveData._debtAmount),
            '"}, {"trait_type": "Interest Rate", "value": "',
            LibString.toString(_troveData._interestRate),
            '"}, {"trait_type": "Status", "value": "',
            _status2Str(_troveData._status),
            '"} ]'
        );
    }

    function dynamicTextComponents(TroveData memory _troveData) public view returns (string memory) {
        string memory id = LibString.toHexString(_troveData._tokenId);
        id = string.concat(LibString.slice(id, 0, 6), "...", LibString.slice(id, 38, 42));

        uint8 collDecimals = IERC20Metadata(_troveData._collToken).decimals();

        return string.concat(
            baseSVG._formattedIdEl(id),
            baseSVG._formattedAddressEl(_troveData._owner),
            baseSVG._collLogo("COLLATERAL", mainAssetReader),
            baseSVG._statusEl(_status2Str(_troveData._status)),
            baseSVG._dynamicTextEls(_troveData._debtAmount, _troveData._collAmount, _troveData._interestRate, collDecimals)
        );
    }

    function _status2Str(ITroveManager.Status status) internal pure returns (string memory) {
        if (status == ITroveManager.Status.active) return "Active";
        if (status == ITroveManager.Status.closedByOwner) return "Closed";
        if (status == ITroveManager.Status.closedByLiquidation) return "Liquidated";
        if (status == ITroveManager.Status.zombie) return "Below Min Debt";
        return "";
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IBoldToken.sol";
import {ITroveManager} from "./ITroveManager.sol";
import "./IEbisuAdminRegistry.sol";
import "./IEbisuBranchManager.sol";
import "openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ICollateralRegistry is IEbisuAdminRegistry {
    function baseRate() external view returns (uint256);
    function lastFeeOperationTime() external view returns (uint256);

    function redeemCollateral(uint256 _boldamount, uint256 _maxIterations, uint256 _maxFeePercentage) external;
    // getters
    function totalCollaterals() external view returns (uint256);
    function getToken(uint256 _index) external view returns (IERC20Metadata);
    function getTroveManager(uint256 _index) external view returns (ITroveManager);
    function boldToken() external view returns (IBoldToken);
    function branchFactoryAddress() external view returns (address);
    function troveManagerAddresses(address _address) external view returns (bool);
    function branchManagerAddresses(address _address) external view returns (bool);
    function stabilityPoolAddresses(address _address) external view returns (bool);
    function borrowerOperationsAddresses(address _address) external view returns (bool);
    function activePoolAddresses(address _address) external view returns (bool);

    function getRedemptionRate() external view returns (uint256);
    function getRedemptionRateWithDecay() external view returns (uint256);
    function getBranchRedemptionRate(uint256 _index) external view returns (uint256);
    function getBranchRedemptionRateWithDecay(uint256 _index) external view returns (uint256);
    function getRedemptionRateForRedeemedAmount(uint256 _redeemAmount) external view returns (uint256);

    function getRedemptionFeeWithDecay(uint256 _ETHDrawn) external view returns (uint256);
    function getEffectiveRedemptionFeeInBold(uint256 _redeemAmount) external view returns (uint256);
    function getTokenIndex(address _token) external view returns (uint256);
    function redemptionFeeFloors(uint256 _index) external view returns (uint256);

    // add branches
    function addNewBranch(
        address _token,
        ITroveManager _troveManager,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress,
        address _activePoolAddress,
        IEbisuBranchManager _branchManager
    ) external;

    function setBranchRedemptionFeeFloor(address _token, uint256 _redemptionFeeFloor) external;

    function getHighestRedemptionRateWithDecay() external view returns (uint256);

    function setBranchFactory(address _branchFactory) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IInterestRouter {
// Currently the Interest Router doesn’t need any specific function
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

// Store the necessary data for an interest batch manager. We treat each batch as a "big trove".
// Each trove has a share of the debt of the global batch. Collateral is stored per trove (as CRs are different)
// Still the total amount of batch collateral is stored for informational purposes
struct Batch {
    uint256 debt;
    uint256 coll;
    uint64 arrayIndex;
    uint64 lastDebtUpdateTime;
    uint64 lastInterestRateAdjTime;
    uint256 annualInterestRate;
    uint256 annualManagementFee;
    uint256 totalDebtShares;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

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

pragma solidity 0.8.24;

type BatchId is address;

using {equals as ==, notEquals as !=, isZero, isNotZero} for BatchId global;

function equals(BatchId a, BatchId b) pure returns (bool) {
    return BatchId.unwrap(a) == BatchId.unwrap(b);
}

function notEquals(BatchId a, BatchId b) pure returns (bool) {
    return !(a == b);
}

function isZero(BatchId x) pure returns (bool) {
    return x == BATCH_ID_ZERO;
}

function isNotZero(BatchId x) pure returns (bool) {
    return !x.isZero();
}

BatchId constant BATCH_ID_ZERO = BatchId.wrap(address(0));

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822.sol";
import "../ERC1967/ERC1967Upgrade.sol";

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
abstract contract UUPSUpgradeable is IERC1822Proxiable, ERC1967Upgrade {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
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
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
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
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
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
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/Address.sol";

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
        require(
            (isTopLevelCall && _initialized < 1) || (!Address.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
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
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
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
        require(_initializing, "Initializable: contract is not initializing");
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
        require(!_initializing, "Initializable: contract is initializing");
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

interface IEbisuAdminRegistry {
    function ebisuAdmin() external view returns (address);
    function transferEbisuAdmin(address _newEbisuAdmin) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBoldRewardsReceiver {
    function triggerBoldRewards(uint256 _boldYield) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

struct TroveChange {
    uint256 appliedRedistBoldDebtGain;
    uint256 appliedRedistCollGain;
    uint256 collIncrease;
    uint256 collDecrease;
    uint256 debtIncrease;
    uint256 debtDecrease;
    uint256 newWeightedRecordedDebt;
    uint256 oldWeightedRecordedDebt;
    uint256 upfrontFee;
    uint256 batchAccruedManagementFee;
    uint256 newWeightedRecordedBatchManagementFee;
    uint256 oldWeightedRecordedBatchManagementFee;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721MetadataUpgradeable is IERC721Upgradeable {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Read and write to persistent storage at a fraction of the cost.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SSTORE2.sol)
/// @author Saw-mon-and-Natalie (https://github.com/Saw-mon-and-Natalie)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SSTORE2.sol)
/// @author Modified from 0xSequence (https://github.com/0xSequence/sstore2/blob/master/contracts/SSTORE2.sol)
/// @author Modified from SSTORE3 (https://github.com/Philogy/sstore3)
library SSTORE2 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The proxy initialization code.
    uint256 private constant _CREATE3_PROXY_INITCODE = 0x67363d3d37363d34f03d5260086018f3;

    /// @dev Hash of the `_CREATE3_PROXY_INITCODE`.
    /// Equivalent to `keccak256(abi.encodePacked(hex"67363d3d37363d34f03d5260086018f3"))`.
    bytes32 internal constant CREATE3_PROXY_INITCODE_HASH =
        0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unable to deploy the storage contract.
    error DeploymentFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         WRITE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Writes `data` into the bytecode of a storage contract and returns its address.
    function write(bytes memory data) internal returns (address pointer) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data) // Let `l` be `n + 1`. +1 as we prefix a STOP opcode.
            /**
             * ---------------------------------------------------+
             * Opcode | Mnemonic       | Stack     | Memory       |
             * ---------------------------------------------------|
             * 61 l   | PUSH2 l        | l         |              |
             * 80     | DUP1           | l l       |              |
             * 60 0xa | PUSH1 0xa      | 0xa l l   |              |
             * 3D     | RETURNDATASIZE | 0 0xa l l |              |
             * 39     | CODECOPY       | l         | [0..l): code |
             * 3D     | RETURNDATASIZE | 0 l       | [0..l): code |
             * F3     | RETURN         |           | [0..l): code |
             * 00     | STOP           |           |              |
             * ---------------------------------------------------+
             * @dev Prefix the bytecode with a STOP opcode to ensure it cannot be called.
             * Also PUSH2 is used since max contract size cap is 24,576 bytes which is less than 2 ** 16.
             */
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            // Deploy a new contract with the generated creation code.
            pointer := create(0, add(data, 0x15), add(n, 0xb))
            if iszero(pointer) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Writes `data` into the bytecode of a storage contract with `salt`
    /// and returns its normal CREATE2 deterministic address.
    function writeCounterfactual(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            // Deploy a new contract with the generated creation code.
            pointer := create2(0, add(data, 0x15), add(n, 0xb), salt)
            if iszero(pointer) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Writes `data` into the bytecode of a storage contract and returns its address.
    /// This uses the so-called "CREATE3" workflow,
    /// which means that `pointer` is agnostic to `data, and only depends on `salt`.
    function writeDeterministic(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            mstore(0x00, _CREATE3_PROXY_INITCODE) // Store the `_PROXY_INITCODE`.
            let proxy := create2(0, 0x10, 0x10, salt)
            if iszero(proxy) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(0x14, proxy) // Store the proxy's address.
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01) // Nonce of the proxy contract (1).
            pointer := keccak256(0x1e, 0x17)

            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            mstore(add(data, gt(n, 0xfffe)), add(0xfe61000180600a3d393df300, shl(0x40, n)))
            if iszero(
                mul( // The arguments of `mul` are evaluated last to first.
                    extcodesize(pointer),
                    call(gas(), proxy, 0, add(data, 0x15), add(n, 0xb), codesize(), 0x00)
                )
            ) {
                mstore(0x00, 0x30116425) // `DeploymentFailed()`.
                revert(0x1c, 0x04)
            }
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    ADDRESS CALCULATIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the initialization code hash of the storage contract for `data`.
    /// Used for mining vanity addresses with create2crunch.
    function initCodeHash(bytes memory data) internal pure returns (bytes32 hash) {
        /// @solidity memory-safe-assembly
        assembly {
            let n := mload(data)
            // Do a out-of-gas revert if `n + 1` is more than 2 bytes.
            returndatacopy(returndatasize(), returndatasize(), gt(n, 0xfffe))
            mstore(data, add(0x61000180600a3d393df300, shl(0x40, n)))
            hash := keccak256(add(data, 0x15), add(n, 0xb))
            mstore(data, n) // Restore the length of `data`.
        }
    }

    /// @dev Equivalent to `predictCounterfactualAddress(data, salt, address(this))`
    function predictCounterfactualAddress(bytes memory data, bytes32 salt)
        internal
        view
        returns (address pointer)
    {
        pointer = predictCounterfactualAddress(data, salt, address(this));
    }

    /// @dev Returns the CREATE2 address of the storage contract for `data`
    /// deployed with `salt` by `deployer`.
    /// Note: The returned result has dirty upper 96 bits. Please clean if used in assembly.
    function predictCounterfactualAddress(bytes memory data, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 hash = initCodeHash(data);
        /// @solidity memory-safe-assembly
        assembly {
            // Compute and store the bytecode hash.
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, hash)
            mstore(0x01, shl(96, deployer))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x35, 0)
        }
    }

    /// @dev Equivalent to `predictDeterministicAddress(salt, address(this))`.
    function predictDeterministicAddress(bytes32 salt) internal view returns (address pointer) {
        pointer = predictDeterministicAddress(salt, address(this));
    }

    /// @dev Returns the "CREATE3" deterministic address for `salt` with `deployer`.
    function predictDeterministicAddress(bytes32 salt, address deployer)
        internal
        pure
        returns (address pointer)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.
            mstore(0x00, deployer) // Store `deployer`.
            mstore8(0x0b, 0xff) // Store the prefix.
            mstore(0x20, salt) // Store the salt.
            mstore(0x40, CREATE3_PROXY_INITCODE_HASH) // Store the bytecode hash.

            mstore(0x14, keccak256(0x0b, 0x55)) // Store the proxy's address.
            mstore(0x40, m) // Restore the free memory pointer.
            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01).
            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex).
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01) // Nonce of the proxy contract (1).
            pointer := keccak256(0x1e, 0x17)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         READ LOGIC                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to `read(pointer, 0, 2 ** 256 - 1)`.
    function read(address pointer) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            let n := and(sub(extcodesize(pointer), 0x01), 0xffffffffff)
            extcodecopy(pointer, add(data, 0x1f), 0x00, add(n, 0x21))
            mstore(data, n) // Store the length.
            mstore(0x40, add(n, add(data, 0x40))) // Allocate memory.
        }
    }

    /// @dev Equivalent to `read(pointer, start, 2 ** 256 - 1)`.
    function read(address pointer, uint256 start) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            let n := and(sub(extcodesize(pointer), 0x01), 0xffffffffff)
            extcodecopy(pointer, add(data, 0x1f), start, add(n, 0x21))
            mstore(data, mul(sub(n, start), lt(start, n))) // Store the length.
            mstore(0x40, add(data, add(0x40, mload(data)))) // Allocate memory.
        }
    }

    /// @dev Returns a slice of the data on `pointer` from `start` to `end`.
    /// `start` and `end` will be clamped to the range `[0, args.length]`.
    /// The `pointer` MUST be deployed via the SSTORE2 write functions.
    /// Otherwise, the behavior is undefined.
    /// Out-of-gas reverts if `pointer` does not have any code.
    function read(address pointer, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory data)
    {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            if iszero(lt(end, 0xffff)) { end := 0xffff }
            let d := mul(sub(end, start), lt(start, end))
            extcodecopy(pointer, add(data, 0x1f), start, add(d, 0x01))
            if iszero(and(0xff, mload(add(data, d)))) {
                let n := sub(extcodesize(pointer), 0x01)
                returndatacopy(returndatasize(), returndatasize(), shr(64, n))
                d := mul(gt(n, start), sub(d, mul(gt(end, n), sub(end, n))))
            }
            mstore(data, d) // Store the length.
            mstore(add(add(data, 0x20), d), 0) // Zeroize the slot after the bytes.
            mstore(0x40, add(add(data, 0x40), d)) // Allocate memory.
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// JSON utilities for base64 encoded ERC721 JSON metadata scheme
library json {
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// @dev JSON requires that double quotes be escaped or JSONs will not build correctly
    /// string.concat also requires an escape, use \\" or the constant DOUBLE_QUOTES to represent " in JSON
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////

    string constant DOUBLE_QUOTES = '\\"';

    function formattedMetadata(
        string memory name,
        string memory description,
        string memory svgImg,
        string memory attributes
    ) internal pure returns (string memory) {
        return string.concat(
            "data:application/json;base64,",
            encode(
                bytes(
                    string.concat(
                        "{",
                        _prop("name", name),
                        _prop("description", description),
                        _xmlImage(svgImg),
                        ',"attributes":',
                        attributes,
                        "}"
                    )
                )
            )
        );
    }

    function _xmlImage(string memory _svgImg) internal pure returns (string memory) {
        return _prop("image", string.concat("data:image/svg+xml;base64,", encode(bytes(_svgImg))), true);
    }

    function _prop(string memory _key, string memory _val) internal pure returns (string memory) {
        return string.concat('"', _key, '": ', '"', _val, '", ');
    }

    function _prop(string memory _key, string memory _val, bool last) internal pure returns (string memory) {
        if (last) {
            return string.concat('"', _key, '": ', '"', _val, '"');
        } else {
            return string.concat('"', _key, '": ', '"', _val, '", ');
        }
    }

    function _object(string memory _key, string memory _val) internal pure returns (string memory) {
        return string.concat('"', _key, '": ', "{", _val, "}");
    }

    /**
     * taken from Openzeppelin
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {} {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 { mstore8(sub(resultPtr, 1), 0x3d) }
        }

        return result;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {svg} from "./SVG.sol";
import {utils, LibString, numUtils} from "./Utils.sol";
import "./FixedAssets.sol";

library baseSVG {
    string constant GEIST = 'style="font-family: Geist" ';
    string constant DARK_BLUE = "#010101";
    string constant STOIC_WHITE = "#FCF7F2";

    function _svgProps() internal pure returns (string memory) {
        return string.concat(
            svg.prop("width", "300"),
            svg.prop("height", "484"),
            svg.prop("viewBox", "0 0 300 484"),
            svg.prop("style", "background:none")
        );
    }

    function _baseElements(FixedAssetReader _assetReader) internal view returns (string memory) {
        return string.concat(
            svg.rect(
                string.concat(
                    svg.prop("fill", DARK_BLUE),
                    svg.prop("rx", "8"),
                    svg.prop("width", "300"),
                    svg.prop("height", "484")
                )
            ),
            _styles(_assetReader),
            _leverageLogo(),
            _boldLogo(_assetReader),
            _staticTextEls()
        );
    }

    function _styles(FixedAssetReader _assetReader) private view returns (string memory) {
        return svg.el(
            "style",
            utils.NULL,
            string.concat(
                '@font-face { font-family: "Geist"; src: url("data:font/woff2;utf-8;base64,',
                _assetReader.readAsset(bytes4(keccak256("geist"))),
                '"); }'
            )
        );
    }

    function _leverageLogo() internal pure returns (string memory) {
        return string.concat(
            svg.path(
                "M20.2 31.2C19.1 32.4 17.6 33 16 33L16 21C17.6 21 19.1 21.6 20.2 22.7C21.4 23.9 22 25.4 22 27C22 28.6 21.4 30.1 20.2 31.2Z",
                svg.prop("fill", STOIC_WHITE)
            ),
            svg.path(
                "M22 27C22 25.4 22.6 23.9 23.8 22.7C25 21.6 26.4 21 28 21V33C26.4 33 25 32.4 24 31.2C22.6 30.1 22 28.6 22 27Z",
                svg.prop("fill", STOIC_WHITE)
            )
        );
    }

    function _boldLogo(FixedAssetReader _assetReader) internal view returns (string memory) {
        return svg.el(
            "image",
            string.concat(
                svg.prop("x", "264"),
                svg.prop("y", "373.5"),
                svg.prop("width", "20"),
                svg.prop("height", "20"),
                svg.prop(
                    "href",
                    string.concat("data:image/svg+xml;base64,", _assetReader.readAsset(bytes4(keccak256("EBUSD"))))
                )
            )
        );
    }

    function _staticTextEls() internal pure returns (string memory) {
        return string.concat(
            svg.text(
                string.concat(
                    GEIST,
                    svg.prop("x", "16"),
                    svg.prop("y", "358"),
                    svg.prop("font-size", "14"),
                    svg.prop("fill", "white")
                ),
                "Collateral"
            ),
            svg.text(
                string.concat(
                    GEIST,
                    svg.prop("x", "16"),
                    svg.prop("y", "389"),
                    svg.prop("font-size", "14"),
                    svg.prop("fill", "white")
                ),
                "Debt"
            ),
            svg.text(
                string.concat(
                    GEIST,
                    svg.prop("x", "16"),
                    svg.prop("y", "420"),
                    svg.prop("font-size", "14"),
                    svg.prop("fill", "white")
                ),
                "Interest Rate"
            ),
            svg.text(
                string.concat(
                    GEIST,
                    svg.prop("x", "265"),
                    svg.prop("y", "422"),
                    svg.prop("font-size", "20"),
                    svg.prop("fill", "white")
                ),
                "%"
            ),
            svg.text(
                string.concat(
                    GEIST,
                    svg.prop("x", "16"),
                    svg.prop("y", "462"),
                    svg.prop("font-size", "14"),
                    svg.prop("fill", "white")
                ),
                "Owner"
            )
        );
    }

    function _formattedDynamicEl(string memory _value, uint256 _x, uint256 _y) internal pure returns (string memory) {
        return svg.text(
            string.concat(
                GEIST,
                svg.prop("text-anchor", "end"),
                svg.prop("x", LibString.toString(_x)),
                svg.prop("y", LibString.toString(_y)),
                svg.prop("font-size", "20"),
                svg.prop("fill", "white")
            ),
            _value
        );
    }

    function _formattedIdEl(string memory _id) internal pure returns (string memory) {
        return svg.text(
            string.concat(
                GEIST,
                svg.prop("text-anchor", "end"),
                svg.prop("x", "284"),
                svg.prop("y", "33"),
                svg.prop("font-size", "14"),
                svg.prop("fill", "white")
            ),
            _id
        );
    }

    function _formattedAddressEl(address _address) internal pure returns (string memory) {
        return svg.text(
            string.concat(
                GEIST,
                svg.prop("text-anchor", "end"),
                svg.prop("x", "284"),
                svg.prop("y", "462"),
                svg.prop("font-size", "14"),
                svg.prop("fill", "white")
            ),
            string.concat(
                LibString.slice(LibString.toHexStringChecksummed(_address), 0, 6),
                "...",
                LibString.slice(LibString.toHexStringChecksummed(_address), 38, 42)
            )
        );
    }

    function _collLogo(string memory _collName, FixedAssetReader _assetReader) internal view returns (string memory) {
        return svg.el(
            "image",
            string.concat(
                svg.prop("x", "264"),
                svg.prop("y", "342.5"),
                svg.prop("width", "20"),
                svg.prop("height", "20"),
                svg.prop(
                    "href",
                    string.concat(
                        "data:image/svg+xml;base64,", _assetReader.readAsset(bytes4(keccak256(bytes(_collName))))
                    )
                )
            )
        );
    }

    function _statusEl(string memory _status) internal pure returns (string memory) {
        return svg.text(
            string.concat(
                GEIST, svg.prop("x", "40"), svg.prop("y", "33"), svg.prop("font-size", "14"), svg.prop("fill", "white")
            ),
            _status
        );
    }

    function _dynamicTextEls(uint256 _debt, uint256 _coll, uint256 _annualInterestRate, uint8 _collDecimals)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            // Collateral amount - uses token's actual decimals (e.g., 6 for USDC, 18 for WETH)
            _formattedDynamicEl(numUtils.toLocaleString(_coll, _collDecimals, 4), 256, 360),
            // Debt amount (BOLD) - always 18 decimals
            _formattedDynamicEl(numUtils.toLocaleString(_debt, 18, 2), 256, 391),
            // Interest rate - always 16 decimals (basis points)
            _formattedDynamicEl(numUtils.toLocaleString(_annualInterestRate, 16, 2), 256, 422)
        );
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./SVG.sol";
import "./FixedAssets.sol";

library ebisuSVG {
    string constant A = "#EE4F9C";
    string constant B = "#FCF7F2";
    string constant C = "#FFF172";
    string constant D = "#AF96FB";
    string constant E = "#FC7339";
    string constant F = "#BEFF6C";
    string constant G = "#EFEFEF";
    string constant H = "#49DBC8";
    string constant I = "#F5D93A";

    function _hero(uint256 _troveId, FixedAssetReader _assetReader) internal view returns (string memory) {
        uint256 variant = _troveId % 9;
        string memory color;

        if (variant == 0) {
            color = A;
        } else if (variant == 1) {
            color = B;
        } else if (variant == 2) {
            color = C;
        } else if (variant == 3) {
            color = D;
        } else if (variant == 4) {
            color = E;
        } else if (variant == 5) {
            color = F;
        } else if (variant == 6) {
            color = G;
        } else if (variant == 7) {
            color = H;
        } else {
            color = I;
        }

        return string.concat(
            svg.rect(
                string.concat(
                    svg.prop("x", "16"),
                    svg.prop("y", "55"),
                    svg.prop("width", "268"),
                    svg.prop("height", "268"),
                    svg.prop("fill", color)
                )
            ),
            svg.el(
                "image",
                string.concat(
                    svg.prop("x", "16"),
                    svg.prop("y", "63"),
                    svg.prop("width", "268"),
                    svg.prop("height", "268"),
                    svg.prop(
                        "href",
                        string.concat(
                            "data:image/svg+xml;base64,", _assetReader.readAsset(bytes4(keccak256(bytes("HERO"))))
                        )
                    )
                )
            )
        );
    }
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
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
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
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeacon.sol";
import "../../interfaces/IERC1967.sol";
import "../../interfaces/draft-IERC1822.sol";
import "../../utils/Address.sol";
import "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 */
abstract contract ERC1967Upgrade is IERC1967 {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data, bool forceCall) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {utils, LibString} from "./Utils.sol";

/// @notice Core SVG utility library which helps us construct onchain SVG's with a simple, web-like API.
/// @author Modified from (https://github.com/w1nt3r-eth/hot-chain-svg/blob/main/contracts/SVG.sol) by w1nt3r-eth.

library svg {
    /* GLOBAL CONSTANTS */
    string internal constant _SVG = 'xmlns="http://www.w3.org/2000/svg"';
    string internal constant _HTML = 'xmlns="http://www.w3.org/1999/xhtml"';
    string internal constant _XMLNS = "http://www.w3.org/2000/xmlns/ ";
    string internal constant _XLINK = "http://www.w3.org/1999/xlink ";

    /* MAIN ELEMENTS */
    function g(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("g", _props, _children);
    }

    function _svg(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("svg", string.concat(_SVG, " ", _props), _children);
    }

    function style(string memory _title, string memory _props) internal pure returns (string memory) {
        return el("style", string.concat(".", _title, " ", _props));
    }

    function path(string memory _d) internal pure returns (string memory) {
        return el("path", prop("d", _d, true));
    }

    function path(string memory _d, string memory _props) internal pure returns (string memory) {
        return el("path", string.concat(prop("d", _d), _props));
    }

    function path(string memory _d, string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el("path", string.concat(prop("d", _d), _props), _children);
    }

    function text(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("text", _props, _children);
    }

    function line(string memory _props) internal pure returns (string memory) {
        return el("line", _props);
    }

    function line(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("line", _props, _children);
    }

    function circle(string memory _props) internal pure returns (string memory) {
        return el("circle", _props);
    }

    function circle(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("circle", _props, _children);
    }

    function circle(string memory cx, string memory cy, string memory r) internal pure returns (string memory) {
        return el("circle", string.concat(prop("cx", cx), prop("cy", cy), prop("r", r, true)));
    }

    function circle(string memory cx, string memory cy, string memory r, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el("circle", string.concat(prop("cx", cx), prop("cy", cy), prop("r", r, true)), _children);
    }

    function circle(string memory cx, string memory cy, string memory r, string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return el("circle", string.concat(prop("cx", cx), prop("cy", cy), prop("r", r), _props), _children);
    }

    function ellipse(string memory _props) internal pure returns (string memory) {
        return el("ellipse", _props);
    }

    function ellipse(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("ellipse", _props, _children);
    }

    function polygon(string memory _props) internal pure returns (string memory) {
        return el("polygon", _props);
    }

    function polygon(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("polygon", _props, _children);
    }

    function polyline(string memory _props) internal pure returns (string memory) {
        return el("polyline", _props);
    }

    function polyline(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("polyline", _props, _children);
    }

    function rect(string memory _props) internal pure returns (string memory) {
        return el("rect", _props);
    }

    function rect(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("rect", _props, _children);
    }

    function filter(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("filter", _props, _children);
    }

    function cdata(string memory _content) internal pure returns (string memory) {
        return string.concat("<![CDATA[", _content, "]]>");
    }

    /* GRADIENTS */
    function radialGradient(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("radialGradient", _props, _children);
    }

    function linearGradient(string memory _props, string memory _children) internal pure returns (string memory) {
        return el("linearGradient", _props, _children);
    }

    function gradientStop(uint256 offset, string memory stopColor, string memory _props)
        internal
        pure
        returns (string memory)
    {
        return el(
            "stop",
            string.concat(
                prop("stop-color", stopColor),
                " ",
                prop("offset", string.concat(LibString.toString(offset), "%")),
                " ",
                _props
            ),
            utils.NULL
        );
    }

    /* ANIMATION */
    function animateTransform(string memory _props) internal pure returns (string memory) {
        return el("animateTransform", _props);
    }

    function animate(string memory _props) internal pure returns (string memory) {
        return el("animate", _props);
    }

    /* COMMON */
    // A generic element, can be used to construct any SVG (or HTML) element
    function el(string memory _tag, string memory _props, string memory _children)
        internal
        pure
        returns (string memory)
    {
        return string.concat("<", _tag, " ", _props, ">", _children, "</", _tag, ">");
    }

    // A generic element, can be used to construct SVG (or HTML) elements without children
    function el(string memory _tag, string memory _props) internal pure returns (string memory) {
        return string.concat("<", _tag, " ", _props, "/>");
    }

    // an SVG attribute
    function prop(string memory _key, string memory _val) internal pure returns (string memory) {
        return string.concat(_key, "=", '"', _val, '" ');
    }

    function prop(string memory _key, string memory _val, bool last) internal pure returns (string memory) {
        if (last) {
            return string.concat(_key, "=", '"', _val, '"');
        } else {
            return string.concat(_key, "=", '"', _val, '" ');
        }
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "Solady/utils/LibString.sol";

library numUtils {
    function toLocale(string memory _wholeNumber) internal pure returns (string memory) {
        bytes memory b = bytes(_wholeNumber);
        uint256 len = b.length;
        if (len < 4) return _wholeNumber;

        uint256 numCommas = (len - 1) / 3;

        bytes memory result = new bytes(len + numCommas);

        uint256 j = result.length - 1;
        uint256 k = len;
        for (uint256 i = 0; i < len; i++) {
            result[j] = b[k - 1];
            j = j > 1 ? j - 1 : 0;
            k--;
            if (k > 0 && (len - k) % 3 == 0) {
                result[j] = ",";
                j = j > 1 ? j - 1 : 0;
            }
        }

        return string(result);
    }

    // returns a string representation of a number with commas, where result = _value / 10 ** _divisor
    function toLocaleString(uint256 _value, uint8 _divisor, uint8 _precision) internal pure returns (string memory) {
        uint256 whole;
        uint256 fraction;

        if (_divisor > 0) {
            whole = _value / 10 ** _divisor;
            // check if the divisor is less than the precision
            if (_divisor <= _precision) {
                fraction = (_value % 10 ** _divisor);
                // adjust fraction to be the same as the precision
                fraction = fraction * 10 ** (_precision - _divisor);

                // if whole is zero, then add another zero to the fraction, special case if the value is 1
                fraction = (whole == 0 && _value != 1) ? fraction * 10 : fraction;
            } else {
                fraction = (_value % 10 ** _divisor) / 10 ** (_divisor - _precision - 1);
            }
        } else {
            whole = _value;
        }

        string memory wholeStr = toLocale(LibString.toString(whole));

        if (fraction == 0) {
            if (whole > 0 && _precision > 0) wholeStr = string.concat(wholeStr, ".");
            for (uint8 i = 0; i < _precision; i++) {
                wholeStr = string.concat(wholeStr, "0");
            }

            return wholeStr;
        }

        string memory fractionStr = LibString.slice(LibString.toString(fraction), 0, _precision);

        // pad with leading zeros
        if (_precision > bytes(fractionStr).length) {
            uint256 len = _precision - bytes(fractionStr).length;
            string memory zeroStr = "";

            for (uint8 i = 0; i < len; i++) {
                zeroStr = string.concat(zeroStr, "0");
            }

            fractionStr = string.concat(zeroStr, fractionStr);
        }

        return string.concat(wholeStr, _precision > 0 ? "." : "", fractionStr);
    }
}

/// @notice Core utils used extensively to format CSS and numbers.
/// @author Modified from (https://github.com/w1nt3r-eth/hot-chain-svg/blob/main/contracts/Utils.sol) by w1nt3r-eth.

library utils {
    // used to simulate empty strings
    string internal constant NULL = "";

    // formats a CSS variable line. includes a semicolon for formatting.
    function setCssVar(string memory _key, string memory _val) internal pure returns (string memory) {
        return string.concat("--", _key, ":", _val, ";");
    }

    // formats getting a css variable
    function getCssVar(string memory _key) internal pure returns (string memory) {
        return string.concat("var(--", _key, ")");
    }

    // formats getting a def URL
    function getDefURL(string memory _id) internal pure returns (string memory) {
        return string.concat("url(#", _id, ")");
    }

    // formats rgba white with a specified opacity / alpha
    function white_a(uint256 _a) internal pure returns (string memory) {
        return rgba(255, 255, 255, _a);
    }

    // formats rgba black with a specified opacity / alpha
    function black_a(uint256 _a) internal pure returns (string memory) {
        return rgba(0, 0, 0, _a);
    }

    // formats generic rgba color in css
    function rgba(uint256 _r, uint256 _g, uint256 _b, uint256 _a) internal pure returns (string memory) {
        string memory formattedA = _a < 100 ? string.concat("0.", LibString.toString(_a)) : "1";
        return string.concat(
            "rgba(",
            LibString.toString(_r),
            ",",
            LibString.toString(_g),
            ",",
            LibString.toString(_b),
            ",",
            formattedA,
            ")"
        );
    }

    function cssBraces(string memory _attribute, string memory _value) internal pure returns (string memory) {
        return string.concat(" {", _attribute, ": ", _value, "}");
    }

    function cssBraces(string[] memory _attributes, string[] memory _values) internal pure returns (string memory) {
        require(_attributes.length == _values.length, "Utils: Unbalanced Arrays");

        uint256 len = _attributes.length;

        string memory results = " {";

        for (uint256 i = 0; i < len; i++) {
            results = string.concat(results, _attributes[i], ": ", _values[i], "; ");
        }

        return string.concat(results, "}");
    }

    //deals with integers (i.e. no decimals)
    function points(uint256[2][] memory pointsArray) internal pure returns (string memory) {
        require(pointsArray.length >= 3, "Utils: Array too short");

        uint256 len = pointsArray.length - 1;

        string memory results = 'points="';

        for (uint256 i = 0; i < len; i++) {
            results = string.concat(
                results, LibString.toString(pointsArray[i][0]), ",", LibString.toString(pointsArray[i][1]), " "
            );
        }

        return string.concat(
            results, LibString.toString(pointsArray[len][0]), ",", LibString.toString(pointsArray[len][1]), '"'
        );
    }

    // allows for a uniform precision to be applied to all points
    function points(uint256[2][] memory pointsArray, uint256 decimalPrecision) internal pure returns (string memory) {
        require(pointsArray.length >= 3, "Utils: Array too short");

        uint256 len = pointsArray.length - 1;

        string memory results = 'points="';

        for (uint256 i = 0; i < len; i++) {
            results = string.concat(
                results,
                toString(pointsArray[i][0], decimalPrecision),
                ",",
                toString(pointsArray[i][1], decimalPrecision),
                " "
            );
        }

        return string.concat(
            results,
            toString(pointsArray[len][0], decimalPrecision),
            ",",
            toString(pointsArray[len][1], decimalPrecision),
            '"'
        );
    }

    // checks if two strings are equal
    function stringsEqual(string memory _a, string memory _b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(_a)) == keccak256(abi.encodePacked(_b));
    }

    // returns the length of a string in characters
    function utfStringLength(string memory _str) internal pure returns (uint256 length) {
        uint256 i = 0;
        bytes memory string_rep = bytes(_str);

        while (i < string_rep.length) {
            if (string_rep[i] >> 7 == 0) {
                i += 1;
            } else if (string_rep[i] >> 5 == bytes1(uint8(0x6))) {
                i += 2;
            } else if (string_rep[i] >> 4 == bytes1(uint8(0xE))) {
                i += 3;
            } else if (string_rep[i] >> 3 == bytes1(uint8(0x1E))) {
                i += 4;
            }
            //For safety
            else {
                i += 1;
            }

            length++;
        }
    }

    // allows the insertion of a decimal point in the returned string at precision
    function toString(uint256 value, uint256 precision) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        require(precision <= digits && precision > 0, "Utils: precision invalid");
        precision == digits ? digits += 2 : digits++; //adds a space for the decimal point, 2 if it is the whole uint

        uint256 decimalPlacement = digits - precision - 1;
        bytes memory buffer = new bytes(digits);

        buffer[decimalPlacement] = 0x2E; // add the decimal point, ASCII 46/hex 2E
        if (decimalPlacement == 1) {
            buffer[0] = 0x30;
        }

        while (value != 0) {
            digits -= 1;
            if (digits != decimalPlacement) {
                buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
                value /= 10;
            }
        }

        return string(buffer);
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "Solady/utils/SSTORE2.sol";

contract FixedAssetReader {
    struct Asset {
        uint128 start;
        uint128 end;
    }

    address public immutable pointer;

    mapping(bytes4 => Asset) public assets;

    function readAsset(bytes4 _sig) public view returns (string memory) {
        return string(SSTORE2.read(pointer, uint256(assets[_sig].start), uint256(assets[_sig].end)));
    }

    constructor(address _pointer, bytes4[] memory _sigs, Asset[] memory _assets) {
        pointer = _pointer;
        require(_sigs.length == _assets.length, "FixedAssetReader: Invalid input");
        for (uint256 i = 0; i < _sigs.length; i++) {
            assets[_sigs[i]] = _assets[i];
        }
    }
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
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 *
 * _Available since v4.8.3._
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
// OpenZeppelin Contracts (last updated v4.9.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

pragma solidity ^0.8.0;

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
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, `uint256`._
 * _Available since v4.9 for `string`, `bytes`._
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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for converting numbers into strings and other string operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol)
///
/// @dev Note:
/// For performance and bytecode compactness, most of the string operations are restricted to
/// byte strings (7-bit ASCII), except where otherwise specified.
/// Usage of byte string operations on charsets with runes spanning two or more bytes
/// can lead to undefined behavior.
library LibString {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The length of the output is too small to contain all the hex digits.
    error HexLengthInsufficient();

    /// @dev The length of the string is more than 32 bytes.
    error TooBigForSmallString();

    /// @dev The input string must be a 7-bit ASCII.
    error StringNot7BitASCII();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The constant returned when the `search` is not found in the string.
    uint256 internal constant NOT_FOUND = type(uint256).max;

    /// @dev Lookup for '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant ALPHANUMERIC_7_BIT_ASCII = 0x7fffffe07fffffe03ff000000000000;

    /// @dev Lookup for 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant LETTERS_7_BIT_ASCII = 0x7fffffe07fffffe0000000000000000;

    /// @dev Lookup for 'abcdefghijklmnopqrstuvwxyz'.
    uint128 internal constant LOWERCASE_7_BIT_ASCII = 0x7fffffe000000000000000000000000;

    /// @dev Lookup for 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    uint128 internal constant UPPERCASE_7_BIT_ASCII = 0x7fffffe0000000000000000;

    /// @dev Lookup for '0123456789'.
    uint128 internal constant DIGITS_7_BIT_ASCII = 0x3ff000000000000;

    /// @dev Lookup for '0123456789abcdefABCDEF'.
    uint128 internal constant HEXDIGITS_7_BIT_ASCII = 0x7e0000007e03ff000000000000;

    /// @dev Lookup for '01234567'.
    uint128 internal constant OCTDIGITS_7_BIT_ASCII = 0xff000000000000;

    /// @dev Lookup for '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r\x0b\x0c'.
    uint128 internal constant PRINTABLE_7_BIT_ASCII = 0x7fffffffffffffffffffffff00003e00;

    /// @dev Lookup for '!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~'.
    uint128 internal constant PUNCTUATION_7_BIT_ASCII = 0x78000001f8000001fc00fffe00000000;

    /// @dev Lookup for ' \t\n\r\x0b\x0c'.
    uint128 internal constant WHITESPACE_7_BIT_ASCII = 0x100003e00;

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
            mstore(0x40, add(str, 0x20)) // Allocate the memory.
            mstore(str, 0) // Zeroize the slot after the string.

            let end := str // Cache the end of the memory to calculate the length later.
            let w := not(0) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                str := add(str, w) // `sub(str, 1)`.
                // Store the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                temp := div(temp, 10) // Keep dividing `temp` until zero.
                if iszero(temp) { break }
            }
            let length := sub(end, str)
            str := sub(str, 0x20) // Move the pointer 32 bytes back to make room for the length.
            mstore(str, length) // Store the length.
        }
    }

    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(int256 value) internal pure returns (string memory str) {
        if (value >= 0) return toString(uint256(value));
        unchecked {
            str = toString(~uint256(value) + 1);
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
            mstore(str, 0x3078) // Store the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Store the length.
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
            mstore(0x40, add(str, 0x20)) // Allocate the memory.
            mstore(str, 0) // Zeroize the slot after the string.

            let end := str // Cache the end to calculate the length later.
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
                mstore(0x00, 0x2194895a) // `HexLengthInsufficient()`.
                revert(0x1c, 0x04)
            }
            let strLength := sub(end, str)
            str := sub(str, 0x20)
            mstore(str, strLength) // Store the length.
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
            mstore(str, 0x3078) // Store the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Store the length.
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
            mstore(add(str, o), 0x3078) // Store the "0x" prefix, accounting for leading zero.
            str := sub(add(str, o), 2) // Move the pointer, accounting for leading zero.
            mstore(str, sub(strLength, o)) // Store the length, accounting for leading zero.
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
            mstore(str, sub(strLength, o)) // Store the length, accounting for leading zero.
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
            mstore(0x40, add(str, 0x20)) // Allocate the memory.
            mstore(str, 0) // Zeroize the slot after the string.

            let end := str // Cache the end to calculate the length later.
            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.

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
            let strLength := sub(end, str)
            str := sub(str, 0x20)
            mstore(str, strLength) // Store the length.
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
            mstore(str, 0x3078) // Store the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Store the length.
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
            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.

            str := add(str, 2)
            mstore(str, 40) // Store the length.
            let o := add(str, 0x20)
            mstore(add(o, 40), 0) // Zeroize the slot after the string.
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
            mstore(str, 0x3078) // Store the "0x" prefix.
            str := sub(str, 2) // Move the pointer.
            mstore(str, strLength) // Store the length.
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

            mstore(0x0f, 0x30313233343536373839616263646566) // Store the "0123456789abcdef" lookup.
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

    /// @dev Returns if this string is a 7-bit ASCII string,
    /// AND all characters are in the `allowed` lookup.
    /// Note: If `s` is empty, returns true regardless of `allowed`.
    function is7BitASCII(string memory s, uint128 allowed) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := 1
            if mload(s) {
                let allowed_ := shr(128, shl(128, allowed))
                let o := add(s, 0x20)
                let end := add(o, mload(s))
                for {} 1 {} {
                    result := and(result, shr(byte(0, mload(o)), allowed_))
                    o := add(o, 1)
                    if iszero(and(result, lt(o, end))) { break }
                }
            }
        }
    }

    /// @dev Converts the bytes in the 7-bit ASCII string `s` to
    /// an allowed lookup for use in `is7BitASCII(s, allowed)`.
    /// To save runtime gas, you can cache the result in an immutable variable.
    function to7BitASCIIAllowedLookup(string memory s) internal pure returns (uint128 result) {
        /// @solidity memory-safe-assembly
        assembly {
            if mload(s) {
                let o := add(s, 0x20)
                let end := add(o, mload(s))
                for {} 1 {} {
                    result := or(result, shl(byte(0, mload(o)), 1))
                    o := add(o, 1)
                    if iszero(lt(o, end)) { break }
                }
                if shr(128, result) {
                    mstore(0x00, 0xc9807e0d) // `StringNot7BitASCII()`.
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   BYTE STRING OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // For performance and bytecode compactness, byte string operations are restricted
    // to 7-bit ASCII strings. All offsets are byte offsets, not UTF character offsets.
    // Usage of byte string operations on charsets with runes spanning two or more bytes
    // can lead to undefined behavior.

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

    /// @dev Returns true if `search` is found in `subject`, false otherwise.
    function contains(string memory subject, string memory search) internal pure returns (bool) {
        return indexOf(subject, search) != NOT_FOUND;
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
                mstore(0x40, add(result, add(resultLength, 0x40))) // Allocate the memory.
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
                mstore(0x40, add(result, add(resultLength, 0x40))) // Allocate the memory.
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
            mstore(last, 0) // Zeroize the slot after the string.
            mstore(result, totalLength) // Store the length.
            mstore(0x40, add(last, 0x20)) // Allocate the memory.
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
    /// `s` must be null-terminated, or behavior will be undefined.
    function fromSmallString(bytes32 s) internal pure returns (string memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            let n := 0
            for {} byte(n, s) { n := add(n, 1) } {} // Scan for '\0'.
            mstore(result, n) // Store the length.
            let o := add(result, 0x20)
            mstore(o, s) // Store the bytes of the string.
            mstore(add(o, n), 0) // Zeroize the slot after the string.
            mstore(0x40, add(result, 0x40)) // Allocate the memory.
        }
    }

    /// @dev Returns the small string, with all bytes after the first null byte zeroized.
    function normalizeSmallString(bytes32 s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            for {} byte(result, s) { result := add(result, 1) } {} // Scan for '\0'.
            mstore(0x00, s)
            mstore(result, 0x00)
            result := mload(0x00)
        }
    }

    /// @dev Returns the string as a normalized null-terminated small string.
    function toSmallString(string memory s) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(s)
            if iszero(lt(result, 33)) {
                mstore(0x00, 0xec92f9a3) // `TooBigForSmallString()`.
                revert(0x1c, 0x04)
            }
            result := shl(shl(3, sub(32, result)), mload(add(s, result)))
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

    /// @dev Returns whether `a` equals `b`, where `b` is a null-terminated small string.
    function eqs(string memory a, bytes32 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            // These should be evaluated on compile time, as far as possible.
            let m := not(shl(7, div(not(iszero(b)), 255))) // `0x7f7f ...`.
            let x := not(or(m, or(b, add(m, and(b, m)))))
            let r := shl(7, iszero(iszero(shr(128, x))))
            r := or(r, shl(6, iszero(iszero(shr(64, shr(r, x))))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            // forgefmt: disable-next-item
            result := gt(eq(mload(a), add(iszero(x), xor(31, shr(3, r)))),
                xor(shr(add(8, r), b), shr(add(8, r), mload(add(a, 0x20)))))
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
            result := mload(0x40) // Grab the free memory pointer.
            mstore(0x40, add(result, 0x40)) // Allocate 2 words (1 for the length, 1 for the bytes).
            mstore(result, 0) // Zeroize the length slot.
            mstore(add(result, 0x1f), packed) // Store the length and bytes.
            mstore(add(add(result, 0x20), mload(result)), 0) // Right pad with zeroes.
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
                    or( // Load the length and the bytes of `a` and `b`.
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
            resultA := mload(0x40) // Grab the free memory pointer.
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
            let retUnpaddedSize := add(mload(a), 0x40)
            // Right pad with zeroes. Just in case the string is produced
            // by a method that doesn't zero right pad.
            mstore(add(retStart, retUnpaddedSize), 0)
            mstore(retStart, 0x20) // Store the return offset.
            // End the transaction, returning the string.
            return(retStart, and(not(0x1f), add(0x1f, retUnpaddedSize)))
        }
    }
}
