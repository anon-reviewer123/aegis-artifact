import json
import os
import subprocess
import sys
import time

def main():
    root = sys.argv[1]
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    llm = sys.argv[3] if len(sys.argv) > 3 else "openai"
    cross = json.load(open(os.path.join(root, "cross_clean.json")))[:n]
    cdir = os.path.join(root, "contracts")
    os.makedirs("aegis10_out", exist_ok=True)
    rows = []
    for c in cross:
        addr, prop = c["address"], c["property"]
        sol = os.path.join(cdir, addr + ".sol")
        t0 = time.time()
        cmd = [sys.executable, "run_aegis.py", sol, "--property", prop,
               "--llm", llm, "--k", "4", "--smt-timeout-ms", "20000", "--json"]
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
            el = round(time.time() - t0, 1)
            try:
                out = json.loads(p.stdout[p.stdout.index("{"):])
                st = out.get("status")
                obl = len(out.get("obligations", []))
                solved = sum(1 for o in out.get("obligations", [])
                             if o.get("status") in ("verified", "sat", "unsat",
                                                    "failed"))
                json.dump(out, open(f"aegis10_out/{addr}.json", "w"), indent=1)
            except Exception:
                st, obl, solved = "PARSE_ERR", 0, 0
                open(f"aegis10_out/{addr}.log", "w").write(
                    p.stdout + "\n--STDERR--\n" + p.stderr)
        except subprocess.TimeoutExpired:
            st, obl, solved, el = "TIMEOUT", 0, 0, 900
        rows.append({"address": addr, "property": prop, "status": st,
                     "obligations": obl, "solved": solved, "elapsed": el})
        print(f"{addr[:12]}  {st:11s}  obl={obl:2d} solved={solved:2d}  "
              f"({prop})  {el}s")
    json.dump(rows, open("aegis10_out/summary.json", "w"), indent=1)
    ver = sum(1 for r in rows if r["status"] == "VERIFIED")
    bug = sum(1 for r in rows if r["status"] == "BUG_FOUND")
    unk = sum(1 for r in rows if r["status"] == "UNKNOWN")
    reached = sum(1 for r in rows if r["solved"] > 0)
    print(f"\nVERIFIED={ver}  BUG_FOUND={bug}  UNKNOWN={unk}  "
          f"| reached solver: {reached}/{len(rows)}")
    print("details in aegis10_out/summary.json")

if __name__ == "__main__":
    main()
