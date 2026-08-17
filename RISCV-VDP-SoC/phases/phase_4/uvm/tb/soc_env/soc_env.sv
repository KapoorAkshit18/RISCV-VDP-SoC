`ifndef SOC_ENV_SV
`define SOC_ENV_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// UVM Environment
//
// Architecture:
//
//                         soc_env
//                            |
//                +-----------+-----------+
//                |                       |
//                v                       v
//          native_agent              RAL layer
//                |                       |
//         +------+------+          +-----+------+
//         |             |          |            |
//    sequencer       monitor     reg_block    predictor
//         |             |                       ^
//       driver          |                       |
//         |              +-----------------------+
//         |                 analysis_port
//         v
//        DUT
//
// RAL frontdoor:
//
//     RAL sequence
//          |
//          v
//     soc_reg_block
//          |
//          v
//     soc_reg_adapter
//          |
//          v
//     native sequencer
//          |
//          v
//        driver
//          |
//          v
//         DUT
//
// RAL prediction:
//
//        DUT
//          |
//       monitor
//          |
//   analysis_port
//          |
//          v
//      predictor
//          |
//          v
//     RAL mirror
//
// =============================================================================

class soc_env extends uvm_env;

    `uvm_component_utils(soc_env)


    // =========================================================================
    // Native bus agent
    // =========================================================================

    soc_agent native_agent;
    soc_coverage coverage;

    // =========================================================================
    // RAL
    // =========================================================================

    soc_reg_block     ral_model;
    soc_reg_adapter   ral_adapter;
    soc_reg_predictor ral_predictor;


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


        // =====================================================================
        // Native bus agent
        // =====================================================================

        native_agent = soc_agent::type_id::create(
            "native_agent",
            this
        );


        // ---------------------------------------------------------------------
        // Current environment actively drives the DUT.
        // ---------------------------------------------------------------------

        native_agent.is_active = UVM_ACTIVE;

        // Coverage

        coverage = soc_coverage::type_id::create("coverage",this);



        // =====================================================================
        // RAL MODEL
        // =====================================================================

        ral_model = soc_reg_block::type_id::create(
            "ral_model",
            this
        );

        ral_model.build();


        // ---------------------------------------------------------------------
        // Disable automatic RAL prediction.
        //
        // The monitor/predictor path will update the mirror based on the
        // transaction actually observed on the native bus.
        // ---------------------------------------------------------------------

        ral_model.default_map.set_auto_predict(0);


        // =====================================================================
        // RAL ADAPTER
        // =====================================================================

        ral_adapter = soc_reg_adapter::type_id::create(
            "ral_adapter"
        );


        // =====================================================================
        // RAL PREDICTOR
        // =====================================================================

        ral_predictor = soc_reg_predictor::type_id::create(
            "ral_predictor",
            this
        );


        // ---------------------------------------------------------------------
        // Tell predictor which RAL map and adapter to use.
        // ---------------------------------------------------------------------

        ral_predictor.map = ral_model.default_map;

        ral_predictor.adapter = ral_adapter;

    endfunction


    // =========================================================================
    // Connect phase
    // =========================================================================

   virtual function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);


    // =========================================================================
    // RAL FRONTDOOR CONNECTION
    //
    // RAL register accesses are converted by soc_reg_adapter and then sent
    // through the existing native-bus sequencer.
    //
    // RAL
    //  |
    //  +--> soc_reg_adapter
    //  |
    //  +--> native_agent.sequencer
    // =========================================================================

    ral_model.default_map.set_sequencer(
        native_agent.sequencer,
        ral_adapter
    );


    // =========================================================================
    // RAL PREDICTOR CONNECTION
    //
    // Actual bus transactions observed by the monitor update the RAL mirror.
    // =========================================================================

    native_agent.monitor.analysis_port.connect(
        ral_predictor.bus_in
    );

    // Coverage

    native_agent.monitor.analysis_port.connect(
    coverage.analysis_export
);



    `uvm_info(
        "RAL_CONNECT",
        "RAL default_map connected to native sequencer",
        UVM_LOW
    )


    `uvm_info(
        "RAL_CONNECT",
        "Monitor connected to RAL predictor",
        UVM_LOW
    )

    `uvm_info(
    "COV_CONNECT",
    "Monitor connected to functional coverage",
    UVM_LOW
)

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


        `uvm_info(
            "ENV",
            "SoC RAL model constructed",
            UVM_LOW
        )


        `uvm_info(
            "ENV",
            "SoC RAL predictor connected to native monitor",
            UVM_LOW
        )

    endfunction

endclass


`endif