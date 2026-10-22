// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract FlashLoanCallback_S04 {
    uint256 public cash; uint256 public loans; uint256 public totalAssets;
    function supply(uint256 amt) external { cash+=amt; totalAssets+=amt; }
    function borrow(uint256 amt, address b) external { require(cash >= amt, "cash"); cash-=amt; loans+=amt; IFlashBorrower(b).onFlashLoan(amt); loans-=amt; cash+=amt; }
    function topUp() external { require(totalAssets > cash + loans, "no shortfall"); uint256 s = totalAssets - cash - loans; cash+=s; }
    function invariant() public view returns(bool) { return cash + loans == totalAssets; }
}
