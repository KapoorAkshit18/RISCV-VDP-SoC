# =============================================================================
# Makefile for Passive UVM Waveform Generation (Firmware Execution)
# RISCV-VDP-SoC — Phase 5 Old2New_SoC TPU Waveforms
# =============================================================================

# Tools
VLOG     ?= vlog
VLIB     ?= vlib
VMAP     ?= vmap
VOPT     ?= vopt
VSIM     ?= vsim

# External Paths
VIVADO   ?= C:/Xilinx/Vivado/2020.1
GLBL     := $(VIVADO)/data/verilog/src/glbl.v
XPM_LIB  ?= C:/projects/apb/apb.cache/compile_simlib/questa/xpm

# Target files & parameters
UVM_DIR  := C:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/Tb/UVM
WORK_DIR := $(UVM_DIR)/work
TOP      := tb_cpu_soc_ram_top
OPT_TOP  := tb_opt_passive_wave
FILELIST := filelist.f
DO_FILE  := C:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/waveform_results/tpu_inference_wave.do

# DPI C reference model library path
TPU_REF  := $(UVM_DIR)/tb/soc_scoreboard/tpu_ref
FIRMWARE := C:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/firmware_test03/firmware.hex

VLOG_OPTS := -sv +acc
VOPT_OPTS := +acc -L xpm

# Simulation options for PASSIVE UVM (CPU runs firmware, UVM observes)
VSIM_ARGS := -sv_lib $(TPU_REF) \
             +UVM_TESTNAME=soc_tpu_test \
             +UVM_MODE=FIRMWARE \
             +FW_HEX=$(FIRMWARE) \
             +UVM_VERBOSITY=UVM_MEDIUM

.PHONY: all work compile mapxpm optimize wave gui clean help

all: wave

# 1. Create work library inside UVM directory context
work:
	@cd $(UVM_DIR) && if [ ! -d "work" ]; then $(VLIB) work; fi
	@cd $(UVM_DIR) && $(VMAP) work work

# 2. Compile UVM and RTL filelist from UVM_DIR so all relative paths resolve
compile: work
	@cd $(UVM_DIR) && $(VLOG) $(VLOG_OPTS) -f $(FILELIST)
	@cd $(UVM_DIR) && $(VLOG) $(GLBL)

# 3. Map XPM library
mapxpm:
	@cd $(UVM_DIR) && $(VMAP) xpm "$(XPM_LIB)"

# 4. Optimize design (+acc keeps internal DUT signals visible for waveform)
optimize: compile mapxpm
	@cd $(UVM_DIR) && $(VOPT) $(VOPT_OPTS) \
		work.$(TOP) \
		work.glbl \
		-o $(OPT_TOP)

# 5. Launch Passive UVM simulation with waveform script
wave: optimize
	@cd $(UVM_DIR) && $(VSIM) $(OPT_TOP) $(VSIM_ARGS) -do "do $(DO_FILE);"

# Interactive GUI session
gui: optimize
	@cd $(UVM_DIR) && $(VSIM) $(OPT_TOP) $(VSIM_ARGS) -do "do $(DO_FILE);"

# Clean artifacts
clean:
	@cd $(UVM_DIR) && rm -rf work transcript *.wlf *.log

help:
	@echo "Available Targets:"
	@echo "  make wave  - Compile and run Passive UVM simulation with waveform zoom"
	@echo "  make gui   - Open QuestaSim GUI with Passive UVM and DO script loaded"
	@echo "  make clean - Clean simulation artifacts"
