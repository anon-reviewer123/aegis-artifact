// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LiquidStakingTokenLockboxCompose} from "src/layer2/LiquidStakingTokenLockboxCompose.sol";
import {MessagingFee} from "src/vendor/layerzero-upgradeable/oapp/OAppSenderUpgradeable.sol";
import {MsgCodec} from "src/layer2/libraries/MsgCodec.sol";
import {Errors} from "src/layer2/libraries/Errors.sol";

/**
 * @title  MuiltichainLockbox
 * @notice An OApp contract for handling LiquidStakingToken operations between mainnet and L2.
 * @dev    This contract is responsible for handling deposits of LiquidStakingTokens between mainnet and L2s.
 * @author redactedcartel.finance
 */
contract MultichainLockbox is LiquidStakingTokenLockboxCompose {
    /// @custom:storage-location erc7201:redacted.storage.LiquidStakingTokenLockbox
    struct MultichainLockboxStorage {
        address oftLockbox;
    }

    // keccak256(abi.encode(uint256(keccak256(redacted.storage.MultichainLiquidStakingTokenLockbox)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MultichainLockboxStorageLocation =
        0x897e2bd6d2b1fdc2f2eafe3d01dc261c27476164ef4fd48c6a72614cdf731b00;

    /**
     * @notice Contract constructor to initialize LiquidStakingTokenLockboxCompose with necessary parameters and configurations.
     * @dev    This constructor sets up the LiquidStakingTokenLockboxCompose contract, configuring key parameters and initializing state variables.
     * @param  _endpoint   address  The address of the LOCAL LayerZero endpoint.
     * @param  _dstEid     uint32   The destination endpoint ID for L2.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _endpoint,
        uint32 _dstEid
    ) LiquidStakingTokenLockboxCompose(_endpoint, _dstEid) {}

    function _getMultichainLockboxStorage()
        private
        pure
        returns (MultichainLockboxStorage storage $)
    {
        assembly {
            $.slot := MultichainLockboxStorageLocation
        }
    }

    event OFTLockboxSet(address oftLockbox);

    /**
     * @notice Perform deposit via AutoPxEth and then relaying the message to L2.
     * @dev    Accept pxEth deposits and then mint apxEth to be stored in the vault as well as sending message to L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount.
     * @param _shouldWrap bool     Whether to wrap rebase token on destination chain.
     * @param  _options   bytes    Additional options for the message.
     */
    function depositEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable override nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handleEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _sendDeposit(
            _dstEid,
            _receiver,
            _refundAddress,
            _amount,
            amount,
            assetsPerShare,
            _shouldWrap,
            true,
            _options
        );

        emit Deposit(
            _dstEid,
            receipt,
            msg.sender,
            _receiver,
            address(0),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Perform deposit via PxEth and then relaying the message to L2.
     * @dev    Accept pxEth deposits and then mint apxEth to be stored in the vault as well as sending message to L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount.
     * @param  _shouldWrap bool     Whether to wrap rebase token on destination chain.
     * @param  _options   bytes    Additional options for the message.
     */
    function depositPxEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable override nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handlePxEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _sendDeposit(
            _dstEid,
            _receiver,
            _refundAddress,
            _amount,
            amount,
            assetsPerShare,
            _shouldWrap,
            false,
            _options
        );

        emit Deposit(
            _dstEid,
            receipt,
            msg.sender,
            _receiver,
            address(getTokenOut()),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Perform deposit via ApxETH and then relaying the message to L2.
     * @dev    Accept apxEth deposits to be stored in the vault as well as sending message to L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount (in shares).
     * @param  _options   bytes    Additional options for the message.
     */
    function depositApxEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable override nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handleApxEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _sendDeposit(
            _dstEid,
            _receiver,
            _refundAddress,
            _amount,
            amount,
            assetsPerShare,
            _shouldWrap,
            false,
            _options
        );

        emit Deposit(
            _dstEid,
            receipt,
            msg.sender,
            _receiver,
            address(getTokenOut()),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Set the OFTLockbox contract address.
     * @param oftLockbox The address of the OFTLockbox contract.
     */
    function setOFTLockbox(address oftLockbox) external onlyOwner {
        _getMultichainLockboxStorage().oftLockbox = oftLockbox;

        emit OFTLockboxSet(oftLockbox);
    }

    /**
     * @notice Encode the compose message.
     * @param _dstEid The destination endpoint ID.
     * @param _lockbox The address of the lockbox.
     * @param _receiver The address of the receiver.
     * @param _guid The GUID.
     * @param _amountIn The amount in.
     * @param _amountOut The amount out.
     */
    function _encodeComposeMsg(
        uint32 _dstEid,
        address _lockbox,
        address _receiver,
        bytes32 _guid,
        uint256 _amountIn,
        uint256 _amountOut
    ) internal pure virtual returns (bytes memory) {
        return
            abi.encode(
                bytes32(uint256(uint160(_lockbox))),
                _dstEid,
                _guid,
                _receiver,
                _amountIn,
                _amountOut
            );
    }

    /**
     * @notice send deposit to the destination endpoint.
     * @param _dstEid           uint32 The destination endpoint ID.
     * @param _receiver         address The address of the receiver.
     * @param _refundAddress    address The address to receive any excess funds sent to layer zero.
     * @param _depositAmount    uint256 The deposit amount.
     * @param _receivedAmount   uint256 The received amount.
     * @param _assetsPerShare   uint256 The assets per share.
     * @param _shouldWrap       bool Whether to wrap rebase token on destination chain.
     * @param _ethDeposit       bool Whether the deposit is in ETH.
     * @param _options          bytes Additional options for the message.
     */
    function _sendDeposit(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _depositAmount,
        uint256 _receivedAmount,
        uint256 _assetsPerShare,
        bool _shouldWrap,
        bool _ethDeposit,
        bytes calldata _options
    ) internal returns (bytes32 receipt) {
        if (_dstEid != L2_EID) {
            if (_shouldWrap) revert Errors.MultichainDepositsCannotBeWrapped();
            address oftLockbox = _getMultichainLockboxStorage().oftLockbox;
            if (oftLockbox == address(0)) revert Errors.OFTLockboxNotSet();

            receipt = _send(
                _encodeDeposit(
                    _receivedAmount,
                    _assetsPerShare,
                    oftLockbox,
                    _shouldWrap
                ),
                _encodeComposeMsg(
                    _dstEid,
                    oftLockbox,
                    _receiver,
                    bytes32(0x0), // not used
                    _depositAmount,
                    _receivedAmount
                ),
                combineOptions(_dstEid, 1, _options),
                _ethDeposit ? msg.value - _depositAmount : msg.value,
                _refundAddress
            );
        } else {
            receipt = _send(
                _encodeDeposit(
                    _receivedAmount,
                    _assetsPerShare,
                    _receiver,
                    _shouldWrap
                ),
                "",
                combineOptions(_dstEid, 0, _options),
                _ethDeposit ? msg.value - _depositAmount : msg.value,
                _refundAddress
            );
        }
    }

    /**
     * @notice Quote gas cost for multichain deposit messages
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _amount    uint256  Deposit amount.
     * @param  _options   bytes    Additional options for the message.
     */
    function quoteMultichainDeposit(
        uint32 _dstEid,
        address _receiver,
        uint256 _amount,
        bytes calldata _options
    ) external view returns (MessagingFee memory msgFee) {
        return
            _quote(
                L2_EID,
                MsgCodec.encode(
                    abi.encode(
                        1,
                        _amount, // Use amount directly for quote
                        uint256(1e18),
                        _receiver,
                        _syncedIdsBatch()
                    ),
                    abi.encode(
                        bytes32(uint256(uint160(address(this)))),
                        L2_EID,
                        bytes32(uint256(1)),
                        _receiver,
                        uint256(1e18),
                        uint256(1e18)
                    )
                ),
                combineOptions(_dstEid, 1, _options),
                false
            );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IAutoPxEth} from "../interfaces/IAutoPxEth.sol";
import {L1SyncPool} from "src/layer2/L1SyncPool.sol";
import {IPirexEth} from "../interfaces/IPirexEthDeposit.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {OAppUpgradeable} from "src/vendor/layerzero-upgradeable/oapp/OAppUpgradeable.sol";
import {MessagingFee, MessagingReceipt} from "src/vendor/layerzero-upgradeable/oapp/OAppSenderUpgradeable.sol";
import {OAppOptionsType3Upgradeable} from "src/vendor/layerzero-upgradeable/oapp/libs/OAppOptionsType3Upgradeable.sol";
import {Origin} from "src/vendor/layerzero-upgradeable/oapp/interfaces/IOAppReceiver.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MsgCodec} from "src/layer2/libraries/MsgCodec.sol";
import {Constants} from "./libraries/Constants.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title  LiquidStakingTokenLockbox
 * @notice An OApp contract for handling LiquidStakingToken operations between mainnet and L2.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the L2 system.
 * @author redactedcartel.finance
 */
contract LiquidStakingTokenLockboxCompose is
    L1SyncPool,
    OAppUpgradeable,
    OAppOptionsType3Upgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    /**
     * @dev Library: SafeERC20 - Provides safe transfer functions for ERC20 tokens.
     */
    using SafeERC20 for IERC20;

    /**
     * @dev Library: FixedPointMathLib - Provides fixed-point arithmetic for uint256.
     */
    using FixedPointMathLib for uint256;

    /**
     * @dev Library: MsgCodec - Provides encoding and decoding of messages.
     */
    using MsgCodec for bytes;

    /**
     * @notice The destination endpoint ID for L2.
     * @dev This constant defines the destination endpoint ID for the L2.
     */
    uint32 internal immutable L2_EID;

    /// @custom:storage-location erc7201:redacted.storage.LiquidStakingTokenLockbox
    struct LockboxStorage {
        /**
         * @notice The autoPxEth vault that holds the assets.
         * @dev This variable holds the address of the autoPxEth contract instance.
         */
        IAutoPxEth autoPxEth;
        /**
         * @notice The average exchange rate between the share apxEth and pxEth.
         * @dev This constant defines the exchange rate between the share apxEth and pxEth, used for accounting rewards accrued.
         */
        uint256 avgAssetsPerShare;
        /**
         * @notice The total shares in the vault.
         * @dev This variable holds the total shares in the vault.
         */
        uint256 totalShares;
        /**
         * @notice The pending deposit amount.
         * @dev This variable holds the amount received from L1SyncPool that has not been deposited into the vault.
         */
        uint256 pendingDeposit;
        /**
         * @dev the maximum number of synced Ids to be sent in a single message.
         * @dev This variable holds the maximum number of synced Ids to be sent in a single message to avoid out of gas.
         */
        uint256 maxSyncedIdBatch;
        /**
         * @notice The nonce for the received messages.
         * @dev Mapping to track the maximum received nonce for each source endpoint and sender
         */
        mapping(uint32 eid => mapping(bytes32 sender => uint64 nonce)) receivedNonce;
        /**
         * @notice The whitelisted destination chains.
         * @dev This variable holds the whitelisted destination chains for deposits.
         */
        mapping(uint32 => bool) dstChainStatus;
        /**
         * @notice The array of synced IDs pending finalization on L2.
         * @dev This variable holds the array of synced IDs which the finalization msg
         * has been received from the native bridge but it's pending finalization on L2.
         */
        bytes32[] syncedIds;
        /**
         * @notice The index of the first synced ID in the syncedIds array.
         * @dev This variable holds the index of the first synced ID in the syncedIds array
         * to avoid iterating over the entire array on each deposit. It is updated on rebases and deposits.
         */
        uint256 firstSyncedIdIndex;
        /**
         * @notice Mapping to track the accounts that can pause the contract.
         * @dev This mapping holds the accounts that can pause the contract.
         */
        mapping(address => bool) canPause;
    }

    // keccak256(abi.encode(uint256(keccak256(redacted.storage.LiquidStakingTokenLockboxCompose)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant LockboxStorageLocation =
        0xa29f8a00fbc93ddce1e4d2ba354008f1eca37e7e6f8abe05b23f82782b089900;

    function _getLockboxStorage()
        private
        pure
        returns (LockboxStorage storage $)
    {
        assembly {
            $.slot := LockboxStorageLocation
        }
    }

    /**
     * @notice Emitted on sending deposit message.
     * @dev    Origin token address is set to address(0) for native (ETH) deposit
     * @param  dstEid           uint32   The destination endpoint ID for L2.
     * @param  guid             bytes32  GUID of the OFT message.
     * @param  fromAddress      address  Address of the sender on the src chain.
     * @param  toAddress        address  Address of the recipient on the src chain.
     * @param  originToken      address  Origin token address used for deposit
     * @param  amount           uint256  Deposit amount (in pxEth).
     * @param  assetsPerShare   uint256  The assetsPerShare at the time of deposit.
     */
    event Deposit(
        uint32 dstEid,
        bytes32 indexed guid,
        address indexed fromAddress,
        address indexed toAddress,
        address originToken,
        uint256 amount,
        uint256 assetsPerShare
    );

    /**
     * @notice Emitted on sending rebase message.
     * @param  guid             bytes32  GUID of the OFT message.
     * @param  caller           address  Address of the rebase caller.
     * @param  amount           uint256  Total rewards accrued value.
     * @param  assetsPerShare   uint256  The assetsPerShare at the time of rebase.
     */
    event Rebase(
        bytes32 indexed guid,
        address indexed caller,
        uint256 amount,
        uint256 assetsPerShare
    );

    /**
     * @notice Emitted on receiving and processing withdrawal message.
     * @param  guid       bytes32  GUID of the OFT message.
     * @param  toAddress  address  Address of the recipient on the src chain.
     * @param  amount     uint256  Withdrawal amount (in pxEth).
     */
    event Withdrawal(
        bytes32 indexed guid,
        address indexed toAddress,
        uint256 amount
    );

    /**
     * @notice Emitted on deposits received from the sync pool.
     * @param  guid             bytes32  GUID of the sync message.
     * @param  syncAmount       uint256  Original sync amount (in pxEth).
     * @param  depositedAmount  uint256  Deposited amount (in pxEth).
     */
    event FinalizeSync(
        bytes32 guid,
        uint256 syncAmount,
        uint256 depositedAmount
    );

    /**
     * @notice Emitted on withdrawals sent to the sync pool.
     * @param  amount   uint256  Withdrawal amount (in pxEth).
     */
    event WithdrawalSync(uint256 amount);

    /**
     * @notice Emitted when destionation chain status is set.
     * @param  dstChainId  uint32  The destination chain ID.
     * @param  status      bool    The status of the destination chain.
     */
    event DstChainSet(uint32 dstChainId, bool status);

    /**
     * @notice Emitted when the pause is set.
     * @param  account  address  The account that can pause the contract.
     * @param  allowed  bool     The allowed status.
     */
    event canPauseSet(address indexed account, bool allowed);

    /**
     * @notice Contract constructor to initialize LiquidStakingTokenVault with necessary parameters and configurations.
     * @dev    This constructor sets up the LiquidStakingTokenVault contract, configuring key parameters and initializing state variables.
     * @param  _endpoint   address  The address of the LOCAL LayerZero endpoint.
     * @param  _dstEid     uint32   The destination endpoint ID for L2.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _endpoint, uint32 _dstEid) OAppUpgradeable(_endpoint) {
        L2_EID = _dstEid;
        _disableInitializers();
    }

    /**
     * @dev modifier to allow only the owner or the canPause address to pause the contract
     */
    modifier onlyCanPause() {
        if (!_canPause(_msgSender())) revert Errors.NotAllowed();
        _;
    }

    /**
     * @notice LiquidStakingTokenVault initializer with necessary parameters and configurations.
     * @dev    This initializer sets up the LiquidStakingTokenVault contract, configuring key parameters and initializing state variables.
     * @param  _owner      address The owner of the contract.
     * @param  _delegate   address  The delegate capable of making OApp configurations inside of the endpoint.
     * @param  _pirexEth   address  PirexEth contract address.
     * @param  _autoPxEth  address  AutoPxEth contract address.
     */
    function initialize(
        address _delegate,
        address _owner,
        address _pirexEth,
        address _pxEth,
        address _autoPxEth,
        uint256 _maxSyncedIdBatch
    ) external initializer {
        if (_pirexEth == address(0)) revert Errors.ZeroAddress();
        if (_pxEth == address(0)) revert Errors.ZeroAddress();
        if (_autoPxEth == address(0)) revert Errors.ZeroAddress();

        __L1BaseSyncPool_init(_pirexEth, _pxEth);
        __LiquidStakingTokenLockbox_init(
            _delegate,
            _owner,
            _autoPxEth,
            _maxSyncedIdBatch
        );
    }

    function __LiquidStakingTokenLockbox_init(
        address _delegate,
        address _owner,
        address _autoPxEth,
        uint256 _maxSyncedIdBatch
    ) internal onlyInitializing {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init(_owner);
        __OAppCore_init(_delegate);
        __LiquidStakingTokenLockbox_init_unchained(
            _autoPxEth,
            _maxSyncedIdBatch
        );
    }

    function __LiquidStakingTokenLockbox_init_unchained(
        address _autoPxEth,
        uint256 _maxSyncedIdBatch
    ) internal {
        LockboxStorage storage $ = _getLockboxStorage();

        _setMaxSyncedIdBatch(_maxSyncedIdBatch);

        $.autoPxEth = IAutoPxEth(_autoPxEth);

        IERC20(getTokenOut()).approve(address($.autoPxEth), type(uint256).max);
    }

    /**
     * @notice Handler for processing layerzero messages from L2.
     * @dev    Only accept and handle the withdrawal message from L2, which then perform withdrawal from autoPxEth into pxEth.
     * @dev    _origin   Origin   The origin information containing the source endpoint and sender address.
     * @dev    _guid     bytes32  The unique identifier for the received LayerZero message.
     * @param  _message  bytes    The payload of the received message.
     * @dev              address  The address of the executor for the received message.
     * @dev              bytes    Additional arbitrary data provided by the corresponding executor.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override nonReentrant {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);

        LockboxStorage storage $ = _getLockboxStorage();

        uint8 _messageType = _message.messageType();

        if (_messageType == Constants.MESSAGE_TYPE_SYNC) {
            (address _token, uint256 _amountIn, uint256 _amountOut) = _message
                .decodeSync();

            _anticipatedDeposit(_guid, _token, _amountIn, _amountOut);

            return;
        }

        if (_messageType != Constants.MESSAGE_TYPE_WITHDRAW)
            revert Errors.NotAllowed();

        (uint256 _amount, address _receiver) = _message.decodeWithdraw();

        // Withdraw from pendingDeposit first
        uint256 pendingAmount = $.pendingDeposit;

        if (pendingAmount > 0) {
            if (pendingAmount >= _amount) {
                $.pendingDeposit -= _amount;

                getTokenOut().safeTransfer(_receiver, _amount);

                emit Withdrawal(_guid, _receiver, _amount);

                return;
            }

            getTokenOut().safeTransfer(_receiver, pendingAmount);

            $.pendingDeposit = 0;
        }

        // Adjust withdrawal amount based on the withdrawalPenalty
        // and the current assets in the vault
        uint256 postFeeAmount = _calculateWithdrawalAmount(
            _amount - pendingAmount
        );

        IAutoPxEth autoPxEth = $.autoPxEth;

        uint256 preBalance = autoPxEth.balanceOf(address(this));

        autoPxEth.withdraw(postFeeAmount, _receiver, address(this));

        $.totalShares -= preBalance - autoPxEth.balanceOf(address(this));

        emit Withdrawal(_guid, _receiver, pendingAmount + postFeeAmount);
    }

    /**
     * @notice Perform deposit via AutoPxEth and then relaying the message to L2.
     * @dev    Accept pxEth deposits and then mint apxEth to be stored in the vault as well as sending message to L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount.
     * @param _shouldWrap bool     Whether to wrap rebase token on destination chain.
     * @param  _options   bytes    Additional options for the message.
     */
    function depositEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable virtual nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handleEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _send(
            _encodeDeposit(amount, assetsPerShare, _receiver, _shouldWrap),
            "",
            combineOptions(_dstEid, 0, _options),
            msg.value - _amount,
            _refundAddress
        );

        emit Deposit(
            L2_EID,
            receipt,
            msg.sender,
            _receiver,
            address(0),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Perform deposit via PxEth and then relaying the message to L2.
     * @dev    Accept pxEth deposits and then mint apxEth to be stored in the vault as well as sending message to L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount.
     * @param _shouldWrap bool     Whether to wrap rebase token on destination chain.
     * @param  _options   bytes    Additional options for the message.
     */
    function depositPxEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable virtual nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handlePxEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _send(
            _encodeDeposit(amount, assetsPerShare, _receiver, _shouldWrap),
            "",
            combineOptions(_dstEid, 0, _options),
            msg.value,
            _refundAddress
        );

        emit Deposit(
            L2_EID,
            receipt,
            msg.sender,
            _receiver,
            address(getTokenOut()),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Perform deposit via ApxETH and then relaying the message to L2.
     * @dev    Accept apxEth deposits to be stored in the vault as well as sending message to L2.
     * @param  _dstEid    uint32   The destination endpoint ID for L2.
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _amount    uint256  Deposit amount (in shares).
     * @param  _options   bytes    Additional options for the message.
     */
    function depositApxEth(
        uint32 _dstEid,
        address _receiver,
        address _refundAddress,
        uint256 _amount,
        bool _shouldWrap,
        bytes calldata _options
    ) external payable virtual nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert Errors.ZeroAddress();
        if (_refundAddress == address(0)) revert Errors.ZeroAddress();

        (uint256 assetsPerShare, uint256 amount) = _handleApxEthDeposit(
            _dstEid,
            _amount
        );

        bytes32 receipt = _send(
            _encodeDeposit(amount, assetsPerShare, _receiver, _shouldWrap),
            "",
            combineOptions(_dstEid, 0, _options),
            msg.value,
            _refundAddress
        );

        emit Deposit(
            L2_EID,
            receipt,
            msg.sender,
            _receiver,
            address(_getLockboxStorage().autoPxEth),
            amount,
            assetsPerShare
        );
    }

    /**
     * @notice Perform rebase on L2
     * @dev    Calculate rebase rate based on latest assetsPerShare and accrue treasury fee.
     * @param  _refundAddress The address to receive any excess funds sent to layer zero.
     * @param  _options  bytes   Additional options for the message.
     */
    function rebase(
        address _refundAddress,
        bytes calldata _options
    ) external payable nonReentrant whenNotPaused {
        LockboxStorage storage $ = _getLockboxStorage();

        uint256 assetsPerShare = $.autoPxEth.convertToAssets(1e18);

        uint256 assetsIncrease = assetsPerShare - $.avgAssetsPerShare;

        if (assetsIncrease == 0) revert Errors.InvalidAmount();

        // amount increased by pxEth rewards accrued
        uint256 amount = assetsIncrease.mulDivDown($.totalShares, 1e18);

        if (amount == 0) revert Errors.InvalidAmount();

        bytes memory combinedOptions = combineOptions(L2_EID, 0, _options);

        $.avgAssetsPerShare = assetsPerShare;

        MessagingReceipt memory msgReceipt = _lzSend(
            L2_EID,
            MsgCodec.encode(
                abi.encode(
                    Constants.MESSAGE_TYPE_REBASE,
                    amount,
                    assetsPerShare,
                    address(0),
                    _syncedIdsBatchUpdate()
                ),
                ""
            ),
            combinedOptions,
            MessagingFee(msg.value, 0),
            payable(_refundAddress)
        );

        emit Rebase(msgReceipt.guid, msg.sender, amount, assetsPerShare);
    }

    /**
     * @dev Handler for processing ETH deposits to the lockbox.
     * @param _dstEid Destination endpoint ID.
     * @param _amount Amount of pxETH to be deposited.
     * @return assetsPerShare The assets per share value at the time of deposit.
     * @return amount The amount of assets deposited.
     */
    function _handleEthDeposit(
        uint32 _dstEid,
        uint256 _amount
    ) internal returns (uint256 assetsPerShare, uint256 amount) {
        if (_amount == 0) revert Errors.ZeroAmount();
        // msg.value includes layerzero fees so the exact deposit amount must be specified
        if (msg.value <= _amount) revert Errors.InvalidAmount();

        LockboxStorage storage $ = _getLockboxStorage();

        if (!$.dstChainStatus[_dstEid]) {
            revert Errors.UnsupportedEid();
        }

        IAutoPxEth autoPxEth = $.autoPxEth;

        uint256 preBalance = autoPxEth.balanceOf(address(this));

        // Deposit via PirexEth and receive apxEth in return to be kept in this vault
        (amount, ) = IPirexEth(getPlatform()).deposit{value: _amount}(
            address(this),
            true
        );

        uint256 shares = autoPxEth.balanceOf(address(this)) - preBalance;

        $.totalShares += shares;

        assetsPerShare = autoPxEth.convertToAssets(1e18);

        _updateAverageAssetsPerShare(shares, assetsPerShare);
    }

    /**
     * @dev Handler for processing pxETH deposits to the lockbox.
     * @param _dstEid Destination endpoint ID.
     * @param _amount Amount of pxETH to be deposited.
     * @return assetsPerShare The assets per share value at the time of deposit.
     * @return amount The amount of assets deposited.
     */
    function _handlePxEthDeposit(
        uint32 _dstEid,
        uint256 _amount
    ) internal returns (uint256 assetsPerShare, uint256 amount) {
        if (_amount == 0) revert Errors.ZeroAmount();

        LockboxStorage storage $ = _getLockboxStorage();

        if (!$.dstChainStatus[_dstEid]) {
            revert Errors.UnsupportedEid();
        }

        IAutoPxEth autoPxEth = $.autoPxEth;
        IERC20 pxEth = getTokenOut();

        pxEth.safeTransferFrom(msg.sender, address(this), _amount);

        // Deposit via PirexEth and receive apxEth in return to be kept in this vault
        uint256 shares = autoPxEth.deposit(_amount, address(this));
        amount = autoPxEth.convertToAssets(shares);

        $.totalShares += shares;

        assetsPerShare = autoPxEth.convertToAssets(1e18);

        _updateAverageAssetsPerShare(shares, assetsPerShare);
    }

    /**
     * @dev Handler for processing apxETH deposits to the lockbox.
     * @param _dstEid Destination endpoint ID.
     * @param _amount Amount of apxETH to be deposited.
     * @return assetsPerShare The assets per share value at the time of deposit.
     * @return amount The amount of assets deposited.
     */
    function _handleApxEthDeposit(
        uint32 _dstEid,
        uint256 _amount
    ) internal returns (uint256 assetsPerShare, uint256 amount) {
        if (_amount == 0) revert Errors.ZeroAmount();

        LockboxStorage storage $ = _getLockboxStorage();

        if (!$.dstChainStatus[_dstEid]) {
            revert Errors.UnsupportedEid();
        }

        IAutoPxEth autoPxEth = $.autoPxEth;

        IERC20(address(autoPxEth)).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        amount = autoPxEth.convertToAssets(_amount);

        $.totalShares += _amount;

        assetsPerShare = autoPxEth.convertToAssets(1e18);

        _updateAverageAssetsPerShare(_amount, assetsPerShare);
    }

    /**
     * @notice Perform deposit apxEth from the sync pool.
     * @dev     Accept apxEth deposits to be stored in the vault.
     * @param  _syncId          bytes32  The sync ID of the deposit.
     * @param  _amount          uint256  Deposit amount (in apxEth).
     */
    function _handleFinalizeDeposit(
        bytes32 _syncId,
        uint256 _amount
    ) internal override nonReentrant {
        LockboxStorage storage $ = _getLockboxStorage();

        uint256 amount;
        if ($.pendingDeposit > 0) {
            IAutoPxEth autoPxEth = $.autoPxEth;

            amount = _amount > $.pendingDeposit ? $.pendingDeposit : _amount;

            $.pendingDeposit -= amount;

            uint256 shares = autoPxEth.deposit(amount, address(this));

            $.totalShares += shares;

            _updateAverageAssetsPerShare(
                shares,
                autoPxEth.convertToAssets(1e18)
            );
        }

        emit FinalizeSync(_syncId, _amount, amount);

        $.syncedIds.push(_syncId);
    }

    /**
     * @notice Set the destination chain status.
     * @param dstChainId The destination chain ID.
     * @param status The status of the destination chain.
     */
    function setDstChain(uint32 dstChainId, bool status) external onlyOwner {
        _getLockboxStorage().dstChainStatus[dstChainId] = status;

        emit DstChainSet(dstChainId, status);
    }

    /**
     * @notice Set the maximum number of synced Ids to be sent in a single message.
     * @param _maxSyncedIdBatch The maximum number of synced Ids to be sent in a single message.
     */
    function setMaxSyncedIdBatch(uint256 _maxSyncedIdBatch) external onlyOwner {
        _setMaxSyncedIdBatch(_maxSyncedIdBatch);
    }

    /**
     * @notice Set the maximum number of synced Ids to be sent in a single message.
     * @param _maxSyncedIdBatch The maximum number of synced Ids to be sent in a single message.
     */
    function _setMaxSyncedIdBatch(uint256 _maxSyncedIdBatch) internal {
        if (_maxSyncedIdBatch == 0) revert Errors.InvalidAmount();

        _getLockboxStorage().maxSyncedIdBatch = _maxSyncedIdBatch;
    }

    /**
     * @notice Set the last received nonce for the specified source endpoint and sender.
     * @dev this should be used to fix the nonce if there's a problem in the execution of a particular message.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be set.
     */
    function setNonce(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    ) external onlyOwner {
        _getLockboxStorage().receivedNonce[_srcEid][_sender] = _nonce;
    }

    /**
     * @notice Get the destination chain status.
     * @param _dstEid The destination endpoint ID.
     * @return bool The status of the destination chain.
     */
    function getDestionationEidStatus(
        uint32 _dstEid
    ) external view returns (bool) {
        return _getLockboxStorage().dstChainStatus[_dstEid];
    }

    /**
     * @dev Public function to get the next expected nonce for a given source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @return uint64 Next expected nonce.
     */
    function nextNonce(
        uint32 _srcEid,
        bytes32 _sender
    ) public view override returns (uint64) {
        return _getLockboxStorage().receivedNonce[_srcEid][_sender] + 1;
    }

    /**
     * @dev Internal function to accept nonce from the specified source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be accepted.
     */
    function _acceptNonce(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    ) internal {
        LockboxStorage storage $ = _getLockboxStorage();

        if (_nonce != $.receivedNonce[_srcEid][_sender] + 1)
            revert Errors.InvalidNonce();

        $.receivedNonce[_srcEid][_sender] += 1;
    }

    /**
     * @notice Internal function to set the canPause address.
     * @param _address the address to check if it can pause the contract.
     */
    function _canPause(address _address) internal view returns (bool) {
        return _getLockboxStorage().canPause[_address] || _address == owner();
    }

    /**
     * @notice Function to set the canPause address.
     * @param _address the address to check if it can pause the contract.
     */
    function setCanPause(address _address, bool _allowed) external onlyOwner {
        _getLockboxStorage().canPause[_address] = _allowed;
    }

    /**
     * @notice Check if an address can pause the contract.
     * @param _address the address to check if it can pause the contract.
     */
    function canPause(address _address) external view returns (bool) {
        return _canPause(_address);
    }

    /**
     * @notice Pause deposit and rebase operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause deposit and rebase operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Quote gas cost for deposit messages
     * @param  _receiver  address  The recipient of the deposit in L2.
     * @param  _amount    uint256  Deposit amount.
     * @param  _options   bytes    Additional options for the message.
     */
    function quoteDeposit(
        address _receiver,
        uint256 _amount,
        bytes calldata _options
    ) external view returns (MessagingFee memory msgFee) {
        LockboxStorage storage $ = _getLockboxStorage();

        return
            _quote(
                L2_EID,
                MsgCodec.encode(
                    abi.encode(
                        Constants.MESSAGE_TYPE_DEPOSIT,
                        _amount, // Use amount directly for quote
                        $.autoPxEth.convertToAssets(1e18),
                        _receiver,
                        _syncedIdsBatch()
                    ),
                    ""
                ),
                combineOptions(L2_EID, 0, _options),
                false
            );
    }

    /**
     * @notice Quote gas cost for rebase message
     * @param  _options   bytes   Additional options for the message.
     */
    function quoteRebase(
        bytes calldata _options
    ) external view returns (MessagingFee memory msgFee) {
        LockboxStorage storage $ = _getLockboxStorage();

        return
            _quote(
                L2_EID,
                MsgCodec.encode(
                    abi.encode(
                        Constants.MESSAGE_TYPE_REBASE,
                        1e18, // Use 1e18 as placeholder for quote
                        $.autoPxEth.convertToAssets(1e18),
                        address(0),
                        _syncedIdsBatch()
                    ),
                    ""
                ),
                combineOptions(L2_EID, 0, _options),
                false
            );
    }

    /**
     * @notice AutoPxEth contract address.
     */
    function getAutoPxEth() external view returns (address) {
        return address(_getLockboxStorage().autoPxEth);
    }

    /**
     * @notice The pending deposit amount.
     */
    function pendingDeposit() external view returns (uint256) {
        return _getLockboxStorage().pendingDeposit;
    }

    /**
     * @notice The average exchange rate between the share apxEth and pxEth, used for calculating the fee.
     */
    function averageAssetsPerShare() external view returns (uint256) {
        return _getLockboxStorage().avgAssetsPerShare;
    }

    /**
     * @notice The total shares in the vault.
     */
    function totalShares() external view returns (uint256) {
        return _getLockboxStorage().totalShares;
    }

    /**
     * @notice All finalized sync IDs.
     */
    function syncedIds() external view returns (bytes32[] memory) {
        return _getLockboxStorage().syncedIds;
    }

    /**
     * @notice All finalized sync Ids pending to be sent to L2.
     * @param  batchLimit  bool  Whether to limit the batch size.
     */
    function syncedIdsPending(
        bool batchLimit
    ) external view returns (bytes32[] memory) {
        LockboxStorage storage $ = _getLockboxStorage();

        uint256 firstSyncedIdIndex = $.firstSyncedIdIndex;
        uint256 syncedIdsLen = $.syncedIds.length - firstSyncedIdIndex;

        if (syncedIdsLen == 0) return new bytes32[](0);

        uint256 size = syncedIdsLen;
        if (batchLimit) {
            uint256 maxBatch = $.maxSyncedIdBatch;
            size = syncedIdsLen > maxBatch ? maxBatch : syncedIdsLen;
        }

        bytes32[] memory idsPending = new bytes32[](size);

        for (uint256 i; i < size; i++) {
            idsPending[i] = $.syncedIds[firstSyncedIdIndex + i];
        }

        return idsPending;
    }

    /**
     * @notice The maximum number of synced Ids to be sent in a single message.
     */
    function maxSyncedIdBatch() external view returns (uint256) {
        return _getLockboxStorage().maxSyncedIdBatch;
    }

    /**
     * @dev    Adjusts the withdrawal amount based on the withdrawalPenalty and the current assets in the vault.
     * @param  _amount uint256  The LiquidStakingToken amount to withdraw.
     * @return uint256 The amount to withdraw.
     */
    function _calculateWithdrawalAmount(
        uint256 _amount
    ) internal view returns (uint256) {
        LockboxStorage storage $ = _getLockboxStorage();

        IAutoPxEth autoPxEth = $.autoPxEth;

        uint256 withdrawalPenalty = autoPxEth.withdrawalPenalty();

        uint256 penalty = _amount.mulDivUp(
            withdrawalPenalty,
            Constants.FEE_DENOMINATOR
        );

        uint256 previewRedeem = _amount - penalty;

        uint256 totalAssets = autoPxEth.previewRedeem(
            autoPxEth.balanceOf(address(this))
        );

        return previewRedeem > totalAssets ? totalAssets : previewRedeem;
    }

    /**
     * @dev Update avgAssetsPerShare proportional to newly deposited assets.
     * @param  _newShares                uint256  The new shares to added.
     * @param  _currentAssetsPerShare    uint256  The current assetsPerShare in autoPxEth.
     */
    function _updateAverageAssetsPerShare(
        uint256 _newShares,
        uint256 _currentAssetsPerShare
    ) internal {
        LockboxStorage storage $ = _getLockboxStorage();

        uint256 sharesBalance = $.totalShares;
        uint256 preDepositShares = sharesBalance - _newShares;
        uint256 assetsPerShare = $.avgAssetsPerShare;

        $.avgAssetsPerShare =
            ((assetsPerShare * preDepositShares) +
                (_currentAssetsPerShare * _newShares)) /
            sharesBalance;
    }

    /**
     * @dev Internal function to encode deposit message.
     * @param  _amount          uint256  Deposit amount.
     * @param  _assetsPerShare  uint256  The assetsPerShare at the time of deposit.
     * @param  _receiver        address  The recipient of the deposit in the L2.
     * @param  _shouldWrap      bool     Whether to wrap rebase token on destination chain.
     * @return depositMsg       bytes    The encoded deposit message.
     */
    function _encodeDeposit(
        uint256 _amount,
        uint256 _assetsPerShare,
        address _receiver,
        bool _shouldWrap
    ) internal returns (bytes memory depositMsg) {
        depositMsg = abi.encode(
            _shouldWrap
                ? Constants.MESSAGE_TYPE_DEPOSIT_WRAP
                : Constants.MESSAGE_TYPE_DEPOSIT,
            _amount,
            _assetsPerShare,
            _receiver,
            _syncedIdsBatchUpdate()
        );
    }

    /**
     * @dev Internal function to encode payload msg and send to L2.
     * @param _msg          bytes   encoded of the message to be processed on LiquidStakingToken.
     * @param _composeMsg   bytes   encoded of the message to be processed on the compose receiver L2.
     * @param _options      bytes   encoded bytes for the lz extra options.
     * @return guid         bytes32 The unique identifier of the sent message.
     */
    function _send(
        bytes memory _msg,
        bytes memory _composeMsg,
        bytes memory _options,
        uint256 _nativeFee,
        address _refundAddress
    ) internal returns (bytes32 guid) {
        guid = _lzSend(
            L2_EID,
            MsgCodec.encode(_msg, _composeMsg),
            _options,
            MessagingFee(_nativeFee, 0),
            payable(_refundAddress)
        ).guid;
    }

    /**
     * @dev Internal function to pay the native fee associated with the message.
     * @param _nativeFee The native fee to be paid.
     * @return nativeFee The amount of native currency paid.
     *
     * @dev This function is overridden to handle the native fee payment for the depositEth.
     */
    function _payNative(
        uint256 _nativeFee
    ) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }

    /**
     * @dev internal function to get the next batch of synced IDs to be sent to L2
     *      and update the sync queue.
     */
    function _syncedIdsBatchUpdate() internal returns (bytes32[] memory) {
        bytes32[] memory syncedIdsBatch = _syncedIdsBatch();

        _getLockboxStorage().firstSyncedIdIndex += syncedIdsBatch.length;

        return syncedIdsBatch;
    }

    /**
     * @dev internal function to get the next batch of synced IDs to be sent to L2.
     */
    function _syncedIdsBatch() internal view returns (bytes32[] memory) {
        LockboxStorage storage $ = _getLockboxStorage();

        // finalized synced ids not yet sent to L2
        uint256 firstSyncedIdIndex = $.firstSyncedIdIndex;
        uint256 syncedIdsLen = $.syncedIds.length - firstSyncedIdIndex;

        if (syncedIdsLen == 0) return new bytes32[](0);

        uint256 maxBatch = $.maxSyncedIdBatch;
        uint256 size = syncedIdsLen > maxBatch ? maxBatch : syncedIdsLen;

        bytes32[] memory syncedIdsBatch = new bytes32[](size);

        for (uint256 i; i < size; i++) {
            syncedIdsBatch[i] = $.syncedIds[firstSyncedIdIndex + i];
        }

        return syncedIdsBatch;
    }

    /**
     * @inheritdoc L1SyncPool
     */
    function _anticipatedDeposit(
        bytes32 guid,
        address token,
        uint256 amountIn,
        uint256 amountOut
    ) internal override returns (uint256 amount) {
        LockboxStorage storage $ = _getLockboxStorage();

        amount = super._anticipatedDeposit(guid, token, amountIn, amountOut);

        $.pendingDeposit += amount;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { MessagingParams, MessagingFee, MessagingReceipt } from "src/vendor/layerzero/protocol/interfaces/ILayerZeroEndpointV2.sol";
import { OAppCoreUpgradeable } from "./OAppCoreUpgradeable.sol";

/**
 * @title OAppSender
 * @dev Abstract contract implementing the OAppSender functionality for sending messages to a LayerZero endpoint.
 */
abstract contract OAppSenderUpgradeable is OAppCoreUpgradeable {
    using SafeERC20 for IERC20;

    // Custom error messages
    error NotEnoughNative(uint256 msgValue);
    error LzTokenUnavailable();

    // @dev The version of the OAppSender implementation.
    // @dev Version is bumped when changes are made to this contract.
    uint64 internal constant SENDER_VERSION = 1;

    /**
     * @dev Ownable is not initialized here on purpose. It should be initialized in the child contract to
     * accommodate the different version of Ownable.
     */
    function __OAppSender_init() internal onlyInitializing {}

    function __OAppSender_init_unchained() internal onlyInitializing {}

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol contract.
     * @return receiverVersion The version of the OAppReceiver.sol contract.
     *
     * @dev Providing 0 as the default for OAppReceiver version. Indicates that the OAppReceiver is not implemented.
     * ie. this is a SEND only OApp.
     * @dev If the OApp uses both OAppSender and OAppReceiver, then this needs to be override returning the correct versions
     */
    function oAppVersion() public view virtual returns (uint64 senderVersion, uint64 receiverVersion) {
        return (SENDER_VERSION, 0);
    }

    /**
     * @dev Internal function to interact with the LayerZero EndpointV2.quote() for fee calculation.
     * @param _dstEid The destination endpoint ID.
     * @param _message The message payload.
     * @param _options Additional options for the message.
     * @param _payInLzToken Flag indicating whether to pay the fee in LZ tokens.
     * @return fee The calculated MessagingFee for the message.
     *      - nativeFee: The native fee for the message.
     *      - lzTokenFee: The LZ token fee for the message.
     */
    function _quote(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) internal view virtual returns (MessagingFee memory fee) {
        return
            endpoint.quote(
                MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _payInLzToken),
                address(this)
            );
    }

    /**
     * @dev Internal function to interact with the LayerZero EndpointV2.send() for sending a message.
     * @param _dstEid The destination endpoint ID.
     * @param _message The message payload.
     * @param _options Additional options for the message.
     * @param _fee The calculated LayerZero fee for the message.
     *      - nativeFee: The native fee.
     *      - lzTokenFee: The lzToken fee.
     * @param _refundAddress The address to receive any excess fee values sent to the endpoint.
     * @return receipt The receipt for the sent message.
     *      - guid: The unique identifier for the sent message.
     *      - nonce: The nonce of the sent message.
     *      - fee: The LayerZero fee incurred for the message.
     */
    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal virtual returns (MessagingReceipt memory receipt) {
        // @dev Push corresponding fees to the endpoint, any excess is sent back to the _refundAddress from the endpoint.
        uint256 messageValue = _payNative(_fee.nativeFee);
        if (_fee.lzTokenFee > 0) _payLzToken(_fee.lzTokenFee);

        return
            endpoint.send{ value: messageValue }(
            // solhint-disable-next-line check-send-result
                MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, _fee.lzTokenFee > 0),
                _refundAddress
            );
    }

    /**
     * @dev Internal function to pay the native fee associated with the message.
     * @param _nativeFee The native fee to be paid.
     * @return nativeFee The amount of native currency paid.
     *
     * @dev If the OApp needs to initiate MULTIPLE LayerZero messages in a single transaction,
     * this will need to be overridden because msg.value would contain multiple lzFees.
     * @dev Should be overridden in the event the LayerZero endpoint requires a different native currency.
     * @dev Some EVMs use an ERC20 as a method for paying transactions/gasFees.
     * @dev The endpoint is EITHER/OR, ie. it will NOT support both types of native payment at a time.
     */
    function _payNative(uint256 _nativeFee) internal virtual returns (uint256 nativeFee) {
        if (msg.value != _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }

    /**
     * @dev Internal function to pay the LZ token fee associated with the message.
     * @param _lzTokenFee The LZ token fee to be paid.
     *
     * @dev If the caller is trying to pay in the specified lzToken, then the lzTokenFee is passed to the endpoint.
     * @dev Any excess sent, is passed back to the specified _refundAddress in the _lzSend().
     */
    function _payLzToken(uint256 _lzTokenFee) internal virtual {
        // @dev Cannot cache the token because it is not immutable in the endpoint.
        address lzToken = endpoint.lzToken();
        if (lzToken == address(0)) revert LzTokenUnavailable();

        // Pay LZ token fee by sending tokens to the endpoint.
        IERC20(lzToken).safeTransferFrom(msg.sender, address(endpoint), _lzTokenFee);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library MsgCodec {
    // Offset constants for decoding messages
    uint256 private constant MESSAGE_TYPE_OFFSET = 32;
    uint256 private constant COMPOSE_TYPE_OFFSET = 64;
    uint256 private constant COMPOSE_RECEIVER_OFFSET = 32;

    /**
     * @dev Retrieves the message type from the message.
     * @param _msg The message.
     * @return The message type.
     */
    function messageType(bytes calldata _msg) internal pure returns (uint8) {
        return abi.decode(_msg[:MESSAGE_TYPE_OFFSET], (uint8));
    }

    /**
     * @dev Retrieve the relavant parameters from the message.
     * @param _msg The message.
     * @return msgType The message type.
     * @return amount The amount.
     * @return assetsPerShare The assets per share.
     * @return receiver The token receiver.
     * @return syncedIds The synced IDs.
     */
    function decodeL1Msg(
        bytes calldata _msg
    )
        internal
        pure
        returns (
            uint8 msgType,
            uint256 amount,
            uint256 assetsPerShare,
            address receiver,
            bytes32[] memory syncedIds
        )
    {
        (, uint256 composeMsgLen) = isComposed(_msg);

        (msgType, amount, assetsPerShare, receiver, syncedIds) = abi.decode(
            _msg[COMPOSE_TYPE_OFFSET:_msg.length - composeMsgLen],
            (uint8, uint256, uint256, address, bytes32[])
        );
    }

    /**
     * @dev Retrieve the relavant parameters from the sync message.
     * @param _msg The message.
     * @return token The deposited token.
     * @return amountIn The amount in.
     * @return amountOut The amount out.
     */
    function decodeSync(
        bytes calldata _msg
    )
        internal
        pure
        returns (address token, uint256 amountIn, uint256 amountOut)
    {
        (token, amountIn, amountOut) = abi.decode(
            _msg[MESSAGE_TYPE_OFFSET:],
            (address, uint256, uint256)
        );
    }

    /**
     * @dev Retrieve the relavant parameters from the withdraw message.
     * @param _msg The message.
     * @return amount The amount.
     * @return receiver The receiver address.
     */
    function decodeWithdraw(
        bytes calldata _msg
    ) internal pure returns (uint256 amount, address receiver) {
        (amount, receiver) = abi.decode(
            _msg[MESSAGE_TYPE_OFFSET:],
            (uint256, address)
        );
    }

    /**
     * @dev Retrieve the compose message.
     * @param _payload The LayerZero msg payload.
     * @return The compose message.
     */
    function composeMsg(
        bytes calldata _payload
    ) internal pure returns (bytes memory) {
        (bool composed, uint256 composeMsgLen) = isComposed(_payload);
        uint256 payloadLen = _payload.length;

        return composed ? 
            _payload[COMPOSE_RECEIVER_OFFSET + payloadLen - composeMsgLen:]
            : new bytes(0);
    }

    /**
     * @dev Check if the message is composed.
     * @param _payload The LayerZero msg payload.
     * @return Boolean if paylaod is composed and the length of the compose message.
     */
    function isComposed(
        bytes calldata _payload
    ) internal pure returns (bool, uint256) {
        (bool isCompose, uint256 composeMsgLen) = abi.decode(
            _payload[:COMPOSE_TYPE_OFFSET],
            (bool, uint256)
        );

        return (isCompose, composeMsgLen);
    }

    /**
     * @dev Encode the message.
     * @param _msg The message.
     * @param _composeMsg The compose message.
     * @return The encoded message.
     */
    function encode(
        bytes memory _msg,
        bytes memory _composeMsg
    ) internal pure returns (bytes memory) {
        uint256 composeMsgLen = _composeMsg.length;
        bool isCompose = composeMsgLen != 0;

        return
            abi.encodePacked(
                abi.encode(isCompose, composeMsgLen),
                _msg,
                _composeMsg
            );
    }

    /**
     * @dev Encode the compose message receiver.
     * The compose message must reserve its first 32 bytes for the receiver.
     * @param _payload The LayerZero msg payload.
     * @return The receiver address.
     */
    function composeTo(
        bytes calldata _payload
    ) internal pure returns (address) {
        (, uint256 composeMsgLen) = isComposed(_payload);
        uint256 payloadLen = _payload.length;
        uint256 start = payloadLen - composeMsgLen;
        uint256 end = start + 32;

        return address(uint160(uint256(bytes32(_payload[start:end]))));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library Errors {
    /**
     * @dev Zero address specified
     */
    error ZeroAddress();

    /**
     * @dev Zero amount specified
     */
    error ZeroAmount();

    /**
     * @dev Invalid fee specified
     */
    error InvalidFee();

    /**
     * @dev not same as deposit size
     */
    error InvalidAmount();

    /**
     * @dev Invalid nonce
     */
    error InvalidNonce();

    /**
     * @dev not allowed
     */
    error NotAllowed();

    /**
     * @dev Only ETH allowed
     */
    error OnlyETH();

    /**
     * @dev Invalid rate
     */
    error InvalidRate();

    /**
     * @dev Withdraw limit exceeded
     */
    error WithdrawLimitExceeded();

    /**
     * @dev Unauthorized caller on SyncPool
     */
    error UnauthorizedCaller();

    /**
     * @dev Native transfer failed on SyncPool
     */
    error NativeTransferFailed();

    /**
     * @dev Insufficient amount out
     */
    error InsufficientAmountOut();
    
    /**
     * @dev Insufficient amount to sync
     */
    error InsufficientAmountToSync();
    
    /**
     * @dev Unauthorized token
     */
    error UnauthorizedToken();

    /**
     * @dev Invalid amount in
     */
    error InvalidAmountIn();

    /**
     * @dev Max sync amount exceeded, to prevent going over the bridge limit
     */
    error MaxSyncAmountExceeded();

    /**
     * @dev Unsupported destination chain
     */
    error UnsupportedEid();

    /**
     * @dev Multichain eposits can't be wrapped
     */
    error MultichainDepositsCannotBeWrapped();

    /**
     * @dev OFT lockbox not set for multichain deposit
     */
    error OFTLockboxNotSet();
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAutoPxEth.
 * @notice Interface for the AutoPxEth contract.
 * @dev This interface defines the methods for interacting with AutoPxEth.
 * @author redactedcartel.finance
 */
interface IAutoPxEth {
    /**
     * @notice Return the amount of assets per 1 (1e18) share.
     * @return uint256 Assets
     */
    function assetsPerShare() external view returns (uint256);

    /**
     * @notice Return the amount of shares owned by an account.
     * @return uint256 Shares
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Deposit pxEth into the apxEth vault.
     * @param  assets    uint256  Assets amount
     * @param  receiver  address  Receiver address
     * @return shares    uint256  Shares
     */
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    /**
     * @notice Withdraw pxEth from the apxEth vault.
     * @param  assets    uint256  Assets amount
     * @param  receiver  address  Receiver address
     * @param  owner     address  Owner address
     * @return shares    uint256  Shares
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    /**
     * @notice Preview redemption assets amount using the specified shares (with fees)
     * @param  shares  uint256  Shares
     * @return         uint256  Assets
     */
    function previewRedeem(uint256 shares) external view returns (uint256);

    /**
     * @notice Get the amount of shares from the specified assets amount (no fees)
     * @param  assets  uint256  Assets
     * @return         uint256  Shares
     */
    function convertToShares(uint256 assets) external view returns (uint256);

    /**
     * @notice Get the amount of assets from the specified shares amount (no fees)
     * @param  shares  uint256  Shares
     * @return         uint256  Assets
     */
    function convertToAssets(uint256 shares) external view returns (uint256);

    /**
     * @notice Withdrawal penalty percentage.
     */
    function withdrawalPenalty() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IPirexEth} from "../interfaces/IPirexEthDeposit.sol";
import {Constants} from "src/vendor/layerzero/syncpools/L1/L1BaseSyncPoolUpgradeable.sol";
import {IDineroERC20} from "src/interfaces/IDineroERC20.sol";
import {Errors} from "./libraries/Errors.sol";

/**
 * @title L1 Base Sync Pool
 * @dev Base contract for Layer 1 sync pools
 * This contract is intended to be inherited by a lockbox contract
 * that will handle the sync of balances from Layer 2 to Layer 1
 * anticipating the deposit of tokens during the fast sync and
 * finalizing sync by depositing ETH to Pirex ETH during the slow sync
 */
abstract contract L1SyncPool is OwnableUpgradeable {
    struct L1SyncPoolStorage {
        /**
         * @notice The pirexEth instance.
         * @dev This variable holds the address of the PirexEth contract instance.
         */
        IPirexEth pirexEth;
        /**
         * @notice The address of the tokenOut contract.
         * @dev This variable holds the address of the tokenOut contract.
         */
        IERC20 tokenOut;
        /**
         * @notice The total amount of unbacked tokens.
         * @dev This variable holds the total amount of unbacked tokens.
         */
        uint256 totalUnbackedTokens;
        /**
         * @notice Mapping between EID and receiver address.
         * @dev Mapping to keep track of the receiver address for each EID.
         */
        mapping(uint32 => address) receivers;
        /**
         * @notice Processed messages.
         * @dev Mapping to keep track of processed messages.
         */
        mapping(bytes32 => bool) processedMessages;
    }

    // keccak256(abi.encode(uint256(keccak256(syncpools.storage.l1syncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1SyncPoolStorageLocation =
        0xec90cfc37697dc33dbcf188d524bdc2a41f251df5a390991a45d6388ac04b500;

    function _getL1SyncPoolStorage()
        internal
        pure
        returns (L1SyncPoolStorage storage $)
    {
        assembly {
            $.slot := L1SyncPoolStorageLocation
        }
    }

    /**
     * @notice Emitted on setting receiver.
     * @param  originEid  uint32   Origin EID.
     * @param  receiver   address  Address of the receiver.
     */
    event ReceiverSet(uint32 indexed originEid, address receiver);

    /**
     * @notice Emitted on setting tokenOut.
     * @param  tokenOut  address  Address of the tokenOut.
     */
    event TokenOutSet(address tokenOut);

    /**
     * @notice Emitted on setting platform.
     * @param  platform  address  Address of the platform.
     */
    event PlatformSet(address platform);

    /**
     * @notice Emitted on withdrawal.
     * @param  receiver  address  Address of the receiver.
     * @param  amount    uint256  Amount.
     */
    event Withdraw(address receiver, uint256 amount);

    /**
     * @notice Emitted on deposits received from the sync pool.
     * @param  guid             bytes32  GUID of the sync message.
     * @param  amount           uint256  Deposit amount (in pxEth).
     */
    event AnticipateSync(bytes32 guid, uint256 amount);

    /**
     * @dev Initialize the contract
     * @param platform Address of the platform
     * @param tokenOut Address of the main token
     */
    function __L1BaseSyncPool_init(
        address platform,
        address tokenOut
    ) internal onlyInitializing {
        _setPlatform(platform);
        _setTokenOut(tokenOut);
    }

    /**
     * @dev Get the main token address
     * @return The main token address
     */
    function getTokenOut() public view returns (IERC20) {
        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        return $.tokenOut;
    }

    /**
     * @dev Get the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @return The receiver address
     */
    function getReceiver(uint32 originEid) public view returns (address) {
        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        return $.receivers[originEid];
    }

    /**
     * @dev Get the total unbacked tokens
     * @return The total unbacked tokens
     */
    function getTotalUnbackedTokens() public view returns (uint256) {
        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        return $.totalUnbackedTokens;
    }

    /**
     * @dev Receive a message from an L2
     * Will revert if:
     * - The caller is not the receiver
     * @param originEid Origin EID
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount in
     * @param amountOut Amount out
     */
    function onMessageReceived(
        uint32 originEid,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) public payable virtual {
        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();

        if (msg.sender != $.receivers[originEid])
            revert Errors.UnauthorizedCaller();

        _finalizeDeposit(originEid, guid, tokenIn, amountIn, amountOut);
    }

    /**
     * @dev Set the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @param receiver Receiver address
     */
    function setReceiver(uint32 originEid, address receiver) public onlyOwner {
        _setReceiver(originEid, receiver);
    }

    /**
     * @dev Get the platform address
     * @return The platform address
     */
    function getPlatform() public view returns (address) {
        return address(_getL1SyncPoolStorage().pirexEth);
    }

    /**
     * @dev Set the platform address
     * @param platform The platform address
     */
    function setPlatform(address platform) public onlyOwner {
        _setPlatform(platform);
    }

    /**
     * @dev Internal function to set the platform address
     * @param platform The platform address
     */
    function _setPlatform(address platform) internal {
        if (platform == address(0)) revert Errors.ZeroAddress();

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();

        $.pirexEth = IPirexEth(platform);

        emit PlatformSet(platform);
    }

    /**
     * @dev Set the main token address
     * @param tokenOut Address of the main token
     */
    function setTokenOut(address tokenOut) public onlyOwner {
        _setTokenOut(tokenOut);
    }

    /**
     * @dev Internal function to set the main token address
     * @param tokenOut Address of the main token
     */
    function _setTokenOut(address tokenOut) internal {
        if (tokenOut == address(0)) revert Errors.ZeroAddress();

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        $.tokenOut = IERC20(tokenOut);

        emit TokenOutSet(tokenOut);
    }

    /**
     * @dev Internal function to set the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @param receiver Receiver address
     */
    function _setReceiver(uint32 originEid, address receiver) internal {
        if (receiver == address(0)) revert Errors.ZeroAddress();

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();
        $.receivers[originEid] = receiver;

        emit ReceiverSet(originEid, receiver);
    }

    /**
     * @dev Internal function to anticipate a deposit
     * Will mint pxEth and transfer it to the lock box
     * @param guid Message GUID
     * @param amountOut Amount of token received by the users
     * @return actualAmountOut The actual amount of token received
     */
    function _anticipatedDeposit(
        bytes32 guid,
        address,
        uint256,
        uint256 amountOut
    ) internal virtual returns (uint256) {
        // if the message was already processed, return 0
        // this should only happen if the slow sync msg arrives first than the fast sync msg
        if (_getL1SyncPoolStorage().processedMessages[guid]) return 0;

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();

        _getL1SyncPoolStorage().processedMessages[guid] = true;

        $.totalUnbackedTokens += amountOut;

        IDineroERC20 pxETH = IDineroERC20(address(getTokenOut()));

        pxETH.mint(address(this), amountOut);

        emit AnticipateSync(guid, amountOut);

        return amountOut;
    }

    /**
     * @dev Internal function to update lockbox state when finalizing a deposit
     */
    function _handleFinalizeDeposit(
        bytes32 guid,
        uint256 amountOut
    ) internal virtual {}

    /**
     * @dev Internal function to finalize a deposit
     * Will swap the dummy tokens for the actual ETH
     * Will revert if:
     * - The token in is not ETH
     * - The amount in is not equal to the value
     * - The dummy token is not set
     * @param guid Message GUID
     * @param tokenIn Address of the token in
     * @param amountIn Amount in
     */
    function _finalizeDeposit(
        uint32,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        if (amountOut > msg.value) revert Errors.InvalidAmount();

        // if the message was not processed, anticipate the deposit first
        // this should not normally happen
        if (!_getL1SyncPoolStorage().processedMessages[guid]) {
            _anticipatedDeposit(guid, tokenIn, amountIn, amountOut);
        }

        L1SyncPoolStorage storage $ = _getL1SyncPoolStorage();

        $.totalUnbackedTokens > amountOut
            ? $.totalUnbackedTokens -= amountOut
            : $.totalUnbackedTokens = 0;

        // sent the ETH to PirexETH
        (uint256 postFeeAmount, ) = IPirexEth(getPlatform()).deposit{
            value: msg.value
        }(address(this), false);

        // if it receives from the deposit more tokens than anticipated
        // then it should only burn the anticipated amount (amountOut)
        // this might happen if the deposit fee gets reduced from the moment of the L2 deposit
        // to the moment of the deposit finalization
        // the extra pxEth amount can be withdrawn by the owner through `withdraw()`
        uint256 amountToBurn = postFeeAmount > amountOut
            ? amountOut
            : postFeeAmount;

        // burn the pxEth
        IDineroERC20(address(getTokenOut())).burn(address(this), amountToBurn);

        // notify the lockbox to deposit up to amountIn into the vault
        _handleFinalizeDeposit(guid, amountOut);
    }

    /**
     * @notice Transfers to `receiver` the excess tokens not burned during the sync finalization
     * because of the amount received being greater than the anticipated amount
     * @param receiver the address of the token receiver
     */
    function withdraw(address receiver, uint256 amount) external onlyOwner {
        if (amount == 0) revert Errors.ZeroAmount();

        IDineroERC20 pxEth = IDineroERC20(address(getTokenOut()));

        pxEth.transfer(receiver, amount);

        emit Withdraw(receiver, amount);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

/**
 * @title  IPirexEth
 * @notice Interface for the PirexEth contract
 * @dev    This interface defines the methods for interacting with PirexEth.
 * @author redactedcartel.finance
 */
interface IPirexEth {
    /**
     * @notice Handle pxETH minting in return for ETH deposits.
     * @dev    This function handles the minting of pxETH in return for ETH deposits.
     * @param  receiver        address  Receiver of the minted pxETH or apxEth
     * @param  shouldCompound  bool     Whether to also compound into the vault
     * @return postFeeAmount   uint256  pxETH minted for the receiver
     * @return feeAmount       uint256  pxETH distributed as fees
     */
    function deposit(
        address receiver,
        bool shouldCompound
    ) external payable returns (uint256 postFeeAmount, uint256 feeAmount);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

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
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
    }

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

pragma solidity ^0.8.20;

// @dev Import the 'MessagingFee' and 'MessagingReceipt' so it's exposed to OApp implementers
// solhint-disable-next-line no-unused-import
import { OAppSenderUpgradeable, MessagingFee, MessagingReceipt } from "./OAppSenderUpgradeable.sol";
// @dev Import the 'Origin' so it's exposed to OApp implementers
// solhint-disable-next-line no-unused-import
import { OAppReceiverUpgradeable, Origin } from "./OAppReceiverUpgradeable.sol";
import { OAppCoreUpgradeable } from "./OAppCoreUpgradeable.sol";

/**
 * @title OApp
 * @dev Abstract contract serving as the base for OApp implementation, combining OAppSender and OAppReceiver functionality.
 */
abstract contract OAppUpgradeable is OAppSenderUpgradeable, OAppReceiverUpgradeable {
    /**
     * @dev Constructor to initialize the OApp with the provided endpoint and owner.
     * @param _endpoint The address of the LOCAL LayerZero endpoint.
     */
    constructor(address _endpoint) OAppCoreUpgradeable(_endpoint) {}

    /**
     * @dev Initializes the OApp with the provided delegate.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     *
     * @dev The delegate typically should be set as the owner of the contract.
     * @dev Ownable is not initialized here on purpose. It should be initialized in the child contract to
     * accommodate the different version of Ownable.
     */
    function __OApp_init(address _delegate) internal onlyInitializing {
        __OAppCore_init(_delegate);
    }

    function __OApp_init_unchained() internal onlyInitializing {}

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol implementation.
     * @return receiverVersion The version of the OAppReceiver.sol implementation.
     */
    function oAppVersion()
        public
        pure
        virtual
        override(OAppSenderUpgradeable, OAppReceiverUpgradeable)
        returns (uint64 senderVersion, uint64 receiverVersion)
    {
        return (SENDER_VERSION, RECEIVER_VERSION);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IOAppOptionsType3, EnforcedOptionParam } from "../interfaces/IOAppOptionsType3.sol";

/**
 * @title OAppOptionsType3
 * @dev Abstract contract implementing the IOAppOptionsType3 interface with type 3 options.
 */
abstract contract OAppOptionsType3Upgradeable is IOAppOptionsType3, OwnableUpgradeable {
    struct OAppOptionsType3Storage {
        // @dev The "msgType" should be defined in the child contract.
        mapping(uint32 => mapping(uint16 => bytes)) enforcedOptions;
    }

    // keccak256(abi.encode(uint256(keccak256("layerzerov2.storage.oappoptionstype3")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OAppOptionsType3StorageLocation =
        0x8d2bda5d9f6ffb5796910376005392955773acee5548d0fcdb10e7c264ea0000;

    uint16 internal constant OPTION_TYPE_3 = 3;

    function _getOAppOptionsType3Storage() internal pure returns (OAppOptionsType3Storage storage $) {
        assembly {
            $.slot := OAppOptionsType3StorageLocation
        }
    }

    /**
     * @dev Ownable is not initialized here on purpose. It should be initialized in the child contract to
     * accommodate the different version of Ownable.
     */
    function __OAppOptionsType3_init() internal onlyInitializing {}

    function __OAppOptionsType3_init_unchained() internal onlyInitializing {}

    function enforcedOptions(uint32 _eid, uint16 _msgType) public view returns (bytes memory) {
        OAppOptionsType3Storage storage $ = _getOAppOptionsType3Storage();
        return $.enforcedOptions[_eid][_msgType];
    }

    /**
     * @dev Sets the enforced options for specific endpoint and message type combinations.
     * @param _enforcedOptions An array of EnforcedOptionParam structures specifying enforced options.
     *
     * @dev Only the owner/admin of the OApp can call this function.
     * @dev Provides a way for the OApp to enforce things like paying for PreCrime, AND/OR minimum dst lzReceive gas amounts etc.
     * @dev These enforced options can vary as the potential options/execution on the remote may differ as per the msgType.
     * eg. Amount of lzReceive() gas necessary to deliver a lzCompose() message adds overhead you dont want to pay
     * if you are only making a standard LayerZero message ie. lzReceive() WITHOUT sendCompose().
     */
    function setEnforcedOptions(EnforcedOptionParam[] calldata _enforcedOptions) public virtual onlyOwner {
        OAppOptionsType3Storage storage $ = _getOAppOptionsType3Storage();
        for (uint256 i = 0; i < _enforcedOptions.length; i++) {
            // @dev Enforced options are only available for optionType 3, as type 1 and 2 dont support combining.
            _assertOptionsType3(_enforcedOptions[i].options);
            $.enforcedOptions[_enforcedOptions[i].eid][_enforcedOptions[i].msgType] = _enforcedOptions[i].options;
        }

        emit EnforcedOptionSet(_enforcedOptions);
    }

    /**
     * @notice Combines options for a given endpoint and message type.
     * @param _eid The endpoint ID.
     * @param _msgType The OAPP message type.
     * @param _extraOptions Additional options passed by the caller.
     * @return options The combination of caller specified options AND enforced options.
     *
     * @dev If there is an enforced lzReceive option:
     * - {gasLimit: 200k, msg.value: 1 ether} AND a caller supplies a lzReceive option: {gasLimit: 100k, msg.value: 0.5 ether}
     * - The resulting options will be {gasLimit: 300k, msg.value: 1.5 ether} when the message is executed on the remote lzReceive() function.
     * @dev This presence of duplicated options is handled off-chain in the verifier/executor.
     */
    function combineOptions(
        uint32 _eid,
        uint16 _msgType,
        bytes calldata _extraOptions
    ) public view virtual returns (bytes memory) {
        OAppOptionsType3Storage storage $ = _getOAppOptionsType3Storage();
        bytes memory enforced = $.enforcedOptions[_eid][_msgType];

        // No enforced options, pass whatever the caller supplied, even if it's empty or legacy type 1/2 options.
        if (enforced.length == 0) return _extraOptions;

        // No caller options, return enforced
        if (_extraOptions.length == 0) return enforced;

        // @dev If caller provided _extraOptions, must be type 3 as its the ONLY type that can be combined.
        if (_extraOptions.length >= 2) {
            _assertOptionsType3(_extraOptions);
            // @dev Remove the first 2 bytes containing the type from the _extraOptions and combine with enforced.
            return bytes.concat(enforced, _extraOptions[2:]);
        }

        // No valid set of options was found.
        revert InvalidOptions(_extraOptions);
    }

    /**
     * @dev Internal function to assert that options are of type 3.
     * @param _options The options to be checked.
     */
    function _assertOptionsType3(bytes calldata _options) internal pure virtual {
        uint16 optionsType = uint16(bytes2(_options[0:2]));
        if (optionsType != OPTION_TYPE_3) revert InvalidOptions(_options);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILayerZeroReceiver, Origin } from "src/vendor/layerzero/protocol/interfaces/ILayerZeroReceiver.sol";

interface IOAppReceiver is ILayerZeroReceiver {
    /**
     * @notice Retrieves the address responsible for 'sending' composeMsg's to the Endpoint.
     * @return sender The address responsible for 'sending' composeMsg's to the Endpoint.
     *
     * @dev Applications can optionally choose to implement a separate composeMsg sender that is NOT the bridging layer.
     * @dev The default sender IS the OApp implementer.
     */
    function composeMsgSender() external view returns (address sender);
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

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Inspired by USM (https://github.com/usmfum/USM/blob/master/contracts/WadMath.sol)
library FixedPointMathLib {
    /*//////////////////////////////////////////////////////////////
                    SIMPLIFIED FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MAX_UINT256 = 2**256 - 1;

    uint256 internal constant WAD = 1e18; // The scalar of ETH and most ERC20s.

    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); // Equivalent to (x * y) / WAD rounded down.
    }

    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); // Equivalent to (x * y) / WAD rounded up.
    }

    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); // Equivalent to (x * WAD) / y rounded down.
    }

    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); // Equivalent to (x * WAD) / y rounded up.
    }

    /*//////////////////////////////////////////////////////////////
                    LOW LEVEL FIXED POINT OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // Divide x * y by the denominator.
            z := div(mul(x, y), denominator)
        }
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to require(denominator != 0 && (y == 0 || x <= type(uint256).max / y))
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }

            // If x * y modulo the denominator is strictly greater than 0,
            // 1 is added to round up the division of x * y by the denominator.
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }

    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    // 0 ** 0 = 1
                    z := scalar
                }
                default {
                    // 0 ** n = 0
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    // If n is even, store scalar in z for now.
                    z := scalar
                }
                default {
                    // If n is odd, store x in z for now.
                    z := x
                }

                // Shifting right by 1 is like dividing by 2.
                let half := shr(1, scalar)

                for {
                    // Shift n right by 1 before looping to halve it.
                    n := shr(1, n)
                } n {
                    // Shift n right by 1 each iteration to halve it.
                    n := shr(1, n)
                } {
                    // Revert immediately if x ** 2 would overflow.
                    // Equivalent to iszero(eq(div(xx, x), x)) here.
                    if shr(128, x) {
                        revert(0, 0)
                    }

                    // Store x squared.
                    let xx := mul(x, x)

                    // Round to the nearest number.
                    let xxRound := add(xx, half)

                    // Revert if xx + half overflowed.
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }

                    // Set x to scaled xxRound.
                    x := div(xxRound, scalar)

                    // If n is even:
                    if mod(n, 2) {
                        // Compute z * x.
                        let zx := mul(z, x)

                        // If z * x overflowed:
                        if iszero(eq(div(zx, x), z)) {
                            // Revert if x is non-zero.
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }

                        // Round to the nearest number.
                        let zxRound := add(zx, half)

                        // Revert if zx + half overflowed.
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }

                        // Return properly scaled zxRound.
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        GENERAL NUMBER UTILITIES
    //////////////////////////////////////////////////////////////*/

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            let y := x // We start y at x, which will help us make our initial estimate.

            z := 181 // The "correct" value is 1, but this saves a multiplication later.

            // This segment is to get a reasonable initial estimate for the Babylonian method. With a bad
            // start, the correct # of bits increases ~linearly each iteration instead of ~quadratically.

            // We check y >= 2^(k + 8) but shift right by k bits
            // each branch to ensure that if x >= 256, then y >= 256.
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }

            // Goal was to get z*z*y within a small factor of x. More iterations could
            // get y in a tighter range. Currently, we will have y in [256, 256*2^16).
            // We ensured y >= 256 so that the relative difference between y and y+1 is small.
            // That's not possible if x < 256 but we can just verify those cases exhaustively.

            // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8), and either y >= 256, or x < 256.
            // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
            // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of sqrt(x), or about 20bps.

            // For s in the range [1/256, 256], the estimate f(s) = (181/1024) * (s+1) is in the range
            // (1/2.84 * sqrt(s), 2.84 * sqrt(s)), with largest error when s = 1 and when s = 256 or 1/256.

            // Since y is in [256, 256*2^16), let a = y/65536, so that a is in [1/256, 256). Then we can estimate
            // sqrt(y) using sqrt(65536) * 181/1024 * (a + 1) = 181/4 * (y + 65536)/65536 = 181 * (y + 65536)/2^18.

            // There is no overflow risk here since y < 2^136 after the first branch above.
            z := shr(18, mul(z, add(y, 65536))) // A mul() is saved from starting z at 181.

            // Given the worst case multiplicative error of 2.84 above, 7 iterations should be enough.
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))

            // If x+1 is a perfect square, the Babylonian method cycles between
            // floor(sqrt(x)) and ceil(sqrt(x)). This statement ensures we return floor.
            // See: https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division
            // Since the ceil is rare, we save gas on the assignment and repeat division in the rare case.
            // If you don't care whether the floor or ceil square root is returned, you can remove this statement.
            z := sub(z, lt(div(x, z), z))
        }
    }

    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Mod x by y. Note this will return
            // 0 instead of reverting if y is zero.
            z := mod(x, y)
        }
    }

    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        /// @solidity memory-safe-assembly
        assembly {
            // Divide x by y. Note this will return
            // 0 instead of reverting if y is zero.
            r := div(x, y)
        }
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title  Constants
 * @notice Library containing various constants for the L2LiquidStakingToken system.
 * @author redactedcartel.finance
 */
library Constants {
    /**
     * @notice Message type constant for deposit.
     * @dev This constant defines the message type for deposit operations.
     */
    uint8 constant MESSAGE_TYPE_DEPOSIT = 1;

    /**
     * @notice Message type constant for deposit.
     * @dev This constant defines the message type for deposit operations.
     */
    uint8 constant MESSAGE_TYPE_DEPOSIT_WRAP = 2;

    /**
     * @notice Message type constant for withdrawal.
     * @dev This constant defines the message type for withdrawal operations.
     */
    uint8 constant MESSAGE_TYPE_WITHDRAW = 3;

    /**
     * @notice Message type constant for rebase.
     * @dev This constant defines the message type for rebase operations.
     */
    uint8 constant MESSAGE_TYPE_REBASE = 4;

    /**
     * @notice Message type constant for sync.
     * @dev This constant defines the message type for sync operations.
     */
    uint8 constant MESSAGE_TYPE_SYNC = 5;

    /**
     * @notice The destination endpoint ID for Mainnet.
     * @dev This constant holds the destination endpoint ID for Mainnet.
     */
    uint32 constant MAINNET_EID = 30101;

    /**
     * @notice Fee denominator for precise fee calculations.
     * @dev This constant holds the fee denominator for precise fee calculations.
     */
    uint256 constant FEE_DENOMINATOR = 1_000_000;

    /**
     * @notice Max rebase fee.
     * @dev This constant holds the maximum rebase fee that can be set.
     */
    uint256 constant MAX_REBASE_FEE = 200_000;

    /**
     * @notice Max deposit fee.
     * @dev This constant holds the maximum sync deposit fee that can be set.
     */
    uint256 constant MAX_DEPOSIT_FEE = 200_000;

    /**
     * @dev The address of the ETH token.
     */
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import { IMessageLibManager } from "./IMessageLibManager.sol";
import { IMessagingComposer } from "./IMessagingComposer.sol";
import { IMessagingChannel } from "./IMessagingChannel.sol";
import { IMessagingContext } from "./IMessagingContext.sol";

struct MessagingParams {
    uint32 dstEid;
    bytes32 receiver;
    bytes message;
    bytes options;
    bool payInLzToken;
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct Origin {
    uint32 srcEid;
    bytes32 sender;
    uint64 nonce;
}

interface ILayerZeroEndpointV2 is IMessageLibManager, IMessagingComposer, IMessagingChannel, IMessagingContext {
    event PacketSent(bytes encodedPayload, bytes options, address sendLibrary);

    event PacketVerified(Origin origin, address receiver, bytes32 payloadHash);

    event PacketDelivered(Origin origin, address receiver);

    event LzReceiveAlert(
        address indexed receiver,
        address indexed executor,
        Origin origin,
        bytes32 guid,
        uint256 gas,
        uint256 value,
        bytes message,
        bytes extraData,
        bytes reason
    );

    event LzTokenSet(address token);

    event DelegateSet(address sender, address delegate);

    function quote(MessagingParams calldata _params, address _sender) external view returns (MessagingFee memory);

    function send(
        MessagingParams calldata _params,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory);

    function verify(Origin calldata _origin, address _receiver, bytes32 _payloadHash) external;

    function verifiable(Origin calldata _origin, address _receiver) external view returns (bool);

    function initializable(Origin calldata _origin, address _receiver) external view returns (bool);

    function lzReceive(
        Origin calldata _origin,
        address _receiver,
        bytes32 _guid,
        bytes calldata _message,
        bytes calldata _extraData
    ) external payable;

    // oapp can burn messages partially by calling this function with its own business logic if messages are verified in order
    function clear(address _oapp, Origin calldata _origin, bytes32 _guid, bytes calldata _message) external;

    function setLzToken(address _lzToken) external;

    function lzToken() external view returns (address);

    function nativeToken() external view returns (address);

    function setDelegate(address _delegate) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from "../../../../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IOAppCore, ILayerZeroEndpointV2 } from "./interfaces/IOAppCore.sol";

/**
 * @title OAppCore
 * @dev Abstract contract implementing the IOAppCore interface with basic OApp configurations.
 */
abstract contract OAppCoreUpgradeable is IOAppCore, OwnableUpgradeable {
    struct OAppCoreStorage {
        mapping(uint32 => bytes32) peers;
    }

    // keccak256(abi.encode(uint256(keccak256("layerzerov2.storage.oappcore")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OAppCoreStorageLocation =
        0x72ab1bc1039b79dc4724ffca13de82c96834302d3c7e0d4252232d4b2dd8f900;

    function _getOAppCoreStorage() internal pure returns (OAppCoreStorage storage $) {
        assembly {
            $.slot := OAppCoreStorageLocation
        }
    }

    // The LayerZero endpoint associated with the given OApp
    ILayerZeroEndpointV2 public immutable endpoint;

    /**
     * @dev Constructor to initialize the OAppCore with the provided endpoint and delegate.
     * @param _endpoint The address of the LOCAL Layer Zero endpoint.
     */
    constructor(address _endpoint) {
        endpoint = ILayerZeroEndpointV2(_endpoint);
    }

    /**
     * @dev Initializes the OAppCore with the provided delegate.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     *
     * @dev The delegate typically should be set as the owner of the contract.
     * @dev Ownable is not initialized here on purpose. It should be initialized in the child contract to
     * accommodate the different version of Ownable.
     */
    function __OAppCore_init(address _delegate) internal onlyInitializing {
        __OAppCore_init_unchained(_delegate);
    }

    function __OAppCore_init_unchained(address _delegate) internal onlyInitializing {
        if (_delegate == address(0)) revert InvalidDelegate();
        endpoint.setDelegate(_delegate);
    }

    /**
     * @notice Returns the peer address (OApp instance) associated with a specific endpoint.
     * @param _eid The endpoint ID.
     * @return peer The address of the peer associated with the specified endpoint.
     */
    function peers(uint32 _eid) public view override returns (bytes32) {
        OAppCoreStorage storage $ = _getOAppCoreStorage();
        return $.peers[_eid];
    }

    /**
     * @notice Sets the peer address (OApp instance) for a corresponding endpoint.
     * @param _eid The endpoint ID.
     * @param _peer The address of the peer to be associated with the corresponding endpoint.
     *
     * @dev Only the owner/admin of the OApp can call this function.
     * @dev Indicates that the peer is trusted to send LayerZero messages to this OApp.
     * @dev Set this to bytes32(0) to remove the peer address.
     * @dev Peer is a bytes32 to accommodate non-evm chains.
     */
    function setPeer(uint32 _eid, bytes32 _peer) public virtual onlyOwner {
        OAppCoreStorage storage $ = _getOAppCoreStorage();
        $.peers[_eid] = _peer;
        emit PeerSet(_eid, _peer);
    }

    /**
     * @notice Internal function to get the peer address associated with a specific endpoint; reverts if NOT set.
     * ie. the peer is set to bytes32(0).
     * @param _eid The endpoint ID.
     * @return peer The address of the peer associated with the specified endpoint.
     */
    function _getPeerOrRevert(uint32 _eid) internal view virtual returns (bytes32) {
        OAppCoreStorage storage $ = _getOAppCoreStorage();
        bytes32 peer = $.peers[_eid];
        if (peer == bytes32(0)) revert NoPeer(_eid);
        return peer;
    }

    /**
     * @notice Sets the delegate address for the OApp.
     * @param _delegate The address of the delegate to be set.
     *
     * @dev Only the owner/admin of the OApp can call this function.
     * @dev Provides the ability for a delegate to set configs, on behalf of the OApp, directly on the Endpoint contract.
     */
    function setDelegate(address _delegate) public onlyOwner {
        endpoint.setDelegate(_delegate);
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

// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    OAppReceiverUpgradeable,
    OAppCoreUpgradeable
} from "src/vendor/layerzero-upgradeable/oapp/OAppReceiverUpgradeable.sol";
import {Origin} from "src/vendor/layerzero/protocol/interfaces/ILayerZeroEndpointV2.sol";

import {IL1SyncPool} from "../interfaces/IL1SyncPool.sol";
import {Constants} from "../libraries/Constants.sol";

/**
 * @title L1 Base Sync Pool
 * @dev Base contract for L1 Sync Pools
 * A sync pool is an OApp that allows users to deposit tokens on Layer 2, and then sync them to Layer 1
 * using the LayerZero messaging protocol.
 * The L1 sync pool takes care of the actual syncing process, it receives different messages from L2s
 * and handles the anticipated deposits and the actual deposits.
 * The L1 sync pool is responsible for managing the lock box making sure it is backed by the correct amount of tokens.
 * Fast messages are used to anticipate the deposit, and slow messages are used to finalize the deposit.
 * For example, a user can deposit 100 ETH on L2, the L2 sync pool will send a fast message to the L1 sync pool
 * anticipating the actual 100 ETH deposit (as it takes ~7 days to finalize the deposit), and finalize the deposit
 * when the 100 ETH is actually received from the L2.
 */
abstract contract L1BaseSyncPoolUpgradeable is OAppReceiverUpgradeable, ReentrancyGuardUpgradeable, IL1SyncPool {
    struct L1BaseSyncPoolStorage {
        IERC20 tokenOut;
        address lockBox;
        uint256 totalUnbackedTokens;
        mapping(uint32 => address) receivers;
    }

    // keccak256(abi.encode(uint256(keccak256(syncpools.storage.l1basesyncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1BaseSyncPoolStorageLocation =
        0xd96cd964f71a052084af61290ff53294a8f76de4d8f66ba7682fe6598635ef00;

    function _getL1BaseSyncPoolStorage() internal pure returns (L1BaseSyncPoolStorage storage $) {
        assembly {
            $.slot := L1BaseSyncPoolStorageLocation
        }
    }

    error L1BaseSyncPool__UnauthorizedCaller();
    error L1BaseSyncPool__NativeTransferFailed();

    event ReceiverSet(uint32 indexed originEid, address receiver);
    event TokenOutSet(address tokenOut);
    event LockBoxSet(address lockBox);
    event InsufficientDeposit(
        uint32 indexed originEid,
        bytes32 guid,
        uint256 actualAmountOut,
        uint256 expectedAmountOut,
        uint256 unbackedTokens
    );
    event Fee(uint32 indexed originEid, bytes32 guid, uint256 actualAmountOut, uint256 expectedAmountOut, uint256 fee);
    event Sweep(address token, address receiver, uint256 amount);

    /**
     * @dev Constructor for L1 Base Sync Pool
     * @param endpoint Address of the LayerZero endpoint
     */
    constructor(address endpoint) OAppCoreUpgradeable(endpoint) {}

    function __L1BaseSyncPool_init(address tokenOut, address lockBox, address delegate) internal onlyInitializing {
        __ReentrancyGuard_init();
        __OAppCore_init(delegate);
        __L1BaseSyncPool_init_unchained(tokenOut, lockBox);
    }

    function __L1BaseSyncPool_init_unchained(address tokenOut, address lockBox) internal onlyInitializing {
        _setTokenOut(tokenOut);
        _setLockBox(lockBox);
    }

    /**
     * @dev Get the main token address
     * @return The main token address
     */
    function getTokenOut() public view virtual returns (address) {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();
        return address($.tokenOut);
    }

    /**
     * @dev Get the lock box address
     * @return The lock box address
     */
    function getLockBox() public view virtual returns (address) {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();
        return $.lockBox;
    }

    /**
     * @dev Get the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @return The receiver address
     */
    function getReceiver(uint32 originEid) public view virtual returns (address) {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();
        return $.receivers[originEid];
    }

    /**
     * @dev Get the total unbacked tokens
     * @return The total unbacked tokens
     */
    function getTotalUnbackedTokens() public view virtual returns (uint256) {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();
        return $.totalUnbackedTokens;
    }

    /**
     * @dev Receive a message from an L2
     * Will revert if:
     * - The caller is not the receiver
     * @param originEid Origin EID
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount in
     * @param amountOut Amount out
     */
    function onMessageReceived(uint32 originEid, bytes32 guid, address tokenIn, uint256 amountIn, uint256 amountOut)
        public
        payable
        override
        nonReentrant
    {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();

        if (msg.sender != $.receivers[originEid]) revert L1BaseSyncPool__UnauthorizedCaller();

        _finalizeDeposit(originEid, guid, tokenIn, amountIn, amountOut);
    }

    /**
     * @dev Receive a message from LayerZero
     * Overriden to add reentrancy guard
     * @param origin Origin
     * @param guid Message GUID
     * @param message Message
     * @param executor Executor
     * @param extraData Extra data
     */
    function lzReceive(
        Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) public payable virtual override nonReentrant {
        super.lzReceive(origin, guid, message, executor, extraData);
    }

    /**
     * @dev Set the main token address
     * @param tokenOut Address of the main token
     */
    function setTokenOut(address tokenOut) public virtual onlyOwner {
        _setTokenOut(tokenOut);
    }

    /**
     * @dev Set the lock box address
     * @param lockBox Address of the lock box
     */
    function setLockBox(address lockBox) public virtual onlyOwner {
        _setLockBox(lockBox);
    }

    /**
     * @dev Set the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @param receiver Receiver address
     */
    function setReceiver(uint32 originEid, address receiver) public virtual onlyOwner {
        _setReceiver(originEid, receiver);
    }

    /**
     * @dev Sweep tokens from the contract
     * @param token Token address
     * @param receiver Receiver address
     * @param amount Amount to sweep
     */
    function sweep(address token, address receiver, uint256 amount) public virtual onlyOwner {
        if (token == Constants.ETH_ADDRESS) {
            (bool success,) = receiver.call{value: amount}("");
            if (!success) revert L1BaseSyncPool__NativeTransferFailed();
        } else {
            SafeERC20.safeTransfer(IERC20(token), receiver, amount);
        }

        emit Sweep(token, receiver, amount);
    }

    /**
     * @dev Internal function called when a LZ message is received
     * @param origin Origin
     * @param guid Message GUID
     * @param message Message
     */
    function _lzReceive(Origin calldata origin, bytes32 guid, bytes calldata message, address, bytes calldata)
        internal
        virtual
        override
    {
        (address tokenIn, uint256 amountIn, uint256 amountOut) = abi.decode(message, (address, uint256, uint256));

        uint256 actualAmountOut = _anticipatedDeposit(origin.srcEid, guid, tokenIn, amountIn, amountOut);

        _handleAnticipatedDeposit(origin.srcEid, guid, actualAmountOut, amountOut);
    }

    /**
     * @dev Internal function to set the main token address
     * @param tokenOut Address of the main token
     */
    function _setTokenOut(address tokenOut) internal virtual {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();
        $.tokenOut = IERC20(tokenOut);

        emit TokenOutSet(tokenOut);
    }

    /**
     * @dev Internal function to set the receiver address for a specific origin EID
     * @param originEid Origin EID
     * @param receiver Receiver address
     */
    function _setReceiver(uint32 originEid, address receiver) internal virtual {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();
        $.receivers[originEid] = receiver;

        emit ReceiverSet(originEid, receiver);
    }

    /**
     * @dev Internal function to set the lock box address
     * @param lockBox Address of the lock box
     */
    function _setLockBox(address lockBox) internal virtual {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();
        $.lockBox = lockBox;

        emit LockBoxSet(lockBox);
    }

    /**
     * @dev Internal function to handle an anticipated deposit
     * Will emit an InsufficientDeposit event if the actual amount out is less than the expected amount out
     * Will emit a Fee event if the actual amount out is equal or greater than the expected amount out
     * The fee kept in this contract will be used to back any future insufficient deposits
     * When the fee is used, the total unbacked tokens will be lower than the actual missing amount
     * Any time the InsufficientDeposit event is emitted, necessary actions should be taken to back the lock box
     * such as using POL, increasing the deposit fee on the faulty L2, etc.
     * @param originEid Origin EID
     * @param guid Message GUID
     * @param actualAmountOut Actual amount out
     * @param expectedAmountOut Expected amount out
     */
    function _handleAnticipatedDeposit(
        uint32 originEid,
        bytes32 guid,
        uint256 actualAmountOut,
        uint256 expectedAmountOut
    ) internal virtual {
        L1BaseSyncPoolStorage storage $ = _getL1BaseSyncPoolStorage();

        IERC20 tokenOut = $.tokenOut;

        uint256 totalUnbackedTokens = $.totalUnbackedTokens;
        uint256 balance = tokenOut.balanceOf(address(this));

        uint256 totalAmountOut = expectedAmountOut + totalUnbackedTokens;
        uint256 amountToSend;

        if (balance < totalAmountOut) {
            amountToSend = balance;

            $.totalUnbackedTokens = totalAmountOut - balance;
        } else {
            amountToSend = totalAmountOut;

            if (totalUnbackedTokens > 0) $.totalUnbackedTokens = 0;
        }

        if (actualAmountOut < expectedAmountOut) {
            uint256 unbackedTokens = expectedAmountOut - actualAmountOut;
            emit InsufficientDeposit(originEid, guid, actualAmountOut, expectedAmountOut, unbackedTokens);
        } else {
            uint256 fee = actualAmountOut - expectedAmountOut;
            emit Fee(originEid, guid, actualAmountOut, expectedAmountOut, fee);
        }

        SafeERC20.safeTransfer(tokenOut, $.lockBox, amountToSend);
    }

    /**
     * @dev Internal function to anticipate a deposit
     * @param originEid Origin EID
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount in
     * @param amountOut Amount out
     * @return actualAmountOut Actual amount out
     */
    function _anticipatedDeposit(uint32 originEid, bytes32 guid, address tokenIn, uint256 amountIn, uint256 amountOut)
        internal
        virtual
        returns (uint256 actualAmountOut);

    /**
     * @dev Internal function to finalize a deposit
     * @param originEid Origin EID
     * @param guid Message GUID (will match the one used in the anticipated deposit)
     * @param tokenIn Token address
     * @param amountIn Amount in
     * @param amountOut Amount out
     */
    function _finalizeDeposit(uint32 originEid, bytes32 guid, address tokenIn, uint256 amountIn, uint256 amountOut)
        internal
        virtual;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDineroERC20
 * @dev Interface for the Dinero ERC20 token.
 * @author redactedcartel.finance
 */
interface IDineroERC20 {
    /**
     * @notice Mints tokens to an address.
     * @dev Only callable by minters.
     * @param _to      address  Address to mint tokens to.
     * @param _amount  uint256  Amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external;

    /**
     * @notice Burns tokens from an address.
     * @dev Only callable by burners.
     * @param _from    address  Address to burn tokens from.
     * @param _amount  uint256  Amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external;

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the caller's tokens.
     * @return a boolean value indicating whether the operation succeeded.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @return the value of tokens owned by `account`.
     */
    function balanceOf(address owner) external returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *  @return a boolean value indicating whether the operation succeeded.
     */
    function transfer(address to, uint256 amount) external returns (bool);
}

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

pragma solidity ^0.8.20;

import { IOAppReceiver, Origin } from "./interfaces/IOAppReceiver.sol";
import { OAppCoreUpgradeable } from "./OAppCoreUpgradeable.sol";

/**
 * @title OAppReceiver
 * @dev Abstract contract implementing the ILayerZeroReceiver interface and extending OAppCore for OApp receivers.
 */
abstract contract OAppReceiverUpgradeable is IOAppReceiver, OAppCoreUpgradeable {
    // Custom error message for when the caller is not the registered endpoint/
    error OnlyEndpoint(address addr);

    // @dev The version of the OAppReceiver implementation.
    // @dev Version is bumped when changes are made to this contract.
    uint64 internal constant RECEIVER_VERSION = 1;

    /**
     * @dev Ownable is not initialized here on purpose. It should be initialized in the child contract to
     * accommodate the different version of Ownable.
     */
    function __OAppReceiver_init() internal onlyInitializing {}

    function __OAppReceiver_init_unchained() internal onlyInitializing {}

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol contract.
     * @return receiverVersion The version of the OAppReceiver.sol contract.
     *
     * @dev Providing 0 as the default for OAppSender version. Indicates that the OAppSender is not implemented.
     * ie. this is a RECEIVE only OApp.
     * @dev If the OApp uses both OAppSender and OAppReceiver, then this needs to be override returning the correct versions.
     */
    function oAppVersion() public view virtual returns (uint64 senderVersion, uint64 receiverVersion) {
        return (0, RECEIVER_VERSION);
    }

    /**
     * @notice Retrieves the address responsible for 'sending' composeMsg's to the Endpoint.
     * @return sender The address responsible for 'sending' composeMsg's to the Endpoint.
     *
     * @dev Applications can optionally choose to implement a separate composeMsg sender that is NOT the bridging layer.
     * @dev The default sender IS the OApp implementer.
     */
    function composeMsgSender() public view virtual returns (address sender) {
        return address(this);
    }

    /**
     * @notice Checks if the path initialization is allowed based on the provided origin.
     * @param origin The origin information containing the source endpoint and sender address.
     * @return Whether the path has been initialized.
     *
     * @dev This indicates to the endpoint that the OApp has enabled msgs for this particular path to be received.
     * @dev This defaults to assuming if a peer has been set, its initialized.
     * Can be overridden by the OApp if there is other logic to determine this.
     */
    function allowInitializePath(Origin calldata origin) public view virtual returns (bool) {
        return peers(origin.srcEid) == origin.sender;
    }

    /**
     * @notice Retrieves the next nonce for a given source endpoint and sender address.
     * @dev _srcEid The source endpoint ID.
     * @dev _sender The sender address.
     * @return nonce The next nonce.
     *
     * @dev The path nonce starts from 1. If 0 is returned it means that there is NO nonce ordered enforcement.
     * @dev Is required by the off-chain executor to determine the OApp expects msg execution is ordered.
     * @dev This is also enforced by the OApp.
     * @dev By default this is NOT enabled. ie. nextNonce is hardcoded to return 0.
     */
    function nextNonce(uint32, /*_srcEid*/ bytes32 /*_sender*/) public view virtual returns (uint64 nonce) {
        return 0;
    }

    /**
     * @dev Entry point for receiving messages or packets from the endpoint.
     * @param _origin The origin information containing the source endpoint and sender address.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address on the src chain.
     *  - nonce: The nonce of the message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The payload of the received message.
     * @param _executor The address of the executor for the received message.
     * @param _extraData Additional arbitrary data provided by the corresponding executor.
     *
     * @dev Entry point for receiving msg/packet from the LayerZero endpoint.
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) public payable virtual {
        // Ensures that only the endpoint can attempt to lzReceive() messages to this OApp.
        if (address(endpoint) != msg.sender) revert OnlyEndpoint(msg.sender);

        // Ensure that the sender matches the expected peer for the source endpoint.
        if (_getPeerOrRevert(_origin.srcEid) != _origin.sender) revert OnlyPeer(_origin.srcEid, _origin.sender);

        // Call the internal OApp implementation of lzReceive.
        _lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    /**
     * @dev Internal function to implement lzReceive logic without needing to copy the basic parameter validation.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal virtual;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev Struct representing enforced option parameters.
 */
struct EnforcedOptionParam {
    uint32 eid; // Endpoint ID
    uint16 msgType; // Message Type
    bytes options; // Additional options
}

/**
 * @title IOAppOptionsType3
 * @dev Interface for the OApp with Type 3 Options, allowing the setting and combining of enforced options.
 */
interface IOAppOptionsType3 {
    // Custom error message for invalid options
    error InvalidOptions(bytes options);

    // Event emitted when enforced options are set
    event EnforcedOptionSet(EnforcedOptionParam[] _enforcedOptions);

    /**
     * @notice Sets enforced options for specific endpoint and message type combinations.
     * @param _enforcedOptions An array of EnforcedOptionParam structures specifying enforced options.
     */
    function setEnforcedOptions(EnforcedOptionParam[] calldata _enforcedOptions) external;

    /**
     * @notice Combines options for a given endpoint and message type.
     * @param _eid The endpoint ID.
     * @param _msgType The OApp message type.
     * @param _extraOptions Additional options passed by the caller.
     * @return options The combination of caller specified options AND enforced options.
     */
    function combineOptions(
        uint32 _eid,
        uint16 _msgType,
        bytes calldata _extraOptions
    ) external view returns (bytes memory options);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import { Origin } from "./ILayerZeroEndpointV2.sol";

interface ILayerZeroReceiver {
    function allowInitializePath(Origin calldata _origin) external view returns (bool);

    function nextNonce(uint32 _eid, bytes32 _sender) external view returns (uint64);

    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable;
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

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

struct SetConfigParam {
    uint32 eid;
    uint32 configType;
    bytes config;
}

interface IMessageLibManager {
    struct Timeout {
        address lib;
        uint256 expiry;
    }

    event LibraryRegistered(address newLib);
    event DefaultSendLibrarySet(uint32 eid, address newLib);
    event DefaultReceiveLibrarySet(uint32 eid, address newLib);
    event DefaultReceiveLibraryTimeoutSet(uint32 eid, address oldLib, uint256 expiry);
    event SendLibrarySet(address sender, uint32 eid, address newLib);
    event ReceiveLibrarySet(address receiver, uint32 eid, address newLib);
    event ReceiveLibraryTimeoutSet(address receiver, uint32 eid, address oldLib, uint256 timeout);

    function registerLibrary(address _lib) external;

    function isRegisteredLibrary(address _lib) external view returns (bool);

    function getRegisteredLibraries() external view returns (address[] memory);

    function setDefaultSendLibrary(uint32 _eid, address _newLib) external;

    function defaultSendLibrary(uint32 _eid) external view returns (address);

    function setDefaultReceiveLibrary(uint32 _eid, address _newLib, uint256 _timeout) external;

    function defaultReceiveLibrary(uint32 _eid) external view returns (address);

    function setDefaultReceiveLibraryTimeout(uint32 _eid, address _lib, uint256 _expiry) external;

    function defaultReceiveLibraryTimeout(uint32 _eid) external view returns (address lib, uint256 expiry);

    function isSupportedEid(uint32 _eid) external view returns (bool);

    function isValidReceiveLibrary(address _receiver, uint32 _eid, address _lib) external view returns (bool);

    /// ------------------- OApp interfaces -------------------
    function setSendLibrary(address _oapp, uint32 _eid, address _newLib) external;

    function getSendLibrary(address _sender, uint32 _eid) external view returns (address lib);

    function isDefaultSendLibrary(address _sender, uint32 _eid) external view returns (bool);

    function setReceiveLibrary(address _oapp, uint32 _eid, address _newLib, uint256 _gracePeriod) external;

    function getReceiveLibrary(address _receiver, uint32 _eid) external view returns (address lib, bool isDefault);

    function setReceiveLibraryTimeout(address _oapp, uint32 _eid, address _lib, uint256 _gracePeriod) external;

    function receiveLibraryTimeout(address _receiver, uint32 _eid) external view returns (address lib, uint256 expiry);

    function setConfig(address _oapp, address _lib, SetConfigParam[] calldata _params) external;

    function getConfig(
        address _oapp,
        address _lib,
        uint32 _eid,
        uint32 _configType
    ) external view returns (bytes memory config);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IMessagingComposer {
    event ComposeSent(address from, address to, bytes32 guid, uint16 index, bytes message);
    event ComposeDelivered(address from, address to, bytes32 guid, uint16 index);
    event LzComposeAlert(
        address indexed from,
        address indexed to,
        address indexed executor,
        bytes32 guid,
        uint16 index,
        uint256 gas,
        uint256 value,
        bytes message,
        bytes extraData,
        bytes reason
    );

    function composeQueue(
        address _from,
        address _to,
        bytes32 _guid,
        uint16 _index
    ) external view returns (bytes32 messageHash);

    function sendCompose(address _to, bytes32 _guid, uint16 _index, bytes calldata _message) external;

    function lzCompose(
        address _from,
        address _to,
        bytes32 _guid,
        uint16 _index,
        bytes calldata _message,
        bytes calldata _extraData
    ) external payable;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IMessagingChannel {
    event InboundNonceSkipped(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce);
    event PacketNilified(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce, bytes32 payloadHash);
    event PacketBurnt(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce, bytes32 payloadHash);

    function eid() external view returns (uint32);

    // this is an emergency function if a message cannot be verified for some reasons
    // required to provide _nextNonce to avoid race condition
    function skip(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce) external;

    function nilify(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) external;

    function burn(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) external;

    function nextGuid(address _sender, uint32 _dstEid, bytes32 _receiver) external view returns (bytes32);

    function inboundNonce(address _receiver, uint32 _srcEid, bytes32 _sender) external view returns (uint64);

    function outboundNonce(address _sender, uint32 _dstEid, bytes32 _receiver) external view returns (uint64);

    function inboundPayloadHash(
        address _receiver,
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    ) external view returns (bytes32);

    function lazyInboundNonce(address _receiver, uint32 _srcEid, bytes32 _sender) external view returns (uint64);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IMessagingContext {
    function isSendingMessage() external view returns (bool);

    function getSendContext() external view returns (uint32 dstEid, address sender);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ILayerZeroEndpointV2 } from "src/vendor/layerzero/protocol/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @title IOAppCore
 */
interface IOAppCore {
    // Custom error messages
    error OnlyPeer(uint32 eid, bytes32 sender);
    error NoPeer(uint32 eid);
    error InvalidEndpointCall();
    error InvalidDelegate();

    // Event emitted when a peer (OApp) is set for a corresponding endpoint
    event PeerSet(uint32 eid, bytes32 peer);

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol contract.
     * @return receiverVersion The version of the OAppReceiver.sol contract.
     */
    function oAppVersion() external view returns (uint64 senderVersion, uint64 receiverVersion);

    /**
     * @notice Retrieves the LayerZero endpoint associated with the OApp.
     * @return iEndpoint The LayerZero endpoint as an interface.
     */
    function endpoint() external view returns (ILayerZeroEndpointV2 iEndpoint);

    /**
     * @notice Retrieves the peer (OApp) associated with a corresponding endpoint.
     * @param _eid The endpoint ID.
     * @return peer The peer address (OApp instance) associated with the corresponding endpoint.
     */
    function peers(uint32 _eid) external view returns (bytes32 peer);

    /**
     * @notice Sets the peer address (OApp instance) for a corresponding endpoint.
     * @param _eid The endpoint ID.
     * @param _peer The address of the peer to be associated with the corresponding endpoint.
     */
    function setPeer(uint32 _eid, bytes32 _peer) external;

    /**
     * @notice Sets the delegate address for the OApp Core.
     * @param _delegate The address of the delegate to be set.
     */
    function setDelegate(address _delegate) external;
}

// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {IOAppCore} from "src/vendor/layerzero-upgradeable/oapp/interfaces/IOAppCore.sol";

interface IL1SyncPool is IOAppCore {
    function onMessageReceived(uint32 originEid, bytes32 guid, address tokenIn, uint256 amountIn, uint256 amountOut)
        external
        payable;
}

// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

library Constants {
    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;
}
