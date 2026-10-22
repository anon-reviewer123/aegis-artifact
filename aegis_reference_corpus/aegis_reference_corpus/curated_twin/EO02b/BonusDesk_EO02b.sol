// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BonusDesk_EO02b {
    mapping(address => uint256) public bonus;
    uint256 public bonusTotal;
    uint256 public bonusDebt;

    function accrue() external payable {
        bonus[msg.sender] += msg.value;
        bonusTotal += msg.value;
        bonusDebt += msg.value;
    }

    function claim() external {
        uint256 x = bonus[msg.sender];
        require(x > 0, "none");
        bonus[msg.sender] = 0;
        bonusDebt -= x;
        bonusTotal -= x;
        (bool ok, ) = payable(msg.sender).call{value: x}("");
        require(ok, "send");
    }

    function sweep() external {
        require(bonusTotal > bonusDebt, "no gap");
        uint256 s = bonusTotal - bonusDebt;
        bonus[msg.sender] += s;
        bonusDebt += s;
    }
}
