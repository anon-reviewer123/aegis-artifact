"""
trace.py - keep everything a run produces, so a failure can be read afterwards.

Off unless a trace directory is set. When on, a run writes:

  contract.sol                 the source as analysed (after the ETH model)
  harness.sol                  the synthesized harness
  plans/c<i>_r<n>.json         each candidate plan, at the start of each round
  obligations/<seq>_<ctx>_<OBL>.sol   every obligation any arm checked
  obligations/<seq>_<ctx>_<OBL>.out   solc's raw output for it, in full
  stderr.txt                   everything printed to stderr (the validator)
  log.txt                      the run log
  result.json                  the final status and obligation report

<ctx> is the candidate and round the obligation belongs to, so a sequence of
files reads as the run happened. Nothing here changes what the run does.
"""
from __future__ import annotations

import json
import os
import sys

_DIR: str | None = None
_SEQ = 0
context = {"candidate": None, "round": None}


def start(directory: str | None) -> None:
    global _DIR, _SEQ
    _DIR = directory
    _SEQ = 0
    context["candidate"] = None
    context["round"] = None
    if _DIR:
        os.makedirs(os.path.join(_DIR, "obligations"), exist_ok=True)
        os.makedirs(os.path.join(_DIR, "plans"), exist_ok=True)


def stop() -> None:
    global _DIR
    _DIR = None


def enabled() -> bool:
    return _DIR is not None


def write(relpath: str, text: str) -> None:
    if not _DIR:
        return
    path = os.path.join(_DIR, relpath)
    os.makedirs(os.path.dirname(path) or _DIR, exist_ok=True)
    with open(path, "w", errors="replace") as fh:
        fh.write(text if isinstance(text, str) else str(text))


def write_json(relpath: str, obj) -> None:
    if not _DIR:
        return
    import dataclasses
    if dataclasses.is_dataclass(obj):
        obj = dataclasses.asdict(obj)
    write(relpath, json.dumps(obj, indent=1, default=str))


def _ctx() -> str:
    c, r = context["candidate"], context["round"]
    parts = []
    if c is not None:
        parts.append(f"c{c}")
    if r is not None:
        parts.append(f"r{r}")
    return "_".join(parts) or "pre"


def obligation(name: str, source: str, raw_output: str, status: str) -> None:
    """Record one obligation: its source and the solver's own words."""
    global _SEQ
    if not _DIR:
        return
    _SEQ += 1
    stem = f"obligations/{_SEQ:03d}_{_ctx()}_{name}"
    write(stem + ".sol", source)
    write(stem + ".out", f"status: {status}\n\n{raw_output}")


class Tee:
    """Write to the real stream and to a file at once."""

    def __init__(self, stream, path):
        self.stream = stream
        self.fh = open(path, "w", errors="replace")

    def write(self, s):
        self.stream.write(s)
        self.fh.write(s)
        return len(s)

    def flush(self):
        self.stream.flush()
        self.fh.flush()

    def close(self):
        self.fh.close()


_KEY = ("[1]", "[2]", "[3]", "[loop]", "[readonly]", "[harness]", "[access]",
        "[gate", "[confirm]", "[eth-model]", "[!]", "-- candidate", "[round",
        "OBL_", "CONFIRM_", "validation", "candidate via", "BUG_FOUND",
        "VERIFIED", "UNKNOWN", "FIXPOINT", "sliced harness", "closure",
        "exposure site", "outside the closure")


def summary(result: dict, log_lines: list) -> None:
    """A one-page account of the run: every stage, every round's obligations
    and their outcome, the confirmation runs and the verdict. The files beside
    it hold the full detail when a line here needs a closer look."""
    if not _DIR:
        return
    out = [f"STATUS: {result.get('status')}",
           f"exposure invariant: {result.get('exposure_invariant')}",
           f"candidates tried: {result.get('candidates_tried')}   "
           f"repair rounds: {result.get('repair_rounds')}", ""]
    out += [l.rstrip() for l in log_lines
            if any(k in l for k in _KEY)]
    out += ["", "obligation files (in order):"]
    ob = os.path.join(_DIR, "obligations")
    if os.path.isdir(ob):
        for f in sorted(os.listdir(ob)):
            if f.endswith(".out"):
                first = open(os.path.join(ob, f), errors="replace").readline().strip()
                out.append(f"  {f[:-4]:52s} {first}")
    write("summary.txt", "\n".join(out) + "\n")
