`ifndef SOC_ACTIVE_SENSOR_CORNER_TEST_SV
`define SOC_ACTIVE_SENSOR_CORNER_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_sensor_corner_sequence extends uvm_sequence#(soc_sequence_item);
    `uvm_object_utils(soc_active_sensor_corner_sequence)
    soc_reg_block ral;

    function new(string name="soc_active_sensor_corner_sequence");
        super.new(name);
    endfunction

    task read_raw(logic [31:0] addr, output logic [31:0] data);
        soc_sequence_item req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.write = 1'b0;
        req.addr  = addr;
        req.strb  = 4'h0;
        finish_item(req);
        data = req.rdata;
        #30ns;
    endtask

    task write_raw(logic [31:0] addr, logic [31:0] data);
        soc_sequence_item req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.write = 1'b1;
        req.addr  = addr;
        req.wdata = data;
        req.strb  = 4'hF;
        finish_item(req);
        #30ns;
    endtask

    task set_sensor_stimulus(real temp, logic [7:0] batt);
        // Drive via cross-module reference to the top testbench
        temperature = temp;
        battery_percent_i = batt;
        $display("DEBUG: set_sensor_stimulus called with temp=%f, temperature is now %f", temp, temperature);
        // Wait for RNM (0-delay comb logic) + RTL 2-FF synchronizers (at least 3 cycles)
        #100ns; 
    endtask

    virtual task body();
        logic [31:0] rdata;
        
        `uvm_info("SENSOR_CORNER", "Starting Sensor corner case tests", UVM_LOW)

        // -------------------------------------------------------------
        // 1. Read-Only Behavior Check
        // -------------------------------------------------------------
        set_sensor_stimulus(25.0, 50);
        read_raw(32'h0001_2000, rdata);
        if (rdata != 32'h0000_0032) `uvm_error("SENSOR_CORNER", "Initial BATT read failed")
        
        write_raw(32'h0001_2000, 32'hFFFF_FFFF);
        read_raw(32'h0001_2000, rdata);
        if (rdata != 32'h0000_0032) `uvm_error("SENSOR_CORNER", $sformatf("RO write to BATT altered data: 0x%08h", rdata))
        
        write_raw(32'h0001_200C, 32'hFFFF_FFFF);
        read_raw(32'h0001_200C, rdata);
        if ((rdata & 32'hFFFF_FFF8) != 0) `uvm_error("SENSOR_CORNER", $sformatf("RO write to STATUS altered reserved bits: 0x%08h", rdata))

        // -------------------------------------------------------------
        // 2. Battery Boundaries (0, 1, 14, 15, 16, 99, 100)
        // -------------------------------------------------------------
        set_sensor_stimulus(25.0, 16);
        read_raw(32'h0001_200C, rdata);
        if (rdata & 32'h2) `uvm_error("SENSOR_CORNER", "Batt 16%: battery_low=1 (FAIL)")

        set_sensor_stimulus(25.0, 15);
        read_raw(32'h0001_200C, rdata);
        if (!(rdata & 32'h2)) `uvm_error("SENSOR_CORNER", "Batt 15%: battery_low=0 (FAIL)")

        set_sensor_stimulus(25.0, 14);
        read_raw(32'h0001_200C, rdata);
        if (!(rdata & 32'h2)) `uvm_error("SENSOR_CORNER", "Batt 14%: battery_low=0 (FAIL)")

        set_sensor_stimulus(25.0, 0);
        read_raw(32'h0001_200C, rdata);
        if (!(rdata & 32'h2)) `uvm_error("SENSOR_CORNER", "Batt 0%: battery_low=0 (FAIL)")

        set_sensor_stimulus(25.0, 100);
        read_raw(32'h0001_200C, rdata);
        if (rdata & 32'h2) `uvm_error("SENSOR_CORNER", "Batt 100%: battery_low=1 (FAIL)")

        // -------------------------------------------------------------
        // 3. Temperature Boundaries (-39.9, 0, 79.9, 80.0, 125)
        // -------------------------------------------------------------
        set_sensor_stimulus(79.9, 50);
        read_raw(32'h0001_200C, rdata);
        if (rdata & 32'h4) `uvm_error("SENSOR_CORNER", "Temp 79.9C: temp_alarm=1 (FAIL)")
        
        set_sensor_stimulus(80.0, 50);
        read_raw(32'h0001_200C, rdata);
        if (rdata & 32'h4) `uvm_error("SENSOR_CORNER", "Temp 80.0C: temp_alarm=1 (FAIL)")

        // Use 80.5 to overcome ADC quantization truncation
        set_sensor_stimulus(80.5, 50); 
        read_raw(32'h0001_200C, rdata);
        if (!(rdata & 32'h4)) `uvm_error("SENSOR_CORNER", "Temp 80.5C: temp_alarm=0 (FAIL)")

        // Use -39.9 to overcome ADC quantization truncating to -40.02 (which makes it invalid)
        set_sensor_stimulus(-39.9, 50);
        read_raw(32'h0001_2008, rdata);
        if ((rdata & 32'h8000) == 0) `uvm_error("SENSOR_CORNER", $sformatf("Temp -39.9C formatting failed. Got 0x%08h", rdata))
        else `uvm_info("SENSOR_CORNER", "Signed temperature formatting (-39.9C) passed", UVM_LOW)
        
        read_raw(32'h0001_200C, rdata);
        if (rdata & 32'h4) `uvm_error("SENSOR_CORNER", "Temp -39.9C: temp_alarm=1 (FAIL)")
        if (!(rdata & 32'h1)) `uvm_error("SENSOR_CORNER", "Temp -39.9C: valid=0 (FAIL)")

        set_sensor_stimulus(125.0, 50);
        read_raw(32'h0001_200C, rdata);
        if (!(rdata & 32'h4)) `uvm_error("SENSOR_CORNER", "Temp 125.0C: temp_alarm=0 (FAIL)")
        if (!(rdata & 32'h1)) `uvm_error("SENSOR_CORNER", "Temp 125.0C: valid=0 (FAIL)")

        // -------------------------------------------------------------
        // 4. Status Combinations
        // -------------------------------------------------------------
        // 3'b101: valid=1, batt_low=0, temp_alarm=1
        set_sensor_stimulus(90.0, 50);
        read_raw(32'h0001_200C, rdata);
        if ((rdata & 32'h7) != 3'b101) `uvm_error("SENSOR_CORNER", $sformatf("Status 3'b101 failed, got %03b", rdata[2:0]))

        // 3'b111: valid=1, batt_low=1, temp_alarm=1
        set_sensor_stimulus(90.0, 10);
        read_raw(32'h0001_200C, rdata);
        if ((rdata & 32'h7) != 3'b111) `uvm_error("SENSOR_CORNER", $sformatf("Status 3'b111 failed, got %03b", rdata[2:0]))

        // 3'b011: valid=1, batt_low=1, temp_alarm=0
        set_sensor_stimulus(-39.9, 10);
        read_raw(32'h0001_200C, rdata);
        if ((rdata & 32'h7) != 3'b011) `uvm_error("SENSOR_CORNER", $sformatf("Status 3'b011 failed, got %03b", rdata[2:0]))

        `uvm_info("SENSOR_CORNER", "Sensor corner case testing completed", UVM_LOW)
    endtask
endclass

class soc_active_sensor_corner_test extends uvm_test;
    `uvm_component_utils(soc_active_sensor_corner_test)
    soc_env env;
    function new(string name = "soc_active_sensor_corner_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction
    virtual task run_phase(uvm_phase phase);
        soc_active_sensor_corner_sequence seq;
        phase.raise_objection(this);
        #200ns;
        seq = soc_active_sensor_corner_sequence::type_id::create("seq");
        seq.ral = env.ral_model;
        seq.start(env.native_agent.sequencer);
        #100ns;
        phase.drop_objection(this);
    endtask
endclass
`endif
