// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ClassicReentrancy_S10 {
    mapping(address=>uint256) public escrowed; uint256 public totalEscrowed; uint256 public custody;
    function deposit(uint256 amt) external { escrowed[msg.sender]+=amt; totalEscrowed+=amt; custody+=amt; }
    function withdraw(uint256 amt, address cb) external { require(escrowed[msg.sender] >= amt, "bal"); escrowed[msg.sender]-=amt; totalEscrowed-=amt; custody-=amt; if (cb != address(0)) ICallback(cb).onCallback(); }
    function claimSurplus() external { require(custody > totalEscrowed, "no surplus"); uint256 s = custody - totalEscrowed; escrowed[msg.sender]+=s; totalEscrowed+=s; }
    function invariant() public view returns(bool) { return totalEscrowed == custody; }
}
