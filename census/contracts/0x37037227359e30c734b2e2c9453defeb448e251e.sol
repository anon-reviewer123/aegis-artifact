// SPDX-License-Identifier: MIT
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


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

// File: .deps/Presale(mainnet).sol


pragma solidity ^0.8.0;




contract Presale is Ownable, ReentrancyGuard {
    uint256 public constant PHASE_DURATION = 16 hours;
    uint256 public constant TOTAL_PHASES = 3;
    uint256[] public phasePrices = [67, 71, 77]; 
    uint256 public currentPhase;
    uint256 public phaseStartTime;
    uint256 public uniqueParticipantCount;
    bool public presaleStart = true;
    mapping(address => bool) private isParticipant;
    address[] private participants;
    uint256 public tokenSold;
    uint256 public constant MAX_TOKEN_PER_WALLET = 150000; 

    IERC20 public usdtToken;

    mapping(address => uint256) private usdtContributions;
    mapping(address => uint256) private tokenPurchases;
    mapping(address => uint256) private tokenBonus;
    mapping(address => string) private referralCodes;
    mapping(string => address) private addFromRefCode;

    struct ReferralDetails {
        uint256 totalUsdt; 
        uint256 bonusUsdt;
        uint256 bonusTokens;
    }

    mapping(address => mapping(address => ReferralDetails))
        private referralDetails;
    mapping(address => address[]) private referrerToReferred;

    constructor(address _usdtAddress, uint256 _startTimestamp)
        Ownable(msg.sender)
    {
        require(
            _startTimestamp > block.timestamp,
            "Start time must be in the future"
        );
        phaseStartTime = _startTimestamp;
        currentPhase = 1;
        usdtToken = IERC20(_usdtAddress);
        uniqueParticipantCount = 0;
    }

    function buyTokens(
        uint256 usdtAmount,
        string memory referralCode,
        string memory refCodeUsed
    ) public nonReentrant {
        require(
            bytes(referralCode).length == 6,
            "msg.sender referral code invalid"
        );
        require(
            block.timestamp >= phaseStartTime,
            "Presale has not started yet"
        );
        updatePhase();
        require(currentPhase <= TOTAL_PHASES, "Presale has ended");
        require(presaleStart == true, "Presale is paused/not started");
        require(usdtAmount >= 67 * 1e6, "Minimum purchase is 1000 tokens"); 

        uint256 tokenAmount = calculateTokenAmount(usdtAmount);
        uint256 maxAllowedTokens = 6750000; 
        require(
            tokenAmount + tokenSold <= maxAllowedTokens,
            "Purchase exceeds presale allocation, try a smaller amount instead."
        );

        if (
            bytes(referralCodes[msg.sender]).length == 0 &&
            bytes(referralCode).length == 6
        ) {
            assignReferralCode(referralCode);
        }

        if (bytes(refCodeUsed).length == 6) {
            require(
                addFromRefCode[refCodeUsed] != address(0),
                "Invalid referral code used"
            );
            require(
                addFromRefCode[refCodeUsed] != msg.sender,
                "Self-referral not allowed"
            );
            require(
                tokenPurchases[msg.sender] + tokenAmount <= MAX_TOKEN_PER_WALLET,
                "Exceed max contribution per wallet"
            );
            //add referred to referral's list
            if (
                referralDetails[addFromRefCode[refCodeUsed]][msg.sender]
                    .bonusTokens == 0
            ) {
                referrerToReferred[addFromRefCode[refCodeUsed]].push(
                    msg.sender
                );
            }

            if (referralDetails[msg.sender][msg.sender].bonusTokens == 0) {
                referrerToReferred[msg.sender].push(msg.sender);
            }

            // bonus to referrer
            require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "Failed to transfer USDT");
            referralDetails[addFromRefCode[refCodeUsed]][msg.sender]
                .totalUsdt += usdtAmount;
            referralDetails[addFromRefCode[refCodeUsed]][msg.sender].bonusUsdt +=
                (usdtAmount * 5) / 100;
            referralDetails[addFromRefCode[refCodeUsed]][msg.sender]
                .bonusTokens += (tokenAmount * 5) / 100;
            tokenBonus[addFromRefCode[refCodeUsed]] += (tokenAmount * 5) / 100;

            // bonus to referee
            referralDetails[msg.sender][msg.sender].totalUsdt += usdtAmount;
            referralDetails[msg.sender][msg.sender].bonusUsdt +=
                (usdtAmount * 5) / 100;
            referralDetails[msg.sender][msg.sender].bonusTokens +=
                (tokenAmount * 5) / 100;
            tokenBonus[msg.sender] += (tokenAmount * 5) / 100;

            // buy
            
            usdtContributions[msg.sender] += usdtAmount;
            tokenPurchases[msg.sender] += tokenAmount;

        } else {
            // no referral code used
             require(
                tokenPurchases[msg.sender] + tokenAmount <= MAX_TOKEN_PER_WALLET,
                "Exceed max contribution per wallet"
            );
            require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "Failed to transfer USDT");
            usdtContributions[msg.sender] += usdtAmount;
            tokenPurchases[msg.sender] += tokenAmount;
        }

        if (!isParticipant[msg.sender]) {
            isParticipant[msg.sender] = true;
            uniqueParticipantCount++;
            participants.push(msg.sender);
        }

        
        tokenSold += tokenAmount;

        if (tokenSold >= 6750000) {
            presaleStart = false;
        }
    }

    function calculateTokenAmount(uint256 usdtAmount)
        private
        view
        returns (uint256)
    {
        uint256 tokenPriceCents = phasePrices[currentPhase - 1]; // Array is 0-indexed
        uint256 tokenPriceUSDT = (tokenPriceCents * 1e6) / 1000; // Converts cents to USDT value with correct decimals
        uint256 tokens = (usdtAmount) / tokenPriceUSDT; 
        return tokens;
    }

    function updatePhase() private {
        if (
            block.timestamp >= phaseStartTime + (TOTAL_PHASES * PHASE_DURATION)
        ) {
            currentPhase = 4;
            presaleStart = false;
        } else if (
            block.timestamp >= phaseStartTime + PHASE_DURATION &&
            block.timestamp <= phaseStartTime + (2 * PHASE_DURATION)
        ) {
            currentPhase = 2;
        } else if (
            block.timestamp > phaseStartTime + (2 * PHASE_DURATION) &&
            block.timestamp <= phaseStartTime + (3 * PHASE_DURATION)
        ) {
            currentPhase = 3;
        }
    }

    function assignReferralCode(string memory code) public {
        require(
            bytes(referralCodes[msg.sender]).length == 0,
            "Referral code already assigned"
        );
        require(
            addFromRefCode[code] == address(0),
            "Referral code already in use"
        );
        referralCodes[msg.sender] = code;
        addFromRefCode[code] = msg.sender;
    }

    function getAllParticipants() public view returns (address[] memory) {
        return participants;
    }

    function getNumberOfParticipants() public view returns (uint256) {
        return uniqueParticipantCount;
    }

    function getUSDTContribution(address participant)
        public
        view
        returns (uint256)
    {
        return usdtContributions[participant];
    }

    function getTokenPurchase(address participant)
        public
        view
        returns (uint256)
    {
        return tokenPurchases[participant];
    }

    //array of addresses that is referred by referrer
    function getReferredAddresses(address referrer)
        public
        view
        returns (address[] memory)
    {
        return referrerToReferred[referrer];
    }

    //Total USDT referred by the referrer for a particular wallet address
    function gettotalUsdtReferred(address referrer, address referred)
        public
        view
        returns (uint256)
    {
        return referralDetails[referrer][referred].totalUsdt;
    }

    //Total bonus tokens referred by the referrer for a particular wallet address
    function getBonusTokensEarned(address referrer, address referred)
        public
        view
        returns (uint256)
    {
        return referralDetails[referrer][referred].bonusTokens;
    }

    //Total bonus tokens for connected wallet
    function getTotalBonusTokens(address referrer)
        public
        view
        returns (uint256)
    {
        return tokenBonus[referrer];
    }

    function getPresaleStatus() public view returns (bool) {
        return presaleStart;
    }

    function getReferralCode(address participant)
        public
        view
        returns (string memory)
    {
        return referralCodes[participant];
    }

    function presaleToggle(bool toggle) public onlyOwner {
        presaleStart = toggle;
    }

    function withdrawUSDT() public onlyOwner {
        uint256 balance = usdtToken.balanceOf(address(this));
        require(usdtToken.transfer(owner(), balance), "Failed to transfer USDT");
    }

    function setUsdtAddress(address _newUsdtAddress) public onlyOwner {
        require(_newUsdtAddress != address(0), "Invalid address");
        usdtToken = IERC20(_newUsdtAddress);
    }


    receive() external payable {}
}