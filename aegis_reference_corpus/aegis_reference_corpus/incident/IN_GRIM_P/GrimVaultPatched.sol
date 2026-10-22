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

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract GrimVaultPatched is Context, ReentrancyGuard {
    IERC20 public immutable underlying;
    mapping(address => uint256) public shareOf;
    uint256 public backedShares;
    uint256 public pooledTokens;

    constructor(address u) {
        underlying = IERC20(u);
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "amount");
        pooledTokens += amount;
        uint256 minted = amount;
        shareOf[_msgSender()] += minted;
        backedShares += minted;
        underlying.transferFrom(_msgSender(), address(this), amount);
    }

    function withdraw(uint256 shares) external nonReentrant {
        require(shareOf[_msgSender()] >= shares, "shares");
        shareOf[_msgSender()] -= shares;
        backedShares -= shares;
        pooledTokens -= shares;
        underlying.transfer(_msgSender(), shares);
    }
}
