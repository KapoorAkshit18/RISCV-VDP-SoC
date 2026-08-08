# RISCV-VDP-SoC
## RISC-V Video Display Processor System-on-Chip

**Document Type:** Project Technical Documentation / Viva Reference  
**Status:** RTL Integration and Directed Verification Baseline  
**Revision:** 1.0  
**Architecture:** RV32I-class RISC-V + Native Memory-Mapped SoC  
**Primary Verification Direction:** SystemVerilog / UVM  
**Target:** FPGA prototyping and ASIC-style RTL development

---

# 1. Project Overview

RISCV-VDP-SoC is a compact RISC-V-based System-on-Chip integrating a processor, on-chip RAM, memory-mapped peripherals, and a video display subsystem.

The current architecture is centered around a PicoRV32/RV32I-class processor. The processor's native memory interface is converted into a clean SoC master transaction interface through a CPU bus adapter. A combinational memory interconnect performs system address decoding and routes each transaction to the appropriate slave.

The principal integrated blocks are:

- RISC-V/PicoRV32 processor
- CPU native-bus adapter
- SoC memory interconnect
- On-chip RAM
- GPIO peripheral
- Sensor status peripheral
- RF telemetry peripheral
- Video Display Processor (VDP)
- VGA timing/display interface
- Clock/reset infrastructure where required
- SystemVerilog directed verification
- Planned/ongoing UVM-based verification

The project is intended to demonstrate both **RTL/SoC integration** and **Design Verification (DV)** capability.

---

# 2. Project Goals

## Primary Goals

1. Integrate a RISC-V processor into a synthesizable SoC.
2. Establish a deterministic memory-mapped transaction architecture.
3. Connect processor transactions to RAM and heterogeneous peripherals.
4. Provide a reusable local-address convention for 4-KB peripheral windows.
5. Integrate GPIO, sensor, RF telemetry, and VDP/VGA functionality.
6. Handle clock-domain separation for the display subsystem.
7. Verify the interconnect and peripheral integration using SystemVerilog.
8. Establish a scalable UVM verification environment.
9. Keep the architecture suitable for FPGA implementation and future ASIC-style flows.

## Secondary Goals

- Demonstrate byte-write/strobe handling.
- Verify unmapped-address behavior.
- Verify correct response propagation.
- Provide a clear separation between CPU-specific protocol handling and SoC routing.
- Establish a foundation for constrained-random verification, assertions, functional coverage, and regression.

---

# 3. High-Level Architecture

```text
                         +----------------------+
                         |      RISC-V CPU      |
                         |      PicoRV32        |
                         +----------+-----------+
                                    |
                         Native Memory Interface
                                    |
                         +----------v-----------+
                         |   CPU Bus Adapter    |
                         | CPU -> SoC Bus       |
                         +----------+-----------+
                                    |
                      32-bit SoC Native Master Bus
                                    |
                         +----------v-----------+
                         |  SoC Memory          |
                         |  Interconnect        |
                         |  Address Decoder     |
                         +--+----+----+----+----+
                            |    |    |    |    |
                            |    |    |    |    |
                           RAM  GPIO Sensor RF  VDP
                            |    |    |    |    |
                            |    |    |    |    |
                            |    |    |    |    +----> VGA / Pixel Clock
                            |    |    |    |
                            |    |    |    +---------> RF telemetry
                            |    |    +--------------> Sensor status
                            |    +-------------------> GPIO
                            +-------------------------> Program/Data RAM
```

---

# 4. Processor Subsystem

## 4.1 RISC-V Processor

The CPU subsystem uses a PicoRV32/RV32I-class RISC-V processor.

The processor exposes a native memory interface containing signals such as:

```text
mem_valid
mem_instr
mem_addr
mem_wdata
mem_wstrb
mem_ready
mem_rdata
```

The processor does not directly know about the internal peripheral implementation. It generates memory transactions, and the SoC infrastructure determines where those transactions go.

## 4.2 Why RISC-V?

RISC-V was selected because:

- The ISA is open.
- It is suitable for academic and research SoC development.
- Compact implementations are available.
- The architecture is well suited to FPGA prototyping.
- It allows processor, memory and peripheral integration without dependence on a proprietary ISA.

## 4.3 Why PicoRV32?

PicoRV32 is appropriate for this project because:

- It is compact.
- It provides a simple native memory interface.
- It is suitable for FPGA/ASIC-oriented RTL.
- Its interface is straightforward to integrate with a custom memory subsystem.

---

# 5. CPU Bus Adapter

## Purpose

The CPU bus adapter separates PicoRV32-specific memory-interface semantics from the generic SoC master-side interface.

### CPU-side signals

```text
mem_valid
mem_instr
mem_addr
mem_wdata
mem_wstrb
mem_ready
mem_rdata
```

### SoC-side signals

```text
m_valid
m_write
m_addr
m_wdata
m_strb
m_ready
m_rdata
```

Conceptually:

```text
PicoRV32
   |
   | mem_valid / mem_addr / mem_wdata / mem_wstrb
   v
CPU Bus Adapter
   |
   | m_valid / m_write / m_addr / m_wdata / m_strb
   v
SoC Interconnect
```

## Design Rationale

The adapter creates a clean boundary between the processor and the rest of the SoC.

Benefits:

- CPU-specific protocol logic remains localized.
- The interconnect does not need to understand every CPU-specific detail.
- A different CPU can potentially be integrated by replacing the adapter.
- Verification can treat the adapter boundary as a stable transaction interface.

---

# 6. SoC Memory Interconnect

## 6.1 Function

`soc_mem_interconnect` is the central memory-mapped routing block.

It:

1. Receives a transaction from the CPU-side master.
2. Decodes the system address.
3. Selects exactly one target region.
4. Passes the transaction to the selected slave.
5. Converts peripheral system addresses into 12-bit local addresses.
6. Returns `ready` and `rdata` from the selected slave.
7. Completes unmapped accesses with zero data.

The current implementation is **combinational**.

## 6.2 Important Architectural Point

The interconnect itself does not contain a clock or reset because the current implementation is combinational.

Transaction latency is supplied by the selected slave.

Therefore, the top-level should **not connect `clk` or `resetn` to `soc_mem_interconnect`** unless the architecture is later changed to a registered/pipelined interconnect.

---

# 7. Address Map

| Region | Base Address | Window |
|---|---:|---:|
| RAM | `0x0000_0000` | 64 KB address window |
| GPIO | `0x0001_0000` | 4 KB |
| RF | `0x0001_1000` | 4 KB |
| Sensor | `0x0001_2000` | 4 KB |
| VDP | `0x0001_3000` | 4 KB |

## Peripheral Local Addressing

Each peripheral receives:

```text
system address[11:0]
```

Example:

```text
System address = 0x0001_200C

Interconnect:
    Sensor selected
    sensor_addr = 12'h00C
```

This keeps global system address decoding inside the interconnect and local register decoding inside the peripheral.

---

# 8. Native Bus Convention

The internal SoC bus uses a PicoRV32-compatible native transaction model.

### Request

```text
m_valid = 1
```

indicates a valid request.

### Operation

```text
m_write = 1  -> write
m_write = 0  -> read
```

### Byte strobes

```text
m_strb = 4'b0000 -> read
m_strb != 4'b0000 -> write
```

Each strobe bit corresponds to a byte lane.

For 32-bit data:

```text
m_strb[0] -> bits [7:0]
m_strb[1] -> bits [15:8]
m_strb[2] -> bits [23:16]
m_strb[3] -> bits [31:24]
```

---

# 9. RAM Subsystem

The RAM interface is:

```text
clk
reset
valid
write
addr
wdata
strb
ready
rdata
```

The system interconnect retains the complete 32-bit system address.

At the RAM instance, only the address bits required by the configured RAM depth are passed to the memory array.

## Important Distinction

The current address map provides a **64-KB RAM address window**, but the current default instantiated memory depth is:

```text
RAM_DEPTH = 256 words
DATA_WIDTH = 32 bits
```

Therefore:

```text
256 × 32 bits
= 8192 bits
= 1024 bytes
= 1 KB
```

The address window and physical instantiated RAM capacity should not be confused.

---

# 10. GPIO Peripheral

The GPIO peripheral uses a native PicoRV32-style slave interface.

## Register Map

| Offset | Register | Access | Description |
|---|---|---|---|
| `0x00` | `GPIO_DATA_OUT` | R/W | GPIO output data |
| `0x04` | `GPIO_DATA_IN` | RO | Synchronized input snapshot |
| `0x08` | `GPIO_DIR` | R/W | Output-enable direction |
| `0x0C` | `GPIO_STATUS` | RO | Write-pulse status |

## GPIO Data Path

```text
CPU write
   |
Interconnect
   |
GPIO DATA_OUT
   |
gpio_out
```

For input:

```text
gpio_in
   |
2-FF Synchronizer
   |
GPIO_DATA_IN
   |
CPU read
```

## CDC / Metastability

External GPIO inputs may be asynchronous to the SoC clock.

The peripheral therefore uses a two-flop synchronizer.

This reduces the probability of metastability propagating into synchronous logic.

---

# 11. Sensor Status Peripheral

The sensor peripheral exposes:

- Battery percentage
- Battery voltage
- Temperature
- Sensor-valid status

Representative external inputs:

```text
battery_percent_i      [7:0]
battery_voltage_mv_i   [15:0]
temperature_tenthsC_i  [15:0]
sensor_valid_i
```

The native slave interface uses:

```text
mem_valid
mem_instr
mem_ready
mem_addr[11:0]
mem_wdata[31:0]
mem_wstrb[3:0]
mem_rdata[31:0]
```

## Current Status

The sensor peripheral is integrated into the SoC top-level.

The remaining task is complete end-to-end validation through the integrated CPU/UVM path.

This should be presented as **under validation**, rather than as a fully demonstrated result.

---

# 12. RF Telemetry Peripheral

The RF telemetry peripheral provides memory-mapped access to telemetry information.

Inputs include:

```text
rssi_dbm_i
link_up_i
link_error_i
carrier_detect_i
```

The peripheral also exposes an RF enable/control output:

```text
rf_enable_o
```

The peripheral is intended to provide a software-visible telemetry/control interface.

## Current Status

The native RF slave interface has been implemented and integrated at the interconnect level.

Deeper end-to-end validation remains part of the final verification phase.

---

# 13. Video Display Processor

The VDP provides a memory-mapped CPU configuration interface and an independent VGA pixel-clock domain.

## CPU-side interface

```text
clk
resetn
mem_valid
mem_instr
mem_ready
mem_addr[11:0]
mem_wdata[31:0]
mem_wstrb[3:0]
mem_rdata[31:0]
```

## Display-side interface

```text
pixel_clk
hsync_o
vsync_o
pixel_x_o
pixel_y_o
rgb_r_o[3:0]
rgb_g_o[3:0]
rgb_b_o[3:0]
```

## Clock Domains

There are at least two relevant clock domains:

```text
System / CPU Clock
       |
       | configuration
       v
      VDP
       |
       | CDC
       v
Pixel Clock Domain
       |
       +---- HSYNC
       +---- VSYNC
       +---- RGB
```

The pixel-clock domain must maintain deterministic display timing independently of CPU activity.

---

# 14. Reset Architecture

The SoC contains both synchronous and clock-domain-specific reset requirements.

The native GPIO and sensor-style synchronous logic uses an active-low reset convention:

```text
resetn
```

The RAM uses:

```text
reset
```

where the exact polarity/behavior must match the `soc_ram` implementation.

The combinational interconnect has no reset.

## Key Rule

Do not add reset ports to a module merely because it is instantiated in a clocked subsystem.

Reset should exist only where sequential state requires it.

---

# 15. Top-Level Integration

The integrated top-level is conceptually:

```text
cpu_soc_ram_top
|
+-- PicoRV32 / CPU
|
+-- CPU Bus Adapter
|
+-- soc_mem_interconnect
|
+-- soc_ram
|
+-- gpio_native_slave
|
+-- sensor_status_native_slave
|
+-- rf_telemetry_native_slave
|
+-- vdp_native_slave
```

The top-level connects:

- System clock
- Active-low system reset
- External sensor inputs
- GPIO external pins
- RF external signals/control
- Pixel clock
- VGA outputs
- CPU trap output

---

# 16. Implementation Progress

## Completed / Established

- RISC-V/PicoRV32 processor integration.
- CPU native memory interface.
- CPU bus adapter.
- SoC memory interconnect.
- System address map.
- RAM routing.
- GPIO native slave.
- GPIO register interface.
- GPIO synchronization.
- Sensor native slave integration.
- RF native slave interface.
- VDP native slave interface.
- VGA/pixel-clock interface.
- Directed interconnect verification.
- Clean RTL compilation baseline.

## Demonstrated

### Interconnect

Directed verification has demonstrated:

- RAM routing.
- RAM address propagation.
- RAM response propagation.
- GPIO routing.
- GPIO local address conversion.
- RF routing.
- RF local address conversion.
- Sensor routing.
- Sensor local address conversion.
- VDP routing.
- VDP local address conversion.
- Write/data/strobe propagation.
- Unmapped transaction completion.
- Correct selected-slave behavior.

### GPIO

GPIO functionality has been demonstrated in the integrated environment.

## Remaining / In Progress

- Complete end-to-end sensor validation.
- Complete deeper RF validation.
- Complete deeper VDP/CPU integration validation.
- Build and run the final UVM environment.
- Add constrained-random stimulus.
- Add functional coverage.
- Add assertions.
- Establish regression.

---

# 17. Verification Strategy

The verification strategy is layered.

```text
                 Verification
                      |
        +-------------+-------------+
        |                           |
   Block-Level                  SoC-Level
        |                           |
 Directed / SVA              Directed / UVM
                                    |
                       +------------+------------+
                       |            |            |
                    Driver      Monitor      Checker
                       |            |            |
                    Stimulus    Transactions   Expected
                                                   |
                                              Scoreboard /
                                              Predictor
```

---

# 18. Directed Verification

Directed verification is used for deterministic architectural checks.

Important test categories:

### RAM

- Write then read.
- Multiple data patterns.
- Address propagation.
- Byte strobe behavior.

### GPIO

- DATA_OUT write/read.
- DIR write/read.
- Input synchronization.
- Status behavior.
- Byte enables.

### Interconnect

- Each address region.
- Local-address conversion.
- Correct `ready`.
- Correct `rdata`.
- Unmapped accesses.
- No simultaneous target selection.

---

# 19. UVM Verification Plan

The final UVM environment should be transaction-based.

## Proposed Components

```text
uvm_test
   |
uvm_env
   |
   +-- soc_agent
   |      |
   |      +-- sequencer
   |      +-- driver
   |      +-- monitor
   |
   +-- predictor/reference model
   |
   +-- scoreboard
   |
   +-- coverage
```

## Transaction

A transaction should represent:

```text
address
write/read
write_data
byte_strobes
expected/observed response
```

## Driver

Converts a transaction into native-bus signals.

## Monitor

Samples the interface and reconstructs transactions.

## Predictor

Determines the expected target and response using the same architectural address map.

## Scoreboard

Compares observed behavior against expected behavior.

---

# 20. UVM Smoke Test

The first UVM test should remain small.

Recommended sequence:

```text
RESET
  |
RAM WRITE
  |
RAM READ
  |
RAM CHECK
  |
GPIO WRITE
  |
GPIO READ
  |
GPIO CHECK
  |
SENSOR READ
  |
RF READ
  |
VDP ACCESS
  |
UNMAPPED ACCESS
  |
PASS / FAIL
```

The smoke test should validate the complete UVM infrastructure before constrained-random testing is introduced.



---

# 21. Constrained-Random Verification

After smoke testing, randomize:

- Address.
- Read/write operation.
- Write data.
- Byte strobes.
- Peripheral region.
- Back-to-back accesses.
- Repeated accesses.
- Boundary addresses.

Useful constraints include:

```text
valid address region
aligned/unaligned policy as supported
legal byte strobes
read/write distribution
peripheral selection distribution
```

---

# 22. Functional Coverage

Recommended coverage points:

## Address Region

```text
RAM
GPIO
RF
SENSOR
VDP
UNMAPPED
```

## Operation

```text
READ
WRITE
```

## Byte Strobe

```text
0000
0001
0010
0100
1000
1111
other legal combinations
```

## Cross Coverage

```text
ADDRESS_REGION × OPERATION
ADDRESS_REGION × BYTE_STROBE
```

Additional coverage can include:

- Boundary addresses.
- Reset-to-first-transaction behavior.
- Back-to-back transactions.
- Peripheral-specific register accesses.

---

# 23. Assertions

Potential SystemVerilog Assertions include:

### Valid request selects at most one slave

```text
$onehot0({
    ram_valid,
    gpio_valid,
    rf_valid,
    sensor_valid,
    vdp_valid
})
```

### Peripheral select requires master validity

```text
gpio_valid |-> m_valid
```

and similarly for other peripherals.

### Local address range

Peripheral addresses should remain within:

```text
0x000 - 0xFFF
```

### Response routing

When a slave is selected, the master response should correspond to that slave.

Assertions can also verify:

- No illegal simultaneous selection.
- Correct response propagation.
- Unmapped transaction completion.
- Stable request behavior where required by the protocol.

---

# 24. Formal Verification

Formal verification can complement simulation. Though z3 doesnt performs well for the complex codes.

Useful properties include:

- Address decode correctness.
- One-hot slave selection.
- No illegal target selection.
- Unmapped accesses terminate.
- Ready propagation.
- Local-address extraction.
- Byte-strobe propagation.
- Reset behavior.

The interconnect is particularly suitable for formal verification because much of its behavior is deterministic combinational routing.

---

# 25. Why a Scoreboard Is Not Always Required at Every SoC Boundary

A common misconception is:

> "Every SoC testbench must have one giant scoreboard."

That is not necessarily true.

A scoreboard is valuable when the expected transaction/result can be modeled effectively.

At SoC level, verification can also use:

- Assertions.
- Protocol monitors.
- Architectural state checking.
- Reference models.
- Software self-checking.
- Memory models.
- Functional coverage.
- End-to-end checking.

For this project, a **small predictor/checker for the memory interconnect** is useful because the expected target and response are deterministic.

---

# 26. Expected Verification Flow

```text
RTL Compilation
      |
      v
Directed Smoke
      |
      v
Block-Level Tests
      |
      v
SoC Directed Tests
      |
      v
UVM Smoke Test
      |
      v
Constrained Random
      |
      v
Assertions
      |
      v
Functional Coverage
      |
      v
Regression
      |
      v
FPGA Validation
```

---

# 27. Results

## Directed Interconnect Results

The directed testbench demonstrated successful behavior for:

| Test | Result |
|---|---|
| RAM routing | PASS |
| RAM address propagation | PASS |
| RAM ready/data return | PASS |
| GPIO routing | PASS |
| GPIO local address conversion | PASS |
| RF routing | PASS |
| RF local address conversion | PASS |
| Sensor routing | PASS |
| Sensor local address conversion | PASS |
| VDP routing | PASS |
| VDP local address conversion | PASS |
| Write data/strobe routing | PASS |
| Unmapped access handling | PASS |
| Selected-slave behavior | PASS |

**Overall directed interconnect result: ALL TESTS PASSED.**

## Integrated Status

| Subsystem | Status |
|---|---|
| RISC-V CPU | Integrated |
| CPU bus adapter | Integrated |
| RAM | Integrated |
| Interconnect | Verified by directed tests |
| GPIO | Working / demonstrated |
| Sensor | Integrated / under validation |
| RF | Interface integrated / deeper validation pending |
| VDP/VGA | Interface integrated / deeper validation pending |
| UVM | Final verification phase / in progress |

No fabricated synthesis, timing, frequency, or coverage numbers should be reported unless measured.

---

# 28. Strengths

1. Open RISC-V ISA.
2. Compact processor subsystem.
3. Simple native-bus architecture.
4. Deterministic memory map.
5. Reusable 4-KB peripheral windows.
6. Clear separation between CPU and SoC bus.
7. Heterogeneous peripheral integration.
8. VGA/VDP demonstrates multi-clock-domain design.
9. Suitable for FPGA prototyping.
10. Scalable verification architecture.

---

# 29. Limitations

1. Current interconnect is single-master/simple routing.
2. Current RAM physical depth is smaller than its mapped address window.
3. No DMA engine in the MVP.
4. No advanced bus arbitration.
5. Some peripheral end-to-end validation remains.
6. VDP introduces CDC complexity.
7. UVM regression and coverage closure are not yet the primary completed result.
8. No claim should be made for ASIC PPA until synthesis/STA data is available.

---

# 30. Future Scope

## Verification

- Complete UVM environment.
- Constrained-random regression.
- Functional coverage closure.
- SVA-based protocol checking.
- UVM Register Abstraction Layer.
- Reference-model integration.
- Formal property expansion.
- CI-based regression.

## SoC Architecture

- Add DMA.
- Add interrupts.
- Add timers.
- Expand memory.
- Add additional communication peripherals.
- Add multiple masters/arbitration if required.
- Add external AXI4-Lite control interface where appropriate.

## FPGA

- Complete FPGA implementation.
- Timing closure.
- Resource utilization analysis.
- On-board sensor/RF testing.
- VGA validation on target board.

## ASIC-Oriented Flow

- RTL linting.
- CDC analysis.
- Synthesis.
- Static timing analysis.
- Formal verification.
- DFT considerations.
- Physical design exploration.

---

# 31. Applications

Potential applications include:

- Embedded sensor monitoring.
- RF telemetry systems.
- FPGA-based instrumentation.
- Industrial monitoring/control.
- Embedded display controllers.
- Educational RISC-V SoC platforms.
- Low-complexity embedded processing systems.
- Research platforms for SoC verification.
- FPGA-based hardware/software co-design experiments.

---

# 32. Literature Survey

## 32.1 PicoRV32

**Clifford Wolf / YosysHQ — PicoRV32**

Relevance:

- Compact RISC-V processor.
- Native memory interface.
- FPGA/ASIC-oriented open RTL.
- Direct architectural foundation for this project.

The project uses the processor's native memory interface as the starting point for the CPU-to-SoC transaction path.


# 33. Publication Status

The current project should be described as:

> **Project implementation with related literature identified; publication of the present work is future scope.**

A publication claim should only be made after actual submission, acceptance, or publication.

Potential future paper directions:

1. RISC-V-based embedded display SoC architecture.
2. Native-bus memory-mapped SoC integration methodology.
3. UVM verification of a RISC-V heterogeneous peripheral subsystem.
4. FPGA validation of a RISC-V sensor/telemetry/display SoC.
5. Coverage-driven verification methodology for compact RISC-V SoCs.

---

# 34. Key Viva Questions and Answers

## Q1. What is the project?

A RISC-V-based memory-mapped SoC integrating RAM, GPIO, sensor, RF telemetry and VDP/VGA, supported by directed and UVM-oriented verification.

## Q2. Why RISC-V?

Because it is an open ISA with compact implementations and is well suited for academic, FPGA and research-oriented SoC development.

## Q3. Why PicoRV32?

It provides a compact RV32 processor and a simple native memory interface that is easy to integrate.

## Q4. Is the internal bus AXI?

No. The current CPU-to-peripheral path uses the PicoRV32 native memory interface. AXI4-Lite can be used at an external boundary in a future architecture.

## Q5. Why use a bus adapter?

To isolate PicoRV32-specific interface semantics from the generic SoC interconnect.

## Q6. Why are peripheral addresses 12 bits?

Each peripheral has a 4-KB window, so only the lower 12 address bits are required after global decoding.

## Q7. What happens to an unmapped access?

It completes with `m_ready = 1` and zero read data because the native bus has no AXI-style error response.

## Q8. What has actually been verified?

The directed interconnect tests verify routing, local address conversion, response propagation, write data/strobes, unmapped accesses and selected-slave behavior. GPIO functionality has also been demonstrated.

## Q9. Is UVM complete?

The UVM environment is the final verification phase/in progress unless actual completed regression evidence is available. Do not claim coverage or pass numbers without simulation evidence.

## Q10. What is the biggest limitation?

The current design is an MVP with a simple single-master interconnect, limited RAM depth, and incomplete end-to-end validation of some peripherals.

## Q11. What is novel?

The project does not claim a novel RISC-V ISA or CPU. Its engineering contribution is the integration of a RISC-V CPU, native-bus adaptation, memory-mapped heterogeneous peripherals, display clock-domain separation, and a scalable verification methodology.

## Q12. What would you add next?

Complete UVM coverage/regression, assertions and formal checks, then add DMA, interrupts, larger memory, improved CDC verification and FPGA validation.

---

# 35. Important Technical Facts to Memorize

```text
CPU:
    PicoRV32 / RV32I-class RISC-V

System data width:
    32 bits

System address width:
    32 bits

Byte strobes:
    4 bits

Peripheral local address:
    12 bits

RAM mapped window:
    64 KB

Default RAM:
    256 × 32-bit words = 1 KB

GPIO:
    0x0001_0000

RF:
    0x0001_1000

Sensor:
    0x0001_2000

VDP:
    0x0001_3000

Interconnect:
    Combinational

GPIO input:
    2-FF synchronization

VDP:
    Independent pixel clock

Verification:
    Directed RTL verification completed for interconnect
    GPIO demonstrated
    Sensor/RF/VDP deeper validation pending
    UVM final phase
```
