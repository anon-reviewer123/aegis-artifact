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
from aegis import harness_synth, backend

CLASSES = [
    ("pragma_mismatch", r"requires different compiler version"),
    ("import_unresolved", r'Source ".*" not found'),
    ("spdx_multiple", r"Multiple SPDX license"),
    ("inline_assembly", r"got 'assembly'"),
    ("data_location", r'Data location must be'),
    ("user_defined_type", r"Name has to refer to a user-defined type|"
                         r"Name has to refer to a struct, enum or contract"),
    ("nested_mapping_storage", r"Types in storage containing \(nested\) map"),
    ("undeclared_ident", r"Undeclared identifier"),
    ("already_declared", r"Identifier already declared"),
    ("type_conversion", r"not implicitly convertible|Explicit type conversion|"
                        r"Operator .* not compatible"),
    ("missing_type", r"Expected type name|Expected elementary type name"),
    ("member_not_found", r'Member ".*" not found'),
    ("wrong_args", r"No matching declaration|Different number of arguments|"
                   r"Wrong argument count"),
    ("visibility_kw", r"Expected ';' but got '(public|private|internal|"
                      r"external)'"),
    ("unbalanced_brace", r"Expected ';' but got '\}'|Expected '\}'"),
    ("paren_mismatch", r"Expected '\)' but got|Expected '\(' but got"),
    ("primary_expr", r"Expected primary expression"),
    ("ident_expected", r"Expected identifier but got"),
    ("comma_expected", r"Expected ',' but got"),
    ("comment_terminator", r"Expected multi-line comment-terminator"),
    ("decl_expected", r"declaration expected|Expected pragma, import"),
    ("not_callable", r"not callable"),
    ("override_needed", r"override|virtual|abstract"),
    ("stack_too_deep", r"[Ss]tack too deep"),
]


def classes_in(stderr):
    """Every distinct error class present, not just the first."""
    errs = []
    for block in re.split(r"\n(?=Error:)", stderr):
        if not block.startswith("Error:"):
            continue
        hit = None
        for name, pat in CLASSES:
            if re.search(pat, block):
                hit = name
                break
        if hit is None:
            m = re.match(r"Error: ([^\n]+)", block)
            hit = "other:" + (m.group(1)[:40] if m else "unknown")
        errs.append(hit)
    return errs


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
    ap.add_argument("--kind", default="readonly",
                    choices=["readonly", "loop"])
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--out", default="results/blocking_analysis.csv")
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(args.scan_csv))
            if r["kind"] == args.kind]
    if args.kind == "loop":
        rows = [r for r in rows if r["shape"] != "no_effect"]
    rows = dedup(rows)
    if args.limit:
        rows = rows[:args.limit]

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    recs = []
    stage = collections.Counter()
    present = collections.Counter()
    blockers = collections.Counter()
    errors_per = collections.Counter()

    for i, r in enumerate(rows):
        rec = {"contract": r["contract"], "file": r["file"],
               "stage": "", "n_errors": 0, "classes": ""}
        try:
            facts = analyze(r["file"])
            if not facts.exposure_sites:
                rec["stage"] = "no_exposure_site"
                stage["no_exposure_site"] += 1
                recs.append(rec)
                continue
            site = facts.exposure_sites[0]
            src = open(r["file"], errors="ignore").read()
            h = harness_synth.synthesize_harness(src, facts, site, "")
        except Exception as e:
            rec["stage"] = "synth_error"
            rec["classes"] = type(e).__name__
            stage["synth_error"] += 1
            recs.append(rec)
            continue

        fd, p = tempfile.mkstemp(suffix=".sol")
        os.close(fd)
        try:
            with open(p, "w") as fh:
                fh.write(h)
            solc = backend._resolve_solc_for(h)
            cp = subprocess.run([solc, "--bin", p], capture_output=True,
                                text=True, timeout=120)
            if cp.returncode == 0:
                rec["stage"] = "compiles"
                stage["compiles"] += 1
            else:
                cls = classes_in(cp.stderr)
                uniq = sorted(set(cls))
                rec["stage"] = "compile_error"
                rec["n_errors"] = len(cls)
                rec["classes"] = "|".join(uniq)
                stage["compile_error"] += 1
                errors_per[len(uniq)] += 1
                for c in uniq:
                    present[c] += 1
                if len(uniq) == 1:
                    blockers[uniq[0]] += 1
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
    print(f"\ncandidates                 {total}")
    for k, v in stage.most_common():
        print(f"  {k:24s} {v:5d}  ({100*v/total:.0f}%)")

    print("\ndistinct error classes per failing contract")
    for k in sorted(errors_per):
        print(f"  {k:2d} class(es)  {errors_per[k]:5d}")

    print("\nclass PRESENT in N contracts  |  SOLE blocker in N")
    keys = sorted(present, key=lambda c: -present[c])
    for c in keys[:22]:
        print(f"  {c:26s} {present[c]:5d}  |  {blockers.get(c,0):5d}")

    fixed = sum(blockers.values())
    print(f"\ncontracts unblocked by fixing exactly one class: {fixed}")
    print("cumulative gain by fixing classes in greedy order:")
    remaining = [set(r["classes"].split("|")) for r in recs
                 if r["stage"] == "compile_error" and r["classes"]]
    chosen, gained = [], 0
    for _ in range(8):
        best, bestn = None, 0
        for c in keys:
            if c in chosen:
                continue
            n = sum(1 for s in remaining if s <= set(chosen + [c]))
            if n > bestn:
                best, bestn = c, n
        if not best:
            break
        chosen.append(best)
        gained = bestn
        print(f"  + {best:26s} -> {gained:4d} contracts compile "
              f"({100*(gained+stage['compiles'])/total:.0f}% total)")
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
