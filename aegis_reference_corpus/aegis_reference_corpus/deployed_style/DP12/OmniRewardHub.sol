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

contract OmniRewardHub is Context, Ownable, ReentrancyGuard {
    mapping(address => uint256) public balance;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public locked;
    mapping(address => uint256) public boosted;
    uint256 public totalBalance;
    uint256 public totalRewardDebt;
    uint256 public totalLocked;
    uint256 public accPerShare;
    uint256 public treasury;

    function deposit() external payable { balance[_msgSender()] += msg.value; totalBalance += msg.value; }
    function lock(uint256 a) external { require(balance[_msgSender()] >= a, "bal"); balance[_msgSender()] -= a; locked[_msgSender()] += a; totalLocked += a; }
    function unlock(uint256 a) external { require(locked[_msgSender()] >= a, "lk"); locked[_msgSender()] -= a; totalLocked -= a; balance[_msgSender()] += a; }
    function boost(uint256 a) external { require(balance[_msgSender()] >= a, "bal"); balance[_msgSender()] -= a; boosted[_msgSender()] += a; }
    function accrue() external payable { accPerShare += totalBalance == 0 ? 0 : (msg.value * 1e18) / totalBalance; treasury += msg.value; }
    function updateDebt(address u) external { rewardDebt[u] = (balance[u] * accPerShare) / 1e18; totalRewardDebt += rewardDebt[u]; }

    function harvest() external nonReentrant {
        uint256 pending = (balance[_msgSender()] * accPerShare) / 1e18 - rewardDebt[_msgSender()];
        require(pending > 0, "none");
        treasury -= pending;
        (bool ok, ) = _msgSender().call{value: pending}("");
        require(ok, "send");
        rewardDebt[_msgSender()] = (balance[_msgSender()] * accPerShare) / 1e18;
        totalRewardDebt += pending;
    }
}
