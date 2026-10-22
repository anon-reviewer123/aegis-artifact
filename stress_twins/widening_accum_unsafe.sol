// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract WideningAccumUnsafe {
    mapping(address => uint256) public due;
    uint256 public cumulative;
    uint256 public rounds;
    address[] public members;
    function distribute() public {
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            uint256 amt = due[m];
            if (amt == 0) continue;
            (bool ok, ) = m.call{value: amt}("");
            require(ok, "distribute failed");
            due[m] = 0;
            cumulative += amt;
            rounds += 1;
        }
    }
}
