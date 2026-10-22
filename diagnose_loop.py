#!/usr/bin/env python3
"""Show why the loop arm reached the verdict it did on one contract.

Walks the same path the pipeline takes -- loop-site detection, shape
classification, step-obligation construction, canary -- and prints what each
stage produced, so an UNKNOWN can be attributed to a missing loop site, an
unrecognised shape, a construction failure, or an undecided solver query.

  python3 diagnose_loop.py contracts/corpus/ForcedRevertGriefing_S01.sol
  python3 diagnose_loop.py contracts/corpus/ForcedRevertGriefing_*.sol --brief
  python3 diagnose_loop.py <contract> --dump-harness
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis import backend as backend_mod
from aegis import static_analysis


def report(path, brief=False, dump=False, run_solver=False, timeout_ms=120000):
    facts = static_analysis.analyze(path)
    src = open(path).read()
    name = os.path.basename(path)

    try:
        from loop_step_build import build_loop_step, classify_loop_shape
        from loop_step_build import extract_loop_context
    except Exception as exc:
        print(f"{name}: loop_step_build unavailable ({exc})")
        return

    if not facts.loop_sites:
        print(f"{name}: NO LOOP SITE detected -- the loop arm never runs, so "
              f"the contract falls to the general arm")
        return

    if brief:
        shapes = []
        for s in facts.loop_sites:
            k = classify_loop_shape(src, facts, s)
            built = build_loop_step(src, facts, s) is not None
            shapes.append(f"{s.function}:{k or 'UNRECOGNISED'}"
                          f"{'' if built else '/no-obligation'}")
        print(f"{name:38s} loop sites={len(facts.loop_sites)}  "
              f"{', '.join(shapes)}")
        return

    print(f"\n=== {name}   (analyzer: {static_analysis.LAST_ANALYZER})")
    print(f"    storage   : {facts.storage_vars}")
    print(f"    var types : {facts.var_types}")
    for s in facts.loop_sites:
        print(f"\n    loop site: {s.function} -> {s.call}")
        print(f"      body writes        : {s.loop_body_writes}")
        print(f"      body reads         : {s.loop_body_reads}")
        print(f"      writes before call : {s.writes_before_call}")
        print(f"      writes after call  : {s.writes_after_call}")
        print(f"      propagates failure : {s.propagates_failure}")

        ctx = extract_loop_context(src, s.function, s.call)
        if ctx is None:
            print("      loop context     : NOT EXTRACTED -- the body could "
                  "not be recovered, so no obligation is built")
            continue
        for k in ("pre", "post"):
            snippet = " ".join((ctx.get(k) or "").split())[:160]
            print(f"      ctx[{k}]{'':<10s}: {snippet}")

        kind = classify_loop_shape(src, facts, s)
        print(f"      shape            : {kind or 'UNRECOGNISED (no builder; '
                                                 'site reported unsupported)'}")
        if kind is None:
            continue

        ob = build_loop_step(src, facts, s)
        if ob is None:
            print("      obligation       : NOT BUILT")
            continue
        print(f"      obligation       : built "
              f"({len(ob.harness_source)} chars), canary "
              f"{'present' if getattr(ob, 'canary_source', None) else 'MISSING'}")
        if dump:
            print("\n--- step obligation ---")
            print(ob.harness_source)
            if getattr(ob, "canary_source", None):
                print("\n--- canary ---")
                print(ob.canary_source)
        if run_solver:
            b = backend_mod.get_backend()
            for label, source in (("step", ob.harness_source),
                                  ("canary", getattr(ob, "canary_source", ""))):
                if not source:
                    continue
                res = b.check(source, timeout_ms=timeout_ms)
                print(f"      {label:8s} -> {getattr(res, 'status', '?'):9s} "
                      f"{(getattr(res, 'detail', '') or '')[:100]}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("contracts", nargs="+")
    ap.add_argument("--brief", action="store_true")
    ap.add_argument("--dump-harness", action="store_true")
    ap.add_argument("--solve", action="store_true",
                    help="discharge the step and canary and print each status")
    ap.add_argument("--smt-timeout-ms", type=int, default=120000)
    args = ap.parse_args()
    for c in args.contracts:
        if ".harness." in c or ".ethmodel." in c:
            continue
        try:
            report(c, args.brief, args.dump_harness, args.solve,
                   args.smt_timeout_ms)
        except Exception as exc:
            print(f"{os.path.basename(c)}: failed: {exc}")


if __name__ == "__main__":
    main()
