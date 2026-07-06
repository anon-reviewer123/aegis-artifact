/**
* SPDX-License-Identifier: MIT
*
* Copyright (c) 2016-2019 zOS Global Limited
*
*/
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */

interface IERC20 {

    // Optional functions
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

}
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)
// Copied from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/draft-IERC20Permit.sol

pragma solidity ^0.8.0;

import "./IERC20.sol";

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit is IERC20 {

    /*//////////////////////////////////////////////////////////////
                            Custom errors
	//////////////////////////////////////////////////////////////*/
    /// Block timestamp must to be before deadline.
    /// @param deadline The deadline of the permit.
    /// @param blockTimestamp The timestamp of the execution block.
    error Permit_DeadlineExpired(uint256 deadline, uint256 blockTimestamp);
    /// Recovered address must be owner and not zero address.
    /// @param signerAddress The recovered signer address.
    error Permit_InvalidSigner(address signerAddress);

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
pragma solidity ^0.8.0;

// Given that development on ERC 677 has stalled, we should consider supporting EIP 1363: https://eips.ethereum.org/EIPS/eip-1363
interface IERC677Receiver {

    error IERC677_OnTokenTransferFailed();
    
    function onTokenTransfer(address from, uint256 amount, bytes calldata data) external returns (bool);

}
/**
* SPDX-License-Identifier: LicenseRef-Aktionariat
*
* Proprietary License
*
* This code cannot be used without an explicit permission from the copyright holder.
* If you wish to use the Aktionariat Brokerbot, you can either use the open version
* named Brokerbot.sol that can be used under an MIT License with Automated License Fee Payments,
* or you can get in touch with use to negotiate a license to use LicensedBrokerbot.sol .
*
* Copyright (c) 2021 Aktionariat AG (aktionariat.com), All rights reserved.
*/
pragma solidity ^0.8.0;

import "../utils/Ownable.sol";
import "../ERC20/IERC20.sol";
import "../ERC20/IERC20Permit.sol";
import "../ERC20/IERC677Receiver.sol";
import "./IBrokerbot.sol";
import "../utils/SafeERC20.sol";

contract Brokerbot is IBrokerbot, Ownable {

    using SafeERC20 for IERC20;

    address public override paymenthub;

    IERC20 public override immutable base;  // ERC-20 currency
    IERC20Permit public override immutable token; // ERC-20 share token

    uint256 private price; // current offer price in base currency, without drift
    uint256 public increment; // increment step the price in/decreases when buying/selling

    uint256 public driftStart;
    uint256 public timeToDrift; // seconds until drift pushes price by one drift increment
    int256 public driftIncrement;

    // Note that these settings might be hard-coded in various places, so better not change these values.
    uint8 private constant BUYING_ENABLED = 0x1;
    uint8 private constant SELLING_ENABLED = 0x2;
    // note that in the UI, we call the setting "convert ether", which is the opposite
    uint8 private constant KEEP_ETHER = 0x4;

    // Version history
    // Version 2: added ability to process bank orders even if buying disabled
    // Version 3: added various events, removed license fee
    // Version 4: made version field public so it is actually usable    
    // Version 5: added target address for withdrawEther
    // Version 6: added costs field to notifyTrade
    // Version 7: added withdraw eth event
    // Version 8: use SafeERC20
    uint8 public constant VERSION = 0x8;

    // more bits to be used by payment hub
    uint256 public override settings = BUYING_ENABLED | SELLING_ENABLED;

    event Trade(IERC20Permit indexed token, address who, bytes ref, int amount, IERC20 base, uint totPrice, uint fee, uint newprice);
    event PaymentHubUpdate(address indexed paymentHub);
    event PriceSet(uint256 price, uint256 increment);
    event DriftSet(uint256 timeToDrift, int256 driftIncrement);
    event SettingsChange(uint256 setting);
    // ETH in/out events
    event Received(address indexed from, uint amountETH, uint amountBase);
    event Withdrawn(address indexed target, uint amountETH);
    
    constructor(
        IERC20Permit _token,
        uint256 _price,
        uint256 _increment,
        IERC20 _base,
        address _owner,
        address _paymentHub
    )
        Ownable(_owner)
    {
        base = _base;
        token = _token;
        price = _price;
        increment = _increment;
        paymenthub = _paymentHub;
        // Should we disabled recoverability in the recovery hub here?
        // No, if someone attacks us, we can always trigger a transfer and recover the tokens as well as the collateral.
    }

    function setPrice(uint256 _price, uint256 _increment) external onlyOwner {
        anchorPrice(_price);
        increment = _increment;
        emit PriceSet(_price, _increment);
    }

    function hasDrift() public view returns (bool) {
        return timeToDrift != 0;
    }

    // secondsPerStep should be negative for downwards drift
    function setDrift(uint256 secondsPerStep, int256 _driftIncrement) external onlyOwner {
        anchorPrice(getPrice());
        timeToDrift = secondsPerStep;
        driftIncrement = _driftIncrement;
        emit DriftSet(secondsPerStep, _driftIncrement);
    }

    function anchorPrice(uint256 currentPrice) private {
        price = currentPrice;
        // rely on time stamp is ok, no exact time stamp needed
        // solhint-disable-next-line not-rely-on-time
        driftStart = block.timestamp;
    }

    function getPrice() public view returns (uint256) {
        // rely on time stamp is ok, no exact time stamp needed
        // solhint-disable-next-line not-rely-on-time
        return getPriceAtTime(block.timestamp);
    }

    function getPriceAtTime(uint256 timestamp) public view returns (uint256) {
        if (hasDrift()){
            uint256 passed = timestamp - driftStart;
            int256 drifted = int256(passed / timeToDrift) * driftIncrement;
            int256 driftedPrice = int256(price) + drifted;
            if (driftedPrice < 0){
                return 0;
            } else {
                return uint256(driftedPrice);
            }
        } else {
            return price;
        }
    }

    function buy(address from, uint256 paid, bytes calldata ref) internal returns (uint256) {
        if (!hasSetting(BUYING_ENABLED)) {
            revert Brokerbot_BuyingDisabled();
        }
        uint shares = getShares(paid);
        uint costs = getBuyPrice(shares);
        notifyTraded(from, shares, costs, ref);
        if (costs < paid){
            base.safeTransfer(from, paid - costs);
        }
        IERC20(token).safeTransfer(from, shares);
        return shares;
    }

    // Callers must verify that (hasSetting(BUYING_ENABLED) || msg.sender == owner) holds!
    function notifyTraded(address from, uint256 shares, uint256 costs, bytes calldata ref) internal returns (uint256) {
        // disabling the requirement below for efficiency as this always holds once we reach this point
        // require(hasSetting(BUYING_ENABLED) || msg.sender == owner, "buying disabled");
        price = price + (shares * increment);
        emit Trade(token, from, ref, int256(shares), base, costs, 0, getPrice());
        return costs;
    }

    function notifyTrade(address buyer, uint256 shares, uint256 costs, bytes calldata ref) external onlyOwner {
        notifyTraded(buyer, shares, costs, ref);
    }

    function notifyTradeAndTransfer(address buyer, uint256 shares, uint256 costs, bytes calldata ref) public onlyOwner {
        notifyTraded(buyer, shares, costs, ref);
        IERC20(token).safeTransfer(buyer, shares);
    }

    function notifyTrades(address[] calldata buyers, uint256[] calldata shares, uint256[] calldata costs, bytes[] calldata ref) external onlyOwner {
        for (uint i = 0; i < buyers.length; i++) {
            notifyTraded(buyers[i], shares[i], costs[i], ref[i]);
        }
    }

    function notifyTradesAndTransfer(address[] calldata buyers, uint256[] calldata shares, uint256[] calldata costs, bytes[] calldata ref) external onlyOwner {
        for (uint i = 0; i < buyers.length; i++) {
            notifyTradeAndTransfer(buyers[i], shares[i], costs[i], ref[i]);
        }
    }

    /**
     * @notice Payment hub might actually have sent another accepted token, including Ether.
     * @dev Is either called from payment hub or from transferAndCall of the share token (via onTokenTransfer).
     * @param incomingAsset the erc20 address of either base currency or the share token.
     * @param from Who iniciated the sell/buy.
     * @param amount The amount of shares the are sold / The base amount paid to buy sharees.
     * @param ref Reference data blob.
     * @return The amount of shares bought / The amount received for selling the shares. 
     */
    function processIncoming(IERC20 incomingAsset, address from, uint256 amount, bytes calldata ref) public override payable returns (uint256) {
        if (msg.sender != address(incomingAsset) && msg.sender != paymenthub) {
            revert Brokerbot_InvalidSender(msg.sender);
        }
        if(msg.value > 0) {
            emit Received(from, msg.value, amount);
        }
        if (incomingAsset == token){
            return sell(from, amount, ref);
        } else if (incomingAsset == base){
            return buy(from, amount, ref);
        } else {
            revert("invalid token");
        }
    }

    // ERC-677 recipient
    function onTokenTransfer(address from, uint256 amount, bytes calldata ref) external returns (bool) {
        processIncoming(IERC20(msg.sender), from, amount, ref);
        return true;
    }

    function hasSetting(uint256 setting) private view returns (bool) {
        return settings & setting == setting;
    }

    /**
     * ref 0x01 or old format sells shares for base currency.
     * ref 0x02 indicates a sell via bank transfer.
     */
    function isDirectSale(bytes calldata ref) internal pure returns (bool) {
        if (ref.length == 0 || ref.length == 20) {
            return true; // old format
        } else {
            if (ref[0] == bytes1(0x01)){
                return true;
            } else if (ref[0] == bytes1(0x02)) {
                return false;
            } else {
                revert("unknown ref");
            }
        }
    }


    function sell(address recipient, uint256 amount, bytes calldata ref) internal returns (uint256) {
        if (!hasSetting(SELLING_ENABLED)) {
            revert Brokerbot_SellingDisabled();
        }
        uint256 totPrice = getSellPrice(amount);
        price -= amount * increment;
        if (isDirectSale(ref)){
            base.safeTransfer(recipient, totPrice);
        }
        emit Trade(token, recipient, ref, -int256(amount), base, totPrice, 0, getPrice());
        return totPrice;
    }

    function getSellPrice(uint256 shares) public view override returns (uint256) {
        return getPrice(getPrice() - (shares * increment), shares);
    }

    function getBuyPrice(uint256 shares) public view override returns (uint256) {
        return getPrice(getPrice(), shares);
    }

    function getPrice(uint256 lowest, uint256 shares) internal view returns (uint256){
        if (shares == 0) {
            return 0;
        } else {
            uint256 highest = lowest + (shares - 1) * increment;
            return (lowest + highest) * shares / 2;
        }
    }

    function getShares(uint256 money) public view returns (uint256) {
        uint256 currentPrice = getPrice();
        uint256 min = 0;
        uint256 max = money / currentPrice;
        while (min < max){
            uint256 middle = (min + max)/2;
            uint256 totalPrice = getPrice(currentPrice, middle);
            if (money > totalPrice){
                min = middle + 1;
            } else {
                max = middle;
            }
        }
        return min;
    }

    function withdrawEther(address target, uint256 amount) public ownerOrHub() {
        (bool success, ) = payable(target).call{value:amount}("");
        if (!success) {
            revert Brokerbot_WithdrawFailed(target, amount);
        }
        emit Withdrawn(target, amount);
    }

    function withdrawEther(uint256 amount) external ownerOrHub() {
        withdrawEther(msg.sender, amount);
    }

    function approve(address erc20, address who, uint256 amount) external onlyOwner() {
        IERC20(erc20).approve(who, amount);
    }

    function withdraw(IERC20 ercAddress, address to, uint256 amount) external ownerOrHub() {
        ercAddress.safeTransfer(to, amount);
    }

    function setPaymentHub(address hub) external onlyOwner() {
        paymenthub = hub;
        emit PaymentHubUpdate(paymenthub);
    }

    function setSettings(uint256 _settings) public onlyOwner() {
        settings = _settings;
        emit SettingsChange(_settings);
    }

    function setEnabled(bool _buyingEnabled, bool _sellingEnabled) external onlyOwner() {
        uint256 _settings = settings;
        if (_buyingEnabled != hasSetting(BUYING_ENABLED)){
            _settings ^= BUYING_ENABLED;
        }
        if (_sellingEnabled != hasSetting(SELLING_ENABLED)){
            _settings ^= SELLING_ENABLED;
        }
        setSettings(_settings);
    }
    
    modifier ownerOrHub() {
        if (owner != msg.sender && paymenthub != msg.sender) {
            revert Brokerbot_NotAuthorized(msg.sender);
        }
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC20/IERC20.sol";
import "../ERC20/IERC20Permit.sol";

interface IBrokerbot {

	/*//////////////////////////////////////////////////////////////
                            Custom errors
  //////////////////////////////////////////////////////////////*/
  error Brokerbot_BuyingDisabled();
  error Brokerbot_SellingDisabled();
  /// Sender(msg.sender) has to be incoming token or paymenthub.
  /// @param sender The msg.sender.
  error Brokerbot_InvalidSender(address sender);
  /// target.call() wasn't successful.
  /// @param target The receiver of the Eth.
  /// @param amount The withdraw amount.
  error Brokerbot_WithdrawFailed(address target, uint256 amount);
  /// Sender(msg.sender) needs to be owner or paymenthub.
  /// @param sender The msg.sender.
  error Brokerbot_NotAuthorized(address sender);

  function paymenthub() external view returns (address);

  function base() external view returns (IERC20);

  function token() external view returns (IERC20Permit);
  
  function settings() external view returns (uint256);

  // @return The amount of shares bought on buying or how much in the base currency is transfered on selling
  function processIncoming(IERC20 token_, address from, uint256 amount, bytes calldata ref) external payable returns (uint256);

  function getBuyPrice(uint256 shares) external view returns (uint256);

  function getSellPrice(uint256 shares) external view returns (uint256);

}
// SPDX-License-Identifier: MIT
// Copied from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol
// and modified it.

pragma solidity ^0.8.0;

library Address {

    /// @param target Target address to call the function on.
    error Address_NotTransferNorContract(address target);

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
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.
        return account.code.length > 0;
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

    function functionCallWithValue(address target, bytes memory data, uint256 weiValue) internal returns (bytes memory) {
        if (data.length != 0 && !isContract(target)) {
            revert Address_NotTransferNorContract(target);
        }
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else if (returndata.length > 0) {
            assembly{
                revert (add (returndata, 0x20), mload (returndata))
            }
        } else {
           revert("failed");
        }
    }
}
// SPDX-License-Identifier: MIT
//
// From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol
//
// Modifications:
// - Replaced Context._msgSender() with msg.sender
// - Made leaner
// - Extracted interface

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error Ownable_NotOwner(address sender);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor (address initialOwner) {
        owner = initialOwner;
        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _checkOwner() internal view {
        if (msg.sender != owner) {
            revert Ownable_NotOwner(msg.sender);
        }
    }
}
// SPDX-License-Identifier: MIT
// coppied and adjusted from OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../ERC20/IERC20.sol";
import {IERC20Permit} from "../ERC20/IERC20Permit.sol";
import {Address} from "./Address.sol";

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
        if (nonceAfter != nonceBefore + 1) {
            revert SafeERC20FailedOperation(address(token));
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