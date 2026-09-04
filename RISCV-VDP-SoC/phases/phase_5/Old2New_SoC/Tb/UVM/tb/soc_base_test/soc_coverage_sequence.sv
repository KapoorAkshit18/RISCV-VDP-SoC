`ifndef SOC_COVERAGE_SEQUENCE_SV
`define SOC_COVERAGE_SEQUENCE_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// Coverage Closure Sequence
//
// Purpose:
//   Deliberately exercise the SoC address map, read/write operations,
//   write strobes, and representative write-data patterns so that the
//   functional coverage model can be closed.
//
// Existing infrastructure:
//   soc_sequence_item
//        |
//   soc_sequencer
//        |
//   soc_driver
//        |
//       DUT
//
// No scoreboard is required.
// =============================================================================

class soc_coverage_sequence extends uvm_sequence #(soc_sequence_item);

    `uvm_object_utils(soc_coverage_sequence)


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_coverage_sequence"
    );

        super.new(name);

    endfunction


    // =========================================================================
    // Helper: Perform one transaction
    // =========================================================================

    task automatic do_transaction(
        bit        write_i,
        bit [31:0] addr_i,
        bit [31:0] data_i,
        bit [3:0]  strb_i
    );

        soc_sequence_item req;

        req = soc_sequence_item::type_id::create(
            "req"
        );

        start_item(req);

        req.write = write_i;
        req.addr  = addr_i;
        req.wdata = data_i;
        req.strb  = strb_i;

        finish_item(req);

    endtask


    // =========================================================================
    // Main sequence
    // =========================================================================

    virtual task body();

        `uvm_info(
            "COV_SEQ",
            "Starting functional coverage closure sequence",
            UVM_LOW
        )


        // =====================================================================
        // 1. RAM COVERAGE
        // =====================================================================

        // RAM read
        do_transaction(
            1'b0,
            32'h0000_0000,
            32'h0000_0000,
            4'b0000
        );

        // RAM write - BYTE0
        do_transaction(
            1'b1,
            32'h0000_0004,
            32'h0000_0000,
            4'b0001
        );

        // RAM write - BYTE1
        do_transaction(
            1'b1,
            32'h0000_0008,
            32'hFFFF_FFFF,
            4'b0010
        );

        // RAM write - BYTE2
        do_transaction(
            1'b1,
            32'h0000_000C,
            32'hAAAA_AAAA,
            4'b0100
        );

        // RAM write - BYTE3
        do_transaction(
            1'b1,
            32'h0000_0010,
            32'h5555_5555,
            4'b1000
        );

        // RAM write - HALFWORD LOW
        do_transaction(
            1'b1,
            32'h0000_0014,
            32'hAAAA_AAAA,
            4'b0011
        );

        // RAM write - HALFWORD HIGH
        do_transaction(
            1'b1,
            32'h0000_0018,
            32'h5555_5555,
            4'b1100
        );

        // RAM write - FULL WORD
        do_transaction(
            1'b1,
            32'h0000_001C,
            32'hFFFF_FFFF,
            4'b1111
        );


        // =====================================================================
        // 2. GPIO COVERAGE
        // =====================================================================

        // GPIO read
        do_transaction(
            1'b0,
            32'h0001_0000,
            32'h0000_0000,
            4'b0000
        );

        // GPIO write
        do_transaction(
            1'b1,
            32'h0001_0000,
            32'h0000_0000,
            4'b1111
        );


        // =====================================================================
        // 3. RF TELEMETRY COVERAGE
        // =====================================================================

        // RF read
        do_transaction(
            1'b0,
            32'h0001_1000,
            32'h0000_0000,
            4'b0000
        );

        // RF write
        do_transaction(
            1'b1,
            32'h0001_1000,
            32'hFFFF_FFFF,
            4'b1111
        );


        // =====================================================================
        // 4. SENSOR STATUS COVERAGE
        // =====================================================================

        // SENSOR read
        do_transaction(
            1'b0,
            32'h0001_2000,
            32'h0000_0000,
            4'b0000
        );

        // SENSOR write
        do_transaction(
            1'b1,
            32'h0001_2000,
            32'hAAAA_AAAA,
            4'b1111
        );


        // =====================================================================
        // 5. VDP COVERAGE
        // =====================================================================

        // VDP read
        do_transaction(
            1'b0,
            32'h0001_3000,
            32'h0000_0000,
            4'b0000
        );

        // VDP write
        do_transaction(
            1'b1,
            32'h0001_3000,
            32'h5555_5555,
            4'b1111
        );


        // =====================================================================
        // 6. UNMAPPED ADDRESS COVERAGE
        // =====================================================================

        // Unmapped read
        do_transaction(
            1'b0,
            32'h0002_0000,
            32'h0000_0000,
            4'b0000
        );

        // Unmapped write
        do_transaction(
            1'b1,
            32'h0002_0000,
            32'hFFFF_FFFF,
            4'b1111
        );


        `uvm_info(
            "COV_SEQ",
            "Functional coverage closure sequence completed",
            UVM_LOW
        )

    endtask

endclass


`endif