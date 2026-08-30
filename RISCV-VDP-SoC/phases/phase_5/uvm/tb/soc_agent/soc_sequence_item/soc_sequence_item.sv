`ifndef SOC_SEQUENCE_ITEM_SV
`define SOC_SEQUENCE_ITEM_SV

`timescale 1ns/1ps

// UVM package
import uvm_pkg::*;

// UVM macros
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// UVM Native Bus Sequence Item
//
// Native bus:
//   write = 1 -> write transaction
//   write = 0 -> read transaction
//   strb  = 0000 -> read
//   strb != 0000 -> write
//
// Address : 32-bit
// Data    : 32-bit
// WSTRB   : 4-bit
// =============================================================================

class soc_sequence_item extends uvm_sequence_item;

    // =========================================================================
    // Request
    // =========================================================================

    rand bit        write;
    rand bit [31:0] addr;
    rand bit [31:0] wdata;
    rand bit [3:0]  strb;

    // =========================================================================
    // Response
    // =========================================================================

    bit             ready;
    bit [31:0]      rdata;

    // =========================================================================
    // Verification metadata
    // =========================================================================

    string          target;

    bit [31:0]      expected_rdata;
    bit             check_enable;


    // =========================================================================
    // Factory registration
    // =========================================================================

    `uvm_object_utils_begin(soc_sequence_item)

        `uvm_field_int   (write,          UVM_ALL_ON)
        `uvm_field_int   (addr,           UVM_ALL_ON)
        `uvm_field_int   (wdata,          UVM_ALL_ON)
        `uvm_field_int   (strb,           UVM_ALL_ON)

        `uvm_field_int   (ready,          UVM_ALL_ON)
        `uvm_field_int   (rdata,           UVM_ALL_ON)

        `uvm_field_string(target,         UVM_ALL_ON)

        `uvm_field_int   (expected_rdata, UVM_ALL_ON)
        `uvm_field_int   (check_enable,   UVM_ALL_ON)

    `uvm_object_utils_end


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(string name = "soc_sequence_item");

        super.new(name);

        write          = 1'b0;
        addr           = '0;
        wdata          = '0;
        strb           = 4'b0000;

        ready          = 1'b0;
        rdata          = '0;

        target         = "UNKNOWN";

        expected_rdata = '0;
        check_enable   = 1'b0;

    endfunction


    // =========================================================================
    // Native bus protocol constraint
    // =========================================================================

    constraint c_strb_protocol {

        if (!write)
            strb == 4'b0000;

        else
            strb != 4'b0000;

    }


    // =========================================================================
    // Determine target from system address
    // =========================================================================

    function void set_target();

        if ((addr & 32'hFFFF_0000) == 32'h0000_0000)

            target = "RAM";

        else if ((addr & 32'hFFFF_F000) == 32'h0001_0000)

            target = "GPIO";

        else if ((addr & 32'hFFFF_F000) == 32'h0001_1000)

            target = "RF";

        else if ((addr & 32'hFFFF_F000) == 32'h0001_2000)

            target = "SENSOR";

        else if ((addr & 32'hFFFF_F000) == 32'h0001_3000)

            target = "VDP";

        else

            target = "UNMAPPED";
        //     // =====================================================================
        // // UNMAPPED ADDRESS ACCESS (Expected to return default/error state)
        // // =====================================================================
        // `uvm_info("SMOKE_SEQ", "UNMAPPED READ: address=0x00020000", UVM_MEDIUM)
        // do_read(32'h0002_0000, read_data);

    endfunction


    // =========================================================================
    // String representation
    // =========================================================================

    function string convert2string();

        return $sformatf(
            "target=%s write=%0b addr=0x%08h wdata=0x%08h strb=0x%1h ready=%0b rdata=0x%08h",
            target,
            write,
            addr,
            wdata,
            strb,
            ready,
            rdata
        );

    endfunction

endclass


`endif