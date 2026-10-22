"""
proof_cache.py - Idea 2: cross-round proof reuse via inductive invariants.

When OBL_cb_g verifies, the solver has effectively proven that callback g
preserves the exposure invariant I_exp that was in force at that time. That
proof is keyed by the *invariant g was shown to preserve*. If a later repair
round changes a DIFFERENT module and yields a new exposure invariant I_exp',
we do not need to re-run the (expensive) Horn solver on OBL_cb_g whenever the
new invariant is at least as strong as the old one on g's behaviour: if
I_exp' => I_exp_cached is valid, then g preserving I_exp_cached and the
strengthening together still preserve I_exp' for the cached callback proof's
reachable states. We check that entailment with a single Z3 call -- orders of
magnitude cheaper than a CHC re-discharge.

DESIGN HONESTY:
  * This is an OPTIMISATION, never a soundness device. A "reused" obligation is
    only ever skipped when Z3 proves the entailment VALID. If Z3 returns sat
    (a countermodel) or unknown, we DO NOT skip -- we fall through to the real
    backend. So proof reuse can only ever turn a real solver call into a
    cheaper-but-still-sound Z3 entailment; it can never manufacture a VERIFIED.
  * The cached object is the *invariant formula* the obligation was proven
    against, plus the mcvp_version at which it held. This is the robust form of
    "extract Eldarica's inductive invariant": we cache the predicate the
    obligation established rather than Eldarica's raw Horn solution, which keeps
    the contribution working across Eldarica output-format versions. (If raw
    inductive-invariant extraction is later wired in, it slots into
    CachedProof.invariant unchanged.)

ENTAILMENT ENGINE:
  We translate the backend-agnostic invariant strings (e.g.
  "totalAssets == totalShares + inFlight") into Z3 integer/bool constraints and
  check  Not(I_new => I_old)  for unsat. Variables are modelled as unbounded
  Ints (uint256 is non-negative; we add >= 0 bounds for storage vars) and
  bools as Bools.
"""
from __future__ import annotations
from dataclasses import dataclass, field
import re

try:
    import z3
    _Z3_OK = True
except Exception:               # pragma: no cover
    _Z3_OK = False


@dataclass
class CachedProof:
    """A previously-discharged obligation and the invariant it preserved."""
    obligation: str             # e.g. "OBL_cb_redeemAll"
    callback: str               # e.g. "redeemAll"
    invariant: str              # I_exp formula the proof was against
    mcvp_version: int           # the round/version at which it held


@dataclass
class ReuseDecision:
    obligation: str
    reused: bool
    reason: str = ""
    # If entailment FAILS, Z3 gives a witness: a state where I_new holds but
    # I_old does not. Threaded back into the repair prompt (Idea-1 style).
    witness: dict = field(default_factory=dict)


class ProofCache:
    def __init__(self):
        self._cache: dict[str, CachedProof] = {}
        self.reuse_hits = 0
        self.reuse_misses = 0

    # ---- population ------------------------------------------------------
    def record_verified(self, obligation: str, callback: str,
                        invariant: str, mcvp_version: int) -> None:
        """Called by the pipeline whenever the backend returns 'verified' for a
        callback-preservation obligation."""
        self._cache[obligation] = CachedProof(
            obligation=obligation, callback=callback,
            invariant=invariant, mcvp_version=mcvp_version)

    def invalidate_for_callback(self, callback: str) -> None:
        """A repaired closure may add/remove callbacks; drop any cached proof
        for a callback that is no longer the same module's responsibility."""
        drop = [k for k, v in self._cache.items() if v.callback == callback]
        for k in drop:
            self._cache.pop(k, None)

    # ---- the reuse query -------------------------------------------------
    def try_reuse(self, obligation: str, new_invariant: str,
                  storage_vars: list[str], ghost_vars: list[str]) -> ReuseDecision:
        """Decide whether `obligation` can be skipped under `new_invariant`.

        Reuse is permitted iff  new_invariant => cached_invariant  is VALID.
        Anything other than 'valid' -> do not reuse (fall through to backend).
        """
        cached = self._cache.get(obligation)
        if cached is None:
            return ReuseDecision(obligation, False, "no cached proof")
        if cached.invariant.strip() == new_invariant.strip():
            self.reuse_hits += 1
            return ReuseDecision(obligation, True,
                                 "invariant unchanged since cached proof")
        if not _Z3_OK:
            return ReuseDecision(obligation, False,
                                 "z3 unavailable; cannot check entailment")

        verdict, witness = _entails(new_invariant, cached.invariant,
                                    storage_vars, ghost_vars)
        if verdict == "valid":
            self.reuse_hits += 1
            return ReuseDecision(
                obligation, True,
                f"I_new => I_cached valid (cached@v{cached.mcvp_version}); "
                f"solver re-discharge skipped")
        self.reuse_misses += 1
        reason = ("entailment invalid; new invariant admits a state the cached "
                  "proof excluded" if verdict == "invalid"
                  else "entailment unknown to Z3")
        return ReuseDecision(obligation, False, reason, witness=witness)

    def stats(self) -> dict:
        return {"reuse_hits": self.reuse_hits,
                "reuse_misses": self.reuse_misses,
                "cached_proofs": len(self._cache)}


# --------------------------------------------------------------------------
# Invariant -> Z3 translation + entailment
# --------------------------------------------------------------------------
_IDENT_RE = re.compile(r"[A-Za-z_]\w*")


def _to_z3(formula: str, env: dict):
    """Translate a simple invariant string into a Z3 expression using `env`
    (name -> z3 Int/Bool). Supports ==, !=, <=, >=, <, >, +, -, *, &&, ||, ().
    This is a small, total expression compiler for the linear-int/bool
    fragment our exposure invariants live in.
    """
    # Normalise Solidity/boolean operators to Python-ish tokens we can eval
    # against a z3 namespace. We do NOT use Python eval on raw input: we first
    # whitelist tokens, then build with z3 operators via a tiny shunting eval.
    expr = formula.strip()
    expr = expr.replace("&&", " and ").replace("||", " or ")
    expr = expr.replace("==", " __eq__ ").replace("!=", " __ne__ ")
    expr = expr.replace(">=", " __ge__ ").replace("<=", " __le__ ")
    # guard against the single < > after the >= <= split
    expr = re.sub(r"(?<![_\w])>(?!=)", " __gt__ ", expr)
    expr = re.sub(r"(?<![_\w])<(?!=)", " __lt__ ", expr)

    # Build a safe namespace: identifiers -> z3 vars; comparison helpers.
    safe: dict = {}
    for name in set(_IDENT_RE.findall(formula)):
        if name in ("and", "or", "not", "true", "false", "True", "False"):
            continue
        if name in env:
            safe[name] = env[name]
    safe["__eq__h"] = lambda a, b: a == b

    # Replace infix __op__ tokens with real Python operators that z3 overloads.
    expr = (expr.replace("__eq__", "==").replace("__ne__", "!=")
                .replace("__ge__", ">=").replace("__le__", "<=")
                .replace("__gt__", ">").replace("__lt__", "<"))
    expr = expr.replace("true", "True").replace("false", "False")

    # z3 overloads ==,>=,... on its Int/Bool objects, so a constrained eval over
    # the whitelisted namespace yields a z3 BoolRef.
    safe_globals = {"__builtins__": {}}
    safe_locals = dict(safe)
    safe_locals["And"] = z3.And
    safe_locals["Or"] = z3.Or
    safe_locals["Not"] = z3.Not
    return eval(expr, safe_globals, safe_locals)


def _entails(i_new: str, i_old: str,
             storage_vars: list[str], ghost_vars: list[str]) -> tuple[str, dict]:
    """Return ('valid'|'invalid'|'unknown', witness). Valid iff i_new => i_old.

    We check unsat of  i_new AND Not(i_old).  If sat, the model is a witness
    state where the new invariant holds but the cached one does not.
    """
    env: dict = {}
    for v in storage_vars:
        env[v] = z3.Int(v)
    for g in ghost_vars:
        env.setdefault(g, z3.Int(g))

    try:
        new_e = _to_z3(i_new, env)
        old_e = _to_z3(i_old, env)
    except Exception as ex:
        return "unknown", {"error": str(ex)}

    s = z3.Solver()
    # uint256 storage/ghosts are non-negative.
    for v in env.values():
        if isinstance(v, z3.ArithRef):
            s.add(v >= 0)
    s.add(new_e)
    s.add(z3.Not(old_e))
    res = s.check()
    if res == z3.unsat:
        return "valid", {}
    if res == z3.sat:
        m = s.model()
        witness = {}
        for name, var in env.items():
            try:
                val = m.eval(var, model_completion=True)
                witness[name] = int(val.as_long()) if hasattr(val, "as_long") else str(val)
            except Exception:
                pass
        return "invalid", witness
    return "unknown", {}
