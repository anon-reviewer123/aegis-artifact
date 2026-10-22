// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract FeeSplitUnsafe {
    mapping(address => uint256) public shareOf;
    uint256 public feePool;
    uint256 public distributed;
    address[] public earners;
    function split() public {
        uint256 snapshot = feePool;
        for (uint256 i = 0; i < earners.length; i++) {
            address e = earners[i];
            uint256 amt = snapshot * shareOf[e] / 100;
            (bool ok, ) = e.call{value: amt}("");
            require(ok, "split failed");
        }
        distributed += snapshot;
        feePool = 0;
    }
}
