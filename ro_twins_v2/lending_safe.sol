// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, quiescent member.
/// Every footprint write is settled before control leaves the contract, so the observation during the window equals the settled observation.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract LendingSafe {
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
        debtTotal -= amt;
        collateral[party] = 0;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        // footprint already settled before the call
    }

    function healthFactor() public view returns (uint256) {
        if (openLoans == 0) return 0;
        return debtTotal / openLoans;
    }
}
