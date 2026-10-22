#!/usr/bin/env bash
# Run the WAsgard callback obligation exactly as the backend does, twice:
# as it appeared in the trace, and with only the nested call removed.
cd "$(dirname "$0")"
for f in wasgard_original.sol wasgard_no_nested_call.sol; do
  echo "=== $f"
  out=$(timeout 125 solc --model-checker-engine chc --model-checker-targets assert \
        --model-checker-solvers eld --model-checker-ext-calls trusted \
        --model-checker-timeout 120000 --model-checker-show-unproved "$f" 2>&1)
  rc=$?
  if [ $rc -eq 124 ]; then echo "    TIMEOUT"
  elif echo "$out" | grep -q "Assertion violation happens here"; then echo "    FAILED   (assertion violation)"
  elif echo "$out" | grep -q "Error:"; then echo "    COMPILE ERROR"; echo "$out" | grep "Error:" | head -3
  elif echo "$out" | grep -q "could not be proved"; then echo "    UNKNOWN  (could not be proved)"
  else echo "    VERIFIED"; fi
done
