`ifndef SOC_ACTIVE_UNMAPPED_HANG_TEST_SV
`define SOC_ACTIVE_UNMAPPED_HANG_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_unmapped_hang_sequence extends uvm_sequence #(soc_sequence_item);
    `uvm_object_utils(soc_active_unmapped_hang_sequence)
    
    function new(string name="soc_active_unmapped_hang_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        soc_sequence_item req;
        
        `uvm_info("UNMAPPED_HANG", "Starting SoC-level unmapped space test...", UVM_LOW)
        
        // Step 1: Read from an address that hits NO slaves (e.g. 0x0001_F000)
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0001_F000;
        req.write = 1'b0;
        req.strb  = 4'h0;
        finish_item(req);
        
        // Oracle: Golden RTL assigns m_ready = 1'b1 and m_rdata = 32'h0 for unmapped.
        if (req.rdata !== 32'h0000_0000) begin
            `uvm_error("UNMAPPED_HANG", $sformatf("Read from unmapped address 0x0001_F000 returned 0x%08h, expected 0x0000_0000", req.rdata))
        end else begin
            `uvm_info("UNMAPPED_HANG", "Read from 0x0001_F000 correctly returned 0", UVM_LOW)
        end
        
        `uvm_info("UNMAPPED_HANG", "Unmapped test sequence finished successfully.", UVM_LOW)
    endtask
endclass

class soc_active_unmapped_hang_test extends uvm_test;
    `uvm_component_utils(soc_active_unmapped_hang_test)

    soc_env env;

    function new(string name = "soc_active_unmapped_hang_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_unmapped_hang_sequence seq;
        phase.raise_objection(this, "Starting unmapped hang test");

        #200ns;

        seq = soc_active_unmapped_hang_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        #100ns;
        phase.drop_objection(this, "Finished unmapped hang test");
    endtask
endclass

`endif

