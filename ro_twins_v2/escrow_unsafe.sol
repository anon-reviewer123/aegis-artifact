// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// Read-only twin, non-quiescent member.
/// openEscrows is decremented before the call and totalEscrowed only after it, so averageEscrow() read during the window divides a stale total by an updated count and matches neither the entry nor the settled value.
/// fund() is guarded on the same flag settle() holds, so it cannot
/// run while the window is open and does not defeat the footprint premise.
contract EscrowUnsafe {
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
        inCall = true;
        (bool ok, ) = party.call{value: amt}("");
        require(ok, "transfer failed");
        inCall = false;
        totalEscrowed -= amt;
        escrowed[party] = 0;
    }

    function averageEscrow() public view returns (uint256) {
        if (openEscrows == 0) return 0;
        return totalEscrowed / openEscrows;
    }
}
