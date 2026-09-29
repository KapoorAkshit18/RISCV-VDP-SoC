`ifndef SOC_ACTIVE_SENSOR_STATUS_TEST_SV
`define SOC_ACTIVE_SENSOR_STATUS_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_sensor_status_sequence extends uvm_sequence #(soc_sequence_item);
    `uvm_object_utils(soc_active_sensor_status_sequence)
    
    function new(string name="soc_active_sensor_status_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        soc_sequence_item req;
        
        `uvm_info("SENSOR_STATUS", "Starting Sensor Status decode test...", UVM_LOW)
        
        // Step 1: Read from SENSOR BATT_PCT (0x0001_2000)
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0001_2000;
        req.write = 1'b0;
        req.strb  = 4'h0;
        finish_item(req);
        
        // Oracle: In TB environment, Battery Pct defaults to 0x50. Unmapped returns 0x0.
        // Golden RTL correctly routes to SENSOR and returns 0x50.
        if (req.rdata !== 32'h0000_0050) begin
            `uvm_error("SENSOR_STATUS", $sformatf("Sensor decode mismatch! Expected 0x00000050, got 0x%08h", req.rdata))
        end
        
        `uvm_info("SENSOR_STATUS", "Sensor Status decode test sequence finished.", UVM_LOW)
    endtask
endclass

class soc_active_sensor_status_test extends uvm_test;
    `uvm_component_utils(soc_active_sensor_status_test)

    soc_env env;

    function new(string name = "soc_active_sensor_status_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_sensor_status_sequence seq;
        phase.raise_objection(this, "Starting Sensor Status test");

        #500ns; // Wait for TB to synchronize the battery pct value

        seq = soc_active_sensor_status_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        #100ns;
        phase.drop_objection(this, "Finished Sensor Status test");
    endtask
endclass

`endif

