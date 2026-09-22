`ifndef SOC_COVERAGE_TEST_SV
`define SOC_COVERAGE_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// Functional Coverage Test
//
// Uses the existing:
//   soc_env
//   soc_agent
//   soc_driver
//   soc_monitor
//   soc_sequencer
//
// The coverage sequence is directed specifically toward closing functional
// coverage holes identified in the coverage report.
// =============================================================================

class soc_coverage_test extends uvm_test;

    `uvm_component_utils(soc_coverage_test)


    // =========================================================================
    // Environment
    // =========================================================================

    soc_env env;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_coverage_test",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction


    // =========================================================================
    // Build phase
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        env = soc_env::type_id::create(
            "env",
            this
        );

    endfunction


    // =========================================================================
    // Run phase
    // =========================================================================

    virtual task run_phase(uvm_phase phase);

        soc_coverage_sequence cov_seq;

        phase.raise_objection(this);


        `uvm_info(
            "COV_TEST",
            "Starting SoC functional coverage test",
            UVM_LOW
        )


        // ---------------------------------------------------------------------
        // Create and start coverage closure sequence
        // ---------------------------------------------------------------------

        cov_seq = soc_coverage_sequence::type_id::create(
            "cov_seq"
        );

        cov_seq.start(
            env.native_agent.sequencer
        );


        `uvm_info(
            "COV_TEST",
            "SoC functional coverage sequence completed",
            UVM_LOW
        )


        phase.drop_objection(this);

    endtask


    // =========================================================================
    // Report phase
    // =========================================================================

    virtual function void report_phase(uvm_phase phase);

        super.report_phase(phase);

        `uvm_info(
            "COV_TEST",
            "SoC functional coverage test completed",
            UVM_NONE
        )

    endfunction


endclass


`endif