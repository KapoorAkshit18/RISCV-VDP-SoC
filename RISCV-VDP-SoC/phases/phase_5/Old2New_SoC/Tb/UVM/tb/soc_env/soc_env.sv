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
//              +-------------+-------------+
//              |             |             |
//              v             v             v
//       native_agent       RAL        TPU scoreboard
//              |             |             ^
//       +------+------+      |             |
//       |             |      |             |
//   sequencer      monitor   |             |
//       |             |      |             |
//     driver         |      |             |
//       |             +------+------+------+
//       |                    |
//       v                    v
//      DUT             analysis consumers
//
// Monitor analysis_port is connected to:
//
//   1. RAL predictor
//      -> Updates RAL mirror from actual DUT bus activity
//
//   2. Functional coverage
//      -> Samples observed native-bus transactions
//
//   3. TPU scoreboard
//      -> Filters TPU MMIO transactions
//      -> Reconstructs 64-bit TPU operands
//      -> Invokes C reference model
//      -> Compares TPU results against golden results
//
// RAL frontdoor:
//
//   RAL sequence
//        |
//        v
//   soc_reg_block
//        |
//        v
//   soc_reg_adapter
//        |
//        v
//   native_agent.sequencer
//        |
//        v
//      driver
//        |
//        v
//       DUT
//
// RAL prediction:
//
//       DUT
//        |
//     monitor
//        |
//   analysis_port
//        |
//        v
//     predictor
//        |
//        v
//    RAL mirror
//
// =============================================================================

class soc_env extends uvm_env;

    `uvm_component_utils(soc_env)

    // =========================================================================
    // Native bus agent
    // =========================================================================

    soc_agent native_agent;

    // =========================================================================
    // Functional coverage
    // =========================================================================

    soc_coverage coverage;

    // =========================================================================
    // RAL components
    // =========================================================================

    soc_reg_block     ral_model;
    soc_reg_adapter   ral_adapter;
    soc_reg_predictor ral_predictor;

    // =========================================================================
    // TPU scoreboard
    //
    // Receives transactions from the same native-bus monitor used by the
    // existing RAL predictor and functional coverage.
    // =========================================================================

    soc_tpu_scoreboard tpu_scoreboard;
    bit e2e_mode;
    
    // 

    tpu_monitor tpu_mon;

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
        // The environment actively drives the DUT.
        // ---------------------------------------------------------------------

  

        if (!uvm_config_db#(bit)::get(
                this,
                "",
                "e2e_mode",
                e2e_mode
            )) begin
            e2e_mode = 0;
        end

        native_agent.is_active =
            e2e_mode ? UVM_PASSIVE : UVM_ACTIVE;

        // =====================================================================
        // Functional coverage
        // =====================================================================

        coverage = soc_coverage::type_id::create(
            "coverage",
            this
        );

        // =====================================================================
        // TPU scoreboard
        // =====================================================================
        //
        // The scoreboard is transaction-level and observes the same native
        // bus traffic generated by the monitor.
        //
        // It does NOT directly access PicoRV32 internal signals.
        //
        // =====================================================================

        tpu_scoreboard = soc_tpu_scoreboard::type_id::create(
            "tpu_scoreboard",
            this
        );

        // tpu monitor

            tpu_mon = tpu_monitor::type_id::create(
                "tpu_mon",
                this
            );




        // =====================================================================
        // RAL model
        // =====================================================================

        ral_model = soc_reg_block::type_id::create(
            "ral_model",
            this
        );

        ral_model.build();

        // ---------------------------------------------------------------------
        // Disable automatic RAL prediction.
        //
        // The monitor/predictor path explicitly updates the RAL mirror using
        // the transaction actually observed on the native bus.
        // ---------------------------------------------------------------------

        ral_model.default_map.set_auto_predict(0);

        // =====================================================================
        // RAL adapter
        // =====================================================================

        ral_adapter = soc_reg_adapter::type_id::create(
            "ral_adapter"
        );

        // =====================================================================
        // RAL predictor
        // =====================================================================

        ral_predictor = soc_reg_predictor::type_id::create(
            "ral_predictor",
            this
        );

        // ---------------------------------------------------------------------
        // Configure predictor with the RAL map and adapter.
        // ---------------------------------------------------------------------

        ral_predictor.map     = ral_model.default_map;
        ral_predictor.adapter = ral_adapter;

    endfunction


    // =========================================================================
    // Connect phase
    // =========================================================================

    virtual function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        // =====================================================================
        // TPU SCOREBOARD CONNECTION
        // =====================================================================
        //
        // Native monitor
        //       |
        //       v
        // analysis_port
        //       |
        //       v
        // TPU scoreboard
        //
        // The scoreboard receives every accepted native-bus transaction and
        // internally filters for the TPU address window:
        //
        //       0x0001_4000 - 0x0001_4FFF
        //
        // Non-TPU transactions are ignored by the scoreboard.
        // =====================================================================

        native_agent.monitor.analysis_port.connect(
            tpu_scoreboard.analysis_imp
        );


        tpu_mon.analysis_port.connect(
        tpu_scoreboard.tpu_analysis_imp
         );
        // =====================================================================
        // RAL FRONTDOOR CONNECTION
        // =====================================================================
        //
        // RAL
        //  |
        //  v
        // soc_reg_adapter
        //  |
        //  v
        // native sequencer
        //  |
        //  v
        // driver
        //  |
        //  v
        // DUT
        //
        // =====================================================================

        if (!e2e_mode) begin

            ral_model.default_map.set_sequencer(
                native_agent.sequencer,
                ral_adapter
            );

        end

        // =====================================================================
        // RAL PREDICTOR CONNECTION
        // =====================================================================
        //
        // Actual native-bus activity observed by the monitor updates the
        // corresponding RAL mirror values.
        // =====================================================================

        native_agent.monitor.analysis_port.connect(
            ral_predictor.bus_in
        );

        // =====================================================================
        // FUNCTIONAL COVERAGE CONNECTION
        // =====================================================================
        //
        // The same observed transaction stream is sampled by the functional
        // coverage component.
        // =====================================================================

        native_agent.monitor.analysis_port.connect(
            coverage.analysis_export
        );

        // =====================================================================
        // Informational messages
        // =====================================================================

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

        `uvm_info(
            "TPU_CONNECT",
            "Monitor connected to TPU scoreboard",
            UVM_LOW
        )

    endfunction


    // =========================================================================
    // End-of-elaboration phase
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

        `uvm_info(
            "ENV",
            "Functional coverage connected to native monitor",
            UVM_LOW
        )

        `uvm_info(
            "ENV",
            "TPU scoreboard connected to native monitor",
            UVM_LOW
        )

    endfunction

endclass

`endif