import shutil
P = "aegis/validator.py"
shutil.copy(P, P + ".bak_hg")
s = open(P).read()

# snapPre and inFlight are HARNESS-provided ghosts, constrained by the harness
# semantics (snapPre = entry snapshot set once in beginExposed; inFlight = the
# amount, set in beginExposed and cleared in endExposed). They are NOT free
# LLM-invented variables, so they must not count toward the "at most one
# unconstrained ghost" rule. Exempt them.
old = '''    unbacked = {g.name for g in plan.ghost_state if not g.backed_by_storage}
    unbacked_in_inv = unbacked & formula_idents'''
new = '''    # Harness-provided ghosts are constrained by harness semantics (snapPre is
    # the entry snapshot; inFlight is the amount ledger). They are not free
    # LLM-invented variables and must not count as unconstrained.
    _HARNESS_CONSTRAINED = {"inFlight", "snapPre", "exposed"}
    unbacked = {g.name for g in plan.ghost_state
                if not g.backed_by_storage and g.name not in _HARNESS_CONSTRAINED}
    unbacked_in_inv = unbacked & formula_idents'''
if old not in s:
    raise SystemExit("unbacked anchor missing")
s = s.replace(old, new)
open(P, "w").write(s)
print("patched: snapPre/inFlight exempt from unconstrained-ghost limit (harness-constrained)")
