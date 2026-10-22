import argparse
import collections
import csv
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis.inplace_probe import build_probe
from aegis import backend

ERROR_CLASSES = [
    ("pragma_mismatch", r"requires different compiler version"),
    ("abstract_target", r"abstract|not implemented"),
    ("no_receive", r"receive|fallback"),
    ("ctor_args", r"[Ww]rong argument count|No arguments passed"),
    ("not_payable", r"not payable|Cannot set option \"value\""),
    ("conversion", r"not implicitly convertible|Explicit type conversion"),
    ("undeclared", r"Undeclared identifier"),
    ("visibility", r"not visible|not found or not visible"),
    ("interface_only", r"Interface|Library"),
    ("stack_too_deep", r"[Ss]tack too deep"),
    ("parse", r"Expected|Expected primary"),
]


def classify(stderr):
    for name, pat in ERROR_CLASSES:
        if re.search(pat, stderr):
            return name
    m = re.search(r"Error: ([^\n]+)", stderr)
    return "other:" + (m.group(1)[:44] if m else "unknown")


def dedup(rows):
    seen, out = set(), []
    for r in rows:
        if r["hash"] in seen:
            continue
        seen.add(r["hash"])
        out.append(r)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scan_csv")
    ap.add_argument("--out", default="results/probe_feasibility.csv")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dump-dir", default="")
    args = ap.parse_args()

    rows = dedup([r for r in csv.DictReader(open(args.scan_csv))
                  if r["kind"] == "readonly"])
    if args.limit:
        rows = rows[:args.limit]

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    if args.dump_dir:
        os.makedirs(args.dump_dir, exist_ok=True)

    recs = []
    stage = collections.Counter()
    errs = collections.Counter()

    for i, r in enumerate(rows):
        rec = {"contract": r["contract"], "exposure": r.get("call", ""),
               "view": r["function"], "file": r["file"],
               "stage": "", "error_class": "", "error": ""}
        try:
            src = open(r["file"], errors="ignore").read()
        except Exception as e:
            rec["stage"] = "read_error"
            rec["error"] = str(e)[:100]
            stage["read_error"] += 1
            recs.append(rec)
            continue

        out, why = build_probe(src, r["contract"], r.get("call", ""),
                               r["function"])
        if out is None:
            rec["stage"] = "not_drivable"
            rec["error"] = why
            stage["not_drivable"] += 1
            errs["undrivable:" + why] += 1
            recs.append(rec)
            continue

        fd, p = tempfile.mkstemp(suffix=".sol")
        os.close(fd)
        try:
            with open(p, "w") as fh:
                fh.write(out)
            solc = backend._resolve_solc_for(out)
            cp = subprocess.run([solc, "--bin", p], capture_output=True,
                                text=True, timeout=120)
            if cp.returncode == 0:
                rec["stage"] = "compiles"
                stage["compiles"] += 1
            else:
                rec["stage"] = "compile_error"
                rec["error_class"] = classify(cp.stderr)
                first = [l for l in cp.stderr.splitlines() if "Error" in l]
                rec["error"] = (first[0] if first else "")[:150]
                stage["compile_error"] += 1
                errs[rec["error_class"]] += 1
                if args.dump_dir:
                    with open(os.path.join(args.dump_dir,
                                           f"{r['contract']}_{i}.sol"), "w") as fh:
                        fh.write(out)
        except subprocess.TimeoutExpired:
            rec["stage"] = "timeout"
            stage["timeout"] += 1
        except FileNotFoundError:
            rec["stage"] = "no_solc"
            stage["no_solc"] += 1
        finally:
            os.unlink(p)

        recs.append(rec)
        if (i + 1) % 25 == 0:
            print(f"  {i+1}/{len(rows)}  compiles={stage['compiles']}",
                  file=sys.stderr)

    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(recs[0].keys()))
        w.writeheader()
        w.writerows(recs)

    total = len(recs)
    print(f"\ncandidates            {total}")
    for k, v in stage.most_common():
        print(f"  {k:20s} {v:5d}  ({100*v/total:.0f}%)")
    if errs:
        print("\nfailure classes")
        for k, v in errs.most_common(15):
            print(f"  {k:34s} {v:5d}")
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
