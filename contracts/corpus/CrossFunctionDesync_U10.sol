// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract CrossFunctionDesync_U10 {
    mapping(address=>uint256) public lots; uint256 public reserve; uint256 public recorded;
    function open(uint256 amt) external { lots[msg.sender]+=amt; reserve+=amt; recorded+=amt; }
    function reduce(uint256 amt, address cb) external { require(lots[msg.sender] >= amt, "pos"); lots[msg.sender]-=amt; recorded-=amt; if (cb != address(0)) ICallback(cb).onCallback(); reserve-=amt; }
    function mint() external { require(reserve > recorded, "no surplus"); uint256 s = reserve - recorded; lots[msg.sender]+=s; recorded+=s; }
    function invariant() public view returns(bool) { return reserve == recorded; }
}
