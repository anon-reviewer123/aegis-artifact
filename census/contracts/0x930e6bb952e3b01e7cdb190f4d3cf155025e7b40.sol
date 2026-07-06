// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {
    struct Stake {
        uint256 amount;
        uint256 lockPeriod;
        uint256 startTimestamp;
        bool withdrawn;
    }

    struct CombinedStake {
        address staker;
        uint256 amount;
        uint256 lockPeriod;
        uint256 startTimestamp;
        bool withdrawn;
    }

    IERC20 public stakingToken;
    uint256 public totalStaked;
    uint256 public uniqueStakersCount;
    bool public paused;
    address[] internal stakerList;

    mapping(address => Stake[]) internal stakes;
    mapping(address => bool) internal hasStaked;

    uint256 public baseMultiplier = 118;
    uint256 public maxMultiplier = 129;
    uint256 public maxLockPeriod = 360 days;

    address public owner;

    constructor(address _stakingToken) {
        stakingToken = IERC20(_stakingToken);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    function pause() external onlyOwner {
        require(!paused, "Already paused");
        paused = true;
    }

    function unpause() external onlyOwner {
        require(paused, "Not paused");
        paused = false;
    }

    function rescueTokens(IERC20 _token, uint256 _amount) external onlyOwner {
        require(_token.transfer(owner, _amount), "Transfer failed");
    }

    function stake(uint256 _amount, uint256 _lockPeriod) external whenNotPaused {
        require(_amount > 0, "Amount must be > 0");
        require(_lockPeriod > 0 && _lockPeriod <= maxLockPeriod, "Invalid lock period");

        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        if (!hasStaked[msg.sender]) {
            uniqueStakersCount++;
            hasStaked[msg.sender] = true;
            stakerList.push(msg.sender);
        }

        stakes[msg.sender].push(Stake({
            amount: _amount,
            lockPeriod: _lockPeriod,
            startTimestamp: block.timestamp,
            withdrawn: false
        }));

        totalStaked += _amount;
    }

    function calculateMultiplier(uint256 _lockPeriod) public view returns (uint256) {
        return baseMultiplier + ((maxMultiplier - baseMultiplier) * _lockPeriod) / maxLockPeriod;
    }

    function calculateReward(address _staker, uint256 _index) public view returns (uint256) {
        Stake memory s = stakes[_staker][_index];
        uint256 multiplier = calculateMultiplier(s.lockPeriod);
        return (s.amount * (multiplier - baseMultiplier)) / baseMultiplier;
    }

    function unstake(uint256 _index) external whenNotPaused {
        require(_index < stakes[msg.sender].length, "Invalid stake index");
        Stake storage s = stakes[msg.sender][_index];
        require(!s.withdrawn, "Already withdrawn");
        require(block.timestamp >= s.startTimestamp + s.lockPeriod, "Lock period not ended");

        uint256 reward = calculateReward(msg.sender, _index);
        uint256 totalAmount = s.amount + reward;
        s.withdrawn = true;

        totalStaked -= s.amount;

        require(stakingToken.transfer(msg.sender, totalAmount), "Transfer failed");
    }

    function setMaxMultiplier(uint256 _maxMultiplier) external onlyOwner {
        require(_maxMultiplier >= baseMultiplier, "Invalid multiplier");
        maxMultiplier = _maxMultiplier;
    }

    function setBaseMultiplier(uint256 _baseMultiplier) external onlyOwner {
        require(_baseMultiplier >= 100, "Invalid multiplier");
        baseMultiplier = _baseMultiplier;
    }

    function setMaxLockPeriod(uint256 _maxLockPeriod) external onlyOwner {
        maxLockPeriod = _maxLockPeriod;
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }

    function getAllStakes() external view onlyOwner returns (CombinedStake[] memory) {
        uint256 total;
        for (uint i = 0; i < stakerList.length; i++) {
            total += stakes[stakerList[i]].length;
        }

        CombinedStake[] memory all = new CombinedStake[](total);
        uint256 idx;
        for (uint i = 0; i < stakerList.length; i++) {
            address u = stakerList[i];
            for (uint j = 0; j < stakes[u].length; j++) {
                Stake memory s = stakes[u][j];
                all[idx++] = CombinedStake(
                    u,
                    s.amount,
                    s.lockPeriod,
                    s.startTimestamp,
                    s.withdrawn
                );
            }
        }
        return all;
    }
}
