#!/usr/bin/env python3
"""Re-run the fixed-form twins and diff the verdicts against a stored baseline.

Reads the twin manifest, runs each contract through run_aegis.py, and compares
the result with a baseline CSV recorded before the read-only changes. Prints
what moved and in which direction, so a table can be updated from evidence
rather than from a full re-run whose deltas are not visible.

  python3 compare_rq1.py --dry-run
  python3 compare_rq1.py --pattern read_only
  python3 compare_rq1.py --smt-timeout-ms 120000

Baseline defaults to the mode=none rows of results/rq4.csv.
"""
import argparse
import csv
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_FIELDS = ["contract", "pattern", "pair", "label", "expected",
              "baseline_status", "new_status", "baseline_correct",
              "new_correct", "movement", "seconds", "reason"]

# Log prefixes that explain where a contract ended up. Kept short so the
# printed table stays readable; the full log is in the saved run if needed.
_REASON_PREFIXES = ("[readonly]", "[gate", "[loop]", "[harness]", "[!]")


def load_manifest(path):
    data = json.load(open(path))
    data.pop("_README", None)
    return data


def load_baseline(path, mode):
    """Load the baseline verdicts, or an empty mapping when there is none.

    An empty --baseline means the manifest is new and has nothing to compare
    against, so every row is reported as new rather than as a movement.
    """
    base = {}
    if not path or not os.path.isfile(path):
        return base
    for row in csv.DictReader(open(path)):
        if "mode" in row and row["mode"] != mode:
            continue
        base[os.path.basename(row["contract"])] = row
    return base


def _reason(log):
    """One line saying where the run ended, taken from its own log."""
    picked = [ln.strip() for ln in (log or [])
              if ln.strip().startswith(_REASON_PREFIXES)]
    return picked[-1][:160] if picked else ""


def run_one(sol, prop, timeout_ms, per_contract_timeout, extra):
    cmd = [sys.executable, "run_aegis.py", sol, "--property", prop,
           "--json", "--smt-timeout-ms", str(timeout_ms)] + extra
    started = time.time()
    try:
        proc = subprocess.run(cmd, cwd=HERE, capture_output=True, text=True,
                              timeout=per_contract_timeout)
    except subprocess.TimeoutExpired:
        return "TIMEOUT", round(time.time() - started, 1), "killed after " \
               f"{per_contract_timeout}s"
    elapsed = round(time.time() - started, 1)
    try:
        parsed = json.loads(proc.stdout)
        return parsed["status"], elapsed, _reason(parsed.get("log"))
    except Exception:
        tail = (proc.stderr or proc.stdout or "").strip().splitlines()
        return ("ERROR:" + (tail[-1][:60] if tail else "no output"), elapsed,
                "")


def movement(base_correct, new_correct, base_status, new_status):
    if base_status == "":
        return "new"
    if base_correct == new_correct:
        return "same" if base_status == new_status else "same-verdict-class"
    return "improved" if new_correct else "REGRESSED"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default="rq1_twins.json")
    ap.add_argument("--baseline", default="results/rq4.csv")
    ap.add_argument("--baseline-mode", default="none")
    ap.add_argument("--out", default="results/rq1_recheck.csv")
    ap.add_argument("--pattern", default="", help="only loop or read_only")
    ap.add_argument("--smt-timeout-ms", type=int, default=120000,
                    help="per-obligation solver budget")
    ap.add_argument("--per-contract-timeout", type=int, default=300,
                    help="wall-clock kill for one contract, in seconds; the "
                         "paper's per-contract budget is 300")
    ap.add_argument("--llm", default="stub")
    ap.add_argument("--sites", default="primary",
                    help="general arm site mode: primary or all")
    ap.add_argument("--k", type=int, default=4,
                    help="candidate MCVPs sampled per contract")
    ap.add_argument("--max-repair-rounds", type=int, default=3,
                    help="repair budget; the paper reports three rounds, "
                         "while run_aegis.py defaults to eight")
    ap.add_argument("--limit", type=int, default=0,
                    help="stop after this many contracts, for sampling a "
                         "long run before committing to all of it")
    ap.add_argument("--dry-run", action="store_true",
                    help="list what would run, without invoking the solver")
    args = ap.parse_args()

    manifest = load_manifest(os.path.join(HERE, args.manifest))
    baseline_path = (os.path.join(HERE, args.baseline)
                     if args.baseline.strip() else "")
    baseline = load_baseline(baseline_path, args.baseline_mode)
    items = [(p, m) for p, m in sorted(manifest.items())
             if not args.pattern or m.get("pattern") == args.pattern]
    # Sampling keeps whole pairs together: half a pair says nothing about
    # discrimination, which is what these twins exist to measure.
    if args.limit:
        keep, seen = [], []
        for entry in items:
            pair = entry[1].get("pair", "")
            if pair not in seen:
                if len(seen) >= args.limit:
                    break
                seen.append(pair)
            keep.append(entry)
        items = keep
        print(f"sampling {len(seen)} pair(s): {', '.join(seen)}")

    print(f"manifest {args.manifest}: {len(items)} contract(s)")
    if baseline:
        print(f"baseline {args.baseline} (mode={args.baseline_mode}): "
              f"{len(baseline)} row(s)")
    else:
        print("baseline: none -- reporting verdicts against the manifest's "
              "expected values only")
    if args.dry_run:
        for sol, meta in items:
            b = baseline.get(os.path.basename(sol), {})
            print(f"  {os.path.basename(sol):32s} expect={meta['expected']:10s} "
                  f"baseline={b.get('status', '-')}")
        print("\ndry run: nothing was executed")
        return

    rows, changed = [], []
    for i, (sol, meta) in enumerate(items, 1):
        name = os.path.basename(sol)
        status, secs, why = run_one(sol, meta["property"], args.smt_timeout_ms,
                                    args.per_contract_timeout,
                                    ["--llm", args.llm,
                                     "--k", str(args.k),
                                     "--max-repair-rounds",
                                     str(args.max_repair_rounds),
                                     "--sites", args.sites])
        new_correct = (status == meta["expected"])
        b = baseline.get(name, {})
        b_status = b.get("status", "")
        b_correct = (b.get("correct", "") == "True")
        move = movement(b_correct, new_correct, b_status, status)
        row = {"contract": name, "pattern": meta.get("pattern", ""),
               "pair": meta.get("pair", ""), "label": meta.get("label", ""),
               "expected": meta["expected"], "baseline_status": b_status,
               "new_status": status, "baseline_correct": b_correct,
               "new_correct": new_correct, "movement": move, "seconds": secs,
               "reason": why}
        rows.append(row)
        if move not in ("same",):
            changed.append(row)
        flag = {"REGRESSED": "  <-- REGRESSED", "improved": "  <-- improved"}.get(move, "")
        print(f"[{i:3d}/{len(items)}] {name:32s} {b_status or '-':>12s} -> "
              f"{status:12s} {secs:6.1f}s{flag}")
        if why and move != "same":
            print(f"          {why}")

    os.makedirs(os.path.dirname(os.path.join(HERE, args.out)) or ".",
                exist_ok=True)
    with open(os.path.join(HERE, args.out), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=OUT_FIELDS)
        w.writeheader()
        w.writerows(rows)

    n = len(rows)
    correct_new = sum(1 for r in rows if r["new_correct"])
    correct_old = sum(1 for r in rows if r["baseline_correct"])
    if baseline:
        print(f"\ncorrect: baseline {correct_old}/{n} -> new {correct_new}/{n}")
    else:
        print(f"\ncorrect: {correct_new}/{n} against expected verdicts")
    for kind in ("REGRESSED", "improved", "same-verdict-class", "new"):
        hits = [r for r in changed if r["movement"] == kind]
        if hits:
            print(f"\n{kind} ({len(hits)}):")
            for r in hits:
                print(f"  {r['contract']:32s} {r['label']:7s} "
                      f"expect {r['expected']:10s} "
                      f"{r['baseline_status'] or '-'} -> {r['new_status']}")
                if r["reason"]:
                    print(f"      {r['reason']}")
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
