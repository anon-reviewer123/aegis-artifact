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

     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * 
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**

     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**


 */
abstract contract ReentrancyGuard {

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

// File: bonzistake1.sol


pragma solidity ^0.8.0;



interface IEtherVistaFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function routerSetter() external view returns (address);
    function router() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setRouterSetter(address) external;
    function setRouter(address) external;
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(uint80 _roundId) external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

contract BonziStaking is ReentrancyGuard {
    IERC20 public immutable stakingToken;
    address public immutable StakingTokenAddress;
    address private immutable factory;
    AggregatorV3Interface internal immutable priceFeed;
    address private immutable costSetter;

    uint256 public constant LOCK_TIME = 21 days;
    uint256 private constant bigNumber = 10**20;
    uint256 public totalCollected = 0;
    uint256 public poolBalance = 0;
    uint256 public totalSupply = 0; 
    uint256 public cost = 200; // $2.00 in USDC

    struct Staker {
        uint256 amountStaked;
        uint256 stakingTime;
        uint256 euler0;
        uint256 totalLifetimeRewards;
    }

    uint256[] public euler;
    mapping(address => Staker) public stakers;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event SharesClaimed(address indexed user, uint256 amount);
    event CostUpdated(uint256 newCost);
    event ContributionReceived(address indexed contributor, uint256 amount);

    constructor(
        address _bonziToken,
        address _chainlinkETHUSD,
        address _factoryAddress,
        address _costSetter
    ) {
        require(_bonziToken != address(0), "Invalid token address");
        require(_chainlinkETHUSD != address(0), "Invalid price feed address");
        require(_factoryAddress != address(0), "Invalid factory address");
        require(_costSetter != address(0), "Invalid cost setter address");

        stakingToken = IERC20(_bonziToken);
        StakingTokenAddress = _bonziToken;
        priceFeed = AggregatorV3Interface(_chainlinkETHUSD);
        factory = _factoryAddress;
        costSetter = _costSetter;
    }

    function getEthUsdcPrice() internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price/100); 
    }

    function usdcToEth(uint256 usdcAmount) public view returns (uint256) {
        uint256 ethUsdcPrice = getEthUsdcPrice();
        return (usdcAmount * 1e6 * 1e18 / ethUsdcPrice); 
    }

    function setCost(uint256 _cost) external {
        require(msg.sender == costSetter, "Not authorized");
        cost = _cost;
        emit CostUpdated(_cost);
    }

    function updateEuler(uint256 Fee) internal {
        if (totalSupply == 0) return;
        if (euler.length == 0) {
            euler.push((Fee * bigNumber) / totalSupply);
        } else {
            euler.push(euler[euler.length - 1] + (Fee * bigNumber) / totalSupply);
        }
    }

    function contributeETH() external payable nonReentrant {
        require(msg.value >= usdcToEth(cost), "Insufficient ETH sent");
        poolBalance += msg.value;
        totalCollected += msg.value;
        updateEuler(msg.value);
        emit ContributionReceived(msg.sender, msg.value);
    }

    function stake(uint256 _amount, address user, address token) external nonReentrant {
        require(msg.sender == IEtherVistaFactory(factory).router(), 'EtherVista: FORBIDDEN');
        require(token == StakingTokenAddress, "Invalid token");
        require(_amount > 0, "Cannot stake 0");
        require(user != address(0), "Invalid user address");

        totalSupply += _amount;
        Staker storage staker = stakers[user];
        staker.amountStaked += _amount;
        staker.stakingTime = block.timestamp;
        staker.euler0 = euler.length == 0 ? 0 : euler[euler.length - 1];

        emit Staked(user, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot withdraw 0");
        Staker storage staker = stakers[msg.sender];
        require(staker.amountStaked >= _amount, "Insufficient staked amount");
        require(block.timestamp >= staker.stakingTime + LOCK_TIME, "Tokens are still locked");

        // Claim any pending rewards before withdrawal
        uint256 pendingRewards = viewShare();
        if (pendingRewards > 0) {
            _claimShare();
        }

        staker.amountStaked -= _amount;
        totalSupply -= _amount;

        require(stakingToken.transfer(msg.sender, _amount), "Transfer failed");

        if (staker.amountStaked == 0) {
            // Preserve totalLifetimeRewards even when fully withdrawn
            uint256 lifetimeRewards = staker.totalLifetimeRewards;
            delete stakers[msg.sender];
            stakers[msg.sender].totalLifetimeRewards = lifetimeRewards;
        } else {
            staker.stakingTime = block.timestamp;
            staker.euler0 = euler[euler.length - 1];
        }

        emit Withdrawn(msg.sender, _amount);
    }

    function _claimShare() internal {
        require(euler.length > 0, 'Nothing to Claim');
        uint256 balance = stakers[msg.sender].amountStaked;
        require(balance > 0, "No stakes found");

        uint256 share = (balance * (euler[euler.length - 1] - stakers[msg.sender].euler0)) / bigNumber;
        require(share > 0, "No shares to claim");
        require(share <= poolBalance, "Insufficient contract balance");

        // Update staker info
        stakers[msg.sender].euler0 = euler[euler.length - 1];
        stakers[msg.sender].totalLifetimeRewards += share;
        poolBalance -= share;
        
        (bool sent,) = payable(msg.sender).call{value: share}("");
        require(sent, "Failed to send Ether");

        emit SharesClaimed(msg.sender, share);
    }

    function claimShare() external nonReentrant {
        _claimShare();
    }
    
    function viewShare() public view returns (uint256) {
        if (euler.length == 0) return 0;
        return stakers[msg.sender].amountStaked * (euler[euler.length - 1] - stakers[msg.sender].euler0) / bigNumber;
    }

    function getLifetimeRewards(address _staker) public view returns (uint256 totalRewards) {
        uint256 unclaimedRewards = viewShareForAddress(_staker);
        return stakers[_staker].totalLifetimeRewards + unclaimedRewards;
    }

    function viewShareForAddress(address _staker) public view returns (uint256) {
        if (euler.length == 0) return 0;
        return stakers[_staker].amountStaked * (euler[euler.length - 1] - stakers[_staker].euler0) / bigNumber;
    }

    function getStakerInfo(address _staker) public view returns (
        uint256 amountStaked,
        uint256 timeLeftToUnlock,
        uint256 currentShare,
        uint256 lifetimeRewards
    ) {
        require(_staker != address(0), "Invalid address");
        Staker storage staker = stakers[_staker];
        
        amountStaked = staker.amountStaked;
        
        if (block.timestamp < staker.stakingTime + LOCK_TIME) {
            timeLeftToUnlock = (staker.stakingTime + LOCK_TIME) - block.timestamp;
        } else {
            timeLeftToUnlock = 0;
        }
        
        if (euler.length > 0 && staker.amountStaked > 0) {
            currentShare = (staker.amountStaked * (euler[euler.length - 1] - staker.euler0)) / bigNumber;
        } else {
            currentShare = 0;
        }

        lifetimeRewards = getLifetimeRewards(_staker);
    }

    function getEulerLength() public view returns (uint256) {
        return euler.length;
    }

    function getEulerAt(uint256 index) public view returns (uint256) {
        require(index < euler.length, "Index out of bounds");
        return euler[index];
    }
}