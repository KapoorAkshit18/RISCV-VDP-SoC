# TPU Mutation Testing — Evidence Matrix (Phase 7)

## Verification Flows

| Flow | Stimulus | Bus Master | What it covers |
|---|---|---|---|
| **Active UVM RAL** | UVM RAL sequence (CPU in reset) | Testbench | Full register map: reset state, all RW readbacks, RO write-ignore, unmapped access, BUSY guard, end-to-end result |
| **Firmware Directed** | firmware_test03.hex via `$readmemh` | PicoRV32 CPU | CPU pipeline → bus adapter → interconnect → MMIO write path → START → poll DONE → read results |
| **Firmware UVM Passive** | firmware_test03.hex + UVM monitors | PicoRV32 CPU | Same as directed but scoreboard compares results against C DPI reference model |

---

## New Active UVM RAL Checks (not exercised by firmware)

| Check | Why firmware misses it |
|---|---|
| Reset state — all RW regs = 0 | Firmware writes registers immediately after reset, never reads them first |
| Full W0–W4 + INPUT0–1 readback (all 20 half-words) | Firmware only writes; never reads back weights or inputs to verify storage |
| RO write-ignore on RESULT0/RESULT1 | Firmware only reads results, never attempts to write them |
| Unmapped address (0x4060) returns 0 | Firmware never accesses outside the defined register map |
| BUSY guard — second START ignored while running | Firmware never retriggers; single START per run |

---

## Mutation Results

| Mutant | RTL Fault | Active UVM RAL | FW Directed | FW UVM Passive | Caught by |
|---|---|---|---|---|---|
| **M_TPU_01** | CTRL START bit forced 0 — `axis_start` never pulses | DETECTED | DETECTED | DETECTED | All flows — timeout on DONE poll |
| **M_TPU_02** | WEIGHT4_L write decode maps to WEIGHT3_L offset | DETECTED | DETECTED | DETECTED | RAL: W4_L readback mismatch; FW: wrong weight sent → result mismatch |
| **M_TPU_03** | INPUT0_L read mux returns `input1[31:0]` | DETECTED | ESCAPED | ESCAPED | Active UVM only — firmware writes INPUT0≠INPUT1 but never reads back |
| **M_TPU_04** | RESULT0_L read mux returns `result1[31:0]` | DETECTED | DETECTED | DETECTED | RAL: result readback mismatch; FW UVM: scoreboard catches wrong result |
| **M_TPU_05** | STATUS BUSY/DONE bits swapped | DETECTED | DETECTED | DETECTED | All flows — premature result read before computation completes |

---

## M_TPU_03 — Why firmware escapes

firmware_test03 writes `INPUT0 = 0x1400140020002000` and `INPUT1 = 0x1400200014002000`. These are different values, so if INPUT0_L readback returns INPUT1_L data the values differ. However firmware **never reads INPUT0_L back** — it only writes then fires START. The mutant still delivers the correct `input1` value to the AXI-Stream beat that carries input0 data because the write path is unaffected (only the read mux is broken). The NN computation therefore uses the correct hardware register contents and produces the correct result. Only the Active UVM RAL sequence explicitly reads INPUT0_L after writing it and catches the mismatch.

---

## Detection Summary

| Flow | Detected | Escaped |
|---|---|---|
| Active UVM RAL | 5 / 5 | 0 |
| Firmware Directed | 4 / 5 | 1 (M_TPU_03) |
| Firmware UVM Passive | 4 / 5 | 1 (M_TPU_03) |

Active UVM RAL is the only flow that catches M_TPU_03 because it is the only flow that reads back the input registers after writing them.

---

## How to Run

From `phases/phase_7/mutation_testing/`:

```powershell
# Full campaign — all 3 flows, all 5 mutants + golden
.\scripts\tpu_batch_run.ps1

# Results written to tpu_batch_results.txt (CSV: mutant,active_ral,fw_directed,fw_uvm)
```
