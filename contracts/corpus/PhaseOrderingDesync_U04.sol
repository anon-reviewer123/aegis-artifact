// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract PhaseOrderingDesync_U04 {
    mapping(address=>uint256) public invoices; uint256 public billed; uint256 public cleared;
    function post(uint256 amt) external { invoices[msg.sender]+=amt; billed+=amt; cleared+=amt; }
    function rotate(uint256 amt, address cb) external { require(invoices[msg.sender] >= amt, "entry"); invoices[msg.sender]-=amt; billed-=amt; if (cb != address(0)) ICallback(cb).onCallback(); cleared-=amt; }
    function adjust() external { require(cleared > billed, "no gap"); uint256 s = cleared - billed; invoices[msg.sender]+=s; billed+=s; }
    function invariant() public view returns(bool) { return billed == cleared; }
}
