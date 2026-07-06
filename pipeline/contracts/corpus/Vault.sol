// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// A pooled vault with a callback hook.
/// CEI applied locally (shares decremented before external call), but the
/// global accounting variable totalAssets is decremented AFTER the call.
/// During the callback window, an invariant violation is observable that
/// allows cross-function exploitation.
interface IReceiver { function onTokensReceived(uint256 amount) external; }

contract Vault {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalAssets;
    address public receiver;

    function setReceiver(address r) external { receiver = r; }

    function deposit(uint256 amount) external {
        shares[msg.sender] += amount;
        totalShares += amount;
        totalAssets += amount;
    }

    /// Issue free shares by reading totalAssets. INTENDED to be called
    /// only when the vault is consistent: it computes how many new shares
    /// to mint based on totalAssets vs totalShares ratio (a yield-claim
    /// pattern). If totalAssets > totalShares (i.e. yield has accrued),
    /// caller can claim the excess as new shares.
    function claimYield() external {
        require(totalAssets > totalShares, "no yield");
        uint256 yield = totalAssets - totalShares;
        shares[msg.sender] += yield;
        totalShares       += yield;
        // Note: totalAssets unchanged -- the yield was already there.
    }

    function withdraw(uint256 amount) external {
        require(shares[msg.sender] >= amount, "insufficient");
        // ---- pre-phase ----
        shares[msg.sender] -= amount;
        totalShares       -= amount;
        // ---- exposed phase: external call ----
        if (receiver != address(0)) {
            IReceiver(receiver).onTokensReceived(amount);
        }
        // ---- post-phase ----
        totalAssets -= amount;
    }
}
