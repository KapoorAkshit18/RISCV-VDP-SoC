# ============================================================
# RISCV-VDP-SoC — Questa UVM Makefile
# ============================================================

TOP  	 = tb_cpu_soc_ram_top
OPT_TOP  = tb_uvm_opt
FILELIST = filelist.f

VLOG     = vlog
VLIB     = vlib
VMAP     = vmap
VOPT     = vopt
VSIM     = vsim -sv_lib C:/RISCV-VDP-SoC/RISCV-VDP-SoC/phases/phase_5/Old2New_SoC/Tb/UVM/tb/soc_scoreboard/tpu_ref

COV_RPT = coverage_report.txt

VLOG_OPTS = -sv +acc

# -----------------------------------------------------------------------------
# Xilinx Vivado 2020.1 — needed for glbl.v (xpm_cdc references glbl.GSR)
# -----------------------------------------------------------------------------

VIVADO ?= C:/Xilinx/Vivado/2020.1
GLBL    := $(VIVADO)/data/verilog/src/glbl.v

# -----------------------------------------------------------------------------
# XPM pre-compiled library
# -----------------------------------------------------------------------------

XPM_LIB ?= C:/projects/apb/apb.cache/compile_simlib/questa/xpm

VOPT_OPTS = +acc -L xpm

VSIM_OPTS = -c -sv_lib tpu_ref

# -----------------------------------------------------------------------------
# Per-test overrides (defaults are the sensor test's values)
#
#   make run   TEST=soc_sensor_test FW=<sensor>.hex BATT=10 TEMP_C=85.0
#   make run   TEST=soc_tpu_test    FW=<tpu>.hex
#
# TOP module reads FW via +FW_HEX; falls back to its own hardcoded default
# if FW is left empty here.
# -----------------------------------------------------------------------------

TEST    ?= soc_sensor_test
FW      ?=
BATT    ?= 10
TEMP_C  ?= 85.0
COV_DB  ?= $(TEST).ucdb

FW_ARG  = $(if $(FW),+FW_HEX=$(FW),)

TEST_ARGS = +UVM_TESTNAME=$(TEST) $(FW_ARG) +BATT=$(BATT) +TEMP_C=$(TEMP_C) \
            +UVM_VERBOSITY=UVM_MEDIUM


# ============================================================
# Default
# ============================================================

all: run


# ============================================================
# Work library
# ============================================================

work:
	@if [ ! -d work ]; then $(VLIB) work; fi
	$(VMAP) work work


# ============================================================
# Compile
# ============================================================

compile: work
	$(VLOG) $(VLOG_OPTS) -f $(FILELIST)
	$(VLOG) $(GLBL)


# ============================================================
# Map XPM library
# ============================================================

mapxpm:
	$(VMAP) xpm "$(XPM_LIB)"


# ============================================================
# Optimize (links xpm + glbl for TPU/AXIS hierarchy)
# ============================================================

optimize: compile mapxpm
	$(VOPT) $(VOPT_OPTS) \
		work.$(TOP) \
		work.glbl \
		-o $(OPT_TOP)


# ============================================================
# Run Test — generic, uses TEST/FW/BATT/TEMP_C above
# ============================================================

run: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		$(TEST_ARGS) \
		-do "run -all; quit -f"


# ============================================================
# TPU-focused test
# ============================================================

tpu: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_tpu_test \
		$(if $(FW),+FW_HEX=$(FW),) \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-do "run -all; quit -f"


# ============================================================
# SENSOR-focused test
# ============================================================

sensor: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_sensor_test \
		$(if $(FW),+FW_HEX=$(FW),) \
		+BATT=$(BATT) +TEMP_C=$(TEMP_C) \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-do "run -all; quit -f"


# ============================================================
# Functional Coverage — per test, own UCDB so runs don't clobber
# each other; use coverage_tpu / coverage_sensor, or coverage
# with TEST=<name> for anything else.
# ============================================================

coverage: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		$(TEST_ARGS) \
		-coverage \
		-do "coverage save -onexit $(COV_DB); run -all; quit -f"

coverage_tpu: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_tpu_test \
		$(if $(FW),+FW_HEX=$(FW),) \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-coverage \
		-do "coverage save -onexit soc_tpu_test.ucdb; run -all; quit -f"

coverage_sensor: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_sensor_test \
		$(if $(FW),+FW_HEX=$(FW),) \
		+BATT=$(BATT) +TEMP_C=$(TEMP_C) \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-coverage \
		-do "coverage save -onexit soc_sensor_test.ucdb; run -all; quit -f"

coverage_report: coverage
	vcover report $(COV_DB) -details -output $(COV_RPT)

coverage_summary: coverage
	vcover report $(COV_DB)


# ============================================================
# Merge coverage across tests (run coverage_tpu + coverage_sensor
# first, or any other *.ucdb you've saved)
# ============================================================

MERGED_DB = merged.ucdb

merge:
	vcover merge $(MERGED_DB) soc_tpu_test.ucdb soc_sensor_test.ucdb

merge_report: merge
	vcover report $(MERGED_DB) -details -output merged_$(COV_RPT)

merge_summary: merge
	vcover report $(MERGED_DB)


# ============================================================
# Debug (interactive, no -c)
# ============================================================

debug: optimize
	$(VSIM) -voptargs=+acc \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_smoke_test \
		+UVM_VERBOSITY=UVM_HIGH -do run.do


# ============================================================
# Clean
# ============================================================

clean:
	rm -rf work
	rm -rf transcript
	rm -rf vsim.wlf
	rm -rf *.log
	rm -rf *.ucdb
	rm -f $(COV_RPT) merged_$(COV_RPT)


# ============================================================
# Rebuild
# ============================================================

rebuild: clean all


.PHONY: all work compile mapxpm optimize run tpu sensor \
        coverage coverage_tpu coverage_sensor coverage_report coverage_summary \
        merge merge_report merge_summary debug clean rebuild