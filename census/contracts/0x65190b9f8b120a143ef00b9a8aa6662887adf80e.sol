// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { GasInfo } from '../types/GasEstimationTypes.sol';
import { IInterchainGasEstimation } from './IInterchainGasEstimation.sol';
import { IUpgradable } from './IUpgradable.sol';

/**
 * @title IAxelarGasService Interface
 * @notice This is an interface for the AxelarGasService contract which manages gas payments
 * and refunds for cross-chain communication on the Axelar network.
 * @dev This interface inherits IUpgradable
 */
interface IAxelarGasService is IInterchainGasEstimation, IUpgradable {
    error InvalidAddress();
    error NotCollector();
    error InvalidAmounts();
    error InvalidGasUpdates();
    error InvalidParams();
    error InsufficientGasPayment(uint256 required, uint256 provided);

    event GasPaidForContractCall(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event GasPaidForContractCallWithToken(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        string symbol,
        uint256 amount,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event NativeGasPaidForContractCall(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event NativeGasPaidForContractCallWithToken(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        string symbol,
        uint256 amount,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event GasPaidForExpressCall(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event GasPaidForExpressCallWithToken(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        string symbol,
        uint256 amount,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event NativeGasPaidForExpressCall(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event NativeGasPaidForExpressCallWithToken(
        address indexed sourceAddress,
        string destinationChain,
        string destinationAddress,
        bytes32 indexed payloadHash,
        string symbol,
        uint256 amount,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event GasAdded(
        bytes32 indexed txHash,
        uint256 indexed logIndex,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event NativeGasAdded(bytes32 indexed txHash, uint256 indexed logIndex, uint256 gasFeeAmount, address refundAddress);

    event ExpressGasAdded(
        bytes32 indexed txHash,
        uint256 indexed logIndex,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event NativeExpressGasAdded(
        bytes32 indexed txHash,
        uint256 indexed logIndex,
        uint256 gasFeeAmount,
        address refundAddress
    );

    event Refunded(
        bytes32 indexed txHash,
        uint256 indexed logIndex,
        address payable receiver,
        address token,
        uint256 amount
    );

    /**
     * @notice Pay for gas for any type of contract execution on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to execute a remote contract.
     * @dev If estimateOnChain is true, the function will estimate the gas cost and revert if the payment is insufficient.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call
     * @param executionGasLimit The gas limit for the contract call
     * @param estimateOnChain Flag to enable on-chain gas estimation
     * @param refundAddress The address where refunds, if any, should be sent
     * @param params Additional parameters for gas payment. This can be left empty for normal contract call payments.
     */
    function payGas(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        uint256 executionGasLimit,
        bool estimateOnChain,
        address refundAddress,
        bytes calldata params
    ) external payable;

    /**
     * @notice Pay for gas using ERC20 tokens for a contract call on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to execute a remote contract.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call
     * @param gasToken The address of the ERC20 token used to pay for gas
     * @param gasFeeAmount The amount of tokens to pay for gas
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function payGasForContractCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    ) external;

    /**
     * @notice Pay for gas using ERC20 tokens for a contract call with tokens on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to execute a remote contract.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call with tokens will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call with tokens
     * @param symbol The symbol of the token to be sent with the call
     * @param amount The amount of tokens to be sent with the call
     * @param gasToken The address of the ERC20 token used to pay for gas
     * @param gasFeeAmount The amount of tokens to pay for gas
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function payGasForContractCallWithToken(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    ) external;

    /**
     * @notice Pay for gas using native currency for a contract call on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to execute a remote contract.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function payNativeGasForContractCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address refundAddress
    ) external payable;

    /**
     * @notice Pay for gas using native currency for a contract call with tokens on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to execute a remote contract.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call with tokens will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call with tokens
     * @param symbol The symbol of the token to be sent with the call
     * @param amount The amount of tokens to be sent with the call
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function payNativeGasForContractCallWithToken(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount,
        address refundAddress
    ) external payable;

    /**
     * @notice Pay for gas using ERC20 tokens for an express contract call on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to express execute a remote contract.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call
     * @param gasToken The address of the ERC20 token used to pay for gas
     * @param gasFeeAmount The amount of tokens to pay for gas
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function payGasForExpressCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    ) external;

    /**
     * @notice Pay for gas using ERC20 tokens for an express contract call with tokens on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to express execute a remote contract.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call with tokens will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call with tokens
     * @param symbol The symbol of the token to be sent with the call
     * @param amount The amount of tokens to be sent with the call
     * @param gasToken The address of the ERC20 token used to pay for gas
     * @param gasFeeAmount The amount of tokens to pay for gas
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function payGasForExpressCallWithToken(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    ) external;

    /**
     * @notice Pay for gas using native currency for an express contract call on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to execute a remote contract.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function payNativeGasForExpressCall(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        address refundAddress
    ) external payable;

    /**
     * @notice Pay for gas using native currency for an express contract call with tokens on a destination chain.
     * @dev This function is called on the source chain before calling the gateway to execute a remote contract.
     * @param sender The address making the payment
     * @param destinationChain The target chain where the contract call with tokens will be made
     * @param destinationAddress The target address on the destination chain
     * @param payload Data payload for the contract call with tokens
     * @param symbol The symbol of the token to be sent with the call
     * @param amount The amount of tokens to be sent with the call
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function payNativeGasForExpressCallWithToken(
        address sender,
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount,
        address refundAddress
    ) external payable;

    /**
     * @notice Add additional gas payment using ERC20 tokens after initiating a cross-chain call.
     * @dev This function can be called on the source chain after calling the gateway to execute a remote contract.
     * @param txHash The transaction hash of the cross-chain call
     * @param logIndex The log index for the cross-chain call
     * @param gasToken The ERC20 token address used to add gas
     * @param gasFeeAmount The amount of tokens to add as gas
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function addGas(
        bytes32 txHash,
        uint256 logIndex,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    ) external;

    /**
     * @notice Add additional gas payment using native currency after initiating a cross-chain call.
     * @dev This function can be called on the source chain after calling the gateway to execute a remote contract.
     * @param txHash The transaction hash of the cross-chain call
     * @param logIndex The log index for the cross-chain call
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function addNativeGas(
        bytes32 txHash,
        uint256 logIndex,
        address refundAddress
    ) external payable;

    /**
     * @notice Add additional gas payment using ERC20 tokens after initiating an express cross-chain call.
     * @dev This function can be called on the source chain after calling the gateway to express execute a remote contract.
     * @param txHash The transaction hash of the cross-chain call
     * @param logIndex The log index for the cross-chain call
     * @param gasToken The ERC20 token address used to add gas
     * @param gasFeeAmount The amount of tokens to add as gas
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function addExpressGas(
        bytes32 txHash,
        uint256 logIndex,
        address gasToken,
        uint256 gasFeeAmount,
        address refundAddress
    ) external;

    /**
     * @notice Add additional gas payment using native currency after initiating an express cross-chain call.
     * @dev This function can be called on the source chain after calling the gateway to express execute a remote contract.
     * @param txHash The transaction hash of the cross-chain call
     * @param logIndex The log index for the cross-chain call
     * @param refundAddress The address where refunds, if any, should be sent
     */
    function addNativeExpressGas(
        bytes32 txHash,
        uint256 logIndex,
        address refundAddress
    ) external payable;

    /**
     * @notice Updates the gas price for a specific chain.
     * @dev This function is called by the gas oracle to update the gas prices for a specific chains.
     * @param chains Array of chain names
     * @param gasUpdates Array of gas updates
     */
    function updateGasInfo(string[] calldata chains, GasInfo[] calldata gasUpdates) external;

    /**
     * @notice Allows the gasCollector to collect accumulated fees from the contract.
     * @dev Use address(0) as the token address for native currency.
     * @param receiver The address to receive the collected fees
     * @param tokens Array of token addresses to be collected
     * @param amounts Array of amounts to be collected for each respective token address
     */
    function collectFees(
        address payable receiver,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice Refunds gas payment to the receiver in relation to a specific cross-chain transaction.
     * @dev Only callable by the gasCollector.
     * @dev Use address(0) as the token address to refund native currency.
     * @param txHash The transaction hash of the cross-chain call
     * @param logIndex The log index for the cross-chain call
     * @param receiver The address to receive the refund
     * @param token The token address to be refunded
     * @param amount The amount to refund
     */
    function refund(
        bytes32 txHash,
        uint256 logIndex,
        address payable receiver,
        address token,
        uint256 amount
    ) external;

    /**
     * @notice Returns the address of the designated gas collector.
     * @return address of the gas collector
     */
    function gasCollector() external returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IGovernable } from './IGovernable.sol';
import { IImplementation } from './IImplementation.sol';

interface IAxelarGateway is IImplementation, IGovernable {
    /**********\
    |* Errors *|
    \**********/

    error NotSelf();
    error InvalidCodeHash();
    error SetupFailed();
    error InvalidAuthModule();
    error InvalidTokenDeployer();
    error InvalidAmount();
    error InvalidChainId();
    error InvalidCommands();
    error TokenDoesNotExist(string symbol);
    error TokenAlreadyExists(string symbol);
    error TokenDeployFailed(string symbol);
    error TokenContractDoesNotExist(address token);
    error BurnFailed(string symbol);
    error MintFailed(string symbol);
    error InvalidSetMintLimitsParams();
    error ExceedMintLimit(string symbol);

    /**********\
    |* Events *|
    \**********/

    event TokenSent(
        address indexed sender,
        string destinationChain,
        string destinationAddress,
        string symbol,
        uint256 amount
    );

    event ContractCall(
        address indexed sender,
        string destinationChain,
        string destinationContractAddress,
        bytes32 indexed payloadHash,
        bytes payload
    );

    event ContractCallWithToken(
        address indexed sender,
        string destinationChain,
        string destinationContractAddress,
        bytes32 indexed payloadHash,
        bytes payload,
        string symbol,
        uint256 amount
    );

    event Executed(bytes32 indexed commandId);

    event TokenDeployed(string symbol, address tokenAddresses);

    event ContractCallApproved(
        bytes32 indexed commandId,
        string sourceChain,
        string sourceAddress,
        address indexed contractAddress,
        bytes32 indexed payloadHash,
        bytes32 sourceTxHash,
        uint256 sourceEventIndex
    );

    event ContractCallApprovedWithMint(
        bytes32 indexed commandId,
        string sourceChain,
        string sourceAddress,
        address indexed contractAddress,
        bytes32 indexed payloadHash,
        string symbol,
        uint256 amount,
        bytes32 sourceTxHash,
        uint256 sourceEventIndex
    );

    event ContractCallExecuted(bytes32 indexed commandId);

    event TokenMintLimitUpdated(string symbol, uint256 limit);

    event OperatorshipTransferred(bytes newOperatorsData);

    event Upgraded(address indexed implementation);

    /********************\
    |* Public Functions *|
    \********************/

    function sendToken(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata symbol,
        uint256 amount
    ) external;

    function callContract(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload
    ) external;

    function callContractWithToken(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount
    ) external;

    function isContractCallApproved(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        address contractAddress,
        bytes32 payloadHash
    ) external view returns (bool);

    function isContractCallAndMintApproved(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        address contractAddress,
        bytes32 payloadHash,
        string calldata symbol,
        uint256 amount
    ) external view returns (bool);

    function validateContractCall(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) external returns (bool);

    function validateContractCallAndMint(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash,
        string calldata symbol,
        uint256 amount
    ) external returns (bool);

    /***********\
    |* Getters *|
    \***********/

    function authModule() external view returns (address);

    function tokenDeployer() external view returns (address);

    function tokenMintLimit(string memory symbol) external view returns (uint256);

    function tokenMintAmount(string memory symbol) external view returns (uint256);

    function allTokensFrozen() external view returns (bool);

    function implementation() external view returns (address);

    function tokenAddresses(string memory symbol) external view returns (address);

    function tokenFrozen(string memory symbol) external view returns (bool);

    function isCommandExecuted(bytes32 commandId) external view returns (bool);

    /************************\
    |* Governance Functions *|
    \************************/

    function setTokenMintLimits(string[] calldata symbols, uint256[] calldata limits) external;

    function upgrade(
        address newImplementation,
        bytes32 newImplementationCodeHash,
        bytes calldata setupParams
    ) external;

    /**********************\
    |* External Functions *|
    \**********************/

    function execute(bytes calldata input) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// General interface for upgradable contracts
interface IContractIdentifier {
    /**
     * @notice Returns the contract ID. It can be used as a check during upgrades.
     * @dev Meant to be overridden in derived contracts.
     * @return bytes32 The contract ID
     */
    function contractId() external pure returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title IGovernable Interface
 * @notice This is an interface used by the AxelarGateway contract to manage governance and mint limiter roles.
 */
interface IGovernable {
    error NotGovernance();
    error NotMintLimiter();
    error InvalidGovernance();
    error InvalidMintLimiter();

    event GovernanceTransferred(address indexed previousGovernance, address indexed newGovernance);
    event MintLimiterTransferred(address indexed previousGovernance, address indexed newGovernance);

    /**
     * @notice Returns the governance address.
     * @return address of the governance
     */
    function governance() external view returns (address);

    /**
     * @notice Returns the mint limiter address.
     * @return address of the mint limiter
     */
    function mintLimiter() external view returns (address);

    /**
     * @notice Transfer the governance role to another address.
     * @param newGovernance The new governance address
     */
    function transferGovernance(address newGovernance) external;

    /**
     * @notice Transfer the mint limiter role to another address.
     * @param newGovernance The new mint limiter address
     */
    function transferMintLimiter(address newGovernance) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IContractIdentifier } from './IContractIdentifier.sol';

interface IImplementation is IContractIdentifier {
    error NotProxy();

    function setup(bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { GasEstimationType, GasInfo } from '../types/GasEstimationTypes.sol';

/**
 * @title IInterchainGasEstimation Interface
 * @notice This is an interface for the InterchainGasEstimation contract
 * which allows for estimating gas fees for cross-chain communication on the Axelar network.
 */
interface IInterchainGasEstimation {
    error UnsupportedEstimationType(GasEstimationType gasEstimationType);

    /**
     * @notice Event emitted when the gas price for a specific chain is updated.
     * @param chain The name of the chain
     * @param info The gas info for the chain
     */
    event GasInfoUpdated(string chain, GasInfo info);

    /**
     * @notice Returns the gas price for a specific chain.
     * @param chain The name of the chain
     * @return gasInfo The gas info for the chain
     */
    function getGasInfo(string calldata chain) external view returns (GasInfo memory);

    /**
     * @notice Estimates the gas fee for a cross-chain contract call.
     * @param destinationChain Axelar registered name of the destination chain
     * @param destinationAddress Destination contract address being called
     * @param executionGasLimit The gas limit to be used for the destination contract execution,
     *        e.g. pass in 200k if your app consumes needs upto 200k for this contract call
     * @param params Additional parameters for the gas estimation
     * @return gasEstimate The cross-chain gas estimate, in terms of source chain's native gas token that should be forwarded to the gas service.
     */
    function estimateGasFee(
        string calldata destinationChain,
        string calldata destinationAddress,
        bytes calldata payload,
        uint256 executionGasLimit,
        bytes calldata params
    ) external view returns (uint256 gasEstimate);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title IOwnable Interface
 * @notice IOwnable is an interface that abstracts the implementation of a
 * contract with ownership control features. It's commonly used in upgradable
 * contracts and includes the functionality to get current owner, transfer
 * ownership, and propose and accept ownership.
 */
interface IOwnable {
    error NotOwner();
    error InvalidOwner();
    error InvalidOwnerAddress();

    event OwnershipTransferStarted(address indexed newOwner);
    event OwnershipTransferred(address indexed newOwner);

    /**
     * @notice Returns the current owner of the contract.
     * @return address The address of the current owner
     */
    function owner() external view returns (address);

    /**
     * @notice Returns the address of the pending owner of the contract.
     * @return address The address of the pending owner
     */
    function pendingOwner() external view returns (address);

    /**
     * @notice Transfers ownership of the contract to a new address
     * @param newOwner The address to transfer ownership to
     */
    function transferOwnership(address newOwner) external;

    /**
     * @notice Proposes to transfer the contract's ownership to a new address.
     * The new owner needs to accept the ownership explicitly.
     * @param newOwner The address to transfer ownership to
     */
    function proposeOwnership(address newOwner) external;

    /**
     * @notice Transfers ownership to the pending owner.
     * @dev Can only be called by the pending owner
     */
    function acceptOwnership() external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IOwnable } from './IOwnable.sol';
import { IImplementation } from './IImplementation.sol';

// General interface for upgradable contracts
interface IUpgradable is IOwnable, IImplementation {
    error InvalidCodeHash();
    error InvalidImplementation();
    error SetupFailed();

    event Upgraded(address indexed newImplementation);

    function implementation() external view returns (address);

    function upgrade(
        address newImplementation,
        bytes32 newImplementationCodeHash,
        bytes calldata params
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title AddressBytesUtils
 * @dev This library provides utility functions to convert between `address` and `bytes`.
 */
library AddressBytes {
    error InvalidBytesLength(bytes bytesAddress);

    /**
     * @dev Converts a bytes address to an address type.
     * @param bytesAddress The bytes representation of an address
     * @return addr The converted address
     */
    function toAddress(bytes memory bytesAddress) internal pure returns (address addr) {
        if (bytesAddress.length != 20) revert InvalidBytesLength(bytesAddress);

        assembly {
            addr := mload(add(bytesAddress, 20))
        }
    }

    /**
     * @dev Converts an address to bytes.
     * @param addr The address to be converted
     * @return bytesAddress The bytes representation of the address
     */
    function toBytes(address addr) internal pure returns (bytes memory bytesAddress) {
        bytesAddress = new bytes(20);
        // we can test if using a single 32 byte variable that is the address with the length together and using one mstore would be slightly cheaper.
        assembly {
            mstore(add(bytesAddress, 20), addr)
            mstore(bytesAddress, 20)
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title GasEstimationType
 * @notice This enum represents the gas estimation types for different chains.
 */
enum GasEstimationType {
    Default,
    OptimismEcotone,
    OptimismBedrock,
    Arbitrum,
    Scroll
}

/**
 * @title GasInfo
 * @notice This struct represents the gas pricing information for a specific chain.
 * @dev Smaller uint types are used for efficient struct packing to save storage costs.
 */
struct GasInfo {
    /// @dev Custom gas pricing rule, such as L1 data fee on L2s
    uint64 gasEstimationType;
    /// @dev Scalar value needed for specific gas estimation types, expected to be less than 1e10
    uint64 l1FeeScalar;
    /// @dev Axelar base fee for cross-chain message approval on destination, in terms of source native gas token
    uint128 axelarBaseFee;
    /// @dev Gas price of destination chain, in terms of the source chain token, i.e dest_gas_price * dest_token_market_price / src_token_market_price
    uint128 relativeGasPrice;
    /// @dev Needed for specific gas estimation types. Blob base fee of destination chain, in terms of the source chain token, i.e dest_blob_base_fee * dest_token_market_price / src_token_market_price
    uint128 relativeBlobBaseFee;
    /// @dev Axelar express fee for express execution, in terms of source chain token
    uint128 expressFee;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ContextUpgradeable} from "../utils/ContextUpgradeable.sol";
import {ERC165Upgradeable} from "../utils/introspection/ERC165Upgradeable.sol";
import {Initializable} from "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControl, ERC165Upgradeable {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;


    /// @custom:storage-location erc7201:openzeppelin.storage.AccessControl
    struct AccessControlStorage {
        mapping(bytes32 role => RoleData) _roles;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.AccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AccessControlStorageLocation = 0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;

    function _getAccessControlStorage() private pure returns (AccessControlStorage storage $) {
        assembly {
            $.slot := AccessControlStorageLocation
        }
    }

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        return $._roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        AccessControlStorage storage $ = _getAccessControlStorage();
        bytes32 previousAdminRole = getRoleAdmin(role);
        $._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (!hasRole(role, account)) {
            $._roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        AccessControlStorage storage $ = _getAccessControlStorage();
        if (hasRole(role, account)) {
            $._roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
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
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.20;

import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {Initializable} from "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
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
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC1967-compliant implementation pointing to self.
     * See {_onlyProxy}.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
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
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Initializable} from "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
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
// OpenZeppelin Contracts (last updated v5.0.0) (access/IAccessControl.sol)

pragma solidity ^0.8.20;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.20;

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
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.20;

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
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.20;

import {IBeacon} from "../beacon/IBeacon.sol";
import {Address} from "../../utils/Address.sol";
import {StorageSlot} from "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 */
library ERC1967Utils {
    // We re-declare ERC-1967 events here because they can't be used directly from IERC1967.
    // This will be fixed in Solidity 0.8.21. At that point we should remove these events.
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
     * @dev Stores a new address in the EIP1967 implementation slot.
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
        emit Upgraded(newImplementation);

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
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
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
        emit AdminChanged(getAdmin(), newAdmin);
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
     * @dev Stores a new beacon in the EIP1967 beacon slot.
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
        emit BeaconUpgraded(newBeacon);

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
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.20;

import {IERC165} from "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
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
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
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
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
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
     * - The `operator` cannot be the address zero.
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
// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
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
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
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
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
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

pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import "../utils/AddressTracker.sol";
import {AddressBytes} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressBytes.sol";
import {IInterchainNftExecutable} from "../interfaces/IInterchainNftExecutable.sol";
import {IERC20MintableBurnable} from "../interfaces/IERC20MintableBurnable.sol";
import {SafeTokenCall} from "../libs/SafeTransfer.sol";
import "../interfaces/IBaseKemi.sol";
import "../interfaces/IWearable.sol";
import "../interfaces/INftManager.sol";
import "../interfaces/IKemi.sol";
import "../interfaces/ICatgirlNFT.sol";

/**
 * @title NFTManager
 * @notice This contract is responsible for managing NFT, such as setting locking nft, for interchain transfers.
 */
contract NftManager is
    Initializable,
    AddressTracker,
    INftManager,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    using AddressBytes for bytes;
    using AddressBytes for address;
    using SafeTokenCall for IERC20MintableBurnable;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant OPERATOR = keccak256("OPERATOR");

    uint256 internal constant UINT256_MAX = type(uint256).max;
    ICatgirlNFT catgirlNft;
    IBaseKemi public baseKemiNFT;
    IWearable public wearableNFT;
    IKemi public kemiNFT;
    IAxelarGateway public gateway;
    IAxelarGasService public gasService;
    /**
     * @dev Latest version of metadata that's supported.
     */
    enum MetadataVersion {
        CONTRACT_CALL,
        EXPRESS_CALL
    }

    enum NftType {
        BASEKEMI,
        WEARABLE,
        KEMI,
        CATGIRL
    }
    bytes32 private constant EXECUTE_SUCCESS = keccak256("its-execute-success");
    bytes32 private constant EXPRESS_EXECUTE_SUCCESS =
        keccak256("its-express-execute-success");
    uint256 private constant MESSAGE_TYPE_INTERCHAIN_TRANSFER = 0;
    uint32 internal constant LATEST_METADATA_VERSION = 1;
    uint32 public nftTransferLimit;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*
     * @notice Constructs the TokenManager contract.
     * @param interchainTokenService_ The address of the interchain token service.
     */
    function initialize(
        address defaultAdmin_,
        address gasService_,
        address gateway_,
        address[] calldata nftAddressList_, // Avoid stack too deep
        bytes calldata params_
    ) public initializer {
        // Initialize the contract roles.
        _init(defaultAdmin_, gasService_, gateway_, nftAddressList_, params_);
    }

    function _init(
        address defaultAdmin,
        address gasService_,
        address gateway_,
        address[] calldata nftAddressList, // Avoid stack too deep
        bytes calldata params
    ) internal {
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(OPERATOR, defaultAdmin);

        gasService = IAxelarGasService(gasService_);
        gateway = IAxelarGateway(gateway_);
        nftTransferLimit = 100;
        baseKemiNFT = IBaseKemi(nftAddressList[0]);
        wearableNFT = IWearable(nftAddressList[1]);
        kemiNFT = IKemi(nftAddressList[2]);
        catgirlNft = ICatgirlNFT(nftAddressList[3]);
        (
            string memory chainName_,
            string[] memory trustedChainNames,
            string[] memory trustedAddresses
        ) = abi.decode(params, (string, string[], string[]));
        _setChainName(chainName_);
        if (
            bytes(chainName_).length == 0 ||
            trustedChainNames.length != trustedAddresses.length
        ) revert InvalidChainName();
        for (uint256 i; i < trustedChainNames.length; ++i) {
            _setTrustedAddress(trustedChainNames[i], trustedAddresses[i]);
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /*******\
    MODIFIERS
    \*******/

    /**
     * @notice This modifier is used to ensure that only a remote Manager can invoke the execute function.
     * @param sourceChain The source chain of the contract call.
     * @param sourceAddress The source address that the call came from.
     */
    modifier onlyRemoteManager(
        string calldata sourceChain,
        string calldata sourceAddress
    ) {
        if (!isTrustedAddress(sourceChain, sourceAddress))
            revert NotRemoteService();

        _;
    }

    function setGateway(address gateway_) external onlyRole(OPERATOR) {
        gateway = IAxelarGateway(gateway_);
        emit GatewayChanged(gateway_);
    }

    function setBaseKemiNft(address baseKemiNFT_) external onlyRole(OPERATOR) {
        baseKemiNFT = IBaseKemi(baseKemiNFT_);
        emit BaseKemiNftChanged(baseKemiNFT_);
    }

    function setWearableNft(address wearableNFT_) external onlyRole(OPERATOR) {
        wearableNFT = IWearable(wearableNFT_);
        emit WearableNftChanged(wearableNFT_);
    }

    function setKemi(address kemiNft_) external onlyRole(OPERATOR) {
        kemiNFT = IKemi(kemiNft_);
        emit KemiNftChanged(kemiNft_);
    }

    function setCatgirlNft(address catgirlNft_) external onlyRole(OPERATOR) {
        catgirlNft = ICatgirlNFT(catgirlNft_);
        emit CatgirlNftChanged(catgirlNft_);
    }
    function setGasService(address gasService_) external onlyRole(OPERATOR) {
        gasService = IAxelarGasService(gasService_);
        emit GasServiceChanged(gasService_);
    }
    function setNftTransferLimit(uint32 nftTransferLimit_)
        external
        onlyRole(OPERATOR)
    {
        nftTransferLimit = nftTransferLimit_;
    }

    /************\
    USER FUNCTIONS
    \************/
    /**
     * @notice Executes operations based on the payload and selector.
     * @param commandId The unique message id.
     * @param sourceChain The chain where the transaction originates from.
     * @param sourceAddress The address of the remote ITS where the transaction originates from.
     * @param payload The encoded data payload for the transaction.
     */
    function execute(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) external onlyRemoteManager(sourceChain, sourceAddress) whenNotPaused {
        if (
            !gateway.validateContractCall(
                commandId,
                sourceChain,
                sourceAddress,
                keccak256(payload)
            )
        ) revert NotApprovedByGateway();

        _execute(commandId, sourceChain, payload);
    }

    /**
     * @notice Initiates an interchain transfer
     * @param destinationChain The destination chain to send the tokens to.
     * @param destinationAddress The address on the destination chain to send the tokens to.
     * @param nftTokenIds TokenIDs of the NFT to be transferred.
     * @param metadata Optional metadata for the call for additional effects (such as calling a destination contract).
     */
    function interchainTransfer(
        string calldata destinationChain,
        bytes calldata destinationAddress,
        uint256[] calldata nftTokenIds,
        NftType[] calldata nftTypes,
        bytes calldata metadata,
        uint256 gasValue
    ) external payable whenNotPaused {
        (MetadataVersion metadataVersion, bytes memory data) = _decodeMetadata(
            metadata
        );
        require(
            nftTokenIds.length == nftTypes.length,
            "NftManager: Invalid nftTokenIds and nftTypes length"
        );
        require(
            nftTokenIds.length <= nftTransferLimit,
            "NftManager: Exceed nftTransferLimit"
        );
        _takeNft(nftTokenIds, nftTypes);
        _transmitInterchainTransfer(
            msg.sender,
            destinationChain,
            destinationAddress,
            nftTokenIds,
            nftTypes,
            metadataVersion,
            data,
            gasValue
        );
    }

    /****************\
    INTERNAL FUNCTIONS
    \****************/

    /**
     * @notice Processes the payload data for a send token call.
     * @param commandId The unique message id.
     * @param sourceChain The chain where the transaction originates from.
     * @param payload The encoded data payload to be processed.
     */
    function _processInterchainTransferPayload(
        bytes32 commandId,
        string calldata sourceChain,
        bytes calldata payload
    ) internal {
        address destinationAddress;
        bytes[] memory callDatas;
        bytes memory data;
        bytes memory sourceAddressBytes;
        uint256[] memory nftTypes;
        {
            bytes memory destinationAddressBytes;
            (
                ,
                sourceAddressBytes,
                destinationAddressBytes,
                callDatas,
                nftTypes,
                data
            ) = abi.decode(
                payload,
                (uint256, bytes, bytes, bytes[], uint256[], bytes)
            );
            destinationAddress = destinationAddressBytes.toAddress();
        }
        uint8[] memory countNft = new uint8[](4);
        for (uint8 i = 0; i < callDatas.length; i++) {
            if (nftTypes[i] == uint256(NftType.BASEKEMI)) {
                countNft[0]++; // 0: NFType.BASEKEMI
            }
            if (nftTypes[i] == uint256(NftType.WEARABLE)) {
                countNft[1]++; // 1: NFType.WEARABLE
            }
            if (nftTypes[i] == uint256(NftType.KEMI)) {
                countNft[2]++; // 2: NFType.KEMI
            }
            if (nftTypes[i] == uint256(NftType.CATGIRL)) {
                countNft[3]++; // 3: NFType.CATGIRL
            }
        }
        mintNft(callDatas, nftTypes, countNft);

        emit InterchainTransferReceived(
            commandId,
            sourceChain,
            sourceAddressBytes,
            destinationAddress,
            data,
            data.length == 0 ? bytes32(0) : keccak256(data)
        );
        if (data.length != 0) {
            bytes32 result = IInterchainNftExecutable(destinationAddress)
                .executeWithInterchainToken(
                    commandId,
                    sourceChain,
                    sourceAddressBytes,
                    callDatas,
                    data,
                    nftTypes
                );

            if (result != EXECUTE_SUCCESS)
                revert ExecuteWithInterchainTokenFailed(destinationAddress);
        }
    }
    function mintNft(
        bytes[] memory callDatas,
        uint256[] memory nftTypes,
        uint8[] memory countNft
    ) internal {
        bytes[] memory catgirlCallDatas = new bytes[](countNft[3]);
        bytes[] memory baseKemiCallDatas = new bytes[](countNft[0]);
        bytes[] memory wearableCallDatas = new bytes[](countNft[1]);

        bytes[] memory kemiCallDatas = new bytes[](countNft[2]);
        uint16[][] memory wearableList = new uint16[][](countNft[2]);
        uint8 countKemiCurrent = 0;
        address[] memory kemiUsers = new address[](countNft[2]);
        for (uint8 i = 0; i < callDatas.length; i++) {
            if (nftTypes[i] == uint256(NftType.CATGIRL)) {
                catgirlCallDatas[i] = callDatas[i];
            }
            if (nftTypes[i] == uint256(NftType.BASEKEMI)) {
                baseKemiCallDatas[i] = callDatas[i];
            }
            if (nftTypes[i] == uint256(NftType.WEARABLE)) {
                wearableCallDatas[i] = callDatas[i];
            }
            if (nftTypes[i] == uint256(NftType.KEMI)) {
                address to;
                uint16 raceId;
                uint16[] memory wearableIds;
                string memory tokenURI;
                string memory name;
                (to, raceId, wearableIds, tokenURI, name) = abi.decode(
                    callDatas[i],
                    (address, uint16, uint16[], string, string)
                );
                kemiUsers[countKemiCurrent] = to;
                wearableList[countKemiCurrent] = wearableIds;
                countKemiCurrent++;
                kemiCallDatas[i] = callDatas[i];
            }
        }

        if (countNft[0] > 0) {
            baseKemiNFT.mintByMananger(baseKemiCallDatas);
        }
        if (countNft[1] > 0) {
            wearableNFT.mintByMananger(wearableCallDatas);
        }
        if (countNft[2] > 0) {
            uint256[][] memory wearableTokenIds = new uint256[][](countNft[2]);
            wearableTokenIds = wearableNFT.mintForKemi(
                wearableList,
                address(kemiNFT)
            );
            kemiNFT.mintByMananger(kemiCallDatas, wearableTokenIds);
        }
        if (countNft[3] > 0) {
            catgirlNft.mintByMananger(catgirlCallDatas);
        }
    }
    /**
     * @notice Calls a contract on a specific destination chain with the given payload
     * @param destinationChain The target chain where the contract will be called.
     * @param payload The data payload for the transaction.
     * @param gasValue The amount of gas to be paid for the transaction.
     */
    function _callContract(
        string calldata destinationChain,
        bytes memory payload,
        MetadataVersion metadataVersion,
        uint256 gasValue
    ) internal {
        string memory destinationAddress = trustedAddress(destinationChain);
        if (bytes(destinationAddress).length == 0) revert UntrustedChain();

        if (gasValue > 0) {
            if (metadataVersion == MetadataVersion.CONTRACT_CALL) {
                gasService.payNativeGasForContractCall{value: gasValue}(
                    address(this),
                    destinationChain,
                    destinationAddress,
                    payload, // solhint-disable-next-line avoid-tx-origin
                    tx.origin
                );
            } else {
                revert InvalidMetadataVersion(uint32(metadataVersion));
            }
        }

        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    function _execute(
        bytes32 commandId,
        string calldata sourceChain,
        bytes calldata payload
    ) internal {
        uint256 messageType = abi.decode(payload, (uint256));
        if (messageType != MESSAGE_TYPE_INTERCHAIN_TRANSFER) {
            revert InvalidMessageType(messageType);
        }
        _processInterchainTransferPayload(commandId, sourceChain, payload);
    }

    /**
     * @notice Decodes the metadata into a version number and data bytes.
     * @dev The function expects the metadata to have the version in the first 4 bytes, followed by the actual data.
     * @param metadata The bytes containing the metadata to decode.
     * @return version The version number extracted from the metadata.
     * @return data The data bytes extracted from the metadata.
     */
    function _decodeMetadata(
        bytes calldata metadata
    ) internal pure returns (MetadataVersion version, bytes memory data) {
        if (metadata.length < 4) return (MetadataVersion.CONTRACT_CALL, data);

        uint32 versionUint = uint32(bytes4(metadata[:4]));
        if (versionUint > LATEST_METADATA_VERSION)
            revert InvalidMetadataVersion(versionUint);

        version = MetadataVersion(versionUint);

        if (metadata.length == 4) return (version, data);

        data = metadata[4:];
    }

    /**
     * @notice Transmit a callContractWithInterchainToken for the given tokenId.
     * @param sourceAddress The address where the token is coming from, which will also be used for gas reimbursement.
     * @param destinationChain The name of the chain to send tokens to.
     * @param destinationAddress The destinationAddress for the interchainTransfer.
     * @param metadataVersion The version of the metadata.
     * @param data The data to be passed with the token transfer.
     */
    function _transmitInterchainTransfer(
        address sourceAddress,
        string calldata destinationChain,
        bytes memory destinationAddress,
        uint256[] calldata nftTokenIds,
        NftType[] calldata nftTypes,
        MetadataVersion metadataVersion,
        bytes memory data,
        uint256 gasValue
    ) internal {
        bytes[] memory mintNftPayloads = new bytes[](nftTokenIds.length);
        for (uint8 i = 0; i < nftTokenIds.length; i++) {
            mintNftPayloads[i] = getpayloadMintNFT(
                nftTypes[i],
                sourceAddress,
                nftTokenIds[i]
            );
            emit InterchainTransfer(
                sourceAddress,
                destinationChain,
                destinationAddress,
                nftTokenIds[i],
                uint256(nftTypes[i]),
                data.length == 0 ? bytes32(0) : keccak256(data)
            );
        }
        bytes memory payload = abi.encode(
            MESSAGE_TYPE_INTERCHAIN_TRANSFER,
            sourceAddress.toBytes(),
            destinationAddress,
            mintNftPayloads,
            nftTypes,
            data
        );
        _callContract(destinationChain, payload, metadataVersion, gasValue);
    }

    function getpayloadMintNFT(
        NftType nftType,
        address sourceAddress,
        uint256 nftTokenId
    ) internal view returns (bytes memory mintNftPayload) {
        if (nftType == NftType.CATGIRL) {
            ICatgirlNFT.CatgirlDetails memory catgirl = catgirlNft.getCatgirl(
                nftTokenId
            );
            mintNftPayload = abi.encode(
                sourceAddress,
                catgirl.characterId,
                catgirl.season,
                catgirl.rarity,
                catgirl.nyaScore
            );
        }
        if (nftType == NftType.BASEKEMI) {
            IBaseKemi.BaseDetails memory baseKemi = baseKemiNFT.getBaseKemi(
                nftTokenId
            );
            mintNftPayload = abi.encode(
                sourceAddress,
                baseKemi.raceId,
                baseKemi.facialExpressionId,
                baseKemi.skinId,
                baseKemi.tailId,
                baseKemi.faceShapeId
            );
        }
        if (nftType == NftType.WEARABLE) {
            IWearable.WearableDetails memory wearable = wearableNFT.getWearable(
                nftTokenId
            );
            mintNftPayload = abi.encode(sourceAddress, wearable.wearableId);
        }
        if (nftType == NftType.KEMI) {
            IKemi.KemiDetails memory kemi = kemiNFT.getKemi(nftTokenId);
            uint16[] memory wearableIds = new uint16[](
                kemi.wearableTokenIds.length
            );
            for (uint8 i = 0; i < wearableIds.length; i++) {
                wearableIds[i] = wearableNFT
                    .getWearable(kemi.wearableTokenIds[i])
                    .wearableId;
            }
            mintNftPayload = abi.encode(
                sourceAddress,
                kemi.raceId,
                kemi.name,
                kemi.tokenURI,
                wearableIds
            );
        }
    }

    function _takeNft(
        uint256[] calldata nftTokenIds,
        NftType[] calldata nftTypes
    ) internal {
        for (uint8 i = 0; i < nftTokenIds.length; i++) {
            uint256 nftTokenId = nftTokenIds[i];
            NftType nftType = nftTypes[i];
            if (nftType == NftType.BASEKEMI) {
                baseKemiNFT.burn(nftTokenId);
            }
            if (nftType == NftType.WEARABLE) {
                wearableNFT.burn(nftTokenId);
            }
            if (nftType == NftType.KEMI) {
                kemiNFT.burnKemi(nftTokenId);
            }
            if (nftType == NftType.CATGIRL) {
                catgirlNft.burn(nftTokenId);
            }
        }
    }
}

pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IBaseKemi is IERC721 {
    struct BaseDetails {
        uint16 raceId;
        uint16 facialExpressionId;
        uint16 faceShapeId;
        uint16 skinId;
        uint16 tailId;
    }

    function externalMint(
        address _to,
        uint16 _raceId,
        uint16 _facialExpressionId,
        uint16 _skinId,
        uint16 _tailId,
        uint16 _faceShapeId
    ) external returns (uint256);
    function mintByMananger(bytes[] memory callDatas) external;
    function getFaceIdList() external view returns (uint16[] memory);

    function getSkinToneIdList() external view returns (uint16[] memory);

    function getRaceIdList() external view returns (uint16[] memory);

    function mintByRandom(
        uint256 _requestId,
        uint256 _catgirlTokenId,
        uint256 _rand,
        address _user
    ) external;

    function burn(uint256 tokenId) external;

    function getTailListByRaceId(
        uint16 raceId
    ) external view returns (uint16[] memory);

    function getDroprateFaceId() external view returns (uint16[] memory);

    function getDroprateSkinTone() external view returns (uint16[] memory);

    function getDroprateRaceId() external view returns (uint16[] memory);

    function getDroprateByTailId(uint16 tailId) external view returns (uint16);

    function getBaseKemi(
        uint256 tokenId
    ) external view returns (BaseDetails memory baseKemi);
}

pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ICatgirlNFT is IERC721{
    struct CatgirlDetails {
        uint32 characterId;
        uint32 season;
        uint8 rarity;
        uint32 nyaScore;
    }

    function getCatgirl(uint256 tokenId) external view returns (CatgirlDetails memory catgirl);
    // Need to upgrade catgirl contract
    function getMaxNyaScore() external view returns (uint32 maxNyaScore);
    function openBoxes(address to, uint64 _boxId, uint32 _season, uint8 _numberOfBoxes, uint _rand) external;
    function openPendingBoxes(address to, uint64[] calldata boxIds, uint32 _season, uint8[] calldata _numberOfPendingBoxes, uint[] calldata _rand, uint totalBox) external;
    function externalMint(
        address to,
        uint8 rarity,
        uint32 nyaScore,
        uint32 season,
        uint32 characterId) external returns (uint256);
    function setBaseURI(string memory _uri) external;
    function burnMultiple(uint[] memory tokenIds) external;
    function burn(uint256 tokenId) external;
    function mintByMananger(
        bytes[] memory callDatas
    ) external;
    function rebornCatgirl(uint256 _tokenId, uint32 _nyaScore, uint8 _rarity, uint32 _season, uint32 _characterId) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title IERC20MintableBurnable Interface
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20MintableBurnable is IERC20 {
    /**
     * @notice Function to mint new tokens.
     * @dev Can only be called by the minter address.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Function to burn tokens.
     * @param value The amount of tokens to burn.
     */
    function burn(uint256 value) external;
    /**
     * @notice Function to burn tokens from address.
     * @dev Can only be called by the minter address.
     * @param account The address that will have its tokens burnt.
     * @param value The amount of tokens to burn.
     */

    function burnFrom(address account, uint256 value) external;

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

pragma solidity ^0.8.20;

/**
 * @title FlowLimit Interface
 * @notice Interface for flow limit logic for interchain token transfers.
 */
interface IFlowLimit {
    error FlowLimitExceeded(uint256 limit, uint256 flowAmount, address tokenManager);

    event FlowLimitSet(bytes32 indexed tokenId, address operator, uint256 flowLimit_);

    /**
     * @notice Returns the current flow limit.
     * @return flowLimit_ The current flow limit value.
     */
    function flowLimit() external view returns (uint256 flowLimit_);

    /**
     * @notice Returns the current flow out amount.
     * @return flowOutAmount_ The current flow out amount.
     */
    function flowOutAmount() external view returns (uint256 flowOutAmount_);

    /**
     * @notice Returns the current flow in amount.
     * @return flowInAmount_ The current flow in amount.
     */
    function flowInAmount() external view returns (uint256 flowInAmount_);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IInterchainAddressTracker
 * @dev Manages trusted addresses by chain, keeps track of addresses supported by the Axelar gateway contract
 */
interface IInterchainAddressTracker {
    error ZeroAddress();
    error LengthMismatch();
    error ZeroStringLength();
    error UntrustedChain();

    event TrustedAddressSet(string chain, string address_);
    event TrustedAddressRemoved(string chain);

    /**
     * @dev Gets the name of the chain this is deployed at
     */
    function chainName() external view returns (string memory);

    /**
     * @dev Gets the trusted address at a remote chain
     * @param chain Chain name of the remote chain
     * @return trustedAddress_ The trusted address for the chain. Returns '' if the chain is untrusted
     */
    function trustedAddress(string memory chain) external view returns (string memory trustedAddress_);

    /**
     * @dev Gets the trusted address hash for a chain
     * @param chain Chain name
     * @return trustedAddressHash_ the hash of the trusted address for that chain
     */
    function trustedAddressHash(string memory chain) external view returns (bytes32 trustedAddressHash_);

    /**
     * @dev Checks whether the interchain sender is a trusted address
     * @param chain Chain name of the sender
     * @param address_ Address of the sender
     * @return bool true if the sender chain/address are trusted, false otherwise
     */
    function isTrustedAddress(string calldata chain, string calldata address_) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title IInterchainNftExecutable
 * @notice Contracts should implement this interface to accept calls from the InterchainTokenService.
 */
interface IInterchainNftExecutable {
    enum NftType {
        BASEKEMI,
        WEARABLE
    }
    /**
     * @notice This will be called after the tokens are sent to this contract.
     * @dev Execution should revert unless the msg.sender is the InterchainTokenService
     * @param commandId The unique message id for the call.
     * @param sourceChain The name of the source chain.
     * @param sourceAddress The address that sent the contract call.
     * @param callData Call data to contract
     * @param data The data to be processed.
     * @param nftType Nft type of the NFT
     * @return bytes32 Hash indicating success of the execution.
     */
    function executeWithInterchainToken(
        bytes32 commandId,
        string calldata sourceChain,
        bytes calldata sourceAddress,
        bytes[] calldata callData,
        bytes calldata data,
        uint256[] calldata nftType
    ) external returns (bytes32);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKemi {
    struct KemiDetails {
        uint16 raceId;
        uint256[] wearableTokenIds;
        uint256 baseKemiTokenId;
        string tokenURI;
        string name;
    }
    function getKemi(
        uint256 _tokenId
    ) external view returns (KemiDetails memory kemi);
    function burnKemi(uint256 _tokenId) external;
    function breakKemiByRand(
        uint256 _kemiTokenId,
        uint256 _rand
    ) external;
    function mintByMananger(
        bytes[] calldata _callDatas,
        uint256[][] calldata _wearableTokenIds
    ) external;
    function mintKemiByMinter(
        address _to,
        string memory _tokenURI,
        uint256[] memory _wearableTokenIds,
        uint16 _raceId,
        string memory _name
    ) external returns (uint tokenId);
    function calculateCatgirlBreakKemi() external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {IFlowLimit} from "./IFlowLimit.sol";

/**
 * @title INftManager Interface
 * @notice This contract is responsible for managing NFTS
 */
interface INftManager {
    error InvalidChainName();
    error NotRemoteService();
    error InvalidMetadataVersion(uint32 version);
    error InvalidMessageType(uint256 messageType);
    error ZeroAmount();
    error NotApprovedByGateway();
    error ExecuteWithInterchainTokenFailed(address contractAddress);

    event InterchainTransfer(
        address indexed sourceAddress,
        string destinationChain,
        bytes destinationAddress,
        uint256 nftTokenId,
        uint256 nftType,
        bytes32 indexed dataHash
    );

    event GatewayChanged(address gateway);

    event InterchainTransferReceived(
        bytes32 indexed commandId,
        string sourceChain,
        bytes sourceAddress,
        address indexed destinationAddress,
        bytes callData,
        bytes32 dataHash
    );

    event GasServiceChanged(address gasService);

    event CatgirlNftChanged(address nftAddress);

    event BaseKemiNftChanged(address nftAddress);

    event WearableNftChanged(address nftAddress);

    event KemiNftChanged(address nftAddress);
    function execute(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) external;
}

pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IWearable is IERC721 {
    struct WearableSetting {
        bool allowMintBefore;
        bool onlyMinterRole;
        // if specific only charactor to mint a specific wearable
        bool requireCharacter;
        uint8 gender; // 0: for all, 1: male, 2: female
        uint8 catgirlRarity;
        uint8 catgirlCharacter;
        // Type of kemi could use this wearable
        uint16[] kemiTypes;
        uint16 categoryId;
        int128 fiatPrice;
        uint256 totalSupply;
        uint256 timeStampCanMint;
        string name;
    }
    function mintByMananger(bytes[] memory callDatas) external;
    function mintForKemi(
        uint16[][] calldata wearableList,
        address kemiAddress
    ) external returns (uint256[][] memory tokenIds);
    struct WearableDetails {
        uint8 rarity;
        uint16 wearableId;
        uint16 categoryId;
    }
    function externalMint(
        uint16 _wearableSettingId,
        address _user
    ) external returns (uint256 tokenId);

    function mintByRandom(
        uint16 _wearableId,
        uint256 _requestId,
        uint256 _rand,
        uint256 _catgirlTokenId,
        address _user
    ) external;

    function getWearable(
        uint256 tokenId
    ) external view returns (WearableDetails memory wearable);

    function getCurrentSupply(
        uint16 _wearableId
    ) external view returns (uint256);

    function updateCurrentSupplyWhenMint(uint16 _wearableId) external;

    function getWearableSettingByTokenId(
        uint256 _tokenId
    ) external view returns (WearableSetting memory wearableSetting);

    function calculateCatgirlSalePrice(
        uint16 _wearableId
    ) external view returns (uint256);

    function getWearableSettingByWearableId(
        uint16 _wearableId
    ) external view returns (WearableSetting memory wearableSetting);

    function burn(uint256 tokenId) external;

    function mintMultiple(
        uint16[] calldata _wearableSettingId,
        address _user
    ) external returns (uint256[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    error TokenTransferFailed();

/*
 * @title SafeTokenCall
 * @dev This library is used for performing safe token transfers.
 */
library SafeTokenCall {
    /*
     * @notice Make a safe call to a token contract.
     * @param token The token contract to interact with.
     * @param callData The function call data.
     * @throws TokenTransferFailed error if transfer of token is not successful.
     */
    function safeCall(IERC20 token, bytes memory callData) internal {
        (bool success, bytes memory returnData) = address(token).call(callData);
        bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || address(token).code.length == 0) revert TokenTransferFailed();
    }
}

/*
 * @title SafeTokenTransfer
 * @dev This library safely transfers tokens from the contract to a recipient.
 */
library SafeTokenTransfer {
    /*
     * @notice Transfer tokens to a recipient.
     * @param token The token contract.
     * @param receiver The recipient of the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function safeTransfer(
        IERC20 token,
        address receiver,
        uint256 amount
    ) internal {
        SafeTokenCall.safeCall(token, abi.encodeWithSelector(IERC20.transfer.selector, receiver, amount));
    }
}

/*
 * @title SafeTokenTransferFrom
 * @dev This library helps to safely transfer tokens on behalf of a token holder.
 */
library SafeTokenTransferFrom {
    /*
     * @notice Transfer tokens on behalf of a token holder.
     * @param token The token contract.
     * @param from The address of the token holder.
     * @param to The address the tokens are to be sent to.
     * @param amount The amount of tokens to be transferred.
     */
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        SafeTokenCall.safeCall(token, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library StringStorage {
    struct Wrapper {
        string value;
    }

    function set(bytes32 slot, string memory value) internal {
        _getStorageStruct(slot).value = value;
    }

    function get(bytes32 slot) internal view returns (string memory value) {
        value = _getStorageStruct(slot).value;
    }

    function clear(bytes32 slot) internal {
        delete _getStorageStruct(slot).value;
    }

    function _getStorageStruct(bytes32 slot) internal pure returns (Wrapper storage wrapper) {
        assembly {
            wrapper.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IInterchainAddressTracker } from '../interfaces/IInterchainAddressTracker.sol';
import { StringStorage } from '../libs/StringStorage.sol';

/**
 * @title InterchainAddressTracker
 * @dev Manages and validates trusted interchain addresses of an application.
 */
contract AddressTracker is IInterchainAddressTracker {
    bytes32 internal constant PREFIX_ADDRESS_MAPPING = keccak256('interchain-address-tracker-address-mapping');
    bytes32 internal constant PREFIX_ADDRESS_HASH_MAPPING =
    keccak256('interchain-address-tracker-address-hash-mapping');
    // bytes32(uint256(keccak256('interchain-address-tracker-chain-name')) - 1)
    bytes32 internal constant _CHAIN_NAME_SLOT = 0x0e2c162a1f4b5cff9fdbd6b34678a9bcb9898a0b9fbca695b112d61688d8b2ac;

    function _setChainName(string memory chainName_) internal {
        StringStorage.set(_CHAIN_NAME_SLOT, chainName_);
    }

    /**
     * @dev Gets the name of the chain this is deployed at
     */
    function chainName() external view returns (string memory chainName_) {
        chainName_ = StringStorage.get(_CHAIN_NAME_SLOT);
    }

    /**
     * @dev Gets the trusted address at a remote chain
     * @param chain Chain name of the remote chain
     * @return trustedAddress_ The trusted address for the chain. Returns '' if the chain is untrusted
     */
    function trustedAddress(string memory chain) public view returns (string memory trustedAddress_) {
        trustedAddress_ = StringStorage.get(_getTrustedAddressSlot(chain));
    }

    /**
     * @dev Gets the trusted address hash for a chain
     * @param chain Chain name
     * @return trustedAddressHash_ the hash of the trusted address for that chain
     */
    function trustedAddressHash(string memory chain) public view returns (bytes32 trustedAddressHash_) {
        bytes32 slot = _getTrustedAddressHashSlot(chain);
        assembly {
            trustedAddressHash_ := sload(slot)
        }
    }

    /**
     * @dev Checks whether the interchain sender is a trusted address
     * @param chain Chain name of the sender
     * @param address_ Address of the sender
     * @return bool true if the sender chain/address are trusted, false otherwise
     */
    function isTrustedAddress(string calldata chain, string calldata address_) public view returns (bool) {
        bytes32 addressHash = keccak256(bytes(address_));

        return addressHash == trustedAddressHash(chain);
    }

    /**
     * @dev Gets the key for the trusted address at a remote chain
     * @param chain Chain name of the remote chain
     * @return slot the slot to store the trusted address in
     */
    function _getTrustedAddressSlot(string memory chain) internal pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(PREFIX_ADDRESS_MAPPING, chain));
    }

    /**
     * @dev Gets the key for the trusted address at a remote chain
     * @param chain Chain name of the remote chain
     * @return slot the slot to store the trusted address hash in
     */
    function _getTrustedAddressHashSlot(string memory chain) internal pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(PREFIX_ADDRESS_HASH_MAPPING, chain));
    }

    /**
     * @dev Sets the trusted address and its hash for a remote chain
     * @param chain Chain name of the remote chain
     * @param address_ the string representation of the trusted address
     */
    function _setTrustedAddress(string memory chain, string memory address_) internal {
        if (bytes(chain).length == 0) revert ZeroStringLength();
        if (bytes(address_).length == 0) revert ZeroStringLength();

        StringStorage.set(_getTrustedAddressSlot(chain), address_);

        bytes32 slot = _getTrustedAddressHashSlot(chain);
        bytes32 addressHash = keccak256(bytes(address_));
        assembly {
            sstore(slot, addressHash)
        }

        emit TrustedAddressSet(chain, address_);
    }

    /**
     * @dev Remove the trusted address of the chain.
     * @param chain Chain name that should be made untrusted
     */
    function _removeTrustedAddress(string memory chain) internal {
        if (bytes(chain).length == 0) revert ZeroStringLength();

        StringStorage.clear(_getTrustedAddressSlot(chain));

        bytes32 slot = _getTrustedAddressHashSlot(chain);
        assembly {
            sstore(slot, 0)
        }

        emit TrustedAddressRemoved(chain);
    }
}
