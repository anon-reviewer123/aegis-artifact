// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, quiescent member.
/// Every footprint write is settled before control leaves the contract, so the observation during the window equals the settled observation.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract LpVaultSafe {
    mapping(address => uint256) public units;
    uint256 public lpHolders;
    uint256 public poolValue;
    bool public inCall;

    function fund(address party) external payable {
        require(!inCall, "reentrant");
        units[party] += msg.value;
        lpHolders += 1;
        poolValue += msg.value;
    }

    function settle(address payable party) public {
        require(!inCall, "reentrant");
        uint256 amt = units[party];
        require(amt > 0, "nothing owed");
        lpHolders -= 1;
        poolValue -= amt;
        units[party] = 0;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        // footprint already settled before the call
    }

    function pricePerUnit() public view returns (uint256) {
        if (lpHolders == 0) return 0;
        return poolValue / lpHolders;
    }
}
