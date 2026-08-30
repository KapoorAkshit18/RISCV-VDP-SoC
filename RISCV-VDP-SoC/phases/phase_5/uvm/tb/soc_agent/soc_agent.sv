`ifndef SOC_AGENT_SV
`define SOC_AGENT_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// Dependencies
// `include "/soc_sequence_item/soc_sequence_item.sv"
// `include "/soc_sequencer/soc_sequencer.sv"
// `include "../soc_driver/soc_driver.sv"
// `include "../soc_monitor/soc_monitor.sv"
// `include "../soc_native_if/soc_native_if.sv"


// =============================================================================
// RISCV-VDP-SoC
// Native Bus UVM Agent
// =============================================================================
//
// Active agent:
//
//     sequence
//        |
//        v
//     sequencer
//        |
//        v
//     driver
//        |
//        v
//       DUT
//        |
//        v
//     monitor
//
// Passive agent:
//
//       DUT
//        |
//        v
//     monitor
//
// The agent is reusable for the native memory-mapped bus.
//
// It is NOT an AXI4-Lite agent. The current RTL contains no AXI4-Lite
// interface, so this agent correctly models the actual PicoRV32/native bus.
// =============================================================================

class soc_agent extends uvm_agent;

    `uvm_component_utils(soc_agent)


    // =========================================================================
    // Agent components
    // =========================================================================

    soc_sequencer sequencer;
    soc_driver    driver;
    soc_monitor   monitor;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_agent",
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
        // Monitor always exists.
        // ------------------------------------------------------------

        monitor = soc_monitor::type_id::create(
            "monitor",
            this
        );


        // ------------------------------------------------------------
        // Sequencer + driver only exist for ACTIVE agent.
        // ------------------------------------------------------------

        if (is_active == UVM_ACTIVE) begin

            sequencer = soc_sequencer::type_id::create(
                "sequencer",
                this
            );

            driver = soc_driver::type_id::create(
                "driver",
                this
            );

        end

    endfunction


    // =========================================================================
    // Connect phase
    // =========================================================================

    virtual function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);


        if (is_active == UVM_ACTIVE) begin

            driver.seq_item_port.connect(
                sequencer.seq_item_export
            );

        end

    endfunction


    // =========================================================================
    // End-of-elaboration information
    // =========================================================================

       virtual function void end_of_elaboration_phase(
        uvm_phase phase
    );

        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "AGENT",
            $sformatf(
                "Native bus agent configured as %s",
                (is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE"
            ),
            UVM_LOW
        )

    endfunction

endclass

`endif