// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract CrossFunctionDesync_U06 {
    mapping(address=>uint256) public shares; uint256 public aum; uint256 public trackedValue;
    function open(uint256 amt) external { shares[msg.sender]+=amt; aum+=amt; trackedValue+=amt; }
    function reduce(uint256 amt, address cb) external { require(shares[msg.sender] >= amt, "pos"); shares[msg.sender]-=amt; trackedValue-=amt; if (cb != address(0)) ICallback(cb).onCallback(); aum-=amt; }
    function mint() external { require(aum > trackedValue, "no surplus"); uint256 s = aum - trackedValue; shares[msg.sender]+=s; trackedValue+=s; }
    function invariant() public view returns(bool) { return aum == trackedValue; }
}
