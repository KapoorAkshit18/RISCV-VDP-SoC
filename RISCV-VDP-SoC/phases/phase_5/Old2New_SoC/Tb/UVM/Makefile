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
SEED    ?= 1
NOISE   ?= 0
COV_DB  ?= $(TEST).ucdb

FW_ARG    = $(if $(FW),+FW_HEX=$(FW),)
NOISE_ARG = $(if $(filter 1,$(NOISE)),+NOISE_ON,)

TEST_ARGS = +UVM_TESTNAME=$(TEST) $(FW_ARG) +BATT=$(BATT) +TEMP_C=$(TEMP_C) \
            $(NOISE_ARG) +UVM_VERBOSITY=UVM_MEDIUM

# Temperature sweep list for sweep_temp / results (degC)
TEMP_LIST ?= -40 0 25 79.9 80.1 85 125

# Seed list for sweep_temp - multiple seeds per temperature give real
# variance on `seed` (and, with NOISE=1, on the noise itself) instead of
# every row sharing one frozen seed.
SEED_LIST ?= 1 2 3

# Battery and noise lists for the full factorial sweep (sweep_full below).
# Keep these short by default - the run count is
#   len(TEMP_LIST) * len(SEED_LIST) * len(BATT_LIST) * len(NOISE_LIST)
# so a couple of battery points and both noise states is usually enough to
# get non-NaN correlations on batt/noise_on without an excessive run count.
BATT_LIST  ?= 10 80
NOISE_LIST ?= 0 1


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
	$(VSIM) $(VSIM_OPTS) -sv_seed $(SEED) \
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
	$(VSIM) $(VSIM_OPTS) -sv_seed $(SEED) \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_sensor_test \
		$(if $(FW),+FW_HEX=$(FW),) \
		+BATT=$(BATT) +TEMP_C=$(TEMP_C) $(NOISE_ARG) \
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
# Temperature sweep (noise-on, sensor firmware)
#
#   make sweep_temp FW=<sensor>.hex SEED=1
#   make sweep_temp FW=<sensor>.hex SEED=1 TEMP_LIST="0 25 80.1"
#
# Runs NOISE=1 across TEMP_LIST, one run per temperature, each with its own
# .ucdb and .log named by temperature.
# ============================================================

sweep_temp: optimize
	@for t in $(TEMP_LIST); do \
		for s in $(SEED_LIST); do \
			echo "=== TEMP_C=$$t seed=$$s ==="; \
			$(VSIM) $(VSIM_OPTS) -sv_seed $$s \
				$(OPT_TOP) \
				+UVM_TESTNAME=soc_sensor_test \
				$(if $(FW),+FW_HEX=$(FW),) \
				+BATT=$(BATT) +TEMP_C=$$t +NOISE_ON \
				+UVM_VERBOSITY=UVM_MEDIUM \
				-coverage \
				-do "coverage save -onexit run_$${t}_seed$${s}.ucdb; run -all; quit -f" \
				| tee run_$${t}_seed$${s}.log; \
		done; \
	done


# ============================================================
# Full factorial sweep: TEMP_LIST x SEED_LIST x BATT_LIST x NOISE_LIST
#
#   make sweep_full FW=<sensor>.hex
#   make sweep_full FW=<sensor>.hex TEMP_LIST="25 85" SEED_LIST="1 2" \
#                    BATT_LIST="10 80" NOISE_LIST="0 1"
#
# Unlike sweep_temp (which forces NOISE_ON and a fixed BATT), this varies
# battery and noise too, so `batt` and `noise_on` get real variance in
# results.csv / the correlation matrix instead of coming out constant/NaN.
# Run count = len(TEMP_LIST) * len(SEED_LIST) * len(BATT_LIST) * len(NOISE_LIST) -
# keep the lists short, this grows fast.
# ============================================================



# ============================================================
# Extract results from a sweep_temp run into results.csv
#
# Assumes sensor_monitor prints SENSORLOG,<time>,TEMP,<tenths> and the
# firmware prints/asserts a recognizable PASS/FAIL/marker line - adjust the
# grep patterns below to match your actual log text.
# ============================================================

results:
	python3 parse_results.py

correlation: results
	python3 rnm_correlation.py results.csv


# ============================================================
# Merge every per-temperature UCDB from a sweep_temp run
# ============================================================

SWEEP_DB = sweep_merged.ucdb

merge_sweep:
	vcover merge $(SWEEP_DB) run_*.ucdb

merge_sweep_summary: merge_sweep
	vcover report $(SWEEP_DB)


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

# ============================================================
# Clean
#
#   make clean        - full clean: work library + every generated artifact
#   make clean_sweep   - only sweep/analysis outputs, keeps `work` so the
#                        next sweep doesn't force a recompile
# ============================================================

clean:
	rm -rf work
	rm -rf transcript
	rm -rf vsim.wlf
	rm -rf *.log
	rm -rf *.ucdb
	rm -rf *.vstf
	rm -f $(COV_RPT) merged_$(COV_RPT)
	rm -f results.csv
	rm -f rnm_correlation.png

clean_sweep:
	rm -f run_*.log
	rm -f run_*.ucdb
	rm -f $(MERGED_DB) $(SWEEP_DB)
	rm -f results.csv
	rm -f rnm_correlation.png
	rm -f merged_$(COV_RPT)


# ============================================================
# Rebuild
# ============================================================

rebuild: clean all


.PHONY: all work compile mapxpm optimize run tpu sensor \
        coverage coverage_tpu coverage_sensor coverage_report coverage_summary \
        merge merge_report merge_summary \
        sweep_temp sweep_full results correlation merge_sweep merge_sweep_summary \
        debug clean clean_sweep rebuild