`ifndef SOC_SENSOR_TEST_SV
`define SOC_SENSOR_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// RISCV-VDP-SoC
// UVM SENSOR Firmware Test
//
// Firmware drives the SENSOR MMIO window (0x0001_2000). The test ends when
// sensor_mon sees the firmware completion marker, or fails on timeout.
//
// Run with:
//   +UVM_TESTNAME=soc_sensor_test
// Optional:
//   +SENSOR_TIMEOUT_NS=<ns>
// =============================================================================

class soc_sensor_test extends uvm_test;

    `uvm_component_utils(soc_sensor_test)

    soc_env env;

    int unsigned timeout_ns = 90_000;


    function new(string name = "soc_sensor_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction


    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction


    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info("TEST_TOPOLOGY", this.sprint(), UVM_LOW)
    endfunction


    virtual task run_phase(uvm_phase phase);
        bit done = 0;

        void'($value$plusargs("SENSOR_TIMEOUT_NS=%d", timeout_ns));

        phase.raise_objection(this, "Starting SENSOR firmware test");

        fork
            begin
                @(env.sensor_mon.sensor_done_event);
                done = 1;
            end
            begin
                #(timeout_ns);
            end
        join_any
        disable fork;

        if (done) begin
            // Let the last bus transactions reach coverage before ending
            #100;
            `uvm_info("TEST", "SENSOR firmware done marker observed.", UVM_LOW)
        end
        else begin
            `uvm_error("TEST",
                $sformatf("Timeout: no SENSOR done marker within %0d ns", timeout_ns))
        end

        phase.drop_objection(this, "Finished SENSOR firmware test");
    endtask

endclass

`endif
