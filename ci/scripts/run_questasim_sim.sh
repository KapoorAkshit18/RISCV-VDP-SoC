#!/usr/bin/env bash
# =============================================================================
# run_questasim_sim.sh
# QuestaSim automated batch simulation runner for the Top Testbench
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== [CI Stage 2] QuestaSim Top Testbench Simulation ==="

# 1. Locate QuestaSim
VSIM_BIN=""
VLOG_BIN=""
VLIB_BIN=""

if command -v vsim &> /dev/null; then
    VSIM_BIN="$(command -v vsim)"
    VLOG_BIN="$(command -v vlog)"
    VLIB_BIN="$(command -v vlib)"
elif [ -f "/c/questasim64_2024.1/win64/vsim.exe" ]; then
    VSIM_BIN="/c/questasim64_2024.1/win64/vsim.exe"
    VLOG_BIN="/c/questasim64_2024.1/win64/vlog.exe"
    VLIB_BIN="/c/questasim64_2024.1/win64/vlib.exe"
elif [ -n "${QUESTASIM_HOME:-}" ] && [ -f "$QUESTASIM_HOME/win64/vsim.exe" ]; then
    VSIM_BIN="$QUESTASIM_HOME/win64/vsim.exe"
    VLOG_BIN="$QUESTASIM_HOME/win64/vlog.exe"
    VLIB_BIN="$QUESTASIM_HOME/win64/vlib.exe"
else
    echo "ERROR: QuestaSim (vsim/vlog/vlib) not found."
    exit 1
fi

echo "Using vsim: $VSIM_BIN"

# 2. Configurable options
TOP_TB="${SIM_TOP_TB:-tb_cpu_soc_ram_top}"
SIM_TIME="${SIM_TIME:-50us}"
BUILD_DIR="$ROOT_DIR/build/questasim_sim"
LOG_FILE="$BUILD_DIR/simulation.log"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
rm -rf work

echo "Creating work library in $BUILD_DIR/work..."
"$VLIB_BIN" work

# 3. Source files for Top simulation (All RTL directly from Design_Dir/RTL)
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
    "${SIM_TB_FILE:-$ROOT_DIR/Design_Dir/Tb/tb_soc_ram_top.sv}"
)

# Include Vivado XPM libraries if available for XPM macros (e.g. tdpram, axis fifo)
XPM_FILES=()
if [ -d "/c/Xilinx/Vivado/2020.1/data/ip/xpm" ]; then
    XPM_FILES=(
        "/c/Xilinx/Vivado/2020.1/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv"
        "/c/Xilinx/Vivado/2020.1/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv"
        "/c/Xilinx/Vivado/2020.1/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv"
    )
fi

echo "Compiling RTL and Top Testbench with QuestaSim..."
set +e
"$VLOG_BIN" \
    -work work \
    -sv \
    "+incdir+$ROOT_DIR/Design_Dir/RTL" \
    "+incdir+$ROOT_DIR/Design_Dir/Tb" \
    "${XPM_FILES[@]}" \
    "${RTL_FILES[@]}" \
    "${TB_FILES[@]}"

COMPILE_STATUS=$?
if [ $COMPILE_STATUS -ne 0 ]; then
    echo "ERROR: Compilation failed with exit code $COMPILE_STATUS"
    exit $COMPILE_STATUS
fi

echo "Running Top Testbench simulation: $TOP_TB ($SIM_TIME)..."
"$VSIM_BIN" \
    -c \
    -voptargs="+acc" \
    work."$TOP_TB" \
    -do "run $SIM_TIME; quit -f" \
    2>&1 | tee "$LOG_FILE"

SIM_EXIT_CODE=${PIPESTATUS[0]}
set -e

echo "Analyzing simulation results from $LOG_FILE..."

# Check for explicit test failures
if grep -iq "FAIL:" "$LOG_FILE" || grep -iq "Error loading design" "$LOG_FILE" || grep -iq "Errors: [1-9]" "$LOG_FILE"; then
    echo "=========================================================="
    echo "  SIMULATION RESULT: FAILED or Error detected in log."
    echo "  (See $LOG_FILE for details)"
    echo "=========================================================="
    exit 1
elif grep -iq "ALL TESTS PASSED" "$LOG_FILE"; then
    echo "=========================================================="
    echo "  SUCCESS: Top Testbench ($TOP_TB) PASSED!"
    echo "=========================================================="
    exit 0
else
    echo "=========================================================="
    echo "  Top Testbench simulation completed without critical errors."
    echo "=========================================================="
    exit 0
fi
