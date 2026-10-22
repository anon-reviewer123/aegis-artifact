// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, quiescent member.
/// Every footprint write is settled before control leaves the contract, so the observation during the window equals the settled observation.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract EscrowSafe {
    mapping(address => uint256) public escrowed;
    uint256 public openEscrows;
    uint256 public totalEscrowed;
    bool public inCall;

    function fund(address party) external payable {
        require(!inCall, "reentrant");
        escrowed[party] += msg.value;
        openEscrows += 1;
        totalEscrowed += msg.value;
    }

    function settle(address payable party) public {
        require(!inCall, "reentrant");
        uint256 amt = escrowed[party];
        require(amt > 0, "nothing owed");
        openEscrows -= 1;
        totalEscrowed -= amt;
        escrowed[party] = 0;
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        // footprint already settled before the call
    }

    function averageEscrow() public view returns (uint256) {
        if (openEscrows == 0) return 0;
        return totalEscrowed / openEscrows;
    }
}
