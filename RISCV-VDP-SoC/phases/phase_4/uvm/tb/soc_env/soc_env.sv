`ifndef SOC_ENV_SV
`define SOC_ENV_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// UVM Environment
// =============================================================================
//
// Current architecture:
//
//                         soc_env
//                            |
//                     +------+-------+
//                     |              |
//                     v              v
//                native_agent    analysis path
//                     |
//              +------+------+
//              |             |
//          sequencer       monitor
//              |
//            driver
//              |
//             DUT
//
// Later:
//
//        monitor
//           |
//           +----> predictor/reference model
//           |
//           +----> scoreboard/checker
//           |
//           +----> functional coverage
//
// RAL will be added as a separate layer on top of the native bus.
// =============================================================================

class soc_env extends uvm_env;

    `uvm_component_utils(soc_env)


    // =========================================================================
    // Native bus agent
    // =========================================================================

    soc_agent native_agent;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_env",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction


    // =========================================================================
    // Build phase
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);

        super.build_phase(phase);


        // ------------------------------------------------------------
        // Create native bus agent through factory.
        // ------------------------------------------------------------

        native_agent = soc_agent::type_id::create(
            "native_agent",
            this
        );


        // ------------------------------------------------------------
        // The current environment actively drives the DUT.
        //
        // Later tests can override this to UVM_PASSIVE if required.
        // ------------------------------------------------------------

        native_agent.is_active = UVM_ACTIVE;

    endfunction


    // =========================================================================
    // Connect phase
    // =========================================================================

    virtual function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        // Analysis connections will be added here when the predictor,
        // scoreboard and coverage components are instantiated.

    endfunction


    // =========================================================================
    // End-of-elaboration
    // =========================================================================

    virtual function void end_of_elaboration_phase(
        uvm_phase phase
    );

        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "ENV",
            "RISCV-VDP-SoC UVM environment constructed",
            UVM_LOW
        )

        `uvm_info(
            "ENV",
            "Native bus agent is ACTIVE",
            UVM_LOW
        )

    endfunction

endclass


`endif