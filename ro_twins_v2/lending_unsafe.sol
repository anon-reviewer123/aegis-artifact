// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, non-quiescent member.
/// openLoans is decremented before the call and debtTotal only after it, so healthFactor() read during the window divides a stale total by an updated count and matches neither the entry nor the settled value.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract LendingUnsafe {
    mapping(address => uint256) public collateral;
    uint256 public openLoans;
    uint256 public debtTotal;
    bool public inCall;

    function fund(address party) external payable {
        require(!inCall, "reentrant");
        collateral[party] += msg.value;
        openLoans += 1;
        debtTotal += msg.value;
    }

    function settle(address payable party) public {
        require(!inCall, "reentrant");
        uint256 amt = collateral[party];
        require(amt > 0, "nothing owed");
        openLoans -= 1;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        debtTotal -= amt;
        collateral[party] = 0;
    }

    function healthFactor() public view returns (uint256) {
        if (openLoans == 0) return 0;
        return debtTotal / openLoans;
    }
}
