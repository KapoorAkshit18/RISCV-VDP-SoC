#!/usr/bin/env bash
# =============================================================================
# run_local_ci.sh
# 1-Click Local CI Runner for RISCV-VDP-SoC (Git Bash / Linux)
#
# Usage:
#   ./run_local_ci.sh [all|lint|sim|synth]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

STAGE="${1:-all}"

echo "=================================================================="
echo "  RISCV-VDP-SoC Local CI Runner"
echo "  Target Stage: $STAGE"
echo "=================================================================="

run_lint() {
    echo ""
    echo ">>> Running Stage 1: QuestaSim Lint & Syntax Check..."
    bash "$SCRIPT_DIR/ci/scripts/run_questasim_lint.sh"
}

run_sim() {
    echo ""
    echo ">>> Running Stage 2: QuestaSim Top Testbench Simulation..."
    bash "$SCRIPT_DIR/ci/scripts/run_questasim_sim.sh"
}

run_synth() {
    echo ""
    echo ">>> Running Stage 3: Local Vivado FPGA Synthesis..."
    bash "$SCRIPT_DIR/ci/scripts/run_vivado_synth.sh"
}

case "$STAGE" in
    lint)
        run_lint
        ;;
    sim)
        run_sim
        ;;
    synth)
        run_synth
        ;;
    all)
        run_lint
        run_sim
        run_synth
        ;;
    *)
        echo "Unknown stage: $STAGE"
        echo "Valid options: all, lint, sim, synth"
        exit 1
        ;;
esac

echo ""
echo "=================================================================="
echo "  Local CI Stage [$STAGE] Completed Successfully!"
echo "=================================================================="

