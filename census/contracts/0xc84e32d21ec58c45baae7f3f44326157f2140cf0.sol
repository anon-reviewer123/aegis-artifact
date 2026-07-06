// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ExecuteArgs, TransferInfo, DestinationTransferStatus} from "../libraries/LibConnextStorage.sol";
import {TokenId} from "../libraries/TokenId.sol";

interface IConnext {

  // ============ BRIDGE ==============

  function xcall(
    uint32 _destination,
    address _to,
    address _asset,
    address _delegate,
    uint256 _amount,
    uint256 _slippage,
    bytes calldata _callData
  ) external payable returns (bytes32);

  function xcall(
    uint32 _destination,
    address _to,
    address _asset,
    address _delegate,
    uint256 _amount,
    uint256 _slippage,
    bytes calldata _callData,
    uint256 _relayerFee
  ) external returns (bytes32);

  function xcallIntoLocal(
    uint32 _destination,
    address _to,
    address _asset,
    address _delegate,
    uint256 _amount,
    uint256 _slippage,
    bytes calldata _callData
  ) external payable returns (bytes32);

  function execute(ExecuteArgs calldata _args) external returns (bytes32 transferId);

  function forceUpdateSlippage(TransferInfo calldata _params, uint256 _slippage) external;

  function forceReceiveLocal(TransferInfo calldata _params) external;

  function bumpTransfer(bytes32 _transferId) external payable;

  function routedTransfers(bytes32 _transferId) external view returns (address[] memory);

  function transferStatus(bytes32 _transferId) external view returns (DestinationTransferStatus);

  function remote(uint32 _domain) external view returns (address);

  function domain() external view returns (uint256);

  function nonce() external view returns (uint256);

  function approvedSequencers(address _sequencer) external view returns (bool);

  function xAppConnectionManager() external view returns (address);

  // ============ ROUTERS ==============

  function LIQUIDITY_FEE_NUMERATOR() external view returns (uint256);

  function LIQUIDITY_FEE_DENOMINATOR() external view returns (uint256);

  function getRouterApproval(address _router) external view returns (bool);

  function getRouterRecipient(address _router) external view returns (address);

  function getRouterOwner(address _router) external view returns (address);

  function getProposedRouterOwner(address _router) external view returns (address);

  function getProposedRouterOwnerTimestamp(address _router) external view returns (uint256);

  function maxRoutersPerTransfer() external view returns (uint256);

  function routerBalances(address _router, address _asset) external view returns (uint256);

  function getRouterApprovalForPortal(address _router) external view returns (bool);

  function initializeRouter(address _owner, address _recipient) external;

  function setRouterRecipient(address _router, address _recipient) external;

  function proposeRouterOwner(address _router, address _proposed) external;

  function acceptProposedRouterOwner(address _router) external;

  function addRouterLiquidityFor(
    uint256 _amount,
    address _local,
    address _router
  ) external payable;

  function addRouterLiquidity(uint256 _amount, address _local) external payable;

  function removeRouterLiquidityFor(
    TokenId memory _canonical,
    uint256 _amount,
    address payable _to,
    address _router
  ) external;

  function removeRouterLiquidity(TokenId memory _canonical, uint256 _amount, address payable _to) external;

  // ============ TOKEN_FACET ==============
  function adoptedToCanonical(address _adopted) external view returns (TokenId memory);

  function approvedAssets(TokenId calldata _canonical) external view returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @notice Enum representing status of destination transfer
 * @dev Status is only assigned on the destination domain, will always be "none" for the
 * origin domains
 * @return uint - Index of value in enum
 */
enum DestinationTransferStatus {
  None, // 0
  Reconciled, // 1
  Executed, // 2
  Completed // 3 - executed + reconciled
}

/**
 * @notice These are the parameters that will remain constant between the
 * two chains. They are supplied on `xcall` and should be asserted on `execute`
 * @property to - The account that receives funds, in the event of a crosschain call,
 * will receive funds if the call fails.
 *
 * @param originDomain - The originating domain (i.e. where `xcall` is called)
 * @param destinationDomain - The final domain (i.e. where `execute` / `reconcile` are called)\
 * @param canonicalDomain - The canonical domain of the asset you are bridging
 * @param to - The address you are sending funds (and potentially data) to
 * @param delegate - An address who can execute txs on behalf of `to`, in addition to allowing relayers
 * @param receiveLocal - If true, will use the local asset on the destination instead of adopted.
 * @param callData - The data to execute on the receiving chain. If no crosschain call is needed, then leave empty.
 * @param slippage - Slippage user is willing to accept from original amount in expressed in BPS (i.e. if
 * a user takes 1% slippage, this is expressed as 1_000)
 * @param originSender - The msg.sender of the xcall
 * @param bridgedAmt - The amount sent over the bridge (after potential AMM on xcall)
 * @param normalizedIn - The amount sent to `xcall`, normalized to 18 decimals
 * @param nonce - The nonce on the origin domain used to ensure the transferIds are unique
 * @param canonicalId - The unique identifier of the canonical token corresponding to bridge assets
 */
struct TransferInfo {
  uint32 originDomain;
  uint32 destinationDomain;
  uint32 canonicalDomain;
  address to;
  address delegate;
  bool receiveLocal;
  bytes callData;
  uint256 slippage;
  address originSender;
  uint256 bridgedAmt;
  uint256 normalizedIn;
  uint256 nonce;
  bytes32 canonicalId;
}

/**
 * @notice
 * @param params - The TransferInfo. These are consistent across sending and receiving chains.
 * @param routers - The routers who you are sending the funds on behalf of.
 * @param routerSignatures - Signatures belonging to the routers indicating permission to use funds
 * for the signed transfer ID.
 * @param sequencer - The sequencer who assigned the router path to this transfer.
 * @param sequencerSignature - Signature produced by the sequencer for path assignment accountability
 * for the path that was signed.
 */
struct ExecuteArgs {
  TransferInfo params;
  address[] routers;
  bytes[] routerSignatures;
  address sequencer;
  bytes sequencerSignature;
}
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.0;

// ============= Structs =============

// Tokens are identified by a TokenId:
// domain - 4 byte chain ID of the chain from which the token originates
// id - 32 byte identifier of the token address on the origin chain, in that chain's address format
struct TokenId {
  uint32 domain;
  bytes32 id;
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './IWETH9.sol';

import {IConnext} from "@connext/interfaces/core/IConnext.sol";

contract BridgeFee is Ownable{
    address feeReceiver;
    IConnext public immutable connext;
    IWETH9 public immutable WETH9;

    constructor(address _feeReceiver, address _connext, address _WETH9, address _owner) Ownable(_owner) {
        feeReceiver = _feeReceiver;
        connext = IConnext(_connext);
        WETH9 = IWETH9(_WETH9);
    }

    fallback() external payable {}

    receive() external payable {}

    function xcall(uint256 feeAmount, bool isTokenInNative, uint32 _destination, address _to, address _asset, address _delegate, uint256 _amount, uint256 _slippage, bytes calldata _callData, uint256 _relayerFee) external payable returns (bytes32){
        uint256 totalAmount = feeAmount + _amount;
        _handleTokenIn(_asset, totalAmount, _relayerFee, isTokenInNative);
        if(feeAmount > 0){
            _transferFee(_asset, feeAmount);
        }
        _safeApprove(_asset, address(connext), _amount);
        return connext.xcall{value:_relayerFee}(_destination, _to, _asset, _delegate, _amount, _slippage, _callData);
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner{
        feeReceiver = _feeReceiver;
    }

    function transferErc20(address _asset, address _destination, uint256 _amount) external onlyOwner {
        _safeTransfer(_asset, _destination, _amount);
    }

    function transferNative(address _destination, uint256 _amount) external onlyOwner {
        (bool sent, bytes memory data) = _destination.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    function _handleTokenIn(address _asset, uint256 _amountIn, uint256 _relayerFee, bool _isTokenInNative) internal {
        if(_isTokenInNative) {
            require(msg.value == _amountIn + _relayerFee, "Incorrect amount of ETH sent");
            WETH9.deposit{value: _amountIn}();
        } else {
            _safeTransferFrom(_asset, msg.sender, address(this), _amountIn);
        }
    }

    function _transferFee(address _asset, uint256 _amount) internal {
        _safeTransfer(_asset, feeReceiver, _amount);
    }

    function _safeTransferFrom(address _asset, address _from, address _destination, uint256 _amount) internal {
        bool sent = IERC20(_asset).transferFrom(_from, _destination, _amount);
        require(sent, 'token transfer failed');
    }

    function _safeTransfer(address _asset, address _destination, uint256 _amount) internal {
        bool sent = IERC20(_asset).transfer(_destination, _amount);
        require(sent, 'token transfer failed');
    }

    function _safeApprove(address _asset, address _spender, uint256 _amount) internal {
        bool approved = IERC20(_asset).approve(_spender, _amount);
        require(approved, 'token transfer failed');
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title Interface for WETH9
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}