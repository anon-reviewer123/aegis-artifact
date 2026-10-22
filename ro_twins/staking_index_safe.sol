// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract StakingIndexSafe {
    mapping(address => uint256) public staked;
    uint256 public totalStaked;
    function stake() external payable {
        staked[msg.sender] += msg.value;
        totalStaked += msg.value;
    }
    function unstake(address payable to, uint256 amt) public {
        require(staked[to] >= amt, "not staked");
        staked[to] -= amt;
        totalStaked -= amt;
        (bool ok, ) = to.call{value: amt}("");
        require(ok, "unstake failed");
    }
    function stakeOf(address a) public view returns (uint256) {
        return staked[a];
    }
    function totalStakedView() public view returns (uint256) {
        return totalStaked;
    }
}
