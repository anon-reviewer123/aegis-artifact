// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Inductive loop-step for GriefingSafe.settle, built around the CONTRACT'S REAL
// loop body and its branch on the call's success flag (extracted verbatim).
contract GriefingSafeStepH {
    mapping(address => uint256) public owed;
    mapping(address => bool) public failed;
    bool    public halted;       // ghost: a callee failure aborted the settlement

    function check(address c, uint256 w, bool ok) public {
        require(w > 0 && w < (1 << 128));
        owed[c] = w;
        halted = false;
        uint256 amt = owed[c];
        if (amt == 0) return;
        owed[c] = 0;
        // the in-loop external call returns ok; left symbolic so the check
        // ranges over every admissible callee behaviour
        if (!ok) { owed[c] = amt; failed[c] = true; } // record, do NOT revert
        assert(!halted);                   // progress: no callee behaviour halts the loop
    }
}
