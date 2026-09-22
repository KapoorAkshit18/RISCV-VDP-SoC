`ifndef SOC_TPU_TEST_SV
`define SOC_TPU_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// RISCV-VDP-SoC
// UVM TPU Directed Test
// =============================================================================
//
// Purpose:
//   Top-level test class that instantiates the UVM environment and explicitly
//   starts the TPU directed sequence on the native bus sequencer, exercising
//   the TPU MMIO window (0x0001_4000) so the TPU scoreboard has real
//   transactions to check against the C reference model.
//
// Execution:
//   Called via Makefile using +UVM_TESTNAME=soc_tpu_test
// =============================================================================

class soc_tpu_test extends uvm_test;

    `uvm_component_utils(soc_tpu_test)


    // =========================================================================
    // Environment instance
    // =========================================================================

    soc_env env;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(string name = "soc_tpu_test", uvm_component parent = null);  // consumes no simulation time
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
        super.end_of_elaboration_phase(phase);            // shows the hierarchy

        // Print the testbench topology for debugging
        `uvm_info("TEST_TOPOLOGY", this.sprint(), UVM_LOW)
    endfunction


    // =========================================================================
    // Run phase
    // =========================================================================

    virtual task run_phase(uvm_phase phase);
        soc_tpu_directed_sequence tpu_seq;

        // 1. Raise objection to keep simulation alive
        // phase.raise_objection(this, "Starting TPU directed sequence");
         phase.raise_objection(this, "Starting TPU firmware sequence");

        @env.tpu_mon.tpu_done_event;
        // `uvm_info("TEST", "Starting soc_tpu_test...", UVM_LOW)

        // // 2. Create the sequence through the UVM factory
        // tpu_seq = soc_tpu_directed_sequence::type_id::create("tpu_seq");

        // // 3. Start the sequence on the native agent's sequencer
        // tpu_seq.start(env.native_agent.sequencer);

        `uvm_info("TEST", "soc_tpu_test completed.", UVM_LOW)

        // 4. Drop objection to allow simulation to finish gracefully
        phase.drop_objection(this, "Finished TPU directed sequence");

    endtask

endclass

`endif