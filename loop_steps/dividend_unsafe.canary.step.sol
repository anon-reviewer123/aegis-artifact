// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Inductive loop-step for DividendUnsafe.distribute, built around the CONTRACT'S REAL
// pre-loop guard, loop body and post-loop teardown (extracted verbatim).
contract DividendUnsafeStepH {
    mapping(address => uint256) public shareOf;
    uint256 public pool;
    uint256 public totalPaid;    // ghost: value paid to the element this round
    bool    public inReenter;

    // one re-entrant replay of the real sequence (models the in-loop call).
    function reenter(address h) internal {
        if (inReenter) return;
        inReenter = true;
        uint256 snapshot = pool;                // no mutex
        uint256 amt = snapshot * shareOf[h] / 100;
        bool ok = true;
        // re-entrant call re-reads pool
        if (!(ok)) { inReenter = false; return; }
        totalPaid += amt;
        pool = 0;                               // zeroed only after the whole loop
        inReenter = false;
    }

    function check(address h, uint256 P, uint256 share) public {
        require(P > 0 && P < (1 << 64));
        require(share > 0 && share <= 100);
        pool = P;
        shareOf[h] = share;
        totalPaid = 0;
        uint256 poolAtStart = pool;
        uint256 snapshot = pool;                // no mutex
        uint256 amt = snapshot * shareOf[h] / 100;
        reenter(h);                      // the in-loop external call re-enters
        bool ok = true;
        // re-entrant call re-reads pool
        require(ok, "pay failed");
        totalPaid += amt;
        pool = 0;                               // zeroed only after the whole loop
        assert(false);                       // CANARY: reachability probe
    }
}
