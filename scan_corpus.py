#!/usr/bin/env python3
"""
Scan a corpus for the two callback patterns Aegis targets.

  loop      an external call inside a for/while body
  readonly  a public view reading state that a function containing an external
            call also writes

This is a first-pass syntactic filter, not a verdict. It is deliberately
permissive: it over-approximates so that the manual inspection step decides what
is genuine, and it records enough context (function, line, matched text) to make
that inspection quick.

Usage:
  python3 scan_corpus.py <corpus_dir> --out results/scan_rsd
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import sys

CALL = re.compile(
    r"\.\s*(call|delegatecall|callcode|staticcall)\s*[.{(]"
    r"|\.\s*(send|transfer)\s*\(")
FUNC = re.compile(
    r"function\s+(\w+)\s*\(([^)]*)\)\s*([^{;]*)(\{|;)", re.S)
LOOP = re.compile(r"\b(for|while)\s*\(")
PRAGMA = re.compile(r"pragma\s+solidity\s*([^;]+);")
STATE_WRITE = re.compile(r"\b([A-Za-z_]\w*)\s*(\[[^\]]*\])?\s*(=[^=]|[-+*/]=)")
IDENT = re.compile(r"\b([A-Za-z_]\w*)\b")


def _balanced_body(src: str, open_idx: int) -> str:
    depth, i = 0, open_idx
    while i < len(src):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[open_idx:i + 1]
        i += 1
    return src[open_idx:]



STATE_DECL = re.compile(
    r"^\s*(mapping\s*\([^;]*?\)|u?int\d*|bool|address(?:\s+payable)?|bytes\d*|string)"
    r"(?:\s+(?:public|private|internal|constant|immutable))*"
    r"\s+([A-Za-z_]\w*)\s*(?:=[^;]*)?;", re.M)


def _state_vars(src: str) -> set:
    """Contract-level variable names, i.e. declarations outside any function."""
    out, depth, i, start = set(), 0, 0, 0
    # collect the top-level region of each contract body
    for m in re.finditer(r"\b(contract|library|interface)\s+\w+[^{]*\{", src):
        body = _balanced_body(src, m.end() - 1)
        # strip function bodies so only contract-level declarations remain
        stripped, d, buf = [], 0, []
        for fm in FUNC.finditer(body):
            pass
        top = body
        for fname, _h, fbody, _o in _functions(body):
            top = top.replace(fbody, ";")
        for dm in STATE_DECL.finditer(top):
            out.add(dm.group(2))
    return out

def _functions(src: str):
    """Yield (name, header, body, start_offset) for each function with a body."""
    for m in FUNC.finditer(src):
        if m.group(4) != "{":
            continue
        body = _balanced_body(src, m.end() - 1)
        yield m.group(1), m.group(3) or "", body, m.start()


def _line_of(src: str, offset: int) -> int:
    return src.count("\n", 0, offset) + 1


def _loop_bodies(fn_body: str):
    """Yield the body text of each loop in the function."""
    for lm in LOOP.finditer(fn_body):
        brace = fn_body.find("{", lm.end())
        if brace == -1:
            continue
        yield _balanced_body(fn_body, brace)


def scan_file(path: str):
    """Return a list of hit dicts for one contract file."""
    try:
        src = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return []
    hits = []
    pragma = PRAGMA.search(src)
    pragma = pragma.group(1).strip() if pragma else ""

    fns = list(_functions(src))

    # pattern 1: external call inside a loop
    for name, _hdr, body, off in fns:
        for lb in _loop_bodies(body):
            cm = CALL.search(lb)
            if cm:
                hits.append({
                    "pattern": "loop",
                    "function": name,
                    "line": _line_of(src, off),
                    "matched": cm.group(0).strip(),
                    "pragma": pragma,
                })
                break

    # pattern 2: a public view reads a STATE variable that some function writes
    # AFTER an external call. All three conditions are required: a local, or a
    # state write that precedes the call, is not read-only reentrancy.
    state = _state_vars(src)
    written_after = set()
    for _name, _hdr, body, _off in fns:
        cm = CALL.search(body)
        if not cm:
            continue
        tail = body[cm.end():]
        for wm in STATE_WRITE.finditer(tail):
            if wm.group(1) in state:
                written_after.add(wm.group(1))
    if written_after:
        for name, hdr, body, off in fns:
            if "view" not in hdr and "constant" not in hdr and "pure" in hdr:
                continue
            if "view" not in hdr and "constant" not in hdr:
                continue
            if not ("public" in hdr or "external" in hdr):
                continue
            read = set(IDENT.findall(body))
            shared = sorted(written_after & read)
            if shared:
                hits.append({
                    "pattern": "readonly",
                    "function": name,
                    "line": _line_of(src, off),
                    "matched": ",".join(shared[:4]),
                    "pragma": pragma,
                })
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("corpus")
    ap.add_argument("--out", default="results/scan")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    files = []
    for root, _d, names in os.walk(args.corpus):
        for n in names:
            if n.endswith(".sol"):
                files.append(os.path.join(root, n))
    files.sort()
    if args.limit:
        files = files[:args.limit]

    rows, loop_files, ro_files = [], set(), set()
    for i, path in enumerate(files, 1):
        for h in scan_file(path):
            h["contract"] = os.path.basename(path)
            h["path"] = path
            rows.append(h)
            (loop_files if h["pattern"] == "loop" else ro_files).add(path)
        if i % 2000 == 0:
            print(f"  scanned {i}/{len(files)}", flush=True)

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out + ".csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["contract", "pattern", "function",
                                           "line", "matched", "pragma", "path"],
                           lineterminator="\n")
        w.writeheader()
        w.writerows(rows)

    print(f"\ncorpus:            {len(files)} files")
    print(f"loop hits:         {len(rows and [r for r in rows if r['pattern']=='loop'])} "
          f"in {len(loop_files)} contracts")
    print(f"readonly hits:     {len([r for r in rows if r['pattern']=='readonly'])} "
          f"in {len(ro_files)} contracts")
    print(f"both patterns:     {len(loop_files & ro_files)} contracts")
    print(f"\nwrote {args.out}.csv")


if __name__ == "__main__":
    main()
