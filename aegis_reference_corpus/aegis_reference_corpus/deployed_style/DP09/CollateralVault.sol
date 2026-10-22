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

contract CollateralVault is Context, ReentrancyGuard {
    IERC20 public immutable asset;
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    constructor(address a) {
        asset = IERC20(a);
    }

    function deposit(uint256 amount) external nonReentrant {
        require(asset.transferFrom(_msgSender(), address(this), amount), "in");
        uint256 minted = totalShares == 0 ? amount : (amount * totalShares) / asset.balanceOf(address(this));
        shares[_msgSender()] += minted;
        totalShares += minted;
    }

    function withdraw(uint256 s) external nonReentrant {
        require(shares[_msgSender()] >= s, "shares");
        uint256 amount = (s * asset.balanceOf(address(this))) / totalShares;
        shares[_msgSender()] -= s;
        totalShares -= s;
        require(asset.transfer(_msgSender(), amount), "out");
    }

    function pricePerShare() external view returns (uint256) {
        return totalShares == 0 ? 1e18 : (asset.balanceOf(address(this)) * 1e18) / totalShares;
    }
}
