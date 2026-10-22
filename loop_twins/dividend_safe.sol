// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// Dividend payout loop guarded by a whole-loop mutex. RAVEN excludes it (call
// inside loop); the invariant is that `distributing` blocks re-entry so each
// holder is paid exactly once per round.
contract DividendSafe {
    mapping(address => uint256) public shareOf;
    address[] public holders;
    uint256 public pool;
    bool public distributing;

    function setShare(address h, uint256 s) external {
        if (shareOf[h] == 0) holders.push(h);
        shareOf[h] = s;
    }
    function fund() external payable { pool += msg.value; }

    function distribute() external {
        require(!distributing, "reentrant");
        distributing = true;                    // mutex around the whole loop
        uint256 snapshot = pool;
        for (uint256 i = 0; i < holders.length; i++) {
            address h = holders[i];
            uint256 amt = snapshot * shareOf[h] / 100;
            (bool ok, ) = h.call{value: amt}("");
            require(ok, "pay failed");
        }
        pool = 0;
        distributing = false;
    }
}
