`ifndef SOC_ACTIVE_GPIO_READY_TEST_SV
`define SOC_ACTIVE_GPIO_READY_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_gpio_ready_sequence extends uvm_sequence #(soc_sequence_item);
    `uvm_object_utils(soc_active_gpio_ready_sequence)
    
    function new(string name="soc_active_gpio_ready_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        soc_sequence_item req;
        
        `uvm_info("GPIO_READY", "Starting GPIO spec-based completion test...", UVM_LOW)
        
        // Step 1: Write to GPIO DIR (0x0001_0008)
        req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.addr  = 32'h0001_0008;
        req.write = 1'b1;
        req.wdata = 32'h000000FF;
        req.strb  = 4'hF;
        finish_item(req);
        
        `uvm_info("GPIO_READY", "GPIO transaction completed successfully.", UVM_LOW)
    endtask
endclass

class soc_active_gpio_ready_test extends uvm_test;
    `uvm_component_utils(soc_active_gpio_ready_test)

    soc_env env;

    function new(string name = "soc_active_gpio_ready_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_gpio_ready_sequence seq;
        phase.raise_objection(this, "Starting GPIO ready test");

        #200ns;

        seq = soc_active_gpio_ready_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        #100ns;
        phase.drop_objection(this, "Finished GPIO ready test");
    endtask
endclass

`endif

