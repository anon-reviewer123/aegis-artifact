// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract EscrowReleaseSafe {
    mapping(address => uint256) public held;
    uint256 public released;
    address[] public parties;
    function release() public {
        for (uint256 i = 0; i < parties.length; i++) {
            address p = parties[i];
            uint256 amt = held[p];
            if (amt == 0) continue;
            held[p] = 0;
            released += amt;
            (bool ok, ) = p.call{value: amt}("");
            require(ok, "release failed");
        }
    }
}
