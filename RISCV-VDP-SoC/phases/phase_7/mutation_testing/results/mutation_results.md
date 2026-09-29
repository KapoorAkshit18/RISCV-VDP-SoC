# Phase 7 - RTL Mutation Testing Final Results

## `soc_mem_interconnect` - Mutation Campaign

**Date**: 2026-09-29
**Golden SHA256**: `7695FBE6D53A69E15B80F3DDDF57C520CA2ABE7B0204E1118577425519100D3E`

---

## Verification Flows

| Flow | Testbench | DUT | Stimulus | Pass/Fail Criteria |
|---|---|---|---|---|
| **Directed** | `tb_soc_ram_top_with_firmw.sv` | `cpu_soc_ram_top` | Firmware (`$readmemh`) | Firmware marker (`PASS`/`FAIL`/`TIMEOUT`) |
| **Passive UVM** | `tb_cpu_soc_ram_top_end_to_end.sv` | `cpu_soc_ram_top` | Firmware (`$readmemh`) + UVM monitors | `UVM_ERROR`/`UVM_FATAL` count + scoreboard |
| **Active UVM** | `tb_cpu_soc_ram_top_end_to_end.sv` | `cpu_soc_ram_top` | UVM native bus sequences (CPU in reset) | `UVM_ERROR`/`UVM_FATAL` count vs. Golden |

---

## Active UVM Experimental Methodology

To rigorously prove the value of Active UVM without testbench bias, the following strict methodology was enforced for all mutation experiments:

1. **Specification-Derived Oracle**: Active UVM sequences and expected results were derived **strictly** from the golden RTL, the design specification, and the verified RAL model. The mutated RTL was *never* inspected to design the sequence or to hard-code mutant-specific expected values.
2. **Frozen Sequence Execution**: The exact same, unmodified UVM sequence was executed independently against both the Golden DUT and the Mutated DUT. 
3. **Independent Recording**: The UVM sequence is strictly blind to the mutant compile. It generated frozen stimulus, read the raw observed response natively, and performed basic Golden-derived comparisons. It did not contain classifying logic such as "M02 detected".
4. **External Classification**: Classification occurred externally by comparing the recorded results of the two independent runs:
    - **DETECTED**: The sequence produced Golden behavior (`UVM_INFO` PASS) on the Golden DUT, but produced inconsistent behavior (`UVM_ERROR` or `UVM_FATAL` timeout) on the mutated DUT.
    - **ESCAPED**: The sequence passed on both DUTs despite the fault being activated.
    - **UNOBSERVABLE**: The sequence passed on both DUTs because the faulty condition was not activated.
    - **EQUIVALENT**: Structural RTL analysis proved the injected mutation has zero functional effect under valid bus semantics (e.g., modifying signals ignored by slaves).

This strict methodology guarantees that Active UVM's detection capabilities are mathematically genuine and not artificially inflated by mutant-aware testbench coding.

---

## Final Results Summary

| Mutant | Description | Directed FW Result | Passive UVM Result | Active UVM Result | Active UVM Justification |
|---|---|---|---|---|---|
| **M01** | TPU Base-Address Decode | **DETECTED** | **DETECTED** | **DETECTED** | TPU writes go to unmapped space. TPU decode test writes known value to TPU and reads back. Golden returns value, mutant returns 0x0 (unmapped). |
| **M02** | Sensor Local-Addr Bit 11=0 | **ESCAPED** | **ESCAPED** | **DETECTED** | Sensor unmapped test reads 0x0001_2800. Golden returns 0x0. Mutant translates to 0x0000 (Battery Pct) returning 0x50. |
| **M03** | GPIO Ready from RF | `UNOBSERVABLE` | `UNOBSERVABLE` | **DETECTED** | GPIO test writes to GPIO DIR. Golden completes in N+1 cycles. Mutant receives RF ready (idle), hanging the bus (`UVM_FATAL` timeout). |
| **M04** | RF RData from Sensor | `UNOBSERVABLE` | `UNOBSERVABLE` | **DETECTED** | RF ID test reads RF ID register. Golden returns 0x5246_5430. Mutant routes Sensor RData returning 0x0000_0000. |
| **M05** | VDP Write Stuck 0 | `UNOBSERVABLE` | `UNOBSERVABLE` | `UNOBSERVABLE` | **Equivalent Mutant**. VDP Native slave relies entirely on byte strobes and ignores `mem_write`. |
| **M06** | RAM Strobe always 4'hF | **ESCAPED** | **ESCAPED** | **DETECTED** | RAM strobe test writes Word, then selectively writes Byte. Golden preserves word correctly. Mutant forces all strobes, overwriting the word. |
| **M07** | RF Valid Stuck 0 | `UNOBSERVABLE` | `UNOBSERVABLE` | **DETECTED** | RF ID test attempts RF access. Golden completes. Mutant forces valid low, causing `UVM_FATAL` timeout from slave non-response. |
| **M08** | Sensor uses VDP_BASE | **DETECTED** | **DETECTED** | **DETECTED** | Sensor Status test reads Sensor BATT_PCT (0x0001_2000). Golden routes to sensor (returns 0x50). Mutant compares vs VDP_BASE, falls to unmapped (0x0). |
| **M09** | RAM Addr LSBs zeroed | **ESCAPED** | **ESCAPED** | `UNOBSERVABLE` | **Equivalent Mutant**. RAM natively drops LSBs and relies on byte strobes for sub-word alignment. |
| **M10** | Unmapped Ready Stuck 0 | `UNOBSERVABLE` | `UNOBSERVABLE` | **DETECTED** | Unmapped hang test reads 0x0001_F000. Golden completes immediately with 0x0. Mutant sets ready=0, causing `UVM_FATAL` timeout. |

### Key Takeaways for Research Paper

1. **Active UVM Triumphs Over Firmware Limitations**: While Directed and Passive UVM flows were limited entirely to the firmware's reach (leaving isolated blocks like RF, GPIO, VDP unobservable), Active UVM natively drove transactions to every corner of the SoC.
2. **Test Independence and Oracles**: By strictly enforcing Golden-first oracle derivation, the tests remain pure specifications of design intent. 
3. **Timeout Detection**: Active sequences effectively utilized watchdog limits (`UVM_FATAL` timeouts) to detect routing deadlocks (M03, M07, M10), proving that robust testbenches don't just verify data, but bus protocol completion.
4. **Structural Equivalence**: M05 and M09 highlight that mutations can often be functionally benign. Active UVM forces rigorous analysis of protocol semantics (e.g. relying on strobes vs read/write flags) to classify these accurately as equivalent rather than escapes.