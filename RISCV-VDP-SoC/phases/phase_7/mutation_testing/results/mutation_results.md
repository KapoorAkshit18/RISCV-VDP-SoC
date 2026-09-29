# Phase 7 — RTL Mutation Testing Final Results

## `soc_mem_interconnect` — Mutation Campaign

**Date**: 2026-09-29
**Golden SHA256**: `7695FBE6D53A69E15B80F3DDDF57C520CA2ABE7B0204E1118577425519100D3E`

---

## Verification Flows

| Flow | Testbench | DUT | Stimulus | Pass/Fail Criteria |
|---|---|---|---|---|
| **Directed** | `tb_soc_ram_top_with_firmw.sv` | `cpu_soc_ram_top` | Firmware (`$readmemh`) | Firmware marker (`PASS`/`FAIL`/`TIMEOUT`) |
| **UVM** | `tb_cpu_soc_ram_top_end_to_end.sv` | `cpu_soc_ram_top` | Firmware (`$readmemh`) + UVM monitors | `UVM_ERROR`/`UVM_FATAL` count + scoreboard |

## Firmware Images

| ID | Path | Peripherals Exercised | Completion Marker |
|---|---|---|---|
| **FW1** | `firmware_test03/firmware.hex` | CPU, RAM, **TPU/NN** | `0x33333333` |
| **FW2** | `firmware_test_04/firmware.hex` | CPU, RAM, **Sensor** | `0x55555555` |

---

## Experimental Control: Observability

A strict rule was applied: *If a firmware workload never accesses the mutated logic in the golden RTL, the mutation is classified as **UNOBSERVABLE** rather than an "escape".*

Profiling the golden runs revealed:
- **FW1** never accesses Sensor, GPIO, RF, or VDP.
- **FW2** never accesses TPU, GPIO, RF, or VDP.
- **Neither** accesses Unmapped space.

As a result, mutants affecting GPIO (M03), RF (M04, M07), VDP (M05), and Unmapped space (M10) were marked `UNOBSERVABLE` by both workloads, and mutations affecting TPU or Sensor were marked `UNOBSERVABLE` by the opposing firmware.

---

## Final Results Summary

| Mutant | Description | Exercised By | Directed Result | UVM Result | Analysis |
|---|---|---|---|---|---|
| **M01** | TPU Base-Address Decode | FW1 | **DETECTED** (Timeout) | **DETECTED** (Timeout/Err) | TPU writes go to unmapped space. FW1 loops on TPU STATUS forever. |
| **M02** | Sensor Local-Addr Bit 11=0 | FW2 | **ESCAPED** | **ESCAPED** | FW2 only accesses low addresses (`< 0x800`) in the Sensor window. Bit 11 is never used. |
| **M03** | GPIO Ready from RF | None | `UNOBSERVABLE` | `UNOBSERVABLE` | Neither FW accesses GPIO. |
| **M04** | RF RData from Sensor | None | `UNOBSERVABLE` | `UNOBSERVABLE` | Neither FW accesses RF. |
| **M05** | VDP Write Stuck 0 | None | `UNOBSERVABLE` | `UNOBSERVABLE` | Neither FW accesses VDP. |
| **M06** | RAM Strobe always 4'hF | Either | **ESCAPED** | **ESCAPED** | FW1/FW2 compiler only emits 32-bit word writes (strobe is naturally 4'hF). Partial writes never tested. |
| **M07** | RF Valid Stuck 0 | None | `UNOBSERVABLE` | `UNOBSERVABLE` | Neither FW accesses RF. |
| **M08** | Sensor uses VDP_BASE | FW2 | **DETECTED** (FW Fail) | **DETECTED** (Error) | FW2 writes to unmapped space, detects failure, and explicitly emits `0xDEAD0001` marker. |
| **M09** | RAM Addr LSBs zeroed | Either | **ESCAPED** | **ESCAPED** | PicoRV32 uses a word-aligned bus. The lower 2 bits of `m_addr` are already always `00` (sub-word addressing uses strobes). This is an "equivalent mutant" in this architecture. |
| **M10** | Unmapped Ready Stuck 0 | None | `UNOBSERVABLE` | `UNOBSERVABLE` | Neither FW accesses Unmapped space. |

### Statistical Breakdown (Observable Mutants Only)

Total Observable Mutants (tested against relevant firmware): **5** (M01, M02, M06, M08, M09)

| Metric | Directed Flow | UVM Flow |
|---|---|---|
| **Detected** | 2 (40%) | 2 (40%) |
| **Escaped** | 3 (60%) | 3 (60%) |

### Key Takeaways for Research Paper

1. **Testbench Parity**: Because both the Directed and UVM testbenches are essentially wrappers around the *same* firmware-driven workload executing on the *same* DUT, their detection capabilities were **identical**. UVM did not catch anything the Directed testbench missed.
2. **Firmware is the true Testbench**: The detection mechanism was almost entirely driven by the firmware's ability to self-check and manage state. When the firmware crashed or got stuck in a polling loop, both environments simply observed a timeout. When the firmware detected bad data, it emitted a failure marker which both environments caught.
3. **Escapes due to Workload Gaps**: M02 and M06 escaped because the *workload itself* didn't exercise the mutated behavior (sub-word RAM writes, or high-address Sensor reads). No amount of UVM monitor sophistication could detect bugs in functionality the CPU never invoked.
4. **Conclusion**: To improve verification, replacing a firmware-driven directed test with a passive UVM testbench running the *same* firmware yields negligible benefit. Better detection requires active UVM sequences (driving transactions directly via VIP) or more comprehensive firmware test vectors.
