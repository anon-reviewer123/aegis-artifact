// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// FLASH-LOAN CALLBACK (safe variant).
///
/// Models the ERC-3156 flash-loan pattern: the pool lends `amount`, hands
/// control to the borrower's onFlashLoan hook, then requires repayment. The
/// accounting invariant is conservation: the pool's tracked liquidity equals
/// the backing assets at every observable boundary. During the loan the assets
/// are out (in flight) but the invariant is preserved by recording them.
///
/// Stable invariant   I_stable : totalAssets == totalShares
/// Exposure invariant I_exp    : totalAssets == totalShares + inFlight
///   (inFlight = the borrowed amount that is temporarily outside the pool)
///
/// SAFE: the pre-phase records the borrowed amount as inFlight and the
/// post-phase reconciles it on repayment, so re-entrant callbacks (a second
/// borrow / a deposit) cannot mint claims against assets that are loaned out.
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract FlashLoanVault {
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

    function flashLoan(uint256 amount) public {
        require(totalAssets >= amount);
        // PRE: lend out `amount`; record it as in-flight so the conservation
        // invariant still describes total backing during the callback.
        totalAssets -= amount;
        inFlight += amount; exposed = true;
        // EXPOSED: borrower's hook runs; may re-enter deposit() or flashLoan()
        if (receiver != address(0)) IFlashBorrower(receiver).onFlashLoan(amount);
        // POST: repayment reconciles the borrowed assets and clears in-flight
        totalAssets += amount; inFlight -= amount; exposed = false;
    }
}
