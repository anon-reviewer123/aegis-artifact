// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title IFuzeVesting
 * @notice Minimal interface for the Vesting contract (allocate only).
 */
interface IFuzeVesting {
    function allocate(address _user, uint256 _amount) external;
}

/**
 * @title FuzePresale
 * @author Fuze.ac
 * @notice This contract manages a tiered presale of FUZE tokens.
 * @dev It handles purchases with ETH and whitelisted stablecoins, calculates token amounts
 * based on a tiered pricing model, and allocates the purchased tokens to the
 * FuzeVesting contract for a scheduled release. It includes security features
 * like reentrancy guards, pausable functionality, and a secure oracle price update mechanism.
 */
contract FuzePresale is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event TokensPurchased(address indexed user, uint256 tokensOut, uint256 usdPaid);
    event EthPriceUpdated(uint256 oldPrice, uint256 newPrice, address updater);
    event TreasurySet(address indexed newTreasury);
    event PaymentTokenSet(address indexed token, bool isAllowed, uint8 decimals);
    event FundsWithdrawn(address indexed token, uint256 amount);
    event EthWithdrawn(uint256 amount);
    event PriceParamsUpdated(uint256 cooldown, uint256 maxChangeBps, uint256 maxAge);

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Tier {
        uint256 cap;    // cumulative cap in token units (includes decimals)
        uint256 price;  // price in USD * 1e6 per token
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant PRICE_PRECISION = 1e6; // USD with 6 decimals

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/
    IFuzeVesting public immutable vestingContract;
    IERC20Metadata public immutable fuzeToken;
    uint256 public immutable fuzeDecimalsUnit;

    Tier[] public tiers;
    uint256 public tokensSold;

    uint256 public ethUsdPrice;
    uint256 public lastPriceUpdateAt;
    uint256 public priceCooldown = 300; // 5 minutes
    uint256 public maxChangeBps = 2000; // 20%
    uint256 public maxAge = 3600; // 1 hour

    address public treasury;
    mapping(address => bool) public isPaymentTokenWhitelisted;
    mapping(address => uint8)  public stablecoinDecimals;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _fuzeTokenAddress,
        address _vestingContractAddress,
        address _initialTreasury
    ) Ownable(msg.sender) {
        require(_fuzeTokenAddress != address(0), "Presale: bad token");
        require(_vestingContractAddress != address(0), "Presale: bad vesting");
        require(_initialTreasury != address(0), "Presale: bad treasury");

        fuzeToken = IERC20Metadata(_fuzeTokenAddress);
        vestingContract = IFuzeVesting(_vestingContractAddress);
        treasury = _initialTreasury;
        emit TreasurySet(_initialTreasury);

        uint8 decimals = fuzeToken.decimals();
        require(decimals > 0, "Presale: token must have decimals");
        fuzeDecimalsUnit = 10 ** decimals;

        // --- UPDATED TIER DATA ---
        // Pioneer Round: 15M tokens @ $0.015
        tiers.push(Tier(15_000_000 * fuzeDecimalsUnit, 15_000));
        // Builder Round: 25M tokens @ $0.025 (Cumulative Cap: 40M)
        tiers.push(Tier(40_000_000 * fuzeDecimalsUnit, 25_000));
        // Architect Round: 30M tokens @ $0.035 (Cumulative Cap: 70M)
        tiers.push(Tier(70_000_000 * fuzeDecimalsUnit, 35_000));
        // Vanguard Round: 40M tokens @ $0.045 (Cumulative Cap: 110M)
        tiers.push(Tier(110_000_000 * fuzeDecimalsUnit, 45_000));
    }

    /*//////////////////////////////////////////////////////////////
                               RECEIVE
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Allows the contract to receive ETH directly, triggering a purchase.
     * @dev Forwards the call to the internal buy function with no minimum tokens out.
     */
    receive() external payable {
        _buyWithEthInternal(0);
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC BUY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Purchase FUZE tokens using ETH.
     * @param minTokensOut The minimum amount of tokens the user is willing to receive, to protect against slippage.
     */
    function buyWithEth(uint256 minTokensOut) external payable whenNotPaused nonReentrant {
        _buyWithEthInternal(minTokensOut);
    }

    /**
     * @notice Purchase FUZE tokens using a whitelisted stablecoin.
     * @param _paymentToken The address of the stablecoin to use for payment.
     * @param _amount The amount of the stablecoin to spend.
     * @param minTokensOut The minimum amount of FUZE tokens the user is willing to receive.
     */
    function buyWithStablecoin(address _paymentToken, uint256 _amount, uint256 minTokensOut)
        external
        whenNotPaused
        nonReentrant
    {
        _buyWithStablecoinInternal(_paymentToken, _amount, minTokensOut);
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL CORE
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Internal logic for handling ETH purchases. Converts ETH to USD and calculates the token amount.
     */
    function _buyWithEthInternal(uint256 minTokensOut) internal {
        require(ethUsdPrice > 0, "Presale: ETH price not set");
        require(block.timestamp - lastPriceUpdateAt <= maxAge, "Presale: ETH price stale");

        uint256 usdValue = (msg.value * ethUsdPrice) / 1 ether;
        require(usdValue > 0, "Presale: ETH amount too low");

        (uint256 tokensToAllocate, uint256 usdValuePaid) = _calculatePurchase(usdValue);
        require(tokensToAllocate >= minTokensOut, "Presale: slippage");

        tokensSold += tokensToAllocate;

        vestingContract.allocate(msg.sender, tokensToAllocate);
        emit TokensPurchased(msg.sender, tokensToAllocate, usdValuePaid);

        if (usdValuePaid < usdValue) {
            uint256 ethPaid = (usdValuePaid * 1 ether) / ethUsdPrice;
            uint256 refund = msg.value - ethPaid;
            (bool ok, ) = msg.sender.call{value: refund}("");
            require(ok, "Presale: ETH refund failed");
        }
    }

    /**
     * @dev Internal logic for handling stablecoin purchases. Normalizes the stablecoin amount to USD.
     */
    function _buyWithStablecoinInternal(address _paymentToken, uint256 _amount, uint256 minTokensOut) internal {
        require(isPaymentTokenWhitelisted[_paymentToken], "Presale: token not whitelisted");
        
        uint256 usdValue = _normalizeStableToUsd(_paymentToken, _amount);
        require(usdValue > 0, "Presale: amount too low");

        (uint256 tokensToAllocate, uint256 usdValuePaid) = _calculatePurchase(usdValue);
        require(tokensToAllocate >= minTokensOut, "Presale: slippage");

        uint256 payAmount = _normalizeUsdToStable(_paymentToken, usdValuePaid);

        require(_amount >= payAmount, "Presale: insufficient allowance or balance");

        IERC20 stable = IERC20(_paymentToken);
        stable.safeTransferFrom(msg.sender, address(this), payAmount);

        tokensSold += tokensToAllocate;

        vestingContract.allocate(msg.sender, tokensToAllocate);
        emit TokensPurchased(msg.sender, tokensToAllocate, usdValuePaid);
    }

    /**
     * @notice Calculates the number of tokens a user receives for a given USD value, accounting for multiple price tiers.
     * @param _usdValue The value of the user's contribution in USD with 6 decimals.
     * @return totalTokens The total amount of FUZE tokens to be allocated.
     * @return totalCost The actual USD cost for the allocated tokens.
     */
    function _calculatePurchase(uint256 _usdValue) internal view returns (uint256 totalTokens, uint256 totalCost) {
        uint256 remainingUsd = _usdValue;
        uint256 currentTokensSold = tokensSold;

        uint256 numTiers = tiers.length;

        for (uint256 i = 0; i < numTiers && remainingUsd > 0; i++) {
            Tier memory tier = tiers[i];
            if (currentTokensSold >= tier.cap) continue;

            uint256 tierRemainingTokens = tier.cap - currentTokensSold;
            uint256 costForAllInTier = (tierRemainingTokens * tier.price) / fuzeDecimalsUnit;

            if (remainingUsd >= costForAllInTier) {
                totalTokens += tierRemainingTokens;
                totalCost += costForAllInTier;
                remainingUsd -= costForAllInTier;
                currentTokensSold += tierRemainingTokens;
            } else {
                uint256 tokensHere = (remainingUsd * fuzeDecimalsUnit) / tier.price;
                totalTokens += tokensHere;
                totalCost += remainingUsd;
                remainingUsd = 0;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN & CONFIG
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Sets the ETH to USD price. Can only be called by the owner.
     * @dev Includes safeguards against rapid or large price changes.
     * @param _new The new ETH price in USD, with 6 decimals.
     */
    function setEthUsdPrice(uint256 _new) external onlyOwner {
        uint256 old = ethUsdPrice;
        if (old == 0) {
            require(_new > 0, "Presale: bad price");
            ethUsdPrice = _new;
        } else {
            require(_new > 0, "Presale: bad price");
            require(block.timestamp >= lastPriceUpdateAt + priceCooldown, "Presale: cooldown");
            uint256 delta = _new > old ? _new - old : old - _new;
            require(delta * 10_000 <= old * maxChangeBps, "Presale: exceeds maxChange");
            ethUsdPrice = _new;
        }
        lastPriceUpdateAt = block.timestamp;
        emit EthPriceUpdated(old, _new, msg.sender);
    }
    
    /**
     * @notice Updates the parameters for the ETH price oracle.
     * @param _cooldown The minimum time in seconds between price updates.
     * @param _maxChangeBps The maximum allowed price change in basis points (1% = 100 bps).
     * @param _maxAge The maximum age in seconds of the price feed before it's considered stale.
     */
    function setPriceParams(uint256 _cooldown, uint256 _maxChangeBps, uint256 _maxAge) external onlyOwner {
        require(_maxChangeBps <= 5000, "Presale: maxChange too high"); // Max 50% change
        priceCooldown = _cooldown;
        maxChangeBps = _maxChangeBps;
        maxAge = _maxAge;
        emit PriceParamsUpdated(_cooldown, _maxChangeBps, _maxAge);
    }

    /**
     * @notice Sets the address that will receive the funds from the sale.
     * @param _newTreasury The new treasury address.
     */
    function setTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Presale: bad treasury");
        treasury = _newTreasury;
        emit TreasurySet(_newTreasury);
    }

    /**
     * @notice Whitelists or removes a stablecoin as a valid payment token.
     * @param _token The address of the ERC20 stablecoin.
     * @param _isAllowed True to whitelist, false to remove.
     */
    function setPaymentToken(address _token, bool _isAllowed) external onlyOwner {
        uint8 dec = 0;
        if (_isAllowed) {
            dec = IERC20Metadata(_token).decimals();
            require(dec >= 2 && dec <= 30, "Presale: unusual decimals");
            stablecoinDecimals[_token] = dec;
            isPaymentTokenWhitelisted[_token] = true;
        } else {
            delete stablecoinDecimals[_token];
            delete isPaymentTokenWhitelisted[_token];
        }
        emit PaymentTokenSet(_token, _isAllowed, dec);
    }

    /** @notice Pauses the contract, preventing new purchases. Can only be called by the owner. */
    function pause() external onlyOwner { _pause(); }

    /** @notice Unpauses the contract, allowing new purchases. Can only be called by the owner. */
    function unpause() external onlyOwner { _unpause(); }

    /*//////////////////////////////////////////////////////////////
                               WITHDRAWALS
    //////////////////////////////////////////////////////////////*/
    /** @notice Withdraws all accumulated ETH to the treasury. */
    function withdrawEth() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool ok, ) = treasury.call{value: balance}("");
            require(ok, "Presale: ETH withdrawal failed");
            emit EthWithdrawn(balance);
        }
    }

    /** @notice Withdraws all accumulated balance of a specific whitelisted ERC20 token to the treasury. */
    function withdrawErc20(address _tokenAddress) external onlyOwner {
        require(isPaymentTokenWhitelisted[_tokenAddress], "Presale: not whitelisted");
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(treasury, balance);
            emit FundsWithdrawn(_tokenAddress, balance);
        }
    }

    /**
     * @notice Rescues any non-payment ERC20 tokens accidentally sent to this contract.
     * @param _tokenAddress The address of the token to rescue.
     * @param amount The amount to rescue. If 0, rescues the entire balance.
     */
    function rescueERC20(address _tokenAddress, uint256 amount) external onlyOwner {
        require(!isPaymentTokenWhitelisted[_tokenAddress], "Presale: use withdrawErc20");
        IERC20 token = IERC20(_tokenAddress);
        uint256 rescueAmount = amount == 0 ? token.balanceOf(address(this)) : amount;
        if (rescueAmount > 0) {
            token.safeTransfer(treasury, rescueAmount);
            emit FundsWithdrawn(_tokenAddress, rescueAmount);
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                             INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Normalizes a stablecoin amount to a standard 6-decimal USD value.
     */
    function _normalizeStableToUsd(address token, uint256 amount) internal view returns (uint256) {
        uint8 dec = stablecoinDecimals[token];
        if (dec == 6) return amount;
        return dec < 6 ? amount * (10 ** (6 - dec)) : amount / (10 ** (dec - 6));
    }

    /**
     * @dev Converts a standard 6-decimal USD value back to a stablecoin's native amount.
     */
    function _normalizeUsdToStable(address token, uint256 usdAmount) internal view returns (uint256) {
        uint8 dec = stablecoinDecimals[token];
        if (dec == 6) return usdAmount;
        return dec < 6 ? usdAmount / (10 ** (6 - dec)) : usdAmount * (10 ** (dec - 6));
    }

    /*//////////////////////////////////////////////////////////////
                               VIEW HELPERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice A public view function for the frontend to calculate purchase amounts without spending gas.
     * @param _usdValue The value of the user's potential contribution in USD with 6 decimals.
     * @return totalTokens The total amount of FUZE tokens to be allocated.
     * @return totalCost The actual USD cost for the allocated tokens.
     */
    function calculatePurchaseView(uint256 _usdValue) public view returns (uint256 totalTokens, uint256 totalCost) {
        return _calculatePurchase(_usdValue);
    }
    
    /**
     * @notice Returns the index of the current pricing tier.
     */
    function currentTierIndex() public view returns (uint256 idx) {
        uint256 sold = tokensSold;
        uint256 numTiers = tiers.length;
        for (uint256 i = 0; i < numTiers; i++) {
            if (sold < tiers[i].cap) return i;
        }
        return numTiers;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

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

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
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
        _paused = true;
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
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

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
abstract contract ReentrancyGuard {
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

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity >=0.6.2;

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
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

pragma solidity >=0.4.16;

import {IERC165} from "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

pragma solidity >=0.4.16;

import {IERC20} from "../token/ERC20/IERC20.sol";

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
