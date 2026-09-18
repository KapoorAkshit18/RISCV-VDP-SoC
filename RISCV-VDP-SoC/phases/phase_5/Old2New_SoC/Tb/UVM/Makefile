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


COV_DB  = soc_coverage.ucdb
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
# Run TPU directed test
# ============================================================

run: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_tpu_test \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-do "run -all; quit -f"


# ============================================================
# Smoke
# ============================================================

smoke: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_smoke_test \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-do "run -all; quit -f"


# ============================================================
# Functional Coverage
# ============================================================

coverage: optimize
	$(VSIM) $(VSIM_OPTS) \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_coverage_test \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-coverage \
		-do "coverage save -onexit $(COV_DB); run -all; quit -f"

coverage_report: coverage
	vcover report $(COV_DB) -details -output $(COV_RPT)

coverage_summary: coverage
	vcover report $(COV_DB)


# ============================================================
# Debug (interactive, no -c)
# ============================================================

debug: optimize
	$(VSIM) -voptargs=+acc \
		$(OPT_TOP) \
		+UVM_TESTNAME=soc_smoke_test \
		+UVM_VERBOSITY=UVM_HIGH


# ============================================================
# Clean
# ============================================================

clean:
	rm -rf work
	rm -rf transcript
	rm -rf vsim.wlf
	rm -rf *.log
	rm -rf *.ucdb
	rm -f $(COV_RPT)


# ============================================================
# Rebuild
# ============================================================

rebuild: clean run


.PHONY: all work compile mapxpm optimize run smoke coverage coverage_report coverage_summary debug clean rebuild