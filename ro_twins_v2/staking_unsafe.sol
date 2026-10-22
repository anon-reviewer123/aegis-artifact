// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, non-quiescent member.
/// stakerCount is decremented before the call and rewardPool only after it, so rewardIndex() read during the window divides a stale total by an updated count and matches neither the entry nor the settled value.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract StakingUnsafe {
    mapping(address => uint256) public staked;
    uint256 public stakerCount;
    uint256 public rewardPool;
    bool public inCall;

    function fund(address party) external payable {
        require(!inCall, "reentrant");
        staked[party] += msg.value;
        stakerCount += 1;
        rewardPool += msg.value;
    }

    function settle(address payable party) public {
        require(!inCall, "reentrant");
        uint256 amt = staked[party];
        require(amt > 0, "nothing owed");
        stakerCount -= 1;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        rewardPool -= amt;
        staked[party] = 0;
    }

    function rewardIndex() public view returns (uint256) {
        if (stakerCount == 0) return 0;
        return rewardPool / stakerCount;
    }
}
