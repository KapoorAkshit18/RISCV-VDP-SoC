`ifndef SOC_UVM_PKG_SV
`define SOC_UVM_PKG_SV

`timescale 1ns/1ps

package soc_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ------------------------------------------------------------
    // Sequence item
    // ------------------------------------------------------------
    `include "soc_agent/soc_sequence_item/soc_sequence_item.sv"

    // ------------------------------------------------------------
    // Sequencer
    // ------------------------------------------------------------
    `include "soc_sequencer/soc_sequencer.sv"

    // ------------------------------------------------------------
    // Driver
    // ------------------------------------------------------------
    `include "soc_driver/soc_driver.sv"

    // ------------------------------------------------------------
    // Monitor
    // ------------------------------------------------------------
    `include "soc_monitor/soc_monitor.sv"

    // ------------------------------------------------------------
    // Agent
    // ------------------------------------------------------------
    `include "soc_agent/soc_agent.sv"

// ------------------------------------------------------------
// RAL
// ------------------------------------------------------------
      `include "soc_ral/gpio_reg_block.sv"
      `include "soc_ral/rf_reg_block.sv"
      `include "soc_ral/sensor_reg_block.sv"
      `include "soc_ral/vdp_reg_block.sv"
      `include "soc_ral/soc_reg_block.sv"
      `include "soc_ral/soc_reg_adapter.sv" 
      `include "soc_ral/soc_reg_predictor.sv"
    // ------------------------------------------------------------
    // Environment
    // ------------------------------------------------------------
    `include "soc_env/soc_env.sv"
   
    // ------------------------------------------------------------
    // Sequences
    // ------------------------------------------------------------
    `include "soc_base_test/soc_base_sequence.sv"
    `include "soc_base_test/soc_ral_sequence.sv"
    `include "soc_base_test/soc_smoke_sequence.sv"
    `include "soc_base_test/soc_smoke_test.sv"
    `include "soc_base_test/soc_ral_test.sv"    

endpackage

`endif