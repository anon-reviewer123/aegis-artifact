# Harness interface convention (REQUIRED for every corpus contract)

The obligation compiler (`compiler.py`) lowers each MCVP into per-obligation
SMTChecker harnesses against a UNIFORM harness interface. Every `<Name>.harness.sol`
MUST expose a contract `<Name>H` with exactly these members, so the compiler can
generate OBL_pre / OBL_cb_<f> / OBL_post without per-contract special-casing:

REQUIRED public state getters (solc auto-generates from `public` vars):
  - the accounting variables named in the exposure/stable invariants
    (e.g. totalShares, totalAssets)
  - `uint256 public inFlight`     -- the in-flight ghost (settled to 0 by post)
  - `bool    public exposed`      -- exposure-phase flag
  - `mapping(address => uint256) public shares`

REQUIRED functions:
  - `depositFor(address who, uint256 amount)` -- seed feasible state for OBL_pre
  - `beginExposed(uint256 amount)`  -- the PRE phase body (establishes I_exp)
  - `endExposed(uint256 amount)`    -- the POST phase body (restores I_stable, clears inFlight)
  - one function per callback in the closure, each callable as `f(uint256)`
    (the callback bodies the exposed function can re-enter: deposit, transfer, redeemAll, ...)

INVARIANT DIRECTION:
  - withdraw-style (assets leave): I_exp = totalAssets == totalShares + inFlight
  - mint-style (shares lead):      I_exp = totalShares == totalAssets + inFlight
  The harness's begin/endExposed must match the chosen I_exp so OBL_pre/OBL_post
  discharge. The stub synth enumerates both directions; the LLM derives them.

POST-PHASE CONTRACT:
  endExposed(amount) is called under precondition `inFlight == amount` and must
  leave `inFlight == 0 && !exposed` with I_stable restored. A contract that
  fails to clear inFlight (the BuggyVault bug) is refuted at OBL_post.

A SAFE variant satisfies all obligations; a BUGGY variant violates exactly one,
localized to the responsible module. Keep safe/buggy pairs structurally identical
except for the injected bug, so VERIFIED-vs-BUG_FOUND isolates the defect.
