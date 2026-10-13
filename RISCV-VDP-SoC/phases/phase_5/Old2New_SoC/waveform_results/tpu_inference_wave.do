# =============================================================================
# tpu_inference_wave.do
#
# Clean, Publication-Grade Waveform Script for RISCV-VDP-SoC
# Mode: PASSIVE UVM (Firmware Execution) with RISC-V ASCII Instruction Trace
# Target: Direct DUT Internal Hierarchy (sim:/tb_cpu_soc_ram_top/dut)
# =============================================================================

view wave
delete wave *

# -----------------------------------------------------------------------------
# 1. Publication-Ready Appearance Configuration
# -----------------------------------------------------------------------------
configure wave -wavebackground white
configure wave -waveeventbackground white
configure wave -wavestripbackground white
configure wave -gridcolor grey80
configure wave -textcolor black
configure wave -timecolor black
configure wave -namecolwidth 220
configure wave -valuecolwidth 110
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

# -----------------------------------------------------------------------------
# GROUP 1: CLOCK & RESET (DUT Boundary)
# -----------------------------------------------------------------------------
add wave -divider "CLOCK & RESET"
add wave -noupdate -color {Grey30}          sim:/tb_cpu_soc_ram_top/dut/clk
add wave -noupdate -color {Grey30}          sim:/tb_cpu_soc_ram_top/dut/resetn

# -----------------------------------------------------------------------------
# GROUP 2: RISC-V CPU EXECUTION & DECODED INSTRUCTIONS (ASCII Radix)
# -----------------------------------------------------------------------------
add wave -divider "RISC-V CPU EXECUTION"
add wave -noupdate -color {Dark Blue} -radix hexadecimal sim:/tb_cpu_soc_ram_top/dut/u_cpu/prv/reg_pc
add wave -noupdate -color {Dark Green} -radix ascii       sim:/tb_cpu_soc_ram_top/dut/u_cpu/prv/dbg_ascii_instr
add wave -noupdate -color {Dark Blue} -radix ascii       sim:/tb_cpu_soc_ram_top/dut/u_cpu/prv/dbg_ascii_state
add wave -noupdate -color {Grey40}    -radix unsigned    sim:/tb_cpu_soc_ram_top/dut/u_cpu/prv/count_instr

# -----------------------------------------------------------------------------
# GROUP 3: SOC INTERCONNECT TO TPU INTERFACE
# -----------------------------------------------------------------------------
add wave -divider "INTERCONNECT TO TPU"
add wave -noupdate -color {Dark Blue}       sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_sel
add wave -noupdate -color {Dark Blue}       sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_valid
add wave -noupdate -color {Dark Blue}       sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_write
add wave -noupdate -color {Dark Green} -radix hexadecimal sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_addr
add wave -noupdate -color {Dark Green} -radix hexadecimal sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_wdata
add wave -noupdate -color {Dark Blue}       sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_ready
add wave -noupdate -color {Dark Green} -radix hexadecimal sim:/tb_cpu_soc_ram_top/dut/u_interconnect/nn_rdata

# -----------------------------------------------------------------------------
# GROUP 4: TPU COMPUTE LIFECYCLE (MMIO / Control FSM)
# -----------------------------------------------------------------------------
add wave -divider "TPU COMPUTE LIFECYCLE"
add wave -noupdate -color {Red}             sim:/tb_cpu_soc_ram_top/dut/tpu/axis_start
add wave -noupdate -color {Orange}          sim:/tb_cpu_soc_ram_top/dut/tpu/axis_busy
add wave -noupdate -color {Blue}            sim:/tb_cpu_soc_ram_top/dut/tpu/axis_done

# -----------------------------------------------------------------------------
# GROUP 5: AXI4-STREAM STREAMING INTERFACE (Internal Systolic Pipe)
# -----------------------------------------------------------------------------
add wave -divider "STREAMING COMPUTE INTERFACE"
add wave -noupdate -color {Medium Blue}     sim:/tb_cpu_soc_ram_top/dut/tpu/in_tvalid
add wave -noupdate -color {Medium Blue}     sim:/tb_cpu_soc_ram_top/dut/tpu/in_tready
add wave -noupdate -color {Purple} -radix hexadecimal sim:/tb_cpu_soc_ram_top/dut/tpu/in_tdata
add wave -noupdate -color {Medium Blue}     sim:/tb_cpu_soc_ram_top/dut/tpu/in_tlast

add wave -noupdate -color {Dark Cyan}       sim:/tb_cpu_soc_ram_top/dut/tpu/out_tvalid
add wave -noupdate -color {Dark Cyan}       sim:/tb_cpu_soc_ram_top/dut/tpu/out_tready
add wave -noupdate -color {Purple} -radix hexadecimal sim:/tb_cpu_soc_ram_top/dut/tpu/out_tdata
add wave -noupdate -color {Dark Cyan}       sim:/tb_cpu_soc_ram_top/dut/tpu/out_tlast

# -----------------------------------------------------------------------------
# GROUP 6: TPU INFERENCE RESULTS
# -----------------------------------------------------------------------------
add wave -divider "TPU INFERENCE RESULTS"
add wave -noupdate -color {Forest Green} -radix hexadecimal sim:/tb_cpu_soc_ram_top/dut/tpu/result0
add wave -noupdate -color {Forest Green} -radix hexadecimal sim:/tb_cpu_soc_ram_top/dut/tpu/result1

# -----------------------------------------------------------------------------
# 2. RUN SIMULATION TO CAPTURE TRACES
# -----------------------------------------------------------------------------
run -all

# -----------------------------------------------------------------------------
# 3. Cursors & Automatic Zoom for Inference Window
# -----------------------------------------------------------------------------
WaveRestoreCursors {START {3885 ns} 1 {Dark Red}} {DONE {4435 ns} 1 {Dark Blue}}
quietly wave cursor active 1

WaveRestoreZoom {3800 ns} {4600 ns}

update
