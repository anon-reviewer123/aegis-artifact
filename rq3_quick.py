#!/usr/bin/env python3
"""Why do general-arm contracts with clean formula targets decide nothing?

A narrow, fast diagnostic. It takes only the general-arm contracts whose target
translated into a proper formula and still came back undecided, runs each once
with a small budget, several at a time, and sorts them by where they stopped.
The point is to find the cause, not to produce verdicts, so one candidate plan,
one repair round and a short solver timeout are enough.

  python3 rq3_quick.py
  python3 rq3_quick.py --workers 4 --smt-timeout-ms 20000
"""
import argparse
import collections
import concurrent.futures as cf
import csv
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def run(row, smt_ms, budget, slice_mode="off", k=1, rounds=1, trace_root="",
        llm="openai"):
    cmd = [sys.executable, "run_aegis.py", row["path"],
           "--property", row["target"], "--json", "--llm", llm,
           "--k", str(k), "--max-repair-rounds", str(rounds),
           "--smt-timeout-ms", str(smt_ms), "--slice", slice_mode,
           "--sites", os.environ.get("AEGIS_SITES", "all")]
    if trace_root:
        stem = os.path.basename(row["path"]).rsplit(".", 1)[0]
        cmd += ["--trace", os.path.join(HERE, trace_root, stem)]
    import signal
    p = subprocess.Popen(cmd, cwd=HERE, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True,
                         start_new_session=True)
    try:
        out, err = p.communicate(timeout=budget)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        p.communicate()
        return row, None, "", "wall-clock budget"
    try:
        return row, json.loads(out), err, ""
    except Exception:
        return row, None, err, "no json"


def where(d, err, fail):
    """The stage the contract stopped at, and the detail that says why."""
    if fail:
        return "timeout", fail
    if d.get("status") in ("VERIFIED", "BUG_FOUND"):
        return d["status"], ""
    log = "\n".join(d.get("log", []))
    both = log + "\n" + (err or "")
    if d.get("status") == "HARNESS_NONCONFORMING":
        m = re.search(r"\[!\] ([^\n]+)", both)
        return "harness nonconforming", (m.group(1)[:120] if m else "")
    m = re.search(r"closure member\(s\) (\[[^\]]*\]) may write storage", both)
    if m:
        return "unbounded closure member", m.group(1)[:90]
    if "the target is true in every state" in both:
        return "target is a tautology", ""
    if "the target is violated without any callback" in both:
        return "target not an invariant", "violated with re-entry blocked"
    m = re.search(r"\[validator\] ([^\n]+)", both)
    if m and not re.search(r"compiled \d+ obligations", both):
        detail = re.sub(r"\[[^\]]*\]$", "", m.group(1)).strip()
        return "validator rejected the plan", detail[:90]
    hits = [m for m in re.finditer(
        r"(OBL_\w+) \[\w+\]: (FAILED|UNKNOWN) :: ([^\n]{0,70})", both)
        if not (m.group(1).endswith("_canary") and m.group(2) == "FAILED")]
    if hits:
        # a refuted OBL_pre only says that candidate's invariant was wrong;
        # when another candidate got past it, its stop is the informative one
        hits.sort(key=lambda m: 0 if "compile error" in m.group(3) else
                  (3 if m.group(1) == "OBL_pre" and m.group(2) == "FAILED" else
                   (1 if m.group(2) == "FAILED" else 2)))
        m = hits[0]
        kind = "compile error" if "compile error" in m.group(3) else (
            "obligation undecided" if m.group(2) == "UNKNOWN" else
            "obligation refuted, repair failed")
        return kind, f"{m.group(1)}: {m.group(3)}"
    if "wall-clock timeout" in both:
        return "solver timeout", ""
    return "other", (d.get("status") or "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verdicts", default="results/rq3_verdicts_v3.csv")
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--smt-timeout-ms", type=int, default=20000)
    ap.add_argument("--slice", default="off", choices=("off", "on"))
    ap.add_argument("--contracts", nargs="*", default=None,
                    help="only these contracts, by name; the default is every "
                         "general-arm contract with a clean target")
    ap.add_argument("--llm", default="openai",
                    help="proposer backend; `stub` makes no API call at all, "
                         "which is enough for anything about harness "
                         "construction, compilation or the closure")
    ap.add_argument("--k", type=int, default=1,
                    help="candidate plans; the pipeline default is 4")
    ap.add_argument("--rounds", type=int, default=1,
                    help="repair rounds; the paper's budget is 3")
    ap.add_argument("--out", default="results/rq3_quick.csv",
                    help="each result is written here as it finishes, so a "
                         "stopped run resumes where it left off")
    ap.add_argument("--trace-root", default="results/trace",
                    help="keep every intermediate artifact of each contract "
                         "under <root>/<contract>/; empty string to switch off")
    ap.add_argument("--fresh", action="store_true",
                    help="ignore results already in --out and start over")
    ap.add_argument("--budget", type=int, default=150,
                    help="wall-clock seconds per contract")
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(os.path.join(HERE, args.verdicts)))
            if r["arm"] == "general" and r["outcome"] == "NV"
            and r["status"] not in ("NO_TARGET", "NOT_EXPRESSIBLE")
            and (r.get("target") or "").strip()]
    if args.contracts:
        want = set(args.contracts)
        rows = [r for r in rows if r["contract"] in want]
        missing = want - {r["contract"] for r in rows}
        if missing:
            print(f"not in the verdicts file: {sorted(missing)}")
    print(f"{len(rows)} general-arm contract(s) with a clean target and no "
          f"verdict; {args.workers} at a time, "
          f"{args.smt_timeout_ms // 1000}s per obligation, "
          f"slicing {args.slice}, {args.k} plan(s), {args.rounds} round(s), "
          f"proposer {args.llm}\n")

    # Results already on disk are kept and those contracts skipped, so a run
    # that was stopped picks up where it left off.
    out_path = os.path.join(HERE, args.out)
    fields = ["contract", "path", "stage", "detail"]
    done = {}
    if os.path.exists(out_path) and not args.fresh:
        for r in csv.DictReader(open(out_path)):
            done[r["path"]] = r
    todo = [r for r in rows if r["path"] not in done]
    if done:
        print(f"resuming: {len(done)} already recorded, {len(todo)} to run\n")
    new_file = args.fresh or not os.path.exists(out_path)
    fh = open(out_path, "w" if new_file else "a", newline="")
    writer = csv.DictWriter(fh, fieldnames=fields)
    if new_file:
        writer.writeheader()
        fh.flush()

    with cf.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = [ex.submit(run, r, args.smt_timeout_ms, args.budget,
                          args.slice, args.k, args.rounds, args.trace_root,
                          args.llm)
                for r in todo]
        for i, fut in enumerate(cf.as_completed(futs), 1):
            row, d, err, fail = fut.result()
            stage, detail = where(d or {}, err, fail)
            rec = {"contract": row["contract"], "path": row["path"],
                   "stage": stage, "detail": detail}
            writer.writerow(rec)
            fh.flush()
            os.fsync(fh.fileno())
            done[row["path"]] = rec
            print(f"[{i:2d}/{len(todo)}] {row['contract'][:28]:28s} {stage}")
    fh.close()

    tally = collections.Counter()
    details = collections.defaultdict(list)
    for rec in done.values():
        tally[rec["stage"]] += 1
        details[rec["stage"]].append((rec["contract"], rec["detail"]))

    print("\nwhere they stop:")
    for stage, n in tally.most_common():
        print(f"  {n:3d}  {stage}")
    for stage, items in details.items():
        print(f"\n{stage}:")
        seen = collections.Counter(d for _, d in items if d)
        for d, n in seen.most_common(6):
            print(f"  {n:2d}x  {d}")


if __name__ == "__main__":
    main()
