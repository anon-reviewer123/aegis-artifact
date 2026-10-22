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

contract ConstantProductPool is Context, ReentrancyGuard {
    uint256 public reserve0;
    uint256 public reserve1;
    mapping(address => uint256) public liquidity;
    uint256 public totalLiquidity;

    function addLiquidity(uint256 amount1) external payable {
        reserve0 += msg.value;
        reserve1 += amount1;
        uint256 minted = msg.value + amount1;
        liquidity[_msgSender()] += minted;
        totalLiquidity += minted;
    }

    function removeLiquidity(uint256 lp) external nonReentrant {
        require(liquidity[_msgSender()] >= lp, "lp");
        uint256 out0 = (reserve0 * lp) / totalLiquidity;
        liquidity[_msgSender()] -= lp;
        totalLiquidity -= lp;
        reserve0 -= out0;
        (bool ok, ) = _msgSender().call{value: out0}("");
        require(ok, "send");
        reserve1 -= (reserve1 * lp) / (totalLiquidity + lp);
    }

    function spotPrice() external view returns (uint256) {
        return (reserve0 * 1e18) / reserve1;
    }
}
