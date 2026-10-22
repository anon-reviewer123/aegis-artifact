// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract PhaseOrderingDesync_U05 {
    mapping(address=>uint256) public lines; uint256 public drawn; uint256 public repaid;
    function post(uint256 amt) external { lines[msg.sender]+=amt; drawn+=amt; repaid+=amt; }
    function rotate(uint256 amt, address cb) external { require(lines[msg.sender] >= amt, "entry"); lines[msg.sender]-=amt; drawn-=amt; if (cb != address(0)) ICallback(cb).onCallback(); repaid-=amt; }
    function adjust() external { require(repaid > drawn, "no gap"); uint256 s = repaid - drawn; lines[msg.sender]+=s; drawn+=s; }
    function invariant() public view returns(bool) { return drawn == repaid; }
}
