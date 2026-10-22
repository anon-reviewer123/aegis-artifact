// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface ICallback { function onCallback() external; }
interface IOracle { function peek() external view returns (uint256); }
interface ITokenReceiver { function tokensReceived(address from, uint256 amount) external; }
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract ClassicReentrancy_S02 {
    uint256 public _ethBal; // [ghost] models address(this).balance
    mapping(address=>uint256) public bal; uint256 public totalDeposits; bool internal locked;
    modifier nonReentrant() { require(!locked,"reentrant"); locked=true; _; locked=false; }
    function deposit() external payable { _ethBal += msg.value; bal[msg.sender]+=msg.value; totalDeposits+=msg.value; }
    function withdraw(uint256 amount, address cb) external nonReentrant {
        require(bal[msg.sender] >= amount, "bal");
        bal[msg.sender] -= amount; totalDeposits -= amount;
        if (cb != address(0)) ICallback(cb).onCallback();
        _ethBal -= amount; payable(msg.sender).transfer(amount);
    }
    function invariant() public view returns (bool) { return _ethBal >= totalDeposits; }
}
