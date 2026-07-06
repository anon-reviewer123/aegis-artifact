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

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./../interfaces/IWETH.sol";
import {IMorpho, MarketParams} from "./../interfaces/MorphoBlue/IMorpho.sol";
import "../ServiceRegistry.sol";

contract MorphoBlueProxyActions {
    address public immutable weth;
    IMorpho public immutable morphoBlue;

    constructor(address _weth, address _morpho) {
        weth = _weth;
        morphoBlue = IMorpho(_morpho);
    }

    function openPosition(MarketParams calldata marketParams, address token, uint256 amount) external payable {
        _pull(token, amount);
        IERC20(token).approve(address(morphoBlue), amount);
        morphoBlue.supplyCollateral(marketParams, amount, address(this), bytes(""));
        emit Deposit(address(this), token, amount);
    }

    function drawDebt(MarketParams calldata marketParams, address token, address recipient, uint256 amount) external payable {
        if (amount > 0) {
            morphoBlue.borrow(marketParams, amount, 0, address(this), address(this));
            _send(token, recipient, amount);
            emit Borrow(address(this), token, amount);
        }
    }

    function repayDebt(MarketParams calldata marketParams, address token, uint256 amount, address user) public payable {
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "morpho-blue-proxy-action/insufficient-repay-balance"
        );

        IERC20(token).approve(address(morphoBlue), amount);
        morphoBlue.repay(marketParams, amount, 0, user, bytes(""));
        emit Repay(address(this), token, amount);
    }

    function depositCollateral(MarketParams calldata marketParams, address token, uint256 amount) external payable {
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "morpho-blue-proxy-action/insufficient-deposit-balance"
        );
        IERC20(token).approve(address(morphoBlue), amount);
        morphoBlue.supplyCollateral(marketParams, amount, address(this), bytes(""));
        emit Deposit(address(this), token, amount);
    }

    function withdrawCollateral(MarketParams calldata marketParams, address token, address recipient, uint256 amount) external {
        morphoBlue.withdrawCollateral(marketParams, amount, address(this), address(this));
        _send(token, recipient, amount);
        emit Withdraw(address(this), token, amount);
    }

    function _send(address token, address recipient, uint256 amount) internal {
        if (token == weth) {
            IWETH(weth).withdraw(amount);
            payable(recipient).transfer(amount);
        } else {
            IERC20(token).transfer(recipient, amount);
        }
    }

    function _pull(address token, uint256 amount) internal {
        if (token == weth) {
            require(msg.value == amount, "morpho-blue-proxy-action/insufficient-eth-amount");
            IWETH(weth).deposit{value: amount}();
        } else {
            require(
                IERC20(token).allowance(msg.sender, address(this)) == amount,
                "morpho-blue-proxy-action/insufficient-allowance"
            );
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }
    }

    event Deposit(address indexed depositor, address indexed token, uint256 amount);

    event Withdraw(address indexed depositor, address indexed token, uint256 amount);

    event Borrow(address indexed depositor, address indexed token, uint256 amount);

    event Repay(address indexed depositor, address indexed token, uint256 amount);
}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

interface IWETH {
    function withdraw(uint256 wad) external;

    function deposit() external payable;

    function balanceOf(address owner) external view returns (uint256);
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
  function supplyCollateral(
    MarketParams memory marketParams,
    uint256 assets,
    address onBehalf,
    bytes memory data
  ) external;

  /// @notice Withdraws `assets` of collateral on behalf of `onBehalf` and sends the assets to `receiver`.
  /// @dev `msg.sender` must be authorized to manage `onBehalf`'s positions.
  /// @dev Withdrawing an amount corresponding to more collateral than supplied will revert for underflow.
  /// @param marketParams The market to withdraw collateral from.
  /// @param assets The amount of collateral to withdraw.
  /// @param onBehalf The address of the owner of the collateral position.
  /// @param receiver The address that will receive the collateral assets.
  function withdrawCollateral(
    MarketParams memory marketParams,
    uint256 assets,
    address onBehalf,
    address receiver
  ) external;

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
  function setAuthorizationWithSig(
    Authorization calldata authorization,
    Signature calldata signature
  ) external;

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
  function position(
    Id id,
    address user
  ) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

  /// @notice The state of the market corresponding to `id`.
  /// @dev Warning: `totalSupplyAssets` does not contain the accrued interest since the last interest accrual.
  /// @dev Warning: `totalBorrowAssets` does not contain the accrued interest since the last interest accrual.
  /// @dev Warning: `totalSupplyShares` does not contain the accrued shares by `feeRecipient` since the last interest
  /// accrual.
  function market(
    Id id
  )
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
  function idToMarketParams(
    Id id
  )
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

// SPDX-License-Identifier: AGPL-3.0-or-later

/// ServiceRegistry.sol

// Copyright (C) 2021-2021 Oazo Apps Limited

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
pragma solidity ^0.8.0;

contract ServiceRegistry {
    uint256 public constant MAX_DELAY = 30 days;

    mapping(bytes32 => uint256) public lastExecuted;
    mapping(bytes32 => address) private namedService;
    mapping(bytes32 => bool) private invalidHashes;
    address public owner;
    uint256 public requiredDelay;

    modifier validateInput(uint256 len) {
        require(msg.data.length == len, "registry/illegal-padding");
        _;
    }

    modifier delayedExecution() {
        bytes32 operationHash = keccak256(msg.data);
        uint256 reqDelay = requiredDelay;

        /* solhint-disable not-rely-on-time */
        if (lastExecuted[operationHash] == 0 && reqDelay > 0) {
            // not called before, scheduled for execution
            lastExecuted[operationHash] = block.timestamp;
            emit ChangeScheduled(operationHash, block.timestamp + reqDelay, msg.data);
        } else {
            require(
                block.timestamp - reqDelay > lastExecuted[operationHash],
                "registry/delay-too-small"
            );
            emit ChangeApplied(operationHash, block.timestamp, msg.data);
            _;
            lastExecuted[operationHash] = 0;
        }
        /* solhint-enable not-rely-on-time */
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "registry/only-owner");
        _;
    }

    constructor(uint256 initialDelay) {
        require(initialDelay <= MAX_DELAY, "registry/invalid-delay");
        requiredDelay = initialDelay;
        owner = msg.sender;
    }

    function transferOwnership(
        address newOwner
    ) external onlyOwner validateInput(36) delayedExecution {
        owner = newOwner;
    }

    function changeRequiredDelay(
        uint256 newDelay
    ) external onlyOwner validateInput(36) delayedExecution {
        require(newDelay <= MAX_DELAY, "registry/invalid-delay");
        requiredDelay = newDelay;
    }

    function getServiceNameHash(string memory name) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(name));
    }

    function addNamedService(
        bytes32 serviceNameHash,
        address serviceAddress
    ) external onlyOwner validateInput(68) delayedExecution {
        require(invalidHashes[serviceNameHash] == false, "registry/service-name-used-before");
        require(namedService[serviceNameHash] == address(0), "registry/service-override");
        namedService[serviceNameHash] = serviceAddress;
        emit NamedServiceAdded(serviceNameHash, serviceAddress);
    }

    function removeNamedService(bytes32 serviceNameHash) external onlyOwner validateInput(36) {
        require(namedService[serviceNameHash] != address(0), "registry/service-does-not-exist");
        namedService[serviceNameHash] = address(0);
        invalidHashes[serviceNameHash] = true;
        emit NamedServiceRemoved(serviceNameHash);
    }

    function getRegisteredService(string memory serviceName) external view returns (address) {
        return namedService[keccak256(abi.encodePacked(serviceName))];
    }

    function getServiceAddress(bytes32 serviceNameHash) external view returns (address) {
        return namedService[serviceNameHash];
    }

    function clearScheduledExecution(
        bytes32 scheduledExecution
    ) external onlyOwner validateInput(36) {
        require(lastExecuted[scheduledExecution] > 0, "registry/execution-not-scheduled");
        lastExecuted[scheduledExecution] = 0;
        emit ChangeCancelled(scheduledExecution);
    }

    event ChangeScheduled(bytes32 dataHash, uint256 scheduledFor, bytes data);
    event ChangeApplied(bytes32 dataHash, uint256 appliedAt, bytes data);
    event ChangeCancelled(bytes32 dataHash);
    event NamedServiceRemoved(bytes32 nameHash);
    event NamedServiceAdded(bytes32 nameHash, address service);
}
