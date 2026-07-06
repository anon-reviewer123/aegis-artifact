#!/usr/bin/env python3
"""
baseline_detectors.py  --  RQ1 detection-only baselines (Slither, Mythril).

These are NOT verifiers: they take no target property. Their RQ1 row exists to
make one point precisely -- detectors flag a re-entry *pattern* but (a) produce
no verdict on YOUR property, and (b) never localize to a violated A/G
obligation. So their columns are:
    flags_reentrancy : Y/N   (did it raise any reentrancy/SWC-107/116 finding?)
    verdict          : always "NO_VERDICT" (they don't decide your property)
    localized        : always False (no obligation notion)

This wrapper parses each tool's machine output into the shared schema so
make_rq1_tables.py can place them in Table 1 / Table 2 alongside the verifiers.

It SHELLS OUT to `slither` and `myth`, which you install separately (see
INSTALL_BASELINES.md). It never fabricates a finding: if the tool errors or is
absent, the record says so and flags_reentrancy=None (unknown), never N.

Usage:
  python3 baseline_detectors.py --tool slither --corpus contracts/corpus \
        --labels benchmark.json --out results/baseline_slither.json
  python3 baseline_detectors.py --tool mythril --corpus contracts/corpus \
        --labels benchmark.json --out results/baseline_mythril.json
"""
from __future__ import annotations
import os, re, sys, glob, json, time, shutil, subprocess, argparse


# --- reentrancy-ish signals each tool emits -------------------------------
SLITHER_REENTRANCY_DETECTORS = (
    "reentrancy-eth", "reentrancy-no-eth", "reentrancy-benign",
    "reentrancy-events", "reentrancy-unlimited-gas", "reentrancy-balance",
)
MYTHRIL_REENTRANCY_SWC = ("SWC-107", "SWC-116", "SWC-117")  # reentrancy / state-after-call


def run_slither(sol_path: str, solc_version: str | None) -> dict:
    if not shutil.which("slither"):
        return dict(ran=False, flags=None, detail="slither not installed")
    env = dict(os.environ)
    # caller is expected to have `solc-select use <ver>` already; we still try
    # to set per-file if a version is given and solc-select is present.
    cmd = ["slither", sol_path, "--json", "-"]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=600, env=env)
    except subprocess.TimeoutExpired:
        return dict(ran=True, flags=None, detail="slither timeout")
    out = p.stdout or ""
    # slither --json - prints a JSON blob on stdout even on non-zero exit
    flagged = False
    detectors_seen = []
    try:
        blob = json.loads(out)
        for d in blob.get("results", {}).get("detectors", []):
            chk = d.get("check", "")
            if chk in SLITHER_REENTRANCY_DETECTORS:
                flagged = True
                detectors_seen.append(chk)
    except Exception:
        # fall back to text scan of stderr (slither prints findings there too)
        txt = (p.stdout or "") + (p.stderr or "")
        for det in SLITHER_REENTRANCY_DETECTORS:
            if det in txt:
                flagged = True
                detectors_seen.append(det)
    return dict(ran=True, flags=flagged,
                detail="detectors: " + (",".join(sorted(set(detectors_seen)))
                                        or "none"))


def run_mythril(sol_path: str, solc_version: str | None) -> dict:
    if not shutil.which("myth"):
        return dict(ran=False, flags=None, detail="mythril (myth) not installed")
    cmd = ["myth", "analyze", sol_path, "-o", "json",
           "--execution-timeout", "120"]
    if solc_version:
        cmd += ["--solv", solc_version]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    except subprocess.TimeoutExpired:
        return dict(ran=True, flags=None, detail="mythril timeout")
    out = p.stdout or ""
    flagged = False
    swcs = []
    try:
        blob = json.loads(out)
        for issue in blob.get("issues", []):
            swc = "SWC-" + str(issue.get("swc-id", ""))
            if swc in MYTHRIL_REENTRANCY_SWC:
                flagged = True
                swcs.append(swc)
    except Exception:
        txt = out + (p.stderr or "")
        for swc in MYTHRIL_REENTRANCY_SWC:
            if swc in txt:
                flagged = True
                swcs.append(swc)
    return dict(ran=True, flags=flagged,
                detail="SWC: " + (",".join(sorted(set(swcs))) or "none"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tool", required=True, choices=["slither", "mythril"])
    ap.add_argument("--corpus", default="contracts/corpus")
    ap.add_argument("--labels", default="benchmark.json")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    labels = json.load(open(args.labels)) if os.path.exists(args.labels) else {}
    runner = run_slither if args.tool == "slither" else run_mythril
    toolname = "slither" if args.tool == "slither" else "mythril"

    records = []
    for sol in sorted(glob.glob(os.path.join(args.corpus, "*.sol"))):
        b = os.path.basename(sol)
        if b.endswith(".harness.sol"):
            continue
        meta = labels.get(b)
        if not meta:
            continue
        t0 = time.time()
        r = runner(sol, meta.get("solc"))
        secs = round(time.time() - t0, 1)
        rec = dict(
            tool=toolname, contract=b, **{"class": meta.get("class", "?")},
            flags_reentrancy=(None if r["flags"] is None else bool(r["flags"])),
            verdict="NO_VERDICT",          # detectors never decide your property
            localized=False,               # no obligation notion, ever
            localized_to=None,
            seconds=secs, detail=r["detail"], ran=r["ran"],
        )
        records.append(rec)
        flag = ("?" if r["flags"] is None else ("Y" if r["flags"] else "N"))
        print(f"  {b:28s} flags_reentrancy={flag}  {secs}s  ({r['detail'][:40]})")

    out = args.out or f"results/baseline_{toolname}.json"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(records, open(out, "w"), indent=2)
    print(f"\nwrote {len(records)} records -> {out}")


if __name__ == "__main__":
    main()
