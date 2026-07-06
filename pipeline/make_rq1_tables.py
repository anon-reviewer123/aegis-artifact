#!/usr/bin/env python3
"""
make_rq1_tables.py  --  build RQ1 Table 1 (main comparison) and Table 2
(per-class breakdown) as drop-in LaTeX, from the shared-schema tool JSONs.

Inputs (any subset; missing tools are simply omitted from the table):
  results/aegis_rq1.json              (collect_aegis.py)
  results/baseline_smtchecker.json    (baseline_smtchecker.py)
  results/baseline_slither.json       (baseline_detectors.py --tool slither)
  results/baseline_mythril.json       (baseline_detectors.py --tool mythril)
  benchmark.json                      (labels: class + ground-truth verdict)

Table 1 columns (verifier rows): Verified | Bug-found(correct) | Spurious |
  Unknown/Timeout | Localized.   Detection rows instead report flags-reentry
  (Y count) and Localized (always 0).

Table 2: rows = 6 taxonomy classes; columns = per-tool "#correct / #class".

Usage:
  python3 make_rq1_tables.py --labels benchmark.json --out-dir results
"""
from __future__ import annotations
import os, json, argparse, collections

# canonical class order = the paper's taxonomy (§1)
CLASS_ORDER = [
    ("classic_reentrancy",     "Classic reentrancy"),
    ("cross_function_desync",  "Cross-function desync"),
    ("read_only_reentrancy",   "Read-only reentrancy"),
    ("token_hook_accounting",  "Token-hook accounting"),
    ("flash_loan_callback",    "Flash-loan callback"),
    ("griefing_liveness",      "Griefing / liveness"),
]
CLASS_LABEL = dict(CLASS_ORDER)

# tool display order + which are "verifiers" vs "detectors"
TOOL_ORDER = ["slither", "mythril", "smtchecker-direct", "aegis"]
TOOL_LABEL = {
    "slither": "Slither", "mythril": "Mythril",
    "smtchecker-direct": "SMTChecker-direct", "aegis": "\\textsc{Aegis}",
}
DETECTORS = {"slither", "mythril"}


def load(path):
    return json.load(open(path)) if os.path.exists(path) else []


def correct_verdict(rec, expected):
    """Is this tool's verdict correct vs ground truth?"""
    v = rec.get("verdict")
    if rec["tool"] in DETECTORS:
        # detectors: "correct" = flagged reentrancy on a buggy contract and
        # stayed quiet on a safe one. This is generous to them on purpose.
        f = rec.get("flags_reentrancy")
        if f is None:
            return False
        return (f and expected == "BUG_FOUND") or ((not f) and expected == "VERIFIED")
    return v == expected


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", default="benchmark.json")
    ap.add_argument("--results-dir", default="results")
    ap.add_argument("--out-dir", default="results")
    args = ap.parse_args()

    labels = json.load(open(args.labels))
    rd = args.results_dir
    byttool = {
        "aegis": load(os.path.join(rd, "aegis_rq1.json")),
        "smtchecker-direct": load(os.path.join(rd, "baseline_smtchecker.json")),
        "slither": load(os.path.join(rd, "baseline_slither.json")),
        "mythril": load(os.path.join(rd, "baseline_mythril.json")),
    }
    # index by contract
    idx = {t: {r["contract"]: r for r in recs} for t, recs in byttool.items()}
    present = [t for t in TOOL_ORDER if byttool.get(t)]

    # ---------- Table 1: main comparison (summed over benchmark) ----------
    # verifier columns
    counts = {t: collections.Counter() for t in present}
    for b, meta in labels.items():
        expected = meta["verdict"]
        for t in present:
            r = idx[t].get(b)
            if not r:
                counts[t]["missing"] += 1
                continue
            if t in DETECTORS:
                f = r.get("flags_reentrancy")
                if f:
                    counts[t]["flagged"] += 1
                counts[t]["total"] += 1
                continue
            v = r.get("verdict")
            counts[t]["total"] += 1
            if v == "VERIFIED":
                counts[t]["verified"] += 1
                if expected == "VERIFIED":
                    counts[t]["verified_correct"] += 1
            elif v == "BUG_FOUND":
                counts[t]["bug"] += 1
                if expected == "BUG_FOUND":
                    counts[t]["bug_correct"] += 1
            elif v == "SPURIOUS":
                counts[t]["spurious"] += 1
            else:
                counts[t]["unknown"] += 1
            if r.get("localized"):
                counts[t]["localized"] += 1

    N = len(labels)
    lines = []
    lines.append("% ===== Table 1: RQ1 main comparison =====")
    lines.append("\\begin{table}[t]\\centering")
    lines.append("\\caption{RQ1 main comparison on the callback benchmark "
                 f"($N={N}$ contracts). Verified/Bug-found counts are "
                 "ground-truth-correct. \\emph{Localized} = pointed to the "
                 "violated obligation / re-entrant entry point. Detectors take "
                 "no target property (no verdict).}")
    lines.append("\\label{tab:rq1-main}")
    lines.append("\\begin{tabular}{l rrrrr}")
    lines.append("\\toprule")
    lines.append("Tool & Verified & Bug-found & Spurious & Unknown & "
                 "Localized \\\\")
    lines.append("\\midrule")
    for t in present:
        c = counts[t]
        if t in DETECTORS:
            # detectors: show flags-reentry as a note, dashes elsewhere
            lines.append(f"{TOOL_LABEL[t]} & \\multicolumn{{4}}{{c}}{{"
                         f"flags re-entry: {c['flagged']}/{c['total']} "
                         f"(no property verdict)}} & 0 \\\\")
        else:
            lines.append(
                f"{TOOL_LABEL[t]} & {c['verified_correct']} & "
                f"{c['bug_correct']} & {c['spurious']} & {c['unknown']} & "
                f"{c['localized']} \\\\")
    lines.append("\\bottomrule")
    lines.append("\\end{tabular}")
    lines.append("\\end{table}")
    table1 = "\n".join(lines)

    # ---------- Table 2: per-class breakdown (#correct / #class) ----------
    # class -> list of contracts
    class_contracts = collections.defaultdict(list)
    for b, meta in labels.items():
        class_contracts[meta.get("class", "?")].append(b)

    lines = []
    lines.append("% ===== Table 2: RQ1 per-class breakdown =====")
    lines.append("\\begin{table}[t]\\centering")
    lines.append("\\caption{RQ1 per-class breakdown: contracts handled "
                 "correctly per taxonomy class ($\\#$correct\\,/\\,$\\#$class). "
                 "Operationalizes the callback-safety-as-a-family thesis.}")
    lines.append("\\label{tab:rq1-perclass}")
    col = "l" + "c" * len(present)
    lines.append(f"\\begin{{tabular}}{{{col}}}")
    lines.append("\\toprule")
    header = "Class & " + " & ".join(TOOL_LABEL[t] for t in present) + " \\\\"
    lines.append(header)
    lines.append("\\midrule")
    for key, label in CLASS_ORDER:
        contracts = class_contracts.get(key, [])
        if not contracts:
            continue
        cells = []
        for t in present:
            n_ok = 0
            for b in contracts:
                r = idx[t].get(b)
                if r and correct_verdict(r, labels[b]["verdict"]):
                    n_ok += 1
            cells.append(f"{n_ok}/{len(contracts)}")
        lines.append(f"{label} & " + " & ".join(cells) + " \\\\")
    # totals row
    tot_cells = []
    for t in present:
        n_ok = sum(1 for b, meta in labels.items()
                   if idx[t].get(b) and correct_verdict(idx[t][b], meta["verdict"]))
        tot_cells.append(f"\\textbf{{{n_ok}/{N}}}")
    lines.append("\\midrule")
    lines.append("\\textbf{Total} & " + " & ".join(tot_cells) + " \\\\")
    lines.append("\\bottomrule")
    lines.append("\\end{tabular}")
    lines.append("\\end{table}")
    table2 = "\n".join(lines)

    os.makedirs(args.out_dir, exist_ok=True)
    open(os.path.join(args.out_dir, "table1_main.tex"), "w").write(table1 + "\n")
    open(os.path.join(args.out_dir, "table2_perclass.tex"), "w").write(table2 + "\n")

    print(table1)
    print()
    print(table2)
    print(f"\n[wrote {args.out_dir}/table1_main.tex and table2_perclass.tex]")


if __name__ == "__main__":
    main()
