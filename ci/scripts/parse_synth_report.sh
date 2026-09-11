#!/usr/bin/env bash
# =============================================================================
# parse_synth_report.sh
# Parses Vivado utilization & timing reports using bash/awk (No Python required)
# =============================================================================

set -euo pipefail

REPORT_DIR="${1:-ci/vivado/reports}"
UTIL_RPT="$REPORT_DIR/utilization.rpt"
TIMING_RPT="$REPORT_DIR/timing_summary.rpt"

TOP_MODULE="${VIVADO_TOP_MODULE:-cpu_soc_ram_top}"
PART="${VIVADO_PART:-xc7z020clg484-1}"

# Initialize default values
LUT_USED="N/A"; LUT_AVAIL="N/A"; LUT_UTIL="N/A"
FF_USED="N/A";  FF_AVAIL="N/A";  FF_UTIL="N/A"
BRAM_USED="N/A"; BRAM_AVAIL="N/A"; BRAM_UTIL="N/A"
DSP_USED="N/A";  DSP_AVAIL="N/A";  DSP_UTIL="N/A"

WNS="N/A"; TNS="N/A"; WHS="N/A"; THS="N/A"
TIMING_STATUS="UNKNOWN"

if [ -f "$UTIL_RPT" ]; then
    # Parse Slice LUTs
    LUT_LINE=$(grep -E '\|\s*Slice LUTs\*?\s*\|' "$UTIL_RPT" | head -n 1 || true)
    if [ -n "$LUT_LINE" ]; then
        LUT_USED=$(echo "$LUT_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
        LUT_AVAIL=$(echo "$LUT_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
        LUT_UTIL=$(echo "$LUT_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')"%"
    fi

    # Parse Slice Registers
    FF_LINE=$(grep -E '\|\s*Slice Registers\s*\|' "$UTIL_RPT" | head -n 1 || true)
    if [ -n "$FF_LINE" ]; then
        FF_USED=$(echo "$FF_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
        FF_AVAIL=$(echo "$FF_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
        FF_UTIL=$(echo "$FF_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')"%"
    fi

    # Parse Block RAM
    BRAM_LINE=$(grep -E '\|\s*Block RAM Tile\s*\|' "$UTIL_RPT" | head -n 1 || true)
    if [ -n "$BRAM_LINE" ]; then
        BRAM_USED=$(echo "$BRAM_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
        BRAM_AVAIL=$(echo "$BRAM_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
        BRAM_UTIL=$(echo "$BRAM_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')"%"
    fi

    # Parse DSPs
    DSP_LINE=$(grep -E '\|\s*DSPs\s*\|' "$UTIL_RPT" | head -n 1 || true)
    if [ -n "$DSP_LINE" ]; then
        DSP_USED=$(echo "$DSP_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
        DSP_AVAIL=$(echo "$DSP_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $5); print $5}')
        DSP_UTIL=$(echo "$DSP_LINE" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $6); print $6}')"%"
    fi
fi

if [ -f "$TIMING_RPT" ]; then
    if grep -q "All user specified timing constraints are met." "$TIMING_RPT"; then
        TIMING_STATUS="PASSED (MET)"
    elif grep -q "Timing constraints are not met." "$TIMING_RPT"; then
        TIMING_STATUS="FAILED (VIOLATED)"
    else
        TIMING_STATUS="N/A"
    fi

    # Look for WNS
    WNS_LINE=$(grep -A 2 "WNS(ns)" "$TIMING_RPT" | tail -n 1 || true)
    if [ -n "$WNS_LINE" ]; then
        WNS=$(echo "$WNS_LINE" | awk '{print $1}')" ns"
        TNS=$(echo "$WNS_LINE" | awk '{print $2}')" ns"
        WHS=$(echo "$WNS_LINE" | awk '{print $5}')" ns"
        THS=$(echo "$WNS_LINE" | awk '{print $6}')" ns"
    fi
fi

# Build Markdown Output
MD_OUTPUT=$(cat <<EOF
## 🚀 Vivado Local Synthesis Results

- **Top Module**: \`$TOP_MODULE\`
- **Target Part**: \`$PART\`
- **Timing Closure**: **$TIMING_STATUS**
- **Worst Negative Slack (WNS)**: \`$WNS\`
- **Worst Hold Slack (WHS)**: \`$WHS\`

### Resource Utilization Summary

| Resource | Used | Available | Utilization |
| :--- | :--- | :--- | :--- |
| **Slice LUTs** | $LUT_USED | $LUT_AVAIL | $LUT_UTIL |
| **Slice Registers (FF)** | $FF_USED | $FF_AVAIL | $FF_UTIL |
| **Block RAM (BRAM)** | $BRAM_USED | $BRAM_AVAIL | $BRAM_UTIL |
| **DSP48 Slices** | $DSP_USED | $DSP_AVAIL | $DSP_UTIL |
EOF
)

echo ""
echo "=================================================================="
echo "$MD_OUTPUT"
echo "=================================================================="
echo ""

# Write to GITHUB_STEP_SUMMARY if available
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "$MD_OUTPUT" >> "$GITHUB_STEP_SUMMARY"
    echo "Appended synthesis summary to \$GITHUB_STEP_SUMMARY"
fi

