`ifndef SOC_RAL_TEST_SV
`define SOC_RAL_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// RAL Test
//
// Purpose:
//   Execute the SoC RAL smoke sequence.
//
// Test hierarchy:
//
//     soc_ral_test
//          |
//          v
//       soc_env
//          |
//          +--> native_agent
//          |
//          +--> RAL model
//          |
//          +--> RAL adapter
//          |
//          +--> RAL predictor
//
// =============================================================================

class soc_ral_test extends uvm_test;

    `uvm_component_utils(soc_ral_test)


    // =========================================================================
    // Environment
    // =========================================================================

    soc_env env;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_ral_test",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction


    // =========================================================================
    // Build phase
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);

        super.build_phase(phase);


        // ---------------------------------------------------------------------
        // Create environment
        // ---------------------------------------------------------------------

        env = soc_env::type_id::create(
            "env",
            this
        );

    endfunction


    // =========================================================================
    // Run phase
    // =========================================================================

    virtual task run_phase(uvm_phase phase);

        soc_ral_smoke_sequence ral_seq;


        // ---------------------------------------------------------------------
        // Raise objection
        // ---------------------------------------------------------------------

        phase.raise_objection(this);


        `uvm_info(
            "RAL_TEST",
            "Starting SoC RAL smoke test",
            UVM_LOW
        )


        // ---------------------------------------------------------------------
        // Create RAL sequence
        // ---------------------------------------------------------------------

        ral_seq = soc_ral_smoke_sequence::type_id::create(
            "ral_seq"
        );


        // ---------------------------------------------------------------------
        // Give sequence access to the environment RAL model.
        // ---------------------------------------------------------------------

        ral_seq.ral_model = env.ral_model;


        // ---------------------------------------------------------------------
        // Start RAL sequence on existing native sequencer.
        // ---------------------------------------------------------------------

        ral_seq.start(
            env.native_agent.sequencer
        );


        `uvm_info(
            "RAL_TEST",
            "SoC RAL smoke sequence completed",
            UVM_LOW
        )


        // ---------------------------------------------------------------------
        // Drop objection
        // ---------------------------------------------------------------------

        phase.drop_objection(this);

    endtask


    // =========================================================================
    // End of elaboration
    // =========================================================================

    virtual function void end_of_elaboration_phase(
        uvm_phase phase
    );

        super.end_of_elaboration_phase(phase);


        `uvm_info(
            "RAL_TEST",
            "==============================================",
            UVM_LOW
        )

        `uvm_info(
            "RAL_TEST",
            "        SOC RAL TEST CREATED",
            UVM_LOW
        )

        `uvm_info(
            "RAL_TEST",
            "==============================================",
            UVM_LOW
        )

    endfunction

endclass


`endif