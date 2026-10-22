// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract CrossFunctionDesync_U01 {
    mapping(address=>uint256) public shares; uint256 public aum; uint256 public trackedValue;
    constructor() { aum=1000; trackedValue=1000; shares[msg.sender]=1000; }
    function decreasePosition(uint256 amount, address cb) external {
        require(shares[msg.sender] >= amount, "shares");
        shares[msg.sender]-=amount; trackedValue-=amount;
        if (cb != address(0)) ICallback(cb).onCallback();
        aum-=amount;
    }
    function mintShares() external { require(aum > trackedValue, "no surplus"); uint256 s=aum-trackedValue; shares[msg.sender]+=s; trackedValue+=s; }
    function invariant() public view returns(bool) { return aum == trackedValue; }
}
