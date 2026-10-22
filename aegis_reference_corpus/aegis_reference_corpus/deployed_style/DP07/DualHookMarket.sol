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

contract DualHookMarket is Context, ReentrancyGuard {
    mapping(address => uint256) public credit;
    uint256 public totalCredit;
    uint256 public backing;

    function fund() external payable {
        credit[_msgSender()] += msg.value;
        totalCredit += msg.value;
        backing += msg.value;
    }

    function settle(address a, address b, uint256 amount) external {
        require(credit[_msgSender()] >= amount, "credit");
        credit[_msgSender()] -= amount;
        (bool ok1, ) = a.call{value: amount / 2}("");
        require(ok1, "a");
        (bool ok2, ) = b.call{value: amount / 2}("");
        require(ok2, "b");
        totalCredit -= amount;
        backing -= amount;
    }
}
