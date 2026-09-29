`ifndef SOC_ACTIVE_CAMPAIGN_SEQUENCE_SV
`define SOC_ACTIVE_CAMPAIGN_SEQUENCE_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class soc_active_campaign_sequence extends uvm_sequence#(soc_sequence_item);
    `uvm_object_utils(soc_active_campaign_sequence)

    function new(string name="soc_active_campaign_sequence");
        super.new(name);
    endfunction

    virtual task do_write(logic [31:0] a, logic [31:0] d, logic [3:0] s);
        soc_sequence_item req = soc_sequence_item::type_id::create("req");
        start_item(req); req.write=1; req.addr=a; req.wdata=d; req.strb=s; finish_item(req);
    endtask

    virtual task do_read(logic [31:0] a, output logic [31:0] d);
        soc_sequence_item req = soc_sequence_item::type_id::create("req");
        start_item(req); req.write=0; req.addr=a; req.wdata=0; req.strb=4'h0; finish_item(req);
        d = req.rdata;
    endtask

    virtual task body();
        logic [31:0] rdata;
        
        `uvm_info("CAMPAIGN", "Starting Active UVM Mutation Campaign Sequence", UVM_LOW)

        // ---------------------------------------------------------
        // M10: Unmapped Ready Stuck 0
        // Golden: Unmapped reads return 0. M10: Hangs (Timeout).
        // ---------------------------------------------------------
        do_read(32'h0001_F000, rdata);
        if (rdata != 32'h0) `uvm_error("M10", $sformatf("Expected 0 for unmapped, got %0h", rdata))

        // ---------------------------------------------------------
        // M07: RF Valid Stuck 0
        // Golden: Reads RF reg. M07: Valid never asserted, hangs (Timeout).
        // ---------------------------------------------------------
        do_read(32'h0001_1000, rdata);

        // ---------------------------------------------------------
        // M04: RF Rdata routing
        // Golden: RF returns 0 by default. M04: Returns Sensor data (0x0A/10).
        // ---------------------------------------------------------
        if (rdata == 32'h0000_000A) `uvm_error("M04", "DETECTED: RF read returned Sensor data (0x0A)!")

        // ---------------------------------------------------------
        // M03: GPIO Ready routing
        // Golden: Reads GPIO. M03: Ready comes from RF. If RF isn't ready, hangs. 
        // Or if it completes, data might be wrong.
        // ---------------------------------------------------------
        do_read(32'h0001_0000, rdata);

        // ---------------------------------------------------------
        // M05: VDP Write Stuck 0
        // Golden: VDP Color Reg (0x0001_3010) is R/W. M05: Write dropped, reads default 0xFFFFFF.
        // ---------------------------------------------------------
        do_write(32'h0001_3010, 32'h00112233, 4'hF);
        do_read(32'h0001_3010, rdata);
        if (rdata == 32'h00FFFFFF) `uvm_error("M05", "DETECTED: VDP write ignored, read default 0xFFFFFF!")

        // ---------------------------------------------------------
        // M08: Sensor uses VDP Base (0x13000)
        // Golden: Sensor at 0x12000 returns 0x0A. M08: Unmapped, returns 0.
        // ---------------------------------------------------------
        do_read(32'h0001_2000, rdata);
        if (rdata != 32'h0000_000A) `uvm_error("M08", $sformatf("DETECTED: Sensor read failed. Got %0h", rdata))

        // ---------------------------------------------------------
        // M01: TPU Base Addr (shifted to 0x15000)
        // Golden: 0x15000 unmapped (ignores write). M01: Starts TPU.
        // ---------------------------------------------------------
        do_write(32'h0001_5000, 32'h0000_0001, 4'hF); // Write TPU_CONTROL
        do_read(32'h0001_5004, rdata);                // Read TPU_STATUS
        if (rdata != 32'h0) `uvm_error("M01", "DETECTED: Unmapped TPU alias at 0x15000 responded!")

        // ---------------------------------------------------------
        // M06: RAM Strobe Forced 0xF
        // Golden: Byte write works. M06: Overwrites whole word.
        // ---------------------------------------------------------
        do_write(32'h0000_1000, 32'h11223344, 4'hF);
        do_write(32'h0000_1000, 32'h00000099, 4'h1);
        do_read(32'h0000_1000, rdata);
        if (rdata != 32'h11223399) `uvm_error("M06", $sformatf("DETECTED: RAM strobe byte write failed. Got %0h", rdata))
        
        `uvm_info("CAMPAIGN", "Active Campaign Sequence Completed successfully.", UVM_LOW)
    endtask
endclass

class soc_active_campaign_test extends uvm_test;
    `uvm_component_utils(soc_active_campaign_test)

    soc_env env;

    function new(string name = "soc_active_campaign_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_active_campaign_sequence seq;
        phase.raise_objection(this, "Starting ACTIVE CAMPAIGN test");

        #200ns;

        seq = soc_active_campaign_sequence::type_id::create("seq");
        seq.start(env.native_agent.sequencer);
        
        #100ns;

        phase.drop_objection(this, "Finished ACTIVE CAMPAIGN test");
    endtask
endclass

`endif
