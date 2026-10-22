// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title MotivatingVault
/// @notice The running example from the Aegis paper, written as REAL Solidity
///         control flow: the external call happens *mid-function* in withdraw(),
///         and re-entrant callbacks (deposit / redeemAll / nested withdraw) can
///         execute on the call stack before withdraw() resumes.
///
///         Stable invariant   I_stable : totalAssets == totalShares
///         Exposure invariant I_exp    : totalAssets == totalShares + inFlight
interface IAssetReceiver {
    /// ERC-777-style hook: called during a transfer, can re-enter the vault.
    function onAssetReceived(uint256 amount) external;
}

contract MotivatingVault {
    mapping(address => uint256) public shares;
    uint256 public totalShares;
    uint256 public totalAssets;

    // Ghost-like real-storage quantity that tracks committed-but-not-settled
    // withdrawal value. In a hand-written contract this models I_exp.
    uint256 public inFlight;
    bool public exposed; // true while a callback window is open

    address public receiver; // the external party that may re-enter

    constructor(address _receiver) {
        receiver = _receiver;
    }

    // --- deposit: an admissible callback during the exposed phase ----------
    function deposit(uint256 amount) public {
        shares[msg.sender] += amount;
        totalShares += amount;
        totalAssets += amount;
        // I_exp must be preserved if this runs as a callback.
    }

    // --- redeemAll: another admissible callback ----------------------------
    function redeemAll() public {
        uint256 s = shares[msg.sender];
        shares[msg.sender] = 0;
        totalShares -= s;
        totalAssets -= s;
    }

    // --- withdraw: the callback-exposed function ---------------------------
    // PRE phase  : burn shares, record in-flight, establish I_exp
    // EXPOSED    : external call -> receiver may re-enter the vault here
    // POST phase : settle accounting, clear inFlight, restore I_stable
    function withdraw(uint256 amount) public {
        require(shares[msg.sender] >= amount, "insufficient");

        // ---- PRE PHASE ----
        shares[msg.sender] -= amount;
        totalShares -= amount;
        inFlight += amount;
        exposed = true;
        // I_exp holds here: totalAssets == totalShares + inFlight

        // ---- EXPOSED PHASE (external call) ----
        if (receiver != address(0)) {
            IAssetReceiver(receiver).onAssetReceived(amount);
        }

        // ---- POST PHASE ----
        totalAssets -= amount;
        inFlight -= amount;
        exposed = false;
        // I_stable should hold here: totalAssets == totalShares
    }
}
