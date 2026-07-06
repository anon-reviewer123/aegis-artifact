// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ILpHook { function onRemove(uint256 amount) external; }

contract LpVault {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public reserve;

    constructor() { shares[msg.sender] = 1000; totalShares = 1000; reserve = 1000; }

    function provide(uint256 amount) external {
        shares[msg.sender] += amount;
        totalShares += amount;
        reserve += amount;
    }

    function removeLiquidity(uint256 amount, address hook) external {
        require(shares[msg.sender] >= amount, "shares");
        shares[msg.sender] -= amount;
        totalShares -= amount;
        ILpHook(hook).onRemove(amount);
        reserve -= amount;
    }

    function mint() external {
        require(reserve > totalShares, "no surplus");
        uint256 surplus = reserve - totalShares;
        shares[msg.sender] += surplus;
        totalShares += surplus;
    }

    function invariant() public view returns (bool) {
        return reserve == totalShares;
    }
}
