`ifndef SOC_SEQUENCER_SV
`define SOC_SEQUENCER_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// // Sequence item dependency
// `include "../soc_sequence_item/soc_sequence_item.sv"


// =============================================================================
// RISCV-VDP-SoC
// Native Bus Sequencer
// =============================================================================
//
// Purpose:
//   Supplies soc_sequence_item transactions from sequences to the driver.
//
// Architecture:
//
//   sequence
//      |
//      v
//   sequencer
//      |
//      v
//    driver
//
// =============================================================================

class soc_sequencer extends uvm_sequencer #(soc_sequence_item);

    `uvm_component_utils(soc_sequencer)


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_sequencer",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction

endclass


`endif