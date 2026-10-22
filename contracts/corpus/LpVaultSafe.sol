// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ILpHook { function onRemove(uint256 amount) external; }

contract LpVaultSafe {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public reserve;
    bool public exposed;

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
        exposed = true;
        ILpHook(hook).onRemove(amount);
        reserve -= amount;
        exposed = false;
    }

    function mint() external {
        require(!exposed, "exposed");
        require(reserve > totalShares, "no surplus");
        uint256 surplus = reserve - totalShares;
        shares[msg.sender] += surplus;
        totalShares += surplus;
    }

    function invariant() public view returns (bool) {
        return exposed || reserve == totalShares;
    }
}
