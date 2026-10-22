#!/usr/bin/env python3
"""Find out why RQ3 contracts produce no verdict.

The verdicts file records which arm ran, not why it produced nothing: the
general arm's last line is almost always "sampling N candidate MCVPs", which
only says no plan survived. This re-runs non-verdict contracts, keeps the full
log and stderr (where the validator reports), and sorts each into a root cause.

  python3 rq3_diagnose.py --per-group 4
  python3 rq3_diagnose.py --all

Logs are kept under results/rq3_diag/ so any row can be read in full.
"""
import argparse
import collections
import csv
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def run(path, target, timeout, llm):
    cmd = [sys.executable, "run_aegis.py", path, "--property", target or "true",
           "--json", "--llm", llm, "--k", "2", "--max-repair-rounds", "2",
           "--smt-timeout-ms", "60000"]
    try:
        p = subprocess.run(cmd, cwd=HERE, capture_output=True, text=True,
                           timeout=timeout)
    except subprocess.TimeoutExpired:
        return None, "", "timeout"
    try:
        d = json.loads(p.stdout)
    except Exception:
        return None, p.stderr, "no json"
    return d, p.stderr, ""


def cause(d, err):
    """One root cause per contract, most specific first."""
    log = "\n".join(d.get("log", []) if d else [])
    both = log + "\n" + (err or "")

    if d and d.get("status") == "HARNESS_NONCONFORMING":
        m = re.search(r"\[harness\][^\n]*", both)
        return "harness: " + (m.group(0)[10:90] if m else "nonconforming")
    if "compile error" in both:
        m = re.search(r"Error: ([^\n.]{0,70})", both)
        return "compile error: " + (m.group(1) if m else "?")
    if "could not encode this obligation" in both:
        return "CHC could not encode obligation"
    if "wall-clock timeout" in both or "timeout" in both.lower():
        if "OBL_" in both:
            return "solver timeout on an obligation"
    flagged = re.findall(r"validation flagged: \[([^\]]*)\]", both)
    if flagged and not re.search(r"compiled \d+ obligations", both):
        mods = collections.Counter(
            m.strip(" '\"") for f in flagged for m in f.split(","))
        top = mods.most_common(1)[0][0] if mods else "?"
        return f"validator rejected every plan (mostly: {top})"
    if re.search(r"OBL_\w+ \[\w+\]: UNKNOWN", both):
        m = re.search(r"(OBL_\w+) \[\w+\]: UNKNOWN :: ([^\n]{0,60})", both)
        return (f"obligation undecided: {m.group(1)} :: {m.group(2)}"
                if m else "obligation undecided")
    if "CANARY DID NOT FIRE" in both:
        m = re.search(r"CANARY DID NOT FIRE[^;]*; ([^-\n]{0,60})", both)
        return "canary: " + (m.group(1).strip() if m else "did not fire")
    if "loop verification: UNKNOWN" in both:
        m = re.search(r"\[loop\] ([^\n]{0,80})", both)
        return "loop undecided: " + (m.group(1) if m else "")
    if "repair budget" in both:
        return "repair budget exhausted"
    return "unclassified"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verdicts", default="results/rq3_verdicts.csv")
    ap.add_argument("--per-group", type=int, default=4,
                    help="contracts to re-run from each arm/status group")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--llm", default="openai")
    ap.add_argument("--timeout", type=int, default=240)
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(os.path.join(HERE, args.verdicts)))
            if r["outcome"] == "NV"]
    if not args.all:
        groups = collections.defaultdict(list)
        for r in rows:
            groups[(r["arm"], r["status"])].append(r)
        rows = [r for g in groups.values() for r in g[:args.per_group]]

    outdir = os.path.join(HERE, "results/rq3_diag")
    os.makedirs(outdir, exist_ok=True)
    tally = collections.Counter()
    records = []
    for i, r in enumerate(rows, 1):
        d, err, fail = run(r["path"], r.get("target", ""), args.timeout,
                           "stub" if r["arm"] != "general" else args.llm)
        c = fail or cause(d, err)
        tally[(r["arm"], c.split(":")[0])] += 1
        records.append((r["contract"], r["arm"], c))
        base = f"{i:02d}_{r['contract'][:40]}"
        with open(os.path.join(outdir, base + ".log"), "w") as fh:
            fh.write("\n".join((d or {}).get("log", [])))
            fh.write("\n\n--- stderr ---\n" + (err or ""))
        print(f"[{i:2d}/{len(rows)}] {r['contract'][:28]:28s} {r['arm']:9s} {c[:90]}")

    print("\nroot causes:")
    for (arm, c), n in sorted(tally.items(), key=lambda x: (-x[1], x[0])):
        print(f"  {n:3d}  {arm:9s}  {c}")
    with open(os.path.join(outdir, "summary.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["contract", "arm", "cause"])
        w.writerows(records)
    print(f"\nfull logs: results/rq3_diag/   summary: results/rq3_diag/summary.csv")


if __name__ == "__main__":
    main()
