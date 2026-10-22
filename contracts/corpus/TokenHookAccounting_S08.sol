// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract TokenHookAccounting_S08 {
    mapping(address=>uint256) public coupon; uint256 public coupons; uint256 public dues;
    function fund(uint256 amt) external { coupon[msg.sender]+=amt; coupons+=amt; dues+=amt; }
    function issue(address to, uint256 amt) external { dues+=amt; coupon[to]+=amt; coupons+=amt; if (to.code.length>0) ITokenReceiver(to).tokensReceived(msg.sender, amt); }
    function mintSurplus() external { require(dues > coupons, "no surplus"); uint256 s = dues - coupons; coupon[msg.sender]+=s; coupons+=s; }
    function redeem(uint256 amt) external { require(coupon[msg.sender] >= amt, "credit"); coupon[msg.sender]-=amt; coupons-=amt; dues-=amt; }
    function invariant() public view returns(bool) { return coupons == dues; }
}
