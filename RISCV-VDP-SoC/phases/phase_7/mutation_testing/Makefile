# ============================================================
# Phase 7 — Mutation Testing Makefile
#
# Both directed and UVM flows use the SAME full-SoC DUT
# (cpu_soc_ram_top) with firmware loaded via $readmemh.
#
# Two firmware images:
#   FW1 (firmware_test03) — TPU firmware: CPU, RAM, TPU
#   FW2 (firmware_test_04) — Sensor firmware: CPU, RAM, Sensor
#
# Usage:
#   make mutation_directed MUTANT=M01 FW=<path>
#   make mutation_uvm      MUTANT=M01 FW=<path> TEST=<uvm_test>
#
#   make run_m01  — Full M01 validation (both FW, both flows)
#   make batch    — All mutants M01–M10
# ============================================================

# ---------------------------------------------------------------
# Paths
# ---------------------------------------------------------------
PHASE7        = $(CURDIR)/..
PHASE5        = $(PHASE7)/../phase_5/Old2New_SoC
PHASE5_UVM    = $(PHASE5)/Tb/UVM
FAULT_MODELS  = $(PHASE7)/fault_models
MUTANTS_DIR   = $(CURDIR)/mutants/soc_mem_interconnect
LOGS_DIR      = $(CURDIR)/logs
GOLDEN_BACKUP = $(CURDIR)/golden/soc_mem_interconnect_golden.v
GOLDEN_TARGET = $(FAULT_MODELS)/soc_mem_interconnect.v
RESULTS_DIR   = $(CURDIR)/results

# Firmware paths (relative to this working directory)
FW1 = ../../phase_5/Old2New_SoC/firmware_test03/firmware.hex
FW2 = ../../phase_5/Old2New_SoC/firmware_test_04/firmware.hex

# ---------------------------------------------------------------
# Tools
# ---------------------------------------------------------------
VLOG = vlog
VLIB = vlib
VMAP = vmap
VOPT = vopt
VSIM = vsim

# ---------------------------------------------------------------
# Xilinx / XPM
# ---------------------------------------------------------------
VIVADO  ?= C:/Xilinx/Vivado/2020.1
GLBL    := $(VIVADO)/data/verilog/src/glbl.v
XPM_LIB ?= C:/projects/apb/apb.cache/compile_simlib/questa/xpm

# ---------------------------------------------------------------
# UVM configuration
# ---------------------------------------------------------------
UVM_TOP      = tb_cpu_soc_ram_top
UVM_OPT_TOP  = tb_uvm_opt_mut
UVM_FILELIST = filelist_uvm.f
UVM_TPU_REF  = $(PHASE5_UVM)/tb/soc_scoreboard/tpu_ref

# ---------------------------------------------------------------
# Directed configuration
# ---------------------------------------------------------------
DIR_TOP      = tb_cpu_soc_ram_top
DIR_OPT_TOP  = tb_dir_opt_mut
DIR_FILELIST = filelist_directed.f

# ---------------------------------------------------------------
# Per-run overrides
# ---------------------------------------------------------------
MUTANT  ?=
FW      ?=
TEST    ?= soc_sensor_test
BATT    ?= 10
TEMP_C  ?= 85.0

FW_ARG  = $(if $(FW),+FW_HEX=$(FW),)

TEST_ARGS = +UVM_TESTNAME=$(TEST) $(FW_ARG) +BATT=$(BATT) +TEMP_C=$(TEMP_C) \
            +UVM_VERBOSITY=UVM_NONE

DIR_ARGS  = $(FW_ARG) +BATT=$(BATT) +TEMP_C=$(TEMP_C)

# Golden checksum
GOLDEN_SHA256 = 7695FBE6D53A69E15B80F3DDDF57C520CA2ABE7B0204E1118577425519100D3E


# ============================================================
# Default
# ============================================================

all: help

help:
	@echo ""
	@echo "Phase 7 — Mutation Testing Makefile"
	@echo "===================================="
	@echo ""
	@echo "  DIRECTED (firmware-driven, full SoC):"
	@echo "    make mutation_directed MUTANT=M01 FW=$(FW1)"
	@echo "    make mutation_directed MUTANT=M01 FW=$(FW2)"
	@echo ""
	@echo "  UVM (firmware-driven, full SoC):"
	@echo "    make mutation_uvm MUTANT=M01 FW=$(FW1) TEST=soc_tpu_test"
	@echo "    make mutation_uvm MUTANT=M01 FW=$(FW2) TEST=soc_sensor_test"
	@echo ""
	@echo "  FULL CAMPAIGN:"
	@echo "    make run_m01    — Full M01 validation (both FW, both flows)"
	@echo "    make batch      — All mutants M01-M10"
	@echo ""
	@echo "  UTILITIES:"
	@echo "    make golden_check  — Verify golden RTL integrity"
	@echo "    make inject MUTANT=M01"
	@echo "    make restore"
	@echo "    make clean"
	@echo ""


# ============================================================
# Golden Integrity Check
# ============================================================

golden_check:
	@echo "=== Checking golden RTL integrity ==="
	@powershell -Command " \
		$$h = (Get-FileHash '$(GOLDEN_TARGET)' -Algorithm SHA256).Hash; \
		if ($$h -eq '$(GOLDEN_SHA256)') { \
			Write-Host 'GOLDEN CHECK: PASS'; \
		} else { \
			Write-Host 'GOLDEN CHECK: FAIL'; \
			Write-Host \"Expected: $(GOLDEN_SHA256)\"; \
			Write-Host \"Got:      $$h\"; \
			exit 1; \
		}"


# ============================================================
# Mutant Injection / Restoration
# ============================================================

inject:
ifndef MUTANT
	$(error MUTANT not set. Usage: make inject MUTANT=M01)
endif
	@echo "=== Injecting mutant $(MUTANT) ==="
	powershell -Command "Copy-Item '$(MUTANTS_DIR)/$(MUTANT)*.v' '$(GOLDEN_TARGET)' -Force"
	@echo "Mutant $(MUTANT) injected."

restore:
	@echo "=== Restoring golden ==="
	powershell -Command "Copy-Item '$(GOLDEN_BACKUP)' '$(GOLDEN_TARGET)' -Force"
	@echo "Golden restored."


# ============================================================
# DIRECTED — Compile + Optimize
# ============================================================

directed_compile:
	@if [ ! -d work_directed ]; then $(VLIB) work_directed; fi
	$(VLOG) -sv +acc -work work_directed -f $(DIR_FILELIST)
	$(VLOG) $(GLBL) -work work_directed
	$(VMAP) xpm "$(XPM_LIB)"
	$(VOPT) +acc -L xpm \
		work_directed.$(DIR_TOP) \
		work_directed.glbl \
		-o $(DIR_OPT_TOP) -work work_directed


# ============================================================
# DIRECTED — Run
# ============================================================

directed_run:
	$(VSIM) -c $(DIR_OPT_TOP) -work work_directed \
		$(DIR_ARGS) \
		-do "run -all; quit -f"


# ============================================================
# DIRECTED — Full mutation flow
#   make mutation_directed MUTANT=M01 FW=<path>
# ============================================================

mutation_directed: inject directed_compile directed_run


# ============================================================
# UVM — Compile + Optimize
# ============================================================

uvm_compile:
	@if [ ! -d work_uvm ]; then $(VLIB) work_uvm; fi
	$(VLOG) -sv +acc -work work_uvm -f $(UVM_FILELIST)
	$(VLOG) $(GLBL) -work work_uvm
	$(VMAP) xpm "$(XPM_LIB)"
	$(VOPT) +acc -L xpm \
		work_uvm.$(UVM_TOP) \
		work_uvm.glbl \
		-o $(UVM_OPT_TOP) -work work_uvm


# ============================================================
# UVM — Run
# ============================================================

uvm_run:
	$(VSIM) -c -sv_lib $(UVM_TPU_REF) \
		$(UVM_OPT_TOP) -work work_uvm \
		$(TEST_ARGS) \
		-do "run -all; quit -f"


# ============================================================
# UVM — Full mutation flow
#   make mutation_uvm MUTANT=M01 FW=<path> TEST=<uvm_test>
# ============================================================

mutation_uvm: inject uvm_compile uvm_run


# ============================================================
# M01 MANUAL VALIDATION — All 4 combinations
# ============================================================

run_m01:
	@echo "========================================"
	@echo "M01 VALIDATION: 4 runs"
	@echo "========================================"
	@echo ""
	@echo "--- [1/4] Directed + FW1 (TPU) ---"
	-$(MAKE) mutation_directed MUTANT=M01 FW=$(FW1) 2>&1 | tee $(LOGS_DIR)/directed/M01_directed_fw1.log
	$(MAKE) restore
	$(MAKE) golden_check
	@echo ""
	@echo "--- [2/4] Directed + FW2 (Sensor) ---"
	-$(MAKE) mutation_directed MUTANT=M01 FW=$(FW2) 2>&1 | tee $(LOGS_DIR)/directed/M01_directed_fw2.log
	$(MAKE) restore
	$(MAKE) golden_check
	@echo ""
	@echo "--- [3/4] UVM + FW1 (TPU) ---"
	-$(MAKE) mutation_uvm MUTANT=M01 FW=$(FW1) TEST=soc_tpu_test 2>&1 | tee $(LOGS_DIR)/uvm/M01_uvm_fw1.log
	$(MAKE) restore
	$(MAKE) golden_check
	@echo ""
	@echo "--- [4/4] UVM + FW2 (Sensor) ---"
	-$(MAKE) mutation_uvm MUTANT=M01 FW=$(FW2) TEST=soc_sensor_test 2>&1 | tee $(LOGS_DIR)/uvm/M01_uvm_fw2.log
	$(MAKE) restore
	$(MAKE) golden_check
	@echo ""
	@echo "========================================"
	@echo "M01 VALIDATION COMPLETE"
	@echo "========================================"


# ============================================================
# Clean
# ============================================================

clean:
	rm -rf work_directed work_uvm
	rm -rf transcript vsim.wlf *.log *.ucdb
	rm -rf waveform*.vcd modelsim.ini


.PHONY: all help golden_check inject restore \
        directed_compile directed_run mutation_directed \
        uvm_compile uvm_run mutation_uvm \
        run_m01 batch clean
