// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract FlashLoanCallback_U06 {
    uint256 public liquid; uint256 public borrowed; uint256 public bookValue;
    function supply(uint256 amt) external { liquid+=amt; bookValue+=amt; }
    function borrow(uint256 amt, address b) external { require(liquid >= amt, "cash"); liquid-=amt; IFlashBorrower(b).onFlashLoan(amt); liquid+=amt; }
    function topUp() external { require(bookValue > liquid + borrowed, "no shortfall"); uint256 s = bookValue - liquid - borrowed; liquid+=s; }
    function invariant() public view returns(bool) { return liquid + borrowed == bookValue; }
}
