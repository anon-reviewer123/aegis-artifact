import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from aegis.slice_harness import build_slice_obligation, full_body, find_function
from aegis import backend

CALL = re.compile(r"\.call\s*[({]|\.call\s*\.\s*value|\.transfer\s*\(|"
                  r"\.send\s*\(|\.\s*on[A-Z]\w*\s*\(|\.tokensReceived\s*\(")


def exposure_of(body):
    for m in re.finditer(r"function\s+(\w+)\s*\(", body):
        fn = m.group(1)
        if fn == "invariant":
            continue
        _, _, fb = find_function(body, fn)
        if fb and CALL.search(fb):
            return fn
    return None


def main():
    rows = []
    for g in sorted(glob.glob("contracts/corpus/*.sol")):
        if ".harness" in g:
            continue
        name = os.path.basename(g)[:-4].split(".")[0]
        src = open(g, errors="ignore").read()
        body = full_body(src, name)
        if not body or "function invariant" not in body:
            continue
        expo = exposure_of(body)
        if not expo:
            continue
        out, err = build_slice_obligation(src, name, expo, "invariant")
        if out is None:
            rows.append((name, expo, "skip", err))
            continue
        r = backend.check_obligation("OBL_ro", "phases", out, timeout_ms=60000)
        rows.append((name, expo, r.status, r.detail[:44]))

    tp = fp = tn = fn_ = other = 0
    for name, expo, status, detail in rows:
        if "_U" in name:
            unsafe = True
        elif "_S" in name:
            unsafe = False
        else:
            # `X` / `XSafe` pairs: the plain name is the vulnerable variant
            unsafe = not name.endswith("Safe")
        mark = "  "
        if status == "failed":
            if unsafe:
                tp += 1
                mark = "ok"
            else:
                fp += 1
                mark = "FP"
        elif status == "verified":
            if unsafe:
                fn_ += 1
                mark = "FN"
            else:
                tn += 1
                mark = "ok"
        else:
            other += 1
        print("%s %-32s %-14s %-9s %s" % (mark, name[:32], expo[:14],
                                          status, detail))

    print("\nunsafe refuted (TP)   %d" % tp)
    print("safe verified  (TN)   %d" % tn)
    print("safe refuted   (FP)   %d" % fp)
    print("unsafe missed  (FN)   %d" % fn_)
    print("inconclusive          %d" % other)
    if tp + fn_:
        print("\nrecall on unsafe twins  %.0f%%" % (100.0 * tp / (tp + fn_)))
    if tp + fp:
        print("precision               %.0f%%" % (100.0 * tp / (tp + fp)))


if __name__ == "__main__":
    main()
