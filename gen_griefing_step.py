"""Generate the griefing (progress) inductive step harnesses for the loop twins.

Emits, for each twin, the real assertion harness and a canary variant whose
assertion is assert(false). The canary must FAIL: if it verifies, the harness
body is unreachable and the real verdict would be vacuous.
"""
import os
import sys
from types import SimpleNamespace

sys.path.insert(0, ".")
from loop_step_build import build_progress_step

VAR_TYPES = {
    "owed": "mapping(address => uint256)",
    "claimants": "address[]",
    "failed": "mapping(address => bool)",
}

TWINS = {"griefing_safe": "GriefingSafe", "griefing_unsafe": "GriefingUnsafe"}


def main(outdir="loop_steps"):
    os.makedirs(outdir, exist_ok=True)
    for name, cname in TWINS.items():
        src = open(f"loop_twins/{name}.sol").read()
        facts = SimpleNamespace(contract=cname, var_types=VAR_TYPES)
        site = SimpleNamespace(function="settle", call=".call",
                               loop_body_writes=[])
        for tag, canary in (("", False), (".canary", True)):
            out = build_progress_step(src, facts, site, canary=canary)
            if out is None:
                print(f"{name}{tag}: shape not recognised")
                continue
            path = os.path.join(outdir, f"{name}{tag}.step.sol")
            open(path, "w").write(out)
            print(f"wrote {path}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "loop_steps")
