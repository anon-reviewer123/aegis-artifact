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

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract GrimVaultVuln is Context {
    IERC20 public immutable underlying;
    mapping(address => uint256) public shareOf;
    uint256 public backedShares;
    uint256 public pooledTokens;

    constructor(address u) {
        underlying = IERC20(u);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "amount");
        pooledTokens += amount;
        underlying.transferFrom(_msgSender(), address(this), amount);
        uint256 minted = pooledTokens - backedShares;
        shareOf[_msgSender()] += minted;
        backedShares += minted;
    }

    function withdraw(uint256 shares) external {
        require(shareOf[_msgSender()] >= shares, "shares");
        shareOf[_msgSender()] -= shares;
        backedShares -= shares;
        pooledTokens -= shares;
        underlying.transfer(_msgSender(), shares);
    }
}
