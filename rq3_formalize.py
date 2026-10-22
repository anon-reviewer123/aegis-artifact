#!/usr/bin/env python3
"""Translate the annotators' target relations into the tool's property language.

The targets were written in ordinary notation -- `sum(_balances) ==
_totalSupply`, `totalSupply() <= maxSupply` -- which is the right way to ask an
annotator. The general arm's property language instead names a mapping sum
`_sum__balances` and speaks of storage variables, not function calls, so fed
unchanged, every such target was rejected by the validator as naming unknown
identifiers before any plan could be checked.

Translation here is mechanical and fixed in advance, never informed by a
verdict:

  sum(m)          ->  _sum_m          m a single-level mapping in storage
  f()             ->  v               f a view whose body is `return v;`
  f(x)            ->  m[x]            f a view whose body is `return m[p];`,
                                      p its one parameter

A target that still names something the contract does not store -- a local, a
parameter, a sum over an array of structs -- is not a storage invariant, so it
is recorded as not expressible rather than run.

  python3 rq3_formalize.py
  python3 rq3_formalize.py --out results/rq3_formal_targets.csv

Then run the general arm with:  python3 rq3_run.py --arm general --formal \\
    results/rq3_formal_targets.csv ...
"""
import argparse
import csv
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# identifiers the property language accepts without them being storage
BUILTINS = {"address", "this", "balance", "true", "false", "uint256", "uint",
            "int256", "int", "type", "max", "min"}


def getters(src, facts):
    """Views whose whole body returns one storage expression."""
    from aegis.harness_synth import _extract_function_body
    storage = set(facts.storage_vars)
    zero, one = {}, {}
    for name, info in facts.functions.items():
        if info.mutability not in ("view", "pure"):
            continue
        body = _extract_function_body(src, name)
        if body is None:
            continue
        b = " ".join(body.split())
        m = re.fullmatch(r"return\s+([A-Za-z_]\w*)\s*;", b)
        if m and m.group(1) in storage and not info.param_types:
            zero[name] = m.group(1)
            continue
        m = re.fullmatch(r"return\s+([A-Za-z_]\w*)\s*\[\s*([A-Za-z_]\w*)\s*\]\s*;", b)
        if m and m.group(1) in storage and len(info.param_types) == 1:
            one[name] = m.group(1)
    return zero, one


def formalize(target, facts, src):
    """(formal target, status, note). status: auto | not_expressible."""
    t = target.strip()
    storage = set(facts.storage_vars)
    maps = {v for v in storage
            if (facts.var_types.get(v, "") or "").startswith("mapping")}
    # Without a type map (the regex fallback) read mappings off the source.
    for m in re.finditer(r"\bmapping\s*\([^;]*?\)\s*(?:public\s+|private\s+|"
                         r"internal\s+)*([A-Za-z_]\w*)\s*;", src):
        if m.group(1) in storage:
            maps.add(m.group(1))

    def sum_repl(m):
        inner = m.group(1).strip()
        if inner in maps:
            return f"_sum_{inner}"
        raise ValueError(f"sum over `{inner}`, which is not a mapping in storage")

    try:
        t = re.sub(r"\bsum\s*\(\s*([^()]*?)\s*\)", sum_repl, t)
    except ValueError as exc:
        return "", "not_expressible", str(exc)

    zero, one = getters(src, facts)
    for name, var in zero.items():
        t = re.sub(rf"\b{re.escape(name)}\s*\(\s*\)", var, t)
    for name, mp in one.items():
        t = re.sub(rf"\b{re.escape(name)}\s*\(\s*([^()]*(?:\([^()]*\))?[^()]*)\s*\)",
                   lambda m, mp=mp: f"{mp}[{m.group(1).strip()}]", t)

    # any call other than an address(...) cast is outside the language
    calls = [c for c in re.findall(r"\b([A-Za-z_]\w*)\s*\(", t)
             if c not in ("address", "uint256", "uint", "int256", "int")]
    if calls:
        return "", "not_expressible", f"calls {sorted(set(calls))}"

    # A translation that collapses to a tautology proves nothing: substituting
    # a getter whose body is `return demons;` turns `totalSupply() == demons`
    # into `demons == demons`. Such a target is not expressible, not usable.
    from aegis.validator import degenerate_invariant
    if degenerate_invariant(t):
        return "", "not_expressible", ("translation collapses to a tautology "
                                       f"(`{t.strip()}`)")

    ids = set(re.findall(r"\b([A-Za-z_]\w*)\b", t))
    unknown = sorted(i for i in ids
                     if i not in storage and i not in BUILTINS
                     and not (i.startswith("_sum_") and i[5:] in maps))
    if unknown:
        return "", "not_expressible", f"names {unknown}, not in storage"
    return t, "auto", ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", default="results/rq3_frozen_labels.json")
    ap.add_argument("--out", default="results/rq3_formal_targets.csv")
    args = ap.parse_args()

    from aegis import static_analysis
    labels = json.load(open(os.path.join(HERE, args.labels)))
    out_rows = []
    for path, meta in sorted(labels.items()):
        if meta["arm"] != "general":
            continue
        target = (meta.get("target") or "").strip()
        if target.lower() in ("", "none"):
            out_rows.append(dict(path=path, contract=meta["contract"],
                                 target=target, target_formal="",
                                 status="no_target", note=""))
            continue
        try:
            facts = static_analysis.analyze(path)
            src = open(path).read()
            formal, status, note = formalize(target, facts, src)
        except Exception as exc:
            formal, status, note = "", "not_expressible", f"analysis: {exc}"
        out_rows.append(dict(path=path, contract=meta["contract"],
                             target=target, target_formal=formal,
                             status=status, note=note))

    out = os.path.join(HERE, args.out)
    with open(out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["contract", "path", "target",
                                           "target_formal", "status", "note"])
        w.writeheader()
        w.writerows(out_rows)

    import collections
    c = collections.Counter(r["status"] for r in out_rows)
    print(f"general-arm targets: {len(out_rows)}")
    for k in ("auto", "not_expressible", "no_target"):
        print(f"  {k:16s} {c.get(k, 0)}")
    changed = [r for r in out_rows
               if r["status"] == "auto" and r["target_formal"] != r["target"]]
    if changed:
        print("\ntranslated:")
        for r in changed[:12]:
            print(f"  {r['contract'][:24]:24s} {r['target'][:40]:40s} -> "
                  f"{r['target_formal'][:40]}")
    ne = [r for r in out_rows if r["status"] == "not_expressible"]
    if ne:
        print("\nnot expressible:")
        for r in ne[:12]:
            print(f"  {r['contract'][:24]:24s} {r['note'][:70]}")
    print(f"\nwrote {args.out}")


if __name__ == "__main__":
    main()
