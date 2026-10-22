#!/usr/bin/env bash
# Run the Foundry invariant tests over the fuzzer-runnable twin variants.
# Reports, per contract, whether the solvency invariant was broken, along with
# the number of runs and calls so a "held" result can be distinguished from a
# campaign that never executed.
set -u
cd "$(dirname "$0")"

rm -rf cache/invariant/failures 2>/dev/null

printf "%-26s %-8s %s\n" "contract" "result" "campaign"
for t in test/*.t.sol; do
  name=$(basename "$t" .t.sol)
  out=$(forge test --match-path "$t" 2>&1)
  stats=$(echo "$out" | grep -oE "\(runs: [0-9]+, calls: [0-9]+, reverts: [0-9]+\)" | head -1)
  if   echo "$out" | grep -q "^\[FAIL"; then res="BROKEN"
  elif echo "$out" | grep -q "^\[PASS\]"; then res="held"
  elif echo "$out" | grep -qE "Compiler run failed|Error:"; then res="BUILD_ERR"
  else res="unknown"; fi
  printf "%-26s %-8s %s\n" "$name" "$res" "${stats:-no campaign}"
done
