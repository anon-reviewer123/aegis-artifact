import argparse
import csv
import json
import os
import re
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

REENTRANCY_HINTS = re.compile(
    r"reentran|re-entran|state.?change.?after|external call.*state|"
    r"unprotected.*call|dangerous.*call", re.I)


PRAGMA_V = re.compile(r"pragma\s+solidity\s+[^\d]*(\d+\.\d+\.\d+)")


def required_version(path):
    """Highest concrete version named by any pragma in the file.

    Flattened sources carry one pragma per inlined file; the deployed
    contract's is the highest, and a mismatched compiler makes every tool
    abort before it analyses anything.
    """
    try:
        src = open(path, errors="ignore").read()
    except Exception:
        return None
    vs = PRAGMA_V.findall(src)
    if not vs:
        return None
    return max(vs, key=lambda v: tuple(int(x) for x in v.split(".")))


def solc_env(path):
    """Environment selecting the compiler this contract needs.

    solc-select and crytic-compile both honour SOLC_VERSION, so setting it per
    invocation avoids mutating global state between contracts.
    """
    env = dict(os.environ)
    v = required_version(path)
    if v:
        env["SOLC_VERSION"] = v
    return env


def resolve_solc(path):
    """Path to the matching solc binary, or plain `solc`."""
    v = required_version(path)
    if not v:
        return "solc"
    for base in (os.path.expanduser("~/.solc-select/artifacts"),
                 os.path.expanduser("~/venv/.solc-select/artifacts")):
        cand = os.path.join(base, "solc-%s" % v, "solc-%s" % v)
        if os.path.isfile(cand):
            return cand
    return "solc"


SPDX = re.compile(r"^\s*//\s*SPDX-License-Identifier:.*$", re.M)
IMPORT = re.compile(r"^\s*import\s+[^;]*;\s*$", re.M)
DECL = re.compile(r"\b(?:contract|interface|library)\s+(\w+)")


def normalized_copy(path):
    """Write a copy solc will accept, or return the original path.

    Flattened sources concatenate many files, each keeping its own SPDX line,
    and solc rejects more than one per compilation unit. That is an artifact of
    how the corpus stores contracts, not a property of the contract, so the
    duplicates are collapsed rather than counted as analysis failures.
    """
    try:
        src = open(path, errors="ignore").read()
    except Exception:
        return path, None
    hits = SPDX.findall(src)
    imports = IMPORT.findall(src)
    if len(hits) <= 1 and not imports:
        return path, None
    first = hits[0].strip() if hits else "// SPDX-License-Identifier: UNKNOWN"
    body = SPDX.sub("", src)
    # Flattening inlines the imported sources but leaves the import statements
    # behind. They then resolve against a path layout that does not exist, so
    # the file fails to compile even though every dependency is present. Drop
    # an import only when the unit it names is declared in this same file.
    declared = set(DECL.findall(src))

    def drop(m):
        n = re.search(r"([\w]+)\.sol", m.group(0))
        if n and n.group(1) in declared:
            return ""
        return m.group(0)

    body = IMPORT.sub(drop, body)
    fd, tmp = tempfile.mkstemp(suffix=".sol")
    os.close(fd)
    with open(tmp, "w") as fh:
        fh.write(first + "\n" + body)
    return tmp, tmp


def run_smtchecker(path, timeout):
    solc = resolve_solc(path)
    path, tmp = normalized_copy(path)
    try:
        cp = subprocess.run(
            [solc, "--model-checker-engine", "chc",
             "--model-checker-targets", "assert,underflow,overflow",
             "--model-checker-timeout", "30000", path],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "timeout", 0
    except FileNotFoundError:
        return "no_tool", 0
    if tmp:
        try:
            os.unlink(tmp)
        except OSError:
            pass
    out = cp.stdout + cp.stderr
    if "requires different compiler version" in out:
        return "version_error", 0
    if "Error:" in out and "Warning" not in out:
        return "error", 0
    n = len(re.findall(r"Warning: CHC:", out))
    return ("warn" if n else "clean"), n


def run_slither(path, timeout):
    try:
        cp = subprocess.run(
            ["slither", path, "--json", "-", "--detect",
             "reentrancy-eth,reentrancy-no-eth,reentrancy-benign,"
             "reentrancy-events,reentrancy-unlimited-gas"],
            capture_output=True, text=True, timeout=timeout,
            env=solc_env(path))
    except subprocess.TimeoutExpired:
        return "timeout", 0
    except FileNotFoundError:
        return "no_tool", 0
    if "requires different compiler version" in cp.stderr:
        return "version_error", 0
    try:
        start = cp.stdout.find("{")
        data = json.loads(cp.stdout[start:])
        dets = data.get("results", {}).get("detectors", [])
        return ("warn" if dets else "clean"), len(dets)
    except Exception:
        if "Error:" in cp.stderr:
            return "error", 0
        return "clean", 0


def run_mythril(path, timeout):
    try:
        cp = subprocess.run(
            ["myth", "analyze", path, "-o", "json",
             "--execution-timeout", str(max(10, timeout - 10)),
             "--solv", required_version(path) or "0.8.19"],
            capture_output=True, text=True, timeout=timeout,
            env=solc_env(path))
    except subprocess.TimeoutExpired:
        return "timeout", 0
    except FileNotFoundError:
        return "no_tool", 0
    try:
        start = cp.stdout.find("{")
        data = json.loads(cp.stdout[start:])
        issues = [i for i in data.get("issues", [])
                  if REENTRANCY_HINTS.search(i.get("title", "") +
                                             i.get("description", ""))]
        return ("warn" if issues else "clean"), len(issues)
    except Exception:
        return "error", 0


RUNNERS = {
    "smtchecker": run_smtchecker,
    "slither": run_slither,
    "mythril": run_mythril,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scope_csv")
    ap.add_argument("--tools", default="smtchecker,slither")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--out", default="results/baselines.csv")
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(args.scope_csv))
            if r.get("gas_forwarding") == "1"
            and r.get("expressible") == "1"
            and r.get("linear") == "1"]
    if args.limit:
        rows = rows[:args.limit]
    tools = [t.strip() for t in args.tools.split(",") if t.strip()]

    print("in-scope contracts: %d   tools: %s" % (len(rows), tools))
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)

    recs = []
    tally = {t: {} for t in tools}
    t0 = time.time()
    for i, r in enumerate(rows):
        rec = {"contract": r["contract"], "file": r["file"],
               "families": r["families"]}
        for t in tools:
            st, n = RUNNERS[t](r["file"], args.timeout)
            rec[t] = st
            rec[t + "_n"] = n
            tally[t][st] = tally[t].get(st, 0) + 1
        recs.append(rec)
        if (i + 1) % 10 == 0:
            el = time.time() - t0
            print("  %d/%d  %.0fs elapsed, ~%.0fmin left" %
                  (i + 1, len(rows), el,
                   (el / (i + 1) * (len(rows) - i - 1)) / 60),
                  file=sys.stderr)

    cols = ["contract", "file", "families"]
    for t in tools:
        cols += [t, t + "_n"]
    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(recs)

    print("\ncontracts run: %d" % len(recs))
    for t in tools:
        print("\n%s" % t)
        for k, v in sorted(tally[t].items(), key=lambda x: -x[1]):
            print("  %-10s %5d  (%.0f%%)" % (k, v, 100.0 * v / len(recs)))
    print("\nwrote %s" % args.out)


if __name__ == "__main__":
    main()
