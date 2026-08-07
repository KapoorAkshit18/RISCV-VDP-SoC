`ifndef SOC_DRIVER_SV
`define SOC_DRIVER_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// // Dependencies
// `include "../soc_agent/soc_sequence_item/soc_sequence_item.sv"
// `include "../soc_native_if/soc_native_if.sv"


// =============================================================================
// RISCV-VDP-SoC
// Native Bus UVM Driver
// =============================================================================
//
// Drives the PicoRV32-style native memory interface used by
// soc_mem_interconnect.
//
// Request:
//     m_valid
//     m_write
//     m_addr
//     m_wdata
//     m_strb
//
// Response:
//     m_ready
//     m_rdata
//
// Handshake:
//     Request remains valid until m_ready == 1.
//
// Read:
//     write = 0
//     strb  = 4'b0000
//
// Write:
//     write = 1
//     strb  != 4'b0000
// =============================================================================

class soc_driver extends uvm_driver #(soc_sequence_item);

    `uvm_component_utils(soc_driver)


    // =========================================================================
    // Virtual interface
    // =========================================================================

    virtual soc_native_if vif;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_driver",
        uvm_component parent = null
    );

        super.new(name, parent);

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
                "soc_driver: virtual interface not found in uvm_config_db"
            )

        end

    endfunction


    // =========================================================================
    // Run phase
    // =========================================================================

    virtual task run_phase(uvm_phase phase);

        // Always start with the bus inactive.
        drive_idle();

        forever begin

            seq_item_port.get_next_item(req);

            `uvm_info(
                "DRIVER",
                $sformatf(
                    "Driving transaction: %s",
                    req.convert2string()
                ),
                UVM_MEDIUM
            )

            drive_transaction(req);

            seq_item_port.item_done();

        end

    endtask


    // =========================================================================
    // Drive one native-bus transaction
    // =========================================================================

        virtual task drive_transaction(soc_sequence_item tr);

        // ------------------------------------------------------------
        // Drive request
        // ------------------------------------------------------------

        @(vif.driver_cb);

        vif.driver_cb.m_valid <= 1'b1;
        vif.driver_cb.m_write <= tr.write;
        vif.driver_cb.m_addr  <= tr.addr;
        vif.driver_cb.m_wdata <= tr.wdata;
        vif.driver_cb.m_strb  <= tr.strb;


        // ------------------------------------------------------------
        // Wait for slave/interconnect response.
        //
        // m_valid remains asserted until m_ready.
        // ------------------------------------------------------------

        do begin

            @(vif.driver_cb);

        end while (!vif.driver_cb.m_ready);


        // ------------------------------------------------------------
        // Capture response
        // ------------------------------------------------------------

        tr.ready = vif.driver_cb.m_ready;
        tr.rdata = vif.driver_cb.m_rdata;


        // ------------------------------------------------------------
        // Return bus to idle
        // ------------------------------------------------------------

        vif.driver_cb.m_valid <= 1'b0;
        vif.driver_cb.m_write <= 1'b0;
        vif.driver_cb.m_addr  <= '0;
        vif.driver_cb.m_wdata <= '0;
        vif.driver_cb.m_strb  <= '0;


        `uvm_info(
            "DRIVER",
            $sformatf(
                "Transaction completed: %s",
                tr.convert2string()
            ),
            UVM_MEDIUM
        )

    endtask


    // =========================================================================
    // Idle bus
    // =========================================================================

    virtual task drive_idle();

        vif.driver_cb.m_valid <= 1'b0;
        vif.driver_cb.m_write <= 1'b0;
        vif.driver_cb.m_addr  <= '0;
        vif.driver_cb.m_wdata <= '0;
        vif.driver_cb.m_strb  <= '0;

    endtask

endclass


`endif