#!/usr/bin/env python3
"""
setup_50.py -- prepare the 50-contract benchmark for Aegis RQ1.
Run from inside aegis_dist/ AFTER placing the benchmark pack at ~/Downloads/aegis_rq1_benchmark/

Does three things:
  1. Patches the two analyzers to recognize onCallback/onReadOnly/peek callbacks.
  2. Copies all 50 contracts into contracts/corpus/.
  3. Installs benchmark_50.json labels next to run_aegis.py.
"""
import os, re, shutil, sys, json

AEGIS = os.getcwd()
PACK = os.path.expanduser("~/Downloads/aegis_rq1_benchmark")

if not os.path.exists(os.path.join(AEGIS, "aegis", "static_analysis.py")):
    sys.exit("ERROR: run this from inside aegis_dist/ (where run_aegis.py lives)")
if not os.path.exists(PACK):
    sys.exit(f"ERROR: benchmark pack not found at {PACK}")

# --- 1. patch ast_analysis.py ---
p = os.path.join(AEGIS, "aegis", "ast_analysis.py")
s = open(p).read()
if "onCallback" not in s:
    anchor = '        "onERC721Received": "ERC721 safeTransfer callback can re-enter",'
    add = anchor + '''
        "onCallback": "generic external callback can re-enter",
        "onFlashLoan": "ERC-3156 flash-loan callback can re-enter",
        "onReadOnly": "read-only reentrancy callback can re-enter",
        "peek": "oracle/view callback can re-enter",'''
    if anchor in s:
        s = s.replace(anchor, add); open(p, "w").write(s)
        print("[1a] ast_analysis.py patched (onCallback etc.)")
    else:
        print("[1a] WARN: ast anchor not found; skipping")
else:
    print("[1a] ast_analysis.py already has onCallback")

# --- patch static_analysis.py ---
p = os.path.join(AEGIS, "aegis", "static_analysis.py")
s = open(p).read()
if "onCallback" not in s:
    anchor = '    (r"\\.on[A-Z]\\w*Received\\s*\\(", "generic \'on*Received\' callback can re-enter"),'
    add = '''    (r"\\.onCallback\\s*\\(", "generic external callback can re-enter"),
    (r"\\.onReadOnly\\w*\\s*\\(", "read-only reentrancy callback can re-enter"),
''' + anchor + '''
    (r"\\.on[A-Z]\\w*\\s*\\(", "generic 'on*' callback can re-enter"),'''
    if anchor in s:
        s = s.replace(anchor, add); open(p, "w").write(s)
        print("[1b] static_analysis.py patched (onCallback etc.)")
    else:
        print("[1b] WARN: static anchor not found; skipping")
else:
    print("[1b] static_analysis.py already has onCallback")

# --- 2. copy contracts ---
dst = os.path.join(AEGIS, "contracts", "corpus")
os.makedirs(dst, exist_ok=True)
n = 0
for f in os.listdir(os.path.join(PACK, "contracts")):
    if f.endswith(".sol"):
        shutil.copy(os.path.join(PACK, "contracts", f), os.path.join(dst, f))
        n += 1
print(f"[2] copied {n} contracts into contracts/corpus/")

# --- 3. install labels ---
shutil.copy(os.path.join(PACK, "benchmark_50.json"),
            os.path.join(AEGIS, "benchmark_50.json"))
print("[3] installed benchmark_50.json")
print("\nDONE. Verify with: python3 -c \"from aegis import static_analysis as sa; print(sa.analyze('contracts/corpus/CrossFunctionDesync_U01.sol').exposure_sites[0].function)\"")
