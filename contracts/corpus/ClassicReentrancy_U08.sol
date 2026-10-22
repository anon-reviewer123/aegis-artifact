// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ClassicReentrancy_U08 {
    mapping(address=>uint256) public owed; uint256 public totalOwed; uint256 public funded;
    function deposit(uint256 amt) external { owed[msg.sender]+=amt; totalOwed+=amt; funded+=amt; }
    function withdraw(uint256 amt, address cb) external { require(owed[msg.sender] >= amt, "bal"); owed[msg.sender]-=amt; totalOwed-=amt; if (cb != address(0)) ICallback(cb).onCallback(); funded-=amt; }
    function claimSurplus() external { require(funded > totalOwed, "no surplus"); uint256 s = funded - totalOwed; owed[msg.sender]+=s; totalOwed+=s; }
    function invariant() public view returns(bool) { return totalOwed == funded; }
}
