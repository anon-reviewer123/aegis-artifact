// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract FlashLoanCallback_U05 {
    uint256 public idle; uint256 public lent; uint256 public poolSize;
    function supply(uint256 amt) external { idle+=amt; poolSize+=amt; }
    function borrow(uint256 amt, address b) external { require(idle >= amt, "cash"); idle-=amt; IFlashBorrower(b).onFlashLoan(amt); idle+=amt; }
    function topUp() external { require(poolSize > idle + lent, "no shortfall"); uint256 s = poolSize - idle - lent; idle+=s; }
    function invariant() public view returns(bool) { return idle + lent == poolSize; }
}
