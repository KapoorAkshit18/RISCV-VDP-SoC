# RISC-V Software Workload Benchmark

## Overview

This firmware implements a **32×32 Matrix-Vector Multiplication (MVM) followed by ReLU** on the RISC-V processor.

The workload is intentionally executed in software to establish the **pre-TPU performance baseline**.

## Workload

$$
y[i] = ReLU\left(\sum_{j=0}^{31} x[j]W[i][j] + bias[i]\right)
$$

* Input size: **32**
* Output size: **32**
* Multiply-accumulate operations: **1024**
* Activation: **ReLU**
* Data type: **32-bit signed integer**

The input, weights, and biases use deterministic values, allowing the result to be verified exactly.

## Cycle Measurement

The RISC-V `rdcycle` and `rdcycleh` CSRs are used to measure only the workload execution:

```text
Start cycle
    ↓
32×32 MVM + ReLU
    ↓
End cycle
    ↓
Workload cycles = End − Start
```

The measured cycle count is stored as two 32-bit values:

* `benchmark_cycles_lo` — lower 32 bits
* `benchmark_cycles_hi` — upper 32 bits

## Result Verification

The expected result is:

```text
output[i] = (i + 1) × 529
```

The firmware enters an infinite loop if verification fails. After successful execution, it remains in an infinite loop so the completion point can be identified in simulation.

## Purpose

This firmware provides a reproducible **software-only baseline** for comparison with the corresponding TPU-accelerated implementation.

The same:

* input data
* weights
* dimensions
* mathematical operation

should be used for the TPU benchmark.

