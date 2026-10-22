import shutil
P = "aegis/synth.py"
shutil.copy(P, P + ".bak_prompt")
s = open(P).read()

# Add explicit guidance: when the exposed state is a mapping and a _sum_<m>
# ghost is available, the read-only backing invariant must use the SCALAR sum
# ghost _sum_<m>, never the bare mapping name (which is ill-typed as a scalar).
anchor = '''  Paper-style names are accepted as aliases: conservation, bounded-drift,'''
inject = '''- READ-ONLY REENTRANCY / mapping-sum backing: when the exposed storage is a
  mapping m(addr=>uint) written across the callback, the harness provides a
  SCALAR ghost named `_sum_m` that tracks sum_k m[k]. Express the exposure
  invariant over `_sum_m`, NEVER over the bare mapping `m` (a mapping cannot be
  compared as a scalar). The backing safety relation is `_sum_m <= <backing>`
  where <backing> is the contract's total that should cover the sum (e.g. the
  ETH balance for a pull-payment escrow). Use kind "conserve" with the tracked
  sum being `_sum_m`. Example for a deposits mapping `_deposits`:
    stable:  _sum__deposits == snapPre
    exposed: _sum__deposits == snapPre + inFlight
  Do NOT write `_deposits == ...`; write `_sum__deposits == ...`.
  Paper-style names are accepted as aliases: conservation, bounded-drift,'''
if anchor not in s:
    raise SystemExit("prompt anchor missing")
s = s.replace(anchor, inject)
open(P, "w").write(s)
print("patched synth.py prompt: mapping-sum ghost guidance added")
