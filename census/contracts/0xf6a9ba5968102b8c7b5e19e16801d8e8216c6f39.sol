// SPDX-License-Identifier: GPL-3.0-or-later
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./utils/RecoverableFunds.sol";
import "./utils/SellableToken.sol";
import "./utils/TgeTimestamp.sol";
import "./utils/NonTransferableToken.sol";
import "./interface/ITokenVesting.sol";

/**
 * @title TokenVesting
 * @dev Abstract contract to manage token vesting schedules for multiple allocations and users.
 * Inherits from Ownable2Step, SellableToken, TgeTimestamp, NonTransferableToken and RecoverableFunds.
 */
contract TokenVesting is
    Ownable2Step,
    SellableToken,
    TgeTimestamp,
    NonTransferableToken,
    RecoverableFunds,
    ITokenVesting
{
    using SafeERC20 for IERC20;
    using Strings for uint256;

    /**
     * @dev Constant denominator for calculating percentages.
     * 10000 represents 100.00%. 1 represents 0.01%.
     */
    uint256 private constant DENOMINATOR = 10_000;

    /**
     * @dev The status of automatic supply of tokens.
     * When set to true, tokens will be automatically supplied based on certain conditions.
     * This can occur when allocating tokens or when claiming tokens.
     */
    bool private _autoSupply;

    /**
     * @dev The status of automatic supply of tokens upon claim.
     * When set to true, tokens will be automatically supplied when a claim is made.
     */
    bool private _autoSupplyOnClaim;

    /**
     * @dev The address from which tokens will be automatically supplied.
     * This address is used as the source for token transfers during automatic supply.
     */
    address private _autoSupplyFrom;

    /**
     * @dev Flag indicating whether tokens should be automatically claimed upon purchase.
     * If set to true and the Token Generation Event (TGE) has passed, tokens will be
     * immediately issued to the buyer if there is no vesting schedule.
     */
    bool private _autoClaimAfterTge;

    /// @dev List of allowed allocation IDs.
    bytes32[] private _allocationIds;

    /// @dev Mapping to check if an allocation ID exists in the allowed allocation IDs list.
    mapping(bytes32 allocationId => bool) private _allocationIdExist;

    /// @dev Total amount of tokens reserved across all allocations.
    uint256 private _totalReserved;

    /// @dev Total amount of tokens vested across all allocations.
    uint256 private _totalVested;

    /// @dev Total amount of tokens claimed by all users.
    uint256 private _totalClaimed;

    /**
     * @dev Struct to store vesting data for each allocation.
     * @param reserved The total amount of tokens reserved for this allocation.
     * @param vested Total amount of tokens vested.
     * @param claimed Total amount of tokens claimed.
     * @param lockup The lock-up period before vesting starts.
     * @param cliff The cliff period during which tokens cannot be claimed.
     * @param vesting The total vesting period over which tokens are gradually unlocked.
     * @param tgeUnlock The percentage of tokens unlocked immediately after the Token Generation Event (TGE). 1/10000 = 0.01%.
     * @param unlockDelay The delay between successive unlocks after the cliff period.
     */
    struct VestingData {
        uint256 reserved; // Total amount of tokens reserved.
        uint256 vested; // Total amount of tokens vested.
        uint256 claimed; // Total amount of tokens claimed.
        uint256 lockup; // Lock-up period for vesting.
        uint256 cliff; // Cliff period for vesting.
        uint256 vesting; // Vesting time.
        uint256 tgeUnlock; // Initial unlock percentage after TGE. 1/10000 = 0.01%.
        uint256 unlockDelay; // Delay between successive unlocks.
    }

    /**
     * @dev Struct to store vesting schedule parameters for an allocation.
     * @param allocationId The ID of the allocation.
     * @param reserved The total amount of tokens reserved for this allocation.
     * @param lockup The lock-up period before vesting starts.
     * @param cliff The cliff period during which tokens cannot be claimed.
     * @param vesting The total vesting period over which tokens are gradually unlocked.
     * @param tgeUnlock The percentage of tokens unlocked immediately after the Token Generation Event (TGE).
     * @param unlockDelay The delay between successive unlocks after the cliff period.
     */
    struct VestingSchedule {
        bytes32 allocationId;
        uint256 reserved;
        uint256 lockup;
        uint256 cliff;
        uint256 vesting;
        uint256 tgeUnlock;
        uint256 unlockDelay;
    }

    /// @dev Mapping to store vesting data for each allocation by its ID.
    mapping(bytes32 allocationId => VestingData) private _vesting;

    /**
     * @dev Struct to store vesting data for each user.
     * @param vested The amount of tokens vested in that allocation.
     * @param claimed The amount of tokens claimed by the user in that allocation.
     */
    struct UserVestingData {
        uint256 vested; // User vested tokens at each allocation.
        uint256 claimed; // User claimed tokens at each allocation.
    }

    /// @dev Mapping to store vesting data for each user by their address.
    mapping(address user => mapping(bytes32 allocationId => UserVestingData))
        private _userVesting;

    /// @dev Address of the TokenSale contract.
    address private _tokenSale;

    /// @dev Flag indicating if the TokenSale address is frozen.
    bool private _tokenSaleFrozen;

    /**
     * @dev Emitted when the auto supply settings are updated.
     * @param autoSupply The new status of the auto supply.
     * @param autoSupplyOnClaim The new status of the auto supply upon claim.
     * @param autoSupplyFrom The new address from which the tokens will be supplied.
     */
    event AutoSupplyUpdated(
        bool autoSupply,
        bool autoSupplyOnClaim,
        address autoSupplyFrom
    );

    /**
     * @dev Emitted when the auto-claim status is updated.
     * @param status The new status of auto-claim.
     */
    event AutoClaimAfterTgeUpdated(bool status);

    /**
     * @dev Emitted when a vesting allocation is updated.
     * @param allocationId The ID of the allocation that was updated.
     * @param reserved The updated total amount of tokens reserved for this allocation.
     * @param lockup The updated lock-up period before vesting starts, in seconds.
     * @param cliff The updated cliff period during which tokens cannot be claimed, in seconds.
     * @param vesting The updated total vesting period over which tokens are gradually unlocked, in seconds.
     * @param tgeUnlock The updated percentage of tokens unlocked immediately after the Token Generation Event (TGE), expressed in basis points (1/10000 = 0.01%).
     * @param unlockDelay The updated delay between successive unlocks after the cliff period, in seconds.
     */
    event AllocationUpdated(
        bytes32 indexed allocationId,
        uint256 reserved,
        uint256 lockup,
        uint256 cliff,
        uint256 vesting,
        uint256 tgeUnlock,
        uint256 unlockDelay
    );

    /**
     * @dev Emitted when a vesting allocation is deleted.
     * @param allocationId The ID of the allocation that was deleted.
     */
    event AllocationDeleted(bytes32 indexed allocationId);

    /**
     * @dev Emitted when tokens are supplied to the contract for vesting.
     * @param amount The amount of tokens that were supplied.
     */
    event TokensSupplied(uint256 amount);

    /**
     * @dev Emitted when tokens are vested for a user at a specific allocation.
     * @param user The address of the user whose tokens are vested.
     * @param allocationId The ID of the allocation in which tokens are vested.
     * @param amount The amount of tokens vested.
     */
    event VestingAccrued(
        address indexed user,
        bytes32 indexed allocationId,
        uint256 amount
    );

    /**
     * @dev Emitted when a user claims vested tokens.
     * @param user The address of the user who claims the tokens.
     * @param allocationId The ID of the allocation from which tokens are claimed.
     * @param amount The amount of tokens claimed.
     */
    event VestingClaimed(
        address indexed user,
        bytes32 indexed allocationId,
        uint256 amount
    );

    /**
     * @dev Emitted when the TokenSale address is changed.
     * @param tokenSale The new TokenSale address.
     */
    event TokenSaleUpdated(address tokenSale);

    /// @dev Emitted when the TokenSale is frozen.
    event TokenSaleFrozen();

    /// @dev Error thrown when an allocation is not exist.
    error AllocationNotFound(bytes32 allocationId);

    /**
     * @dev Error that is thrown when the new reserved amount is less than the already vested amount for a given allocation.
     * @param allocationId The ID of the allocation that has this issue.
     */
    error ReservedLessThanVested(bytes32 allocationId);

    /**
     * @dev Error that is thrown when the vested amount exceeds the reserved amount for a given allocation.
     * @param allocationId The ID of the allocation that exceeded its reserved amount.
     */
    error AllocationExceeded(bytes32 allocationId);

    /// @dev Error indicating that the allocation has already been used.
    error AllocationAlreadyUsed();

    /// @dev Error indicating that the TGE unlock percentage exceeds the maximum allowed value.
    error TgeUnlockExceedsMaximum();

    /// @dev Error thrown when the TokenSale address is zero.
    error TokenSaleIsZero();

    /// @dev Error thrown when the TokenSale is frozen and an update is attempted.
    error TokenSaleIsFrozen();

    /// @dev Error to be thrown when an unauthorized account tries to call a restricted function.
    error UnauthorizedAccount();

    /// @dev Error indicating that there is a mismatch between the provided parameters.
    error ParametersMismatch();

    /// @dev Error indicating an invalid token amount.
    error InvalidTokenAmount();

    /**
     * @dev Constructor for the TokenVesting contract.
     * @param sellableToken The address of the token that will be sold.
     * @param sellableTokenDecimals The number of decimals of the sellable token.
     * @param vestedTokenName The name of the vested token.
     * @param vestedTokenSymbol The symbol of the vested token.
     */
    constructor(
        address sellableToken,
        uint8 sellableTokenDecimals,
        string memory vestedTokenName,
        string memory vestedTokenSymbol
    )
        Ownable(_msgSender())
        TgeTimestamp(0)
        SellableToken(sellableToken, sellableTokenDecimals)
        NonTransferableToken(vestedTokenName, vestedTokenSymbol)
    {
        _setAutoClaimAfterTge(false);
    }

    /**
     * @dev Modifier to check if the allocation ID exists.
     * Reverts if the allocation does not exist.
     * @param allocationId The ID of the allocation to check.
     */
    modifier allocationIdExists(bytes32 allocationId) {
        _checkAllocationIdExistence(allocationId);
        _;
    }

    /// @dev Modifier to restrict access to only the TokenSale contract.
    modifier onlyTokenSale() {
        if (_tokenSale == address(0)) {
            revert TokenSaleIsZero();
        }
        if (_tokenSale != _msgSender()) {
            revert UnauthorizedAccount();
        }
        _;
    }

    /**
     * @notice Returns the total supply of tokens that users have not yet received from vesting.
     * @dev This function overrides the ERC20 totalSupply function to reflect the total amount of vested tokens
     * that are still locked and have not been claimed by users.
     * @return The total amount of unclaimed vested tokens.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalVested - _totalClaimed;
    }

    /**
     * @notice Returns the balance of tokens that a user has not yet received from vesting.
     * @dev This function overrides the ERC20 balanceOf function to reflect the amount of vested tokens
     * that are still locked and have not been claimed by the user.
     * @param user The address of the user.
     * @return The amount of unclaimed vested tokens for the user.
     */
    function balanceOf(address user) public view override returns (uint256) {
        uint256 vested;
        uint256 claimed;

        bytes32[] memory allocationIds = _getAllocationIds();
        uint256 totalAllocations = allocationIds.length;
        for (uint256 i = 0; i < totalAllocations; i++) {
            bytes32 allocationId = allocationIds[i];
            UserVestingData memory vestingData = _getUserVesting(
                user,
                allocationId
            );
            vested += vestingData.vested;
            claimed += vestingData.claimed;
        }
        return vested - claimed;
    }

    /**
     * @notice Returns the number of decimals used to get the user representation of vested tokens.
     * @dev This function overrides the ERC20 decimals function to return the number of decimals
     * of the vested token, which is the same as the sellable token's decimals.
     * @return The number of decimals of the vested token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _getSellableTokenDecimals();
    }

    /**
     * @notice Returns the recoverable funds for a specific token.
     * @dev Overrides the getRecoverableFunds function from RecoverableFunds contract.
     * If the token is a payment token, it calculates the balance excluding deposits and unclaimed raised funds.
     * If the token is the sellable token, it calculates the balance excluding the total unclaimed amount.
     * @param token The address of the token.
     * @return The amount of recoverable funds.
     */
    function getRecoverableFunds(
        address token
    ) public view override returns (uint256) {
        address sellableToken = _getSellableToken();
        if (token == sellableToken) {
            uint256 accountedFunds = _totalVested - _totalClaimed;
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (accountedFunds > balance) {
                return 0;
            }
            return balance - accountedFunds;
        } else {
            return super.getRecoverableFunds(token);
        }
    }

    /**
     * @notice Returns the current auto supply status and the address from which tokens are supplied.
     * @dev This function can be called externally to get the current status and address for automatic token supply.
     * @return autoSupply The current status of the auto supply (if autoSupplyOnClaim is false, then for allocating; if autoSupplyOnClaim is true, then for claiming).
     * @return autoSupplyOnClaim The current status of the auto supply upon claim (true if enabled, false if disabled).
     * @return autoSupplyFrom The address from which the tokens will be supplied.
     */
    function getAutoSupply()
        external
        view
        returns (
            bool autoSupply,
            bool autoSupplyOnClaim,
            address autoSupplyFrom
        )
    {
        autoSupply = _autoSupply;
        autoSupplyOnClaim = _autoSupplyOnClaim;
        autoSupplyFrom = _autoSupplyFrom;
    }

    /**
     * @notice Returns the allocation ID for a given allocation name.
     * @dev This function computes the keccak-256 hash of the given allocation name, subtracts 1, and returns it as bytes32.
     * @param allocationName The name of the allocation.
     * @return The ID of the allocation.
     */
    function computeAllocationId(
        string memory allocationName
    ) external pure returns (bytes32) {
        return _computeAllocationId(allocationName);
    }

    /**
     * @notice Verifies if a specified allocation ID exists in the allowed allocation IDs list.
     * @param allocationId The ID of the allocation to verify.
     * @return bool True if the allocation exists, false otherwise.
     */
    function isAllocationIdExist(
        bytes32 allocationId
    ) external view returns (bool) {
        return _isAllocationIdExist(allocationId);
    }

    /**
     * @notice Retrieves the list of all allowed allocation IDs.
     * @return bytes32[] List of allowed allocation IDs.
     */
    function getAllocationIds() external view returns (bytes32[] memory) {
        return _getAllocationIds();
    }

    /**
     * @notice Returns the vesting parameters for a specific allocation.
     * @dev This function retrieves the vesting details such as lockup period, cliff period, total vesting duration,
     * TGE unlock percentage, and unlock delay for the specified allocation.
     * @param allocationId The ID of the vesting allocation to retrieve.
     * @return reserved The total amount of tokens reserved for this allocation.
     * @return vested Total amount of tokens vested.
     * @return claimed Total amount of tokens claimed.
     * @return lockup The lock-up period before vesting starts.
     * @return cliff The cliff period during which tokens cannot be claimed.
     * @return vesting The total vesting period over which tokens are gradually unlocked.
     * @return tgeUnlock The percentage of tokens unlocked immediately after the Token Generation Event (TGE).
     * @return unlockDelay The delay between successive unlocks after the cliff period.
     */
    function getVesting(
        bytes32 allocationId
    )
        external
        view
        returns (
            uint256 reserved,
            uint256 vested,
            uint256 claimed,
            uint256 lockup,
            uint256 cliff,
            uint256 vesting,
            uint256 tgeUnlock,
            uint256 unlockDelay
        )
    {
        VestingData memory vestingData = _getVesting(allocationId);

        reserved = vestingData.reserved;
        vested = vestingData.vested;
        claimed = vestingData.claimed;
        lockup = vestingData.lockup;
        cliff = vestingData.cliff;
        vesting = vestingData.vesting;
        tgeUnlock = vestingData.tgeUnlock;
        unlockDelay = vestingData.unlockDelay;
    }

    /**
     * @notice Returns the vesting data for all allocations.
     * @return allocationIds An array of allocation IDs.
     * @return vestings An array of vesting data for all allocations.
     */
    function getVestings()
        external
        view
        returns (bytes32[] memory allocationIds, VestingData[] memory vestings)
    {
        allocationIds = _getAllocationIds();
        uint256 totalAllocations = allocationIds.length;
        vestings = new VestingData[](totalAllocations);
        for (uint256 i = 0; i < totalAllocations; i++) {
            bytes32 allocationId = allocationIds[i];
            vestings[i] = _getVesting(allocationId);
        }
    }

    /**
     * @notice Returns the overall state of vesting at a given time.
     * @param atTime The timestamp at which to check the state.
     * @return tge The TGE (Token Generation Event) timestamp.
     * @return autoClaimAfterTge The status of the auto-claim feature.
     * @return tokenSale The address of the TokenSale contract.
     * @return tokenSaleFrozen The status indicating if the TokenSale address is frozen.
     * @return totalReserved The total number of tokens reserved across all allocations.
     * @return totalVested The total number of tokens vested.
     * @return totalClaimed The total number of tokens claimed.
     * @return totalUnlocked The total number of tokens unlocked.
     * @return reserved An array of reserved tokens for each allocation.
     * @return vested An array of vested tokens for each allocation.
     * @return claimed An array of claimed tokens for each allocation.
     * @return unlocked An array of unlocked tokens for each allocation.
     * @return allocationIds An array of allocation IDs.
     */
    function getState(
        uint256 atTime
    )
        external
        view
        returns (
            uint256 tge,
            bool autoClaimAfterTge,
            address tokenSale,
            bool tokenSaleFrozen,
            uint256 totalReserved,
            uint256 totalVested,
            uint256 totalClaimed,
            uint256 totalUnlocked,
            uint256[] memory reserved,
            uint256[] memory vested,
            uint256[] memory claimed,
            uint256[] memory unlocked,
            bytes32[] memory allocationIds
        )
    {
        if (atTime == 0) {
            atTime = block.timestamp;
        }

        tge = _getTgeTimestamp();
        autoClaimAfterTge = _autoClaimAfterTge;
        tokenSale = _tokenSale;
        tokenSaleFrozen = _tokenSaleFrozen;

        totalReserved = _totalReserved;

        allocationIds = _getAllocationIds();
        (
            totalVested,
            totalClaimed,
            totalUnlocked,
            reserved,
            vested,
            claimed,
            unlocked
        ) = _calculateVestingStateAtTime(allocationIds, atTime);
    }

    /**
     * @notice Returns the vesting data for a specific user.
     * @dev This function retrieves the vesting details such as the total vested tokens, claimed tokens, unlocked tokens,
     * and allocation details for the specified user at a given time.
     * @param user The address of the user.
     * @param atTime The timestamp at which to check the user's vesting state.
     * @return totalVested The amount of vested tokens.
     * @return totalClaimed The amount of claimed tokens.
     * @return totalUnlocked The total number of tokens unlocked.
     * @return vested An array of vested tokens for each allocation.
     * @return claimed An array of claimed tokens for each allocation.
     * @return unlocked An array of unlocked tokens for each allocation.
     * @return allocationIds An array of allocation IDs.
     */
    function getUserState(
        address user,
        uint256 atTime
    )
        external
        view
        returns (
            uint256 totalVested,
            uint256 totalClaimed,
            uint256 totalUnlocked,
            uint256[] memory vested,
            uint256[] memory claimed,
            uint256[] memory unlocked,
            bytes32[] memory allocationIds
        )
    {
        if (atTime == 0) {
            atTime = block.timestamp;
        }

        allocationIds = _getAllocationIds();
        (
            totalVested,
            totalClaimed,
            totalUnlocked,
            vested,
            claimed,
            unlocked
        ) = _calculateUserVestingStateAtTime(allocationIds, user, atTime);
    }

    /**
     * @notice Shows the amount of tokens required to be supplied for vesting.
     * @dev This function can be called externally to get the current required supply of tokens for vesting.
     * It calculates the total supply of tokens required for vesting by subtracting the total claimed tokens from the total vested tokens,
     * and adjusting it based on the current token balance of the contract.
     * @return uint256 The amount of tokens required for vesting.
     */
    function getRequiredTokensSupply() external view returns (uint256) {
        return _calculateRequiredTokensSupply();
    }

    /**
     * @notice Allows the caller to claim their vested tokens.
     * @dev This function can only be called if the TGE (Token Generation Event) has passed.
     */
    function claim() external whenTgePassed {
        _claim(_msgSender());
    }

    /**
     * @notice Allows the owner to force claim vested tokens for multiple users.
     * @dev This function can only be called if the TGE (Token Generation Event) has passed.
     * Can only be called by the contract owner.
     * @param users An array of addresses for which to force claim vested tokens.
     */
    function claimForced(
        address[] memory users
    ) external whenTgePassed onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            _claim(users[i]);
        }
    }

    /**
     * @notice Sets the vesting parameters for a specific allocation.
     * @dev Can only be called by the contract owner.
     * WARNING: This function is not synchronized with the sales stages.
     * Ensures that the vesting parameters are set in accordance with the sales strategy.
     * Ensures that the TGE unlock percentage does not exceed the maximum allowed value.
     * @param allocationId The ID of the allocation to set the vesting parameters.
     * @param reserved The total amount of tokens reserved for this allocation.
     * @param lockup The lock-up period before vesting starts.
     * @param cliff The cliff period during which tokens cannot be claimed.
     * @param vesting The total vesting period over which tokens are gradually unlocked.
     * @param tgeUnlock The percentage of tokens unlocked immediately after the Token Generation Event (TGE).
     * @param unlockDelay The delay between successive unlocks after the cliff period.
     */
    function setVestingSchedule(
        bytes32 allocationId,
        uint256 reserved,
        uint256 lockup,
        uint256 cliff,
        uint256 vesting,
        uint256 tgeUnlock,
        uint256 unlockDelay
    ) external onlyOwner {
        _setVestingSchedule(
            allocationId,
            reserved,
            lockup,
            cliff,
            vesting,
            tgeUnlock,
            unlockDelay
        );
    }

    /**
     * @notice Sets the vesting parameters for multiple allocations at once.
     * @dev Can only be called by the contract owner.
     * WARNING: This function is not synchronized with the sales stages.
     * Ensures that the vesting parameters are set in accordance with the sales strategy.
     * Ensures that the TGE unlock percentage does not exceed the maximum allowed value.
     * @param schedules An array of VestingSchedule structs containing the vesting parameters for each allocation.
     */
    function setVestingScheduleBatch(
        VestingSchedule[] calldata schedules
    ) external onlyOwner {
        for (uint256 i = 0; i < schedules.length; i++) {
            _setVestingSchedule(
                schedules[i].allocationId,
                schedules[i].reserved,
                schedules[i].lockup,
                schedules[i].cliff,
                schedules[i].vesting,
                schedules[i].tgeUnlock,
                schedules[i].unlockDelay
            );
        }
    }

    /**
     * @notice Removes the vesting parameters for a specific allocation.
     * @dev Can only be called by the contract owner.
     * WARNING: This function is not synchronized with the sales stages. Ensure that the removal is in line with the sales strategy.
     * @param allocationId The ID of the allocation to remove.
     */
    function removeAllocation(bytes32 allocationId) external onlyOwner {
        _removeAllocation(allocationId);
    }

    /**
     * @notice Allows the owner to set the auto-claim status.
     * @dev Can only be called by the contract owner.
     * @param status The new status of auto-claim.
     */
    function setAutoClaimAfterTge(bool status) external onlyOwner {
        _setAutoClaimAfterTge(status);
    }

    /**
     * @notice Allows the owner to set the name and symbol of the vested token.
     * @dev Can only be called by the contract owner.
     * It sets the name and symbol of the vested token by calling a private function from the NonTransferableToken contract.
     * @param name_ The new name of the vested token.
     * @param symbol_ The new symbol of the vested token.
     */
    function setVestedTokenNameSymbol(
        string memory name_,
        string memory symbol_
    ) external onlyOwner {
        _setNonTransferableTokenNameSymbol(name_, symbol_);
    }

    /**
     * @notice Sets a new TokenSale address.
     * @dev Can only be called by the contract owner.
     * Emits a TokenSaleUpdated event.
     * @param tokenSale The address of the TokenSale.
     */
    function setTokenSale(address tokenSale) external onlyOwner {
        if (_tokenSaleFrozen) {
            revert TokenSaleIsFrozen();
        }
        _tokenSale = tokenSale;
        emit TokenSaleUpdated(tokenSale);
    }

    /**
     * @notice Freezes the TokenSale, preventing further changes.
     * @dev Can only be called by the contract owner.
     * Emits a TokenSaleFrozen event.
     */
    function freezeTokenSale() external onlyOwner {
        if (_tokenSale == address(0)) {
            revert TokenSaleIsZero();
        }
        if (_tokenSaleFrozen) {
            revert TokenSaleIsFrozen();
        }

        _tokenSaleFrozen = true;
        emit TokenSaleFrozen();
    }

    /**
     * @notice Sets the auto supply status and the address from which the tokens will be supplied.
     * @dev Can only be called by the contract owner.
     * It updates the auto supply status, the auto supply status upon claim, and the address from which the tokens will be automatically supplied.
     * @param autoSupply The new status of the auto supply (if autoSupplyOnClaim is false, then for allocating; if autoSupplyOnClaim is true, then for claiming).
     * @param autoSupplyOnClaim The new status of the auto supply upon claim (true if enabled, false if disabled).
     * @param autoSupplyFrom The address from which the tokens will be supplied.
     */
    function setAutoSupply(
        bool autoSupply,
        bool autoSupplyOnClaim,
        address autoSupplyFrom
    ) external onlyOwner {
        _autoSupply = autoSupply;
        _autoSupplyOnClaim = autoSupplyOnClaim;
        _autoSupplyFrom = autoSupplyFrom;
        emit AutoSupplyUpdated(autoSupply, autoSupplyOnClaim, autoSupplyFrom);
    }
    /**
     * @notice Supplies tokens based on the total vested and claimed tokens.
     * @dev Can only be called by the contract owner.
     * It calculates the total supply of tokens required for vesting by subtracting the total claimed tokens from the total vested tokens
     * and adjusts it based on the current token balance of the contract.
     * The tokens are supplied from the address specified in `_autoSupplyFrom`.
     * @param supplyAmount The amount of tokens to supply. If zero or greater than the required amount, the required amount will be supplied.
     */
    function supplyTokens(uint256 supplyAmount) external onlyOwner {
        _supplyTokensFrom(_autoSupplyFrom, supplyAmount, false);
    }

    /**
     * @notice Supplies reserved tokens based on the total reserved and claimed tokens.
     * @dev Can only be called by the contract owner.
     * It calculates the total supply of reserved tokens required for vesting by subtracting the total claimed tokens from the total reserved tokens
     * and adjusts it based on the current token balance of the contract.
     * The tokens are supplied from the address specified in `_autoSupplyFrom`.
     * @param supplyAmount The amount of tokens to supply. If zero or greater than the required amount, the required amount will be supplied.
     */
    function supplyReservedTokens(uint256 supplyAmount) external onlyOwner {
        _supplyTokensFrom(_autoSupplyFrom, supplyAmount, true);
    }

    /**
     * @notice Handles the purchase of tokens for a specific user during a token sale stage.
     * @dev This function is called by the TokenSale contract when tokens are purchased.
     * It verifies the allocation exists and increases the vested amount for the user.
     * @param user The address of the user purchasing tokens.
     * @param stageId The ID of the sale stage.
     * @param tokensToBuy The amount of tokens being purchased.
     * @return bool Returns true if this is successfully processed.
     */
    function onTokensPurchase(
        address user,
        uint256 stageId,
        uint256 tokensToBuy
    ) external override onlyTokenSale returns (bool) {
        if (_isAutoSupplyOnAllocatingApplicable()) {
            _supplyTokensFrom(_autoSupplyFrom, tokensToBuy, false);
        }

        _increaseUserAllocationVested(
            user,
            _computeAllocationId(stageId.toString()),
            tokensToBuy
        );
        return true;
    }

    /**
     * @notice Allocates tokens to a user's vesting allocation.
     * @dev Can only be called by the contract owner.
     * This function adds a specified amount of tokens to the vesting schedule for a given user.
     * @param user The address of the user.
     * @param allocationId The ID of the allocation.
     * @param amount The amount of tokens to add to the vesting allocation.
     * @return bool Returns true if this is successfully processed.
     */
    function allocateTokens(
        address user,
        bytes32 allocationId,
        uint256 amount
    ) external onlyOwner returns (bool) {
        _increaseUserAllocationVested(user, allocationId, amount);

        if (_isAutoSupplyOnAllocatingApplicable()) {
            _supplyTokensFrom(_autoSupplyFrom, amount, false);
        }
        return true;
    }

    /**
     * @notice Allocates tokens to multiple users' vesting allocations.
     * @dev Can only be called by the contract owner.
     * This function adds a specified amount of tokens to the vesting schedule for each user and allocation pair in the list.
     * @param allocationIds An array of allocation IDs.
     * @param users The addresses of the users.
     * @param amounts The amounts of tokens to add to the vesting allocation for each user.
     * @return bool Returns true if this is successfully processed.
     */
    function allocateTokensBatch(
        bytes32[] calldata allocationIds,
        address[] calldata users,
        uint256[] calldata amounts
    ) external onlyOwner returns (bool) {
        uint256 total = allocationIds.length;
        if (users.length != total || amounts.length != total) {
            revert ParametersMismatch();
        }

        uint256 supplyAmount;
        for (uint256 i = 0; i < total; i++) {
            _increaseUserAllocationVested(
                users[i],
                allocationIds[i],
                amounts[i]
            );
            supplyAmount += amounts[i];
        }

        if (_isAutoSupplyOnAllocatingApplicable()) {
            _supplyTokensFrom(_autoSupplyFrom, supplyAmount, false);
        }
        return true;
    }

    /**
     * @dev Private function to calculate the total supply of tokens required for vesting.
     * This function calculates the difference between the total vested tokens and the total claimed tokens,
     * and adjusts it based on the current token balance of the contract.
     * @return uint256 The amount of tokens required for vesting.
     */
    function _calculateRequiredTokensSupply()
        private
        view
        whenSellableTokenIsNotZero
        returns (uint256)
    {
        uint256 requiredSupply = _totalVested - _totalClaimed;

        uint256 balance = IERC20(_getSellableToken()).balanceOf(address(this));
        if (balance >= requiredSupply) {
            return 0;
        } else {
            return requiredSupply - balance;
        }
    }

    /**
     * @dev Private function to calculate the total supply of tokens required for vesting.
     * This function calculates the difference between the total reserved tokens and the total claimed tokens,
     * and adjusts it based on the current token balance of the contract.
     * @return uint256 The amount of tokens required for vesting.
     */
    function _calculateReservedTokensSupply()
        private
        view
        whenSellableTokenIsNotZero
        returns (uint256)
    {
        uint256 requiredSupply = _totalReserved - _totalClaimed;

        uint256 balance = IERC20(_getSellableToken()).balanceOf(address(this));
        if (balance >= requiredSupply) {
            return 0;
        } else {
            return requiredSupply - balance;
        }
    }

    /**
     * @dev Checks if auto supply is applicable for allocating by verifying that auto supply is enabled, auto supply on claim is disabled, and the auto supply address is set.
     * This function ensures that the auto supply is enabled, auto supply on claim is disabled, and the address from which tokens should be supplied is not the zero address.
     * @return bool Returns true if auto supply is applicable for allocating and the address is set, otherwise returns false.
     */
    function _isAutoSupplyOnAllocatingApplicable() private view returns (bool) {
        if (
            _autoSupply && !_autoSupplyOnClaim && _autoSupplyFrom != address(0)
        ) {
            return true;
        }
        return false;
    }

    /**
     * @dev Checks if auto supply is applicable for claiming by verifying that auto supply is enabled, auto supply on claim is enabled, and the auto supply address is set.
     * This function ensures that the auto supply is enabled, auto supply on claim is enabled, and the address from which tokens should be supplied is not the zero address.
     * @return bool Returns true if auto supply is applicable for claiming and the address is set, otherwise returns false.
     */
    function _isAutoSupplyOnClaimingApplicable() private view returns (bool) {
        if (
            _autoSupply && _autoSupplyOnClaim && _autoSupplyFrom != address(0)
        ) {
            return true;
        }
        return false;
    }

    /**
     * @dev Private function to supply tokens from a specified address.
     * This function handles the actual transfer of tokens from the specified address to the contract.
     * It calculates the required supply and performs the transfer.
     * @param from The address from which the tokens will be transferred.
     * @param supplyAmount The amount of tokens to supply.
     * @param isSupplyReserved Indicates whether the supply is for reserved tokens.
     */
    function _supplyTokensFrom(
        address from,
        uint256 supplyAmount,
        bool isSupplyReserved
    ) private {
        uint256 requiredSupply;
        if (isSupplyReserved) {
            requiredSupply = _calculateReservedTokensSupply();
        } else {
            requiredSupply = _calculateRequiredTokensSupply();
        }

        if (requiredSupply == 0) {
            return;
        }

        if (supplyAmount == 0 || supplyAmount > requiredSupply) {
            supplyAmount = requiredSupply;
        }

        IERC20 _token = IERC20(_getSellableToken());
        uint256 before = _token.balanceOf(address(this));
        // If the SellableToken is mintable, then mint here in the transferFrom function.
        _token.safeTransferFrom(from, address(this), supplyAmount);

        uint256 delta = _token.balanceOf(address(this)) - before;
        // Check and prohibition of tax tokens.
        if (delta != supplyAmount) {
            revert InvalidTokenAmount();
        }
        emit TokensSupplied(supplyAmount);
    }

    /**
     * @dev Private function to get the vesting data for a specific allocation.
     * @param allocationId The ID of the allocation.
     * @return The vesting data for the specified allocation.
     */
    function _getVesting(
        bytes32 allocationId
    ) private view returns (VestingData memory) {
        return _vesting[allocationId];
    }

    /**
     * @dev Private function to get the amount of vested tokens for a user at a specific allocation.
     * @param user The address of the user.
     * @param allocationId The ID of the vesting allocation.
     * @return The vesting data for the specified user and allocation.
     */
    function _getUserVesting(
        address user,
        bytes32 allocationId
    ) private view returns (UserVestingData memory) {
        return _userVesting[user][allocationId];
    }

    /**
     * @dev Private function to increase the vested tokens for a user at a specific allocation.
     * Mints non-transferable tokens to the user.
     * Emits a VestingAccrued event.
     * Reverts with an AllocationExceeded error if the vested amount exceeds the reserved amount.
     * @param user The address of the user.
     * @param allocationId The ID of the allocation.
     * @param amount The amount of tokens to vest.
     */
    function _increaseUserAllocationVested(
        address user,
        bytes32 allocationId,
        uint256 amount
    ) private allocationIdExists(allocationId) {
        _totalVested += amount;

        // Check if vested tokens exceed reserved tokens.
        _vesting[allocationId].vested += amount;
        if (_vesting[allocationId].vested > _vesting[allocationId].reserved) {
            revert AllocationExceeded(allocationId);
        }

        _userVesting[user][allocationId].vested += amount;
        _mintNonTransferableToken(user, amount);
        emit VestingAccrued(user, allocationId, amount);

        if (_autoClaimAfterTge && _isTgePassed()) {
            _claim(user);
        }
    }

    /**
     * @dev Private function to increase the total claimed tokens and update the user's claimed tokens.
     * Burns the corresponding amount of non-transferable tokens from the user's balance.
     * Emits a VestingClaimed event.
     * @param user The address of the user whose claimed tokens are being increased.
     * @param allocationId The ID of the allocation.
     * @param _token The sellable token used for transfer.
     * @param amount The amount of tokens to be marked as claimed.
     */
    function _claimAllocation(
        address user,
        bytes32 allocationId,
        IERC20 _token,
        uint256 amount
    ) private {
        _totalClaimed += amount;
        _vesting[allocationId].claimed += amount;

        _userVesting[user][allocationId].claimed += amount;
        _burnNonTransferableToken(user, amount);

        _token.safeTransfer(user, amount);
        emit VestingClaimed(user, allocationId, amount);
    }

    /**
     * @dev Private function to claim vested tokens for a user.
     * Transfers the claimable tokens to the user and updates the claimed tokens.
     * @param user The address of the user claiming the tokens.
     */
    function _claim(address user) private whenSellableTokenIsNotZero {
        bytes32[] memory allocationIds = _getAllocationIds();
        (
            ,
            uint256 totalClaimed,
            uint256 totalUnlocked,
            ,
            uint256[] memory claimed,
            uint256[] memory unlocked
        ) = _calculateUserVestingStateAtTime(
                allocationIds,
                user,
                block.timestamp
            );

        uint256 totalClaimable;
        if (totalUnlocked > totalClaimed) {
            totalClaimable = totalUnlocked - totalClaimed;
        }

        if (totalClaimable > 0) {
            if (_isAutoSupplyOnClaimingApplicable()) {
                _supplyTokensFrom(_autoSupplyFrom, totalClaimable, false);
            }

            IERC20 _token = IERC20(_getSellableToken());
            uint256 totalAllocations = allocationIds.length;
            for (uint256 i = 0; i < totalAllocations; i++) {
                uint256 claimable;
                if (unlocked[i] > claimed[i]) {
                    claimable = unlocked[i] - claimed[i];
                }

                if (claimable > 0) {
                    _claimAllocation(user, allocationIds[i], _token, claimable);
                }
            }
        }
    }

    /**
     * @dev Private function to calculate the unlocked vested tokens for a user at a specific time.
     * @param allocationIds An array of allocation IDs.
     * @param user The address of the user.
     * @param atTime The specific time to check for unlocked tokens.
     * @return totalVested The total amount of vested tokens.
     * @return totalClaimed The total amount of claimed tokens.
     * @return totalUnlocked The amount of unlocked vested tokens.
     * @return vested Array of vested tokens for each allocation.
     * @return claimed Array of claimed tokens for each allocation.
     * @return unlocked Array of unlocked vested tokens for each allocation.
     */
    function _calculateUserVestingStateAtTime(
        bytes32[] memory allocationIds,
        address user,
        uint256 atTime
    )
        private
        view
        returns (
            uint256 totalVested,
            uint256 totalClaimed,
            uint256 totalUnlocked,
            uint256[] memory vested,
            uint256[] memory claimed,
            uint256[] memory unlocked
        )
    {
        uint256 totalAllocations = allocationIds.length;
        vested = new uint256[](totalAllocations);
        claimed = new uint256[](totalAllocations);
        unlocked = new uint256[](totalAllocations);

        for (uint256 i = 0; i < totalAllocations; i++) {
            bytes32 allocationId = allocationIds[i];
            VestingData memory vd = _getVesting(allocationId);
            UserVestingData memory uvd = _getUserVesting(user, allocationId);

            if (uvd.vested == 0) {
                // The user does not have any tokens to vest in this allocation.
                continue;
            }
            totalVested += uvd.vested;
            totalClaimed += uvd.claimed;
            vested[i] = uvd.vested;
            claimed[i] = uvd.claimed;

            uint256 unlockedAtTime = _calculateUserUnlockedAtTime(
                vd,
                uvd,
                atTime
            );
            totalUnlocked += unlockedAtTime;
            unlocked[i] = unlockedAtTime;
        }
    }

    /**
     * @dev Private function to calculate the total amount of unlocked tokens for a user at a specific time based on vesting data.
     * @param vd The vesting data associated with the allocation.
     * @param uvd The user's vesting data for the allocation.
     * @param atTime The specific time to check for unlocked tokens.
     * @return totalUnlocked The total amount of unlocked tokens at the specified time.
     */
    function _calculateUserUnlockedAtTime(
        VestingData memory vd,
        UserVestingData memory uvd,
        uint256 atTime
    ) private view returns (uint256 totalUnlocked) {
        uint256 tge = _getTgeTimestamp();
        if (tge == 0 || atTime < tge) {
            // The TGE event has not yet occurred. Then unlocked is 0.
            return totalUnlocked;
        }

        uint256 tgeUnlocked = (uvd.vested * vd.tgeUnlock) / DENOMINATOR;
        uint256 restVested = uvd.vested - tgeUnlocked;
        totalUnlocked += tgeUnlocked;

        uint256 vestingStartTime = tge + vd.lockup;
        if (atTime < vestingStartTime) {
            // Unlocking tokens from vesting has not yet begun.
            return totalUnlocked;
        }

        uint256 cliffEndTime = vestingStartTime + vd.cliff;
        if (atTime < cliffEndTime) {
            // Unlocking of tokens has already begun, but the claim is impossible until the end of the cliff period.
            return totalUnlocked;
        }

        uint256 vestingEndTime = vestingStartTime + vd.vesting;
        if (atTime >= vestingEndTime) {
            // Vesting is done. The entire amount is available for claim.
            return uvd.vested;
        }

        if (atTime >= cliffEndTime) {
            uint256 passedTime = atTime - vestingStartTime;
            if (vd.unlockDelay > 0) {
                // Fix if the interval between claims is specified.
                uint256 unlocks = passedTime / vd.unlockDelay;
                passedTime = unlocks * vd.unlockDelay;
            }
            uint256 unlockedAtTime = (restVested * passedTime) / vd.vesting;
            totalUnlocked += unlockedAtTime;
        }
    }

    /**
     * @dev Private function to calculate the unlocked vested tokens for all allocations at a specific time.
     * @param allocationIds An array of allocation IDs.
     * @param atTime The specific time to check for unlocked tokens.
     * @return totalVested The total amount of vested tokens across all allocations.
     * @return totalClaimed The total amount of claimed tokens across all allocations.
     * @return totalUnlocked The amount of unlocked vested tokens at the specified time.
     * @return reserved Array of reserved tokens for each allocation.
     * @return vested Array of vested tokens for each allocation.
     * @return claimed Array of claimed tokens for each allocation.
     * @return unlocked Array of unlocked vested tokens for each allocation.
     */
    function _calculateVestingStateAtTime(
        bytes32[] memory allocationIds,
        uint256 atTime
    )
        private
        view
        returns (
            uint256 totalVested,
            uint256 totalClaimed,
            uint256 totalUnlocked,
            uint256[] memory reserved,
            uint256[] memory vested,
            uint256[] memory claimed,
            uint256[] memory unlocked
        )
    {
        uint256 totalAllocations = allocationIds.length;
        reserved = new uint256[](totalAllocations);
        vested = new uint256[](totalAllocations);
        claimed = new uint256[](totalAllocations);
        unlocked = new uint256[](totalAllocations);

        for (uint256 i = 0; i < totalAllocations; i++) {
            bytes32 allocationId = allocationIds[i];
            VestingData memory vd = _getVesting(allocationId);

            reserved[i] = vd.reserved;

            if (vd.vested == 0) {
                // Does not have any tokens to vest in this allocation.
                continue;
            }
            totalVested += vd.vested;
            totalClaimed += vd.claimed;
            vested[i] = vd.vested;
            claimed[i] = vd.claimed;

            uint256 unlockedAtTime = _calculateUnlockedAtTime(vd, atTime);
            totalUnlocked += unlockedAtTime;
            unlocked[i] = unlockedAtTime;
        }
    }

    /**
     * @dev Private function to calculate the total amount of unlocked tokens for a specific allocation at a specific time.
     * @param vd The vesting data associated with the allocation.
     * @param atTime The specific time to check for unlocked tokens.
     * @return totalUnlocked The total amount of unlocked tokens at the specified time.
     */
    function _calculateUnlockedAtTime(
        VestingData memory vd,
        uint256 atTime
    ) private view returns (uint256 totalUnlocked) {
        uint256 tge = _getTgeTimestamp();
        if (tge == 0 || atTime < tge) {
            // The TGE event has not yet occurred. Then unlocked is 0.
            return totalUnlocked;
        }

        uint256 tgeUnlocked = (vd.vested * vd.tgeUnlock) / DENOMINATOR;
        uint256 restVested = vd.vested - tgeUnlocked;
        totalUnlocked += tgeUnlocked;

        uint256 vestingStartTime = tge + vd.lockup;
        if (atTime < vestingStartTime) {
            // Unlocking tokens from vesting has not yet begun.
            return totalUnlocked;
        }

        uint256 cliffEndTime = vestingStartTime + vd.cliff;
        if (atTime < cliffEndTime) {
            // Unlocking of tokens has already begun, but the claim is impossible until the end of the cliff period.
            return totalUnlocked;
        }

        uint256 vestingEndTime = vestingStartTime + vd.vesting;
        if (atTime >= vestingEndTime) {
            // Vesting is done. The entire amount is available for claim.
            return vd.vested;
        }

        if (atTime >= cliffEndTime) {
            uint256 passedTime = atTime - vestingStartTime;
            if (vd.unlockDelay > 0) {
                // Fix if the interval between claims is specified.
                uint256 unlocks = passedTime / vd.unlockDelay;
                passedTime = unlocks * vd.unlockDelay;
            }
            uint256 unlockedAtTime = (restVested * passedTime) / vd.vesting;
            totalUnlocked += unlockedAtTime;
        }
    }

    /**
     * @dev Private function to set the vesting parameters for a specific allocation.
     * WARNING: This function is not synchronized with the sales stages.
     * Ensures that the vesting parameters are set in accordance with the sales strategy.
     * Ensures that the TGE unlock percentage does not exceed the maximum allowed value.
     * Emits an AllocationUpdated event.
     * @param allocationId The ID of the allocation to set the vesting parameters.
     * @param reserved The total amount of tokens reserved for this allocation.
     * @param lockup The lock-up period before vesting starts.
     * @param cliff The cliff period during which tokens cannot be claimed.
     * @param vesting The total vesting period over which tokens are gradually unlocked.
     * @param tgeUnlock The percentage of tokens unlocked immediately after the Token Generation Event (TGE).
     * @param unlockDelay The delay between successive unlocks after the cliff period.
     */
    function _setVestingSchedule(
        bytes32 allocationId,
        uint256 reserved,
        uint256 lockup,
        uint256 cliff,
        uint256 vesting,
        uint256 tgeUnlock,
        uint256 unlockDelay
    ) private {
        if (tgeUnlock > DENOMINATOR) {
            revert TgeUnlockExceedsMaximum();
        }

        if (!_isAllocationIdExist(allocationId)) {
            _allocationIds.push(allocationId);
            _allocationIdExist[allocationId] = true;
        }

        VestingData storage vestingData = _vesting[allocationId];

        if (vestingData.vested > reserved) {
            revert ReservedLessThanVested(allocationId);
        }
        _totalReserved = _totalReserved - vestingData.reserved + reserved;
        vestingData.reserved = reserved;

        vestingData.lockup = lockup;
        vestingData.cliff = cliff;
        vestingData.vesting = vesting;
        vestingData.tgeUnlock = tgeUnlock;
        vestingData.unlockDelay = unlockDelay;

        emit AllocationUpdated(
            allocationId,
            reserved,
            lockup,
            cliff,
            vesting,
            tgeUnlock,
            unlockDelay
        );
    }

    /**
     * @dev Private function to remove the vesting parameters for a specific allocation.
     * WARNING: This function is not synchronized with the sales stages. Ensure that the vesting parameters are removed in accordance with the sales strategy.
     * Emits an AllocationDeleted event.
     * @param allocationId The ID of the allocation to remove the vesting parameters for.
     */
    function _removeAllocation(bytes32 allocationId) private {
        VestingData memory vestingData = _getVesting(allocationId);
        if (vestingData.vested > 0) {
            revert AllocationAlreadyUsed();
        }

        bytes32[] memory allocationIds = _getAllocationIds();
        uint256 index = _findAllocationIndex(allocationId, allocationIds);
        uint256 lastIndex = allocationIds.length - 1;
        bytes32 lastAllocationId = _allocationIds[lastIndex];

        _allocationIds[index] = lastAllocationId; // Move the last allocation ID to the index being removed.
        _allocationIds.pop(); // Remove the last element.

        delete _vesting[allocationId];
        delete _allocationIdExist[allocationId];
        emit AllocationDeleted(allocationId);
    }

    /**
     * @dev Private function to compute the allocation ID for a given allocation name.
     * This function computes the keccak-256 hash of the given allocation name, subtracts 1, and returns it as bytes32.
     * @param allocationName The name of the allocation.
     * @return allocationId The computed ID of the allocation.
     */
    function _computeAllocationId(
        string memory allocationName
    ) private pure returns (bytes32 allocationId) {
        return
            bytes32(
                abi.encode(uint256(keccak256(abi.encode(allocationName))) - 1)
            );
    }

    /**
     * @dev Checks if a given allocation ID exists in the allowed allocation IDs list.
     * This function is used internally to verify if a specific allocation ID is present in the contract's allocation list.
     * @param allocationId The ID of the allocation to check.
     * @return bool Returns true if the allocation exists, false otherwise.
     */
    function _isAllocationIdExist(
        bytes32 allocationId
    ) private view returns (bool) {
        return _allocationIdExist[allocationId];
    }

    /**
     * @dev Checks if a given allocation ID exists in the allowed allocation IDs list and reverts if it does not exist.
     * This function is used internally to ensure that an allocation ID is valid before proceeding with further logic.
     * If the allocation does not exist, it reverts with a custom error `AllocationNotFound`.
     * @param allocationId The ID of the allocation to check.
     */
    function _checkAllocationIdExistence(bytes32 allocationId) private view {
        if (!_isAllocationIdExist(allocationId)) {
            revert AllocationNotFound(allocationId);
        }
    }

    /**
     * @dev Internal function to retrieve the list of all allowed allocation IDs.
     * @return bytes32[] List of allowed allocation IDs.
     */
    function _getAllocationIds() private view returns (bytes32[] memory) {
        return _allocationIds;
    }

    /**
     * @dev Internal function to get the total number of vesting allocations.
     * @return The total number of vesting allocations.
     */
    function _getTotalAllocations() private view returns (uint256) {
        return _allocationIds.length;
    }

    /**
     * @dev Finds the index of a given allocation in an array of allocation IDs.
     * This function searches for a specific allocation ID within an array of allocation IDs and returns its index.
     * If the allocation does not exist, it reverts with a custom error `AllocationNotFound`.
     * @param allocationId The allocation ID to find.
     * @param allocationIds An array of allocation IDs.
     * @return uint256 The index of the found allocation.
     */
    function _findAllocationIndex(
        bytes32 allocationId,
        bytes32[] memory allocationIds
    ) private pure returns (uint256) {
        for (uint256 i = 0; i < allocationIds.length; i++) {
            if (allocationIds[i] == allocationId) {
                return i;
            }
        }
        revert AllocationNotFound(allocationId);
    }

    /**
     * @dev Private function to set the auto-claim status.
     * Emits an AutoClaimAfterTgeUpdated event.
     * @param status The new status of auto-claim.
     */
    function _setAutoClaimAfterTge(bool status) private {
        _autoClaimAfterTge = status;
        emit AutoClaimAfterTgeUpdated(status);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title TgeTimestamp
 * @dev Abstract contract to manage the Token Generation Event (TGE) timestamp.
 * Allows setting, freezing, and checking the TGE timestamp.
 * Inherits from Ownable2Step.
 */
abstract contract TgeTimestamp is Ownable2Step {
    /// @dev Timestamp of the Token Generation Event (TGE).
    uint256 private _tgeTimestamp;

    /// @dev Flag to indicate if the TGE timestamp is frozen.
    bool private _tgeTimestampFrozen;

    /// @dev Event emitted when the TGE timestamp is changed.
    event TgeTimestampUpdated(uint256 tgeTimestamp);

    /// @dev Event emitted when the TGE timestamp is frozen.
    event TgeTimestampFrozen();

    /// @dev Error indicating that the TGE has not yet passed.
    error TgeTimestampNotPassed();

    /// @dev Error indicating that the TGE has already passed.
    error TgeTimestampPassed();

    /// @dev Error indicating that the TGE timestamp is zero.
    error TgeTimestampIsZero();

    /// @dev Error indicating that the TGE timestamp is frozen and cannot be changed.
    error TgeTimestampIsFrozen();

    /// @dev Error indicating that the provided timestamp has already passed.
    error TimeAlreadyPassed();

    /**
     * @dev Sets the initial value for the TGE timestamp.
     * @param tgeTimestamp The initial TGE timestamp.
     */
    constructor(uint256 tgeTimestamp) {
        _setTgeTimestamp(tgeTimestamp);
    }

    /// @dev Modifier to make a function callable only when the TGE has passed.
    modifier whenTgePassed() {
        if (!_isTgePassed()) {
            revert TgeTimestampNotPassed();
        }
        _;
    }

    /**
     * @notice Returns the TGE timestamp details.
     * @return isFrozen Boolean indicating if the TGE timestamp is frozen.
     * @return tge The TGE timestamp.
     */
    function getTge() external view returns (bool isFrozen, uint256 tge) {
        isFrozen = _isTgeTimestampFrozen();
        tge = _getTgeTimestamp();
    }

    /**
     * @notice Sets the TGE timestamp.
     * @dev Can only be called by the contract owner and if the TGE timestamp is not frozen and has not passed.
     * @param newTgeTimestamp The new TGE timestamp.
     */
    function setTgeTimestamp(uint256 newTgeTimestamp) external onlyOwner {
        uint256 currentTge = _getTgeTimestamp();
        if (currentTge > 0 && block.timestamp >= currentTge) {
            revert TgeTimestampPassed();
        }

        if (block.timestamp > newTgeTimestamp) {
            revert TimeAlreadyPassed();
        }

        if (_isTgeTimestampFrozen()) {
            revert TgeTimestampIsFrozen();
        }

        _setTgeTimestamp(newTgeTimestamp);
    }

    /**
     * @notice Freezes the TGE timestamp, preventing any future changes.
     * @dev Can only be called by the contract owner and if the TGE timestamp is not frozen and is not zero.
     */
    function freezeTgeTimestamp() external onlyOwner {
        if (_getTgeTimestamp() == 0) {
            revert TgeTimestampIsZero();
        }
        if (_tgeTimestampFrozen) {
            revert TgeTimestampIsFrozen();
        }

        _tgeTimestampFrozen = true;
        emit TgeTimestampFrozen();
    }

    /**
     * @dev Internal function to get the TGE timestamp.
     * @return uint256 The TGE timestamp.
     */
    function _getTgeTimestamp() internal view returns (uint256) {
        return _tgeTimestamp;
    }

    /**
     * @dev Internal function to check if the Token Generation Event (TGE) has passed.
     * @return Returns true if the TGE has passed, false otherwise.
     */
    function _isTgePassed() internal view returns (bool) {
        uint256 tge = _getTgeTimestamp();
        if (tge == 0 || block.timestamp < tge) {
            return false;
        }
        return true;
    }

    /**
     * @dev Private function to check if the TGE timestamp is frozen.
     * @return bool True if the TGE timestamp is frozen, false otherwise.
     */
    function _isTgeTimestampFrozen() private view returns (bool) {
        return _tgeTimestampFrozen;
    }

    /**
     * @dev Private function to set the TGE (Token Generation Event) timestamp
     * Emits a TgeTimestampUpdated event.
     * @param tgeTimestamp The new TGE timestamp.
     */
    function _setTgeTimestamp(uint256 tgeTimestamp) private {
        _tgeTimestamp = tgeTimestamp;
        emit TgeTimestampUpdated(tgeTimestamp);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title SellableToken
 * @dev Abstract contract to manage a sellable token address and its decimals. Allows setting and freezing the sellable token.
 * Inherits from Ownable2Step.
 */
abstract contract SellableToken is Ownable2Step {
    /// @dev Indicates whether the sellable token is frozen.
    bool private _sellableTokenFrozen;

    /// @dev Address of the sellable token.
    address private _sellableToken;

    /// @dev Number of decimals of the sellable token.
    uint8 private _sellableTokenDecimals;

    /// @dev Event emitted when the sellable token is updated.
    event SellableTokenUpdated(address token, uint8 decimals);

    /// @dev Event emitted when the sellable token is frozen.
    event SellableTokenFrozen();

    /// @dev Error thrown when the sellable token address is zero.
    error SellableTokenIsZero();

    /// @dev Error thrown when the sellable token decimals is zero.
    error SellableTokenDecimalsIsZero();

    /// @dev Error thrown when the sellable token is frozen.
    error SellableTokenIsFrozen();

    /**
     * @dev Sets the initial values for the sellable token and its decimals.
     * @param token The address of the sellable token.
     * @param decimals The number of decimals of the sellable token. Must be greater than 0.
     */
    constructor(address token, uint8 decimals) {
        _setSellableToken(token, decimals);
    }

    /// @dev Modifier to check if the sellable token address is not zero.
    modifier whenSellableTokenIsNotZero() {
        if (_getSellableToken() == address(0)) {
            revert SellableTokenIsZero();
        }
        _;
    }

    /**
     * @notice Gets the sellable token details.
     * @return isFrozen Boolean indicating if the sellable token is frozen.
     * @return token The address of the sellable token.
     * @return decimals The number of decimals of the sellable token.
     */
    function getSellableToken()
        external
        view
        returns (bool isFrozen, address token, uint8 decimals)
    {
        isFrozen = _isSellableTokenFrozen();
        token = _getSellableToken();
        decimals = _getSellableTokenDecimals();
    }

    /**
     * @notice Sets the sellable token and its decimals.
     * @dev Can only be called by the contract owner and if the sellable token is not frozen.
     * @param token The address of the sellable token.
     * @param decimals The number of decimals of the sellable token. Must be greater than 0.
     */
    function setSellableToken(
        address token,
        uint8 decimals
    ) external onlyOwner {
        if (_isSellableTokenFrozen()) {
            revert SellableTokenIsFrozen();
        }
        _setSellableToken(token, decimals);
    }

    /**
     * @notice Freezes the sellable token, preventing further changes to its address or decimals.
     * @dev Can only be called by the contract owner and only if the sellable token is not already frozen.
     * This action is irreversible. Once the sellable token is frozen, it cannot be unfrozen.
     * Emits a SellableTokenFrozen event upon successful freezing of the sellable token.
     */
    function freezeSellableToken()
        external
        whenSellableTokenIsNotZero
        onlyOwner
    {
        if (_sellableTokenFrozen) {
            revert SellableTokenIsFrozen();
        }

        _sellableTokenFrozen = true;
        emit SellableTokenFrozen();
    }

    /**
     * @dev Internal function to get the address of the sellable token.
     * @return The address of the sellable token.
     */
    function _getSellableToken() internal view returns (address) {
        return _sellableToken;
    }

    /**
     * @dev Internal function to get the number of decimals of the sellable token.
     * @return The number of decimals of the sellable token.
     */
    function _getSellableTokenDecimals() internal view returns (uint8) {
        return _sellableTokenDecimals;
    }

    /**
     * @dev Private function to check if the sellable token is frozen.
     * @return Boolean indicating if the sellable token is frozen.
     */
    function _isSellableTokenFrozen() private view returns (bool) {
        return _sellableTokenFrozen;
    }

    /**
     * @dev Private function to set the sellable token and its decimals.
     * Emits a SellableTokenUpdated event.
     * @param token The address of the sellable token.
     * @param decimals The number of decimals of the sellable token. Must be greater than 0.
     */
    function _setSellableToken(address token, uint8 decimals) private {
        if (decimals == 0) {
            revert SellableTokenDecimalsIsZero();
        }

        _sellableToken = token;
        _sellableTokenDecimals = decimals;
        emit SellableTokenUpdated(token, decimals);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RecoverableFunds
 * @dev Abstract contract that allows the owner to recover accidentally sent ERC20 tokens
 * and native coins (ETH) that are not part of the project's tracked funds.
 * Ensures the amount to be recovered does not exceed the recoverable balance.
 * Inherits from Ownable2Step and ReentrancyGuard.
 */
abstract contract RecoverableFunds is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /**
     * @dev Emitted when funds are recovered.
     * @param user The address that received the recovered funds.
     * @param token The address of the recovered ERC20 token or address(0) for ETH.
     * @param amount The amount of ERC20 tokens or ETH recovered.
     */
    event FundsRecovered(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    /// @dev Error to indicate that the amount to be recovered exceeds the recoverable balance.
    error AmountExceedsRecoverableFunds();

    /// @dev Error to indicate that the recipient address is zero.
    error RecipientIsZeroAddress();

    /**
     * @notice Returns the recoverable amount of a specific token or ETH.
     * @dev If the `token` is the zero address, it returns the balance of the contract in ETH.
     * Otherwise, it returns the balance of the specified ERC20 token held by the contract.
     * This function is designed to be overridden in derived contracts if needed.
     * @param token The address of the ERC20 token or the zero address for ETH.
     * @return The recoverable amount of the specified token or ETH.
     */
    function getRecoverableFunds(
        address token
    ) public view virtual returns (uint256) {
        if (token == address(0)) return address(this).balance;
        else return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Allows the owner to recover ERC20 tokens and native coins (ETH) accidentally sent to the contract.
     * @dev Can only be called by the contract owner.
     * Ensures the amount to be recovered does not exceed the recoverable balance.
     * Emits a FundsRecovered event.
     * @param user The address to receive recovered funds from the contract.
     * @param token The address of the ERC20 token to recover or address(0) to recover ETH.
     * @param amount The amount of ERC20 tokens or ETH to recover.
     * @return Returns true if the recovery was successful.
     */
    function recoverFunds(
        address user,
        address token,
        uint256 amount
    ) external onlyOwner nonReentrant returns (bool) {
        if (user == address(0)) {
            revert RecipientIsZeroAddress();
        }

        uint256 recoverableAmount = getRecoverableFunds(token);
        if (amount > recoverableAmount) {
            revert AmountExceedsRecoverableFunds();
        }

        _transferRecoverableFundsTo(user, token, amount);
        emit FundsRecovered(user, token, amount);
        return true;
    }

    /**
     * @dev Private function to handle the transfer of recovered funds.
     * @param user The address to receive the recovered funds.
     * @param token The address of the ERC20 token to recover or address(0) to recover ETH.
     * @param amount The amount of ERC20 tokens or ETH to recover.
     */
    function _transferRecoverableFundsTo(
        address user,
        address token,
        uint256 amount
    ) private {
        if (token == address(0)) {
            payable(user).sendValue(amount);
        } else {
            IERC20(token).safeTransfer(user, amount);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title NonTransferableToken
 * @dev @dev Abstract contract. Implementation of the {IERC20} and {IERC20Metadata} interfaces to display non-transferable tokens.
 */
abstract contract NonTransferableToken is IERC20, IERC20Metadata {
    string private _name;
    string private _symbol;

    /// @dev Event emitted when the token metadata is updated.
    event NonTransferableTokenMetadataUpdated(string name, string symbol);

    /// @dev Indicates that a function can't be used.
    error NonTransferableTokenUnusedFunction();

    /**
     * @dev Sets the values for {name} and {symbol}.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     */
    constructor(string memory name_, string memory symbol_) {
        _setNonTransferableTokenNameSymbol(name_, symbol_);
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20Metadata-name}.
     * @return The name of the token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20Metadata-symbol}.
     * @return The symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20Metadata-decimals}.
     * @return The number of decimals used to get its user representation.
     */
    function decimals() public view virtual returns (uint8) {
        return 18; // Placeholder, should be overridden in derived contracts.
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20-totalSupply}.
     * @return The total supply of the token.
     */
    function totalSupply() public view virtual returns (uint256) {
        return 0; // Placeholder, should be overridden in derived contracts.
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20-balanceOf}.
     * @return The balance of the specified user.
     */
    function balanceOf(address) public view virtual returns (uint256) {
        return 0; // Placeholder, should be overridden in derived contracts.
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20-transfer}.
     * @return Always reverts with NonTransferableTokenUnusedFunction.
     */
    function transfer(address, uint256) external pure returns (bool) {
        revert NonTransferableTokenUnusedFunction();
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20-allowance}.
     * @return Always return 0.
     */
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20-approve}.
     * @return Always reverts with NonTransferableTokenUnusedFunction.
     */
    function approve(address, uint256) external pure returns (bool) {
        revert NonTransferableTokenUnusedFunction();
    }

    /**
     * @dev Imitation of ERC20 function. See {IERC20-transferFrom}.
     * @return Always reverts with NonTransferableTokenUnusedFunction.
     */
    function transferFrom(
        address,
        address,
        uint256
    ) external pure returns (bool) {
        revert NonTransferableTokenUnusedFunction();
    }

    /**
     * @dev Private function to emit Transfer event.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param amount The amount of tokens being transferred.
     */
    function _updateNonTransferableToken(
        address from,
        address to,
        uint256 amount
    ) private {
        emit Transfer(from, to, amount);
    }

    /**
     * @dev Internal function to simulate the minting of new tokens. Emits a Transfer event.
     * @param user The address to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function _mintNonTransferableToken(address user, uint256 amount) internal {
        _updateNonTransferableToken(address(0), user, amount);
    }

    /**
     * @dev Internal function to simulate the burning of tokens. Emits a Transfer event.
     * @param user The address whose tokens are being burned.
     * @param amount The amount of tokens to burn.
     */
    function _burnNonTransferableToken(address user, uint256 amount) internal {
        _updateNonTransferableToken(user, address(0), amount);
    }

    /**
     * @dev Allows to change the token metadata.
     * Emits a NonTransferableTokenMetadataUpdated event.
     * @param name_ The new name of the token.
     * @param symbol_ The new symbol of the token.
     */
    function _setNonTransferableTokenNameSymbol(
        string memory name_,
        string memory symbol_
    ) internal {
        _name = name_;
        _symbol = symbol_;
        emit NonTransferableTokenMetadataUpdated(name_, symbol_);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

interface ITokenVesting {
    /**
     * @notice Handles the purchase of tokens for a specific user during a token sale stage.
     * @dev This function is called by the TokenSale contract when tokens are purchased.
     * It verifies the allocation exists and increases the vested amount for the user.
     * @param user The address of the user purchasing tokens.
     * @param stageId The ID of the sale stage.
     * @param tokensToBuy The amount of tokens being purchased.
     * @return bool Returns true if the purchase is successfully processed.
     */
    function onTokensPurchase(
        address user,
        uint256 stageId,
        uint256 tokensToBuy
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

pragma solidity ^0.8.20;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity ^0.8.20;

import {Math} from "./math/Math.sol";
import {SignedMath} from "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

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
// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable2Step.sol)

pragma solidity ^0.8.20;

import {Ownable} from "./Ownable.sol";

/**
 * @dev Contract module which provides access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
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
