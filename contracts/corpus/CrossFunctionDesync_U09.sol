// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract CrossFunctionDesync_U09 {
    mapping(address=>uint256) public claims; uint256 public backing; uint256 public issued;
    function open(uint256 amt) external { claims[msg.sender]+=amt; backing+=amt; issued+=amt; }
    function reduce(uint256 amt, address cb) external { require(claims[msg.sender] >= amt, "pos"); claims[msg.sender]-=amt; issued-=amt; if (cb != address(0)) ICallback(cb).onCallback(); backing-=amt; }
    function mint() external { require(backing > issued, "no surplus"); uint256 s = backing - issued; claims[msg.sender]+=s; issued+=s; }
    function invariant() public view returns(bool) { return backing == issued; }
}
