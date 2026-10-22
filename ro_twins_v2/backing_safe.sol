// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, quiescent member.
/// Every footprint write is settled before control leaves the contract, so the observation during the window equals the settled observation.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract BackingSafe {
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
        backingTotal -= amt;
        deposits[party] = 0;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        // footprint already settled before the call
    }

    function coverageRatio() public view returns (uint256) {
        if (openClaims == 0) return 0;
        return backingTotal / openClaims;
    }
}
