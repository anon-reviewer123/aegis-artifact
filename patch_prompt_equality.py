import shutil
P = "aegis/synth.py"
shutil.copy(P, P + ".bak_eq")
s = open(P).read()

old = '''- READ-ONLY REENTRANCY / mapping-sum backing: when the exposed storage is a
  mapping m(addr=>uint) written across the callback, the harness provides a
  SCALAR ghost named `_sum_m` that tracks sum_k m[k]. Express the exposure
  invariant over `_sum_m`, NEVER over the bare mapping `m` (a mapping cannot be
  compared as a scalar). The backing safety relation is `_sum_m <= <backing>`
  where <backing> is the contract's total that should cover the sum (e.g. the
  ETH balance for a pull-payment escrow). Use kind "conserve" with the tracked
  sum being `_sum_m`. Example for a deposits mapping `_deposits`:
    stable:  _sum__deposits == snapPre
    exposed: _sum__deposits == snapPre + inFlight
  Do NOT write `_deposits == ...`; write `_sum__deposits == ...`.'''
new = '''- READ-ONLY REENTRANCY / mapping-sum backing: when the exposed storage is a
  mapping m(addr=>uint) written across the callback, the harness provides a
  SCALAR ghost named `_sum_m` that tracks sum_k m[k], plus `snapPre` (its value
  at window entry) and `inFlight` (the amount mid-transfer). Two SEPARATE things:
  (1) the EXPOSURE INVARIANT you output in "formula" MUST be an EXACT EQUALITY
      that conserves the sum across the window:
        stable_formula:  _sum_m == snapPre
        formula:         _sum_m == snapPre + inFlight
      Use "==" ONLY. NEVER "<=" or ">=" in the exposure invariant. The ghost
      inFlight must EXACTLY account for the gap. kind = "conserve".
  (2) the read-only backing safety relation `_sum_m <= balance` is checked
      SEPARATELY by the view obligation and is NOT what you put in "formula".
      Do not copy the `<=` backing relation into the exposure invariant.
  Express over `_sum_m`, NEVER the bare mapping `m`. For a `_deposits` mapping:
    stable_formula: _sum__deposits == snapPre
    formula:        _sum__deposits == snapPre + inFlight
  Do NOT write `_deposits == ...` and do NOT write `_sum__deposits <= ...`.'''
if old not in s:
    raise SystemExit("prompt equality anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched: prompt sharply separates exposure invariant (==) from backing (<=)")
