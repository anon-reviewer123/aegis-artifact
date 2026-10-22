#!/usr/bin/env python3
"""Run RQ1 and print the Table II row for AEGIS, plus a per-family breakdown.

Classification follows the paper: TP is an unsafe contract correctly refuted,
TN a safe contract correctly verified, FP a safe contract spuriously refuted,
FN an unsafe contract incorrectly verified. Failures, timeouts and UNKNOWN are
counted separately as N/V and never folded into the four disjoint columns.

  python3 rq1_run.py --arm fixed                    # deterministic, no model
  python3 rq1_run.py --arm general --llm openai     # needs a proposer
  python3 rq1_run.py --arm all --llm openai

Results append to a CSV so the two arms can be run separately and combined.
"""
import argparse
import csv
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FIELDS = ["contract", "family", "arm", "label", "expected", "status",
          "outcome", "seconds", "backend", "reason"]

# solc can change under a running batch -- a solc-select switch in another
# shell is enough -- and the pipeline then reports no verifier and falls back
# to the regex analyzer. The rows still look like results, so a run is checked
# for this and refuses to report a summary rather than produce a table nobody
# can trust.
_NO_VERIFIER = "NO REAL VERIFIER"
# One line kept per arm, so a non-verdict shows which arms were tried and what
# each concluded. Keeping only the last matching line hides the loop and
# read-only decisions behind the general arm's banner.
# One line kept per prefix. The two gates are listed separately: they print
# different reasons and a shared "[gate" prefix keeps only the last, which
# reported a coverage refusal for what was actually a nesting refusal.
_REASON_PREFIXES = ("[loop]", "[readonly]", "[gate:nesting]", "[gate:coverage]",
                    "[gate]", "[3]", "[!]")


def classify(label, status):
    """One of TP, TN, FP, FN, NV -- the paper's disjoint columns."""
    if status == "BUG_FOUND":
        return "TP" if label == "unsafe" else "FP"
    if status == "VERIFIED":
        return "TN" if label == "safe" else "FN"
    return "NV"


def _reason(log):
    last = {}
    for ln in (log or []):
        t = ln.strip()
        for pre in _REASON_PREFIXES:
            if t.startswith(pre):
                last[pre] = t
                break
    return " | ".join(last[p][:110] for p in _REASON_PREFIXES if p in last)


def _backend_of(log):
    for ln in (log or []):
        if _NO_VERIFIER in ln:
            return "none"
    for ln in (log or []):
        if "REAL SMTChecker" in ln:
            return "smtchecker"
    return "?"


def run_one(sol, prop, args):
    cmd = [sys.executable, "run_aegis.py", sol, "--property", prop, "--json",
           "--smt-timeout-ms", str(args.smt_timeout_ms),
           "--llm", args.llm, "--k", str(args.k),
           "--max-repair-rounds", str(args.max_repair_rounds),
           "--sites", args.sites, "--slice", args.slice]
    if getattr(args, "trace_root", ""):
        _stem = os.path.basename(sol).rsplit(".", 1)[0]
        cmd += ["--trace", os.path.join(HERE, args.trace_root, _stem)]
    started = time.time()
    try:
        proc = subprocess.run(cmd, cwd=HERE, capture_output=True, text=True,
                              timeout=args.per_contract_timeout)
    except subprocess.TimeoutExpired:
        return ("TIMEOUT", round(time.time() - started, 1), "?",
                "per-contract budget")
    secs = round(time.time() - started, 1)
    try:
        parsed = json.loads(proc.stdout)
        log = parsed.get("log")
        return parsed["status"], secs, _backend_of(log), _reason(log)
    except Exception:
        tail = (proc.stderr or proc.stdout or "").strip().splitlines()
        return ("ERROR", secs, "?",
                (tail[-1][:120] if tail else "no output"))


def summarise(rows, title):
    n = len(rows)
    if not n:
        return
    c = {k: sum(1 for r in rows if r["outcome"] == k)
         for k in ("TP", "TN", "FP", "FN", "NV")}
    unsafe = sum(1 for r in rows if r["label"] == "unsafe")
    decided = c["TP"] + c["TN"] + c["FP"] + c["FN"]
    prec = c["TP"] / (c["TP"] + c["FP"]) if (c["TP"] + c["FP"]) else 0.0
    rd = c["TP"] / (c["TP"] + c["FN"]) if (c["TP"] + c["FN"]) else 0.0
    ra = c["TP"] / unsafe if unsafe else 0.0
    cov = decided / n
    print(f"\n{title}  (N={n}, unsafe={unsafe})")
    print(f"  TN {c['TN']:3d}   TP {c['TP']:3d}   FN {c['FN']:3d}   "
          f"FP {c['FP']:3d}   N/V {c['NV']:3d}")
    print(f"  precision {prec:.0%}   recall {rd:.0%}/{ra:.0%}   "
          f"coverage {cov:.0%}   correct {c['TN'] + c['TP']}/{n}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default="rq1_full.json")
    ap.add_argument("--arm", default="all", choices=("all", "fixed", "general"))
    ap.add_argument("--family", default="", help="restrict to one family")
    ap.add_argument("--out", default="results/rq1_table2.csv")
    ap.add_argument("--llm", default="stub")
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--max-repair-rounds", type=int, default=3)
    ap.add_argument("--sites", default="primary")
    ap.add_argument("--trace-root", default="results/trace_rq1",
                    help="keep every intermediate artifact of each contract "
                         "under <root>/<contract>/; empty string to switch off")
    ap.add_argument("--slice", default="off", choices=("off", "on"))
    ap.add_argument("--smt-timeout-ms", type=int, default=120000)
    ap.add_argument("--per-contract-timeout", type=int, default=300)
    ap.add_argument("--append", action="store_true",
                    help="add to the existing CSV instead of replacing it")
    ap.add_argument("--rerun-nv", default="",
                    help="re-run only the contracts recorded as N/V in this "
                         "CSV, so a failure cluster can be re-examined "
                         "without repeating the whole set")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    manifest = json.load(open(os.path.join(HERE, args.manifest)))
    manifest.pop("_README", None)
    items = [(p, m) for p, m in sorted(manifest.items())
             if (args.arm == "all" or m.get("arm") == args.arm)
             and (not args.family or m.get("pattern") == args.family)]

    if args.rerun_nv:
        src = os.path.join(HERE, args.rerun_nv)
        nv = {r["contract"] for r in csv.DictReader(open(src))
              if r["outcome"] == "NV"}
        items = [(p, m) for p, m in items if os.path.basename(p) in nv]
        print(f"re-running {len(items)} contract(s) recorded as N/V in "
              f"{args.rerun_nv}")

    print(f"{args.manifest}: {len(items)} contract(s), arm={args.arm}, "
          f"llm={args.llm}")
    if args.dry_run:
        for p, m in items:
            print(f"  {os.path.basename(p):34s} {m['pattern']:20s} "
                  f"{m['label']:7s} expect={m['expected']}")
        return

    out_path = os.path.join(HERE, args.out)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    prior = []
    if args.append and os.path.exists(out_path):
        prior = list(csv.DictReader(open(out_path)))
        done = {r["contract"] for r in prior}
        items = [(p, m) for p, m in items
                 if os.path.basename(p) not in done]
        print(f"appending: {len(prior)} row(s) already recorded, "
              f"{len(items)} to run")

    rows = []
    for i, (sol, meta) in enumerate(items, 1):
        status, secs, backend, why = run_one(sol, meta["property"], args)
        outcome = classify(meta["label"], status)
        rows.append({"contract": os.path.basename(sol),
                     "family": meta["pattern"], "arm": meta["arm"],
                     "label": meta["label"], "expected": meta["expected"],
                     "status": status, "outcome": outcome,
                     "seconds": secs, "backend": backend, "reason": why})
        mark = "" if outcome in ("TP", "TN") else f"   <-- {outcome}"
        print(f"[{i:3d}/{len(items)}] {os.path.basename(sol):34s} "
              f"{status:12s} {secs:6.1f}s{mark}")
        if why and outcome not in ("TP", "TN"):
            for part in why.split(" | "):
                print(f"          {part}")

    all_rows = prior + rows
    with open(out_path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        for r in all_rows:
            w.writerow({k: r.get(k, "") for k in FIELDS})

    dead = [r for r in all_rows if r.get("backend") == "none"]
    if dead:
        print(f"\n*** {len(dead)} of {len(all_rows)} contract(s) ran with NO "
              f"VERIFIER, so this run is not a result. ***")
        print("    solc is not resolving to a 0.8.x build. Check with")
        print("      solc --version ; solc-select versions")
        print("    then  solc-select use 0.8.26  and run again.")
        for r in dead[:6]:
            print(f"      {r['contract']}")
        if len(dead) > 6:
            print(f"      ... and {len(dead) - 6} more")
        print(f"\nrows written to {args.out}; no summary is printed for a run "
              f"without a verifier")
        return

    summarise(all_rows, "TABLE II row (AEGIS)")
    fams = sorted({r["family"] for r in all_rows})
    if len(fams) > 1:
        print("\nper family:")
        for fam in fams:
            sub = [r for r in all_rows if r["family"] == fam]
            good = sum(1 for r in sub if r["outcome"] in ("TP", "TN"))
            nv = sum(1 for r in sub if r["outcome"] == "NV")
            print(f"  {fam:22s} correct {good:3d}/{len(sub):<3d}  N/V {nv}")
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
