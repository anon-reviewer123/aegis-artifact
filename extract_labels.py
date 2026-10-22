import argparse
import csv
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from scope_full import (strip, block_end, contracts_in, functions_in,
                        state_types, writes_in, CB, exposed, view,
                        loop_bodies, GAS_FWD)


def clip(text, n):
    lines = text.splitlines()
    if len(lines) <= n:
        return text
    return "\n".join(lines[:n]) + "\n    ... [%d more lines]" % (len(lines) - n)


def bundle(path, cname):
    try:
        src = strip(open(path, errors="ignore").read())
    except Exception as e:
        return None, str(e)
    body = None
    for n, b in contracts_in(src):
        if n == cname:
            body = b
            break
    if body is None:
        return None, "contract not found"

    fns = functions_in(body)
    st = state_types(body, fns)
    names = set(st)

    sites = []
    for fn in fns:
        if view(fn["header"]):
            continue
        for rx, kind, gas in CB:
            m = rx.search(fn["body"])
            if not m:
                continue
            after = writes_in(fn["body"][m.end():], names)
            if after:
                sites.append((fn, kind, gas, after, m))
            break
    loops = []
    for fn in fns:
        for lb in loop_bodies(fn["body"]):
            if GAS_FWD.search(lb) and writes_in(lb, names):
                loops.append((fn, lb))

    exp_vars = set()
    for _, _, _, a, _ in sites:
        exp_vars |= a

    closure = []
    for fn in fns:
        if not exposed(fn["header"]) or view(fn["header"]):
            continue
        if writes_in(fn["body"], names) & exp_vars:
            if all(fn["name"] != s[0]["name"] for s in sites):
                closure.append(fn)

    views = []
    for fn in fns:
        if view(fn["header"]) and exposed(fn["header"]):
            if any(re.search(r"\b%s\b" % re.escape(v), fn["body"])
                   for v in exp_vars):
                views.append(fn)

    decls = []
    for v in sorted(exp_vars | {x for _, lb in loops
                                for x in writes_in(lb, names)}):
        decls.append("    %s %s;" % (st.get(v, "?"), v))

    out = []
    if decls:
        out.append("state (exposed only):\n```solidity\n" +
                   "\n".join(decls) + "\n```")
    for fn, kind, gas, after, m in sites[:2]:
        out.append("exposure `%s` (%s, gas-forwarding=%s), writes after call: %s"
                   % (fn["name"], kind, bool(gas), sorted(after)))
        out.append("```solidity\nfunction %s(%s\n%s\n}\n```" %
                   (fn["name"], fn["header"].strip()[:60],
                    clip(fn["body"], 40)))
    for fn, lb in loops[:1]:
        out.append("in-loop call in `%s`:" % fn["name"])
        out.append("```solidity\n" + clip(lb, 25) + "\n```")
    for fn in closure[:2]:
        out.append("closure `%s` (writes exposed state):" % fn["name"])
        out.append("```solidity\n" + clip(fn["body"], 25) + "\n```")
    for fn in views[:1]:
        out.append("observing view `%s`:" % fn["name"])
        out.append("```solidity\n" + clip(fn["body"], 15) + "\n```")
    return "\n\n".join(out), ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scope_csv")
    ap.add_argument("--out-dir", default="results/label")
    ap.add_argument("--per-file", type=int, default=60)
    ap.add_argument("--max-lines", type=int, default=40)
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(args.scope_csv))
            if r.get("gas_forwarding") == "1"
            and r.get("expressible") == "1"
            and r.get("linear") == "1"]
    os.makedirs(args.out_dir, exist_ok=True)
    print("in-scope: %d  -> %d batches" %
          (len(rows), (len(rows) + args.per_file - 1) // args.per_file))

    batch, idx, written = [], 1, 0
    for i, r in enumerate(rows, 1):
        text, err = bundle(r["file"], r["contract"])
        if text is None:
            continue
        batch.append((i, r, text))
        written += 1
        if len(batch) >= args.per_file:
            write_batch(args.out_dir, idx, batch)
            idx += 1
            batch = []
    if batch:
        write_batch(args.out_dir, idx, batch)

    print("extracted %d bundles into %s/" % (written, args.out_dir))


def write_batch(d, idx, batch):
    p = os.path.join(d, "label_batch_%02d.md" % idx)
    with open(p, "w") as fh:
        fh.write("# Labelling batch %d (%d contracts)\n\n" % (idx, len(batch)))
        for i, r, text in batch:
            fh.write("## %d. %s\n" % (i, r["contract"]))
            fh.write("- families: %s\n" % r["families"])
            fh.write("- closure size: %s | sites: %s | loops: %s\n\n" %
                     (r["closure"], r["sites"], r["loops"]))
            fh.write(text + "\n\n---\n\n")
    print("  wrote %s (%d KB)" % (p, os.path.getsize(p) // 1024))


if __name__ == "__main__":
    main()
