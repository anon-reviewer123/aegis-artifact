# Corpus status

## Verified-working shape (withdraw-style: totalAssets == totalShares + inFlight)
- MotivatingVault (safe)      -> expect VERIFIED
- InheritedVault (safe, base-contract state) -> expect VERIFIED
- BuggyVault (omits inFlight settlement)      -> expect BUG_FOUND
- CrossFunctionVault (safe)   -> expect VERIFIED   [KEYSTONE: callback enters transfer()]
- CrossFunctionBuggy (transfer corrupts totalShares) -> expect BUG_FOUND via OBL_cb_transfer

The CrossFunction pair is the keystone for the closure-analysis claim: the
callback enters transfer(), a DIFFERENT function than the exposed withdraw().
A function-local verifier never generates OBL_cb_transfer; Aegis does, because
transfer is in the conservative closure. The buggy variant's bug lives ENTIRELY
in transfer and is invisible without cross-function reasoning.

## Provisional (in corpus_provisional/, NOT yet validated on real solver)
- ERC1155Vault: mint-style accounting runs in the OPPOSITE direction
  (shares lead assets), so its exposure invariant is the MIRROR
  totalShares == totalAssets + inFlight. The stub now includes this invariant,
  but the per-obligation harness shapes (pre/post phase bodies) were written for
  withdraw-style flow and need validation/adjustment on a machine with solc
  before being promoted to the active corpus.
- Flash-loan executeOperation pattern: TODO (repayment property
  balanceAfter >= balanceBefore needs its own obligation shape).

These are staged honestly rather than shipped as if verified. Promote them to
contracts/corpus/ only after confirming VERIFIED/BUG_FOUND on real Eldarica.
