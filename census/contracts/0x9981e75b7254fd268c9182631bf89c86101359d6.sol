// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IFuseCommon} from "../IFuseCommon.sol";
import {IMorpho, MarketParams, Id} from "@morpho-org/morpho-blue/src/interfaces/IMorpho.sol";

import {PlasmaVaultConfigLib} from "../../libraries/PlasmaVaultConfigLib.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @dev Data structure for entering a Morpho borrow fuse.
struct MorphoBorrowFuseEnterData {
    /// @dev The ID of the Morpho market.
    bytes32 morphoMarketId;
    /// @dev The amount to borrow.
    uint256 amountToBorrow;
    /// @dev The shares to borrow.
    uint256 sharesToBorrow;
}

/// @dev Data structure for exiting a Morpho borrow fuse, repay on Morpho.
struct MorphoBorrowFuseExitData {
    /// @dev The ID of the Morpho market.
    bytes32 morphoMarketId;
    /// @dev The amount to repay in borrow asset decimals .
    uint256 amountToRepay;
    /// @dev The shares to repay in morpho decimals.
    uint256 sharesToRepay;
}

contract MorphoBorrowFuse is IFuseCommon {
    using SafeCast for uint256;
    using SafeERC20 for ERC20;

    /// @dev The version of the contract.
    address public immutable VERSION;
    /// @dev The unique identifier for IporFusionMarkets.
    uint256 public immutable MARKET_ID;
    /// @dev The address of the Morpho contract.
    IMorpho public immutable MORPHO;

    error MorphoBorrowFuseUnsupportedMarket(string action, bytes32 morphoMarketId);

    event MorphoBorrowFuseEvent(
        address version,
        uint256 marketId,
        bytes32 morphoMarket,
        uint256 assetsBorrowed,
        uint256 sharesBorrowed
    );

    event MorphoBorrowFuseRepay(
        address version,
        uint256 marketId,
        bytes32 morphoMarket,
        uint256 assetsRepaid,
        uint256 sharesRepaid
    );

    constructor(uint256 marketId_, address morpho_) {
        VERSION = address(this);
        MARKET_ID = marketId_;
        MORPHO = IMorpho(morpho_);
    }

    function enter(MorphoBorrowFuseEnterData calldata data_) public {
        if (data_.amountToBorrow == 0 && data_.sharesToBorrow == 0) {
            return;
        }

        if (!PlasmaVaultConfigLib.isMarketSubstrateGranted(MARKET_ID, data_.morphoMarketId)) {
            revert MorphoBorrowFuseUnsupportedMarket("enter", data_.morphoMarketId);
        }

        (uint256 assetsBorrowed, uint256 sharesBorrowed) = MORPHO.borrow(
            MORPHO.idToMarketParams(Id.wrap(data_.morphoMarketId)),
            data_.amountToBorrow,
            data_.sharesToBorrow,
            address(this),
            address(this)
        );

        emit MorphoBorrowFuseEvent(VERSION, MARKET_ID, data_.morphoMarketId, assetsBorrowed, sharesBorrowed);
    }

    function exit(MorphoBorrowFuseExitData calldata data_) public {
        if (data_.amountToRepay == 0 && data_.sharesToRepay == 0) {
            return;
        }

        if (!PlasmaVaultConfigLib.isMarketSubstrateGranted(MARKET_ID, data_.morphoMarketId)) {
            revert MorphoBorrowFuseUnsupportedMarket("exit", data_.morphoMarketId);
        }

        MarketParams memory marketParams = MORPHO.idToMarketParams(Id.wrap(data_.morphoMarketId));

        /// @dev Approve the loan token to be spent by MORPHO, to max value because cost of calculation in case when want to send shears to repay
        ERC20(marketParams.loanToken).forceApprove(address(MORPHO), type(uint256).max);

        (uint256 assetsRepaid, uint256 sharesRepaid) = MORPHO.repay(
            marketParams,
            data_.amountToRepay,
            data_.sharesToRepay,
            address(this),
            bytes("")
        );

        ERC20(marketParams.loanToken).forceApprove(address(MORPHO), 0);

        emit MorphoBorrowFuseRepay(VERSION, MARKET_ID, data_.morphoMarketId, assetsRepaid, sharesRepaid);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

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
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
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
     * All two of these values are immutable: they can only be set once during
     * construction.
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
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
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
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
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
     * ```
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
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Interface for Fuses Common functions
interface IFuseCommon {
    /// @notice Market ID associated with the Fuse
    //solhint-disable-next-line
    function MARKET_ID() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

type Id is bytes32;

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

/// @dev Warning: For `feeRecipient`, `supplyShares` does not contain the accrued shares since the last interest
/// accrual.
struct Position {
    uint256 supplyShares;
    uint128 borrowShares;
    uint128 collateral;
}

/// @dev Warning: `totalSupplyAssets` does not contain the accrued interest since the last interest accrual.
/// @dev Warning: `totalBorrowAssets` does not contain the accrued interest since the last interest accrual.
/// @dev Warning: `totalSupplyShares` does not contain the additional shares accrued by `feeRecipient` since the last
/// interest accrual.
struct Market {
    uint128 totalSupplyAssets;
    uint128 totalSupplyShares;
    uint128 totalBorrowAssets;
    uint128 totalBorrowShares;
    uint128 lastUpdate;
    uint128 fee;
}

struct Authorization {
    address authorizer;
    address authorized;
    bool isAuthorized;
    uint256 nonce;
    uint256 deadline;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/// @dev This interface is used for factorizing IMorphoStaticTyping and IMorpho.
/// @dev Consider using the IMorpho interface instead of this one.
interface IMorphoBase {
    /// @notice The EIP-712 domain separator.
    /// @dev Warning: Every EIP-712 signed message based on this domain separator can be reused on another chain sharing
    /// the same chain id because the domain separator would be the same.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice The owner of the contract.
    /// @dev It has the power to change the owner.
    /// @dev It has the power to set fees on markets and set the fee recipient.
    /// @dev It has the power to enable but not disable IRMs and LLTVs.
    function owner() external view returns (address);

    /// @notice The fee recipient of all markets.
    /// @dev The recipient receives the fees of a given market through a supply position on that market.
    function feeRecipient() external view returns (address);

    /// @notice Whether the `irm` is enabled.
    function isIrmEnabled(address irm) external view returns (bool);

    /// @notice Whether the `lltv` is enabled.
    function isLltvEnabled(uint256 lltv) external view returns (bool);

    /// @notice Whether `authorized` is authorized to modify `authorizer`'s position on all markets.
    /// @dev Anyone is authorized to modify their own positions, regardless of this variable.
    function isAuthorized(address authorizer, address authorized) external view returns (bool);

    /// @notice The `authorizer`'s current nonce. Used to prevent replay attacks with EIP-712 signatures.
    function nonce(address authorizer) external view returns (uint256);

    /// @notice Sets `newOwner` as `owner` of the contract.
    /// @dev Warning: No two-step transfer ownership.
    /// @dev Warning: The owner can be set to the zero address.
    function setOwner(address newOwner) external;

    /// @notice Enables `irm` as a possible IRM for market creation.
    /// @dev Warning: It is not possible to disable an IRM.
    function enableIrm(address irm) external;

    /// @notice Enables `lltv` as a possible LLTV for market creation.
    /// @dev Warning: It is not possible to disable a LLTV.
    function enableLltv(uint256 lltv) external;

    /// @notice Sets the `newFee` for the given market `marketParams`.
    /// @param newFee The new fee, scaled by WAD.
    /// @dev Warning: The recipient can be the zero address.
    function setFee(MarketParams memory marketParams, uint256 newFee) external;

    /// @notice Sets `newFeeRecipient` as `feeRecipient` of the fee.
    /// @dev Warning: If the fee recipient is set to the zero address, fees will accrue there and will be lost.
    /// @dev Modifying the fee recipient will allow the new recipient to claim any pending fees not yet accrued. To
    /// ensure that the current recipient receives all due fees, accrue interest manually prior to making any changes.
    function setFeeRecipient(address newFeeRecipient) external;

    /// @notice Creates the market `marketParams`.
    /// @dev Here is the list of assumptions on the market's dependencies (tokens, IRM and oracle) that guarantees
    /// Morpho behaves as expected:
    /// - The token should be ERC-20 compliant, except that it can omit return values on `transfer` and `transferFrom`.
    /// - The token balance of Morpho should only decrease on `transfer` and `transferFrom`. In particular, tokens with
    /// burn functions are not supported.
    /// - The token should not re-enter Morpho on `transfer` nor `transferFrom`.
    /// - The token balance of the sender (resp. receiver) should decrease (resp. increase) by exactly the given amount
    /// on `transfer` and `transferFrom`. In particular, tokens with fees on transfer are not supported.
    /// - The IRM should not re-enter Morpho.
    /// - The oracle should return a price with the correct scaling.
    /// @dev Here is a list of properties on the market's dependencies that could break Morpho's liveness properties
    /// (funds could get stuck):
    /// - The token can revert on `transfer` and `transferFrom` for a reason other than an approval or balance issue.
    /// - A very high amount of assets (~1e35) supplied or borrowed can make the computation of `toSharesUp` and
    /// `toSharesDown` overflow.
    /// - The IRM can revert on `borrowRate`.
    /// - A very high borrow rate returned by the IRM can make the computation of `interest` in `_accrueInterest`
    /// overflow.
    /// - The oracle can revert on `price`. Note that this can be used to prevent `borrow`, `withdrawCollateral` and
    /// `liquidate` from being used under certain market conditions.
    /// - A very high price returned by the oracle can make the computation of `maxBorrow` in `_isHealthy` overflow, or
    /// the computation of `assetsRepaid` in `liquidate` overflow.
    /// @dev The borrow share price of a market with less than 1e4 assets borrowed can be decreased by manipulations, to
    /// the point where `totalBorrowShares` is very large and borrowing overflows.
    function createMarket(MarketParams memory marketParams) external;

    /// @notice Supplies `assets` or `shares` on behalf of `onBehalf`, optionally calling back the caller's
    /// `onMorphoSupply` function with the given `data`.
    /// @dev Either `assets` or `shares` should be zero. Most use cases should rely on `assets` as an input so the
    /// caller is guaranteed to have `assets` tokens pulled from their balance, but the possibility to mint a specific
    /// amount of shares is given for full compatibility and precision.
    /// @dev Supplying a large amount can revert for overflow.
    /// @dev Supplying an amount of shares may lead to supply more or fewer assets than expected due to slippage.
    /// Consider using the `assets` parameter to avoid this.
    /// @param marketParams The market to supply assets to.
    /// @param assets The amount of assets to supply.
    /// @param shares The amount of shares to mint.
    /// @param onBehalf The address that will own the increased supply position.
    /// @param data Arbitrary data to pass to the `onMorphoSupply` callback. Pass empty data if not needed.
    /// @return assetsSupplied The amount of assets supplied.
    /// @return sharesSupplied The amount of shares minted.
    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);

    /// @notice Withdraws `assets` or `shares` on behalf of `onBehalf` and sends the assets to `receiver`.
    /// @dev Either `assets` or `shares` should be zero. To withdraw max, pass the `shares`'s balance of `onBehalf`.
    /// @dev `msg.sender` must be authorized to manage `onBehalf`'s positions.
    /// @dev Withdrawing an amount corresponding to more shares than supplied will revert for underflow.
    /// @dev It is advised to use the `shares` input when withdrawing the full position to avoid reverts due to
    /// conversion roundings between shares and assets.
    /// @param marketParams The market to withdraw assets from.
    /// @param assets The amount of assets to withdraw.
    /// @param shares The amount of shares to burn.
    /// @param onBehalf The address of the owner of the supply position.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @return assetsWithdrawn The amount of assets withdrawn.
    /// @return sharesWithdrawn The amount of shares burned.
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsWithdrawn, uint256 sharesWithdrawn);

    /// @notice Borrows `assets` or `shares` on behalf of `onBehalf` and sends the assets to `receiver`.
    /// @dev Either `assets` or `shares` should be zero. Most use cases should rely on `assets` as an input so the
    /// caller is guaranteed to borrow `assets` of tokens, but the possibility to mint a specific amount of shares is
    /// given for full compatibility and precision.
    /// @dev `msg.sender` must be authorized to manage `onBehalf`'s positions.
    /// @dev Borrowing a large amount can revert for overflow.
    /// @dev Borrowing an amount of shares may lead to borrow fewer assets than expected due to slippage.
    /// Consider using the `assets` parameter to avoid this.
    /// @param marketParams The market to borrow assets from.
    /// @param assets The amount of assets to borrow.
    /// @param shares The amount of shares to mint.
    /// @param onBehalf The address that will own the increased borrow position.
    /// @param receiver The address that will receive the borrowed assets.
    /// @return assetsBorrowed The amount of assets borrowed.
    /// @return sharesBorrowed The amount of shares minted.
    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed);

    /// @notice Repays `assets` or `shares` on behalf of `onBehalf`, optionally calling back the caller's
    /// `onMorphoReplay` function with the given `data`.
    /// @dev Either `assets` or `shares` should be zero. To repay max, pass the `shares`'s balance of `onBehalf`.
    /// @dev Repaying an amount corresponding to more shares than borrowed will revert for underflow.
    /// @dev It is advised to use the `shares` input when repaying the full position to avoid reverts due to conversion
    /// roundings between shares and assets.
    /// @dev An attacker can front-run a repay with a small repay making the transaction revert for underflow.
    /// @param marketParams The market to repay assets to.
    /// @param assets The amount of assets to repay.
    /// @param shares The amount of shares to burn.
    /// @param onBehalf The address of the owner of the debt position.
    /// @param data Arbitrary data to pass to the `onMorphoRepay` callback. Pass empty data if not needed.
    /// @return assetsRepaid The amount of assets repaid.
    /// @return sharesRepaid The amount of shares burned.
    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsRepaid, uint256 sharesRepaid);

    /// @notice Supplies `assets` of collateral on behalf of `onBehalf`, optionally calling back the caller's
    /// `onMorphoSupplyCollateral` function with the given `data`.
    /// @dev Interest are not accrued since it's not required and it saves gas.
    /// @dev Supplying a large amount can revert for overflow.
    /// @param marketParams The market to supply collateral to.
    /// @param assets The amount of collateral to supply.
    /// @param onBehalf The address that will own the increased collateral position.
    /// @param data Arbitrary data to pass to the `onMorphoSupplyCollateral` callback. Pass empty data if not needed.
    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    /// @notice Withdraws `assets` of collateral on behalf of `onBehalf` and sends the assets to `receiver`.
    /// @dev `msg.sender` must be authorized to manage `onBehalf`'s positions.
    /// @dev Withdrawing an amount corresponding to more collateral than supplied will revert for underflow.
    /// @param marketParams The market to withdraw collateral from.
    /// @param assets The amount of collateral to withdraw.
    /// @param onBehalf The address of the owner of the collateral position.
    /// @param receiver The address that will receive the collateral assets.
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    /// @notice Liquidates the given `repaidShares` of debt asset or seize the given `seizedAssets` of collateral on the
    /// given market `marketParams` of the given `borrower`'s position, optionally calling back the caller's
    /// `onMorphoLiquidate` function with the given `data`.
    /// @dev Either `seizedAssets` or `repaidShares` should be zero.
    /// @dev Seizing more than the collateral balance will underflow and revert without any error message.
    /// @dev Repaying more than the borrow balance will underflow and revert without any error message.
    /// @dev An attacker can front-run a liquidation with a small repay making the transaction revert for underflow.
    /// @param marketParams The market of the position.
    /// @param borrower The owner of the position.
    /// @param seizedAssets The amount of collateral to seize.
    /// @param repaidShares The amount of shares to repay.
    /// @param data Arbitrary data to pass to the `onMorphoLiquidate` callback. Pass empty data if not needed.
    /// @return The amount of assets seized.
    /// @return The amount of assets repaid.
    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes memory data
    ) external returns (uint256, uint256);

    /// @notice Executes a flash loan.
    /// @dev Flash loans have access to the whole balance of the contract (the liquidity and deposited collateral of all
    /// markets combined, plus donations).
    /// @dev Warning: Not ERC-3156 compliant but compatibility is easily reached:
    /// - `flashFee` is zero.
    /// - `maxFlashLoan` is the token's balance of this contract.
    /// - The receiver of `assets` is the caller.
    /// @param token The token to flash loan.
    /// @param assets The amount of assets to flash loan.
    /// @param data Arbitrary data to pass to the `onMorphoFlashLoan` callback.
    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    /// @notice Sets the authorization for `authorized` to manage `msg.sender`'s positions.
    /// @param authorized The authorized address.
    /// @param newIsAuthorized The new authorization status.
    function setAuthorization(address authorized, bool newIsAuthorized) external;

    /// @notice Sets the authorization for `authorization.authorized` to manage `authorization.authorizer`'s positions.
    /// @dev Warning: Reverts if the signature has already been submitted.
    /// @dev The signature is malleable, but it has no impact on the security here.
    /// @dev The nonce is passed as argument to be able to revert with a different error message.
    /// @param authorization The `Authorization` struct.
    /// @param signature The signature.
    function setAuthorizationWithSig(Authorization calldata authorization, Signature calldata signature) external;

    /// @notice Accrues interest for the given market `marketParams`.
    function accrueInterest(MarketParams memory marketParams) external;

    /// @notice Returns the data stored on the different `slots`.
    function extSloads(bytes32[] memory slots) external view returns (bytes32[] memory);
}

/// @dev This interface is inherited by Morpho so that function signatures are checked by the compiler.
/// @dev Consider using the IMorpho interface instead of this one.
interface IMorphoStaticTyping is IMorphoBase {
    /// @notice The state of the position of `user` on the market corresponding to `id`.
    /// @dev Warning: For `feeRecipient`, `supplyShares` does not contain the accrued shares since the last interest
    /// accrual.
    function position(Id id, address user)
        external
        view
        returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

    /// @notice The state of the market corresponding to `id`.
    /// @dev Warning: `totalSupplyAssets` does not contain the accrued interest since the last interest accrual.
    /// @dev Warning: `totalBorrowAssets` does not contain the accrued interest since the last interest accrual.
    /// @dev Warning: `totalSupplyShares` does not contain the accrued shares by `feeRecipient` since the last interest
    /// accrual.
    function market(Id id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );

    /// @notice The market params corresponding to `id`.
    /// @dev This mapping is not used in Morpho. It is there to enable reducing the cost associated to calldata on layer
    /// 2s by creating a wrapper contract with functions that take `id` as input instead of `marketParams`.
    function idToMarketParams(Id id)
        external
        view
        returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv);
}

/// @title IMorpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @dev Use this interface for Morpho to have access to all the functions with the appropriate function signatures.
interface IMorpho is IMorphoBase {
    /// @notice The state of the position of `user` on the market corresponding to `id`.
    /// @dev Warning: For `feeRecipient`, `p.supplyShares` does not contain the accrued shares since the last interest
    /// accrual.
    function position(Id id, address user) external view returns (Position memory p);

    /// @notice The state of the market corresponding to `id`.
    /// @dev Warning: `m.totalSupplyAssets` does not contain the accrued interest since the last interest accrual.
    /// @dev Warning: `m.totalBorrowAssets` does not contain the accrued interest since the last interest accrual.
    /// @dev Warning: `m.totalSupplyShares` does not contain the accrued shares by `feeRecipient` since the last
    /// interest accrual.
    function market(Id id) external view returns (Market memory m);

    /// @notice The market params corresponding to `id`.
    /// @dev This mapping is not used in Morpho. It is there to enable reducing the cost associated to calldata on layer
    /// 2s by creating a wrapper contract with functions that take `id` as input instead of `marketParams`.
    function idToMarketParams(Id id) external view returns (MarketParams memory);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {PlasmaVaultStorageLib} from "./PlasmaVaultStorageLib.sol";

/// @title Plasma Vault Configuration Library responsible for managing the configuration of the Plasma Vault
library PlasmaVaultConfigLib {
    event MarketSubstratesGranted(uint256 marketId, bytes32[] substrates);

    /// @notice Checks if a given asset address is granted as a substrate for a specific market
    /// @dev This function is part of the Plasma Vault's substrate management system that controls which assets can be used in specific markets
    ///
    /// @param marketId_ The ID of the market to check
    /// @param substrateAsAsset The address of the asset to verify as a substrate
    /// @return bool True if the asset is granted as a substrate for the market, false otherwise
    ///
    /// @custom:security-notes
    /// - Substrates are stored internally as bytes32 values
    /// - Asset addresses are converted to bytes32 for storage efficiency
    /// - Part of the vault's asset distribution protection system
    ///
    /// @custom:context The function is used in conjunction with:
    /// - PlasmaVault's execute() function for validating market operations
    /// - PlasmaVaultGovernance's grantMarketSubstrates() for configuration
    /// - Asset distribution protection system for market limit enforcement
    ///
    /// @custom:example
    /// ```solidity
    /// // Check if USDC is granted for market 1
    /// bool isGranted = isSubstrateAsAssetGranted(1, USDC_ADDRESS);
    /// ```
    ///
    /// @custom:permissions
    /// - View function, no special permissions required
    /// - Substrate grants are managed by ATOMIST_ROLE through PlasmaVaultGovernance
    ///
    /// @custom:related-functions
    /// - grantMarketSubstrates(): For granting substrates to markets
    /// - isMarketSubstrateGranted(): For checking non-asset substrates
    /// - getMarketSubstrates(): For retrieving all granted substrates
    function isSubstrateAsAssetGranted(uint256 marketId_, address substrateAsAsset) internal view returns (bool) {
        PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates = _getMarketSubstrates(marketId_);
        return marketSubstrates.substrateAllowances[addressToBytes32(substrateAsAsset)] == 1;
    }

    /// @notice Validates if a substrate is granted for a specific market
    /// @dev Part of the Plasma Vault's substrate management system that enables flexible market configurations
    ///
    /// @param marketId_ The ID of the market to check
    /// @param substrate_ The bytes32 identifier of the substrate to verify
    /// @return bool True if the substrate is granted for the market, false otherwise
    ///
    /// @custom:security-notes
    /// - Substrates are stored and compared as raw bytes32 values
    /// - Used for both asset and non-asset substrates (e.g., vaults, parameters)
    /// - Critical for market access control and security
    ///
    /// @custom:context The function is used for:
    /// - Validating market operations in PlasmaVault.execute()
    /// - Checking substrate permissions before market interactions
    /// - Supporting various substrate types:
    ///   * Asset addresses (converted to bytes32)
    ///   * Protocol-specific vault identifiers
    ///   * Market parameters and configuration values
    ///
    /// @custom:example
    /// ```solidity
    /// // Check if a compound vault substrate is granted
    /// bytes32 vaultId = keccak256(abi.encode("compound-vault-1"));
    /// bool isGranted = isMarketSubstrateGranted(1, vaultId);
    ///
    /// // Check if a market parameter is granted
    /// bytes32 param = bytes32("max-leverage");
    /// bool isParamGranted = isMarketSubstrateGranted(1, param);
    /// ```
    ///
    /// @custom:permissions
    /// - View function, no special permissions required
    /// - Substrate grants are managed by ATOMIST_ROLE through PlasmaVaultGovernance
    ///
    /// @custom:related-functions
    /// - isSubstrateAsAssetGranted(): For checking asset-specific substrates
    /// - grantMarketSubstrates(): For granting substrates to markets
    /// - getMarketSubstrates(): For retrieving all granted substrates
    function isMarketSubstrateGranted(uint256 marketId_, bytes32 substrate_) internal view returns (bool) {
        PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates = _getMarketSubstrates(marketId_);
        return marketSubstrates.substrateAllowances[substrate_] == 1;
    }

    /// @notice Retrieves all granted substrates for a specific market
    /// @dev Part of the Plasma Vault's substrate management system that provides visibility into market configurations
    ///
    /// @param marketId_ The ID of the market to query
    /// @return bytes32[] Array of all granted substrate identifiers for the market
    ///
    /// @custom:security-notes
    /// - Returns raw bytes32 values that may represent different substrate types
    /// - Order of substrates in array is preserved from grant operations
    /// - Empty array indicates no substrates are granted
    ///
    /// @custom:context The function is used for:
    /// - Auditing market configurations
    /// - Validating substrate grants during governance operations
    /// - Supporting UI/external systems that need market configuration data
    /// - Debugging and monitoring market setups
    ///
    /// @custom:substrate-types The returned array may contain:
    /// - Asset addresses (converted to bytes32)
    /// - Protocol-specific vault identifiers
    /// - Market parameters and configuration values
    /// - Any other substrate type granted to the market
    ///
    /// @custom:example
    /// ```solidity
    /// // Get all substrates for market 1
    /// bytes32[] memory substrates = getMarketSubstrates(1);
    ///
    /// // Process different substrate types
    /// for (uint256 i = 0; i < substrates.length; i++) {
    ///     if (isSubstrateAsAssetGranted(1, bytes32ToAddress(substrates[i]))) {
    ///         // Handle asset substrate
    ///     } else {
    ///         // Handle other substrate type
    ///     }
    /// }
    /// ```
    ///
    /// @custom:permissions
    /// - View function, no special permissions required
    /// - Useful for both governance and user interfaces
    ///
    /// @custom:related-functions
    /// - isMarketSubstrateGranted(): For checking individual substrate grants
    /// - grantMarketSubstrates(): For modifying substrate grants
    /// - bytes32ToAddress(): For converting asset substrates back to addresses
    function getMarketSubstrates(uint256 marketId_) internal view returns (bytes32[] memory) {
        return _getMarketSubstrates(marketId_).substrates;
    }

    /// @notice Grants or updates substrate permissions for a specific market
    /// @dev Core function for managing market substrate configurations in the Plasma Vault system
    ///
    /// @param marketId_ The ID of the market to configure
    /// @param substrates_ Array of substrate identifiers to grant to the market
    ///
    /// @custom:security-notes
    /// - Revokes all existing substrate grants before applying new ones
    /// - Atomic operation - either all substrates are granted or none
    /// - Emits MarketSubstratesGranted event for tracking changes
    /// - Critical for market security and access control
    ///
    /// @custom:context The function is used for:
    /// - Initial market setup by governance
    /// - Updating market configurations
    /// - Managing protocol integrations
    /// - Controlling asset access per market
    ///
    /// @custom:substrate-handling
    /// - Accepts both asset and non-asset substrates:
    ///   * Asset addresses (converted to bytes32)
    ///   * Protocol-specific vault identifiers
    ///   * Market parameters
    ///   * Configuration values
    /// - Maintains a list of active substrates
    /// - Updates allowance mapping for each substrate
    ///
    /// @custom:example
    /// ```solidity
    /// // Grant multiple substrates to market 1
    /// bytes32[] memory substrates = new bytes32[](2);
    /// substrates[0] = addressToBytes32(USDC_ADDRESS);
    /// substrates[1] = keccak256(abi.encode("compound-vault-1"));
    /// grantMarketSubstrates(1, substrates);
    /// ```
    ///
    /// @custom:permissions
    /// - Should only be called by authorized governance functions
    /// - Typically restricted to ATOMIST_ROLE
    /// - Critical for vault security
    ///
    /// @custom:related-functions
    /// - isMarketSubstrateGranted(): For checking granted substrates
    /// - getMarketSubstrates(): For viewing current grants
    /// - grantSubstratesAsAssetsToMarket(): For asset-specific grants
    ///
    /// @custom:events
    /// - Emits MarketSubstratesGranted(marketId, substrates)
    function grantMarketSubstrates(uint256 marketId_, bytes32[] memory substrates_) internal {
        PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates = _getMarketSubstrates(marketId_);

        _revokeMarketSubstrates(marketSubstrates);

        bytes32[] memory list = new bytes32[](substrates_.length);
        for (uint256 i; i < substrates_.length; ++i) {
            marketSubstrates.substrateAllowances[substrates_[i]] = 1;
            list[i] = substrates_[i];
        }

        marketSubstrates.substrates = list;

        emit MarketSubstratesGranted(marketId_, substrates_);
    }

    /// @notice Grants asset-specific substrates to a market
    /// @dev Specialized function for managing asset-type substrates in the Plasma Vault system
    ///
    /// @param marketId_ The ID of the market to configure
    /// @param substratesAsAssets_ Array of asset addresses to grant as substrates
    ///
    /// @custom:security-notes
    /// - Revokes all existing substrate grants before applying new ones
    /// - Converts addresses to bytes32 for storage efficiency
    /// - Atomic operation - either all assets are granted or none
    /// - Emits MarketSubstratesGranted event with converted addresses
    /// - Critical for market asset access control
    ///
    /// @custom:context The function is used for:
    /// - Setting up asset permissions for markets
    /// - Managing DeFi protocol integrations
    /// - Controlling which tokens can be used in specific markets
    /// - Implementing asset-based strategies
    ///
    /// @custom:implementation-details
    /// - Converts each address to bytes32 using addressToBytes32()
    /// - Updates both allowance mapping and substrate list
    /// - Maintains consistency between address and bytes32 representations
    /// - Ensures proper event emission with converted values
    ///
    /// @custom:example
    /// ```solidity
    /// // Grant USDC and DAI access to market 1
    /// address[] memory assets = new address[](2);
    /// assets[0] = USDC_ADDRESS;
    /// assets[1] = DAI_ADDRESS;
    /// grantSubstratesAsAssetsToMarket(1, assets);
    /// ```
    ///
    /// @custom:permissions
    /// - Should only be called by authorized governance functions
    /// - Typically restricted to ATOMIST_ROLE
    /// - Critical for vault security and asset management
    ///
    /// @custom:related-functions
    /// - grantMarketSubstrates(): For granting general substrates
    /// - isSubstrateAsAssetGranted(): For checking asset grants
    /// - addressToBytes32(): For address conversion
    ///
    /// @custom:events
    /// - Emits MarketSubstratesGranted(marketId, convertedSubstrates)
    function grantSubstratesAsAssetsToMarket(uint256 marketId_, address[] calldata substratesAsAssets_) internal {
        PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates = _getMarketSubstrates(marketId_);

        _revokeMarketSubstrates(marketSubstrates);

        bytes32[] memory list = new bytes32[](substratesAsAssets_.length);

        for (uint256 i; i < substratesAsAssets_.length; ++i) {
            marketSubstrates.substrateAllowances[addressToBytes32(substratesAsAssets_[i])] = 1;
            list[i] = addressToBytes32(substratesAsAssets_[i]);
        }

        marketSubstrates.substrates = list;

        emit MarketSubstratesGranted(marketId_, list);
    }

    /// @notice Converts an Ethereum address to its bytes32 representation for substrate storage
    /// @dev Core utility function for substrate address handling in the Plasma Vault system
    ///
    /// @param address_ The Ethereum address to convert
    /// @return bytes32 The bytes32 representation of the address
    ///
    /// @custom:security-notes
    /// - Performs unchecked conversion from address to bytes32
    /// - Pads the address (20 bytes) with zeros to fill bytes32 (32 bytes)
    /// - Used for storage efficiency in substrate mappings
    /// - Critical for consistent substrate identifier handling
    ///
    /// @custom:context The function is used for:
    /// - Converting asset addresses for substrate storage
    /// - Maintaining consistent substrate identifier format
    /// - Supporting the substrate allowance system
    /// - Enabling efficient storage and comparison operations
    ///
    /// @custom:implementation-details
    /// - Uses uint160 casting to handle address bytes
    /// - Follows standard Solidity type conversion patterns
    /// - Zero-pads the upper bytes implicitly
    /// - Maintains compatibility with bytes32ToAddress()
    ///
    /// @custom:example
    /// ```solidity
    /// // Convert USDC address to substrate identifier
    /// bytes32 usdcSubstrate = addressToBytes32(USDC_ADDRESS);
    ///
    /// // Use in substrate allowance mapping
    /// marketSubstrates.substrateAllowances[usdcSubstrate] = 1;
    /// ```
    ///
    /// @custom:permissions
    /// - Pure function, no state modifications
    /// - Can be called by any function
    /// - Used internally for substrate management
    ///
    /// @custom:related-functions
    /// - bytes32ToAddress(): Complementary conversion function
    /// - grantSubstratesAsAssetsToMarket(): Uses this for address conversion
    /// - isSubstrateAsAssetGranted(): Uses converted values for comparison
    function addressToBytes32(address address_) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(address_)));
    }

    /// @notice Converts a bytes32 substrate identifier to its corresponding address representation
    /// @dev Core utility function for substrate address handling in the Plasma Vault system
    ///
    /// @param substrate_ The bytes32 substrate identifier to convert
    /// @return address The resulting Ethereum address
    ///
    /// @custom:security-notes
    /// - Performs unchecked conversion from bytes32 to address
    /// - Only the last 20 bytes (160 bits) are used
    /// - Should only be used for known substrate conversions
    /// - Critical for proper asset substrate handling
    ///
    /// @custom:context The function is used for:
    /// - Converting stored substrate identifiers back to asset addresses
    /// - Processing asset-type substrates in market operations
    /// - Interfacing with external protocols using addresses
    /// - Validating asset substrate configurations
    ///
    /// @custom:implementation-details
    /// - Uses uint160 casting to ensure proper address size
    /// - Follows standard Solidity address conversion pattern
    /// - Maintains compatibility with addressToBytes32()
    /// - Zero-pads the upper bytes implicitly
    ///
    /// @custom:example
    /// ```solidity
    /// // Convert a stored substrate back to an asset address
    /// bytes32 storedSubstrate = marketSubstrates.substrates[0];
    /// address assetAddress = bytes32ToAddress(storedSubstrate);
    ///
    /// // Use in asset validation
    /// if (assetAddress == USDC_ADDRESS) {
    ///     // Handle USDC-specific logic
    /// }
    /// ```
    ///
    /// @custom:related-functions
    /// - addressToBytes32(): Complementary conversion function
    /// - isSubstrateAsAssetGranted(): Uses this for address comparison
    /// - getMarketSubstrates(): Returns values that may need conversion
    function bytes32ToAddress(bytes32 substrate_) internal pure returns (address) {
        return address(uint160(uint256(substrate_)));
    }

    /// @notice Gets the market substrates configuration for a specific market
    function _getMarketSubstrates(
        uint256 marketId_
    ) private view returns (PlasmaVaultStorageLib.MarketSubstratesStruct storage) {
        return PlasmaVaultStorageLib.getMarketSubstrates().value[marketId_];
    }

    function _revokeMarketSubstrates(PlasmaVaultStorageLib.MarketSubstratesStruct storage marketSubstrates) private {
        uint256 length = marketSubstrates.substrates.length;
        for (uint256 i; i < length; ++i) {
            marketSubstrates.substrateAllowances[marketSubstrates.substrates[i]] = 0;
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
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
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
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
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
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
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

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title Plasma Vault Storage Library
 * @notice Library managing storage layout and access for the PlasmaVault system using ERC-7201 namespaced storage pattern
 * @dev This library is a core component of the PlasmaVault system that:
 * 1. Defines and manages all storage structures using ERC-7201 namespaced storage pattern
 * 2. Provides storage access functions for PlasmaVault.sol, PlasmaVaultBase.sol and PlasmaVaultGovernance.sol
 * 3. Ensures storage safety for the upgradeable vault system
 *
 * Storage Components:
 * - Core ERC4626 vault storage (asset, decimals)
 * - Market management (assets, balances, substrates)
 * - Fee system storage (performance, management fees)
 * - Access control and execution state
 * - Fuse system configuration
 * - Price oracle and rewards management
 *
 * Key Integrations:
 * - Used by PlasmaVault.sol for core vault operations and asset management
 * - Used by PlasmaVaultGovernance.sol for configuration and admin functions
 * - Used by PlasmaVaultBase.sol for ERC20 functionality and access control
 *
 * Security Considerations:
 * - Uses ERC-7201 namespaced storage pattern to prevent storage collisions
 * - Each storage struct has a unique namespace derived from its purpose
 * - Critical for maintaining storage integrity in upgradeable contracts
 * - Storage slots are carefully chosen and must not be modified
 *
 * @custom:security-contact security@ipor.io
 */
library PlasmaVaultStorageLib {
    /**
     * @dev Storage slot for ERC4626 vault configuration following ERC-7201 namespaced storage pattern
     * @notice This storage location is used to store the core ERC4626 vault data (asset address and decimals)
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC4626")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Important:
     * - This value MUST NOT be changed as it's used by OpenZeppelin's ERC4626 implementation
     * - Changing this value would break storage compatibility with existing deployments
     * - Used by PlasmaVault.sol for core vault operations like deposit/withdraw
     *
     * Storage Layout:
     * - Points to ERC4626Storage struct containing:
     *   - asset: address of the underlying token
     *   - underlyingDecimals: decimals of the underlying token
     */
    bytes32 private constant ERC4626_STORAGE_LOCATION =
        0x0773e532dfede91f04b12a73d3d2acd361424f41f76b4fb79f090161e36b4e00;

    /**
     * @dev Storage slot for ERC20Capped configuration following ERC-7201 namespaced storage pattern
     * @notice This storage location manages the total supply cap functionality for the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20Capped")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Important:
     * - This value MUST NOT be changed as it's used by OpenZeppelin's ERC20Capped implementation
     * - Changing this value would break storage compatibility with existing deployments
     * - Used by PlasmaVault.sol and PlasmaVaultBase.sol for supply cap enforcement
     *
     * Storage Layout:
     * - Points to ERC20CappedStorage struct containing:
     *   - cap: maximum total supply allowed for the vault tokens
     *
     * Usage:
     * - Enforces maximum supply limits during minting operations
     * - Can be temporarily disabled for fee-related minting operations
     * - Critical for maintaining vault supply control
     */
    bytes32 private constant ERC20_CAPPED_STORAGE_LOCATION =
        0x0f070392f17d5f958cc1ac31867dabecfc5c9758b4a419a200803226d7155d00;

    /**
     * @dev Storage slot for managing the ERC20 supply cap validation state
     * @notice Controls whether total supply cap validation is active or temporarily disabled
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.Erc20CappedValidationFlag")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Provides a mechanism to temporarily disable supply cap checks
     * - Essential for special minting operations like fee distribution
     * - Used by PlasmaVault.sol during performance and management fee minting
     *
     * Storage Layout:
     * - Points to ERC20CappedValidationFlag struct containing:
     *   - value: flag indicating if cap validation is enabled (0) or disabled (1)
     *
     * Usage Pattern:
     * - Default state: Enabled (0) - enforces supply cap
     * - Temporarily disabled (1) during:
     *   - Performance fee minting
     *   - Management fee minting
     * - Always re-enabled after special minting operations
     *
     * Security Note:
     * - Critical for maintaining controlled token supply
     * - Only disabled briefly during authorized fee operations
     * - Must be properly re-enabled to prevent unlimited minting
     */
    bytes32 private constant ERC20_CAPPED_VALIDATION_FLAG =
        0xaef487a7a52e82ae7bbc470b42be72a1d3c066fb83773bf99cce7e6a7df2f900;

    /**
     * @dev Storage slot for tracking total assets across all markets in the Plasma Vault
     * @notice Maintains the global accounting of all assets managed by the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.PlasmaVaultTotalAssetsInAllMarkets")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks the total value of assets managed by the vault across all markets
     * - Used for global vault accounting and share price calculations
     * - Critical for ERC4626 compliance and vault operations
     *
     * Storage Layout:
     * - Points to TotalAssets struct containing:
     *   - value: total assets in underlying token decimals
     *
     * Usage:
     * - Updated during deposit/withdraw operations
     * - Used in share price calculations
     * - Referenced for fee calculations
     * - Key component in asset distribution checks
     *
     * Integration Points:
     * - PlasmaVault.sol: Used in totalAssets() calculations
     * - Fee System: Used as base for fee calculations
     * - Asset Protection: Used in distribution limit checks
     *
     * Security Considerations:
     * - Must be accurately maintained for proper vault operation
     * - Critical for share price accuracy
     * - Any updates must consider all asset sources (markets, rewards, etc.)
     */
    bytes32 private constant PLASMA_VAULT_TOTAL_ASSETS_IN_ALL_MARKETS =
        0x24e02552e88772b8e8fd15f3e6699ba530635ffc6b52322da922b0b497a77300;

    /**
     * @dev Storage slot for tracking assets per individual market in the Plasma Vault
     * @notice Maintains per-market asset accounting for the vault's distributed positions
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.PlasmaVaultTotalAssetsInMarket")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks assets allocated to each market individually
     * - Enables market-specific asset distribution control
     * - Used for market balance validation and limits enforcement
     *
     * Storage Layout:
     * - Points to MarketTotalAssets struct containing:
     *   - value: mapping(uint256 marketId => uint256 assets)
     *   - Assets stored in underlying token decimals
     *
     * Usage:
     * - Updated during market operations via fuses
     * - Used in market balance checks
     * - Referenced for market limit validations
     * - Key for asset distribution protection
     *
     * Integration Points:
     * - Balance Fuses: Update market balances
     * - Asset Distribution Protection: Enforce market limits
     * - Withdrawal Logic: Check available assets per market
     *
     * Security Considerations:
     * - Critical for market-specific asset limits
     * - Must be synchronized with actual market positions
     * - Updates protected by balance fuse system
     */
    bytes32 private constant PLASMA_VAULT_TOTAL_ASSETS_IN_MARKET =
        0x656f5ca8c676f20b936e991a840e1130bdd664385322f33b6642ec86729ee600;

    /**
     * @dev Storage slot for market substrates configuration in the Plasma Vault
     * @notice Manages the configuration of supported assets and sub-markets for each market
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultMarketSubstrates")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Defines which assets/sub-markets are supported in each market
     * - Controls market-specific asset allowances
     * - Essential for market integration configuration
     *
     * Storage Layout:
     * - Points to MarketSubstrates struct containing:
     *   - value: mapping(uint256 marketId => MarketSubstratesStruct)
     *     where MarketSubstratesStruct contains:
     *     - substrateAllowances: mapping(bytes32 => uint256) for permission control
     *     - substrates: bytes32[] list of supported substrates
     *
     * Usage:
     * - Configured by governance for each market
     * - Referenced during market operations
     * - Used by fuses to validate operations
     * - Controls which assets can be used in each market
     *
     * Integration Points:
     * - Fuse System: Validates allowed substrates
     * - Market Operations: Controls available assets
     * - Governance: Manages market configurations
     *
     * Security Considerations:
     * - Critical for controlling market access
     * - Only modifiable through governance
     * - Impacts market operation permissions
     */
    bytes32 private constant CFG_PLASMA_VAULT_MARKET_SUBSTRATES =
        0x78e40624004925a4ef6749756748b1deddc674477302d5b7fe18e5335cde3900;

    /**
     * @dev Storage slot for pre-hooks configuration in the Plasma Vault
     * @notice Manages function-specific pre-execution hooks and their implementations
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultPreHooks")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Maps function selectors to their pre-execution hook implementations
     * - Enables customizable pre-execution validation and logic
     * - Provides extensible function-specific behavior
     * - Coordinates cross-function state updates
     *
     * Storage Layout:
     * - Points to PreHooksConfig struct containing:
     *   - hooksImplementation: mapping(bytes4 selector => address implementation)
     *   - selectors: bytes4[] array of registered function selectors
     *   - indexes: mapping(bytes4 selector => uint256 index) for O(1) selector lookup
     *
     * Usage Pattern:
     * - Each function can have one designated pre-hook
     * - Hooks execute before main function logic
     * - Selector array enables efficient iteration over registered hooks
     * - Index mapping provides quick hook existence checks
     *
     * Integration Points:
     * - PlasmaVault.execute: Pre-execution hook invocation
     * - PreHooksHandler: Hook execution coordination
     * - PlasmaVaultGovernance: Hook configuration
     * - Function-specific hooks: Custom validation logic
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for function execution control
     * - Must validate hook implementations
     * - Requires careful state management
     * - Key component of vault security layer
     */
    bytes32 private constant CFG_PLASMA_VAULT_PRE_HOOKS =
        0xd334d8b26e68f82b7df26f2f64b6ffd2aaae5e2fc0e8c144c4b3598dcddd4b00;

    /**
     * @dev Storage slot for balance fuses configuration in the Plasma Vault
     * @notice Maps markets to their balance fuses and maintains an ordered list of active markets
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultBalanceFuses")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Associates balance fuses with specific markets for asset tracking
     * - Maintains ordered list of active markets for efficient iteration
     * - Enables market balance validation and updates
     * - Coordinates multi-market balance operations
     *
     * Storage Layout:
     * - Points to BalanceFuses struct containing:
     *   - fuseAddresses: mapping(uint256 marketId => address fuseAddress)
     *   - marketIds: uint256[] array of active market IDs
     *   - indexes: mapping(uint256 marketId => uint256 index) for O(1) market lookup
     *
     * Usage Pattern:
     * - Each market has one designated balance fuse
     * - Market IDs array enables efficient iteration over active markets
     * - Index mapping provides quick market existence checks
     * - Used during balance updates and market operations
     *
     * Integration Points:
     * - PlasmaVault._updateMarketsBalances: Market balance tracking
     * - Balance Fuses: Market position management
     * - PlasmaVaultGovernance: Fuse configuration
     * - Asset Protection: Balance validation
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for accurate asset tracking
     * - Must maintain market list integrity
     * - Requires proper fuse address validation
     * - Key component of vault accounting
     */
    bytes32 private constant CFG_PLASMA_VAULT_BALANCE_FUSES =
        0x150144dd6af711bac4392499881ec6649090601bd196a5ece5174c1400b1f700;

    /**
     * @dev Storage slot for instant withdrawal fuses configuration
     * @notice Stores ordered array of fuses that can be used for instant withdrawals
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultInstantWithdrawalFusesArray")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Maintains list of fuses available for instant withdrawals
     * - Defines order of withdrawal attempts
     * - Enables efficient withdrawal path selection
     *
     * Storage Layout:
     * - Points to InstantWithdrawalFuses struct containing:
     *   - value: address[] array of fuse addresses
     *   - Order of fuses in array determines withdrawal priority
     *
     * Usage:
     * - Referenced during withdrawal operations
     * - Used by PlasmaVault.sol in _withdrawFromMarkets
     * - Determines withdrawal execution sequence
     *
     * Integration Points:
     * - Withdrawal System: Defines available withdrawal paths
     * - Fuse System: Lists supported instant withdrawal fuses
     * - Governance: Manages withdrawal configuration
     *
     * Security Considerations:
     * - Order of fuses is critical for optimal withdrawals
     * - Same fuse can appear multiple times with different params
     * - Must be carefully managed to ensure withdrawal efficiency
     */
    bytes32 private constant CFG_PLASMA_VAULT_INSTANT_WITHDRAWAL_FUSES_ARRAY =
        0xd243afa3da07e6bdec20fdd573a17f99411aa8a62ae64ca2c426d3a86ae0ac00;

    /**
     * @dev Storage slot for price oracle middleware configuration
     * @notice Stores the address of the price oracle middleware used for asset price conversions
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.PriceOracleMiddleware")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Provides price feed access for asset valuations
     * - Essential for market value calculations
     * - Used in balance conversions and limit checks
     *
     * Storage Layout:
     * - Points to PriceOracleMiddleware struct containing:
     *   - value: address of the price oracle middleware contract
     *
     * Usage:
     * - Used during market balance updates
     * - Required for USD value calculations
     * - Critical for asset distribution checks
     *
     * Integration Points:
     * - Balance Fuses: Asset value calculations
     * - Market Operations: Price conversions
     * - Asset Protection: Value-based limits
     *
     * Security Considerations:
     * - Must point to a valid and secure price oracle
     * - Critical for accurate vault valuations
     * - Only updatable through governance
     */
    bytes32 private constant PRICE_ORACLE_MIDDLEWARE =
        0x0d761ae54d86fc3be4f1f2b44ade677efb1c84a85fc6bb1d087dc42f1e319a00;

    /**
     * @dev Storage slot for instant withdrawal fuse parameters configuration
     * @notice Maps fuses to their specific withdrawal parameters for instant withdrawal execution
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultInstantWithdrawalFusesParams")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Stores configuration parameters for each instant withdrawal fuse
     * - Enables customized withdrawal behavior per fuse
     * - Supports multiple parameter sets for the same fuse at different indices
     *
     * Storage Layout:
     * - Points to InstantWithdrawalFusesParams struct containing:
     *   - value: mapping(bytes32 => bytes32[]) where:
     *     - key: keccak256(abi.encodePacked(fuse address, index))
     *     - value: array of parameters specific to the fuse
     *
     * Parameter Structure:
     * - params[0]: Always represents withdrawal amount in underlying token
     * - params[1+]: Fuse-specific parameters (e.g., slippage, path, market-specific data)
     *
     * Usage Pattern:
     * - Referenced during instant withdrawal operations in PlasmaVault
     * - Parameters are passed to fuse's instantWithdraw function
     * - Supports multiple parameter sets for same fuse with different indices
     *
     * Integration Points:
     * - PlasmaVault._withdrawFromMarkets: Uses params for withdrawal execution
     * - PlasmaVaultGovernance: Manages parameter configuration
     * - Fuse Contracts: Receive and interpret parameters during withdrawal
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for controlling withdrawal behavior
     * - Parameters must be carefully validated per fuse requirements
     * - Order of parameters must match fuse expectations
     */
    bytes32 private constant CFG_PLASMA_VAULT_INSTANT_WITHDRAWAL_FUSES_PARAMS =
        0x45a704819a9dcb1bb5b8cff129eda642cf0e926a9ef104e27aa53f1d1fa47b00;

    /**
     * @dev Storage slot for fee configuration in the Plasma Vault
     * @notice Manages the fee configuration including performance and management fees
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.CfgPlasmaVaultFeeConfig")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Stores comprehensive fee configuration for the vault
     * - Manages both IPOR DAO and recipient-specific fee settings
     * - Enables flexible fee distribution model
     *
     * Storage Layout:
     * - Points to FeeConfig struct containing:
     *   - feeFactory: address of the FeeManagerFactory contract
     *   - iporDaoManagementFee: management fee percentage for IPOR DAO
     *   - iporDaoPerformanceFee: performance fee percentage for IPOR DAO
     *   - iporDaoFeeRecipientAddress: address receiving IPOR DAO fees
     *   - recipientManagementFees: array of management fee percentages for other recipients
     *   - recipientPerformanceFees: array of performance fee percentages for other recipients
     *
     * Fee Structure:
     * - Management fees: Continuous time-based fees on AUM
     * - Performance fees: Charged on positive vault performance
     * - All fees in basis points (1/10000)
     *
     * Integration Points:
     * - FeeManagerFactory: Deploys fee management contracts
     * - FeeManager: Handles fee calculations and distributions
     * - PlasmaVault: References for fee realizations
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Fee percentages must be within reasonable bounds
     * - Critical for vault economics and sustainability
     * - Must maintain proper recipient configurations
     */
    bytes32 private constant CFG_PLASMA_VAULT_FEE_CONFIG =
        0x78b5ce597bdb64d5aa30a201c7580beefe408ff13963b5d5f3dce2dc09e89c00;

    /**
     * @dev Storage slot for performance fee data in the Plasma Vault
     * @notice Stores current performance fee configuration and recipient information
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.PlasmaVaultPerformanceFeeData")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Manages performance fee settings and collection
     * - Tracks fee recipient address
     * - Controls performance-based revenue sharing
     *
     * Storage Layout:
     * - Points to PerformanceFeeData struct containing:
     *   - feeAccount: address receiving performance fees
     *   - feeInPercentage: current fee rate (basis points, 1/10000)
     *
     * Fee Mechanics:
     * - Calculated on positive vault performance
     * - Applied during execute() operations
     * - Minted as new vault shares to fee recipient
     * - Charged only on realized gains
     *
     * Integration Points:
     * - PlasmaVault._addPerformanceFee: Fee calculation and minting
     * - FeeManager: Fee configuration management
     * - PlasmaVaultGovernance: Fee settings updates
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Fee percentage must be within defined limits
     * - Critical for fair value distribution
     * - Must maintain valid fee recipient address
     * - Requires careful handling during share minting
     */
    bytes32 private constant PLASMA_VAULT_PERFORMANCE_FEE_DATA =
        0x9399757a27831a6cfb6cf4cd5c97a908a2f8f41e95a5952fbf83a04e05288400;

    /**
     * @notice Stores management fee configuration and time tracking data
     * @dev Manages continuous fee collection with time-based accrual
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultManagementFeeData
     */
    bytes32 private constant PLASMA_VAULT_MANAGEMENT_FEE_DATA =
        0x239dd7e43331d2af55e2a25a6908f3bcec2957025f1459db97dcdc37c0003f00;

    /**
     * @dev Storage slot for rewards claim manager address
     * @notice Stores the address of the contract managing external protocol rewards
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.RewardsClaimManagerAddress")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Manages external protocol reward claims
     * - Tracks claimable rewards across integrated protocols
     * - Centralizes reward collection logic
     *
     * Storage Layout:
     * - Points to RewardsClaimManagerAddress struct containing:
     *   - value: address of the rewards claim manager contract
     *
     * Functionality:
     * - Coordinates reward claims from multiple protocols
     * - Tracks unclaimed rewards in underlying asset terms
     * - Included in total assets calculations when active
     * - Optional component (can be set to address(0))
     *
     * Integration Points:
     * - PlasmaVault._getGrossTotalAssets: Includes rewards in total assets
     * - PlasmaVault.claimRewards: Executes reward collection
     * - External protocols: Source of claimable rewards
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Must handle protocol-specific claim logic safely
     * - Critical for accurate reward accounting
     * - Requires careful integration testing
     * - Should handle failed claims gracefully
     */
    bytes32 private constant REWARDS_CLAIM_MANAGER_ADDRESS =
        0x08c469289c3f85d9b575f3ae9be6831541ff770a06ea135aa343a4de7c962d00;

    /**
     * @dev Storage slot for market allocation limits
     * @notice Controls maximum asset allocation per market in the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.MarketLimits")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Enforces market-specific allocation limits
     * - Prevents over-concentration in single markets
     * - Enables risk management through diversification
     *
     * Storage Layout:
     * - Points to MarketLimits struct containing:
     *   - limitInPercentage: mapping(uint256 marketId => uint256 limit)
     *   - Limits stored in basis points (1e18 = 100%)
     *
     * Limit Mechanics:
     * - Each market has independent allocation limit
     * - Limits are percentage of total vault assets
     * - Zero limit for marketId 0 deactivates all limits
     * - Non-zero limit for marketId 0 activates limit system
     *
     * Integration Points:
     * - AssetDistributionProtectionLib: Enforces limits
     * - PlasmaVault._updateMarketsBalances: Checks limits
     * - PlasmaVaultGovernance: Limit configuration
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Critical for risk management
     * - Must handle percentage calculations carefully
     * - Requires proper market balance tracking
     * - Should prevent concentration risk
     */
    bytes32 private constant MARKET_LIMITS = 0xc2733c187287f795e2e6e84d35552a190e774125367241c3e99e955f4babf000;

    /**
     * @dev Storage slot for market balance dependency relationships
     * @notice Manages interconnected market balance update requirements
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.DependencyBalanceGraph")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Tracks dependencies between market balances
     * - Ensures atomic balance updates across related markets
     * - Maintains consistency in cross-market positions
     *
     * Storage Layout:
     * - Points to DependencyBalanceGraph struct containing:
     *   - dependencyGraph: mapping(uint256 marketId => uint256[] marketIds)
     *   - Each market maps to array of dependent market IDs
     *
     * Dependency Mechanics:
     * - Markets can depend on multiple other markets
     * - When updating a market balance, all dependent markets must be updated
     * - Dependencies are unidirectional (A->B doesn't imply B->A)
     * - Empty dependency array means no dependencies
     *
     * Integration Points:
     * - PlasmaVault._checkBalanceFusesDependencies: Resolves update order
     * - PlasmaVault._updateMarketsBalances: Ensures complete updates
     * - PlasmaVaultGovernance: Dependency configuration
     *
     * Security Considerations:
     * - Only modifiable through governance
     * - Must prevent circular dependencies
     * - Critical for market balance integrity
     * - Requires careful dependency chain validation
     * - Should handle deep dependency trees efficiently
     */
    bytes32 private constant DEPENDENCY_BALANCE_GRAPH =
        0x82411e549329f2815579116a6c5e60bff72686c93ab5dba4d06242cfaf968900;

    /**
     * @dev Storage slot for tracking execution state of vault operations
     * @notice Controls execution flow and prevents concurrent operations in the vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.executeRunning")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Prevents concurrent execution of vault operations
     * - Enables callback handling during execution
     * - Acts as a reentrancy guard for execute() operations
     *
     * Storage Layout:
     * - Points to ExecuteState struct containing:
     *   - value: uint256 flag indicating execution state
     *     - 0: No execution in progress
     *   - 1: Execution in progress
     *
     * Usage Pattern:
     * - Set to 1 at start of execute() operation
     * - Checked during callback handling
     * - Reset to 0 when execution completes
     * - Used by PlasmaVault.execute() and callback system
     *
     * Integration Points:
     * - PlasmaVault.execute: Sets/resets execution state
     * - CallbackHandlerLib: Validates callbacks during execution
     * - Fallback function: Routes callbacks during execution
     *
     * Security Considerations:
     * - Critical for preventing concurrent operations
     * - Must be properly reset after execution
     * - Protects against malicious callbacks
     * - Part of vault's security architecture
     */
    bytes32 private constant EXECUTE_RUNNING = 0x054644eb87255c1c6a2d10801735f52fa3b9d6e4477dbed74914d03844ab6600;

    /**
     * @dev Storage slot for callback handler mapping in the Plasma Vault
     * @notice Maps protocol-specific callbacks to their handler contracts
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.callbackHandler")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Routes protocol-specific callbacks to appropriate handlers
     * - Enables dynamic callback handling during vault operations
     * - Supports integration with external protocols
     * - Manages protocol-specific callback logic
     *
     * Storage Layout:
     * - Points to CallbackHandler struct containing:
     *   - callbackHandler: mapping(bytes32 => address)
     *     - key: keccak256(abi.encodePacked(sender, sig))
     *     - value: address of the handler contract
     *
     * Usage Pattern:
     * - Callbacks received during execute() operations
     * - Key generated from sender address and function signature
     * - Handler contract processes protocol-specific logic
     * - Only accessible when execution is in progress
     *
     * Integration Points:
     * - PlasmaVault.fallback: Routes incoming callbacks
     * - CallbackHandlerLib: Processes callback routing
     * - Protocol-specific handlers: Implement callback logic
     * - PlasmaVaultGovernance: Manages handler configuration
     *
     * Security Considerations:
     * - Only callable during active execution
     * - Handler addresses must be trusted
     * - Prevents unauthorized callback processing
     * - Critical for secure protocol integration
     * - Must validate callback sources
     */
    bytes32 private constant CALLBACK_HANDLER = 0xb37e8684757599da669b8aea811ee2b3693b2582d2c730fab3f4965fa2ec3e00;

    /**
     * @dev Storage slot for withdraw manager contract address
     * @notice Manages withdrawal controls and permissions in the Plasma Vault
     *
     * Calculation:
     * keccak256(abi.encode(uint256(keccak256("io.ipor.WithdrawManager")) - 1)) & ~bytes32(uint256(0xff))
     *
     * Purpose:
     * - Controls withdrawal permissions and limits
     * - Manages withdrawal schedules and timing
     * - Enforces withdrawal restrictions
     * - Coordinates withdrawal validation
     *
     * Storage Layout:
     * - Points to WithdrawManager struct containing:
     *   - manager: address of the withdraw manager contract
     *   - Zero address indicates disabled withdrawal controls
     *
     * Usage Pattern:
     * - Checked during withdraw() and redeem() operations
     * - Validates withdrawal permissions
     * - Enforces withdrawal schedules
     * - Can be disabled by setting to address(0)
     *
     * Integration Points:
     * - PlasmaVault.withdraw: Checks withdrawal permissions
     * - PlasmaVault.redeem: Validates redemption requests
     * - PlasmaVaultGovernance: Manager configuration
     * - AccessManager: Permission coordination
     *
     * Security Considerations:
     * - Critical for controlling asset outflows
     * - Only modifiable through governance
     * - Must maintain withdrawal restrictions
     * - Coordinates with access control system
     * - Key component of vault security
     */
    bytes32 private constant WITHDRAW_MANAGER = 0xb37e8684757599da669b8aea811ee2b3693b2582d2c730fab3f4965fa2ec3e11;

    /**
     * @notice Maps callback signatures to their handler contracts
     * @dev Stores routing information for protocol-specific callbacks
     * @custom:storage-location erc7201:io.ipor.callbackHandler
     */
    struct CallbackHandler {
        /// @dev key: keccak256(abi.encodePacked(sender, sig)), value: handler address
        mapping(bytes32 key => address handler) callbackHandler;
    }

    /**
     * @notice Stores and manages per-market allocation limits for the vault
     * @custom:storage-location erc7201:io.ipor.MarketLimits
     */
    struct MarketLimits {
        mapping(uint256 marketId => uint256 limit) limitInPercentage;
    }

    /**
     * @notice Core storage for ERC4626 vault implementation
     * @dev Value taken from OpenZeppelin's ERC4626 implementation - DO NOT MODIFY
     * @custom:storage-location erc7201:openzeppelin.storage.ERC4626
     */
    struct ERC4626Storage {
        /// @dev underlying asset in Plasma Vault
        address asset;
        /// @dev underlying asset decimals in Plasma Vault
        uint8 underlyingDecimals;
    }

    /// @dev Value taken from ERC20VotesUpgradeable contract, don't change it!
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC20Capped
    struct ERC20CappedStorage {
        uint256 cap;
    }

    /// @notice ERC20CappedValidationFlag is used to enable or disable the total supply cap validation during execution
    /// Required for situation when performance fee or management fee is minted for fee managers
    /// @custom:storage-location erc7201:io.ipor.Erc20CappedValidationFlag
    struct ERC20CappedValidationFlag {
        uint256 value;
    }

    /**
     * @notice Stores address of the contract managing protocol reward claims
     * @dev Optional component - can be set to address(0) to disable rewards
     * @custom:storage-location erc7201:io.ipor.RewardsClaimManagerAddress
     */
    struct RewardsClaimManagerAddress {
        /// @dev total assets in the Plasma Vault
        address value;
    }

    /**
     * @notice Tracks total assets across all markets in the vault
     * @dev Used for global accounting and share price calculations
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultTotalAssetsInAllMarkets
     */
    struct TotalAssets {
        /// @dev total assets in the Plasma Vault
        uint256 value;
    }

    /**
     * @notice Tracks per-market asset balances in the vault
     * @dev Used for market-specific accounting and limit enforcement
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultTotalAssetsInMarket
     */
    struct MarketTotalAssets {
        /// @dev marketId => total assets in the vault in the market
        mapping(uint256 => uint256) value;
    }

    /**
     * @notice Market Substrates configuration
     * @dev Substrate - abstract item in the market, could be asset or sub market in the external protocol, it could be any item required to calculate balance in the market
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultMarketSubstrates
     */
    struct MarketSubstratesStruct {
        /// @notice Define which substrates are allowed and supported in the market
        /// @dev key can be specific asset or sub market in a specific external protocol (market), value - 1 - granted, otherwise - not granted
        mapping(bytes32 => uint256) substrateAllowances;
        /// @dev it could be list of assets or sub markets in a specific protocol or any other ids required to calculate balance in the market (external protocol)
        bytes32[] substrates;
    }

    /**
     * @notice Maps markets to their supported substrate configurations
     * @dev Stores per-market substrate allowances and lists
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultMarketSubstrates
     */
    struct MarketSubstrates {
        /// @dev marketId => MarketSubstratesStruct
        mapping(uint256 => MarketSubstratesStruct) value;
    }

    /**
     * @notice Manages market-to-fuse mappings and active market tracking
     * @dev Provides efficient market lookup and iteration capabilities
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultBalanceFuses
     *
     * Storage Components:
     * - fuseAddresses: Maps each market to its designated balance fuse
     * - marketIds: Maintains ordered list of active markets for iteration
     * - indexes: Enables O(1) market existence checks and array access
     *
     * Key Features:
     * - Efficient market-fuse relationship management
     * - Fast market existence validation
     * - Optimized iteration over active markets
     * - Maintains market list integrity
     *
     * Usage:
     * - Market balance tracking and validation
     * - Fuse assignment and management
     * - Market activation/deactivation
     * - Multi-market operations coordination
     *
     * Security Notes:
     * - Market IDs must be unique
     * - Index mapping must stay synchronized with array
     * - Fuse addresses must be validated before assignment
     * - Critical for vault's balance tracking system
     */
    struct BalanceFuses {
        /// @dev Maps market IDs to their corresponding balance fuse addresses
        mapping(uint256 marketId => address fuseAddress) fuseAddresses;
        /// @dev Ordered array of active market IDs for efficient iteration
        uint256[] marketIds;
        /// @dev Maps market IDs to their position in the marketIds array for O(1) lookup
        mapping(uint256 marketId => uint256 index) indexes;
    }

    /**
     * @notice Manages pre-execution hooks configuration for vault functions
     * @dev Provides efficient hook lookup and management for function-specific pre-execution logic
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultPreHooks
     *
     * Storage Components:
     * - hooksImplementation: Maps function selectors to their hook implementation contracts
     * - selectors: Maintains ordered list of registered function selectors
     * - indexes: Enables O(1) selector existence checks and array access
     *
     * Key Features:
     * - Efficient function-to-hook mapping management
     * - Fast hook implementation lookup
     * - Optimized iteration over registered hooks
     * - Maintains hook registry integrity
     *
     * Usage:
     * - Pre-execution validation and checks
     * - Custom function-specific behavior
     * - Hook registration and management
     * - Cross-function state coordination
     *
     * Security Notes:
     * - Function selectors must be unique
     * - Index mapping must stay synchronized with array
     * - Hook implementations must be validated before assignment
     * - Critical for vault's execution security layer
     */
    struct PreHooksConfig {
        /// @dev Maps function selectors to their corresponding hook implementation addresses
        mapping(bytes4 => address) hooksImplementation;
        /// @dev Ordered array of registered function selectors for efficient iteration
        bytes4[] selectors;
        /// @dev Maps function selectors to their position in the selectors array for O(1) lookup
        mapping(bytes4 selector => uint256 index) indexes;
    }

    /**
     * @notice Tracks dependencies between market balances for atomic updates
     * @dev Maps markets to their dependent markets requiring simultaneous balance updates
     * @custom:storage-location erc7201:io.ipor.BalanceDependenceGraph
     */
    struct DependencyBalanceGraph {
        mapping(uint256 marketId => uint256[] marketIds) dependencyGraph;
    }

    /**
     * @notice Stores ordered list of fuses available for instant withdrawals
     * @dev Order determines withdrawal attempt sequence, same fuse can appear multiple times
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultInstantWithdrawalFusesArray
     */
    struct InstantWithdrawalFuses {
        /// @dev value is a Fuse address used for instant withdrawal
        address[] value;
    }

    /**
     * @notice Stores parameters for instant withdrawal fuse operations
     * @dev Maps fuse+index pairs to their withdrawal configuration parameters
     * @custom:storage-location erc7201:io.ipor.CfgPlasmaVaultInstantWithdrawalFusesParams
     */
    struct InstantWithdrawalFusesParams {
        /// @dev key: fuse address and index in InstantWithdrawalFuses array, value: list of parameters used for instant withdrawal
        /// @dev first param always amount in underlying asset of PlasmaVault, second and next params are specific for the fuse and market
        mapping(bytes32 => bytes32[]) value;
    }

    /**
     * @notice Stores performance fee configuration and recipient data
     * @dev Manages fee percentage and recipient account for performance-based fees
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultPerformanceFeeData
     */
    struct PerformanceFeeData {
        address feeAccount;
        uint16 feeInPercentage;
    }

    /**
     * @notice Stores management fee configuration and time tracking data
     * @dev Manages continuous fee collection with time-based accrual
     * @custom:storage-location erc7201:io.ipor.PlasmaVaultManagementFeeData
     */
    struct ManagementFeeData {
        address feeAccount;
        uint16 feeInPercentage;
        uint32 lastUpdateTimestamp;
    }

    /**
     * @notice Stores address of price oracle middleware for asset valuations
     * @dev Provides standardized price feed access for vault operations
     * @custom:storage-location erc7201:io.ipor.PriceOracleMiddleware
     */
    struct PriceOracleMiddleware {
        address value;
    }

    /**
     * @notice Tracks execution state of vault operations
     * @dev Used as a flag to prevent concurrent execution and manage callbacks
     * @custom:storage-location erc7201:io.ipor.executeRunning
     */
    struct ExecuteState {
        uint256 value;
    }

    /**
     * @notice Stores address of the contract managing withdrawal controls
     * @dev Handles withdrawal permissions, schedules and limits
     * @custom:storage-location erc7201:io.ipor.WithdrawManager
     */
    struct WithdrawManager {
        address manager;
    }

    function getERC4626Storage() internal pure returns (ERC4626Storage storage $) {
        assembly {
            $.slot := ERC4626_STORAGE_LOCATION
        }
    }

    function getERC20CappedStorage() internal pure returns (ERC20CappedStorage storage $) {
        assembly {
            $.slot := ERC20_CAPPED_STORAGE_LOCATION
        }
    }

    function getERC20CappedValidationFlag() internal pure returns (ERC20CappedValidationFlag storage $) {
        assembly {
            $.slot := ERC20_CAPPED_VALIDATION_FLAG
        }
    }

    function getTotalAssets() internal pure returns (TotalAssets storage totalAssets) {
        assembly {
            totalAssets.slot := PLASMA_VAULT_TOTAL_ASSETS_IN_ALL_MARKETS
        }
    }

    function getExecutionState() internal pure returns (ExecuteState storage executeRunning) {
        assembly {
            executeRunning.slot := EXECUTE_RUNNING
        }
    }

    function getCallbackHandler() internal pure returns (CallbackHandler storage handler) {
        assembly {
            handler.slot := CALLBACK_HANDLER
        }
    }

    function getDependencyBalanceGraph() internal pure returns (DependencyBalanceGraph storage dependencyBalanceGraph) {
        assembly {
            dependencyBalanceGraph.slot := DEPENDENCY_BALANCE_GRAPH
        }
    }

    function getMarketTotalAssets() internal pure returns (MarketTotalAssets storage marketTotalAssets) {
        assembly {
            marketTotalAssets.slot := PLASMA_VAULT_TOTAL_ASSETS_IN_MARKET
        }
    }

    function getMarketSubstrates() internal pure returns (MarketSubstrates storage marketSubstrates) {
        assembly {
            marketSubstrates.slot := CFG_PLASMA_VAULT_MARKET_SUBSTRATES
        }
    }

    function getBalanceFuses() internal pure returns (BalanceFuses storage balanceFuses) {
        assembly {
            balanceFuses.slot := CFG_PLASMA_VAULT_BALANCE_FUSES
        }
    }

    function getPreHooksConfig() internal pure returns (PreHooksConfig storage preHooksConfig) {
        assembly {
            preHooksConfig.slot := CFG_PLASMA_VAULT_PRE_HOOKS
        }
    }

    function getInstantWithdrawalFusesArray()
        internal
        pure
        returns (InstantWithdrawalFuses storage instantWithdrawalFuses)
    {
        assembly {
            instantWithdrawalFuses.slot := CFG_PLASMA_VAULT_INSTANT_WITHDRAWAL_FUSES_ARRAY
        }
    }

    function getInstantWithdrawalFusesParams()
        internal
        pure
        returns (InstantWithdrawalFusesParams storage instantWithdrawalFusesParams)
    {
        assembly {
            instantWithdrawalFusesParams.slot := CFG_PLASMA_VAULT_INSTANT_WITHDRAWAL_FUSES_PARAMS
        }
    }

    function getPriceOracleMiddleware() internal pure returns (PriceOracleMiddleware storage oracle) {
        assembly {
            oracle.slot := PRICE_ORACLE_MIDDLEWARE
        }
    }

    function getPerformanceFeeData() internal pure returns (PerformanceFeeData storage performanceFeeData) {
        assembly {
            performanceFeeData.slot := PLASMA_VAULT_PERFORMANCE_FEE_DATA
        }
    }

    function getManagementFeeData() internal pure returns (ManagementFeeData storage managementFeeData) {
        assembly {
            managementFeeData.slot := PLASMA_VAULT_MANAGEMENT_FEE_DATA
        }
    }

    function getRewardsClaimManagerAddress()
        internal
        pure
        returns (RewardsClaimManagerAddress storage rewardsClaimManagerAddress)
    {
        assembly {
            rewardsClaimManagerAddress.slot := REWARDS_CLAIM_MANAGER_ADDRESS
        }
    }

    function getMarketsLimits() internal pure returns (MarketLimits storage marketLimits) {
        assembly {
            marketLimits.slot := MARKET_LIMITS
        }
    }

    function getWithdrawManager() internal pure returns (WithdrawManager storage withdrawManager) {
        assembly {
            withdrawManager.slot := WITHDRAW_MANAGER
        }
    }
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
