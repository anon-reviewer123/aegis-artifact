// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract UnexpectedEOACallback_U04 {
    mapping(address=>uint256) public rebate; uint256 public rebateDebt; uint256 public rebateTotal;
    function accrue(uint256 amt) external { rebate[msg.sender]+=amt; rebateDebt+=amt; rebateTotal+=amt; }
    function claim(address cb) external { uint256 x = rebate[msg.sender]; require(x > 0, "none"); rebate[msg.sender]=0; rebateDebt-=x; if (cb != address(0)) ICallback(cb).onCallback(); rebateTotal-=x; }
    function sweep() external { require(rebateTotal > rebateDebt, "no gap"); uint256 s = rebateTotal - rebateDebt; rebate[msg.sender]+=s; rebateDebt+=s; }
    function invariant() public view returns(bool) { return rebateDebt == rebateTotal; }
}
