// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// FLASH-LOAN CALLBACK (buggy variant).
///
/// Structurally identical to FlashLoanVault EXCEPT the pre-phase lends out the
/// assets WITHOUT recording them as in-flight. During the borrower's hook the
/// pool's accounting claims more backing than it actually holds, so a
/// re-entrant deposit/borrow can mint claims against assets that are loaned
/// out -- the classic flash-loan accounting-desync exploit. Aegis should
/// refute the callback obligation: a re-entrant entry observes the broken
/// I_exp during exposure.
///
/// Stable invariant   I_stable : totalAssets == totalShares
/// Exposure invariant I_exp    : totalAssets == totalShares + inFlight
/// BUG: flashLoan() decrements totalAssets but never sets inFlight, so during
///      the loan totalAssets == totalShares - amount while inFlight == 0,
///      violating I_exp.
interface IFlashBorrower { function onFlashLoan(uint256 amount) external; }

contract FlashLoanBuggy {
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
        // PRE (BUG): lend out assets but DO NOT record inFlight. Now during
        // exposure the pool under-reports its obligations and I_exp breaks.
        totalAssets -= amount;
        exposed = true;                       // inFlight intentionally NOT set
        // EXPOSED
        if (receiver != address(0)) IFlashBorrower(receiver).onFlashLoan(amount);
        // POST
        totalAssets += amount; exposed = false;
    }
}
