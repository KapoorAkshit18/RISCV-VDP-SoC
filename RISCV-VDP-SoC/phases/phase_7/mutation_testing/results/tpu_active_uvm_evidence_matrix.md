# TPU UVM RAL Mutation Experiment Evidence Matrix

## Methodology
The experiment validates the TPU (Tensor Processing Unit) register interface and native SOC wrapper (`nn_axi_wrapper.v`) using UVM RAL APIs in an Active UVM environment. The Golden RTL behavior was first verified using `soc_active_tpu_ral_test` which programs weights and inputs, triggers `START`, polls the `STATUS` register for `DONE`, and reads the results. Five functional mutations were introduced to the wrapper logic and run against the exact same, frozen UVM sequence to verify the testbench's detection capability.

## Evidence Matrix

### 1. M_TPU_01
*   **Mutation Intent**: CTRL START bit is incorrectly ignored.
*   **RTL Modification**: 
    ```verilog
    // GOLDEN: if (bus_strb[0] && bus_wdata[0] &&
    if (bus_strb[0] && 1'b0 &&
    ```
*   **Golden Behavior**: Writing `1` to `REG_CONTROL` pulses `axis_start`. The TPU computes and eventually sets the `DONE` bit (bit 1 of `REG_STATUS`).
*   **Mutant Behavior**: Writing `1` to `REG_CONTROL` is ignored. `axis_start` is never pulsed, the computation never begins, and `DONE` is never set.
*   **Classification**: **DETECTED**
*   **Evidence**: The RAL sequence hangs while polling the `STATUS` register and is caught by the testbench timeout mechanism.
    ```
    [ACTIVE_TPU] Timeout polling for TPU DONE bit
    ```

### 2. M_TPU_02
*   **Mutation Intent**: TPU weight register `WEIGHT4_L` is mapped to the wrong offset.
*   **RTL Modification**:
    ```verilog
    // GOLDEN: else if (bus_addr[7:0] == REG_WEIGHT4_L) begin
    else if (bus_addr[7:0] == REG_WEIGHT3_L) begin
    ```
*   **Golden Behavior**: Writing to `0x30` (`WEIGHT4_L`) correctly stores the data in the `weight4` register.
*   **Mutant Behavior**: Address `0x30` decoding is replaced by `0x28` (`WEIGHT3_L`). Writes to `0x30` fall through and are ignored.
*   **Classification**: **DETECTED**
*   **Evidence**: The RAL sequence explicitly reads back `WEIGHT4_L` after writing it to verify the register mapping and detects the mismatch.
    ```
    [ACTIVE_TPU] W4_L readback failed
    [TPU_RESULT_MISMATCH] TPU result mismatch: ACTUAL R0=0200020002000200 R1=0000000000000000 | EXPECTED R0=0200020002000200 R1=00000000000003ff
    ```

### 3. M_TPU_03
*   **Mutation Intent**: `INPUT0_L` register readback incorrectly mapped to `INPUT1_L`.
*   **RTL Modification**:
    ```verilog
    // GOLDEN: REG_INPUT0_L: bus_rdata = input0[31:0];
    REG_INPUT0_L: bus_rdata = input1[31:0];
    ```
*   **Golden Behavior**: Reading `0x38` (`INPUT0_L`) returns the data stored in `input0`.
*   **Mutant Behavior**: Reading `0x38` incorrectly returns the data stored in `input1`.
*   **Classification**: **DETECTED**
*   **Evidence**: The RAL sequence reads back `INPUT0_L` after programming it and detects the incorrect value returned on the bus.
    ```
    [ACTIVE_TPU] IN0_L readback failed
    ```

### 4. M_TPU_04
*   **Mutation Intent**: `RESULT0_L` readback incorrectly routed to `RESULT1_L`.
*   **RTL Modification**:
    ```verilog
    // GOLDEN: REG_RESULT0_L: bus_rdata = result0[31:0];
    REG_RESULT0_L: bus_rdata = result1[31:0];
    ```
*   **Golden Behavior**: After completion, reading `0x50` (`RESULT0_L`) returns the lower 32 bits of `result0`.
*   **Mutant Behavior**: Reading `0x50` returns the lower 32 bits of `result1`.
*   **Classification**: **DETECTED**
*   **Evidence**: The sequence issues the read which triggers the TPU scoreboard's passive checking mechanism against the C++ reference model, which identifies the incorrect result data.
    ```
    [TPU_FAIL] RESULT0_LO MISMATCH: addr=0x00014050 expected=0x02000200 actual=0x000003ff
    ```

### 5. M_TPU_05
*   **Mutation Intent**: `STATUS` bits `BUSY` and `DONE` are swapped.
*   **RTL Modification**:
    ```verilog
    // GOLDEN: bus_rdata = {30'd0, done_latched, axis_busy};
    bus_rdata = {30'd0, axis_busy, done_latched};
    ```
*   **Golden Behavior**: Reading `STATUS` (`0x04`) returns `BUSY` on bit 0 and `DONE` on bit 1.
*   **Mutant Behavior**: Reading `STATUS` returns `DONE` on bit 0 and `BUSY` on bit 1. 
*   **Classification**: **DETECTED**
*   **Evidence**: The RAL sequence polls bit 1 expecting `DONE`. Because the bits are swapped, it reads the active `BUSY` signal as `DONE` and prematurely assumes the computation is complete. It issues a read for `RESULT0_L` before the calculation finishes, causing the scoreboard to catch a mismatch between the stale `0x00000000` data and the expected reference model data.
    ```
    [TPU_FAIL] RESULT0_LO MISMATCH: addr=0x00014050 expected=0x02000200 actual=0x00000000
    ```
