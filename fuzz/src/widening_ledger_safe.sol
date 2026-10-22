// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
contract WideningLedgerSafe {
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
            if (!ok) { credit[a] = amt; settled[a] = false; }
        }
    }

    // added for fuzzing only: makes the pre-state constructible.
    function seed(address who, uint256 amount) external payable {
        credit[who] = amount;
        accounts.push(who);
    }
}
