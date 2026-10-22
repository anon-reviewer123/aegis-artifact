// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract FlashLoanCallback_S03 {
    mapping(address=>uint256) public shares; uint256 public cash=1000; uint256 public loans; uint256 public totalAssets=1000; bool public inFlash;
    function flashLoan(uint256 amt, address borrower) external { require(!inFlash,"nested"); require(cash>=amt,"cash"); inFlash=true; cash-=amt; loans+=amt; IFlashBorrower(borrower).onFlashLoan(amt); loans-=amt; cash+=amt; inFlash=false; }
    function depositDuringCallback(uint256 amt) external { require(!inFlash,"flash"); shares[msg.sender]+=amt; cash+=amt; totalAssets+=amt; }
    function invariant() public view returns(bool) { return inFlash || cash + loans == totalAssets; }
}
