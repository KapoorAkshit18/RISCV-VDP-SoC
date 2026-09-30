`ifndef SOC_ACTIVE_TPU_CORNER_TEST_SV
`define SOC_ACTIVE_TPU_CORNER_TEST_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_tpu_corner_sequence extends uvm_sequence#(soc_sequence_item);
    `uvm_object_utils(soc_active_tpu_corner_sequence)
    soc_reg_block ral;

    function new(string name="soc_active_tpu_corner_sequence");
        super.new(name);
    endfunction

    task write_raw(logic [31:0] addr, logic [31:0] data, logic [3:0] strb = 4'hF);
        soc_sequence_item req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.write = 1'b1;
        req.addr  = addr;
        req.wdata = data;
        req.strb  = strb;
        finish_item(req);
    endtask

    task read_raw(logic [31:0] addr, output logic [31:0] data);
        soc_sequence_item req = soc_sequence_item::type_id::create("req");
        start_item(req);
        req.write = 1'b0;
        req.addr  = addr;
        req.strb  = 4'h0;
        finish_item(req);
        data = req.rdata;
    endtask

    task write_operands(logic [31:0] pattern);
        uvm_status_e status;
        ral.tpu.weight0_l.write(status, pattern, .parent(this));
        ral.tpu.weight0_h.write(status, pattern, .parent(this));
        ral.tpu.weight1_l.write(status, pattern, .parent(this));
        ral.tpu.weight1_h.write(status, pattern, .parent(this));
        ral.tpu.weight2_l.write(status, pattern, .parent(this));
        ral.tpu.weight2_h.write(status, pattern, .parent(this));
        ral.tpu.weight3_l.write(status, pattern, .parent(this));
        ral.tpu.weight3_h.write(status, pattern, .parent(this));
        ral.tpu.weight4_l.write(status, pattern, .parent(this));
        ral.tpu.weight4_h.write(status, pattern, .parent(this));
        ral.tpu.input0_l.write(status, pattern, .parent(this));
        ral.tpu.input0_h.write(status, pattern, .parent(this));
        ral.tpu.input1_l.write(status, pattern, .parent(this));
        ral.tpu.input1_h.write(status, pattern, .parent(this));
    endtask

    virtual task body();
        uvm_status_e status;
        uvm_reg_data_t data;
        logic [31:0] rdata;
        int timeout;
        
        `uvm_info("TPU_CORNER", "Starting TPU corner case tests", UVM_LOW)

        // -------------------------------------------------------------
        // 1. Reset Check (RTL done_latched bug observation)
        // -------------------------------------------------------------
        ral.tpu.status.read(status, data, .parent(this));
        `uvm_info("TPU_CORNER", $sformatf("Status at reset: 0x%08h", data), UVM_LOW)
        if (data != 32'h0) `uvm_error("TPU_CORNER", "Status not 0 at reset")

        // -------------------------------------------------------------
        // 2. Access permissions (Writes to RO)
        // -------------------------------------------------------------
        // Try writing to STATUS
        write_raw(32'h0001_4004, 32'hFFFF_FFFF);
        read_raw(32'h0001_4004, rdata);
        if (rdata != 32'h0) `uvm_error("TPU_CORNER", "RO Write to STATUS succeeded")
        else `uvm_info("TPU_CORNER", "RO Write to STATUS ignored correctly", UVM_LOW)

        // Try writing to RESULT0_L
        write_raw(32'h0001_4050, 32'hFFFF_FFFF);
        read_raw(32'h0001_4050, rdata);
        if (rdata != 32'h0) `uvm_error("TPU_CORNER", "RO Write to RESULT0_L succeeded")

        // -------------------------------------------------------------
        // 3. Invalid/Boundary Addresses
        // -------------------------------------------------------------
        // Unmapped inside TPU
        read_raw(32'h0001_4008, rdata);
        if (rdata != 32'h0) `uvm_error("TPU_CORNER", "Unmapped 0x08 returned non-zero")
        read_raw(32'h0001_4060, rdata);
        if (rdata != 32'h0) `uvm_error("TPU_CORNER", "Unmapped 0x60 returned non-zero")
        
        // -------------------------------------------------------------
        // 4. Byte Strobes
        // -------------------------------------------------------------
        // Write WEIGHT0_L = 0
        write_raw(32'h0001_4010, 32'h0000_0000);
        // Write byte 0
        write_raw(32'h0001_4010, 32'hDEAD_BEEF, 4'b0001);
        read_raw(32'h0001_4010, rdata);
        if (rdata != 32'h0000_00EF) `uvm_error("TPU_CORNER", $sformatf("Strobe 0001 failed: 0x%h", rdata))
        else `uvm_info("TPU_CORNER", "Strobe 0001 passed", UVM_LOW)

        // Write byte 1
        write_raw(32'h0001_4010, 32'hDEAD_BEEF, 4'b0010);
        read_raw(32'h0001_4010, rdata);
        if (rdata != 32'h0000_BEEF) `uvm_error("TPU_CORNER", $sformatf("Strobe 0010 failed: 0x%h", rdata))

        // Write Halfword High
        write_raw(32'h0001_4010, 32'hBABE_0000, 4'b1100);
        read_raw(32'h0001_4010, rdata);
        if (rdata != 32'hBABE_BEEF) `uvm_error("TPU_CORNER", $sformatf("Strobe 1100 failed: 0x%h", rdata))

        // -------------------------------------------------------------
        // 5. 64-bit and Patterns (All 1s)
        // -------------------------------------------------------------
        write_operands(32'hFFFF_FFFF);
        read_raw(32'h0001_4010, rdata);
        if (rdata != 32'hFFFF_FFFF) `uvm_error("TPU_CORNER", "WEIGHT0_L did not hold FFFFFFFF")
        
        // Inference with max values
        write_raw(32'h0001_4000, 32'h0000_0001);
        timeout = 0;
        do begin
            ral.tpu.status.read(status, data, .parent(this));
            timeout++;
        end while ((data & 32'h2) == 0 && timeout < 1000);
        if (timeout >= 1000) `uvm_error("TPU_CORNER", "Timeout waiting for DONE (max values)")
        else `uvm_info("TPU_CORNER", "DONE asserted for FFFFFFFF inference", UVM_LOW)

        // Result behavior check
        ral.tpu.result0_l.read(status, data, .parent(this));
        `uvm_info("TPU_CORNER", $sformatf("Result0_L (max vals): 0x%08h", data), UVM_LOW)

        // -------------------------------------------------------------
        // 6. Repeated START and Zero Inference
        // -------------------------------------------------------------
        // Force the scoreboard to resync by doing a full zero write to all operands
        write_operands(32'h0000_0000);
        // Start = 0 (should do nothing)
        write_raw(32'h0001_4000, 32'h0000_0000);
        #10ns;
        ral.tpu.status.read(status, data, .parent(this));
        if (data & 32'h1) `uvm_error("TPU_CORNER", "BUSY went high after START=0")
        
        // Start = 1
        write_raw(32'h0001_4000, 32'h0000_0001);
        // Repeated start (while BUSY) -> shouldn't break anything, but RTL ignores it
        write_raw(32'h0001_4000, 32'h0000_0001);
        
        timeout = 0;
        do begin
            ral.tpu.status.read(status, data, .parent(this));
            timeout++;
        end while ((data & 32'h2) == 0 && timeout < 1000);
        
        ral.tpu.result0_l.read(status, data, .parent(this));
        `uvm_info("TPU_CORNER", $sformatf("Result0_L (zeros): 0x%08h", data), UVM_LOW)

        // -------------------------------------------------------------
        // 7. Q6.10 Specific Values (Large negative, Small positive)
        // -------------------------------------------------------------
        write_operands(32'h0000_0000);
        // Write W0 = -32.0 (0x8000), IN0 = -32.0 (0x8000) to cause max neg mult
        ral.tpu.weight0_l.write(status, {16'h8000, 16'h8000}, .parent(this)); // low word has 2 operands
        ral.tpu.input0_l.write(status, {16'h8000, 16'h8000}, .parent(this));
        
        write_raw(32'h0001_4000, 32'h0000_0001);
        timeout = 0;
        do begin
            ral.tpu.status.read(status, data, .parent(this));
            timeout++;
        end while ((data & 32'h2) == 0 && timeout < 1000);

        ral.tpu.result0_l.read(status, data, .parent(this));
        `uvm_info("TPU_CORNER", $sformatf("Result0_L (-32.0 inputs): 0x%08h", data), UVM_LOW)

    endtask
endclass

class soc_active_tpu_corner_test extends uvm_test;
    `uvm_component_utils(soc_active_tpu_corner_test)
    soc_env env;
    function new(string name = "soc_active_tpu_corner_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction
    virtual task run_phase(uvm_phase phase);
        soc_active_tpu_corner_sequence seq;
        phase.raise_objection(this);
        #200ns;
        seq = soc_active_tpu_corner_sequence::type_id::create("seq");
        seq.ral = env.ral_model;
        seq.start(env.native_agent.sequencer);
        #100ns;
        phase.drop_objection(this);
    endtask
endclass
`endif
