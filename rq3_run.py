#!/usr/bin/env python3
"""Run the tool over the frozen RQ3 labels.

Step four. Each contract is run with the target relation its annotator wrote,
frozen before this script existed. Nothing here decides what is correct; it
records what the tool said, and rq3_table5.py scores it.

  python3 rq3_run.py --llm openai --smt-timeout-ms 120000
  python3 rq3_run.py --arm read_only --out results/rq3_ro.csv

A contract whose annotator stated no target relation is still run -- the loop
and read-only arms need none -- but the row is marked so the scorer can keep
general-arm verdicts on those separate.
"""
import argparse
import csv
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
FIELDS = ["contract", "path", "arm", "weight", "label", "expected", "target",
          "has_target", "status", "outcome", "seconds", "backend", "reason"]
_REASON_PREFIXES = ("[loop]", "[readonly]", "[gate:nesting]",
                    "[gate:coverage]", "[gate]", "[3]", "[!]")
_NO_VERIFIER = "NO REAL VERIFIER"


def classify(label, status):
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


def _backend(log):
    for ln in (log or []):
        if _NO_VERIFIER in ln:
            return "none"
    for ln in (log or []):
        if "REAL SMTChecker" in ln:
            return "smtchecker"
    return "?"


def run_one(path, target, args):
    cmd = [sys.executable, "run_aegis.py", path, "--property", target or "true",
           "--json", "--smt-timeout-ms", str(args.smt_timeout_ms),
           "--llm", args.llm, "--k", str(args.k),
           "--max-repair-rounds", str(args.max_repair_rounds),
           "--sites", args.sites]
    if getattr(args, "trace_root", ""):
        _stem = os.path.basename(path).rsplit(".", 1)[0]
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
        return parsed["status"], secs, _backend(log), _reason(log)
    except Exception:
        tail = (proc.stderr or proc.stdout or "").strip().splitlines()
        return "ERROR", secs, "?", (tail[-1][:120] if tail else "no output")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", default="results/rq3_frozen_labels.json")
    ap.add_argument("--out", default="results/rq3_verdicts.csv")
    ap.add_argument("--arm", default="", help="restrict to one arm")
    ap.add_argument("--llm", default="openai")
    ap.add_argument("--k", type=int, default=4)
    ap.add_argument("--max-repair-rounds", type=int, default=3)
    ap.add_argument("--sites", default="primary")
    ap.add_argument("--trace-root", default="results/trace_rq3",
                    help="keep every intermediate artifact of each contract "
                         "under <root>/<contract>/; empty string to switch off")
    ap.add_argument("--smt-timeout-ms", type=int, default=120000)
    ap.add_argument("--per-contract-timeout", type=int, default=300)
    ap.add_argument("--append", action="store_true")
    ap.add_argument("--formal", default="",
                    help="results/rq3_formal_targets.csv: run the general arm "
                         "on the translated targets, and record the ones that "
                         "are not expressible instead of running them")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    labels = json.load(open(os.path.join(HERE, args.labels)))
    formal = {}
    if args.formal:
        for r in csv.DictReader(open(os.path.join(HERE, args.formal))):
            formal[r["path"]] = r
    items = [(p, m) for p, m in sorted(labels.items())
             if not args.arm or m["arm"] == args.arm]
    print(f"{args.labels}: {len(items)} contract(s)"
          + (f", arm={args.arm}" if args.arm else ""))

    if args.dry_run:
        for p, m in items:
            print(f"  {m['contract']:34s} {m['arm']:10s} {m['label']:7s} "
                  f"target={(m['target'] or 'none')[:40]}")
        return

    out_path = os.path.join(HERE, args.out)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    prior = []
    if args.append and os.path.exists(out_path):
        prior = list(csv.DictReader(open(out_path)))
        done = {r["path"] for r in prior}
        items = [(p, m) for p, m in items if p not in done]
        print(f"appending: {len(prior)} recorded, {len(items)} to run")

    # Rows are written as each contract finishes rather than once at the end,
    # so an interrupted run loses at most the contract in flight and --append
    # resumes from the next one. Writing only at the end meant a machine that
    # powered off an hour into the general arm lost the whole hour.
    fresh = not (args.append and os.path.exists(out_path))
    fh = open(out_path, "w" if fresh else "a", newline="")
    writer = csv.DictWriter(fh, fieldnames=FIELDS)
    if fresh:
        writer.writeheader()
        fh.flush()

    rows = []
    for i, (path, meta) in enumerate(items, 1):
        target = (meta.get("target") or "").strip()
        has_target = "no" if target.lower() in ("", "none") else "yes"
        f = formal.get(path)
        if f is not None and meta["arm"] == "general":
            if f["status"] == "auto" and f["target_formal"].strip():
                target = f["target_formal"].strip()
            elif f["status"] == "not_expressible":
                has_target = "no"
        if f is not None and meta["arm"] == "general" and \
                f["status"] == "not_expressible":
            # The relation is not a storage invariant the property language
            # can state, so there is nothing sound to verify; recorded so the
            # scorer can report how many deployed contracts fall outside it.
            status, secs, backend, why = ("NOT_EXPRESSIBLE", 0.0, "skipped",
                                          (f.get("note") or "")[:160])
        elif meta["arm"] == "general" and has_target == "no":
            # The general arm verifies a supplied property. With none, the only
            # thing left to check is `true`, which always holds and proves
            # nothing, so the run is skipped and the contract set apart.
            status, secs, backend, why = ("NO_TARGET", 0.0, "skipped",
                                          "no stated target relation")
        else:
            status, secs, backend, why = run_one(path, target, args)
        outcome = classify(meta["label"], status)
        row = {"contract": meta["contract"], "path": path,
               "arm": meta["arm"], "weight": meta.get("weight", 1.0),
               "label": meta["label"], "expected": meta["expected"],
               "target": target, "has_target": has_target,
               "status": status, "outcome": outcome, "seconds": secs,
               "backend": backend, "reason": why}
        rows.append(row)
        writer.writerow({k: row.get(k, "") for k in FIELDS})
        fh.flush()
        os.fsync(fh.fileno())
        mark = "" if outcome in ("TP", "TN") else f"   <-- {outcome}"
        print(f"[{i:3d}/{len(items)}] {meta['contract'][:32]:32s} "
              f"{meta['arm']:10s} {status:12s} {secs:6.1f}s{mark}")
    fh.close()

    allrows = prior + rows
    dead = [r for r in allrows if r.get("backend") == "none"]
    if dead:
        print(f"\n*** {len(dead)} contract(s) ran with NO VERIFIER. Check "
              f"solc --version, then solc-select use 0.8.26 and re-run. ***")
    print(f"\nwrote {args.out} ({len(allrows)} row(s))")
    print("score it with: python3 rq3_table5.py")


if __name__ == "__main__":
    main()
