`ifndef SOC_SMOKE_TEST_SV
`define SOC_SMOKE_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// RISCV-VDP-SoC
// UVM Smoke Test
// =============================================================================
//
// Purpose:
//   Top-level test class that instantiates the UVM environment and explicitly 
//   starts the smoke sequence on the native bus sequencer.
//
// Execution:
//   Called via Makefile using +UVM_TESTNAME=soc_smoke_test
// =============================================================================

class soc_smoke_test extends uvm_test;

    `uvm_component_utils(soc_smoke_test)


    // =========================================================================
    // Environment instance
    // =========================================================================
    
    soc_env env;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(string name = "soc_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction


    // =========================================================================
    // Build phase
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Create the top-level environment
        env = soc_env::type_id::create("env", this);
    endfunction


    // =========================================================================
    // End-of-elaboration phase
    // =========================================================================

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        
        // Print the testbench topology for debugging
        `uvm_info("TEST_TOPOLOGY", this.sprint(), UVM_LOW)
    endfunction


    // =========================================================================
    // Run phase
    // =========================================================================

    virtual task run_phase(uvm_phase phase);
        soc_smoke_sequence smoke_seq;

        // 1. Raise objection to keep simulation alive
        phase.raise_objection(this, "Starting smoke sequence");

        `uvm_info("TEST", "Starting soc_smoke_test...", UVM_LOW)

        // 2. Create the sequence through the UVM factory
        smoke_seq = soc_smoke_sequence::type_id::create("smoke_seq");

        // 3. Start the sequence on the native agent's sequencer
        smoke_seq.start(env.native_agent.sequencer);

        `uvm_info("TEST", "soc_smoke_test completed.", UVM_LOW)

        // 4. Drop objection to allow simulation to finish gracefully
        phase.drop_objection(this, "Finished smoke sequence");
        
    endtask

endclass

`endif