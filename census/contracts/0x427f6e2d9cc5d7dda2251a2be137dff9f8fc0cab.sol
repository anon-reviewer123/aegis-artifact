// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./errors.sol";
import "./interfaces.sol";

/**
 * @title PAI Distributor Contract
 * @author EdgeServo
 * @notice Central coordinator for managing signature verification, vault registration, and token allocation
 * @dev Implements EIP-712 signature standard to ensure operation security and traceability
 *
 * Core Features:
 * - Vault registration verification: verify user identity and vault ownership
 * - Allocation authorization management: authorize token distribution via signatures
 * - Reward distribution coordination: manage third-party token rewards
 * - Replay attack protection: use nonce mechanism to prevent signature reuse
 *
 * Security Features:
 * - EIP-712 typed data signatures
 * - Timestamp expiration verification
 * - Nonce increment mechanism
 * - Multiple identity authentication
 */
contract distributor {
    // ========== EIP-712 Type Hash Definitions ==========

    /// @notice EIP-712 domain separator type hash
    /// @dev Used to construct domain separator, ensuring signatures are valid within specific domain
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    /// @notice Vault registration message type hash
    /// @dev Defines data structure for vault registration requests
    bytes32 private constant REGISTRATION_TYPEHASH =
        keccak256(
            "VaultRegistration(address vaultAddress,address user,uint256 nonce,uint256 deadline)"
        );

    /// @notice Allocation authorization message type hash
    /// @dev Defines data structure for token allocation authorizations
    bytes32 private constant ALLOCATION_TYPEHASH =
        keccak256(
            "AllocationAuthorization(address userVault,uint256 amount,uint256 nonce,uint256 deadline)"
        );

    // ========== Immutable State Variables ==========

    /// @notice PAI token contract address
    /// @dev Primary token type managed by the system
    address public immutable pai_token;

    /// @notice Vault factory contract address
    /// @dev Used to verify vault legitimacy
    address public immutable vault_factory;

    /// @notice EIP-712 domain separator
    /// @dev Prevents cross-domain signature replay attacks
    bytes32 public immutable DOMAIN_SEPARATOR;

    // ========== Mutable State Variables ==========

    /// @notice Contract owner address
    /// @dev Account with management privileges
    address public owner;

    /// @notice Authorized signer address
    /// @dev Trusted account responsible for issuing allocation and registration authorizations
    address public signer;

    /// @notice Project vault contract address
    /// @dev Central vault storing tokens to be distributed
    address public project_vault;

    // ========== Mapping Storage ==========

    /// @notice User registration operation nonce mapping
    /// @dev user address => current nonce (prevents registration signature replay)
    mapping(address => uint256) public registration_nonces;

    /// @notice Vault allocation operation nonce mapping
    /// @dev vault address => current nonce (prevents allocation signature replay)
    mapping(address => uint256) public allocation_nonces;

    /// @notice Registered vault verification mapping
    /// @dev vault address => whether registered
    mapping(address => bool) public registered_vaults;

    /// @notice User to vault mapping relationship
    /// @dev user address => vault address (one-to-one relationship)
    mapping(address => address) public user_to_vault;

    // ========== Event Definitions ==========

    /**
     * @notice Vault successfully registered event
     * @param vault Registered vault address
     * @param user Vault owner address
     */
    event VaultRegistered(address indexed vault, address indexed user);

    /**
     * @notice Token allocation executed successfully event
     * @param vault Vault receiving allocation
     * @param amount Amount of tokens allocated
     */
    event AllocationExecuted(address indexed vault, uint256 amount);

    /**
     * @notice Project vault address updated event
     * @param new_project_vault Newly set project vault address
     */
    event ProjectVaultUpdated(address indexed new_project_vault);

    // ========== Constructor ==========

    /**
     * @notice Create distributor contract instance
     * @dev Initialize core parameters and construct EIP-712 domain separator
     *
     * @param _token PAI token contract address
     * @param _signer Authorized signer address
     * @param _factory Vault factory contract address
     *
     * Requirements:
     * - All parameters must not be zero address
     *
     * Reverts:
     * - {ZeroAddress} if any parameter is zero address
     */
    constructor(address _token, address _signer, address _factory) {
        // Parameter validation: ensure all addresses are valid
        if (
            _token == address(0) ||
            _signer == address(0) ||
            _factory == address(0)
        ) {
            revert ZeroAddress();
        }

        // Set immutable variables
        owner = msg.sender;
        pai_token = _token;
        signer = _signer;
        vault_factory = _factory;

        // Initialize EIP-712 domain separator
        // Used to construct unique signature domain, preventing cross-contract/cross-chain replay attacks
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256("PAI Allocation System"), // Domain name
                keccak256("1"), // Version number
                block.chainid, // Chain ID
                address(this) // Verifying contract address
            )
        );
    }

    // ========== Management Functions ==========

    /**
     * @notice Set project vault address (one-time operation)
     * @dev Must be completed before system starts running
     *
     * @param _project_vault Project vault contract address
     *
     * Access control:
     * - Can only be called by contract owner
     * - Can only be set once (cannot be changed)
     *
     * State changes:
     * - Set project_vault address
     *
     * Reverts:
     * - {Unauthorized} if caller is not owner
     * - {ZeroAddress} if project vault address is invalid
     * - {AlreadyExists} if already set
     *
     * Emits:
     * - {ProjectVaultUpdated} project vault set successfully
     */
    function set_project_vault(address _project_vault) external {
        // Permission verification: only owner can set
        if (msg.sender != owner) revert Unauthorized();

        // Parameter validation: address must be valid
        if (_project_vault == address(0)) revert ZeroAddress();

        // State verification: prevent duplicate setting
        if (project_vault != address(0)) revert AlreadyExists();

        // Set project vault address
        project_vault = _project_vault;

        // Emit update event
        emit ProjectVaultUpdated(_project_vault);
    }

    // ========== Registration Functions ==========

    /**
     * @notice Complete vault registration through signature verification
     * @dev Multi-step verification process ensures registration security and legitimacy
     *
     * Execution flow:
     * 1. Basic state checks (project vault, signature validity, etc.)
     * 2. Verify vault legitimacy (factory deployment, ownership)
     * 3. Verify EIP-712 signature
     * 4. Update registration state and mapping relationships
     * 5. Notify project vault and complete vault initialization
     *
     * @param vault_address Vault address to register
     * @param deadline Signature expiration timestamp
     * @param signature EIP-712 signature data (65 bytes)
     *
     * Access control:
     * - Anyone can call
     * - But must be vault owner themselves
     * - Requires valid authorization signature
     *
     * Preconditions:
     * - Project vault is set
     * - Vault is not registered
     * - User does not own other vaults
     * - Vault is deployed by factory
     * - Caller is vault owner
     *
     * Security measures:
     * - EIP-712 signature verification
     * - Timestamp expiration check
     * - Nonce mechanism prevents replay
     * - Multiple identity authentication
     *
     * Reverts:
     * - {ZeroAddress} if project vault not set
     * - {SignatureExpired} if signature has expired
     * - {AlreadyExists} if vault registered or user has vault
     * - {Unauthorized} if vault is invalid or caller is not owner
     * - {InvalidSignature} if signature verification fails
     *
     * Emits:
     * - {VaultRegistered} registration successful
     */
    function register_vault_with_signature(
        address vault_address,
        uint256 deadline,
        bytes calldata signature
    ) external {
        address user = msg.sender;

        // ========== Step 1: Basic State Checks ==========

        // Check if project vault is set
        if (project_vault == address(0)) revert ZeroAddress();

        // Check if signature has expired
        if (block.timestamp > deadline) revert SignatureExpired();

        // Check if vault is already registered
        if (registered_vaults[vault_address]) revert AlreadyExists();

        // Check if user already owns another vault
        if (user_to_vault[user] != address(0)) revert AlreadyExists();

        // ========== Step 2: Verify Vault Legitimacy ==========

        // Verify vault is deployed by factory
        if (!i_vault_factory(vault_factory).is_valid_vault(vault_address)) {
            revert Unauthorized();
        }

        // Verify caller is vault owner
        if (i_vault(vault_address).owner() != user) revert Unauthorized();

        // ========== Step 3: Verify EIP-712 Signature ==========

        // Get current user's registration nonce
        uint256 nonce = registration_nonces[user];

        // Construct typed data structure hash
        bytes32 struct_hash = keccak256(
            abi.encode(
                REGISTRATION_TYPEHASH,
                vault_address,
                user,
                nonce,
                deadline
            )
        );

        // Construct EIP-712 signature digest
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, struct_hash)
        );

        // Recover signer address from signature
        address recovered = _recover_signer(digest, signature);

        // Verify signer is authorized signer
        if (recovered != signer) revert InvalidSignature();

        // ========== Step 4: Update State ==========

        // Increment user's registration nonce (prevents signature replay)
        unchecked {
            registration_nonces[user] = nonce + 1;
        }

        // Mark vault as registered
        registered_vaults[vault_address] = true;

        // Establish user to vault mapping relationship
        user_to_vault[user] = vault_address;

        // ========== Step 5: Complete Registration Process ==========

        // Notify project vault for corresponding record
        i_project_vault(project_vault).register_vault(vault_address, user);

        // Complete vault initialization process
        i_vault(vault_address).complete_initialization();

        // Emit registration success event
        emit VaultRegistered(vault_address, user);
    }

    // ========== Allocation Functions ==========

    /**
     * @notice Execute PAI token allocation through signature authorization
     * @dev Transfer specified amount of PAI from project vault to user vault
     *
     * Execution flow:
     * 1. Verify vault is registered
     * 2. Check signature has not expired
     * 3. Verify allocation amount is valid
     * 4. Verify EIP-712 signature
     * 5. Update nonce to prevent replay
     * 6. Call project vault to execute transfer
     *
     * @param amount Amount of tokens to allocate (in wei)
     * @param deadline Signature expiration timestamp
     * @param signature EIP-712 signature data (65 bytes)
     * @return success Whether allocation succeeded
     *
     * Access control:
     * - Can only be called by registered vault contract
     * - Requires valid authorization signature
     *
     * Security measures:
     * - EIP-712 signature verification
     * - Timestamp expiration check
     * - Nonce increment prevents replay
     * - Amount validity verification
     *
     * Reverts:
     * - {Unauthorized} if vault not registered
     * - {SignatureExpired} if signature has expired
     * - {ZeroAmount} if allocation amount is zero
     * - {InvalidSignature} if signature verification fails
     * - {TransferFailed} if transfer fails
     *
     * Emits:
     * - {AllocationExecuted} allocation executed successfully
     */
    function execute_allocation(
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bool) {
        address user_vault = msg.sender;

        // ========== Step 1: Basic Verification ==========

        // Verify caller is registered vault
        if (!registered_vaults[user_vault]) revert Unauthorized();

        // Check if signature has expired
        if (block.timestamp > deadline) revert SignatureExpired();

        // Verify allocation amount is valid
        if (amount == 0) revert ZeroAmount();

        // ========== Step 2: Verify Signature ==========

        // Get current vault's allocation nonce
        uint256 nonce = allocation_nonces[user_vault];

        // Construct typed data structure hash
        bytes32 struct_hash = keccak256(
            abi.encode(ALLOCATION_TYPEHASH, user_vault, amount, nonce, deadline)
        );

        // Construct EIP-712 signature digest
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, struct_hash)
        );

        // Recover and verify signer
        address recovered = _recover_signer(digest, signature);
        if (recovered != signer) revert InvalidSignature();

        // ========== Step 3: Update State ==========

        // Increment vault's allocation nonce (prevents signature replay)
        unchecked {
            allocation_nonces[user_vault] = nonce + 1;
        }

        // ========== Step 4: Execute Allocation ==========

        // Call project vault to execute actual transfer
        bool success = i_project_vault(project_vault).allocate_to_user(
            user_vault,
            amount
        );

        // Verify transfer result
        if (!success) revert TransferFailed();

        // Emit allocation execution event
        emit AllocationExecuted(user_vault, amount);

        return true;
    }

    // ========== Reward Distribution Functions ==========

    /**
     * @notice Distribute third-party token rewards to specified vault
     * @dev Called by project vault, coordinates reward token transfer
     *
     * @param vault_address Vault receiving rewards
     * @param token_address Reward token contract address
     *
     * Access control:
     * - Can only be called by project vault contract
     * - Target vault must be registered
     *
     * Reverts:
     * - {Unauthorized} if caller is not project vault or vault not registered
     */
    function distribute_award(
        address vault_address,
        address token_address
    ) external {
        // Permission verification: only project vault can initiate reward distribution
        if (msg.sender != project_vault) revert Unauthorized();

        // Verify target vault is registered
        if (!registered_vaults[vault_address]) revert Unauthorized();

        // Call vault's award withdrawal function
        i_vault(vault_address).withdraw_award(token_address);
    }

    // ========== Internal Functions ==========

    /**
     * @notice Recover signer address from EIP-712 signature
     * @dev Uses ecrecover precompiled contract for elliptic curve signature recovery
     *
     * @param digest EIP-712 message digest (32 bytes)
     * @param signature Signature data (65 bytes: r + s + v)
     * @return Ethereum address of signer
     *
     * Signature format:
     * - bytes[0:32]: r value (x coordinate of elliptic curve point)
     * - bytes[32:64]: s value (signature proof)
     * - bytes[64]: v value (recovery identifier, 27 or 28)
     *
     * Reverts:
     * - {InvalidAmount} if signature length is not 65 bytes
     * - {InvalidAmount} if v value is not 27 or 28
     */
    function _recover_signer(
        bytes32 digest,
        bytes calldata signature
    ) private pure returns (address) {
        // Verify signature length
        if (signature.length != 65) revert InvalidAmount();

        bytes32 r;
        bytes32 s;
        uint8 v;

        // Use inline assembly for efficient signature parameter extraction
        // Avoids unnecessary memory copies
        assembly {
            // Extract r value (first 32 bytes)
            r := calldataload(signature.offset)
            // Extract s value (next 32 bytes)
            s := calldataload(add(signature.offset, 32))
            // Extract v value (last 1 byte)
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        // Normalize v value (some signature libraries return 0/1 instead of 27/28)
        if (v < 27) v += 27;

        // Verify v value validity
        if (v != 27 && v != 28) revert InvalidAmount();

        // Use ecrecover to recover signer address
        return ecrecover(digest, v, r, s);
    }

    // ========== Query Functions ==========

    /**
     * @notice Get allocation nonce for specified vault
     * @dev Used by frontend to construct signature messages
     *
     * @param vault Vault address
     * @return Current allocation nonce value
     */
    function get_nonce(address vault) external view returns (uint256) {
        return allocation_nonces[vault];
    }

    /**
     * @notice Get registration nonce for specified user
     * @dev Used by frontend to construct registration signature messages
     *
     * @param user User address
     * @return Current registration nonce value
     */
    function get_registration_nonce(
        address user
    ) external view returns (uint256) {
        return registration_nonces[user];
    }

    /**
     * @notice Query whether user has registered vault
     * @dev Convenience query function
     *
     * @param user User address
     * @return Whether vault is registered
     */
    function has_vault(address user) external view returns (bool) {
        return user_to_vault[user] != address(0);
    }

    /**
     * @notice Get user's vault address
     * @dev Returns zero address if user not registered
     *
     * @param user User address
     * @return User's vault address
     */
    function get_user_vault(address user) external view returns (address) {
        return user_to_vault[user];
    }

    /**
     * @notice Verify if vault is registered
     * @dev Used for external contract verification
     *
     * @param vault Vault address
     * @return Whether registered
     */
    function is_registered(address vault) external view returns (bool) {
        return registered_vaults[vault];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title PAI Token System Custom Error Definitions
 * @author EdgeServo
 * @notice Defines all custom errors used throughout the PAI distribution system
 * @dev Uses Solidity 0.8.4+ custom error feature to save gas costs
 *
 * Advantages:
 * - Gas optimization: significantly reduces deployment and runtime costs compared to require strings
 * - Type safety: compile-time checking, avoids string typos
 * - Code clarity: centralized management, easier to maintain and document
 * - Chain-friendly: error selectors only occupy 4 bytes, more compact than strings
 *
 * Usage examples:
 * ```solidity
 * if (amount == 0) revert ZeroAmount();
 * if (msg.sender != owner) revert Unauthorized();
 * ```
 */

// ========== General Validation Errors ==========

/**
 * @notice Zero address error
 * @dev Triggered when function parameter or return value is zero address (0x0)
 *
 * Trigger scenarios:
 * - Constructor parameter validation fails
 * - Zero address passed when setting critical contract addresses
 * - Query result is zero address but should not be
 *
 * Usage example:
 * ```solidity
 * if (_token == address(0)) revert ZeroAddress();
 * ```
 */
error ZeroAddress();

/**
 * @notice Zero amount error
 * @dev Triggered when token amount, value or count is zero but business logic requires non-zero
 *
 * Trigger scenarios:
 * - Attempt to transfer zero amount of tokens
 * - Allocation authorization amount is zero
 * - Vault balance is zero when attempting withdrawal
 *
 * Usage example:
 * ```solidity
 * if (amount == 0) revert ZeroAmount();
 * if (balance == 0) revert ZeroAmount();
 * ```
 */
error ZeroAmount();

/**
 * @notice Invalid amount error
 * @dev Triggered when amount exceeds valid range, incorrect format or doesn't satisfy business rules
 *
 * Trigger scenarios:
 * - Signature length is not 65 bytes
 * - Signature parameter v value is not 27 or 28
 * - Amount exceeds maximum limit
 * - Amount format doesn't meet requirements
 *
 * Usage example:
 * ```solidity
 * if (signature.length != 65) revert InvalidAmount();
 * if (v != 27 && v != 28) revert InvalidAmount();
 * ```
 */
error InvalidAmount();

/**
 * @notice Unauthorized access error
 * @dev Triggered when caller lacks required permissions or operation is unauthorized
 *
 * Trigger scenarios:
 * - Non-owner attempts to call management functions
 * - Non-EOA attempts to deploy vault
 * - Unregistered vault attempts to execute operations
 * - Reentrancy attack detection
 * - Vault not initialized when calling protected functions
 * - Attempting to operate resources not owned by caller
 *
 * Usage example:
 * ```solidity
 * if (msg.sender != owner) revert Unauthorized();
 * if (!_initialized) revert Unauthorized();
 * if (_locked == _ENTERED) revert Unauthorized();
 * ```
 */
error Unauthorized();

/**
 * @notice Entity already exists error
 * @dev Triggered when attempting to create or register an already existing entity
 *
 * Trigger scenarios:
 * - User already owns a vault, attempts to deploy again
 * - Vault already registered, duplicate registration
 * - Attempting to set configuration that can only be set once
 * - Duplicate vault initialization
 *
 * Usage example:
 * ```solidity
 * if (user_vaults[user] != address(0)) revert AlreadyExists();
 * if (registered_vaults[vault]) revert AlreadyExists();
 * if (distributor != address(0)) revert AlreadyExists();
 * ```
 */
error AlreadyExists();

// ========== Transfer Operation Errors ==========

/**
 * @notice Transfer failed error
 * @dev Triggered when ERC20 token transfer operation returns false or execution fails
 *
 * Trigger scenarios:
 * - transfer() returns false
 * - transferFrom() returns false
 * - Insufficient balance causing transfer failure
 * - Insufficient allowance causing transferFrom failure
 * - Allocation execution failure
 *
 * Usage example:
 * ```solidity
 * bool success = token.transfer(to, amount);
 * if (!success) revert TransferFailed();
 * ```
 *
 * Note:
 * - Some ERC20 tokens revert on failure instead of returning false
 * - Recommend using SafeERC20 library for safer transfer operations
 */
error TransferFailed();

// ========== Signature Verification Errors ==========

/**
 * @notice Invalid signature error
 * @dev Triggered when EIP-712 signature verification fails
 *
 * Trigger scenarios:
 * - Signer is not the authorized signer
 * - Signature data has been tampered with
 * - Signature for wrong data structure
 * - ecrecover recovery fails (returns zero address)
 * - Wrong private key used for signing
 *
 * Usage example:
 * ```solidity
 * address recovered = ecrecover(digest, v, r, s);
 * if (recovered != signer) revert InvalidSignature();
 * if (recovered == address(0)) revert InvalidSignature();
 * ```
 *
 * Security recommendations:
 * - Always verify ecrecover return value is not zero address
 * - Use correct EIP-712 domain separator
 * - Ensure nonce mechanism is correctly implemented
 */
error InvalidSignature();

/**
 * @notice Signature expired error
 * @dev Triggered when signature's validity deadline has passed
 *
 * Trigger scenarios:
 * - Current block timestamp > deadline
 * - Signature created beyond validity period
 * - Network congestion causing transaction confirmation delay
 *
 * Usage example:
 * ```solidity
 * if (block.timestamp > deadline) revert SignatureExpired();
 * ```
 *
 * Considerations:
 * - deadline should have reasonable buffer time
 * - Consider network congestion may cause delays
 * - Expired signatures cannot be reused, must regenerate
 */
error SignatureExpired();

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title PAI Token System Interface Definitions
 * @author EdgeServo
 * @notice Defines all contract interaction interfaces in PAI token distribution system
 * @dev Includes ERC20 standard interface and internal system contract interfaces
 *
 * Interface descriptions:
 * - i_erc20: Standard ERC20 token interface (simplified version)
 * - i_vault: User vault contract interface
 * - i_distributor: Distributor contract interface
 * - i_project_vault: Project vault contract interface
 * - i_vault_factory: Vault factory contract interface
 */

// ========== ERC20 Token Interface ==========

/**
 * @title ERC20 Token Interface (Simplified)
 * @notice Defines core ERC20 standard functions needed by PAI system
 * @dev Only includes core functions used by system, not complete ERC20 standard
 */
interface i_erc20 {
    /**
     * @notice Query token balance of specified account
     * @dev Standard ERC20 function
     *
     * @param account Account address to query
     * @return Account's token holdings (in wei)
     *
     * Usage:
     * - Vault queries its own PAI balance
     * - Query reward token balance
     * - Verify sufficient balance before transfer
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Transfer tokens to specified address
     * @dev Standard ERC20 function, transfers from caller's account
     *
     * @param to Recipient address
     * @param amount Transfer amount (in wei)
     * @return Whether transfer succeeded
     *
     * Requirements:
     * - Caller's balance must be >= amount
     * - to address cannot be zero address
     *
     * Usage:
     * - Vault transfers PAI to user
     * - Project vault allocates tokens to user vault
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @notice Transfer tokens from one address to another
     * @dev Standard ERC20 function, requires prior approval
     *
     * @param from Source address (token owner)
     * @param to Recipient address
     * @param amount Transfer amount (in wei)
     * @return Whether transfer succeeded
     *
     * Requirements:
     * - from address balance must be >= amount
     * - Caller must have sufficient allowance
     * - to address cannot be zero address
     *
     * Usage:
     * - Vault withdraws reward tokens (from awarder to accepter)
     * - Requires awarder to pre-call approve() for authorization
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// ========== User Vault Interface ==========

/**
 * @title User Vault Contract Interface
 * @notice Defines externally exposed functions of user vault
 * @dev Used for distributor and project vault to interact with user vaults
 */
interface i_vault {
    /**
     * @notice Get vault owner address
     * @dev Read-only function, returns owner set at vault creation
     *
     * @return Ethereum address of vault owner
     *
     * Usage:
     * - Distributor verifies registrant identity
     * - Frontend displays vault ownership information
     * - Other contracts verify operation permissions
     */
    function owner() external view returns (address);

    /**
     * @notice Complete vault initialization
     * @dev Called by distributor after successful registration, marks vault as usable
     *
     * Access control:
     * - Can only be called by distributor contract
     * - Can only be called once
     *
     * State changes:
     * - Set _initialized flag to true
     * - Vault becomes operational
     *
     * Usage:
     * - Complete final step of vault registration
     * - Activate all vault functions
     */
    function complete_initialization() external;

    /**
     * @notice Withdraw third-party reward tokens
     * @dev Called by distributor, transfers rewards from awarder to accepter
     *
     * @param token_address Reward token contract address
     *
     * Access control:
     * - Can only be called by distributor contract
     * - Vault must be initialized
     *
     * Restrictions:
     * - Cannot withdraw PAI tokens
     * - Awarder must have sufficient balance
     *
     * Usage:
     * - Distribute reward tokens provided by project party
     * - Handle airdrops and other incentive activities
     */
    function withdraw_award(address token_address) external;
}

// ========== Distributor Interface ==========

/**
 * @title Distributor Contract Interface
 * @notice Defines core functions exposed by distributor
 * @dev Used for vaults and project vault to interact with distributor
 */
interface i_distributor {
    /**
     * @notice Get project vault address
     * @dev Read-only function, returns project vault address in system
     *
     * @return Project vault contract address
     *
     * Usage:
     * - Vault queries project vault location
     * - Get award role configuration
     * - Verify system configuration completeness
     */
    function project_vault() external view returns (address);

    /**
     * @notice Execute token allocation operation
     * @dev Verify signature then transfer from project vault to user vault
     *
     * @param amount Amount of tokens to allocate (in wei)
     * @param deadline Signature validity deadline timestamp
     * @param signature EIP-712 signature data (65 bytes)
     * @return Whether allocation succeeded
     *
     * Access control:
     * - Can only be called by registered vault contracts
     * - Requires valid authorization signature
     *
     * Verification flow:
     * 1. Check if vault is registered
     * 2. Verify signature has not expired
     * 3. Verify EIP-712 signature
     * 4. Call project vault to execute transfer
     *
     * Usage:
     * - User vault claims allocation quota
     * - Implement signature-authorized token distribution
     */
    function execute_allocation(
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bool);

    /**
     * @notice Distribute reward tokens
     * @dev Coordinate reward token transfer from awarder to accepter
     *
     * @param vault_address Vault receiving rewards
     * @param token_address Reward token contract address
     *
     * Access control:
     * - Can only be called by project vault contract
     * - Target vault must be registered
     *
     * Execution flow:
     * - Verify permissions and vault status
     * - Call vault's withdraw_award() function
     *
     * Usage:
     * - Project vault initiates reward distribution
     * - Handle third-party token rewards
     */
    function distribute_award(
        address vault_address,
        address token_address
    ) external;
}

// ========== Project Vault Interface ==========

/**
 * @title Project Vault Contract Interface
 * @notice Defines core functions exposed by project vault
 * @dev Used for distributor and user vaults to interact with project vault
 */
interface i_project_vault {
    /**
     * @notice Register user vault to system
     * @dev Called by distributor during user registration, establishes vault-user association
     *
     * @param vault_address Vault address to register
     * @param user Vault owner (user address)
     *
     * Access control:
     * - Can only be called by distributor contract
     *
     * State changes:
     * - Record vault and user mapping relationship
     * - May initialize reward configuration, etc.
     *
     * Usage:
     * - Complete vault registration process
     * - Establish user and vault association
     * - Initialize user-related configuration
     */
    function register_vault(address vault_address, address user) external;

    /**
     * @notice Allocate tokens to user vault
     * @dev Transfer specified amount of PAI tokens to user vault
     *
     * @param user_vault User vault address receiving tokens
     * @param amount Allocation amount (in wei)
     * @return Whether allocation succeeded
     *
     * Access control:
     * - Can only be called by distributor contract
     *
     * Preconditions:
     * - Project vault has sufficient balance
     * - User vault is registered
     *
     * Usage:
     * - Execute actual token transfer
     * - Complete final step of allocation authorization
     */
    function allocate_to_user(
        address user_vault,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Get award role configuration for specified vault
     * @dev Returns reward token awarder and accepter addresses
     *
     * @param vault_address Vault address
     * @return awarder Reward awarder address (token holder)
     * @return accepter Reward accepter address (final beneficiary)
     *
     * Usage:
     * - Vault queries reward configuration
     * - Determine reward token transfer path
     * - Support flexible reward distribution mechanism
     *
     * Note:
     * - Awarder needs to pre-approve vault sufficient allowance
     * - Accepter may be user themselves or other designated address
     */
    function get_award_roles(
        address vault_address
    ) external view returns (address awarder, address accepter);
}

// ========== Vault Factory Interface ==========

/**
 * @title Vault Factory Contract Interface
 * @notice Defines validation functions exposed by vault factory
 * @dev Used for distributor to verify vault legitimacy
 */
interface i_vault_factory {
    /**
     * @notice Verify if address is a valid deployed vault
     * @dev Check if address was deployed by this factory via CREATE2
     *
     * @param vault_address Vault address to verify
     * @return Whether it is a valid vault address
     *
     * Verification logic:
     * - Check deployed_vaults mapping
     * - Confirm vault was deployed by factory
     *
     * Usage:
     * - Distributor verifies vault legitimacy
     * - Prevent registration of unauthorized vaults
     * - Ensure vault code is trustworthy
     *
     * Note:
     * - Only verifies deployment source, not initialization status
     * - Returns true means deployed by factory, but may not be registered
     */
    function is_valid_vault(address vault_address) external view returns (bool);
}
