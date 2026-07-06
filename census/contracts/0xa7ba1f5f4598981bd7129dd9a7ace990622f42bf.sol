// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./HourglassLockDepositorBase.sol";
import {IEtherFiLiquid, ERC20} from "@interfaces/LRTInterfaces.sol";
/**
 *  @notice Each timelocked token will be responsible for managing it's own types of deposits & withdrawals.
 *      This may include different numbers of receipt tokens.
 */
contract HourglassEtherFiLiquidLockDepositor is HourglassLockDepositorBase {
    using SafeERC20 for IERC20;
    using TransientPrimitivesLib for taddress;
    using TransientPrimitivesLib for tuint256;

    address internal minter;
    address internal accountant;

    mapping(address => bool) internal deposited;

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the depositor
    /// @param _underlying The underlying token address
    /// @param _maturity The maturity timestamp
    /// @param _nameSuffix The suffix to append to the name
    /// @param _symbolSuffix The suffix to append to the symbol
    /// @param _receiptImpl The receipt implementation address
    /// @param _decimals The number of decimals of the deposit token
    /// @param _minter The minter address
    /// @param _accountant The accountant address
    function initialize(
        address _underlying,
        uint256 _maturity,
        string memory _nameSuffix,
        string memory _symbolSuffix,
        address _receiptImpl,
        uint256 _decimals,
        address _minter,
        address _accountant
    ) external initializer {
        minter = _minter;
        accountant = _accountant;
        __Depositor_Init(_underlying, _maturity, _nameSuffix, _symbolSuffix, _receiptImpl, _decimals);
    }

    /// @notice Mint Liquid USD with the assets held in this contract
    /// @notice Must be called atomically after entering the contract and transferring in the amount to mint with
    /// @param minMintReceivedSlippageBps The minimum amount of Liquid USD to mint based on slippage (converts within to Liquid USD)
    /// @param liquidDepositAsset The address of the deposit asset to mint Liquid USD with
    /// @param sourceOfFunds The address to return any excess funds to
    /// @return amountDepositAssetMinted The amount of the deposit asset minted into Liquid USD
    /**
     *  @dev To call this, first enter the contract with the amount to deposit into Liquid USD.
     *       Push those assets into this contract.
     *       Then call this function to mint the Liquid USD that cannot be transferred for 72 hours.
     *       Once the deposit asset is minted and held here, call `depositTo` to execute the deposit.
     *       This contract should remain entered until the deposit is called.
     */
    function mintLockedUnderlying(uint256 minMintReceivedSlippageBps, address liquidDepositAsset, address sourceOfFunds)
        external
        returns (uint256 amountDepositAssetMinted)
    {
        // since funds are pushed in prior to this being called, lock the contract
        address entrant = _tEntrant.get();
        uint256 amountToMintWith = _tAmount.get();

        // must be entered as there are undeposited but commited funds
        if (entrant == address(0)) revert NotEntered();
        // only the entrant can call while funds are held but undeposited
        if (msg.sender != entrant) revert CallerNotEntrant();
        // must have funds to mint with
        if (amountToMintWith == 0) revert InsufficientFunds();

        // the first time this address receives an asset that has the rounding error, it will be 1 wei less
        if (!deposited[liquidDepositAsset]) {
            // this needs to be checked the first time it receives any asset with the rounding error, not just the first deposit.
            // the liquidDepositAsset should not be retained after execution, so there should be no leftover balance.
            amountToMintWith = IERC20(liquidDepositAsset).balanceOf(address(this));

            // now that this has received this Liquid asset, it doesn't experience the rounding error again
            deposited[liquidDepositAsset] = true;
            

            // on this first transaction with the liquid deposit asset, increase allowance to max
            IERC20(liquidDepositAsset).safeIncreaseAllowance(underlying, type(uint256).max);
        } else if (IERC20(liquidDepositAsset).balanceOf(address(this)) < amountToMintWith) {
            // must have supplied the assets for minting with between entering & calling this
            // eETH has a rounding error of 1 wei on the first transfer from a new holder, so allow for 1 wei less in this check
            revert InsufficientAssetSupplied();
        }

        // calculate the minimum share quantity acceptable based on slippage
        // divide out the shareRate decimals (6) & the slippage bps decimals (4) plus deposit asset decimals
        uint256 depositAssetDecimals = uint256(IEtherFiLiquid(liquidDepositAsset).decimals());
        uint256 shareRate = IEtherFiLiquid(accountant).getRate();
        uint256 minShareAcceptable = (
            (((10 ** depositAssetDecimals) * amountToMintWith) / shareRate) * minMintReceivedSlippageBps
        ) / (10 ** (10 + depositAssetDecimals));

        // deposit the assets into Liquid USD
        amountDepositAssetMinted =
            IEtherFiLiquid(minter).deposit(liquidDepositAsset, amountToMintWith, minShareAcceptable);
        // the first time this address receives the deposit token, correct for the off by 1 error. Use address(0) to check if it has been deposited into yet.
        if (!deposited[address(0)]) {
            amountDepositAssetMinted = IERC20(underlying).balanceOf(address(this));
            deposited[address(0)] = true;
        }

        // store the amount minted, overwriting the amount provided when entered
        _tAmount.set(amountDepositAssetMinted);

        // minting Liquid USD has slippage & may not utilize 100% of the funds, so return any excess
        uint256 afterMintBalance = IERC20(liquidDepositAsset).balanceOf(address(this));
        if (afterMintBalance > 0) {
            IERC20(liquidDepositAsset).safeTransfer(sourceOfFunds, afterMintBalance);
        }
    }

    function _deposit(address user, uint256 amount, bool receiveSplit) internal override {
        // amount should not be zero
        if (amount == 0) revert InsufficientFunds();

        // pull the deposit token in from the caller, not the user
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        // the first time this address receives the deposit token, correct for the off by 1 error. Use address(0) to check if it has been deposited into yet.
        if (!deposited[address(0)]) {
            amount = IERC20(underlying).balanceOf(address(this));
            deposited[address(0)] = true;
        }
        // check that deposit cap has not been reached
        if (currentDeposits + amount > depositCap) revert DepositCapExceeded();
        // increment the current deposits
        currentDeposits += amount;

        if (receiveSplit) {
            // mint both the principal and yield tokens
            IHourglassERC20TBT(principalToken).mint(user, amount);
            IHourglassERC20TBT(yieldToken).mint(user, amount);
        } else {
            // otherwise just mint the combined token, which could be this contract.
            IHourglassERC20TBT(combinedToken).mint(user, amount);
        }

        emit Deposit(user, amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@interfaces/IHourglassLockingTBTFactory.sol";
import "@interfaces/IHourglassERC20TBT.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "transient-goodies/TransientPrimitives.sol";

/**
 *  @notice Each timelocked token will be responsible for managing it's own types of deposits & withdrawals.
 *      This may include different numbers of receipt tokens.
 */
abstract contract HourglassLockDepositorBase is Initializable {
    using SafeERC20 for IERC20;
    using TransientPrimitivesLib for taddress;
    using TransientPrimitivesLib for tuint256;

    /// This contract will be the implementation added to the TBT proxy where users can deposit an ERC20 token for this contract's defined duration, receiving this contract (as an ERC20) in return.
    /// Each new maturity will be represented by a newly cloned version of this contract.
    /// The user will be able to withdraw the underlying ERC20 token after the maturity duration has passed, plus any extra assets received.

    /// @notice Address of the factory that created this contract
    address public factory;
    /// @notice The timestamp of the maturity
    uint256 public maturity;
    /// @notice The block number of the contract creation
    uint256 public creationBlock;

    address internal underlying;
    address internal combinedToken;
    address internal principalToken;
    address internal yieldToken;

    /// @notice The max allowable deposits (in underlying token/decimals) for this maturity
    uint256 internal depositCap;
    /// @notice The amount of finalized deposits (in underlying token/decimals)
    uint256 internal currentDeposits;

    taddress internal _tEntrant;
    tuint256 internal _tAmount;

    modifier onlyMatured() {
        if (block.timestamp < maturity) revert PrematureRedeem();
        _;
    }

    modifier notMatured() {
        if (block.timestamp > maturity) revert Matured();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the depositor
    /// @param _underlying The underlying token address
    /// @param _maturity The maturity timestamp
    /// @param _nameSuffix The suffix to append to the name
    /// @param _symbolSuffix The suffix to append to the symbol
    /// @param _receiptImpl The receipt implementation address
    /// @param _decimals The number of decimals of the underlying
    function __Depositor_Init(
        address _underlying,
        uint256 _maturity,
        string memory _nameSuffix,
        string memory _symbolSuffix,
        address _receiptImpl,
        uint256 _decimals
    ) internal onlyInitializing {
        if (_underlying == address(0)) revert InvalidUnderlying();
        if (_maturity <= block.timestamp) revert InvalidMaturity();
        if (_decimals == 0 || _decimals > 18) revert InvalidDecimals();
        underlying = _underlying;
        maturity = _maturity;
        depositCap = type(uint256).max;
        factory = msg.sender;
        creationBlock = block.number;

        // forgefmt: disable-start
        // clone & initialize the combined token
        address tkn1 = IHourglassLockingTBTFactory(msg.sender).cloneReceipt(_receiptImpl);
        IHourglassERC20TBT(tkn1).initialize(
            string(abi.encodePacked("ct-", _nameSuffix)), 
            string(abi.encodePacked("ct-", _symbolSuffix)), 
            uint8(_decimals)
        );
        combinedToken = tkn1;

        // clone & initialize the principal token
        address tkn2 = IHourglassLockingTBTFactory(msg.sender).cloneReceipt(_receiptImpl);
        IHourglassERC20TBT(tkn2).initialize(
            string(abi.encodePacked("pt-", _nameSuffix)), 
            string(abi.encodePacked("pt-", _symbolSuffix)), 
            uint8(_decimals)
        );
        principalToken = tkn2;

        // clone & initialize the yield token
        address tkn3 = IHourglassLockingTBTFactory(msg.sender).cloneReceipt(_receiptImpl);
        IHourglassERC20TBT(tkn3).initialize(
            string(abi.encodePacked("pyt-", _nameSuffix)), 
            string(abi.encodePacked("pyt-", _symbolSuffix)), 
            uint8(_decimals)
        );
        yieldToken = tkn3;
        // forgefmt: disable-end
        emit NewMaturityCreated(tkn1, tkn2, tkn3);
    }

    /// @notice Enter the contract, locking the sender as the entrant, callable by contracts only
    /// @param amountToBeDeposited The amount of the deposit token being pushed in after entering
    function enter(uint256 amountToBeDeposited) external virtual {
        if (_tEntrant.get() != address(0)) revert AlreadyEntered();
        if (msg.sender.code.length == 0) revert NoCode();
        _tEntrant.set(msg.sender);
        _tAmount.set(amountToBeDeposited);
    }

    ////////// DEPOSITS & WITHDRAWALS //////////

    /// @notice Deposit, sending the minted assets to `msg.sender`
    /// @param amount The amount of the deposit token to deposit
    /// @param receiveSplit Whether to receive the split tokens or the combined token
    function deposit(uint256 amount, bool receiveSplit) external virtual notMatured {
        _deposit(msg.sender, amount, receiveSplit);
    }

    /// @notice Deposit, sending the minted assets to `user`
    /// @param user The address to send the minted assets to
    /// @param amount The amount of the deposit token to deposit
    /// @param receiveSplit Whether to receive the split tokens or the combined token
    /// @dev This doesn't pull funds from the user, but from the caller & therefor doesn't require permissioned access
    function depositFor(address user, uint256 amount, bool receiveSplit) external virtual notMatured {
        _deposit(user, amount, receiveSplit);
    }

    /// @notice Allows a deposit to occur where the principal & yield tokens are sent to different addresses
    /// @param principalRecipient The address to send the principal tokens to
    /// @param pointRecipient The address to send the yield tokens to
    /// @param amount The amount of the deposit token to deposit
    function depositTo(address principalRecipient, address pointRecipient, uint256 amount, bool receiveSplit)
        external
        virtual
        notMatured
    {
        // since funds are pushed in prior to this being called, lock the contract
        address entrant = _tEntrant.get();
        uint256 amountAvailableForDeposit = _tAmount.get();
        if (entrant == address(0)) revert NotEntered();
        if (msg.sender != entrant) revert CallerNotEntrant();
        if (amountAvailableForDeposit == 0) revert InsufficientFunds();
        if (amount != amountAvailableForDeposit) revert AmountMismatch();
        // un-enter
        _tEntrant.set(address(0));
        _tAmount.set(0);

        // Check that the funds were sent to this contract prior to this call
        uint256 currentBalance = IERC20(underlying).balanceOf(address(this));
        if (currentBalance - currentDeposits < amount) revert InsufficientAssetSupplied();

        // check that deposit cap has not been reached
        if (currentDeposits + amount > depositCap) revert DepositCapExceeded();

        // increment the current deposits
        currentDeposits += amount;

        if (!receiveSplit) {
            // if not receiving split tokens, check that the principal & point recipients are the same
            // this isn't minting either token, but is minting the combined token
            if (principalRecipient != pointRecipient) revert RecipientMismatch();
            // mint the combined token
            IHourglassERC20TBT(combinedToken).mint(principalRecipient, amount);
        } else {
            // mint both the principal and yield tokens
            IHourglassERC20TBT(principalToken).mint(principalRecipient, amount);
            IHourglassERC20TBT(yieldToken).mint(pointRecipient, amount);
        }

        emit DepositedTo(principalRecipient, pointRecipient, amount);
    }

    function _deposit(address user, uint256 amount, bool receiveSplit) internal virtual {
        // amount should not be zero
        if (amount == 0) revert InsufficientFunds();
        // check that deposit cap has not been reached
        if (currentDeposits + amount > depositCap) revert DepositCapExceeded();
        // increment the current deposits
        currentDeposits += amount;

        // pull the deposit token in from the caller, not the user
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);

        if (receiveSplit) {
            // mint both the principal and yield tokens
            IHourglassERC20TBT(principalToken).mint(user, amount);
            IHourglassERC20TBT(yieldToken).mint(user, amount);
        } else {
            // otherwise just mint the combined token, which could be this contract.
            IHourglassERC20TBT(combinedToken).mint(user, amount);
        }

        emit Deposit(user, amount);
    }

    /// @notice Redeem the combined token for the underlying & return the yield token to caller
    /// @param amount The amount of combined tokens to redeem
    /// @dev This will only be callable after the maturity has passed
    function redeem(uint256 amount) external virtual onlyMatured {
        _redemption(amount, combinedToken);
        IHourglassERC20TBT(yieldToken).mint(msg.sender, amount);
    }

    /// @notice Redeem the principal-only token for the underlying
    /// @param amount The amount of principal tokens to redeem
    /// @dev This will only be callable after the maturity has passed
    function redeemPrincipal(uint256 amount) external virtual onlyMatured {
        _redemption(amount, principalToken);
    }

    function _redemption(uint256 amount, address subToken) internal virtual {
        // note deposit cap only relevant while not matured, so no need to decrease the tracker here
        // ensure that the user has enough funds to redeem
        IHourglassERC20TBT(subToken).burn(msg.sender, amount);

        // transfer funds to user
        IERC20(underlying).safeTransfer(msg.sender, amount);

        emit Redeem(msg.sender, amount);
    }

    /// @notice Split the combined token into the principal & yield tokens
    /// @dev only callable before the maturity has passed
    function split(uint256 amount) external virtual notMatured {
        // burn the combined token
        IHourglassERC20TBT(combinedToken).burn(msg.sender, amount);

        // mint both the yield & principal tokens
        IHourglassERC20TBT(principalToken).mint(msg.sender, amount);
        IHourglassERC20TBT(yieldToken).mint(msg.sender, amount);

        emit Split(msg.sender, amount);
    }

    /// @notice Recombine the principal & yield tokens into the combined token
    /// @notice Must have at least `amount` of both the principal & yield tokens
    /// @dev only callable before the maturity has passed
    function recombine(uint256 amount) external virtual notMatured {
        // burn both the yield & principal tokens
        IHourglassERC20TBT(principalToken).burn(msg.sender, amount);
        IHourglassERC20TBT(yieldToken).burn(msg.sender, amount);

        // mint the combined token
        IHourglassERC20TBT(combinedToken).mint(msg.sender, amount);

        emit Recombine(msg.sender, amount);
    }

    ////////// GETTERS //////////

    /// @notice Returns the addresses of the TBT reciepts for this maturity
    /// @return tokens The addresses of the TBT reciepts for this maturity as an array
    function getTokens() external view returns (address[] memory) {
        address[] memory tokens = new address[](3);
        tokens[0] = combinedToken;
        tokens[1] = principalToken;
        tokens[2] = yieldToken;
        return tokens;
    }

    /// @notice Returns the address of the point token
    function getPointToken() external view returns (address) {
        return yieldToken;
    }

    /// @notice Returns the address of the principal token
    function getPrincipalToken() external view returns (address) {
        return principalToken;
    }

    /// @notice Returns the address of the deposit token
    function getUnderlying() external view returns (address) {
        return underlying;
    }

    ////////// ADMIN FUNCTIONS //////////

    /// @notice Set the deposit cap
    function setMaxDeposits(uint256 _depositCap) external {
        if (msg.sender != factory) revert UnauthorizedCaller();
        if (_depositCap < currentDeposits) revert InsufficientDeposit();
        depositCap = _depositCap;
    }

    /// @notice For withdrawing any airdropped token
    /// @param token The address of the token to withdraw
    /// @param rewardsDistributor The address to send the withdrawn tokens to
    /// @return amount The amount of the token withdrawn
    function recoverToken(address token, address rewardsDistributor) external returns (uint256 amount) {
        if (msg.sender != factory) revert UnauthorizedCaller();
        if (token == underlying) revert CannotRemoveDepositToken();
        amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(rewardsDistributor, IERC20(token).balanceOf(address(this)));

        emit Recovered(token, amount);
    }

    ////////// EVENTS //////////

    event Deposit(address user, uint256 amount);
    event DepositedTo(address principalRecipient, address pointRecipient, uint256 amount);
    event Redeem(address user, uint256 amount);
    event Recombine(address user, uint256 amount);
    event Split(address user, uint256 amount);
    event NewMaturityCreated(address combined, address principal, address yield);
    event Recovered(address token, uint256 amount);

    ////////// ERRORS //////////

    error NotEntered();
    error AlreadyEntered();
    error NoCode();
    error CallerNotEntrant();
    error Matured();
    error InsufficientFunds();
    error AmountMismatch();
    error RecipientMismatch();
    error PrematureRedeem();
    error InsufficientDeposit();
    error InsufficientAssetSupplied();
    error UnauthorizedCaller();
    error DepositCapExceeded();
    error CannotRemoveDepositToken();

    // init errors
    error InvalidDecimals();
    error InvalidUnderlying();
    error InvalidMaturity();
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC20 as ERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IStEth is ERC20 {
    function submit(address _referral) external payable returns (uint256);

    function getTotalPooledEther() external view returns (uint256);

    function getTotalShares() external view returns (uint256);

    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);

    function getCurrentStakeLimit() external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

interface IWstEth is ERC20 {
    function wrap(uint256 _stETHAmount) external returns (uint256);

    /**
     * @notice Exchanges wstETH to stETH
     * @param _wstETHAmount amount of wstETH to uwrap in exchange for stETH
     * @dev Requirements:
     *  - `_wstETHAmount` must be non-zero
     *  - msg.sender must have at least `_wstETHAmount` wstETH.
     * @return Amount of stETH user receives after unwrap
     */
    function unwrap(uint256 _wstETHAmount) external returns (uint256);

    function getStETHByWstETH(uint256 _ETHAmount) external view returns (uint256);

    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);

    function stETH() external view returns (address);

    function stEthPerToken() external view returns (uint256);

    function tokensPerStEth() external view returns (uint256);
}

interface IEtherFi {
    // weETH

    function wrap(uint256 amount) external returns (uint256);

    // eETH
    function deposit(address referral) external payable returns (uint256);
    function deposit(uint256 amount) external returns (uint256);
    function deposit(address referral, uint256 amount) external returns (uint256);

    /**
     * @notice Deposits assets into the cellar, and returns shares to receiver.
     * @param assets amount of assets deposited by user.
     * @param receiver address to receive the shares.
     * @return shares amount of shares given for deposit.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @notice Allows users to deposit into cellar using alternative assets.
     * @param depositAsset the asset to deposit
     * @param assets amount of depositAsset to deposit
     * @param receiver address to receive the shares
     */
    function multiAssetDeposit(ERC20 depositAsset, uint256 assets, address receiver)
        external
        returns (uint256 shares);
}

interface IEtherFiLUSD is ERC20 {
    // EtherFi LUSD Minter
    function deposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint)
        external
        returns (uint256 shares);
    function depositWithPermit(
        ERC20 depositAsset,
        uint256 depositAmount,
        uint256 minimumMint,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 shares);

    /// ignore these
    function enter(address from, address asset, uint256 assetAmount, address to, uint256 shareAmount)
        external
        returns (uint256);
    function exit(address to, address asset, uint256 assetAmount, address from, uint256 shareAmount)
        external
        returns (uint256);

    function getRate() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IEtherFiLiquid {
    function deposit(address depositAsset, uint256 depositAmount, uint256 minimumMint)
        external
        payable
        returns (uint256 shares);
    function getRate() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IFrax {
    // used for minting frxETH & staking to receive sfrxETH
    function submitAndDeposit(address recipient) external payable returns (uint256 shares);
    // used to obtain frxETH
    function submit() external payable;
    // redeem sfrxETH to frxETH
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    // deposit frxETH to receive sfrxETH
    function deposit(uint256 amount, address receiver) external returns (uint256);
}

interface IEthena {}

interface ICurve {
    // curve pool functions
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    /// @notice Perform an exchange between two coins
    /// @dev Index values can be found via the `coins` public getter method
    /// @param i Index value for the coin to send
    /// @param j Index value of the coin to receive
    /// @param _dx Amount of `i` being exchanged
    /// @param _min_dy Minimum amount of `j` to receive
    /// @return Actual amount of `j` received
    function exchange(int128 i, int128 j, uint256 _dx, uint256 _min_dy) external returns (uint256);
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
    /// @notice Perform an exchange between two coins, where sender transfers in the input token amount
    /// @dev Index values can be found via the `coins` public getter method
    /// @param i Index value for the coin to send
    /// @param j Index value of the coin to receive
    /// @param _dx Amount of `i` being exchanged
    /// @param _min_dy Minimum amount of `j` to receive
    /// @param _receiver Address that receives `j`
    /// @return Actual amount of `j` received
    function exchange_received(int128 i, int128 j, uint256 _dx, uint256 _min_dy, address _receiver)
        external
        returns (uint256);
}

interface IKelp {
    function getSwapETHToAssetReturnAmount(address toAsset, uint256 ethAmountToSend) external view returns (uint256);
    function swapETHForAssetWithinDepositPool(address toAsset, uint256 minToAssetAmount)
        external
        payable
        returns (uint256);
    function getRsETHAmountToMint(address asset, uint256 assetAmount) external view returns (uint256);
    function minAmountToDeposit() external view returns (uint256);

    function deposit(address _referral) external payable;

    function depositETH(uint256 _minRSETHAmountExpected, string calldata _referral)
        external
        payable
        returns (uint256);

    function depositAsset(address _asset, uint256 _amount, uint256 _minAmount, string calldata _referral) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";

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
pragma solidity ^0.8.20;

interface IHourglassLockingTBTFactory {
    function cloneReceipt(address implementation) external returns (address deployment);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHourglassERC20TBT {
    function initialize(string calldata _name, string calldata _symbol, uint8 __decimals) external;
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
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
pragma solidity ^0.8.24;

/// @author philogy <https://github.com/philogy>

struct tuint256 {
    uint256 __placeholder;
}

struct tint256 {
    uint256 __placeholder;
}

struct tbytes32 {
    uint256 __placeholder;
}

struct taddress {
    uint256 __placeholder;
}

using TransientPrimitivesLib for tuint256 global;
using TransientPrimitivesLib for tint256 global;
using TransientPrimitivesLib for tbytes32 global;
using TransientPrimitivesLib for taddress global;

library TransientPrimitivesLib {
    function get(tuint256 storage ptr) internal view returns (uint256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(ptr.slot)
        }
    }

    function get(tint256 storage ptr) internal view returns (int256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(ptr.slot)
        }
    }

    function get(tbytes32 storage ptr) internal view returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(ptr.slot)
        }
    }

    function get(taddress storage ptr) internal view returns (address value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := tload(ptr.slot)
        }
    }

    function set(tuint256 storage ptr, uint256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, value)
        }
    }

    function inc(tuint256 storage ptr, uint256 change) internal returns (uint256 newValue) {
        ptr.set(newValue = ptr.get() + change);
    }

    function dec(tuint256 storage ptr, uint256 change) internal returns (uint256 newValue) {
        ptr.set(newValue = ptr.get() - change);
    }

    function set(tint256 storage ptr, int256 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, value)
        }
    }

    function inc(tint256 storage ptr, int256 change) internal returns (int256 newValue) {
        ptr.set(newValue = ptr.get() + change);
    }

    function dec(tint256 storage ptr, int256 change) internal returns (int256 newValue) {
        ptr.set(newValue = ptr.get() - change);
    }

    function set(tbytes32 storage ptr, bytes32 value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, value)
        }
    }

    function set(taddress storage ptr, address value) internal {
        /// @solidity memory-safe-assembly
        assembly {
            tstore(ptr.slot, value)
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
