// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract DividendUnsafe {
    mapping(address => uint256) public shareOf;
    address[] public holders;
    uint256 public pool;

    function setShare(address h, uint256 s) external {
        if (shareOf[h] == 0) holders.push(h);
        shareOf[h] = s;
    }
    function fund() external payable { pool += msg.value; }

    function distribute() external {
        uint256 snapshot = pool;                // no mutex
        for (uint256 i = 0; i < holders.length; i++) {
            address h = holders[i];
            uint256 amt = snapshot * shareOf[h] / 100;
            (bool ok, ) = h.call{value: amt}(""); // re-entrant call re-reads pool
            require(ok, "pay failed");
        }
        pool = 0;                               // zeroed only after the whole loop
    }
}
