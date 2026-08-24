# RISC-V SoC Design Verification using SystemVerilog & UVM

## RISCV-VDP-SoC — RISC-V Video Display Processor System-on-Chip

[![Language](https://img.shields.io/badge/HDL-SystemVerilog%2FVerilog-blue)]
[![Verification](https://img.shields.io/badge/Verification-UVM-orange)]
[![Simulator](https://img.shields.io/badge/Simulator-QuestaSim-red)]
[![Coverage](https://img.shields.io/badge/Functional%20Coverage-100%25-success)]
[![Architecture](https://img.shields.io/badge/Architecture-RISC--V%20SoC-purple)]

> **Design Verification focused RISC-V SoC project demonstrating SystemVerilog,
> UVM, transaction-level verification, UVM RAL, functional coverage,
> waveform analysis, and memory-mapped bus verification.**

---

# 1. Project Overview

RISCV-VDP-SoC is a compact RISC-V-based System-on-Chip developed to
demonstrate RTL integration and, more importantly, a structured
**Design Verification (DV) methodology** for a memory-mapped SoC.

The SoC integrates:

- PicoRV32 / RV32I-class RISC-V processor
- CPU bus adapter
- Native memory-mapped SoC interconnect
- On-chip RAM
- GPIO
- RF telemetry peripheral
- Sensor-status peripheral
- Video Display Processor (VDP)
- VGA timing/display logic

The verification environment was developed using:

- SystemVerilog
- UVM
- UVM Register Abstraction Layer (RAL)
- SystemVerilog functional coverage
- QuestaSim
- Simulation waveforms
- Coverage database / UCDB

The verification environment is structured around a reusable native-bus
UVM agent consisting of a sequence item, sequencer, driver, monitor and
environment.

---

# 2. Why This Project Is Relevant to Design Verification

This project was developed with a strong emphasis on the verification
flow used in practical RTL/DV environments.

The verification environment demonstrates:

```text
                    Test
                     |
                     v
                  Sequence
                     |
                     v
                 Sequencer
                     |
                     v
                   Driver
                     |
                     v
              Native SoC Bus
                     |
                     v
                    DUT
                     |
                     v
                  Monitor
                     |
          +----------+----------+
          |                     |
          v                     v
     RAL Predictor          Functional
          |                  Coverage
          v
      RAL Mirror
