// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract NonlinearCurveSafe {
    mapping(address => uint256) public weight;
    uint256 public reserve;
    uint256 public totalWeight;
    bool public curving;
    address[] public holders;
    function payout() public {
        require(!curving, "reentrant");
        curving = true;
        uint256 snap = reserve;
        for (uint256 i = 0; i < holders.length; i++) {
            address h = holders[i];
            uint256 amt = snap * weight[h] / (totalWeight + 1);
            (bool ok, ) = h.call{value: amt}("");
            require(ok, "payout failed");
        }
        reserve = 0;
        curving = false;
    }
}
