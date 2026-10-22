// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract StakePool is Context, Ownable, ReentrancyGuard {
    IERC20 public immutable stakeToken;
    mapping(address => uint256) public staked;
    uint256 public totalStaked;
    uint256 public rewardPool;

    constructor(address token) {
        stakeToken = IERC20(token);
    }

    function fundRewards() external payable onlyOwner {
        rewardPool += msg.value;
    }

    function stake(uint256 amount) external nonReentrant {
        require(stakeToken.transferFrom(_msgSender(), address(this), amount), "transfer");
        staked[_msgSender()] += amount;
        totalStaked += amount;
    }

    function unstake(uint256 amount) external nonReentrant {
        require(staked[_msgSender()] >= amount, "staked");
        staked[_msgSender()] -= amount;
        totalStaked -= amount;
        require(stakeToken.transfer(_msgSender(), amount), "transfer");
    }
}
