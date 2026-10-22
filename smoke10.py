import argparse
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aegis.static_analysis import analyze


def numeric(facts, name):
    t = facts.var_types.get(name, "")
    if t:
        return t.startswith("uint") or t.startswith("int")
    return True


def derive_property(facts):
    for site in facts.exposure_sites:
        before = [v for v in site.write_before_call if numeric(facts, v)]
        after = [v for v in site.write_after_call if numeric(facts, v)]
        for a in before:
            for b in after:
                if a != b:
                    return f"{a} == {b}"
    nums = [v for v in facts.storage_vars if numeric(facts, v)
            and "mapping" not in facts.var_types.get(v, "")]
    if len(nums) >= 2:
        return f"{nums[0]} == {nums[1]}"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("benchmark_dir")
    ap.add_argument("--n", type=int, default=10)
    ap.add_argument("--llm", default="stub")
    ap.add_argument("--timeout", type=int, default=600)
    ap.add_argument("--out", default="smoke_out")
    args = ap.parse_args()

    manifest = json.load(open(os.path.join(args.benchmark_dir,
                                           "MANIFEST.json")))
    sample = [c["address"] for c in manifest["sample_220"]][:args.n]
    os.makedirs(args.out, exist_ok=True)
    rows = []
    for addr in sample:
        sol = os.path.join(args.benchmark_dir, "contracts", addr + ".sol")
        rec = {"address": addr}
        t0 = time.time()
        try:
            facts = analyze(sol)
            rec["main_contract"] = facts.contract
            rec["exposure_sites"] = len(facts.exposure_sites)
            prop = derive_property(facts)
            rec["property"] = prop
        except Exception as e:
            rec["stage"] = "static_analysis"
            rec["error"] = f"{type(e).__name__}: {e}"
            rec["elapsed"] = round(time.time() - t0, 1)
            rows.append(rec)
            print(f"{addr[:12]}  ANALYZE_FAIL  {rec['error'][:70]}")
            continue
        if not prop:
            rec["stage"] = "property"
            rec["error"] = "no numeric property derivable"
            rec["elapsed"] = round(time.time() - t0, 1)
            rows.append(rec)
            print(f"{addr[:12]}  NO_PROPERTY   sites={rec['exposure_sites']}")
            continue
        cmd = [sys.executable, "run_aegis.py", sol, "--property", prop,
               "--llm", args.llm, "--json"]
        try:
            p = subprocess.run(cmd, capture_output=True, text=True,
                               timeout=args.timeout)
            rec["elapsed"] = round(time.time() - t0, 1)
            try:
                out = json.loads(p.stdout[p.stdout.index("{"):])
                rec["status"] = out.get("status")
                rec["backend"] = out.get("backend")
                rec["obligations"] = len(out.get("obligations", []))
                json.dump(out, open(os.path.join(args.out,
                                                 addr + ".json"), "w"),
                          indent=1)
            except Exception:
                rec["stage"] = "pipeline"
                rec["error"] = (p.stderr.strip().splitlines()[-1]
                                if p.stderr.strip() else
                                "no JSON in output")
                open(os.path.join(args.out, addr + ".log"), "w").write(
                    p.stdout + "\n----STDERR----\n" + p.stderr)
        except subprocess.TimeoutExpired:
            rec["elapsed"] = args.timeout
            rec["status"] = "TIMEOUT"
        rows.append(rec)
        print(f"{addr[:12]}  {rec.get('status', 'ERROR'):12s} "
              f"prop=({prop})  sites={rec['exposure_sites']}  "
              f"{rec['elapsed']}s")
    json.dump(rows, open(os.path.join(args.out, "summary.json"), "w"),
              indent=1)
    ok = sum(1 for r in rows if r.get("status") in
             ("VERIFIED", "BUG_FOUND", "UNKNOWN"))
    print(f"\nclean pipeline runs: {ok}/{len(rows)}  "
          f"(details in {args.out}/summary.json)")


if __name__ == "__main__":
    main()
