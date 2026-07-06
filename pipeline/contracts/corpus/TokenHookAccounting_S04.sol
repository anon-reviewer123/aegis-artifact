// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract TokenHookAccounting_S04 {
    mapping(address=>uint256) public credit; uint256 public credits; uint256 public liabilities;
    function issue(address to, uint256 amt) external { liabilities += amt; credit[to]+=amt; credits+=amt; if (to.code.length>0) ITokenReceiver(to).tokensReceived(msg.sender, amt); }
    function claim(address to, uint256 amt) external { require(credit[msg.sender]>=amt,"credit"); credit[msg.sender]-=amt; credits-=amt; liabilities-=amt; payable(to).transfer(0); }
    function invariant() public view returns(bool) { return credits == liabilities; }
}
