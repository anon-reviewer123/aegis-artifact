// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract WideningLedgerUnsafe {
    mapping(address => uint256) public credit;
    mapping(address => bool) public settled;
    uint256 public ledgerTotal;
    address[] public accounts;
    function close() public {
        for (uint256 i = 0; i < accounts.length; i++) {
            address a = accounts[i];
            uint256 amt = credit[a];
            if (amt == 0) continue;
            credit[a] = 0;
            ledgerTotal += amt;
            (bool ok, ) = a.call{value: amt}("");
            require(ok, "close failed");
            settled[a] = true;
        }
    }
}
