#!/usr/bin/env python3
"""Show how far RQ3 has got, and the next command to run.

Every step leaves a file behind, so the state can be read off disk. Safe to run
at any time; it changes nothing.

  python3 rq3_status.py
"""
import collections
import csv
import json
import os
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
R = lambda p: os.path.join(HERE, p)


def ok(msg):
    print(f"  [done] {msg}")


def todo(msg):
    print(f"  [    ] {msg}")


def main():
    nxt = None
    print("RQ3 status\n")

    # 0. solc, which a reboot or another shell can change
    solc = shutil.which("solc")
    ver = ""
    if solc:
        try:
            ver = subprocess.run(["solc", "--version"], capture_output=True,
                                 text=True, timeout=20).stdout
        except Exception:
            pass
    good = "0.8." in ver
    print("  solc: " + (ver.strip().splitlines()[-1] if ver else "not found")
          + ("" if good else "   <-- WRONG, run: solc-select use 0.8.26"))
    if not good:
        nxt = nxt or "solc-select use 0.8.26"
    print()

    # 1. scripts
    for s in ("rq3_route.py", "rq3_sample.py", "rq3_bundle.py",
              "rq3_merge.py", "rq3_run.py", "rq3_table5.py"):
        (ok if os.path.exists(R(s)) else todo)(f"script {s}")
    print()

    # 2. routing and sample
    (ok if os.path.exists(R("results/rq3_routing.csv")) else todo)(
        "routing  results/rq3_routing.csv")
    (ok if os.path.exists(R("results/rq3_sample_key.csv")) else todo)(
        "sample   results/rq3_sample_key.csv")

    # 3. labels
    have_a = os.path.exists(R("results/rq3_labels_a_completed.csv"))
    have_b = os.path.exists(R("results/rq3_labels_b_filled.csv"))
    (ok if have_a else todo)("labels A results/rq3_labels_a_completed.csv")
    (ok if have_b else todo)("labels B results/rq3_labels_b_filled.csv")

    # 4. adjudication
    dpath = R("results/rq3_disagreements.csv")
    adjudicated = False
    if os.path.exists(dpath):
        drows = list(csv.DictReader(open(dpath)))
        filled = sum(1 for r in drows if (r.get("final") or "").strip())
        if drows and filled == len(drows):
            ok(f"adjudication: {filled}/{len(drows)} disagreements decided")
            adjudicated = True
        else:
            todo(f"adjudication: {filled}/{len(drows)} decided -- fill the "
                 f"`final` column in results/rq3_disagreements.csv")
            nxt = nxt or ("edit results/rq3_disagreements.csv, then\n"
                          "    python3 rq3_merge.py --adjudicated "
                          "results/rq3_disagreements.csv")
    else:
        todo("adjudication: results/rq3_disagreements.csv not written yet")
        nxt = nxt or "python3 rq3_merge.py"

    # 5. frozen labels, and whether they include the adjudication
    fpath = R("results/rq3_frozen_labels.json")
    frozen = {}
    if os.path.exists(fpath):
        frozen = json.load(open(fpath))
        arms = collections.Counter(v["arm"] for v in frozen.values())
        stale = (adjudicated and os.path.exists(dpath) and
                 os.path.getmtime(fpath) < os.path.getmtime(dpath))
        if stale:
            todo(f"frozen labels ({len(frozen)}) predate the adjudication -- "
                 f"re-merge")
            nxt = nxt or ("python3 rq3_merge.py --adjudicated "
                          "results/rq3_disagreements.csv")
        else:
            ok(f"frozen labels: {len(frozen)} "
               f"({', '.join(f'{a}={n}' for a, n in sorted(arms.items()))})")
    else:
        todo("frozen labels: results/rq3_frozen_labels.json")
    print()

    # 6. verdicts, per arm
    vpath = R("results/rq3_verdicts.csv")
    done = collections.Counter()
    dead = 0
    if os.path.exists(vpath):
        for r in csv.DictReader(open(vpath)):
            done[r["arm"]] += 1
            if r.get("backend") == "none":
                dead += 1
    want = collections.Counter(v["arm"] for v in frozen.values())
    for arm in ("loop", "read_only", "general"):
        n, w = done.get(arm, 0), want.get(arm, 0)
        if w and n >= w:
            ok(f"verdicts {arm:10s} {n}/{w}")
        else:
            todo(f"verdicts {arm:10s} {n}/{w}")
            if frozen and not nxt:
                llm = "openai" if arm == "general" else "stub"
                nxt = (f"python3 rq3_run.py --arm {arm} --llm {llm} "
                       f"--out results/rq3_verdicts.csv --append")
    if dead:
        print(f"\n  *** {dead} verdict row(s) ran with NO VERIFIER; delete "
              f"results/rq3_verdicts.csv rows for them, or the whole file, "
              f"and re-run ***")

    if frozen and not nxt and all(done.get(a, 0) >= want.get(a, 0)
                                  for a in want):
        nxt = "python3 rq3_table5.py"

    print("\nnext:")
    print("    " + (nxt or "nothing -- RQ3 is complete"))


if __name__ == "__main__":
    main()
