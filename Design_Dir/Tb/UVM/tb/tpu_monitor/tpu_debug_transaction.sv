`ifndef TPU_DEBUG_TRANSACTION_SV
`define TPU_DEBUG_TRANSACTION_SV

// import uvm_pkg::*;
// `include "uvm_macros.svh"
// to get internal signals 

class tpu_debug_transaction extends uvm_sequence_item;

    `uvm_object_utils(tpu_debug_transaction)


    // ============================================================
    // EVENT TYPE
    // ============================================================

    typedef enum {
        TPU_START,
        TPU_BUSY_ASSERT,
        TPU_BUSY_DEASSERT,
        TPU_DONE,
        TPU_INPUT_TRANSFER,
        TPU_OUTPUT_TRANSFER,
        TPU_RESULT_SAMPLE,
        TPU_TRAP
    } event_type_e;

    event_type_e event_type;


    // ============================================================
    // AXI STREAM DATA
    // ============================================================

    bit [63:0] data;
    bit        last;


    // ============================================================
    // TPU RESULTS
    // ============================================================

    bit [63:0] result0;
    bit [63:0] result1;


    // ============================================================
    // TIMESTAMP
    // ============================================================

    time timestamp;

    longint unsigned cycle;


    // ============================================================
    // CONSTRUCTOR
    // ============================================================

    function new(
        string name = "tpu_debug_transaction"
    );

        super.new(name);

        event_type = TPU_START;

        data       = '0;
        last       = 1'b0;

        result0    = '0;
        result1    = '0;

        timestamp  = 0;
        cycle      = 0;

    endfunction


    // ============================================================
    // PRINT
    // ============================================================

    function string convert2string();

        case (event_type)

            TPU_START:
                return $sformatf(
                    "TPU_START time=%0t cycle=%0d",
                    timestamp,
                    cycle
                );

            TPU_BUSY_ASSERT:
                return $sformatf(
                    "TPU_BUSY_ASSERT time=%0t cycle=%0d",
                    timestamp,
                    cycle
                );

            TPU_BUSY_DEASSERT:
                return $sformatf(
                    "TPU_BUSY_DEASSERT time=%0t cycle=%0d",
                    timestamp,
                    cycle
                );

            TPU_DONE:
                return $sformatf(
                    "TPU_DONE time=%0t cycle=%0d",
                    timestamp,
                    cycle
                );

            TPU_INPUT_TRANSFER:
                return $sformatf(
                    "TPU_INPUT data=%016h last=%0b time=%0t cycle=%0d",
                    data,
                    last,
                    timestamp,
                    cycle
                );

            TPU_OUTPUT_TRANSFER:
                return $sformatf(
                    "TPU_OUTPUT data=%016h last=%0b time=%0t cycle=%0d",
                    data,
                    last,
                    timestamp,
                    cycle
                );

            TPU_RESULT_SAMPLE:
                return $sformatf(
                    "TPU_RESULT result0=%016h result1=%016h time=%0t cycle=%0d",
                    result0,
                    result1,
                    timestamp,
                    cycle
                );

            TPU_TRAP:
                return $sformatf(
                    "TPU_TRAP time=%0t cycle=%0d",
                    timestamp,
                    cycle
                );

            default:
                return "TPU_UNKNOWN";

        endcase

    endfunction

endclass


`endif