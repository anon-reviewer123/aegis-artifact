// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract UnexpectedEOACallback_U01 {
    mapping(address=>uint256) public reward; uint256 public rewardDebt; uint256 public paid;
    function accrue(address a, uint256 x) external { reward[a]+=x; rewardDebt+=x; }
    function claim(address cb) external { uint256 x=reward[msg.sender]; require(x>0,"none"); rewardDebt-=x; if(cb!=address(0)) ICallback(cb).onCallback(); reward[msg.sender]=0; paid+=x; }
    function invariant() public view returns(bool) { return rewardDebt + paid >= paid; }
}
