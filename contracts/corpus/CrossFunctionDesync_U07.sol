// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract CrossFunctionDesync_U07 {
    mapping(address=>uint256) public units; uint256 public pool; uint256 public booked;
    function open(uint256 amt) external { units[msg.sender]+=amt; pool+=amt; booked+=amt; }
    function reduce(uint256 amt, address cb) external { require(units[msg.sender] >= amt, "pos"); units[msg.sender]-=amt; booked-=amt; if (cb != address(0)) ICallback(cb).onCallback(); pool-=amt; }
    function mint() external { require(pool > booked, "no surplus"); uint256 s = pool - booked; units[msg.sender]+=s; booked+=s; }
    function invariant() public view returns(bool) { return pool == booked; }
}
