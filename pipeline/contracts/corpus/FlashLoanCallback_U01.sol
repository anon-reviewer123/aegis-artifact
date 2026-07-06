// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract FlashLoanCallback_U01 {
    mapping(address=>uint256) public shares; uint256 public cash=1000; uint256 public loans; uint256 public totalAssets=1000;
    function flashLoan(uint256 amt, address borrower) external { require(cash>=amt,"cash"); cash-=amt; loans+=amt; IFlashBorrower(borrower).onFlashLoan(amt); loans-=amt; cash+=amt; }
    function depositDuringCallback(uint256 amt) external { require(cash < totalAssets,"not in loan"); shares[msg.sender]+=amt; totalAssets+=amt; }
    function invariant() public view returns(bool) { return cash + loans == totalAssets; }
}
