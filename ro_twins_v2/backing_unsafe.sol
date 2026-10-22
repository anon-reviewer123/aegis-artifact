// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, non-quiescent member.
/// openClaims is decremented before the call and backingTotal only after it, so coverageRatio() read during the window divides a stale total by an updated count and matches neither the entry nor the settled value.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract BackingUnsafe {
    mapping(address => uint256) public deposits;
    uint256 public openClaims;
    uint256 public backingTotal;
    bool public inCall;

    function fund(address party) external payable {
        require(!inCall, "reentrant");
        deposits[party] += msg.value;
        openClaims += 1;
        backingTotal += msg.value;
    }

    function settle(address payable party) public {
        require(!inCall, "reentrant");
        uint256 amt = deposits[party];
        require(amt > 0, "nothing owed");
        openClaims -= 1;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        backingTotal -= amt;
        deposits[party] = 0;
    }

    function coverageRatio() public view returns (uint256) {
        if (openClaims == 0) return 0;
        return backingTotal / openClaims;
    }
}
