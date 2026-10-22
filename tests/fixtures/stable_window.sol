// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract K {
    mapping(address => uint256) public balances;
    uint256 public winnerFunds;
    bool public withdrawing;
    function deposit() external payable { balances[msg.sender] += msg.value; winnerFunds += msg.value; }
    function withdraw(address addr) public {
        require(!withdrawing, "w");
        uint256 amount = balances[msg.sender];
        withdrawing = true;
        (bool ok, ) = payable(addr).call{value: amount}("");
        require(ok);
        balances[msg.sender] = 0;
        winnerFunds -= amount;
        withdrawing = false;
    }
}
