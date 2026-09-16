# =============================================================================
# Makefile for RISCV-VDP-SoC CI/CD Pipeline (Git Bash / Linux)
# =============================================================================
FIRMWARE ?= Design_Dir/Tb/firmware.hex
.PHONY: all lint sim synth clean help

all: lint sim synth
	@echo "=== All CI/CD pipeline stages completed successfully! ==="

lint:
	@echo "=== Running QuestaSim Lint & Compilation Check ==="
	@bash ci/scripts/run_questasim_lint.sh

sim:
	@echo "=== Running QuestaSim Top Testbench Simulation ==="
	FIRMWARE=$(FIRMWARE) bash ci/scripts/run_questasim_sim.sh

synth:
	@echo "=== Running Local Vivado Synthesis ==="
	@bash ci/scripts/run_vivado_synth.sh

clean:
	@echo "=== Cleaning build and reports directories ==="
	@rm -rf build ci/vivado/reports

help:
	@echo "Available targets:"
	@echo "  make all    - Run Lint, Top Simulation, and Local Vivado Synthesis"
	@echo "  make lint   - Run QuestaSim lint & syntax check on RTL & TB"
	@echo "  make sim    - Run QuestaSim batch simulation for top testbench"
	@echo "  make synth  - Run local Vivado synthesis and generate reports"
	@echo "  make clean  - Remove build directories and generated reports"

