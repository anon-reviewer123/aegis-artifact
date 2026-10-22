// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ClassicReentrancy_U04 {
    mapping(address=>uint256) public bal; uint256 public totalDeposits; bool internal entered;
    function deposit() external payable { bal[msg.sender]+=msg.value; totalDeposits+=msg.value; }
    function withdraw(uint256 amount, address cb) external {
        require(bal[msg.sender] >= amount, "bal");
        if (cb != address(0)) ICallback(cb).onCallback();
        bal[msg.sender] -= amount; totalDeposits -= amount;
        payable(msg.sender).transfer(amount);
    }
    function invariant() public view returns (bool) { return address(this).balance >= totalDeposits; }
}
