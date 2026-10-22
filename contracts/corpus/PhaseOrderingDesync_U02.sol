// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract PhaseOrderingDesync_U02 {
    mapping(address=>uint256) public entries; uint256 public debit; uint256 public credit;
    function post(uint256 amt) external { entries[msg.sender]+=amt; debit+=amt; credit+=amt; }
    function rotate(uint256 amt, address cb) external { require(entries[msg.sender] >= amt, "entry"); entries[msg.sender]-=amt; debit-=amt; if (cb != address(0)) ICallback(cb).onCallback(); credit-=amt; }
    function adjust() external { require(credit > debit, "no gap"); uint256 s = credit - debit; entries[msg.sender]+=s; debit+=s; }
    function invariant() public view returns(bool) { return debit == credit; }
}
