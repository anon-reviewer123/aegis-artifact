// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// READ-ONLY REENTRANCY (safe variant).
///
/// Clone of the working cross-function structure, specialized to ROR: a view
/// function pricePerShare() reads the accounting ratio and can be queried by an
/// external integrator DURING the callback window. In this safe variant the
/// pre/post phases keep totalAssets and totalShares moving together (tracked by
/// the inFlight ghost), so the ratio the view exposes stays consistent with
/// I_exp and no stale value can be exploited.
///
/// Stable invariant   I_stable : totalAssets == totalShares
/// Exposure invariant I_exp    : totalAssets == totalShares + inFlight
interface IAssetReceiver { function onAssetReceived(uint256 amount) external; }

contract ReadOnlyVault {
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

    // The read-only view an external integrator can query mid-callback. It only
    // READS accounting state, so it can leak a value but not corrupt state.
    function pricePerShare() public view returns (uint256) {
        if (totalShares == 0) return 0;
        return (totalAssets * 1e18) / totalShares;
    }

    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount);
        // PRE
        shares[msg.sender] -= amount; totalShares -= amount;
        inFlight += amount; exposed = true;
        // EXPOSED: callback may query pricePerShare() or call deposit()
        if (receiver != address(0)) IAssetReceiver(receiver).onAssetReceived(amount);
        // POST
        totalAssets -= amount; inFlight -= amount; exposed = false;
    }
}
