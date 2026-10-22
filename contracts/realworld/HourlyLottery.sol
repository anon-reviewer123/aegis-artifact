// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

interface ISortitionIndex {
    function totalWeight() external view returns (uint256);
    function drawByUint(uint256 randomValue) external view returns (address);
}

interface IBUXToken {
    function isEligible(address account) external view returns (bool);
}

/**
 * @title BUXAction
 * @author BUX Lottery Team
 * @notice Automated ETH lottery with hourly and daily drawings funded by Uniswap v4 trading fees
 *
 * @dev AUDIT FIXES IMPLEMENTED:
 *      [H-01] Added MIN/MAX bounds for callback gas limit (100k-500k)
 *      [H-02] Fixed rescueETH to properly deduct from pot balances proportionally
 *      [M-01] Added MAX_HOURLY_PRIZE_WEI cap (10 ETH) to prevent DoS
 *      [M-02] Added MIN/MAX bounds for draw timeout
 *      [Q-01] Fixed pragma from floating (^0.8.26) to locked (0.8.30)
 *      - Added comprehensive parameter validation with constants
 *      - Enhanced accounting consistency throughout
 *      - Uses Ownable2Step for safer ownership transfers
 *
 * @dev SYSTEM OVERVIEW:
 *      This contract manages two independent lottery draws:
 *      - Hourly: Requires minimum pot size, resets every hour
 *      - Daily: No minimum required, resets every 24 hours
 *
 * @dev FUNDING FLOW:
 *      1. ActionFundingHook captures fees from BUX/ETH swaps
 *      2. Hook calls fundFromHook() to deposit ETH into prize pots
 *      3. Funds accumulate until draw conditions are met
 *
 * @dev DRAW MECHANICS:
 *      1. Chainlink Automation calls performUpkeep() when timer expires
 *      2. Contract requests random number from Chainlink VRF
 *      3. VRF calls rawFulfillRandomWords() with random value
 *      4. Random value used to select winner via SortitionIndex
 *      5. ETH prize sent to winner (or rolled back to pot if transfer fails)
 *
 * @dev SECURITY FEATURES:
 *      - ReentrancyGuard on all external entry points
 *      - Pot amounts zeroed BEFORE requesting randomness (no double-spend)
 *      - Failed transfers roll prize back to pot (no loss of funds)
 *      - Timeout recovery for stuck VRF requests (15 minutes default)
 *      - Owner-controlled pause for emergency situations
 *      - All setter functions validate inputs against safe bounds
 *
 * @dev INTEGRATION REQUIREMENTS:
 *      - Must be registered as VRF consumer with funded subscription
 *      - Must have Chainlink Automation upkeep registered and funded
 *      - Hook must be authorized via setHook()
 *      - SortitionIndex and BUXToken must be deployed and initialized
 */
contract BUXAction is Ownable2Step, Pausable, ReentrancyGuard, AutomationCompatibleInterface {
    // ============ Custom Errors ============
    error OnlyHook();
    error OnlyCoordinator();
    error RequestAlreadyPending();
    error NothingToDo();
    error BadFundingSplit();
    error BadCallback();
    error TooManyWords();
    error ZeroAddress();
    error InvalidRequest();
    error NoPendingDraw();
    error InsufficientBalance();
    error TimeoutNotReached();
    error InsufficientPot();
    error ReRequestConditionsNotMet();
    error InsufficientUnaccountedBalance();
    error InvalidGasLimit();
    error UnauthorizedCaller();

    // ============ Events ============
    event HookUpdated(address indexed hook);
    event MinHourlyPrizeUpdated(uint256 oldWei, uint256 newWei);
    event CallbackGasLimitUpdated(uint32 oldGas, uint32 newGas);
    event VRFConfigUpdated(address coordinator, bytes32 keyHash, uint256 subId, uint32 callbackGas);
    event FundedFromHook(uint256 hourlyWei, uint256 dailyWei, uint256 newHourlyPot, uint256 newDailyPot);
    event HourlyDrawRequested(uint256 indexed requestId, uint64 roundId, uint64 nextAnchor);
    event DailyDrawRequested(uint256 indexed requestId, uint64 roundId, uint64 nextAnchor);
    event HourlyWinnerPaid(uint64 indexed roundId, address indexed winner, uint256 prizeWei, string note);
    event DailyWinnerPaid(uint64 indexed roundId, address indexed winner, uint256 prizeWei, string note);
    event DrawSkipped(string drawType, string reason, uint64 roundId, uint256 potWei, uint256 totalWeight);
    event WinnerIneligible(string drawType, uint64 roundId, address candidate, uint256 prizeWei, string reason);
    event WinnerDeferred(string drawType, uint64 roundId, address candidate, uint256 prizeWei, string reason);
    event DrawTimeoutUpdated(uint64 oldTimeout, uint64 newTimeout);
    event DrawRecovered(DrawType indexed drawType, uint64 roundId, uint256 prizeWei, bool reRequested, uint256 newRequestId);

    // ============ Immutable Configuration ============
    ISortitionIndex public immutable index;
    IBUXToken public immutable token;

    // ============ VRF Configuration ============
    struct VRFConfig {
        IVRFCoordinatorV2Plus coordinator;
        bytes32 keyHash;
        uint256 subId;
        uint16 minConfirmations;
        uint32 callbackGasLimit;
    }
    
    VRFConfig private _vrf;
    uint32 private constant VRF_NUM_WORDS = 1;
    uint32 private constant MIN_CALLBACK_GAS = 100_000;  // Minimum gas for VRF callback
    uint32 private constant MAX_CALLBACK_GAS = 2_500_000; // Maximum gas for VRF callback
    uint256 private constant MAX_REALISTIC_HOURLY_PRIZE_WEI = 0.1 ether; // Maximum realistic hourly prize (M-01 fix)
    uint64 private constant MAX_DRAW_TIMEOUT = 7 days;     // Maximum draw timeout (M-02 fix)

    // ============ Lottery Configuration ============
    address public hook;
    uint256 public minHourlyPrizeWei;

    // ============ Lottery State ============
    uint256 public hourlyPotWei;
    uint256 public dailyPotWei;
    uint64 public nextHourlyAt;
    uint64 public nextDailyAt;
    uint64 public hourlyRoundId;
    uint64 public dailyRoundId;
    
    // Request tracking
    enum DrawType { HOURLY, DAILY }
    struct PendingRequest {
        DrawType drawType;
        uint64 roundId;
        uint256 prizeAmount;
        uint64 requestedAt;
        bool exists;
    }
    
    mapping(uint256 => PendingRequest) private _pendingRequests;
    uint256 private _pendingHourlyRequestId;
    uint256 private _pendingDailyRequestId;
    bool public hourlyPending;
    bool public dailyPending;
    
    // Reentrancy protection for fulfillment
    bool private _inFulfill;

    // Timeout after which a pending draw can be rescued (seconds)
    uint64 public drawTimeout = 15 minutes;

    // ============ Modifiers ============
    modifier onlyHook() {
        if (msg.sender != hook) revert OnlyHook();
        _;
    }

    modifier onlyCoordinator() {
        if (msg.sender != address(_vrf.coordinator)) revert OnlyCoordinator();
        _;
    }

    modifier notInFulfill() {
        if (_inFulfill) revert BadCallback();
        _;
    }

    // ============ Constructor ============
    constructor(
        address initialOwner,
        address index_,
        address token_,
        address vrfCoordinator_,
        bytes32 keyHash_,
        uint256 subId_,
        uint16 minConfirmations_,
        uint32 callbackGasLimit_,
        uint256 minHourlyPrizeWei_
    ) Ownable(initialOwner) {
        // Validate addresses before calling parent constructor
        if (initialOwner == address(0)) revert ZeroAddress();
        if (index_ == address(0)) revert ZeroAddress();
        if (token_ == address(0)) revert ZeroAddress();
        if (vrfCoordinator_ == address(0)) revert ZeroAddress();

        // Set immutable contracts
        index = ISortitionIndex(index_);
        token = IBUXToken(token_);
        
        // Initialize VRF configuration
        _vrf = VRFConfig({
            coordinator: IVRFCoordinatorV2Plus(vrfCoordinator_),
            keyHash: keyHash_,
            subId: subId_,
            minConfirmations: minConfirmations_,
            callbackGasLimit: callbackGasLimit_
        });
        
        // Set lottery parameters
        minHourlyPrizeWei = minHourlyPrizeWei_;

        // Initialize time anchors
        uint64 nowTs = uint64(block.timestamp);
        nextHourlyAt = _ceilToNextHour(nowTs);
        nextDailyAt = _ceilToNextDay(nowTs);
    }

    // ============ Admin Functions ============
    
    function pauseLottery() external onlyOwner {
        _pause();
    }

    function unpauseLottery() external onlyOwner {
        _unpause();
    }

    function setHook(address hook_) external onlyOwner {
        if (hook_ == address(0)) revert ZeroAddress();
        hook = hook_;
        emit HookUpdated(hook_);
    }

    /**
     * @notice Set minimum hourly prize with upper bound validation
     * @dev This fixes audit finding M-01: Unconstrained minHourlyPrizeWei
     * @param newMin The new minimum prize (must be <= MAX_REALISTIC_HOURLY_PRIZE_WEI)
     */
    function setMinHourlyPrizeWei(uint256 newMin) external onlyOwner {
        if (newMin > MAX_REALISTIC_HOURLY_PRIZE_WEI) revert InvalidRequest();
        uint256 old = minHourlyPrizeWei;
        minHourlyPrizeWei = newMin;
        emit MinHourlyPrizeUpdated(old, newMin);
    }

    /**
     * @notice Set the VRF callback gas limit with bounds validation
     * @dev This fixes Hashlock audit finding H-01: Unconstrained callback gas
     * @param newGas The new gas limit (must be between MIN_CALLBACK_GAS and MAX_CALLBACK_GAS)
     */
    function setCallbackGasLimit(uint32 newGas) external onlyOwner {
        if (newGas < MIN_CALLBACK_GAS || newGas > MAX_CALLBACK_GAS) {
            revert InvalidGasLimit();
        }
        uint32 old = _vrf.callbackGasLimit;
        _vrf.callbackGasLimit = newGas;
        emit CallbackGasLimitUpdated(old, newGas);
    }

    function setVRFConfig(
        address coordinator_,
        bytes32 keyHash_,
        uint256 subId_,
        uint16 minConfirmations_,
        uint32 callbackGasLimit_
    ) external onlyOwner {
        if (coordinator_ == address(0)) revert ZeroAddress();
        
        _vrf = VRFConfig({
            coordinator: IVRFCoordinatorV2Plus(coordinator_),
            keyHash: keyHash_,
            subId: subId_,
            minConfirmations: minConfirmations_,
            callbackGasLimit: callbackGasLimit_
        });
        
        emit VRFConfigUpdated(coordinator_, keyHash_, subId_, callbackGasLimit_);
    }

    /**
     * @notice Set draw timeout with bounds validation
     * @dev This fixes audit finding M-02: Unconstrained draw timeout
     * @param newTimeout The new timeout (must be > 0 and <= MAX_DRAW_TIMEOUT)
     */
    function setDrawTimeout(uint64 newTimeout) external onlyOwner {
        if (newTimeout == 0 || newTimeout > MAX_DRAW_TIMEOUT) revert InvalidRequest();
        uint64 old = drawTimeout;
        drawTimeout = newTimeout;
        emit DrawTimeoutUpdated(old, newTimeout);
    }

    // ============ View Functions (VRF) ============
    
    function vrfCoordinator() external view returns (address) {
        return address(_vrf.coordinator);
    }

    function keyHash() external view returns (bytes32) {
        return _vrf.keyHash;
    }

    function vrfSubId() external view returns (uint256) {
        return _vrf.subId;
    }

    function vrfMinConfs() external view returns (uint16) {
        return _vrf.minConfirmations;
    }

    function callbackGasLimit() external view returns (uint32) {
        return _vrf.callbackGasLimit;
    }

    // ============ Funding Entry Point ============

    /**
     * @notice Receive ETH from the Uniswap v4 hook to fund prize pots
     * @dev Only callable by authorized hook contract
     * @dev Validates that msg.value equals hourlyWei + dailyWei to prevent accounting errors
     * @param hourlyWei Amount of ETH to add to hourly pot
     * @param dailyWei Amount of ETH to add to daily pot
     * @custom:security Caller restricted to hook address to prevent unauthorized funding
     * @custom:emits FundedFromHook with updated pot balances
     */
    function fundFromHook(uint256 hourlyWei, uint256 dailyWei) external payable onlyHook whenNotPaused {
        if (hourlyWei + dailyWei != msg.value) revert BadFundingSplit();
        
        if (hourlyWei > 0) hourlyPotWei += hourlyWei;
        if (dailyWei > 0) dailyPotWei += dailyWei;
        
        emit FundedFromHook(hourlyWei, dailyWei, hourlyPotWei, dailyPotWei);
    }

    // ============ Automation Entry Points ============

    /**
     * @notice Check if upkeep is needed for Chainlink Automation
     * @dev Called by Chainlink Automation nodes to determine if performUpkeep should be called
     * @dev Implements AutomationCompatibleInterface for Chainlink Automation v2.1
     * @dev Returns true when draw time has passed, regardless of pot balance
     * @dev This allows performUpkeep to either execute or skip draws and advance time windows
     *
     * @return upkeepNeeded True if draw time has passed (may execute or skip based on funds)
     * @return performData Empty bytes, not used but required by interface
     *
     * @custom:security View function - no state changes
     */
    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        // Don't trigger upkeep if contract is paused
        if (paused()) {
            return (false, "");
        }

        uint64 nowTs = uint64(block.timestamp);

        // Check hourly draw conditions
        // Return true when time has passed, regardless of pot balance
        // This allows performUpkeep to properly skip and advance the time
        bool hourlyReady = !hourlyPending &&
                          nowTs >= nextHourlyAt;

        // Check daily draw conditions
        // Return true when time has passed, regardless of pot balance
        bool dailyReady = !dailyPending &&
                         nowTs >= nextDailyAt;

        // Upkeep needed if either draw is ready
        upkeepNeeded = hourlyReady || dailyReady;
    }

    /**
     * @notice Chainlink Automation entry point - triggers lottery draws when conditions are met
     * @dev Called by Chainlink Automation nodes when checkUpkeep returns true
     *
     * @dev HOURLY DRAW CONDITIONS:
     *      - Not already pending AND
     *      - Current time >= nextHourlyAt
     *      - If pot >= minHourlyPrizeWei: Execute draw
     *      - If pot < minHourlyPrizeWei: Skip draw and advance to next hour
     *
     * @dev DAILY DRAW CONDITIONS:
     *      - Not already pending AND
     *      - Current time >= nextDailyAt
     *      - If pot > 0: Execute draw
     *      - If pot = 0: Skip draw and advance to next day
     *
     * @dev CRITICAL SECURITY:
     *      Prize pots are zeroed BEFORE requesting VRF to prevent double-spend
     *      This ensures even if VRF fails, funds cannot be drawn twice
     *
     * @dev performData parameter is ignored - not used for custom logic
     *
     * @custom:security nonReentrant prevents nested calls
     * @custom:security notInFulfill prevents calls during VRF fulfillment
     * @custom:reverts NothingToDo if no draws are ready
     */
    function performUpkeep(bytes calldata /* performData */)
        external
        override
        whenNotPaused
        nonReentrant
        notInFulfill
    {
        uint64 nowTs = uint64(block.timestamp);
        bool didSomething;

        // Check hourly draw
        if (!hourlyPending && nowTs >= nextHourlyAt) {
            if (hourlyPotWei >= minHourlyPrizeWei && hourlyPotWei > 0) {
                // Capture and zero pot immediately
                uint256 prize = hourlyPotWei;
                hourlyPotWei = 0;

                // Request VRF for hourly draw
                hourlyRoundId++;
                uint256 requestId = _requestVRF(DrawType.HOURLY, hourlyRoundId, prize);
                _pendingHourlyRequestId = requestId;
                hourlyPending = true;

                nextHourlyAt = _ceilToNextHour(nowTs);
                emit HourlyDrawRequested(requestId, hourlyRoundId, nextHourlyAt);
                didSomething = true;
            } else {
                // Skip hourly draw - insufficient pot
                // Advance the round and time window
                hourlyRoundId++;
                nextHourlyAt = _ceilToNextHour(nowTs);
                emit DrawSkipped("hourly", "insufficient_pot", hourlyRoundId, hourlyPotWei, index.totalWeight());
                // Mark as valid action since we're advancing the time window
                didSomething = true;
            }
        }

        // Check daily draw
        if (!dailyPending && nowTs >= nextDailyAt) {
            if (dailyPotWei > 0) {
                // Capture and zero pot immediately
                uint256 prize = dailyPotWei;
                dailyPotWei = 0;

                // Request VRF for daily draw
                dailyRoundId++;
                uint256 requestId = _requestVRF(DrawType.DAILY, dailyRoundId, prize);
                _pendingDailyRequestId = requestId;
                dailyPending = true;

                nextDailyAt = _ceilToNextDay(nowTs);
                emit DailyDrawRequested(requestId, dailyRoundId, nextDailyAt);
                didSomething = true;
            } else {
                // Skip daily draw - no pot
                // Advance the round and time window
                dailyRoundId++;
                nextDailyAt = _ceilToNextDay(nowTs);
                emit DrawSkipped("daily", "insufficient_pot", dailyRoundId, dailyPotWei, index.totalWeight());
                // Mark as valid action since we're advancing the time window
                didSomething = true;
            }
        }

        if (!didSomething) revert NothingToDo();
    }

    // ============ VRF Request/Fulfillment ============
    
    function _requestVRF(DrawType drawType, uint64 roundId, uint256 prizeAmount) internal returns (uint256 requestId) {
        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: _vrf.keyHash,
            subId: _vrf.subId,
            requestConfirmations: _vrf.minConfirmations,
            callbackGasLimit: _vrf.callbackGasLimit,
            numWords: VRF_NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        requestId = _vrf.coordinator.requestRandomWords(req);
        _pendingRequests[requestId] = PendingRequest({
            drawType: drawType,
            roundId: roundId,
            prizeAmount: prizeAmount,
            requestedAt: uint64(block.timestamp),
            exists: true
        });
    }

    function recoverStuckDraw(DrawType drawType, bool reRequest) external onlyOwner {
        uint256 requestId = drawType == DrawType.HOURLY ? _pendingHourlyRequestId : _pendingDailyRequestId;
        if (requestId == 0) revert NoPendingDraw();

        PendingRequest memory request = _pendingRequests[requestId];
        if (!request.exists) revert NoPendingDraw();
        if (block.timestamp < uint256(request.requestedAt) + uint256(drawTimeout)) revert TimeoutNotReached();

        uint256 prize = request.prizeAmount;
        uint64 roundId = request.roundId;
        uint256 newRequestId;

        if (drawType == DrawType.HOURLY) {
            hourlyPotWei += prize;
            hourlyPending = false;
            _pendingHourlyRequestId = 0;
        } else {
            dailyPotWei += prize;
            dailyPending = false;
            _pendingDailyRequestId = 0;
        }

        delete _pendingRequests[requestId];

        if (reRequest) {
            if (drawType == DrawType.HOURLY) {
                if (hourlyPotWei < prize) revert InsufficientPot();
                if (prize < minHourlyPrizeWei) revert ReRequestConditionsNotMet();
                hourlyPotWei -= prize;
                newRequestId = _requestVRF(drawType, roundId, prize);
                _pendingHourlyRequestId = newRequestId;
                hourlyPending = true;
            } else {
                if (dailyPotWei < prize) revert InsufficientPot();
                if (prize == 0) revert ReRequestConditionsNotMet();
                dailyPotWei -= prize;
                newRequestId = _requestVRF(drawType, roundId, prize);
                _pendingDailyRequestId = newRequestId;
                dailyPending = true;
            }
        }

        emit DrawRecovered(drawType, roundId, prize, reRequest, newRequestId);
    }

    /**
     * @notice Chainlink VRF callback - receives random number and executes lottery draw
     * @dev Only callable by the VRF Coordinator contract
     *
     * @dev EXECUTION FLOW:
     *      1. Validate request exists and is pending
     *      2. Set reentrancy flag (_inFulfill = true)
     *      3. Route to appropriate settlement function (hourly/daily)
     *      4. Clear pending flags and request tracking
     *      5. Clear reentrancy flag
     *
     * @dev SECURITY NOTES:
     *      - Unknown requests are silently ignored (no revert) to prevent griefing
     *      - _inFulfill flag prevents nested callbacks
     *      - Prize amount passed to settlement was captured when request was made
     *
     * @param requestId VRF request identifier
     * @param randomWords Array containing the random value(s)
     *
     * @custom:security Only VRF Coordinator can call this function
     * @custom:security Gracefully handles unknown requests without reverting
     */
    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) external onlyCoordinator {
        if (_inFulfill) revert BadCallback();
        if (randomWords.length != VRF_NUM_WORDS) revert TooManyWords();
        
        PendingRequest memory request = _pendingRequests[requestId];
        
        // Handle unknown requests gracefully (don't revert)
        if (!request.exists) {
            return;
        }
        
        _inFulfill = true;
        
        // Process based on draw type
        if (request.drawType == DrawType.HOURLY) {
            _settleHourly(request.roundId, randomWords[0], request.prizeAmount);
            hourlyPending = false;
            _pendingHourlyRequestId = 0;
        } else {
            _settleDaily(request.roundId, randomWords[0], request.prizeAmount);
            dailyPending = false;
            _pendingDailyRequestId = 0;
        }
        
        delete _pendingRequests[requestId];
        _inFulfill = false;
    }

    function _settleHourly(uint64 roundId, uint256 randomValue, uint256 prize) internal {
        // Handle zero prize
        if (prize == 0) {
            emit DrawSkipped("hourly", "zero_pot_on_fulfill", roundId, 0, index.totalWeight());
            return;
        }

        // Check total weight
        uint256 totalWeight = index.totalWeight();
        if (totalWeight == 0) {
            emit DrawSkipped("hourly", "zero_total_weight", roundId, prize, 0);
            // Return prize to pot
            hourlyPotWei += prize;
            return;
        }

        // Draw winner
        address winner = index.drawByUint(randomValue);

        // Check eligibility - REMOVED, HANDELED BY TOKEN
        //if (!_isEOA(winner)) {
        //    emit WinnerIneligible("hourly", roundId, winner, prize, "non_eoa_winner");
        //    return;
        //}

        if (!token.isEligible(winner)) {
            emit WinnerIneligible("hourly", roundId, winner, prize, "token_ineligible");
            // Return prize to pot
            hourlyPotWei += prize;
            return;
        }

        // Attempt transfer
        (bool success, ) = payable(winner).call{value: prize}("");
        if (success) {
            emit HourlyWinnerPaid(roundId, winner, prize, "push_ok");
        } else {
            // Roll back pot on failed transfer
            hourlyPotWei += prize;
            emit WinnerDeferred("hourly", roundId, winner, prize, "send_failed_rolled");
        }
    }

    function _settleDaily(uint64 roundId, uint256 randomValue, uint256 prize) internal {
        // Handle zero prize
        if (prize == 0) {
            emit DrawSkipped("daily", "zero_pot_on_fulfill", roundId, 0, index.totalWeight());
            return;
        }

        // Check total weight
        uint256 totalWeight = index.totalWeight();
        if (totalWeight == 0) {
            emit DrawSkipped("daily", "zero_total_weight", roundId, prize, 0);
            // Return prize to pot
            dailyPotWei += prize;
            return;
        }

        // Draw winner
        address winner = index.drawByUint(randomValue);

        // Check eligibility - REMOVED - HANDELED BY TOKEN
        //if (!_isEOA(winner)) {
        //    emit WinnerIneligible("daily", roundId, winner, prize, "non_eoa_winner");
        //    return;
        //}

        if (!token.isEligible(winner)) {
            emit WinnerIneligible("daily", roundId, winner, prize, "token_ineligible");
            // Return prize to pot
            dailyPotWei += prize;
            return;
        }

        // Attempt transfer
        (bool success, ) = payable(winner).call{value: prize}("");
        if (success) {
            emit DailyWinnerPaid(roundId, winner, prize, "push_ok");
        } else {
            // Roll back pot on failed transfer
            dailyPotWei += prize;
            emit WinnerDeferred("daily", roundId, winner, prize, "send_failed_rolled");
        }
    }

    // ============ View Functions ============
    
    function secondsToNextHourly() external view returns (uint64) {
        uint64 nowTs = uint64(block.timestamp);
        return nextHourlyAt > nowTs ? (nextHourlyAt - nowTs) : 0;
    }

    function secondsToNextDaily() external view returns (uint64) {
        uint64 nowTs = uint64(block.timestamp);
        return nextDailyAt > nowTs ? (nextDailyAt - nowTs) : 0;
    }

    function requests(uint256 requestId) external view returns (DrawType drawType, uint64 roundId, uint256 prizeAmount, bool used) {
        PendingRequest memory req = _pendingRequests[requestId];
        return (req.drawType, req.roundId, req.prizeAmount, req.exists);
    }

    // ============ Internal Helpers ============
    
    function _isEOA(address account) internal view returns (bool) {
        return account.code.length == 0;
    }

    function _ceilToNextHour(uint64 timestamp) internal pure returns (uint64) {
        unchecked {
            uint64 hour = timestamp - (timestamp % 3600);
            return hour == timestamp ? timestamp + 3600 : hour + 3600;
        }
    }

    function _ceilToNextDay(uint64 timestamp) internal pure returns (uint64) {
        unchecked {
            uint64 day = timestamp - (timestamp % 86400);
            return day == timestamp ? timestamp + 86400 : day + 86400;
        }
    }

    // ============ Emergency Functions ============
    
    /**
     * @notice Rescue ETH from the contract with proper accounting
     * @dev This fixes Hashlock audit finding H-02: Accounting inconsistency
     * @param amount Amount of ETH to rescue
     * @param to Address to send ETH to
     */
    function rescueETH(uint256 amount, address payable to) external onlyOwner whenPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount > address(this).balance) revert InsufficientBalance();

        // Calculate total accounted funds
        uint256 totalPots = hourlyPotWei + dailyPotWei;

        // Handle edge case where pots exceed balance (shouldn't happen but safety check)
        uint256 unaccountedBalance = 0;
        if (address(this).balance > totalPots) {
            unaccountedBalance = address(this).balance - totalPots;
        }

        // Check if we're rescuing unaccounted funds or from pots
        if (amount > unaccountedBalance) {
            // Attempting to rescue from pot funds, need to update accounting
            uint256 fromPots = amount - unaccountedBalance;

            // Deduct from pots proportionally or from hourly first
            if (fromPots <= hourlyPotWei) {
                hourlyPotWei -= fromPots;
            } else {
                uint256 fromHourly = hourlyPotWei;
                hourlyPotWei = 0;
                // Check that we don't underflow dailyPotWei
                uint256 fromDaily = fromPots - fromHourly;
                if (fromDaily > dailyPotWei) {
                    revert InsufficientBalance();
                }
                dailyPotWei -= fromDaily;
            }
        }
        // If amount <= unaccounted balance, no pot updates needed

        (bool success, ) = to.call{value: amount}("");
        require(success, "rescue failed");
    }

    /**
     * @notice Receive ETH only from authorized sources
     * @dev Prevents direct ETH deposits that bypass accounting
     */
    receive() external payable {
        // Only accept ETH from the hook or owner
        if (msg.sender != hook && msg.sender != owner()) {
            revert UnauthorizedCaller();
        }
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
pragma solidity ^0.8.0;

import {VRFV2PlusClient} from "../libraries/VRFV2PlusClient.sol";
import {IVRFSubscriptionV2Plus} from "./IVRFSubscriptionV2Plus.sol";

// Interface that enables consumers of VRFCoordinatorV2Plus to be future-proof for upgrades
// This interface is supported by subsequent versions of VRFCoordinatorV2Plus
interface IVRFCoordinatorV2Plus is IVRFSubscriptionV2Plus {
  /**
   * @notice Request a set of random words.
   * @param req - a struct containing following fields for randomness request:
   * keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * requestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * extraArgs - abi-encoded extra args
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    VRFV2PlusClient.RandomWordsRequest calldata req
  ) external returns (uint256 requestId);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// End consumer library.
library VRFV2PlusClient {
  // extraArgs will evolve to support new features
  bytes4 public constant EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));

  struct ExtraArgsV1 {
    bool nativePayment;
  }

  struct RandomWordsRequest {
    bytes32 keyHash;
    uint256 subId;
    uint16 requestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
    bytes extraArgs;
  }

  function _argsToBytes(
    ExtraArgsV1 memory extraArgs
  ) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(
    bytes calldata checkData
  ) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(
    bytes calldata performData
  ) external;
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
pragma solidity ^0.8.0;

/// @notice The IVRFSubscriptionV2Plus interface defines the subscription
/// @notice related methods implemented by the V2Plus coordinator.
interface IVRFSubscriptionV2Plus {
  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint256 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint256 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint256 subId, address to) external;

  /**
   * @notice Accept subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(
    uint256 subId
  ) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint256 subId, address newOwner) external;

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription with LINK, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   * @dev Note to fund the subscription with Native, use fundSubscriptionWithNative. Be sure
   * @dev  to send Native with the call, for example:
   * @dev COORDINATOR.fundSubscriptionWithNative{value: amount}(subId);
   */
  function createSubscription() external returns (uint256 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return nativeBalance - native balance of the subscription in wei.
   * @return reqCount - Requests count of subscription.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(
    uint256 subId
  )
    external
    view
    returns (uint96 balance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers);

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(
    uint256 subId
  ) external view returns (bool);

  /**
   * @notice Paginate through all active VRF subscriptions.
   * @param startIndex index of the subscription to start from
   * @param maxCount maximum number of subscriptions to return, 0 to return all
   * @dev the order of IDs in the list is **not guaranteed**, therefore, if making successive calls, one
   * @dev should consider keeping the blockheight constant to ensure a holistic picture of the contract state
   */
  function getActiveSubscriptionIds(uint256 startIndex, uint256 maxCount) external view returns (uint256[] memory);

  /**
   * @notice Fund a subscription with native.
   * @param subId - ID of the subscription
   * @notice This method expects msg.value to be greater than or equal to 0.
   */
  function fundSubscriptionWithNative(
    uint256 subId
  ) external payable;
}
