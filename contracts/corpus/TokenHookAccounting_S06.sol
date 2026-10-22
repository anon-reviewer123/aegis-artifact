// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract TokenHookAccounting_S06 {
    mapping(address=>uint256) public voucher; uint256 public vouchers; uint256 public owedTotal;
    function fund(uint256 amt) external { voucher[msg.sender]+=amt; vouchers+=amt; owedTotal+=amt; }
    function issue(address to, uint256 amt) external { owedTotal+=amt; voucher[to]+=amt; vouchers+=amt; if (to.code.length>0) ITokenReceiver(to).tokensReceived(msg.sender, amt); }
    function mintSurplus() external { require(owedTotal > vouchers, "no surplus"); uint256 s = owedTotal - vouchers; voucher[msg.sender]+=s; vouchers+=s; }
    function redeem(uint256 amt) external { require(voucher[msg.sender] >= amt, "credit"); voucher[msg.sender]-=amt; vouchers-=amt; owedTotal-=amt; }
    function invariant() public view returns(bool) { return vouchers == owedTotal; }
}
