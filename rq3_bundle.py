#!/usr/bin/env python3
"""Bundle the sampled contracts with their labelling sheet.

Makes one self-contained packet per annotator: the sheet, the contract sources
it refers to, and a short brief. The packet carries no tool output and no arm
assignment, so it can be handed to a second annotator as it stands.

  python3 rq3_bundle.py
  python3 rq3_bundle.py --sheet results/rq3_labels_b.csv --out rq3_packet_b

Each contract is copied under sources/ with a name matching the `file` column
in the sheet, so a label can always be traced back to what was read.
"""
import argparse
import csv
import os
import shutil
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))

BRIEF = """RQ3 labelling brief
===================

You are deciding, for each contract, whether an external call it makes can be
exploited by the code it hands control to.

Fill in three columns of the sheet. Do the middle one first.

  target   The relation this contract is meant to maintain, written in its own
           variable names. For example `totalDeposits == backing`, or
           `sumOfShares == totalSupply`. This is the property the contract
           would be verified against. If you cannot state one, write `none`.

  label    safe | unsafe | unclear
             unsafe  - some sequence of re-entrant calls, made while an
                       external call from this contract is still running, can
                       leave `target` false at the end of the transaction
             safe    - no such sequence exists
             unclear - you cannot tell from the source

  why      One line. What makes it safe, or the path that breaks it.

Use `unclear` whenever you mean it. A forced guess on ambiguous flattened code
is worse than an honest abstention, and how many are set aside is itself a
result worth reporting.

Two things to keep in mind:

  * Do not run any tool on these contracts, and do not discuss them with the
    other annotator until both sheets are finished. The agreement between the
    two sheets is being measured, and it is only meaningful if the two were
    made independently.

  * Label what the contract does, not what you expect a verifier to conclude.
    A contract can be unsafe in a way no tool would catch, and that case is
    exactly what these labels exist to find.

Sources for every contract in the sheet are under sources/. The `file` column
gives the file name; `site_function` and `site_call` point at the external call
that opens the window, as a starting place rather than the only thing to read.
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", default="results/rq3_labels_a.csv")
    ap.add_argument("--out", default="")
    ap.add_argument("--zip", dest="make_zip", action="store_true", default=True)
    args = ap.parse_args()

    sheet_path = os.path.join(HERE, args.sheet)
    rows = list(csv.DictReader(open(sheet_path)))
    if not rows:
        print(f"{args.sheet} is empty")
        return

    tag = os.path.basename(args.sheet).replace("rq3_labels_", "").replace(".csv", "")
    outdir = os.path.join(HERE, args.out or f"rq3_packet_{tag}")
    srcdir = os.path.join(outdir, "sources")
    shutil.rmtree(outdir, ignore_errors=True)
    os.makedirs(srcdir, exist_ok=True)

    copied, missing = 0, []
    out_rows = []
    for i, r in enumerate(rows, 1):
        src = r["path"]
        if not os.path.isabs(src):
            src = os.path.join(HERE, src)
        # a flat, collision-free name: mainnet reuses contract names
        fname = f"{i:03d}_{r['contract']}.sol"
        if os.path.exists(src):
            shutil.copy(src, os.path.join(srcdir, fname))
            copied += 1
        else:
            missing.append(r["contract"])
            fname = ""
        out = dict(r)
        out["file"] = fname
        out_rows.append(out)

    fields = ["contract", "file", "site_function", "site_call",
              "label", "target", "why"]
    with open(os.path.join(outdir, os.path.basename(args.sheet)),
              "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for r in out_rows:
            w.writerow({k: r.get(k, "") for k in fields})

    with open(os.path.join(outdir, "BRIEF.txt"), "w") as fh:
        fh.write(BRIEF)

    print(f"packet {os.path.relpath(outdir, HERE)}/")
    print(f"  {copied} source file(s) under sources/")
    print(f"  sheet: {os.path.basename(args.sheet)}  ({len(rows)} row(s))")
    if missing:
        print(f"  *** {len(missing)} source(s) not found: "
              f"{', '.join(missing[:5])}"
              + (" ..." if len(missing) > 5 else "") + " ***")

    if args.make_zip:
        zpath = outdir + ".zip"
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
            for dp, _dirs, files in os.walk(outdir):
                for f in files:
                    full = os.path.join(dp, f)
                    z.write(full, os.path.relpath(full, os.path.dirname(outdir)))
        mb = os.path.getsize(zpath) / 1e6
        print(f"  zipped: {os.path.relpath(zpath, HERE)}  ({mb:.1f} MB)")


if __name__ == "__main__":
    main()
