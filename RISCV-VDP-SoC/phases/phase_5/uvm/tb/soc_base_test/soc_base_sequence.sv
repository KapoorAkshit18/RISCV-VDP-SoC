`ifndef SOC_BASE_SEQUENCE_SV
`define SOC_BASE_SEQUENCE_SV

`timescale 1ns/1ps

import uvm_pkg::*;
// `include "uvm_macros.svh"

// // Dependencies
// `include "../soc_agent/soc_sequence_item/soc_sequence_item.sv"
// `include "../soc_agent/soc_sequencer/soc_sequencer.sv"


// =============================================================================
// RISCV-VDP-SoC
// Base Native Bus Sequence
// =============================================================================
//
// Provides reusable transaction tasks for:
//     - read
//     - write
//
// Derived sequences can use:
//     do_write()
//     do_read()
//
// This keeps protocol-level transaction creation in one place.
// =============================================================================

class soc_base_sequence extends uvm_sequence #(soc_sequence_item);

    `uvm_object_utils(soc_base_sequence)


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(string name = "soc_base_sequence");

        super.new(name);

    endfunction


    // =========================================================================
    // Write helper
    // =========================================================================

    virtual task do_write(
        input bit [31:0] addr,
        input bit [31:0] data,
        input bit [3:0]  strb = 4'b1111
    );

        soc_sequence_item req;

        req = soc_sequence_item::type_id::create("write_req");

        start_item(req);

        req.write = 1'b1;
        req.addr  = addr;
        req.wdata = data;
        req.strb  = strb;

        req.set_target();

        finish_item(req);

        `uvm_info(
            "BASE_SEQ",
            $sformatf(
                "WRITE addr=0x%08h data=0x%08h strb=0x%1h target=%s",
                addr,
                data,
                strb,
                req.target
            ),
            UVM_MEDIUM
        )

    endtask


    // =========================================================================
    // Read helper
    // =========================================================================

    virtual task do_read(
        input  bit [31:0] addr,
        output bit [31:0] data
    );

        soc_sequence_item req;

        req = soc_sequence_item::type_id::create("read_req");

        start_item(req);

        req.write = 1'b0;
        req.addr  = addr;
        req.wdata = 32'h0000_0000;
        req.strb  = 4'b0000;

        req.set_target();

        finish_item(req);

        data = req.rdata;

        `uvm_info(
            "BASE_SEQ",
            $sformatf(
                "READ addr=0x%08h data=0x%08h target=%s",
                addr,
                data,
                req.target
            ),
            UVM_MEDIUM
        )

    endtask


    // =========================================================================
    // Body
    //
    // Base sequence intentionally performs no transactions.
    // Derived sequences provide actual stimulus.
    // =========================================================================

    virtual task body();

        `uvm_info(
            "BASE_SEQ",
            "Base sequence started",
            UVM_LOW
        )

    endtask

endclass


`endif