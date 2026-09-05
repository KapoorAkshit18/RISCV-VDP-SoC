transcript on

delete wave *

# -----------------------------------------------------------------------------
# 2. Waveform appearance
# -----------------------------------------------------------------------------

configure wave -wavebackground white
configure wave -waveeventbackground white
configure wave -wavestripbackground white
configure wave -gridcolor grey50
configure wave -textcolor black
configure wave -timecolor black
configure wave -background white
configure wave -foreground black
configure wave -signalnamewidth 1
configure wave -namecolwidth 200

# ============================================================
# PHASE 1 - PRE-TPU BASELINE
# ============================================================

# ---------------- CLOCK / RESET ----------------
add wave -divider "CLOCK / RESET"
add wave -position insertpoint sim:/tb_top/clk
add wave -position insertpoint sim:/tb_top/resetn

# ---------------- u_cpu ----------------
add wave -divider "u_cpu / PicoRV32"
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/reg_pc
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/mem_valid
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/mem_ready
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/mem_instr
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/mem_addr
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/mem_wdata
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/mem_rdata
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/mem_wstrb
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/count_cycle
add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/count_instr

add wave -position insertpoint sim:/tb_top/dut/u_cpu/prv/dbg_ascii_instr

# ---------------- u_cpu ADAPTER ----------------
add wave -divider "u_cpu BUS ADAPTER"
add wave -position insertpoint sim:/tb_top/dut/u_adapter/*

# ---------------- INTERCONNECT ----------------
add wave -divider "MEMORY INTERCONNECT"
add wave -position insertpoint sim:/tb_top/dut/u_interconnect/*

# ---------------- RAM ----------------
add wave -divider "RAM"
add wave -position insertpoint sim:/tb_top/dut/u_ram/*

# ---------------- TESTBENCH ----------------
add wave -divider "TESTBENCH"
add wave -position insertpoint sim:/tb_top/*

# =============================================================================
# 16. RUN SIMULATION
# =============================================================================

run -all


# =============================================================================
# 17. FIT WAVEFORM TO WINDOW
# =============================================================================

wave zoom full