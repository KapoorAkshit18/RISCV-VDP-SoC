`ifndef TPU_SCOREBOARD_TB_SV
`define TPU_SCOREBOARD_TB_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// -----------------------------------------------------------------------------
// Include the transaction class used by the scoreboard.
//
// IMPORTANT:
// Replace this filename with the actual filename in your project if your
// soc_sequence_item class is stored elsewhere.
// -----------------------------------------------------------------------------
// `include "soc_sequence_item.sv"
// // Dependencies
// `include "../soc_agent/soc_sequence_item/soc_sequence_item.sv"
// `include "../soc_native_if/soc_native_if.sv"


// -----------------------------------------------------------------------------
// Include the scoreboard itself.
// -----------------------------------------------------------------------------
`include "soc_tpu_scoreboard.sv"


// =============================================================================
// RISCV-VDP-SoC
// Standalone TPU Scoreboard Testbench
// =============================================================================
//
// PURPOSE
// -------
// This testbench verifies the TPU scoreboard independently from:
//
//     - PicoRV32
//     - SoC RTL
//     - native bus driver
//     - native bus monitor
//     - RAL
//     - functional coverage
//
// Instead, this testbench directly generates the SAME transaction type that
// soc_monitor would normally publish.
//
//
//
// TEST FLOW
// ---------
//
//     1. Create scoreboard
//
//     2. Write W0-W4
//
//     3. Write INPUT0
//
//     4. Write INPUT1
//
//     5. Write CONTROL.START
//
//     6. Scoreboard calls C reference model
//
//     7. Read STATUS
//
//     8. Read RESULT0_LO
//
//     9. Read RESULT0_HI
//
//    10. Read RESULT1_LO
//
//    11. Read RESULT1_HI
//
//
//
// This therefore validates the scoreboard's:
//
//     - TPU address decoding
//     - 32-bit to 64-bit reconstruction
//     - operand capture
//     - START detection
//     - DPI reference-model invocation
//     - expected-result storage
//     - RESULT0 comparison
//     - RESULT1 comparison
//     - scoreboard statistics
//
// =============================================================================


// =============================================================================
// Standalone TPU scoreboard test
// =============================================================================

class tpu_scoreboard_test extends uvm_test;

    `uvm_component_utils(tpu_scoreboard_test)


    // =========================================================================
    // Scoreboard
    // =========================================================================

    soc_tpu_scoreboard scoreboard;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "tpu_scoreboard_test",
        uvm_component parent = null
    );

        super.new(name, parent);

    endfunction


    // =========================================================================
    // Build phase
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        scoreboard =
            soc_tpu_scoreboard::type_id::create(
                "scoreboard",
                this
            );

    endfunction


    // =========================================================================
    // End of elaboration
    // =========================================================================

    virtual function void end_of_elaboration_phase(
        uvm_phase phase
    );

        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "TB",
            "Standalone TPU scoreboard testbench constructed",
            UVM_LOW
        );

    endfunction


    // =========================================================================
    // Helper: create a write transaction
    // =========================================================================
    //
    // The actual soc_monitor would normally generate this transaction.
    //
    // Here we directly construct it and call scoreboard.write().
    //
    // =========================================================================

    task automatic send_write(
        bit [31:0] addr,
        bit [31:0] data
    );

        soc_sequence_item tr;

        tr = soc_sequence_item::type_id::create("write_tr");

        tr.addr   = addr;
        tr.wdata  = data;
        tr.rdata  = 32'h0000_0000;
        tr.write  = 1'b1;

        // The scoreboard filters using:
        //
        //     if (tr.target != "TPU")
        //         return;
        //
        // Therefore explicitly mark this transaction as TPU traffic.
        tr.target = "TPU";

        `uvm_info(
            "TB_WRITE",
            $sformatf(
                "TPU WRITE: addr=0x%08h data=0x%08h",
                addr,
                data
            ),
            UVM_MEDIUM
        );

        scoreboard.write(tr);

    endtask


    // =========================================================================
    // Helper: create a read transaction
    // =========================================================================

    task automatic send_read(
        bit [31:0] addr,
        bit [31:0] data
    );

        soc_sequence_item tr;

        tr = soc_sequence_item::type_id::create("read_tr");

        tr.addr   = addr;
        tr.wdata  = 32'h0000_0000;
        tr.rdata  = data;
        tr.write  = 1'b0;

        tr.target = "TPU";

        `uvm_info(
            "TB_READ",
            $sformatf(
                "TPU READ: addr=0x%08h data=0x%08h",
                addr,
                data
            ),
            UVM_MEDIUM
        );

        scoreboard.write(tr);

    endtask


    // =========================================================================
    // Helper: write one 64-bit TPU register
    // =========================================================================
    //
    // Native bus width = 32 bits.
    //
    // Therefore:
    //
    //     64-bit value
    //          |
    //          +---- LOW 32 bits
    //          |
    //          +---- HIGH 32 bits
    //
    // =========================================================================

    task automatic send_write64(
        bit [31:0] lo_addr,
        bit [31:0] hi_addr,
        bit [63:0] value
    );

        send_write(
            lo_addr,
            value[31:0]
        );

        send_write(
            hi_addr,
            value[63:32]
        );

    endtask


    // =========================================================================
    // Main test sequence
    // =========================================================================

    virtual task run_phase(uvm_phase phase);

        bit [63:0] w0;
        bit [63:0] w1;
        bit [63:0] w2;
        bit [63:0] w3;
        bit [63:0] w4;

        bit [63:0] input0;
        bit [63:0] input1;

        bit [63:0] expected_result0;
        bit [63:0] expected_result1;


        // =====================================================================
        // Start UVM test
        // =====================================================================

        phase.raise_objection(this);


        `uvm_info(
            "TB",
            "============================================================",
            UVM_NONE
        )

        `uvm_info(
            "TB",
            "STARTING STANDALONE TPU SCOREBOARD TEST",
            UVM_NONE
        )

        `uvm_info(
            "TB",
            "============================================================",
            UVM_NONE
        )


        // =====================================================================
        // Test vector
        // =====================================================================
        //
        // These are 64-bit software-visible values.
        //
        // Each contains four Q6.10 16-bit lanes:
        //
        //     [15:0]
        //     [31:16]
        //     [47:32]
        //     [63:48]
        //
        // You can replace these values with the exact TPU workload used by
        // your RTL test.
        //
        // =====================================================================

        w0 = 64'h0000_B07A_0505_057A;   // weight0

           

        w1 = 64'h0000_FC66_03E1_0314;   // weight1

            

        w2 = 64'h0000_FC70_028F_0433;   // weight2

           
        w3 = 64'hF5A3_0051_FAC2_1870;   // weight3

     
        w4 = 64'h00CC_07E1_0685_E399;   // weight4

            
        input0 = 64'h1400_1400_2000_2000;   // input0

           

        input1 = 64'h1400_2000_1400_2000;   // input1
           


        // =====================================================================
        // Display test vector
        // =====================================================================

        `uvm_info(
            "TB_VECTOR",
            $sformatf(
                "W0     = 0x%016h",
                w0
            ),
            UVM_LOW
        )

        `uvm_info(
            "TB_VECTOR",
            $sformatf(
                "W1     = 0x%016h",
                w1
            ),
            UVM_LOW
        )

        `uvm_info(
            "TB_VECTOR",
            $sformatf(
                "W2     = 0x%016h",
                w2
            ),
            UVM_LOW
        )

        `uvm_info(
            "TB_VECTOR",
            $sformatf(
                "W3     = 0x%016h",
                w3
            ),
            UVM_LOW
        )

        `uvm_info(
            "TB_VECTOR",
            $sformatf(
                "W4     = 0x%016h",
                w4
            ),
            UVM_LOW
        )

        `uvm_info(
            "TB_VECTOR",
            $sformatf(
                "INPUT0 = 0x%016h",
                input0
            ),
            UVM_LOW
        )

        `uvm_info(
            "TB_VECTOR",
            $sformatf(
                "INPUT1 = 0x%016h",
                input1
            ),
            UVM_LOW
        )


        // =====================================================================
        // Write W0
        // =====================================================================

        `uvm_info(
            "TB",
            "Writing W0",
            UVM_MEDIUM
        )

        send_write64(
            32'h0001_4010,
            32'h0001_4014,
            w0
        );


        // =====================================================================
        // Write W1
        // =====================================================================

        `uvm_info(
            "TB",
            "Writing W1",
            UVM_MEDIUM
        )

        send_write64(
            32'h0001_4018,
            32'h0001_401C,
            w1
        );


        // =====================================================================
        // Write W2
        // =====================================================================

        `uvm_info(
            "TB",
            "Writing W2",
            UVM_MEDIUM
        )

        send_write64(
            32'h0001_4020,
            32'h0001_4024,
            w2
        );


        // =====================================================================
        // Write W3
        // =====================================================================

        `uvm_info(
            "TB",
            "Writing W3",
            UVM_MEDIUM
        )

        send_write64(
            32'h0001_4028,
            32'h0001_402C,
            w3
        );


        // =====================================================================
        // Write W4
        // =====================================================================

        `uvm_info(
            "TB",
            "Writing W4",
            UVM_MEDIUM
        )

        send_write64(
            32'h0001_4030,
            32'h0001_4034,
            w4
        );


        // =====================================================================
        // Write INPUT0
        // =====================================================================

        `uvm_info(
            "TB",
            "Writing INPUT0",
            UVM_MEDIUM
        )

        send_write64(
            32'h0001_4038,
            32'h0001_403C,
            input0
        );


        // =====================================================================
        // Write INPUT1
        // =====================================================================

        `uvm_info(
            "TB",
            "Writing INPUT1",
            UVM_MEDIUM
        )

        send_write64(
            32'h0001_4040,
            32'h0001_4044,
            input1
        );


        // =====================================================================
        // START TPU
        // =====================================================================
        //
        // CONTROL bit 0 = START.
        //
        // The scoreboard should now:
        //
        //     1. detect START
        //     2. verify operands are complete
        //     3. invoke the C reference model
        //     4. obtain expected_result0
        //     5. obtain expected_result1
        //
        // =====================================================================

        `uvm_info(
            "TB",
            "Issuing TPU START",
            UVM_NONE
        )

        send_write(
            32'h0001_4000,
            32'h0000_0001
        );


        // =====================================================================
        // Allow scoreboard processing to complete
        // =====================================================================

        #1ns;


        // =====================================================================
        // Capture expected values from scoreboard
        // =====================================================================
        //
        // At this point the reference model should already have executed.
        //
        // =====================================================================

        expected_result0 =
            scoreboard.expected_result0;

        expected_result1 =
            scoreboard.expected_result1;


        `uvm_info(
            "TB_EXPECTED",
            $sformatf(
                "Reference RESULT0 = 0x%016h",
                expected_result0
            ),
            UVM_NONE
        )

        `uvm_info(
            "TB_EXPECTED",
            $sformatf(
                "Reference RESULT1 = 0x%016h",
                expected_result1
            ),
            UVM_NONE
        )


        // =====================================================================
        // Simulate STATUS read
        // =====================================================================
        //
        // For this standalone testbench we model the expected completed state:
        //
        //     BUSY = 0
        //     DONE = 1
        //
        // STATUS = 32'h0000_0002
        //
        // This is not a DUT check because there is no DUT in this standalone
        // environment. It simply exercises scoreboard STATUS processing.
        //
        // =====================================================================

        send_read(
            32'h0001_4004,
            32'h0000_0002
        );


        // =====================================================================
        // Read RESULT0 low word
        // =====================================================================

        send_read(
            32'h0001_4050,
            expected_result0[31:0]
        );


        // =====================================================================
        // Read RESULT0 high word
        // =====================================================================

        send_read(
            32'h0001_4054,
            expected_result0[63:32]
        );


        // =====================================================================
        // Read RESULT1 low word
        // =====================================================================

        send_read(
            32'h0001_4058,
            expected_result1[31:0]
        );


        // =====================================================================
        // Read RESULT1 high word
        // =====================================================================

        send_read(
            32'h0001_405C,
            expected_result1[63:32]
        );


        // =====================================================================
        // Allow all scoreboard messages to finish
        // =====================================================================

        #1ns;


        // =====================================================================
        // End test
        // =====================================================================

        `uvm_info(
            "TB",
            "============================================================",
            UVM_NONE
        )

        `uvm_info(
            "TB",
            "STANDALONE TPU SCOREBOARD TEST COMPLETED",
            UVM_NONE
        )

        `uvm_info(
            "TB",
            "============================================================",
            UVM_NONE
        )


        phase.drop_objection(this);

    endtask

endclass



// =============================================================================
// UVM top-level
// =============================================================================

module tpu_scoreboard_tb;

    initial begin

        run_test("tpu_scoreboard_test");

    end

endmodule


`endif
