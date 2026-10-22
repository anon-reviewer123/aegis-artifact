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

contract RebasingPool is Context, ReentrancyGuard {
    uint256 public index = 1e18;
    uint256 public principal;
    mapping(address => uint256) public scaled;
    uint256 public totalScaled;

    function deposit() external payable {
        uint256 s = (msg.value * 1e18) / index;
        scaled[_msgSender()] += s;
        totalScaled += s;
        principal += msg.value;
    }

    function rebase(uint256 newIndex) external {
        require(newIndex >= index, "down");
        index = newIndex;
    }

    function withdraw(uint256 s) external nonReentrant {
        require(scaled[_msgSender()] >= s, "scaled");
        uint256 amount = (s * index) / 1e18;
        scaled[_msgSender()] -= s;
        totalScaled -= s;
        (bool ok, ) = _msgSender().call{value: amount}("");
        require(ok, "send");
        principal -= amount > principal ? principal : amount;
    }
}
