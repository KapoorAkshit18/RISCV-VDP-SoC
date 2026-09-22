`ifndef SOC_RAL_SEQUENCE_SV
`define SOC_RAL_SEQUENCE_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// RAL Smoke Sequence
//
// This sequence verifies the RAL frontdoor path:
//
//     RAL register
//          |
//          v
//     soc_reg_adapter
//          |
//          v
//     soc_sequence_item
//          |
//          v
//     native sequencer
//          |
//          v
//     driver
//          |
//          v
//         DUT
//
// The existing soc_base_sequence is used as the sequence base so that the
// sequence remains compatible with the existing native-bus sequencer.
//
// =============================================================================

class soc_ral_smoke_sequence extends soc_base_sequence;

    `uvm_object_utils(soc_ral_smoke_sequence)


    // =========================================================================
    // RAL model
    // =========================================================================

    soc_reg_block ral_model;


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_ral_smoke_sequence"
    );

        super.new(name);

    endfunction


    // =========================================================================
    // Body
    // =========================================================================

    virtual task body();

        uvm_status_e status;

        uvm_reg_data_t read_data;


        // =====================================================================
        // Check RAL model handle
        // =====================================================================

        if (ral_model == null) begin

            `uvm_fatal(
                "RAL_NULL",
                "soc_ral_smoke_sequence: ral_model is null"
            )

        end


        `uvm_info(
            "RAL_SEQ",
            "Starting RAL smoke sequence",
            UVM_LOW
        )


        // =====================================================================
        // TEST 1
        // VDP_CTRL WRITE
        //
        // VDP base address = 0x0001_3000
        // CTRL offset      = 0x0000
        //
        // Address = 0x0001_3000
        //
        // bit 0 = display_enable = 1
        // bit 1 = pattern_mode   = 0
        //
        // Expected value = 0x00000001
        // =====================================================================

        `uvm_info(
            "RAL_SEQ",
            "VDP_CTRL WRITE: 0x00000001",
            UVM_MEDIUM
        )


        ral_model.vdp.ctrl.write(
            status,
            32'h0000_0001,
            UVM_FRONTDOOR,
            ral_model.default_map,
            this
        );


        if (status != UVM_IS_OK) begin

            `uvm_error(
                "RAL_WRITE",
                "VDP_CTRL write failed"
            )

        end
        else begin

            `uvm_info(
                "RAL_WRITE",
                "VDP_CTRL write PASS",
                UVM_MEDIUM
            )

        end


        // =====================================================================
        // TEST 2
        // VDP_CTRL READ
        // =====================================================================

        `uvm_info(
            "RAL_SEQ",
            "VDP_CTRL READ",
            UVM_MEDIUM
        )


        ral_model.vdp.ctrl.read(
            status,
            read_data,
            UVM_FRONTDOOR,
            ral_model.default_map,
            this
        );


        if (status != UVM_IS_OK) begin

            `uvm_error(
                "RAL_READ",
                "VDP_CTRL read failed"
            )

        end
        else begin

            `uvm_info(
                "RAL_READ",
                $sformatf(
                    "VDP_CTRL read = 0x%08h",
                    read_data
                ),
                UVM_MEDIUM
            )

        end


        // =====================================================================
        // CHECK VDP_CTRL
        // =====================================================================

        if (read_data[1:0] != 2'b01) begin

            `uvm_error(
                "RAL_CHECK",
                $sformatf(
                    "VDP_CTRL mismatch: expected 0x01, got 0x%08h",
                    read_data
                )
            )

        end
        else begin

            `uvm_info(
                "RAL_CHECK",
                "VDP_CTRL readback PASS",
                UVM_MEDIUM
            )

        end


        // =====================================================================
        // TEST 3
        // VDP_COLOR WRITE
        //
        // RGB888:
        //
        // R = FF
        // G = 00
        // B = 00
        //
        // COLOR = 0x00FF0000
        // =====================================================================

        `uvm_info(
            "RAL_SEQ",
            "VDP_COLOR WRITE: 0x00FF0000",
            UVM_MEDIUM
        )


        ral_model.vdp.color.write(
            status,
            32'h00FF_0000,
            UVM_FRONTDOOR,
            ral_model.default_map,
            this
        );


        if (status != UVM_IS_OK) begin

            `uvm_error(
                "RAL_WRITE",
                "VDP_COLOR write failed"
            )

        end
        else begin

            `uvm_info(
                "RAL_WRITE",
                "VDP_COLOR write PASS",
                UVM_MEDIUM
            )

        end


        // =====================================================================
        // TEST 4
        // VDP_COLOR READ
        // =====================================================================

        ral_model.vdp.color.read(
            status,
            read_data,
            UVM_FRONTDOOR,
            ral_model.default_map,
            this
        );


        if (status != UVM_IS_OK) begin

            `uvm_error(
                "RAL_READ",
                "VDP_COLOR read failed"
            )

        end
        else begin

            `uvm_info(
                "RAL_READ",
                $sformatf(
                    "VDP_COLOR read = 0x%08h",
                    read_data
                ),
                UVM_MEDIUM
            )

        end


        // =====================================================================
        // CHECK VDP_COLOR
        // =====================================================================

        if (read_data[23:0] != 24'hFF0000) begin

            `uvm_error(
                "RAL_CHECK",
                $sformatf(
                    "VDP_COLOR mismatch: expected 0xFF0000, got 0x%06h",
                    read_data[23:0]
                )
            )

        end
        else begin

            `uvm_info(
                "RAL_CHECK",
                "VDP_COLOR readback PASS",
                UVM_MEDIUM
            )

        end


        // =====================================================================
        // Final message
        // =====================================================================

        `uvm_info(
            "RAL_SEQ",
            "==============================================",
            UVM_LOW
        )

        `uvm_info(
            "RAL_SEQ",
            "       RAL SMOKE SEQUENCE COMPLETED",
            UVM_LOW
        )

        `uvm_info(
            "RAL_SEQ",
            "==============================================",
            UVM_LOW
        )

    endtask

endclass


`endif