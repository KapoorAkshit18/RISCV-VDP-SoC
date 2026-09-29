`ifndef SOC_ACTIVE_SENSOR_UNMAPPED_TEST_SV
`define SOC_ACTIVE_SENSOR_UNMAPPED_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_sensor_unmapped_sequence extends uvm_sequence #(soc_sequence_item);
    `uvm_object_utils(soc_active_sensor_unmapped_sequence)
    
    function new(string name="soc_active_sensor_unmapped_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        soc_sequence_item req;
        
        `uvm_info("SENSOR_UNMAPPED", "Starting unmapped sensor address space checks...", UVM_LOW)
        
        // Test 1: Midpoint of unmapped 4KB space (0x0001_2800)
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0001_2800; 
        req.write = 1'b0; 
        req.strb  = 4'h0;
        finish_item(req);
        
        if (req.rdata !== 32'h0000_0000) begin
            `uvm_error("SENSOR_UNMAPPED", $sformatf("Read from unmapped address 0x0001_2800 returned 0x%08h, expected 0x0000_0000", req.rdata))
        end else begin
            `uvm_info("SENSOR_UNMAPPED", "Read from 0x0001_2800 correctly returned 0", UVM_LOW)
        end

        // Test 2: Upper boundary of unmapped 4KB space (0x0001_2FFC)
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0001_2FFC; 
        req.write = 1'b0; 
        req.strb  = 4'h0;
        finish_item(req);
        
        if (req.rdata !== 32'h0000_0000) begin
            `uvm_error("SENSOR_UNMAPPED", $sformatf("Read from unmapped address 0x0001_2FFC returned 0x%08h, expected 0x0000_0000", req.rdata))
        end else begin
            `uvm_info("SENSOR_UNMAPPED", "Read from 0x0001_2FFC correctly returned 0", UVM_LOW)
        end
        
    endtask
endclass

class soc_active_sensor_unmapped_test extends uvm_test;
    `uvm_component_utils(soc_active_sensor_unmapped_test)

    soc_env env;

    function new(string name = "soc_active_sensor_unmapped_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_sensor_unmapped_sequence seq;
        phase.raise_objection(this, "Starting unmapped space test");

        #200ns;

        seq = soc_active_sensor_unmapped_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        #100ns;
        phase.drop_objection(this, "Finished unmapped space test");
    endtask
endclass

`endif
