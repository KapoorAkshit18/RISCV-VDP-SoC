`ifndef SOC_ACTIVE_VDP_RAL_TEST_SV
`define SOC_ACTIVE_VDP_RAL_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_vdp_ral_sequence extends uvm_sequence;
    `uvm_object_utils(soc_active_vdp_ral_sequence)
    
    soc_reg_block ral;
    
    function new(string name="soc_active_vdp_ral_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        uvm_status_e status;
        uvm_reg_data_t data;
        
        `uvm_info("ACTIVE_VDP", "Reading VDP Color register via existing RAL model", UVM_LOW)
        ral.vdp.color.read(status, data, .parent(this));
        if (status != UVM_IS_OK)
            `uvm_error("ACTIVE_VDP", "RAL read failed with non-OK status")
            
        if (data != 32'h00FFFFFF)
            `uvm_error("ACTIVE_VDP", $sformatf("Expected default color 0x00FFFFFF, got 0x%08h", data))
        else
            `uvm_info("ACTIVE_VDP", "Successfully read default color 0x00FFFFFF from VDP via RAL.", UVM_LOW)
            
        `uvm_info("ACTIVE_VDP", "Writing 0x00112233 to VDP Color register via RAL", UVM_LOW)
        ral.vdp.color.write(status, 32'h00112233, .parent(this));
        
        `uvm_info("ACTIVE_VDP", "Reading back VDP Color register", UVM_LOW)
        ral.vdp.color.read(status, data, .parent(this));
        if (data != 32'h00112233)
            `uvm_error("ACTIVE_VDP", $sformatf("Expected updated color 0x00112233, got 0x%08h", data))
        else
            `uvm_info("ACTIVE_VDP", "Successfully verified written color 0x00112233 from VDP via RAL.", UVM_LOW)
            
    endtask
endclass

class soc_active_vdp_ral_test extends uvm_test;
    `uvm_component_utils(soc_active_vdp_ral_test)

    soc_env env;

    function new(string name = "soc_active_vdp_ral_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_vdp_ral_sequence seq;
        phase.raise_objection(this, "Starting ACTIVE VDP RAL test");

        #200ns;

        seq = soc_active_vdp_ral_sequence::type_id::create("seq");
        seq.ral = env.ral_model;
        seq.start(env.native_agent.sequencer);
        
        #100ns;
        phase.drop_objection(this, "Finished ACTIVE VDP RAL test");
    endtask
endclass

`endif
