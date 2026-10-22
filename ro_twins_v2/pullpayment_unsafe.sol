// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, non-quiescent member.
/// openCredits is decremented before the call and creditTotal only after it, so averageCredit() read during the window divides a stale total by an updated count and matches neither the entry nor the settled value.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract PullPaymentUnsafe {
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
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        creditTotal -= amt;
        credits[party] = 0;
    }

    function averageCredit() public view returns (uint256) {
        if (openCredits == 0) return 0;
        return creditTotal / openCredits;
    }
}
