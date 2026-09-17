`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "soc_sequence_item.sv"
`include "soc_tpu_scoreboard.sv"


// =============================================================================
// Standalone TPU Scoreboard Test
// =============================================================================
// No DUT
// No PicoRV32
// No soc_env
// No agent
// No monitor
// No RAL
//
// This directly creates native-bus transactions and feeds them into the
// TPU scoreboard.
//
// Transaction flow:
//
//   TB
//    |
//    v
//   soc_sequence_item
//    |
//    v
//   soc_tpu_scoreboard.write()
//    |
//    v
//   DPI-C reference model
//    |
//    v
//   Expected RESULT0/RESULT1
//    |
//    v
//   Compare against supplied RESULT reads
//
// =============================================================================


class tpu_scoreboard_test extends uvm_test;

    `uvm_component_utils(tpu_scoreboard_test)

    soc_tpu_scoreboard scb;

    function new(
        string name = "tpu_scoreboard_test",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction


    // =========================================================================
    // Build
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        scb = soc_tpu_scoreboard::type_id::create(
            "scb",
            this
        );

    endfunction


    // =========================================================================
    // Helper: send one TPU write
    // =========================================================================

    task automatic tpu_write(
        bit [31:0] addr,
        bit [31:0] data
    );

        soc_sequence_item tr;

        tr = soc_sequence_item::type_id::create("tr");

        tr.write = 1'b1;
        tr.addr  = addr;
        tr.wdata = data;
        tr.strb  = 4'b1111;
        tr.ready = 1'b1;
        tr.target = "TPU";

        scb.write(tr);

    endtask


    // =========================================================================
    // Helper: send one TPU read
    // =========================================================================

    task automatic tpu_read(
        bit [31:0] addr,
        bit [31:0] data
    );

        soc_sequence_item tr;

        tr = soc_sequence_item::type_id::create("tr");

        tr.write = 1'b0;
        tr.addr  = addr;
        tr.wdata = 32'h0000_0000;
        tr.strb  = 4'b0000;
        tr.ready = 1'b1;
        tr.rdata = data;
        tr.target = "TPU";

        scb.write(tr);

    endtask


    // =========================================================================
    // Main test
    // =========================================================================

    virtual task run_phase(uvm_phase phase);

        bit [31:0] BASE;

        bit [63:0] W0;
        bit [63:0] W1;
        bit [63:0] W2;
        bit [63:0] W3;
        bit [63:0] W4;

        bit [63:0] INPUT0;
        bit [63:0] INPUT1;

        bit [63:0] expected_result0;
        bit [63:0] expected_result1;


        phase.raise_objection(this);

        BASE = 32'h0001_4000;


        // =====================================================================
        // TEST OPERANDS
        // =====================================================================
        //
        // Replace these with your actual TPU test vectors.
        //
        // Each 64-bit value contains four 16-bit Q6.10 lanes.
        //
        // =====================================================================

        W0 = 64'h0400_0400_0400_0400;
        W1 = 64'h0400_0400_0400_0400;
        W2 = 64'h0400_0400_0400_0400;
        W3 = 64'h0400_0400_0400_0400;
        W4 = 64'h0400_0400_0400_0400;

        INPUT0 = 64'h0400_0400_0400_0400;
        INPUT1 = 64'h0400_0400_0400_0400;


        // =====================================================================
        // WRITE W0
        // =====================================================================

        tpu_write(BASE + 32'h10, W0[31:0]);
        tpu_write(BASE + 32'h14, W0[63:32]);


        // =====================================================================
        // WRITE W1
        // =====================================================================

        tpu_write(BASE + 32'h18, W1[31:0]);
        tpu_write(BASE + 32'h1C, W1[63:32]);


        // =====================================================================
        // WRITE W2
        // =====================================================================

        tpu_write(BASE + 32'h20, W2[31:0]);
        tpu_write(BASE + 32'h24, W2[63:32]);


        // =====================================================================
        // WRITE W3
        // =====================================================================

        tpu_write(BASE + 32'h28, W3[31:0]);
        tpu_write(BASE + 32'h2C, W3[63:32]);


        // =====================================================================
        // WRITE W4
        // =====================================================================

        tpu_write(BASE + 32'h30, W4[31:0]);
        tpu_write(BASE + 32'h34, W4[63:32]);


        // =====================================================================
        // WRITE INPUT0
        // =====================================================================

        tpu_write(BASE + 32'h38, INPUT0[31:0]);
        tpu_write(BASE + 32'h3C, INPUT0[63:32]);


        // =====================================================================
        // WRITE INPUT1
        // =====================================================================

        tpu_write(BASE + 32'h40, INPUT1[31:0]);
        tpu_write(BASE + 32'h44, INPUT1[63:32]);


        // =====================================================================
        // START TPU
        // =====================================================================

        tpu_write(BASE + 32'h00, 32'h0000_0001);


        // =====================================================================
        // IMPORTANT
        // =====================================================================
        //
        // At this point the scoreboard has called the C reference model.
        //
        // We need the expected values to create the RESULT reads.
        //
        // For a true independent test, obtain these from the same known-good
        // reference vector rather than copying the scoreboard's internal
        // expected value.
        //
        // For the first connectivity test, use the DPI model directly here.
        //
        // =====================================================================

        expected_result0 = tpu_ref_get_result(0);
        expected_result1 = tpu_ref_get_result(1);


        // =====================================================================
        // READ RESULT0
        // =====================================================================

        tpu_read(
            BASE + 32'h50,
            expected_result0[31:0]
        );

        tpu_read(
            BASE + 32'h54,
            expected_result0[63:32]
        );


        // =====================================================================
        // READ RESULT1
        // =====================================================================

        tpu_read(
            BASE + 32'h58,
            expected_result1[31:0]
        );

        tpu_read(
            BASE + 32'h5C,
            expected_result1[63:32]
        );


        #100;

        phase.drop_objection(this);

    endtask

endclass



// =============================================================================
// DPI declaration used only by this standalone TB
// =============================================================================
//
// This assumes your DLL exports tpu_ref_get_result().
//
// If your current DLL does NOT export this function, remove these two calls
// and instead hard-code the independently calculated expected result.
//
// =============================================================================

import "DPI-C" function longint unsigned tpu_ref_get_result(
    input int unsigned index
);


// =============================================================================
// Actual Questa simulation top
// =============================================================================

module tb;

    initial begin

        $display("============================================================");
        $display(" Standalone TPU UVM Scoreboard Verification");
        $display("============================================================");

        run_test("tpu_scoreboard_test");

    end

endmodule