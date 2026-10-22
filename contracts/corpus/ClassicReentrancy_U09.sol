// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ClassicReentrancy_U09 {
    mapping(address=>uint256) public stake; uint256 public totalStaked; uint256 public bonded;
    function deposit(uint256 amt) external { stake[msg.sender]+=amt; totalStaked+=amt; bonded+=amt; }
    function withdraw(uint256 amt, address cb) external { require(stake[msg.sender] >= amt, "bal"); stake[msg.sender]-=amt; totalStaked-=amt; if (cb != address(0)) ICallback(cb).onCallback(); bonded-=amt; }
    function claimSurplus() external { require(bonded > totalStaked, "no surplus"); uint256 s = bonded - totalStaked; stake[msg.sender]+=s; totalStaked+=s; }
    function invariant() public view returns(bool) { return totalStaked == bonded; }
}
