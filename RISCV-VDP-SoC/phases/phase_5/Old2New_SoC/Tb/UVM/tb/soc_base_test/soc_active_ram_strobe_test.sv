`ifndef SOC_ACTIVE_RAM_STROBE_TEST_SV
`define SOC_ACTIVE_RAM_STROBE_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_ram_strobe_sequence extends uvm_sequence #(soc_sequence_item);
    `uvm_object_utils(soc_active_ram_strobe_sequence)
    
    function new(string name="soc_active_ram_strobe_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        soc_sequence_item req;
        
        `uvm_info("RAM_STROBE", "Starting RAM byte strobe test...", UVM_LOW)
        
        // Step 1: Write Word
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0000_1000;
        req.write = 1'b1;
        req.wdata = 32'hAABBCCDD;
        req.strb  = 4'hF;
        finish_item(req);
        
        // Step 2: Write Byte (offset 1, strobe 4'h2)
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0000_1001; // address gets floored to word by ram, but interconnect passes it
        req.write = 1'b1;
        // Native bus adapter typically duplicates the byte across all lanes. We will just supply FF.
        req.wdata = 32'hFFFFFFFF; 
        req.strb  = 4'h2;
        finish_item(req);
        
        // Step 3: Read Word
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0000_1000;
        req.write = 1'b0;
        req.strb  = 4'h0;
        finish_item(req);
        
        if (req.rdata !== 32'hAABBFFDD) begin
            `uvm_error("RAM_STROBE", $sformatf("RAM strobe mismatch! Expected 0xAABBFFDD, got 0x%08h", req.rdata))
        end
        
        `uvm_info("RAM_STROBE", "RAM strobe test sequence finished.", UVM_LOW)
    endtask
endclass

class soc_active_ram_strobe_test extends uvm_test;
    `uvm_component_utils(soc_active_ram_strobe_test)

    soc_env env;

    function new(string name = "soc_active_ram_strobe_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_ram_strobe_sequence seq;
        phase.raise_objection(this, "Starting RAM strobe test");

        #200ns;

        seq = soc_active_ram_strobe_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        #100ns;
        phase.drop_objection(this, "Finished RAM strobe test");
    endtask
endclass

`endif

