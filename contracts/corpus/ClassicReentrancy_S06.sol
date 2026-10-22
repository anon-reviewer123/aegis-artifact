// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ClassicReentrancy_S06 {
    mapping(address=>uint256) public bal; uint256 public totalDeposits; uint256 public backing;
    function deposit(uint256 amt) external { bal[msg.sender]+=amt; totalDeposits+=amt; backing+=amt; }
    function withdraw(uint256 amt, address cb) external { require(bal[msg.sender] >= amt, "bal"); bal[msg.sender]-=amt; totalDeposits-=amt; backing-=amt; if (cb != address(0)) ICallback(cb).onCallback(); }
    function claimSurplus() external { require(backing > totalDeposits, "no surplus"); uint256 s = backing - totalDeposits; bal[msg.sender]+=s; totalDeposits+=s; }
    function invariant() public view returns(bool) { return totalDeposits == backing; }
}
