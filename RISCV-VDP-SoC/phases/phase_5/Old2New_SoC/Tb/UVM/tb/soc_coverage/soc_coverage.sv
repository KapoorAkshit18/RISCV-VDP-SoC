`ifndef SOC_COVERAGE_SV
`define SOC_COVERAGE_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"


// =============================================================================
// RISCV-VDP-SoC
// UVM Functional Coverage
//
// Coverage is collected from transactions observed by soc_monitor.
//
// Monitor
//    |
//    +----> RAL Predictor
//    |
//    +----> soc_coverage
//
// No scoreboard is required for functional coverage.
// =============================================================================

class soc_coverage extends uvm_subscriber #(soc_sequence_item);

    `uvm_component_utils(soc_coverage)


    // =========================================================================
    // Transaction received from monitor
    // =========================================================================

    soc_sequence_item tr;

    // Numeric representation of transaction target
    int target_bin;


    // =========================================================================
    // Functional Coverage
    // =========================================================================

    covergroup soc_cg;

        // ---------------------------------------------------------------------
        // READ / WRITE coverage
        // ---------------------------------------------------------------------

        cp_write: coverpoint tr.write {

            bins READ  = {1'b0};
            bins WRITE = {1'b1};

        }


        // ---------------------------------------------------------------------
        // Target coverage
        // ---------------------------------------------------------------------

        cp_target: coverpoint target_bin {

            bins RAM      = {0};
            bins GPIO     = {1};
            bins RF       = {2};
            bins SENSOR   = {3};
            bins VDP      = {4};
            bins UNMAPPED = {5};
          //  bins UNKNOWN  = {6};

        }


        // ---------------------------------------------------------------------
        // Write strobe coverage
        // ---------------------------------------------------------------------

        cp_strb: coverpoint tr.strb {

            bins READ_STRB = {4'b0000};

            bins BYTE0 = {4'b0001};
            bins BYTE1 = {4'b0010};
            bins BYTE2 = {4'b0100};
            bins BYTE3 = {4'b1000};

            bins HALFWORD_LOW  = {4'b0011};
            bins HALFWORD_HIGH = {4'b1100};

            bins FULL_WORD = {4'b1111};

            bins OTHER = default;

        }


        // ---------------------------------------------------------------------
        // Address coverage
        // ---------------------------------------------------------------------

        cp_addr: coverpoint tr.addr {

            bins RAM_BASE = {
                32'h0000_0000
            };

            bins RAM_LOW = {
                [32'h0000_0001 : 32'h0000_00FF]
            };

            bins GPIO_BASE = {
                32'h0001_0000
            };

            bins RF_BASE = {
                32'h0001_1000
            };

            bins SENSOR_BASE = {
                32'h0001_2000
            };

            bins VDP_BASE = {
                32'h0001_3000
            };

            bins UNMAPPED = {
                32'h0002_0000
            };

        }


        // ---------------------------------------------------------------------
        // Write data pattern coverage
        // ---------------------------------------------------------------------

        cp_wdata: coverpoint tr.wdata iff (tr.write) {

            bins ZERO = {
                32'h0000_0000
            };

            bins ONES = {
                32'hFFFF_FFFF
            };

            bins AA = {
                32'hAAAA_AAAA
            };

            bins FIVE = {
                32'h5555_5555
            };

            bins OTHER = default;

        }


        // ---------------------------------------------------------------------
        // Response / ready coverage
        // ---------------------------------------------------------------------

        cp_ready: coverpoint tr.ready {

            bins READY = {1'b1};

        }


        // =========================================================================
        // Cross Coverage
        // =========================================================================

        // Read / Write × Target
        cross_rw_target:
            cross cp_write, cp_target;


        // // // Write × Strobe
        // cross_write_strb:
        //     cross cp_write, cp_strb;  
            cross_write_strb: cross cp_write, cp_strb {

    ignore_bins read_byte0 =
        binsof(cp_write.READ) &&
        binsof(cp_strb.BYTE0);

    ignore_bins read_byte1 =
        binsof(cp_write.READ) &&
        binsof(cp_strb.BYTE1);

    ignore_bins read_byte2 =
        binsof(cp_write.READ) &&
        binsof(cp_strb.BYTE2);

    ignore_bins read_byte3 =
        binsof(cp_write.READ) &&
        binsof(cp_strb.BYTE3);

    ignore_bins read_halfword_low =
        binsof(cp_write.READ) &&
        binsof(cp_strb.HALFWORD_LOW);

    ignore_bins read_halfword_high =
        binsof(cp_write.READ) &&
        binsof(cp_strb.HALFWORD_HIGH);

    ignore_bins read_full_word =
        binsof(cp_write.READ) &&
        binsof(cp_strb.FULL_WORD);

    ignore_bins write_read_strb =
        binsof(cp_write.WRITE) &&
        binsof(cp_strb.READ_STRB);
}


        // // Write × Target × Strobe
        // cross_write_target_strb:
        //     cross cp_write, cp_target, cp_strb;removed for less complexity


    endgroup


    // =========================================================================
    // Constructor
    // =========================================================================

    function new(
        string name = "soc_coverage",
        uvm_component parent = null
    );

        super.new(name, parent);

        soc_cg = new();

    endfunction


    // =========================================================================
    // Receive transaction from monitor
    // =========================================================================

    virtual function void write(
        soc_sequence_item t
    );

        tr = t;


        // ---------------------------------------------------------------------
        // Convert string target to numeric coverage value
        // ---------------------------------------------------------------------

        case (tr.target)

            "RAM":
                target_bin = 0;

            "GPIO":
                target_bin = 1;

            "RF":
                target_bin = 2;

            "SENSOR":
                target_bin = 3;

            "VDP":
                target_bin = 4;

            "UNMAPPED":
                target_bin = 5;

            default:
                target_bin = 6;

        endcase


        // ---------------------------------------------------------------------
        // Sample coverage
        // ---------------------------------------------------------------------

        soc_cg.sample();


        `uvm_info(
            "COVERAGE",
            $sformatf(
                "Coverage sampled: target=%s write=%0b addr=0x%08h strb=0x%1h",
                tr.target,
                tr.write,
                tr.addr,
                tr.strb
            ),
            UVM_HIGH
        )

    endfunction


    // =========================================================================
    // Coverage report
    // =========================================================================

    virtual function void report_phase(
        uvm_phase phase
    );

        super.report_phase(phase);


        `uvm_info(
            "FUNCTIONAL_COVERAGE",
            $sformatf(
                "SoC Functional Coverage = %0.2f%%",
                soc_cg.get_inst_coverage()
            ),
            UVM_NONE
        )

    endfunction


endclass


`endif