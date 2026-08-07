`ifndef SOC_SMOKE_SEQUENCE_SV
`define SOC_SMOKE_SEQUENCE_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// Dependency
`include "soc_base_sequence.sv"


// =============================================================================
// RISCV-VDP-SoC
// UVM Smoke Sequence
// =============================================================================
//
// Purpose:
//   First executable functional sanity test.
//
// Covers:
//   1. RAM write
//   2. RAM read
//   3. GPIO write
//   4. GPIO read
//
// Address map:
//
//   RAM  : 0x0000_0000 - 0x0000_FFFF
//   GPIO : 0x0001_0000 - 0x0001_0FFF
//
// This sequence intentionally does not model expected values itself.
// That responsibility will move to the predictor/reference model and
// checker when those components are added.
// =============================================================================

class soc_smoke_sequence extends soc_base_sequence;

    `uvm_object_utils(soc_smoke_sequence)


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(string name = "soc_smoke_sequence");

        super.new(name);

    endfunction


    // =========================================================================
    // Body
    // =========================================================================

    virtual task body();

        bit [31:0] read_data;


        `uvm_info(
            "SMOKE_SEQ",
            "Starting SoC native-bus smoke sequence",
            UVM_LOW
        )


        // =====================================================================
        // RAM WRITE
        // =====================================================================

        `uvm_info(
            "SMOKE_SEQ",
            "RAM WRITE: address=0x00000040 data=0x12345678",
            UVM_MEDIUM
        )

        do_write(
            32'h0000_0040,
            32'h1234_5678,
            4'b1111
        );


        // =====================================================================
        // RAM READ
        // =====================================================================

        `uvm_info(
            "SMOKE_SEQ",
            "RAM READ: address=0x00000040",
            UVM_MEDIUM
        )

        do_read(
            32'h0000_0040,
            read_data
        );

        `uvm_info(
            "SMOKE_SEQ",
            $sformatf(
                "RAM READ returned 0x%08h",
                read_data
            ),
            UVM_MEDIUM
        );


        // =====================================================================
        // GPIO WRITE
        // =====================================================================

        `uvm_info(
            "SMOKE_SEQ",
            "GPIO WRITE: address=0x00010000 data=0xA5A5A5A5",
            UVM_MEDIUM
        )

        do_write(
            32'h0001_0000,
            32'hA5A5_A5A5,
            4'b1111
        );


        // =====================================================================
        // GPIO READ
        // =====================================================================

        `uvm_info(
            "SMOKE_SEQ",
            "GPIO READ: address=0x00010000",
            UVM_MEDIUM
        )

        do_read(
            32'h0001_0000,
            read_data
        );

        `uvm_info(
            "SMOKE_SEQ",
            $sformatf(
                "GPIO READ returned 0x%08h",
                read_data
            ),
            UVM_MEDIUM
        );


        `uvm_info(
            "SMOKE_SEQ",
            "SoC native-bus smoke sequence completed",
            UVM_LOW
        )

    endtask

endclass


`endif