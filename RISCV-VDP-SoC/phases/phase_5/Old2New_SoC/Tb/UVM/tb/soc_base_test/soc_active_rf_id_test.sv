`ifndef SOC_ACTIVE_RF_ID_TEST_SV
`define SOC_ACTIVE_RF_ID_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_rf_id_sequence extends uvm_sequence #(soc_sequence_item);
    `uvm_object_utils(soc_active_rf_id_sequence)
    
    function new(string name="soc_active_rf_id_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        soc_sequence_item req;
        
        `uvm_info("RF_ID_SEQ", "Starting isolated spec-based RF-ID read...", UVM_LOW)
        
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        // Address based on Golden interconnect (0x0001_1000 base) + RF RTL offset (0x00C)
        req.addr  = 32'h0001_100C;
        req.write = 1'b0;
        req.strb  = 4'h0;
        finish_item(req);
        
        // Oracle based purely on Golden rf_telemetry_native.v (localparam RF_ID_VALUE = 32'h5246_5430)
        if (req.rdata !== 32'h5246_5430) begin
            `uvm_error("RF_ID_SEQ", $sformatf("RF ID readback mismatch! Expected 0x5246_5430, got 0x%08h", req.rdata))
        end
        
        `uvm_info("RF_ID_SEQ", "RF-ID test sequence finished.", UVM_LOW)
    endtask
endclass

class soc_active_rf_id_test extends uvm_test;
    `uvm_component_utils(soc_active_rf_id_test)

    soc_env env;

    function new(string name = "soc_active_rf_id_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_rf_id_sequence seq;
        phase.raise_objection(this, "Starting RF ID test");

        #200ns;

        seq = soc_active_rf_id_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        #100ns;
        phase.drop_objection(this, "Finished RF ID test");
    endtask
endclass

`endif
