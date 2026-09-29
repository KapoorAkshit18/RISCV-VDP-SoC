`ifndef SOC_ACTIVE_TPU_DECODE_TEST_SV
`define SOC_ACTIVE_TPU_DECODE_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_tpu_decode_sequence extends uvm_sequence #(soc_sequence_item);
    `uvm_object_utils(soc_active_tpu_decode_sequence)
    
    function new(string name="soc_active_tpu_decode_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        soc_sequence_item req;
        
        `uvm_info("TPU_DEC_SEQ", "Starting isolated spec-based TPU decode test...", UVM_LOW)
        
        // Step 1: Write a known non-zero value to TPU WEIGHT0_L (offset 0x10)
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0001_4010;
        req.write = 1'b1;
        req.wdata = 32'hDEADBEEF;
        req.strb  = 4'hF;
        finish_item(req);
        
        // Step 2: Read it back to verify successful routing and decode
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0001_4010;
        req.write = 1'b0;
        req.strb  = 4'h0;
        finish_item(req);
        
        // Oracle: Golden RTL specifies WEIGHT0_L is RW. Readback must match written value.
        if (req.rdata !== 32'hDEADBEEF) begin
            `uvm_error("TPU_DEC_SEQ", $sformatf("TPU decode RW mismatch! Expected 0xDEADBEEF, got 0x%08h", req.rdata))
        end
        
        `uvm_info("TPU_DEC_SEQ", "TPU decode test sequence finished.", UVM_LOW)
    endtask
endclass

class soc_active_tpu_decode_test extends uvm_test;
    `uvm_component_utils(soc_active_tpu_decode_test)

    soc_env env;

    function new(string name = "soc_active_tpu_decode_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_tpu_decode_sequence seq;
        phase.raise_objection(this, "Starting TPU decode test");

        #200ns;

        seq = soc_active_tpu_decode_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        #100ns;
        phase.drop_objection(this, "Finished TPU decode test");
    endtask
endclass

`endif

