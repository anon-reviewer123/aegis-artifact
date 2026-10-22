#!/usr/bin/env python3
"""Print every exposure site of a contract, in ranked order, with the window
test and the gate decisions that follow from it.

Use when a contract reports "the verdict does not cover the whole contract" so
you can see which site was chosen as primary, which sites carry a window, and
whether the two agree.

  python3 diagnose_sites.py contracts/corpus/TokenHookAccounting_U01.sol
  python3 diagnose_sites.py contracts/corpus/*.sol --brief
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis import coverage, guards, static_analysis


def report(path, brief=False):
    facts = static_analysis.analyze(path)
    sites = facts.exposure_sites
    name = os.path.basename(path)
    if not sites:
        print(f"{name}: no exposure site")
        return
    windowed = [s for s in sites
                if s.write_before_call and s.write_after_call]
    primary = sites[0]
    primary_windowed = bool(primary.write_before_call and
                            primary.write_after_call)
    gate = coverage.coverage_gate(facts, primary)

    if brief:
        flag = "" if (primary_windowed or not windowed) else "  <-- PRIMARY HAS NO WINDOW"
        print(f"{name:38s} sites={len(sites)} windowed={len(windowed)} "
              f"primary={primary.function}#{primary.index} "
              f"gate={'ok' if gate.ok else 'refuses'}{flag}")
        return

    print(f"\n=== {name}   (analyzer: {static_analysis.LAST_ANALYZER})")
    print(f"    storage   : {facts.storage_vars}")
    print(f"    var types : {facts.var_types}")
    print(f"    sites in ranked order (index 0 is the primary):")
    for rank, s in enumerate(sites):
        win = "WINDOW" if (s.write_before_call and s.write_after_call) else "no window"
        mark = "  <== primary" if rank == 0 else ""
        print(f"      [{rank}] {s.function}{s.call}#{s.index}  [{win}]{mark}")
        print(f"          before = {sorted(s.write_before_call)}")
        print(f"          after  = {sorted(s.write_after_call)}")
        print(f"          exposed= {sorted(s.exposed_storage)}")
        print(f"          flags  = {sorted(s.window_flags)}")
    print(f"    loop sites: {[(l.function, l.call) for l in facts.loop_sites]}")
    print(f"    full closure (primary) : {sorted(facts.full_closure(primary))}")
    print(f"    admissible closure     : "
          f"{sorted(guards.admissible_closure(facts, primary))}")
    g = guards.explain(facts, primary)
    if g:
        print(f"    {g}")
    print(f"    coverage gate : {'ok' if gate.ok else gate.reason}")
    ng = coverage.nesting_gate(facts, primary)
    print(f"    nesting gate  : {'ok' if ng.ok else ng.reason}")
    if windowed and not primary_windowed:
        print("    NOTE: the primary site carries no window while another site "
              "does; the ranking and the gate disagree about which site "
              "matters, which is what produces an unexplained refusal.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("contracts", nargs="+")
    ap.add_argument("--brief", action="store_true")
    args = ap.parse_args()
    for c in args.contracts:
        if ".harness." in c or ".ethmodel." in c:
            continue
        try:
            report(c, args.brief)
        except Exception as exc:
            print(f"{os.path.basename(c)}: analysis failed: {exc}")


if __name__ == "__main__":
    main()
