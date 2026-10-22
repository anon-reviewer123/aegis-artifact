// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract TokenHookAccounting_U07 {
    mapping(address=>uint256) public note; uint256 public notes; uint256 public obligations;
    function fund(uint256 amt) external { note[msg.sender]+=amt; notes+=amt; obligations+=amt; }
    function issue(address to, uint256 amt) external { obligations+=amt; if (to.code.length>0) ITokenReceiver(to).tokensReceived(msg.sender, amt); note[to]+=amt; notes+=amt; }
    function mintSurplus() external { require(obligations > notes, "no surplus"); uint256 s = obligations - notes; note[msg.sender]+=s; notes+=s; }
    function redeem(uint256 amt) external { require(note[msg.sender] >= amt, "credit"); note[msg.sender]-=amt; notes-=amt; obligations-=amt; }
    function invariant() public view returns(bool) { return notes == obligations; }
}
