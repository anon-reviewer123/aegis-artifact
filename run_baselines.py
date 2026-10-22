import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

REENTRANCY_HINTS = re.compile(
    r"reentran|re-entran|state.?change.?after|external call.*state|"
    r"unprotected.*call|dangerous.*call", re.I)


def resolve_solc(src):
    try:
        from aegis import backend
        return backend._resolve_solc_for(src)
    except Exception:
        return "solc"


def run_smtchecker(path, timeout):
    src = open(path, errors="ignore").read()
    solc = resolve_solc(src)
    try:
        cp = subprocess.run(
            [solc, "--model-checker-engine", "chc",
             "--model-checker-targets", "assert,underflow,overflow",
             "--model-checker-timeout", "30000", path],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "timeout", 0
    except FileNotFoundError:
        return "no_tool", 0
    out = cp.stdout + cp.stderr
    if "Error:" in out and "Warning" not in out:
        return "error", 0
    n = len(re.findall(r"Warning: CHC:", out))
    return ("warn" if n else "clean"), n


def run_slither(path, timeout):
    try:
        cp = subprocess.run(
            ["slither", path, "--json", "-", "--detect",
             "reentrancy-eth,reentrancy-no-eth,reentrancy-benign,"
             "reentrancy-events,reentrancy-unlimited-gas"],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "timeout", 0
    except FileNotFoundError:
        return "no_tool", 0
    try:
        start = cp.stdout.find("{")
        data = json.loads(cp.stdout[start:])
        dets = data.get("results", {}).get("detectors", [])
        return ("warn" if dets else "clean"), len(dets)
    except Exception:
        if "Error" in cp.stderr or cp.returncode not in (0, 255):
            return "error", 0
        return "clean", 0


def run_mythril(path, timeout):
    try:
        cp = subprocess.run(
            ["myth", "analyze", path, "-o", "json",
             "--execution-timeout", str(max(10, timeout - 10))],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "timeout", 0
    except FileNotFoundError:
        return "no_tool", 0
    try:
        start = cp.stdout.find("{")
        data = json.loads(cp.stdout[start:])
        issues = [i for i in data.get("issues", [])
                  if REENTRANCY_HINTS.search(i.get("title", "") +
                                             i.get("description", ""))]
        return ("warn" if issues else "clean"), len(issues)
    except Exception:
        return "error", 0


RUNNERS = {
    "smtchecker": run_smtchecker,
    "slither": run_slither,
    "mythril": run_mythril,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scope_csv")
    ap.add_argument("--tools", default="smtchecker,slither")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--out", default="results/baselines.csv")
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(args.scope_csv))
            if r.get("gas_forwarding") == "1"
            and r.get("expressible") == "1"
            and r.get("linear") == "1"]
    if args.limit:
        rows = rows[:args.limit]
    tools = [t.strip() for t in args.tools.split(",") if t.strip()]

    print("in-scope contracts: %d   tools: %s" % (len(rows), tools))
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)

    recs = []
    tally = {t: {} for t in tools}
    t0 = time.time()
    for i, r in enumerate(rows):
        rec = {"contract": r["contract"], "file": r["file"],
               "families": r["families"]}
        for t in tools:
            st, n = RUNNERS[t](r["file"], args.timeout)
            rec[t] = st
            rec[t + "_n"] = n
            tally[t][st] = tally[t].get(st, 0) + 1
        recs.append(rec)
        if (i + 1) % 10 == 0:
            el = time.time() - t0
            print("  %d/%d  %.0fs elapsed, ~%.0fmin left" %
                  (i + 1, len(rows), el,
                   (el / (i + 1) * (len(rows) - i - 1)) / 60),
                  file=sys.stderr)

    cols = ["contract", "file", "families"]
    for t in tools:
        cols += [t, t + "_n"]
    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(recs)

    print("\ncontracts run: %d" % len(recs))
    for t in tools:
        print("\n%s" % t)
        for k, v in sorted(tally[t].items(), key=lambda x: -x[1]):
            print("  %-10s %5d  (%.0f%%)" % (k, v, 100.0 * v / len(recs)))
    print("\nwrote %s" % args.out)


if __name__ == "__main__":
    main()
