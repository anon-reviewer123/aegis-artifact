// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract NonlinearRateSafe {
    mapping(address => uint256) public principal;
    uint256 public rate;
    uint256 public disbursed;
    address[] public lenders;
    function repay() public {
        for (uint256 i = 0; i < lenders.length; i++) {
            address l = lenders[i];
            uint256 amt = principal[l] * rate / 10000;
            if (amt == 0) continue;
            principal[l] = 0;
            disbursed += amt;
            (bool ok, ) = l.call{value: amt}("");
            require(ok, "repay failed");
        }
    }
}
