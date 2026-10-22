"""Check that loop-shape classification is independent of the verdict.

For every safe/unsafe twin pair the classifier must return the same shape. A
classifier that distinguished the twins would be reading the safety property it
is supposed to verify, which would make the loop verdicts circular.
"""
import sys
from types import SimpleNamespace

sys.path.insert(0, ".")
from loop_step_build import classify_loop_shape, build_loop_step

PAIRS = [
    ("refund", "settle", "conserve",
     {"owed": "mapping(address => uint256)", "totalOwed": "uint256",
      "claimants": "address[]"}),
    ("dividend", "distribute", "mutex",
     {"shareOf": "mapping(address => uint256)", "holders": "address[]",
      "pool": "uint256", "distributing": "bool"}),
    ("griefing", "settle", "progress",
     {"owed": "mapping(address => uint256)", "claimants": "address[]",
      "failed": "mapping(address => bool)"}),
]


def main():
    ok = True
    for family, fn, expected, vt in PAIRS:
        shapes = {}
        for variant in ("safe", "unsafe"):
            name = f"{family}_{variant}"
            src = open(f"loop_twins/{name}.sol").read()
            # the unsafe twin of dividend declares no mutex flag
            vt_v = dict(vt)
            if family == "dividend" and variant == "unsafe":
                vt_v.pop("distributing", None)
            facts = SimpleNamespace(contract=name, var_types=vt_v)
            site = SimpleNamespace(function=fn, call=".call", loop_body_writes=[])
            shapes[variant] = classify_loop_shape(src, facts, site)

            ob = build_loop_step(src, facts, site)
            built = ob is not None and ob.harness_source and ob.canary_source
            print(f"{'PASS' if built else 'FAIL'}  {name}: builds a step "
                  f"obligation and a canary")
            ok &= bool(built)

        agree = shapes["safe"] == shapes["unsafe"] == expected
        print(f"{'PASS' if agree else 'FAIL'}  {family}: both twins classify as "
              f"{expected} (safe={shapes['safe']}, unsafe={shapes['unsafe']})")
        ok &= agree

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
