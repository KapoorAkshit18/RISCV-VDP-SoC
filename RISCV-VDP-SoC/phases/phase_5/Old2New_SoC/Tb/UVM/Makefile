# ============================================================
# RISCV-VDP-SoC — Questa UVM Makefile
# ============================================================

TOP      = tb_soc_uvm
FILELIST = filelist.f

VLOG     = vlog
VSIM     = vsim

COV_DB = soc_coverage.ucdb
COV_RPT= coverage_report.txt

#==============================================
# Functional Coverage
#==============================================

coverage: compile
	$(VSIM) -c \
		$(TOP) \
		+UVM_TESTNAME=soc_coverage_test \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-coverage \
		-do "coverage save -onexit $(COV_DB); run -all; quit -f"

# ============================================================
# Coverage Report
# ============================================================

coverage_report: coverage
	vcover report $(COV_DB) \
		-details \
		-output $(COV_RPT)

# ============================================================
# Coverage Summary
# ============================================================

coverage_summary: coverage
	vcover report $(COV_DB)









VLOG_OPTS = -sv +acc

VSIM_OPTS = -c \
            -voptargs=+acc

# ============================================================
# Default
# ============================================================

all: compile run


# ============================================================
# Compile
# ============================================================

compile:
	$(VLOG) $(VLOG_OPTS) -f $(FILELIST)


# ============================================================
# Run smoke test
# ============================================================

run:
	$(VSIM) $(VSIM_OPTS) \
		$(TOP) \
		+UVM_TESTNAME=soc_ral_test \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-do "run -all; quit -f"


# ============================================================
# Smoke
# ============================================================

smoke: compile
	$(VSIM) $(VSIM_OPTS) \
		$(TOP) \
		+UVM_TESTNAME=soc_smoke_test \
		+UVM_VERBOSITY=UVM_MEDIUM \
		-do "run -all; quit -f"


# ============================================================
# Debug
# ============================================================

debug: compile
	$(VSIM) \
		$(TOP) \
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
	rm -rf modelsim.ini


# ============================================================
# Rebuild
# ============================================================

rebuild: clean compile


.PHONY: all compile run smoke debug clean rebuild