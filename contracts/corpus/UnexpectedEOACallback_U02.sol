// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract UnexpectedEOACallback_U02 {
    mapping(address=>uint256) public reward; uint256 public rewardDebt; uint256 public accruedTotal;
    function accrue(uint256 amt) external { reward[msg.sender]+=amt; rewardDebt+=amt; accruedTotal+=amt; }
    function claim(address cb) external { uint256 x = reward[msg.sender]; require(x > 0, "none"); reward[msg.sender]=0; rewardDebt-=x; if (cb != address(0)) ICallback(cb).onCallback(); accruedTotal-=x; }
    function sweep() external { require(accruedTotal > rewardDebt, "no gap"); uint256 s = accruedTotal - rewardDebt; reward[msg.sender]+=s; rewardDebt+=s; }
    function invariant() public view returns(bool) { return rewardDebt == accruedTotal; }
}
