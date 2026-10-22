// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, quiescent member.
/// Every footprint write is settled before control leaves the contract, so the observation during the window equals the settled observation.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract StakingSafe {
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
        rewardPool -= amt;
        staked[party] = 0;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        // footprint already settled before the call
    }

    function rewardIndex() public view returns (uint256) {
        if (stakerCount == 0) return 0;
        return rewardPool / stakerCount;
    }
}
