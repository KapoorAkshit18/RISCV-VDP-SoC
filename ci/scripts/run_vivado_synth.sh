#!/usr/bin/env bash
# =============================================================================
# run_vivado_synth.sh
# Automated batch Vivado synthesis runner for RISCV-VDP-SoC
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== [CI Stage 3] Local Vivado FPGA Synthesis ==="

# 1. Locate Vivado
VIVADO_BIN=""

if command -v vivado &> /dev/null; then
    VIVADO_BIN="$(command -v vivado)"
elif [ -f "/c/Xilinx/Vivado/2020.1/bin/vivado.bat" ]; then
    VIVADO_BIN="/c/Xilinx/Vivado/2020.1/bin/vivado.bat"
elif [ -n "${XILINX_VIVADO:-}" ] && [ -f "$XILINX_VIVADO/bin/vivado.bat" ]; then
    VIVADO_BIN="$XILINX_VIVADO/bin/vivado.bat"
else
    echo "ERROR: Vivado not found in PATH or standard directory (C:/Xilinx/Vivado/2020.1)."
    echo "Please ensure Vivado is installed on this machine."
    exit 1
fi

echo "Using Vivado: $VIVADO_BIN"

# 2. Output and Working Directories
OUTPUT_DIR="${VIVADO_OUTPUT_DIR:-$ROOT_DIR/ci/vivado/reports}"
BUILD_DIR="$ROOT_DIR/build/vivado"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

TCL_SCRIPT="$ROOT_DIR/ci/vivado/synth_soc.tcl"
SYNTH_LOG="$BUILD_DIR/vivado_synth.log"

# Convert paths for Windows native tools if cygpath exists
if command -v cygpath &> /dev/null; then
    WIN_OUTPUT_DIR="$(cygpath -m "$OUTPUT_DIR")"
    WIN_TCL_SCRIPT="$(cygpath -m "$TCL_SCRIPT")"
else
    WIN_OUTPUT_DIR="$OUTPUT_DIR"
    WIN_TCL_SCRIPT="$TCL_SCRIPT"
fi

export VIVADO_OUTPUT_DIR="$WIN_OUTPUT_DIR"
export VIVADO_TOP_MODULE="${VIVADO_TOP_MODULE:-cpu_soc_ram_top}"
export VIVADO_PART="${VIVADO_PART:-xc7z020clg484-1}"

echo "Starting Vivado synthesis for $VIVADO_TOP_MODULE on $VIVADO_PART..."
set +e
"$VIVADO_BIN" -mode batch -nojournal -nolog -source "$WIN_TCL_SCRIPT" 2>&1 | tee "$SYNTH_LOG"
SYNTH_EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ $SYNTH_EXIT_CODE -ne 0 ]; then
    echo "=========================================================="
    echo "  VIVADO SYNTHESIS FAILED (Exit Code: $SYNTH_EXIT_CODE)"
    echo "  Check log: $SYNTH_LOG"
    echo "=========================================================="
    exit $SYNTH_EXIT_CODE
fi

echo "=========================================================="
echo "  Vivado Synthesis Completed Successfully!"
echo "=========================================================="

# 3. Parse and display report summary
PARSER_SCRIPT="$ROOT_DIR/ci/scripts/parse_synth_report.sh"
if [ -f "$PARSER_SCRIPT" ]; then
    echo "Extracting resource utilization and timing metrics..."
    bash "$PARSER_SCRIPT" "$OUTPUT_DIR" || true
fi

exit 0

