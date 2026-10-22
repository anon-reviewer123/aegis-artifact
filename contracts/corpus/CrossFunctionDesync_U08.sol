// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract CrossFunctionDesync_U08 {
    mapping(address=>uint256) public positions; uint256 public assets; uint256 public tracked;
    function open(uint256 amt) external { positions[msg.sender]+=amt; assets+=amt; tracked+=amt; }
    function reduce(uint256 amt, address cb) external { require(positions[msg.sender] >= amt, "pos"); positions[msg.sender]-=amt; tracked-=amt; if (cb != address(0)) ICallback(cb).onCallback(); assets-=amt; }
    function mint() external { require(assets > tracked, "no surplus"); uint256 s = assets - tracked; positions[msg.sender]+=s; tracked+=s; }
    function invariant() public view returns(bool) { return assets == tracked; }
}
