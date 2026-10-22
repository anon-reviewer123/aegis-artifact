import argparse
import collections
import csv
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis.slice_harness import build_slice_harness
from aegis import backend

CLASSES = [
    ("undeclared_ident", r"Undeclared identifier"),
    ("type_conversion", r"not implicitly convertible|Operator .* not compat|"
                        r"Explicit type conversion"),
    ("member_not_found", r'Member ".*" not found'),
    ("data_location", r"Data location must be"),
    ("already_declared", r"Identifier already declared"),
    ("wrong_args", r"No matching declaration|Different number of arg"),
    ("parse", r"Expected"),
    ("visibility", r"not visible|not callable"),
    ("nested_mapping", r"Types in storage containing \(nested\) map"),
]


def classes_in(stderr):
    out = []
    for blk in re.split(r"\n(?=Error:)", stderr):
        if not blk.startswith("Error:"):
            continue
        hit = None
        for n, p in CLASSES:
            if re.search(p, blk):
                hit = n
                break
        if hit is None:
            m = re.match(r"Error: ([^\n]+)", blk)
            hit = "other:" + (m.group(1)[:40] if m else "?")
        out.append(hit)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scan_csv")
    ap.add_argument("--out", default="results/slice_readonly.csv")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dump-dir", default="")
    args = ap.parse_args()

    seen, rows = set(), []
    for r in csv.DictReader(open(args.scan_csv)):
        if r["kind"] != "readonly" or r["hash"] in seen:
            continue
        seen.add(r["hash"])
        rows.append(r)
    if args.limit:
        rows = rows[:args.limit]

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    if args.dump_dir:
        os.makedirs(args.dump_dir, exist_ok=True)

    recs, stage, errs, why = [], collections.Counter(), collections.Counter(), \
        collections.Counter()

    for i, r in enumerate(rows):
        rec = {"contract": r["contract"], "exposure": r.get("call", ""),
               "view": r["function"], "file": r["file"],
               "stage": "", "classes": "", "error": ""}
        try:
            src = open(r["file"], errors="ignore").read()
            out, reason = build_slice_harness(src, r["contract"],
                                              r.get("call", ""), r["function"])
        except Exception as e:
            rec["stage"] = "slice_error"
            rec["error"] = "%s: %s" % (type(e).__name__, e)
            stage["slice_error"] += 1
            recs.append(rec)
            continue
        if out is None:
            rec["stage"] = "not_sliceable"
            rec["error"] = reason
            stage["not_sliceable"] += 1
            why[reason] += 1
            recs.append(rec)
            continue

        fd, p = tempfile.mkstemp(suffix=".sol")
        os.close(fd)
        try:
            with open(p, "w") as fh:
                fh.write(out)
            cp = subprocess.run([backend._resolve_solc_for(out), "--bin", p],
                                capture_output=True, text=True, timeout=90)
            if cp.returncode == 0:
                rec["stage"] = "compiles"
                stage["compiles"] += 1
            else:
                cl = sorted(set(classes_in(cp.stderr)))
                rec["stage"] = "compile_error"
                rec["classes"] = "|".join(cl)
                first = [l for l in cp.stderr.splitlines() if "Error" in l]
                rec["error"] = (first[0] if first else "")[:140]
                stage["compile_error"] += 1
                for c in cl:
                    errs[c] += 1
                if args.dump_dir:
                    with open(os.path.join(args.dump_dir,
                                           "%s_%d.sol" % (r["contract"], i)),
                              "w") as fh:
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
            print("  %d/%d  compiles=%d" % (i + 1, len(rows),
                                            stage["compiles"]),
                  file=sys.stderr)

    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(recs[0].keys()))
        w.writeheader()
        w.writerows(recs)

    total = len(recs)
    print("\ncandidates            %d" % total)
    for k, v in stage.most_common():
        print("  %-20s %5d  (%.0f%%)" % (k, v, 100.0 * v / total))
    if why:
        print("\nnot sliceable, by reason")
        for k, v in why.most_common(10):
            print("  %-44s %4d" % (k, v))
    if errs:
        print("\ncompile error classes")
        for k, v in errs.most_common(14):
            print("  %-30s %5d" % (k, v))
    print("\nwrote %s" % args.out)


if __name__ == "__main__":
    main()
