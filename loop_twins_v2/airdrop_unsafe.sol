// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract AirdropUnsafe {
    mapping(address => uint256) public alloc;
    uint256 public sentTotal;
    address[] public recipients;
    function airdrop() public {
        uint256 budget = sentTotal;
        for (uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 amt = budget * alloc[r] / 100;
            (bool ok, ) = r.call{value: amt}("");
            require(ok, "airdrop failed");
        }
        sentTotal = 0;
    }
}
