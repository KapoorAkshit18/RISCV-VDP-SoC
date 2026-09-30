# TPU Formal Verification Execution Guide

This directory contains the experimental framework to evaluate the tractability boundary of the TPU subsystem using formal bounded model checking (BMC). It includes scripts to run a decomposed set of properties at varying depths and to execute mutation testing.

## Prerequisites

To run these scripts, you must have the following tools installed and accessible in your `$PATH` (typically within a WSL or Linux environment):
*   **Bash** (to execute the `.sh` scripts)
*   **Yosys** (Synthesis and formal frontend)
*   **SymbiYosys (SBY)** (Formal verification frontend)
*   **Z3** (SMT Solver)

## 1. Running the Decomposition Sweep

The decomposition script evaluates the isolated AXI Stream properties (`TPU_P01`, `P02`, `P03`, `P04`, `P06`) against `nn_axis_master`, and the isolated MMIO property (`TPU_P05`) against `nn_axi_wrapper`. It sweeps across BMC depths `1, 2, 4, 6, 8, 10`.

**Command:**
```bash
cd phases/phase_8/formal/tpu/
chmod +x run_decomposition.sh
./run_decomposition.sh
```

**Outputs:**
*   `tpu_formal_decomposition.csv`: A CSV containing the pass/fail/timeout result and runtime for every property at every depth.
*   `decomposition/`: A generated folder containing the raw `.sby` files, `yosys-smtbmc` logs (`.log`), and solver trace directories for every individual run.

## 2. Running the Mutation Tests

The mutation testing script evaluates three synthetically injected structural faults on `nn_axis_master.v` to prove that the formal bounding environment does not vacuously pass. 

**Command:**
```bash
cd phases/phase_8/formal/tpu/
chmod +x run_mutants.sh
./run_mutants.sh
```

**What it tests:**
*   `M01_nn_axis_master.v`: Tests payload stability failure (Caught by P02).
*   `M02_nn_axis_master.v`: Tests premature TLAST assertion failure (Caught by P04).
*   `M03_nn_axis_master.v`: Tests transfer qualification failure (Caught by P03).

**Outputs:**
*   `tpu_mutation_formal_results.csv`: A CSV containing the pass/fail status indicating whether the property successfully generated a counterexample to catch the mutant.
*   `mutant_results/`: A folder containing the SBY traces, `.vcd` waveforms (if a counterexample is found), and logs for each mutation run.

## Directory Overview

*   `tpu_axis_checker.sv`: The SystemVerilog bounding environment isolating the `nn_axis_master` logic (Tractable properties).
*   `tpu_mmio_checker.sv`: The SystemVerilog bounding environment isolating the `nn_axi_wrapper` logic (Intractable property).
*   `mutants/`: Contains the intentionally flawed `M01`, `M02`, and `M03` Verilog files.
*   `tpu_formal_decomposition_report.txt`: The final analytical report of the experiment's findings.
