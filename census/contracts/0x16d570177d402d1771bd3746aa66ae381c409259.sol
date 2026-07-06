// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1BaseReceiverUpgradeable} from "src/vendor/layerzero/syncpools/L1/L1BaseReceiverUpgradeable.sol";
import {IZkSync, L2Message} from "src/layer2/interfaces/IZkSync.sol";
import {UnsafeBytes} from "src/vendor/zksync/UnsafeBytes.sol";
import {Constants} from "src/vendor/layerzero/syncpools/libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

/**
 * @title L1 Zk Receiver ETH Pull
 * @notice L1 receiver contract for ETH
 * @dev This contract proves messages finalized by the ZkSync Era and forwards them to the L1 sync pool
 * It only supports ETH
 */
contract L1ZkReceiverETH is L1BaseReceiverUpgradeable {
    struct L1ZkReceiverStorage {
        IZkSync zksync;
        mapping(uint32 => mapping(uint256 => bool)) messageProcessed;
    }

    // keccak256(abi.encode(uint256(keccak256(l1zkreceiver.storage.l1syncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1ZkReceiverStorageLocation =
        0x9afae95578550b808d6217e490b7904a535b217c6ef95448b843ae6f03c73900;

    function _getL1ZkReceiverStorage()
        internal
        pure
        returns (L1ZkReceiverStorage storage $)
    {
        assembly {
            $.slot := L1ZkReceiverStorageLocation
        }
    }

    error FailedToProveMessageInclusion();
    error InvalidFunctionSignature();
    error MessageAlreadyProcessed();
    error CallFailed();
    error OnlySelf();

    event FinalizeSync(
        uint32 indexed blockNumber,
        uint256 indexed index,
        bytes message
    );

    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer for L1 Optimism Receiver ETH
     * @param l1SyncPool Address of the L1 sync pool
     * @param messenger Address of the messenger contract
     * @param owner Address of the owner
     */
    function initialize(
        address l1SyncPool,
        address messenger,
        address owner
    ) external initializer {
        __Ownable_init(owner);
        __L1BaseReceiver_init(l1SyncPool, messenger);
    }

    /**
     * @dev Function to receive messages from the L2 messenger
     * @param message The message received from the L2 messenger
     */
    function onMessageReceived(
        bytes calldata message
    ) public payable virtual override onlySelf {
        (
            uint32 originEid,
            bytes32 guid,
            address tokenIn,
            uint256 amountIn,
            uint256 amountOut
        ) = abi.decode(message, (uint32, bytes32, address, uint256, uint256));

        if (tokenIn != Constants.ETH_ADDRESS) revert Errors.OnlyETH();

        _forwardToL1SyncPool(
            originEid,
            _getAuthorizedL2Address(originEid),
            guid,
            tokenIn,
            amountIn,
            amountOut,
            amountIn
        );
    }

    /**
     * @notice Set the ZkSync contract address
     * @param _zksync ZkSync contract address
     */
    function setZkSync(address _zksync) external onlyOwner {
        if (_zksync == address(0)) {
            revert Errors.ZeroAddress();
        }

        _getL1ZkReceiverStorage().zksync = IZkSync(_zksync);
    }

    /**
     * @notice Get the ZkSync contract address
     * @return ZkSync contract address
     */
    function zkSync() external view returns (IZkSync) {
        return _getL1ZkReceiverStorage().zksync;
    }

    /**
     * @notice Check if the message was processed
     * @param _blockNumber zkSync block number in which the message was sent
     * @param _index The position in the L2 logs Merkle tree of the L2Log that was sent with the message
     * @return True if the message was processed
     */
    function isMessageProcessed(
        uint32 _blockNumber,
        uint256 _index
    ) external view returns (bool) {
        return _getL1ZkReceiverStorage().messageProcessed[_blockNumber][_index];
    }

    /**
     * @notice Finalize the sync by proving the message inclusion
     * @param _originEid Origin endpoint ID
     * @param _blockNumber zkSync block number in which the message was sent
     * @param _txBlockIndex Message index in the block
     * @param _index The position in the L2 logs Merkle tree of the L2Log that was sent with the message
     * @param _sender The sender address of the message
     * @param _message The message that was sent from L2
     * @param _proof Merkle proof for inclusion of L2 log that was sent with the message
     */
    function finalizeSync(
        uint32 _originEid,
        uint32 _blockNumber,
        uint16 _txBlockIndex,
        uint256 _index,
        address _sender,
        bytes calldata _message,
        bytes32[] calldata _proof
    ) external {
        L1ZkReceiverStorage storage $ = _getL1ZkReceiverStorage();

        if ($.messageProcessed[_blockNumber][_index]) {
            revert MessageAlreadyProcessed();
        }

        _checkSignatureAndCaller(_sender, _originEid, _message);

        bool success = $.zksync.proveL2MessageInclusion(
            _blockNumber,
            _index,
            L2Message({
                sender: _sender,
                data: _message,
                txNumberInBlock: _txBlockIndex
            }),
            _proof
        );
        if (!success) {
            revert FailedToProveMessageInclusion();
        }

        (bool callSuccess, ) = address(this).call(_message[76:]);
        if (!callSuccess) {
            revert CallFailed();
        }

        emit FinalizeSync(_blockNumber, _index, _message);

        $.messageProcessed[_blockNumber][_index] = true;
    }

    /**
     * @dev Internal function to forward the message to the L1 sync pool
     * @param originEid Origin endpoint ID
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount of tokens
     * @param amountOut Amount of tokens
     * @param valueToL1SyncPool Value to send to the L1 sync pool
     */
    function _forwardToL1SyncPool(
        uint32 originEid,
        bytes32,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint256 valueToL1SyncPool
    ) internal override {
        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        $.l1SyncPool.onMessageReceived{value: valueToL1SyncPool}(
            originEid,
            guid,
            tokenIn,
            amountIn,
            amountOut
        );
    }

    function _checkSignatureAndCaller(
        address _sender,
        uint32 _originEid,
        bytes calldata _message
    ) internal view {
        if (_sender != getMessenger())
            revert L1BaseReceiver__UnauthorizedCaller();

        (uint32 functionSignature, ) = UnsafeBytes.readUint32(_message, 76);
        if (bytes4(functionSignature) != this.onMessageReceived.selector) {
            revert InvalidFunctionSignature();
        }

        (address originalCaller, ) = UnsafeBytes.readAddress(_message, 56);
        if (
            _getAuthorizedL2Address(_originEid) !=
            bytes32(uint256(uint160(originalCaller)))
        ) {
            revert L1BaseReceiver__UnauthorizedL2Sender();
        }
    }

    receive() external payable {}
}

// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import {BaseMessengerUpgradeable} from "../utils/BaseMessengerUpgradeable.sol";
import {IL1SyncPool} from "../interfaces/IL1SyncPool.sol";
import {IL1Receiver} from "../interfaces/IL1Receiver.sol";

/**
 * @title L1 Base Receiver
 * @notice Base contract for L1 receivers
 * This contract is intended to receive messages from the native L2 bridge, decode the message
 * and then forward it to the L1 sync pool.
 */
abstract contract L1BaseReceiverUpgradeable is OwnableUpgradeable, BaseMessengerUpgradeable, IL1Receiver {
    struct L1BaseReceiverStorage {
        IL1SyncPool l1SyncPool;
    }

    // keccak256(abi.encode(uint256(keccak256(l1basereceiver.storage.l1syncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1BaseReceiverStorageLocation =
        0xec90cfc37697dc33dbcf188d524bdc2a41f251df5a390991a45d6388ac04b500;

    function _getL1BaseReceiverStorage() internal pure returns (L1BaseReceiverStorage storage $) {
        assembly {
            $.slot := L1BaseReceiverStorageLocation
        }
    }

    error L1BaseReceiver__UnauthorizedCaller();
    error L1BaseReceiver__UnauthorizedL2Sender();

    event L1SyncPoolSet(address l1SyncPool);

    function __L1BaseReceiver_init(address l1SyncPool, address messenger) internal onlyInitializing {
        __BaseMessenger_init(messenger);
        __L1BaseReceiver_init_unchained(l1SyncPool);
    }

    function __L1BaseReceiver_init_unchained(address l1SyncPool) internal onlyInitializing {
        _setL1SyncPool(l1SyncPool);
    }

    /**
     * @dev Get the L1 sync pool address
     * @return The L1 sync pool address
     */
    function getL1SyncPool() public view virtual returns (address) {
        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        return address($.l1SyncPool);
    }

    /**
     * @dev Set the L1 sync pool address
     * @param l1SyncPool The L1 sync pool address
     */
    function setL1SyncPool(address l1SyncPool) public virtual onlyOwner {
        _setL1SyncPool(l1SyncPool);
    }

    /**
     * @dev Internal function to set the L1 sync pool address
     * @param l1SyncPool The L1 sync pool address
     */
    function _setL1SyncPool(address l1SyncPool) internal virtual {
        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        $.l1SyncPool = IL1SyncPool(l1SyncPool);

        emit L1SyncPoolSet(l1SyncPool);
    }

    /**
     * @dev Internal function to forward the message to the L1 sync pool
     * @param originEid Origin endpoint ID
     * @param sender Sender address
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount of tokens
     * @param amountOut Amount of tokens
     * @param valueToL1SyncPool Value to send to the L1 sync pool
     */
    function _forwardToL1SyncPool(
        uint32 originEid,
        bytes32 sender,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint256 valueToL1SyncPool
    ) internal virtual {
        if (msg.sender != getMessenger()) revert L1BaseReceiver__UnauthorizedCaller();
        if (_getAuthorizedL2Address(originEid) != sender) revert L1BaseReceiver__UnauthorizedL2Sender();

        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        $.l1SyncPool.onMessageReceived{value: valueToL1SyncPool}(originEid, guid, tokenIn, amountIn, amountOut);
    }

    /**
     * @dev Internal function to get the authorized L2 address
     * @param originEid Origin endpoint ID
     * @return The authorized L2 address
     */
    function _getAuthorizedL2Address(uint32 originEid) internal view virtual returns (bytes32) {
        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        return $.l1SyncPool.peers(originEid);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @dev An arbitrary length message passed from L2
/// @notice Under the hood it is `L2Log` sent from the special system L2 contract
/// @param txNumberInBlock The L2 transaction number in a block, in which the message was sent
/// @param sender The address of the L2 account from which the message was passed
/// @param data An arbitrary length message
struct L2Message {
    uint16 txNumberInBlock;
    address sender;
    bytes data;
}

interface IZkSync {
    function proveL2MessageInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Message calldata _message,
        bytes32[] calldata _proof
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @author Matter Labs
 * @custom:security-contact security@matterlabs.dev
 * @dev The library provides a set of functions that help read data from an "abi.encodePacked" byte array.
 * @dev Each of the functions accepts the `bytes memory` and the offset where data should be read and returns a value of a certain type.
 *
 * @dev WARNING!
 * 1) Functions don't check the length of the bytes array, so it can go out of bounds.
 * The user of the library must check for bytes length before using any functions from the library!
 *
 * 2) Read variables are not cleaned up - https://docs.soliditylang.org/en/v0.8.16/internals/variable_cleanup.html.
 * Using data in inline assembly can lead to unexpected behavior!
 */
library UnsafeBytes {
    function readUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32 result, uint256 offset) {
        assembly {
            offset := add(_start, 4)
            result := mload(add(_bytes, offset))
        }
    }

    function readAddress(bytes memory _bytes, uint256 _start) internal pure returns (address result, uint256 offset) {
        assembly {
            offset := add(_start, 20)
            result := mload(add(_bytes, offset))
        }
    }

    function readUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256 result, uint256 offset) {
        assembly {
            offset := add(_start, 32)
            result := mload(add(_bytes, offset))
        }
    }

    function readBytes32(bytes memory _bytes, uint256 _start) internal pure returns (bytes32 result, uint256 offset) {
        assembly {
            offset := add(_start, 32)
            result := mload(add(_bytes, offset))
        }
    }
}
// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

library Constants {
    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant PRECISION_SUB_ONE = PRECISION - 1;
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

/**
 * @title Base Messenger
 * @dev Base contract for setting the messenger contract
 */
abstract contract BaseMessengerUpgradeable is OwnableUpgradeable {
    struct BaseMessengerStorage {
        address messenger;
    }

    // keccak256(abi.encode(uint256(keccak256(syncpools.storage.basemessenger)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BaseMessengerStorageLocation =
        0x2d365d82646798ae645c4baa2dc2ee228626f61d8b5395bf298ba125a3c6b100;

    function _getBaseMessengerStorage() internal pure returns (BaseMessengerStorage storage $) {
        assembly {
            $.slot := BaseMessengerStorageLocation
        }
    }

    event MessengerSet(address messenger);

    function __BaseMessenger_init(address messenger) internal onlyInitializing {
        __BaseMessenger_init_unchained(messenger);
    }

    function __BaseMessenger_init_unchained(address messenger) internal onlyInitializing {
        _setMessenger(messenger);
    }

    /**
     * @dev Get the messenger address
     * @return The messenger address
     */
    function getMessenger() public view virtual returns (address) {
        BaseMessengerStorage storage $ = _getBaseMessengerStorage();
        return $.messenger;
    }

    /**
     * @dev Set the messenger address
     * @param messenger The messenger address
     */
    function setMessenger(address messenger) public virtual onlyOwner {
        _setMessenger(messenger);
    }

    /**
     * @dev Internal function to set the messenger address
     * @param messenger The messenger address
     */
    function _setMessenger(address messenger) internal {
        BaseMessengerStorage storage $ = _getBaseMessengerStorage();
        $.messenger = messenger;

        emit MessengerSet(messenger);
    }
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

interface IL1Receiver {
    function onMessageReceived(bytes calldata message) external payable;
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
