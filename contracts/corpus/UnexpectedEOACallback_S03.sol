// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract UnexpectedEOACallback_S03 {
    mapping(address=>uint256) public bonus; uint256 public bonusDebt; uint256 public bonusTotal;
    function accrue(uint256 amt) external { bonus[msg.sender]+=amt; bonusDebt+=amt; bonusTotal+=amt; }
    function claim(address cb) external { uint256 x = bonus[msg.sender]; require(x > 0, "none"); bonus[msg.sender]=0; bonusDebt-=x; bonusTotal-=x; if (cb != address(0)) ICallback(cb).onCallback(); }
    function sweep() external { require(bonusTotal > bonusDebt, "no gap"); uint256 s = bonusTotal - bonusDebt; bonus[msg.sender]+=s; bonusDebt+=s; }
    function invariant() public view returns(bool) { return bonusDebt == bonusTotal; }
}
