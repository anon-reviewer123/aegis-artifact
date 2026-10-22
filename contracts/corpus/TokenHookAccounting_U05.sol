// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract TokenHookAccounting_U05 {
    mapping(address=>uint256) public credit; uint256 public credits; uint256 public liabilities;
    function fund(uint256 amt) external { credit[msg.sender]+=amt; credits+=amt; liabilities+=amt; }
    function issue(address to, uint256 amt) external { liabilities+=amt; if (to.code.length>0) ITokenReceiver(to).tokensReceived(msg.sender, amt); credit[to]+=amt; credits+=amt; }
    function mintSurplus() external { require(liabilities > credits, "no surplus"); uint256 s = liabilities - credits; credit[msg.sender]+=s; credits+=s; }
    function redeem(uint256 amt) external { require(credit[msg.sender] >= amt, "credit"); credit[msg.sender]-=amt; credits-=amt; liabilities-=amt; }
    function invariant() public view returns(bool) { return credits == liabilities; }
}
