`ifndef SOC_ACTIVE_SENSOR_TEST_SV
`define SOC_ACTIVE_SENSOR_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// RISCV-VDP-SoC
// UVM ACTIVE SENSOR Test
//
// Demonstrates active UVM mastery of the native bus with the CPU disabled.
// Targets the specific address 0x0001_2800 to detect mutation M02.
// =============================================================================

class soc_active_sensor_sequence extends uvm_sequence#(soc_sequence_item);
    `uvm_object_utils(soc_active_sensor_sequence)

    function new(string name = "soc_active_sensor_sequence");
        super.new(name);
    endfunction

    virtual task body();
        soc_sequence_item req;
        
        `uvm_info("ACTIVE_SEQ", "Starting active read to 0x0001_2800", UVM_LOW)
        
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.write = 1'b0;
        req.addr  = 32'h0001_2800; // Sensor base + 0x800
        req.wdata = 32'h0;
        req.strb  = 4'h0; // Read
        finish_item(req);
        
        // Wait for response to be captured in req
        // Golden behavior: Unmapped inside sensor (0x800 offset) -> returns 0.
        // Mutated M02 (bit 11=0): Routes to 0x000 (battery_percent) -> returns non-zero.
        
        if (req.rdata != 32'h0000_0000) begin
            `uvm_error("ACTIVE_SEQ", $sformatf("Mutation DETECTED! Expected 0x0 at 0x0001_2800, got 0x%08h", req.rdata))
        end else begin
            `uvm_info("ACTIVE_SEQ", "Mutation ESCAPED (or Golden RTL). Read 0x0 as expected.", UVM_LOW)
        end
        
    endtask
endclass

class soc_active_sensor_test extends uvm_test;
    `uvm_component_utils(soc_active_sensor_test)

    soc_env env;

    function new(string name = "soc_active_sensor_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_sensor_sequence seq;
        phase.raise_objection(this, "Starting ACTIVE SENSOR test");

        // Wait a short time for reset to settle
        #200ns;

        seq = soc_active_sensor_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        // Allow time for completion
        #100ns;

        phase.drop_objection(this, "Finished ACTIVE SENSOR test");
    endtask
endclass

`endif

