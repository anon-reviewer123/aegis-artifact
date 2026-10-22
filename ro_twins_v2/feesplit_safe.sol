// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, quiescent member.
/// Every footprint write is settled before control leaves the contract, so the observation during the window equals the settled observation.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract FeeSplitSafe {
    mapping(address => uint256) public entitled;
    uint256 public openPayees;
    uint256 public feeTotal;
    bool public inCall;

    function fund(address party) external payable {
        require(!inCall, "reentrant");
        entitled[party] += msg.value;
        openPayees += 1;
        feeTotal += msg.value;
    }

    function settle(address payable party) public {
        require(!inCall, "reentrant");
        uint256 amt = entitled[party];
        require(amt > 0, "nothing owed");
        openPayees -= 1;
        feeTotal -= amt;
        entitled[party] = 0;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        // footprint already settled before the call
    }

    function sharePerPayee() public view returns (uint256) {
        if (openPayees == 0) return 0;
        return feeTotal / openPayees;
    }
}
