#!/usr/bin/env python3
"""Run the same dumped obligations through several CHC solvers.

  python3 solver_compare.py results/stages_now --solvers eld z3 --timeout 300
  python3 solver_compare.py results/stages_now --only OBL_cb OBL_post --out results/solver_compare.csv
"""
import argparse
import csv
import glob
import os
import re
import signal
import subprocess
import time


def verdict(out):
    if re.search(r"^Error:", out, re.M):
        return "compile_error"
    if "not available" in out or "no Horn solver" in out.lower():
        return "no_solver"
    if "Assertion violation happens here" in out:
        return "refuted"
    if "might happen here" in out or "could not be proved" in out:
        return "unknown"
    return "proved"


def run(solc, path, solver, timeout):
    cmd = [solc, "--model-checker-engine", "chc",
           "--model-checker-targets", "assert",
           "--model-checker-solvers", solver,
           "--model-checker-timeout", str(timeout * 1000),
           "--model-checker-show-unproved", path]
    start = time.time()
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         text=True, start_new_session=True)
    try:
        out, err = p.communicate(timeout=timeout + 5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        p.communicate()
        return "timeout", round(time.time() - start, 1)
    return verdict(out + "\n" + err), round(time.time() - start, 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--solvers", nargs="+", default=["eld", "z3"])
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--only", nargs="*", default=["OBL_cb", "OBL_post", "OBL_pre"])
    ap.add_argument("--contracts", nargs="*", default=None)
    ap.add_argument("--solc", default="solc")
    ap.add_argument("--out", default="results/solver_compare.csv")
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(args.root, "*", "04_OBL_*.sol")))
    rows = []
    for f in files:
        contract = os.path.basename(os.path.dirname(f))
        name = os.path.basename(f)[3:-4]
        if args.contracts and contract not in args.contracts:
            continue
        if not any(name.startswith(p) for p in args.only):
            continue
        row = {"contract": contract, "obligation": name}
        for s in args.solvers:
            v, secs = run(args.solc, f, s, args.timeout)
            row[s] = v
            row[s + "_s"] = secs
        rows.append(row)
        print("  ".join(f"{k}={v}" for k, v in row.items()), flush=True)

    fields = ["contract", "obligation"] + [x for s in args.solvers for x in (s, s + "_s")]
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    print()
    for s in args.solvers:
        counts = {}
        for r in rows:
            counts[r[s]] = counts.get(r[s], 0) + 1
        print(s, counts)
    only = [r for r in rows if r[args.solvers[0]] != "proved"
            and any(r[s] == "proved" for s in args.solvers[1:])]
    print(f"proved only by a solver other than {args.solvers[0]}: {len(only)}")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
