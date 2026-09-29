`ifndef SOC_ACTIVE_TPU_RAL_TEST_SV
`define SOC_ACTIVE_TPU_RAL_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_tpu_ral_sequence extends uvm_sequence;
    `uvm_object_utils(soc_active_tpu_ral_sequence)
    
    soc_reg_block ral;
    
    function new(string name="soc_active_tpu_ral_sequence");
        super.new(name);
    endfunction
    
    virtual task body();
        uvm_status_e status;
        uvm_reg_data_t data;
        
        `uvm_info("ACTIVE_TPU", "Starting TPU RAL verification sequence", UVM_LOW)
        
        // ========================================================
        // 1. Verify CTRL (RW) and default
        // ========================================================
        ral.tpu.ctrl.read(status, data, .parent(this));
        if (data != 32'h0)
            `uvm_error("ACTIVE_TPU", $sformatf("CTRL default should be 0, got %08h", data))
        
        // ========================================================
        // 2. Verify W0-W4 registers (RW)
        // ========================================================
        ral.tpu.weight0_l.write(status, 32'hAABBCCDD, .parent(this));
        ral.tpu.weight0_h.write(status, 32'h11223344, .parent(this));
        ral.tpu.weight1_l.write(status, 32'h0, .parent(this));
        ral.tpu.weight1_h.write(status, 32'h0, .parent(this));
        ral.tpu.weight2_l.write(status, 32'h0, .parent(this));
        ral.tpu.weight2_h.write(status, 32'h0, .parent(this));
        ral.tpu.weight3_l.write(status, 32'h0, .parent(this));
        ral.tpu.weight3_h.write(status, 32'h0, .parent(this));
        ral.tpu.weight4_l.write(status, 32'hBEEFCAFE, .parent(this));
        ral.tpu.weight4_h.write(status, 32'hCAFEBEEF, .parent(this));

        ral.tpu.weight0_l.read(status, data, .parent(this));
        if (data != 32'hAABBCCDD) `uvm_error("ACTIVE_TPU", "W0_L readback failed")
        ral.tpu.weight0_h.read(status, data, .parent(this));
        if (data != 32'h11223344) `uvm_error("ACTIVE_TPU", "W0_H readback failed")
        ral.tpu.weight4_l.read(status, data, .parent(this));
        if (data != 32'hBEEFCAFE) `uvm_error("ACTIVE_TPU", "W4_L readback failed")
        ral.tpu.weight4_h.read(status, data, .parent(this));
        if (data != 32'hCAFEBEEF) `uvm_error("ACTIVE_TPU", "W4_H readback failed")

        // ========================================================
        // 3. Verify INPUT0-1 registers (RW)
        // ========================================================
        ral.tpu.input0_l.write(status, 32'h55667788, .parent(this));
        ral.tpu.input0_h.write(status, 32'h0, .parent(this));
        ral.tpu.input1_l.write(status, 32'h0, .parent(this));
        ral.tpu.input1_h.write(status, 32'h99AABBCC, .parent(this));
        ral.tpu.input0_l.read(status, data, .parent(this));
        if (data != 32'h55667788) `uvm_error("ACTIVE_TPU", "IN0_L readback failed")
        ral.tpu.input1_h.read(status, data, .parent(this));
        if (data != 32'h99AABBCC) `uvm_error("ACTIVE_TPU", "IN1_H readback failed")

        // ========================================================
        // 4. Verify RESULT0-1 registers (RO) and STATUS (RO)
        // ========================================================
        // Writing to RO should ideally not change hardware value. 
        // We just read to make sure they are mapped and do not hang.
        ral.tpu.result0_l.read(status, data, .parent(this));
        ral.tpu.status.read(status, data, .parent(this));
        // We don't check exact result value since we haven't pulsed start and waited.
        // But making sure it successfully returns (which proves no bus hang) is good.

        // ========================================================
        // 5. Test START behavior (pulse CTRL bit 0)
        // ========================================================
        `uvm_info("ACTIVE_TPU", "Pulsing START bit", UVM_LOW)
        ral.tpu.ctrl.write(status, 32'h1, .parent(this));
        ral.tpu.ctrl.write(status, 32'h0, .parent(this));

        // Poll STATUS for DONE bit (bit 1)
        begin
            int timeout = 0;
            do begin
                ral.tpu.status.read(status, data, .parent(this));
                timeout++;
                if (timeout > 500) begin
                    `uvm_error("ACTIVE_TPU", "Timeout polling for TPU DONE bit")
                    break;
                end
            end while ((data & 32'h2) == 0);
        end

        `uvm_info("ACTIVE_TPU", "TPU DONE detected in STATUS register", UVM_LOW)

        // Read results
        ral.tpu.result0_l.read(status, data, .parent(this));
        `uvm_info("ACTIVE_TPU", $sformatf("RESULT0_L = %08h", data), UVM_LOW)

        `uvm_info("ACTIVE_TPU", "TPU RAL verification sequence complete", UVM_LOW)
    endtask
endclass

class soc_active_tpu_ral_test extends uvm_test;
    `uvm_component_utils(soc_active_tpu_ral_test)

    soc_env env;

    function new(string name = "soc_active_tpu_ral_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_tpu_ral_sequence seq;
        phase.raise_objection(this, "Starting ACTIVE TPU RAL test");

        #200ns;

        seq = soc_active_tpu_ral_sequence::type_id::create("seq");
        seq.ral = env.ral_model;
        seq.start(env.native_agent.sequencer);
        
        #100ns;

        phase.drop_objection(this, "Finished ACTIVE TPU RAL test");
    endtask
endclass

`endif
