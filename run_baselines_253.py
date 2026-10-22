import argparse
import collections
import csv
import json
import os
import re
import subprocess
import sys
import tempfile
import time

SPDX = re.compile(r"^\s*//\s*SPDX-License-Identifier:.*$", re.M)
IMPORT = re.compile(r"^\s*import\s+[^;]*;\s*$", re.M)
DECL = re.compile(r"\b(?:contract|interface|library)\s+(\w+)")
PRAGMA_V = re.compile(r"pragma\s+solidity\s+[^\d]*(\d+\.\d+\.\d+)")
REENTRANCY = re.compile(
    r"reentran|re-entran|state.?change.?after|external call.*state", re.I)

ARTIFACT_DIRS = [os.path.expanduser("~/.solc-select/artifacts"),
                 os.path.expanduser("~/venv/.solc-select/artifacts")]


def required_version(path):
    try:
        src = open(path, errors="ignore").read()
    except Exception:
        return None
    vs = PRAGMA_V.findall(src)
    if not vs:
        return None
    return max(vs, key=lambda v: tuple(int(x) for x in v.split(".")))


def resolve_solc(path):
    v = required_version(path)
    if v:
        for base in ARTIFACT_DIRS:
            c = os.path.join(base, "solc-%s" % v, "solc-%s" % v)
            if os.path.isfile(c):
                return c
    return "solc"


def solc_env(path):
    env = dict(os.environ)
    v = required_version(path)
    if v:
        env["SOLC_VERSION"] = v
    return env


def normalized_copy(path):
    """A copy solc accepts: one SPDX line, no imports already inlined."""
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
    declared = set(DECL.findall(src))

    def drop(m):
        n = re.search(r"([\w]+)\.sol", m.group(0))
        return "" if (n and n.group(1) in declared) else m.group(0)

    body = IMPORT.sub(drop, body)
    fd, tmp = tempfile.mkstemp(suffix=".sol")
    os.close(fd)
    with open(tmp, "w") as fh:
        fh.write(first + "\n" + body)
    return tmp, tmp


def cleanup(tmp):
    if tmp:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def compiles(path, timeout=60):
    p, tmp = normalized_copy(path)
    try:
        cp = subprocess.run([resolve_solc(path), "--bin", p],
                            capture_output=True, text=True, timeout=timeout)
        return cp.returncode == 0
    except Exception:
        return False
    finally:
        cleanup(tmp)


def run_smtchecker(path, timeout):
    p, tmp = normalized_copy(path)
    try:
        cp = subprocess.run(
            [resolve_solc(path), "--model-checker-engine", "chc",
             "--model-checker-targets", "assert,underflow,overflow",
             "--model-checker-timeout", "30000", p],
            capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        cleanup(tmp)
        return "timeout", 0
    except FileNotFoundError:
        cleanup(tmp)
        return "no_tool", 0
    cleanup(tmp)
    out = cp.stdout + cp.stderr
    if re.search(r"^Error:", out, re.M):
        return "error", 0
    n = len(re.findall(r"Warning: CHC:", out))
    return ("warn" if n else "clean"), n


def run_slither(path, timeout):
    """Slither's reentrancy detectors.

    Exit status alone is ambiguous -- Slither returns non-zero when it finds
    issues as well as when it fails -- so the verdict is taken from whether the
    JSON report parsed with success=true. Anything else is an analysis failure
    and must not be recorded as a clean result.
    """
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
    start = cp.stdout.find('{"success"')
    if start == -1:
        start = cp.stdout.find("{")
    if start == -1:
        return "error", 0
    try:
        data = json.loads(cp.stdout[start:])
    except Exception:
        return "error", 0
    if not data.get("success", False):
        return "error", 0
    dets = data.get("results", {}).get("detectors", [])
    return ("warn" if dets else "clean"), len(dets)


def run_mythril(path, timeout):
    v = required_version(path) or "0.8.19"
    try:
        cp = subprocess.run(
            ["myth", "analyze", path, "-o", "json", "--solv", v,
             "--execution-timeout", str(max(10, timeout - 20))],
            capture_output=True, text=True, timeout=timeout,
            env=solc_env(path))
    except subprocess.TimeoutExpired:
        return "timeout", 0
    except FileNotFoundError:
        return "no_tool", 0
    start = cp.stdout.find("{")
    if start == -1:
        return "error", 0
    try:
        data = json.loads(cp.stdout[start:])
    except Exception:
        return "error", 0
    if not data.get("success", True):
        return "error", 0
    issues = [i for i in data.get("issues", [])
              if REENTRANCY.search(i.get("title", "") +
                                   i.get("description", ""))]
    return ("warn" if issues else "clean"), len(issues)


RUNNERS = {"smtchecker": run_smtchecker, "slither": run_slither,
           "mythril": run_mythril}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scope_csv")
    ap.add_argument("--tools", default="slither,smtchecker")
    ap.add_argument("--timeout", type=int, default=180)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--compilable-csv", default="results/compilable.csv")
    ap.add_argument("--out", default="results/baselines_253.csv")
    args = ap.parse_args()

    rows = [r for r in csv.DictReader(open(args.scope_csv))
            if r.get("gas_forwarding") == "1"
            and r.get("expressible") == "1"
            and r.get("linear") == "1"]

    if os.path.exists(args.compilable_csv):
        keep = {r["file"] for r in csv.DictReader(open(args.compilable_csv))}
        rows = [r for r in rows if r["file"] in keep]
        print("using cached compilable set: %d" % len(rows))
    else:
        print("determining compilable subset of %d ..." % len(rows))
        good = []
        for i, r in enumerate(rows):
            if compiles(r["file"]):
                good.append(r)
            if (i + 1) % 50 == 0:
                print("  %d/%d  compilable %d" % (i + 1, len(rows), len(good)),
                      file=sys.stderr)
        os.makedirs(os.path.dirname(args.compilable_csv) or ".", exist_ok=True)
        with open(args.compilable_csv, "w", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=["file", "contract"])
            w.writeheader()
            for r in good:
                w.writerow({"file": r["file"], "contract": r["contract"]})
        rows = good
        print("compilable: %d" % len(rows))

    if args.limit:
        rows = rows[:args.limit]
    tools = [t.strip() for t in args.tools.split(",") if t.strip()]
    print("running %s on %d contracts\n" % (tools, len(rows)))

    recs, tally = [], {t: collections.Counter() for t in tools}
    t0 = time.time()
    for i, r in enumerate(rows):
        rec = {"contract": r["contract"], "file": r["file"],
               "families": r.get("families", "")}
        for t in tools:
            st, n = RUNNERS[t](r["file"], args.timeout)
            rec[t], rec[t + "_n"] = st, n
            tally[t][st] += 1
        recs.append(rec)
        if (i + 1) % 20 == 0:
            el = time.time() - t0
            print("  %d/%d  %.0fs, ~%.0fmin left" %
                  (i + 1, len(rows), el,
                   el / (i + 1) * (len(rows) - i - 1) / 60), file=sys.stderr)

    cols = ["contract", "file", "families"]
    for t in tools:
        cols += [t, t + "_n"]
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(recs)

    print("\ncontracts: %d" % len(recs))
    for t in tools:
        print("\n%s" % t)
        ran = sum(v for k, v in tally[t].items() if k in ("warn", "clean"))
        for k, v in tally[t].most_common():
            print("  %-10s %5d  (%.0f%%)" % (k, v, 100.0 * v / len(recs)))
        if ran:
            w_ = tally[t]["warn"]
            print("  warning rate among runs that completed: %d/%d (%.0f%%)"
                  % (w_, ran, 100.0 * w_ / ran))
    print("\nwrote %s" % args.out)


if __name__ == "__main__":
    main()
