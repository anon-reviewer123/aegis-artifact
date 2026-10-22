// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract FeeSplitSafe {
    mapping(address => uint256) public shareOf;
    uint256 public feePool;
    uint256 public distributed;
    bool public splitting;
    address[] public earners;
    function split() public {
        require(!splitting, "reentrant");
        splitting = true;
        uint256 snapshot = feePool;
        for (uint256 i = 0; i < earners.length; i++) {
            address e = earners[i];
            uint256 amt = snapshot * shareOf[e] / 100;
            (bool ok, ) = e.call{value: amt}("");
            require(ok, "split failed");
        }
        distributed += snapshot;
        feePool = 0;
        splitting = false;
    }
}
