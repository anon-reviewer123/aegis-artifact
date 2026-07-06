#!/bin/bash
# Run the full RQ3 + RQ4 experiment suite on bench10.
#
# Prerequisites:
#   - solc 0.8.20+ on PATH (solc-select install 0.8.20 && solc-select use 0.8.20)
#   - Eldarica available to solc (--model-checker-solvers eld)
#   - OPENAI_API_KEY or ANTHROPIC_API_KEY set
#   - AEGIS_OPENAI_MODEL set (e.g. gpt-5.4-mini)
#
# Usage:
#   cd ~/Downloads/aegis_dist
#   chmod +x run_experiments.sh
#   ./run_experiments.sh

set -euo pipefail

LLM="${AEGIS_LLM:-openai}"
K="${AEGIS_K:-4}"
TIMEOUT="${AEGIS_TIMEOUT:-90000}"
ROUNDS="${AEGIS_REPAIR_ROUNDS:-8}"

echo "=========================================="
echo " AEGIS bench10 experiment suite"
echo " LLM=$LLM  K=$K  TIMEOUT=${TIMEOUT}ms"
echo "=========================================="

echo ""
echo "--- RQ3: MCVP module ablation ---"
python3 run_rq3.py --llm "$LLM" --k "$K" --smt-timeout-ms "$TIMEOUT"

echo ""
echo "--- RQ4: modular repair contribution ---"
python3 run_rq4.py --llm "$LLM" --k "$K" --smt-timeout-ms "$TIMEOUT" \
    --max-repair-rounds "$ROUNDS"

echo ""
echo "--- aggregate results ---"
python3 aggregate_rqs.py

echo ""
echo "Done. CSVs are in results/"
