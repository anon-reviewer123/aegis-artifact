#!/usr/bin/env python3
"""Aegis evaluation harness. Runs the full A/G spec-synthesis + verification
pipeline over the corpus and emits a results table plus per-contract RQ metrics.
Use --llm openai for real synthesis numbers; default 'stub' checks plumbing.

Each entry records the EXPECTED outcome so the table doubles as a regression
oracle: safe contracts must VERIFY, buggy contracts must be refuted (BUG_FOUND)
at a specific obligation/module."""
import os, glob, json, argparse
from aegis.pipeline import run_aegis

CORPUS = os.path.join(os.path.dirname(__file__), "contracts", "corpus")

# contract -> (target property, expected status, callback pattern)
TARGETS = {
    "MotivatingVault.sol":    ("totalAssets == totalShares", "VERIFIED",  "ERC777-hook"),
    "BuggyVault.sol":         ("totalAssets == totalShares", "BUG_FOUND", "ERC777-hook"),
    "InheritedVault.sol":     ("totalAssets == totalShares", "VERIFIED",  "inherited-state"),
    "ERC777Vault.sol":        ("totalAssets == totalShares", "VERIFIED",  "ERC777-hook"),
    "ERC777Buggy.sol":        ("totalAssets == totalShares", "BUG_FOUND", "ERC777-hook"),
    "NestedVault.sol":        ("totalAssets == totalShares", "VERIFIED",  "nested-reentrancy"),
    "NestedBuggy.sol":        ("totalAssets == totalShares", "BUG_FOUND", "nested-reentrancy"),
    "CrossFunctionVault.sol": ("totalAssets == totalShares", "VERIFIED",  "cross-function"),
    "CrossFunctionBuggy.sol": ("totalAssets == totalShares", "BUG_FOUND", "cross-function"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--llm", default="stub", choices=["stub", "openai", "anthropic"])
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    rows, records, correct = [], [], 0
    for sol in sorted(glob.glob(os.path.join(CORPUS, "*.sol"))):
        base = os.path.basename(sol)
        if base.endswith(".harness.sol") or base not in TARGETS:
            continue
        prop, expected, pattern = TARGETS[base]
        res = run_aegis(sol, prop, llm_backend=args.llm, k=args.k, verbose=False)
        m = res.metrics or {}
        # which obligation refuted it (for buggy contracts)
        failing = [o["obligation"] for o in res.obligations_report
                   if o.get("status") == "failed"]
        ok = (res.status == expected)
        correct += int(ok)
        rows.append((base, pattern, res.status, expected, "OK" if ok else "XX",
                     res.repair_rounds, ("+".join(failing) if failing else "-")))
        records.append({"contract": base, "pattern": pattern, "status": res.status,
                        "expected": expected, "match": ok, "metrics": m,
                        "refuted_at": failing})

    print(f"\n{'contract':<22}{'pattern':<18}{'status':<11}"
          f"{'expect':<11}{'':<4}{'rounds':<8}{'refuted_at'}")
    print("-" * 92)
    for r in rows:
        print(f"{r[0]:<22}{r[1]:<18}{r[2]:<11}{r[3]:<11}{r[4]:<4}{r[5]:<8}{r[6]}")
    print("-" * 92)
    print(f"oracle match: {correct}/{len(rows)} contracts behaved as expected "
          f"(backend={'real' if rows and records[0]['metrics'] else 'n/a'})")

    if args.json:
        print("\n" + json.dumps(records, indent=2))


if __name__ == "__main__":
    main()
