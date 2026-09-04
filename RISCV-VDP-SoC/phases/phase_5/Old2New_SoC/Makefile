# =============================================================================
# Makefile
#
# RISCV-VDP-SoC - Phase 5
# Old2New_SoC + TPU integration
#
# Simulator : QuestaSim / ModelSim
# Platform  : Linux / WSL
# Vivado    : 2020.1
#
# Simulation flow:
#
#   1. vlib work
#   2. vlog -sv -f filelist.f
#   3. vlog Vivado glbl.v
#   4. vopt +acc -L xpm work.tb_soc_ram_top work.glbl -o tb_opt
#   5. vsim tb_opt
#   6. execute run.do
#
# =============================================================================


# -----------------------------------------------------------------------------
# Tools
# -----------------------------------------------------------------------------

VLOG ?= vlog
VLIB ?= vlib
VMAP ?= vmap
VOPT ?= vopt
VSIM ?= vsim


# -----------------------------------------------------------------------------
# Project configuration
# -----------------------------------------------------------------------------

TOP      := tb_soc_ram_top
OPT_TOP  := tb_opt

WORK     := work
FILELIST := filelist.f
RUN_DO   := run.do


# -----------------------------------------------------------------------------
# Xilinx Vivado 2020.1
# -----------------------------------------------------------------------------
#
# IMPORTANT:
# This is the Linux path.
#
# If Vivado is installed somewhere else, override it:
#
#     make VIVADO=/path/to/Vivado/2020.1
#
# -----------------------------------------------------------------------------

VIVADO ?= /opt/Xilinx/Vivado/2020.1

GLBL := $(VIVADO)/data/verilog/src/glbl.v


# -----------------------------------------------------------------------------
# Questa compile options
# -----------------------------------------------------------------------------

VLOG_FLAGS := -sv

# Preserve internal hierarchy/signals for waveform/debug.
VOPT_FLAGS := +acc -L xpm


# =============================================================================
# DEFAULT TARGET
# =============================================================================

.PHONY: all
all: simulate


# =============================================================================
# CREATE WORK LIBRARY
# =============================================================================

.PHONY: work

work:
	@echo "============================================================"
	@echo " Creating Questa work library"
	@echo "============================================================"

	@if [ ! -d "$(WORK)" ]; then \
		$(VLIB) $(WORK); \
	fi

	$(VMAP) work $(WORK)


# =============================================================================
# COMPILE RTL + TESTBENCH
# =============================================================================

.PHONY: compile

compile: work
	@echo "============================================================"
	@echo " Compiling RTL and testbench"
	@echo "============================================================"
	@echo " File list : $(FILELIST)"
	@echo " Top       : $(TOP)"
	@echo "============================================================"

	$(VLOG) $(VLOG_FLAGS) -f $(FILELIST)

	@echo ""
	@echo "============================================================"
	@echo " Compiling Xilinx glbl.v"
	@echo "============================================================"
	@echo " GLBL      : $(GLBL)"
	@echo "============================================================"

	$(VLOG) $(GLBL)

	@echo ""
	@echo "============================================================"
	@echo " Compilation completed"
	@echo "============================================================"


# =============================================================================
# OPTIMIZE DESIGN
# =============================================================================
#
# Equivalent to:
#
#   vopt +acc -L xpm work.tb_soc_ram_top work.glbl -o tb_opt
#
# The Xilinx XPM library is explicitly linked because the TPU / AXIS
# hierarchy may contain Xilinx XPM-based components.
#
# =============================================================================

.PHONY: optimize

optimize: compile
	@echo "============================================================"
	@echo " Optimizing simulation design"
	@echo "============================================================"
	@echo " Top      : work.$(TOP)"
	@echo " GLBL     : work.glbl"
	@echo " Output   : $(OPT_TOP)"
	@echo " Library  : xpm"
	@echo "============================================================"

	$(VOPT) $(VOPT_FLAGS) \
		work.$(TOP) \
		work.glbl \
		-o $(OPT_TOP)

	@echo ""
	@echo "============================================================"
	@echo " Optimization completed"
	@echo " Optimized top: $(OPT_TOP)"
	@echo "============================================================"


# =============================================================================
# SIMULATION
# =============================================================================
#
# Equivalent to:
#
#   vsim tb_opt
#
# Then run.do is executed.
#
# =============================================================================

.PHONY: simulate

simulate: optimize
	@echo "============================================================"
	@echo " Starting Questa simulation"
	@echo "============================================================"
	@echo " Simulation top: $(OPT_TOP)"
	@echo " DO file       : $(RUN_DO)"
	@echo "============================================================"

	$(VSIM) $(OPT_TOP) -do "$(RUN_DO)"


# =============================================================================
# INTERACTIVE SIMULATION
# =============================================================================
#
# Opens the optimized design without automatically running run.do.
#
# Useful for manually inspecting the hierarchy.
# =============================================================================

.PHONY: gui

gui: optimize
	@echo "============================================================"
	@echo " Starting interactive Questa session"
	@echo "============================================================"

	$(VSIM) $(OPT_TOP)


# =============================================================================
# RUN EXISTING OPTIMIZED DESIGN
# =============================================================================
#
# Does not recompile.
#
# Useful when you only modified run.do.
# =============================================================================

.PHONY: rerun

rerun:
	@echo "============================================================"
	@echo " Running existing optimized design"
	@echo "============================================================"

	$(VSIM) $(OPT_TOP) -do "$(RUN_DO)"


# =============================================================================
# CHECK PROJECT
# =============================================================================

.PHONY: check

check:
	@echo "============================================================"
	@echo " Checking project structure"
	@echo "============================================================"

	@test -f "$(FILELIST)" || \
		(echo "ERROR: $(FILELIST) not found"; exit 1)

	@test -f "$(RUN_DO)" || \
		(echo "ERROR: $(RUN_DO) not found"; exit 1)

	@test -d "Old2New_SoC" || \
		(echo "ERROR: Old2New_SoC directory not found"; exit 1)

	@test -d "TPU" || \
		(echo "ERROR: TPU directory not found"; exit 1)

	@test -f "$(GLBL)" || \
		(echo "ERROR: Vivado glbl.v not found: $(GLBL)"; exit 1)

	@echo "Project structure: OK"
	@echo "Vivado glbl.v    : OK"


# =============================================================================
# CLEAN
# =============================================================================

.PHONY: clean

clean:
	@echo "============================================================"
	@echo " Cleaning simulation files"
	@echo "============================================================"

	rm -rf $(WORK)
	rm -f transcript
	rm -f vsim.wlf
	rm -f *.wlf
	rm -f *.log

	@echo "Clean completed."


# =============================================================================
# REBUILD
# =============================================================================

.PHONY: rebuild

rebuild: clean simulate


# =============================================================================
# HELP
# =============================================================================

.PHONY: help

help:
	@echo ""
	@echo "RISCV-VDP-SoC Phase-5 Simulation"
	@echo ""
	@echo "Targets:"
	@echo ""
	@echo "  make check"
	@echo "      Check file structure and Vivado glbl.v"
	@echo ""
	@echo "  make compile"
	@echo "      Compile RTL, testbench and Xilinx glbl.v"
	@echo ""
	@echo "  make optimize"
	@echo "      Run vopt +acc -L xpm"
	@echo ""
	@echo "  make simulate"
	@echo "      Compile + optimize + launch Questa"
	@echo ""
	@echo "  make gui"
	@echo "      Compile + optimize + open Questa"
	@echo ""
	@echo "  make rerun"
	@echo "      Run existing tb_opt using run.do"
	@echo ""
	@echo "  make clean"
	@echo "      Remove simulation artifacts"
	@echo ""
	@echo "  make rebuild"
	@echo "      Clean and completely rebuild"
	@echo ""