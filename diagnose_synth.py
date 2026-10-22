import argparse
import collections
import csv
import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis.static_analysis import analyze
from aegis import harness_synth, backend as aegis_backend

ERROR_CLASSES = [
    ("pragma_mismatch", r"requires different compiler version"),
    ("inline_assembly", r"got 'assembly'"),
    ("data_location", r"Data location must be"),
    ("undeclared_ident", r"Undeclared identifier"),
    ("type_mismatch", r"not implicitly convertible|Type .* is not"),
    ("missing_type", r"Expected type name"),
    ("decl_expected", r"declaration expected"),
    ("unbalanced_brace", r"Expected ';' but got '\}'|Expected '\}'"),
    ("paren_mismatch", r"Expected '\)' but got|Expected '\(' but got"),
    ("primary_expr", r"Expected primary expression"),
    ("ident_expected", r"Expected identifier but got"),
    ("visibility", r"visibility|mutability"),
    ("override", r"override|virtual|abstract"),
]


def classify(stderr):
    for name, pat in ERROR_CLASSES:
        if re.search(pat, stderr):
            return name
    m = re.search(r"Error: ([^\n]+)", stderr)
    return "other:" + (m.group(1)[:40] if m else "unknown")


def first_error(stderr):
    for line in stderr.splitlines():
        if "Error" in line:
            return line.strip()[:160]
    return ""


def dedup(rows, key="hash"):
    seen, out = set(), []
    for r in rows:
        if r[key] in seen:
            continue
        seen.add(r[key])
        out.append(r)
    return out


def build_readonly(path):
    facts = analyze(path)
    if not facts.exposure_sites:
        return None, "no_exposure_site"
    site = facts.exposure_sites[0]
    src = open(path, errors="ignore").read()
    return harness_synth.synthesize_harness(src, facts, site, ""), None


def build_loop(path):
    facts = analyze(path)
    if not facts.loop_sites:
        return None, "no_loop_site"
    try:
        from aegis.loop_harness_synth import synth_loop_step
    except Exception:
        return None, "no_synthesizer"
    ob = synth_loop_step(facts.loop_sites[0], facts, backend=None, say=None)
    if ob is None:
        return None, "unsupported_shape"
    return ob.harness_source, None


def compile_check(source, solc):
    if solc == "auto":
        solc = aegis_backend._resolve_solc_for(source)
    fd, path = tempfile.mkstemp(suffix=".sol")
    os.close(fd)
    try:
        with open(path, "w") as fh:
            fh.write(source)
        cp = subprocess.run([solc, "--bin", path], capture_output=True,
                            text=True, timeout=120)
        return cp.returncode == 0, cp.stderr
    except subprocess.TimeoutExpired:
        return False, "Error: solc timeout"
    finally:
        os.unlink(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scan_csv")
    ap.add_argument("--kind", choices=["readonly", "loop"], required=True)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--solc", default="auto")
    ap.add_argument("--out", default="")
    ap.add_argument("--dump-dir", default="")
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(args.scan_csv))
            if r["kind"] == args.kind]
    if args.kind == "loop":
        rows = [r for r in rows if r["shape"] != "no_effect"]
    rows = dedup(rows)
    if args.limit:
        rows = rows[:args.limit]

    out_path = args.out or f"results/diag_{args.kind}.csv"
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    if args.dump_dir:
        os.makedirs(args.dump_dir, exist_ok=True)

    builder = build_readonly if args.kind == "readonly" else build_loop
    records = []
    stage = collections.Counter()
    errors = collections.Counter()

    for i, r in enumerate(rows):
        rec = {"contract": r["contract"], "function": r["function"],
               "file": r["file"], "stage": "", "error_class": "",
               "error": ""}
        try:
            src, reason = builder(r["file"])
        except Exception as e:
            rec["stage"] = "analyze_error"
            rec["error_class"] = type(e).__name__
            rec["error"] = str(e)[:160]
            stage["analyze_error"] += 1
            records.append(rec)
            continue
        if src is None:
            rec["stage"] = reason
            stage[reason] += 1
            records.append(rec)
            continue
        ok, stderr = compile_check(src, args.solc)
        if ok:
            rec["stage"] = "compiles"
            stage["compiles"] += 1
        else:
            rec["stage"] = "compile_error"
            rec["error_class"] = classify(stderr)
            rec["error"] = first_error(stderr)
            stage["compile_error"] += 1
            errors[rec["error_class"]] += 1
            if args.dump_dir:
                name = f"{r['contract']}_{i}.sol"
                with open(os.path.join(args.dump_dir, name), "w") as fh:
                    fh.write(src)
        records.append(rec)
        if (i + 1) % 25 == 0:
            print(f"  {i+1}/{len(rows)}  compiles={stage['compiles']}",
                  file=sys.stderr)

    with open(out_path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(records[0].keys()))
        w.writeheader()
        w.writerows(records)

    total = len(records)
    print(f"\ncandidates            {total}")
    for k, v in stage.most_common():
        print(f"  {k:20s} {v:5d}  ({100*v/total:.0f}%)")
    if errors:
        print("\ncompile error classes")
        cum = 0
        for k, v in errors.most_common():
            cum += v
            print(f"  {k:20s} {v:5d}  cumulative {cum}")
    print(f"\nwrote {out_path}")
    if args.dump_dir:
        print(f"failing harnesses in {args.dump_dir}/")


if __name__ == "__main__":
    main()
