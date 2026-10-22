#!/usr/bin/env python3
"""Collect the full construction failure for named RQ3 contracts.

The verdicts and the diagnostic summary say a harness did not compile, or was
rejected as nonconforming, but not which line or which missing name. This runs
each named contract through the harness and view-obligation builders, compiles
what they produce, and writes every error with the source lines around it into
one file that can be read or shared as it stands.

  python3 rq3_explain.py KWWVaultEth OCTOPUS_MINT BPYC
  python3 rq3_explain.py --group readonly
  python3 rq3_explain.py --all-failures

Output: results/rq3_explain.txt
"""
import argparse
import csv
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

GROUPS = {
    "readonly": ["KWWVaultEth", "MistfitsNFTV2", "X7Pioneer", "Freaks", "NFT"],
    "syntax": ["OCTOPUS_MINT", "KinaInuBetting", "CelestialSecrets",
               "X7DAOLiquidityHub", "Unleashedplatinum"],
    "nonconforming": ["BPYC", "DLAND", "GoodMorning", "Coin", "EnderDragon"],
}


def context(src, line, span=3):
    lines = src.splitlines()
    out = []
    for n in range(max(1, line - span), min(len(lines), line + span) + 1):
        mark = ">>" if n == line else "  "
        out.append(f"      {mark} {n:5d} | {lines[n - 1][:140]}")
    return "\n".join(out)


def compile_report(tag, src, fh, tmpdir):
    path = os.path.join(tmpdir, re.sub(r"\W", "_", tag) + ".sol")
    with open(path, "w") as f:
        f.write(src)
    p = subprocess.run(["solc", "--bin", path], capture_output=True, text=True,
                       timeout=120)
    err = (p.stderr or "") + (p.stdout or "")
    errors = [m for m in re.finditer(
        r"Error: ([^\n]+)\n\s*-->\s*[^:]+:(\d+):(\d+)", err)]
    if not errors and "Error" not in err:
        fh.write(f"    {tag}: compiles\n")
        return True
    fh.write(f"    {tag}: DOES NOT COMPILE\n")
    for m in errors[:4]:
        msg, line = m.group(1), int(m.group(2))
        # the name solc complains about, where it quotes one
        fh.write(f"      error: {msg}\n")
        fh.write(context(src, line) + "\n")
    if not errors:
        fh.write("      " + err.strip()[:400].replace("\n", "\n      ") + "\n")
    return False


def explain(name, path, target, fh, tmpdir):
    from aegis import compiler, harness_check, harness_synth, static_analysis
    fh.write(f"\n{'=' * 78}\n{name}\n  {path}\n  target: {target or '(none)'}\n")
    try:
        facts = static_analysis.analyze(path)
    except Exception as exc:
        fh.write(f"  analysis failed: {exc}\n")
        return
    fh.write(f"  analyzer: {static_analysis.LAST_ANALYZER}   "
             f"storage vars: {len(facts.storage_vars)}   "
             f"sites: {len(facts.exposure_sites)}\n")
    if not facts.exposure_sites:
        fh.write("  no exposure site\n")
        return
    site = facts.exposure_sites[0]
    closure = facts.conservative_closure(site)
    fh.write(f"  site: {site.function} -> {site.call}\n")
    fh.write(f"  closure: {sorted(closure)}\n")

    src = open(path).read()
    try:
        hc = harness_synth.synthesize_harness(src, facts, site,
                                              stable_invariant=target)
    except Exception as exc:
        fh.write(f"  harness synthesis raised: {exc}\n")
        return

    rep = harness_check.check_harness(hc, list(closure),
                                      exposed_function=site.function)
    fh.write(f"  conformance: "
             + ("ok" if rep.conforming else rep.diagnostic) + "\n")
    compile_report("harness", hc, fh, tmpdir)

    try:
        obls = compiler.compile_view_obligations(facts, site, facts.contract, hc)
    except Exception as exc:
        fh.write(f"  view obligations raised: {exc}\n")
        obls = []
    for ob in obls[:3]:
        compile_report(ob.name, ob.harness_source, fh, tmpdir)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--group", choices=sorted(GROUPS))
    ap.add_argument("--all-failures", action="store_true")
    ap.add_argument("--verdicts", default="results/rq3_verdicts.csv")
    ap.add_argument("--out", default="results/rq3_explain.txt")
    args = ap.parse_args()

    rows = list(csv.DictReader(open(os.path.join(HERE, args.verdicts))))
    wanted = list(args.names)
    if args.group:
        wanted += GROUPS[args.group]
    if args.all_failures:
        wanted += [n for g in GROUPS.values() for n in g]
    if not wanted:
        ap.error("name some contracts, or use --group / --all-failures")

    import tempfile
    tmpdir = tempfile.mkdtemp(prefix="rq3_explain_")
    out = os.path.join(HERE, args.out)
    seen = set()
    with open(out, "w") as fh:
        for name in wanted:
            for r in rows:
                if r["contract"] != name or r["path"] in seen:
                    continue
                seen.add(r["path"])
                print(f"  {name}")
                explain(name, r["path"], r.get("target", ""), fh, tmpdir)
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
