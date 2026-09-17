`ifndef SOC_TPU_SCOREBOARD_SV
`define SOC_TPU_SCOREBOARD_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// =============================================================================
// RISCV-VDP-// // Dependencies
// `include "../soc_agent/soc_sequence_item/soc_sequence_item.sv"
// `include "../soc_native_if/soc_native_if.sv"
//SoC
// TPU UVM Scoreboard
// =============================================================================
//
// PURPOSE
// -------
// This scoreboard verifies the software-visible behavior of the integrated TPU
// through the existing 32-bit native CPU bus.
//
// The scoreboard observes completed transactions from soc_monitor:
//
//
//               z     soc_monitor
//                         |
//                         | analysis_port
//                         v
//                 soc_tpu_scoreboard
//                         |
//                         | DPI-C
//                         v
//                  C TPU Reference Model
//                         |
//                         v
//                 Expected RESULT0/1
//
//                         |
//                         | compare
//                         v
//                  Actual DUT result
//
// The scoreboard does NOT inspect internal TPU RTL signals.
//
// Instead, it observes the same native-bus transactions that are visible to
// the RISC-V CPU. Therefore, the verification is performed at the
// software-visible MMIO interface of the integrated TPU.
//
// =============================================================================
// TPU ADDRESS MAP
// =============================================================================
//
// TPU base address:
//
//     0x0001_4000
//
// Register map:
//
//     CONTROL   0x00       START bit 0
//     STATUS    0x04       BUSY bit 0, DONE bit 1
//
//     W0        0x10 / 0x14
//     W1        0x18 / 0x1C
//     W2        0x20 / 0x24
//     W3        0x28 / 0x2C
//     W4        0x30 / 0x34
//
//     INPUT0    0x38 / 0x3C
//     INPUT1    0x40 / 0x44
//
//     RESULT0   0x50 / 0x54
//     RESULT1   0x58 / 0x5C
//
// Every 64-bit TPU operand/result is accessed through two 32-bit native-bus
// transactions:
//
//     LOW  = bits [31:0]
//     HIGH = bits [63:32]
//
// =============================================================================
// REFERENCE MODEL INTERFACE
// =============================================================================
//
// The actual C reference model supplied with this project provides:
//
//     void tpu_reference(
//         const uint64_t axi_words[7],
//         uint64_t *result0,
//         uint64_t *result1
//     );
//
// The seven 64-bit words are:
//
//     axi_words[0] = W0
//     axi_words[1] = W1
//     axi_words[2] = W2
//     axi_words[3] = W3
//     axi_words[4] = W4
//     axi_words[5] = INPUT0
//     axi_words[6] = INPUT1
//
// The scoreboard therefore uses exactly the same seven-word interface as the
// C golden model.
//
// =============================================================================


//
// DPI-C IMPORT
// =============================================================================
//
// This declaration must match:
//
//     void tpu_reference(const uint64_t axi_words[7],
//                       uint64_t *result0,
//                       uint64_t *result1);
//
// The SystemVerilog longint unsigned type is 64 bits and is therefore suitable
// for the uint64_t values used by the C reference model.
//
//

import "DPI-C" function void tpu_reference(
    input  longint unsigned axi_words[7],
    output longint unsigned result0,
    output longint unsigned result1
);


// =============================================================================
// SCOREBOARD CLASS
// =============================================================================

class soc_tpu_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(soc_tpu_scoreboard)


    // =========================================================================
    // Analysis implementation
    // =========================================================================
    //
    // soc_monitor publishes soc_sequence_item transactions through its
    // analysis_port.
    //
    // The scoreboard receives every transaction through write().
    //
    // Non-TPU transactions are ignored.
    //

    uvm_analysis_imp #(soc_sequence_item, soc_tpu_scoreboard) analysis_imp;


    // =========================================================================
    // TPU BASE ADDRESS
    // =========================================================================

    localparam bit [31:0] TPU_BASE = 32'h0001_4000;


    // =========================================================================
    // CONTROL / STATUS
    // =========================================================================

    localparam bit [31:0] TPU_CONTROL = TPU_BASE + 32'h00;
    localparam bit [31:0] TPU_STATUS  = TPU_BASE + 32'h04;


    // =========================================================================
    // WEIGHT REGISTERS
    // =========================================================================

    localparam bit [31:0] TPU_W0_LO = TPU_BASE + 32'h10;
    localparam bit [31:0] TPU_W0_HI = TPU_BASE + 32'h14;

    localparam bit [31:0] TPU_W1_LO = TPU_BASE + 32'h18;
    localparam bit [31:0] TPU_W1_HI = TPU_BASE + 32'h1C;

    localparam bit [31:0] TPU_W2_LO = TPU_BASE + 32'h20;
    localparam bit [31:0] TPU_W2_HI = TPU_BASE + 32'h24;

    localparam bit [31:0] TPU_W3_LO = TPU_BASE + 32'h28;
    localparam bit [31:0] TPU_W3_HI = TPU_BASE + 32'h2C;

    localparam bit [31:0] TPU_W4_LO = TPU_BASE + 32'h30;
    localparam bit [31:0] TPU_W4_HI = TPU_BASE + 32'h34;


    // =========================================================================
    // INPUT REGISTERS
    // =========================================================================

    localparam bit [31:0] TPU_INPUT0_LO = TPU_BASE + 32'h38;
    localparam bit [31:0] TPU_INPUT0_HI = TPU_BASE + 32'h3C;

    localparam bit [31:0] TPU_INPUT1_LO = TPU_BASE + 32'h40;
    localparam bit [31:0] TPU_INPUT1_HI = TPU_BASE + 32'h44;


    // =========================================================================
    // RESULT REGISTERS
    // =========================================================================

    localparam bit [31:0] TPU_RESULT0_LO = TPU_BASE + 32'h50;
    localparam bit [31:0] TPU_RESULT0_HI = TPU_BASE + 32'h54;

    localparam bit [31:0] TPU_RESULT1_LO = TPU_BASE + 32'h58;
    localparam bit [31:0] TPU_RESULT1_HI = TPU_BASE + 32'h5C;


    // =========================================================================
    // CAPTURED 64-BIT OPERANDS
    // =========================================================================
    //
    // The native CPU bus is 32 bits wide.
    //
    // Therefore every 64-bit TPU operand is reconstructed from two writes.
    //
    // Example:
    //
    //     W0 = {W0_HI, W0_LO}
    //
    // These arrays represent exactly the seven 64-bit words consumed by the
    // C reference model.
    //

    bit [63:0] weight [0:4];

    bit [63:0] input0;
    bit [63:0] input1;


    // =========================================================================
    // EXPECTED RESULTS
    // =========================================================================

    bit [63:0] expected_result0;
    bit [63:0] expected_result1;


    // =========================================================================
    // OPERAND VALID FLAGS
    // =========================================================================
    //
    // Each 64-bit operand requires both a LOW and HIGH write before START.
    //
    // These flags prevent the reference model from being executed with
    // incomplete operands.
    //

    bit w0_lo_valid;
    bit w0_hi_valid;

    bit w1_lo_valid;
    bit w1_hi_valid;

    bit w2_lo_valid;
    bit w2_hi_valid;

    bit w3_lo_valid;
    bit w3_hi_valid;

    bit w4_lo_valid;
    bit w4_hi_valid;

    bit input0_lo_valid;
    bit input0_hi_valid;

    bit input1_lo_valid;
    bit input1_hi_valid;


    // =========================================================================
    // REFERENCE MODEL / TRANSACTION STATE
    // =========================================================================

    // Set after the C reference model has successfully generated expected data.
    bit reference_model_valid;

    // Indicates that a START write has been observed.
    bit start_seen;

    // Indicates that the DUT has reported DONE.
    bit done_seen;

    // Indicates whether individual result words have already been checked.
    bit result0_lo_checked;
    bit result0_hi_checked;

    bit result1_lo_checked;
    bit result1_hi_checked;


    // =========================================================================
    // STATISTICS
    // =========================================================================

    int unsigned tpu_write_count;
    int unsigned tpu_read_count;

    int unsigned start_count;

    int unsigned status_read_count;

    int unsigned result_compare_count;
    int unsigned result_error_count;


    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================

    function new(
        string name = "soc_tpu_scoreboard",
        uvm_component parent = null
    );

        super.new(name, parent);

        // Create analysis implementation.
        analysis_imp = new("analysis_imp", this);

        // Initialize statistics.
        tpu_write_count      = 0;
        tpu_read_count       = 0;
        start_count          = 0;
        status_read_count    = 0;
        result_compare_count = 0;
        result_error_count   = 0;

        // Initialize transaction state.
        reference_model_valid = 1'b0;
        start_seen            = 1'b0;
        done_seen             = 1'b0;

        // Clear all operand capture state.
        clear_capture_state();

    endfunction


    // =========================================================================
    // BUILD PHASE
    // =========================================================================

    virtual function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        `uvm_info(
            "TPU_SCB",
            "TPU scoreboard constructed",
            UVM_LOW
        )

    endfunction


    // =========================================================================
    // END OF ELABORATION
    // =========================================================================

    virtual function void end_of_elaboration_phase(
        uvm_phase phase
    );

        super.end_of_elaboration_phase(phase);

        `uvm_info(
            "TPU_SCB",
            "TPU scoreboard connected to native-bus monitor",
            UVM_LOW
        )

    endfunction


    // =========================================================================
    // MAIN ANALYSIS CALLBACK
    // =========================================================================
    //
    // Every completed native-bus transaction from soc_monitor arrives here.
    //
    // The scoreboard first checks whether the transaction belongs to the TPU.
    //
    // Non-TPU accesses such as:
    //
    //     RAM
    //     GPIO
    //     RF
    //     SENSOR
    //     VDP
    //
    // are ignored.
    //

    virtual function void write(soc_sequence_item tr);

        if (tr == null) begin

            `uvm_error(
                "TPU_SCB",
                "Received null transaction"
            )

            return;

        end


        // ---------------------------------------------------------------------
        // Ignore all non-TPU accesses.
        // ---------------------------------------------------------------------

        if (tr.target != "TPU")
            return;


        // ---------------------------------------------------------------------
        // Update transaction statistics.
        // ---------------------------------------------------------------------

        if (tr.write)
            tpu_write_count++;
        else
            tpu_read_count++;


        // ---------------------------------------------------------------------
        // Dispatch according to transaction direction.
        // ---------------------------------------------------------------------

        if (tr.write)
            process_tpu_write(tr);
        else
            process_tpu_read(tr);

    endfunction


    // =========================================================================
    // PROCESS TPU WRITE
    // =========================================================================
    //
    // Handles:
    //
    //     W0-W4
    //     INPUT0
    //     INPUT1
    //     CONTROL.START
    //

    virtual function void process_tpu_write(
        soc_sequence_item tr
    );

        case (tr.addr)


            // =================================================================
            // W0 LOW
            // =================================================================

            TPU_W0_LO: begin

                weight[0][31:0] = tr.wdata;
                w0_lo_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W0_LO  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W0 HIGH
            // =================================================================

            TPU_W0_HI: begin

                weight[0][63:32] = tr.wdata;
                w0_hi_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W0_HI  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W1 LOW
            // =================================================================

            TPU_W1_LO: begin

                weight[1][31:0] = tr.wdata;
                w1_lo_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W1_LO  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W1 HIGH
            // =================================================================

            TPU_W1_HI: begin

                weight[1][63:32] = tr.wdata;
                w1_hi_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W1_HI  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W2 LOW
            // =================================================================

            TPU_W2_LO: begin

                weight[2][31:0] = tr.wdata;
                w2_lo_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W2_LO  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W2 HIGH
            // =================================================================

            TPU_W2_HI: begin

                weight[2][63:32] = tr.wdata;
                w2_hi_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W2_HI  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W3 LOW
            // =================================================================

            TPU_W3_LO: begin

                weight[3][31:0] = tr.wdata;
                w3_lo_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W3_LO  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W3 HIGH
            // =================================================================

            TPU_W3_HI: begin

                weight[3][63:32] = tr.wdata;
                w3_hi_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W3_HI  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W4 LOW
            // =================================================================

            TPU_W4_LO: begin

                weight[4][31:0] = tr.wdata;
                w4_lo_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W4_LO  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // W4 HIGH
            // =================================================================

            TPU_W4_HI: begin

                weight[4][63:32] = tr.wdata;
                w4_hi_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "W4_HI  <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // INPUT0 LOW
            // =================================================================

            TPU_INPUT0_LO: begin

                input0[31:0] = tr.wdata;
                input0_lo_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "INPUT0_LO <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // INPUT0 HIGH
            // =================================================================

            TPU_INPUT0_HI: begin

                input0[63:32] = tr.wdata;
                input0_hi_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "INPUT0_HI <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // INPUT1 LOW
            // =================================================================

            TPU_INPUT1_LO: begin

                input1[31:0] = tr.wdata;
                input1_lo_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "INPUT1_LO <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // INPUT1 HIGH
            // =================================================================

            TPU_INPUT1_HI: begin

                input1[63:32] = tr.wdata;
                input1_hi_valid = 1'b1;

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "INPUT1_HI <= 0x%08h",
                        tr.wdata
                    ),
                    UVM_MEDIUM
                )

            end


            // =================================================================
            // CONTROL
            // =================================================================
            //
            // CONTROL bit 0 = START.
            //
            // When START is detected:
            //
            //     1. Verify all operands were written.
            //     2. Build the seven-word reference-model input.
            //     3. Execute the C golden model.
            //     4. Capture expected RESULT0/RESULT1.
            //

            TPU_CONTROL: begin

                if (tr.wdata[0]) begin

                    start_count++;
                    start_seen = 1'b1;
                    done_seen = 1'b0;

                    // A new START begins a new comparison transaction.
                    result0_lo_checked = 1'b0;
                    result0_hi_checked = 1'b0;
                    result1_lo_checked = 1'b0;
                    result1_hi_checked = 1'b0;

                    `uvm_info(
                        "TPU_START",
                        "TPU START detected",
                        UVM_MEDIUM
                    )


                    // ---------------------------------------------------------
                    // Check that every 64-bit operand has been written.
                    // ---------------------------------------------------------

                    if (!all_operands_valid()) begin

                        `uvm_error(
                            "TPU_START",
                            "START detected before all TPU operands were written"
                        )

                    end
                    else begin

                        // -----------------------------------------------------
                        // Execute C reference model.
                        // -----------------------------------------------------

                        run_reference_model();

                    end

                end

            end


            // =================================================================
            // UNKNOWN TPU WRITE
            // =================================================================

            default: begin

                `uvm_info(
                    "TPU_WRITE",
                    $sformatf(
                        "Unrecognized TPU write: addr=0x%08h data=0x%08h",
                        tr.addr,
                        tr.wdata
                    ),
                    UVM_LOW
                )

            end

        endcase

    endfunction


    // =========================================================================
    // PROCESS TPU READ
    // =========================================================================
    //
    // Handles:
    //
    //     STATUS
    //     RESULT0
    //     RESULT1
    //

    virtual function void process_tpu_read(
        soc_sequence_item tr
    );

        case (tr.addr)


            // =================================================================
            // STATUS
            // =================================================================

            TPU_STATUS: begin

                status_read_count++;

                check_status(tr);

            end


            // =================================================================
            // RESULT0 LOW
            // =================================================================

            TPU_RESULT0_LO: begin

                if (!reference_model_valid) begin

                    `uvm_warning(
                        "TPU_RESULT",
                        "RESULT0_LO read before reference model generated expected data"
                    )

                end
                else if (!done_seen) begin

                    `uvm_warning(
                        "TPU_RESULT",
                        "RESULT0_LO read before DONE was observed"
                    )

                end
                else begin

                    compare_result_word(
                        "RESULT0_LO",
                        expected_result0[31:0],
                        tr.rdata,
                        tr.addr
                    );

                    result0_lo_checked = 1'b1;

                end

            end


            // =================================================================
            // RESULT0 HIGH
            // =================================================================

            TPU_RESULT0_HI: begin

                if (!reference_model_valid) begin

                    `uvm_warning(
                        "TPU_RESULT",
                        "RESULT0_HI read before reference model generated expected data"
                    )

                end
                else if (!done_seen) begin

                    `uvm_warning(
                        "TPU_RESULT",
                        "RESULT0_HI read before DONE was observed"
                    )

                end
                else begin

                    compare_result_word(
                        "RESULT0_HI",
                        expected_result0[63:32],
                        tr.rdata,
                        tr.addr
                    );

                    result0_hi_checked = 1'b1;

                end

            end


            // =================================================================
            // RESULT1 LOW
            // =================================================================

            TPU_RESULT1_LO: begin

                if (!reference_model_valid) begin

                    `uvm_warning(
                        "TPU_RESULT",
                        "RESULT1_LO read before reference model generated expected data"
                    )

                end
                else if (!done_seen) begin

                    `uvm_warning(
                        "TPU_RESULT",
                        "RESULT1_LO read before DONE was observed"
                    )

                end
                else begin

                    compare_result_word(
                        "RESULT1_LO",
                        expected_result1[31:0],
                        tr.rdata,
                        tr.addr
                    );

                    result1_lo_checked = 1'b1;

                end

            end


            // =================================================================
            // RESULT1 HIGH
            // =================================================================

            TPU_RESULT1_HI: begin

                if (!reference_model_valid) begin

                    `uvm_warning(
                        "TPU_RESULT",
                        "RESULT1_HI read before reference model generated expected data"
                    )

                end
                else if (!done_seen) begin

                    `uvm_warning(
                        "TPU_RESULT",
                        "RESULT1_HI read before DONE was observed"
                    )

                end
                else begin

                    compare_result_word(
                        "RESULT1_HI",
                        expected_result1[63:32],
                        tr.rdata,
                        tr.addr
                    );

                    result1_hi_checked = 1'b1;

                end

            end


            // =================================================================
            // UNKNOWN TPU READ
            // =================================================================

            default: begin

                `uvm_info(
                    "TPU_READ",
                    $sformatf(
                        "Unrecognized TPU read: addr=0x%08h rdata=0x%08h",
                        tr.addr,
                        tr.rdata
                    ),
                    UVM_LOW
                )

            end

        endcase

    endfunction


    // =========================================================================
    // STATUS CHECK
    // =========================================================================
    //
    // STATUS:
    //
    //     bit 0 = BUSY
    //     bit 1 = DONE
    //
    // The scoreboard intentionally does not impose an arbitrary cycle count.
    //
    // Instead, it verifies:
    //
    //     - reserved bits are zero
    //     - DONE is observed by the time result reads are expected
    //
    // The exact TPU latency remains an RTL implementation property.
    //

    virtual function void check_status(
        soc_sequence_item tr
    );

        bit busy;
        bit done;

        busy = tr.rdata[0];
        done = tr.rdata[1];


        // ---------------------------------------------------------------------
        // Reserved bits must remain zero.
        // ---------------------------------------------------------------------

        if (tr.rdata[31:2] != 30'b0) begin

            `uvm_error(
                "TPU_STATUS",
                $sformatf(
                    "STATUS reserved bits are non-zero: rdata=0x%08h",
                    tr.rdata
                )
            )

        end


        // ---------------------------------------------------------------------
        // Capture DONE state.
        //
        // Once DONE has been observed, result reads may be compared.
        // ---------------------------------------------------------------------

        if (done) begin

            done_seen = 1'b1;

            `uvm_info(
                "TPU_STATUS",
                "TPU DONE observed",
                UVM_MEDIUM
            )

        end


        // ---------------------------------------------------------------------
        // Informational status report.
        // ---------------------------------------------------------------------

        `uvm_info(
            "TPU_STATUS",
            $sformatf(
                "STATUS: BUSY=%0b DONE=%0b",
                busy,
                done
            ),
            UVM_MEDIUM
        )


        // ---------------------------------------------------------------------
        // If the reference model has completed but RTL has not reported DONE,
        // report this as informational rather than an error.
        //
        // This avoids imposing a fixed cycle latency on the scoreboard.
        // ---------------------------------------------------------------------

        if (reference_model_valid && !done) begin

            `uvm_info(
                "TPU_STATUS",
                "Reference model complete; DUT has not reported DONE yet",
                UVM_LOW
            )

        end

    endfunction


    // =========================================================================
    // CHECK ALL OPERANDS
    // =========================================================================

    virtual function bit all_operands_valid();

        return
            w0_lo_valid &&
            w0_hi_valid &&

            w1_lo_valid &&
            w1_hi_valid &&

            w2_lo_valid &&
            w2_hi_valid &&

            w3_lo_valid &&
            w3_hi_valid &&

            w4_lo_valid &&
            w4_hi_valid &&

            input0_lo_valid &&
            input0_hi_valid &&

            input1_lo_valid &&
            input1_hi_valid;

    endfunction


    // =========================================================================
    // RUN C REFERENCE MODEL
    // =========================================================================
    //
    // The C model expects exactly seven 64-bit words:
    //
    //     word[0] = W0
    //     word[1] = W1
    //     word[2] = W2
    //     word[3] = W3
    //     word[4] = W4
    //     word[5] = INPUT0
    //     word[6] = INPUT1
    //
    // This mapping exactly matches the supplied C implementation:
    //
    //     memcpy(in.wb, &axi_words[0], sizeof(in.wb));
    //     memcpy(in.k,  &axi_words[5], sizeof(in.k));
    //
    // The C model then performs:
    //
    //     - signed 16-bit lane unpacking
    //     - fixed-point PE MAC
    //     - 16-bit wraparound
    //     - first systolic pass
    //     - sigmoid
    //     - sigmoid feedback
    //     - second systolic pass
    //     - sigmoid
    //     - final 64-bit result packing
    //
    // The scoreboard deliberately does NOT duplicate these numerical
    // calculations. The C model is the golden reference.
    //

    virtual function void run_reference_model();

        longint unsigned axi_words[7];

        longint unsigned c_result0;
        longint unsigned c_result1;


        // ---------------------------------------------------------------------
        // Build the exact seven-word input expected by the C model.
        // ---------------------------------------------------------------------

        axi_words[0] = weight[0];
        axi_words[1] = weight[1];
        axi_words[2] = weight[2];
        axi_words[3] = weight[3];
        axi_words[4] = weight[4];

        axi_words[5] = input0;
        axi_words[6] = input1;


        `uvm_info(
            "TPU_REF",
            "Calling C TPU reference model",
            UVM_MEDIUM
        )


        // ---------------------------------------------------------------------
        // Display complete reference-model input.
        // ---------------------------------------------------------------------

        `uvm_info(
            "TPU_REF",
            $sformatf(
                "W0     = 0x%016h",
                axi_words[0]
            ),
            UVM_HIGH
        )

        `uvm_info(
            "TPU_REF",
            $sformatf(
                "W1     = 0x%016h",
                axi_words[1]
            ),
            UVM_HIGH
        )

        `uvm_info(
            "TPU_REF",
            $sformatf(
                "W2     = 0x%016h",
                axi_words[2]
            ),
            UVM_HIGH
        )

        `uvm_info(
            "TPU_REF",
            $sformatf(
                "W3     = 0x%016h",
                axi_words[3]
            ),
            UVM_HIGH
        )

        `uvm_info(
            "TPU_REF",
            $sformatf(
                "W4     = 0x%016h",
                axi_words[4]
            ),
            UVM_HIGH
        )

        `uvm_info(
            "TPU_REF",
            $sformatf(
                "INPUT0 = 0x%016h",
                axi_words[5]
            ),
            UVM_HIGH
        )

        `uvm_info(
            "TPU_REF",
            $sformatf(
                "INPUT1 = 0x%016h",
                axi_words[6]
            ),
            UVM_HIGH
        )


        // ---------------------------------------------------------------------
        // Execute the actual C golden reference model.
        // ---------------------------------------------------------------------

        tpu_reference(
            axi_words,
            c_result0,
            c_result1
        );


        // ---------------------------------------------------------------------
        // Store expected values for subsequent RESULT reads.
        // ---------------------------------------------------------------------

        expected_result0 = c_result0;
        expected_result1 = c_result1;

        reference_model_valid = 1'b1;


        `uvm_info(
            "TPU_REF",
            $sformatf(
                "Expected RESULT0 = 0x%016h",
                expected_result0
            ),
            UVM_MEDIUM
        )

        `uvm_info(
            "TPU_REF",
            $sformatf(
                "Expected RESULT1 = 0x%016h",
                expected_result1
            ),
            UVM_MEDIUM
        )

    endfunction


    // =========================================================================
    // COMPARE ONE 32-BIT RESULT WORD
    // =========================================================================
    //
    // The native bus is 32 bits wide, so each 64-bit result is checked in two
    // independent comparisons.
    //

    virtual function void compare_result_word(
        string       result_name,
        bit [31:0]   expected,
        bit [31:0]   actual,
        bit [31:0]   addr
    );

        result_compare_count++;


        // ---------------------------------------------------------------------
        // PASS
        // ---------------------------------------------------------------------

        if (actual === expected) begin

            `uvm_info(
                "TPU_PASS",
                $sformatf(
                    "%s PASS: addr=0x%08h expected=0x%08h actual=0x%08h",
                    result_name,
                    addr,
                    expected,
                    actual
                ),
                UVM_LOW
            )

        end


        // ---------------------------------------------------------------------
        // FAIL
        // ---------------------------------------------------------------------

        else begin

            result_error_count++;

            `uvm_error(
                "TPU_FAIL",
                $sformatf(
                    "%s MISMATCH: addr=0x%08h expected=0x%08h actual=0x%08h",
                    result_name,
                    addr,
                    expected,
                    actual
                )
            )

        end

    endfunction


    // =========================================================================
    // CLEAR CAPTURE STATE
    // =========================================================================
    //
    // Clears the operand-valid flags and captured operands.
    //
    // This is used during construction and can also be used when explicitly
    // resetting the scoreboard between independent TPU transactions.
    //

    virtual function void clear_capture_state();

        weight[0] = '0;
        weight[1] = '0;
        weight[2] = '0;
        weight[3] = '0;
        weight[4] = '0;

        input0 = '0;
        input1 = '0;


        w0_lo_valid = 1'b0;
        w0_hi_valid = 1'b0;

        w1_lo_valid = 1'b0;
        w1_hi_valid = 1'b0;

        w2_lo_valid = 1'b0;
        w2_hi_valid = 1'b0;

        w3_lo_valid = 1'b0;
        w3_hi_valid = 1'b0;

        w4_lo_valid = 1'b0;
        w4_hi_valid = 1'b0;

        input0_lo_valid = 1'b0;
        input0_hi_valid = 1'b0;

        input1_lo_valid = 1'b0;
        input1_hi_valid = 1'b0;


        expected_result0 = '0;
        expected_result1 = '0;

        reference_model_valid = 1'b0;

        start_seen = 1'b0;
        done_seen = 1'b0;

        result0_lo_checked = 1'b0;
        result0_hi_checked = 1'b0;

        result1_lo_checked = 1'b0;
        result1_hi_checked = 1'b0;

    endfunction


    // =========================================================================
    // REPORT PHASE
    // =========================================================================
    //
    // Produces a concise summary suitable for regression logs.
    //

    virtual function void report_phase(
        uvm_phase phase
    );

        super.report_phase(phase);


        `uvm_info(
            "TPU_SCB_SUMMARY",
            "============================================================",
            UVM_NONE
        )

        `uvm_info(
            "TPU_SCB_SUMMARY",
            $sformatf(
                "TPU write transactions : %0d",
                tpu_write_count
            ),
            UVM_NONE
        )

        `uvm_info(
            "TPU_SCB_SUMMARY",
            $sformatf(
                "TPU read transactions  : %0d",
                tpu_read_count
            ),
            UVM_NONE
        )

        `uvm_info(
            "TPU_SCB_SUMMARY",
            $sformatf(
                "TPU START events       : %0d",
                start_count
            ),
            UVM_NONE
        )

        `uvm_info(
            "TPU_SCB_SUMMARY",
            $sformatf(
                "STATUS reads           : %0d",
                status_read_count
            ),
            UVM_NONE
        )

        `uvm_info(
            "TPU_SCB_SUMMARY",
            $sformatf(
                "Result comparisons     : %0d",
                result_compare_count
            ),
            UVM_NONE
        )

        `uvm_info(
            "TPU_SCB_SUMMARY",
            $sformatf(
                "Result mismatches      : %0d",
                result_error_count
            ),
            UVM_NONE
        )

        `uvm_info(
            "TPU_SCB_SUMMARY",
            "============================================================",
            UVM_NONE
        )


        // ---------------------------------------------------------------------
        // Overall scoreboard result.
        //
        // Four result-word comparisons are expected when both 64-bit RESULT0
        // and RESULT1 are read completely:
        //
        //     RESULT0_LO
        //     RESULT0_HI
        //     RESULT1_LO
        //     RESULT1_HI
        //
        // ---------------------------------------------------------------------

        if ((result_error_count == 0) &&
            (result_compare_count != 0)) begin

            `uvm_info(
                "TPU_SCB_SUMMARY",
                "TPU SCOREBOARD: ALL RESULT CHECKS PASSED",
                UVM_NONE
            )

        end
        else if (result_error_count != 0) begin

            `uvm_error(
                "TPU_SCB_SUMMARY",
                $sformatf(
                    "TPU SCOREBOARD: %0d RESULT MISMATCH(ES)",
                    result_error_count
                )
            )

        end
        else begin

            `uvm_warning(
                "TPU_SCB_SUMMARY",
                "TPU scoreboard completed without result comparisons"
            )

        end

    endfunction


endclass

`endif

