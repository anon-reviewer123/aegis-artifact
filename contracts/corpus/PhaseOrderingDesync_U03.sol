// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract PhaseOrderingDesync_U03 {
    mapping(address=>uint256) public tickets; uint256 public charged; uint256 public settled;
    function post(uint256 amt) external { tickets[msg.sender]+=amt; charged+=amt; settled+=amt; }
    function rotate(uint256 amt, address cb) external { require(tickets[msg.sender] >= amt, "entry"); tickets[msg.sender]-=amt; charged-=amt; if (cb != address(0)) ICallback(cb).onCallback(); settled-=amt; }
    function adjust() external { require(settled > charged, "no gap"); uint256 s = settled - charged; tickets[msg.sender]+=s; charged+=s; }
    function invariant() public view returns(bool) { return charged == settled; }
}
