#!/usr/bin/env python3
"""Show exactly why a view obligation harness fails to compile.

Builds the facts, the phase-split harness and the read-only obligations for one
contract, writes each obligation to disk, runs solc on it, and prints the
reported line with its neighbours. With --no-trim it compiles the untrimmed
harness as well, which tells you whether the failure comes from the trim
dropping something a kept function needs.

  python3 diagnose_view_harness.py contracts/corpus/ReadOnlyReentrancy_U01.sol
  python3 diagnose_view_harness.py contracts/corpus/ReadOnlyReentrancy_U01.sol --no-trim
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis import compiler, harness_synth, static_analysis
from aegis.footprint import classify_views
from aegis.static_analysis import view_closure


def solc_check(source, tag, outdir):
    path = os.path.join(outdir, tag + ".sol")
    with open(path, "w") as fh:
        fh.write(source)
    proc = subprocess.run(["solc", "--bin", path],
                          capture_output=True, text=True, timeout=120)
    err = (proc.stderr or "") + (proc.stdout or "")
    ok = "Error:" not in err
    print(f"\n--- {tag}: {'compiles' if ok else 'DOES NOT COMPILE'}  ({path})")
    if ok:
        return True
    for m in re.finditer(r"Error:\s*([^\n]+)\n\s*-->\s*[^:]+:(\d+):(\d+)", err):
        msg, line, col = m.group(1), int(m.group(2)), int(m.group(3))
        print(f"    {msg}  (line {line}, col {col})")
        lines = source.splitlines()
        for n in range(max(1, line - 2), min(len(lines), line + 2) + 1):
            mark = ">>" if n == line else "  "
            print(f"    {mark} {n:4d} | {lines[n-1]}")
    if "Error:" in err and "-->" not in err:
        print("   ", err.strip()[:600])
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("contract")
    ap.add_argument("--property", default="")
    ap.add_argument("--no-trim", action="store_true",
                    help="also compile the harness with no functions removed")
    ap.add_argument("--outdir", default="")
    args = ap.parse_args()

    outdir = args.outdir or tempfile.mkdtemp(prefix="aegis_diag_")
    os.makedirs(outdir, exist_ok=True)

    facts = static_analysis.analyze(args.contract)
    print(f"analyzer  : {static_analysis.LAST_ANALYZER}")
    print(f"storage   : {facts.storage_vars}")
    print(f"var types : {facts.var_types}")
    if not facts.exposure_sites:
        print("no exposure site; nothing to build")
        return
    site = facts.exposure_sites[0]
    print(f"site      : {site.function} -> {site.call}")
    print(f"writers   : {sorted(facts.conservative_closure(site))}")
    print(f"readers   : {sorted(facts.observation_closure(site))}")

    views = view_closure(facts, site.function)
    for v in classify_views(facts, site, views):
        print(f"  view {v.view}: admitted={v.admitted} :: {v.reason}")

    src = open(args.contract).read()
    hc = harness_synth.synthesize_harness(
        src, facts, site, stable_invariant=args.property)
    solc_check(hc, "harness_full", outdir)

    obls = compiler.compile_view_obligations(facts, site, facts.contract, hc)
    if not obls:
        print("\nno view obligations were compiled")
        return
    for ob in obls:
        solc_check(ob.harness_source, ob.name, outdir)

    if args.no_trim:
        print("\n=== same obligations with trimming disabled ===")
        original = compiler._trim_harness
        compiler._trim_harness = lambda s, keep: s
        try:
            for ob in compiler.compile_view_obligations(
                    facts, site, facts.contract, hc):
                solc_check(ob.harness_source, ob.name + "_untrimmed", outdir)
        finally:
            compiler._trim_harness = original

    print(f"\nall sources written to {outdir}")


if __name__ == "__main__":
    main()
