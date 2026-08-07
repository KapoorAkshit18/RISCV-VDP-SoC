# ============================================================
# RISCV-VDP-SoC — Questa UVM Makefile
# ============================================================

TOP      = tb_soc_uvm
FILELIST = filelist.f

VLOG     = vlog
VSIM     = vsim

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
		+UVM_TESTNAME=soc_smoke_test \
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