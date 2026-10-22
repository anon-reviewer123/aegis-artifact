// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ClassicReentrancy_S07 {
    mapping(address=>uint256) public held; uint256 public totalHeld; uint256 public reserves;
    function deposit(uint256 amt) external { held[msg.sender]+=amt; totalHeld+=amt; reserves+=amt; }
    function withdraw(uint256 amt, address cb) external { require(held[msg.sender] >= amt, "bal"); held[msg.sender]-=amt; totalHeld-=amt; reserves-=amt; if (cb != address(0)) ICallback(cb).onCallback(); }
    function claimSurplus() external { require(reserves > totalHeld, "no surplus"); uint256 s = reserves - totalHeld; held[msg.sender]+=s; totalHeld+=s; }
    function invariant() public view returns(bool) { return totalHeld == reserves; }
}
