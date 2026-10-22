// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// Inductive loop-step for DividendSafe.distribute, built around the CONTRACT'S REAL
// pre-loop guard, loop body and post-loop teardown (extracted verbatim).
contract DividendSafeStepH {
    mapping(address => uint256) public shareOf;
    uint256 public pool;
    bool public distributing;
    uint256 public totalPaid;    // ghost: value paid to the element this round
    bool    public inReenter;

    // one re-entrant replay of the real sequence (models the in-loop call).
    function reenter(address h) internal {
        if (inReenter) return;
        inReenter = true;
        if (!(!distributing)) { inReenter = false; return; }
        distributing = true;                    // mutex around the whole loop
        uint256 snapshot = pool;
        uint256 amt = snapshot * shareOf[h] / 100;
        bool ok = true;
        if (!(ok)) { inReenter = false; return; }
        totalPaid += amt;
        pool = 0;
        distributing = false;
        inReenter = false;
    }

    function check(address h, uint256 P, uint256 share) public {
        require(P > 0 && P < (1 << 64));
        require(share > 0 && share <= 100);
        pool = P;
        shareOf[h] = share;
        totalPaid = 0;
        uint256 poolAtStart = pool;
        require(!distributing, "reentrant");
        distributing = true;                    // mutex around the whole loop
        uint256 snapshot = pool;
        uint256 amt = snapshot * shareOf[h] / 100;
        reenter(h);                      // the in-loop external call re-enters
        bool ok = true;
        require(ok, "pay failed");
        totalPaid += amt;
        pool = 0;
        distributing = false;
        assert(totalPaid <= poolAtStart);     // paid at most the pool it started with
    }
}
