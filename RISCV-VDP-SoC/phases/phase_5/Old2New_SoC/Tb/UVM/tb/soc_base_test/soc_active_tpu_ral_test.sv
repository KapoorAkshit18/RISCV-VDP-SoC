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
        uvm_status_e   status;
        uvm_reg_data_t data;
        uvm_reg_data_t before_val;

        `uvm_info("ACTIVE_TPU", "=== TPU Active RAL Sequence START ===", UVM_LOW)

        // ====================================================================
        // 1. Reset state — all RW registers must power up as 0
        // ====================================================================
        ral.tpu.ctrl.read     (status, data, .parent(this));
        if (data != 0) `uvm_error("ACTIVE_TPU", $sformatf("CTRL reset != 0: %08h", data))

        ral.tpu.weight0_l.read(status, data, .parent(this));
        if (data != 0) `uvm_error("ACTIVE_TPU", $sformatf("W0_L reset != 0: %08h", data))
        ral.tpu.weight4_h.read(status, data, .parent(this));
        if (data != 0) `uvm_error("ACTIVE_TPU", $sformatf("W4_H reset != 0: %08h", data))
        ral.tpu.input0_l.read (status, data, .parent(this));
        if (data != 0) `uvm_error("ACTIVE_TPU", $sformatf("IN0_L reset != 0: %08h", data))
        ral.tpu.input1_h.read (status, data, .parent(this));
        if (data != 0) `uvm_error("ACTIVE_TPU", $sformatf("IN1_H reset != 0: %08h", data))

        // ====================================================================
        // 2. Full weight register readback — W0 through W4, both LO and HI
        //    Firmware only writes these, never reads them back
        // ====================================================================
        ral.tpu.weight0_l.write(status, 32'hAABBCCDD, .parent(this));
        ral.tpu.weight0_h.write(status, 32'h11223344, .parent(this));
        ral.tpu.weight1_l.write(status, 32'hDEADBEEF, .parent(this));
        ral.tpu.weight1_h.write(status, 32'hCAFEBABE, .parent(this));
        ral.tpu.weight2_l.write(status, 32'h12345678, .parent(this));
        ral.tpu.weight2_h.write(status, 32'h87654321, .parent(this));
        ral.tpu.weight3_l.write(status, 32'hA5A5A5A5, .parent(this));
        ral.tpu.weight3_h.write(status, 32'h5A5A5A5A, .parent(this));
        ral.tpu.weight4_l.write(status, 32'hBEEFCAFE, .parent(this));
        ral.tpu.weight4_h.write(status, 32'hCAFEBEEF, .parent(this));

        ral.tpu.weight0_l.read(status, data, .parent(this));
        if (data != 32'hAABBCCDD) `uvm_error("ACTIVE_TPU", $sformatf("W0_L readback: exp=AABBCCDD got=%08h", data))
        ral.tpu.weight0_h.read(status, data, .parent(this));
        if (data != 32'h11223344) `uvm_error("ACTIVE_TPU", $sformatf("W0_H readback: exp=11223344 got=%08h", data))
        ral.tpu.weight1_l.read(status, data, .parent(this));
        if (data != 32'hDEADBEEF) `uvm_error("ACTIVE_TPU", $sformatf("W1_L readback: exp=DEADBEEF got=%08h", data))
        ral.tpu.weight1_h.read(status, data, .parent(this));
        if (data != 32'hCAFEBABE) `uvm_error("ACTIVE_TPU", $sformatf("W1_H readback: exp=CAFEBABE got=%08h", data))
        ral.tpu.weight2_l.read(status, data, .parent(this));
        if (data != 32'h12345678) `uvm_error("ACTIVE_TPU", $sformatf("W2_L readback: exp=12345678 got=%08h", data))
        ral.tpu.weight2_h.read(status, data, .parent(this));
        if (data != 32'h87654321) `uvm_error("ACTIVE_TPU", $sformatf("W2_H readback: exp=87654321 got=%08h", data))
        ral.tpu.weight3_l.read(status, data, .parent(this));
        if (data != 32'hA5A5A5A5) `uvm_error("ACTIVE_TPU", $sformatf("W3_L readback: exp=A5A5A5A5 got=%08h", data))
        ral.tpu.weight3_h.read(status, data, .parent(this));
        if (data != 32'h5A5A5A5A) `uvm_error("ACTIVE_TPU", $sformatf("W3_H readback: exp=5A5A5A5A got=%08h", data))
        ral.tpu.weight4_l.read(status, data, .parent(this));
        if (data != 32'hBEEFCAFE) `uvm_error("ACTIVE_TPU", $sformatf("W4_L readback: exp=BEEFCAFE got=%08h", data))
        ral.tpu.weight4_h.read(status, data, .parent(this));
        if (data != 32'hCAFEBEEF) `uvm_error("ACTIVE_TPU", $sformatf("W4_H readback: exp=CAFEBEEF got=%08h", data))

        // ====================================================================
        // 3. Full input register readback — INPUT0 and INPUT1, both LO and HI
        // ====================================================================
        ral.tpu.input0_l.write(status, 32'h55667788, .parent(this));
        ral.tpu.input0_h.write(status, 32'hAABBCCDD, .parent(this));
        ral.tpu.input1_l.write(status, 32'h11223344, .parent(this));
        ral.tpu.input1_h.write(status, 32'h99AABBCC, .parent(this));

        ral.tpu.input0_l.read(status, data, .parent(this));
        if (data != 32'h55667788) `uvm_error("ACTIVE_TPU", $sformatf("IN0_L readback: exp=55667788 got=%08h", data))
        ral.tpu.input0_h.read(status, data, .parent(this));
        if (data != 32'hAABBCCDD) `uvm_error("ACTIVE_TPU", $sformatf("IN0_H readback: exp=AABBCCDD got=%08h", data))
        ral.tpu.input1_l.read(status, data, .parent(this));
        if (data != 32'h11223344) `uvm_error("ACTIVE_TPU", $sformatf("IN1_L readback: exp=11223344 got=%08h", data))
        ral.tpu.input1_h.read(status, data, .parent(this));
        if (data != 32'h99AABBCC) `uvm_error("ACTIVE_TPU", $sformatf("IN1_H readback: exp=99AABBCC got=%08h", data))

        // ====================================================================
        // 4. RO write-ignore — RESULT0/RESULT1 must not be writable
        //    Firmware never attempts to write result registers
        // ====================================================================
        ral.tpu.result0_l.read(status, before_val, .parent(this));
        ral.tpu.result0_l.write(status, 32'hFFFFFFFF, .parent(this));
        ral.tpu.result0_l.read(status, data, .parent(this));
        if (data != before_val)
            `uvm_error("ACTIVE_TPU", $sformatf("RESULT0_L is writable! before=%08h after=%08h", before_val, data))

        ral.tpu.result1_h.read(status, before_val, .parent(this));
        ral.tpu.result1_h.write(status, 32'hFFFFFFFF, .parent(this));
        ral.tpu.result1_h.read(status, data, .parent(this));
        if (data != before_val)
            `uvm_error("ACTIVE_TPU", $sformatf("RESULT1_H is writable! before=%08h after=%08h", before_val, data))

        // ====================================================================
        // 5. Unmapped address returns 0 — offset 0x60 is outside register map
        //    Firmware never accesses unmapped TPU space
        // ====================================================================
        begin
            soc_sequence_item req;
            req = soc_sequence_item::type_id::create("req");
            start_item(req);
            req.write = 1'b0;
            req.addr  = 32'h0001_4060;
            req.strb  = 4'h0;
            finish_item(req);
            if (req.rdata != 32'h0)
                `uvm_error("ACTIVE_TPU", $sformatf("Unmapped 0x4060 returned non-zero: %08h", req.rdata))
        end

        // ====================================================================
        // 6. Load real firmware_test03 weights and inputs, fire START, poll DONE
        // ====================================================================
        ral.tpu.weight0_l.write(status, 32'h0505_057A, .parent(this));
        ral.tpu.weight0_h.write(status, 32'h0000_B07A, .parent(this));
        ral.tpu.weight1_l.write(status, 32'h03E1_0314, .parent(this));
        ral.tpu.weight1_h.write(status, 32'h0000_FC66, .parent(this));
        ral.tpu.weight2_l.write(status, 32'h028F_0433, .parent(this));
        ral.tpu.weight2_h.write(status, 32'h0000_FC70, .parent(this));
        ral.tpu.weight3_l.write(status, 32'hFAC2_1870, .parent(this));
        ral.tpu.weight3_h.write(status, 32'hF5A3_0051, .parent(this));
        ral.tpu.weight4_l.write(status, 32'h0685_E399, .parent(this));
        ral.tpu.weight4_h.write(status, 32'h00CC_07E1, .parent(this));
        ral.tpu.input0_l.write (status, 32'h2000_2000, .parent(this));
        ral.tpu.input0_h.write (status, 32'h1400_1400, .parent(this));
        ral.tpu.input1_l.write (status, 32'h1400_2000, .parent(this));
        ral.tpu.input1_h.write (status, 32'h1400_2000, .parent(this));

        ral.tpu.ctrl.write(status, 32'h1, .parent(this));

        // ====================================================================
        // 7. BUSY guard — START while BUSY must be ignored
        //    Firmware never retriggers; this is purely an Active UVM check
        // ====================================================================
        ral.tpu.status.read(status, data, .parent(this));
        if (data[0]) begin
            // TPU is BUSY — a second START write must not restart it
            ral.tpu.ctrl.write(status, 32'h1, .parent(this));
            ral.tpu.status.read(status, data, .parent(this));
            if (!data[0])
                `uvm_error("ACTIVE_TPU", "BUSY guard failed: second START cleared BUSY")
            `uvm_info("ACTIVE_TPU", "BUSY guard passed: second START correctly ignored", UVM_LOW)
        end

        // ====================================================================
        // 8. Poll STATUS for DONE (bit 1)
        // ====================================================================
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

        `uvm_info("ACTIVE_TPU", "TPU DONE observed", UVM_LOW)

        // ====================================================================
        // 9. Read and log all four result half-words
        // ====================================================================
        ral.tpu.result0_l.read(status, data, .parent(this));
        `uvm_info("ACTIVE_TPU", $sformatf("RESULT0_L = %08h", data), UVM_LOW)
        ral.tpu.result0_h.read(status, data, .parent(this));
        `uvm_info("ACTIVE_TPU", $sformatf("RESULT0_H = %08h", data), UVM_LOW)
        ral.tpu.result1_l.read(status, data, .parent(this));
        `uvm_info("ACTIVE_TPU", $sformatf("RESULT1_L = %08h", data), UVM_LOW)
        ral.tpu.result1_h.read(status, data, .parent(this));
        `uvm_info("ACTIVE_TPU", $sformatf("RESULT1_H = %08h", data), UVM_LOW)

        `uvm_info("ACTIVE_TPU", "=== TPU Active RAL Sequence COMPLETE ===", UVM_LOW)
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
