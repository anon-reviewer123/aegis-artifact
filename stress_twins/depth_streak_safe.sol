// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract DepthStreakSafe {
    mapping(address => uint256) public owed;
    uint256 public streak;
    uint256 public extra;
    address[] public queue;
    function drain() public {
        for (uint256 i = 0; i < queue.length; i++) {
            address q = queue[i];
            uint256 amt = owed[q];
            if (amt == 0) continue;
            owed[q] = 0;
            streak += 1;
            if (streak > 4) { extra += 1; }
            (bool ok, ) = q.call{value: amt}("");
            require(ok, "drain failed");
        }
    }
}
