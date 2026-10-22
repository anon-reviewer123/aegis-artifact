// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract PhaseOrderingDesync_U01 {
    uint256 public phase; uint256 public debit=100; uint256 public credit=100;
    function rotate(uint256 x, address cb) external { require(phase==0,"phase"); phase=1; debit-=x; if(cb!=address(0)) ICallback(cb).onCallback(); credit-=x; phase=0; }
    function settleAux() external { require(phase==1,"only mid"); credit+=1; }
    function invariant() public view returns(bool) { return phase != 0 || debit == credit; }
}
