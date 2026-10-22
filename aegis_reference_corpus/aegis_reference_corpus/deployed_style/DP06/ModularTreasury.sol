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

contract ModularTreasury is Context, Ownable, ReentrancyGuard {
    uint256 public teamBalance;
    address public strategy;
    mapping(bytes4 => bool) public allowedSelectors;

    constructor(address s) {
        strategy = s;
    }

    function setStrategy(address s) external onlyOwner {
        strategy = s;
    }

    function execute(bytes calldata data) external onlyOwner nonReentrant {
        (bool ok, ) = strategy.delegatecall(data);
        require(ok, "strategy call failed");
    }

    function distribute(address payable to, uint256 amount) external onlyOwner nonReentrant {
        require(amount <= teamBalance, "balance");
        teamBalance -= amount;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "transfer");
    }

    receive() external payable {
        teamBalance += msg.value;
    }
}
