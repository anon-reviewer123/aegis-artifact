// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, quiescent member.
/// Every footprint write is settled before control leaves the contract, so the observation during the window equals the settled observation.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract AmmSafe {
    mapping(address => uint256) public shares;
    uint256 public activeLots;
    uint256 public reserveTotal;
    bool public inCall;

    function fund(address party) external payable {
        require(!inCall, "reentrant");
        shares[party] += msg.value;
        activeLots += 1;
        reserveTotal += msg.value;
    }

    function settle(address payable party) public {
        require(!inCall, "reentrant");
        uint256 amt = shares[party];
        require(amt > 0, "nothing owed");
        activeLots -= 1;
        reserveTotal -= amt;
        shares[party] = 0;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        // footprint already settled before the call
    }

    function quote() public view returns (uint256) {
        if (activeLots == 0) return 0;
        return reserveTotal / activeLots;
    }
}
