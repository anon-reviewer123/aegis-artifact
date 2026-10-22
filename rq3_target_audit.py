#!/usr/bin/env python3
"""Check each RQ3 target property on the original contract, with no LLM.

Two model-checker runs per contract, external calls untrusted:

  blocked   no function may be entered while another is running
  open      callbacks may re-enter (privileged functions excepted)

  blocked violated             the target fails without any callback: it is
                               not an invariant of the contract, so it cannot
                               measure reentrancy
  blocked holds, open violated a callback breaks the target
  both hold                    no callback breaks the target

The result is for review of the labels, not a replacement for them.

  python3 rq3_target_audit.py
  python3 rq3_target_audit.py --contracts VulnerableContract TRYPTO
"""
import argparse
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from aegis import backend, confirm, eth_model, static_analysis


def check(path, target, timeout_ms):
    src = open(path, errors="ignore").read()
    new_src, target, changed = eth_model.transform(src, target)
    work = path
    if changed:
        work = path.replace(".sol", ".ethmodel.sol")
        with open(work, "w") as fh:
            fh.write(new_src)
        src = new_src
    facts = static_analysis.analyze(work)
    privileged = set(getattr(facts, "privileged", {}) or {})
    out = {}
    for label, block_all in (("blocked", True), ("open", False)):
        inst = confirm.build(src, facts.contract, target, privileged, block_all)
        if inst is None:
            out[label] = "not_built"
            continue
        r = backend.check_obligation(f"AUDIT_{label}", "audit", inst,
                                     timeout_ms=timeout_ms, ext_calls="untrusted")
        out[label] = {"failed": "violated", "verified": "holds"}.get(r.status, "undecided")
    return target, out


def reading(b, o):
    if b == "violated":
        return "target not an invariant without callbacks"
    if b == "holds" and o == "violated":
        return "a callback breaks the target"
    if b == "holds" and o == "holds":
        return "no callback breaks the target"
    return "undecided"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--verdicts", default="results/rq3_verdicts_v3.csv")
    ap.add_argument("--names", default="results/rq3_final.csv")
    ap.add_argument("--contracts", nargs="*", default=None)
    ap.add_argument("--timeout-ms", type=int, default=120000)
    ap.add_argument("--out", default="results/rq3_target_audit.csv")
    args = ap.parse_args()

    want = {r["path"] for r in csv.DictReader(open(os.path.join(HERE, args.names)))}
    rows = [r for r in csv.DictReader(open(os.path.join(HERE, args.verdicts)))
            if r["path"] in want and r["arm"] == "general"
            and (r.get("target") or "").strip()]
    seen, todo = set(), []
    for r in rows:
        if r["path"] in seen:
            continue
        if args.contracts and r["contract"] not in args.contracts:
            continue
        seen.add(r["path"])
        todo.append(r)

    fields = ["contract", "path", "label", "target", "blocked", "open", "reading"]
    with open(os.path.join(HERE, args.out), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for r in todo:
            try:
                target, res = check(r["path"], r["target"], args.timeout_ms)
                b, o = res["blocked"], res["open"]
            except Exception as exc:
                target, b, o = r["target"], "error", str(exc)[:80]
            row = {"contract": r["contract"], "path": r["path"], "label": r["label"],
                   "target": target, "blocked": b, "open": o, "reading": reading(b, o)}
            w.writerow(row)
            fh.flush()
            print(f"{r['contract'][:24]:24s} {r['label']:7s} blocked={b:10s} "
                  f"open={o:10s} {row['reading']}", flush=True)
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
