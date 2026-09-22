`ifndef SOC_DRIVER_SV
`define SOC_DRIVER_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// // Dependencies
// `include "../soc_agent/soc_sequence_item/soc_sequence_item.sv"
// `include "../soc_native_if/soc_native_if.sv"

class soc_driver extends uvm_driver #(soc_sequence_item);

    `uvm_component_utils(soc_driver)

    // =========================================================================
    // Virtual interface
    // =========================================================================

    virtual soc_native_if vif;

    // =========================================================================
    // Configuration
    // =========================================================================

    localparam int MAX_TIMEOUT = 500;

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

        int timeout_count = 0;

        // ---------------------------------------------------------------------
        // Drive request
        // ---------------------------------------------------------------------

        @(vif.driver_cb);

        vif.driver_cb.m_valid <= 1'b1;
        vif.driver_cb.m_write <= tr.write;
        vif.driver_cb.m_addr  <= tr.addr;
        vif.driver_cb.m_wdata <= tr.wdata;
        vif.driver_cb.m_strb  <= tr.strb;

        // ---------------------------------------------------------------------
        // Wait for m_ready
        //
        // Request remains stable while m_valid = 1 and m_ready = 0.
        // ---------------------------------------------------------------------

        while (!vif.driver_cb.m_ready) begin

            @(vif.driver_cb);

            timeout_count++;

            if (timeout_count >= MAX_TIMEOUT) begin

                `uvm_fatal(
                    "TIMEOUT",
                    $sformatf(
                        "No m_ready for address 0x%08h after %0d cycles",
                        tr.addr,
                        MAX_TIMEOUT
                    )
                )

            end

        end

        // ---------------------------------------------------------------------
        // Capture response
        // ---------------------------------------------------------------------

        tr.ready = vif.driver_cb.m_ready;
        tr.rdata = vif.driver_cb.m_rdata;

        // ---------------------------------------------------------------------
        // Return bus to idle
        // ---------------------------------------------------------------------

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

        @(vif.driver_cb);

        vif.driver_cb.m_valid <= 1'b0;
        vif.driver_cb.m_write <= 1'b0;
        vif.driver_cb.m_addr  <= '0;
        vif.driver_cb.m_wdata <= '0;
        vif.driver_cb.m_strb  <= '0;

    endtask

endclass

`endif