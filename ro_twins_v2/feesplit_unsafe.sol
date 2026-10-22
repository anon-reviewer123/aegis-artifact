// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, non-quiescent member.
/// openPayees is decremented before the call and feeTotal only after it, so sharePerPayee() read during the window divides a stale total by an updated count and matches neither the entry nor the settled value.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract FeeSplitUnsafe {
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
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        feeTotal -= amt;
        entitled[party] = 0;
    }

    function sharePerPayee() public view returns (uint256) {
        if (openPayees == 0) return 0;
        return feeTotal / openPayees;
    }
}
