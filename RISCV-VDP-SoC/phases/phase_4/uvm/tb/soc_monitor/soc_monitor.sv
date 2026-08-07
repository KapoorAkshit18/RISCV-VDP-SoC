`ifndef SOC_MONITOR_SV
`define SOC_MONITOR_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// // Dependencies
// `include "../soc_agent/soc_sequence_item/soc_sequence_item.sv"
// `include "../soc_native_if/soc_native_if.sv"


// // =============================================================================
// // RISCV-VDP-SoC
// Native Bus UVM Monitor
// =============================================================================
//
// Observes:
//
//     m_valid
//     m_write
//     m_addr
//     m_wdata
//     m_strb
//     m_ready
//     m_rdata
//
// A transaction is considered complete when:
//
//     m_valid && m_ready
//
// The completed transaction is broadcast through:
//
//     analysis_port
//
// Consumers can include:
//
//     - scoreboard/checker
//     - reference model
//     - predictor
//     - functional coverage
//     - protocol checking
// =============================================================================

class soc_monitor extends uvm_monitor;

    `uvm_component_utils(soc_monitor)


    // =========================================================================
    // Virtual interface
    // =========================================================================

    virtual soc_native_if vif;


    // =========================================================================
    // Analysis port
    // =========================================================================

    uvm_analysis_port #(soc_sequence_item) analysis_port;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_monitor",
        uvm_component parent = null
    );

        super.new(name, parent);

        analysis_port = new("analysis_port", this);

    endfunction


    // =========================================================================
    // Build phase
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db#(virtual soc_native_if)::get(
                this,
                "",
                "vif",
                vif
            )) begin

            `uvm_fatal(
                "NOVIF",
                "soc_monitor: virtual interface not found in uvm_config_db"
            )

        end

    endfunction


    // =========================================================================
    // Run phase
    // =========================================================================

    virtual task run_phase(uvm_phase phase);

        forever begin

            collect_transaction();

        end

    endtask


    // =========================================================================
    // Collect completed transaction
    // =========================================================================

    virtual task collect_transaction();

        soc_sequence_item tr;

        // ------------------------------------------------------------
        // Wait for clock
        // ------------------------------------------------------------

        @(vif.monitor_cb);


        // ------------------------------------------------------------
        // A transaction completes only when both VALID and READY
        // are asserted.
        // ------------------------------------------------------------

        if (vif.monitor_cb.m_valid &&
            vif.monitor_cb.m_ready) begin

            tr = soc_sequence_item::type_id::create(
                "tr",
                this
            );


            // --------------------------------------------------------
            // Capture request
            // --------------------------------------------------------

            tr.write = vif.monitor_cb.m_write;
            tr.addr  = vif.monitor_cb.m_addr;
            tr.wdata = vif.monitor_cb.m_wdata;
            tr.strb  = vif.monitor_cb.m_strb;


            // --------------------------------------------------------
            // Capture response
            // --------------------------------------------------------

            tr.ready = vif.monitor_cb.m_ready;
            tr.rdata = vif.monitor_cb.m_rdata;


            // --------------------------------------------------------
            // Determine address target
            // --------------------------------------------------------

            tr.set_target();


            // --------------------------------------------------------
            // Publish transaction
            // --------------------------------------------------------

            analysis_port.write(tr);


            `uvm_info(
                "MONITOR",
                $sformatf(
                    "Observed transaction: %s",
                    tr.convert2string()
                ),
                UVM_MEDIUM
            )

        end

    endtask

endclass


`endif