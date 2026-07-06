"""Show the REAL solc error that analyze_ast is silently swallowing.
Run on your PC:
    cd ~/Downloads/aegis_dist
    python3 diagnose_solc.py contracts/realworld/Z4GPresale.sol
    python3 diagnose_solc.py contracts/realworld/HourlyLottery.sol
"""
import subprocess, sys, re
path = sys.argv[1]
src = open(path).read()
pragma = re.search(r"pragma solidity[^;]*;", src)
print(f"file: {path}")
print(f"pragma: {pragma.group(0) if pragma else 'NONE'}")
print(f"has imports: {'import' in src}")
print("installed solc:")
print(subprocess.run(['solc','--version'],capture_output=True,text=True).stdout.strip())
print("\n--- bare invocation (what analyze_ast does today) ---")
r = subprocess.run(['solc','--ast-compact-json',path],capture_output=True,text=True)
print("returncode:", r.returncode)
print("stdout has JSON:", '{' in r.stdout)
print("STDERR:")
print(r.stderr[:1500] if r.stderr else "(none)")
