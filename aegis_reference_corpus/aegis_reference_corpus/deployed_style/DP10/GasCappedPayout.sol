// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract GasCappedPayout is Context {
    mapping(address => uint256) public owed;
    uint256 public totalOwed;
    uint256 public settledFlag;

    function credit(address to) external payable {
        owed[to] += msg.value;
        totalOwed += msg.value;
    }

    function payout(address to) external {
        uint256 amt = owed[to];
        require(amt > 0, "none");
        owed[to] = 0;
        totalOwed -= amt;
        (bool ok, ) = to.call{gas: 2300, value: amt}("");
        if (ok) {
            settledFlag += 1;
        } else {
            owed[to] = amt;
            totalOwed += amt;
        }
    }
}
