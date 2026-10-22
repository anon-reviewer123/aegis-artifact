// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, quiescent member.
/// Every footprint write is settled before control leaves the contract, so the observation during the window equals the settled observation.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract PullPaymentSafe {
    mapping(address => uint256) public credits;
    uint256 public openCredits;
    uint256 public creditTotal;
    bool public inCall;

    function fund(address party) external payable {
        require(!inCall, "reentrant");
        credits[party] += msg.value;
        openCredits += 1;
        creditTotal += msg.value;
    }

    function settle(address payable party) public {
        require(!inCall, "reentrant");
        uint256 amt = credits[party];
        require(amt > 0, "nothing owed");
        openCredits -= 1;
        creditTotal -= amt;
        credits[party] = 0;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        // footprint already settled before the call
    }

    function averageCredit() public view returns (uint256) {
        if (openCredits == 0) return 0;
        return creditTotal / openCredits;
    }
}
