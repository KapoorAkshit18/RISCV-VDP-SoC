`ifndef SOC_SENSOR_TEST_SV
`define SOC_SENSOR_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// RISCV-VDP-SoC
// UVM SENSOR Directed Test
// =============================================================================
//
// Purpose:
//   Top-level test class that instantiates the UVM environment and exercises
//   the SENSOR MMIO window (0x0001_2000) so functional coverage closes the
//   SENSOR-related bins (cp_target.SENSOR, cp_addr.SENSOR_BASE,
//   cross_rw_target <*,SENSOR>).
//
// Execution:
//   Called via Makefile using +UVM_TESTNAME=soc_sensor_test
// =============================================================================

class soc_sensor_test extends uvm_test;

    `uvm_component_utils(soc_sensor_test)


    // =========================================================================
    // Environment instance
    // =========================================================================

    soc_env env;


    // =========================================================================
    // Timeout guard (mirrors the 90,000 ns fallback used in soc_tpu_test)
    // =========================================================================

    localparam time TIMEOUT_NS = 90_000;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(string name = "soc_sensor_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction


    // =========================================================================
    // Build phase
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create the top-level environment (same env/covergroup instance
        // shared across all directed tests)
        env = soc_env::type_id::create("env", this);
    endfunction


    // =========================================================================
    // End-of-elaboration phase
    // =========================================================================

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        `uvm_info("TEST_TOPOLOGY", this.sprint(), UVM_LOW)
    endfunction


    // =========================================================================
    // Run phase
    // =========================================================================

    virtual task run_phase(uvm_phase phase);

        // 1. Raise objection to keep simulation alive
        phase.raise_objection(this, "Starting SENSOR firmware sequence");

        // 2. Wait for either the sensor-done event or the timeout,
        //    whichever comes first — avoids an indefinite hang if
        //    tb_done_event is never triggered (e.g. firmware bug,
        //    monitor not wired up).
        fork
            begin
                @env.sensor_mon.sensor_done_event;
                `uvm_info("TEST", "SENSOR DONE event observed.", UVM_LOW)
            end
            begin
                #(TIMEOUT_NS);
                `uvm_info("TEST", $sformatf("%0d ns timeout reached.", TIMEOUT_NS), UVM_LOW)
            end
        join_any
        disable fork;

        `uvm_info("TEST", "soc_sensor_test completed.", UVM_LOW)

        // 3. Drop objection to allow simulation to finish gracefully
        phase.drop_objection(this, "Finished SENSOR firmware sequence");

    endtask

endclass

`endif