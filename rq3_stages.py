#!/usr/bin/env python3
"""Write out every stage the general arm goes through, for named contracts.

Summaries say which stage failed; this keeps what each stage produced, so the
text transformations themselves can be read. Per contract, under
results/stages/<Contract>/:

  00_contract.sol     the source as it was given
  01_facts.txt        storage, types, exposure sites, closure
  02_harness.sol      the synthesized harness, and whether it compiles
  03_plan.json        the plan the proposer returned (one candidate)
  04_<OBL>.sol        each obligation as compiled, after slicing
  summary.txt         the first failing stage, with solc's error and the lines
                      around it

Obligations are compiled, not model-checked, so this is fast.

  python3 rq3_stages.py ReservaX BPYC GoodMorning
  python3 rq3_stages.py --all-failing
"""
import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ.setdefault("AEGIS_LLM_MODE", "offline")

GROUPS = {
    "compile": ["ReservaX", "BPYC", "GoodMorning", "NeoCypherpunk", "WAsgard",
                "Dao", "VulnerableContract", "AmenoToken"],
    "timeout": ["TraderSpirits", "DLAND", "TRYPTO", "WuZeTian"],
    "refuted": ["SHIBB", "KatRoyalties", "SafePaymentVault", "BULLRUNNERSCLUB"],
}


def compile_errors(source, tmpdir, tag):
    from aegis.backend import _resolve_solc_for
    path = os.path.join(tmpdir, tag + ".sol")
    with open(path, "w") as fh:
        fh.write(source)
    p = subprocess.run([_resolve_solc_for(source), "--bin", path],
                       capture_output=True, text=True, timeout=120)
    err = (p.stderr or "") + (p.stdout or "")
    if "Error" not in err:
        return []
    out = []
    lines = source.splitlines()
    for m in re.finditer(r"(\w*Error): ([^\n]+)\n\s*-->\s*[^:]+:(\d+):(\d+)", err):
        ln = int(m.group(3))
        ctx = "\n".join(f"      {'>>' if n == ln else '  '} {n:4d} | {lines[n-1]}"
                        for n in range(max(1, ln - 3), min(len(lines), ln + 3) + 1))
        out.append(f"    {m.group(1)}: {m.group(2)}  (line {ln})\n{ctx}")
    if not out:
        out.append("    " + err.strip()[:600])
    return out


def dump(row, root, tmpdir):
    from aegis import compiler, harness_synth, static_analysis, synth
    c = row["contract"]
    d = os.path.join(root, c)
    os.makedirs(d, exist_ok=True)
    summary = []

    src = open(row["path"], errors="ignore").read()
    shutil.copy(row["path"], os.path.join(d, "00_contract.sol"))

    # Apply the ETH-balance model exactly as the pipeline does, before any
    # analysis: without it a target over address(this).balance is compiled
    # against the obligation contract's own balance, and the dump shows a
    # failure the pipeline never has.
    from aegis import eth_model
    target = row["target"]
    path = row["path"]
    new_src, target, changed = eth_model.transform(src, target)
    if changed:
        path = os.path.join(d, "00_contract.ethmodel.sol")
        with open(path, "w") as fh:
            fh.write(new_src)
        src = new_src
        summary.append(f"eth-model: address(this).balance -> _ethBal; "
                       f"target now: {target}")
    row = dict(row, target=target)

    facts = static_analysis.analyze(path)
    site = facts.exposure_sites[0] if facts.exposure_sites else None
    with open(os.path.join(d, "01_facts.txt"), "w") as fh:
        fh.write(f"analyzer : {static_analysis.LAST_ANALYZER}\n")
        fh.write(f"target   : {row['target']}\n\n")
        for v in facts.storage_vars:
            fh.write(f"  {v:32s} {facts.var_types.get(v, '?')}\n")
        fh.write("\nsites:\n")
        for s in facts.exposure_sites:
            fh.write(f"  {s.function}{s.call}#{getattr(s, 'index', 0)} "
                     f"before={sorted(s.write_before_call)} "
                     f"after={sorted(s.write_after_call)}\n")
        if site:
            fh.write(f"\nclosure : {sorted(facts.conservative_closure(site))}\n")
    if site is None:
        summary.append("stops at: static analysis (no exposure site)")
        return c, summary

    harness = harness_synth.synthesize_harness(src, facts, site, row["target"])
    with open(os.path.join(d, "02_harness.sol"), "w") as fh:
        fh.write(harness)
    herr = compile_errors(harness, tmpdir, c + "_harness")
    summary.append(f"harness  : {'compiles' if not herr else 'DOES NOT COMPILE'}"
                   f"  ({len(harness.splitlines())} lines)")
    summary += herr[:3]

    try:
        plan = synth.sample_plans(facts, site, row["target"],
                                  backend="openai", k=1)[0]
    except Exception as exc:
        summary.append(f"plan     : proposer failed ({exc})")
        return c, summary
    try:
        import dataclasses
        pj = (dataclasses.asdict(plan) if dataclasses.is_dataclass(plan)
              else plan.__dict__)
        with open(os.path.join(d, "03_plan.json"), "w") as fh:
            json.dump(pj, fh, indent=1, default=str)
    except Exception:
        pass
    summary.append(f"Iexp     : {plan.exposure_invariant.formula}")

    compiler.SLICE = True
    try:
        obs = compiler.compile_obligations(plan, facts, harness)
    except Exception as exc:
        summary.append(f"obligations: compile_obligations raised {exc}")
        return c, summary
    for o in obs:
        with open(os.path.join(d, f"04_{o.name}.sol"), "w") as fh:
            fh.write(o.harness_source)
        errs = compile_errors(o.harness_source, tmpdir, c + "_" + o.name)
        state = "compiles" if not errs else "DOES NOT COMPILE"
        summary.append(f"{o.name:28s}: {state}  "
                       f"({len(o.harness_source.splitlines())} lines)")
        summary += errs[:2]
    return c, summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("contracts", nargs="*")
    ap.add_argument("--group", choices=sorted(GROUPS))
    ap.add_argument("--all-failing", action="store_true")
    ap.add_argument("--verdicts", default="results/rq3_verdicts_v3.csv")
    ap.add_argument("--out", default="results/stages")
    args = ap.parse_args()

    want = list(args.contracts)
    if args.group:
        want += GROUPS[args.group]
    if args.all_failing:
        want += [c for g in GROUPS.values() for c in g]
    if not want:
        ap.error("name contracts, or use --group / --all-failing")

    rows, seen = [], set()
    for r in csv.DictReader(open(os.path.join(HERE, args.verdicts))):
        if r["contract"] in want and r["arm"] == "general" \
                and r["contract"] not in seen and (r.get("target") or "").strip():
            rows.append(r)
            seen.add(r["contract"])

    import tempfile
    tmpdir = tempfile.mkdtemp(prefix="rq3_stages_")
    root = os.path.join(HERE, args.out)
    os.makedirs(root, exist_ok=True)
    with open(os.path.join(root, "summary.txt"), "w") as all_fh:
        for r in rows:
            print(f"  {r['contract']}")
            try:
                c, summary = dump(r, root, tmpdir)
            except Exception as exc:
                c, summary = r["contract"], [f"crashed: {exc}"]
            block = f"\n{'=' * 70}\n{c}\n" + "\n".join(summary) + "\n"
            all_fh.write(block)
            with open(os.path.join(root, c, "summary.txt"), "w") as fh:
                fh.write(block)
    print(f"\nwrote {args.out}/  (summary.txt, plus one folder per contract)")
    print(f"zip it:  cd results && zip -rq ~/Downloads/stages.zip stages")


if __name__ == "__main__":
    main()
