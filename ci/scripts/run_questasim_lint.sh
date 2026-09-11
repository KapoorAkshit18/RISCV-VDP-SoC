#!/usr/bin/env bash
# =============================================================================
# run_questasim_lint.sh
# QuestaSim lint and compilation syntax check for RISCV-VDP-SoC
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== [CI Stage 1] QuestaSim Lint & Compilation Check ==="

# 1. Locate QuestaSim
VLOG_BIN=""
VLIB_BIN=""

if command -v vlog &> /dev/null; then
    VLOG_BIN="$(command -v vlog)"
    VLIB_BIN="$(command -v vlib)"
elif [ -f "/c/questasim64_2024.1/win64/vlog.exe" ]; then
    VLOG_BIN="/c/questasim64_2024.1/win64/vlog.exe"
    VLIB_BIN="/c/questasim64_2024.1/win64/vlib.exe"
elif [ -n "${QUESTASIM_HOME:-}" ] && [ -f "$QUESTASIM_HOME/win64/vlog.exe" ]; then
    VLOG_BIN="$QUESTASIM_HOME/win64/vlog.exe"
    VLIB_BIN="$QUESTASIM_HOME/win64/vlib.exe"
else
    echo "ERROR: QuestaSim (vlog/vlib) not found in PATH or standard installation directory."
    echo "Please ensure QuestaSim is installed or add it to PATH."
    exit 1
fi

echo "Using vlog: $VLOG_BIN"
echo "Using vlib: $VLIB_BIN"

# 2. Setup build directory & work library
BUILD_DIR="$ROOT_DIR/build/questasim_lint"
mkdir -p "$BUILD_DIR"
rm -rf "$BUILD_DIR/work"

echo "Creating work library in $BUILD_DIR/work..."
"$VLIB_BIN" "$BUILD_DIR/work"

# 3. Source files to lint (All RTL directly from Design_Dir/RTL)
RTL_DIR="$ROOT_DIR/Design_Dir/RTL"
RTL_FILES=(
    "$RTL_DIR/riscv.v"
    "$RTL_DIR/riscv_wrapper.v"
    "$RTL_DIR/cpu_bus_adapter.v"
    "$RTL_DIR/soc_mem_interconnect.v"
    "$RTL_DIR/soc_ram.v"
    "$RTL_DIR/gpio_native_slave.v"
    "$RTL_DIR/rf_telemetry_native.v"
    "$RTL_DIR/sensor_status_native.v"
    "$RTL_DIR/vdp_native_slave.v"
    "$RTL_DIR/vga_timing_gen.v"
    "$RTL_DIR/cdc_reset_sync.v"
    "$RTL_DIR/pe.v"
    "$RTL_DIR/register.v"
    "$RTL_DIR/sigmoid.v"
    "$RTL_DIR/systolic.v"
    "$RTL_DIR/pe_top.v"
    "$RTL_DIR/nn.v"
    "$RTL_DIR/axis_nn.v"
    "$RTL_DIR/nn_axi_wrapper.v"
    "$RTL_DIR/nn_axis_master.v"
    "$RTL_DIR/tpu_axis_top.v"
    "$RTL_DIR/cpu_soc_ram_top.v"
)

TB_FILES=(
    "$ROOT_DIR/Design_Dir/Tb/tb_soc_ram_top.sv"
)

LINT_LOG="$BUILD_DIR/lint.log"

echo "Running QuestaSim vlog compilation and lint checks..."
set +e
"$VLOG_BIN" \
    -work "$BUILD_DIR/work" \
    -sv \
    -lint \
    "+incdir+$ROOT_DIR/Design_Dir/RTL" \
    "+incdir+$ROOT_DIR/Design_Dir/Tb" \
    "${RTL_FILES[@]}" \
    "${TB_FILES[@]}" \
    2>&1 | tee "$LINT_LOG"

EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "=========================================================="
    echo "  LINT CHECK FAILED: vlog returned exit code $EXIT_CODE"
    echo "=========================================================="
    exit $EXIT_CODE
fi

# Check for Error counts in log
if grep -q "Errors: [1-9]" "$LINT_LOG"; then
    echo "=========================================================="
    echo "  LINT CHECK FAILED: Errors found in vlog output."
    echo "=========================================================="
    exit 1
fi

echo "=========================================================="
echo "  SUCCESS: QuestaSim Lint & Compilation Passed (0 Errors)!"
echo "=========================================================="
exit 0
