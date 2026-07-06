// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// READ-ONLY REENTRANCY (buggy variant).
///
/// Clone of ReadOnlyVault EXCEPT the pre-phase fails to record inFlight, so
/// during the callback window totalAssets == totalShares + amount while
/// inFlight == 0 -- I_exp is violated and the view pricePerShare() returns a
/// ratio inflated by the in-flight amount. An integrator that re-enters via the
/// view and acts on the stale ratio is exploited. Aegis should refute the
/// callback preservation obligation.
///
/// Stable invariant   I_stable : totalAssets == totalShares
/// Exposure invariant I_exp    : totalAssets == totalShares + inFlight
/// BUG: withdraw() omits the inFlight bookkeeping in the exposed window.
interface IAssetReceiver { function onAssetReceived(uint256 amount) external; }

contract ReadOnlyBuggy {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalAssets;
    uint256 public inFlight;
    bool public exposed;
    address public receiver;

    constructor(address _r) { receiver = _r; }

    function deposit(uint256 a) public {
        shares[msg.sender] += a; totalShares += a; totalAssets += a;
    }

    function pricePerShare() public view returns (uint256) {
        if (totalShares == 0) return 0;
        return (totalAssets * 1e18) / totalShares;
    }

    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        // PRE (BUG): decrement shares/totalShares but DO NOT record inFlight.
        shares[msg.sender] -= amount; totalShares -= amount;
        exposed = true;                       // inFlight intentionally NOT set
        // EXPOSED: pricePerShare() now reads an inflated ratio
        if (receiver != address(0)) IAssetReceiver(receiver).onAssetReceived(amount);
        // POST
        totalAssets -= amount; exposed = false;
    }
}
