// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ForcedRevertGriefing_U02 {
    address[] public receivers; mapping(address=>uint256) public refund; bool public finalized;
    function add(address r, uint256 amt) external { receivers.push(r); refund[r]=amt; }
    function settle() external { for(uint256 i=0;i<receivers.length;i++){ (bool ok,) = receivers[i].call(""); require(ok,"refund failed"); } finalized=true; }
    function invariant() public view returns(bool) { return true; }
}
